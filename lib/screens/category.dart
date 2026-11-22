import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forui/forui.dart';
import 'package:share_plus/share_plus.dart';

import '../attachments.dart';
import '../models.dart';
import '../sheets.dart';
import '../storage.dart';
import '../theme.dart';
import '../widgets.dart';
import 'media.dart';

/// One conversation: notes as messages, newest at the bottom.
///
/// Press and hold a note to select it. While notes are selected the top bar
/// turns into an action bar (remind, star, copy, forward, delete).
class CategoryScreen extends StatefulWidget {
  const CategoryScreen({super.key, required this.category, this.focusNote});
  final Category category;

  /// When set, the conversation opens scrolled to this note and highlights it.
  final Note? focusNote;

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  final TextEditingController _input = TextEditingController();
  final TextEditingController _search = TextEditingController();
  bool _searching = false;
  final Map<String, GlobalKey> _keys = <String, GlobalKey>{};
  final Set<Note> _selected = <Note>{};
  int _tab = 0; // 0 = all notes, 1 = starred
  String? _flashId;
  Timer? _flashTimer;
  int _reminderCursor = 0;

  bool get _selecting => _selected.isNotEmpty;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      AppScope.of(context).markRead(widget.category);
      final Note? focus = widget.focusNote;
      if (focus != null) _jumpTo(focus);
    });
  }

  @override
  void dispose() {
    _flashTimer?.cancel();
    _input.dispose();
    _search.dispose();
    super.dispose();
  }

  GlobalKey _keyFor(Note n) => _keys.putIfAbsent(n.id, () => GlobalKey());

  /// Scrolls to [note] and tints it for a moment so the eye can find it.
  void _jumpTo(Note note) {
    if (_tab != 0) setState(() => _tab = 0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final BuildContext? target = _keys[note.id]?.currentContext;
      if (target == null) return;
      Scrollable.ensureVisible(
        target,
        alignment: 0.5,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
      setState(() => _flashId = note.id);
      _flashTimer?.cancel();
      _flashTimer = Timer(const Duration(milliseconds: 1400), () {
        if (mounted) setState(() => _flashId = null);
      });
    });
  }

  void _send() {
    final String text = _input.text.trim();
    if (text.isEmpty) return;
    AppScope.of(context).addNote(widget.category, text);
    _input.clear();
    setState(() => _tab = 0);
  }

  Future<void> _attach() async {
    FocusScope.of(context).unfocus();
    await addAttachmentFlow(context, widget.category);
    if (mounted) setState(() => _tab = 0);
  }

  // ----- selection -----

  void _toggle(Note n) {
    setState(() {
      if (!_selected.remove(n)) _selected.add(n);
    });
  }

  void _clearSelection() => setState(_selected.clear);

  List<Note> get _selectedInOrder =>
      widget.category.notes.where(_selected.contains).toList();

  Future<void> _remindSelected() async {
    final Note note = _selected.first;
    final DateTime? when = await showReminderSheet(context, note: note);
    if (!mounted) return;
    _clearSelection();
    if (when != null) setReminderWithUndo(context, note, when);
  }

  void _starSelected() {
    final bool allStarred = _selected.every((Note n) => n.starred);
    AppScope.of(context).setStarred(_selected, !allStarred);
    _clearSelection();
  }

  Future<void> _copySelected() async {
    final String text = _selectedInOrder.map((Note n) => n.searchText.trim()).join('\n\n');
    final int count = _selected.length;
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    _clearSelection();
    showCemoSnack(context, count == 1 ? 'Copied' : '$count notes copied');
  }

  Future<void> _forwardSelected() async {
    final List<Note> notes = _selectedInOrder;
    final Category? target = await pickCategory(context, title: 'Forward to', exclude: widget.category);
    if (target == null || !mounted) return;
    await AppScope.of(context).forwardNotes(notes, target);
    if (!mounted) return;
    _clearSelection();
    showCemoSnack(context, 'Forwarded to ${target.name}');
  }

  Future<void> _deleteSelected() async {
    final List<Note> notes = _selectedInOrder;
    final int count = notes.length;
    final bool ok = await confirmDialog(
      context,
      title: count == 1 ? 'Delete this note?' : 'Delete $count notes?',
      message: 'This can’t be undone.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok || !mounted) return;
    AppScope.of(context).deleteNotes(widget.category, notes);
    _clearSelection();
    showCemoSnack(context, count == 1 ? 'Note deleted' : '$count notes deleted');
  }

  // ----- menu: search, media, clear, export -----

  void _startSearch() => setState(() {
        _selected.clear();
        _searching = true;
        _tab = 0;
      });

  void _stopSearch() => setState(() {
        _searching = false;
        _search.clear();
      });

  /// Tapping a search result leaves search and shows the note in place.
  void _openFromSearch(Note note) {
    _stopSearch();
    _jumpTo(note);
  }

  Future<void> _editCategory() async {
    await showCategorySheet(context, existing: widget.category);
    if (mounted) setState(() {});
  }

  void _openMedia() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => ConversationMediaScreen(category: widget.category)),
    );
  }

  Future<void> _clearConversation() async {
    final Category cat = widget.category;
    if (cat.notes.isEmpty) {
      showCemoSnack(context, 'There are no notes to clear.');
      return;
    }
    final int count = cat.notes.length;
    final bool ok = await confirmDialog(
      context,
      title: 'Clear this conversation?',
      message: 'This deletes ${count == 1 ? 'its 1 note' : 'all $count notes'} in “${cat.name}”, including starred notes and reminders. The category stays. This can’t be undone.',
      confirmLabel: 'Clear',
      destructive: true,
    );
    if (!ok || !mounted) return;
    AppScope.of(context).clearNotes(cat);
    showCemoSnack(context, 'Conversation cleared');
  }

  /// Writes the conversation as a JSON file and opens the system share sheet,
  /// so it can be saved to Files, sent by email, and so on.
  Future<void> _exportJson() async {
    final Category cat = widget.category;
    final String json = const JsonEncoder.withIndent('  ').convert(AppScope.of(context).exportCategory(cat));
    final String safeName = cat.name.toLowerCase().replaceAll(RegExp('[^a-z0-9]+'), '-');
    final RenderBox? box = context.findRenderObject() as RenderBox?;
    final Rect? origin = box == null ? null : box.localToGlobal(Offset.zero) & box.size;
    try {
      final File file = await Storage.writeExport('cemo-$safeName.json', json);
      await SharePlus.instance.share(ShareParams(
        files: <XFile>[XFile(file.path, mimeType: 'application/json')],
        subject: 'Cemo notes: ${cat.name}',
        sharePositionOrigin: origin,
      ));
    } catch (_) {
      if (mounted) showCemoSnack(context, 'Couldn’t export the notes.');
    }
  }

  /// A header with a hairline under it.
  Widget _bar(Widget header) => Column(mainAxisSize: MainAxisSize.min, children: <Widget>[header, const Hairline()]);

  Widget _searchBar(BuildContext context) {
    return _bar(FHeader.nested(
      titleAlignment: AlignmentDirectional.centerStart,
      prefixes: <Widget>[FHeaderAction.back(semanticsLabel: 'Close search', onPress: _stopSearch)],
      title: FTextField(
        control: FTextFieldControl.managed(controller: _search, onChange: (_) => setState(() {})),
        autofocus: true,
        textInputAction: TextInputAction.search,
        hint: 'Search in ${widget.category.name}',
        clearable: (TextEditingValue value) => value.text.isNotEmpty,
      ),
    ));
  }

  // ----- build -----

  Widget _normalBar(BuildContext context) {
    final Category cat = widget.category;

    FItem entry(FPopoverController controller, String label, VoidCallback action) => FItem(
          title: Text(label, style: Tx.ui(context)),
          onPress: () {
            controller.hide();
            action();
          },
        );

    return _bar(FHeader.nested(
      titleAlignment: AlignmentDirectional.centerStart,
      prefixes: <Widget>[FHeaderAction.back(semanticsLabel: 'Back', onPress: () => Navigator.of(context).pop())],
      title: FTappable(
        semanticsLabel: 'Edit category ${cat.name}',
        onPress: _editCategory,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: <Widget>[
              CategoryAvatar(color: cat.color, icon: cat.icon, size: 36, imagePath: cat.imagePath),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(cat.name, style: Tx.subhead(context), overflow: TextOverflow.ellipsis),
                    Text(cat.notes.isEmpty ? 'No notes yet' : '${cat.notes.length} notes', style: Tx.meta(context)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      suffixes: <Widget>[
        FPopoverMenu(
          menuAnchor: Alignment.topRight,
          childAnchor: Alignment.bottomRight,
          menuBuilder: (BuildContext context, FPopoverController controller, List<FItemGroupMixin>? menu) =>
              <FItemGroupMixin>[
            FItemGroup(
              children: <FItemMixin>[
                entry(controller, 'Search', _startSearch),
                entry(controller, 'Media, links and docs', _openMedia),
                entry(controller, 'Clear conversation', _clearConversation),
                entry(controller, 'Export notes (JSON)', _exportJson),
              ],
            ),
          ],
          builder: (BuildContext context, FPopoverController controller, Widget? child) => FHeaderAction(
            semanticsLabel: 'More',
            icon: const Icon(FLucideIcons.ellipsisVertical),
            onPress: controller.toggle,
          ),
        ),
      ],
    ));
  }

  Widget _selectionBar(BuildContext context) {
    final bool single = _selected.length == 1;
    final bool allStarred = _selected.every((Note n) => n.starred);
    return _bar(FHeader.nested(
      titleAlignment: AlignmentDirectional.centerStart,
      prefixes: <Widget>[FHeaderAction.x(semanticsLabel: 'Cancel selection', onPress: _clearSelection)],
      title: Text('${_selected.length}', style: Tx.subhead(context)),
      suffixes: <Widget>[
        if (single)
          FHeaderAction(semanticsLabel: 'Remind me', icon: const Icon(FLucideIcons.bell), onPress: _remindSelected),
        FHeaderAction(
          semanticsLabel: allStarred ? 'Unstar' : 'Star',
          icon: Icon(allStarred ? FLucideIcons.starOff : FLucideIcons.star),
          onPress: _starSelected,
        ),
        FHeaderAction(semanticsLabel: 'Copy', icon: const Icon(FLucideIcons.copy), onPress: _copySelected),
        FHeaderAction(semanticsLabel: 'Forward', icon: const Icon(FLucideIcons.forward), onPress: _forwardSelected),
        FHeaderAction(semanticsLabel: 'Delete', icon: const Icon(FLucideIcons.trash2), onPress: _deleteSelected),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    AppScope.of(context); // rebuild when notes change
    final CemoColors c = context.c;
    final Category cat = widget.category;
    final String query = _search.text.trim().toLowerCase();
    final List<Note> notes = _searching
        ? cat.notes.where((Note n) => query.isEmpty || n.searchText.toLowerCase().contains(query)).toList()
        : (_tab == 0 ? cat.notes : cat.notes.where((Note n) => n.starred).toList());
    // Notes that were deleted elsewhere must not stay selected.
    _selected.removeWhere((Note n) => !cat.notes.contains(n));

    final List<Note> reminders = cat.notes.where((Note n) => n.reminder != null && !n.reminderDone).toList()
      ..sort((Note a, Note b) => a.reminder!.compareTo(b.reminder!));

    final List<Widget> rows = <Widget>[];
    for (int i = 0; i < notes.length; i++) {
      final Note note = notes[i];
      if (i == 0 || !sameDay(notes[i - 1].time, note.time)) {
        rows.add(_DateSeparator(label: dayLabel(note.time)));
      }
      rows.add(KeyedSubtree(
        key: _keyFor(note),
        child: NoteMessage(
          note: note,
          selecting: _selecting || _searching,
          selected: _selected.contains(note),
          flash: _flashId == note.id,
          onTap: () => (_searching && !_selecting) ? _openFromSearch(note) : _toggle(note),
          onLongPress: () => _toggle(note),
        ),
      ));
    }

    return PopScope(
      canPop: !_selecting && !_searching,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) return;
        if (_selecting) {
          _clearSelection();
        } else {
          _stopSearch();
        }
      },
      child: FScaffold(
        childPad: false,
        header: _selecting ? _selectionBar(context) : (_searching ? _searchBar(context) : _normalBar(context)),
        child: SafeArea(
          top: false,
          child: Column(
            children: <Widget>[
              if (!_searching)
              TopicTabs(
                labels: const <String>['All notes', 'Starred'],
                selected: _tab,
                onSelect: (int i) => setState(() {
                  _tab = i;
                  _selected.clear();
                }),
              ),
              if (reminders.isNotEmpty && !_searching)
                _Bar(
                  icon: FLucideIcons.bellRing,
                  iconColor: c.reminder,
                  color: c.bg2,
                  text: () {
                    final Note next = reminders[_reminderCursor % reminders.length];
                    return '${reminderLabel(next.reminder!)} · ${next.preview}';
                  }(),
                  trailing: reminders.length > 1 ? '${_reminderCursor % reminders.length + 1} of ${reminders.length}' : null,
                  onTap: () {
                    final Note target = reminders[_reminderCursor % reminders.length];
                    _jumpTo(target);
                    // The next tap moves on to the following reminder.
                    setState(() => _reminderCursor = (_reminderCursor + 1) % reminders.length);
                  },
                ),
              Expanded(
                child: notes.isEmpty
                    ? (_searching
                        ? EmptyState(
                            scene: 11,
                            imageLabel: 'Memo looking at a blank card through a magnifying glass',
                            title: 'No notes match “${_search.text.trim()}”.',
                            text: 'Check the spelling or try a shorter word.',
                          )
                        : _tab == 1
                        ? const EmptyState(
                            scene: 13,
                            imageLabel: 'Memo reaching for an empty star',
                            title: 'No starred notes yet.',
                            text: 'Press and hold a note, then tap the star to keep it here.',
                          )
                        : const EmptyState(
                            scene: 10,
                            imageLabel: 'Memo beside an empty speech bubble',
                            title: 'Nothing here yet.',
                            text: 'Write your first note below, or tap the camera to add a photo, video or document.',
                          ))
                    : SingleChildScrollView(
                        reverse: true,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows),
                      ),
              ),
              if (_tab == 0 && !_selecting && !_searching) _composer(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _composer(BuildContext context) {
    final CemoColors c = context.c;
    final bool canSend = _input.text.trim().isNotEmpty;
    return Container(
      decoration: BoxDecoration(color: c.bg, border: Border(top: BorderSide(color: c.divider))),
      padding: const EdgeInsets.fromLTRB(Space.sm, Space.sm, Space.sm, Space.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          FButton.icon(
            variant: FButtonVariant.ghost,
            semanticsLabel: 'Add a photo, video or document',
            onPress: _attach,
            child: Icon(FLucideIcons.camera, size: 24, color: c.t2),
          ),
          const SizedBox(width: Space.xs),
          Expanded(
            child: FTextField(
              control: FTextFieldControl.managed(controller: _input, onChange: (_) => setState(() {})),
              minLines: 1,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              hint: 'Write a note…',
            ),
          ),
          const SizedBox(width: Space.xs),
          FButton.icon(
            variant: FButtonVariant.primary,
            semanticsLabel: 'Send',
            onPress: canSend ? _send : null,
            child: const Icon(FLucideIcons.arrowUp, size: 18),
          ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.icon,
    required this.iconColor,
    required this.color,
    required this.text,
    required this.onTap,
    this.trailing,
  });
  final IconData icon;
  final Color iconColor;
  final Color color;
  final String text;
  final VoidCallback onTap;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final CemoColors c = context.c;
    return ColoredBox(
      color: color,
      child: FTappable.static(
        onPress: onTap,
        child: Container(
          height: 44,
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.divider))),
          padding: const EdgeInsets.fromLTRB(24, 0, 16, 0),
          child: Row(
            children: <Widget>[
              Icon(icon, size: 16, color: iconColor),
              const SizedBox(width: 10),
              Expanded(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: Tx.ui(context))),
              if (trailing != null) ...<Widget>[
                const SizedBox(width: 8),
                Text(trailing!, style: Tx.meta(context)),
              ],
              Icon(FLucideIcons.chevronRight, size: 18, color: c.t2),
            ],
          ),
        ),
      ),
    );
  }
}

class _DateSeparator extends StatelessWidget {
  const _DateSeparator({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final CemoColors c = context.c;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
      child: Row(
        children: <Widget>[
          Expanded(child: Hairline(color: c.border)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(label.toUpperCase(), style: Tx.caption(context).copyWith(letterSpacing: 0.5)),
          ),
          Expanded(child: Hairline(color: c.border)),
        ],
      ),
    );
  }
}

/// One note, right-aligned like a sent message.
///
/// Press and hold selects it. While [selecting] is true a tap toggles the
/// selection and the note's own controls (checklist boxes) are switched off.
class NoteMessage extends StatelessWidget {
  const NoteMessage({
    super.key,
    required this.note,
    required this.onLongPress,
    this.onTap,
    this.selecting = false,
    this.selected = false,
    this.flash = false,
  });
  final Note note;
  final VoidCallback onLongPress;
  final VoidCallback? onTap;
  final bool selecting;
  final bool selected;
  final bool flash;

  static const BorderRadius _radius = BorderRadius.only(
    topLeft: Radius.circular(18),
    topRight: Radius.circular(18),
    bottomLeft: Radius.circular(18),
    bottomRight: Radius.circular(4),
  );

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final CemoColors c = context.c;
    final double maxW = (MediaQuery.sizeOf(context).width - 32) * 0.84;

    Widget ink(String text) => Container(
          constraints: BoxConstraints(maxWidth: maxW),
          decoration: BoxDecoration(color: c.primaryFill, borderRadius: _radius),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Text(text, style: Tx.bodySerif(context).copyWith(color: c.primaryText)),
        );

    final List<Widget> parts = <Widget>[];
    switch (note.kind) {
      case NoteKind.text:
        parts.add(ink(note.text));
        break;
      case NoteKind.link:
        parts.add(Semantics(
          link: true,
          child: GestureDetector(
            onTap: () => openLink(context, note.link),
            child: _LinkCard(note: note, width: maxW),
          ),
        ));
        if (note.text.isNotEmpty) {
          parts.add(const SizedBox(height: 6));
          parts.add(ink(note.text));
        }
        break;
      case NoteKind.image:
      case NoteKind.video:
        final double side = maxW < 260 ? maxW : 260;
        parts.add(Semantics(
          button: true,
          label: note.kind == NoteKind.video ? 'Play video' : 'Open photo',
          child: GestureDetector(
            onTap: () => openAttachment(context, note),
            child: MediaTile(note: note, width: side, height: side * 0.75),
          ),
        ));
        if (note.text.isNotEmpty) {
          parts.add(const SizedBox(height: 6));
          parts.add(ink(note.text));
        }
        break;
      case NoteKind.document:
        parts.add(Semantics(
          button: true,
          label: 'Open document',
          child: GestureDetector(
            onTap: () => openAttachment(context, note),
            child: DocumentCard(note: note, width: maxW),
          ),
        ));
        break;
      case NoteKind.checklist:
        parts.add(Container(
          constraints: BoxConstraints(maxWidth: maxW),
          decoration: BoxDecoration(border: Border.all(color: c.border), borderRadius: _radius),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              for (final CheckItem item in note.items)
                FTappable.static(
                  semanticsChecked: item.done,
                  onPress: () => state.toggleCheck(item),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Icon(item.done ? FLucideIcons.squareCheck : FLucideIcons.square, size: 22, color: c.t2),
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            item.text,
                            style: Tx.bodySerif(context).copyWith(
                              color: item.done ? c.t2 : c.t1,
                              decoration: item.done ? TextDecoration.lineThrough : TextDecoration.none,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ));
        break;
    }

    final Widget meta = Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Wrap(
        alignment: WrapAlignment.end,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 4,
        children: <Widget>[
          if (note.reminder != null) ReminderChip(when: note.reminder!, done: note.reminderDone),
          if (note.starred)
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.6, end: 1),
              duration: const Duration(milliseconds: 180),
              builder: (BuildContext context, double v, Widget? child) => Transform.scale(scale: v, child: child),
              child: Icon(FLucideIcons.star, size: 14, color: c.t2, semanticLabel: 'Starred'),
            ),
          Text(hhmm(note.time), style: Tx.caption(context).copyWith(color: c.t3)),
        ],
      ),
    );

    return Semantics(
      selected: selected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onLongPress: onLongPress,
        onTap: selecting ? onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          color: (selected || flash) ? c.highlight : c.highlight.withAlpha(0),
          padding: const EdgeInsets.fromLTRB(16, 7, 16, 7),
          child: IgnorePointer(
            ignoring: selecting,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[...parts, meta],
            ),
          ),
        ),
      ),
    );
  }
}

class _LinkCard extends StatelessWidget {
  const _LinkCard({required this.note, required this.width});
  final Note note;
  final double width;

  @override
  Widget build(BuildContext context) {
    final CemoColors c = context.c;
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: c.bg,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(4),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Text(note.linkTitle ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: Tx.subhead(context)),
                    const SizedBox(height: 4),
                    Text(note.linkDomain ?? '', style: Tx.caption(context)),
                  ],
                ),
              ),
            ),
            Container(
              width: 72,
              constraints: const BoxConstraints(minHeight: 72),
              color: c.bg2,
              child: Icon(FLucideIcons.link, color: c.t2),
            ),
          ],
        ),
      ),
    );
  }
}

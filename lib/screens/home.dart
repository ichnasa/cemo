import 'package:flutter/material.dart';

import '../models.dart';
import '../sheets.dart';
import '../theme.dart';
import '../widgets.dart';
import 'category.dart';
import 'feedback.dart';

/// Opens a conversation. With [focus] it opens scrolled to that note.
void openCategory(BuildContext context, Category category, {Note? focus}) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => CategoryScreen(category: category, focusNote: focus)),
  );
}

/// Top bar shown while items are selected: close, count, then the actions.
class _SelectionHeader extends StatelessWidget {
  const _SelectionHeader({required this.count, required this.onClose, required this.actions});
  final int count;
  final VoidCallback onClose;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          children: <Widget>[
            IconButton(tooltip: 'Cancel selection', icon: const Icon(Icons.close), onPressed: onClose),
            const SizedBox(width: 4),
            Text('$count', style: Tx.subhead(context)),
            const Spacer(),
            ...actions,
          ],
        ),
      ),
    );
  }
}

/// The signed-in app: four tabs. New note is the round button on the Notes tab.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;

  Future<void> _newNote() async {
    final AppState state = AppScope.of(context);
    if (state.sortedCategories.isEmpty) {
      final Category? created = await showNewCategorySheet(context);
      if (created == null || !mounted) return;
    }
    if (!mounted) return;
    final Category? saved = await showNewNoteSheet(context);
    if (saved != null && mounted) {
      showCemoSnack(context, 'Saved to ${saved.name}', actionLabel: 'Open', onAction: () => openCategory(context, saved));
    }
  }

  @override
  Widget build(BuildContext context) {
    final CemoColors c = context.c;
    Widget tab(int index, IconData off, IconData on, String label) {
      final bool selected = _tab == index;
      return IconButton(
        tooltip: label,
        isSelected: selected,
        iconSize: 26,
        onPressed: () => setState(() => _tab = index),
        icon: Icon(selected ? on : off, color: selected ? c.t1 : c.t2),
      );
    }

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: _tab,
          children: <Widget>[
            HomeTab(active: _tab == 0, onNewNote: _newNote),
            const SearchTab(),
            RemindersTab(active: _tab == 2),
            const ProfileTab(),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(color: c.bg, border: Border(top: BorderSide(color: c.divider))),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 56,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: <Widget>[
                tab(0, Icons.home_outlined, Icons.home, 'Notes'),
                tab(1, Icons.search, Icons.search, 'Search'),
                tab(2, Icons.notifications_none, Icons.notifications, 'Reminders'),
                tab(3, Icons.person_outline, Icons.person, 'Profile'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------- Home tab: the conversation list ----------

class HomeTab extends StatefulWidget {
  const HomeTab({super.key, required this.active, required this.onNewNote});

  /// False while another bottom tab is showing; selection is dropped then.
  final bool active;
  final VoidCallback onNewNote;

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  static const List<String> _filters = <String>['All', 'Pinned', 'Archived'];
  int _filter = 0;
  final Set<Category> _selected = <Category>{};

  bool get _selecting => _selected.isNotEmpty;
  bool get _inArchive => _filter == 2;

  @override
  void didUpdateWidget(HomeTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.active && _selected.isNotEmpty) _selected.clear();
  }

  void _toggle(Category c) {
    setState(() {
      if (!_selected.remove(c)) _selected.add(c);
    });
  }

  void _clear() => setState(_selected.clear);

  String _what(List<Category> list) => list.length == 1 ? '“${list.first.name}”' : '${list.length} categories';

  void _pin() {
    final AppState state = AppScope.of(context);
    final bool allPinned = _selected.every((Category c) => c.pinned);
    state.setPinned(_selected.toList(), !allPinned);
    _clear();
  }

  void _archive() {
    final AppState state = AppScope.of(context);
    final List<Category> list = _selected.toList();
    state.setArchived(list, true);
    _clear();
    showCemoSnack(context, '${_what(list)} archived', actionLabel: 'Undo', onAction: () => state.setArchived(list, false));
  }

  /// Delete on the main list archives, after asking. Permanent delete lives in Archived.
  Future<void> _deleteToArchive() async {
    final AppState state = AppScope.of(context);
    final List<Category> list = _selected.toList();
    final bool ok = await confirmDialog(
      context,
      title: 'Archive ${_what(list)}?',
      message: 'It moves to the Archived tab with all its notes. To delete it permanently, delete it from Archived.',
      confirmLabel: 'Archive',
    );
    if (!ok || !mounted) return;
    state.setArchived(list, true);
    _clear();
    showCemoSnack(context, '${_what(list)} archived');
  }

  void _unarchive() {
    final AppState state = AppScope.of(context);
    final List<Category> list = _selected.toList();
    state.setArchived(list, false);
    _clear();
    showCemoSnack(context, '${_what(list)} restored');
  }

  Future<void> _deleteForever() async {
    final AppState state = AppScope.of(context);
    final List<Category> list = _selected.toList();
    final int notes = list.fold<int>(0, (int sum, Category c) => sum + c.notes.length);
    final bool ok = await confirmDialog(
      context,
      title: 'Delete ${_what(list)} permanently?',
      message: 'This also deletes ${notes == 1 ? '1 note' : '$notes notes'}. This can’t be undone.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok || !mounted) return;
    state.deleteCategories(list);
    _clear();
    showCemoSnack(context, '${_what(list)} deleted');
  }

  Widget _header(BuildContext context) {
    final CemoColors c = context.c;
    if (_selecting) {
      final bool allPinned = _selected.every((Category cat) => cat.pinned);
      return _SelectionHeader(
        count: _selected.length,
        onClose: _clear,
        actions: _inArchive
            ? <Widget>[
                IconButton(tooltip: 'Restore from archive', icon: const Icon(Icons.unarchive_outlined), onPressed: _unarchive),
                IconButton(tooltip: 'Delete permanently', icon: const Icon(Icons.delete_outline), onPressed: _deleteForever),
              ]
            : <Widget>[
                IconButton(
                  tooltip: allPinned ? 'Unpin' : 'Pin',
                  icon: Icon(allPinned ? Icons.push_pin : Icons.push_pin_outlined),
                  onPressed: _pin,
                ),
                IconButton(tooltip: 'Archive', icon: const Icon(Icons.archive_outlined), onPressed: _archive),
                IconButton(tooltip: 'Delete', icon: const Icon(Icons.delete_outline), onPressed: _deleteToArchive),
              ],
      );
    }
    return SizedBox(
      height: 52,
      child: Padding(
        padding: const EdgeInsets.only(left: 24, right: 16),
        child: Row(
          children: <Widget>[
            Text('Cemo', style: Tx.serifTitle(context, size: 26)),
            const Spacer(),
            OutlinedButton.icon(
              onPressed: () => showNewCategorySheet(context),
              icon: Icon(Icons.add, size: 18, color: c.t1),
              label: Text('Category', style: Tx.uiStrong(context).copyWith(fontSize: 14)),
              style: OutlinedButton.styleFrom(
                foregroundColor: c.t1,
                side: BorderSide(color: c.border),
                shape: const StadiumBorder(),
                minimumSize: const Size(0, 36),
                padding: const EdgeInsets.fromLTRB(10, 0, 14, 0),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final CemoColors c = context.c;
    final List<Category> list = _inArchive
        ? state.archivedCategories
        : state.sortedCategories.where((Category cat) => _filter == 0 || cat.pinned).toList();
    // Anything no longer in this list (archived, deleted) must not stay selected.
    _selected.removeWhere((Category cat) => !list.contains(cat));

    Widget body;
    if (state.categories.isEmpty) {
      body = EmptyState(
        scene: 9,
        imageLabel: 'Memo holding an empty notebook',
        title: 'Your notes start here.',
        text: 'Share a link from any app, or create a category to start collecting.',
        actionLabel: 'Create a category',
        onAction: () => showNewCategorySheet(context),
      );
    } else if (list.isEmpty) {
      const List<String> empty = <String>[
        'No categories here. Everything is archived.',
        'No pinned categories. Press and hold a category, then tap the pin.',
        'Nothing archived. Archived categories keep their notes and stay out of the way.',
      ];
      body = Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 36),
          child: Text(empty[_filter], textAlign: TextAlign.center, style: Tx.excerpt(context)),
        ),
      );
    } else {
      body = ListView.builder(
        padding: const EdgeInsets.only(bottom: 96),
        itemCount: list.length,
        itemBuilder: (BuildContext context, int i) {
          final Category cat = list[i];
          return _CategoryRow(
            key: ValueKey<String>(cat.id),
            category: cat,
            selected: _selected.contains(cat),
            onTap: _selecting ? () => _toggle(cat) : () => openCategory(context, cat),
            onLongPress: () => _toggle(cat),
          );
        },
      );
    }

    return PopScope(
      canPop: !(_selecting && widget.active),
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) _clear();
      },
      child: Stack(
        children: <Widget>[
          Column(
            children: <Widget>[
              _header(context),
              TopicTabs(
                labels: _filters,
                selected: _filter,
                onSelect: (int i) => setState(() {
                  _filter = i;
                  _selected.clear();
                }),
              ),
              Expanded(child: body),
            ],
          ),
          if (!_selecting && !_inArchive)
            Positioned(
              right: 16,
              bottom: 16,
              child: FloatingActionButton(
                tooltip: 'New note',
                onPressed: widget.onNewNote,
                backgroundColor: c.primaryFill,
                foregroundColor: c.primaryText,
                elevation: 0,
                focusElevation: 0,
                hoverElevation: 0,
                highlightElevation: 0,
                shape: const CircleBorder(),
                child: const Icon(Icons.edit_outlined),
              ),
            ),
        ],
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    super.key,
    required this.category,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
  });
  final Category category;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final CemoColors c = context.c;
    final Note? latest = category.latest;
    final bool unread = category.unread > 0;
    return Semantics(
      selected: selected,
      child: InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        color: selected ? c.bg2 : c.bg2.withAlpha(0),
        padding: const EdgeInsets.only(left: 24),
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 48,
              height: 48,
              child: Stack(
                clipBehavior: Clip.none,
                children: <Widget>[
                  CategoryAvatar(color: category.color, icon: category.icon, size: 48, imagePath: category.imagePath),
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: AnimatedScale(
                      scale: selected ? 1 : 0,
                      duration: const Duration(milliseconds: 160),
                      curve: Curves.easeOutBack,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: c.accent,
                          shape: BoxShape.circle,
                          border: Border.all(color: c.bg, width: 2),
                        ),
                        child: Icon(Icons.check, size: 12, color: c.bg),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                height: 76,
                padding: const EdgeInsets.only(right: 24),
                decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.divider))),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Flexible(child: Text(category.name, overflow: TextOverflow.ellipsis, style: Tx.subhead(context))),
                              if (category.pinned) ...<Widget>[
                                const SizedBox(width: 6),
                                Icon(Icons.push_pin, size: 12, color: c.t2, semanticLabel: 'Pinned'),
                              ],
                            ],
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: <Widget>[
                              if (latest != null && _previewIcon(latest.kind) != null) ...<Widget>[
                                Icon(_previewIcon(latest.kind), size: 14, color: c.t2),
                                const SizedBox(width: 6),
                              ],
                              Expanded(
                                child: Text(
                                  latest?.preview ?? 'No notes yet',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Tx.excerpt(context).copyWith(fontSize: 15, height: 22 / 15, color: unread ? c.t1 : c.t2),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: <Widget>[
                        Text(
                          latest == null ? '' : listTime(latest.time),
                          style: Tx.meta(context).copyWith(
                            color: unread ? c.accent : c.t2,
                            fontWeight: unread ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                        const SizedBox(height: 5),
                        SizedBox(
                          height: 20,
                          child: unread
                              ? Container(
                                  constraints: const BoxConstraints(minWidth: 20),
                                  padding: const EdgeInsets.symmetric(horizontal: 6),
                                  decoration: BoxDecoration(color: c.accent, borderRadius: BorderRadius.circular(10)),
                                  alignment: Alignment.center,
                                  child: Text('${category.unread}',
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.bg)),
                                )
                              : (category.hasOpenReminder
                                  ? Icon(Icons.notifications, size: 15, color: c.reminder, semanticLabel: 'Has a reminder')
                                  : null),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

// ---------- Search tab ----------

class SearchTab extends StatefulWidget {
  const SearchTab({super.key});

  @override
  State<SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends State<SearchTab> {
  final TextEditingController _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final CemoColors c = context.c;
    final String q = _query.text.trim();
    final List<Widget> results = <Widget>[];
    if (q.isNotEmpty) {
      for (final Category cat in state.sortedCategories) {
        final List<Note> hits =
            cat.notes.where((Note n) => n.searchText.toLowerCase().contains(q.toLowerCase())).toList();
        if (hits.isEmpty) continue;
        results.add(Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 4),
          child: Row(
            children: <Widget>[
              CategoryAvatar(color: cat.color, icon: cat.icon, size: 20, imagePath: cat.imagePath),
              const SizedBox(width: 8),
              Text('${cat.name} · ${hits.length} ${hits.length == 1 ? 'result' : 'results'}'.toUpperCase(),
                  style: Tx.caption(context).copyWith(letterSpacing: 0.5)),
            ],
          ),
        ));
        for (final Note n in hits) {
          results.add(InkWell(
            onTap: () => openCategory(context, cat, focus: n),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.divider))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('${dayLabel(n.time)}, ${hhmm(n.time)}', style: Tx.caption(context).copyWith(color: c.t3)),
                  const SizedBox(height: 4),
                  HighlightText(text: n.searchText.trim(), query: q, style: Tx.excerpt(context).copyWith(color: c.t1)),
                ],
              ),
            ),
          ));
        }
      }
    }

    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Container(
            height: 40,
            decoration: BoxDecoration(color: c.bg2, borderRadius: BorderRadius.circular(999)),
            padding: const EdgeInsets.only(left: 14),
            child: Row(
              children: <Widget>[
                Icon(Icons.search, size: 18, color: c.t2),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _query,
                    textInputAction: TextInputAction.search,
                    style: Tx.ui(context),
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      hintText: 'Search notes and links',
                      hintStyle: Tx.ui(context).copyWith(color: c.t3),
                    ),
                  ),
                ),
                if (q.isNotEmpty)
                  IconButton(
                    tooltip: 'Clear search',
                    icon: Icon(Icons.close, size: 16, color: c.t2),
                    onPressed: () => setState(_query.clear),
                  ),
              ],
            ),
          ),
        ),
        Divider(height: 1, color: c.divider),
        Expanded(
          child: q.isEmpty
              ? Center(child: Text('Search across every note, link and conversation.', style: Tx.excerpt(context)))
              : results.isEmpty
                  ? EmptyState(
                      scene: 11,
                      imageLabel: 'Memo looking at a blank card through a magnifying glass',
                      title: 'No notes match “$q”.',
                      text: 'Check the spelling or try a shorter word.',
                    )
                  : ListView(children: results),
        ),
      ],
    );
  }
}

// ---------- Reminders tab ----------

class RemindersTab extends StatefulWidget {
  const RemindersTab({super.key, required this.active});

  /// False while another bottom tab is showing; selection is dropped then.
  final bool active;

  @override
  State<RemindersTab> createState() => _RemindersTabState();
}

class _RemindersTabState extends State<RemindersTab> {
  int _tab = 0; // 0 upcoming, 1 overdue, 2 done
  final Set<Note> _selected = <Note>{};

  bool get _selecting => _selected.isNotEmpty;

  @override
  void didUpdateWidget(RemindersTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.active && _selected.isNotEmpty) _selected.clear();
  }

  void _toggle(Note n) {
    setState(() {
      if (!_selected.remove(n)) _selected.add(n);
    });
  }

  void _clear() => setState(_selected.clear);

  String _group(DateTime when) {
    final int diff = dayOf(when).difference(dayOf(DateTime.now())).inDays;
    if (diff < 0) return 'Earlier';
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    if (diff < 7) return 'This week';
    return 'Later';
  }

  void _markSelectedDone() {
    final AppState state = AppScope.of(context);
    final List<Note> list = _selected.toList();
    state.setRemindersDone(list, true);
    _clear();
    showCemoSnack(
      context,
      list.length == 1 ? 'Marked as done' : '${list.length} marked as done',
      actionLabel: 'Undo',
      onAction: () => state.setRemindersDone(list, false),
    );
  }

  Future<void> _deleteSelected() async {
    final AppState state = AppScope.of(context);
    final List<Note> list = _selected.toList();
    final String what = list.length == 1 ? 'this reminder' : '${list.length} reminders';
    final bool ok = await confirmDialog(
      context,
      title: _tab == 2 ? 'Delete $what permanently?' : 'Delete $what?',
      message: 'Only the reminder is removed. The note stays in its conversation.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok || !mounted) return;
    state.clearReminders(list);
    _clear();
    showCemoSnack(context, list.length == 1 ? 'Reminder deleted' : '${list.length} reminders deleted');
  }

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final List<ReminderEntry> list = state.reminders.where((ReminderEntry r) {
      if (_tab == 2) return r.note.reminderDone;
      if (r.note.reminderDone) return false;
      return _tab == 1 ? r.overdue : !r.overdue;
    }).toList();
    // Reminders that left this list must not stay selected.
    _selected.removeWhere((Note n) => !list.any((ReminderEntry r) => r.note == n));

    final List<Widget> rows = <Widget>[];
    String? lastGroup;
    for (final ReminderEntry r in list) {
      final String g = _group(r.when);
      if (g != lastGroup) {
        rows.add(Overline(g));
        lastGroup = g;
      }
      rows.add(_ReminderRow(
        key: ValueKey<String>('${r.note.id}-$_tab'),
        entry: r,
        selecting: _selecting,
        selected: _selected.contains(r.note),
        onTap: _selecting ? () => _toggle(r.note) : () => openCategory(context, r.category, focus: r.note),
        onLongPress: () => _toggle(r.note),
        onDoneChanged: (bool done) => state.setRemindersDone(<Note>[r.note], done),
      ));
    }

    const List<String> emptyTitles = <String>['All caught up.', 'Nothing overdue.', 'Nothing done yet.'];
    const List<String> emptyTexts = <String>[
      'You have no upcoming reminders. Set one from any note.',
      'Reminders that pass their time without being ticked show up here.',
      'Reminders you tick off will appear here.',
    ];

    return PopScope(
      canPop: !(_selecting && widget.active),
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) _clear();
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (_selecting)
            _SelectionHeader(
              count: _selected.length,
              onClose: _clear,
              actions: <Widget>[
                if (_tab != 2)
                  IconButton(tooltip: 'Mark as done', icon: const Icon(Icons.check), onPressed: _markSelectedDone),
                IconButton(
                  tooltip: _tab == 2 ? 'Delete permanently' : 'Delete reminder',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: _deleteSelected,
                ),
              ],
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
              child: Text('Reminders', style: Tx.display(context)),
            ),
          TopicTabs(
            labels: const <String>['Upcoming', 'Overdue', 'Done'],
            selected: _tab,
            onSelect: (int i) => setState(() {
              _tab = i;
              _selected.clear();
            }),
          ),
          Expanded(
            child: rows.isEmpty
                ? EmptyState(
                    scene: 12,
                    imageLabel: 'Memo resting beside a bell',
                    title: emptyTitles[_tab],
                    text: emptyTexts[_tab],
                  )
                : ListView(children: rows),
          ),
        ],
      ),
    );
  }
}

/// One reminder. Ticking the box draws a line through the title and fades the
/// row, and only then moves it to Done, so the change is easy to follow.
class _ReminderRow extends StatefulWidget {
  const _ReminderRow({
    super.key,
    required this.entry,
    required this.selecting,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
    required this.onDoneChanged,
  });
  final ReminderEntry entry;
  final bool selecting;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final ValueChanged<bool> onDoneChanged;

  @override
  State<_ReminderRow> createState() => _ReminderRowState();
}

class _ReminderRowState extends State<_ReminderRow> {
  bool _leaving = false;

  void _onCheck() {
    final Note note = widget.entry.note;
    if (note.reminderDone) {
      widget.onDoneChanged(false); // un-tick in Done: back to the open lists at once
    } else if (!_leaving) {
      setState(() => _leaving = true); // play the strike and fade, then move it
    }
  }

  @override
  Widget build(BuildContext context) {
    final CemoColors c = context.c;
    final ReminderEntry r = widget.entry;
    final bool done = r.note.reminderDone;
    final Color timeColor = done ? c.t2 : (r.overdue ? c.destructive : c.reminder);

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: _leaving ? 1 : 0),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
      onEnd: () {
        if (_leaving) widget.onDoneChanged(true);
      },
      builder: (BuildContext context, double v, Widget? child) {
        final Widget title = Stack(
          alignment: Alignment.centerLeft,
          children: <Widget>[
            Text(
              r.note.preview,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Tx.subhead(context).copyWith(
                color: (done || _leaving) ? c.t2 : c.t1,
                decoration: done ? TextDecoration.lineThrough : TextDecoration.none,
              ),
            ),
            if (!done && v > 0)
              Positioned.fill(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(widthFactor: v, child: Container(height: 1.5, color: c.t2)),
                ),
              ),
          ],
        );
        return Opacity(
          opacity: 1 - 0.8 * v,
          child: Semantics(
            selected: widget.selected,
            child: InkWell(
              onTap: widget.onTap,
              onLongPress: widget.onLongPress,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                color: widget.selected ? c.bg2 : c.bg2.withAlpha(0),
                padding: const EdgeInsets.only(left: 4, right: 16),
                child: Row(
                  children: <Widget>[
                    IgnorePointer(
                      ignoring: widget.selecting,
                      child: Checkbox(
                        value: done || _leaving,
                        activeColor: c.accent,
                        onChanged: (_) => _onCheck(),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            title,
                            const SizedBox(height: 4),
                            Row(
                              children: <Widget>[
                                CategoryAvatar(color: r.category.color, icon: r.category.icon, size: 16, imagePath: r.category.imagePath),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(r.category.name, overflow: TextOverflow.ellipsis, style: Tx.meta(context)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      (!done && r.overdue) ? 'Overdue · ${reminderLabel(r.when)}' : reminderLabel(r.when),
                      style: Tx.meta(context).copyWith(color: timeColor, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ---------- Profile tab ----------

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final CemoColors c = context.c;
    Widget mode(ThemeMode m, String label) {
      final bool on = state.themeMode == m;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: PillButton(
          label: label,
          kind: on ? PillKind.primary : PillKind.secondary,
          expand: false,
          height: 40,
          onPressed: () => state.setThemeMode(m),
        ),
      );
    }

    Widget row(IconData icon, String label, VoidCallback onTap, {Color? color}) {
      return ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 24),
        leading: Icon(icon, color: color ?? c.t1, size: 22),
        title: Text(label, style: Tx.ui(context).copyWith(color: color ?? c.t1)),
        trailing: Icon(Icons.chevron_right, color: c.t2, size: 20),
        onTap: onTap,
      );
    }

    return ListView(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
          child: Text('Profile', style: Tx.display(context)),
        ),
        const Overline('Appearance', padding: EdgeInsets.fromLTRB(24, 16, 24, 8)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: <Widget>[
              mode(ThemeMode.system, 'System'),
              mode(ThemeMode.light, 'Light'),
              mode(ThemeMode.dark, 'Dark'),
            ],
          ),
        ),
        const Overline('More', padding: EdgeInsets.fromLTRB(24, 24, 24, 0)),
        row(Icons.chat_bubble_outline, 'Send feedback', () {
          Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const FeedbackScreen()));
        }),
        row(Icons.replay, 'Replay onboarding', state.replayOnboarding),
        row(Icons.logout, 'Log out', state.signOut, color: c.destructive),
      ],
    );
  }
}

/// Small icon in front of a list preview, for notes that are not plain text.
IconData? _previewIcon(NoteKind kind) {
  switch (kind) {
    case NoteKind.link:
      return Icons.link;
    case NoteKind.image:
      return Icons.photo_outlined;
    case NoteKind.video:
      return Icons.videocam_outlined;
    case NoteKind.document:
      return Icons.insert_drive_file_outlined;
    case NoteKind.text:
    case NoteKind.checklist:
      return null;
  }
}

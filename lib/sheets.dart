import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import 'models.dart';
import 'storage.dart';
import 'theme.dart';
import 'widgets.dart';

int _snackSeq = 0;

/// Short message at the bottom. It always leaves by itself after 2 seconds,
/// including when it has an action button.
void showCemoSnack(BuildContext context, String message, {String? actionLabel, VoidCallback? onAction}) {
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  final int seq = ++_snackSeq;
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(SnackBar(
    content: Text(message),
    duration: const Duration(seconds: 2),
    action: actionLabel == null ? null : SnackBarAction(label: actionLabel, onPressed: onAction ?? () {}),
  ));
  // Newer Flutter versions keep a snackbar with an action on screen until it is
  // tapped, so close it explicitly unless a newer message has replaced it.
  Timer(const Duration(seconds: 2), () {
    if (seq == _snackSeq && messenger.mounted) messenger.hideCurrentSnackBar();
  });
}

/// Opens a web address in the browser, or in the app that handles it
/// (YouTube, Maps and so on).
Future<void> openLink(BuildContext context, String? address) async {
  final Uri? uri = address == null ? null : Uri.tryParse(address.trim());
  if (uri == null || !uri.hasScheme) {
    showCemoSnack(context, 'This link can’t be opened.');
    return;
  }
  bool opened = false;
  try {
    opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    opened = false;
  }
  if (!opened && context.mounted) showCemoSnack(context, 'Couldn’t open the link.');
}

/// Asks "are you sure?" and returns true only when the confirm button is tapped.
Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool destructive = false,
}) async {
  final bool? ok = await showDialog<bool>(
    context: context,
    builder: (BuildContext context) {
      final CemoColors c = context.c;
      return AlertDialog(
        backgroundColor: c.elevated,
        surfaceTintColor: Colors.transparent,
        title: Text(title, style: Tx.subhead(context)),
        content: Text(message, style: Tx.ui(context).copyWith(color: c.t2)),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel', style: Tx.ui(context).copyWith(color: c.t2)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(confirmLabel, style: Tx.uiStrong(context).copyWith(color: destructive ? c.destructive : c.t1)),
          ),
        ],
      );
    },
  );
  return ok ?? false;
}

/// Sets a reminder and shows the "Reminder set · Undo" snackbar.
void setReminderWithUndo(BuildContext context, Note note, DateTime when) {
  final AppState state = AppScope.of(context);
  final DateTime? previous = note.reminder;
  state.setReminder(note, when);
  showCemoSnack(
    context,
    'Reminder set for ${reminderLabel(when)}',
    actionLabel: 'Undo',
    onAction: () => state.setReminder(note, previous),
  );
}

// ---------- shared sheet header ----------

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Text(title, style: Tx.subhead(context)),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel', style: Tx.ui(context).copyWith(color: context.c.t2)),
            ),
          ),
        ],
      ),
    );
  }
}

Widget _sheetBody(BuildContext context, {required List<Widget> children, Widget? footer}) {
  final double maxH = MediaQuery.sizeOf(context).height * 0.88;
  return Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxH),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Flexible(
              child: ListView(shrinkWrap: true, padding: EdgeInsets.zero, children: children),
            ),
            if (footer != null)
              Container(
                decoration: BoxDecoration(border: Border(top: BorderSide(color: context.c.divider))),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: footer,
              ),
          ],
        ),
      ),
    ),
  );
}

// ---------- reminder sheet ----------

Future<DateTime?> showReminderSheet(BuildContext context, {Note? note}) {
  return showModalBottomSheet<DateTime>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (BuildContext context) => _ReminderSheet(note: note),
  );
}

DateTime _defaultReminder() {
  final DateTime tomorrow = dayOf(DateTime.now()).add(const Duration(days: 1));
  return tomorrow.add(const Duration(hours: 9));
}

class _ReminderSheet extends StatefulWidget {
  const _ReminderSheet({this.note});
  final Note? note;

  @override
  State<_ReminderSheet> createState() => _ReminderSheetState();
}

class _ReminderSheetState extends State<_ReminderSheet> {
  late DateTime _when = widget.note?.reminder ?? _defaultReminder();

  Future<void> _pickDate() async {
    final DateTime now = DateTime.now();
    final DateTime? d = await showDatePicker(
      context: context,
      initialDate: _when.isBefore(now) ? now : _when,
      firstDate: dayOf(now),
      lastDate: dayOf(now).add(const Duration(days: 365 * 3)),
    );
    if (d == null) return;
    setState(() => _when = DateTime(d.year, d.month, d.day, _when.hour, _when.minute));
  }

  Future<void> _pickTime() async {
    final TimeOfDay? t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_when));
    if (t == null) return;
    setState(() => _when = DateTime(_when.year, _when.month, _when.day, t.hour, t.minute));
  }

  @override
  Widget build(BuildContext context) {
    final CemoColors c = context.c;
    final Note? note = widget.note;
    final bool past = _when.isBefore(DateTime.now());
    return _sheetBody(
      context,
      footer: PillButton(label: 'Set reminder', onPressed: past ? null : () => Navigator.of(context).pop(_when)),
      children: <Widget>[
        const _SheetHeader(title: 'Remind me'),
        if (note != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Text(note.preview, maxLines: 2, overflow: TextOverflow.ellipsis, style: Tx.subhead(context)),
          ),
        Divider(height: 1, color: c.divider),
        _row(context, icon: Icons.calendar_today_outlined, label: 'Date', trailing: dayLabel(_when), onTap: _pickDate),
        _row(context, icon: Icons.schedule, label: 'Time', trailing: hhmm(_when), onTap: _pickTime),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Text(
            past ? 'Pick a time in the future.' : 'You’ll get a notification at ${reminderLabel(_when)}.',
            style: Tx.meta(context).copyWith(color: past ? c.destructive : c.t2),
          ),
        ),
      ],
    );
  }

  Widget _row(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String trailing,
    required VoidCallback onTap,
  }) {
    final CemoColors c = context.c;
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 52,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: <Widget>[
              Icon(icon, size: 20, color: c.t2),
              const SizedBox(width: 14),
              Expanded(child: Text(label, style: Tx.ui(context))),
              Text(trailing, style: Tx.uiStrong(context)),
              const SizedBox(width: 6),
              Icon(Icons.chevron_right, size: 18, color: c.t2),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------- choose a category (Save to, Forward to) ----------

/// A scrollable list of conversations in a bottom sheet. It never grows past
/// 70% of the screen height, so a long list scrolls inside the sheet.
Future<Category?> pickCategory(BuildContext context, {required String title, Category? exclude}) {
  final AppState state = AppScope.of(context);
  final List<Category> list = state.sortedCategories.where((Category c) => c != exclude).toList();
  return showModalBottomSheet<Category>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (BuildContext context) {
      final CemoColors c = context.c;
      return SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.7),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _SheetHeader(title: title),
              Divider(height: 1, color: c.divider),
              Flexible(
                child: list.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text('No other categories yet.', style: Tx.excerpt(context)),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: list.length,
                        itemBuilder: (BuildContext context, int i) {
                          final Category cat = list[i];
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                            leading: CategoryAvatar(color: cat.color, icon: cat.icon, size: 36, imagePath: cat.imagePath),
                            title: Text(cat.name, style: Tx.ui(context), maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: Text('${cat.notes.length} notes', style: Tx.meta(context)),
                            onTap: () => Navigator.of(context).pop(cat),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

// ---------- new category / edit category ----------

/// New category sheet. Returns the category that was created.
Future<Category?> showNewCategorySheet(BuildContext context) => showCategorySheet(context);

/// The same sheet edits [existing] when it is given.
Future<Category?> showCategorySheet(BuildContext context, {Category? existing}) {
  return showModalBottomSheet<Category>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (BuildContext context) => _CategorySheet(existing: existing),
  );
}

class _CategorySheet extends StatefulWidget {
  const _CategorySheet({this.existing});
  final Category? existing;

  @override
  State<_CategorySheet> createState() => _CategorySheetState();
}

class _CategorySheetState extends State<_CategorySheet> {
  late final TextEditingController _name = TextEditingController(text: widget.existing?.name ?? '');
  late int _color = _indexOr(kAvatarColors.indexOf(widget.existing?.color ?? kAvatarColors[3]), 3);
  late int _icon = _indexOr(kCategoryIcons.indexOf(widget.existing?.icon ?? kCategoryIcons[0]), 0);

  /// Photo already saved for this category (relative path), if it is kept.
  late String? _savedImage = widget.existing?.imagePath;

  /// Photo just picked from the gallery (absolute path), not copied yet.
  String? _pickedImage;
  bool _busy = false;

  static int _indexOr(int index, int fallback) => index < 0 ? fallback : index;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _choosePhoto() async {
    try {
      final XFile? file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      if (file != null && mounted) setState(() => _pickedImage = file.path);
    } catch (_) {
      if (mounted) showCemoSnack(context, 'Couldn’t open your photos.');
    }
  }

  void _removePhoto() => setState(() {
        _pickedImage = null;
        _savedImage = null;
      });

  Future<void> _save() async {
    final AppState state = AppScope.of(context);
    final Category? existing = widget.existing;
    if (_busy || state.nameTaken(_name.text, except: existing)) return;
    setState(() => _busy = true);
    final Category c = existing ?? state.addCategory(_name.text, kAvatarColors[_color], kCategoryIcons[_icon]);
    String? image = _savedImage;
    final String? picked = _pickedImage;
    if (picked != null) {
      try {
        image = await Storage.saveCategoryImage(picked, c.id); // a copy, kept in app storage
      } catch (_) {
        image = _savedImage;
      }
    }
    // A photo that was replaced or removed is no longer needed on disk.
    if (existing?.imagePath != null && existing!.imagePath != image) {
      Storage.deleteRelative(existing.imagePath);
    }
    state.updateCategory(c, name: _name.text, color: kAvatarColors[_color], icon: kCategoryIcons[_icon], imagePath: image);
    if (mounted) Navigator.of(context).pop(c);
  }

  @override
  Widget build(BuildContext context) {
    final CemoColors c = context.c;
    final bool editing = widget.existing != null;
    final bool taken = AppScope.of(context).nameTaken(_name.text, except: widget.existing);
    final bool hasPhoto = _pickedImage != null || _savedImage != null;
    final Widget preview = _pickedImage != null
        ? ClipOval(child: Image.file(File(_pickedImage!), width: 56, height: 56, fit: BoxFit.cover))
        : CategoryAvatar(color: kAvatarColors[_color], icon: kCategoryIcons[_icon], size: 56, imagePath: _savedImage);
    return _sheetBody(
      context,
      footer: PillButton(
        label: editing ? 'Save' : 'Create',
        onPressed: _name.text.trim().isEmpty || taken || _busy ? null : _save,
      ),
      children: <Widget>[
        _SheetHeader(title: editing ? 'Edit category' : 'New category'),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: <Widget>[
              preview,
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _name,
                  autofocus: !editing,
                  textCapitalization: TextCapitalization.sentences,
                  style: Tx.title(context),
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Name',
                    errorText: taken ? 'A category with this name already exists.' : null,
                    errorStyle: Tx.meta(context).copyWith(color: c.destructive),
                    errorBorder: UnderlineInputBorder(borderSide: BorderSide(color: c.destructive)),
                    focusedErrorBorder: UnderlineInputBorder(borderSide: BorderSide(color: c.destructive)),
                    hintStyle: Tx.title(context).copyWith(color: c.t3),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: c.border)),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: c.t1)),
                  ),
                ),
              ),
            ],
          ),
        ),
        const Overline('Icon'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: <Widget>[
              PillButton(
                label: hasPhoto ? 'Change photo' : 'Use a photo',
                kind: PillKind.secondary,
                expand: false,
                height: 40,
                onPressed: _choosePhoto,
              ),
              if (hasPhoto) ...<Widget>[
                const SizedBox(width: 8),
                PillButton(label: 'Remove photo', kind: PillKind.text, expand: false, height: 40, onPressed: _removePhoto),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Text(
            hasPhoto
                ? 'The photo is copied into Cemo and used as the icon. Remove it to use a colour and symbol.'
                : 'Or pick a colour and a symbol below.',
            style: Tx.meta(context),
          ),
        ),
        const Overline('Colour'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              for (int i = 0; i < kAvatarColors.length; i++)
                Semantics(
                  button: true,
                  selected: i == _color,
                  label: 'Colour ${i + 1}',
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(() => _color = i),
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: Center(
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: i == _color ? c.t1 : Colors.transparent, width: 2),
                          ),
                          padding: const EdgeInsets.all(2),
                          child: DecoratedBox(
                            decoration: BoxDecoration(color: kAvatarColors[i], shape: BoxShape.circle),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const Overline('Symbol'),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.5,
            children: <Widget>[
              for (int i = 0; i < kCategoryIcons.length; i++)
                Semantics(
                  button: true,
                  selected: i == _icon,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(() => _icon = i),
                    child: Center(
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i == _icon ? c.t1 : Colors.transparent,
                          border: Border.all(color: i == _icon ? c.t1 : c.border),
                        ),
                        child: Icon(kCategoryIcons[i], size: 22, color: i == _icon ? c.bg : c.t1),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------- new note ----------

/// Opens the New note sheet. Returns the category the note was saved to.
Future<Category?> showNewNoteSheet(BuildContext context, {Category? initial}) {
  return showModalBottomSheet<Category>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (BuildContext context) => _NewNoteSheet(initial: initial),
  );
}

class _NewNoteSheet extends StatefulWidget {
  const _NewNoteSheet({this.initial});
  final Category? initial;

  @override
  State<_NewNoteSheet> createState() => _NewNoteSheetState();
}

class _NewNoteSheetState extends State<_NewNoteSheet> {
  final TextEditingController _text = TextEditingController();
  Category? _category;
  DateTime? _reminder;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final List<Category> all = AppScope.of(context).sortedCategories;
    _category ??= widget.initial ?? (all.isEmpty ? null : all.first);
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _choose() async {
    final Category? picked = await pickCategory(context, title: 'Save to');
    if (picked != null) setState(() => _category = picked);
  }

  Future<void> _remind() async {
    final DateTime? when = await showReminderSheet(context);
    if (when != null) setState(() => _reminder = when);
  }

  void _save() {
    final Category c = _category!;
    AppScope.of(context).addNote(c, _text.text, reminder: _reminder);
    Navigator.of(context).pop(c);
  }

  @override
  Widget build(BuildContext context) {
    final CemoColors c = context.c;
    final Category? cat = _category;
    final bool canSave = cat != null && _text.text.trim().isNotEmpty;
    return _sheetBody(
      context,
      footer: PillButton(label: 'Save note', onPressed: canSave ? _save : null),
      children: <Widget>[
        const _SheetHeader(title: 'New note'),
        InkWell(
          onTap: _choose,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: <Widget>[
                Text('Save to', style: Tx.meta(context)),
                const SizedBox(width: 12),
                if (cat != null) CategoryAvatar(color: cat.color, icon: cat.icon, size: 28, imagePath: cat.imagePath),
                const SizedBox(width: 10),
                Expanded(child: Text(cat?.name ?? 'Create a category first', style: Tx.ui(context))),
                Icon(Icons.chevron_right, color: c.t2),
              ],
            ),
          ),
        ),
        Divider(height: 1, color: c.divider),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
          child: TextField(
            controller: _text,
            autofocus: true,
            minLines: 4,
            maxLines: 8,
            textCapitalization: TextCapitalization.sentences,
            style: Tx.bodySerif(context),
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: 'Write a note or paste a link…',
              hintStyle: Tx.bodySerif(context).copyWith(color: c.t3),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 16, 8),
          child: Row(
            children: <Widget>[
              IconButton(
                tooltip: 'Add reminder',
                onPressed: _remind,
                icon: Icon(_reminder == null ? Icons.notifications_none : Icons.notifications,
                    color: _reminder == null ? c.t2 : c.reminder),
              ),
              if (_reminder != null) ReminderChip(when: _reminder!),
            ],
          ),
        ),
      ],
    );
  }
}

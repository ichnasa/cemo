import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import 'icons.dart';
import 'models.dart';
import 'storage.dart';
import 'theme.dart';
import 'widgets.dart';

FToasterEntry? _lastToast;

/// Short message at the bottom (an [FToast]). It always leaves by itself after
/// 2 seconds, including when it has an action button, and replaces any message
/// still on screen.
void showCemoSnack(BuildContext context, String message, {String? actionLabel, VoidCallback? onAction}) {
  final FToasterEntry? previous = _lastToast;
  if (previous != null && previous.showing) previous.dismiss();
  _lastToast = showFToast(
    context: context,
    title: Text(message),
    duration: const Duration(seconds: 2),
    suffixBuilder: actionLabel == null
        ? null
        : (BuildContext context, FToasterEntry entry) => FButton(
              variant: FButtonVariant.ghost,
              size: FButtonSizeVariant.sm,
              mainAxisSize: MainAxisSize.min,
              onPress: () {
                entry.dismiss();
                onAction?.call();
              },
              child: Text(actionLabel, style: TextStyle(color: context.c.accent)),
            ),
  );
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
  final bool? ok = await showFDialog<bool>(
    context: context,
    builder: (BuildContext context, FDialogStyle style, Animation<double> animation) => FDialog(
      style: const FDialogStyleDelta.context(),
      animation: animation,
      semanticsLabel: title,
      builder: (BuildContext context, FDialogStyle style) => Padding(
        padding: const EdgeInsets.all(Space.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(title, style: Tx.subhead(context)),
            const SizedBox(height: Space.sm),
            Text(message, style: Tx.ui(context).copyWith(color: context.c.t2)),
            const SizedBox(height: Space.xl),
            FButton(
              variant: destructive ? FButtonVariant.destructive : FButtonVariant.primary,
              onPress: () => Navigator.of(context).pop(true),
              child: Text(confirmLabel),
            ),
            const SizedBox(height: Space.sm),
            FButton(
              variant: FButtonVariant.outline,
              onPress: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    ),
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

// ---------- shared sheet frame and header ----------

/// Opens [builder] in a Forui bottom sheet with the Cemo sheet surface and a
/// drag handle. Each sheet limits its own height.
Future<T?> showCemoSheet<T>(BuildContext context, WidgetBuilder builder) {
  return showFSheet<T>(
    context: context,
    side: FLayout.btt,
    mainAxisMaxRatio: null,
    resizeToAvoidBottomInset: false,
    builder: (BuildContext context) => _SheetFrame(child: builder(context)),
  );
}

class _SheetFrame extends StatelessWidget {
  const _SheetFrame({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final CemoColors c = context.c;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.elevated,
        border: Border(top: BorderSide(color: c.border)),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(Space.lg)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: Space.md),
            child: Container(
              width: 32,
              height: 4,
              decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          Flexible(child: child),
        ],
      ),
    );
  }
}

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
            child: FButton(
              variant: FButtonVariant.ghost,
              mainAxisSize: MainAxisSize.min,
              onPress: () => Navigator.of(context).pop(),
              child: Text('Cancel', style: TextStyle(color: context.c.t2)),
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
  return showCemoSheet<DateTime>(context, (BuildContext context) => _ReminderSheet(note: note));
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
        const Hairline(),
        _row(context, icon: FLucideIcons.calendar, label: 'Date', trailing: dayLabel(_when), onTap: _pickDate),
        _row(context, icon: FLucideIcons.clock, label: 'Time', trailing: hhmm(_when), onTap: _pickTime),
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
    return FItem(
      prefix: Icon(icon, size: 20, color: c.t2),
      title: Text(label, style: Tx.ui(context)),
      details: Text(trailing, style: Tx.uiStrong(context)),
      suffix: Icon(FLucideIcons.chevronRight, size: 18, color: c.t2),
      onPress: onTap,
    );
  }
}

// ---------- choose a category (Save to, Forward to) ----------

/// A scrollable list of conversations in a bottom sheet. It never grows past
/// 70% of the screen height, so a long list scrolls inside the sheet.
Future<Category?> pickCategory(BuildContext context, {required String title, Category? exclude}) {
  final AppState state = AppScope.of(context);
  final List<Category> list = state.sortedCategories.where((Category c) => c != exclude).toList();
  return showCemoSheet<Category>(
    context,
    (BuildContext context) {
      return SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.7),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _SheetHeader(title: title),
              const Hairline(),
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
                          return FItem(
                            prefix: CategoryAvatar(color: cat.color, icon: cat.icon, size: 36, imagePath: cat.imagePath),
                            title: Text(cat.name, style: Tx.ui(context), maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: Text('${cat.notes.length} notes', style: Tx.meta(context)),
                            onPress: () => Navigator.of(context).pop(cat),
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
  return showCemoSheet<Category>(context, (BuildContext context) => _CategorySheet(existing: existing));
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
                child: FTextField(
                  control: FTextFieldControl.managed(controller: _name, onChange: (_) => setState(() {})),
                  autofocus: !editing,
                  textCapitalization: TextCapitalization.sentences,
                  hint: 'Name',
                  error: taken ? const Text('A category with this name already exists.') : null,
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
                        child: Icon(kCategoryLucideIcons[i], size: 22, color: i == _icon ? c.bg : c.t1),
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
  return showCemoSheet<Category>(context, (BuildContext context) => _NewNoteSheet(initial: initial));
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
        FItem(
          prefix: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text('Save to', style: Tx.meta(context)),
              if (cat != null) ...<Widget>[
                const SizedBox(width: Space.md),
                CategoryAvatar(color: cat.color, icon: cat.icon, size: 28, imagePath: cat.imagePath),
              ],
            ],
          ),
          title: Text(cat?.name ?? 'Create a category first', style: Tx.ui(context)),
          suffix: Icon(FLucideIcons.chevronRight, color: c.t2),
          onPress: _choose,
        ),
        const Hairline(),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
          child: FTextField(
            control: FTextFieldControl.managed(controller: _text, onChange: (_) => setState(() {})),
            autofocus: true,
            minLines: 4,
            maxLines: 8,
            textCapitalization: TextCapitalization.sentences,
            hint: 'Write a note or paste a link…',
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 16, 8),
          child: Row(
            children: <Widget>[
              FButton.icon(
                variant: FButtonVariant.ghost,
                semanticsLabel: 'Add reminder',
                onPress: _remind,
                child: Icon(_reminder == null ? FLucideIcons.bell : FLucideIcons.bellRing,
                    color: _reminder == null ? c.t2 : c.reminder),
              ),
              const SizedBox(width: Space.sm),
              if (_reminder != null) ReminderChip(when: _reminder!),
            ],
          ),
        ),
      ],
    );
  }
}


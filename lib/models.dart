import 'dart:async';

import 'package:flutter/material.dart';

import 'storage.dart';

// ---------- date helpers (no intl dependency) ----------

String _two(int n) => n.toString().padLeft(2, '0');
String hhmm(DateTime d) => '${_two(d.hour)}:${_two(d.minute)}';

const List<String> _weekdays = <String>['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const List<String> _months = <String>[
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
];

DateTime dayOf(DateTime d) => DateTime(d.year, d.month, d.day);
bool sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

/// "Today", "Yesterday", "Tomorrow", a weekday within a week, else "4 Nov".
String dayLabel(DateTime d) {
  final int diff = dayOf(d).difference(dayOf(DateTime.now())).inDays;
  if (diff == 0) return 'Today';
  if (diff == -1) return 'Yesterday';
  if (diff == 1) return 'Tomorrow';
  if (diff.abs() < 7) return _weekdays[d.weekday - 1];
  return '${d.day} ${_months[d.month - 1]}';
}

/// Time for list rows: the clock time today, otherwise the day.
String listTime(DateTime d) => sameDay(d, DateTime.now()) ? hhmm(d) : dayLabel(d);

/// "Sat 10:00", "Today 17:30".
String reminderLabel(DateTime d) => '${dayLabel(d)} ${hhmm(d)}';

// ---------- models ----------

enum NoteKind { text, link, checklist, image, video, document }

/// "840 KB", "2.4 MB".
String fileSizeLabel(int? bytes) {
  if (bytes == null || bytes <= 0) return '';
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} KB';
  if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
}

class CheckItem {
  CheckItem(this.text, {this.done = false});
  final String text;
  bool done;

  Map<String, dynamic> toJson() => <String, dynamic>{'text': text, 'done': done};
  static CheckItem fromJson(Map<String, dynamic> j) => CheckItem(j['text'] as String? ?? '', done: j['done'] == true);
}

class Note {
  Note({
    required this.id,
    required this.kind,
    required this.time,
    this.text = '',
    this.linkTitle,
    this.linkDomain,
    this.url,
    this.filePath,
    this.fileName,
    this.fileSize,
    List<CheckItem>? items,
    this.starred = false,
    this.reminder,
    this.reminderDone = false,
  }) : items = items ?? <CheckItem>[];

  final String id;
  final NoteKind kind;
  final DateTime time;
  final String text;
  final String? linkTitle;
  final String? linkDomain;

  /// Full web address for link notes.
  final String? url;

  /// Photo, video and document notes: the app's own copy of the file, as a
  /// path relative to the app's storage folder (see Storage.resolve).
  final String? filePath;

  /// The file's original name, shown on document notes.
  final String? fileName;
  final int? fileSize;
  final List<CheckItem> items;
  bool starred;
  DateTime? reminder;
  bool reminderDone;

  /// The address to open when a link note is tapped.
  bool get isMedia => kind == NoteKind.image || kind == NoteKind.video;

  String? get link => url ?? (linkDomain == null ? null : 'https://$linkDomain');

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'kind': kind.name,
        'time': time.toIso8601String(),
        'text': text,
        if (linkTitle != null) 'linkTitle': linkTitle,
        if (linkDomain != null) 'linkDomain': linkDomain,
        if (url != null) 'url': url,
        if (filePath != null) 'filePath': filePath,
        if (fileName != null) 'fileName': fileName,
        if (fileSize != null) 'fileSize': fileSize,
        if (items.isNotEmpty) 'items': items.map((CheckItem i) => i.toJson()).toList(),
        'starred': starred,
        if (reminder != null) 'reminder': reminder!.toIso8601String(),
        'reminderDone': reminderDone,
      };

  static Note fromJson(Map<String, dynamic> j) => Note(
        id: j['id'] as String,
        kind: NoteKind.values.firstWhere((NoteKind k) => k.name == j['kind'], orElse: () => NoteKind.text),
        time: DateTime.tryParse(j['time'] as String? ?? '') ?? DateTime.now(),
        text: j['text'] as String? ?? '',
        linkTitle: j['linkTitle'] as String?,
        linkDomain: j['linkDomain'] as String?,
        url: j['url'] as String?,
        filePath: j['filePath'] as String?,
        fileName: j['fileName'] as String?,
        fileSize: (j['fileSize'] as num?)?.toInt(),
        items: (j['items'] as List<dynamic>? ?? <dynamic>[])
            .map((dynamic e) => CheckItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        starred: j['starred'] == true,
        reminder: j['reminder'] == null ? null : DateTime.tryParse(j['reminder'] as String),
        reminderDone: j['reminderDone'] == true,
      );

  /// One line for list rows and bars.
  String get preview {
    switch (kind) {
      case NoteKind.link:
        return linkTitle ?? text;
      case NoteKind.checklist:
        final int done = items.where((CheckItem i) => i.done).length;
        return 'Checklist · $done of ${items.length}';
      case NoteKind.text:
        return text;
      case NoteKind.image:
        return text.isNotEmpty ? text : 'Photo';
      case NoteKind.video:
        return text.isNotEmpty ? text : 'Video';
      case NoteKind.document:
        return fileName ?? 'Document';
    }
  }

  /// Everything searchable in this note.
  String get searchText =>
      <String>[text, linkTitle ?? '', linkDomain ?? '', fileName ?? '', ...items.map((CheckItem i) => i.text)].join(' ');
}

class Category {
  Category({
    required this.id,
    required this.name,
    required this.color,
    required this.icon,
    this.pinned = false,
    this.archived = false,
    this.unread = 0,
    this.imagePath,
    List<Note>? notes,
  }) : notes = notes ?? <Note>[];

  final String id;
  String name;
  Color color;
  IconData icon;
  bool pinned;
  bool archived;
  int unread;

  /// Photo used as the icon, relative to the app's storage folder. Null = use [icon].
  String? imagePath;
  final List<Note> notes;

  Note? get latest => notes.isEmpty ? null : notes.last;

  /// Colour and symbol are saved as positions in [kAvatarColors] and
  /// [kCategoryIcons], so the built-in icons keep working in release builds.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'color': kAvatarColors.indexOf(color),
        'icon': kCategoryIcons.indexOf(icon),
        'pinned': pinned,
        'archived': archived,
        'unread': unread,
        if (imagePath != null) 'imagePath': imagePath,
        'notes': notes.map((Note n) => n.toJson()).toList(),
      };

  static Category fromJson(Map<String, dynamic> j) {
    final int color = j['color'] is int ? j['color'] as int : 0;
    final int icon = j['icon'] is int ? j['icon'] as int : 7;
    return Category(
      id: j['id'] as String,
      name: j['name'] as String? ?? 'Untitled',
      color: kAvatarColors[(color < 0 || color >= kAvatarColors.length) ? 0 : color],
      icon: kCategoryIcons[(icon < 0 || icon >= kCategoryIcons.length) ? 7 : icon],
      pinned: j['pinned'] == true,
      archived: j['archived'] == true,
      unread: j['unread'] is int ? j['unread'] as int : 0,
      imagePath: j['imagePath'] as String?,
      notes: (j['notes'] as List<dynamic>? ?? <dynamic>[])
          .map((dynamic e) => Note.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
  bool get hasLinks => notes.any((Note n) => n.kind == NoteKind.link);
  bool get hasOpenReminder => notes.any((Note n) => n.reminder != null && !n.reminderDone);
}

class ReminderEntry {
  ReminderEntry(this.category, this.note);
  final Category category;
  final Note note;
  DateTime get when => note.reminder!;
  bool get overdue => !note.reminderDone && when.isBefore(DateTime.now());
}

/// The muted avatar tones from the design.
const List<Color> kAvatarColors = <Color>[
  Color(0xFF5B6B7A), // slate
  Color(0xFF6B8F71), // sage
  Color(0xFFB07156), // clay
  Color(0xFF7A5C80), // plum
  Color(0xFFB8963E), // ochre
  Color(0xFF4F8A8B), // teal
];

const List<IconData> kCategoryIcons = <IconData>[
  Icons.menu_book_outlined,
  Icons.work_outline,
  Icons.lightbulb_outline,
  Icons.shopping_cart_outlined,
  Icons.school_outlined,
  Icons.restaurant_outlined,
  Icons.flight_outlined,
  Icons.folder_outlined,
  Icons.link,
  Icons.bookmark_border,
  Icons.push_pin_outlined,
  Icons.notifications_none,
  Icons.schedule,
  Icons.calendar_today_outlined,
  Icons.mic_none,
  Icons.notes,
];

// ---------- app state ----------

/// All app data, kept in memory. Replace with a database or backend later.
class AppState extends ChangeNotifier {
  /// [seed] fills the app with sample content. The running app passes
  /// `seed: false` and calls [load], which restores what was saved on the
  /// device and only falls back to the sample content on the very first run.
  AppState({bool seed = true}) {
    if (seed) _seed();
  }

  final List<Category> categories = <Category>[];
  ThemeMode themeMode = ThemeMode.system;
  bool onboarded = false;
  bool signedIn = false;
  int _counter = 0;
  bool _persist = false;
  Timer? _saveTimer;

  String _nextId() => 'id${_counter++}';

  // --- saving on the device ---

  /// Restores saved data. Call once before the app starts.
  Future<void> load() async {
    await Storage.init();
    final Map<String, dynamic>? data = await Storage.read();
    if (data == null) {
      _seed();
    } else {
      try {
        _counter = data['counter'] is int ? data['counter'] as int : 0;
        onboarded = data['onboarded'] == true;
        signedIn = data['signedIn'] == true;
        themeMode = ThemeMode.values.firstWhere(
          (ThemeMode m) => m.name == data['themeMode'],
          orElse: () => ThemeMode.system,
        );
        categories
          ..clear()
          ..addAll((data['categories'] as List<dynamic>? ?? <dynamic>[])
              .map((dynamic e) => Category.fromJson(e as Map<String, dynamic>)));
      } catch (_) {
        categories.clear();
        _seed(); // saved data could not be understood: start with the samples
      }
    }
    _persist = true;
  }

  Map<String, dynamic> _toJson() => <String, dynamic>{
        'version': 1,
        'counter': _counter,
        'onboarded': onboarded,
        'signedIn': signedIn,
        'themeMode': themeMode.name,
        'categories': categories.map((Category c) => c.toJson()).toList(),
      };

  /// Every change goes through notifyListeners, so saving hooks in here.
  /// Changes made close together are written once, shortly after the last one.
  @override
  void notifyListeners() {
    super.notifyListeners();
    if (!_persist) return;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 400), () {
      Storage.write(_toJson()).catchError((Object _) {});
    });
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    super.dispose();
  }

  // --- session ---
  void finishOnboarding() {
    onboarded = true;
    notifyListeners();
  }

  void signIn() {
    signedIn = true;
    notifyListeners();
  }

  void signOut() {
    signedIn = false;
    notifyListeners();
  }

  void replayOnboarding() {
    onboarded = false;
    signedIn = false;
    notifyListeners();
  }

  void setThemeMode(ThemeMode mode) {
    themeMode = mode;
    notifyListeners();
  }

  // --- categories ---
  static int _byRecent(Category a, Category b) {
    if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
    final DateTime at = a.latest?.time ?? DateTime(2000);
    final DateTime bt = b.latest?.time ?? DateTime(2000);
    return bt.compareTo(at);
  }

  /// Conversations shown in the app (archived ones are left out).
  List<Category> get sortedCategories =>
      categories.where((Category c) => !c.archived).toList()..sort(_byRecent);

  List<Category> get archivedCategories =>
      categories.where((Category c) => c.archived).toList()..sort(_byRecent);

  /// True when another category already uses this name (ignoring case and outer spaces).
  bool nameTaken(String name, {Category? except}) {
    final String wanted = name.trim().toLowerCase();
    if (wanted.isEmpty) return false;
    return categories.any((Category c) => c != except && c.name.trim().toLowerCase() == wanted);
  }

  Category addCategory(String name, Color color, IconData icon) {
    final Category c = Category(id: _nextId(), name: name.trim(), color: color, icon: icon);
    categories.add(c);
    notifyListeners();
    return c;
  }

  /// Saves edits from the Edit category sheet.
  void updateCategory(Category c, {required String name, required Color color, required IconData icon, String? imagePath}) {
    c.name = name.trim();
    c.color = color;
    c.icon = icon;
    c.imagePath = imagePath;
    notifyListeners();
  }

  void clearNotes(Category c) {
    for (final Note n in c.notes) {
      Storage.deleteRelative(n.filePath);
    }
    c.notes.clear();
    notifyListeners();
  }

  /// A plain, readable copy of one conversation for the JSON export.
  Map<String, dynamic> exportCategory(Category c) => <String, dynamic>{
        'app': 'Cemo',
        'exportedAt': DateTime.now().toIso8601String(),
        'category': c.name,
        'notes': c.notes
            .map((Note n) => <String, dynamic>{
                  'type': n.kind.name,
                  'createdAt': n.time.toIso8601String(),
                  if (n.text.isNotEmpty) 'text': n.text,
                  if (n.kind == NoteKind.link) 'title': n.linkTitle,
                  if (n.kind == NoteKind.link) 'url': n.link,
                  if (n.fileName != null) 'fileName': n.fileName,
                  if (n.items.isNotEmpty) 'checklist': n.items.map((CheckItem i) => i.toJson()).toList(),
                  'starred': n.starred,
                  if (n.reminder != null) 'reminderAt': n.reminder!.toIso8601String(),
                  if (n.reminder != null) 'reminderDone': n.reminderDone,
                })
            .toList(),
      };

  void setPinned(Iterable<Category> list, bool pinned) {
    for (final Category c in list) {
      c.pinned = pinned;
    }
    notifyListeners();
  }

  /// Archiving also unpins, so an archived conversation never jumps the list later.
  void setArchived(Iterable<Category> list, bool archived) {
    for (final Category c in list) {
      c.archived = archived;
      if (archived) c.pinned = false;
    }
    notifyListeners();
  }

  /// Permanent: removes the conversations and every note in them.
  void deleteCategories(Iterable<Category> list) {
    final Set<Category> gone = list.toSet();
    for (final Category c in gone) {
      Storage.deleteRelative(c.imagePath);
      for (final Note n in c.notes) {
        Storage.deleteRelative(n.filePath);
      }
    }
    categories.removeWhere(gone.contains);
    notifyListeners();
  }

  void markRead(Category c) {
    if (c.unread == 0) return;
    c.unread = 0;
    notifyListeners();
  }

  // --- notes ---
  Note addNote(Category c, String raw, {DateTime? reminder}) {
    final String text = raw.trim();
    final Uri? uri = Uri.tryParse(text);
    final bool isLink = uri != null && uri.hasScheme && uri.host.isNotEmpty && !text.contains(' ');
    final Note n = Note(
      id: _nextId(),
      kind: isLink ? NoteKind.link : NoteKind.text,
      time: DateTime.now(),
      text: isLink ? '' : text,
      linkTitle: isLink ? text : null,
      linkDomain: isLink ? (uri?.host ?? '').replaceFirst('www.', '') : null,
      url: isLink ? text : null,
      reminder: reminder,
    );
    c.notes.add(n);
    notifyListeners();
    return n;
  }

  /// Adds a photo, video or document note. [relativePath] is the app's own
  /// copy of the file (see Storage.saveAttachment).
  Note addAttachment(
    Category c,
    NoteKind kind,
    String relativePath, {
    String caption = '',
    String? fileName,
    int? fileSize,
  }) {
    final Note n = Note(
      id: _nextId(),
      kind: kind,
      time: DateTime.now(),
      text: caption.trim(),
      filePath: relativePath,
      fileName: fileName,
      fileSize: fileSize,
    );
    c.notes.add(n);
    notifyListeners();
    return n;
  }

  void deleteNotes(Category c, Iterable<Note> list) {
    final Set<Note> gone = list.toSet();
    for (final Note n in gone) {
      Storage.deleteRelative(n.filePath);
    }
    c.notes.removeWhere(gone.contains);
    notifyListeners();
  }

  /// Forward: puts a copy of each note at the end of [to]. The originals stay.
  /// Copies start fresh: not starred, no reminder, checklist items copied.
  /// A photo, video or document gets its own copy of the file, so deleting
  /// one note never breaks the other.
  Future<void> forwardNotes(Iterable<Note> list, Category to) async {
    for (final Note n in list.toList()) {
      String? path = n.filePath;
      if (path != null) {
        try {
          path = await Storage.saveAttachment(Storage.resolve(path));
        } catch (_) {
          continue; // the file is gone: skip this note rather than forward a broken one
        }
      }
      to.notes.add(Note(
        id: _nextId(),
        kind: n.kind,
        time: DateTime.now(),
        text: n.text,
        linkTitle: n.linkTitle,
        linkDomain: n.linkDomain,
        url: n.url,
        filePath: path,
        fileName: n.fileName,
        fileSize: n.fileSize,
        items: n.items.map((CheckItem i) => CheckItem(i.text, done: i.done)).toList(),
      ));
    }
    notifyListeners();
  }

  void setStarred(Iterable<Note> list, bool starred) {
    for (final Note n in list) {
      n.starred = starred;
    }
    notifyListeners();
  }

  void toggleCheck(CheckItem item) {
    item.done = !item.done;
    notifyListeners();
  }

  // --- reminders ---
  void setReminder(Note n, DateTime? when) {
    n.reminder = when;
    n.reminderDone = false;
    notifyListeners();
    // TODO: schedule or cancel a local notification here.
  }

  void setRemindersDone(Iterable<Note> list, bool done) {
    for (final Note n in list) {
      n.reminderDone = done;
    }
    notifyListeners();
  }

  /// Removes the reminder only. The note stays in its conversation.
  void clearReminders(Iterable<Note> list) {
    for (final Note n in list) {
      n.reminder = null;
      n.reminderDone = false;
    }
    notifyListeners();
  }

  /// Every reminder in conversations that are not archived, soonest first.
  List<ReminderEntry> get reminders {
    final List<ReminderEntry> out = <ReminderEntry>[];
    for (final Category c in categories) {
      if (c.archived) continue;
      for (final Note n in c.notes) {
        if (n.reminder != null) out.add(ReminderEntry(c, n));
      }
    }
    out.sort((ReminderEntry a, ReminderEntry b) => a.when.compareTo(b.when));
    return out;
  }

  bool get hasDueReminders => reminders.any((ReminderEntry r) => !r.note.reminderDone && sameDay(r.when, DateTime.now()));

  // --- sample data ---
  void _seed() {
    final DateTime now = DateTime.now();
    final DateTime today = dayOf(now);
    DateTime at(int daysAgo, int h, int m) => today.subtract(Duration(days: daysAgo)).add(Duration(hours: h, minutes: m));
    DateTime inDays(int days, int h, int m) => today.add(Duration(days: days, hours: h, minutes: m));

    final Category reading = Category(
      id: _nextId(),
      name: 'Reading list',
      color: kAvatarColors[0],
      icon: Icons.menu_book_outlined,
      pinned: true,
      unread: 3,
      notes: <Note>[
        Note(id: _nextId(), kind: NoteKind.text, time: at(1, 18, 42), text: 'Start a list of everything I reread more than twice.', starred: true),
        Note(
            id: _nextId(),
            kind: NoteKind.text,
            time: at(1, 21, 15),
            text: 'You don’t find time; you decide in advance what will not get it.',
            starred: true),
        Note(
            id: _nextId(),
            kind: NoteKind.link,
            time: at(0, 9, 12),
            text: 'Read this on the weekend',
            linkTitle: 'How to save time every day',
            linkDomain: 'worksmarter.blog',
            starred: true),
        Note(id: _nextId(), kind: NoteKind.checklist, time: at(0, 9, 40), items: <CheckItem>[
          CheckItem('Finish chapter 4 of Deep Work', done: true),
          CheckItem('Summarise the batching article'),
          CheckItem('Send highlights to Naufal'),
        ]),
        Note(
            id: _nextId(),
            kind: NoteKind.text,
            time: at(0, 11, 5),
            text: 'Return the library copy of Deep Work before the late fee starts.',
            reminder: inDays(5, 9, 0)),
      ],
    );

    final Category work = Category(
      id: _nextId(),
      name: 'Work',
      color: kAvatarColors[3],
      icon: Icons.work_outline,
      pinned: true,
      notes: <Note>[
        Note(
            id: _nextId(),
            kind: NoteKind.text,
            time: at(1, 16, 5),
            text: 'Agreed to move the onboarding redesign ahead of billing. Dana owns the first draft.'),
        Note(id: _nextId(), kind: NoteKind.text, time: at(1, 16, 20), text: 'Send revised budget to Dana', reminder: inDays(0, 8, 30)),
      ],
    );

    final Category ideas = Category(
      id: _nextId(),
      name: 'Ideas',
      color: kAvatarColors[4],
      icon: Icons.lightbulb_outline,
      notes: <Note>[
        Note(
            id: _nextId(),
            kind: NoteKind.text,
            time: at(2, 14, 0),
            text: 'A reading app that only shows one article a day. What if the limit is the feature?'),
      ],
    );

    final Category shopping = Category(
      id: _nextId(),
      name: 'Shopping',
      color: kAvatarColors[2],
      icon: Icons.shopping_cart_outlined,
      notes: <Note>[
        Note(
            id: _nextId(),
            kind: NoteKind.link,
            time: at(3, 8, 2),
            text: 'Wait for the sale. Compare it with the one Dimas has.',
            linkTitle: 'Mechanical keyboard, 75% layout, hot-swappable',
            linkDomain: 'keys.example',
            reminder: inDays(1, 12, 0)),
      ],
    );

    final Category campus = Category(
      id: _nextId(),
      name: 'Campus',
      color: kAvatarColors[5],
      icon: Icons.school_outlined,
      notes: <Note>[
        Note(
            id: _nextId(),
            kind: NoteKind.link,
            time: at(4, 10, 30),
            text: 'Send the outline to the supervisor before the seminar.',
            linkTitle: 'Thesis proposal template (2026 edition)',
            linkDomain: 'campus.example',
            reminder: inDays(2, 8, 0)),
      ],
    );

    final Category recipes = Category(
      id: _nextId(),
      name: 'Recipes',
      color: kAvatarColors[1],
      icon: Icons.restaurant_outlined,
      notes: <Note>[
        Note(
            id: _nextId(),
            kind: NoteKind.link,
            time: at(7, 19, 5),
            text: 'Halve the chilli. Works with thighs, not breast.',
            linkTitle: 'One-pan lemon chicken with crispy rice',
            linkDomain: 'weeknight.example'),
        Note(id: _nextId(), kind: NoteKind.text, time: at(7, 19, 10), text: 'Buy lemons and chicken thighs', reminder: inDays(0, 17, 30)),
      ],
    );

    final Category travel = Category(
      id: _nextId(),
      name: 'Travel',
      color: kAvatarColors[0],
      icon: Icons.flight_outlined,
      notes: <Note>[
        Note(
            id: _nextId(),
            kind: NoteKind.link,
            time: at(14, 8, 40),
            text: 'Go in the first week of December. Book the ryokan early.',
            linkTitle: 'Three days in Kyoto without the crowds',
            linkDomain: 'slowtravel.example'),
      ],
    );

    categories.addAll(<Category>[reading, work, ideas, shopping, campus, recipes, travel]);
  }
}

/// Makes [AppState] available to the widget tree and rebuilds dependants when it changes.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child}) : super(notifier: state);

  static AppState of(BuildContext context) {
    final AppScope? scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope not found');
    return scope!.notifier!;
  }
}

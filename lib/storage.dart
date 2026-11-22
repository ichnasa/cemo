import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Files the app keeps on the device.
///
/// Everything lives in the app's documents folder:
///   cemo.json            all categories, notes, reminders and settings
///   category_icons/      photos chosen as category icons (copies, not links)
///   attachments/         photos, videos and documents added to notes (copies)
///
/// Paths saved in cemo.json are relative to that folder, because on iOS the
/// absolute path of the folder can change after an app update.
class Storage {
  static String? _root;

  /// Call once before runApp.
  static Future<void> init() async {
    final Directory dir = await getApplicationDocumentsDirectory();
    _root = dir.path;
  }

  static bool get ready => _root != null;

  /// Absolute path for a relative path stored in cemo.json.
  static String resolve(String relative) => '$_root/$relative';

  static File get _dataFile => File('$_root/cemo.json');

  static Future<Map<String, dynamic>?> read() async {
    try {
      final File f = _dataFile;
      if (!await f.exists()) return null;
      final Object? data = jsonDecode(await f.readAsString());
      return data is Map<String, dynamic> ? data : null;
    } catch (_) {
      return null; // unreadable file: start fresh rather than crash
    }
  }

  /// Writes to a temporary file first, then swaps it in, so a crash halfway
  /// through never leaves a broken data file.
  static Future<void> write(Map<String, dynamic> data) async {
    final File tmp = File('${_dataFile.path}.tmp');
    await tmp.writeAsString(jsonEncode(data), flush: true);
    await tmp.rename(_dataFile.path);
  }

  /// Copies a picked photo into app storage and returns its relative path.
  static Future<String> saveCategoryImage(String sourcePath, String categoryId) async {
    final Directory dir = Directory('$_root/category_icons');
    await dir.create(recursive: true);
    final int dot = sourcePath.lastIndexOf('.');
    final String ext = dot > sourcePath.lastIndexOf('/') ? sourcePath.substring(dot) : '.jpg';
    final String relative = 'category_icons/$categoryId-${DateTime.now().millisecondsSinceEpoch}$ext';
    await File(sourcePath).copy(resolve(relative));
    return relative;
  }

  static int _attachmentSeq = 0;

  /// Copies a photo, video or document into app storage and returns its
  /// relative path. The original file is left where it was.
  static Future<String> saveAttachment(String sourcePath) async {
    final Directory dir = Directory('$_root/attachments');
    await dir.create(recursive: true);
    final int dot = sourcePath.lastIndexOf('.');
    final String ext = dot > sourcePath.lastIndexOf('/') ? sourcePath.substring(dot).toLowerCase() : '';
    final String relative = 'attachments/${DateTime.now().microsecondsSinceEpoch}-${_attachmentSeq++}$ext';
    await File(sourcePath).copy(resolve(relative));
    return relative;
  }

  static Future<void> deleteRelative(String? relative) async {
    if (relative == null || _root == null) return;
    try {
      final File f = File(resolve(relative));
      if (await f.exists()) await f.delete();
    } catch (_) {
      // a leftover file is harmless
    }
  }

  /// Writes an export into the temporary folder and returns the file.
  static Future<File> writeExport(String fileName, String contents) async {
    final Directory dir = await getTemporaryDirectory();
    final File f = File('${dir.path}/$fileName');
    await f.writeAsString(contents, flush: true);
    return f;
  }
}

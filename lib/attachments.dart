import 'dart:io';

import 'package:file_selector/file_selector.dart' as fs;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

import 'models.dart';
import 'sheets.dart';
import 'storage.dart';
import 'theme.dart';

// Photos, videos and documents in notes.
//
// Every file added to a note is copied into the app's own storage
// (attachments/), so the note keeps working when the original is moved or
// deleted from the phone.

enum _Source { photo, video, library, document }

const Set<String> _videoExtensions = <String>{'mp4', 'mov', 'm4v', '3gp', 'webm', 'mkv', 'avi'};

bool _looksLikeVideo(XFile f) {
  final String? mime = f.mimeType;
  if (mime != null && mime.startsWith('video/')) return true;
  final int dot = f.path.lastIndexOf('.');
  return dot >= 0 && _videoExtensions.contains(f.path.substring(dot + 1).toLowerCase());
}

class _Picked {
  _Picked(this.path, this.kind);
  final String path;
  final NoteKind kind;
}

/// The whole "add a photo, video or document" flow, started from the camera
/// button in the composer: choose a source, pick, add a caption, save.
Future<void> addAttachmentFlow(BuildContext context, Category category) async {
  final _Source? source = await _showSourceSheet(context);
  if (source == null || !context.mounted) return;
  final AppState state = AppScope.of(context);

  if (source == _Source.document) {
    await _addDocument(context, state, category);
    return;
  }

  final List<_Picked> picked = <_Picked>[];
  try {
    final ImagePicker picker = ImagePicker();
    switch (source) {
      case _Source.photo:
        final XFile? f = await picker.pickImage(source: ImageSource.camera, imageQuality: 90);
        if (f != null) picked.add(_Picked(f.path, NoteKind.image));
        break;
      case _Source.video:
        final XFile? f = await picker.pickVideo(source: ImageSource.camera);
        if (f != null) picked.add(_Picked(f.path, NoteKind.video));
        break;
      case _Source.library:
        final List<XFile> files = await picker.pickMultipleMedia(imageQuality: 90);
        for (final XFile f in files) {
          picked.add(_Picked(f.path, _looksLikeVideo(f) ? NoteKind.video : NoteKind.image));
        }
        break;
      case _Source.document:
        break;
    }
  } catch (_) {
    if (context.mounted) {
      showCemoSnack(
        context,
        source == _Source.library
            ? 'Couldn’t open your photos. Check photo access in Settings.'
            : 'Couldn’t open the camera. Check camera access in Settings.',
      );
    }
    return;
  }
  if (picked.isEmpty || !context.mounted) return;

  // Preview with a caption field for each item. Null means the user backed out.
  final List<String>? captions = await Navigator.of(context).push<List<String>>(
    MaterialPageRoute<List<String>>(
      fullscreenDialog: true,
      builder: (_) => _PreviewScreen(items: picked, categoryName: category.name),
    ),
  );
  if (captions == null) return;

  int failed = 0;
  for (int i = 0; i < picked.length; i++) {
    try {
      final String relative = await Storage.saveAttachment(picked[i].path);
      final int size = await File(Storage.resolve(relative)).length();
      state.addAttachment(category, picked[i].kind, relative, caption: captions[i], fileSize: size);
    } catch (_) {
      failed++;
    }
  }
  if (failed > 0 && context.mounted) {
    showCemoSnack(context, failed == 1 ? 'One file couldn’t be saved.' : '$failed files couldn’t be saved.');
  }
}

Future<void> _addDocument(BuildContext context, AppState state, Category category) async {
  try {
    final XFile? f = await fs.openFile();
    if (f == null) return;
    final String relative = await Storage.saveAttachment(f.path);
    final int size = await File(Storage.resolve(relative)).length();
    final String name = f.name.isNotEmpty ? f.name : f.path.split('/').last;
    state.addAttachment(category, NoteKind.document, relative, fileName: name, fileSize: size);
  } catch (_) {
    if (context.mounted) showCemoSnack(context, 'Couldn’t add that document.');
  }
}

Future<_Source?> _showSourceSheet(BuildContext context) {
  final CemoColors c = context.c;
  Widget row(BuildContext context, IconData icon, String label, _Source value) => ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 24),
        leading: Icon(icon, color: c.t1),
        title: Text(label, style: Tx.ui(context).copyWith(fontSize: 16)),
        onTap: () => Navigator.of(context).pop(value),
      );
  return showModalBottomSheet<_Source>(
    context: context,
    backgroundColor: c.elevated,
    showDragHandle: true,
    builder: (BuildContext context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            row(context, Icons.photo_camera_outlined, 'Take a photo', _Source.photo),
            row(context, Icons.videocam_outlined, 'Record a video', _Source.video),
            row(context, Icons.photo_library_outlined, 'Choose from photos', _Source.library),
            row(context, Icons.insert_drive_file_outlined, 'Add a document', _Source.document),
          ],
        ),
      ),
    ),
  );
}

/// Opens a photo or video full screen, or hands a document to the app that
/// reads it.
Future<void> openAttachment(BuildContext context, Note note) async {
  final String? relative = note.filePath;
  if (relative == null || !File(Storage.resolve(relative)).existsSync()) {
    showCemoSnack(context, 'This file is no longer on the device.');
    return;
  }
  if (note.kind == NoteKind.document) {
    try {
      final OpenResult result = await OpenFilex.open(Storage.resolve(relative));
      if (result.type != ResultType.done && context.mounted) {
        showCemoSnack(
          context,
          result.type == ResultType.noAppToOpen ? 'No app on this phone can open this file.' : 'Couldn’t open the document.',
        );
      }
    } catch (_) {
      if (context.mounted) showCemoSnack(context, 'Couldn’t open the document.');
    }
    return;
  }
  await Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => AttachmentViewerScreen(note: note)),
  );
}

// ---------- tiles shown in the conversation and the Media tab ----------

/// A photo, or a dark tile with a play button for a video.
class MediaTile extends StatelessWidget {
  const MediaTile({super.key, required this.note, required this.width, required this.height, this.radius = 12});
  final Note note;
  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final CemoColors c = context.c;
    final String? relative = note.filePath;

    Widget missing() => Container(
          width: width,
          height: height,
          color: c.bg2,
          alignment: Alignment.center,
          child: Icon(Icons.broken_image_outlined, color: c.t3, semanticLabel: 'File missing'),
        );

    Widget child;
    if (relative == null || !Storage.ready) {
      child = missing();
    } else if (note.kind == NoteKind.video) {
      child = Container(
        width: width,
        height: height,
        color: const Color(0xFF191919),
        alignment: Alignment.center,
        child: Container(
          width: 44,
          height: 44,
          decoration: const BoxDecoration(color: Color(0x33FFFFFF), shape: BoxShape.circle),
          child: const Icon(Icons.play_arrow, color: Colors.white, size: 28, semanticLabel: 'Video'),
        ),
      );
    } else {
      child = Image.file(
        File(Storage.resolve(relative)),
        width: width,
        height: height,
        fit: BoxFit.cover,
        // Decode at screen size, not full camera resolution, to keep scrolling smooth.
        cacheWidth: (width * MediaQuery.devicePixelRatioOf(context)).round(),
        gaplessPlayback: true,
        semanticLabel: note.text.isNotEmpty ? note.text : 'Photo',
        errorBuilder: (BuildContext context, Object error, StackTrace? stack) => missing(),
      );
    }
    return ClipRRect(borderRadius: BorderRadius.circular(radius), child: child);
  }
}

/// A document note: file icon, name, size.
class DocumentCard extends StatelessWidget {
  const DocumentCard({super.key, required this.note, this.width});
  final Note note;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final CemoColors c = context.c;
    final String name = note.fileName ?? 'Document';
    final int dot = name.lastIndexOf('.');
    final String type = dot > 0 && dot < name.length - 1 ? name.substring(dot + 1).toUpperCase() : 'FILE';
    final String size = fileSizeLabel(note.fileSize);
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: c.bg,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(4),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: <Widget>[
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: c.bg2, borderRadius: BorderRadius.circular(4)),
            child: Icon(Icons.insert_drive_file_outlined, color: c.t2, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(name, maxLines: 2, overflow: TextOverflow.ellipsis, style: Tx.subhead(context)),
                const SizedBox(height: 2),
                Text(size.isEmpty ? type : '$type · $size', style: Tx.caption(context)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------- video ----------

/// Plays one video file. Tap the picture to play or pause.
class _VideoView extends StatefulWidget {
  const _VideoView({super.key, required this.path, this.autoPlay = false});
  final String path;
  final bool autoPlay;

  @override
  State<_VideoView> createState() => _VideoViewState();
}

class _VideoViewState extends State<_VideoView> {
  late final VideoPlayerController _controller;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(File(widget.path));
    _start();
  }

  Future<void> _start() async {
    try {
      await _controller.initialize();
      if (!mounted) return;
      setState(() {});
      if (widget.autoPlay) await _controller.play();
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    final VideoPlayerValue v = _controller.value;
    if (v.isPlaying) {
      _controller.pause();
    } else {
      // At the end, start again from the beginning.
      if (v.position >= v.duration) _controller.seekTo(Duration.zero);
      _controller.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return const Center(
        child: Text('This video can’t be played.', style: TextStyle(color: Colors.white70, fontSize: 15)),
      );
    }
    if (!_controller.value.isInitialized) {
      return const Center(
        child: SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70)),
      );
    }
    return Column(
      children: <Widget>[
        Expanded(
          child: Semantics(
            button: true,
            label: 'Play or pause',
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _toggle,
              child: Center(
                child: AspectRatio(
                  aspectRatio: _controller.value.aspectRatio,
                  child: Stack(
                    alignment: Alignment.center,
                    children: <Widget>[
                      VideoPlayer(_controller),
                      ValueListenableBuilder<VideoPlayerValue>(
                        valueListenable: _controller,
                        builder: (BuildContext context, VideoPlayerValue v, Widget? child) => AnimatedScale(
                          scale: v.isPlaying ? 0 : 1,
                          duration: const Duration(milliseconds: 140),
                          child: child,
                        ),
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: const BoxDecoration(color: Color(0x66000000), shape: BoxShape.circle),
                          child: const Icon(Icons.play_arrow, color: Colors.white, size: 34),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: VideoProgressIndicator(
            _controller,
            allowScrubbing: true,
            padding: const EdgeInsets.symmetric(vertical: 8),
            colors: const VideoProgressColors(
              playedColor: Colors.white,
              bufferedColor: Color(0x55FFFFFF),
              backgroundColor: Color(0x33FFFFFF),
            ),
          ),
        ),
      ],
    );
  }
}

// ---------- preview before saving ----------

/// Shows what was picked, with a caption field for each item.
/// Pops with one caption per item, or null when the user backs out.
class _PreviewScreen extends StatefulWidget {
  const _PreviewScreen({required this.items, required this.categoryName});
  final List<_Picked> items;
  final String categoryName;

  @override
  State<_PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<_PreviewScreen> {
  late final List<TextEditingController> _captions =
      List<TextEditingController>.generate(widget.items.length, (_) => TextEditingController());
  final PageController _pages = PageController();
  int _index = 0;

  @override
  void dispose() {
    for (final TextEditingController t in _captions) {
      t.dispose();
    }
    _pages.dispose();
    super.dispose();
  }

  void _save() {
    Navigator.of(context).pop(_captions.map((TextEditingController t) => t.text.trim()).toList());
  }

  @override
  Widget build(BuildContext context) {
    final int count = widget.items.length;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Cancel',
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          count == 1 ? widget.categoryName : '${_index + 1} of $count',
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: PageView.builder(
                controller: _pages,
                itemCount: count,
                onPageChanged: (int i) => setState(() => _index = i),
                itemBuilder: (BuildContext context, int i) {
                  final _Picked item = widget.items[i];
                  if (item.kind == NoteKind.video) {
                    return _VideoView(key: ValueKey<String>(item.path), path: item.path);
                  }
                  return Image.file(
                    File(item.path),
                    fit: BoxFit.contain,
                    errorBuilder: (BuildContext context, Object error, StackTrace? stack) => const Center(
                      child: Text('This photo can’t be shown.', style: TextStyle(color: Colors.white70)),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Expanded(
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 44),
                      decoration: BoxDecoration(color: const Color(0xFF242424), borderRadius: BorderRadius.circular(22)),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      // IndexedStack keeps each caption field's text and cursor
                      // while swiping between items.
                      child: IndexedStack(
                        index: _index,
                        children: <Widget>[
                          for (int i = 0; i < count; i++)
                            TextField(
                              controller: _captions[i],
                              minLines: 1,
                              maxLines: 4,
                              textCapitalization: TextCapitalization.sentences,
                              style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.4),
                              cursorColor: Colors.white,
                              decoration: const InputDecoration(
                                isDense: true,
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(vertical: 11),
                                hintText: 'Add a caption (optional)',
                                hintStyle: TextStyle(color: Color(0xFF9A9A9A), fontSize: 16),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Semantics(
                    button: true,
                    label: count == 1 ? 'Save to ${widget.categoryName}' : 'Save $count items to ${widget.categoryName}',
                    child: InkResponse(
                      onTap: _save,
                      radius: 26,
                      child: const SizedBox(
                        width: 48,
                        height: 48,
                        child: Center(
                          child: DecoratedBox(
                            decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                            child: SizedBox(
                              width: 36,
                              height: 36,
                              child: Icon(Icons.arrow_upward, size: 20, color: Colors.black),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------- full-screen viewer ----------

class AttachmentViewerScreen extends StatelessWidget {
  const AttachmentViewerScreen({super.key, required this.note});
  final Note note;

  Future<void> _share(BuildContext context) async {
    final RenderBox? box = context.findRenderObject() as RenderBox?;
    final Rect? origin = box == null ? null : box.localToGlobal(Offset.zero) & box.size;
    try {
      await SharePlus.instance.share(ShareParams(
        files: <XFile>[XFile(Storage.resolve(note.filePath!))],
        sharePositionOrigin: origin,
      ));
    } catch (_) {
      if (context.mounted) showCemoSnack(context, 'Couldn’t share this file.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final String path = Storage.resolve(note.filePath!);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.chevron_left, size: 28),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          '${dayLabel(note.time)} ${hhmm(note.time)}',
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
        ),
        actions: <Widget>[
          Builder(
            builder: (BuildContext context) => IconButton(
              tooltip: 'Share',
              icon: const Icon(Icons.ios_share),
              onPressed: () => _share(context),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: note.kind == NoteKind.video
                  ? _VideoView(path: path, autoPlay: true)
                  : InteractiveViewer(
                      maxScale: 5,
                      child: Center(
                        child: Image.file(
                          File(path),
                          fit: BoxFit.contain,
                          semanticLabel: note.text.isNotEmpty ? note.text : 'Photo',
                          errorBuilder: (BuildContext context, Object error, StackTrace? stack) => const Text(
                            'This photo can’t be shown.',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ),
                      ),
                    ),
            ),
            if (note.text.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
                child: Text(
                  note.text,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.45),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

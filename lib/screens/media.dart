import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

import '../attachments.dart';
import '../models.dart';
import '../sheets.dart';
import '../theme.dart';
import '../widgets.dart';

/// Media, links and docs saved in one conversation, on three tabs.
/// Tapping an item opens it.
class ConversationMediaScreen extends StatefulWidget {
  const ConversationMediaScreen({super.key, required this.category});
  final Category category;

  @override
  State<ConversationMediaScreen> createState() => _ConversationMediaScreenState();
}

class _ConversationMediaScreenState extends State<ConversationMediaScreen> {
  int _tab = 0; // 0 media, 1 links, 2 docs

  @override
  Widget build(BuildContext context) {
    AppScope.of(context); // rebuild when notes change
    final CemoColors c = context.c;
    final List<Note> links =
        widget.category.notes.where((Note n) => n.kind == NoteKind.link).toList().reversed.toList();

    Widget empty(String text) => Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 36),
            child: Text(text, textAlign: TextAlign.center, style: Tx.excerpt(context)),
          ),
        );

    final List<Note> media = widget.category.notes.where((Note n) => n.isMedia).toList().reversed.toList();
    final List<Note> docs =
        widget.category.notes.where((Note n) => n.kind == NoteKind.document).toList().reversed.toList();

    Widget body;
    if (_tab == 0) {
      body = media.isEmpty
          ? empty('No photos or videos yet. Tap the camera in the conversation to add one.')
          : LayoutBuilder(
              builder: (BuildContext context, BoxConstraints box) {
                const double gap = 2;
                final double side = (box.maxWidth - gap * 2) / 3;
                return GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: gap,
                    crossAxisSpacing: gap,
                  ),
                  itemCount: media.length,
                  itemBuilder: (BuildContext context, int i) => Semantics(
                    button: true,
                    label: media[i].kind == NoteKind.video ? 'Play video' : 'Open photo',
                    child: GestureDetector(
                      onTap: () => openAttachment(context, media[i]),
                      child: MediaTile(note: media[i], width: side, height: side, radius: 0),
                    ),
                  ),
                );
              },
            );
    } else if (_tab == 2) {
      body = docs.isEmpty
          ? empty('No documents yet. Tap the camera in the conversation, then “Add a document”.')
          : ListView.separated(
              itemCount: docs.length,
              separatorBuilder: (BuildContext context, int i) => const Hairline(indent: 72),
              itemBuilder: (BuildContext context, int i) {
                final Note n = docs[i];
                final String size = fileSizeLabel(n.fileSize);
                return FItem(
                  prefix: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(color: c.bg2, borderRadius: BorderRadius.circular(4)),
                    child: Icon(FLucideIcons.file, color: c.t2, size: 20),
                  ),
                  title: Text(n.fileName ?? 'Document', maxLines: 2, overflow: TextOverflow.ellipsis, style: Tx.subhead(context)),
                  subtitle: Text(size.isEmpty ? dayLabel(n.time) : '$size · ${dayLabel(n.time)}', style: Tx.meta(context)),
                  onPress: () => openAttachment(context, n),
                );
              },
            );
    } else if (links.isEmpty) {
      body = empty('No links in this conversation yet. Paste a web address as a note to save one.');
    } else {
      body = ListView.separated(
        itemCount: links.length,
        separatorBuilder: (BuildContext context, int i) => const Hairline(indent: 72),
        itemBuilder: (BuildContext context, int i) {
          final Note n = links[i];
          return FItem(
            prefix: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: c.bg2, borderRadius: BorderRadius.circular(4)),
              child: Icon(FLucideIcons.link, color: c.t2, size: 20),
            ),
            title: Text(n.linkTitle ?? n.link ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: Tx.subhead(context)),
            subtitle: Text('${n.linkDomain ?? ''} · ${dayLabel(n.time)}', style: Tx.meta(context)),
            onPress: () => openLink(context, n.link),
          );
        },
      );
    }

    return FScaffold(
      childPad: false,
      header: FHeader.nested(
        title: Text(widget.category.name),
        prefixes: <Widget>[FHeaderAction.back(semanticsLabel: 'Back', onPress: () => Navigator.of(context).pop())],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: <Widget>[
            TopicTabs(
              labels: const <String>['Media', 'Links', 'Docs'],
              selected: _tab,
              onSelect: (int i) => setState(() => _tab = i),
            ),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}

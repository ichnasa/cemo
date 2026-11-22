import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';

import 'package:cemo/attachments.dart';
import 'package:cemo/models.dart';
import 'package:cemo/theme.dart';

/// Platforms without a video player (Linux, Windows) must not leave the
/// viewer stuck on a spinner or a dead end. The test host has no video player
/// either, so this is the same path.
void main() {
  testWidgets('video viewer offers another app when playback is unavailable', (WidgetTester tester) async {
    final FThemeData theme = buildCemoFTheme(Brightness.light);
    final Note note = Note(id: 'v1', kind: NoteKind.video, time: DateTime(2026, 1, 1, 9), filePath: 'attachments/clip.mp4');
    await tester.pumpWidget(MaterialApp(
      theme: buildCemoMaterialTheme(theme),
      builder: (BuildContext context, Widget? child) => FTheme(data: theme, child: FToaster(child: child!)),
      home: AttachmentViewerScreen(note: note),
    ));
    await tester.pumpAndSettle();

    expect(find.text('This video can’t be played here.'), findsOneWidget);
    expect(find.text('Open in another app'), findsOneWidget);
  });
}

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Loads Forui's Inter and Lucide fonts so tests lay text out with real
/// metrics instead of the square test font.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await (FontLoader('packages/forui/Inter')..addFont(rootBundle.load('packages/forui/assets/fonts/inter/Inter.ttf')))
      .load();
  await (FontLoader('packages/forui_assets/ForuiLucideIcons')
        ..addFont(rootBundle.load('packages/forui_assets/assets/lucide.ttf')))
      .load();
  await testMain();
}

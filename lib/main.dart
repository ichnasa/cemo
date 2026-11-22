import 'package:flutter/material.dart';

import 'models.dart';
import 'screens/auth.dart';
import 'screens/home.dart';
import 'screens/onboarding.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Restore what was saved on the device before the first frame.
  final AppState state = AppState(seed: false);
  await state.load();
  runApp(CemoApp(state: state));
}

class CemoApp extends StatefulWidget {
  /// Without [state] the app runs on sample content and saves nothing (used by tests).
  const CemoApp({super.key, this.state});
  final AppState? state;

  @override
  State<CemoApp> createState() => _CemoAppState();
}

class _CemoAppState extends State<CemoApp> {
  late final AppState _state = widget.state ?? AppState();

  @override
  void dispose() {
    _state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: _state,
      child: AnimatedBuilder(
        animation: _state,
        builder: (BuildContext context, Widget? _) => MaterialApp(
          title: 'Cemo',
          debugShowCheckedModeBanner: false,
          theme: buildCemoTheme(Brightness.light),
          darkTheme: buildCemoTheme(Brightness.dark),
          themeMode: _state.themeMode,
          home: const _Gate(),
        ),
      ),
    );
  }
}

/// Onboarding first, then sign up or log in, then the app.
class _Gate extends StatelessWidget {
  const _Gate();

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    if (!state.onboarded) return const OnboardingScreen();
    if (!state.signedIn) return const JoinScreen();
    return const HomeShell();
  }
}

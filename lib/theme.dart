import 'package:flutter/material.dart';

/// Colour tokens from the Cemo Foundations board, in Light and Dark.
@immutable
class CemoColors extends ThemeExtension<CemoColors> {
  const CemoColors({
    required this.bg,
    required this.bg2,
    required this.elevated,
    required this.t1,
    required this.t2,
    required this.t3,
    required this.divider,
    required this.border,
    required this.primaryFill,
    required this.primaryText,
    required this.accent,
    required this.highlight,
    required this.reminder,
    required this.destructive,
    required this.disabled,
  });

  final Color bg;
  final Color bg2;
  final Color elevated;
  final Color t1;
  final Color t2;
  final Color t3;
  final Color divider;
  final Color border;
  final Color primaryFill;
  final Color primaryText;
  final Color accent;
  final Color highlight;
  final Color reminder;
  final Color destructive;
  final Color disabled;

  static const CemoColors light = CemoColors(
    bg: Color(0xFFFFFFFF),
    bg2: Color(0xFFF9F9F9),
    elevated: Color(0xFFFFFFFF),
    t1: Color(0xFF242424),
    t2: Color(0xFF6B6B6B),
    t3: Color(0xFF767676),
    divider: Color(0xFFF2F2F2),
    border: Color(0xFFE6E6E6),
    primaryFill: Color(0xFF191919),
    primaryText: Color(0xFFFFFFFF),
    accent: Color(0xFF1A8917),
    highlight: Color(0xFFE8F3E8),
    reminder: Color(0xFFB4540A),
    destructive: Color(0xFFC94A4A),
    disabled: Color(0xFFF2F2F2),
  );

  static const CemoColors dark = CemoColors(
    bg: Color(0xFF121212),
    bg2: Color(0xFF1A1A1A),
    elevated: Color(0xFF1E1E1E),
    t1: Color(0xFFE6E6E6),
    t2: Color(0xFFA8A8A8),
    t3: Color(0xFF8C8C8C),
    divider: Color(0xFF2A2A2A),
    border: Color(0xFF333333),
    primaryFill: Color(0xFFF2F2F2),
    primaryText: Color(0xFF121212),
    accent: Color(0xFF3FB950),
    highlight: Color(0xFF1F3A22),
    reminder: Color(0xFFFF9F0A),
    destructive: Color(0xFFFF6B6B),
    disabled: Color(0xFF2A2A2A),
  );

  @override
  CemoColors copyWith() => this;

  @override
  CemoColors lerp(ThemeExtension<CemoColors>? other, double t) {
    if (other is! CemoColors) return this;
    return t < 0.5 ? this : other;
  }
}

extension CemoContext on BuildContext {
  CemoColors get c => Theme.of(this).extension<CemoColors>()!;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}

/// Serif used for anything the user reads. Georgia ships with iOS; Android
/// falls back to its own serif.
const String kSerif = 'Georgia';
const List<String> kSerifFallback = <String>['Noto Serif', 'serif'];

/// Text styles from the Foundations board.
class Tx {
  static TextStyle display(BuildContext x) => TextStyle(
      fontSize: 32, height: 38 / 32, fontWeight: FontWeight.w700, letterSpacing: -0.5, color: x.c.t1);
  static TextStyle title(BuildContext x) => TextStyle(
      fontSize: 24, height: 30 / 24, fontWeight: FontWeight.w700, letterSpacing: -0.3, color: x.c.t1);
  static TextStyle headline(BuildContext x) => TextStyle(
      fontSize: 20, height: 26 / 20, fontWeight: FontWeight.w700, letterSpacing: -0.2, color: x.c.t1);
  static TextStyle subhead(BuildContext x) =>
      TextStyle(fontSize: 16, height: 20 / 16, fontWeight: FontWeight.w700, color: x.c.t1);
  static TextStyle bodySerif(BuildContext x) => TextStyle(
      fontFamily: kSerif,
      fontFamilyFallback: kSerifFallback,
      fontSize: 17,
      height: 26 / 17,
      fontWeight: FontWeight.w400,
      color: x.c.t1);
  static TextStyle excerpt(BuildContext x) => TextStyle(
      fontFamily: kSerif,
      fontFamilyFallback: kSerifFallback,
      fontSize: 16,
      height: 24 / 16,
      fontWeight: FontWeight.w400,
      color: x.c.t2);
  static TextStyle serifTitle(BuildContext x, {double size = 30}) => TextStyle(
      fontFamily: kSerif,
      fontFamilyFallback: kSerifFallback,
      fontSize: size,
      height: (size + 6) / size,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.4,
      color: x.c.t1);
  static TextStyle ui(BuildContext x) =>
      TextStyle(fontSize: 15, height: 20 / 15, fontWeight: FontWeight.w400, color: x.c.t1);
  static TextStyle uiStrong(BuildContext x) =>
      TextStyle(fontSize: 15, height: 20 / 15, fontWeight: FontWeight.w600, color: x.c.t1);
  static TextStyle meta(BuildContext x) =>
      TextStyle(fontSize: 13, height: 18 / 13, fontWeight: FontWeight.w400, color: x.c.t2);
  static TextStyle caption(BuildContext x) =>
      TextStyle(fontSize: 12, height: 16 / 12, fontWeight: FontWeight.w500, color: x.c.t2);
  static TextStyle tab(BuildContext x) =>
      TextStyle(fontSize: 14, height: 20 / 14, fontWeight: FontWeight.w400, color: x.c.t2);
}

ThemeData buildCemoTheme(Brightness brightness) {
  final CemoColors c = brightness == Brightness.dark ? CemoColors.dark : CemoColors.light;
  final ColorScheme scheme = ColorScheme.fromSeed(seedColor: c.accent, brightness: brightness).copyWith(
    primary: c.primaryFill,
    onPrimary: c.primaryText,
    secondary: c.accent,
    surface: c.bg,
    onSurface: c.t1,
    error: c.destructive,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: c.bg,
    dividerColor: c.divider,
    splashFactory: NoSplash.splashFactory,
    highlightColor: c.bg2,
    extensions: <ThemeExtension<dynamic>>[c],
    appBarTheme: AppBarTheme(
      backgroundColor: c.bg,
      foregroundColor: c.t1,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: c.elevated,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: const Color(0xFF191919),
      contentTextStyle: const TextStyle(color: Colors.white, fontSize: 15),
      actionTextColor: const Color(0xFF3FB950),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    ),
    textSelectionTheme: TextSelectionThemeData(cursorColor: c.accent),
  );
}

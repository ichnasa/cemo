import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

// The Forui theme ([buildCemoFTheme]) is the single source of truth for the
// app's colours, typography and spacing. Cemo's own colour tokens ride along
// on it as an [FColors] extension, and the Material theme that the few
// remaining Material widgets (date and time pickers) need is derived from it.

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
  /// Cemo colour tokens of the current [FTheme].
  CemoColors get c => theme.colors.extension<CemoColors>();
  bool get isDark => theme.colors.brightness == Brightness.dark;
}

/// Spacing scale from the Foundations board (4 pt grid).
class Space {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 36;

  /// Side padding of screens and lists.
  static const double page = 24;
}

/// Serif used for anything the user reads. Georgia ships with iOS; Android
/// falls back to its own serif.
const String kSerif = 'Georgia';
const List<String> kSerifFallback = <String>['Noto Serif', 'serif'];

/// Text styles from the Foundations board, built on the [FTheme] typography so
/// the font family comes from one place.
class Tx {
  static TextStyle _sans(BuildContext x, double size, double lineHeight, FontWeight weight, {double? letterSpacing}) =>
      x.theme.typography.body.md.copyWith(
        fontSize: size,
        height: lineHeight / size,
        fontWeight: weight,
        letterSpacing: letterSpacing,
        color: x.c.t1,
      );

  static TextStyle _serif(BuildContext x, double size, double lineHeight, FontWeight weight, Color color) => TextStyle(
        fontFamily: kSerif,
        fontFamilyFallback: kSerifFallback,
        fontSize: size,
        height: lineHeight / size,
        fontWeight: weight,
        color: color,
      );

  static TextStyle display(BuildContext x) => _sans(x, 32, 38, FontWeight.w700, letterSpacing: -0.5);
  static TextStyle title(BuildContext x) => _sans(x, 24, 30, FontWeight.w700, letterSpacing: -0.3);
  static TextStyle headline(BuildContext x) => _sans(x, 20, 26, FontWeight.w700, letterSpacing: -0.2);
  static TextStyle subhead(BuildContext x) => _sans(x, 16, 20, FontWeight.w700);
  static TextStyle bodySerif(BuildContext x) => _serif(x, 17, 26, FontWeight.w400, x.c.t1);
  static TextStyle excerpt(BuildContext x) => _serif(x, 16, 24, FontWeight.w400, x.c.t2);
  static TextStyle serifTitle(BuildContext x, {double size = 30}) =>
      _serif(x, size, size + 6, FontWeight.w700, x.c.t1).copyWith(letterSpacing: -0.4);
  static TextStyle ui(BuildContext x) => _sans(x, 15, 20, FontWeight.w400);
  static TextStyle uiStrong(BuildContext x) => _sans(x, 15, 20, FontWeight.w600);
  static TextStyle meta(BuildContext x) => _sans(x, 13, 18, FontWeight.w400).copyWith(color: x.c.t2);
  static TextStyle caption(BuildContext x) => _sans(x, 12, 16, FontWeight.w500).copyWith(color: x.c.t2);
  static TextStyle tab(BuildContext x) => _sans(x, 14, 20, FontWeight.w400).copyWith(color: x.c.t2);
}

/// The app theme: Forui's neutral touch theme recoloured with the Cemo tokens.
FThemeData buildCemoFTheme(Brightness brightness) {
  final bool dark = brightness == Brightness.dark;
  final CemoColors c = dark ? CemoColors.dark : CemoColors.light;
  final FColors base = dark ? FColors.neutralDark : FColors.neutralLight;
  final FColors colors = base.copyWith(
    background: c.bg,
    foreground: c.t1,
    primary: c.primaryFill,
    primaryForeground: c.primaryText,
    secondary: c.bg2,
    secondaryForeground: c.t1,
    muted: c.bg2,
    mutedForeground: c.t2,
    destructive: c.destructive,
    destructiveForeground: const Color(0xFFFFFFFF),
    error: c.destructive,
    errorForeground: const Color(0xFFFFFFFF),
    card: c.elevated,
    border: c.border,
    extensions: <ThemeExtension<dynamic>>[c],
  );
  return FThemeData(
    debugLabel: dark ? 'Cemo Dark' : 'Cemo Light',
    colors: colors,
    touch: true,
  );
}

/// Material theme for the remaining Material widgets, derived from [f].
ThemeData buildCemoMaterialTheme(FThemeData f) {
  final CemoColors c = f.colors.extension<CemoColors>();
  return f.toApproximateMaterialTheme().copyWith(
        scaffoldBackgroundColor: c.bg,
        splashFactory: NoSplash.splashFactory,
        highlightColor: c.bg2,
        extensions: <ThemeExtension<dynamic>>[c],
        textSelectionTheme: TextSelectionThemeData(cursorColor: c.accent),
      );
}

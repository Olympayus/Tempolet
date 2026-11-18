import 'package:flutter/material.dart';

/// Neutral category colour for events without a category
/// (`docs/design/01-tokens.md` §1.3). Identical in light and dark themes.
const Color kUncategorizedColor = Color(0xFFC7C7CC);

/// Floating-window drop shadow (`docs/design/01-tokens.md` §4): a 14px
/// offset with a 40px blur, softened on paper and deepened in dark mode.
const List<BoxShadow> kDialogShadow = [
  BoxShadow(color: Color(0x29000000), blurRadius: 40, offset: Offset(0, 14)),
];

/// Dark-mode counterpart of [kDialogShadow].
const List<BoxShadow> kDialogShadowDark = [
  BoxShadow(color: Color(0x73000000), blurRadius: 40, offset: Offset(0, 14)),
];

/// Soft lift for floating reminder cards (`0 2px 6px rgba(0,0,0,.05)`).
const List<BoxShadow> kCardShadow = [
  BoxShadow(color: Color(0x0D000000), blurRadius: 6, offset: Offset(0, 2)),
];

/// Fill of the focused segment in date/time/custom segmented fields
/// (`rgba(0,0,0,.06)` on paper).
const Color kSelectedSegmentFill = Color(0x0F000000);

/// Semantic palette from `docs/design/01-tokens.md`.
///
/// UI code reads tokens through this class (or `Theme.of`), never hex.
@immutable
class AppPalette {
  const AppPalette({
    required this.ink,
    required this.sub,
    required this.subText,
    required this.subWeak,
    required this.subMuted,
    required this.line,
    required this.lineStrong,
    required this.chip,
    required this.block,
    required this.nav,
    required this.side,
    required this.bg,
    required this.card,
    required this.accent,
    required this.accentTint,
    required this.danger,
    required this.dangerTint,
    required this.hover,
    required this.surfaceSelected,
    required this.festival,
    required this.festivalTint,
  });

  /// Light theme tokens.
  static const light = AppPalette(
    ink: Color(0xFF1C1C1E),
    sub: Color(0xFF8E8E93),
    subText: Color(0xFF6E6E73),
    subWeak: Color(0xFFC7C7CC),
    subMuted: Color(0xFFAEAEB2),
    line: Color(0xFFEDEDF0),
    lineStrong: Color(0xFFDCDCE1),
    chip: Color(0xFFF2F2F5),
    block: Color(0xFFF2F2F5),
    nav: Color(0xFFECEDF0),
    side: Color(0xFFF2F3F5),
    bg: Color(0xFFFFFFFF),
    card: Color(0xFFFFFFFF),
    accent: Color(0xFF007AFF),
    accentTint: Color(0x1C007AFF),
    danger: Color(0xFFFF3B30),
    dangerTint: Color(0x0FFF3B30),
    hover: Color(0xFFF7F7F9),
    surfaceSelected: Color(0xFFF7F7FA),
    festival: Color(0xFFC22F2F),
    festivalTint: Color(0x1AC22F2F),
  );

  /// Dark theme tokens.
  static const dark = AppPalette(
    ink: Color(0xFFE9EBF0),
    sub: Color(0xFF8A919C),
    subText: Color(0xFF9AA3AE),
    subWeak: Color(0xFF5A6068),
    subMuted: Color(0xFF6F7680),
    line: Color(0x12FFFFFF),
    lineStrong: Color(0x24FFFFFF),
    chip: Color(0x0FFFFFFF),
    block: Color(0xFF262A33),
    nav: Color(0xFF0B0C0F),
    side: Color(0xFF121419),
    bg: Color(0xFF191C22),
    card: Color(0xFF20232A),
    accent: Color(0xFF4DA3FF),
    accentTint: Color(0x294DA3FF),
    danger: Color(0xFFFF6B5E),
    dangerTint: Color(0x1AFF6B5E),
    hover: Color(0x0AFFFFFF),
    surfaceSelected: Color(0x0CFFFFFF),
    festival: Color(0xFFFF8F8A),
    festivalTint: Color(0x1FFF8F8A),
  );

  /// Primary text and numerals.
  final Color ink;

  /// Secondary text, times and counts.
  final Color sub;

  /// 13px explanatory and field-helper text.
  final Color subText;

  /// Placeholders, empty states and free slots.
  final Color subWeak;

  /// Third-level metadata (11px counts and units only).
  final Color subMuted;

  /// Hairlines and in-component dividers.
  final Color line;

  /// Table rules, field borders and the timeline.
  final Color lineStrong;

  /// Fills, input backgrounds and secondary buttons.
  final Color chip;

  /// Paper block behind plan rows.
  final Color block;

  /// Window titlebar and icon rail surface.
  final Color nav;

  /// Sidebar, header and axis gutter surface.
  final Color side;

  /// Main content background.
  final Color bg;

  /// Card background.
  final Color card;

  /// "Now", selection and primary actions.
  final Color accent;

  /// Selection fill and "now" line wash.
  final Color accentTint;

  /// Overdue and destructive actions.
  final Color danger;

  /// Overdue band background.
  final Color dangerTint;

  /// Row hover background.
  final Color hover;

  /// Selected-day column wash in week view.
  final Color surfaceSelected;

  /// Festival names and the "休" pill text.
  final Color festival;

  /// The "休" pill background.
  final Color festivalTint;

  /// Copy of this palette with a user-chosen [accent] and derived tint.
  AppPalette withAccent(Color accent) => AppPalette(
    ink: ink,
    sub: sub,
    subText: subText,
    subWeak: subWeak,
    subMuted: subMuted,
    line: line,
    lineStrong: lineStrong,
    chip: chip,
    block: block,
    nav: nav,
    side: side,
    bg: bg,
    card: card,
    accent: accent,
    accentTint: accent.withValues(alpha: .11),
    danger: danger,
    dangerTint: dangerTint,
    hover: hover,
    surfaceSelected: surfaceSelected,
    festival: festival,
    festivalTint: festivalTint,
  );
}

/// Desktop type scale from `docs/design/01-tokens.md` §3.1.
abstract final class AppTextStyles {
  /// Page-level titles (settings, note library, timetable).
  static const display = TextStyle(
    fontFamily: 'Inter',
    fontFamilyFallback: ['NotoSansSC'],
    fontSize: 28,
    height: 34 / 28,
    letterSpacing: -0.6,
    fontWeight: FontWeight.w700,
    fontVariations: [FontVariation('wght', 700)],
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// Sheet titles and large section headers.
  static const title = TextStyle(
    fontFamily: 'Inter',
    fontFamilyFallback: ['NotoSansSC'],
    fontSize: 20,
    height: 26 / 20,
    letterSpacing: -0.2,
    fontWeight: FontWeight.w700,
    fontVariations: [FontVariation('wght', 700)],
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// Card titles and day-view date.
  static const headline = TextStyle(
    fontFamily: 'Inter',
    fontFamilyFallback: ['NotoSansSC'],
    fontSize: 15,
    height: 20 / 15,
    letterSpacing: -0.1,
    fontWeight: FontWeight.w700,
    fontVariations: [FontVariation('wght', 700)],
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// Group headers in lists.
  static const section = TextStyle(
    fontFamily: 'Inter',
    fontFamilyFallback: ['NotoSansSC'],
    fontSize: 15,
    height: 20 / 15,
    letterSpacing: 0,
    fontWeight: FontWeight.w600,
    fontVariations: [FontVariation('wght', 600)],
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// List row titles.
  static const rowTitle = TextStyle(
    fontFamily: 'Inter',
    fontFamilyFallback: ['NotoSansSC'],
    fontSize: 14,
    height: 20 / 14,
    letterSpacing: 0,
    fontWeight: FontWeight.w500,
    fontVariations: [FontVariation('wght', 500)],
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// Body copy, inputs and list rows.
  static const body = TextStyle(
    fontFamily: 'Inter',
    fontFamilyFallback: ['NotoSansSC'],
    fontSize: 13,
    height: 18 / 13,
    letterSpacing: 0,
    fontWeight: FontWeight.w400,
    fontVariations: [FontVariation('wght', 400)],
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// Explanatory and field-helper text.
  static const hint = TextStyle(
    fontFamily: 'Inter',
    fontFamilyFallback: ['NotoSansSC'],
    fontSize: 13,
    height: 18 / 13,
    letterSpacing: 0,
    fontWeight: FontWeight.w400,
    fontVariations: [FontVariation('wght', 400)],
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// Secondary rows, times and hints.
  static const secondary = TextStyle(
    fontFamily: 'Inter',
    fontFamilyFallback: ['NotoSansSC'],
    fontSize: 12,
    height: 16 / 12,
    letterSpacing: 0,
    fontWeight: FontWeight.w400,
    fontVariations: [FontVariation('wght', 400)],
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// Labels, badges and axis ticks.
  static const caption = TextStyle(
    fontFamily: 'Inter',
    fontFamilyFallback: ['NotoSansSC'],
    fontSize: 11,
    height: 14 / 11,
    letterSpacing: 0,
    fontWeight: FontWeight.w400,
    fontVariations: [FontVariation('wght', 400)],
    fontFeatures: [FontFeature.tabularFigures()],
  );
}

/// Fixed row, field and control heights from `docs/design/01-tokens.md`.
abstract final class AppSizes {
  static const double row = 46;
  static const double rowTall = 64;
  static const double field = 34;
  static const double header = 64;
  static const double control = 30;
}

/// Corner radii from `docs/design/01-tokens.md` §4.
abstract final class AppRadii {
  static const double field = 5;
  static const double chip = 6;
  static const double button = 7;
  static const double block = 8;
  static const double segment = 9;
  static const double card = 10;
  static const double group = 12;
  static const double dialog = 12;
  static const double window = 14;
  static const double pill = 999;
}

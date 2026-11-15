import 'package:flutter/material.dart';

/// Neutral category colour for events without a category
/// (`docs/design/01-tokens.md` §1.3). Identical in light and dark themes.
const Color kUncategorizedColor = Color(0xFFC7C7CC);

/// Semantic palette from `docs/design/01-tokens.md`.
///
/// UI code reads tokens through this class (or `Theme.of`), never hex.
@immutable
class AppPalette {
  const AppPalette({
    required this.ink,
    required this.sub,
    required this.subWeak,
    required this.line,
    required this.lineStrong,
    required this.chip,
    required this.rail,
    required this.bg,
    required this.card,
    required this.accent,
    required this.accentTint,
    required this.danger,
    required this.dangerTint,
    required this.hover,
    required this.todayColumn,
    required this.festival,
    required this.festivalTint,
  });

  /// Light theme tokens.
  static const light = AppPalette(
    ink: Color(0xFF1C1C1E),
    sub: Color(0xFF8E8E93),
    subWeak: Color(0xFFC7C7CC),
    line: Color(0xFFEDEDF0),
    lineStrong: Color(0xFFDCDCE1),
    chip: Color(0xFFF2F2F5),
    rail: Color(0xFFF7F7F9),
    bg: Color(0xFFFFFFFF),
    card: Color(0xFFFFFFFF),
    accent: Color(0xFF007AFF),
    accentTint: Color(0x1C007AFF),
    danger: Color(0xFFFF3B30),
    dangerTint: Color(0x0FFF3B30),
    hover: Color(0xFFF7F7F9),
    todayColumn: Color(0xFFFCFCFD),
    festival: Color(0xFFC22F2F),
    festivalTint: Color(0x1AC22F2F),
  );

  /// Dark theme tokens.
  static const dark = AppPalette(
    ink: Color(0xFFE9EBF0),
    sub: Color(0xFF8A919C),
    subWeak: Color(0xFF5A6068),
    line: Color(0x12FFFFFF),
    lineStrong: Color(0x24FFFFFF),
    chip: Color(0x0FFFFFFF),
    rail: Color(0xFF0C0D10),
    bg: Color(0xFF101114),
    card: Color(0xFF1B1E25),
    accent: Color(0xFF4DA3FF),
    accentTint: Color(0x294DA3FF),
    danger: Color(0xFFFF6B5E),
    dangerTint: Color(0x1AFF6B5E),
    hover: Color(0x0AFFFFFF),
    todayColumn: Color(0x08FFFFFF),
    festival: Color(0xFFFF8F8A),
    festivalTint: Color(0x1FFF8F8A),
  );

  /// Primary text and numerals.
  final Color ink;

  /// Secondary text, times and counts.
  final Color sub;

  /// Placeholders, empty states and free slots.
  final Color subWeak;

  /// Hairlines and in-component dividers.
  final Color line;

  /// Table rules, field borders and the timeline.
  final Color lineStrong;

  /// Fills, input backgrounds and secondary buttons.
  final Color chip;

  /// Icon rail background.
  final Color rail;

  /// Paper background.
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

  /// Today column background in week/day views.
  final Color todayColumn;

  /// Festival names and the "休" pill text.
  final Color festival;

  /// The "休" pill background.
  final Color festivalTint;

  /// Copy of this palette with a user-chosen [accent] and derived tint.
  AppPalette withAccent(Color accent) => AppPalette(
    ink: ink,
    sub: sub,
    subWeak: subWeak,
    line: line,
    lineStrong: lineStrong,
    chip: chip,
    rail: rail,
    bg: bg,
    card: card,
    accent: accent,
    accentTint: accent.withValues(alpha: .11),
    danger: danger,
    dangerTint: dangerTint,
    hover: hover,
    todayColumn: todayColumn,
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
    fontWeight: FontWeight.w700,
    fontVariations: [FontVariation('wght', 700)],
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// Body copy, inputs and list rows.
  static const body = TextStyle(
    fontFamily: 'Inter',
    fontFamilyFallback: ['NotoSansSC'],
    fontSize: 13,
    height: 18 / 13,
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
    fontWeight: FontWeight.w400,
    fontVariations: [FontVariation('wght', 400)],
    fontFeatures: [FontFeature.tabularFigures()],
  );
}

/// Corner radii from `docs/design/01-tokens.md` §4.
abstract final class AppRadii {
  static const double field = 5;
  static const double chip = 6;
  static const double button = 7;
  static const double block = 8;
  static const double segment = 9;
  static const double card = 10;
  static const double dialog = 12;
  static const double window = 14;
  static const double pill = 999;
}

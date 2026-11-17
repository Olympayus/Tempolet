import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// Design grid every [AppIcon] path is authored on (the same 24×24 as
/// Lucide, `docs/design/01-tokens.md` §7).
const double _iconGrid = 24;

/// Shared key-icon stroke weight (`docs/design/01-tokens.md` §7): 1.75 in
/// grid units, round caps and joins.
const double _strokeWidth = 1.75;

/// Glyph carried by an [AppIcon]; one per self-drawn key icon.
enum AppIconGlyph {
  calendar,
  bell,
  settings,
  plus,
  chevronLeft,
  chevronRight,
  check,
  trash,
}

/// Self-drawn key icons with a 1.75 round stroke
/// (`docs/design/01-tokens.md` §7).
///
/// The eight glyphs below replace Lucide in the shell rail, the calendar
/// header and the reminders header. Every other icon stays on
/// `lucide_icons_flutter`; the exception list lives in §7 of the tokens doc.
///
/// Colors default to the theme's `ink` token; pass [color] to override (the
/// rail and primary buttons do). The painter works on a 24×24 grid and
/// scales to [size], so the whole widget is exactly `size × size`.
class AppIcon extends StatelessWidget {
  const AppIcon.calendar({super.key, this.size = 18, this.color})
    : glyph = AppIconGlyph.calendar;

  const AppIcon.bell({super.key, this.size = 18, this.color})
    : glyph = AppIconGlyph.bell;

  const AppIcon.settings({super.key, this.size = 18, this.color})
    : glyph = AppIconGlyph.settings;

  const AppIcon.plus({super.key, this.size = 18, this.color})
    : glyph = AppIconGlyph.plus;

  const AppIcon.chevronLeft({super.key, this.size = 18, this.color})
    : glyph = AppIconGlyph.chevronLeft;

  const AppIcon.chevronRight({super.key, this.size = 18, this.color})
    : glyph = AppIconGlyph.chevronRight;

  const AppIcon.check({super.key, this.size = 18, this.color})
    : glyph = AppIconGlyph.check;

  const AppIcon.trash({super.key, this.size = 18, this.color})
    : glyph = AppIconGlyph.trash;

  /// Which glyph to paint.
  final AppIconGlyph glyph;

  /// Edge length of the square paint box.
  final double size;

  /// Explicit stroke color; defaults to the theme's `ink` token.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _AppIconPainter(glyph, color ?? _defaultColor(context)),
    );
  }
}

Color _defaultColor(BuildContext context) {
  final theme = Theme.of(context);
  return (theme.brightness == Brightness.light
          ? AppPalette.light
          : AppPalette.dark)
      .withAccent(theme.colorScheme.primary)
      .ink;
}

class _AppIconPainter extends CustomPainter {
  const _AppIconPainter(this.glyph, this.color);

  final AppIconGlyph glyph;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / _iconGrid;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = _strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas
      ..save()
      ..scale(scale, scale)
      ..drawPath(_pathFor(glyph), paint)
      ..restore();
  }

  @override
  bool shouldRepaint(_AppIconPainter oldDelegate) =>
      oldDelegate.glyph != glyph || oldDelegate.color != color;
}

Path _pathFor(AppIconGlyph glyph) => switch (glyph) {
  AppIconGlyph.calendar => _calendarPath,
  AppIconGlyph.bell => _bellPath,
  AppIconGlyph.settings => _settingsPath,
  AppIconGlyph.plus => _plusPath,
  AppIconGlyph.chevronLeft => _chevronLeftPath,
  AppIconGlyph.chevronRight => _chevronRightPath,
  AppIconGlyph.check => _checkPath,
  AppIconGlyph.trash => _trashPath,
};

/// Body plus two hangers and the header rule (Lucide's `calendar`).
final Path _calendarPath = Path()
  ..addRRect(
    RRect.fromRectAndRadius(
      const Rect.fromLTWH(3.5, 5, 17, 15.5),
      const Radius.circular(2),
    ),
  )
  ..moveTo(8, 3)
  ..lineTo(8, 7)
  ..moveTo(16, 3)
  ..lineTo(16, 7)
  ..moveTo(3.5, 9.5)
  ..lineTo(20.5, 9.5);

/// Domed bell with a flat rim and clapper (Lucide's `bell`).
final Path _bellPath = Path()
  ..moveTo(18, 17)
  ..cubicTo(18, 13.5, 18, 12, 18, 8)
  ..cubicTo(18, 4.7, 15.3, 3, 12, 3)
  ..cubicTo(8.7, 3, 6, 4.7, 6, 8)
  ..cubicTo(6, 12, 6, 13.5, 6, 17)
  ..moveTo(4, 17)
  ..lineTo(20, 17)
  ..moveTo(10.2, 20)
  ..quadraticBezierTo(12, 22.2, 13.8, 20);

/// Three sliders with vertical handles (Lucide's `sliders-horizontal`).
final Path _settingsPath = Path()
  ..moveTo(3.5, 6)
  ..lineTo(7.5, 6)
  ..moveTo(10.5, 6)
  ..lineTo(20.5, 6)
  ..moveTo(9, 3.8)
  ..lineTo(9, 8.2)
  ..moveTo(3.5, 12)
  ..lineTo(13.5, 12)
  ..moveTo(16.5, 12)
  ..lineTo(20.5, 12)
  ..moveTo(15, 9.8)
  ..lineTo(15, 14.2)
  ..moveTo(3.5, 18)
  ..lineTo(5.5, 18)
  ..moveTo(8.5, 18)
  ..lineTo(20.5, 18)
  ..moveTo(7, 15.8)
  ..lineTo(7, 20.2);

final Path _plusPath = Path()
  ..moveTo(12, 5)
  ..lineTo(12, 19)
  ..moveTo(5, 12)
  ..lineTo(19, 12);

final Path _chevronLeftPath = Path()
  ..moveTo(14.5, 6)
  ..lineTo(8.5, 12)
  ..lineTo(14.5, 18);

final Path _chevronRightPath = Path()
  ..moveTo(9.5, 6)
  ..lineTo(15.5, 12)
  ..lineTo(9.5, 18);

final Path _checkPath = Path()
  ..moveTo(4.5, 12.5)
  ..lineTo(9.5, 17.5)
  ..lineTo(19.5, 6.5);

/// Can with lid, handle and two ribs (Lucide's `trash-2`).
final Path _trashPath = Path()
  ..moveTo(3.5, 6.5)
  ..lineTo(20.5, 6.5)
  ..moveTo(6, 6.5)
  ..lineTo(6, 18.5)
  ..quadraticBezierTo(6, 20.5, 8, 20.5)
  ..lineTo(16, 20.5)
  ..quadraticBezierTo(18, 20.5, 18, 18.5)
  ..lineTo(18, 6.5)
  ..moveTo(9.5, 6.5)
  ..lineTo(9.5, 4.6)
  ..quadraticBezierTo(9.5, 3.2, 10.9, 3.2)
  ..lineTo(13.1, 3.2)
  ..quadraticBezierTo(14.5, 3.2, 14.5, 4.6)
  ..lineTo(14.5, 6.5)
  ..moveTo(10.2, 10)
  ..lineTo(10.2, 17)
  ..moveTo(13.8, 10)
  ..lineTo(13.8, 17);

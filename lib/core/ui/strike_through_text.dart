import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// Hairline thickness of the strike-through line.
const double _strikeWidth = 1;

/// Strikethrough title for retained completed rows: a 1px line sweeps from
/// left to right as [progress] moves from 0 to 1.
///
/// The line is measured with the same [style], text direction, [maxLines] and
/// width as the rendered [Text], so it never runs past an ellipsized title
/// (including the Chinese fallback font). If measuring fails, it falls back to
/// the full, unwrapped text width.
class StrikeThroughText extends StatelessWidget {
  const StrikeThroughText({
    super.key,
    required this.text,
    required this.style,
    required this.progress,
    this.maxLines = 1,
  });

  final String text;
  final TextStyle style;

  /// Sweep position, 0..1.
  final double progress;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final palette = _paletteOf(context);
    final lineColor = style.color ?? palette.sub;
    final clampedProgress = progress.clamp(0.0, 1.0).toDouble();
    final textDirection = Directionality.of(context);
    final textScaler = MediaQuery.textScalerOf(context);
    final locale = Localizations.maybeLocaleOf(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final metrics = _measure(
          text: text,
          style: style,
          textDirection: textDirection,
          textScaler: textScaler,
          locale: locale,
          maxLines: maxLines,
          maxWidth: constraints.maxWidth,
        );
        return Stack(
          children: [
            Text(
              text,
              style: style,
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
            ),
            Positioned(
              left: 0,
              top: 0,
              width: metrics.width,
              height: metrics.height,
              child: CustomPaint(
                painter: StrikeLinePainter(
                  progress: clampedProgress,
                  color: lineColor,
                  width: metrics.width,
                  y: metrics.height / 2,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Paints the strike-through line from x=0 to `width × progress`.
class StrikeLinePainter extends CustomPainter {
  const StrikeLinePainter({
    required this.progress,
    required this.color,
    required this.width,
    required this.y,
  });

  /// Sweep position, 0..1.
  final double progress;
  final Color color;

  /// Measured text width; the line never exceeds it.
  final double width;

  /// Vertical centre of the line inside the paint box.
  final double y;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || width <= 0) return;
    final paint = Paint()
      ..color = color
      ..strokeWidth = _strikeWidth;
    canvas.drawLine(Offset(0, y), Offset(width * progress, y), paint);
  }

  @override
  bool shouldRepaint(StrikeLinePainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.color != color ||
      oldDelegate.width != width ||
      oldDelegate.y != y;
}

class _TextMetrics {
  const _TextMetrics(this.width, this.height);

  final double width;
  final double height;
}

_TextMetrics _measure({
  required String text,
  required TextStyle style,
  required TextDirection textDirection,
  required TextScaler textScaler,
  required Locale? locale,
  required int maxLines,
  required double maxWidth,
}) {
  TextPainter newPainter() => TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: textDirection,
    textScaler: textScaler,
    locale: locale,
    maxLines: maxLines,
    ellipsis: '…',
  );
  try {
    final bounded = newPainter()..layout(maxWidth: maxWidth);
    final metrics = _TextMetrics(bounded.width, bounded.height);
    bounded.dispose();
    return metrics;
  } catch (_) {
    // Fall back to the full, unwrapped text width.
    try {
      final unbounded = newPainter()..layout();
      final metrics = _TextMetrics(unbounded.width, unbounded.height);
      unbounded.dispose();
      return metrics;
    } catch (_) {
      return const _TextMetrics(0, 0);
    }
  }
}

AppPalette _paletteOf(BuildContext context) {
  final theme = Theme.of(context);
  return (theme.brightness == Brightness.light
          ? AppPalette.light
          : AppPalette.dark)
      .withAccent(theme.colorScheme.primary);
}

import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/ui/app_hairline.dart';
import '../../core/utils/dates.dart';

/// Vertical scale of the time grid. Shared by day and week views.
const double kHourHeight = 68;

double minuteToY(int minute) => minute * kHourHeight / 60;

int yToMinute(double dy) => snapMinutes((dy * 60 / kHourHeight).round());

/// Snapped, ordered plan range from a raw drag (design spec §3.1: 5-minute
/// suction, end strictly after start).
({int start, int end}) selectionFromDrag(int a, int b) {
  final start = snapMinutes(a < b ? a : b);
  final end = snapMinutes(a < b ? b : a);
  return (start: start, end: end);
}

/// Number of whole hours shown in the full-day grid.
const int kHoursInDay = 24;

/// Width of the hour-label gutter along the left edge of the time grid.
/// 44px keeps `07:00` on one line with breathing room after the tick.
const double kAxisGutter = 44;

/// Vertical offset of the default viewport (07:00).
const double kDefaultScrollOffset = 7 * kHourHeight;

/// Full-height grid canvas with hour rules and labels, used by the day and
/// week views.
class HourGrid extends StatelessWidget {
  const HourGrid({
    super.key,
    this.labelBuilder,
    this.gutterWidth = kAxisGutter,
    this.labelRightPadding = 6,
    this.gutterColor,
  });

  final Widget Function(BuildContext context, int hour)? labelBuilder;
  final double gutterWidth;

  /// Right padding inside the label gutter. The reminders left column uses 0
  /// so an 11px `HH:MM` label plus its `left: 8` inset fits in a 40px gutter.
  final double labelRightPadding;

  /// Background of the hour-label gutter. Week and day views pass the side
  /// surface; the reminders timeline leaves it transparent.
  final Color? gutterColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette =
        (theme.brightness == Brightness.light
                ? AppPalette.light
                : AppPalette.dark)
            .withAccent(theme.colorScheme.primary);
    return SizedBox(
      height: kHoursInDay * kHourHeight,
      child: Stack(
        children: [
          if (gutterColor != null)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: gutterWidth,
              child: Container(
                key: const ValueKey('hour-grid-gutter'),
                decoration: BoxDecoration(
                  color: gutterColor,
                  border: Border(right: BorderSide(color: palette.line)),
                ),
              ),
            ),
          for (var hour = 0; hour < kHoursInDay; hour++)
            Positioned(
              top: hour * kHourHeight,
              left: 0,
              right: 0,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: gutterWidth,
                    child: Padding(
                      padding: EdgeInsets.only(right: labelRightPadding),
                      child: labelBuilder != null
                          ? labelBuilder!(context, hour)
                          : FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerRight,
                              child: Text(
                                '${hour.toString().padLeft(2, '0')}:00',
                                textAlign: TextAlign.right,
                                style: AppTextStyles.caption.copyWith(
                                  color: palette.sub,
                                ),
                              ),
                            ),
                    ),
                  ),
                  Expanded(child: AppHairline(color: palette.lineStrong)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

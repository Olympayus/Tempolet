import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/utils/dates.dart';

/// Vertical scale of the time grid. Shared by day and week views.
const double kHourHeight = 34;

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
const double kAxisGutter = 34;

/// Vertical offset of the default viewport (07:00).
const double kDefaultScrollOffset = 7 * kHourHeight;

/// Full-height grid canvas with hour rules and labels, used by the day and
/// week views.
class HourGrid extends StatelessWidget {
  const HourGrid({
    super.key,
    this.labelBuilder,
    this.gutterWidth = kAxisGutter,
  });

  final Widget Function(BuildContext context, int hour)? labelBuilder;
  final double gutterWidth;

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
                      padding: const EdgeInsets.only(right: 6),
                      child: labelBuilder != null
                          ? labelBuilder!(context, hour)
                          : Text(
                              '${hour.toString().padLeft(2, '0')}:00',
                              textAlign: TextAlign.right,
                              style: AppTextStyles.caption.copyWith(
                                color: palette.sub,
                              ),
                            ),
                    ),
                  ),
                  Expanded(
                    child: Divider(
                      height: 1,
                      thickness: 0.6,
                      color: theme.colorScheme.outlineVariant.withValues(
                        alpha: .5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/ui/app_hairline.dart';
import '../../core/utils/dates.dart';
import '../../core/utils/formats.dart';
import '../calendar/calendar_state.dart';
import '../calendar/time_grid.dart';

/// Fixed width of the reminders page's left column (`04-reminders.md` §2).
const double kRemindersLeftColumnWidth = 204;

/// Mini-calendar footprint reserved above the timeline (Task 15 replaces the
/// placeholder with `MiniMonthCalendar`).
const double _miniCalendarWidth = 180;
const double _miniCalendarHeight = 220;

/// Left column of the reminders page: the selected day's mini calendar and a
/// timeline skeleton. The full `MiniMonthCalendar` and event blocks arrive in
/// Task 15; this task fixes the column width, the 20px rule and the 40px axis
/// gutter so the page skeleton is correct.
class RemindersLeftColumn extends ConsumerStatefulWidget {
  const RemindersLeftColumn({super.key});

  @override
  ConsumerState<RemindersLeftColumn> createState() =>
      _RemindersLeftColumnState();
}

class _RemindersLeftColumnState extends ConsumerState<RemindersLeftColumn> {
  final _scroll = ScrollController(initialScrollOffset: kDefaultScrollOffset);

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette =
        (theme.brightness == Brightness.light
                ? AppPalette.light
                : AppPalette.dark)
            .withAccent(theme.colorScheme.primary);
    final locale = Localizations.localeOf(context);
    final day = dateOnly(ref.watch(todayProvider));

    return Container(
      key: const ValueKey('reminders-left-column'),
      width: kRemindersLeftColumnWidth,
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: palette.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            // The 1px right border consumes one logical pixel inside the
            // 204px column, so the 180px calendar keeps an 11px right inset.
            padding: const EdgeInsets.fromLTRB(12, 16, 11, 0),
            child: SizedBox(
              key: const ValueKey('reminders-mini-calendar-placeholder'),
              width: _miniCalendarWidth,
              height: _miniCalendarHeight,
              child: Placeholder(color: palette.lineStrong, strokeWidth: 1),
            ),
          ),
          const SizedBox(height: 20),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: AppHairline(),
          ),
          SizedBox(
            height: 34,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${AppFormats.monthDay(locale, day)} '
                  '${AppFormats.weekday(locale, day)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.section.copyWith(color: palette.ink),
                ),
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              key: const ValueKey('reminders-timeline'),
              controller: _scroll,
              child: SizedBox(
                height: kHoursInDay * kHourHeight,
                child: HourGrid(
                  gutterWidth: 40,
                  labelBuilder: (context, hour) => Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Text(
                      '${hour.toString().padLeft(2, '0')}:00',
                      maxLines: 1,
                      textAlign: TextAlign.left,
                      style: AppTextStyles.caption.copyWith(color: palette.sub),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

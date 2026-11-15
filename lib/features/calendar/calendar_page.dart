import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'calendar_header.dart';
import 'calendar_state.dart';
import 'day_view.dart';
import 'month_view.dart';
import 'week_view.dart';

/// Cross-fade length between calendar views (`docs/design/08-motion.md`).
const kCalendarViewFadeDuration = Duration(milliseconds: 120);

class CalendarPage extends ConsumerWidget {
  const CalendarPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(calendarViewModeProvider);
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    final body = switch (mode) {
      CalendarViewMode.month => const MonthView(),
      CalendarViewMode.week => const WeekView(),
      CalendarViewMode.day => const DayView(),
    };

    return Scaffold(
      key: const ValueKey('calendar-page'),
      body: Column(
        children: [
          // The header stays outside the switcher: it must not cross-fade.
          const CalendarHeader(),
          Expanded(
            child: AnimatedSwitcher(
              duration: reduceMotion
                  ? Duration.zero
                  : kCalendarViewFadeDuration,
              child: KeyedSubtree(key: ValueKey(mode), child: body),
            ),
          ),
        ],
      ),
    );
  }
}

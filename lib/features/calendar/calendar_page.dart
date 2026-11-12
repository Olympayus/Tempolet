import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'calendar_state.dart';
import 'day_view.dart';
import 'month_view.dart';
import 'week_view.dart';

class CalendarPage extends ConsumerWidget {
  const CalendarPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(calendarViewModeProvider);

    return Scaffold(
      key: const ValueKey('calendar-page'),
      body: switch (mode) {
        CalendarViewMode.month => const MonthView(),
        CalendarViewMode.week => const WeekView(),
        CalendarViewMode.day => const DayView(),
      },
    );
  }
}

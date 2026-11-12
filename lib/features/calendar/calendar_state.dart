import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/dates.dart';

enum CalendarViewMode { month, week, day }

final calendarViewModeProvider =
    NotifierProvider<CalendarViewModeController, CalendarViewMode>(
  CalendarViewModeController.new,
);

class CalendarViewModeController extends Notifier<CalendarViewMode> {
  @override
  CalendarViewMode build() => CalendarViewMode.month;

  void set(CalendarViewMode mode) => state = mode;
}

final selectedDayProvider =
    NotifierProvider<SelectedDayController, DateTime>(SelectedDayController.new);

class SelectedDayController extends Notifier<DateTime> {
  @override
  DateTime build() => dateOnly(DateTime.now());

  void select(DateTime day) => state = dateOnly(day);
}

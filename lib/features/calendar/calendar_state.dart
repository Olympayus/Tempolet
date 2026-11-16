import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/prefs.dart';
import '../../core/utils/dates.dart';
import 'month_model.dart';

/// The wall clock used to highlight "today". Overridden in tests so goldens do
/// not depend on the calendar date they run on.
final todayProvider = Provider<DateTime>((ref) => DateTime.now());

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

final selectedDayProvider = NotifierProvider<SelectedDayController, DateTime>(
  SelectedDayController.new,
);

class SelectedDayController extends Notifier<DateTime> {
  @override
  DateTime build() => dateOnly(ref.watch(todayProvider));

  void select(DateTime day) => state = dateOnly(day);

  /// Moves the selection by [delta] calendar days (DST-safe).
  void shiftDays(int delta) =>
      state = DateTime(state.year, state.month, state.day + delta);

  /// Moves the selection by [delta] months, clamping the day of month.
  void shiftMonths(int delta) =>
      state = clampDayOfMonth(state.year, state.month + delta, state.day);
}

/// Whether the calendar sidebar is open; null until the user first toggles it.
final sidebarPreferenceProvider =
    NotifierProvider<SidebarPreferenceController, bool?>(
      SidebarPreferenceController.new,
    );

class SidebarPreferenceController extends Notifier<bool?> {
  static const prefKey = 'sidebar_open';

  @override
  bool? build() => ref.watch(sharedPreferencesProvider).getBool(prefKey);

  void set(bool open) {
    state = open;
    ref.read(sharedPreferencesProvider).setBool(prefKey, open);
  }
}

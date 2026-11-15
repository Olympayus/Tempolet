/// Calendar month maths shared by the header and month view.
///
/// All date arithmetic goes through [DateTime] constructors (never `Duration`)
/// so results stay correct across daylight-saving transitions.
library;

DateTime firstDayOfMonth(DateTime month) =>
    DateTime(month.year, month.month, 1);

/// Last day number of [year]/[month]; accepts out-of-range months, which
/// [DateTime] normalises (e.g. month 13 means January of the next year).
int _daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;

/// [day] clamped to a real date in [month], keeping the day when possible.
DateTime clampDayOfMonth(int year, int month, int day) {
  final maxDay = _daysInMonth(year, month);
  return DateTime(year, month, day.clamp(1, maxDay));
}

/// Monday-first rows for [month], containing only dates of the target month.
///
/// Missing leading/trailing cells are `null`; there are never dates from
/// adjacent months. Row count follows the month's real week span (4–6 rows).
List<List<DateTime?>> monthWeeks(DateTime month) {
  final first = firstDayOfMonth(month);
  final dayCount = _daysInMonth(first.year, first.month);
  final leadingBlanks = first.weekday - DateTime.monday;
  final rowCount = ((leadingBlanks + dayCount) / 7).ceil();

  return List<List<DateTime?>>.generate(rowCount, (row) {
    return List<DateTime?>.generate(7, (column) {
      final day = row * 7 + column - leadingBlanks;
      if (day < 0 || day >= dayCount) return null;
      return DateTime(first.year, first.month, day + 1);
    });
  });
}

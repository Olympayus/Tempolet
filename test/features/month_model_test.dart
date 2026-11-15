import 'package:flutter_test/flutter_test.dart';
import 'package:tempolet/features/calendar/month_model.dart';

void main() {
  group('monthWeeks', () {
    test('November 2026 needs six rows and no adjacent months', () {
      final weeks = monthWeeks(DateTime(2026, 11, 1));
      expect(weeks, hasLength(6));
      expect(weeks.first.whereType<DateTime>().single, DateTime(2026, 11, 1));
      expect(weeks.last.whereType<DateTime>().single, DateTime(2026, 11, 30));
    });

    test('February 2028 is five rows', () {
      expect(monthWeeks(DateTime(2028, 2, 1)), hasLength(5));
    });

    test('every row is seven Monday-first cells of in-month dates only', () {
      final weeks = monthWeeks(DateTime(2026, 11, 15));

      expect(weeks.every((week) => week.length == 7), isTrue);
      final days = weeks.expand((week) => week.whereType<DateTime>()).toList();
      expect(days, hasLength(30));
      expect(days.every((day) => day.year == 2026 && day.month == 11), isTrue);
      // 2026-11-01 is a Sunday, so the first six cells are blank.
      expect(weeks.first.take(6), everyElement(isNull));
      expect(weeks.first[6], DateTime(2026, 11, 1));
    });

    test('a month that starts on Monday has no leading padding', () {
      // 2026-06-01 is a Monday.
      final weeks = monthWeeks(DateTime(2026, 6, 1));

      expect(weeks, hasLength(5));
      expect(weeks.first.first, DateTime(2026, 6, 1));
      expect(weeks.first.whereType<DateTime>(), hasLength(7));
    });
  });

  group('clampDayOfMonth', () {
    test('clampDayOfMonth keeps the day when possible', () {
      expect(clampDayOfMonth(2026, 2, 31), DateTime(2026, 2, 28));
      expect(clampDayOfMonth(2028, 2, 31), DateTime(2028, 2, 29));
    });

    test('clamps to the end of shorter months', () {
      expect(clampDayOfMonth(2026, 4, 31), DateTime(2026, 4, 30));
      expect(clampDayOfMonth(2026, 11, 11), DateTime(2026, 11, 11));
    });
  });

  test('firstDayOfMonth normalises to the first', () {
    expect(
      firstDayOfMonth(DateTime(2026, 11, 11, 5, 6)),
      DateTime(2026, 11, 1),
    );
  });
}

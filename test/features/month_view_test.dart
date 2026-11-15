import 'package:flutter_test/flutter_test.dart';
import 'package:tempolet/features/calendar/month_model.dart';

void main() {
  group('month grid maths', () {
    test('firstDayOfMonth normalises to the first', () {
      expect(
        firstDayOfMonth(DateTime(2026, 11, 11, 5, 6)),
        DateTime(2026, 11, 1),
      );
    });

    test('2026-11 shrinks to six Monday-first rows of in-month dates', () {
      final weeks = monthWeeks(DateTime(2026, 11));

      expect(weeks, hasLength(6));
      expect(weeks.every((row) => row.length == 7), isTrue);
      final days = weeks.expand((row) => row.whereType<DateTime>()).toList();
      expect(days.first, DateTime(2026, 11, 1));
      expect(days.last, DateTime(2026, 11, 30));
      expect(days, hasLength(30));
    });

    test('2028-02 (leap) keeps all 29 in-month days', () {
      final weeks = monthWeeks(DateTime(2028, 2));
      final days = weeks.expand((row) => row.whereType<DateTime>()).toList();

      expect(days.where((day) => day.month == 2), hasLength(29));
    });
  });
}

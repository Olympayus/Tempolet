import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tempolet/core/utils/dates.dart';

void main() {
  test('dateOnly drops the time part', () {
    expect(dateOnly(DateTime(2026, 11, 11, 23, 59)), DateTime(2026, 11, 11));
    expect(dateOnly(DateTime(2026, 1, 1)), DateTime(2026, 1, 1));
  });

  test('timeToMinutes converts a TimeOfDay', () {
    expect(timeToMinutes(const TimeOfDay(hour: 8, minute: 5)), 485);
    expect(timeToMinutes(const TimeOfDay(hour: 0, minute: 0)), 0);
    expect(timeToMinutes(const TimeOfDay(hour: 23, minute: 59)), 1439);
  });

  test('minutesToTimeOfDay is the inverse of timeToMinutes', () {
    expect(minutesToTimeOfDay(485), const TimeOfDay(hour: 8, minute: 5));
    // 1440 (end-of-day sentinel) is clamped; TimeOfDay cannot represent 24:00.
    expect(minutesToTimeOfDay(1440), const TimeOfDay(hour: 23, minute: 59));
  });

  test('snapMinutes rounds to the nearest step', () {
    expect(snapMinutes(7), 5);
    expect(snapMinutes(8), 10);
    expect(snapMinutes(0), 0);
    expect(snapMinutes(12), 10);
  });

  test('snapMinutes clamps into 0..1440', () {
    expect(snapMinutes(-3), 0);
    expect(snapMinutes(1439), 1440);
    expect(snapMinutes(1450), 1440);
  });

  test('formatMinuteOfDay renders the 24:00 sentinel', () {
    expect(formatMinuteOfDay(540), '09:00');
    expect(formatMinuteOfDay(1439), '23:59');
    expect(formatMinuteOfDay(1440), '24:00');
  });

  test('snapMinutes honours a custom step', () {
    expect(snapMinutes(7, step: 15), 0);
    expect(snapMinutes(8, step: 15), 15);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:tempolet/data/database/database.dart';
import 'package:tempolet/data/models/event_status.dart';

Event _event({
  required DateTime date,
  bool isCompleted = false,
}) {
  final now = DateTime(2026, 11, 11);
  return Event(
    id: 'e1',
    title: 't',
    note: '',
    kind: 'reminder',
    date: date,
    startMinute: 540,
    importance: 0,
    isCompleted: isCompleted,
    completedAt: isCompleted ? now : null,
    notificationId: 1,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  final today = DateTime(2026, 11, 11, 15, 0);

  test('yesterday unfinished is overdue', () {
    final e = _event(date: DateTime(2026, 11, 10, 9, 0));
    expect(eventStatus(e, today), EventStatus.overdue);
  });

  test('today with a passed start stays pending until the day ends', () {
    final e = _event(date: DateTime(2026, 11, 11, 9, 0));
    expect(eventStatus(e, today), EventStatus.pending);
  });

  test('completed events are done regardless of date', () {
    final e = _event(date: DateTime(2026, 11, 10, 9, 0), isCompleted: true);
    expect(eventStatus(e, today), EventStatus.done);
  });
}

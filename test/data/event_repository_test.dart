import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tempolet/core/utils/dates.dart';
import 'package:tempolet/data/database/database.dart';
import 'package:tempolet/data/repositories/event_repository.dart';

void main() {
  late AppDatabase db;
  late EventRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = EventRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('created event appears in watchDay', () async {
    final day = DateTime(2026, 11, 11);
    final created = await repo.create(
      title: 'Product sync',
      kind: 'reminder',
      date: day,
      startMinute: 540,
      reminderOffsetMinutes: 10,
    );

    final events = await repo.watchDay(day).first;
    expect(events, hasLength(1));
    expect(events.single.id, created.id);
    expect(events.single.startMinute, 540);
    expect(events.single.notificationId, stableNotificationId(created.id));
  });

  test('watchDay sorts by start minute with unscheduled last', () async {
    final day = DateTime(2026, 11, 11);
    await repo.create(title: 'late', kind: 'reminder', date: day, startMinute: 600);
    await repo.create(title: 'early', kind: 'reminder', date: day, startMinute: 540);
    await repo.create(title: 'all-day', kind: 'plan', date: day);

    final events = await repo.watchDay(day).first;
    expect(events.map((e) => e.title), ['early', 'late', 'all-day']);
  });

  test('setCompleted persists completion and completedAt', () async {
    final day = DateTime(2026, 11, 11);
    final e = await repo.create(
      title: 'a',
      kind: 'reminder',
      date: day,
      startMinute: 540,
    );

    await repo.setCompleted(e.id, true);
    final reloaded = await repo.watchDay(day).first;
    expect(reloaded.single.isCompleted, isTrue);
    expect(reloaded.single.completedAt, isNotNull);

    await repo.setCompleted(e.id, false);
    final undone = await repo.watchDay(day).first;
    expect(undone.single.isCompleted, isFalse);
    expect(undone.single.completedAt, isNull);
  });

  test('reschedule moves the event and resets completion', () async {
    final day = DateTime(2026, 11, 11);
    final e = await repo.create(
      title: 'a',
      kind: 'reminder',
      date: day,
      startMinute: 540,
    );
    await repo.setCompleted(e.id, true);

    final nextDay = DateTime(2026, 11, 12);
    await repo.reschedule(e.id, nextDay);

    expect(await repo.watchDay(day).first, isEmpty);
    final moved = await repo.watchDay(nextDay).first;
    expect(moved.single.isCompleted, isFalse);
    expect(moved.single.completedAt, isNull);
  });

  test('softDelete hides the event from queries', () async {
    final day = DateTime(2026, 11, 11);
    final e = await repo.create(
      title: 'a',
      kind: 'reminder',
      date: day,
      startMinute: 540,
    );

    await repo.softDelete(e.id);
    expect(await repo.watchDay(day).first, isEmpty);
  });

  test('watchRange only returns events inside the range', () async {
    await repo.create(
        title: 'before', kind: 'reminder', date: DateTime(2026, 11, 10), startMinute: 540);
    await repo.create(
        title: 'inside', kind: 'reminder', date: DateTime(2026, 11, 11), startMinute: 540);
    await repo.create(
        title: 'after', kind: 'reminder', date: DateTime(2026, 11, 12), startMinute: 540);

    final events = await repo
        .watchRange(DateTime(2026, 11, 11), DateTime(2026, 11, 12))
        .first;
    expect(events.map((e) => e.title), ['inside']);
  });

  test('stableNotificationId is deterministic and non-negative', () {
    const uuid = '6f1c2b0e-1111-4c2a-9d3f-abcdefabcdef';
    expect(stableNotificationId(uuid), stableNotificationId(uuid));
    expect(stableNotificationId(uuid), isNonNegative);
    expect(stableNotificationId('$uuid-x'), isNot(stableNotificationId(uuid)));
  });
}

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tempolet/data/database/database.dart';
import 'package:tempolet/data/repositories/event_repository.dart';

void main() {
  late AppDatabase db;
  late EventRepository repo;
  final day = DateTime(2026, 11, 12);

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = EventRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  Future<Event> seed(String title) => repo.create(
    title: title,
    kind: 'reminder',
    date: day,
    startMinute: 540,
    reminderOffsetMinutes: 0,
  );

  Future<void> completeAt(String id, DateTime at) async {
    await (db.update(db.events)..where((t) => t.id.equals(id))).write(
      EventsCompanion(isCompleted: const Value(true), completedAt: Value(at)),
    );
  }

  test('watchRange hides completed events', () async {
    final event = await seed('A');
    await repo.setCompleted(event.id, true);

    expect(await repo.eventsOnDay(day), isEmpty);
    expect(
      await repo.watchRange(day, day.add(const Duration(days: 1))).first,
      isEmpty,
    );
  });

  test('watchRange still returns unfinished events', () async {
    await seed('Open');
    final done = await seed('Done');
    await repo.setCompleted(done.id, true);

    final events = await repo.eventsOnDay(day);
    expect(events.map((e) => e.title), ['Open']);
  });

  test('watchCompleted orders by completedAt desc', () async {
    final a = await seed('A');
    final b = await seed('B');
    await completeAt(a.id, DateTime(2026, 11, 12, 9));
    await completeAt(b.id, DateTime(2026, 11, 12, 11));

    final done = await repo.watchCompleted().first;
    expect(done.map((e) => e.title), ['B', 'A']);
  });

  test('watchCompleted excludes pending and soft-deleted events', () async {
    final pending = await seed('Pending');
    final deleted = await seed('Deleted');
    await completeAt(deleted.id, DateTime(2026, 11, 12, 10));
    await repo.softDelete(deleted.id);

    expect(await repo.watchCompleted().first, isEmpty);
    expect(pending.isCompleted, isFalse);
  });

  test('hardDelete removes the row', () async {
    final event = await seed('A');
    await completeAt(event.id, DateTime(2026, 11, 12, 10));

    await repo.hardDelete(event.id);

    expect(await repo.getById(event.id), isNull);
    expect(await repo.watchCompleted().first, isEmpty);
  });

  test('clearCompleted deletes only completed rows', () async {
    final pending = await seed('Open');
    final done = await seed('Done');
    final another = await seed('Another done');
    await completeAt(done.id, DateTime(2026, 11, 12, 10));
    await completeAt(another.id, DateTime(2026, 11, 12, 11));

    await repo.clearCompleted();

    final remaining = await db.select(db.events).get();
    expect(remaining.map((e) => e.id), [pending.id]);
  });
}

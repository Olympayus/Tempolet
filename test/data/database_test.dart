import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tempolet/data/database/database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('inserts an event and reads it back by date', () async {
    final day = DateTime(2026, 11, 11);
    await db.into(db.events).insert(
          EventsCompanion.insert(
            id: 'e1',
            title: 'Product sync',
            kind: 'reminder',
            date: day,
            notificationId: 42,
            createdAt: day,
            updatedAt: day,
            startMinute: const Value(540),
          ),
        );

    final rows = await (db.select(db.events)
          ..where((t) => t.date.equals(day)))
        .get();

    expect(rows, hasLength(1));
    expect(rows.single.title, 'Product sync');
    expect(rows.single.note, '');
    expect(rows.single.importance, 0);
    expect(rows.single.isCompleted, isFalse);
    expect(rows.single.notificationId, 42);
  });

  test('holiday is queryable by date', () async {
    final day = DateTime(2026, 10, 1);
    await db.into(db.holidays).insert(
          HolidaysCompanion.insert(date: day, name: '国庆节'),
        );

    final row = await (db.select(db.holidays)
          ..where((t) => t.date.equals(day)))
        .getSingle();

    expect(row.name, '国庆节');
  });
}

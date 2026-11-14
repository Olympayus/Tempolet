import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tempolet/data/database/database.dart';
import '../generated_migrations/schema.dart';

void main() {
  late SchemaVerifier verifier;

  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  test('v1 -> v2 keeps events and holidays', () async {
    final connection = await verifier.startAt(1);
    final db = AppDatabase(connection);

    final day = DateTime(2026, 11, 11);
    await db.into(db.events).insert(EventsCompanion.insert(
          id: 'e1',
          title: 'legacy',
          kind: 'reminder',
          date: day,
          notificationId: 1,
          createdAt: day,
          updatedAt: day,
        ));
    await db.into(db.holidays).insert(HolidaysCompanion.insert(
          date: DateTime(2026, 10, 1),
          name: '国庆节',
        ));

    await verifier.migrateAndValidate(db, 2);

    final event = await (db.select(db.events)
          ..where((t) => t.id.equals('e1')))
        .getSingle();
    expect(event.title, 'legacy');
    expect(event.categoryId, isNull);

    final holiday = await (db.select(db.holidays)
          ..where((t) => t.date.equals(DateTime(2026, 10, 1))))
        .getSingle();
    expect(holiday.name, '国庆节');
    expect(holiday.isWorkday, isFalse);
    expect(holiday.source, 'seed');
  });
}

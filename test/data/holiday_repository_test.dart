import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tempolet/data/database/database.dart';
import 'package:tempolet/data/repositories/holiday_repository.dart';

void main() {
  late AppDatabase db;
  late HolidayRepository holidays;
  late String json;

  setUpAll(() async {
    json = await File('assets/holidays/2026.json').readAsString();
  });

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    holidays = HolidayRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  Future<Holiday> rowFor(DateTime date) => (db.select(db.holidays)
        ..where((t) => t.date.equals(DateTime(date.year, date.month, date.day))))
      .getSingle();

  test('isWorkday falls back to Monday-Friday without seed data', () async {
    expect(await holidays.isWorkday(DateTime(2026, 11, 16)), isTrue); // Monday
    expect(await holidays.isWorkday(DateTime(2026, 11, 15)), isFalse); // Sunday
    expect(await db.select(db.holidays).get(), isEmpty);
  });

  test('seedFromJson applies the 2026 asset', () async {
    await holidays.seedFromJson(json);

    expect(await holidays.isWorkday(DateTime(2026, 10, 1)), isFalse); // 国庆放假
    expect(await holidays.isWorkday(DateTime(2026, 1, 4)), isTrue); // 调休上班
    expect(await holidays.isWorkday(DateTime(2026, 11, 16)), isTrue); // 普通周一
    expect(await holidays.isWorkday(DateTime(2026, 11, 15)), isFalse); // 普通周日

    final row = await rowFor(DateTime(2026, 10, 1));
    expect(row.name, '国庆节');
    expect(row.isWorkday, isFalse);
    expect(row.source, 'seed');
    expect(row.updatedAt, isNotNull);
  });

  test('seedFromJson is idempotent', () async {
    await holidays.seedFromJson(json);
    final first = await db.select(db.holidays).get();
    expect(first, hasLength(39));

    await holidays.seedFromJson(json);
    final second = await db.select(db.holidays).get();
    expect(second, hasLength(first.length));
  });

  test('seedFromJson rejects malformed data without writing rows', () async {
    await expectLater(
      holidays.seedFromJson(
        '{"year": 2026, "days": [{"name": "元旦", "date": "not-a-date", '
        '"isOffDay": true}]}',
      ),
      throwsFormatException,
    );
    expect(await db.select(db.holidays).get(), isEmpty);
  });

  test('manual override survives reseeding and clearManual restores seed',
      () async {
    await holidays.seedFromJson(json);

    await holidays.setManual(
      date: DateTime(2026, 10, 1),
      name: '自定义',
      isWorkday: true,
    );
    var row = await rowFor(DateTime(2026, 10, 1));
    expect(row.name, '自定义');
    expect(row.isWorkday, isTrue);
    expect(row.source, 'manual');
    expect(await holidays.isWorkday(DateTime(2026, 10, 1)), isTrue);

    // Re-seeding must not overwrite manual rows.
    await holidays.seedFromJson(json);
    row = await rowFor(DateTime(2026, 10, 1));
    expect(row.name, '自定义');
    expect(row.isWorkday, isTrue);
    expect(row.source, 'manual');

    await holidays.clearManual(DateTime(2026, 10, 1));
    row = await rowFor(DateTime(2026, 10, 1));
    expect(row.name, '国庆节');
    expect(row.isWorkday, isFalse);
    expect(row.source, 'seed');
  });

  test('manual rows without a seed counterpart are deleted by clearManual',
      () async {
    // [setManual] normalizes the time component to midnight.
    await holidays.setManual(
      date: DateTime(2026, 11, 16, 15, 30),
      name: '自定义上班',
      isWorkday: false,
    );
    expect(await holidays.isWorkday(DateTime(2026, 11, 16)), isFalse);
    expect((await rowFor(DateTime(2026, 11, 16))).source, 'manual');

    await holidays.clearManual(DateTime(2026, 11, 16));

    expect(await db.select(db.holidays).get(), isEmpty);
    expect(await holidays.isWorkday(DateTime(2026, 11, 16)), isTrue); // fallback
  });

  test('clearManual leaves seed rows untouched', () async {
    await holidays.seedFromJson(json);

    await holidays.clearManual(DateTime(2026, 10, 1));

    final row = await rowFor(DateTime(2026, 10, 1));
    expect(row.name, '国庆节');
    expect(row.source, 'seed');
    expect(await db.select(db.holidays).get(), hasLength(39));
  });

  test('watchYear filters by year and sorts by date', () async {
    await holidays.seedFromJson(json);
    await holidays.setManual(
      date: DateTime(2027, 1, 1),
      name: '自定义',
      isWorkday: true,
    );

    final rows2026 = await holidays.watchYear(2026).first;
    expect(rows2026, hasLength(39));
    expect(rows2026.every((h) => h.date.year == 2026), isTrue);
    final dates = rows2026.map((h) => h.date).toList();
    expect(dates, orderedEquals([...dates]..sort()));

    final rows2027 = await holidays.watchYear(2027).first;
    expect(rows2027.single.name, '自定义');

    expect(await holidays.watchYear(2025).first, isEmpty);
  });
}

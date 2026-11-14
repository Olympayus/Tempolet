import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tempolet/data/database/database.dart';
import 'package:tempolet/data/repositories/category_repository.dart';
import 'package:tempolet/data/repositories/event_repository.dart';

void main() {
  late AppDatabase db;
  late CategoryRepository cats;
  late EventRepository events;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    cats = CategoryRepository(db);
    events = EventRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('create trims the name and persists the category', () async {
    final cat = await cats.create(name: ' 工作 ', color: 0xFF007AFF);

    expect(cat.name, '工作');
    expect(cat.color, 0xFF007AFF);
    final all = await cats.watchAll().first;
    expect(all.single.id, cat.id);
    expect(all.single.name, '工作');
  });

  test('create rejects empty names', () async {
    await expectLater(cats.create(name: '   '), throwsArgumentError);
    expect(await cats.watchAll().first, isEmpty);
  });

  test('create rejects case-insensitive duplicate names', () async {
    await cats.create(name: '工作');
    await expectLater(
        cats.create(name: ' 工作 '), throwsA(isA<CategoryNameConflict>()));

    await cats.create(name: 'Work');
    await expectLater(
        cats.create(name: 'work'), throwsA(isA<CategoryNameConflict>()));
  });

  test('duplicate name is allowed after soft delete', () async {
    final cat = await cats.create(name: '工作');
    await cats.softDelete(cat.id);

    final again = await cats.create(name: '工作');
    expect((await cats.watchAll().first).single.id, again.id);
  });

  test('rename trims and rejects conflicts with other categories', () async {
    final a = await cats.create(name: 'a');
    final b = await cats.create(name: 'b');

    await cats.rename(b.id, ' c ');
    expect((await cats.watchAll().first).map((e) => e.name), ['a', 'c']);

    await cats.rename(b.id, ' b ');
    await expectLater(
        cats.rename(b.id, 'A'), throwsA(isA<CategoryNameConflict>()));
    await expectLater(cats.rename(a.id, '  '), throwsArgumentError);
  });

  test('setColor persists the color and can clear it', () async {
    final cat = await cats.create(name: '工作');

    await cats.setColor(cat.id, 0xFFFF3B30);
    expect((await cats.watchAll().first).single.color, 0xFFFF3B30);

    await cats.setColor(cat.id, null);
    expect((await cats.watchAll().first).single.color, isNull);
  });

  test('reorder changes the watchAll order', () async {
    final a = await cats.create(name: 'a');
    final b = await cats.create(name: 'b');
    final c = await cats.create(name: 'c');
    expect((await cats.watchAll().first).map((e) => e.name), ['a', 'b', 'c']);

    await cats.reorder([c.id, a.id, b.id]);

    expect((await cats.watchAll().first).map((e) => e.name), ['c', 'a', 'b']);
  });

  test('softDelete clears the category off events and hides the category',
      () async {
    final cat = await cats.create(name: '工作', color: 0xFF007AFF);
    final event = await events.create(
      title: 'a',
      kind: 'reminder',
      date: DateTime(2026, 11, 11),
      startMinute: 540,
      categoryId: cat.id,
    );
    expect((await events.getById(event.id))!.categoryId, cat.id);

    await cats.softDelete(cat.id);

    expect((await events.getById(event.id))!.categoryId, isNull);
    expect(await cats.watchAll().first, isEmpty);
  });

  test('setCategory assigns and clears the category on an event', () async {
    final cat = await cats.create(name: '工作');
    final event = await events.create(
      title: 'a',
      kind: 'reminder',
      date: DateTime(2026, 11, 11),
    );

    await events.setCategory(event.id, cat.id);
    expect((await events.getById(event.id))!.categoryId, cat.id);

    await events.setCategory(event.id, null);
    expect((await events.getById(event.id))!.categoryId, isNull);
  });
}

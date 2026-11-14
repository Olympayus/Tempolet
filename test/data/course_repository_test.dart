import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tempolet/data/database/database.dart';
import 'package:tempolet/data/repositories/course_repository.dart';

void main() {
  late AppDatabase db;
  late CourseRepository courses;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    courses = CourseRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  Future<Course> addCourse({
    String name = '数学',
    int weekday = 1,
    int startMinute = 480,
    int endMinute = 570,
    String weekPattern = '1-16',
    String room = '',
    int? color,
    bool enabled = true,
  }) {
    return courses.create(
      name: name,
      weekday: weekday,
      startMinute: startMinute,
      endMinute: endMinute,
      weekPattern: weekPattern,
      room: room,
      color: color,
      enabled: enabled,
    );
  }

  test('create persists the course with defaults', () async {
    final course = await addCourse(
      name: '数学',
      weekday: 1,
      startMinute: 480,
      endMinute: 570,
      weekPattern: '1-16,18',
      room: 'A101',
      color: 0xFF007AFF,
    );

    expect(course.id, isNotEmpty);
    expect(course.name, '数学');
    expect(course.weekday, 1);
    expect(course.startMinute, 480);
    expect(course.endMinute, 570);
    expect(course.weekPattern, '1-16,18');
    expect(course.room, 'A101');
    expect(course.color, 0xFF007AFF);
    expect(course.enabled, isTrue);
    expect(course.deletedAt, isNull);

    final plain = await addCourse(name: '语文', weekday: 2);
    expect(plain.room, '');
    expect(plain.color, isNull);
    expect(plain.enabled, isTrue);
  });

  test('watchAll and watchByWeekday return non-deleted courses', () async {
    final monday = await addCourse(name: '数学', weekday: 1, startMinute: 480);
    final mondayLater = await addCourse(
      name: '英语',
      weekday: 1,
      startMinute: 600,
      endMinute: 690,
    );
    await addCourse(name: '语文', weekday: 2, startMinute: 480);

    expect(
      (await courses.watchAll().first).map((c) => c.id),
      containsAll([monday.id, mondayLater.id]),
    );
    final mondays = await courses.watchByWeekday(1).first;
    expect(mondays.map((c) => c.id), [monday.id, mondayLater.id]);
    expect(await courses.watchByWeekday(3).first, isEmpty);
  });

  test('create rejects weekdays outside 1..7', () async {
    for (final weekday in [0, -1, 8]) {
      await expectLater(
        addCourse(weekday: weekday),
        throwsArgumentError,
        reason: 'weekday $weekday',
      );
    }
    expect(await db.select(db.courses).get(), isEmpty);
  });

  test('create enforces 0 <= startMinute < endMinute <= 1440', () async {
    const invalid = [
      (start: 480, end: 480),
      (start: 570, end: 480),
      (start: -1, end: 570),
      (start: 480, end: 1441),
    ];
    for (final minutes in invalid) {
      await expectLater(
        addCourse(startMinute: minutes.start, endMinute: minutes.end),
        throwsArgumentError,
        reason: '${minutes.start}..${minutes.end}',
      );
    }
    expect(await db.select(db.courses).get(), isEmpty);

    // The exact bounds are valid.
    final fullDay = await addCourse(startMinute: 0, endMinute: 1440);
    expect(fullDay.startMinute, 0);
    expect(fullDay.endMinute, 1440);
  });

  test('create rejects invalid week patterns', () async {
    for (final pattern in ['', 'abc', '0-16', '18-16', '1-61', '1-16,']) {
      await expectLater(
        addCourse(weekPattern: pattern),
        throwsArgumentError,
        reason: pattern,
      );
    }
    expect(await db.select(db.courses).get(), isEmpty);
  });

  test('update persists edits and bumps updatedAt', () async {
    final course = await addCourse(name: '数学', weekday: 1);
    // Drift stores DateTime with second precision, so backdate the row
    // instead of sleeping across a second boundary.
    final stale = DateTime(2020);
    await (db.update(db.courses)..where((t) => t.id.equals(course.id))).write(
      CoursesCompanion(updatedAt: Value(stale)),
    );

    await courses.update(
      course.copyWith(
        name: '高等数学',
        weekday: 3,
        startMinute: 600,
        endMinute: 690,
        weekPattern: '2-8',
        room: 'B202',
        color: const Value(0xFFFF3B30),
        enabled: false,
      ),
    );

    final updated = (await courses.watchAll().first).single;
    expect(updated.name, '高等数学');
    expect(updated.weekday, 3);
    expect(updated.startMinute, 600);
    expect(updated.endMinute, 690);
    expect(updated.weekPattern, '2-8');
    expect(updated.room, 'B202');
    expect(updated.color, 0xFFFF3B30);
    expect(updated.enabled, isFalse);
    expect(updated.createdAt, course.createdAt);
    expect(updated.updatedAt.isAfter(stale), isTrue);
  });

  test('update validates weekday, minutes, and week pattern', () async {
    final course = await addCourse();

    await expectLater(
      courses.update(course.copyWith(weekday: 0)),
      throwsArgumentError,
    );
    await expectLater(
      courses.update(course.copyWith(endMinute: 480)),
      throwsArgumentError,
    );
    await expectLater(
      courses.update(course.copyWith(startMinute: -5)),
      throwsArgumentError,
    );
    await expectLater(
      courses.update(course.copyWith(endMinute: 1441)),
      throwsArgumentError,
    );
    await expectLater(
      courses.update(course.copyWith(weekPattern: '16-1')),
      throwsArgumentError,
    );

    final unchanged = (await courses.watchAll().first).single;
    expect(unchanged.name, course.name);
    expect(unchanged.weekday, course.weekday);
    expect(unchanged.weekPattern, course.weekPattern);
  });

  test('setEnabled hides the course without deleting it', () async {
    final course = await addCourse(name: '数学', weekday: 1);

    await courses.setEnabled(course.id, false);

    final disabled = (await courses.watchAll().first).single;
    expect(disabled.id, course.id);
    expect(disabled.enabled, isFalse);
    expect((await courses.watchByWeekday(1).first).single.enabled, isFalse);

    await courses.setEnabled(course.id, true);
    expect((await courses.watchAll().first).single.enabled, isTrue);
  });

  test('softDelete hides the course but keeps the row', () async {
    final course = await addCourse(name: '数学', weekday: 1);
    final kept = await addCourse(
      name: '语文',
      weekday: 1,
      startMinute: 600,
      endMinute: 690,
    );

    await courses.softDelete(course.id);

    expect((await courses.watchAll().first).map((c) => c.id), [kept.id]);
    expect((await courses.watchByWeekday(1).first).map((c) => c.id), [kept.id]);

    final rows = await db.select(db.courses).get();
    expect(rows, hasLength(2));
    expect(rows.singleWhere((c) => c.id == course.id).deletedAt, isNotNull);
    expect(rows.singleWhere((c) => c.id == kept.id).deletedAt, isNull);
  });
}

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../database/database.dart';
import '../models/week_pattern.dart';

class CourseRepository {
  CourseRepository(this._db);

  final AppDatabase _db;

  /// Non-deleted courses ordered by weekday, then start time.
  Stream<List<Course>> watchAll() {
    final query = _db.select(_db.courses)
      ..where((t) => t.deletedAt.isNull())
      ..orderBy([
        (t) => OrderingTerm(expression: t.weekday),
        (t) => OrderingTerm(expression: t.startMinute),
        (t) => OrderingTerm(expression: t.id),
      ]);
    return query.watch();
  }

  /// Non-deleted courses on [weekday], ordered by start time.
  Stream<List<Course>> watchByWeekday(int weekday) {
    final query = _db.select(_db.courses)
      ..where((t) => t.deletedAt.isNull() & t.weekday.equals(weekday))
      ..orderBy([
        (t) => OrderingTerm(expression: t.startMinute),
        (t) => OrderingTerm(expression: t.id),
      ]);
    return query.watch();
  }

  Future<Course> create({
    required String name,
    required int weekday,
    required int startMinute,
    required int endMinute,
    required String weekPattern,
    String room = '',
    int? color,
    bool enabled = true,
  }) async {
    _validate(
      weekday: weekday,
      startMinute: startMinute,
      endMinute: endMinute,
      weekPattern: weekPattern,
    );
    final id = const Uuid().v4();
    final now = DateTime.now();
    await _db
        .into(_db.courses)
        .insert(
          CoursesCompanion.insert(
            id: id,
            name: name,
            weekday: weekday,
            startMinute: startMinute,
            endMinute: endMinute,
            weekPattern: weekPattern,
            room: Value(room),
            color: Value(color),
            enabled: Value(enabled),
            createdAt: now,
            updatedAt: now,
          ),
        );
    return (_db.select(_db.courses)..where((t) => t.id.equals(id))).getSingle();
  }

  Future<void> update(Course course) async {
    _validate(
      weekday: course.weekday,
      startMinute: course.startMinute,
      endMinute: course.endMinute,
      weekPattern: course.weekPattern,
    );
    await (_db.update(_db.courses)..where((t) => t.id.equals(course.id))).write(
      CoursesCompanion(
        name: Value(course.name),
        weekday: Value(course.weekday),
        startMinute: Value(course.startMinute),
        endMinute: Value(course.endMinute),
        weekPattern: Value(course.weekPattern),
        room: Value(course.room),
        color: Value(course.color),
        enabled: Value(course.enabled),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> softDelete(String id) async {
    final now = DateTime.now();
    await (_db.update(_db.courses)..where((t) => t.id.equals(id))).write(
      CoursesCompanion(deletedAt: Value(now), updatedAt: Value(now)),
    );
  }

  Future<void> setEnabled(String id, bool enabled) async {
    await (_db.update(_db.courses)..where((t) => t.id.equals(id))).write(
      CoursesCompanion(
        enabled: Value(enabled),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  void _validate({
    required int weekday,
    required int startMinute,
    required int endMinute,
    required String weekPattern,
  }) {
    if (weekday < 1 || weekday > 7) {
      throw ArgumentError.value(weekday, 'weekday', 'must be between 1 and 7');
    }
    if (startMinute < 0 || startMinute >= endMinute || endMinute > 1440) {
      throw ArgumentError(
        'minutes must satisfy 0 <= startMinute ($startMinute) < '
        'endMinute ($endMinute) <= 1440',
      );
    }
    if (!isValidWeekPattern(weekPattern)) {
      throw ArgumentError.value(
        weekPattern,
        'weekPattern',
        'invalid week pattern',
      );
    }
  }
}

final courseRepositoryProvider = Provider<CourseRepository>(
  (ref) => CourseRepository(ref.watch(databaseProvider)),
);

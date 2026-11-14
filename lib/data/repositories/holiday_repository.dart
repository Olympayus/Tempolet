import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/dates.dart';
import '../database/database.dart';

/// Holiday rows: seed data imported from the bundled holiday-cn asset, plus
/// user overrides ([Holiday.source] is `seed` or `manual`).
///
/// The parsed seed is kept in memory so [clearManual] can restore a seed row
/// without re-reading the asset; [seedFromJson] and [primeSeedCacheFromJson]
/// populate it.
class HolidayRepository {
  HolidayRepository(this._db);

  final AppDatabase _db;

  /// Seed rows by date, populated by [seedFromJson].
  final Map<DateTime, ({String name, bool isWorkday})> _seed = {};

  /// Holidays of [year], ordered by date.
  Stream<List<Holiday>> watchYear(int year) {
    final query = _db.select(_db.holidays)
      ..where(
        (t) => t.date.isBiggerOrEqualValue(DateTime(year)) &
            t.date.isSmallerThanValue(DateTime(year + 1)),
      )
      ..orderBy([(t) => OrderingTerm(expression: t.date)]);
    return query.watch();
  }

  /// Imports the `days` of a holiday-cn JSON document.
  ///
  /// Idempotent: rows already marked `manual` are left untouched. The document
  /// is fully validated before any row is written.
  Future<void> seedFromJson(String json) async {
    final seed = _parseSeed(json);
    final now = DateTime.now();
    await _db.transaction(() async {
      for (final entry in seed.entries) {
        final existing = await (_db.select(_db.holidays)
              ..where((t) => t.date.equals(entry.key)))
            .getSingleOrNull();
        if (existing?.source == 'manual') continue;
        await _db.into(_db.holidays).insertOnConflictUpdate(
              HolidaysCompanion.insert(
                date: entry.key,
                name: entry.value.name,
                isWorkday: Value(entry.value.isWorkday),
                source: const Value('seed'),
                updatedAt: Value(now),
              ),
            );
      }
    });
    _seed.addAll(seed);
  }

  /// Fills the in-memory seed cache from an already-applied asset without
  /// reading or writing the database. Used when a restart finds the seed
  /// version unchanged, so [clearManual] can still restore seed rows.
  void primeSeedCacheFromJson(String json) {
    _seed.addAll(_parseSeed(json));
  }

  /// Writes a user override for [date].
  Future<void> setManual({
    required DateTime date,
    required String name,
    required bool isWorkday,
  }) async {
    await _db.into(_db.holidays).insertOnConflictUpdate(
          HolidaysCompanion.insert(
            date: dateOnly(date),
            name: name,
            isWorkday: Value(isWorkday),
            source: const Value('manual'),
            updatedAt: Value(DateTime.now()),
          ),
        );
  }

  /// Removes the manual override for [date]: restores the seed row when the
  /// loaded seed has one, otherwise deletes the row.
  Future<void> clearManual(DateTime date) async {
    final day = dateOnly(date);
    final row = await (_db.select(_db.holidays)
          ..where((t) => t.date.equals(day)))
        .getSingleOrNull();
    if (row == null || row.source != 'manual') return;

    final seed = _seed[day];
    if (seed == null) {
      await (_db.delete(_db.holidays)..where((t) => t.date.equals(day))).go();
      return;
    }
    await (_db.update(_db.holidays)..where((t) => t.date.equals(day))).write(
      HolidaysCompanion(
        name: Value(seed.name),
        isWorkday: Value(seed.isWorkday),
        source: const Value('seed'),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Whether [date] is a working day: the stored row wins, otherwise fall back
  /// to Monday-Friday.
  Future<bool> isWorkday(DateTime date) async {
    final day = dateOnly(date);
    final row = await (_db.select(_db.holidays)
          ..where((t) => t.date.equals(day)))
        .getSingleOrNull();
    if (row != null) return row.isWorkday;
    return day.weekday <= DateTime.friday;
  }

  Map<DateTime, ({String name, bool isWorkday})> _parseSeed(String json) {
    final decoded = jsonDecode(json);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Holiday asset must be a JSON object');
    }
    final days = decoded['days'];
    if (days is! List) {
      throw const FormatException('Holiday asset must contain a "days" list');
    }
    final seed = <DateTime, ({String name, bool isWorkday})>{};
    for (final raw in days) {
      if (raw is! Map<String, dynamic>) {
        throw const FormatException('Holiday day must be a JSON object');
      }
      final name = raw['name'];
      final rawDate = raw['date'];
      final isOffDay = raw['isOffDay'];
      if (name is! String || rawDate is! String || isOffDay is! bool) {
        throw const FormatException(
          'Holiday day must have a string name, string date and bool isOffDay',
        );
      }
      final date = DateTime.tryParse(rawDate);
      if (date == null) {
        throw FormatException('Invalid holiday date: $rawDate');
      }
      seed[dateOnly(date)] = (name: name, isWorkday: !isOffDay);
    }
    return seed;
  }
}

final holidayRepositoryProvider = Provider<HolidayRepository>(
  (ref) => HolidayRepository(ref.watch(databaseProvider)),
);

final holidaysForYearProvider = StreamProvider.family<List<Holiday>, int>(
  (ref, year) => ref.watch(holidayRepositoryProvider).watchYear(year),
);

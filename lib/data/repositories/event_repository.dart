import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/utils/dates.dart';
import '../database/database.dart';

/// FNV-1a hash of the event UUID, masked to 31 bits so it is always a
/// non-negative notification id and stable across runs.
int stableNotificationId(String uuid) {
  const offsetBasis = 0x811C9DC5;
  const prime = 0x01000193;
  var hash = offsetBasis;
  for (final code in uuid.codeUnits) {
    hash ^= code;
    hash = (hash * prime) & 0x7FFFFFFF;
  }
  return hash;
}

class EventRepository {
  EventRepository(this._db);

  final AppDatabase _db;

  Stream<List<Event>> watchDay(DateTime day) {
    final start = dateOnly(day);
    return watchRange(start, start.add(const Duration(days: 1)));
  }

  Stream<List<Event>> watchRange(DateTime startDay, DateTime endDay) {
    final start = dateOnly(startDay);
    final end = dateOnly(endDay);
    final query = _db.select(_db.events)
      ..where(
        (t) =>
            t.deletedAt.isNull() &
            t.isCompleted.equals(false) &
            t.date.isBiggerOrEqualValue(start) &
            t.date.isSmallerThanValue(end),
      )
      ..orderBy([
        (t) => OrderingTerm(expression: t.startMinute, nulls: NullsOrder.last),
        (t) => OrderingTerm(expression: t.id),
      ]);
    return query.watch();
  }

  /// Unfinished, non-deleted events dated before [today] — the reminders
  /// page's overdue bucket. Ordered by day, then start minute.
  Stream<List<Event>> watchOverdue(DateTime today) {
    final cutoff = dateOnly(today);
    final query = _db.select(_db.events)
      ..where(
        (t) =>
            t.deletedAt.isNull() &
            t.isCompleted.equals(false) &
            t.date.isSmallerThanValue(cutoff),
      )
      ..orderBy([
        (t) => OrderingTerm(expression: t.date),
        (t) => OrderingTerm(expression: t.startMinute, nulls: NullsOrder.last),
        (t) => OrderingTerm(expression: t.id),
      ]);
    return query.watch();
  }

  /// Date of the oldest overdue event, or null when nothing is overdue.
  Future<DateTime?> earliestOverdueDate(DateTime today) async {
    final cutoff = dateOnly(today);
    final query = _db.select(_db.events)
      ..where(
        (t) =>
            t.deletedAt.isNull() &
            t.isCompleted.equals(false) &
            t.date.isSmallerThanValue(cutoff),
      )
      ..orderBy([(t) => OrderingTerm(expression: t.date)])
      ..limit(1);
    final rows = await query.get();
    return rows.isEmpty ? null : rows.first.date;
  }

  /// Incomplete events in `[start, end)` — shared by the reminders page's
  /// today/week/month buckets. Same semantics as [watchRange].
  Stream<List<Event>> watchIncompleteRange(DateTime start, DateTime end) =>
      watchRange(start, end);

  Future<Event> create({
    required String title,
    String note = '',
    required String kind,
    required DateTime date,
    int? startMinute,
    int? endMinute,
    int importance = 0,
    int? reminderOffsetMinutes,
    String? categoryId,
  }) async {
    final id = const Uuid().v4();
    final now = DateTime.now();
    await _db
        .into(_db.events)
        .insert(
          EventsCompanion.insert(
            id: id,
            title: title,
            note: Value(note),
            kind: kind,
            date: dateOnly(date),
            startMinute: Value(startMinute),
            endMinute: Value(endMinute),
            importance: Value(importance),
            reminderOffsetMinutes: Value(reminderOffsetMinutes),
            categoryId: Value(categoryId),
            notificationId: stableNotificationId(id),
            createdAt: now,
            updatedAt: now,
          ),
        );
    return (_db.select(_db.events)..where((t) => t.id.equals(id))).getSingle();
  }

  Future<Event?> getById(String id) async {
    final rows = await (_db.select(
      _db.events,
    )..where((t) => t.id.equals(id))).get();
    return rows.isEmpty ? null : rows.first;
  }

  /// Completed, non-deleted events, most recently completed first — the only
  /// surface where completed events survive.
  Stream<List<Event>> watchCompleted() {
    final query = _db.select(_db.events)
      ..where((t) => t.deletedAt.isNull() & t.isCompleted.equals(true))
      ..orderBy([
        (t) => OrderingTerm(
          expression: t.completedAt,
          mode: OrderingMode.desc,
          nulls: NullsOrder.last,
        ),
        (t) => OrderingTerm(expression: t.id),
      ]);
    return query.watch();
  }

  /// Unfinished, non-deleted events on or after [day] — used by startup
  /// reconciliation.
  Future<List<Event>> upcomingFrom(DateTime day) {
    final start = dateOnly(day);
    final query = _db.select(_db.events)
      ..where(
        (t) =>
            t.deletedAt.isNull() &
            t.isCompleted.equals(false) &
            t.date.isBiggerOrEqualValue(start),
      )
      ..orderBy([
        (t) => OrderingTerm(expression: t.date),
        (t) => OrderingTerm(expression: t.startMinute, nulls: NullsOrder.last),
      ]);
    return query.get();
  }

  Future<List<Event>> eventsOnDay(DateTime day) => watchDay(day).first;

  Future<void> updateEvent(Event event) async {
    await (_db.update(_db.events)..where((t) => t.id.equals(event.id))).write(
      event.copyWith(updatedAt: DateTime.now()),
    );
  }

  Future<void> setCompleted(String id, bool value) async {
    await (_db.update(_db.events)..where((t) => t.id.equals(id))).write(
      EventsCompanion(
        isCompleted: Value(value),
        completedAt: Value(value ? DateTime.now() : null),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> setCategory(String id, String? categoryId) async {
    await (_db.update(_db.events)..where((t) => t.id.equals(id))).write(
      EventsCompanion(
        categoryId: Value(categoryId),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> reschedule(String id, DateTime newDay) async {
    await (_db.update(_db.events)..where((t) => t.id.equals(id))).write(
      EventsCompanion(
        date: Value(dateOnly(newDay)),
        isCompleted: const Value(false),
        completedAt: const Value(null),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> softDelete(String id) async {
    final now = DateTime.now();
    await (_db.update(_db.events)..where((t) => t.id.equals(id))).write(
      EventsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
    );
  }

  /// Permanently removes a row (completed-page delete).
  Future<void> hardDelete(String id) async {
    await (_db.delete(_db.events)..where((t) => t.id.equals(id))).go();
  }

  /// Permanently removes every completed row (completed-page clear).
  Future<void> clearCompleted() async {
    await (_db.delete(
      _db.events,
    )..where((t) => t.isCompleted.equals(true))).go();
  }
}

final eventRepositoryProvider = Provider<EventRepository>(
  (ref) => EventRepository(ref.watch(databaseProvider)),
);

final eventsForDayProvider = StreamProvider.family<List<Event>, DateTime>((
  ref,
  day,
) {
  return ref.watch(eventRepositoryProvider).watchDay(day);
});

final completedEventsProvider = StreamProvider<List<Event>>((ref) {
  return ref.watch(eventRepositoryProvider).watchCompleted();
});

/// Range key: [start] inclusive, [end] exclusive (both date-only).
typedef DayRange = ({DateTime start, DateTime end});

final eventsInRangeProvider = StreamProvider.family<List<Event>, DayRange>((
  ref,
  range,
) {
  return ref.watch(eventRepositoryProvider).watchRange(range.start, range.end);
});

/// Reminders-page alias for [eventsInRangeProvider]; both surface
/// [EventRepository.watchIncompleteRange].
final rangeEventsProvider = eventsInRangeProvider;

/// Overdue bucket for the reminders page, refreshed whenever [today] changes.
final overdueEventsProvider = StreamProvider.family<List<Event>, DateTime>((
  ref,
  today,
) {
  return ref.watch(eventRepositoryProvider).watchOverdue(today);
});

/// Date of the oldest overdue event, used for the overdue jump target.
final earliestOverdueProvider = FutureProvider.family<DateTime?, DateTime>((
  ref,
  today,
) {
  return ref.watch(eventRepositoryProvider).earliestOverdueDate(today);
});

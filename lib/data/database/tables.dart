import 'package:drift/drift.dart';

/// Work/reminder items. UUID primary keys and soft deletes are here so a
/// future sync layer does not need a schema migration.
@TableIndex(name: 'idx_events_date', columns: {#date})
class Events extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get note => text().withDefault(const Constant(''))();

  /// `reminder` or `plan`.
  TextColumn get kind => text()();
  DateTimeColumn get date => dateTime()();

  /// Minutes since midnight; null for all-day entries (not used in v0.1.0 UI).
  IntColumn get startMinute => integer().nullable()();
  IntColumn get endMinute => integer().nullable()();

  /// 0 = low, 1 = medium, 2 = high.
  IntColumn get importance => integer().withDefault(const Constant(0))();

  /// Minutes before [startMinute] to notify; null means "no notification".
  IntColumn get reminderOffsetMinutes => integer().nullable()();
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get completedAt => dateTime().nullable()();

  /// Stable FNV-1a id derived from [id] for the notification plugin.
  IntColumn get notificationId => integer()();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class Holidays extends Table {
  DateTimeColumn get date => dateTime()();
  TextColumn get name => text()();

  @override
  Set<Column> get primaryKey => {date};
}

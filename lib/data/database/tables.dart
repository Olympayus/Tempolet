import 'package:drift/drift.dart';

/// Work/reminder items. UUID primary keys and soft deletes are here so a
/// future sync layer does not need a schema migration.
@TableIndex(name: 'idx_events_date', columns: {#date})
class Events extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get note => text().withDefault(const Constant(''))();
  TextColumn get categoryId => text().nullable()();

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
  BoolColumn get isWorkday => boolean().withDefault(const Constant(false))();
  TextColumn get source => text().withDefault(const Constant('seed'))();
  DateTimeColumn get updatedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {date};
}

@TableIndex(name: 'idx_notes_short_id', columns: {#shortId}, unique: true)
@TableIndex(name: 'idx_notes_relative_path', columns: {#relativePath}, unique: true)
class Notes extends Table {
  TextColumn get id => text()();
  TextColumn get shortId => text()();
  TextColumn get title => text()();
  TextColumn get format => text()(); // txt | md
  TextColumn get relativePath => text()();
  DateTimeColumn get fileMtime => dateTime()();
  IntColumn get fileSize => integer()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@TableIndex(name: 'idx_links_note', columns: {#noteId})
@TableIndex(name: 'idx_links_event', columns: {#eventId})
class NoteEventLinks extends Table {
  TextColumn get id => text()();
  TextColumn get noteId => text()();
  TextColumn get eventId => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@TableIndex(name: 'idx_categories_name', columns: {#name})
class Categories extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  IntColumn get color => integer().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@TableIndex(name: 'idx_courses_weekday', columns: {#weekday})
class Courses extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  IntColumn get weekday => integer()();
  IntColumn get startMinute => integer()();
  IntColumn get endMinute => integer()();
  TextColumn get weekPattern => text()();
  TextColumn get room => text().withDefault(const Constant(''))();
  IntColumn get color => integer().nullable()();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

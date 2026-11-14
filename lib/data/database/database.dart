import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'tables.dart';

part 'database.g.dart';

@DriftDatabase(tables: [Events, Holidays, Notes, NoteEventLinks, Categories, Courses])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
      : super(executor ?? driftDatabase(name: 'tempolet'));

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.addColumn(events, events.categoryId);
            await m.createTable(notes);
            await m.createTable(noteEventLinks);
            await m.createTable(categories);
            await m.createTable(courses);
            await m.addColumn(holidays, holidays.isWorkday);
            await m.addColumn(holidays, holidays.source);
            await m.addColumn(holidays, holidays.updatedAt);
            await m.createIndex(idxNotesShortId);
            await m.createIndex(idxNotesRelativePath);
            await m.createIndex(idxLinksNote);
            await m.createIndex(idxLinksEvent);
            await m.createIndex(idxCategoriesName);
            await m.createIndex(idxCoursesWeekday);
          }
        },
      );
}

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

/// All holidays (the table holds a handful of rows per year, so no range
/// filtering is needed at the query level).
final holidaysProvider = StreamProvider<List<Holiday>>((ref) {
  return ref.watch(databaseProvider).select(
        ref.watch(databaseProvider).holidays,
      ).watch();
});

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../database/database.dart';

/// Thrown when a category name collides (case-insensitively) with another
/// non-deleted category.
class CategoryNameConflict implements Exception {
  CategoryNameConflict(this.name);

  final String name;

  @override
  String toString() => 'CategoryNameConflict: $name';
}

class CategoryRepository {
  CategoryRepository(this._db);

  final AppDatabase _db;

  /// Non-deleted categories ordered by [Category.sortOrder], then name.
  Stream<List<Category>> watchAll() {
    final query = _db.select(_db.categories)
      ..where((t) => t.deletedAt.isNull())
      ..orderBy([
        (t) => OrderingTerm(expression: t.sortOrder),
        (t) => OrderingTerm(expression: t.name),
      ]);
    return query.watch();
  }

  Future<Category> create({required String name, int? color}) async {
    final trimmed = _validatedName(name);
    await _ensureNameAvailable(trimmed);
    final id = const Uuid().v4();
    final now = DateTime.now();
    await _db.into(_db.categories).insert(
          CategoriesCompanion.insert(
            id: id,
            name: trimmed,
            color: Value(color),
            createdAt: now,
            updatedAt: now,
          ),
        );
    return (_db.select(_db.categories)..where((t) => t.id.equals(id)))
        .getSingle();
  }

  Future<void> rename(String id, String name) async {
    final trimmed = _validatedName(name);
    await _ensureNameAvailable(trimmed, excludeId: id);
    await (_db.update(_db.categories)..where((t) => t.id.equals(id))).write(
      CategoriesCompanion(
        name: Value(trimmed),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> setColor(String id, int? color) async {
    await (_db.update(_db.categories)..where((t) => t.id.equals(id))).write(
      CategoriesCompanion(
        color: Value(color),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Assigns [Category.sortOrder] by position in [orderedIds].
  Future<void> reorder(List<String> orderedIds) async {
    final now = DateTime.now();
    await _db.transaction(() async {
      for (var i = 0; i < orderedIds.length; i++) {
        await (_db.update(_db.categories)
              ..where((t) => t.id.equals(orderedIds[i])))
            .write(
          CategoriesCompanion(sortOrder: Value(i), updatedAt: Value(now)),
        );
      }
    });
  }

  /// Detaches non-deleted events from the category, then soft-deletes it.
  Future<void> softDelete(String id) async {
    final now = DateTime.now();
    await _db.transaction(() async {
      await (_db.update(_db.events)
            ..where((t) => t.categoryId.equals(id) & t.deletedAt.isNull()))
          .write(
        EventsCompanion(
          categoryId: const Value(null),
          updatedAt: Value(now),
        ),
      );
      await (_db.update(_db.categories)..where((t) => t.id.equals(id))).write(
        CategoriesCompanion(deletedAt: Value(now), updatedAt: Value(now)),
      );
    });
  }

  String _validatedName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(name, 'name', 'must not be empty');
    }
    return trimmed;
  }

  /// Case-insensitive duplicate check over non-deleted categories.
  Future<void> _ensureNameAvailable(String name, {String? excludeId}) async {
    final query = _db.select(_db.categories)
      ..where((t) {
        var predicate =
            t.deletedAt.isNull() & t.name.lower().equals(name.toLowerCase());
        if (excludeId != null) {
          predicate = predicate & t.id.equals(excludeId).not();
        }
        return predicate;
      });
    if ((await query.get()).isNotEmpty) {
      throw CategoryNameConflict(name);
    }
  }
}

final categoryRepositoryProvider = Provider<CategoryRepository>(
  (ref) => CategoryRepository(ref.watch(databaseProvider)),
);

final allCategoriesProvider = StreamProvider<List<Category>>(
  (ref) => ref.watch(categoryRepositoryProvider).watchAll(),
);

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../database/database.dart';
import '../models/note_format.dart';

/// Primitive index access for notes and their event links. The note lifecycle
/// is owned by `NoteVaultService`; this repository never touches files, so the
/// index and the vault cannot drift apart from here.
class NoteRepository {
  NoteRepository(this._db);

  final AppDatabase _db;

  /// Non-deleted notes, most recently updated first.
  Stream<List<Note>> watchAll() {
    final query = _db.select(_db.notes)
      ..where((t) => t.deletedAt.isNull())
      ..orderBy([
        (t) => OrderingTerm(expression: t.updatedAt, mode: OrderingMode.desc),
      ]);
    return query.watch();
  }

  /// All notes, most recently updated first. Soft-deleted rows are included
  /// only when [includeDeleted] is true.
  Future<List<Note>> getAll({bool includeDeleted = false}) {
    final query = _db.select(_db.notes);
    if (!includeDeleted) {
      query.where((t) => t.deletedAt.isNull());
    }
    query.orderBy([
      (t) => OrderingTerm(expression: t.updatedAt, mode: OrderingMode.desc),
    ]);
    return query.get();
  }

  Future<Note?> getById(String id) async {
    final rows =
        await (_db.select(_db.notes)..where((t) => t.id.equals(id))).get();
    return rows.isEmpty ? null : rows.first;
  }

  /// Looks up by short id, including soft-deleted rows so reconciliation can
  /// revive a note that was deleted or belongs to a previously switched vault.
  Future<Note?> getByShortId(String shortId) async {
    final rows = await (_db.select(_db.notes)
          ..where((t) => t.shortId.equals(shortId)))
        .get();
    return rows.isEmpty ? null : rows.first;
  }

  /// Looks up by vault-relative path, including soft-deleted rows (their paths
  /// have been rewritten to tombstone paths).
  Future<Note?> getByRelativePath(String relativePath) async {
    final rows = await (_db.select(_db.notes)
          ..where((t) => t.relativePath.equals(relativePath)))
        .get();
    return rows.isEmpty ? null : rows.first;
  }

  /// Inserts a fresh index row. Duplicate [shortId] or [relativePath] values
  /// surface the database unique-constraint error to the caller.
  Future<void> insertIndex({
    required String id,
    required String shortId,
    required String title,
    required NoteFormat format,
    required String relativePath,
    required DateTime fileMtime,
    required int fileSize,
  }) async {
    final now = DateTime.now();
    await _db.into(_db.notes).insert(
          NotesCompanion.insert(
            id: id,
            shortId: shortId,
            title: title,
            format: format.extension,
            relativePath: relativePath,
            fileMtime: fileMtime,
            fileSize: fileSize,
            createdAt: now,
            updatedAt: now,
            deletedAt: const Value(null),
          ),
        );
  }

  /// Refreshes the file-facing metadata. A non-null [shortId] replaces the
  /// existing one; [revive] clears the soft-delete marker.
  Future<void> updateFileMeta(
    String id, {
    required String relativePath,
    required String title,
    required DateTime fileMtime,
    required int fileSize,
    String? shortId,
    bool revive = false,
  }) async {
    await (_db.update(_db.notes)..where((t) => t.id.equals(id))).write(
      NotesCompanion(
        relativePath: Value(relativePath),
        title: Value(title),
        fileMtime: Value(fileMtime),
        fileSize: Value(fileSize),
        shortId: shortId == null ? const Value.absent() : Value(shortId),
        updatedAt: Value(DateTime.now()),
        deletedAt: revive ? const Value(null) : const Value.absent(),
      ),
    );
  }

  /// Soft-deletes a note and rewrites its path to [tombstonePath] so the old
  /// relative path is released for reuse.
  Future<void> markDeleted(String id, {required String tombstonePath}) async {
    final now = DateTime.now();
    await (_db.update(_db.notes)..where((t) => t.id.equals(id))).write(
      NotesCompanion(
        relativePath: Value(tombstonePath),
        deletedAt: Value(now),
        updatedAt: Value(now),
      ),
    );
  }

  /// Links a note to an event, keeping at most one active link per pair.
  /// Reuses an active link as-is or revives a soft-deleted one.
  Future<void> linkToEvent(String noteId, String eventId) async {
    await _db.transaction(() async {
      final active = await (_db.select(_db.noteEventLinks)
            ..where((t) =>
                t.noteId.equals(noteId) &
                t.eventId.equals(eventId) &
                t.deletedAt.isNull()))
          .get();
      if (active.isNotEmpty) return;

      final now = DateTime.now();
      final deleted = await (_db.select(_db.noteEventLinks)
            ..where((t) =>
                t.noteId.equals(noteId) &
                t.eventId.equals(eventId) &
                t.deletedAt.isNotNull())
            ..orderBy([
              (t) =>
                  OrderingTerm(expression: t.updatedAt, mode: OrderingMode.desc),
            ]))
          .get();
      if (deleted.isNotEmpty) {
        await (_db.update(_db.noteEventLinks)
              ..where((t) => t.id.equals(deleted.first.id)))
            .write(
          NoteEventLinksCompanion(
            deletedAt: const Value(null),
            updatedAt: Value(now),
          ),
        );
        return;
      }

      await _db.into(_db.noteEventLinks).insert(
            NoteEventLinksCompanion.insert(
              id: const Uuid().v4(),
              noteId: noteId,
              eventId: eventId,
              createdAt: now,
              updatedAt: now,
            ),
          );
    });
  }

  /// Soft-deletes the active link between [noteId] and [eventId], if any.
  Future<void> unlinkFromEvent(String noteId, String eventId) async {
    final now = DateTime.now();
    await (_db.update(_db.noteEventLinks)
          ..where((t) =>
              t.noteId.equals(noteId) &
              t.eventId.equals(eventId) &
              t.deletedAt.isNull()))
        .write(
      NoteEventLinksCompanion(
        deletedAt: Value(now),
        updatedAt: Value(now),
      ),
    );
  }

  /// Active links pointing at [noteId].
  Stream<List<NoteEventLink>> watchLinksForNote(String noteId) {
    final query = _db.select(_db.noteEventLinks)
      ..where((t) => t.noteId.equals(noteId) & t.deletedAt.isNull())
      ..orderBy([
        (t) => OrderingTerm(expression: t.createdAt),
        (t) => OrderingTerm(expression: t.id),
      ]);
    return query.watch();
  }

  /// Active links pointing at [eventId].
  Stream<List<NoteEventLink>> watchLinksForEvent(String eventId) {
    final query = _db.select(_db.noteEventLinks)
      ..where((t) => t.eventId.equals(eventId) & t.deletedAt.isNull())
      ..orderBy([
        (t) => OrderingTerm(expression: t.createdAt),
        (t) => OrderingTerm(expression: t.id),
      ]);
    return query.watch();
  }
}

final noteRepositoryProvider = Provider<NoteRepository>(
  (ref) => NoteRepository(ref.watch(databaseProvider)),
);

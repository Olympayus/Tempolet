import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tempolet/data/database/database.dart';
import 'package:tempolet/data/models/note_format.dart';
import 'package:tempolet/data/repositories/note_repository.dart';
import 'package:uuid/uuid.dart';

void main() {
  late AppDatabase db;
  late NoteRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = NoteRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  String newId() => const Uuid().v4();

  Future<Note> insertNote({
    String? id,
    String? shortId,
    String title = 'a',
    NoteFormat format = NoteFormat.md,
    String? relativePath,
  }) async {
    final noteId = id ?? newId();
    final sid = shortId ?? noteId.substring(0, 4);
    await repo.insertIndex(
      id: noteId,
      shortId: sid,
      title: title,
      format: format,
      relativePath: relativePath ?? '$title~$sid.${format.extension}',
      fileMtime: DateTime(2026, 11, 14),
      fileSize: 3,
    );
    return (await repo.getById(noteId))!;
  }

  test('NoteFormat exposes its file extension', () {
    expect(NoteFormat.txt.extension, 'txt');
    expect(NoteFormat.md.extension, 'md');
  });

  test('insertIndex persists the index row with format extension', () async {
    final id = newId();
    final shortId = id.substring(0, 4);

    await repo.insertIndex(
      id: id,
      shortId: shortId,
      title: 'a',
      format: NoteFormat.md,
      relativePath: 'a~$shortId.md',
      fileMtime: DateTime(2026, 11, 14),
      fileSize: 3,
    );

    final note = (await repo.getByShortId(shortId))!;
    expect(note.id, id);
    expect(note.shortId, shortId);
    expect(note.title, 'a');
    expect(note.format, 'md');
    expect(note.relativePath, 'a~$shortId.md');
    expect(note.fileMtime, DateTime(2026, 11, 14));
    expect(note.fileSize, 3);
    expect(note.createdAt, isNotNull);
    expect(note.updatedAt, isNotNull);
    expect(note.deletedAt, isNull);
    expect(await repo.watchAll().first, hasLength(1));
  });

  test('insertIndex rejects duplicate shortIds and relative paths', () async {
    await insertNote(shortId: 'aaaa', relativePath: 'a~aaaa.md');

    await expectLater(
      insertNote(shortId: 'aaaa', relativePath: 'b~aaaa.md'),
      throwsA(isA<SqliteException>()),
    );
    await expectLater(
      insertNote(shortId: 'bbbb', relativePath: 'a~aaaa.md'),
      throwsA(isA<SqliteException>()),
    );

    expect(await repo.getAll(), hasLength(1));
  });

  test('watchAll hides soft-deleted notes and sorts by updatedAt desc',
      () async {
    final a = await insertNote(shortId: 'aaaa');
    final b = await insertNote(shortId: 'bbbb');

    // Pin updatedAt explicitly: drift stores DateTime as unix seconds, so
    // rows inserted in the same second would otherwise tie.
    Future<void> setUpdatedAt(String id, DateTime value) {
      return (db.update(db.notes)..where((t) => t.id.equals(id))).write(
        NotesCompanion(updatedAt: Value(value)),
      );
    }

    await setUpdatedAt(a.id, DateTime(2020, 1, 1));
    await setUpdatedAt(b.id, DateTime(2020, 1, 2));

    expect((await repo.watchAll().first).map((n) => n.id), [b.id, a.id]);

    await repo.markDeleted(a.id, tombstonePath: '.lost/20261114-a~aaaa.md');
    expect((await repo.watchAll().first).map((n) => n.id), [b.id]);
  });

  test('getAll includes soft-deleted rows only when asked', () async {
    final a = await insertNote(shortId: 'aaaa');
    final b = await insertNote(shortId: 'bbbb');
    await repo.markDeleted(b.id, tombstonePath: '.lost/20261114-b~bbbb.md');

    expect((await repo.getAll()).map((n) => n.id), [a.id]);

    final all = await repo.getAll(includeDeleted: true);
    expect(all.map((n) => n.id), containsAll([a.id, b.id]));
    expect(all.singleWhere((n) => n.id == b.id).deletedAt, isNotNull);
  });

  test('markDeleted rewrites the path and keeps the row findable', () async {
    final id = newId();
    final shortId = id.substring(0, 4);
    await insertNote(id: id, shortId: shortId);

    await repo.markDeleted(id, tombstonePath: '.lost/20261114-a~$shortId.md');

    expect(await repo.getByRelativePath('a~$shortId.md'), isNull);
    final tombstoned =
        (await repo.getByRelativePath('.lost/20261114-a~$shortId.md'))!;
    expect(tombstoned.deletedAt, isNotNull);

    final byShortId = (await repo.getByShortId(shortId))!;
    expect(byShortId.deletedAt, isNotNull);
    expect((await repo.getById(id))!.deletedAt, isNotNull);
  });

  test('updateFileMeta refreshes metadata and revives a deleted note', () async {
    final id = newId();
    final shortId = id.substring(0, 4);
    await insertNote(id: id, shortId: shortId);
    await repo.markDeleted(id, tombstonePath: '.lost/20261114-a~$shortId.md');

    await repo.updateFileMeta(
      id,
      relativePath: 'a~$shortId.md',
      title: 'a',
      fileMtime: DateTime(2026, 11, 14),
      fileSize: 3,
      revive: true,
    );

    final note = (await repo.getByShortId(shortId))!;
    expect(note.deletedAt, isNull);
    expect(note.relativePath, 'a~$shortId.md');

    await repo.updateFileMeta(
      id,
      relativePath: 'renamed~$shortId.md',
      title: 'renamed',
      fileMtime: DateTime(2026, 11, 15),
      fileSize: 9,
    );

    final updated = (await repo.getByShortId(shortId))!;
    expect(updated.title, 'renamed');
    expect(updated.relativePath, 'renamed~$shortId.md');
    expect(updated.fileMtime, DateTime(2026, 11, 15));
    expect(updated.fileSize, 9);
    expect(updated.deletedAt, isNull);
  });

  test('updateFileMeta can replace the shortId', () async {
    final id = newId();
    final shortId = id.substring(0, 4);
    await insertNote(id: id, shortId: shortId);

    await repo.updateFileMeta(
      id,
      relativePath: 'a~cccc.md',
      title: 'a',
      fileMtime: DateTime(2026, 11, 14),
      fileSize: 3,
      shortId: 'cccc',
    );

    expect(await repo.getByShortId(shortId), isNull);
    expect((await repo.getByShortId('cccc'))!.id, id);
  });

  test('updateFileMeta updates the format only when one is given', () async {
    final note = await insertNote(shortId: 'aaaa');
    expect(note.format, 'md');

    await repo.updateFileMeta(
      note.id,
      relativePath: note.relativePath,
      title: note.title,
      fileMtime: note.fileMtime,
      fileSize: note.fileSize,
    );
    expect((await repo.getById(note.id))!.format, 'md');

    await repo.updateFileMeta(
      note.id,
      relativePath: 'a~aaaa.txt',
      title: note.title,
      fileMtime: note.fileMtime,
      fileSize: note.fileSize,
      format: NoteFormat.txt,
    );
    expect((await repo.getById(note.id))!.format, 'txt');
  });

  test('watchAll and getAll break updatedAt ties by id', () async {
    await insertNote(id: 'aaa', shortId: 'aaaa');
    await insertNote(id: 'bbb', shortId: 'bbbb');
    final tie = DateTime(2020, 1, 1);
    for (final id in ['aaa', 'bbb']) {
      await (db.update(db.notes)..where((t) => t.id.equals(id))).write(
        NotesCompanion(updatedAt: Value(tie)),
      );
    }

    expect((await repo.watchAll().first).map((n) => n.id), ['aaa', 'bbb']);
    expect((await repo.getAll()).map((n) => n.id), ['aaa', 'bbb']);
  });

  test('linkToEvent is idempotent per note-event pair', () async {
    final noteId = newId();
    final eventId = newId();

    await repo.linkToEvent(noteId, eventId);
    await repo.linkToEvent(noteId, eventId);

    final links = await repo.watchLinksForNote(noteId).first;
    expect(links, hasLength(1));
    expect(links.single.noteId, noteId);
    expect(links.single.eventId, eventId);
    expect(links.single.deletedAt, isNull);
    expect(await repo.watchLinksForEvent(eventId).first, hasLength(1));
    expect(await db.select(db.noteEventLinks).get(), hasLength(1));
  });

  test('unlinkFromEvent soft-deletes and re-link revives the same row',
      () async {
    final noteId = newId();
    final eventId = newId();
    await repo.linkToEvent(noteId, eventId);
    final originalId =
        (await repo.watchLinksForNote(noteId).first).single.id;

    await repo.unlinkFromEvent(noteId, eventId);
    expect(await repo.watchLinksForNote(noteId).first, isEmpty);
    expect(await repo.watchLinksForEvent(eventId).first, isEmpty);

    await repo.linkToEvent(noteId, eventId);
    final revived = (await repo.watchLinksForNote(noteId).first).single;
    expect(revived.id, originalId);
    expect(revived.deletedAt, isNull);
    expect(await db.select(db.noteEventLinks).get(), hasLength(1));
  });

  test('link watches are scoped to the note or event', () async {
    final noteA = newId();
    final noteB = newId();
    final eventA = newId();
    final eventB = newId();

    await repo.linkToEvent(noteA, eventA);
    await repo.linkToEvent(noteA, eventB);
    await repo.linkToEvent(noteB, eventA);

    expect(await repo.watchLinksForNote(noteA).first, hasLength(2));
    expect(await repo.watchLinksForEvent(eventA).first, hasLength(2));
    expect(await repo.watchLinksForNote(noteB).first, hasLength(1));
    expect(await repo.watchLinksForEvent(eventB).first, hasLength(1));
  });
}

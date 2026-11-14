import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:tempolet/core/paths.dart';
import 'package:tempolet/data/database/database.dart';
import 'package:tempolet/data/models/note_format.dart';
import 'package:tempolet/data/repositories/note_repository.dart';
import 'package:tempolet/data/vault/note_vault_service.dart';

class _FakeAppPaths implements AppPaths {
  _FakeAppPaths(this.directory);

  final Directory directory;

  @override
  Future<Directory> defaultVaultDirectory() async => directory;
}

class _CountingUpdateRepo extends NoteRepository {
  _CountingUpdateRepo(super.db);

  int updateFileMetaCalls = 0;

  @override
  Future<void> updateFileMeta(
    String id, {
    required String relativePath,
    required String title,
    required DateTime fileMtime,
    required int fileSize,
    NoteFormat? format,
    String? shortId,
    bool revive = false,
  }) {
    updateFileMetaCalls++;
    return super.updateFileMeta(
      id,
      relativePath: relativePath,
      title: title,
      fileMtime: fileMtime,
      fileSize: fileSize,
      format: format,
      shortId: shortId,
      revive: revive,
    );
  }
}

void main() {
  late AppDatabase db;
  late NoteRepository repo;
  late Directory root;
  late Directory vault;
  late NoteVaultService service;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = NoteRepository(db);
    root = Directory.systemTemp.createTempSync('tempolet-reconcile-');
    vault = Directory(p.join(root.path, 'Tempolet'));
    service = NoteVaultService(repository: repo, paths: _FakeAppPaths(vault));
  });

  tearDown(() async {
    await db.close();
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  File vaultFile(String relativePath) => File(p.join(vault.path, relativePath));

  Future<Note> importVia(String relativePath, String content) async {
    final file = vaultFile(relativePath)
      ..createSync(recursive: true)
      ..writeAsStringSync(content);
    return service.importExternalFile(file);
  }

  List<String> relativeFiles(Directory directory) {
    final files = directory
        .listSync(recursive: true, followLinks: false)
        .whereType<File>()
        .map((file) => p.relative(file.path, from: directory.path))
        .toList();
    files.sort();
    return files;
  }

  test(
    'imports an external file that has no short id and renames it',
    () async {
      vaultFile('inbox/想法.md')
        ..createSync(recursive: true)
        ..writeAsStringSync('hello');

      final notes = await service.reconcile();

      expect(notes, hasLength(1));
      final imported = notes.single;
      expect(imported.title, '想法');
      expect(imported.shortId, matches(RegExp(r'^[0-9a-f]{4}$')));
      expect(imported.relativePath, 'inbox/想法~${imported.shortId}.md');
      expect(imported.deletedAt, isNull);
      expect(vaultFile('inbox/想法.md').existsSync(), isFalse);
      expect(await vaultFile(imported.relativePath).readAsString(), 'hello');
      expect((await repo.watchAll().first).map((n) => n.id), [imported.id]);
    },
  );

  test('keeps the note id when a file is renamed externally', () async {
    final imported = await importVia('inbox/想法.md', 'hello');
    vaultFile(imported.relativePath)
        .renameSync(p.join(vault.path, 'inbox', '想法改~${imported.shortId}.md'));

    await service.reconcile();

    final renamed = (await repo.getById(imported.id))!;
    expect(renamed.title, '想法改');
    expect(renamed.relativePath, 'inbox/想法改~${imported.shortId}.md');
    expect(renamed.shortId, imported.shortId);
    expect(renamed.deletedAt, isNull);
  });

  test('soft-deletes and rewrites the path when a file disappears', () async {
    final imported = await importVia('inbox/想法.md', 'hello');
    vaultFile(imported.relativePath).deleteSync();

    final notes = await service.reconcile();

    expect(notes, isEmpty);
    final lost = (await repo.getById(imported.id))!;
    expect(lost.deletedAt, isNotNull);
    expect(lost.relativePath, startsWith('.lost/'));
    expect(
      RegExp(
        r'^\.lost/\d{8}-\d{6}-' +
            RegExp.escape(imported.shortId) +
            r'-想法~' +
            RegExp.escape(imported.shortId) +
            r'\.md$',
      ).hasMatch(lost.relativePath),
      isTrue,
    );
    // Reconciliation never touches the disk for lost rows.
    expect(Directory(p.join(vault.path, '.lost')).existsSync(), isFalse);
  });

  test('revives the same note when its file reappears', () async {
    final imported = await importVia('inbox/想法.md', 'hello');
    vaultFile(imported.relativePath).deleteSync();
    await service.reconcile();
    expect((await repo.getById(imported.id))!.deletedAt, isNotNull);

    vaultFile('inbox/想法~${imported.shortId}.md')
      ..createSync(recursive: true)
      ..writeAsStringSync('back');

    final notes = await service.reconcile();

    expect(notes, hasLength(1));
    final revived = (await repo.getById(imported.id))!;
    expect(revived.deletedAt, isNull);
    expect(revived.title, '想法');
    expect(revived.relativePath, 'inbox/想法~${imported.shortId}.md');
    expect(await service.readNote(imported.id), 'back');
  });

  test('updates the format when a file extension changes externally', () async {
    final imported = await importVia('inbox/想法.md', 'hello');
    expect(imported.format, 'md');
    final newPath = 'inbox/想法~${imported.shortId}.txt';
    vaultFile(imported.relativePath)
        .renameSync(p.join(vault.path, 'inbox', '想法~${imported.shortId}.txt'));

    await service.reconcile();

    final updated = (await repo.getById(imported.id))!;
    expect(updated.format, 'txt');
    expect(updated.relativePath, newPath);
    expect(updated.relativePath, endsWith('.txt'));
    expect(updated.shortId, imported.shortId);
    expect(vaultFile(newPath).existsSync(), isTrue);
    expect(vaultFile(imported.relativePath).existsSync(), isFalse);
    expect(await service.readNote(imported.id), 'hello');

    // A second pass sees nothing left to fix.
    final countingRepo = _CountingUpdateRepo(db);
    final idempotentService = NoteVaultService(
      repository: countingRepo,
      paths: _FakeAppPaths(vault),
      vaultPath: vault.path,
    );
    await idempotentService.reconcile();
    expect(countingRepo.updateFileMetaCalls, 0);
  });

  test('keeps event links across rename, delete and reappearance', () async {
    final imported = await importVia('inbox/想法.md', 'hello');
    await repo.linkToEvent(imported.id, 'event-1');

    Future<void> expectActiveLink({required bool deleted}) async {
      final note = (await repo.getById(imported.id))!;
      expect(note.shortId, imported.shortId);
      expect(note.deletedAt != null, deleted);
      final links = await repo.watchLinksForNote(imported.id).first;
      expect(links, hasLength(1));
      expect(links.single.eventId, 'event-1');
      expect(links.single.deletedAt, isNull);
    }

    // External rename that preserves the short id.
    final renamedPath = 'inbox/想法改~${imported.shortId}.md';
    vaultFile(imported.relativePath).renameSync(vaultFile(renamedPath).path);
    await service.reconcile();
    expect((await repo.getById(imported.id))!.relativePath, renamedPath);
    await expectActiveLink(deleted: false);

    // External delete: the row is tombstoned, the link stays active.
    vaultFile(renamedPath).deleteSync();
    await service.reconcile();
    await expectActiveLink(deleted: true);

    // Reappearance revives the same note and keeps the link.
    vaultFile(renamedPath)
      ..createSync(recursive: true)
      ..writeAsStringSync('back');
    await service.reconcile();
    await expectActiveLink(deleted: false);
    expect(await service.readNote(imported.id), 'back');
  });

  test('perceives external content changes at the same path', () async {
    final imported = await importVia('inbox/想法.md', 'hello');
    final file = vaultFile(imported.relativePath);
    await file.writeAsString('外部修改的内容');
    final newMtime = DateTime.now().add(const Duration(minutes: 2));
    await file.setLastModified(newMtime);
    final stat = await file.stat();

    await service.reconcile();

    final updated = (await repo.getById(imported.id))!;
    expect(updated.relativePath, imported.relativePath);
    expect(updated.fileSize, isNot(imported.fileSize));
    expect(updated.fileSize, stat.size);
    expect(
      updated.fileMtime.millisecondsSinceEpoch ~/ 1000,
      stat.modified.millisecondsSinceEpoch ~/ 1000,
    );
  });

  test(
    'skips hidden entries, vault bookkeeping directories and non-note files',
    () async {
      for (final path in [
        '.hidden.md',
        '.trash/trashed.md',
        '.lost/lost.md',
        '.vault-switch/old/nested.md',
        'inbox/.draft.md',
      ]) {
        vaultFile(path)
          ..createSync(recursive: true)
          ..writeAsStringSync('skip');
      }
      vaultFile('image.png')
        ..createSync(recursive: true)
        ..writeAsBytesSync([0x89, 0x50, 0x4E, 0x47]);

      final notes = await service.reconcile();

      expect(notes, isEmpty);
      expect(await repo.getAll(includeDeleted: true), isEmpty);
    },
  );

  test('skips symlinked note files without following them', () async {
    vault.createSync(recursive: true);
    final outside = File(p.join(root.path, 'outside.md'))
      ..writeAsStringSync('outside');
    final link = Link(p.join(vault.path, 'linked.md'));
    try {
      link.createSync(outside.path);
    } on FileSystemException {
      // Creating symlinks needs privileges on some Windows setups.
      return;
    }

    final notes = await service.reconcile();

    expect(notes, isEmpty);
    expect(await repo.getAll(includeDeleted: true), isEmpty);
    expect(link.existsSync(), isTrue);
  });

  test('skips files that are not valid UTF-8 and reports their path', () async {
    final bad = vaultFile('bad.md')
      ..createSync(recursive: true)
      ..writeAsBytesSync([0xFF, 0xFE, 0x41]);

    final notes = await service.reconcile();

    expect(notes, isEmpty);
    expect(await repo.getAll(includeDeleted: true), isEmpty);
    expect(bad.readAsBytesSync(), [0xFF, 0xFE, 0x41]);
    await expectLater(
      service.importExternalFile(bad),
      throwsA(
        isA<InvalidNoteEncodingException>().having(
          (e) => e.path,
          'path',
          bad.path,
        ),
      ),
    );
  });

  test('reports skipped files and keeps their active row', () async {
    final imported = await importVia('inbox/想法.md', 'hello');
    final encoded = vaultFile(imported.relativePath)
      ..writeAsBytesSync([0xFF, 0xFE, 0x41]);
    final skippedPaths = <String>[];
    final reportingService = NoteVaultService(
      repository: repo,
      paths: _FakeAppPaths(vault),
      onSkippedFile: (path, error) {
        skippedPaths.add(path);
        expect(error, isA<InvalidNoteEncodingException>());
      },
    );

    final notes = await reportingService.reconcile();

    expect(skippedPaths.map(p.normalize), [p.normalize(encoded.path)]);
    final row = (await repo.getById(imported.id))!;
    expect(row.deletedAt, isNull);
    expect(row.relativePath, imported.relativePath);
    expect(notes.map((n) => n.id), [imported.id]);
    expect(encoded.readAsBytesSync(), [0xFF, 0xFE, 0x41]);
  });

  test('keeps the short id for the newest of two files claiming it', () async {
    final older = vaultFile('older~abcd.md')
      ..createSync(recursive: true)
      ..writeAsStringSync('old');
    final newer = vaultFile('newer~abcd.md')
      ..createSync(recursive: true)
      ..writeAsStringSync('new');
    older.setLastModifiedSync(DateTime(2026, 1, 1));
    newer.setLastModifiedSync(DateTime(2026, 6, 1));
    final duplicateService = NoteVaultService(
      repository: repo,
      paths: _FakeAppPaths(vault),
      vaultPath: vault.path,
      shortIdGenerator: () => 'ffff',
    );

    final notes = await duplicateService.reconcile();

    expect(notes, hasLength(2));
    final kept = notes.singleWhere((n) => n.shortId == 'abcd');
    expect(kept.title, 'newer');
    expect(kept.relativePath, 'newer~abcd.md');
    expect(await vaultFile('newer~abcd.md').readAsString(), 'new');

    final reassigned = notes.singleWhere((n) => n.shortId == 'ffff');
    expect(reassigned.title, 'older');
    expect(reassigned.relativePath, 'older~ffff.md');
    expect(await vaultFile('older~ffff.md').readAsString(), 'old');
    expect(vaultFile('older~abcd.md').existsSync(), isFalse);
  });

  test(
    'duplicate resolution avoids ids claimed elsewhere in the scan',
    () async {
      final older = vaultFile('older~abcd.md')
        ..createSync(recursive: true)
        ..writeAsStringSync('old');
      final newer = vaultFile('newer~abcd.md')
        ..createSync(recursive: true)
        ..writeAsStringSync('new');
      vaultFile('third~ffff.md')
        ..createSync(recursive: true)
        ..writeAsStringSync('third');
      older.setLastModifiedSync(DateTime(2026, 1, 1));
      newer.setLastModifiedSync(DateTime(2026, 6, 1));
      var calls = 0;
      final candidates = ['ffff', 'eeee'];
      final duplicateService = NoteVaultService(
        repository: repo,
        paths: _FakeAppPaths(vault),
        vaultPath: vault.path,
        shortIdGenerator: () => candidates[calls++],
      );

      final notes = await duplicateService.reconcile();

      expect(notes, hasLength(3));
      expect(
        notes.singleWhere((n) => n.shortId == 'abcd').relativePath,
        'newer~abcd.md',
      );
      expect(
        notes.singleWhere((n) => n.shortId == 'eeee').relativePath,
        'older~eeee.md',
      );
      expect(
        notes.singleWhere((n) => n.shortId == 'ffff').relativePath,
        'third~ffff.md',
      );
      expect(calls, 2);
    },
  );

  test('imports .MD and .TXT extensions case-insensitively', () async {
    vaultFile('upper.MD')
      ..createSync(recursive: true)
      ..writeAsStringSync('md');
    vaultFile('lower.TXT')
      ..createSync(recursive: true)
      ..writeAsStringSync('txt');

    final notes = await service.reconcile();

    expect(notes.map((n) => n.format).toSet(), {'md', 'txt'});
    expect(notes.map((n) => p.extension(n.relativePath)).toSet(), {
      '.md',
      '.txt',
    });
  });

  test('reconcile is idempotent and does not rewrite unchanged rows', () async {
    vaultFile('inbox/idea.md')
      ..createSync(recursive: true)
      ..writeAsStringSync('idea');
    vaultFile('note.txt')
      ..createSync(recursive: true)
      ..writeAsStringSync('note');

    final countingRepo = _CountingUpdateRepo(db);
    final idempotentService = NoteVaultService(
      repository: countingRepo,
      paths: _FakeAppPaths(vault),
      vaultPath: vault.path,
    );

    await idempotentService.reconcile();
    final before = await countingRepo.getAll(includeDeleted: true);
    final timestampsBefore = {
      for (final note in before) note.id: note.updatedAt,
    };
    final filesBefore = relativeFiles(vault);
    // Every row came from an insert, so nothing needed an update pass.
    expect(countingRepo.updateFileMetaCalls, 0);

    await idempotentService.reconcile();

    expect(countingRepo.updateFileMetaCalls, 0);
    final after = await countingRepo.getAll(includeDeleted: true);
    expect(
      after.map((n) => n.id).toList()..sort(),
      before.map((n) => n.id).toList()..sort(),
    );
    expect(
      after.map((n) => n.relativePath).toList()..sort(),
      before.map((n) => n.relativePath).toList()..sort(),
    );
    for (final note in after) {
      expect(note.updatedAt, timestampsBefore[note.id]);
    }
    expect(relativeFiles(vault), filesBefore);
  });

  test('leaves already soft-deleted rows alone', () async {
    final note = await service.createNote(
      format: NoteFormat.md,
      title: 'trashed',
      content: 'x',
    );
    await service.moveToTrash(note.id);
    final trashed = (await repo.getById(note.id))!;

    await service.reconcile();

    final after = (await repo.getById(note.id))!;
    expect(after.relativePath, trashed.relativePath);
    expect(after.deletedAt, trashed.deletedAt);
  });

  test(
    'switchVault tombstones old rows and revives them on switching back',
    () async {
      final vaultA = Directory(p.join(root.path, 'A'));
      final vaultB = Directory(p.join(root.path, 'B'));
      var calls = 0;
      final candidates = ['aaaa', 'bbbb', 'cccc'];
      final switchingService = NoteVaultService(
        repository: repo,
        paths: _FakeAppPaths(vaultA),
        vaultPath: vaultA.path,
        shortIdGenerator: () => candidates[calls++],
      );
      final original = await switchingService.createNote(
        format: NoteFormat.md,
        title: 'original',
        content: 'content',
      );
      final originalFile = File(p.join(vaultA.path, original.relativePath));
      vaultB.createSync(recursive: true);
      File(p.join(vaultB.path, 'from-b.md'))
        ..createSync(recursive: true)
        ..writeAsStringSync('b');

      await switchingService.switchVault(vaultB.path);

      final oldRow = (await repo.getById(original.id))!;
      expect(oldRow.deletedAt, isNotNull);
      expect(oldRow.relativePath, startsWith('.vault-switch/'));
      expect(oldRow.relativePath, endsWith('/${original.relativePath}'));
      expect(originalFile.existsSync(), isTrue);
      expect(await originalFile.readAsString(), 'content');

      final activeInB = await repo.watchAll().first;
      expect(activeInB, hasLength(1));
      expect(activeInB.single.title, 'from-b');
      expect(activeInB.single.id, isNot(original.id));
      expect(
        File(p.join(vaultB.path, activeInB.single.relativePath)).existsSync(),
        isTrue,
      );

      await switchingService.switchVault(vaultA.path);

      final revived = (await repo.getById(original.id))!;
      expect(revived.deletedAt, isNull);
      expect(revived.shortId, original.shortId);
      expect(revived.relativePath, original.relativePath);
      expect(
        (await repo.watchAll().first).map((n) => n.id),
        contains(original.id),
      );

      final bRow = (await repo.getById(activeInB.single.id))!;
      expect(bRow.deletedAt, isNotNull);
      expect(bRow.relativePath, startsWith('.vault-switch/'));
    },
  );
}

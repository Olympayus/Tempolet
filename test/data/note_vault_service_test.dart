import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:tempolet/core/paths.dart';
import 'package:tempolet/data/database/database.dart';
import 'package:tempolet/data/models/note_format.dart';
import 'package:tempolet/data/repositories/note_repository.dart';
import 'package:tempolet/data/vault/note_conflict.dart';
import 'package:tempolet/data/vault/note_vault_service.dart';

class _FakeAppPaths implements AppPaths {
  _FakeAppPaths(this.directory);

  final Directory directory;

  @override
  Future<Directory> defaultVaultDirectory() async => directory;
}

class _ThrowingInsertRepo extends NoteRepository {
  _ThrowingInsertRepo(super.db);

  @override
  Future<void> insertIndex({
    required String id,
    required String shortId,
    required String title,
    required NoteFormat format,
    required String relativePath,
    required DateTime fileMtime,
    required int fileSize,
  }) async {
    throw StateError('index unavailable');
  }
}

class _ThrowingMarkDeletedRepo extends NoteRepository {
  _ThrowingMarkDeletedRepo(super.db);

  @override
  Future<void> markDeleted(String id, {required String tombstonePath}) async {
    throw StateError('database unavailable');
  }
}

/// Fails the first [tempRenameFailures] attempts to rename a `.tmp` file into
/// place, exercising the retry/backup path of `replaceFileFromTemp`.
class _FlakyRenameService extends NoteVaultService {
  _FlakyRenameService({
    required super.repository,
    required super.paths,
    super.vaultPath,
    required this.tempRenameFailures,
  });

  int tempRenameFailures;
  int tempRenameAttempts = 0;

  @override
  Future<void> renameFile(File source, String target) async {
    if (source.path.endsWith('.tmp')) {
      tempRenameAttempts++;
      if (tempRenameFailures > 0) {
        tempRenameFailures--;
        throw const FileSystemException('rename locked');
      }
    }
    await super.renameFile(source, target);
  }
}

/// Backup files left next to [target] by a failed replacement.
List<File> backupsFor(File target) {
  return target.parent
      .listSync()
      .whereType<File>()
      .where((file) => file.path.startsWith('${target.path}.bak-'))
      .toList();
}

void main() {
  late AppDatabase db;
  late NoteRepository repo;
  late Directory root;
  late Directory defaultVault;
  late _FakeAppPaths paths;
  late NoteVaultService service;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = NoteRepository(db);
    root = Directory.systemTemp.createTempSync('tempolet-vault-');
    defaultVault = Directory(p.join(root.path, 'Tempolet'));
    paths = _FakeAppPaths(defaultVault);
    service = NoteVaultService(repository: repo, paths: paths);
  });

  tearDown(() async {
    await db.close();
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  File vaultFile(Note note) =>
      File(p.join(defaultVault.path, note.relativePath));

  test(
    'createNote writes the file, indexes identity, and reads back',
    () async {
      final note = await service.createNote(
        format: NoteFormat.md,
        title: '产品周会',
        content: '# 会议',
      );

      expect(
        RegExp(r'^产品周会~[0-9a-f]{4}\.md$')
            .hasMatch(p.basename(note.relativePath)),
        isTrue,
      );
      expect(note.title, '产品周会');
      expect(note.format, 'md');
      expect(note.shortId, matches(RegExp(r'^[0-9a-f]{4}$')));
      expect(note.relativePath, '产品周会~${note.shortId}.md');
      expect(note.deletedAt, isNull);

      final file = vaultFile(note);
      expect(file.existsSync(), isTrue);
      expect(await file.readAsString(), '# 会议');
      expect(await service.readNote(note.id), '# 会议');

      final stat = file.statSync();
      expect(note.fileSize, stat.size);
      expect(
        note.fileMtime.millisecondsSinceEpoch ~/ 1000,
        stat.modified.millisecondsSinceEpoch ~/ 1000,
      );
    },
  );

  test(
    'ensureVault treats a null or empty vaultPath as the default directory',
    () async {
      final emptyPathService = NoteVaultService(
        repository: repo,
        paths: paths,
        vaultPath: '',
      );

      final vault = await emptyPathService.ensureVault();
      expect(vault.path, defaultVault.path);
      expect(vault.existsSync(), isTrue);

      final note = await emptyPathService.createNote(
        format: NoteFormat.txt,
        title: 'default',
        content: 'x',
      );
      expect(
        File(p.join(defaultVault.path, note.relativePath)).existsSync(),
        isTrue,
      );

      final nullPathService = NoteVaultService(
        repository: repo,
        paths: paths,
        vaultPath: null,
      );
      expect((await nullPathService.ensureVault()).path, defaultVault.path);
    },
  );

  test('readNote strips a leading UTF-8 BOM and preserves newlines', () async {
    final note = await service.createNote(
      format: NoteFormat.txt,
      title: 'bom',
      content: 'x',
    );
    final file = vaultFile(note);
    await file.writeAsBytes([0xEF, 0xBB, 0xBF, ...utf8.encode('第一行\r\n第二行')]);

    expect(await service.readNote(note.id), '第一行\r\n第二行');
  });

  test('writeNote writes UTF-8 without a BOM and preserves newlines', () async {
    final note = await service.createNote(
      format: NoteFormat.md,
      title: '写',
      content: 'old',
    );
    const content = '新\r\n行';

    await service.writeNote(note.id, content);

    final file = vaultFile(note);
    expect(await file.readAsBytes(), utf8.encode(content));
    expect(await service.readNote(note.id), content);
    expect(File('${file.path}.tmp').existsSync(), isFalse);

    final updated = (await repo.getById(note.id))!;
    expect(updated.fileSize, utf8.encode(content).length);
    expect(updated.relativePath, note.relativePath);
  });

  test('writeNote refuses to overwrite an externally modified file', () async {
    final note = await service.createNote(
      format: NoteFormat.md,
      title: '产品周会',
      content: '# 会议',
    );
    final file = vaultFile(note);
    await file.writeAsString('外部修改');

    await expectLater(
      service.writeNote(note.id, '应用内修改'),
      throwsA(
        isA<NoteConflictException>()
            .having((e) => e.noteId, 'noteId', note.id)
            .having(
              (e) => e.actualSize,
              'actualSize',
              utf8.encode('外部修改').length,
            )
            .having(
              (e) => e.expectedSize,
              'expectedSize',
              utf8.encode('# 会议').length,
            ),
      ),
    );
    expect(await file.readAsString(), '外部修改');
  });

  test('writeNote detects an mtime-only mismatch', () async {
    final note = await service.createNote(
      format: NoteFormat.md,
      title: 'mtime',
      content: 'same',
    );
    final file = vaultFile(note);
    await file.setLastModified(DateTime.now().add(const Duration(minutes: 5)));

    await expectLater(
      service.writeNote(note.id, 'same'),
      throwsA(isA<NoteConflictException>()),
    );
  });

  test('renameNote renames the file and updates the index', () async {
    final note = await service.createNote(
      format: NoteFormat.md,
      title: '旧标题',
      content: 'x',
    );

    await service.renameNote(note.id, '新/标题');

    final renamed = (await repo.getById(note.id))!;
    expect(renamed.title, '新_标题');
    expect(renamed.relativePath, '新_标题~${note.shortId}.md');
    expect(
      File(p.join(defaultVault.path, renamed.relativePath)).existsSync(),
      isTrue,
    );
    expect(vaultFile(note).existsSync(), isFalse);
    expect(await service.readNote(note.id), 'x');
  });

  test('moveToTrash moves the file and soft-deletes the row', () async {
    final note = await service.createNote(
      format: NoteFormat.md,
      title: '产品周会',
      content: '# 会议',
    );
    final original = vaultFile(note);

    await service.moveToTrash(note.id);

    final trashed = (await repo.getById(note.id))!;
    expect(trashed.deletedAt, isNotNull);
    expect(trashed.relativePath, startsWith('.trash/'));
    expect(
      RegExp(
        r'^\.trash/\d{8}-\d{6}-' + RegExp.escape(note.shortId) + r'-产品周会\.md$',
      ).hasMatch(trashed.relativePath),
      isTrue,
    );
    expect(original.existsSync(), isFalse);

    final moved = File(p.join(defaultVault.path, trashed.relativePath));
    expect(moved.existsSync(), isTrue);
    expect(await moved.readAsString(), '# 会议');
    expect((await repo.getAll()).map((n) => n.id), isNot(contains(note.id)));
  });

  test('createNote retries short id allocation on collision', () async {
    await repo.insertIndex(
      id: 'existing',
      shortId: 'abcd',
      title: 'older',
      format: NoteFormat.md,
      relativePath: 'older~abcd.md',
      fileMtime: DateTime(2026, 11, 14),
      fileSize: 1,
    );
    final candidates = ['abcd', 'abcd', 'beef'];
    var calls = 0;
    final collisionService = NoteVaultService(
      repository: repo,
      paths: paths,
      vaultPath: root.path,
      shortIdGenerator: () => candidates[calls++],
    );

    final note = await collisionService.createNote(
      format: NoteFormat.md,
      title: 'new',
      content: 'x',
    );

    expect(note.shortId, 'beef');
    expect(calls, 3);
    expect(File(p.join(root.path, note.relativePath)).existsSync(), isTrue);
  });

  test(
    'createNote deletes the written file when the index insert fails',
    () async {
      final failingService = NoteVaultService(
        repository: _ThrowingInsertRepo(db),
        paths: paths,
        vaultPath: root.path,
      );

      await expectLater(
        failingService.createNote(
          format: NoteFormat.md,
          title: 'x',
          content: 'y',
        ),
        throwsStateError,
      );

      expect(Directory(root.path).existsSync(), isTrue);
      expect(
        Directory(root.path)
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.md')),
        isEmpty,
      );
    },
  );

  test('moveToTrash restores the file when the index update fails', () async {
    final failingService = NoteVaultService(
      repository: _ThrowingMarkDeletedRepo(db),
      paths: paths,
      vaultPath: root.path,
    );
    final note = await failingService.createNote(
      format: NoteFormat.md,
      title: 'x',
      content: 'y',
    );

    await expectLater(failingService.moveToTrash(note.id), throwsStateError);

    expect(File(p.join(root.path, note.relativePath)).existsSync(), isTrue);
    final trash = Directory(p.join(root.path, '.trash'));
    expect(trash.listSync().whereType<File>(), isEmpty);
    expect((await repo.getById(note.id))!.deletedAt, isNull);
  });

  test(
    'replaceFileFromTemp replaces the target and removes the temp',
    () async {
      final target = File(p.join(root.path, 'note.md'))
        ..writeAsStringSync('old');
      final temp = File('${target.path}.tmp')..writeAsStringSync('new');

      await service.replaceFileFromTemp(target, temp);

      expect(await target.readAsString(), 'new');
      expect(temp.existsSync(), isFalse);
      expect(backupsFor(target), isEmpty);
    },
  );

  test(
    'replaceFileFromTemp recovers with a backup when the direct rename fails',
    () async {
      final target = File(p.join(root.path, 'note.md'))
        ..writeAsStringSync('old');
      final temp = File('${target.path}.tmp')..writeAsStringSync('new');
      // All three direct attempts fail; the backup dance then succeeds.
      final flaky = _FlakyRenameService(
        repository: repo,
        paths: paths,
        vaultPath: root.path,
        tempRenameFailures: 3,
      );

      await flaky.replaceFileFromTemp(target, temp);

      expect(flaky.tempRenameAttempts, 4);
      expect(await target.readAsString(), 'new');
      expect(temp.existsSync(), isFalse);
      expect(backupsFor(target), isEmpty);
    },
  );

  test(
    'writeNote restores the original and keeps the temp on double failure',
    () async {
      final note = await service.createNote(
        format: NoteFormat.md,
        title: 'guarded',
        content: 'old',
      );
      final file = vaultFile(note);
      final flaky = _FlakyRenameService(
        repository: repo,
        paths: paths,
        vaultPath: defaultVault.path,
        // Every temp rename fails, including the post-backup one.
        tempRenameFailures: 1 << 20,
      );

      await expectLater(
        flaky.writeNote(note.id, 'new'),
        throwsA(isA<FileSystemException>()),
      );

      expect(await file.readAsString(), 'old');
      final temp = File('${file.path}.tmp');
      expect(temp.existsSync(), isTrue);
      expect(await temp.readAsString(), 'new');
      expect(backupsFor(file), isEmpty);

      // The index still describes the untouched original.
      final row = (await repo.getById(note.id))!;
      expect(row.fileSize, utf8.encode('old').length);
    },
  );

  test('writeNote rejects a soft-deleted note', () async {
    final note = await service.createNote(
      format: NoteFormat.md,
      title: 'trashed',
      content: 'old',
    );
    await service.moveToTrash(note.id);

    await expectLater(service.writeNote(note.id, 'new'), throwsStateError);
  });

  test('writeNote reports a file missing from disk as a conflict', () async {
    final note = await service.createNote(
      format: NoteFormat.md,
      title: 'missing',
      content: 'old',
    );
    vaultFile(note).deleteSync();

    await expectLater(
      service.writeNote(note.id, 'new'),
      throwsA(
        isA<NoteConflictException>().having((e) => e.noteId, 'noteId', note.id),
      ),
    );
  });

  test('createNote treats an existing file as a short id collision', () async {
    final orphan = File(p.join(root.path, 'x~abcd.md'))
      ..writeAsStringSync('orphan');
    var calls = 0;
    final candidates = ['abcd', 'beef'];
    final collisionService = NoteVaultService(
      repository: repo,
      paths: paths,
      vaultPath: root.path,
      shortIdGenerator: () => candidates[calls++],
    );

    final note = await collisionService.createNote(
      format: NoteFormat.md,
      title: 'x',
      content: 'new',
    );

    expect(note.shortId, 'beef');
    expect(await orphan.readAsString(), 'orphan');
    expect(
      await File(p.join(root.path, note.relativePath)).readAsString(),
      'new',
    );
  });
}

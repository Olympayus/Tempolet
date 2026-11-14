import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../core/paths.dart';
import '../database/database.dart';
import '../models/note_format.dart';
import '../repositories/note_repository.dart';
import 'note_conflict.dart';
import 'note_filename.dart';

/// Raised by `NoteVaultService.importExternalFile` (and caught by `reconcile`)
/// when a note file is not valid UTF-8. The file is left untouched and is not
/// imported or converted.
class InvalidNoteEncodingException implements Exception {
  InvalidNoteEncodingException(this.path);

  /// Absolute path of the file that could not be decoded.
  final String path;

  @override
  String toString() => 'InvalidNoteEncodingException($path)';
}

/// Owns the note lifecycle across the index and the vault files. Every write
/// goes file-first (or with a rollback) so the index and the on-disk vault stay
/// in sync; this service is the only thing that should touch note files.
class NoteVaultService {
  NoteVaultService({
    required NoteRepository repository,
    required AppPaths paths,
    String? vaultPath,
    String Function()? shortIdGenerator,
    void Function(String path, Object error)? onSkippedFile,
  }) : // The public names differ from the private fields, so the lint's
       // initializing-formal suggestion cannot apply to named parameters.
       // ignore: prefer_initializing_formals
       _repository = repository,
       // ignore: prefer_initializing_formals
       _paths = paths,
       // An empty preference means "use the platform default", exactly like an
       // absent one. Never let callers construct Directory('').
       _vaultPath = _normalizeVaultPath(vaultPath),
       _shortIdGenerator = shortIdGenerator ?? _defaultShortId,
       // ignore: prefer_initializing_formals
       _onSkippedFile = onSkippedFile;

  final NoteRepository _repository;
  final AppPaths _paths;
  String? _vaultPath;
  final String Function() _shortIdGenerator;

  /// Optional record channel for files that reconciliation could not import
  /// (invalid UTF-8 or an IO failure). The data layer never prints.
  final void Function(String path, Object error)? _onSkippedFile;

  Directory? _vault;

  static String? _normalizeVaultPath(String? path) {
    if (path == null) return null;
    final trimmed = path.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static String _defaultShortId() => const Uuid().v4().substring(0, 4);

  /// Ensures the vault directory exists and returns it. This is the spec's
  /// `initialize(vaultPath)`; it is cheap to call before every operation.
  Future<Directory> ensureVault() async {
    final cached = _vault;
    if (cached != null) return cached;

    final vaultPath = _vaultPath;
    final directory = vaultPath == null
        ? await _paths.defaultVaultDirectory()
        : Directory(vaultPath);
    await directory.create(recursive: true);
    _vault = directory;
    return directory;
  }

  /// Creates the body file first, then inserts the index row. A failed index
  /// insert deletes the just-written file (and leaves it to reconciliation if
  /// even that fails).
  Future<Note> createNote({
    required NoteFormat format,
    required String title,
    required String content,
  }) async {
    final vault = await ensureVault();
    final id = const Uuid().v4();
    final safeTitle = sanitizeNoteTitle(title);

    String? shortId;
    String? relativePath;
    for (var attempt = 0; attempt < 20; attempt++) {
      final candidateShortId = await _allocateShortId();
      final candidatePath = buildNoteFileName(
        title: safeTitle,
        shortId: candidateShortId,
        format: format,
      );
      if (await File(p.join(vault.path, candidatePath)).exists()) {
        // An orphan file already owns this name; never truncate it. Treat it
        // like a short id collision and try another id.
        continue;
      }
      shortId = candidateShortId;
      relativePath = candidatePath;
      break;
    }
    if (shortId == null || relativePath == null) {
      throw StateError(
        'Could not allocate a free note filename after 20 tries',
      );
    }

    final file = File(p.join(vault.path, relativePath));
    await file.writeAsString(content, flush: true);
    try {
      final stat = await file.stat();
      await _repository.insertIndex(
        id: id,
        shortId: shortId,
        title: safeTitle,
        format: format,
        relativePath: relativePath,
        fileMtime: stat.modified,
        fileSize: stat.size,
      );
    } catch (_) {
      try {
        await file.delete();
      } catch (_) {
        // Reconciliation will import the orphan next launch.
      }
      rethrow;
    }

    final note = await _repository.getById(id);
    if (note == null) {
      throw StateError('Note $id disappeared right after insertion');
    }
    return note;
  }

  /// Reads the body as UTF-8, tolerating and stripping a leading BOM. Newlines
  /// are returned exactly as stored.
  Future<String> readNote(String id) async {
    final note = await _requireNote(id);
    final vault = await ensureVault();
    final bytes = await File(p.join(vault.path, note.relativePath))
        .readAsBytes();
    final content = utf8.decode(bytes);
    if (content.isNotEmpty && content.codeUnitAt(0) == 0xFEFF) {
      return content.substring(1);
    }
    return content;
  }

  /// Replaces the body after verifying the file still matches the index. The
  /// new bytes are written to a sibling temp file and renamed over the target;
  /// a mismatch throws [NoteConflictException] without touching the file.
  Future<void> writeNote(String id, String content) async {
    final note = await _requireNote(id);
    if (note.deletedAt != null) {
      throw StateError('Cannot write a deleted note: $id');
    }

    final vault = await ensureVault();
    final file = File(p.join(vault.path, note.relativePath));

    final before = await file.stat();
    if (before.type == FileSystemEntityType.notFound) {
      // The index still references a file that no longer exists. Surface it as
      // a conflict instead of leaking a raw FileSystemException.
      throw NoteConflictException(
        noteId: id,
        expectedMtime: note.fileMtime,
        actualMtime: before.modified,
        expectedSize: note.fileSize,
        actualSize: before.size,
      );
    }
    if (before.size != note.fileSize ||
        !_sameSecond(before.modified, note.fileMtime)) {
      throw NoteConflictException(
        noteId: id,
        expectedMtime: note.fileMtime,
        actualMtime: before.modified,
        expectedSize: note.fileSize,
        actualSize: before.size,
      );
    }

    final temp = File('${file.path}.tmp');
    try {
      await temp.writeAsString(content, flush: true);
    } catch (_) {
      await _deleteQuietly(temp);
      rethrow;
    }

    // On failure the helper restores the original file and keeps the temp,
    // which holds the only copy of the new content; never delete it here.
    await replaceFileFromTemp(file, temp);

    final after = await file.stat();
    await _repository.updateFileMeta(
      id,
      relativePath: note.relativePath,
      title: note.title,
      fileMtime: after.modified,
      fileSize: after.size,
    );
  }

  /// Number of attempts for the direct rename in [replaceFileFromTemp] before
  /// falling back to the backup dance (spec §10.1 asks for a short retry).
  static const int _replaceAttempts = 3;
  static const Duration _replaceRetryDelay = Duration(milliseconds: 50);

  /// Rename seam used by [replaceFileFromTemp]. Tests override this to
  /// simulate platform rename failures without touching the real filesystem.
  @visibleForTesting
  Future<void> renameFile(File source, String target) => source.rename(target);

  /// Replaces [target] with the already-written [temp] file. Exposed for tests
  /// so the Windows fallback can be exercised.
  ///
  /// The target is never deleted before the new content is in place: the
  /// first attempts rename [temp] over it; on failure the target is moved to a
  /// `<target>.bak-<timestamp>` sibling, the temp is renamed into place, and
  /// the backup is removed on success. If that last rename also fails, the
  /// backup is restored and the temp file is kept for recovery.
  @visibleForTesting
  Future<void> replaceFileFromTemp(File target, File temp) async {
    for (var attempt = 0; attempt < _replaceAttempts; attempt++) {
      if (attempt > 0) {
        await Future<void>.delayed(_replaceRetryDelay);
      }
      try {
        await renameFile(temp, target.path);
        return;
      } on FileSystemException {
        // Windows refuses rename-over in some cases; retry, then fall back.
      }
    }

    File? backup;
    if (await target.exists()) {
      final backupFile = File(
        '${target.path}.bak-${DateTime.now().millisecondsSinceEpoch}',
      );
      await renameFile(target, backupFile.path);
      backup = backupFile;
    }

    try {
      await renameFile(temp, target.path);
    } catch (_) {
      if (backup != null) {
        try {
          await renameFile(backup, target.path);
        } catch (_) {
          // Leave the backup in place: it still holds the old content.
        }
      }
      // Keep the temp file: it holds the only copy of the new content.
      rethrow;
    }
    if (backup != null) {
      await _deleteQuietly(backup);
    }
  }

  /// Renames the body file first, then updates the index; on an index failure
  /// the file is renamed back.
  Future<void> renameNote(String id, String title) async {
    final note = await _requireNote(id);
    if (note.deletedAt != null) {
      throw StateError('Cannot rename a deleted note: $id');
    }

    final vault = await ensureVault();
    final format = NoteFormat.values.byName(note.format);
    final safeTitle = sanitizeNoteTitle(title);
    final fileName = buildNoteFileName(
      title: safeTitle,
      shortId: note.shortId,
      format: format,
    );
    final relativeDir = p.posix.dirname(note.relativePath);
    final relativePath = relativeDir == '.'
        ? fileName
        : '$relativeDir/$fileName';

    if (relativePath == note.relativePath) return;

    final oldFile = File(p.join(vault.path, note.relativePath));
    final newFile = File(p.join(vault.path, relativePath));
    await oldFile.rename(newFile.path);
    try {
      final stat = await newFile.stat();
      await _repository.updateFileMeta(
        id,
        relativePath: relativePath,
        title: safeTitle,
        fileMtime: stat.modified,
        fileSize: stat.size,
      );
    } catch (_) {
      try {
        await newFile.rename(oldFile.path);
      } catch (_) {
        // Reconciliation will notice the dangling index row.
      }
      rethrow;
    }
  }

  /// Soft-deletes the note and moves its file into `.trash/`. A failed index
  /// update moves the file back; user files are never physically deleted.
  Future<void> moveToTrash(String id) async {
    final note = await _requireNote(id);
    if (note.deletedAt != null) return;

    final vault = await ensureVault();
    final trash = Directory(p.join(vault.path, '.trash'));
    await trash.create(recursive: true);

    final format = NoteFormat.values.byName(note.format);
    final stamp = DateFormat('yyyyMMdd-HHmmss').format(DateTime.now());
    final fileName =
        '$stamp-${note.shortId}-${sanitizeNoteTitle(note.title)}.${format.extension}';
    final source = File(p.join(vault.path, note.relativePath));
    final target = File(p.join(trash.path, fileName));

    await source.rename(target.path);
    try {
      await _repository.markDeleted(id, tombstonePath: '.trash/$fileName');
    } catch (_) {
      try {
        await target.rename(source.path);
      } catch (_) {
        // Reconciliation will import the stray trash file.
      }
      rethrow;
    }
  }

  /// Imports [file] into the vault, renaming it to the canonical
  /// `<title>~<shortId>.<ext>` shape while preserving its relative directory.
  ///
  /// A short id found in the filename is reused: when it matches an index row
  /// (including soft-deleted ones) that row is updated and revived, otherwise a
  /// new row is created with the same id. Files without a usable id get a fresh
  /// short id and UUID.
  Future<Note> importExternalFile(File file) =>
      _importFile(file, reuseShortId: true);

  /// Scans the vault and reconciles the index with the files on disk.
  ///
  /// Files with a valid `~<shortId>` are matched against all index rows
  /// (including soft-deleted), then imported. Rows whose files disappeared are
  /// soft-deleted with a `.lost/` tombstone path without touching the disk.
  /// Idempotent, and returns the same list as `watchAll().first`.
  Future<List<Note>> reconcile() async {
    final vault = await ensureVault();
    final files = await _scanNoteFiles(vault);

    final byShortId = <String, List<File>>{};
    final withoutShortId = <File>[];
    for (final file in files) {
      final shortId = parseShortId(p.basename(file.path));
      if (shortId == null) {
        withoutShortId.add(file);
      } else {
        byShortId.putIfAbsent(shortId, () => <File>[]).add(file);
      }
    }

    final seenIds = <String>{};
    final scannedShortIds = byShortId.keys.toSet();

    Future<void> recordSkip(File file, String? shortId, Object error) async {
      _onSkippedFile?.call(file.path, error);
      // The file still exists, so the index row it claims is not "missing":
      // do not let rule 4 tombstone it.
      if (shortId == null || !await file.exists()) return;
      final row = await _repository.getByShortId(shortId);
      if (row != null) seenIds.add(row.id);
    }

    Future<void> importBatch(
      Iterable<File> batch, {
      required String? shortId,
      required bool reuseFirstShortId,
    }) async {
      var index = 0;
      for (final file in batch) {
        try {
          final note = await _importFile(
            file,
            reuseShortId: reuseFirstShortId && index == 0,
            reservedShortIds: scannedShortIds,
          );
          seenIds.add(note.id);
        } on InvalidNoteEncodingException catch (error) {
          await recordSkip(file, shortId, error);
        } on FileSystemException catch (error) {
          await recordSkip(file, shortId, error);
        }
        index++;
      }
    }

    for (final shortId in byShortId.keys.toList()..sort()) {
      final group = byShortId[shortId]!;
      if (group.length > 1) {
        // Several files claim one short id: the newest mtime wins, the rest get
        // a new identity and are renamed.
        final mtimes = <String, DateTime>{};
        for (final file in group) {
          mtimes[file.path] = await _lastModified(file);
        }
        group.sort((a, b) {
          final byTime = mtimes[b.path]!.compareTo(mtimes[a.path]!);
          return byTime != 0 ? byTime : a.path.compareTo(b.path);
        });
      }
      await importBatch(group, shortId: shortId, reuseFirstShortId: true);
    }
    await importBatch(withoutShortId, shortId: null, reuseFirstShortId: false);

    final stamp = DateFormat('yyyyMMdd-HHmmss').format(DateTime.now());
    final rows = await _repository.getAll(includeDeleted: true);
    for (final row in rows) {
      if (row.deletedAt != null || seenIds.contains(row.id)) continue;
      final originalName = p.posix.basename(row.relativePath);
      await _repository.markDeleted(
        row.id,
        tombstonePath: '.lost/$stamp-${row.shortId}-$originalName',
      );
    }

    return _repository.watchAll().first;
  }

  /// Soft-deletes the active rows of the current vault, switches to [path]
  /// (null/empty means the platform default) and reconciles the new vault. Old
  /// files stay untouched; switching back revives rows by short id.
  Future<void> switchVault(String? path) async {
    final stamp = DateFormat('yyyyMMdd-HHmmss').format(DateTime.now());
    final active = await _repository.getAll();
    for (final note in active) {
      await _repository.markDeleted(
        note.id,
        tombstonePath: '.vault-switch/$stamp/${note.relativePath}',
      );
    }

    _vaultPath = _normalizeVaultPath(path);
    _vault = null; // Rebuild the cached directory for the new vault.
    await reconcile();
  }

  /// Imports [file] as a note, reusing a parsed short id when asked and
  /// avoiding [reservedShortIds] (short ids that other files in the current
  /// scan claim) when allocating a fresh one.
  Future<Note> _importFile(
    File file, {
    required bool reuseShortId,
    Set<String> reservedShortIds = const {},
  }) async {
    final vault = await ensureVault();
    await _ensureUtf8(file);

    final fileName = p.basename(file.path);
    final format = _formatForPath(file.path);
    final relativeDir = _relativeDirectoryOf(file.path, vault.path);
    final title = sanitizeNoteTitle(titleFromNoteFileName(fileName));

    final parsedShortId = reuseShortId ? parseShortId(fileName) : null;
    Note? existing;
    String? shortId;
    if (parsedShortId != null) {
      existing = await _repository.getByShortId(parsedShortId);
      shortId = parsedShortId;
    }

    String? relativePath;
    File? target;
    for (var attempt = 0; attempt < 20; attempt++) {
      shortId ??= await _allocateShortId(reserved: reservedShortIds);
      final name = buildNoteFileName(
        title: title,
        shortId: shortId,
        format: format,
      );
      final candidatePath = relativeDir.isEmpty ? name : '$relativeDir/$name';
      final candidate = File(p.join(vault.path, candidatePath));
      if (p.equals(candidate.path, file.path) || !await candidate.exists()) {
        relativePath = candidatePath;
        target = candidate;
        break;
      }
      // Another file already owns the canonical name; treat it as a short id
      // collision and import this file under a fresh identity.
      existing = null;
      shortId = null;
    }
    if (shortId == null || relativePath == null || target == null) {
      throw StateError(
        'Could not allocate a free note filename after 20 tries',
      );
    }

    final originalPath = file.path;
    final renamed = !p.equals(originalPath, target.path);
    if (renamed) {
      await file.rename(target.path);
    }

    try {
      final stat = await target.stat();
      if (existing != null) {
        final revive = existing.deletedAt != null;
        final pathChanged = existing.relativePath != relativePath;
        // Spec §6.2: the format is derived from the extension only, so an
        // external .md -> .txt rename must update the row, not just the path.
        final formatChanged = existing.format != format.extension;
        final changed =
            pathChanged ||
            formatChanged ||
            existing.title != title ||
            existing.fileSize != stat.size ||
            !_sameSecond(existing.fileMtime, stat.modified);
        // Reconcile runs on every window focus; only write when something
        // actually changed so repeated runs keep updatedAt (and watchAll's
        // ordering) stable.
        if (!changed && !revive) return existing;

        await _repository.updateFileMeta(
          existing.id,
          relativePath: relativePath,
          title: title,
          fileMtime: stat.modified,
          fileSize: stat.size,
          format: pathChanged || formatChanged ? format : null,
          revive: revive,
        );
        final note = await _repository.getById(existing.id);
        if (note == null) {
          throw StateError('Note ${existing.id} disappeared during import');
        }
        return note;
      }

      final id = const Uuid().v4();
      await _repository.insertIndex(
        id: id,
        shortId: shortId,
        title: title,
        format: format,
        relativePath: relativePath,
        fileMtime: stat.modified,
        fileSize: stat.size,
      );
      final note = await _repository.getById(id);
      if (note == null) {
        throw StateError('Note $id disappeared right after insertion');
      }
      return note;
    } catch (_) {
      if (renamed) {
        try {
          await target.rename(originalPath);
        } catch (_) {
          // Reconciliation will notice the dangling index row.
        }
      }
      rethrow;
    }
  }

  /// Recursively lists note files, skipping hidden entries (which covers
  /// `.trash/`, `.lost/` and `.vault-switch/`), symlinks and non-note files.
  Future<List<File>> _scanNoteFiles(Directory vault) async {
    final files = <File>[];
    await for (final entity in vault.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is! File) continue; // Directories and links are skipped.
      final segments = p.split(p.relative(entity.path, from: vault.path));
      if (segments.any((segment) => segment.startsWith('.'))) continue;
      final extension = p.extension(entity.path).toLowerCase();
      if (extension != '.md' && extension != '.txt') continue;
      files.add(entity);
    }
    files.sort((a, b) => a.path.compareTo(b.path));
    return files;
  }

  Future<void> _ensureUtf8(File file) async {
    final bytes = await file.readAsBytes();
    try {
      utf8.decode(bytes);
    } on FormatException {
      throw InvalidNoteEncodingException(file.path);
    }
  }

  static NoteFormat _formatForPath(String path) {
    final extension = p.extension(path).toLowerCase();
    for (final format in NoteFormat.values) {
      if ('.${format.extension}' == extension) return format;
    }
    throw ArgumentError.value(path, 'file', 'Not a note file (.txt or .md)');
  }

  /// The file's directory relative to the vault with forward slashes, or an
  /// empty string for files at the vault root (or outside the vault).
  static String _relativeDirectoryOf(String filePath, String vaultPath) {
    if (!p.isWithin(vaultPath, filePath)) return '';
    final relative = p.relative(filePath, from: vaultPath);
    final segments = p.split(relative)..removeLast();
    return segments.join('/');
  }

  static Future<DateTime> _lastModified(File file) async {
    final stat = await file.stat();
    return stat.type == FileSystemEntityType.notFound
        ? DateTime.fromMillisecondsSinceEpoch(0)
        : stat.modified;
  }

  static Future<void> _deleteQuietly(File file) async {
    try {
      await file.delete();
    } catch (_) {
      // Best effort cleanup only.
    }
  }

  Future<Note> _requireNote(String id) async {
    final note = await _repository.getById(id);
    if (note == null) throw StateError('Note not found: $id');
    return note;
  }

  /// Allocates a short id that no index row (including soft-deleted rows) or
  /// [reserved] value claims, retrying a bounded number of times.
  Future<String> _allocateShortId({Set<String> reserved = const {}}) async {
    for (var attempt = 0; attempt < 20; attempt++) {
      final candidate = _shortIdGenerator().toLowerCase();
      if (reserved.contains(candidate)) continue;
      if (await _repository.getByShortId(candidate) == null) {
        return candidate;
      }
    }
    throw StateError('Could not allocate a unique short id after 20 attempts');
  }

  /// Drift stores timestamps at second precision, while `File.stat` returns
  /// milliseconds; compare at the precision the index can actually hold.
  static bool _sameSecond(DateTime a, DateTime b) =>
      a.millisecondsSinceEpoch ~/ 1000 == b.millisecondsSinceEpoch ~/ 1000;
}

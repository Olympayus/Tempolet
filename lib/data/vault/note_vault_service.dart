import 'dart:convert';
import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../core/paths.dart';
import '../database/database.dart';
import '../models/note_format.dart';
import '../repositories/note_repository.dart';
import 'note_conflict.dart';
import 'note_filename.dart';

/// Owns the note lifecycle across the index and the vault files. Every write
/// goes file-first (or with a rollback) so the index and the on-disk vault stay
/// in sync; this service is the only thing that should touch note files.
class NoteVaultService {
  NoteVaultService({
    required NoteRepository repository,
    required AppPaths paths,
    String? vaultPath,
    String Function()? shortIdGenerator,
  }) : // The public names differ from the private fields, so the lint's
       // initializing-formal suggestion cannot apply to named parameters.
       // ignore: prefer_initializing_formals
       _repository = repository,
       // ignore: prefer_initializing_formals
       _paths = paths,
       // An empty preference means "use the platform default", exactly like an
       // absent one. Never let callers construct Directory('').
       _vaultPath = _normalizeVaultPath(vaultPath),
       _shortIdGenerator = shortIdGenerator ?? _defaultShortId;

  final NoteRepository _repository;
  final AppPaths _paths;
  final String? _vaultPath;
  final String Function() _shortIdGenerator;

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

    final directory = _vaultPath == null
        ? await _paths.defaultVaultDirectory()
        : Directory(_vaultPath);
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
    final shortId = await _allocateShortId();
    final safeTitle = sanitizeNoteTitle(title);
    final relativePath = buildNoteFileName(
      title: safeTitle,
      shortId: shortId,
      format: format,
    );
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
    final vault = await ensureVault();
    final file = File(p.join(vault.path, note.relativePath));

    final before = await file.stat();
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
      try {
        await temp.rename(file.path);
      } on FileSystemException {
        // Windows refuses rename-over in some cases; the brief's fallback is
        // delete-then-rename.
        await file.delete();
        await temp.rename(file.path);
      }
    } catch (_) {
      if (await temp.exists()) {
        try {
          await temp.delete();
        } catch (_) {
          // Leave the temp file for cleanup.
        }
      }
      rethrow;
    }

    final after = await file.stat();
    await _repository.updateFileMeta(
      id,
      relativePath: note.relativePath,
      title: note.title,
      fileMtime: after.modified,
      fileSize: after.size,
    );
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

  /// Task 8: imports an external file into the vault, renaming it to the
  /// canonical `<title>~<shortId>.<ext>` shape.
  Future<Note> importExternalFile(File file) {
    throw UnimplementedError('importExternalFile is implemented in Task 8');
  }

  /// Task 8: scans the vault and reconciles the index with the files on disk.
  Future<List<Note>> reconcile() {
    throw UnimplementedError('reconcile is implemented in Task 8');
  }

  /// Task 8: soft-deletes the current vault rows and switches to [path].
  Future<void> switchVault(String? path) {
    throw UnimplementedError('switchVault is implemented in Task 8');
  }

  Future<Note> _requireNote(String id) async {
    final note = await _repository.getById(id);
    if (note == null) throw StateError('Note not found: $id');
    return note;
  }

  /// Allocates a short id that no index row (including soft-deleted rows)
  /// claims, retrying a bounded number of times.
  Future<String> _allocateShortId() async {
    for (var attempt = 0; attempt < 20; attempt++) {
      final candidate = _shortIdGenerator().toLowerCase();
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

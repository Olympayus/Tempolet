/// Raised by `NoteVaultService.writeNote` when the file on disk no longer
/// matches what the index recorded. The file is left untouched so the caller
/// can surface a conflict instead of silently overwriting external edits.
class NoteConflictException implements Exception {
  NoteConflictException({
    required this.noteId,
    required this.expectedMtime,
    required this.actualMtime,
    required this.expectedSize,
    required this.actualSize,
  });

  final String noteId;

  /// Modification time recorded in the index.
  final DateTime expectedMtime;

  /// Modification time observed on disk before writing.
  final DateTime actualMtime;

  /// File size recorded in the index.
  final int expectedSize;

  /// File size observed on disk before writing.
  final int actualSize;

  @override
  String toString() =>
      'NoteConflictException(noteId: $noteId, expectedMtime: $expectedMtime, '
      'actualMtime: $actualMtime, expectedSize: $expectedSize, '
      'actualSize: $actualSize)';
}

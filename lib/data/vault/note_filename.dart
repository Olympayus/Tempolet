import 'package:path/path.dart' as p;

import '../models/note_format.dart';

/// Filename rules for note bodies. The vault is a plain directory of UTF-8
/// files, so names must stay portable (Windows is the strictest target) while
/// carrying a stable identity suffix: `<title>~<shortId>.<ext>`.
const int maxNoteTitleRunes = 80;

final RegExp _illegalCharacters = RegExp(r'[<>:"/\\|?*\x00-\x1F\x7F]');
final RegExp _whitespaceRuns = RegExp(r'\s+');
final RegExp _shortIdSuffix = RegExp(r'~([0-9a-f]{4})$');
final RegExp _reservedName = RegExp(r'^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])$');

/// Cleans a user-supplied title until it is safe to use as a Windows filename
/// stem. Illegal characters and control characters become `_`, reserved device
/// names gain a leading `_`, whitespace is trimmed and collapsed, an empty
/// title falls back to `Untitled`, and the result is capped at
/// [maxNoteTitleRunes] runes.
String sanitizeNoteTitle(String title) {
  var result = title.replaceAll(_illegalCharacters, '_');
  result = result.replaceAll(_whitespaceRuns, ' ').trim();

  // Windows reserves device names regardless of extension or case, and the
  // final name is `<title>~<shortId>.<ext>` — the part before the first dot is
  // what Windows checks.
  final deviceStem = result.split('.').first.toUpperCase();
  if (_reservedName.hasMatch(deviceStem)) {
    result = '_$result';
  }

  if (result.isEmpty) return 'Untitled';

  final runes = result.runes.toList();
  if (runes.length > maxNoteTitleRunes) {
    result = String.fromCharCodes(runes.take(maxNoteTitleRunes)).trim();
  }
  return result.isEmpty ? 'Untitled' : result;
}

/// Returns the lower-case four-hex short id embedded at the end of [fileName]
/// (after dropping the extension), or null when the name has no id.
String? parseShortId(String fileName) {
  final stem = p.basenameWithoutExtension(fileName);
  final match = _shortIdSuffix.firstMatch(stem);
  return match?.group(1);
}

/// Builds the canonical vault filename: sanitized [title], a lower-cased
/// [shortId], and the lower-cased format extension.
String buildNoteFileName({
  required String title,
  required String shortId,
  required NoteFormat format,
}) {
  final safeTitle = sanitizeNoteTitle(title);
  final safeShortId = shortId.toLowerCase();
  return '$safeTitle~$safeShortId.${format.extension.toLowerCase()}';
}

/// Recovers the display title from a vault [fileName], dropping a valid
/// `~shortId` suffix and the extension. Filenames without a valid id keep
/// their full stem.
String titleFromNoteFileName(String fileName) {
  final stem = p.basenameWithoutExtension(fileName);
  final match = _shortIdSuffix.firstMatch(stem);
  final title = match == null ? stem : stem.substring(0, match.start);
  return title.isEmpty ? 'Untitled' : title;
}

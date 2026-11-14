/// A single week or week range: `1` or `1-16`.
final _segment = RegExp(r'^(\d{1,2})(?:-(\d{1,2}))?$');

/// Validates a course week pattern such as `1-16,18`.
///
/// The pattern is a comma-separated list of weeks or inclusive week ranges.
/// Each value must be in `1..60` and a range must not be reversed. An empty
/// string, empty segment, or non-numeric text is invalid.
bool isValidWeekPattern(String value) {
  if (value.isEmpty) return false;
  for (final part in value.split(',')) {
    final match = _segment.firstMatch(part);
    if (match == null) return false;
    final start = int.parse(match.group(1)!);
    final end = match.group(2) == null ? start : int.parse(match.group(2)!);
    if (start < 1 || end > 60 || start > end) return false;
  }
  return true;
}

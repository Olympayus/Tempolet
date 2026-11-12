import 'dart:math';

/// A positioned block on a day column, in minutes since midnight.
class TimeRange {
  const TimeRange({required this.id, required this.start, this.end});

  final String id;
  final int start;
  final int? end;

  /// A point range still occupies the timeline, so it reserves one minute.
  int get effectiveEnd => max(end ?? start + 1, start + 1);
}

/// Greedy smallest-available-lane assignment (design spec §3.1 overlap
/// handling). Ranges are considered in start order; a lane is reusable when
/// its last block ends at or before the next block starts.
Map<String, int> assignLanes(List<TimeRange> ranges) {
  final sorted = [...ranges]..sort((a, b) => a.start.compareTo(b.start));
  final laneEnds = <int>[];
  final lanes = <String, int>{};

  for (final range in sorted) {
    var lane = laneEnds.indexWhere((end) => end <= range.start);
    if (lane == -1) {
      lane = laneEnds.length;
      laneEnds.add(range.effectiveEnd);
    } else {
      laneEnds[lane] = range.effectiveEnd;
    }
    lanes[range.id] = lane;
  }
  return lanes;
}

int laneCount(Map<String, int> lanes) =>
    lanes.isEmpty ? 0 : lanes.values.reduce(max) + 1;

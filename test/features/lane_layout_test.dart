import 'package:flutter_test/flutter_test.dart';
import 'package:tempolet/features/calendar/lane_layout.dart';

TimeRange _r(String id, int start, int end) =>
    TimeRange(id: id, start: start, end: end);

void main() {
  test('two identical ranges take two lanes', () {
    final lanes = assignLanes([_r('a', 540, 600), _r('b', 540, 600)]);
    expect(lanes['a'], 0);
    expect(lanes['b'], 1);
    expect(laneCount(lanes), 2);
  });

  test('back-to-back ranges reuse lane 0', () {
    final lanes = assignLanes([_r('a', 540, 600), _r('b', 600, 660)]);
    expect(lanes['a'], 0);
    expect(lanes['b'], 0);
    expect(laneCount(lanes), 1);
  });

  test('staircase reuses the freed lane (minimal available lane)', () {
    // Plan text said "3 lanes", but its own algorithm — smallest available
    // lane — frees lane 1 when "first" ends at 600, so "second" reuses it.
    final lanes = assignLanes([
      _r('long', 540, 720),
      _r('first', 540, 600),
      _r('second', 600, 660),
    ]);
    expect(lanes['long'], 0);
    expect(lanes['first'], 1);
    expect(lanes['second'], 1);
    expect(laneCount(lanes), 2);
  });

  test('null end is treated as a point range', () {
    final lanes = assignLanes([
      TimeRange(id: 'a', start: 540, end: null),
      TimeRange(id: 'b', start: 540, end: null),
    ]);
    expect(laneCount(lanes), 2);
  });

  test('empty input has no lanes', () {
    expect(assignLanes(const []), isEmpty);
    expect(laneCount(const {}), 0);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:tempolet/data/models/week_pattern.dart';

void main() {
  test('accepts comma-separated weeks and ranges', () {
    expect(isValidWeekPattern('1-16,18'), isTrue);
    expect(isValidWeekPattern('5'), isTrue);
    expect(isValidWeekPattern('1-60'), isTrue);
    expect(isValidWeekPattern('60'), isTrue);
  });

  test('rejects out-of-range or reversed weeks', () {
    expect(isValidWeekPattern('0-16'), isFalse);
    expect(isValidWeekPattern('18-16'), isFalse);
    expect(isValidWeekPattern('0'), isFalse);
    expect(isValidWeekPattern('61'), isFalse);
    expect(isValidWeekPattern('1-61'), isFalse);
  });

  test('rejects malformed patterns', () {
    expect(isValidWeekPattern('1-16,'), isFalse);
    expect(isValidWeekPattern('abc'), isFalse);
    expect(isValidWeekPattern(''), isFalse);
    expect(isValidWeekPattern('1,,2'), isFalse);
    expect(isValidWeekPattern('1-2-3'), isFalse);
    expect(isValidWeekPattern(' 5'), isFalse);
  });
}

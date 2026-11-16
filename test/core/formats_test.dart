import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tempolet/core/utils/formats.dart';

void main() {
  const zh = Locale('zh');
  const en = Locale('en');

  test('month and day titles', () {
    expect(AppFormats.monthTitle(zh, DateTime(2026, 11, 13)), '2026年11月');
    expect(AppFormats.monthTitle(en, DateTime(2026, 11, 13)), 'November 2026');
    expect(AppFormats.dayTitle(zh, DateTime(2026, 11, 13)), '2026年11月13日');
    expect(AppFormats.dayTitle(en, DateTime(2026, 11, 13)), 'Nov 13, 2026');
  });

  test('month day and weekday', () {
    expect(AppFormats.monthDay(zh, DateTime(2026, 11, 9)), '11月9日');
    expect(AppFormats.monthDay(en, DateTime(2026, 11, 9)), 'Nov 9');
    expect(AppFormats.weekday(zh, DateTime(2026, 11, 9)), '周一');
    expect(AppFormats.weekday(en, DateTime(2026, 11, 9)), 'Mon');
    expect(AppFormats.weekday(zh, DateTime(2026, 11, 15)), '周日');
  });

  test('week range and time range', () {
    expect(AppFormats.weekRange(zh, DateTime(2026, 11, 9)), '2026年11月9日 – 15日');
    expect(AppFormats.weekRange(en, DateTime(2026, 11, 9)), 'Nov 9 – 15, 2026');
    expect(AppFormats.timeRange(540, 600), '09:00–10:00');
    expect(AppFormats.timeRange(1110, null), '18:30');
  });

  test('week range crosses months and years', () {
    expect(
      AppFormats.weekRange(zh, DateTime(2026, 11, 30)),
      '2026年11月30日 – 12月6日',
    );
    expect(
      AppFormats.weekRange(en, DateTime(2026, 11, 30)),
      'Nov 30 – Dec 6, 2026',
    );
    expect(
      AppFormats.weekRange(zh, DateTime(2025, 12, 29)),
      '2025年12月29日 – 2026年1月4日',
    );
    expect(
      AppFormats.weekRange(en, DateTime(2025, 12, 29)),
      'Dec 29, 2025 – Jan 4, 2026',
    );
  });

  test('time range renders the 24:00 sentinel and missing bounds', () {
    expect(AppFormats.timeRange(1380, 1440), '23:00–24:00');
    expect(AppFormats.timeRange(null, 600), '');
    expect(AppFormats.timeRange(0, null), '00:00');
  });

  test('relative day falls back to the day title', () {
    final today = DateTime(2026, 11, 13);
    expect(AppFormats.relativeDay(zh, DateTime(2026, 11, 13), today), '今天');
    expect(AppFormats.relativeDay(zh, DateTime(2026, 11, 12), today), '昨天');
    expect(AppFormats.relativeDay(zh, DateTime(2026, 11, 14), today), '明天');
    expect(AppFormats.relativeDay(en, DateTime(2026, 11, 13), today), 'Today');
    expect(
      AppFormats.relativeDay(en, DateTime(2026, 11, 12), today),
      'Yesterday',
    );
    expect(AppFormats.relativeDay(en, DateTime(2026, 11, 14), today), 'Tomorrow');
    expect(
      AppFormats.relativeDay(zh, DateTime(2026, 10, 3), today),
      '2026年10月3日',
    );
    expect(AppFormats.relativeDay(en, DateTime(2026, 10, 3), today), 'Oct 3, 2026');
  });
}

import 'dart:ui' show Locale;

import 'package:intl/intl.dart';

import 'dates.dart';

/// Localized date and time titles shared by the calendar, sidebars and the
/// completed list.
///
/// Chinese output is built from literal `年/月/日` templates so it does not
/// depend on Intl's zh date symbols; English uses Intl's `en` patterns.
abstract final class AppFormats {
  static const _zhWeekdays = [
    '周一',
    '周二',
    '周三',
    '周四',
    '周五',
    '周六',
    '周日',
  ];

  static bool _isZh(Locale locale) => locale.languageCode == 'zh';

  static String _en(String pattern, DateTime date) =>
      DateFormat(pattern, 'en_US').format(date);

  /// '2026年11月' / 'November 2026'
  static String monthTitle(Locale locale, DateTime date) => _isZh(locale)
      ? '${date.year}年${date.month}月'
      : _en('MMMM y', date);

  /// '2026年11月13日' / 'Nov 13, 2026'
  static String dayTitle(Locale locale, DateTime date) => _isZh(locale)
      ? '${date.year}年${date.month}月${date.day}日'
      : _en('MMM d, y', date);

  /// '11月13日' / 'Nov 13'
  static String monthDay(Locale locale, DateTime date) => _isZh(locale)
      ? '${date.month}月${date.day}日'
      : _en('MMM d', date);

  /// '周五' / 'Fri'
  static String weekday(Locale locale, DateTime date) =>
      _isZh(locale) ? _zhWeekdays[date.weekday - 1] : _en('EEE', date);

  /// Range title for the week starting on [monday]:
  /// '2026年11月9日 – 15日' / 'Nov 9 – 15, 2026'.
  static String weekRange(Locale locale, DateTime monday) {
    final start = DateTime(monday.year, monday.month, monday.day);
    // Calendar-day arithmetic avoids DST shifts that Duration can introduce.
    final end = DateTime(start.year, start.month, start.day + 6);

    if (_isZh(locale)) {
      final startTitle = '${start.year}年${start.month}月${start.day}日';
      if (end.year == start.year && end.month == start.month) {
        return '$startTitle – ${end.day}日';
      }
      if (end.year == start.year) {
        return '$startTitle – ${end.month}月${end.day}日';
      }
      return '$startTitle – ${end.year}年${end.month}月${end.day}日';
    }

    final startTitle = _en('MMM d', start);
    if (end.year == start.year && end.month == start.month) {
      return '$startTitle – ${end.day}, ${end.year}';
    }
    if (end.year == start.year) {
      return '$startTitle – ${_en('MMM d', end)}, ${end.year}';
    }
    return '${_en('MMM d, y', start)} – ${_en('MMM d, y', end)}';
  }

  /// '09:00–10:00'. A missing end renders the start alone; a missing start
  /// renders an empty string. The 1440 sentinel renders as 24:00.
  static String timeRange(int? start, int? end) {
    if (start == null) return '';
    final from = formatMinuteOfDay(start);
    if (end == null) return from;
    return '$from–${formatMinuteOfDay(end)}';
  }

  /// '今天' / '昨天' / '明天' relative to [today] (and the English equivalents);
  /// any other day falls back to [dayTitle].
  static String relativeDay(Locale locale, DateTime date, DateTime today) {
    final day = DateTime.utc(date.year, date.month, date.day);
    final base = DateTime.utc(today.year, today.month, today.day);
    final diff = day.difference(base).inDays;
    if (_isZh(locale)) {
      return switch (diff) {
        0 => '今天',
        -1 => '昨天',
        1 => '明天',
        _ => dayTitle(locale, date),
      };
    }
    return switch (diff) {
      0 => 'Today',
      -1 => 'Yesterday',
      1 => 'Tomorrow',
      _ => dayTitle(locale, date),
    };
  }
}

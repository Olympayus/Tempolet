import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/utils/dates.dart';
import '../../core/utils/formats.dart';
import '../../data/database/database.dart';
import '../../data/repositories/category_repository.dart';
import '../../data/repositories/event_repository.dart';
import 'calendar_state.dart';
import 'category_marker.dart';
import 'holiday_badge.dart';
import 'month_model.dart';
import 'month_preview_dialog.dart';

/// Current-month grid: only real dates of the selected month, with blank
/// leading/trailing cells and no hovering summary (`docs/design/03-calendar.md`
/// §1). A single click opens [MonthPreviewDialog]; a double click selects the
/// day and opens the sidebar.
class MonthView extends ConsumerWidget {
  const MonthView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final palette =
        (theme.brightness == Brightness.light
                ? AppPalette.light
                : AppPalette.dark)
            .withAccent(theme.colorScheme.primary);
    final locale = Localizations.localeOf(context);
    final selected = ref.watch(selectedDayProvider);
    final weeks = monthWeeks(selected);
    final rangeStart = DateTime(selected.year, selected.month, 1);
    final rangeEnd = DateTime(selected.year, selected.month + 1, 1);
    final events =
        ref
            .watch(eventsInRangeProvider((start: rangeStart, end: rangeEnd)))
            .value ??
        const <Event>[];
    final categories =
        ref.watch(allCategoriesProvider).value ?? const <Category>[];
    final holidays = ref.watch(holidaysProvider).value ?? const <Holiday>[];
    final today = dateOnly(ref.watch(todayProvider));

    final eventsByDay = <DateTime, List<Event>>{};
    for (final event in events) {
      eventsByDay.putIfAbsent(dateOnly(event.date), () => []).add(event);
    }
    final holidayByDay = <DateTime, Holiday>{
      for (final holiday in holidays) dateOnly(holiday.date): holiday,
    };

    void openPreview(DateTime day) {
      showDialog<void>(
        context: context,
        builder: (_) => MonthPreviewDialog(day: day),
      );
    }

    void openSidebar(DateTime day) {
      ref.read(selectedDayProvider.notifier).select(day);
      ref.read(sidebarPreferenceProvider.notifier).set(true);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 12),
      child: Column(
        children: [
          SizedBox(
            height: 24,
            child: Row(
              children: [
                for (var i = 0; i < 7; i++)
                  Expanded(
                    child: Center(
                      child: Text(
                        AppFormats.weekday(locale, DateTime(2024, 1, 1 + i)),
                        style: AppTextStyles.caption.copyWith(
                          color: palette.sub,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: palette.lineStrong),
                  left: BorderSide(color: palette.lineStrong),
                ),
              ),
              child: Column(
                children: [
                  for (final week in weeks)
                    Expanded(
                      child: Row(
                        children: [
                          for (final day in week)
                            Expanded(
                              child: day == null
                                  ? _GridBlank(palette: palette)
                                  : _DayCell(
                                      day: day,
                                      isToday: day == today,
                                      isSelected: day == selected,
                                      events:
                                          eventsByDay[day] ?? const <Event>[],
                                      holiday: holidayByDay[day],
                                      categories: categories,
                                      palette: palette,
                                      onTap: () => openPreview(day),
                                      onDoubleTap: () => openSidebar(day),
                                    ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _dateKey(DateTime day) =>
    '${day.year}-${day.month.toString().padLeft(2, '0')}-'
    '${day.day.toString().padLeft(2, '0')}';

BoxDecoration _cellBorder(AppPalette palette) => BoxDecoration(
  border: Border(
    right: BorderSide(color: palette.lineStrong),
    bottom: BorderSide(color: palette.lineStrong),
  ),
);

/// Empty leading/trailing cell; it still draws its share of the table rules.
class _GridBlank extends StatelessWidget {
  const _GridBlank({required this.palette});

  final AppPalette palette;

  @override
  Widget build(BuildContext context) =>
      Container(decoration: _cellBorder(palette));
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.isToday,
    required this.isSelected,
    required this.events,
    required this.holiday,
    required this.categories,
    required this.palette,
    required this.onTap,
    required this.onDoubleTap,
  });

  final DateTime day;
  final bool isToday;
  final bool isSelected;
  final List<Event> events;
  final Holiday? holiday;
  final List<Category> categories;
  final AppPalette palette;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;

  @override
  Widget build(BuildContext context) {
    final shown = events.take(2).toList();
    final hasOverflow = events.length > shown.length;

    return GestureDetector(
      key: ValueKey('day-${_dateKey(day)}'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onDoubleTap: onDoubleTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(5, 4, 5, 3),
        decoration: _cellBorder(palette),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DayRow(
              day: day,
              isToday: isToday,
              isSelected: isSelected,
              holiday: holiday,
              palette: palette,
            ),
            const SizedBox(height: 2),
            for (final event in shown)
              _EventRow(
                event: event,
                color: categoryMarkerColor(event.categoryId, categories),
                palette: palette,
              ),
            if (hasOverflow)
              Text(
                '…',
                key: ValueKey('month-more-${_dateKey(day)}'),
                style: AppTextStyles.caption.copyWith(
                  color: palette.sub,
                  letterSpacing: 1,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The day-number row: date, then the festival name and 休/班 pill when the
/// date has holiday data. Holiday info stays on this row so both event rows
/// remain available (`docs/design/03-calendar.md` §1.1).
class _DayRow extends StatelessWidget {
  const _DayRow({
    required this.day,
    required this.isToday,
    required this.isSelected,
    required this.holiday,
    required this.palette,
  });

  final DateTime day;
  final bool isToday;
  final bool isSelected;
  final Holiday? holiday;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final holiday = this.holiday;
    return SizedBox(
      height: 18,
      child: Row(
        children: [
          _DayNumber(
            day: day,
            isToday: isToday,
            isSelected: isSelected,
            palette: palette,
          ),
          if (holiday != null) ...[
            const SizedBox(width: 4),
            // A 调休 workday shows the gray pill alone; only days off carry
            // the festival name.
            if (!holiday.isWorkday)
              Flexible(
                child: Text(
                  holiday.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 11,
                    color: palette.festival,
                  ),
                ),
              ),
            const SizedBox(width: 3),
            HolidayBadge(holiday: holiday, palette: palette),
          ],
        ],
      ),
    );
  }
}

class _DayNumber extends StatelessWidget {
  const _DayNumber({
    required this.day,
    required this.isToday,
    required this.isSelected,
    required this.palette,
  });

  final DateTime day;
  final bool isToday;
  final bool isSelected;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final decoration = isToday
        ? BoxDecoration(shape: BoxShape.circle, color: palette.accent)
        : isSelected
        ? BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: palette.accent, width: 1.5),
          )
        : null;

    return Container(
      width: 18,
      height: 18,
      alignment: Alignment.center,
      decoration: decoration,
      child: Text(
        '${day.day}',
        style: AppTextStyles.caption.copyWith(
          color: isToday ? Colors.white : palette.ink,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _EventRow extends StatelessWidget {
  const _EventRow({
    required this.event,
    required this.color,
    required this.palette,
  });

  final Event event;
  final Color color;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final start = event.startMinute;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        children: [
          CategoryMarker(kind: event.kind, color: color),
          const SizedBox(width: 4),
          if (start != null) ...[
            Text(
              formatMinuteOfDay(start),
              style: AppTextStyles.caption.copyWith(
                color: palette.sub,
                fontSize: 10,
              ),
            ),
            const SizedBox(width: 3),
          ],
          Expanded(
            child: Text(
              event.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption.copyWith(color: palette.ink),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/ui/app_popover.dart';
import '../../core/utils/dates.dart';
import '../../core/utils/formats.dart';
import '../../data/database/database.dart';
import '../../data/repositories/category_repository.dart';
import '../../data/repositories/event_repository.dart';
import 'calendar_state.dart';
import 'category_marker.dart';
import 'holiday_badge.dart';
import 'month_model.dart';
import 'month_preview_popover.dart';

/// Current-month grid: only real dates of the selected month, with blank
/// leading/trailing cells and no hovering summary (`docs/design/03-calendar.md`
/// §1). A single click opens the anchored [MonthPreviewPopover]; a double
/// click selects the day and opens the sidebar.
class MonthView extends ConsumerStatefulWidget {
  const MonthView({super.key});

  @override
  ConsumerState<MonthView> createState() => _MonthViewState();
}

class _MonthViewState extends ConsumerState<MonthView> {
  /// Stable per-day keys so the tapped cell can report its rectangle to the
  /// popover without depending on a context outside its own subtree.
  final Map<DateTime, GlobalKey> _cellKeys = <DateTime, GlobalKey>{};

  GlobalKey _cellKey(DateTime day) =>
      _cellKeys.putIfAbsent(day, GlobalKey.new);

  @override
  Widget build(BuildContext context) {
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
      final box = _cellKey(day).currentContext?.findRenderObject();
      if (box is! RenderBox || !box.hasSize) return;
      final anchor = box.localToGlobal(Offset.zero) & box.size;
      showAppPopover<void>(
        context: context,
        anchor: anchor,
        builder: (_) => MonthPreviewPopover(day: day),
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
                                      key: _cellKey(day),
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

BoxDecoration _cellBorder(AppPalette palette, {Color? color}) => BoxDecoration(
  color: color,
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
    super.key,
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
      key: ValueKey('month-day-${_dateKey(day)}'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onDoubleTap: onDoubleTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: _cellBorder(
          palette,
          // Today owns the solid accent circle, so a selected today does not
          // also wash the whole cell (`docs/design/10-ui-refinement.md` §9.15).
          color: isSelected && !isToday ? palette.accentTint : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DayRow(
              day: day,
              isToday: isToday,
              holiday: holiday,
              palette: palette,
            ),
            // The events area clips instead of overflowing when the window is
            // shorter than the 8/10 + 32 row + 2×18 rows budget.
            Expanded(
              child: SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final event in shown)
                      _EventRow(
                        event: event,
                        color: categoryMarkerColor(
                          event.categoryId,
                          categories,
                        ),
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
            ),
          ],
        ),
      ),
    );
  }
}

/// The 32px day-number row: date, then the festival name and 休/班 pill when
/// the date has holiday data. Holiday info stays on this row so both event
/// rows remain available (`docs/design/03-calendar.md` §1.1).
class _DayRow extends StatelessWidget {
  const _DayRow({
    required this.day,
    required this.isToday,
    required this.holiday,
    required this.palette,
  });

  final DateTime day;
  final bool isToday;
  final Holiday? holiday;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final holiday = this.holiday;
    return SizedBox(
      height: 32,
      child: Row(
        children: [
          _DayNumber(
            day: day,
            isToday: isToday,
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
                    fontSize: 10,
                    color: palette.festival,
                  ),
                ),
              ),
            const SizedBox(width: 3),
            HolidayBadge(holiday: holiday, palette: palette, fontSize: 9),
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
    required this.palette,
  });

  final DateTime day;
  final bool isToday;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey('month-day-number-${_dateKey(day)}'),
      width: 20,
      height: 20,
      alignment: Alignment.center,
      decoration: isToday
          ? BoxDecoration(shape: BoxShape.circle, color: palette.accent)
          : null,
      child: Text(
        '${day.day}',
        style: AppTextStyles.body.copyWith(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          fontVariations: const [FontVariation('wght', 600)],
          color: isToday ? Colors.white : palette.ink,
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

    return SizedBox(
      height: 18,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Very narrow cells (a 500px window leaves ~46px of content) cannot
          // hold marker + time + title; drop the time before it overflows.
          final showTime = start != null && constraints.maxWidth >= 60;
          return Row(
            children: [
              CategoryMarker(kind: event.kind, color: color),
              const SizedBox(width: 4),
              if (showTime) ...[
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
          );
        },
      ),
    );
  }
}

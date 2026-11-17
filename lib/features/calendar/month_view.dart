import 'dart:async';
import 'dart:math' as math;

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

/// How long the pointer must rest on a month cell before its preview opens.
const Duration kMonthPreviewHoverDelay = Duration(milliseconds: 350);

/// Grace period for moving the pointer from a cell into its preview; leaving
/// both for this long dismisses the preview.
const Duration kMonthPreviewCloseGrace = Duration(milliseconds: 200);

/// Current-month grid: only real dates of the selected month, with blank
/// leading/trailing cells and no hovering summary (`docs/design/03-calendar.md`
/// §1). A single click selects the day; resting the pointer on a cell for
/// [kMonthPreviewHoverDelay] opens the anchored [MonthPreviewPopover].
class MonthView extends ConsumerStatefulWidget {
  const MonthView({super.key});

  @override
  ConsumerState<MonthView> createState() => _MonthViewState();
}

class _MonthViewState extends ConsumerState<MonthView> {
  /// Stable per-day keys so the hovered cell can report its rectangle to the
  /// popover without depending on a context outside its own subtree.
  final Map<DateTime, GlobalKey> _cellKeys = <DateTime, GlobalKey>{};

  DateTime? _openPreviewDay;
  Timer? _openTimer;
  Timer? _closeTimer;
  VoidCallback? _closePreview;
  DateTime? _suppressedDay;
  DateTime? _hoveredDay;

  GlobalKey _cellKey(DateTime day) =>
      _cellKeys.putIfAbsent(day, GlobalKey.new);

  @override
  void dispose() {
    _openTimer?.cancel();
    _closeTimer?.cancel();
    // Dismissing through the captured scope keeps the overlay from surviving
    // a view switch after this state is gone.
    _closePreview?.call();
    super.dispose();
  }

  void _handleCellTap(DateTime day) {
    ref.read(selectedDayProvider.notifier).select(day);
  }

  void _enterCell(DateTime day) {
    _openTimer?.cancel();
    _cancelClose();
    if (_openPreviewDay == day) return;
    // A preview cannot follow the pointer across cells.
    _closeOpenPreview();
    setState(() => _hoveredDay = day);
    _openTimer = Timer(kMonthPreviewHoverDelay, () => _openPreview(day));
  }

  void _exitCell(DateTime day) {
    _openTimer?.cancel();
    _openTimer = null;
    if (_hoveredDay == day) setState(() => _hoveredDay = null);
    if (_suppressedDay == day) _suppressedDay = null;
    if (_openPreviewDay == day) _scheduleClose();
  }

  void _cancelClose() {
    _closeTimer?.cancel();
    _closeTimer = null;
  }

  void _scheduleClose() {
    _closeTimer?.cancel();
    _closeTimer = Timer(kMonthPreviewCloseGrace, () {
      _closeTimer = null;
      _closeOpenPreview();
    });
  }

  void _closeOpenPreview() {
    if (_openPreviewDay == null) return;
    _openPreviewDay = null;
    final close = _closePreview;
    _closePreview = null;
    close?.call();
  }

  void _openPreview(DateTime day) {
    _openTimer = null;
    if (!mounted || _suppressedDay == day || _openPreviewDay == day) return;
    _closeOpenPreview();
    final box = _cellKey(day).currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return;
    final anchor = box.localToGlobal(Offset.zero) & box.size;
    _openPreviewDay = day;
    final future = showAppPopover<void>(
      context: context,
      anchor: anchor,
      builder: (popoverContext) {
        // Capture the scope's close callback up front: it stays callable from
        // `dispose` even after the popover's own context is deactivated.
        final scope = AppPopoverScope.maybeOf(popoverContext);
        if (scope != null) _closePreview = () => scope.close(null);
        return MouseRegion(
          onEnter: (_) => _cancelClose(),
          onExit: (_) => _scheduleClose(),
          child: MonthPreviewPopover(day: day),
        );
      },
    );
    future.whenComplete(() {
      if (!mounted || _openPreviewDay != day) return;
      // Dismissed by an outside tap, Escape or ×. Keep the cell hovered but
      // suppressed until the pointer leaves and enters again.
      _openPreviewDay = null;
      _closePreview = null;
      _suppressedDay = day;
    });
  }

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

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 12),
      child: Column(
        children: [
          ColoredBox(
            key: const ValueKey('month-weekday-band'),
            color: palette.side,
            child: SizedBox(
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
                                  : MouseRegion(
                                      onEnter: (_) => _enterCell(day),
                                      onExit: (_) => _exitCell(day),
                                      child: _DayCell(
                                        key: _cellKey(day),
                                        day: day,
                                        isToday: day == today,
                                        isSelected: day == selected,
                                        isHovered: day == _hoveredDay,
                                        events:
                                            eventsByDay[day] ?? const <Event>[],
                                        holiday: holidayByDay[day],
                                        categories: categories,
                                        palette: palette,
                                        onTap: () => _handleCellTap(day),
                                      ),
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

/// Fixed cell furniture; the events area has to share what is left
/// (`docs/design/03-calendar.md` §1.1).
const double _cellDayRowHeight = 32;
const double _cellEventRowHeight = 18;

/// Two full event rows are the design maximum; the overflow row is a compact
/// 11px caption so it always has room of its own.
const int _cellMaxEventRows = 2;
const double _cellOverflowRowHeight = 11;

/// How much of the events list a cell can actually show at its current
/// height. At the 960×600 minimum a 6-week month leaves only 29px below the
/// 32px day row (600 − 32 title bar − 64 page header − 14 view padding − 28
/// weekday row = 462; /6 rows = 77; − 16 cell padding − 32 day row = 29), so
/// one 18px event row plus an 11px ellipsis is the full budget. When even
/// that does not fit, only the ellipsis renders.
class _CellEventPlan {
  const _CellEventPlan({
    required this.visibleRows,
    this.showOverflow = false,
  });

  final int visibleRows;
  final bool showOverflow;
}

_CellEventPlan _planCellEvents(int total, double available) {
  if (total == 0 || available <= 0) return const _CellEventPlan(visibleRows: 0);

  final allRowsFit =
      total <= _cellMaxEventRows && total * _cellEventRowHeight <= available;
  if (allRowsFit) return _CellEventPlan(visibleRows: total);

  if (available < _cellOverflowRowHeight) {
    return const _CellEventPlan(visibleRows: 0);
  }
  // Reserve the ellipsis first, then fit whole rows into what remains.
  final fitting = math.max(
    0,
    (available - _cellOverflowRowHeight) ~/ _cellEventRowHeight,
  );
  return _CellEventPlan(
    visibleRows: math.min(math.min(_cellMaxEventRows, total), fitting),
    showOverflow: true,
  );
}

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
    required this.isHovered,
    required this.events,
    required this.holiday,
    required this.categories,
    required this.palette,
    required this.onTap,
  });

  final DateTime day;
  final bool isToday;
  final bool isSelected;
  final bool isHovered;
  final List<Event> events;
  final Holiday? holiday;
  final List<Category> categories;
  final AppPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Today owns the solid accent circle, so a selected today does not also
    // wash the whole cell (`docs/design/10-ui-refinement.md` §9.15). Hover is
    // a flat tint only; selection keeps the accent wash and wins over it.
    Color? cellColor;
    if (isSelected && !isToday) {
      cellColor = palette.accentTint;
    } else if (isHovered && !isSelected) {
      cellColor = palette.hover;
    }

    return GestureDetector(
      key: ValueKey('month-day-${_dateKey(day)}'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: _cellBorder(palette, color: cellColor),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: _cellDayRowHeight,
              child: _DayRow(
                day: day,
                isToday: isToday,
                holiday: holiday,
                palette: palette,
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final plan = _planCellEvents(
                    events.length,
                    constraints.maxHeight,
                  );
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final event in events.take(plan.visibleRows))
                        _EventRow(
                          event: event,
                          color: categoryMarkerColor(
                            event.categoryId,
                            categories,
                          ),
                          palette: palette,
                        ),
                      if (plan.showOverflow)
                        SizedBox(
                          height: _cellOverflowRowHeight,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '…',
                              key: ValueKey('month-more-${_dateKey(day)}'),
                              style: AppTextStyles.caption.copyWith(
                                color: palette.sub,
                                height: 1,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
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

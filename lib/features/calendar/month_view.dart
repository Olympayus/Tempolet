import 'dart:async';

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

  /// Whether the open panel has rendered its first frame. Until then there is
  /// no corridor between the cell and the panel to preserve, so a pointer
  /// that already reached another cell leaves the entry orphaned.
  bool _previewBuilt = false;
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
    if (_hoveredDay != day) setState(() => _hoveredDay = day);
    if (_openPreviewDay == day) return;
    if (_openPreviewDay != null) {
      // The 8px gap between a cell and its panel lies over the neighbouring
      // cell, so a pointer travelling into the panel always enters another
      // cell first. Honour the grace period and let the panel's own
      // MouseRegion cancel the dismissal. A panel that never rendered has no
      // corridor to protect, so a pointer already on another cell makes that
      // entry an orphan and it is dismissed outright.
      if (_previewBuilt) {
        _scheduleClose();
      } else {
        _closeOpenPreview();
      }
    }
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
    _previewBuilt = false;
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
    _previewBuilt = false;
    final future = showAppPopover<void>(
      context: context,
      anchor: anchor,
      builder: (popoverContext) {
        final scope = AppPopoverScope.maybeOf(popoverContext);
        // The entry is inserted a frame before this builder runs. If this
        // state is gone or has moved on to another day by then, dismiss the
        // orphaned entry instead of mounting a panel whose callbacks would
        // outlive the state.
        if (!mounted || _openPreviewDay != day) {
          scope?.close(null);
          return const SizedBox.shrink();
        }
        _previewBuilt = true;
        // Capture the scope's close callback up front: it stays callable from
        // `dispose` even after the popover's own context is deactivated.
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
      // Dismissed by an outside tap, Escape or ×. Suppress only while the
      // pointer still rests on the cell, so leaving and coming back can open
      // it again. If the pointer already left, `_exitCell` cleared the
      // suppression and re-arming it here would swallow the next hover.
      _openPreviewDay = null;
      _previewBuilt = false;
      _closePreview = null;
      if (_hoveredDay == day) _suppressedDay = day;
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
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: palette.lineStrong)),
        ),
        child: Column(
          children: [
            // The weekday row is the month table's own header: it keeps the
            // structural `side` surface (same language as the week header and
            // the sidebar), docks flush onto the grid, and shares its column
            // rules, so the distinction reads as "header of this table"
            // instead of a floating band.
            Container(
              key: const ValueKey('month-weekday-band'),
              height: 28,
              decoration: BoxDecoration(
                color: palette.side,
                border: Border(bottom: BorderSide(color: palette.lineStrong)),
              ),
              child: Row(
                children: [
                  for (var i = 0; i < 7; i++)
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border(
                            right: BorderSide(color: palette.lineStrong),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            AppFormats.weekday(
                              locale,
                              DateTime(2024, 1, 1 + i),
                            ),
                            style: AppTextStyles.caption.copyWith(
                              color: palette.sub,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
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
          ],
        ),
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
              height: 20,
              child: Row(
                children: [
                  _DayNumber(
                    day: day,
                    isToday: isToday,
                    palette: palette,
                  ),
                  if (holiday != null) ...[
                    const SizedBox(width: 4),
                    HolidayBadge(
                      holiday: holiday!,
                      palette: palette,
                      fontSize: 9,
                    ),
                  ],
                ],
              ),
            ),
            // Holiday name sits directly under the date and always renders,
            // no matter how many events the day carries.
            if (holiday != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  holiday!.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 10,
                    color: palette.festival,
                  ),
                ),
              ),
            Expanded(
              child: Align(
                alignment: Alignment.bottomLeft,
                child: MonthMarkerRow(
                  events: events,
                  categories: categories,
                  palette: palette,
                  ellipsisKey: ValueKey('month-more-${_dateKey(day)}'),
                ),
              ),
            ),
          ],
        ),
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

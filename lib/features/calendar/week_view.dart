import 'package:drift/drift.dart' show Value;
import 'package:flutter/gestures.dart' show DragStartBehavior;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/utils/dates.dart';
import '../../core/utils/formats.dart';
import '../../data/database/database.dart';
import '../../data/models/event_status.dart';
import '../../data/repositories/event_repository.dart';
import '../events/event_draft.dart';
import '../events/event_editor_sheet.dart';
import 'calendar_state.dart';
import 'holiday_badge.dart';
import 'lane_layout.dart';
import 'now_line.dart';
import 'plan_block.dart';
import 'reminder_card.dart';
import 'time_grid.dart';

/// Seven-column week timeline (`docs/design/03-calendar.md` §2): a fixed
/// two-line day bar, a left-fixed 34px axis and an hourly rule layer spanning
/// all seven columns, with shared plan blocks and floating reminder cards.
///
/// The displayed week follows the globally selected day, so the page header's
/// ‹ › / Today controls move the body too.
class WeekView extends ConsumerStatefulWidget {
  const WeekView({super.key});

  @override
  ConsumerState<WeekView> createState() => _WeekViewState();
}

class _WeekViewState extends ConsumerState<WeekView> {
  final _scroll = ScrollController(initialScrollOffset: kDefaultScrollOffset);

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _selectDay(DateTime day) {
    ref.read(selectedDayProvider.notifier).select(day);
  }

  void _openDay(DateTime day) {
    _selectDay(day);
    ref.read(calendarViewModeProvider.notifier).set(CalendarViewMode.day);
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
    final monday = startOfWeek(ref.watch(selectedDayProvider));
    final days = List.generate(
      7,
      (i) => DateTime(monday.year, monday.month, monday.day + i),
    );
    // Calendar-day arithmetic keeps the exclusive end DST-safe.
    final end = DateTime(monday.year, monday.month, monday.day + 7);
    final events =
        ref.watch(eventsInRangeProvider((start: monday, end: end))).value ??
        const <Event>[];
    final today = dateOnly(DateTime.now());
    final todayIndex = days.indexWhere((day) => day == today);
    final holidays = ref.watch(holidaysProvider).value ?? const <Holiday>[];
    final holidayByDay = <DateTime, Holiday>{
      for (final holiday in holidays) dateOnly(holiday.date): holiday,
    };

    final byDay = <DateTime, List<Event>>{};
    for (final event in events) {
      // Completed items leave the timeline silently (they stay in the
      // completed page), matching the day view.
      if (event.isCompleted) continue;
      byDay.putIfAbsent(dateOnly(event.date), () => []).add(event);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final columnWidth = (constraints.maxWidth - kAxisGutter) / 7;

        return Column(
          children: [
            Row(
              children: [
                const SizedBox(width: kAxisGutter),
                for (final day in days)
                  SizedBox(
                    width: columnWidth,
                    child: _DayHeaderCell(
                      day: day,
                      today: today,
                      holiday: holidayByDay[day],
                      locale: locale,
                      palette: palette,
                      onSelect: () => _selectDay(day),
                      onOpenDay: () => _openDay(day),
                    ),
                  ),
              ],
            ),
            Divider(height: 1, thickness: 1, color: palette.line),
            Expanded(
              child: SingleChildScrollView(
                key: const ValueKey('week-scroll'),
                controller: _scroll,
                child: SizedBox(
                  height: kHoursInDay * kHourHeight,
                  child: Stack(
                    children: [
                      if (todayIndex != -1)
                        Positioned(
                          key: const ValueKey('week-today-column'),
                          left: kAxisGutter + todayIndex * columnWidth,
                          width: columnWidth,
                          top: 0,
                          bottom: 0,
                          child: ColoredBox(color: palette.todayColumn),
                        ),
                      for (var i = 1; i < 7; i++)
                        Positioned(
                          left: kAxisGutter + i * columnWidth - 0.5,
                          width: 1,
                          top: 0,
                          bottom: 0,
                          child: ColoredBox(color: palette.line),
                        ),
                      Positioned(
                        right: 0,
                        width: 1,
                        top: 0,
                        bottom: 0,
                        child: ColoredBox(color: palette.line),
                      ),
                      // Hour rules and axis ticks span all seven columns as
                      // their own layer, above the today tint.
                      const Positioned.fill(
                        child: HourGrid(gutterWidth: kAxisGutter),
                      ),
                      for (var i = 0; i < 7; i++)
                        Positioned(
                          left: kAxisGutter + i * columnWidth,
                          width: columnWidth,
                          top: 0,
                          bottom: 0,
                          child: _WeekDayColumn(
                            day: days[i],
                            events: byDay[days[i]] ?? const [],
                            today: today,
                            columnWidth: columnWidth,
                            palette: palette,
                          ),
                        ),
                      // Owns its own clock and position; always visible.
                      const NowLine(key: ValueKey('week-now-line')),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Two-line day header: weekday at 11px and the date at 12px via
/// [AppFormats]. Today's date sits on a solid accent pill; dates with holiday
/// data append the 休/班 pill, never the festival name.
class _DayHeaderCell extends StatelessWidget {
  const _DayHeaderCell({
    required this.day,
    required this.today,
    required this.holiday,
    required this.locale,
    required this.palette,
    required this.onSelect,
    required this.onOpenDay,
  });

  final DateTime day;
  final DateTime today;
  final Holiday? holiday;
  final Locale locale;
  final AppPalette palette;
  final VoidCallback onSelect;
  final VoidCallback onOpenDay;

  @override
  Widget build(BuildContext context) {
    final isToday = day == today;
    final holiday = this.holiday;
    return GestureDetector(
      key: ValueKey('week-day-${_isoDay(day)}'),
      behavior: HitTestBehavior.opaque,
      onTap: onSelect,
      onDoubleTap: onOpenDay,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              AppFormats.weekday(locale, day),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption.copyWith(
                fontSize: 11,
                color: palette.sub,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 1,
                    ),
                    decoration: isToday
                        ? BoxDecoration(
                            color: palette.accent,
                            borderRadius: BorderRadius.circular(AppRadii.pill),
                          )
                        : null,
                    child: Text(
                      AppFormats.monthDay(locale, day),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.secondary.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        fontVariations: const [FontVariation('wght', 600)],
                        color: isToday ? Colors.white : palette.ink,
                      ),
                    ),
                  ),
                ),
                if (holiday != null) ...[
                  const SizedBox(width: 4),
                  HolidayBadge(holiday: holiday, palette: palette),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

enum _PlanDragMode { move, resizeStart, resizeEnd }

/// One day column inside the week grid: blank-slot tap/drag creation, lane
/// split plans with drag-to-move and 8px edge resize, and floating reminders
/// painted above the plan blocks.
class _WeekDayColumn extends ConsumerStatefulWidget {
  const _WeekDayColumn({
    required this.day,
    required this.events,
    required this.today,
    required this.columnWidth,
    required this.palette,
  });

  final DateTime day;
  final List<Event> events;
  final DateTime today;
  final double columnWidth;
  final AppPalette palette;

  @override
  ConsumerState<_WeekDayColumn> createState() => _WeekDayColumnState();
}

class _WeekDayColumnState extends ConsumerState<_WeekDayColumn> {
  static const double _edgeZone = 8;
  static const double _minimumDragMinutes = 5;

  int? _dragStartMinute;
  int? _dragCurrentMinute;

  String? _dragEventId;
  _PlanDragMode _dragMode = _PlanDragMode.move;
  int? _originStart;
  int? _originEnd;
  int? _previewStart;
  int? _previewEnd;
  double _dragAccumulated = 0;

  int _minuteAt(double localY) => yToMinute(localY).clamp(0, 1440);

  Future<void> _openCreate({
    required EventKind kind,
    int? start,
    int? end,
  }) async {
    await showEventEditor(
      context,
      date: widget.day,
      initialKind: kind,
      startMinute: start,
      endMinute: end,
    );
  }

  @override
  Widget build(BuildContext context) {
    final plans = <Event>[];
    final reminders = <Event>[];
    for (final event in widget.events) {
      if (event.startMinute == null) continue;
      if (event.kind == EventKind.plan.dbValue) {
        plans.add(event);
      } else {
        reminders.add(event);
      }
    }

    final lanes = assignLanes([
      for (final plan in plans)
        TimeRange(id: plan.id, start: plan.startMinute!, end: plan.endMinute),
    ]);
    final laneTotal = laneCount(lanes);
    final unit = widget.columnWidth / (laneTotal == 0 ? 1 : laneTotal);

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            key: ValueKey('week-column-${_isoDay(widget.day)}'),
            behavior: HitTestBehavior.opaque,
            // Begin the range at the press point, not after the drag slop,
            // so a 34px drag from 09:00 really means 09:00–10:00.
            dragStartBehavior: DragStartBehavior.down,
            onTapUp: (details) {
              _openCreate(
                kind: EventKind.reminder,
                start: _minuteAt(details.localPosition.dy),
              );
            },
            onVerticalDragStart: (details) {
              final minute = _minuteAt(details.localPosition.dy);
              setState(() {
                _dragStartMinute = minute;
                _dragCurrentMinute = minute;
              });
            },
            onVerticalDragUpdate: (details) {
              setState(() {
                _dragCurrentMinute = _minuteAt(details.localPosition.dy);
              });
            },
            onVerticalDragEnd: (_) {
              final start = _dragStartMinute;
              final current = _dragCurrentMinute;
              setState(() {
                _dragStartMinute = null;
                _dragCurrentMinute = null;
              });
              if (start == null || current == null) return;
              final selection = selectionFromDrag(start, current);
              if (selection.end - selection.start < _minimumDragMinutes) {
                // A tiny drag is a tap in disguise.
                _openCreate(kind: EventKind.reminder, start: selection.start);
                return;
              }
              _openCreate(
                kind: EventKind.plan,
                start: selection.start,
                end: selection.end,
              );
            },
          ),
        ),
        for (final plan in plans) _planLayer(plan, lanes[plan.id] ?? 0, unit),
        // Reminders always float above plan blocks.
        for (final reminder in reminders) _reminderLayer(reminder),
        if (_dragStartMinute != null && _dragCurrentMinute != null)
          _createPreview(),
      ],
    );
  }

  Widget _planLayer(Event event, int lane, double unit) {
    final start = event.startMinute!;
    final end = event.endMinute ?? start + 30;
    final dragging = _dragEventId == event.id;
    final shownStart = dragging ? (_previewStart ?? start) : start;
    final shownEnd = dragging ? (_previewEnd ?? end) : end;
    final top = minuteToY(shownStart);
    final height = (minuteToY(shownEnd) - top).clamp(
      16.0,
      kHoursInDay * kHourHeight,
    );
    final left = lane * unit + 1;
    final width = (unit - 2).clamp(1.0, widget.columnWidth);

    return Positioned(
      left: left,
      width: width,
      top: top,
      height: height,
      child: GestureDetector(
        key: ValueKey('week-plan-${event.id}'),
        behavior: HitTestBehavior.opaque,
        // Start at the touch point, not after the drag slop: the 8px edge
        // zones must match the pixels under the finger and the slop distance
        // belongs to the move.
        dragStartBehavior: DragStartBehavior.down,
        onTap: () => showEventEditor(context, existing: event),
        // Vertical drag rather than pan: inside the scrolling grid the
        // scrollable's vertical recognizer wins any pan arena, so a child
        // vertical recognizer is what keeps block moves on the block.
        onVerticalDragStart: (details) =>
            _startPlanDrag(event, start, end, details.localPosition.dy, height),
        onVerticalDragUpdate: _updatePlanDrag,
        onVerticalDragEnd: (_) => _commitPlanDrag(event, start, end),
        child: PlanBlock(
          key: ValueKey('plan-${event.id}'),
          event: event,
          overdue: eventStatus(event, widget.today) == EventStatus.overdue,
          compact: true,
        ),
      ),
    );
  }

  Widget _reminderLayer(Event event) {
    return Positioned(
      left: 1,
      right: 1,
      top: minuteToY(event.startMinute!) - 6,
      child: ReminderCard(
        key: ValueKey('reminder-${event.id}'),
        event: event,
        overdue: eventStatus(event, widget.today) == EventStatus.overdue,
        showCheckbox: false,
        onTap: () => showEventEditor(context, existing: event),
      ),
    );
  }

  Widget _createPreview() {
    final selection = selectionFromDrag(_dragStartMinute!, _dragCurrentMinute!);
    final top = minuteToY(selection.start);
    return Positioned(
      left: 1,
      right: 1,
      top: top,
      height: (minuteToY(selection.end) - top).clamp(
        2.0,
        kHoursInDay * kHourHeight,
      ),
      child: IgnorePointer(
        child: Container(
          key: const ValueKey('week-create-preview'),
          decoration: BoxDecoration(
            color: widget.palette.accent.withValues(alpha: .08),
            borderRadius: BorderRadius.circular(AppRadii.block),
          ),
          child: CustomPaint(
            painter: _DashedBorderPainter(color: widget.palette.accent),
          ),
        ),
      ),
    );
  }

  void _startPlanDrag(
    Event event,
    int start,
    int end,
    double localY,
    double height,
  ) {
    final mode = localY <= _edgeZone
        ? _PlanDragMode.resizeStart
        : localY >= height - _edgeZone
        ? _PlanDragMode.resizeEnd
        : _PlanDragMode.move;
    setState(() {
      _dragEventId = event.id;
      _dragMode = mode;
      _originStart = start;
      _originEnd = end;
      _previewStart = start;
      _previewEnd = end;
      _dragAccumulated = 0;
    });
  }

  void _updatePlanDrag(DragUpdateDetails details) {
    if (_dragEventId == null) return;
    _dragAccumulated += details.delta.dy * 60 / kHourHeight;
    if (_dragAccumulated.abs() < _minimumDragMinutes) return;
    final delta = _dragAccumulated.round();
    final start = _originStart!;
    final end = _originEnd!;
    setState(() {
      switch (_dragMode) {
        case _PlanDragMode.move:
          final duration = end - start;
          final moved = snapMinutes((_previewStart ?? start) + delta)
              .clamp(0, 1440 - duration);
          _previewStart = moved;
          _previewEnd = moved + duration;
        case _PlanDragMode.resizeStart:
          _previewStart = snapMinutes((_previewStart ?? start) + delta)
              .clamp(0, end - 5);
        case _PlanDragMode.resizeEnd:
          _previewEnd = snapMinutes((_previewEnd ?? end) + delta)
              .clamp(start + 5, 1440);
      }
    });
    _dragAccumulated -= delta;
  }

  Future<void> _commitPlanDrag(
    Event event,
    int originalStart,
    int originalEnd,
  ) async {
    final start = _previewStart;
    final end = _previewEnd;
    setState(() {
      _dragEventId = null;
      _originStart = null;
      _originEnd = null;
      _previewStart = null;
      _previewEnd = null;
      _dragAccumulated = 0;
    });
    if (start == null || end == null) return;
    if (start == originalStart && end == originalEnd) return;
    final updated = event.copyWith(
      startMinute: Value(start),
      endMinute: Value(end),
      updatedAt: DateTime.now(),
    );
    await ref.read(eventRepositoryProvider).updateEvent(updated);
  }
}

/// 1px dashed border for the drag-created plan preview.
class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          const Radius.circular(AppRadii.block),
        ),
      );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    const dash = 4.0;
    const gap = 3.0;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = (distance + dash).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance = end + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color;
}

String _isoDay(DateTime day) =>
    '${day.year}-${day.month.toString().padLeft(2, '0')}-'
    '${day.day.toString().padLeft(2, '0')}';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/gestures.dart'
    show DragStartBehavior, kDoubleTapTimeout;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/layout_metrics.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/ui/app_hairline.dart';
import '../../core/ui/dashed_border_painter.dart';
import '../../core/ui/gesture_edges.dart';
import '../../core/ui/touch_target.dart';
import '../../core/utils/dates.dart';
import '../../core/utils/formats.dart';
import '../../data/database/database.dart';
import '../../data/models/event_status.dart';
import '../../data/repositories/category_repository.dart';
import '../../data/repositories/event_repository.dart';
import '../../notifications/notification_scheduler.dart';
import '../events/event_draft.dart';
import '../events/event_editor_sheet.dart';
import 'calendar_state.dart';
import 'category_marker.dart';
import 'day_view.dart';
import 'holiday_badge.dart';
import 'lane_layout.dart';
import 'now_line.dart';
import 'plan_block.dart';
import 'reminder_card.dart';
import 'time_grid.dart';
import 'week_date_strip.dart';

/// Column width below which week reminder cards switch to their compact
/// two-line anatomy (`docs/design/10-ui-refinement.md` §3.1).
const double kWeekTwoLineCardBreakpoint = 150;

/// Seven-column week timeline (`docs/design/03-calendar.md` §2): a fixed
/// two-line day bar, a left-fixed 44px axis and an hourly rule layer spanning
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

  /// Previous header tap, used to recognise a double click without a timer.
  DateTime? _lastHeaderDay;
  DateTime? _lastHeaderTapAt;

  /// Horizontal drag origin for edge-gesture avoidance.
  double _dragStartX = 0;

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

  /// A header click selects immediately; a second click on the same day
  /// within [kDoubleTapTimeout] also opens the day view.
  void _handleHeaderTap(DateTime day) {
    final now = DateTime.now();
    final doubleTap =
        _lastHeaderDay == day &&
        _lastHeaderTapAt != null &&
        now.difference(_lastHeaderTapAt!) < kDoubleTapTimeout;
    _selectDay(day);
    if (doubleTap) {
      _lastHeaderDay = null;
      _lastHeaderTapAt = null;
      _openDay(day);
    } else {
      _lastHeaderDay = day;
      _lastHeaderTapAt = now;
    }
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
    final selectedDay = dateOnly(ref.watch(selectedDayProvider));
    final monday = startOfWeek(selectedDay);
    final days = List.generate(
      7,
      (i) => DateTime(monday.year, monday.month, monday.day + i),
    );
    // Calendar-day arithmetic keeps the exclusive end DST-safe.
    final end = DateTime(monday.year, monday.month, monday.day + 7);
    final events =
        ref.watch(eventsInRangeProvider((start: monday, end: end))).value ??
        const <Event>[];
    final today = dateOnly(ref.watch(todayProvider));
    final selectedIndex = days.indexWhere((day) => day == selectedDay);
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
        // Narrow week (tablet portrait / narrow split): the seven-column grid
        // is unreadable, so fall back to the phone's date strip + day timeline
        // (`v0.1.5 design` §8.4). DayView owns ±1-day paging here.
        if (constraints.maxWidth < 900) {
          return const Column(
            children: [
              WeekDateStrip(),
              Expanded(child: DayView()),
            ],
          );
        }
        final columnWidth = (constraints.maxWidth - kAxisGutter) / 7;
        final narrowColumns = columnWidth < kWeekTwoLineCardBreakpoint;

        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          dragStartBehavior: DragStartBehavior.down,
          onHorizontalDragStart: (details) {
            _dragStartX = details.globalPosition.dx;
          },
          onHorizontalDragEnd: (details) {
            final width = MediaQuery.sizeOf(context).width;
            if (isEdgeSwipe(_dragStartX, width)) return;
            final velocity = details.primaryVelocity ?? 0;
            final dx = details.globalPosition.dx - _dragStartX;
            if (velocity < -150 || dx < -60) {
              ref.read(selectedDayProvider.notifier).shiftDays(7);
            } else if (velocity > 150 || dx > 60) {
              ref.read(selectedDayProvider.notifier).shiftDays(-7);
            }
          },
          child: Column(
            children: [
              Container(
                key: const ValueKey('week-header-band'),
                decoration: BoxDecoration(color: palette.side),
                child: Row(
                  children: [
                    const SizedBox(width: kAxisGutter),
                    for (final day in days)
                      SizedBox(
                        width: columnWidth,
                        child: _DayHeaderCell(
                          day: day,
                          today: today,
                          selected: day == selectedDay,
                          holiday: holidayByDay[day],
                          locale: locale,
                          palette: palette,
                          onTap: () => _handleHeaderTap(day),
                        ),
                      ),
                  ],
                ),
              ),
              AppHairline(color: palette.line),
              Expanded(
                child: SingleChildScrollView(
                  key: const ValueKey('week-scroll'),
                  controller: _scroll,
                  child: SizedBox(
                    height: kHoursInDay * kHourHeight,
                    child: Stack(
                      children: [
                        if (selectedIndex != -1)
                          Positioned(
                            left: kAxisGutter + selectedIndex * columnWidth,
                            width: columnWidth,
                            top: 0,
                            bottom: 0,
                            child: ColoredBox(
                              key: ValueKey(
                                'week-selected-column-${_isoDay(selectedDay)}',
                              ),
                              color: palette.surfaceSelected,
                            ),
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
                        // their own layer, above the selected column wash.
                        Positioned.fill(
                          child: HourGrid(
                            gutterWidth: kAxisGutter,
                            gutterColor: palette.side,
                          ),
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
                              narrow: narrowColumns,
                              palette: palette,
                            ),
                          ),
                        // Owns its own clock and position; always visible.
                        NowLine(
                          key: const ValueKey('week-now-line'),
                          now: ref.watch(pinnedNowProvider),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Two-line 52px day header: weekday at 11px and the date at 12px via
/// [AppFormats]. Today's date sits on a solid accent pill; another selected
/// day gets an `accentTint` pill with ink text and no stroke, so a single
/// click visibly changes state even when the sidebar is closed. When a day is
/// both today and selected, today wins. Dates with holiday data append the
/// 休/班 pill, never the festival name.
class _DayHeaderCell extends StatelessWidget {
  const _DayHeaderCell({
    required this.day,
    required this.today,
    required this.selected,
    required this.holiday,
    required this.locale,
    required this.palette,
    required this.onTap,
  });

  final DateTime day;
  final DateTime today;
  final bool selected;
  final Holiday? holiday;
  final Locale locale;
  final AppPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isToday = day == today;
    final holiday = this.holiday;
    return GestureDetector(
      key: ValueKey('week-day-${_isoDay(day)}'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        height: 52,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
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
                      key: ValueKey('week-day-date-${_isoDay(day)}'),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      decoration: isToday
                          ? BoxDecoration(
                              color: palette.accent,
                              borderRadius: BorderRadius.circular(
                                AppRadii.pill,
                              ),
                            )
                          : selected
                          ? BoxDecoration(
                              color: palette.accentTint,
                              borderRadius: BorderRadius.circular(
                                AppRadii.pill,
                              ),
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
    required this.narrow,
    required this.palette,
  });

  final DateTime day;
  final List<Event> events;
  final DateTime today;
  final double columnWidth;

  /// Narrow columns swap floating reminders to the compact two-line card.
  final bool narrow;
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
            // so a one-hour drag from 09:00 really means 09:00–10:00.
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
            // Touch: a still finger cannot scroll, so a long press claims the
            // gesture before the scrollable does. Moving afterwards selects a
            // range without fighting vertical scrolling.
            onLongPressStart: (details) {
              HapticFeedback.mediumImpact();
              final minute = _minuteAt(details.localPosition.dy);
              setState(() {
                _dragStartMinute = minute;
                _dragCurrentMinute = minute;
              });
            },
            onLongPressMoveUpdate: (details) {
              setState(() {
                _dragCurrentMinute = _minuteAt(details.localPosition.dy);
              });
            },
            onLongPressEnd: (_) {
              final start = _dragStartMinute;
              final current = _dragCurrentMinute;
              setState(() {
                _dragStartMinute = null;
                _dragCurrentMinute = null;
              });
              if (start == null || current == null) return;
              final selection = selectionFromDrag(start, current);
              final end = selection.end - selection.start < 5
                  ? (selection.start + 30).clamp(0, 1440)
                  : selection.end;
              _openCreate(
                kind: EventKind.plan,
                start: selection.start,
                end: end,
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
    final hitHeight = height < kMinHitTarget ? kMinHitTarget : height;

    return Positioned(
      left: left,
      width: width,
      top: top - (hitHeight - height) / 2,
      height: hitHeight,
      child: GestureDetector(
        key: ValueKey('week-plan-${event.id}'),
        behavior: HitTestBehavior.opaque,
        onTap: () => showEventEditor(context, existing: event),
        // Touch: a long press arms the move/resize before the scrollable
        // claims the gesture; the block only moves vertically afterwards.
        onLongPressStart: (details) {
          HapticFeedback.selectionClick();
          _startPlanDrag(
            event,
            start,
            end,
            details.localPosition.dy - (hitHeight - height) / 2,
            height,
          );
        },
        onLongPressMoveUpdate: (details) =>
            _updatePlanDragFromOrigin(details.offsetFromOrigin.dy),
        onLongPressEnd: (_) => _commitPlanDrag(event, start, end),
        child: TouchTarget(
          key: ValueKey('plan-hit-${event.id}'),
          child: SizedBox(
            width: width,
            height: height,
            child: PlanBlock(
              key: ValueKey('plan-${event.id}'),
              event: event,
              overdue: eventStatus(event, widget.today) == EventStatus.overdue,
              compact: true,
            ),
          ),
        ),
      ),
    );
  }

  Widget _reminderLayer(Event event) {
    final overdue = eventStatus(event, widget.today) == EventStatus.overdue;
    void onTap() => showEventEditor(context, existing: event);
    return Positioned(
      left: 1,
      right: 1,
      top: minuteToY(event.startMinute!) - 6,
      child: TouchTarget(
        key: ValueKey('reminder-hit-${event.id}'),
        child: widget.narrow
            ? _TwoLineReminderCard(
                key: ValueKey('reminder-${event.id}'),
                event: event,
                palette: widget.palette,
                onTap: onTap,
              )
            : ReminderCard(
                key: ValueKey('reminder-${event.id}'),
                event: event,
                overdue: overdue,
                showCheckbox: true,
                showNote: false,
                onTap: onTap,
                onComplete: _completion(event),
              ),
      ),
    );
  }

  /// Captures the repository and sync bridge while building, before the
  /// card's 120ms fade, so a mid-fade dismissal can neither lose the write
  /// nor touch `ref` after disposal.
  Future<void> Function() _completion(Event event) {
    final repo = ref.read(eventRepositoryProvider);
    final sync = ref.read(eventNotifierSyncProvider);
    final completed = event.copyWith(isCompleted: true);
    return () async {
      await repo.setCompleted(event.id, true);
      sync.afterCompletion(completed);
    };
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
            painter: DashedBorderPainter(color: widget.palette.accent),
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
    });
  }

  void _updatePlanDragFromOrigin(double dyFromOrigin) {
    if (_dragEventId == null) return;
    final delta = (dyFromOrigin * 60 / kHourHeight).round();
    final start = _originStart!;
    final end = _originEnd!;
    setState(() {
      switch (_dragMode) {
        case _PlanDragMode.move:
          final duration = end - start;
          final moved = snapMinutes(start + delta).clamp(0, 1440 - duration);
          _previewStart = moved;
          _previewEnd = moved + duration;
        case _PlanDragMode.resizeStart:
          _previewStart = snapMinutes(start + delta).clamp(0, end - 5);
        case _PlanDragMode.resizeEnd:
          _previewEnd = snapMinutes(end + delta).clamp(start + 5, 1440);
      }
    });
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
    });
    if (start == null || end == null) return;
    if (start == originalStart && end == originalEnd) return;
    final updated = event.copyWith(
      startMinute: Value(start),
      endMinute: Value(end),
      updatedAt: DateTime.now(),
    );
    await ref.read(eventRepositoryProvider).updateEvent(updated);
    ref.read(eventNotifierSyncProvider).afterUpdate(updated);
  }
}

/// Compact two-line reminder for week columns narrower than
/// [kWeekTwoLineCardBreakpoint]: an 11/700 single-line title over a 10px
/// time and category marker. The completion circle is dropped — a narrow
/// column cannot fit it, and week cards float above the grid rather than
/// owning a check target of their own.
class _TwoLineReminderCard extends ConsumerWidget {
  const _TwoLineReminderCard({
    super.key,
    required this.event,
    required this.palette,
    this.onTap,
  });

  final Event event;
  final AppPalette palette;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories =
        ref.watch(allCategoriesProvider).value ?? const <Category>[];
    final startMinute = event.startMinute;
    final time = startMinute == null ? '' : formatMinuteOfDay(startMinute);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        key: const ValueKey('week-card-two-line'),
        constraints: const BoxConstraints(minHeight: 30),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: palette.card,
          borderRadius: BorderRadius.circular(AppRadii.segment),
          border: Border.all(color: palette.line),
          boxShadow: kCardShadow,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              event.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption.copyWith(
                fontWeight: FontWeight.w700,
                fontVariations: const [FontVariation('wght', 700)],
                color: palette.ink,
              ),
            ),
            const SizedBox(height: 1),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    time,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 10,
                      color: palette.sub,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                CategoryMarker(
                  kind: event.kind,
                  color: categoryMarkerColor(event.categoryId, categories),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 1px dashed border for the drag-created plan preview.
// Moved to core/ui/dashed_border_painter.dart.

String _isoDay(DateTime day) =>
    '${day.year}-${day.month.toString().padLeft(2, '0')}-'
    '${day.day.toString().padLeft(2, '0')}';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/gestures.dart' show DragStartBehavior;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/generated/app_localizations.dart';
import '../../core/theme/app_tokens.dart';
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
import 'lane_layout.dart';
import 'now_line.dart';
import 'plan_block.dart';
import 'reminder_card.dart';
import 'time_grid.dart';

/// Single-column day timeline (`docs/design/03-calendar.md` §3): a 34px/hour
/// grid from 07:00, shared plan blocks and reminder cards, the now line for
/// today, and a 216px day overview rail on wide windows.
class DayView extends ConsumerStatefulWidget {
  const DayView({super.key});

  @override
  ConsumerState<DayView> createState() => _DayViewState();
}

class _DayViewState extends ConsumerState<DayView> {
  final _scroll = ScrollController(initialScrollOffset: kDefaultScrollOffset);

  int? _dragStartMinute;
  int? _dragCurrentMinute;

  String? _draggingId;
  int? _dragCurrentStart;
  double _dragAccumulated = 0;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  int _minuteAt(double localY) => yToMinute(localY).clamp(0, 1440);

  Future<void> _openCreate({
    EventKind kind = EventKind.reminder,
    int? start,
    int? end,
  }) async {
    await showEventEditor(
      context,
      date: ref.read(selectedDayProvider),
      initialKind: kind,
      startMinute: start,
      endMinute: end,
    );
  }

  @override
  Widget build(BuildContext context) {
    final day = ref.watch(selectedDayProvider);
    final events =
        ref.watch(eventsForDayProvider(day)).value ?? const <Event>[];
    // Calendar-day arithmetic keeps tomorrow DST-safe.
    final tomorrow = DateTime(day.year, day.month, day.day + 1);
    final tomorrowEvents =
        ref.watch(eventsForDayProvider(tomorrow)).value ?? const <Event>[];
    final today = dateOnly(ref.watch(todayProvider));
    final isToday = day == today;
    // Completed items leave the timeline silently; they stay in the day's
    // stats and move to the completed page.
    final pending = events.where((event) => !event.isCompleted).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final showRail = constraints.maxWidth >= 1100;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _timeline(pending, today: today, isToday: isToday),
            ),
            if (showRail)
              _DayOverview(events: events, tomorrowEvents: tomorrowEvents),
          ],
        );
      },
    );
  }

  Widget _timeline(
    List<Event> events, {
    required DateTime today,
    required bool isToday,
  }) {
    final theme = Theme.of(context);
    final palette =
        (theme.brightness == Brightness.light
                ? AppPalette.light
                : AppPalette.dark)
            .withAccent(theme.colorScheme.primary);
    final plans = [
      for (final event in events)
        if (event.kind == EventKind.plan.dbValue) event,
    ];
    final lanes = assignLanes([
      for (final plan in plans)
        TimeRange(
          id: plan.id,
          start: plan.startMinute ?? 0,
          end: plan.endMinute,
        ),
    ]);

    return SingleChildScrollView(
      key: const ValueKey('day-scroll'),
      controller: _scroll,
      child: SizedBox(
        height: kHoursInDay * kHourHeight,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final laneTotal = laneCount(lanes);
            final trackWidth = constraints.maxWidth - kAxisGutter - 10;
            final laneUnit = laneTotal == 0
                ? trackWidth
                : trackWidth / laneTotal;
            return Stack(
              children: [
                Positioned.fill(child: HourGrid(gutterColor: palette.side)),
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    // Begin the range at the press point, not after the drag
                    // slop, so a 34px drag from 09:00 really means 09:00–10:00.
                    dragStartBehavior: DragStartBehavior.down,
                    onTapUp: (details) {
                      final minute = _minuteAt(details.localPosition.dy);
                      _openCreate(kind: EventKind.reminder, start: minute);
                    },
                    onVerticalDragStart: (details) {
                      setState(() {
                        _dragStartMinute = _minuteAt(details.localPosition.dy);
                        _dragCurrentMinute = _dragStartMinute;
                      });
                    },
                    onVerticalDragUpdate: (details) {
                      setState(() {
                        _dragCurrentMinute = _minuteAt(
                          details.localPosition.dy,
                        );
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
                      if (selection.end - selection.start < 5) {
                        // A tiny drag is a tap in disguise.
                        _openCreate(
                          kind: EventKind.reminder,
                          start: selection.start,
                        );
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
                if (_dragStartMinute != null && _dragCurrentMinute != null)
                  _dragPreview(palette),
                for (final event in events)
                  ..._eventLayers(
                    event,
                    today,
                    lane: lanes[event.id] ?? 0,
                    unit: laneUnit,
                  ),
                if (isToday)
                  NowLine(
                    key: const ValueKey('day-now-line'),
                    now: ref.watch(pinnedNowProvider),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _dragPreview(AppPalette palette) {
    final selection = selectionFromDrag(_dragStartMinute!, _dragCurrentMinute!);
    return Positioned(
      left: kAxisGutter,
      right: 10,
      top: minuteToY(selection.start),
      height: minuteToY(selection.end) - minuteToY(selection.start),
      child: IgnorePointer(
        child: Container(
          decoration: BoxDecoration(
            color: palette.accentTint,
            borderRadius: BorderRadius.circular(AppRadii.block),
            border: Border.all(color: palette.accent.withValues(alpha: .5)),
          ),
        ),
      ),
    );
  }

  List<Widget> _eventLayers(
    Event event,
    DateTime today, {
    required int lane,
    required double unit,
  }) {
    if (event.kind == EventKind.plan.dbValue) {
      final start = event.startMinute ?? 0;
      final end = event.endMinute ?? start + 30;
      final top = minuteToY(start);
      final height = (minuteToY(end) - top).clamp(
        16.0,
        kHoursInDay * kHourHeight,
      );
      final currentStart = _draggingId == event.id
          ? (_dragCurrentStart ?? start)
          : start;
      final width = unit - 2 <= 1 ? 1.0 : unit - 2;
      return [
        Positioned(
          left: kAxisGutter + lane * unit + 1,
          width: width,
          top: minuteToY(currentStart),
          height: height,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            // Start at the touch point so the whole 34px drag counts; with the
            // default post-slop start, ~20px of the move is discarded.
            dragStartBehavior: DragStartBehavior.down,
            // Vertical drag rather than pan: inside the scrolling grid the
            // scrollable's vertical recognizer wins any pan arena, so a child
            // vertical recognizer is what keeps block moves on the block.
            onVerticalDragStart: (_) {
              setState(() {
                _draggingId = event.id;
                _dragCurrentStart = start;
                _dragAccumulated = 0;
              });
            },
            onVerticalDragUpdate: (details) {
              _dragAccumulated += details.delta.dy * 60 / kHourHeight;
              if (_dragAccumulated.abs() < 5) return;
              final delta = _dragAccumulated.round();
              final latestStart = (1440 - (end - start)).clamp(0, 1440);
              setState(() {
                _dragCurrentStart = snapMinutes(
                  (_dragCurrentStart ?? start) + delta,
                ).clamp(0, latestStart);
              });
              _dragAccumulated -= delta;
            },
            onVerticalDragEnd: (_) => _commitPlanMove(event, start, end),
            child: PlanBlock(
              key: ValueKey('plan-${event.id}'),
              event: event,
              overdue: eventStatus(event, today) == EventStatus.overdue,
              onTap: () => showEventEditor(context, existing: event),
            ),
          ),
        ),
      ];
    }

    final start = event.startMinute ?? 0;
    return [
      Positioned(
        left: kAxisGutter,
        right: 10,
        top: minuteToY(start) - 6,
        child: ReminderCard(
          key: ValueKey('reminder-${event.id}'),
          event: event,
          overdue: eventStatus(event, today) == EventStatus.overdue,
          showCheckbox: true,
          onTap: () => showEventEditor(context, existing: event),
          onComplete: _completion(event),
        ),
      ),
    ];
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

  Future<void> _commitPlanMove(Event event, int start, int end) async {
    final moved = _dragCurrentStart;
    setState(() {
      _draggingId = null;
      _dragCurrentStart = null;
      _dragAccumulated = 0;
    });
    if (moved == null || moved == start) return;
    final updated = event.copyWith(
      startMinute: Value(moved),
      endMinute: Value(moved + (end - start)),
      updatedAt: DateTime.now(),
    );
    await ref.read(eventRepositoryProvider).updateEvent(updated);
    ref.read(eventNotifierSyncProvider).afterUpdate(updated);
  }
}

/// 216px right rail: the selected day's plan/reminder counts and a read-only
/// preview of the next day (`docs/design/10-ui-refinement.md` §9.16). It
/// follows the selected day, not necessarily today, and renders no week block.
class _DayOverview extends ConsumerWidget {
  const _DayOverview({required this.events, required this.tomorrowEvents});

  final List<Event> events;
  final List<Event> tomorrowEvents;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final palette =
        (theme.brightness == Brightness.light
                ? AppPalette.light
                : AppPalette.dark)
            .withAccent(theme.colorScheme.primary);
    final l10n = AppLocalizations.of(context);
    final categories =
        ref.watch(allCategoriesProvider).value ?? const <Category>[];
    final plans = events
        .where((event) => event.kind == EventKind.plan.dbValue)
        .length;
    final reminders = events.length - plans;
    final preview = tomorrowEvents.take(3).toList();
    final numberStyle = AppTextStyles.title.copyWith(
      fontSize: 22,
      height: 1,
      color: palette.ink,
    );
    final labelStyle = AppTextStyles.caption.copyWith(color: palette.sub);

    return Container(
      key: const ValueKey('day-overview'),
      width: 216,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.side,
        border: Border(left: BorderSide(color: palette.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.dayOverviewTitle,
            style: AppTextStyles.section.copyWith(color: palette.ink),
          ),
          const SizedBox(height: 12),
          // Scale down rather than wrap or clip if a count grows long; at the
          // design's usual counts this stays at 1:1.
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                _CountUnit(
                  textKey: const ValueKey('overview-plans-count'),
                  count: plans,
                  plan: true,
                  l10n: l10n,
                  numberStyle: numberStyle,
                  labelStyle: labelStyle,
                ),
                const SizedBox(width: 24),
                _CountUnit(
                  textKey: const ValueKey('overview-reminders-count'),
                  count: reminders,
                  plan: false,
                  l10n: l10n,
                  numberStyle: numberStyle,
                  labelStyle: labelStyle,
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          Text(
            l10n.tomorrowPreviewTitle,
            style: AppTextStyles.section.copyWith(color: palette.ink),
          ),
          const SizedBox(height: 8),
          if (preview.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                l10n.noSchedule,
                style: AppTextStyles.secondary.copyWith(color: palette.subWeak),
              ),
            )
          else
            for (final event in preview)
              _PreviewRow(
                key: ValueKey('overview-row-${event.id}'),
                event: event,
                categories: categories,
                palette: palette,
                l10n: l10n,
              ),
        ],
      ),
    );
  }
}

/// Read-only compact row: no completion circle, a 9×2.5 horizontal bar for
/// plans (the overview's compact marker language) or a 6px dot for reminders,
/// then the title and a right-aligned time.
class _PreviewRow extends StatelessWidget {
  const _PreviewRow({
    super.key,
    required this.event,
    required this.categories,
    required this.palette,
    required this.l10n,
  });

  final Event event;
  final List<Category> categories;
  final AppPalette palette;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final isPlan = event.kind == EventKind.plan.dbValue;
    final color = categoryMarkerColor(event.categoryId, categories);
    final time = event.startMinute == null
        ? l10n.allDay
        : isPlan
        ? AppFormats.timeRange(event.startMinute, event.endMinute)
        : formatMinuteOfDay(event.startMinute!);

    return SizedBox(
      height: 34,
      child: Row(
        children: [
          SizedBox(
            width: 14,
            child: Center(
              child: isPlan
                  ? Container(
                      key: ValueKey('overview-plan-marker-${event.id}'),
                      width: 9,
                      height: 2.5,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(1.25),
                      ),
                    )
                  : Container(
                      key: ValueKey('overview-reminder-marker-${event.id}'),
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              event.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.body.copyWith(color: palette.ink),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            time,
            maxLines: 1,
            style: AppTextStyles.caption.copyWith(color: palette.sub),
          ),
        ],
      ),
    );
  }
}

/// One overview count unit with the number rendered exactly once: a single
/// rich-text run whose plain text is `2 plans` / `1 个计划`. The number span is
/// 22/700 ink and the noun span is 11/`sub`, so `find.text` still matches the
/// whole unit while only one span paints the count.
///
/// The count-free noun comes from the plural-aware `planNoun` / `reminderNoun`
/// ARB keys; the leading space between the two spans lives here because the
/// number itself is painted by the number span.
class _CountUnit extends StatelessWidget {
  const _CountUnit({
    required this.textKey,
    required this.count,
    required this.plan,
    required this.l10n,
    required this.numberStyle,
    required this.labelStyle,
  });

  final Key textKey;
  final int count;
  final bool plan;
  final AppLocalizations l10n;
  final TextStyle numberStyle;
  final TextStyle labelStyle;

  @override
  Widget build(BuildContext context) {
    final noun = plan ? l10n.planNoun(count) : l10n.reminderNoun(count);
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: '$count', style: numberStyle),
          TextSpan(text: ' $noun', style: labelStyle),
        ],
      ),
      key: textKey,
      maxLines: 1,
    );
  }
}

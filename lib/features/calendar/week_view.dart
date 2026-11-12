import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/l10n/generated/app_localizations.dart';
import '../../core/utils/dates.dart';
import '../../data/database/database.dart';
import '../../data/models/event_status.dart';
import '../../data/repositories/event_repository.dart';
import '../events/event_draft.dart';
import '../events/event_editor_sheet.dart';
import 'calendar_state.dart';
import 'event_detail_popover.dart';
import 'lane_layout.dart';
import 'time_grid.dart';

/// Monday of the week containing [date].
DateTime startOfWeek(DateTime date) {
  final day = dateOnly(date);
  return day.subtract(Duration(days: day.weekday - 1));
}

class WeekView extends ConsumerStatefulWidget {
  const WeekView({super.key, this.weekStart});

  /// Any date inside the displayed week; normalised to its Monday.
  final DateTime? weekStart;

  @override
  ConsumerState<WeekView> createState() => _WeekViewState();
}

class _WeekViewState extends ConsumerState<WeekView> {
  final _scroll = ScrollController(initialScrollOffset: kDefaultScrollOffset);
  late DateTime _start;

  @override
  void initState() {
    super.initState();
    _start = startOfWeek(widget.weekStart ?? ref.read(selectedDayProvider));
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _shift(int weeks) {
    setState(() => _start = _start.add(Duration(days: 7 * weeks)));
  }

  void _openDay(DateTime day) {
    ref.read(selectedDayProvider.notifier).select(day);
    ref.read(calendarViewModeProvider.notifier).set(CalendarViewMode.day);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final days = List.generate(7, (i) => _start.add(Duration(days: i)));
    final end = _start.add(const Duration(days: 7));
    final events =
        ref.watch(eventsInRangeProvider((start: _start, end: end))).value ??
            const <Event>[];
    final today = dateOnly(DateTime.now());
    final mode = ref.watch(calendarViewModeProvider);

    final byDay = <DateTime, List<Event>>{};
    for (final event in events) {
      byDay.putIfAbsent(dateOnly(event.date), () => []).add(event);
    }

    final narrow = MediaQuery.sizeOf(context).width < 560;
    final segmented = SegmentedButton<CalendarViewMode>(
      segments: [
        ButtonSegment(value: CalendarViewMode.month, label: Text(l10n.month)),
        ButtonSegment(value: CalendarViewMode.week, label: Text(l10n.week)),
        ButtonSegment(value: CalendarViewMode.day, label: Text(l10n.day)),
      ],
      selected: {mode},
      showSelectedIcon: false,
      onSelectionChanged: (selection) =>
          ref.read(calendarViewModeProvider.notifier).set(selection.first),
    );

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
          child: Row(
            children: [
              Flexible(
                child: Text(
                  '${DateFormat.MMMd(locale).format(_start)} – '
                  '${DateFormat.MMMd(locale).format(days.last)}',
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.chevron_left, size: 20),
                onPressed: () => _shift(-1),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.chevron_right, size: 20),
                onPressed: () => _shift(1),
              ),
              const Spacer(),
              if (!narrow) segmented,
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => setState(() {
                  _start = startOfWeek(DateTime.now());
                  ref.read(selectedDayProvider.notifier).select(today);
                }),
                child: Text(l10n.today),
              ),
            ],
          ),
        ),
        if (narrow)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Align(alignment: Alignment.centerLeft, child: segmented),
          ),
        Padding(
          padding: const EdgeInsets.only(right: 4),
          child: Row(
            children: [
              const SizedBox(width: 26),
              for (final day in days)
                Expanded(
                  child: InkWell(
                    key: ValueKey(
                      'week-day-${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}',
                    ),
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => _openDay(day),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Column(
                        children: [
                          Text(
                            DateFormat.E(locale).format(day),
                            style: TextStyle(
                              fontSize: 10,
                              color: Theme.of(context).colorScheme.outline,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Container(
                            width: 22,
                            height: 22,
                            alignment: Alignment.center,
                            decoration: day == today
                                ? BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary,
                                  )
                                : null,
                            child: Text(
                              '${day.day}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: day == today
                                    ? Theme.of(context).colorScheme.onPrimary
                                    : Theme.of(context)
                                        .colorScheme
                                        .onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              const gutter = 26.0;
              final columnWidth = (constraints.maxWidth - gutter) / 7;
              return SingleChildScrollView(
                key: const ValueKey('week-scroll'),
                controller: _scroll,
                child: SizedBox(
                  height: kHoursInDay * kHourHeight,
                  child: Stack(
                    children: [
                      const Positioned.fill(
                        child: HourGrid(gutterWidth: gutter),
                      ),
                      for (var i = 0; i < 7; i++)
                        Positioned(
                          left: gutter + i * columnWidth,
                          width: columnWidth,
                          top: 0,
                          height: kHoursInDay * kHourHeight,
                          child: _DayColumn(
                            day: days[i],
                            events: byDay[dateOnly(days[i])] ?? const [],
                            today: today,
                            onOpenEvent: (event) =>
                                showEventDetailPopover(context, event),
                            onCreateReminder:
                                (kind, start, endMinute) => showEventEditor(
                              context,
                              date: days[i],
                              initialKind: kind,
                              startMinute: start,
                              endMinute: endMinute,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _DayColumn extends StatelessWidget {
  const _DayColumn({
    required this.day,
    required this.events,
    required this.today,
    required this.onOpenEvent,
    required this.onCreateReminder,
  });

  final DateTime day;
  final List<Event> events;
  final DateTime today;
  final void Function(Event) onOpenEvent;
  final void Function(EventKind kind, int? start, int? end)
      onCreateReminder;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final plans = events
        .where((e) => e.kind == EventKind.plan.dbValue && e.startMinute != null)
        .toList();
    final reminders = events
        .where((e) => e.kind != EventKind.plan.dbValue)
        .toList();

    final lanes = assignLanes([
      for (final plan in plans)
        TimeRange(
          id: plan.id,
          start: plan.startMinute!,
          end: plan.endMinute,
        ),
    ]);
    final laneTotal = laneCount(lanes);

    return LayoutBuilder(
      builder: (context, constraints) {
        final unit = constraints.maxWidth / (laneTotal == 0 ? 1 : laneTotal);
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (details) {
                  final minute = yToMinute(details.localPosition.dy);
                  onCreateReminder(EventKind.reminder, minute, null);
                },
              ),
            ),
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Container(
                width: 0.6,
                color: scheme.outlineVariant.withValues(alpha: .45),
              ),
            ),
            for (final plan in plans)
              Positioned(
                left: (lanes[plan.id] ?? 0) * unit + 1,
                width: unit - 2,
                top: minuteToY(plan.startMinute!),
                height: ((minuteToY(plan.endMinute ?? plan.startMinute! + 30) -
                            minuteToY(plan.startMinute!))
                        .clamp(14.0, kHoursInDay * kHourHeight)),
                child: GestureDetector(
                  onTap: () => onOpenEvent(plan),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: plan.isCompleted
                          ? scheme.surfaceContainerHighest.withValues(alpha: .5)
                          : scheme.primary.withValues(alpha: .13),
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(
                        color: plan.isCompleted
                            ? scheme.outlineVariant
                            : scheme.primary.withValues(alpha: .4),
                        width: 0.7,
                      ),
                    ),
                    child: Text(
                      plan.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: plan.isCompleted
                            ? scheme.outline
                            : scheme.onSurface,
                      ),
                    ),
                  ),
                ),
              ),
            for (final reminder in reminders)
              if (reminder.startMinute != null)
                Positioned(
                  left: 1,
                  right: 1,
                  top: minuteToY(reminder.startMinute!) - 4,
                  child: GestureDetector(
                    onTap: () => onOpenEvent(reminder),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 3, vertical: 2),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(
                          color: eventStatus(reminder, today) ==
                                  EventStatus.overdue
                              ? scheme.error.withValues(alpha: .6)
                              : scheme.outlineVariant,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x1114141E),
                            blurRadius: 4,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Text(
                        reminder.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 9,
                          color: reminder.isCompleted
                              ? scheme.outline
                              : scheme.onSurface,
                          decoration: reminder.isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                        ),
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/l10n/generated/app_localizations.dart';
import '../../core/utils/dates.dart';
import '../../data/database/database.dart';
import '../../data/repositories/event_repository.dart';
import 'calendar_state.dart';

DateTime firstDayOfMonth(DateTime month) =>
    DateTime(month.year, month.month, 1);

/// Monday-first grid, always 42 cells (6 weeks × 7 days).
List<DateTime?> monthGridDays(DateTime month) {
  final first = firstDayOfMonth(month);
  final start = first.subtract(Duration(days: first.weekday - 1));
  return List<DateTime?>.generate(42, (i) => start.add(Duration(days: i)));
}

class MonthView extends ConsumerStatefulWidget {
  const MonthView({super.key, this.month, this.onNewEvent});

  /// Displayed month; defaults to the month of the selected day.
  final DateTime? month;
  final VoidCallback? onNewEvent;

  @override
  ConsumerState<MonthView> createState() => _MonthViewState();
}

class _MonthViewState extends ConsumerState<MonthView> {
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    _month = firstDayOfMonth(widget.month ?? ref.read(selectedDayProvider));
  }

  void _shiftMonth(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta, 1));
  }

  void _goToday() {
    final today = dateOnly(DateTime.now());
    setState(() => _month = firstDayOfMonth(today));
    ref.read(selectedDayProvider.notifier).select(today);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final days = monthGridDays(_month);
    final rangeStart = days.first!;
    final rangeEnd = days.last!.add(const Duration(days: 1));
    final eventsAsync =
        ref.watch(eventsInRangeProvider((start: rangeStart, end: rangeEnd)));
    final holidaysAsync = ref.watch(holidaysProvider);
    final selected = ref.watch(selectedDayProvider);
    final today = dateOnly(DateTime.now());
    final viewMode = ref.watch(calendarViewModeProvider);

    final eventsByDay = <DateTime, List<Event>>{};
    for (final event in eventsAsync.value ?? const <Event>[]) {
      eventsByDay.putIfAbsent(dateOnly(event.date), () => []).add(event);
    }
    final holidaysByDay = <DateTime, String>{
      for (final holiday in holidaysAsync.value ?? const <Holiday>[])
        dateOnly(holiday.date): holiday.name,
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                DateFormat.yMMMM(locale).format(_month),
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 4),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.chevron_left, size: 20),
                onPressed: () => _shiftMonth(-1),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.chevron_right, size: 20),
                onPressed: () => _shiftMonth(1),
              ),
              const Spacer(),
              SegmentedButton<CalendarViewMode>(
                segments: [
                  ButtonSegment(
                      value: CalendarViewMode.month, label: Text(l10n.month)),
                  ButtonSegment(
                      value: CalendarViewMode.week, label: Text(l10n.week)),
                  ButtonSegment(
                      value: CalendarViewMode.day, label: Text(l10n.day)),
                ],
                selected: {viewMode},
                showSelectedIcon: false,
                onSelectionChanged: (selection) => ref
                    .read(calendarViewModeProvider.notifier)
                    .set(selection.first),
              ),
              const SizedBox(width: 8),
              TextButton(onPressed: _goToday, child: Text(l10n.today)),
              const SizedBox(width: 4),
              IconButton.filledTonal(
                tooltip: l10n.newEvent,
                icon: const Icon(Icons.add, size: 18),
                onPressed: widget.onNewEvent,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: Center(
                    child: Text(
                      DateFormat.E(locale)
                          .format(DateTime(2024, 1, 1 + i)),
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(color: Theme.of(context).colorScheme.outline),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Expanded(
            child: Column(
              children: [
                for (var row = 0; row < 6; row++)
                  Expanded(
                    child: Row(
                      children: [
                        for (var col = 0; col < 7; col++)
                          Expanded(
                            child: _DayCell(
                              day: days[row * 7 + col]!,
                              inMonth: days[row * 7 + col]!.month == _month.month,
                              isToday:
                                  dateOnly(days[row * 7 + col]!) == today,
                              isSelected:
                                  dateOnly(days[row * 7 + col]!) == selected,
                              events:
                                  eventsByDay[dateOnly(days[row * 7 + col]!)] ??
                                      const [],
                              holidayName:
                                  holidaysByDay[dateOnly(days[row * 7 + col]!)],
                              onTap: () {
                                final day = dateOnly(days[row * 7 + col]!);
                                ref
                                    .read(selectedDayProvider.notifier)
                                    .select(day);
                                ref
                                    .read(calendarViewModeProvider.notifier)
                                    .set(CalendarViewMode.day);
                              },
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
    );
  }
}

class _DayCell extends StatefulWidget {
  const _DayCell({
    required this.day,
    required this.inMonth,
    required this.isToday,
    required this.isSelected,
    required this.events,
    required this.onTap,
    this.holidayName,
  });

  final DateTime day;
  final bool inMonth;
  final bool isToday;
  final bool isSelected;
  final List<Event> events;
  final String? holidayName;
  final VoidCallback onTap;

  @override
  State<_DayCell> createState() => _DayCellState();
}

class _DayCellState extends State<_DayCell> {
  final _link = LayerLink();
  final _controller = OverlayPortalController();

  String _keyDate() =>
      '${widget.day.year}-${widget.day.month.toString().padLeft(2, '0')}-${widget.day.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final shown = widget.events.take(2).toList();
    final overflow = widget.events.length - shown.length;

    return CompositedTransformTarget(
      link: _link,
      child: MouseRegion(
        onEnter: (_) => _controller.show(),
        onExit: (_) => _controller.hide(),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: OverlayPortal(
            controller: _controller,
            overlayChildBuilder: (context) => IgnorePointer(
              child: CompositedTransformFollower(
                link: _link,
                showWhenUnlinked: false,
                offset: const Offset(6, 6),
                child: Align(
                  alignment: Alignment.topLeft,
                  child: _DaySummaryCard(
                    day: widget.day,
                    events: widget.events,
                  ),
                ),
              ),
            ),
            child: Container(
              key: ValueKey('day-${_keyDate()}'),
              margin: const EdgeInsets.all(1.5),
              padding: const EdgeInsets.fromLTRB(4, 3, 4, 2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: widget.isSelected
                    ? scheme.primary.withValues(alpha: .07)
                    : null,
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha:
                      widget.isSelected ? .9 : .45),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 18,
                        height: 18,
                        alignment: Alignment.center,
                        decoration: widget.isToday
                            ? BoxDecoration(
                                shape: BoxShape.circle,
                                color: scheme.primary,
                              )
                            : null,
                        child: Text(
                          '${widget.day.day}',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: widget.isToday
                                ? scheme.onPrimary
                                : widget.inMonth
                                    ? scheme.onSurface
                                    : scheme.outline,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (widget.holidayName != null)
                    Text(
                      widget.holidayName!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 8.5, color: scheme.error),
                    ),
                  const Spacer(),
                  for (final event in shown)
                    Text(
                      _eventLine(event, l10n),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 9,
                        color: event.isCompleted
                            ? scheme.outline
                            : scheme.onSurfaceVariant,
                        decoration: event.isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                  if (overflow > 0)
                    Text(
                      l10n.moreItems(overflow),
                      style: TextStyle(fontSize: 9, color: scheme.outline),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _eventLine(Event event, AppLocalizations l10n) {
    final minute = event.startMinute;
    if (minute == null) return '${l10n.allDay} ${event.title}';
    final time = DateFormat.Hm().format(
      DateTime(2000, 1, 1, minute ~/ 60, minute % 60),
    );
    return '$time ${event.title}';
  }
}

class _DaySummaryCard extends StatelessWidget {
  const _DaySummaryCard({required this.day, required this.events});

  final DateTime day;
  final List<Event> events;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final shown = events.take(5).toList();
    final hidden = events.length - shown.length;

    return Container(
      key: const ValueKey('day-summary-popover'),
      width: 216,
      padding: const EdgeInsets.fromLTRB(11, 9, 11, 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: .6)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x2214141E),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            DateFormat.MMMMd(locale).format(day),
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 5),
          if (events.isEmpty)
            Text(
              l10n.noEvents,
              style: TextStyle(fontSize: 10.5, color: scheme.outline),
            )
          else
            for (final event in shown)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 1.5),
                child: Row(
                  children: [
                    Container(
                      width: 3,
                      height: 12,
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        color: event.kind == 'plan'
                            ? scheme.primary.withValues(alpha: .55)
                            : scheme.tertiary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        _DayCellState._eventLine(event, l10n),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10.5,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          if (hidden > 0)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                l10n.hoverMoreItems(hidden),
                style: TextStyle(fontSize: 10, color: scheme.outline),
              ),
            ),
        ],
      ),
    );
  }
}

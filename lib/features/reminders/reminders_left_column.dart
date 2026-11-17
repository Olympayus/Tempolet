import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/generated/app_localizations.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/ui/app_hairline.dart';
import '../../core/ui/strike_through_text.dart';
import '../../core/utils/dates.dart';
import '../../core/utils/formats.dart';
import '../../data/database/database.dart';
import '../../data/repositories/category_repository.dart';
import '../../data/repositories/event_repository.dart';
import '../calendar/calendar_state.dart';
import '../calendar/category_marker.dart';
import '../calendar/mini_month_calendar.dart';
import '../calendar/plan_block.dart';
import '../calendar/reminder_card.dart';
import '../calendar/time_grid.dart';
import '../events/event_editor_sheet.dart';

/// Fixed width of the reminders page's left column (`04-reminders.md` §2).
const double kRemindersLeftColumnWidth = 204;

/// Mini-calendar footprint above the timeline.
const double _miniCalendarWidth = 180;

/// Axis gutter and item start from `10-ui-refinement.md` §9.7.
const double _timelineGutter = 40;
const double _timelineItemLeft = 44;
const double _timelineItemRight = 8;

/// Strike/fill sweep for a retained card; zero under reduce-motion.
const Duration _retainDuration = Duration(milliseconds: 200);

/// Left column of the reminders page: a shared [MiniMonthCalendar] over the
/// selected day's 68px/hour timeline (`04-reminders.md` §2, §9.7).
class RemindersLeftColumn extends ConsumerStatefulWidget {
  const RemindersLeftColumn({
    super.key,
    this.onSelectDay,
    this.recentlyCompleted = const {},
    this.animatingIds = const {},
    this.onComplete,
    this.onUndo,
  });

  /// Called after a mini-calendar pick, so the date-mode list can locate it.
  final ValueChanged<DateTime>? onSelectDay;

  /// Session-retained completions from the page. Cards stay in place and the
  /// title count includes them until the page is left.
  final Map<String, Event> recentlyCompleted;

  /// Ids completed during this session; drives the one-shot strike/fill.
  final Set<String> animatingIds;

  /// Page-owned write path; the column never touches the repositories.
  final Future<void> Function(Event)? onComplete;
  final Future<void> Function(Event)? onUndo;

  @override
  ConsumerState<RemindersLeftColumn> createState() =>
      _RemindersLeftColumnState();
}

class _RemindersLeftColumnState extends ConsumerState<RemindersLeftColumn> {
  final _scroll = ScrollController(initialScrollOffset: kDefaultScrollOffset);
  DateTime? _month;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  List<Event> _sorted(List<Event> events) {
    final list = events.toList();
    list.sort((a, b) {
      final aStart = a.startMinute;
      final bStart = b.startMinute;
      if (aStart == null && bStart == null) return a.id.compareTo(b.id);
      if (aStart == null) return 1;
      if (bStart == null) return -1;
      final byStart = aStart.compareTo(bStart);
      return byStart != 0 ? byStart : a.id.compareTo(b.id);
    });
    return list;
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
    final l10n = AppLocalizations.of(context);
    final today = dateOnly(ref.watch(todayProvider));
    final selected = dateOnly(ref.watch(selectedDayProvider));
    final categories =
        ref.watch(allCategoriesProvider).value ?? const <Category>[];

    final month = _month ?? DateTime(selected.year, selected.month, 1);
    final monthStart = DateTime(month.year, month.month, 1);
    final monthEnd = DateTime(month.year, month.month + 1, 1);
    final monthEvents =
        ref
            .watch(rangeEventsProvider((start: monthStart, end: monthEnd)))
            .value ??
        const <Event>[];
    final eventDays = <DateTime>{};
    final planDays = <DateTime>{};
    final eventDayColors = <DateTime, Color>{};
    for (final event in monthEvents) {
      final day = dateOnly(event.date);
      eventDays.add(day);
      eventDayColors.putIfAbsent(
        day,
        () => categoryMarkerColor(event.categoryId, categories),
      );
      if (event.kind == 'plan') planDays.add(day);
    }

    // Completed reminders stay on the timeline for the session; plans have no
    // completion circle and are not retained here. The retained snapshot wins
    // over a lagging stream copy of the pending event.
    final retained = <Event>[
      for (final event in widget.recentlyCompleted.values)
        if (event.kind != 'plan' && dateOnly(event.date) == selected) event,
    ];
    final seen = {for (final event in retained) event.id};
    final dayEvents = _sorted([
      ...retained,
      ...(ref.watch(eventsForDayProvider(selected)).value ?? const <Event>[])
          .where((event) => !seen.contains(event.id)),
    ]);
    // Intentional locale-aware join: Chinese keeps `11月17日 周一 · 3 项`,
    // English uses the `·` separator between date, weekday and count.
    final separator = locale.languageCode == 'zh' ? ' ' : ' · ';
    final title =
        '${AppFormats.monthDay(locale, selected)}'
        '$separator${AppFormats.weekday(locale, selected)}'
        ' · ${l10n.itemsCount(dayEvents.length)}';

    return Container(
      key: const ValueKey('reminders-left-column'),
      width: kRemindersLeftColumnWidth,
      decoration: BoxDecoration(
        color: palette.side,
        border: Border(right: BorderSide(color: palette.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            // The 1px right border consumes one logical pixel inside the
            // 204px column, so the 180px calendar keeps an 11px right inset.
            padding: const EdgeInsets.fromLTRB(12, 16, 11, 0),
            child: MiniMonthCalendar(
              key: const ValueKey('reminders-mini-calendar'),
              month: month,
              selected: selected,
              today: today,
              eventDays: eventDays,
              planDays: planDays,
              eventDayColors: eventDayColors,
              width: _miniCalendarWidth,
              onSelect: (day) {
                ref.read(selectedDayProvider.notifier).select(day);
                widget.onSelectDay?.call(day);
              },
              onMonthChanged: (next) =>
                  setState(() => _month = DateTime(next.year, next.month, 1)),
            ),
          ),
          const SizedBox(height: 20),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: AppHairline(),
          ),
          SizedBox(
            height: 34,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  title,
                  key: const ValueKey('reminders-timeline-title'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.section.copyWith(color: palette.ink),
                ),
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              key: const ValueKey('reminders-timeline'),
              controller: _scroll,
              child: SizedBox(
                height: kHoursInDay * kHourHeight,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: HourGrid(
                        gutterWidth: _timelineGutter,
                        labelRightPadding: 0,
                        labelBuilder: (context, hour) => Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Text(
                            '${hour.toString().padLeft(2, '0')}:00',
                            maxLines: 1,
                            textAlign: TextAlign.left,
                            style: AppTextStyles.caption.copyWith(
                              color: palette.sub,
                            ),
                          ),
                        ),
                      ),
                    ),
                    for (final event in dayEvents)
                      ..._timelineEvent(event, selected, today),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _timelineEvent(Event event, DateTime selected, DateTime today) {
    final start = event.startMinute ?? 0;
    final overdue = selected.isBefore(today);
    if (event.kind == 'plan') {
      final end = event.endMinute ?? (start + 30);
      final top = minuteToY(start);
      final height = (minuteToY(end) - top).clamp(
        16.0,
        kHoursInDay * kHourHeight,
      );
      return [
        Positioned(
          left: _timelineItemLeft,
          right: _timelineItemRight,
          top: top,
          height: height,
          child: PlanBlock(
            key: ValueKey('reminders-timeline-event-${event.id}'),
            event: event,
            overdue: overdue,
            compact: true,
            onTap: () => showEventEditor(context, existing: event),
          ),
        ),
      ];
    }

    final top = (minuteToY(start) - 6).clamp(
      0.0,
      kHoursInDay * kHourHeight - 24,
    );
    final retained = widget.recentlyCompleted.containsKey(event.id);
    return [
      Positioned(
        left: _timelineItemLeft,
        right: _timelineItemRight,
        top: top,
        child: _TimelineReminder(
          event: event,
          overdue: overdue,
          retained: retained,
          animate: widget.animatingIds.contains(event.id),
          onComplete: widget.onComplete,
          onUndo: widget.onUndo,
        ),
      ),
    ];
  }
}

/// Keeps the timeline card widget type and position stable across completion
/// so the circle fill and title strike animate in place.
class _TimelineReminder extends StatelessWidget {
  const _TimelineReminder({
    required this.event,
    required this.overdue,
    required this.retained,
    required this.animate,
    this.onComplete,
    this.onUndo,
  });

  final Event event;
  final bool overdue;
  final bool retained;
  final bool animate;
  final Future<void> Function(Event)? onComplete;
  final Future<void> Function(Event)? onUndo;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final end = retained ? 1.0 : 0.0;
    // Reduce-motion (or an already-animated retake) starts at the terminal
    // value, so the first frame is already the final state.
    final begin = retained && (reduceMotion || !animate) ? 1.0 : 0.0;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: begin, end: end),
      duration: reduceMotion || !retained ? Duration.zero : _retainDuration,
      builder: (context, progress, _) {
        return ReminderCard(
          key: ValueKey('reminders-timeline-event-${event.id}'),
          event: event,
          overdue: overdue,
          showCheckbox: true,
          onTap: retained
              ? null
              : () => showEventEditor(context, existing: event),
          onComplete: retained || onComplete == null
              ? null
              : () => onComplete!(event),
          onUndo: !retained || onUndo == null ? null : () => onUndo!(event),
          progress: retained ? progress : null,
          titleBuilder: retained
              ? (context, style) => StrikeThroughText(
                  text: event.title,
                  style: style,
                  progress: progress,
                )
              : null,
        );
      },
    );
  }
}

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/generated/app_localizations.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/ui/app_buttons.dart';
import '../../core/ui/app_segmented.dart';
import '../../core/ui/strike_through_text.dart';
import '../../core/ui/swipe_actions_row.dart';
import '../../core/utils/dates.dart';
import '../../core/utils/formats.dart';
import '../../data/database/database.dart';
import '../../data/repositories/category_repository.dart';
import '../../data/repositories/event_repository.dart';
import '../../notifications/notification_scheduler.dart';
import '../events/event_editor_sheet.dart';
import '../events/event_list_row.dart';
import 'calendar_state.dart';
import 'category_marker.dart';
import 'day_view.dart';
import 'holiday_badge.dart';
import 'month_model.dart';

/// Phone calendar (`docs/design/02-shell-mobile.md` §2): month and week only.
/// The month view is a sticky grid over an independently scrolling selected-day
/// list; the week view is a centered 7-day strip over the single-day timeline.
class PhoneCalendarPage extends ConsumerWidget {
  const PhoneCalendarPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stored = ref.watch(calendarViewModeProvider);
    final mode = stored == CalendarViewMode.day
        ? CalendarViewMode.month
        : stored;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _PhoneCalendarHeader(),
        Expanded(
          child: mode == CalendarViewMode.month
              ? const _PhoneMonthBody()
              : const _PhoneWeekBody(),
        ),
      ],
    );
  }
}

class _PhoneCalendarHeader extends ConsumerWidget {
  const _PhoneCalendarHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final palette =
        (theme.brightness == Brightness.light
                ? AppPalette.light
                : AppPalette.dark)
            .withAccent(theme.colorScheme.primary);
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final selected = ref.watch(selectedDayProvider);
    final mode = ref.watch(calendarViewModeProvider);
    final effective = mode == CalendarViewMode.day
        ? CalendarViewMode.month
        : mode;

    return Container(
      key: const ValueKey('phone-calendar-header'),
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: palette.line)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              AppFormats.monthTitle(locale, selected),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.title.copyWith(
                fontSize: 22,
                color: palette.ink,
              ),
            ),
          ),
          AppButton.secondary(
            key: const ValueKey('phone-calendar-today'),
            label: l10n.today,
            onPressed: () => ref
                .read(selectedDayProvider.notifier)
                .select(dateOnly(ref.read(todayProvider))),
          ),
          const SizedBox(width: 8),
          AppSegmented<CalendarViewMode>(
            key: const ValueKey('phone-calendar-mode'),
            values: const [CalendarViewMode.month, CalendarViewMode.week],
            labelFor: (value) =>
                Text(value == CalendarViewMode.month ? l10n.month : l10n.week),
            selected: effective,
            onChanged: (value) =>
                ref.read(calendarViewModeProvider.notifier).set(value),
          ),
        ],
      ),
    );
  }
}

/// Sticky month grid + the selected day's list below it.
class _PhoneMonthBody extends ConsumerWidget {
  const _PhoneMonthBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedDayProvider);
    final weeks = monthWeeks(selected);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PhoneMonthPanel(weeks: weeks),
        const _PhoneDaySection(),
      ],
    );
  }
}

const double _phoneMonthRowHeight = 58;

class _PhoneMonthPanel extends ConsumerWidget {
  const _PhoneMonthPanel({required this.weeks});

  final List<List<DateTime?>> weeks;

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
    final today = dateOnly(ref.watch(todayProvider));
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

    final eventsByDay = <DateTime, List<Event>>{};
    for (final event in events) {
      eventsByDay.putIfAbsent(dateOnly(event.date), () => []).add(event);
    }
    final holidayByDay = <DateTime, Holiday>{
      for (final holiday in holidays) dateOnly(holiday.date): holiday,
    };

    return GestureDetector(
      key: const ValueKey('phone-month-panel'),
      onVerticalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity < -120) {
          ref.read(selectedDayProvider.notifier).shiftMonths(1);
        } else if (velocity > 120) {
          ref.read(selectedDayProvider.notifier).shiftMonths(-1);
        }
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 8),
        child: Column(
          children: [
            SizedBox(
              height: 28,
              child: Container(
                decoration: BoxDecoration(
                  color: palette.side,
                  border: Border(bottom: BorderSide(color: palette.lineStrong)),
                ),
                child: Row(
                  children: [
                    for (var i = 0; i < 7; i++)
                      Expanded(
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
                  ],
                ),
              ),
            ),
            for (final week in weeks)
              Container(
                height: _phoneMonthRowHeight,
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: palette.line)),
                ),
                child: Row(
                  children: [
                    for (final day in week)
                      Expanded(
                        child: day == null
                            ? const SizedBox.shrink()
                            : _PhoneDayCell(
                                day: day,
                                isToday: day == today,
                                isSelected: day == selected,
                                events: eventsByDay[day] ?? const <Event>[],
                                holiday: holidayByDay[day],
                                categories: categories,
                                palette: palette,
                                locale: locale,
                                onTap: () => ref
                                    .read(selectedDayProvider.notifier)
                                    .select(day),
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

class _PhoneDayCell extends StatelessWidget {
  const _PhoneDayCell({
    required this.day,
    required this.isToday,
    required this.isSelected,
    required this.events,
    required this.holiday,
    required this.categories,
    required this.palette,
    required this.locale,
    required this.onTap,
  });

  final DateTime day;
  final bool isToday;
  final bool isSelected;
  final List<Event> events;
  final Holiday? holiday;
  final List<Category> categories;
  final AppPalette palette;
  final Locale locale;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.all(1.5),
        decoration: BoxDecoration(
          color: isSelected ? palette.accentTint : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.fromLTRB(1, 4, 1, 3),
        child: Column(
          children: [
            SizedBox(
              height: 20,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isToday)
                    Container(
                      width: 20,
                      height: 20,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: palette.accent,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${day.day}',
                        style: AppTextStyles.body.copyWith(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    )
                  else
                    Text(
                      '${day.day}',
                      style: AppTextStyles.body.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: palette.ink,
                      ),
                    ),
                  if (holiday != null) ...[
                    const SizedBox(width: 2),
                    HolidayBadge(
                      holiday: holiday!,
                      palette: palette,
                      fontSize: 8,
                    ),
                  ],
                ],
              ),
            ),
            // The holiday name always renders right under the date; markers
            // never push it out.
            SizedBox(
              height: 11,
              child: holiday == null
                  ? null
                  : Text(
                      holiday!.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption.copyWith(
                        fontSize: 9,
                        height: 1.1,
                        color: palette.festival,
                      ),
                    ),
            ),
            Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: MonthMarkerRow(
                  events: events,
                  categories: categories,
                  palette: palette,
                  gap: 4,
                  ellipsisKey: ValueKey(
                    'phone-month-more-${day.year}-${day.month}-${day.day}',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The selected day's header + independently scrolling list.
///
/// Touch rows complete in place (D70): the row keeps its position with a
/// 200ms strike-through until the user leaves the month list, and swiping it
/// left reveals edit/delete.
class _PhoneDaySection extends ConsumerStatefulWidget {
  const _PhoneDaySection();

  @override
  ConsumerState<_PhoneDaySection> createState() => _PhoneDaySectionState();
}

class _PhoneDaySectionState extends ConsumerState<_PhoneDaySection> {
  final Map<String, Event> _recentlyCompleted = <String, Event>{};
  final Set<String> _animatedIds = <String>{};
  final SwipeActionsController _swipe = SwipeActionsController();

  @override
  void dispose() {
    // Leaving the page drops the retained snapshots; the items now belong to
    // the completed page.
    _recentlyCompleted.clear();
    _swipe.dispose();
    super.dispose();
  }

  Future<void> _complete(Event event) async {
    final repo = ref.read(eventRepositoryProvider);
    final sync = ref.read(eventNotifierSyncProvider);
    await repo.setCompleted(event.id, true);
    final snapshot = event.copyWith(
      isCompleted: true,
      completedAt: Value(DateTime.now()),
    );
    if (mounted) {
      setState(() {
        _recentlyCompleted[event.id] = snapshot;
        _animatedIds.add(event.id);
      });
    }
    sync.afterCompletion(snapshot);
  }

  Future<void> _undo(Event event) async {
    final repo = ref.read(eventRepositoryProvider);
    final sync = ref.read(eventNotifierSyncProvider);
    await repo.setCompleted(event.id, false);
    if (mounted) {
      setState(() {
        _recentlyCompleted.remove(event.id);
        _animatedIds.remove(event.id);
      });
    }
    sync.afterUpdate(
      event.copyWith(
        isCompleted: false,
        completedAt: const Value(null),
        updatedAt: DateTime.now(),
      ),
    );
  }

  List<SwipeAction> _swipeActionsFor(
    Event event,
    AppPalette palette,
    AppLocalizations l10n,
  ) {
    return [
      SwipeAction(
        id: 'edit',
        label: l10n.edit,
        color: palette.accent,
        onPressed: () => showEventEditor(context, existing: event),
      ),
      SwipeAction(
        id: 'delete',
        label: l10n.delete,
        color: palette.danger,
        onPressed: () => _confirmDelete(event, l10n),
      ),
    ];
  }

  Future<void> _confirmDelete(Event event, AppLocalizations l10n) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: const ValueKey('delete-confirm'),
        content: Text(l10n.deleteForeverHint),
        actions: [
          TextButton(
            key: const ValueKey('delete-confirm-cancel'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            key: const ValueKey('delete-confirm-delete'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(notificationSchedulerProvider).cancelEvent(event);
    await ref.read(eventRepositoryProvider).hardDelete(event.id);
  }

  Widget _strikeTitle({
    required Event event,
    required TextStyle style,
    required Color endColor,
  }) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    Widget title(double progress) => StrikeThroughText(
      key: ValueKey('phone-day-strike-${event.id}'),
      text: event.title,
      style: TextStyle.lerp(style, style.copyWith(color: endColor), progress)!,
      progress: progress,
    );
    if (reduceMotion || !_animatedIds.contains(event.id)) return title(1);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 200),
      builder: (context, progress, _) => title(progress),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette =
        (theme.brightness == Brightness.light
                ? AppPalette.light
                : AppPalette.dark)
            .withAccent(theme.colorScheme.primary);
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final selected = ref.watch(selectedDayProvider);
    final events =
        ref.watch(eventsForDayProvider(selected)).value ?? const <Event>[];
    final categories =
        ref.watch(allCategoriesProvider).value ?? const <Category>[];

    // Pending rows keep their provider order; a retained completion stays in
    // the same slot through its snapshot.
    final visible = <Event>[
      for (final event in events)
        if (!event.isCompleted)
          event
        else if (_recentlyCompleted.containsKey(event.id))
          _recentlyCompleted[event.id]!,
      for (final retained in _recentlyCompleted.values)
        if (!events.any((event) => event.id == retained.id)) retained,
    ];

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Row(
              children: [
                Text(
                  AppFormats.monthDay(locale, selected),
                  style: AppTextStyles.headline.copyWith(color: palette.ink),
                ),
                const SizedBox(width: 8),
                Text(
                  AppFormats.weekday(locale, selected),
                  style: AppTextStyles.body.copyWith(color: palette.ink),
                ),
                const Spacer(),
                Text(
                  l10n.itemsCount(visible.length),
                  style: AppTextStyles.secondary.copyWith(color: palette.sub),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              key: const ValueKey('phone-day-list'),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                if (visible.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      l10n.noSchedule,
                      style: AppTextStyles.body.copyWith(color: palette.sub),
                    ),
                  ),
                for (final event in visible)
                  SwipeActionsRow(
                    id: event.id,
                    controller: _swipe,
                    actions: _swipeActionsFor(event, palette, l10n),
                    enabled: !_recentlyCompleted.containsKey(event.id),
                    child: EventListRow(
                      key: ValueKey('phone-day-row-${event.id}'),
                      event: event,
                      height: 52,
                      color: categoryMarkerColor(event.categoryId, categories),
                      completeKey: ValueKey('phone-day-complete-${event.id}'),
                      onTap: _recentlyCompleted.containsKey(event.id)
                          ? null
                          : () => showEventEditor(context, existing: event),
                      onToggleComplete: _recentlyCompleted.containsKey(event.id)
                          ? () => _undo(event)
                          : () => _complete(event),
                      titleBuilder: _recentlyCompleted.containsKey(event.id)
                          ? (context, style) => _strikeTitle(
                              event: event,
                              style: style,
                              endColor: palette.sub,
                            )
                          : null,
                    ),
                  ),
                SizedBox(
                  height: 52,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => showEventEditor(context, date: selected),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        l10n.addReminderOrPlan,
                        style: AppTextStyles.body.copyWith(
                          color: palette.accent,
                        ),
                      ),
                    ),
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

class _PhoneWeekBody extends ConsumerWidget {
  const _PhoneWeekBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _PhoneDateStrip(),
        const Expanded(child: DayView()),
      ],
    );
  }
}

class _PhoneDateStrip extends ConsumerWidget {
  const _PhoneDateStrip();

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
    final today = dateOnly(ref.watch(todayProvider));
    final start = DateTime(selected.year, selected.month, selected.day - 3);
    final days = [
      for (var i = 0; i < 7; i++)
        DateTime(start.year, start.month, start.day + i),
    ];

    Widget cell(DateTime day) {
      final isToday = day == today;
      final isSelected = day == selected;
      return Expanded(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => ref.read(selectedDayProvider.notifier).select(day),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                AppFormats.weekday(locale, day),
                style: AppTextStyles.caption.copyWith(color: palette.sub),
              ),
              const SizedBox(height: 4),
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected ? palette.accent : Colors.transparent,
                  shape: BoxShape.circle,
                  border: !isSelected && isToday
                      ? Border.all(color: palette.accent, width: 1.5)
                      : null,
                ),
                child: Text(
                  '${day.day}',
                  style: AppTextStyles.body.copyWith(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? Colors.white : palette.ink,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return GestureDetector(
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity < -150) {
          ref.read(selectedDayProvider.notifier).shiftDays(7);
        } else if (velocity > 150) {
          ref.read(selectedDayProvider.notifier).shiftDays(-7);
        }
      },
      child: Container(
        key: const ValueKey('phone-date-strip'),
        height: 64,
        decoration: BoxDecoration(
          color: palette.side,
          border: Border(bottom: BorderSide(color: palette.line)),
        ),
        child: Row(children: [for (final day in days) cell(day)]),
      ),
    );
  }
}

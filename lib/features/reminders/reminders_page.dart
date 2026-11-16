import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/l10n/generated/app_localizations.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/ui/app_buttons.dart';
import '../../core/ui/app_segmented.dart';
import '../../core/utils/dates.dart';
import '../../core/utils/formats.dart';
import '../../data/database/database.dart';
import '../../data/repositories/category_repository.dart';
import '../../data/repositories/event_repository.dart';
import '../../notifications/notification_scheduler.dart';
import '../calendar/calendar_state.dart';
import '../calendar/category_marker.dart';
import '../events/event_editor_sheet.dart';
import '../events/event_list_row.dart';
import 'category_order.dart';
import 'reminders_header.dart';
import 'reminders_left_column.dart';

/// Page content inset (`10-ui-refinement.md` §9.7); rows add 8 outside their
/// own 16px internal padding so their content aligns with this inset.
const double _contentInset = 24;
const double _rowOuterInset = 8;

const double _groupHeaderHeight = 34;
const double _groupGap = 12;

/// Category mode asks for an effectively unbounded future window: a narrow
/// horizon would silently drop far-off reminders and could show the empty
/// state even though they exist. Date mode (Task 15) owns the long-range
/// month band.
const int _futureHorizonYears = 100;

/// Stable group id for the overdue bucket (not a real category id).
const String _overdueGroupId = '__overdue__';

enum RemindersFilter { all, reminder, plan }

enum RemindersMode { category, date }

/// `/reminders` (`04-reminders.md`, `10-ui-refinement.md` §9.7).
///
/// Task 14 builds the shell, the two segment controls and category mode: the
/// overdue bucket first, category groups in `categoryOrderProvider` order and
/// the system 未分类 group. Date mode arrives with Task 15.
class RemindersPage extends ConsumerStatefulWidget {
  const RemindersPage({super.key});

  @override
  ConsumerState<RemindersPage> createState() => _RemindersPageState();
}

class _RemindersPageState extends ConsumerState<RemindersPage> {
  RemindersFilter _filter = RemindersFilter.all;
  RemindersMode _mode = RemindersMode.category;
  final Set<String> _collapsed = <String>{};
  final Set<DateTime> _collapsedDays = <DateTime>{};
  final Set<String> _expandedMonths = <String>{};
  final ScrollController _dateScroll = ScrollController();
  final Map<String, GlobalKey> _dayAnchors = <String, GlobalKey>{};

  @override
  void dispose() {
    _dateScroll.dispose();
    super.dispose();
  }

  String _dayKey(DateTime day) =>
      '${day.year}-'
      '${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';

  String _monthKey(DateTime month) =>
      '${month.year}-${month.month.toString().padLeft(2, '0')}';

  GlobalKey _anchorFor(String key) =>
      _dayAnchors.putIfAbsent(key, GlobalKey.new);

  List<Event> _filtered(Iterable<Event> events) => switch (_filter) {
    RemindersFilter.all => events.toList(),
    RemindersFilter.reminder =>
      events.where((event) => event.kind != 'plan').toList(),
    RemindersFilter.plan =>
      events.where((event) => event.kind == 'plan').toList(),
  };

  /// `watchRange` orders by start minute; multi-day lists need date first.
  List<Event> _sortedByDate(Iterable<Event> events) {
    final list = events.toList();
    list.sort((a, b) {
      final byDate = a.date.compareTo(b.date);
      if (byDate != 0) return byDate;
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

  Future<void> _openNew(DateTime day, {String? categoryId}) {
    return showEventEditor(context, date: day, categoryId: categoryId);
  }

  Future<void> _complete(Event event) async {
    final repo = ref.read(eventRepositoryProvider);
    final sync = ref.read(eventNotifierSyncProvider);
    await repo.setCompleted(event.id, true);
    sync.afterCompletion(event.copyWith(isCompleted: true));
  }

  void _toggleGroup(String id) {
    setState(() {
      if (!_collapsed.remove(id)) _collapsed.add(id);
    });
  }

  void _toggleDay(DateTime day) {
    setState(() {
      if (!_collapsedDays.remove(day)) _collapsedDays.add(day);
    });
  }

  void _toggleMonth(String key) {
    setState(() {
      if (!_expandedMonths.remove(key)) _expandedMonths.add(key);
    });
  }

  DateTime _later(DateTime a, DateTime b) => a.isAfter(b) ? a : b;

  /// Locates a mini-calendar pick inside the date band, or expands the month
  /// that contains it when it sits outside the band.
  void _locateDate(DateTime picked) {
    if (_mode != RemindersMode.date) return;
    final today = dateOnly(ref.read(todayProvider));
    final bandEnd = DateTime(today.year, today.month, today.day + 6);
    final target = dateOnly(picked);
    final afterBand = DateTime(bandEnd.year, bandEnd.month, bandEnd.day + 1);
    final currentMonthEnd = DateTime(today.year, today.month + 1, 1);

    String? monthKey;
    DateTime? rangeStart;
    DateTime? rangeEnd;
    if (target.isAfter(bandEnd)) {
      if (target.isBefore(currentMonthEnd)) {
        monthKey = 'remaining';
        rangeStart = afterBand;
        rangeEnd = currentMonthEnd;
      } else {
        for (var i = 1; i <= 6; i++) {
          final month = DateTime(today.year, today.month + i, 1);
          if (month.year == target.year && month.month == target.month) {
            monthKey = _monthKey(month);
            rangeStart = _later(month, afterBand);
            rangeEnd = DateTime(month.year, month.month + 1, 1);
            break;
          }
        }
      }
    }

    if (monthKey != null) {
      if (rangeStart == null ||
          rangeEnd == null ||
          !rangeStart.isBefore(rangeEnd)) {
        return;
      }
      final rangeEvents =
          ref
              .read(rangeEventsProvider((start: rangeStart, end: rangeEnd)))
              .value ??
          const <Event>[];
      if (_filtered(rangeEvents).isEmpty) return;
      if (!_expandedMonths.contains(monthKey)) {
        setState(() => _expandedMonths.add(monthKey!));
      }
    }

    final anchor = _dayAnchors['day-${_dayKey(target)}'];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final context = anchor?.currentContext;
      if (context == null) return;
      Scrollable.ensureVisible(
        context,
        alignment: .05,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
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
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final today = dateOnly(ref.watch(todayProvider));
    final tomorrow = DateTime(today.year, today.month, today.day + 1);
    final weekStart = startOfWeek(today);
    final weekEnd = DateTime(
      weekStart.year,
      weekStart.month,
      weekStart.day + 7,
    );
    final horizonEnd = DateTime(
      today.year + _futureHorizonYears,
      today.month,
      today.day,
    );

    final overdueAll =
        ref.watch(overdueEventsProvider(today)).value ?? const <Event>[];
    final upcomingAll =
        ref.watch(rangeEventsProvider((start: today, end: horizonEnd))).value ??
        const <Event>[];
    final todayEvents =
        ref.watch(rangeEventsProvider((start: today, end: tomorrow))).value ??
        const <Event>[];
    final weekEvents =
        ref
            .watch(rangeEventsProvider((start: weekStart, end: weekEnd)))
            .value ??
        const <Event>[];
    final categories =
        ref.watch(allCategoriesProvider).value ?? const <Category>[];
    final order = ref.watch(categoryOrderProvider);

    final overdue = _sortedByDate(_filtered(overdueAll));
    final upcoming = _sortedByDate(_filtered(upcomingAll));

    final knownIds = {for (final category in categories) category.id};
    final byCategory = <String?, List<Event>>{};
    for (final event in upcoming) {
      final categoryId = event.categoryId;
      final key = categoryId != null && knownIds.contains(categoryId)
          ? categoryId
          : null;
      byCategory.putIfAbsent(key, () => <Event>[]).add(event);
    }

    final groups = <_CategoryGroup>[];
    if (overdue.isNotEmpty) {
      groups.add(
        _CategoryGroup(
          id: _overdueGroupId,
          title: l10n.remindersOverdue,
          events: overdue,
          danger: true,
        ),
      );
    }
    for (final category in applyCategoryOrder(order, categories)) {
      final events = byCategory[category?.id];
      if (events == null || events.isEmpty) continue;
      groups.add(
        _CategoryGroup(
          id: category?.id ?? uncategorizedOrderId,
          title: category?.name ?? l10n.uncategorized,
          events: events,
          categoryId: category?.id,
        ),
      );
    }

    final Widget content;
    if (_mode == RemindersMode.category) {
      content = _categoryMode(
        groups: groups,
        categories: categories,
        today: today,
        palette: palette,
        l10n: l10n,
      );
    } else {
      // The band starts on the oldest overdue day (or today) and always runs
      // through today+6. The future-months summaries extend the query to the
      // end of the six-month window.
      final earliestOverdue = ref.watch(earliestOverdueProvider(today)).value;
      final bandStart = dateOnly(earliestOverdue ?? today);
      final bandEnd = DateTime(today.year, today.month, today.day + 6);
      final sixMonthsEnd = DateTime(today.year, today.month + 7, 1);
      final raw =
          ref
              .watch(rangeEventsProvider((start: bandStart, end: sixMonthsEnd)))
              .value ??
          const <Event>[];
      content = _dateMode(
        today: today,
        bandStart: bandStart,
        bandEnd: bandEnd,
        events: _sortedByDate(_filtered(raw)),
        categories: categories,
        palette: palette,
        l10n: l10n,
        locale: locale,
      );
    }

    return Scaffold(
      key: const ValueKey('reminders-page'),
      backgroundColor: palette.bg,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RemindersLeftColumn(onSelectDay: _locateDate),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                RemindersHeader(
                  // Disabled until Task 16 wires /reminders/categories.
                  onManageCategories: null,
                  onViewCompleted: () => context.go('/reminders/completed'),
                  onCreate: () => _openNew(today),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    _contentInset,
                    4,
                    _contentInset,
                    0,
                  ),
                  child: Row(
                    children: [
                      _Stat(
                        key: const ValueKey('reminders-stat-overdue'),
                        label: l10n.remindersOverdue,
                        count: overdueAll.length,
                        danger: true,
                      ),
                      const SizedBox(width: 16),
                      _Stat(
                        key: const ValueKey('reminders-stat-today'),
                        label: l10n.remindersToday,
                        count: todayEvents.length,
                      ),
                      const SizedBox(width: 16),
                      _Stat(
                        key: const ValueKey('reminders-stat-week'),
                        label: l10n.remindersThisWeek,
                        count: weekEvents.length,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: _contentInset,
                  ),
                  child: Row(
                    children: [
                      Flexible(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: AppSegmented<RemindersFilter>(
                            key: const ValueKey('reminders-filter'),
                            values: const [
                              RemindersFilter.all,
                              RemindersFilter.reminder,
                              RemindersFilter.plan,
                            ],
                            labelFor: (filter) => Text(switch (filter) {
                              RemindersFilter.all => l10n.filterAll,
                              RemindersFilter.reminder => l10n.kindReminder,
                              RemindersFilter.plan => l10n.kindPlan,
                            }),
                            selected: _filter,
                            onChanged: (filter) =>
                                setState(() => _filter = filter),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Flexible(
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: AppSegmented<RemindersMode>(
                            key: const ValueKey('reminders-mode'),
                            values: const [
                              RemindersMode.category,
                              RemindersMode.date,
                            ],
                            labelFor: (mode) => Text(switch (mode) {
                              RemindersMode.category => l10n.categoryLabel,
                              RemindersMode.date => l10n.dateLabel,
                            }),
                            selected: _mode,
                            onChanged: (mode) => setState(() => _mode = mode),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Expanded(child: content),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _categoryMode({
    required List<_CategoryGroup> groups,
    required List<Category> categories,
    required DateTime today,
    required AppPalette palette,
    required AppLocalizations l10n,
  }) {
    if (groups.isEmpty) {
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(_contentInset, 32, _contentInset, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.remindersEmptyTitle,
              key: const ValueKey('reminders-empty-title'),
              style: AppTextStyles.rowTitle.copyWith(color: palette.sub),
            ),
            const SizedBox(height: 2),
            Text(
              l10n.remindersEmptyBody,
              style: AppTextStyles.body.copyWith(color: palette.subWeak),
            ),
            const SizedBox(height: 10),
            AppButton.textLink(
              key: const ValueKey('reminders-empty-new'),
              label: '＋ ${l10n.newItem}',
              onPressed: () => _openNew(today),
            ),
          ],
        ),
      );
    }

    return ListView(
      key: const ValueKey('reminders-category-mode'),
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      children: [
        for (var i = 0; i < groups.length; i++) ...[
          if (i > 0) const SizedBox(height: _groupGap),
          _group(
            group: groups[i],
            categories: categories,
            today: today,
            palette: palette,
            l10n: l10n,
          ),
        ],
      ],
    );
  }

  List<DateTime> _daysBetween(DateTime start, DateTime endExclusive) {
    final days = <DateTime>[];
    var day = dateOnly(start);
    while (day.isBefore(endExclusive)) {
      days.add(day);
      day = DateTime(day.year, day.month, day.day + 1);
    }
    return days;
  }

  // TODO(Task 19): route the remaining-month range label through the shared
  // date formatting pass.
  String _rangeLabel(Locale locale, DateTime start, DateTime end) {
    final startText = AppFormats.monthDay(locale, start);
    return locale.languageCode == 'zh'
        ? '$startText – ${end.day}日'
        : '$startText – ${end.day}';
  }

  Widget _dateMode({
    required DateTime today,
    required DateTime bandStart,
    required DateTime bandEnd,
    required List<Event> events,
    required List<Category> categories,
    required AppPalette palette,
    required AppLocalizations l10n,
    required Locale locale,
  }) {
    final eventsByDay = <DateTime, List<Event>>{};
    for (final event in events) {
      eventsByDay.putIfAbsent(dateOnly(event.date), () => <Event>[]).add(event);
    }

    final children = <Widget>[];
    var bandDay = bandStart;
    while (!bandDay.isAfter(bandEnd)) {
      final day = bandDay;
      children.add(
        _dateDay(
          day: day,
          events: eventsByDay[day] ?? const <Event>[],
          today: today,
          categories: categories,
          palette: palette,
          l10n: l10n,
          locale: locale,
        ),
      );
      bandDay = DateTime(day.year, day.month, day.day + 1);
    }

    void addExpansion(String key, List<DateTime> days) {
      if (!_expandedMonths.contains(key) || days.isEmpty) return;
      for (final day in days) {
        children.add(
          _dateDay(
            day: day,
            events: eventsByDay[day] ?? const <Event>[],
            today: today,
            categories: categories,
            palette: palette,
            l10n: l10n,
            locale: locale,
          ),
        );
      }
    }

    final currentMonthEnd = DateTime(today.year, today.month + 1, 1);
    final afterBand = DateTime(bandEnd.year, bandEnd.month, bandEnd.day + 1);
    children.add(const SizedBox(height: 12));

    if (afterBand.isBefore(currentMonthEnd)) {
      final days = _daysBetween(afterBand, currentMonthEnd);
      children.add(
        _monthSummary(
          keyString: 'remaining',
          label: l10n.restOfMonth,
          rangeLabel: _rangeLabel(locale, days.first, days.last),
          days: days,
          eventsByDay: eventsByDay,
          palette: palette,
          l10n: l10n,
        ),
      );
      addExpansion('remaining', days);
    }

    children.add(const SizedBox(height: 12));
    children.add(
      SizedBox(
        height: 34,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: _contentInset),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              l10n.futureMonths,
              key: const ValueKey('future-months-header'),
              style: AppTextStyles.body.copyWith(
                fontWeight: FontWeight.w600,
                fontVariations: const [FontVariation('wght', 600)],
                color: palette.sub,
              ),
            ),
          ),
        ),
      ),
    );

    for (var i = 1; i <= 6; i++) {
      final month = DateTime(today.year, today.month + i, 1);
      final monthEnd = DateTime(month.year, month.month + 1, 1);
      final start = _later(month, afterBand);
      final days = start.isBefore(monthEnd)
          ? _daysBetween(start, monthEnd)
          : const <DateTime>[];
      final key = _monthKey(month);
      children.add(
        _monthSummary(
          keyString: key,
          label: AppFormats.monthTitle(locale, month),
          days: days,
          eventsByDay: eventsByDay,
          palette: palette,
          l10n: l10n,
        ),
      );
      addExpansion(key, days);
    }

    return SingleChildScrollView(
      key: const ValueKey('reminders-date-mode'),
      controller: _dateScroll,
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }

  Widget _monthSummary({
    required String keyString,
    required String label,
    required List<DateTime> days,
    required Map<DateTime, List<Event>> eventsByDay,
    required AppPalette palette,
    required AppLocalizations l10n,
    String? rangeLabel,
  }) {
    final count = days.fold<int>(
      0,
      (sum, day) => sum + (eventsByDay[day]?.length ?? 0),
    );
    final expandable = count > 0;
    final expanded = expandable && _expandedMonths.contains(keyString);
    final labelColor = expandable ? palette.ink : palette.subWeak;

    return InkWell(
      key: ValueKey('month-summary-$keyString'),
      onTap: expandable ? () => _toggleMonth(keyString) : null,
      child: SizedBox(
        height: 40,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: _contentInset),
          child: Row(
            children: [
              Text(
                label,
                key: ValueKey('month-summary-$keyString-label'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.body.copyWith(color: labelColor),
              ),
              if (rangeLabel != null) ...[
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    rangeLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.secondary.copyWith(
                      color: expandable ? palette.sub : palette.subWeak,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              Text(
                '·',
                style: AppTextStyles.caption.copyWith(color: palette.subMuted),
              ),
              const SizedBox(width: 6),
              Text(
                expandable ? l10n.itemsCount(count) : l10n.noSchedule,
                maxLines: 1,
                style: AppTextStyles.caption.copyWith(
                  color: expandable ? palette.subMuted : palette.subWeak,
                ),
              ),
              const SizedBox(width: 6),
              SizedBox(
                width: 14,
                child: expandable
                    ? Icon(
                        expanded
                            ? LucideIcons.chevronDown
                            : LucideIcons.chevronRight,
                        size: 14,
                        color: palette.sub,
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _todayTag(AppPalette palette, AppLocalizations l10n, String key) {
    return Container(
      key: ValueKey('date-group-today-$key'),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: palette.accentTint,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Text(
        l10n.today,
        style: AppTextStyles.caption.copyWith(color: palette.accent),
      ),
    );
  }

  Widget _dateDay({
    required DateTime day,
    required List<Event> events,
    required DateTime today,
    required List<Category> categories,
    required AppPalette palette,
    required AppLocalizations l10n,
    required Locale locale,
  }) {
    final key = _dayKey(day);
    final anchor = _anchorFor('day-$key');

    if (events.isEmpty) {
      return KeyedSubtree(
        key: anchor,
        child: InkWell(
          key: ValueKey('empty-day-$key'),
          onTap: () => _openNew(day),
          child: SizedBox(
            height: AppSizes.row,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: _contentInset),
              child: Row(
                children: [
                  Text(
                    AppFormats.monthDay(locale, day),
                    style: AppTextStyles.body.copyWith(color: palette.sub),
                  ),
                  if (locale.languageCode != 'zh') ...[
                    const SizedBox(width: 4),
                    Text(
                      '·',
                      style: AppTextStyles.caption.copyWith(
                        color: palette.sub,
                      ),
                    ),
                  ],
                  const SizedBox(width: 6),
                  Text(
                    AppFormats.weekday(locale, day),
                    style: AppTextStyles.secondary.copyWith(color: palette.sub),
                  ),
                  if (day == today) ...[
                    const SizedBox(width: 6),
                    _todayTag(palette, l10n, key),
                  ],
                  const Spacer(),
                  Text(
                    l10n.noSchedule,
                    style: AppTextStyles.body.copyWith(color: palette.subWeak),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final isOverdueDay = day.isBefore(today);
    final collapsed = _collapsedDays.contains(day);
    return KeyedSubtree(
      key: anchor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            key: ValueKey('date-group-$key'),
            height: _groupHeaderHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: _contentInset),
              child: Row(
                children: [
                  Text(
                    AppFormats.monthDay(locale, day),
                    style: AppTextStyles.section.copyWith(color: palette.ink),
                  ),
                  if (locale.languageCode != 'zh') ...[
                    const SizedBox(width: 4),
                    Text(
                      '·',
                      style: AppTextStyles.caption.copyWith(color: palette.sub),
                    ),
                  ],
                  const SizedBox(width: 6),
                  Text(
                    AppFormats.weekday(locale, day),
                    style: AppTextStyles.secondary.copyWith(color: palette.sub),
                  ),
                  if (day == today) ...[
                    const SizedBox(width: 6),
                    _todayTag(palette, l10n, key),
                  ],
                  if (isOverdueDay) ...[
                    const SizedBox(width: 6),
                    Text(
                      l10n.remindersOverdue,
                      key: ValueKey('date-group-overdue-$key'),
                      style: AppTextStyles.caption.copyWith(
                        color: palette.danger,
                      ),
                    ),
                  ],
                  const SizedBox(width: 8),
                  Text(
                    l10n.itemsCount(events.length),
                    key: ValueKey('date-group-count-$key'),
                    style: AppTextStyles.caption.copyWith(
                      color: isOverdueDay ? palette.danger : palette.subMuted,
                    ),
                  ),
                  const Spacer(),
                  AppIconButton(
                    key: ValueKey('date-group-add-$key'),
                    tooltip: l10n.newItem,
                    onPressed: () => _openNew(day),
                    icon: Icon(LucideIcons.plus, size: 14, color: palette.sub),
                  ),
                  AppIconButton(
                    key: ValueKey('date-group-toggle-$key'),
                    onPressed: () => _toggleDay(day),
                    icon: Icon(
                      collapsed
                          ? LucideIcons.chevronRight
                          : LucideIcons.chevronDown,
                      size: 14,
                      color: palette.sub,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (!collapsed)
            for (final event in events)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: _rowOuterInset),
                child: EventListRow(
                  key: ValueKey('date-row-${event.id}'),
                  event: event,
                  color: categoryMarkerColor(event.categoryId, categories),
                  showDate: false,
                  timeColor: isOverdueDay ? palette.danger : null,
                  timeSuffix: isOverdueDay ? l10n.remindersOverdue : null,
                  onTap: () => showEventEditor(context, existing: event),
                  onToggleComplete: () => _complete(event),
                ),
              ),
        ],
      ),
    );
  }

  Widget _group({
    required _CategoryGroup group,
    required List<Category> categories,
    required DateTime today,
    required AppPalette palette,
    required AppLocalizations l10n,
  }) {
    final collapsed = _collapsed.contains(group.id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          key: ValueKey('reminders-group-${group.id}'),
          height: _groupHeaderHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: _contentInset),
            child: Row(
              children: [
                Text(
                  group.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.section.copyWith(color: palette.ink),
                ),
                const SizedBox(width: 8),
                Text(
                  '${group.events.length}',
                  style: AppTextStyles.caption.copyWith(
                    color: group.danger ? palette.danger : palette.subMuted,
                  ),
                ),
                const Spacer(),
                AppIconButton(
                  key: ValueKey('reminders-group-add-${group.id}'),
                  tooltip: l10n.newItem,
                  onPressed: () =>
                      _openNew(today, categoryId: group.categoryId),
                  icon: Icon(LucideIcons.plus, size: 14, color: palette.sub),
                ),
                AppIconButton(
                  key: ValueKey('reminders-group-toggle-${group.id}'),
                  onPressed: () => _toggleGroup(group.id),
                  icon: Icon(
                    collapsed
                        ? LucideIcons.chevronRight
                        : LucideIcons.chevronDown,
                    size: 14,
                    color: palette.sub,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (!collapsed)
          for (final event in group.events)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: _rowOuterInset),
              child: EventListRow(
                key: ValueKey('reminders-row-${event.id}'),
                event: event,
                color: categoryMarkerColor(event.categoryId, categories),
                showDate: true,
                timeColor: group.danger ? palette.danger : null,
                onTap: () => showEventEditor(context, existing: event),
                onToggleComplete: () => _complete(event),
              ),
            ),
      ],
    );
  }
}

class _CategoryGroup {
  const _CategoryGroup({
    required this.id,
    required this.title,
    required this.events,
    this.categoryId,
    this.danger = false,
  });

  final String id;
  final String title;
  final List<Event> events;
  final String? categoryId;
  final bool danger;
}

/// One stats unit rendered as a single rich-text run: `逾期 1` / `Overdue 1`.
///
/// Keeping the label and number in one Text means `find.text('逾期')` only
/// matches the group header, while the overdue number can take `danger`
/// without painting the label red.
class _Stat extends StatelessWidget {
  const _Stat({
    super.key,
    required this.label,
    required this.count,
    this.danger = false,
  });

  final String label;
  final int count;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette =
        (theme.brightness == Brightness.light
                ? AppPalette.light
                : AppPalette.dark)
            .withAccent(theme.colorScheme.primary);
    final labelStyle = AppTextStyles.body.copyWith(color: palette.sub);
    final numberStyle = AppTextStyles.body.copyWith(
      color: danger ? palette.danger : palette.sub,
    );
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: '$label ', style: labelStyle),
          TextSpan(text: '$count', style: numberStyle),
        ],
      ),
      maxLines: 1,
    );
  }
}

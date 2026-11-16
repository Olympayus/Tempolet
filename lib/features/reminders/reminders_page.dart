import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/l10n/generated/app_localizations.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/ui/app_buttons.dart';
import '../../core/ui/app_segmented.dart';
import '../../core/utils/dates.dart';
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

/// Category mode lists the coming year. Date mode (Task 15) owns the
/// long-range month band.
const int _upcomingHorizonDays = 366;

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette =
        (theme.brightness == Brightness.light
                ? AppPalette.light
                : AppPalette.dark)
            .withAccent(theme.colorScheme.primary);
    final l10n = AppLocalizations.of(context);
    final today = dateOnly(ref.watch(todayProvider));
    final tomorrow = DateTime(today.year, today.month, today.day + 1);
    final weekStart = startOfWeek(today);
    final weekEnd = DateTime(
      weekStart.year,
      weekStart.month,
      weekStart.day + 7,
    );
    final horizonEnd = DateTime(
      today.year,
      today.month,
      today.day + _upcomingHorizonDays,
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

    return Scaffold(
      key: const ValueKey('reminders-page'),
      backgroundColor: palette.bg,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const RemindersLeftColumn(),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                RemindersHeader(
                  onManageCategories: () {
                    // TODO(Task 16): navigate to /reminders/categories once
                    // the category management page exists.
                  },
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
                Expanded(
                  child: _mode == RemindersMode.category
                      ? _categoryMode(
                          groups: groups,
                          categories: categories,
                          today: today,
                          palette: palette,
                          l10n: l10n,
                        )
                      : const SizedBox.expand(
                          key: ValueKey('reminders-date-mode-placeholder'),
                        ),
                ),
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

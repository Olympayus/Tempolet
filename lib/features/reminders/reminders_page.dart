import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/l10n/generated/app_localizations.dart';
import '../../core/layout.dart';
import '../../core/layout_metrics.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/ui/app_buttons.dart';
import '../../core/ui/app_popover.dart';
import '../../core/ui/app_segmented.dart';
import '../../core/ui/fitted_label.dart';
import '../../core/ui/strike_through_text.dart';
import '../../core/ui/swipe_actions_row.dart';
import '../../core/utils/dates.dart';
import '../../core/utils/formats.dart';
import '../../data/database/database.dart';
import '../../data/models/event_status.dart';
import '../../data/repositories/category_repository.dart';
import '../../data/repositories/event_repository.dart';
import '../../notifications/notification_scheduler.dart';
import '../calendar/calendar_state.dart';
import '../calendar/category_marker.dart';
import '../events/event_draft.dart';
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

/// Title strike/fill sweep for a retained completion (`08-motion.md`);
/// collapse to zero under reduce-motion.
const Duration _retainDuration = Duration(milliseconds: 200);

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

  /// Session-only completed snapshots: rows stay in place until the user
  /// leaves `/reminders`, then silently fall back to the completed page.
  final Map<String, Event> _recentlyCompleted = <String, Event>{};

  /// Ids that completed during this session (drives the one-shot animation).
  final Set<String> _animatedIds = <String>{};

  /// At most one touch row reveals its edit/delete actions.
  final SwipeActionsController _swipe = SwipeActionsController();

  /// Tablet left-column override; null follows orientation and width.
  bool? _leftColumnOpenOverride;

  /// Set while the router is on another branch (`/reminders/completed`,
  /// `/reminders/categories`, the calendar, settings). The indexed stack keeps
  /// this page mounted, so `mounted` cannot tell whether the user is still
  /// looking at it; an in-flight completion needs this flag to avoid dropping
  /// a retained row into a page the user already left.
  bool _leftPage = false;

  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = ref.read(routerProvider);
    _router.routerDelegate.addListener(_onRouteChanged);
  }

  @override
  void dispose() {
    _router.routerDelegate.removeListener(_onRouteChanged);
    _dateScroll.dispose();
    _swipe.dispose();
    super.dispose();
  }

  /// `/reminders/completed`, `/reminders/categories`, the calendar, settings
  /// and any other branch all count as leaving the reminders page.
  void _onRouteChanged() {
    if (!mounted) return;
    final onReminders =
        _router.routerDelegate.currentConfiguration.uri.path == '/reminders';
    _leftPage = !onReminders;
    if (!onReminders && _recentlyCompleted.isNotEmpty) {
      setState(() {
        _recentlyCompleted.clear();
        _animatedIds.clear();
      });
    }
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
    // On the plan filter every add entry point (empty state, date group,
    // category group) creates a plan; the other filters keep the editor's
    // reminder default.
    return showEventEditor(
      context,
      date: day,
      categoryId: categoryId,
      initialKind: _filter == RemindersFilter.plan ? EventKind.plan : null,
    );
  }

  /// Concatenates two event lists without duplicating ids. [preferred] wins,
  /// so a just-completed retention snapshot masks the stream's stale pending
  /// copy during the frame before the database stream catches up.
  List<Event> _mergeById(Iterable<Event> preferred, Iterable<Event> fallback) {
    final merged = <Event>[];
    final seen = <String>{};
    for (final event in preferred) {
      if (seen.add(event.id)) merged.add(event);
    }
    for (final event in fallback) {
      if (seen.add(event.id)) merged.add(event);
    }
    return merged;
  }

  /// Completion must not hide the overdue placement: `eventStatus` returns
  /// `done` for completed rows, so judge a pending copy.
  bool _isOverdue(Event event, DateTime today) =>
      eventStatus(event.copyWith(isCompleted: false), today) ==
      EventStatus.overdue;

  /// Session-retained events honouring the active kind filter.
  List<Event> _retained() => _filtered(_recentlyCompleted.values);

  /// Retained overdue items, earliest day first, for the date band's start.
  List<Event> _retainedOverdue(DateTime today) =>
      _sortedByDate(_retained().where((event) => _isOverdue(event, today)));

  /// The date band starts on the oldest pending overdue day, or on the oldest
  /// retained overdue day while this session shows one. It only shrinks once
  /// leaving the page clears retention.
  DateTime _bandStart(DateTime today, List<Event> overdue) {
    DateTime? start;
    if (overdue.isNotEmpty) start = dateOnly(overdue.first.date);
    final retained = _retainedOverdue(today);
    if (retained.isNotEmpty) {
      final candidate = dateOnly(retained.first.date);
      if (start == null || candidate.isBefore(start)) start = candidate;
    }
    return start ?? today;
  }

  Future<void> _complete(Event event) async {
    final repo = ref.read(eventRepositoryProvider);
    final sync = ref.read(eventNotifierSyncProvider);
    await repo.setCompleted(event.id, true);
    final snapshot = event.copyWith(
      isCompleted: true,
      completedAt: Value(DateTime.now()),
    );
    // The write outlives a route change: if the user left `/reminders` while
    // it was in flight, the item belongs in the completed page, not in a
    // retained row on a page they are no longer looking at.
    if (mounted && !_leftPage) {
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

  /// Edit/delete actions behind a swiped touch row.
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
        onPressed: () => _confirmSwipeDelete(event, l10n),
      ),
    ];
  }

  /// Touch layouts use the touch row height; desktop keeps 46.
  double _rowHeight(BuildContext context) =>
      isTouchLayout(resolveAppLayout(context))
      ? LayoutMetrics.of(context).row
      : AppSizes.row;

  /// Wraps a reminders row in the swipe primitive on phone/tablet only.
  Widget _touchRow({
    required Event event,
    required Widget row,
    required AppPalette palette,
    required AppLocalizations l10n,
  }) {
    if (!isTouchLayout(resolveAppLayout(context))) return row;
    return SwipeActionsRow(
      id: event.id,
      controller: _swipe,
      actions: _swipeActionsFor(event, palette, l10n),
      enabled: !_recentlyCompleted.containsKey(event.id),
      child: row,
    );
  }

  Future<void> _confirmSwipeDelete(Event event, AppLocalizations l10n) async {
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
    final overdue =
        ref.read(overdueEventsProvider(today)).value ?? const <Event>[];
    final bandStart = _bandStart(today, overdue);
    final bandEnd = DateTime(today.year, today.month, today.day + 6);
    final target = dateOnly(picked);
    final afterBand = DateTime(bandEnd.year, bandEnd.month, bandEnd.day + 1);
    final currentMonthEnd = DateTime(today.year, today.month + 1, 1);
    final sixMonthsEnd = DateTime(today.year, today.month + 7, 1);

    // Read the exact range the date-mode page already watches. A cold
    // `ref.read` of an unwatched family instance would be AsyncLoading and
    // silently look empty on the first pick. Retained rows are merged in so a
    // month whose only item was completed this session still expands.
    final events = _sortedByDate(
      _mergeById(
        _retained(),
        _filtered(
          ref
                  .read(
                    rangeEventsProvider((start: bandStart, end: sixMonthsEnd)),
                  )
                  .value ??
              const <Event>[],
        ),
      ),
    );

    String? monthKey;
    bool Function(Event)? isInMonth;
    if (target.isAfter(bandEnd)) {
      if (target.isBefore(currentMonthEnd)) {
        monthKey = 'remaining';
        isInMonth = (event) {
          final day = dateOnly(event.date);
          return !day.isBefore(afterBand) && day.isBefore(currentMonthEnd);
        };
      } else {
        for (var i = 1; i <= 6; i++) {
          final month = DateTime(today.year, today.month + i, 1);
          if (month.year == target.year && month.month == target.month) {
            monthKey = _monthKey(month);
            isInMonth = (event) {
              final day = dateOnly(event.date);
              return day.year == month.year && day.month == month.month;
            };
            break;
          }
        }
      }
    }

    if (monthKey != null && isInMonth != null) {
      // Match the summary row's expandability: remaining days for the current
      // month, the whole month for future summaries.
      if (!events.any(isInMonth)) return;
      if (!_expandedMonths.contains(monthKey)) {
        setState(() => _expandedMonths.add(monthKey!));
      }
    }

    // Register the anchor before rebuilding: on the first expansion the day
    // row does not exist yet, so looking it up synchronously would yield null
    // and the post-frame callback would never scroll.
    final anchor = _anchorFor('day-${_dayKey(target)}');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final context = anchor.currentContext;
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
    final retained = _retained();
    final retainedOverdue = _sortedByDate(
      retained.where((event) => _isOverdue(event, today)),
    );
    final retainedUpcoming = retained.where(
      (event) => !_isOverdue(event, today),
    );

    // Merge the session's completed snapshots into every display list: group
    // counts, header stats and the rows themselves must show what is on
    // screen, including items completed a moment ago.
    final overdueDisplay = _sortedByDate(_mergeById(retainedOverdue, overdue));
    final upcomingDisplay = _sortedByDate(
      _mergeById(retainedUpcoming, upcoming),
    );
    bool inRange(Event event, DateTime start, DateTime end) {
      final day = dateOnly(event.date);
      return !day.isBefore(start) && day.isBefore(end);
    }

    final todayDisplay = _mergeById(
      retained.where((event) => inRange(event, today, tomorrow)),
      _filtered(todayEvents),
    );
    final weekDisplay = _mergeById(
      retained.where((event) => inRange(event, weekStart, weekEnd)),
      _filtered(weekEvents),
    );

    final knownIds = {for (final category in categories) category.id};
    final byCategory = <String?, List<Event>>{};
    for (final event in upcomingDisplay) {
      final categoryId = event.categoryId;
      final key = categoryId != null && knownIds.contains(categoryId)
          ? categoryId
          : null;
      byCategory.putIfAbsent(key, () => <Event>[]).add(event);
    }

    final groups = <_CategoryGroup>[];
    if (overdueDisplay.isNotEmpty) {
      groups.add(
        _CategoryGroup(
          id: _overdueGroupId,
          title: l10n.remindersOverdue,
          events: overdueDisplay,
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
          color: category?.color == null ? null : Color(category!.color!),
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
      // The band starts on the oldest overdue day — including retained
      // completions — or today, and always runs through today+6. Deriving it
      // from the already-watched overdue stream keeps it responsive when that
      // event is completed or deleted; retention only shrinks it on leave.
      final bandStart = _bandStart(today, overdueAll);
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
        events: _sortedByDate(_mergeById(retained, _filtered(raw))),
        categories: categories,
        palette: palette,
        l10n: l10n,
        locale: locale,
      );
    }

    return Scaffold(
      key: const ValueKey('reminders-page'),
      backgroundColor: palette.bg,
      body: Builder(
        builder: (context) {
          final layout = resolveAppLayout(context);
          final phone = layout == AppLayout.phone;
          final size = MediaQuery.sizeOf(context);
          final portrait = size.height >= size.width;
          final tablet = layout == AppLayout.tablet;
          final leftColumnOpen =
              _leftColumnOpenOverride ?? (!portrait && size.width >= 700);
          final inset = phone ? 16.0 : _contentInset;
          final column = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (phone)
                _PhoneRemindersHeader(
                  onManageCategories: () => context.go('/reminders/categories'),
                  onViewCompleted: () => context.go('/reminders/completed'),
                  onCreate: () => _openNew(today),
                )
              else
                RemindersHeader(
                  onManageCategories: () => context.go('/reminders/categories'),
                  onViewCompleted: () => context.go('/reminders/completed'),
                  onCreate: () => _openNew(today),
                  leftColumnOpen: tablet ? leftColumnOpen : null,
                  onToggleLeftColumn: tablet
                      ? () => setState(
                          () => _leftColumnOpenOverride = !leftColumnOpen,
                        )
                      : null,
                ),
              Padding(
                padding: EdgeInsets.fromLTRB(inset, 4, inset, 0),
                // Fixed copy: the three counts shrink together on a narrow
                // header instead of overflowing or truncating their labels.
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _Stat(
                          key: const ValueKey('reminders-stat-overdue'),
                          label: l10n.remindersOverdue,
                          count: overdueDisplay.length,
                          danger: true,
                        ),
                        const SizedBox(width: 16),
                        _Stat(
                          key: const ValueKey('reminders-stat-today'),
                          label: l10n.remindersToday,
                          count: todayDisplay.length,
                        ),
                        const SizedBox(width: 16),
                        _Stat(
                          key: const ValueKey('reminders-stat-week'),
                          label: l10n.remindersThisWeek,
                          count: weekDisplay.length,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: inset),
                // Each control keeps its natural width; when a longer
                // translation cannot share one line they stack instead of
                // squeezing the labels down.
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    AppSegmented<RemindersFilter>(
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
                      onChanged: (filter) => setState(() => _filter = filter),
                    ),
                    AppSegmented<RemindersMode>(
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
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: NotificationListener<ScrollNotification>(
                  onNotification: (_) {
                    _swipe.close();
                    return false;
                  },
                  child: content,
                ),
              ),
            ],
          );

          if (phone) return column;

          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!tablet || leftColumnOpen)
                RemindersLeftColumn(
                  onSelectDay: _locateDate,
                  recentlyCompleted: _recentlyCompleted,
                  animatingIds: _animatedIds,
                  onComplete: _complete,
                  onUndo: _undo,
                  defaultKind: _filter == RemindersFilter.plan
                      ? EventKind.plan
                      : EventKind.reminder,
                ),
              Expanded(child: column),
            ],
          );
        },
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

    int countEvents(List<DateTime> days) =>
        days.fold<int>(0, (sum, day) => sum + (eventsByDay[day]?.length ?? 0));

    void addExpansion(String key, List<DateTime> days, int count) {
      if (count <= 0 || !_expandedMonths.contains(key) || days.isEmpty) return;
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
      final count = countEvents(days);
      children.add(
        _monthSummary(
          keyString: 'remaining',
          label: l10n.restOfMonth,
          rangeLabel: AppFormats.dayRange(locale, days.first, days.last),
          count: count,
          palette: palette,
          l10n: l10n,
        ),
      );
      addExpansion('remaining', days, count);
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
      final expansionStart = _later(month, afterBand);
      final expansionDays = expansionStart.isBefore(monthEnd)
          ? _daysBetween(expansionStart, monthEnd)
          : const <DateTime>[];
      // The summary reflects the whole month, including days that already sit
      // in the band; only the expansion excludes those days to avoid repeats.
      final monthCount = countEvents(_daysBetween(month, monthEnd));
      final key = _monthKey(month);
      children.add(
        _monthSummary(
          keyString: key,
          label: AppFormats.monthTitle(locale, month),
          count: monthCount,
          palette: palette,
          l10n: l10n,
        ),
      );
      addExpansion(key, expansionDays, monthCount);
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
    required int count,
    required AppPalette palette,
    required AppLocalizations l10n,
    String? rangeLabel,
  }) {
    final expandable = count > 0;
    final expanded = expandable && _expandedMonths.contains(keyString);
    final labelColor = expandable ? palette.ink : palette.subWeak;

    return InkWell(
      key: ValueKey('month-summary-$keyString'),
      onTap: expandable ? () => _toggleMonth(keyString) : null,
      child: SizedBox(
        height: AppSizes.row,
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

  /// Strike-through title for a retained row: the line sweeps in over 200ms
  /// while the ink colour fades to `sub`. Reduce-motion paints the final
  /// state on the first frame.
  Widget _strikeTitle({
    required Event event,
    required TextStyle style,
    required Color endColor,
  }) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    Widget title(double progress) => StrikeThroughText(
      text: event.title,
      style: TextStyle.lerp(style, style.copyWith(color: endColor), progress)!,
      progress: progress,
    );
    if (reduceMotion) return title(1);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: _retainDuration,
      builder: (context, progress, _) => title(progress),
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
    // English date headers join date and weekday with the `·` separator;
    // Chinese writes `11月17日 周一` with a plain space.
    final showDotSeparator = locale.languageCode != 'zh';

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
                  if (showDotSeparator) ...[
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
                  if (showDotSeparator) ...[
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
                child: _touchRow(
                  event: event,
                  palette: palette,
                  l10n: l10n,
                  row: EventListRow(
                    key: ValueKey('date-row-${event.id}'),
                    event: event,
                    color: categoryMarkerColor(event.categoryId, categories),
                    showDate: false,
                    timeColor: isOverdueDay ? palette.danger : null,
                    timeSuffix: isOverdueDay ? l10n.remindersOverdue : null,
                    height: _rowHeight(context),
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
                Container(
                  key: ValueKey('reminders-group-dot-${group.id}'),
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: group.danger
                        ? palette.danger
                        : (group.color ?? kUncategorizedColor),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
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
              child: _touchRow(
                event: event,
                palette: palette,
                l10n: l10n,
                row: EventListRow(
                  key: ValueKey('reminders-row-${event.id}'),
                  event: event,
                  color: categoryMarkerColor(event.categoryId, categories),
                  showDate: true,
                  timeColor: group.danger ? palette.danger : null,
                  height: _rowHeight(context),
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
    this.color,
    this.danger = false,
  });

  final String id;
  final String title;
  final List<Event> events;
  final String? categoryId;

  /// Category colour for the group-header dot; null for 未分类.
  final Color? color;
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

/// Phone reminders header (`10-ui-refinement.md` §9.10): a 34/700 page title
/// with the overflow menu on the right. The menu holds the two secondary
/// destinations; new items enter through a group's ＋, the empty state and the
/// timeline, so the header stays quiet.
class _PhoneRemindersHeader extends StatelessWidget {
  const _PhoneRemindersHeader({
    required this.onManageCategories,
    required this.onViewCompleted,
    required this.onCreate,
  });

  final VoidCallback? onManageCategories;
  final VoidCallback onViewCompleted;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette =
        (theme.brightness == Brightness.light
                ? AppPalette.light
                : AppPalette.dark)
            .withAccent(theme.colorScheme.primary);
    final l10n = AppLocalizations.of(context);

    return SizedBox(
      key: const ValueKey('reminders-header'),
      height: 64,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Expanded(
              // One line at display size; scales down only when the title is
              // wider than the space beside the actions.
              child: FittedLabel(
                l10n.remindersTitle,
                key: const ValueKey('reminders-title'),
                alignment: Alignment.centerLeft,
                textAlign: TextAlign.left,
                style: AppTextStyles.display.copyWith(
                  fontSize: 34,
                  height: 41 / 34,
                  color: palette.ink,
                ),
              ),
            ),
            AppIconButton(
              key: const ValueKey('reminders-create'),
              tooltip: l10n.newItem,
              onPressed: onCreate,
              icon: Icon(LucideIcons.plus, size: 20, color: palette.sub),
            ),
            const SizedBox(width: 4),
            _PhoneOverflowMenu(
              onManageCategories: onManageCategories,
              onViewCompleted: onViewCompleted,
            ),
          ],
        ),
      ),
    );
  }
}

class _PhoneOverflowMenu extends StatefulWidget {
  const _PhoneOverflowMenu({
    required this.onManageCategories,
    required this.onViewCompleted,
  });

  final VoidCallback? onManageCategories;
  final VoidCallback onViewCompleted;

  @override
  State<_PhoneOverflowMenu> createState() => _PhoneOverflowMenuState();
}

class _PhoneOverflowMenuState extends State<_PhoneOverflowMenu> {
  final _anchorKey = GlobalKey();

  Future<void> _open(BuildContext context) async {
    final box = _anchorKey.currentContext?.findRenderObject();
    if (box is! RenderBox) return;
    final anchor = box.localToGlobal(Offset.zero) & box.size;
    final l10n = AppLocalizations.of(context);
    await showAppPopover<void>(
      context: context,
      anchor: anchor,
      tapRegionGroupId: _anchorKey,
      builder: (popoverContext) => _MenuPanel(
        items: [
          (l10n.viewCompletedShort, widget.onViewCompleted),
          (l10n.manageCategories, widget.onManageCategories),
        ],
      ),
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
    return TapRegion(
      groupId: _anchorKey,
      child: KeyedSubtree(
        key: const ValueKey('reminders-more'),
        child: AppIconButton(
          key: _anchorKey,
          tooltip: AppLocalizations.of(context).moreActions,
          onPressed: () => _open(context),
          icon: Icon(LucideIcons.ellipsis, size: 20, color: palette.sub),
        ),
      ),
    );
  }
}

class _MenuPanel extends StatelessWidget {
  const _MenuPanel({required this.items});

  final List<(String, VoidCallback?)> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette =
        (theme.brightness == Brightness.light
                ? AppPalette.light
                : AppPalette.dark)
            .withAccent(theme.colorScheme.primary);
    return Container(
      width: 200,
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: palette.line),
        boxShadow: kCardShadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (label, action) in items)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                AppPopoverScope.closeWith(context);
                action?.call();
              },
              child: Container(
                height: 36,
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  label,
                  style: AppTextStyles.body.copyWith(color: palette.ink),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

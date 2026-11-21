import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/l10n/generated/app_localizations.dart';
import '../../core/layout.dart';
import '../../core/theme/app_tokens.dart';
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

/// Sidebar width from `docs/design/10-ui-refinement.md` §9.12.
const double _sidebarWidth = 300;

/// Single-row header height (§9.12). Not a list row, so it is a file-local
/// value rather than an [AppSizes] tier.
const double _headerHeight = 60;

/// Group title row from §9.12.
const double _groupHeaderHeight = 34;

/// Gap between the plans and reminders groups.
const double _groupGap = 16;

/// Sidebar row padding matches [EventListRow]'s own 16px inset.
const double _rowPadding = 16;

/// The completion hit target is 24×24 even though its glyph is 14.
const double _checkHitSize = 24;

/// 300px selected-day sidebar on the right of the calendar
/// (`docs/design/10-ui-refinement.md` §9.12): a single-row date header with the
/// completed-list chip, the day's unfinished items grouped plans-first, and a
/// bottom add row.
class CalendarSidebar extends ConsumerStatefulWidget {
  const CalendarSidebar({super.key, this.retainCompletions, this.swipeActions});

  /// Overrides the touch defaults (tablet retains and swipes); desktop keeps
  /// both off unless a caller opts in.
  final bool? retainCompletions;
  final bool? swipeActions;

  @override
  ConsumerState<CalendarSidebar> createState() => _CalendarSidebarState();
}

class _CalendarSidebarState extends ConsumerState<CalendarSidebar> {
  final Map<String, Event> _recentlyCompleted = <String, Event>{};
  final Set<String> _animatedIds = <String>{};
  final SwipeActionsController _swipe = SwipeActionsController();

  // Captured once: a completion write can outlive the row's 120ms fade, and
  // `ref` must not be used after the widget is deactivated.
  late final EventRepository _repo;
  late final EventNotifierSync _sync;

  /// Resolved lazily: only the swipe-delete path needs the notification
  /// service, and tests that never delete do not override it.
  late final NotificationScheduler _scheduler = ref.read(
    notificationSchedulerProvider,
  );

  bool get _tablet => resolveAppLayout(context) == AppLayout.tablet;
  bool get _retain => widget.retainCompletions ?? _tablet;
  bool get _swipeEnabled => widget.swipeActions ?? _tablet;

  @override
  void initState() {
    super.initState();
    _repo = ref.read(eventRepositoryProvider);
    _sync = ref.read(eventNotifierSyncProvider);
  }

  @override
  void dispose() {
    _recentlyCompleted.clear();
    _swipe.dispose();
    super.dispose();
  }

  Future<void> _complete(Event event) async {
    await _repo.setCompleted(event.id, true);
    final snapshot = event.copyWith(
      isCompleted: true,
      completedAt: Value(DateTime.now()),
    );
    if (mounted && _retain) {
      setState(() => _recentlyCompleted[event.id] = snapshot);
    }
    _sync.afterCompletion(snapshot);
  }

  Future<void> _undo(Event event) async {
    await _repo.setCompleted(event.id, false);
    if (mounted) {
      setState(() {
        _recentlyCompleted.remove(event.id);
        _animatedIds.remove(event.id);
      });
    }
    _sync.afterUpdate(
      event.copyWith(
        isCompleted: false,
        completedAt: const Value(null),
        updatedAt: DateTime.now(),
      ),
    );
  }

  /// The repository's day order: start minute (all-day last), then id.
  int _byStartThenId(Event a, Event b) {
    final am = a.startMinute;
    final bm = b.startMinute;
    if (am == null && bm == null) return a.id.compareTo(b.id);
    if (am == null) return 1;
    if (bm == null) return -1;
    final byStart = am.compareTo(bm);
    return byStart != 0 ? byStart : a.id.compareTo(b.id);
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
    await _scheduler.cancelEvent(event);
    await _repo.hardDelete(event.id);
    if (mounted) {
      setState(() => _recentlyCompleted.remove(event.id));
    }
  }

  Widget _rowFor(
    Event event, {
    required List<Category> categories,
    required AppPalette palette,
    required AppLocalizations l10n,
  }) {
    final retained = _recentlyCompleted.containsKey(event.id);
    final row = _SidebarRow(
      key: ValueKey('sidebar-row-${event.id}'),
      event: event,
      color: categoryMarkerColor(event.categoryId, categories),
      retained: retained,
      retainOnComplete: _retain,
      onComplete: () => _complete(event),
      onUndo: () => _undo(event),
    );
    if (!_swipeEnabled) return row;
    return SwipeActionsRow(
      id: event.id,
      controller: _swipe,
      enabled: !retained,
      actions: [
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
      ],
      child: row,
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = _paletteOf(context);
    final locale = Localizations.localeOf(context);
    final l10n = AppLocalizations.of(context);
    final day = ref.watch(selectedDayProvider);
    final events =
        ref.watch(eventsForDayProvider(day)).value ?? const <Event>[];
    final categories =
        ref.watch(allCategoriesProvider).value ?? const <Category>[];

    // Completed items leave the sidebar silently on desktop. On the tablet
    // they retain (D70) through a snapshot, merged back at their start-time
    // slot and scoped to the selected day. A snapshot whose id is live again
    // (restored from the completed page) must not duplicate the row.
    final dayKey = dateOnly(day);
    final liveIds = {for (final event in events) event.id};
    final visible = <Event>[
      ...events.where((event) => !event.isCompleted),
      ..._recentlyCompleted.values.where(
        (event) =>
            dateOnly(event.date) == dayKey && !liveIds.contains(event.id),
      ),
    ]..sort(_byStartThenId);
    final plans = visible.where((event) => event.kind == 'plan').toList();
    final reminders = visible.where((event) => event.kind != 'plan').toList();

    return Container(
      width: _sidebarWidth,
      decoration: BoxDecoration(
        color: palette.side,
        border: Border(left: BorderSide(color: palette.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            key: const ValueKey('sidebar-header'),
            height: _headerHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: _rowPadding),
              child: Row(
                children: [
                  // Compact typography fits the 300px header in both locales;
                  // scaleDown is a no-clip fallback for unusually wide fonts
                  // (e.g. the default test font), never in the desktop build.
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _dateLabel(locale, day),
                              maxLines: 1,
                              style: AppTextStyles.headline.copyWith(
                                color: palette.ink,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              AppFormats.weekday(locale, day),
                              maxLines: 1,
                              style: AppTextStyles.secondary.copyWith(
                                color: palette.sub,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _CompletedChip(
                    key: const ValueKey('sidebar-completed-link'),
                    label: l10n.completedChip,
                    onTap: () => context.go('/calendar/completed'),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: visible.isEmpty
                ? _EmptyState(palette: palette)
                : ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      if (plans.isNotEmpty)
                        _SidebarGroup(
                          key: const ValueKey('sidebar-group-plan'),
                          titleKey: const ValueKey('sidebar-group-title-plan'),
                          title: l10n.plansGroupTitle,
                          count: plans.length,
                          palette: palette,
                          children: [
                            for (final event in plans)
                              _rowFor(
                                event,
                                categories: categories,
                                palette: palette,
                                l10n: l10n,
                              ),
                          ],
                        ),
                      if (plans.isNotEmpty && reminders.isNotEmpty)
                        const SizedBox(height: _groupGap),
                      if (reminders.isNotEmpty)
                        _SidebarGroup(
                          key: const ValueKey('sidebar-group-reminder'),
                          titleKey: const ValueKey(
                            'sidebar-group-title-reminder',
                          ),
                          title: l10n.remindersGroupTitle,
                          count: reminders.length,
                          palette: palette,
                          children: [
                            for (final event in reminders)
                              _rowFor(
                                event,
                                categories: categories,
                                palette: palette,
                                l10n: l10n,
                              ),
                          ],
                        ),
                    ],
                  ),
          ),
          Container(height: 1, color: palette.line),
          SizedBox(
            height: AppSizes.row,
            child: TextButton(
              key: const ValueKey('sidebar-add'),
              onPressed: () => showEventEditor(context, date: day),
              style: TextButton.styleFrom(
                alignment: Alignment.centerLeft,
                foregroundColor: palette.accent,
                textStyle: AppTextStyles.body,
                padding: const EdgeInsets.symmetric(horizontal: _rowPadding),
                minimumSize: Size.zero,
                shape: const RoundedRectangleBorder(),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                l10n.addReminderOrPlan,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Chinese keeps the short month/day form; English uses the year-bearing
/// `Nov 17, 2026` from `docs/design/10-ui-refinement.md` §9.12.
String _dateLabel(Locale locale, DateTime day) => locale.languageCode == 'zh'
    ? AppFormats.monthDay(locale, day)
    : AppFormats.dayTitle(locale, day);

class _CompletedChip extends StatefulWidget {
  const _CompletedChip({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  State<_CompletedChip> createState() => _CompletedChipState();
}

class _CompletedChipState extends State<_CompletedChip> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final palette = _paletteOf(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Container(
          height: 26,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: _hovering ? palette.hover : palette.chip,
            borderRadius: BorderRadius.circular(AppRadii.chip),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.label,
                maxLines: 1,
                style: AppTextStyles.secondary.copyWith(color: palette.accent),
              ),
              const SizedBox(width: 4),
              Icon(LucideIcons.chevronRight, size: 12, color: palette.accent),
            ],
          ),
        ),
      ),
    );
  }
}

class _SidebarGroup extends StatelessWidget {
  const _SidebarGroup({
    super.key,
    required this.titleKey,
    required this.title,
    required this.count,
    required this.palette,
    required this.children,
  });

  final Key titleKey;
  final String title;
  final int count;
  final AppPalette palette;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          key: titleKey,
          height: _groupHeaderHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: _rowPadding),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  title,
                  style: AppTextStyles.section.copyWith(color: palette.ink),
                ),
                const SizedBox(width: 8),
                Text(
                  '$count',
                  style: AppTextStyles.caption.copyWith(
                    color: palette.subMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
        ...children,
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.palette});

  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(_rowPadding, 16, _rowPadding, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.sidebarEmptyTitle,
            style: AppTextStyles.rowTitle.copyWith(color: palette.sub),
          ),
          const SizedBox(height: 2),
          Text(
            l10n.sidebarEmptyHint,
            style: AppTextStyles.body.copyWith(color: palette.subWeak),
          ),
        ],
      ),
    );
  }
}

class _SidebarRow extends StatefulWidget {
  const _SidebarRow({
    super.key,
    required this.event,
    required this.color,
    required this.retained,
    required this.retainOnComplete,
    required this.onComplete,
    required this.onUndo,
  });

  final Event event;
  final Color color;

  /// Retained (D70) rows stay visible with a strike and undo instead of
  /// fading away.
  final bool retained;

  /// Whether this surface retains completions at all (tablet). Captured from
  /// the layout so the row knows before its widget config rebuilds.
  final bool retainOnComplete;

  /// The sidebar owns the write so it can capture its repository before the
  /// fade; the row only runs the 120ms fade and then awaits this.
  final Future<void> Function() onComplete;

  final Future<void> Function() onUndo;

  @override
  State<_SidebarRow> createState() => _SidebarRowState();
}

class _SidebarRowState extends State<_SidebarRow> {
  bool _completing = false;

  Future<void> _complete() async {
    if (_completing) return;
    if (widget.retained) {
      await widget.onUndo();
      return;
    }
    // The retained row keeps its position, so it does not fade; the parent
    // swaps in the struck snapshot on the next frame.
    if (widget.retainOnComplete) {
      await widget.onComplete();
      return;
    }
    setState(() => _completing = true);
    await Future<void>.delayed(const Duration(milliseconds: 120));
    await widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    return AnimatedOpacity(
      opacity: _completing && !widget.retained ? 0.35 : 1,
      duration: const Duration(milliseconds: 120),
      child: Stack(
        children: [
          EventListRow(
            event: event,
            color: widget.color,
            showDate: false,
            onTap: widget.retained
                ? null
                : () => showEventEditor(context, existing: event),
            onToggleComplete: _complete,
          ),
          // EventListRow owns the check circle but not a per-event key; this
          // transparent 24px target keeps `sidebar-complete-<id>` tappable
          // for the completion flow and its tests.
          Positioned(
            left: _rowPadding,
            top: (AppSizes.row - _checkHitSize) / 2,
            width: _checkHitSize,
            height: _checkHitSize,
            child: GestureDetector(
              key: ValueKey('sidebar-complete-${event.id}'),
              behavior: HitTestBehavior.opaque,
              onTap: _complete,
            ),
          ),
        ],
      ),
    );
  }
}

AppPalette _paletteOf(BuildContext context) {
  final theme = Theme.of(context);
  return (theme.brightness == Brightness.light
          ? AppPalette.light
          : AppPalette.dark)
      .withAccent(theme.colorScheme.primary);
}

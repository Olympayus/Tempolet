import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/l10n/generated/app_localizations.dart';
import '../../core/layout.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/ui/app_buttons.dart';
import '../../core/utils/dates.dart';
import '../../core/utils/formats.dart';
import '../../data/database/database.dart';
import '../../data/repositories/category_repository.dart';
import '../../data/repositories/event_repository.dart';
import '../../notifications/notification_scheduler.dart';
import '../calendar/calendar_state.dart';
import '../calendar/category_marker.dart';
import '../events/event_list_row.dart';

/// Page content inset (`10-ui-refinement.md` §9.5). Rows carry their own 16px
/// internal padding, so the list adds an 8px outer inset to align row content
/// with the 24px page inset.
const double _rowOuterInset = 8;

/// Vertical rhythm between completed-day groups.
const double _groupGap = 28;

/// Gap between a group title and its first row.
const double _groupTitleGap = 8;

/// Extra bottom padding that keeps the last row clear of the floating
/// selection bar.
const double _selectionBarClearance = 96;

/// Completed-events page (`docs/design/04-reminders.md` §4,
/// `docs/superpowers/specs/2026-11-16-tempolet-v0.1.3-design.md` §7.5): the
/// only place completed items live after they silently leave every main view.
///
/// Groups by completion day, restores or permanently deletes rows, clears the
/// list behind a confirmation, and (new in v0.1.3) layers a multi-select mode
/// over the same list: long-press a row or press 选择, then act on the
/// selection with 全选 / 全部取消 / 恢复 / 删除. Esc or the header's 完成
/// leaves the mode and clears the selection.
class CompletedPage extends ConsumerStatefulWidget {
  const CompletedPage({super.key});

  @override
  ConsumerState<CompletedPage> createState() => _CompletedPageState();
}

class _CompletedPageState extends ConsumerState<CompletedPage> {
  final Set<String> _selected = <String>{};
  bool _selecting = false;

  void _enterSelection([String? id]) {
    setState(() {
      _selecting = true;
      _selected.clear();
      if (id != null) _selected.add(id);
    });
  }

  void _exitSelection() {
    if (!_selecting && _selected.isEmpty) return;
    setState(() {
      _selecting = false;
      _selected.clear();
    });
  }

  void _toggleSelected(String id) {
    setState(() {
      if (!_selected.remove(id)) _selected.add(id);
    });
  }

  void _selectAll(Iterable<String> ids) {
    setState(() {
      _selected
        ..clear()
        ..addAll(ids);
    });
  }

  /// 全部取消: empties the selection but stays in select mode, so the bar and
  /// the counters stay put while the user starts a new selection.
  void _deselectAll() {
    setState(_selected.clear);
  }

  /// Esc exits multi-select (`v0.1.4` task 6). The page has no text field, so
  /// the body-level [Focus] always owns the key unless a row's checkbox is
  /// focused; either way the event bubbles to it.
  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape &&
        _selecting) {
      _exitSelection();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Future<void> _restoreOne(Event event) async {
    await ref.read(eventRepositoryProvider).setCompleted(event.id, false);
    ref
        .read(eventNotifierSyncProvider)
        .afterUpdate(
          event.copyWith(isCompleted: false, completedAt: const Value(null)),
        );
  }

  Future<void> _deleteOne(Event event) async {
    final l10n = AppLocalizations.of(context);
    if (!await _confirmDelete(context, l10n)) return;
    await ref.read(notificationSchedulerProvider).cancelEvent(event);
    await ref.read(eventRepositoryProvider).hardDelete(event.id);
  }

  Future<void> _restoreSelected(List<Event> targets) async {
    final repo = ref.read(eventRepositoryProvider);
    final sync = ref.read(eventNotifierSyncProvider);
    for (final event in targets) {
      await repo.setCompleted(event.id, false);
      sync.afterUpdate(
        event.copyWith(isCompleted: false, completedAt: const Value(null)),
      );
    }
    if (!mounted) return;
    _exitSelection();
  }

  Future<void> _deleteSelected(List<Event> targets) async {
    final l10n = AppLocalizations.of(context);
    if (!await _confirmDelete(context, l10n)) return;
    final scheduler = ref.read(notificationSchedulerProvider);
    final repo = ref.read(eventRepositoryProvider);
    for (final event in targets) {
      await scheduler.cancelEvent(event);
      await repo.hardDelete(event.id);
    }
    if (!mounted) return;
    _exitSelection();
  }

  Future<void> _clearAll(List<Event> events) async {
    final l10n = AppLocalizations.of(context);
    if (!await _confirmDelete(context, l10n)) return;
    final scheduler = ref.read(notificationSchedulerProvider);
    for (final event in events) {
      await scheduler.cancelEvent(event);
    }
    await ref.read(eventRepositoryProvider).clearCompleted();
  }

  /// Returns to the entry branch: the page is mounted under both
  /// `/calendar/completed` and `/reminders/completed` (spec §7.3).
  void _back(BuildContext context) {
    if (context.canPop()) {
      context.pop();
      return;
    }
    final path = GoRouterState.of(context).uri.path;
    context.go(path.startsWith('/reminders') ? '/reminders' : '/calendar');
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
    final layout = resolveAppLayout(context);
    final phone = layout == AppLayout.phone;
    final events = ref.watch(completedEventsProvider).value ?? const <Event>[];
    final categories =
        ref.watch(allCategoriesProvider).value ?? const <Category>[];

    final today = dateOnly(ref.watch(todayProvider));
    final yesterday = DateTime(today.year, today.month, today.day - 1);
    final todayItems = <Event>[];
    final yesterdayItems = <Event>[];
    final earlierItems = <Event>[];
    for (final event in events) {
      final at = event.completedAt;
      if (at == null) continue;
      final day = dateOnly(at);
      if (day == today) {
        todayItems.add(event);
      } else if (day == yesterday) {
        yesterdayItems.add(event);
      } else {
        earlierItems.add(event);
      }
    }
    final groups = [
      (label: l10n.todayGroup, items: todayItems),
      (label: l10n.yesterdayGroup, items: yesterdayItems),
      (label: l10n.earlierGroup, items: earlierItems),
    ].where((group) => group.items.isNotEmpty).toList();
    final displayedIds = {
      for (final group in groups)
        for (final event in group.items) event.id,
    };
    final selected = _selected.where(displayedIds.contains).toSet();
    final selectedEventList = [
      for (final group in groups)
        for (final event in group.items)
          if (selected.contains(event.id)) event,
    ];

    Widget rowFor(Event event) {
      final at = event.completedAt;
      // Intentional locale-aware join: Chinese writes `11月16日 09:00`, while
      // English uses the `·` date/time separator (no comma) per the v0.1.3
      // separator ruling.
      final separator = locale.languageCode == 'zh' ? ' ' : ' · ';
      final kindLabel = event.kind == 'plan'
          ? l10n.kindPlan
          : l10n.kindReminder;
      final ownTime = AppFormats.timeRange(event.startMinute, event.endMinute);
      final ownDate = AppFormats.monthDay(locale, event.date);
      // Every row says what the item was and when it was scheduled, then when
      // it was completed (`10-ui-refinement` §9.5).
      final ownSchedule = ownTime.isEmpty
          ? '$kindLabel · $ownDate'
          : '$kindLabel · $ownDate$separator$ownTime';
      final completionLabel = at == null
          ? ''
          : l10n.completedAt(
              AppFormats.monthDay(locale, at),
              formatMinuteOfDay(at.hour * 60 + at.minute),
            );
      return Padding(
        key: ValueKey('completed-row-${event.id}'),
        padding: const EdgeInsets.symmetric(horizontal: _rowOuterInset),
        child: EventListRow(
          event: event,
          height: phone ? 52 : AppSizes.row,
          color: categoryMarkerColor(event.categoryId, categories),
          titleColor: palette.sub,
          metadata: phone
              ? null
              : Text(
                  ownSchedule,
                  style: AppTextStyles.caption.copyWith(color: palette.sub),
                ),
          timeLabel: phone
              ? (at == null ? '' : formatMinuteOfDay(at.hour * 60 + at.minute))
              : completionLabel,
          selectionChecked: _selecting ? selected.contains(event.id) : null,
          onToggleSelection: _selecting
              ? () => _toggleSelected(event.id)
              : null,
          onTap: _selecting ? () => _toggleSelected(event.id) : null,
          onLongPress: _selecting ? null : () => _enterSelection(event.id),
          trailing: _selecting
              ? null
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppIconButton(
                      key: ValueKey('completed-restore-${event.id}'),
                      tooltip: l10n.restore,
                      onPressed: () => _restoreOne(event),
                      icon: Icon(
                        LucideIcons.rotateCcw,
                        size: 15,
                        color: palette.accent,
                      ),
                    ),
                    const SizedBox(width: 2),
                    AppIconButton(
                      key: ValueKey('completed-delete-${event.id}'),
                      tooltip: l10n.delete,
                      onPressed: () => _deleteOne(event),
                      icon: Icon(
                        LucideIcons.trash2,
                        size: 14,
                        color: palette.sub,
                      ),
                    ),
                  ],
                ),
        ),
      );
    }

    return Scaffold(
      key: const ValueKey('completed-page'),
      backgroundColor: palette.bg,
      body: Focus(
        autofocus: true,
        onKeyEvent: _handleKey,
        child: Stack(
          children: [
            Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                key: const ValueKey('completed-content'),
                constraints: BoxConstraints(
                  maxWidth: layout == AppLayout.tablet ? 760 : double.infinity,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: AppSizes.header,
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: phone ? 16 : 24,
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              key: const ValueKey('completed-back'),
                              onPressed: () => _back(context),
                              icon: const Icon(
                                LucideIcons.chevronLeft,
                                size: 16,
                              ),
                              color: palette.sub,
                              padding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                              constraints: const BoxConstraints.tightFor(
                                width: AppSizes.control,
                                height: AppSizes.control,
                              ),
                              style: IconButton.styleFrom(
                                backgroundColor: palette.chip,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppRadii.button,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                l10n.completedTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.display.copyWith(
                                  fontSize: phone ? 34 : 28,
                                  color: palette.ink,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            if (_selecting) ...[
                              Text(
                                l10n.selectedCount(selected.length),
                                key: const ValueKey('completed-selected-count'),
                                style: AppTextStyles.body.copyWith(
                                  color: palette.sub,
                                ),
                              ),
                              const SizedBox(width: 12),
                              _HeaderAction(
                                key: const ValueKey('completed-select-done'),
                                label: l10n.done,
                                color: palette.accent,
                                onPressed: _exitSelection,
                              ),
                            ] else ...[
                              _HeaderAction(
                                key: const ValueKey('completed-select'),
                                label: l10n.select,
                                color: palette.sub,
                                onPressed: events.isEmpty
                                    ? null
                                    : () => _enterSelection(),
                              ),
                              const SizedBox(width: 8),
                              _HeaderAction(
                                key: const ValueKey('completed-clear'),
                                label: l10n.clear,
                                color: palette.danger,
                                onPressed: events.isEmpty
                                    ? null
                                    : () => _clearAll(events),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: events.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                              child: Align(
                                alignment: Alignment.topLeft,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      l10n.completedEmptyTitle,
                                      key: const ValueKey(
                                        'completed-empty-title',
                                      ),
                                      style: AppTextStyles.rowTitle.copyWith(
                                        color: palette.sub,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      l10n.completedEmptyHint,
                                      key: const ValueKey(
                                        'completed-empty-hint',
                                      ),
                                      style: AppTextStyles.body.copyWith(
                                        color: palette.subWeak,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : ListView(
                              key: const ValueKey('completed-list'),
                              padding: EdgeInsets.fromLTRB(
                                16,
                                24,
                                16,
                                _selecting ? _selectionBarClearance : 24,
                              ),
                              children: [
                                for (var i = 0; i < groups.length; i++) ...[
                                  if (i > 0) const SizedBox(height: _groupGap),
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      _rowOuterInset,
                                      0,
                                      _rowOuterInset,
                                      _groupTitleGap,
                                    ),
                                    child: Row(
                                      children: [
                                        Text(
                                          groups[i].label,
                                          style: AppTextStyles.section.copyWith(
                                            color: palette.ink,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          l10n.itemsCount(
                                            groups[i].items.length,
                                          ),
                                          style: AppTextStyles.caption.copyWith(
                                            color: palette.sub,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  for (final event in groups[i].items)
                                    rowFor(event),
                                ],
                              ],
                            ),
                    ),
                  ],
                ),
              ),
            ),
            if (_selecting)
              Positioned(
                left: 0,
                right: 0,
                bottom: 24,
                child: Center(
                  child: Container(
                    key: const ValueKey('completed-selection-bar'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: palette.card,
                      border: Border.all(color: palette.line),
                      borderRadius: BorderRadius.circular(AppRadii.card),
                      boxShadow: kCardShadow,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _SelectionAction(
                          key: const ValueKey('completed-select-all'),
                          label: l10n.selectAll,
                          color: palette.ink,
                          onPressed:
                              displayedIds.isEmpty ||
                                  selected.length == displayedIds.length
                              ? null
                              : () => _selectAll(displayedIds),
                        ),
                        const SizedBox(width: 4),
                        _SelectionAction(
                          key: const ValueKey('completed-clear-selection'),
                          label: l10n.deselectAll,
                          color: palette.ink,
                          onPressed: selected.isEmpty ? null : _deselectAll,
                        ),
                        const SizedBox(width: 4),
                        _SelectionAction(
                          key: const ValueKey('completed-batch-restore'),
                          label: l10n.restore,
                          color: palette.accent,
                          onPressed: selectedEventList.isEmpty
                              ? null
                              : () => _restoreSelected(selectedEventList),
                        ),
                        const SizedBox(width: 4),
                        _SelectionAction(
                          key: const ValueKey('completed-batch-delete'),
                          label: l10n.delete,
                          color: palette.danger,
                          onPressed: selectedEventList.isEmpty
                              ? null
                              : () => _deleteSelected(selectedEventList),
                        ),
                      ],
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

/// "Delete forever" confirmation shared by row deletes, batch deletes and
/// clear.
Future<bool> _confirmDelete(BuildContext context, AppLocalizations l10n) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      key: const ValueKey('completed-confirm'),
      content: Text(l10n.deleteForeverHint),
      actions: [
        TextButton(
          key: const ValueKey('completed-confirm-cancel'),
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(l10n.cancel),
        ),
        TextButton(
          key: const ValueKey('completed-confirm-delete'),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(dialogContext).colorScheme.error,
          ),
          child: Text(l10n.delete),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

/// Bare 13px header action (选择 / 清空 / 完成) with a 30px hit area.
class _HeaderAction extends StatelessWidget {
  const _HeaderAction({
    super.key,
    required this.label,
    required this.color,
    this.onPressed,
  });

  final String label;
  final Color color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final palette = _paletteOf(context);
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: color,
        disabledForegroundColor: palette.subMuted,
        textStyle: AppTextStyles.body,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        minimumSize: const Size(0, AppSizes.control),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(label),
    );
  }
}

/// One label in the floating multi-select bar.
class _SelectionAction extends StatefulWidget {
  const _SelectionAction({
    super.key,
    required this.label,
    required this.color,
    this.onPressed,
  });

  final String label;
  final Color color;
  final VoidCallback? onPressed;

  @override
  State<_SelectionAction> createState() => _SelectionActionState();
}

class _SelectionActionState extends State<_SelectionAction> {
  bool _hovering = false;

  void _setHovering(bool hovering) {
    if (_hovering == hovering) return;
    setState(() => _hovering = hovering);
  }

  @override
  Widget build(BuildContext context) {
    final palette = _paletteOf(context);
    final enabled = widget.onPressed != null;
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: enabled ? (_) => _setHovering(true) : null,
      onExit: enabled ? (_) => _setHovering(false) : null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onPressed,
        child: Container(
          height: AppSizes.control,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _hovering && enabled ? palette.hover : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadii.button),
          ),
          child: Text(
            widget.label,
            style: AppTextStyles.body.copyWith(
              color: enabled ? widget.color : palette.subMuted,
            ),
          ),
        ),
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

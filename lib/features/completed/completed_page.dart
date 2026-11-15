import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/l10n/generated/app_localizations.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/dates.dart';
import '../../data/database/database.dart';
import '../../data/repositories/category_repository.dart';
import '../../data/repositories/event_repository.dart';
import '../../notifications/notification_scheduler.dart';
import '../calendar/category_marker.dart';

/// Completed-events page (`docs/design/04-reminders.md` §4): the only place
/// completed items live after they silently leave every main view. Groups by
/// completion day, restores or permanently deletes rows, and clears the list
/// behind a confirmation.
class CompletedPage extends ConsumerWidget {
  const CompletedPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final palette =
        (theme.brightness == Brightness.light
                ? AppPalette.light
                : AppPalette.dark)
            .withAccent(theme.colorScheme.primary);
    final l10n = AppLocalizations.of(context);
    final events = ref.watch(completedEventsProvider).value ?? const <Event>[];
    final categories =
        ref.watch(allCategoriesProvider).value ?? const <Category>[];
    final repo = ref.read(eventRepositoryProvider);
    final sync = ref.read(eventNotifierSyncProvider);
    final scheduler = ref.read(notificationSchedulerProvider);

    final today = dateOnly(DateTime.now());
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

    Future<void> restore(Event event) async {
      await repo.setCompleted(event.id, false);
      sync.afterUpdate(
        event.copyWith(isCompleted: false, completedAt: const Value(null)),
      );
    }

    Future<void> deleteOne(Event event) async {
      if (!await _confirmDelete(context, l10n)) return;
      await scheduler.cancelEvent(event);
      await repo.hardDelete(event.id);
    }

    Future<void> clearAll() async {
      if (!await _confirmDelete(context, l10n)) return;
      for (final event in events) {
        await scheduler.cancelEvent(event);
      }
      await repo.clearCompleted();
    }

    return Scaffold(
      key: const ValueKey('completed-page'),
      backgroundColor: palette.bg,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
            child: Row(
              children: [
                IconButton(
                  key: const ValueKey('completed-back'),
                  onPressed: () => context.go('/calendar'),
                  icon: const Icon(LucideIcons.chevronLeft, size: 16),
                  color: palette.sub,
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints.tightFor(
                    width: 28,
                    height: 28,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: palette.chip,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadii.button),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  l10n.completedTitle,
                  style: AppTextStyles.title.copyWith(color: palette.ink),
                ),
                const Spacer(),
                TextButton(
                  key: const ValueKey('completed-clear'),
                  onPressed: events.isEmpty ? null : clearAll,
                  style: TextButton.styleFrom(
                    foregroundColor: palette.danger,
                    disabledForegroundColor: palette.subWeak,
                    textStyle: AppTextStyles.secondary,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 26),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(l10n.clear),
                ),
              ],
            ),
          ),
          Expanded(
            child: events.isEmpty
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: Text(
                        l10n.noEvents,
                        style: AppTextStyles.secondary.copyWith(
                          color: palette.subWeak,
                        ),
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(20, 2, 20, 20),
                    children: [
                      for (final group in groups) ...[
                        Padding(
                          padding: const EdgeInsets.only(top: 14, bottom: 5),
                          child: Text(
                            group.label,
                            style: AppTextStyles.caption.copyWith(
                              color: palette.sub,
                            ),
                          ),
                        ),
                        Container(height: 1, color: palette.line),
                        for (final event in group.items)
                          _CompletedRow(
                            key: ValueKey(event.id),
                            event: event,
                            color: categoryMarkerColor(
                              event.categoryId,
                              categories,
                            ),
                            onRestore: () => restore(event),
                            onDelete: () => deleteOne(event),
                          ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

/// "Delete forever" confirmation shared by row deletes and clear.
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

class _CompletedRow extends StatelessWidget {
  const _CompletedRow({
    super.key,
    required this.event,
    required this.color,
    required this.onRestore,
    required this.onDelete,
  });

  final Event event;
  final Color color;
  final VoidCallback onRestore;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette =
        (theme.brightness == Brightness.light
                ? AppPalette.light
                : AppPalette.dark)
            .withAccent(theme.colorScheme.primary);
    final l10n = AppLocalizations.of(context);
    final at = event.completedAt;
    final time = at == null ? '' : formatMinuteOfDay(at.hour * 60 + at.minute);

    return SizedBox(
      height: 30,
      child: Row(
        children: [
          CategoryMarker(kind: event.kind, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              event.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.body.copyWith(
                color: palette.sub,
                decoration: TextDecoration.lineThrough,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            event.kind == 'plan' ? l10n.kindPlan : l10n.kindReminder,
            style: AppTextStyles.caption.copyWith(color: palette.sub),
          ),
          const SizedBox(width: 8),
          Text(time, style: AppTextStyles.caption.copyWith(color: palette.sub)),
          const SizedBox(width: 2),
          TextButton(
            key: ValueKey('completed-restore-${event.id}'),
            onPressed: onRestore,
            style: TextButton.styleFrom(
              foregroundColor: palette.accent,
              textStyle: AppTextStyles.caption,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 26),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(l10n.restore),
          ),
          IconButton(
            key: ValueKey('completed-delete-${event.id}'),
            onPressed: onDelete,
            icon: const Icon(LucideIcons.trash2, size: 14),
            color: palette.danger,
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints.tightFor(width: 26, height: 26),
          ),
        ],
      ),
    );
  }
}

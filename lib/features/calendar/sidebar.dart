import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/l10n/generated/app_localizations.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/formats.dart';
import '../../data/database/database.dart';
import '../../data/repositories/category_repository.dart';
import '../../data/repositories/event_repository.dart';
import '../../notifications/notification_scheduler.dart';
import '../events/event_editor_sheet.dart';
import 'calendar_state.dart';
import 'category_marker.dart';

/// 280px selected-day sidebar on the right of the calendar
/// (`docs/design/02-shell-desktop.md` §5.1): the day's unfinished items with
/// inline completion, an editor entry per row, the completed-list link in the
/// header and a bottom add button.
class CalendarSidebar extends ConsumerWidget {
  const CalendarSidebar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final palette =
        (theme.brightness == Brightness.light
                ? AppPalette.light
                : AppPalette.dark)
            .withAccent(theme.colorScheme.primary);
    final locale = Localizations.localeOf(context);
    final l10n = AppLocalizations.of(context);
    final day = ref.watch(selectedDayProvider);
    final events =
        ref.watch(eventsForDayProvider(day)).value ?? const <Event>[];
    final categories =
        ref.watch(allCategoriesProvider).value ?? const <Category>[];
    // Completed items leave the sidebar silently, like every other surface.
    final pending = events.where((event) => !event.isCompleted).toList();
    // Captured while building, before any 120ms fade, so a mid-fade dismissal
    // can neither lose the write nor touch `ref` after disposal.
    final repo = ref.read(eventRepositoryProvider);
    final sync = ref.read(eventNotifierSyncProvider);

    return Container(
      width: 280,
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: palette.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${AppFormats.monthDay(locale, day)} '
                    '${AppFormats.weekday(locale, day)} · '
                    '${l10n.itemsCount(pending.length)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.secondary.copyWith(color: palette.ink),
                  ),
                ),
                const SizedBox(width: 4),
                TextButton(
                  key: const ValueKey('sidebar-completed-link'),
                  onPressed: () => context.go('/calendar/completed'),
                  style: TextButton.styleFrom(
                    foregroundColor: palette.sub,
                    textStyle: AppTextStyles.caption,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    minimumSize: const Size(0, 24),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    l10n.viewCompleted,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Container(height: 1, color: palette.line),
          Expanded(
            child: pending.isEmpty
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Text(
                      l10n.noSchedule,
                      style: AppTextStyles.secondary.copyWith(
                        color: palette.subWeak,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: pending.length,
                    itemBuilder: (context, index) {
                      final event = pending[index];
                      return _SidebarRow(
                        key: ValueKey(event.id),
                        event: event,
                        color: categoryMarkerColor(
                          event.categoryId,
                          categories,
                        ),
                        onComplete: () async {
                          await repo.setCompleted(event.id, true);
                          sync.afterCompletion(
                            event.copyWith(isCompleted: true),
                          );
                        },
                      );
                    },
                  ),
          ),
          Container(height: 1, color: palette.line),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 10),
            child: TextButton(
              key: const ValueKey('sidebar-add'),
              onPressed: () => showEventEditor(context, date: day),
              style: TextButton.styleFrom(
                alignment: Alignment.centerLeft,
                foregroundColor: palette.sub,
                textStyle: AppTextStyles.secondary,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 30),
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

class _SidebarRow extends StatefulWidget {
  const _SidebarRow({
    super.key,
    required this.event,
    required this.color,
    required this.onComplete,
  });

  final Event event;
  final Color color;

  /// The sidebar owns the write so it can capture its repository before the
  /// fade; the row only runs the 120ms fade and then awaits this.
  final Future<void> Function() onComplete;

  @override
  State<_SidebarRow> createState() => _SidebarRowState();
}

class _SidebarRowState extends State<_SidebarRow> {
  bool _completing = false;

  Future<void> _complete() async {
    if (_completing) return;
    setState(() => _completing = true);
    await Future<void>.delayed(const Duration(milliseconds: 120));
    await widget.onComplete();
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
    final event = widget.event;
    final done = _completing;
    final time = event.startMinute == null
        ? l10n.allDay
        : AppFormats.timeRange(event.startMinute, event.endMinute);

    return GestureDetector(
      key: ValueKey('sidebar-row-${event.id}'),
      behavior: HitTestBehavior.opaque,
      onTap: () => showEventEditor(context, existing: event),
      child: AnimatedOpacity(
        opacity: done ? 0.35 : 1,
        duration: const Duration(milliseconds: 120),
        child: SizedBox(
          height: 30,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                GestureDetector(
                  key: ValueKey('sidebar-complete-${event.id}'),
                  behavior: HitTestBehavior.opaque,
                  onTap: _complete,
                  child: Container(
                    width: 14,
                    height: 14,
                    alignment: Alignment.center,
                    decoration: done
                        ? BoxDecoration(
                            shape: BoxShape.circle,
                            color: palette.accent,
                          )
                        : BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: palette.subWeak,
                              width: 1.5,
                            ),
                          ),
                    child: done
                        ? const Icon(
                            LucideIcons.check,
                            size: 9,
                            color: Colors.white,
                          )
                        : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    event.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.body.copyWith(color: palette.ink),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  time,
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 11,
                    color: palette.sub,
                  ),
                ),
                const SizedBox(width: 6),
                CategoryMarker(kind: event.kind, color: widget.color),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

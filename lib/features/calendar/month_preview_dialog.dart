import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/l10n/generated/app_localizations.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/dates.dart';
import '../../core/utils/formats.dart';
import '../../data/database/database.dart';
import '../../data/repositories/category_repository.dart';
import '../../data/repositories/event_repository.dart';
import '../../notifications/notification_scheduler.dart';
import '../events/event_editor_sheet.dart';
import 'calendar_state.dart';
import 'category_marker.dart';

/// Centred day preview opened by a single click on a month cell
/// (`docs/design/03-calendar.md` §1.2): every item of the day with an inline
/// completion circle, plus add and sidebar entry points.
class MonthPreviewDialog extends ConsumerWidget {
  const MonthPreviewDialog({super.key, required this.day});

  final DateTime day;

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
    final date = dateOnly(day);
    final events =
        ref.watch(eventsForDayProvider(date)).value ?? const <Event>[];
    final categories =
        ref.watch(allCategoriesProvider).value ?? const <Category>[];
    final holidays = ref.watch(holidaysProvider).value ?? const <Holiday>[];
    final holiday = _holidayOn(holidays, date);
    final isToday = date == dateOnly(ref.watch(todayProvider));

    void close() => Navigator.of(context).pop();

    return Dialog(
      key: const ValueKey('month-preview'),
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.all(24),
      child: CallbackShortcuts(
        bindings: {const SingleActivator(LogicalKeyboardKey.escape): close},
        child: Focus(
          autofocus: true,
          child: Container(
            width: 340,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * .8,
            ),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            decoration: BoxDecoration(
              color: palette.card,
              borderRadius: BorderRadius.circular(AppRadii.dialog),
              border: Border.all(color: palette.lineStrong),
              boxShadow: theme.brightness == Brightness.light
                  ? kDialogShadow
                  : kDialogShadowDark,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text.rich(
                        TextSpan(
                          text:
                              '${AppFormats.monthDay(locale, date)} '
                              '${AppFormats.weekday(locale, date)}',
                          children: [
                            if (holiday != null)
                              TextSpan(
                                text: ' · ${holiday.name}',
                                style: AppTextStyles.headline.copyWith(
                                  color: palette.festival,
                                ),
                              ),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.headline.copyWith(
                          color: palette.ink,
                        ),
                      ),
                    ),
                    if (isToday) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: palette.accentTint,
                          borderRadius: BorderRadius.circular(AppRadii.pill),
                        ),
                        child: Text(
                          l10n.today,
                          style: AppTextStyles.caption.copyWith(
                            color: palette.accent,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(width: 8),
                    Text(
                      '· ${l10n.itemsCount(events.length)}',
                      style: AppTextStyles.caption.copyWith(color: palette.sub),
                    ),
                    const Spacer(),
                    IconButton(
                      key: const ValueKey('month-preview-close'),
                      onPressed: close,
                      icon: const Icon(LucideIcons.x, size: 14),
                      color: palette.sub,
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints.tightFor(
                        width: 22,
                        height: 22,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(height: 1, color: palette.line),
                const SizedBox(height: 6),
                Flexible(
                  child: SingleChildScrollView(
                    key: const ValueKey('month-preview-scroll'),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (events.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              l10n.noEvents,
                              style: AppTextStyles.secondary.copyWith(
                                color: palette.sub,
                              ),
                            ),
                          )
                        else
                          for (final event in events)
                            _PreviewRow(
                              key: ValueKey(event.id),
                              event: event,
                              color: categoryMarkerColor(
                                event.categoryId,
                                categories,
                              ),
                            ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Container(height: 1, color: palette.line),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: TextButton(
                        key: const ValueKey('preview-add'),
                        onPressed: () => showEventEditor(context, date: date),
                        style: TextButton.styleFrom(
                          foregroundColor: palette.sub,
                          textStyle: AppTextStyles.caption,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          minimumSize: const Size(0, 24),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          l10n.addReminderOrPlan,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: TextButton(
                        key: const ValueKey('preview-edit-sidebar'),
                        onPressed: () {
                          Navigator.of(context).pop();
                          ref.read(selectedDayProvider.notifier).select(date);
                          ref
                              .read(sidebarPreferenceProvider.notifier)
                              .set(true);
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: palette.accent,
                          textStyle: AppTextStyles.caption,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          minimumSize: const Size(0, 24),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          l10n.editInSidebar,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PreviewRow extends ConsumerStatefulWidget {
  const _PreviewRow({super.key, required this.event, required this.color});

  final Event event;
  final Color color;

  @override
  ConsumerState<_PreviewRow> createState() => _PreviewRowState();
}

class _PreviewRowState extends ConsumerState<_PreviewRow> {
  bool _completing = false;

  Future<void> _complete() async {
    if (widget.event.isCompleted || _completing) return;
    // Capture the repository and sync bridge before the fade: the write must
    // land even if the dialog is closed mid-animation, and `ref` is invalid
    // once this row is disposed.
    final repo = ref.read(eventRepositoryProvider);
    final sync = ref.read(eventNotifierSyncProvider);
    setState(() => _completing = true);
    // Let the 120ms fade read as "done" before the completion is written.
    await Future<void>.delayed(const Duration(milliseconds: 120));
    await repo.setCompleted(widget.event.id, true);
    sync.afterCompletion(widget.event.copyWith(isCompleted: true));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette =
        (theme.brightness == Brightness.light
                ? AppPalette.light
                : AppPalette.dark)
            .withAccent(theme.colorScheme.primary);
    final event = widget.event;
    final done = event.isCompleted || _completing;
    final time = AppFormats.timeRange(event.startMinute, event.endMinute);

    return AnimatedOpacity(
      opacity: _completing ? 0.35 : 1,
      duration: const Duration(milliseconds: 120),
      child: InkWell(
        onTap: () => showEventEditor(context, existing: event),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              GestureDetector(
                key: ValueKey('preview-complete-${event.id}'),
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
              const SizedBox(width: 7),
              CategoryMarker(kind: event.kind, color: widget.color),
              const SizedBox(width: 5),
              if (time.isNotEmpty) ...[
                Text(
                  time,
                  style: AppTextStyles.secondary.copyWith(color: palette.sub),
                ),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  event.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.secondary.copyWith(
                    color: event.isCompleted ? palette.sub : palette.ink,
                    decoration: event.isCompleted
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Holiday? _holidayOn(List<Holiday> holidays, DateTime day) {
  final target = dateOnly(day);
  for (final holiday in holidays) {
    if (dateOnly(holiday.date) == target) return holiday;
  }
  return null;
}

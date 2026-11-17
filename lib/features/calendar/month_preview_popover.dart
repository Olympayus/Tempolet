import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/l10n/generated/app_localizations.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/ui/app_buttons.dart';
import '../../core/ui/app_popover.dart';
import '../../core/utils/dates.dart';
import '../../core/utils/formats.dart';
import '../../data/database/database.dart';
import '../../data/repositories/category_repository.dart';
import '../../data/repositories/event_repository.dart';
import '../../notifications/notification_scheduler.dart';
import '../events/event_editor_sheet.dart';
import '../events/event_list_row.dart';
import 'category_marker.dart';

/// Width of the anchored day preview (`docs/design/10-ui-refinement.md`
/// §9.13).
const double _popoverWidth = 340;

/// Fixed header height and one-row height.
const double _headerHeight = 52;
const double _rowHeight = AppSizes.row;

/// Minimum distance the panel keeps from the window edges, matching
/// [showAppPopover]'s own inset.
const double _windowInset = 8;

/// Anchored day preview opened by a single click on a month cell
/// (`docs/design/10-ui-refinement.md` §9.13): every item of the day as a
/// shared [EventListRow] with inline completion. There is no scrim; the
/// primitive closes it on Escape, an outside tap or the × button.
class MonthPreviewPopover extends ConsumerWidget {
  const MonthPreviewPopover({super.key, required this.day});

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

    // Keep the whole panel inside the window: the primitive flips it above
    // the anchor when it does not fit below, and these caps guarantee it fits
    // from the 8px top/left inset in the worst case.
    final window = MediaQuery.sizeOf(context);
    final width = math.min(
      _popoverWidth,
      math.max(0.0, window.width - _windowInset * 2),
    );
    final maxHeight = math.max(
      _headerHeight,
      window.height - _windowInset * 2,
    );

    return Container(
      key: const ValueKey('month-preview'),
      width: width,
      constraints: BoxConstraints(maxHeight: maxHeight),
      clipBehavior: Clip.antiAlias,
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: _headerHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        text: AppFormats.monthDay(locale, date),
                        children: [
                          TextSpan(
                            text: ' ${AppFormats.weekday(locale, date)}',
                            style: AppTextStyles.secondary.copyWith(
                              color: palette.sub,
                            ),
                          ),
                          if (holiday != null)
                            TextSpan(
                              text: ' · ${holiday.name}',
                              style: AppTextStyles.secondary.copyWith(
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
                  const SizedBox(width: 8),
                  Text(
                    '· ${l10n.itemsCount(events.length)}',
                    maxLines: 1,
                    style: AppTextStyles.caption.copyWith(
                      color: palette.subMuted,
                    ),
                  ),
                  const SizedBox(width: 4),
                  AppIconButton(
                    key: const ValueKey('month-preview-close'),
                    onPressed: () => AppPopoverScope.closeWith(context),
                    icon: const Icon(LucideIcons.x),
                  ),
                ],
              ),
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              key: const ValueKey('month-preview-scroll'),
              child: events.isEmpty
                  ? SizedBox(
                      height: _rowHeight,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            l10n.noEvents,
                            style: AppTextStyles.body.copyWith(
                              color: palette.subWeak,
                            ),
                          ),
                        ),
                      ),
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final event in events)
                          _PreviewRow(
                            key: ValueKey('preview-row-${event.id}'),
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
        ],
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
    // land even if the popover is closed mid-animation, and `ref` is invalid
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
    final event = _completing
        ? widget.event.copyWith(isCompleted: true)
        : widget.event;
    return AnimatedOpacity(
      opacity: _completing ? 0.35 : 1,
      duration: const Duration(milliseconds: 120),
      child: EventListRow(
        event: event,
        color: widget.color,
        onTap: () => showEventEditor(context, existing: widget.event),
        onToggleComplete: _complete,
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

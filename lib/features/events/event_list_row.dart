import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/ui/app_check_circle.dart';
import '../../core/utils/formats.dart';
import '../../data/database/database.dart';

/// Fixed width of the marker slot between the completion circle and the title.
const double _markerSlot = 14;

/// Gap between the row's anatomy elements.
const double _gap = 8;

/// Horizontal padding inside the row.
const double _rowPadding = 16;

/// The paper block behind plan rows sits 3px inside the row's top and bottom
/// and leaves [blockRightInset] for the scrollbar and row edge.
const double _blockInset = 3;
const double _blockRightInset = 12;
const double _blockRadius = 7;

/// Shared list-row anatomy for the sidebar, reminders, completed list, day
/// preview popover and day overview (`docs/design/10-ui-refinement.md` §9.11).
///
/// A row is 46px tall. From the left: a 24px completion hit target (14px
/// circle), an 8px gap, a 14px marker slot (a 2.5×16 category-coloured bar for
/// plans, a 6px dot for reminders), an 8px gap, the 13px title, an 8px gap and
/// the 11px right-aligned time. Plan rows also draw a paper block behind the
/// content, inset 12px on the right; the time still aligns to the row's 16px
/// right padding.
class EventListRow extends StatelessWidget {
  const EventListRow({
    super.key,
    required this.event,
    required this.color,
    this.showDate = false,
    this.timeColor,
    this.timeSuffix,
    this.timeLabel,
    this.titleColor,
    this.metadata,
    this.checked,
    this.onTap,
    this.onLongPress,
    this.onToggleComplete,
    this.trailing,
  });

  final Event event;

  /// Category colour used by the marker.
  final Color color;

  /// Prefixes the time with the localized month and day (reminders page).
  final bool showDate;

  /// Overrides the time's `sub` colour (e.g. overdue rows use `danger`).
  final Color? timeColor;

  /// Appended to the time in the same 11px run (e.g. the date mode's `逾期`
  /// marker). A row without a time still shows the suffix.
  final String? timeSuffix;

  /// Replaces the computed event time with [timeLabel] (e.g. the completed
  /// page shows when the item was completed). [showDate] and [timeSuffix] are
  /// ignored when this is set.
  final String? timeLabel;

  /// Overrides the title colour; defaults to `ink`.
  final Color? titleColor;

  /// Optional 11px metadata rendered between the title and the time (e.g. the
  /// completed page's kind label).
  final Widget? metadata;

  /// Overrides the completion circle's state (e.g. multi-select rows show the
  /// selection instead of completion).
  final bool? checked;

  /// Opens the event editor.
  final VoidCallback? onTap;

  /// Enters multi-select on the completed page. Only meaningful when the row
  /// is not already in a selection.
  final VoidCallback? onLongPress;

  /// Toggles [Event.isCompleted]; when null the circle is display-only.
  final VoidCallback? onToggleComplete;

  /// Optional widget rendered after the time (e.g. completed-row actions).
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette =
        (theme.brightness == Brightness.light
                ? AppPalette.light
                : AppPalette.dark)
            .withAccent(theme.colorScheme.primary);
    final locale = Localizations.localeOf(context);
    final isPlan = event.kind == 'plan';
    final time = AppFormats.timeRange(event.startMinute, event.endMinute);
    // Chinese keeps `11月16日 09:00`; English uses the no-comma separator
    // `Nov 16 · 09:00` (v0.1.3 ruling, progress ledger Task 4).
    final dateSeparator = locale.languageCode == 'zh' ? ' ' : ' · ';
    final timeText =
        timeLabel ??
        [
          if (showDate) AppFormats.monthDay(locale, event.date),
          if (time.isNotEmpty) time,
          if (timeSuffix != null && timeSuffix!.isNotEmpty) timeSuffix!,
        ].join(dateSeparator);
    final titleStyle = AppTextStyles.body.copyWith(
      color: titleColor ?? palette.ink,
      decoration: event.isCompleted ? TextDecoration.lineThrough : null,
    );

    return SizedBox(
      height: AppSizes.row,
      child: Stack(
        children: [
          if (isPlan)
            Positioned(
              left: 0,
              right: _blockRightInset,
              top: _blockInset,
              bottom: _blockInset,
              child: Container(
                key: const ValueKey('event-list-row-block'),
                decoration: BoxDecoration(
                  color: palette.block,
                  borderRadius: BorderRadius.circular(_blockRadius),
                ),
              ),
            ),
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              onLongPress: onLongPress,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: _rowPadding),
                child: Row(
                  children: [
                    AppCheckCircle(
                      checked: checked ?? event.isCompleted,
                      onTap: onToggleComplete,
                    ),
                    const SizedBox(width: _gap),
                    SizedBox(
                      width: _markerSlot,
                      child: Center(
                        child: isPlan
                            ? Container(
                                key: const ValueKey(
                                  'event-list-row-plan-marker',
                                ),
                                width: 2.5,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: color,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              )
                            : Container(
                                key: const ValueKey(
                                  'event-list-row-reminder-marker',
                                ),
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: _gap),
                    Expanded(
                      child: Text(
                        event.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: titleStyle,
                      ),
                    ),
                    if (metadata != null) ...[
                      const SizedBox(width: 12),
                      metadata!,
                    ],
                    SizedBox(width: metadata != null ? 12 : _gap),
                    Text(
                      timeText,
                      maxLines: 1,
                      style: AppTextStyles.caption.copyWith(
                        color: timeColor ?? palette.sub,
                      ),
                    ),
                    if (trailing != null) ...[
                      const SizedBox(width: _gap),
                      trailing!,
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

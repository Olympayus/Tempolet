import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/ui/app_check_circle.dart';
import '../../core/ui/app_list_checkbox.dart';
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
/// circle, or a 16px square [AppListCheckbox] in selection mode), an 8px gap,
/// a 14px marker slot (a 2.5×16 category-coloured bar for plans, a 6px dot for
/// reminders), an 8px gap, the 13px title, an 8px gap and the 11px right-aligned
/// time. Plan rows also draw a paper block behind the content, inset 12px on
/// the right; the time still aligns to the row's 16px right padding.
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
    this.titleBuilder,
    this.metadata,
    this.selectionChecked,
    this.onTap,
    this.onLongPress,
    this.onToggleComplete,
    this.onToggleSelection,
    this.trailing,
    this.completeKey,
    this.height = AppSizes.row,
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

  /// Replaces the default title [Text]. The row passes body plus the pending
  /// ink colour and no completion decoration: the builder owns both the
  /// strike-through and any colour sweep. The slot stays expanded to one line.
  final Widget Function(BuildContext context, TextStyle style)? titleBuilder;

  /// Optional 11px metadata rendered between the title and the time (e.g. the
  /// completed page's kind label).
  final Widget? metadata;

  /// When non-null the row is in selection mode: the leading control becomes a
  /// square [AppListCheckbox] carrying this state instead of the completion
  /// circle.
  final bool? selectionChecked;

  /// Opens the event editor.
  final VoidCallback? onTap;

  /// Enters multi-select on the completed page. Only meaningful when the row
  /// is not already in a selection.
  final VoidCallback? onLongPress;

  /// Toggles [Event.isCompleted]; when null the circle is display-only.
  final VoidCallback? onToggleComplete;

  /// Toggles the row's selection; only used when [selectionChecked] is set.
  final VoidCallback? onToggleSelection;

  /// Optional widget rendered after the time (e.g. completed-row actions).
  final Widget? trailing;

  /// Optional key on the completion circle, for tests that tap it directly.
  final Key? completeKey;

  /// Row height. Touch layouts pass the 52px touch row; desktop keeps 46.
  final double height;

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
    // The builder owns its strike-through, so it only receives body + colour;
    // the default title still paints the completed decoration itself.
    final titleStyle = AppTextStyles.body.copyWith(
      color: titleColor ?? palette.ink,
    );
    final defaultTitleStyle = event.isCompleted
        ? titleStyle.copyWith(decoration: TextDecoration.lineThrough)
        : titleStyle;
    final note = event.note.trim();

    return SizedBox(
      height: height,
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
                    if (selectionChecked != null)
                      AppListCheckbox(
                        checked: selectionChecked!,
                        onTap: onToggleSelection,
                      )
                    else
                      KeyedSubtree(
                        key: completeKey,
                        child: AppCheckCircle(
                          checked: event.isCompleted,
                          onTap: onToggleComplete,
                        ),
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
                      child: titleBuilder != null
                          ? titleBuilder!(context, titleStyle)
                          : Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: event.title,
                                    style: defaultTitleStyle,
                                  ),
                                  if (note.isNotEmpty)
                                    TextSpan(
                                      text: ' · $note',
                                      style: AppTextStyles.caption.copyWith(
                                        color: palette.subMuted,
                                      ),
                                    ),
                                ],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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

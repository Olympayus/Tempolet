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
    this.onTap,
    this.onToggleComplete,
    this.trailing,
  });

  final Event event;

  /// Category colour used by the marker.
  final Color color;

  /// Prefixes the time with the localized month and day (reminders page).
  final bool showDate;

  /// Opens the event editor.
  final VoidCallback? onTap;

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
    final timeText = showDate
        ? [
            AppFormats.monthDay(locale, event.date),
            if (time.isNotEmpty) time,
          ].join(' ')
        : time;
    final titleStyle = AppTextStyles.body.copyWith(
      color: palette.ink,
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
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: _rowPadding),
                child: Row(
                  children: [
                    AppCheckCircle(
                      checked: event.isCompleted,
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
                    const SizedBox(width: _gap),
                    Text(
                      timeText,
                      maxLines: 1,
                      style: AppTextStyles.caption.copyWith(color: palette.sub),
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

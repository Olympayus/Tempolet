import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/generated/app_localizations.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/ui/app_check_circle.dart';
import '../../core/utils/dates.dart';
import '../../data/database/database.dart';
import '../../data/repositories/category_repository.dart';
import 'category_marker.dart';

/// Floating reminder card for the day/week time grids: card surface, 1px
/// `line` border, soft shadow, an optional 14px completion circle, the title,
/// its time and a 5px category dot.
///
/// Ticking the circle fades the card for 120ms and then calls [onComplete];
/// the parent owns the actual write so it can capture its repository before
/// the delay. When [onUndo] is set and the event is already completed, tapping
/// the circle calls it immediately instead, keeping the card in place.
class ReminderCard extends ConsumerStatefulWidget {
  const ReminderCard({
    super.key,
    required this.event,
    required this.overdue,
    required this.showCheckbox,
    this.onTap,
    this.onComplete,
    this.onUndo,
    this.progress,
    this.titleBuilder,
  });

  final Event event;
  final bool overdue;

  /// Week view floats reminders without a completion control.
  final bool showCheckbox;
  final VoidCallback? onTap;
  final Future<void> Function()? onComplete;

  /// Reverts a completed event without the completion fade.
  final Future<void> Function()? onUndo;

  /// External fill progress for the completion circle while the strike-through
  /// animates.
  final double? progress;

  /// Replaces the default title [Text]; receives the card's title style.
  final Widget Function(BuildContext context, TextStyle style)? titleBuilder;

  @override
  ConsumerState<ReminderCard> createState() => _ReminderCardState();
}

class _ReminderCardState extends ConsumerState<ReminderCard> {
  bool _completing = false;

  /// The reminders page keeps this card mounted after completion and owns the
  /// completed snapshot. Without resetting the local fade flag, undo would
  /// leave the card dimmed and completed-looking and the circle could never
  /// start another completion.
  @override
  void didUpdateWidget(covariant ReminderCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.event.isCompleted != widget.event.isCompleted) {
      _completing = false;
    }
  }

  Future<void> _complete() async {
    final onComplete = widget.onComplete;
    if (_completing || widget.event.isCompleted || onComplete == null) return;
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    setState(() => _completing = true);
    // Let the fade read as "done" before the completion is written; motion is
    // off, so there is nothing to read.
    if (!reduceMotion) {
      await Future<void>.delayed(const Duration(milliseconds: 120));
    }
    await onComplete();
  }

  VoidCallback? _circleTap() {
    final onUndo = widget.onUndo;
    if (onUndo != null && widget.event.isCompleted) {
      return () => onUndo();
    }
    if (!widget.event.isCompleted && widget.onComplete != null) {
      return _complete;
    }
    return null;
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
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final categories =
        ref.watch(allCategoriesProvider).value ?? const <Category>[];
    final event = widget.event;
    final done = event.isCompleted || _completing;
    final danger = widget.overdue && !done;
    final time = event.startMinute == null
        ? l10n.allDay
        : formatMinuteOfDay(event.startMinute!);
    // The builder owns its strike-through, so it only receives body + colour;
    // the default title still paints the completed decoration itself.
    final titleStyle = AppTextStyles.body.copyWith(
      fontWeight: FontWeight.w700,
      fontVariations: const [FontVariation('wght', 700)],
      color: done ? palette.sub : palette.ink,
    );
    final defaultTitleStyle = done
        ? titleStyle.copyWith(decoration: TextDecoration.lineThrough)
        : titleStyle;

    return AnimatedOpacity(
      opacity: _completing ? 0.35 : 1,
      duration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 120),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(8, 5, 10, 5),
          decoration: BoxDecoration(
            color: palette.card,
            borderRadius: BorderRadius.circular(AppRadii.segment),
            border: Border.all(color: palette.line),
            boxShadow: kCardShadow,
          ),
          child: Row(
            children: [
              if (widget.showCheckbox) ...[
                AppCheckCircle(
                  key: ValueKey('complete-${event.id}'),
                  checked: done,
                  progress: widget.progress,
                  borderColor: danger ? palette.danger : null,
                  onTap: _circleTap(),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: widget.titleBuilder != null
                    ? widget.titleBuilder!(context, titleStyle)
                    : Text(
                        event.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: defaultTitleStyle,
                      ),
              ),
              const SizedBox(width: 8),
              Text(
                time,
                style: AppTextStyles.caption.copyWith(
                  fontSize: 11,
                  color: danger ? palette.danger : palette.sub,
                ),
              ),
              const SizedBox(width: 6),
              CategoryMarker(
                kind: event.kind,
                color: categoryMarkerColor(event.categoryId, categories),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/l10n/generated/app_localizations.dart';
import '../../core/theme/app_tokens.dart';
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
/// the delay.
class ReminderCard extends ConsumerStatefulWidget {
  const ReminderCard({
    super.key,
    required this.event,
    required this.overdue,
    required this.showCheckbox,
    this.onTap,
    this.onComplete,
  });

  final Event event;
  final bool overdue;

  /// Week view floats reminders without a completion control.
  final bool showCheckbox;
  final VoidCallback? onTap;
  final Future<void> Function()? onComplete;

  @override
  ConsumerState<ReminderCard> createState() => _ReminderCardState();
}

class _ReminderCardState extends ConsumerState<ReminderCard> {
  bool _completing = false;

  Future<void> _complete() async {
    final onComplete = widget.onComplete;
    if (_completing || widget.event.isCompleted || onComplete == null) return;
    setState(() => _completing = true);
    // Let the fade read as "done" before the completion is written.
    await Future<void>.delayed(const Duration(milliseconds: 120));
    await onComplete();
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
    final categories =
        ref.watch(allCategoriesProvider).value ?? const <Category>[];
    final event = widget.event;
    final done = event.isCompleted || _completing;
    final danger = widget.overdue && !done;
    final time = event.startMinute == null
        ? l10n.allDay
        : formatMinuteOfDay(event.startMinute!);

    return AnimatedOpacity(
      opacity: _completing ? 0.35 : 1,
      duration: const Duration(milliseconds: 120),
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
                GestureDetector(
                  key: ValueKey('complete-${event.id}'),
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
                              color: danger ? palette.danger : palette.subWeak,
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
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  event.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w700,
                    fontVariations: const [FontVariation('wght', 700)],
                    color: done ? palette.sub : palette.ink,
                    decoration: done ? TextDecoration.lineThrough : null,
                  ),
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

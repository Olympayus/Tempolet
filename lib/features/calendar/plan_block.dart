import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/utils/formats.dart';
import '../../data/database/database.dart';
import '../../data/repositories/category_repository.dart';
import 'category_marker.dart';

/// Paper block for a plan on the day/week time grid: chip fill, a 1px
/// `lineStrong` border and a 2.5px category-coloured bar down the left edge.
///
/// Day view uses the default (13/700 title, 11px time); week view passes
/// [compact] for the denser 11/700 + 10px scale.
class PlanBlock extends ConsumerWidget {
  const PlanBlock({
    super.key,
    required this.event,
    required this.overdue,
    this.onTap,
    this.compact = false,
  });

  final Event event;
  final bool overdue;
  final VoidCallback? onTap;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final palette =
        (theme.brightness == Brightness.light
                ? AppPalette.light
                : AppPalette.dark)
            .withAccent(theme.colorScheme.primary);
    final categories =
        ref.watch(allCategoriesProvider).value ?? const <Category>[];
    final markerColor = categoryMarkerColor(event.categoryId, categories);
    final done = event.isCompleted;
    final time = AppFormats.timeRange(event.startMinute, event.endMinute);

    final titleStyle = AppTextStyles.body.copyWith(
      fontSize: compact ? 11 : 13,
      height: 1.15,
      fontWeight: FontWeight.w700,
      fontVariations: const [FontVariation('wght', 700)],
      color: done ? palette.sub : palette.ink,
      decoration: done ? TextDecoration.lineThrough : null,
    );
    final timeStyle = AppTextStyles.caption.copyWith(
      fontSize: compact ? 10 : 11,
      height: 1.2,
      color: overdue ? palette.danger : palette.sub,
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Two text lines only fit in taller blocks; shorter ones keep the
          // title readable instead of clipping the time.
          final showsTime = (compact ? 31.0 : 34.0);
          final showTime =
              time.isNotEmpty && constraints.maxHeight >= showsTime;
          final tight = constraints.maxHeight < showsTime;
          return Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: palette.chip,
              borderRadius: BorderRadius.circular(AppRadii.block),
              border: Border.all(color: palette.lineStrong),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: Container(width: 2.5, color: markerColor),
                ),
                Positioned.fill(
                  left: 2.5,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      6,
                      tight ? 0 : 2,
                      6,
                      tight ? 0 : 1,
                    ),
                    // Short blocks get a title taller than their slot; the
                    // unbounded box lets it clip against the block instead of
                    // tripping a RenderFlex overflow.
                    child: OverflowBox(
                      alignment: Alignment.topLeft,
                      minHeight: 0,
                      maxHeight: double.infinity,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            event.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: titleStyle,
                          ),
                          if (showTime)
                            Text(
                              time,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: timeStyle,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

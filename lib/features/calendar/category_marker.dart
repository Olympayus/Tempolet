import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import '../../data/database/database.dart';

/// Colour of an event's category marker, falling back to the neutral
/// uncategorised token (`docs/design/01-tokens.md` §1.3).
Color categoryMarkerColor(String? categoryId, List<Category> categories) {
  if (categoryId != null) {
    for (final category in categories) {
      if (category.id == categoryId && category.color != null) {
        return Color(category.color!);
      }
    }
  }
  return kUncategorizedColor;
}

/// The shape-coded category marker shared by month cells, week cards and the
/// day preview: a 5px dot for reminders and a vertical 2.5×9 bar for plans
/// (2026-11-20: plans always read as a bar, never a dash).
class CategoryMarker extends StatelessWidget {
  const CategoryMarker({super.key, required this.kind, required this.color});

  /// `reminder` or `plan` (the database values).
  final String kind;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (kind == 'plan') {
      return Container(
        width: 2.5,
        height: 9,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(1),
        ),
      );
    }
    return Container(
      width: 5,
      height: 5,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

/// The month cell's bottom marker row (2026-11-20): every reminder/plan becomes
/// a horizontal marker pinned to the cell's bottom edge, plans as vertical
/// bars and reminders as dots. Overflow collapses to an ellipsis.
class MonthMarkerRow extends StatelessWidget {
  const MonthMarkerRow({
    super.key,
    required this.events,
    required this.categories,
    required this.palette,
    this.gap = 5,
    this.ellipsisKey,
  });

  final List<Event> events;
  final List<Category> categories;
  final AppPalette palette;
  final double gap;
  final Key? ellipsisKey;

  static const double _dot = 5;
  static const double _bar = 2.5;
  static const double _ellipsis = 9;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final children = <Widget>[];
        var used = 0.0;
        var shown = 0;
        for (final event in events) {
          final width = event.kind == 'plan' ? _bar : _dot;
          final lead = shown == 0 ? 0.0 : gap;
          final reserve = shown + 1 < events.length ? gap + _ellipsis : 0.0;
          if (used + lead + width + reserve > maxWidth) break;
          if (shown > 0) children.add(SizedBox(width: gap));
          children.add(
            CategoryMarker(
              kind: event.kind,
              color: categoryMarkerColor(event.categoryId, categories),
            ),
          );
          used += lead + width;
          shown++;
        }
        final overflow = shown < events.length;
        if (overflow) {
          if (shown > 0) children.add(SizedBox(width: gap));
          children.add(
            Text(
              '…',
              key: ellipsisKey,
              style: AppTextStyles.caption.copyWith(
                fontSize: 10,
                height: 1,
                color: palette.sub,
              ),
            ),
          );
        }
        return Row(mainAxisSize: MainAxisSize.min, children: children);
      },
    );
  }
}

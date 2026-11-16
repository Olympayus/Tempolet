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

/// The shape-coded category marker shared by month cells and the day preview:
/// a 5px dot for reminders and an 8×2.5 dash for plans.
class CategoryMarker extends StatelessWidget {
  const CategoryMarker({super.key, required this.kind, required this.color});

  /// `reminder` or `plan` (the database values).
  final String kind;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (kind == 'plan') {
      return Container(
        width: 8,
        height: 2.5,
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

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/prefs.dart';
import '../../data/database/database.dart';

/// Sentinel id that places the system 未分类 group among real category ids in
/// [categoryOrderProvider].
const String uncategorizedOrderId = '__uncategorized__';

/// Applies a persisted [order] to [categories].
///
/// Items follow the ids in [order] first (unknown ids are ignored); remaining
/// categories keep the repository order. A `null` entry is the system
/// 未分类 group: it stays wherever [order] explicitly placed it, otherwise it
/// is appended after every real category.
List<Category?> applyCategoryOrder(
  List<String> order,
  List<Category> categories,
) {
  final byId = {for (final category in categories) category.id: category};
  final seen = <String>{};
  final result = <Category?>[];
  for (final id in order) {
    if (id == uncategorizedOrderId) {
      if (seen.add(id)) result.add(null);
      continue;
    }
    final category = byId[id];
    if (category != null && seen.add(id)) result.add(category);
  }
  for (final category in categories) {
    if (seen.add(category.id)) result.add(category);
  }
  if (seen.add(uncategorizedOrderId)) result.add(null);
  return result;
}

/// Display order for the reminders page's category groups.
///
/// The stored list contains real category ids and [uncategorizedOrderId]. It is
/// display-only: the database's `sortOrder` is not touched here (the category
/// management page syncs real ids after a drag).
final categoryOrderProvider =
    NotifierProvider<CategoryOrderController, List<String>>(
      CategoryOrderController.new,
    );

class CategoryOrderController extends Notifier<List<String>> {
  static const prefKey = 'category_order';

  @override
  List<String> build() =>
      ref.watch(sharedPreferencesProvider).getStringList(prefKey) ?? const [];

  /// Persists [order] (real ids and the sentinel) and updates listeners.
  void setOrder(List<String> order) {
    state = List<String>.unmodifiable(order);
    ref.read(sharedPreferencesProvider).setStringList(prefKey, [...order]);
  }

  /// Display-ordered items for [categories]; `null` is the 未分类 group.
  List<Category?> applyOrder(List<Category> categories) =>
      applyCategoryOrder(state, categories);

  /// Places a newly created real category at the end of the real categories.
  ///
  /// When 未分类 is persisted last (the default) the new id is inserted just
  /// before it, so a new category never lands below the sentinel.
  void addCategory(String id) {
    if (state.contains(id)) return;
    final order = [...state];
    if (order.isNotEmpty && order.last == uncategorizedOrderId) {
      order.insert(order.length - 1, id);
    } else {
      order.add(id);
    }
    setOrder(order);
  }

  /// Drops a soft-deleted real category from the persisted display order.
  void removeCategory(String id) {
    if (!state.contains(id)) return;
    setOrder([...state]..remove(id));
  }
}

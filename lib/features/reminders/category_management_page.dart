import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/l10n/generated/app_localizations.dart';
import '../../core/layout.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/ui/app_buttons.dart';
import '../../data/database/database.dart';
import '../../data/repositories/category_repository.dart';
import 'category_editor.dart';
import 'category_order.dart';
import '../../core/ui/confirm_delete_dialog.dart';
import '../../core/ui/fitted_label.dart';

/// Event totals per category, including completed but not deleted items.
///
/// `null` is the uncategorised bucket. Rows whose category id no longer exists
/// are folded into 未分类 by the page, mirroring the reminders list.
final categoryEventCountsProvider = StreamProvider<Map<String?, int>>((ref) {
  final db = ref.watch(databaseProvider);
  return db
      .customSelect(
        'SELECT category_id, COUNT(*) AS item_count FROM events '
        'WHERE deleted_at IS NULL GROUP BY category_id',
        readsFrom: {db.events},
      )
      .watch()
      .map((rows) {
        final counts = <String?, int>{};
        for (final row in rows) {
          counts[row.readNullable<String>('category_id')] = row.read<int>(
            'item_count',
          );
        }
        return counts;
      });
});

/// `/reminders/categories` — the category management sub-page
/// (`docs/design/04-reminders.md` §5).
///
/// Rows are 46 high with a 16px drag handle, a 12px colour dot, the name, its
/// item count and a delete button. The system 未分类 row can only be reordered.
/// Dragging updates [categoryOrderProvider] (including the sentinel) and syncs
/// the real categories' `sortOrder`; the colour dot reuses the settings picker;
/// tapping a name edits it inline; deleting soft-deletes and frees its events.
class CategoryManagementPage extends ConsumerStatefulWidget {
  const CategoryManagementPage({super.key});

  @override
  ConsumerState<CategoryManagementPage> createState() =>
      _CategoryManagementPageState();
}

class _CategoryManagementPageState
    extends ConsumerState<CategoryManagementPage> {
  /// One create path for every layout: the shared category editor (a bottom
  /// sheet on phones, a dialog on tablet and desktop), matching the event
  /// editor's flow.
  Future<void> _openCreate() => showCategoryEditor(context);

  Future<void> _delete(Category category) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDeleteConfirmDialog(
      context,
      message: l10n.deleteForeverHint,
      cancelLabel: l10n.cancel,
      deleteLabel: l10n.delete,
      dialogKey: const ValueKey('category-delete-confirm'),
      cancelKey: const ValueKey('category-delete-cancel'),
      deleteKey: const ValueKey('category-delete-confirm-action'),
    );
    if (!confirmed) return;
    await ref.read(categoryRepositoryProvider).softDelete(category.id);
    if (!mounted) return;
    ref.read(categoryOrderProvider.notifier).removeCategory(category.id);
  }

  void _reorder(String sourceId, String targetId) {
    if (sourceId == targetId) return;
    final categories =
        ref.read(allCategoriesProvider).value ?? const <Category>[];
    final displayed = [
      for (final category in applyCategoryOrder(
        ref.read(categoryOrderProvider),
        categories,
      ))
        category?.id ?? uncategorizedOrderId,
    ];
    final from = displayed.indexOf(sourceId);
    final to = displayed.indexOf(targetId);
    if (from == -1 || to == -1) return;
    displayed.removeAt(from);
    final insertAt = to > displayed.length ? displayed.length : to;
    displayed.insert(insertAt, sourceId);
    ref.read(categoryOrderProvider.notifier).setOrder(displayed);
    final realIds = [
      for (final id in displayed)
        if (id != uncategorizedOrderId) id,
    ];
    unawaited(ref.read(categoryRepositoryProvider).reorder(realIds));
  }

  @override
  Widget build(BuildContext context) {
    final palette = _paletteOf(context);
    final l10n = AppLocalizations.of(context);
    final categories =
        ref.watch(allCategoriesProvider).value ?? const <Category>[];
    final counts =
        ref.watch(categoryEventCountsProvider).value ?? const <String?, int>{};
    final ordered = applyCategoryOrder(
      ref.watch(categoryOrderProvider),
      categories,
    );

    final realIds = {for (final category in categories) category.id};
    var uncategorizedCount = counts[null] ?? 0;
    counts.forEach((id, count) {
      if (id != null && !realIds.contains(id)) uncategorizedCount += count;
    });

    return Scaffold(
      key: const ValueKey('category-management-page'),
      backgroundColor: palette.bg,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: AppSizes.header,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: resolveAppLayout(context) == AppLayout.phone
                    ? 16
                    : 24,
              ),
              child: Row(
                children: [
                  IconButton(
                    key: const ValueKey('category-back'),
                    onPressed: () => context.go('/reminders'),
                    icon: const Icon(LucideIcons.chevronLeft, size: 16),
                    color: palette.sub,
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints.tightFor(
                      width: AppSizes.control,
                      height: AppSizes.control,
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: palette.chip,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadii.button),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    // Fixed copy: scale rather than ellipsise beside the create
                    // button, like the reminders title.
                    child: FittedLabel(
                      l10n.manageCategories,
                      key: const ValueKey('category-title'),
                      alignment: Alignment.centerLeft,
                      textAlign: TextAlign.left,
                      style: AppTextStyles.display.copyWith(
                        fontSize: resolveAppLayout(context) == AppLayout.phone
                            ? 34
                            : 28,
                        color: palette.ink,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  AppButton.primary(
                    key: const ValueKey('category-create'),
                    label: l10n.newCategory,
                    leadingIcon: const Icon(LucideIcons.plus, size: 16),
                    onPressed: _openCreate,
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    key: const ValueKey('category-list'),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    children: [
                      for (final category in ordered)
                        _CategoryRow(
                          key: ValueKey(
                            'category-row-${category?.id ?? uncategorizedOrderId}',
                          ),
                          id: category?.id ?? uncategorizedOrderId,
                          name: category?.name ?? l10n.uncategorized,
                          color: category?.color,
                          count: category == null
                              ? uncategorizedCount
                              : counts[category.id] ?? 0,
                          system: category == null,
                          onEdit: category == null
                              ? null
                              : () => showCategoryEditor(
                                  context,
                                  category: category,
                                ),
                          onDelete: category == null
                              ? null
                              : () => unawaited(_delete(category)),
                          onDrop: (sourceId) => _reorder(
                            sourceId,
                            category?.id ?? uncategorizedOrderId,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One 46px category row: colour dot, name + count, and delete. Tapping the
/// row (or the pencil-free body) opens the unified editor; the whole row is
/// the drag handle — long press on touch, direct drag with a mouse.
class _CategoryRow extends StatefulWidget {
  const _CategoryRow({
    super.key,
    required this.id,
    required this.name,
    required this.color,
    required this.count,
    required this.system,
    required this.onEdit,
    required this.onDelete,
    required this.onDrop,
  });

  final String id;
  final String name;
  final int? color;
  final int count;
  final bool system;

  /// Null for the system 未分类 row, which cannot be edited or deleted.
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  /// Receives the dragged row's id when it is dropped onto this row.
  final ValueChanged<String> onDrop;

  @override
  State<_CategoryRow> createState() => _CategoryRowState();
}

class _CategoryRowState extends State<_CategoryRow> {
  bool _hovering = false;
  bool _mouseDragging = false;
  bool _dragActive = false;

  void _setHovering(bool hovering) {
    if (_hovering == hovering) return;
    setState(() => _hovering = hovering);
  }

  @override
  Widget build(BuildContext context) {
    final palette = _paletteOf(context);
    final l10n = AppLocalizations.of(context);
    final color = widget.color != null
        ? Color(widget.color!)
        : kUncategorizedColor;

    final row = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onEdit,
      child: Container(
        height: AppSizes.row,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              height: AppSizes.row,
              child: Center(
                child: Container(
                  key: ValueKey('category-dot-${widget.id}'),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      widget.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.body.copyWith(color: palette.ink),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${widget.count}',
                    key: ValueKey('category-count-${widget.id}'),
                    maxLines: 1,
                    style: AppTextStyles.caption.copyWith(color: palette.sub),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (widget.onDelete == null)
              const SizedBox(width: AppSizes.control)
            else
              AppIconButton(
                key: ValueKey('category-delete-${widget.id}'),
                tooltip: l10n.delete,
                onPressed: widget.onDelete,
                icon: Icon(LucideIcons.trash2, size: 14, color: palette.sub),
              ),
          ],
        ),
      ),
    );

    return DragTarget<String>(
      onWillAcceptWithDetails: (details) => details.data != widget.id,
      onAcceptWithDetails: (details) => widget.onDrop(details.data),
      builder: (context, candidateData, rejectedData) {
        final active = candidateData.isNotEmpty;
        final decorated = Container(
          decoration: BoxDecoration(
            color: active
                ? palette.accentTint
                : _hovering
                ? palette.hover
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadii.block),
          ),
          child: row,
        );
        return MouseRegion(
          // Pick the drag model before the press: a mouse hovers first (so
          // the first drag starts immediately), touch never hovers and keeps
          // the long-press drag.
          onEnter: (_) {
            _setHovering(true);
            if (!_mouseDragging) setState(() => _mouseDragging = true);
          },
          onExit: (_) {
            _setHovering(false);
            if (_mouseDragging && !_dragActive) {
              setState(() => _mouseDragging = false);
            }
          },
          child: _draggable(decorated, palette, color),
        );
      },
    );
  }

  Widget _draggable(Widget child, AppPalette palette, Color color) {
    final feedback = Material(
      color: Colors.transparent,
      child: Container(
        width: 240,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: palette.card,
          border: Border.all(color: palette.line),
          borderRadius: BorderRadius.circular(AppRadii.block),
          boxShadow: kCardShadow,
        ),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.body.copyWith(color: palette.ink),
              ),
            ),
          ],
        ),
      ),
    );
    final placeholder = Opacity(opacity: 0.3, child: child);
    final key = ValueKey('category-drag-${widget.id}');
    if (_mouseDragging) {
      return Draggable<String>(
        key: key,
        data: widget.id,
        feedback: feedback,
        childWhenDragging: placeholder,
        onDragStarted: () => _dragActive = true,
        onDragEnd: (_) => _dragActive = false,
        child: child,
      );
    }
    return LongPressDraggable<String>(
      key: key,
      data: widget.id,
      delay: const Duration(milliseconds: 400),
      hapticFeedbackOnStart: true,
      feedback: feedback,
      childWhenDragging: placeholder,
      onDragStarted: () => _dragActive = true,
      onDragEnd: (_) => _dragActive = false,
      child: child,
    );
  }
}

AppPalette _paletteOf(BuildContext context) {
  final theme = Theme.of(context);
  return (theme.brightness == Brightness.light
          ? AppPalette.light
          : AppPalette.dark)
      .withAccent(theme.colorScheme.primary);
}

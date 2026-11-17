import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/l10n/generated/app_localizations.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/ui/app_buttons.dart';
import '../../data/database/database.dart';
import '../../data/repositories/category_repository.dart';
import '../settings/accent_picker.dart';
import 'category_order.dart';

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
  /// Creates [name] and places it above the 未分类 sentinel. Returns the
  /// conflict message on a duplicate name and null on success.
  Future<String?> _createCategory(String name) async {
    final repo = ref.read(categoryRepositoryProvider);
    try {
      final category = await repo.create(name: name);
      if (!mounted) return null;
      ref.read(categoryOrderProvider.notifier).addCategory(category.id);
      await _persistRealOrder();
      return null;
    } on CategoryNameConflict {
      if (!mounted) return null;
      return AppLocalizations.of(context).categoryNameExists;
    }
  }

  Future<void> _openCreateDialog() => showDialog<String>(
    context: context,
    builder: (context) => _NewCategoryDialog(create: _createCategory),
  );

  Future<void> _rename(Category category, String name) =>
      ref.read(categoryRepositoryProvider).rename(category.id, name);

  Future<void> _pickColor(Category category) async {
    final initial = category.color != null
        ? Color(category.color!)
        : Theme.of(context).colorScheme.primary;
    final picked = await showAccentColorPicker(context, initial: initial);
    if (!mounted || picked == null) return;
    await ref
        .read(categoryRepositoryProvider)
        .setColor(category.id, picked.toARGB32());
  }

  Future<void> _delete(Category category) async {
    await ref.read(categoryRepositoryProvider).softDelete(category.id);
    if (!mounted) return;
    ref.read(categoryOrderProvider.notifier).removeCategory(category.id);
  }

  /// Keeps the database's `sortOrder` in step with the displayed real ids.
  Future<void> _persistRealOrder() async {
    final repo = ref.read(categoryRepositoryProvider);
    final categories = await repo.watchAll().first;
    final ordered = applyCategoryOrder(
      ref.read(categoryOrderProvider),
      categories,
    );
    await repo.reorder([
      for (final category in ordered)
        if (category != null) category.id,
    ]);
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
              padding: const EdgeInsets.symmetric(horizontal: 24),
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
                    child: Text(
                      l10n.manageCategories,
                      key: const ValueKey('category-title'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.display.copyWith(color: palette.ink),
                    ),
                  ),
                  const SizedBox(width: 12),
                  AppButton.primary(
                    key: const ValueKey('category-create'),
                    label: l10n.newCategory,
                    leadingIcon: const Icon(LucideIcons.plus, size: 16),
                    onPressed: _openCreateDialog,
                  ),
                ],
              ),
            ),
          ),
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
                    onRename: category == null
                        ? null
                        : (name) => _rename(category, name),
                    onPickColor: category == null
                        ? null
                        : () => unawaited(_pickColor(category)),
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
    );
  }
}

/// Compact creation dialog behind the header's 新建分类 button: one name
/// field, an inline conflict message, and cancel/create.
class _NewCategoryDialog extends StatefulWidget {
  const _NewCategoryDialog({required this.create});

  /// Creates the category; returns the conflict message, or null on success.
  final Future<String?> Function(String name) create;

  @override
  State<_NewCategoryDialog> createState() => _NewCategoryDialogState();
}

class _NewCategoryDialogState extends State<_NewCategoryDialog> {
  final _controller = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _controller.text.trim();
    if (name.isEmpty || _busy) return;
    setState(() => _busy = true);
    final error = await widget.create(name);
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop(name);
      return;
    }
    setState(() {
      _busy = false;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = _paletteOf(context);
    final l10n = AppLocalizations.of(context);
    return Dialog(
      key: const ValueKey('category-create-dialog'),
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: Container(
        width: 360,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: palette.card,
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(color: palette.line),
          boxShadow: kDialogShadow,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.newCategory,
              style: AppTextStyles.headline.copyWith(color: palette.ink),
            ),
            const SizedBox(height: 14),
            Container(
              height: AppSizes.field,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: palette.chip,
                borderRadius: BorderRadius.circular(AppRadii.button),
              ),
              alignment: Alignment.centerLeft,
              child: TextField(
                key: const ValueKey('category-new-name'),
                controller: _controller,
                autofocus: true,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
                style: AppTextStyles.body.copyWith(color: palette.ink),
                decoration: InputDecoration(
                  isCollapsed: true,
                  border: InputBorder.none,
                  hintText: l10n.newCategoryName,
                  hintStyle: AppTextStyles.body.copyWith(
                    color: palette.subWeak,
                  ),
                ),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  _error!,
                  key: const ValueKey('category-name-error'),
                  style: AppTextStyles.caption.copyWith(color: palette.danger),
                ),
              ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                AppButton.secondary(
                  key: const ValueKey('category-cancel'),
                  label: l10n.cancel,
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: 8),
                AppButton.primary(
                  key: const ValueKey('category-add'),
                  label: l10n.create,
                  onPressed: _submit,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// One 46px category row: drag handle, colour dot, name + count, delete.
class _CategoryRow extends StatefulWidget {
  const _CategoryRow({
    super.key,
    required this.id,
    required this.name,
    required this.color,
    required this.count,
    required this.system,
    required this.onRename,
    required this.onPickColor,
    required this.onDelete,
    required this.onDrop,
  });

  final String id;
  final String name;
  final int? color;
  final int count;
  final bool system;

  /// Null for the system 未分类 row, which cannot be renamed, recoloured or
  /// deleted.
  final Future<void> Function(String name)? onRename;
  final VoidCallback? onPickColor;
  final VoidCallback? onDelete;

  /// Receives the dragged row's id when it is dropped onto this row.
  final ValueChanged<String> onDrop;

  @override
  State<_CategoryRow> createState() => _CategoryRowState();
}

class _CategoryRowState extends State<_CategoryRow> {
  late final TextEditingController _nameController;
  late final FocusNode _nameFocus;
  bool _editing = false;
  bool _hovering = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.name);
    _nameFocus = FocusNode()..addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(covariant _CategoryRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_editing && oldWidget.name != widget.name) {
      _nameController.text = widget.name;
    }
  }

  @override
  void dispose() {
    _nameFocus.removeListener(_onFocusChanged);
    _nameFocus.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (!_nameFocus.hasFocus && _editing) {
      unawaited(_commitRename());
    }
  }

  void _beginRename() {
    if (widget.onRename == null) return;
    setState(() {
      _editing = true;
      _nameController.text = widget.name;
      _nameController.selection = TextSelection.collapsed(
        offset: widget.name.length,
      );
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _editing) _nameFocus.requestFocus();
    });
  }

  Future<void> _commitRename() async {
    if (!_editing) return;
    final next = _nameController.text.trim();
    setState(() => _editing = false);
    if (next.isEmpty || next == widget.name) {
      _nameController.text = widget.name;
      return;
    }
    try {
      await widget.onRename!(next);
    } on CategoryNameConflict {
      _restoreName();
    } on ArgumentError {
      _restoreName();
    }
  }

  void _restoreName() {
    _nameController.text = widget.name;
    if (mounted) setState(() {});
  }

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

    return DragTarget<String>(
      onWillAcceptWithDetails: (details) => details.data != widget.id,
      onAcceptWithDetails: (details) => widget.onDrop(details.data),
      builder: (context, candidateData, rejectedData) {
        final active = candidateData.isNotEmpty;
        return MouseRegion(
          onEnter: (_) => _setHovering(true),
          onExit: (_) => _setHovering(false),
          child: Container(
            height: AppSizes.row,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: active
                  ? palette.accentTint
                  : _hovering
                  ? palette.hover
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadii.block),
            ),
            child: Row(
              children: [
                LongPressDraggable<String>(
                  key: ValueKey('category-handle-${widget.id}'),
                  data: widget.id,
                  feedback: _dragFeedback(palette, color),
                  childWhenDragging: Opacity(
                    opacity: 0.3,
                    child: _handle(palette),
                  ),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.grab,
                    child: _handle(palette),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 24,
                  height: AppSizes.row,
                  child: Center(
                    child: widget.system || widget.onPickColor == null
                        ? _dot(palette, color)
                        : MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: GestureDetector(
                              key: ValueKey('category-color-${widget.id}'),
                              behavior: HitTestBehavior.opaque,
                              onTap: widget.onPickColor,
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: Center(child: _dot(palette, color)),
                              ),
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _editing
                      ? TextField(
                          key: ValueKey('category-name-field-${widget.id}'),
                          controller: _nameController,
                          focusNode: _nameFocus,
                          maxLines: 1,
                          style: AppTextStyles.body.copyWith(
                            color: palette.ink,
                          ),
                          decoration: const InputDecoration(
                            isCollapsed: true,
                            border: InputBorder.none,
                          ),
                          onSubmitted: (_) {
                            unawaited(_commitRename());
                            _nameFocus.unfocus();
                          },
                        )
                      : Row(
                          children: [
                            Flexible(
                              child: GestureDetector(
                                key: ValueKey('category-name-${widget.id}'),
                                behavior: HitTestBehavior.opaque,
                                onTap: widget.onRename == null
                                    ? null
                                    : _beginRename,
                                child: Text(
                                  widget.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.body.copyWith(
                                    color: palette.ink,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${widget.count}',
                              key: ValueKey('category-count-${widget.id}'),
                              maxLines: 1,
                              style: AppTextStyles.caption.copyWith(
                                color: palette.sub,
                              ),
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
                    icon: Icon(
                      LucideIcons.trash2,
                      size: 14,
                      color: palette.sub,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _handle(AppPalette palette) {
    return SizedBox(
      width: 24,
      height: AppSizes.row,
      child: Center(
        child: Icon(
          LucideIcons.gripVertical,
          size: 16,
          color: palette.subMuted,
        ),
      ),
    );
  }

  Widget _dot(AppPalette palette, Color color) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: palette.lineStrong),
      ),
    );
  }

  Widget _dragFeedback(AppPalette palette, Color color) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 240,
        height: AppSizes.row,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: palette.card,
          borderRadius: BorderRadius.circular(AppRadii.block),
          border: Border.all(color: palette.lineStrong),
          boxShadow: kCardShadow,
        ),
        child: Row(
          children: [
            Icon(LucideIcons.gripVertical, size: 16, color: palette.subMuted),
            const SizedBox(width: 8),
            _dot(palette, color),
            const SizedBox(width: 10),
            Flexible(
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
  }
}

AppPalette _paletteOf(BuildContext context) {
  final theme = Theme.of(context);
  return (theme.brightness == Brightness.light
          ? AppPalette.light
          : AppPalette.dark)
      .withAccent(theme.colorScheme.primary);
}

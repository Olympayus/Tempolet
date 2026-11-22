import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/generated/app_localizations.dart';
import '../../core/layout.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/ui/app_buttons.dart';
import '../../data/database/database.dart';
import '../../data/repositories/category_repository.dart';
import 'category_order.dart';
import '../../core/ui/color_wheel_picker.dart';

/// Built-in category colours (`v0.1.5 design` §8.6). Categories store the
/// ARGB value; new categories take the first unused colour.
const List<int> kCategoryColorChoices = [
  0xFFE5484D,
  0xFFF76808,
  0xFFF5B700,
  0xFF46A758,
  0xFF12A594,
  0xFF0091FF,
  0xFF6E56CF,
  0xFFD6409F,
];

/// The first built-in colour no category uses yet, cycling once all are
/// taken.
Color nextCategoryColor(List<Category> existing) {
  final used = {for (final category in existing) category.color};
  for (final value in kCategoryColorChoices) {
    if (!used.contains(value)) return Color(value);
  }
  return Color(
    kCategoryColorChoices[existing.length % kCategoryColorChoices.length],
  );
}

/// Opens the one category editor used by every surface and layout tier:
/// phone gets a bottom sheet, tablet and desktop a centred dialog.
Future<void> showCategoryEditor(BuildContext context, {Category? category}) {
  final phone = resolveAppLayout(context) == AppLayout.phone;
  if (phone) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: CategoryEditor(
          key: const ValueKey('category-editor-sheet'),
          category: category,
          sheet: true,
        ),
      ),
    );
  }
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => CategoryEditor(
      key: const ValueKey('category-editor'),
      category: category,
    ),
  );
}

/// Name + built-in colour palette; empty or unchanged values keep Save
/// disabled, duplicate names show an inline error, and a dirty close asks
/// before discarding.
class CategoryEditor extends ConsumerStatefulWidget {
  const CategoryEditor({super.key, this.category, this.sheet = false});

  /// Null for "new category".
  final Category? category;
  final bool sheet;

  @override
  ConsumerState<CategoryEditor> createState() => _CategoryEditorState();
}

class _CategoryEditorState extends ConsumerState<CategoryEditor> {
  late final TextEditingController _name;
  late final int? _initialColor;
  int? _color;
  String? _error;
  bool _saving = false;
  bool _allowPop = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.category?.name ?? '');
    _initialColor = widget.category?.color;
    final existing =
        ref.read(allCategoriesProvider).value ?? const <Category>[];
    // An existing category keeps its (possibly null) colour so a pure rename
    // is not dirty and never silently recolours it. New categories start on
    // the next unused palette colour.
    _color = widget.category != null
        ? widget.category!.color
        : nextCategoryColor(existing).toARGB32();
    _name.addListener(_onChanged);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (!mounted) return;
    final trimmed = _name.text.trim();
    final existing =
        ref.read(allCategoriesProvider).value ?? const <Category>[];
    final conflict =
        trimmed.isNotEmpty &&
        existing.any(
          (category) =>
              category.id != widget.category?.id &&
              category.name.toLowerCase() == trimmed.toLowerCase(),
        );
    setState(() {
      _error = conflict
          ? AppLocalizations.of(context).categoryNameExists
          : null;
    });
  }

  bool get _dirty =>
      _name.text.trim() != (widget.category?.name ?? '') ||
      _color != _initialColor;

  bool get _canSave {
    final trimmed = _name.text.trim();
    if (trimmed.isEmpty || !_dirty || _saving || _error != null) return false;
    return true;
  }

  Future<void> _save() async {
    if (!_canSave) return;
    final repo = ref.read(categoryRepositoryProvider);
    final l10n = AppLocalizations.of(context);
    setState(() => _saving = true);
    try {
      final existing = widget.category;
      if (existing == null) {
        final created = await repo.create(name: _name.text, color: _color);
        if (!mounted) return;
        ref.read(categoryOrderProvider.notifier).addCategory(created.id);
        await _persistOrder();
      } else {
        if (_name.text.trim() != existing.name) {
          await repo.rename(existing.id, _name.text);
        }
        if (_color != existing.color) {
          await repo.setColor(existing.id, _color);
        }
      }
      if (mounted) {
        _allowPop = true;
        Navigator.of(context).pop();
      }
    } on CategoryNameConflict {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = l10n.categoryNameExists;
        });
      }
    } on ArgumentError {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = l10n.categoryNameExists;
        });
      }
    }
  }

  /// Keeps `sortOrder` in step with the displayed list after a create.
  Future<void> _persistOrder() async {
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

  Future<void> _requestClose() async {
    if (!_dirty) {
      Navigator.of(context).pop();
      return;
    }
    final l10n = AppLocalizations.of(context);
    final discard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: const ValueKey('category-editor-discard'),
        content: Text(l10n.discardChangesTitle),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.keepEditing),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.discard),
          ),
        ],
      ),
    );
    if (discard == true && mounted) {
      _allowPop = true;
      Navigator.of(context).pop();
    }
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
    final existing = widget.category;

    final body = Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            existing == null ? l10n.newCategory : l10n.editCategory,
            style: AppTextStyles.headline.copyWith(color: palette.ink),
          ),
          const SizedBox(height: 16),
          TextField(
            key: const ValueKey('category-editor-name'),
            controller: _name,
            autofocus: true,
            maxLines: 1,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _save(),
            style: AppTextStyles.body.copyWith(color: palette.ink),
            decoration: InputDecoration(
              hintText: l10n.newCategoryName,
              errorText: null,
              isDense: true,
              filled: true,
              fillColor: palette.bg,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 11,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadii.field),
                borderSide: BorderSide(color: palette.line),
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              key: const ValueKey('category-editor-error'),
              style: AppTextStyles.caption.copyWith(color: palette.danger),
            ),
          ],
          const SizedBox(height: 16),
          // The palette swatches are gone: a colour wheel with an 「高级」
          // disclosure covers every colour instead of eight presets.
          ColorWheelPicker(
            key: const ValueKey('category-editor-wheel'),
            keyPrefix: 'category-editor-wheel',
            initial: Color(
              _color ??
                  nextCategoryColor(
                    ref.read(allCategoriesProvider).value ?? const <Category>[],
                  ).toARGB32(),
            ),
            onChanged: (color) => setState(() => _color = color.toARGB32()),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              AppButton.textLink(
                key: const ValueKey('category-editor-cancel'),
                label: l10n.cancel,
                onPressed: _requestClose,
              ),
              const SizedBox(width: 8),
              AppButton.primary(
                key: const ValueKey('category-editor-save'),
                label: l10n.save,
                onPressed: _canSave ? _save : null,
              ),
            ],
          ),
        ],
      ),
    );

    final content = Container(
      width: widget.sheet ? double.infinity : 360,
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(widget.sheet ? AppRadii.dialog : 0),
          topRight: Radius.circular(widget.sheet ? AppRadii.dialog : 0),
          bottomLeft: Radius.circular(widget.sheet ? 0 : AppRadii.dialog),
          bottomRight: Radius.circular(widget.sheet ? 0 : AppRadii.dialog),
        ),
      ),
      child: body,
    );

    final Widget result = widget.sheet
        ? SafeArea(top: false, child: content)
        : Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            child: content,
          );
    return PopScope(
      canPop: _allowPop || !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _requestClose();
      },
      child: result,
    );
  }
}

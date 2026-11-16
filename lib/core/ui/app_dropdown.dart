import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/app_tokens.dart';
import 'app_popover.dart';

const double _defaultTriggerHeight = AppSizes.field;
const double _defaultPanelWidth = 220;
const double _chevronSize = 14;
const double _hairline = 1;

/// Panel metrics from `docs/design/10-ui-refinement.md` §2.
const double _rowHeight = 36;
const double _panelVerticalPadding = 6;
const double _panelSlide = 2;
const Duration _panelAnimation = Duration(milliseconds: 120);

const EdgeInsets _triggerPadding = EdgeInsets.only(left: 10, right: 8);
const EdgeInsets _rowPadding = EdgeInsets.symmetric(horizontal: 10);
const SizedBox _triggerTextGap = SizedBox(width: 6);

/// One choice in an [AppDropdown].
@immutable
class AppDropdownItem<T> {
  const AppDropdownItem({required this.value, required this.label});

  final T value;
  final String label;
}

/// Self-drawn select control (`docs/design/10-ui-refinement.md` §2).
///
/// The trigger is a chip-filled pill (`triggerHeight` high, 7px radius, 13/ink
/// label, 14px chevron). Tapping it opens a 220-wide panel in an undimmed
/// overlay; the panel fades in over 120ms while sliding 2px down, and closes
/// on Escape, an outside tap, or a selection. Arrow keys move the active row
/// and Enter selects it.
class AppDropdown<T> extends StatefulWidget {
  const AppDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.triggerHeight = _defaultTriggerHeight,
    this.panelWidth = _defaultPanelWidth,
    this.semanticLabel,
  });

  final T value;
  final List<AppDropdownItem<T>> items;
  final ValueChanged<T> onChanged;
  final double triggerHeight;
  final double panelWidth;
  final String? semanticLabel;

  @override
  State<AppDropdown<T>> createState() => _AppDropdownState<T>();
}

class _AppDropdownState<T> extends State<AppDropdown<T>> {
  /// Shared by the trigger and the panel so a tap on the trigger does not
  /// count as an outside tap.
  final Object _tapRegionGroupId = Object();

  bool _open = false;
  VoidCallback? _closePanel;

  String get _selectedLabel {
    for (final item in widget.items) {
      if (item.value == widget.value) return item.label;
    }
    return '';
  }

  void _toggle() {
    if (_open) {
      _closePanel?.call();
      return;
    }
    _openPanel();
  }

  void _openPanel() {
    if (widget.items.isEmpty) return;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return;

    _open = true;
    showAppPopover<Object?>(
      context: context,
      anchor: box.localToGlobal(Offset.zero) & box.size,
      tapRegionGroupId: _tapRegionGroupId,
      builder: (overlayContext) {
        final scope = AppPopoverScope.maybeOf(overlayContext);
        _closePanel = scope == null ? null : () => scope.close(null);
        return _DropdownPanel<T>(
          items: widget.items,
          value: widget.value,
          panelWidth: widget.panelWidth,
          onSelected: _select,
        );
      },
    ).whenComplete(() {
      _open = false;
      _closePanel = null;
    });
  }

  void _select(AppDropdownItem<T> item) {
    widget.onChanged(item.value);
    _closePanel?.call();
  }

  @override
  void dispose() {
    _closePanel?.call();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = _paletteOf(context);
    final label = Text(
      _selectedLabel,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppTextStyles.body.copyWith(color: palette.ink),
    );
    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: TapRegion(
        groupId: _tapRegionGroupId,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _toggle,
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Fill a parent that gives a tight width (form fields), but
                // stay intrinsic inside a Row or a scroll view.
                final fills = constraints.hasTightWidth;
                return Container(
                  key: const ValueKey('app-dropdown-trigger'),
                  height: widget.triggerHeight,
                  padding: _triggerPadding,
                  decoration: BoxDecoration(
                    color: palette.chip,
                    borderRadius: BorderRadius.circular(AppRadii.button),
                  ),
                  child: Row(
                    mainAxisSize: fills ? MainAxisSize.max : MainAxisSize.min,
                    children: [
                      if (fills) Expanded(child: label) else label,
                      _triggerTextGap,
                      Icon(
                        LucideIcons.chevronDown,
                        key: const ValueKey('app-dropdown-chevron'),
                        size: _chevronSize,
                        color: palette.sub,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _DropdownPanel<T> extends StatefulWidget {
  const _DropdownPanel({
    required this.items,
    required this.value,
    required this.panelWidth,
    required this.onSelected,
  });

  final List<AppDropdownItem<T>> items;
  final T value;
  final double panelWidth;
  final ValueChanged<AppDropdownItem<T>> onSelected;

  @override
  State<_DropdownPanel<T>> createState() => _DropdownPanelState<T>();
}

class _DropdownPanelState<T> extends State<_DropdownPanel<T>> {
  final FocusNode _focusNode = FocusNode(debugLabel: 'AppDropdownPanel');
  late int _activeIndex = _initialIndex();
  bool _showActiveFill = false;

  int _initialIndex() {
    final index = widget.items.indexWhere((item) => item.value == widget.value);
    return index < 0 ? 0 : index;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _setActive(int index) {
    if (_showActiveFill && _activeIndex == index) return;
    setState(() {
      _activeIndex = index;
      _showActiveFill = true;
    });
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape) {
      AppPopoverScope.closeWith<Object?>(context);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      _setActive((_activeIndex + 1) % widget.items.length);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      _setActive(
        (_activeIndex - 1 + widget.items.length) % widget.items.length,
      );
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      widget.onSelected(widget.items[_activeIndex]);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final palette = _paletteOf(context);
    return Focus(
      focusNode: _focusNode,
      onKeyEvent: _handleKey,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: 1),
        duration: _panelAnimation,
        curve: Curves.easeOut,
        child: Container(
          key: const ValueKey('app-dropdown-panel'),
          width: widget.panelWidth,
          padding: const EdgeInsets.symmetric(
            vertical: _panelVerticalPadding,
          ),
          decoration: BoxDecoration(
            color: palette.card,
            borderRadius: BorderRadius.circular(AppRadii.card),
            border: Border.all(color: palette.line, width: _hairline),
            boxShadow: kDialogShadow,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < widget.items.length; i++)
                _DropdownRow<T>(
                  key: ValueKey('app-dropdown-item-${widget.items[i].value}'),
                  item: widget.items[i],
                  selected: widget.items[i].value == widget.value,
                  active: _showActiveFill && i == _activeIndex,
                  palette: palette,
                  onTap: () => widget.onSelected(widget.items[i]),
                  onHover: () => _setActive(i),
                ),
            ],
          ),
        ),
        builder: (context, value, child) => Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, -_panelSlide * (1 - value)),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _DropdownRow<T> extends StatelessWidget {
  const _DropdownRow({
    super.key,
    required this.item,
    required this.selected,
    required this.active,
    required this.palette,
    required this.onTap,
    required this.onHover,
  });

  final AppDropdownItem<T> item;
  final bool selected;
  final bool active;
  final AppPalette palette;
  final VoidCallback onTap;
  final VoidCallback onHover;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => onHover(),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: _rowHeight,
          padding: _rowPadding,
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            color: active ? palette.hover : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadii.chip),
          ),
          child: Text(
            item.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.body.copyWith(
              color: palette.ink,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              fontVariations: [
                FontVariation('wght', selected ? 600.0 : 400.0),
              ],
            ),
          ),
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

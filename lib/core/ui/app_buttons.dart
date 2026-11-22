import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../layout.dart';
import '../theme/app_tokens.dart';
import 'fitted_label.dart';
import 'touch_target.dart';

const double _iconButtonSize = AppSizes.control;
const double _iconSize = 18;

const EdgeInsets _primaryPadding = EdgeInsets.symmetric(horizontal: 14);

/// Gap between the primary tier's leading glyph and its label.
const double _primaryIconGap = 6;
const EdgeInsets _secondaryPadding = EdgeInsets.symmetric(horizontal: 12);
const EdgeInsets _textLinkPadding = EdgeInsets.symmetric(
  horizontal: 2,
  vertical: 6,
);

/// 13px semibold label used by the solid primary button.
final TextStyle _primaryLabelStyle = AppTextStyles.body.copyWith(
  fontWeight: FontWeight.w600,
  fontVariations: const [FontVariation('wght', 600)],
);

/// Square icon button used across the shell (`docs/design/05-components.md`
/// §1).
///
/// 30×30 with a 7px radius and a `hover` wash on pointer-over. Material-free:
/// [MouseRegion] + [GestureDetector], with an optional [tooltip].
class AppIconButton extends StatefulWidget {
  const AppIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
  });

  final Widget icon;
  final VoidCallback? onPressed;
  final String? tooltip;

  @override
  State<AppIconButton> createState() => _AppIconButtonState();
}

class _AppIconButtonState extends State<AppIconButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final palette = _paletteOf(context);
    final enabled = widget.onPressed != null;
    final tooltip = widget.tooltip;
    final visual = Container(
      width: _iconButtonSize,
      height: _iconButtonSize,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _hovering && enabled ? palette.hover : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadii.button),
      ),
      child: IconTheme(
        data: IconThemeData(
          size: _iconSize,
          color: enabled ? palette.ink : palette.subMuted,
        ),
        child: widget.icon,
      ),
    );
    // Touch layouts grow the tappable area to 44×44; the 30×30 visual and the
    // desktop footprint stay unchanged (`design spec` §8.7).
    final target = isTouchLayout(resolveAppLayout(context))
        ? TouchTarget(child: visual)
        : visual;
    final button = Semantics(
      button: true,
      enabled: enabled,
      hint: tooltip == null || tooltip.isEmpty ? null : tooltip,
      child: FocusableActionDetector(
        enabled: enabled,
        mouseCursor: enabled
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        shortcuts: _activateShortcuts,
        actions: _activateActions(widget.onPressed),
        child: MouseRegion(
          cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
          onEnter: (_) => _setHovering(true),
          onExit: (_) => _setHovering(false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onPressed,
            child: target,
          ),
        ),
      ),
    );
    if (tooltip == null || tooltip.isEmpty) return button;
    return Tooltip(message: tooltip, child: button);
  }

  void _setHovering(bool hovering) {
    if (_hovering == hovering) return;
    setState(() => _hovering = hovering);
  }
}

enum _AppButtonKind { primary, secondary, textLink }

/// The three button tiers from `docs/design/05-components.md` §1: solid
/// accent primary, chip secondary and a bare accent text link.
///
/// Material-free: [MouseRegion] + [GestureDetector]; a null [onPressed] renders
/// the disabled tier. The secondary tier fills with `hover` on pointer-over.
class AppButton extends StatefulWidget {
  const AppButton.primary({
    super.key,
    required this.label,
    this.leadingIcon,
    this.onPressed,
  }) : _kind = _AppButtonKind.primary;

  const AppButton.secondary({super.key, required this.label, this.onPressed})
    : _kind = _AppButtonKind.secondary,
      leadingIcon = null;

  const AppButton.textLink({super.key, required this.label, this.onPressed})
    : _kind = _AppButtonKind.textLink,
      leadingIcon = null;

  final String label;

  /// Optional 16px glyph painted before the label (primary tier only).
  final Widget? leadingIcon;
  final VoidCallback? onPressed;
  final _AppButtonKind _kind;

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  bool _hovering = false;

  void _setHovering(bool hovering) {
    if (_hovering == hovering) return;
    setState(() => _hovering = hovering);
  }

  @override
  Widget build(BuildContext context) {
    final palette = _paletteOf(context);
    final enabled = widget.onPressed != null;
    final hoverEnabled = widget._kind == _AppButtonKind.secondary && enabled;
    return Semantics(
      button: true,
      enabled: enabled,
      child: FocusableActionDetector(
        enabled: enabled,
        mouseCursor: enabled
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        shortcuts: _activateShortcuts,
        actions: _activateActions(widget.onPressed),
        child: MouseRegion(
          cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
          onEnter: hoverEnabled ? (_) => _setHovering(true) : null,
          onExit: hoverEnabled ? (_) => _setHovering(false) : null,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onPressed,
            child: switch (widget._kind) {
              _AppButtonKind.primary => Container(
                height: AppSizes.control,
                padding: _primaryPadding,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: enabled ? palette.accent : palette.chip,
                  borderRadius: BorderRadius.circular(AppRadii.button),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.leadingIcon != null) ...[
                      IconTheme(
                        data: IconThemeData(
                          color: enabled ? Colors.white : palette.subMuted,
                        ),
                        child: widget.leadingIcon!,
                      ),
                      const SizedBox(width: _primaryIconGap),
                    ],
                    Flexible(
                      child: FittedLabel(
                        widget.label,
                        style: _primaryLabelStyle.copyWith(
                          color: enabled ? Colors.white : palette.subMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              _AppButtonKind.secondary => Container(
                height: AppSizes.control,
                padding: _secondaryPadding,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _hovering && enabled ? palette.hover : palette.chip,
                  borderRadius: BorderRadius.circular(AppRadii.button),
                ),
                child: FittedLabel(
                  widget.label,
                  style: AppTextStyles.body.copyWith(
                    color: enabled ? palette.ink : palette.subMuted,
                  ),
                ),
              ),
              _AppButtonKind.textLink => Padding(
                padding: _textLinkPadding,
                child: FittedLabel(
                  widget.label,
                  style: AppTextStyles.body.copyWith(
                    color: enabled ? palette.accent : palette.subMuted,
                  ),
                ),
              ),
            },
          ),
        ),
      ),
    );
  }
}

/// Enter/Space activate the focused control.
const Map<ShortcutActivator, Intent> _activateShortcuts = {
  SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
  SingleActivator(LogicalKeyboardKey.numpadEnter): ActivateIntent(),
  SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
};

Map<Type, Action<Intent>> _activateActions(VoidCallback? onActivate) => {
  ActivateIntent: CallbackAction<ActivateIntent>(
    onInvoke: (_) {
      onActivate?.call();
      return null;
    },
  ),
  ButtonActivateIntent: CallbackAction<ButtonActivateIntent>(
    onInvoke: (_) {
      onActivate?.call();
      return null;
    },
  ),
};

AppPalette _paletteOf(BuildContext context) {
  final theme = Theme.of(context);
  return (theme.brightness == Brightness.light
          ? AppPalette.light
          : AppPalette.dark)
      .withAccent(theme.colorScheme.primary);
}

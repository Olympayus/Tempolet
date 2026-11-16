import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

const double _iconButtonSize = AppSizes.control;
const double _iconSize = 18;

const EdgeInsets _primaryPadding = EdgeInsets.symmetric(horizontal: 14);
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
    final button = MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => _setHovering(true),
      onExit: (_) => _setHovering(false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onPressed,
        child: Container(
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
        ),
      ),
    );
    final tooltip = widget.tooltip;
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
/// the disabled tier.
class AppButton extends StatelessWidget {
  const AppButton.primary({
    super.key,
    required this.label,
    this.onPressed,
  }) : _kind = _AppButtonKind.primary;

  const AppButton.secondary({
    super.key,
    required this.label,
    this.onPressed,
  }) : _kind = _AppButtonKind.secondary;

  const AppButton.textLink({
    super.key,
    required this.label,
    this.onPressed,
  }) : _kind = _AppButtonKind.textLink;

  final String label;
  final VoidCallback? onPressed;
  final _AppButtonKind _kind;

  @override
  Widget build(BuildContext context) {
    final palette = _paletteOf(context);
    final enabled = onPressed != null;
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: switch (_kind) {
          _AppButtonKind.primary => Container(
            height: AppSizes.control,
            padding: _primaryPadding,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: enabled ? palette.accent : palette.chip,
              borderRadius: BorderRadius.circular(AppRadii.button),
            ),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _primaryLabelStyle.copyWith(
                color: enabled ? Colors.white : palette.subMuted,
              ),
            ),
          ),
          _AppButtonKind.secondary => Container(
            height: AppSizes.control,
            padding: _secondaryPadding,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: palette.chip,
              borderRadius: BorderRadius.circular(AppRadii.button),
            ),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.body.copyWith(
                color: enabled ? palette.ink : palette.subMuted,
              ),
            ),
          ),
          _AppButtonKind.textLink => Padding(
            padding: _textLinkPadding,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.body.copyWith(
                color: enabled ? palette.accent : palette.subMuted,
              ),
            ),
          ),
        },
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

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/app_tokens.dart';

/// Invisible hit target around the 14px completion glyph.
const double _checkHitSize = 24;

const double _checkBorder = 1.5;

/// Difference between the glyph box and its check mark.
const double _checkIconInset = 4;

const double _checkPressedScale = 0.92;

const Duration _checkAnimation = Duration(milliseconds: 90);

/// Completion circle used by reminder rows, plan rows and the preview popover
/// (`docs/design/05-components.md` §4).
///
/// The glyph is [size] (14 by default); the tappable area is always 24×24.
class AppCheckCircle extends StatefulWidget {
  const AppCheckCircle({
    super.key,
    required this.checked,
    this.onTap,
    this.size = 14,
  });

  final bool checked;
  final VoidCallback? onTap;
  final double size;

  @override
  State<AppCheckCircle> createState() => _AppCheckCircleState();
}

class _AppCheckCircleState extends State<AppCheckCircle> {
  bool _pressed = false;

  void _setPressed(bool pressed) {
    if (_pressed == pressed) return;
    setState(() => _pressed = pressed);
  }

  @override
  Widget build(BuildContext context) {
    final palette = _paletteOf(context);
    final enabled = widget.onTap != null;
    final glyph = Container(
      key: const ValueKey('check-circle-glyph'),
      width: widget.size,
      height: widget.size,
      alignment: Alignment.center,
      decoration: widget.checked
          ? BoxDecoration(color: palette.accent, shape: BoxShape.circle)
          : BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: palette.subWeak, width: _checkBorder),
            ),
      child: widget.checked
          ? Icon(
              LucideIcons.check,
              size: widget.size - _checkIconInset,
              color: Colors.white,
            )
          : null,
    );

    return SizedBox(
      width: _checkHitSize,
      height: _checkHitSize,
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          onTapDown: enabled ? (_) => _setPressed(true) : null,
          onTapUp: enabled ? (_) => _setPressed(false) : null,
          onTapCancel: enabled ? () => _setPressed(false) : null,
          child: Center(
            child: AnimatedScale(
              scale: _pressed ? _checkPressedScale : 1,
              duration: _checkAnimation,
              curve: Curves.easeOut,
              child: glyph,
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

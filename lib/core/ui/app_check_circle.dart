import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/app_tokens.dart';

/// Invisible hit target around the 14px completion glyph.
const double _checkHitSize = 24;

const double _checkBorder = 1.5;

/// Difference between the glyph box and its check mark.
const double _checkIconInset = 4;

const double _checkPressedScale = 0.92;

/// Scale the check mark starts from while it fades in.
const double _checkHiddenScale = 0.5;

/// Scale the solid fill starts from while it grows under external progress.
const double _checkFillStartScale = 0.6;

/// Press feedback (`docs/design/08-motion.md` §2).
const Duration _checkPressAnimation = Duration(milliseconds: 90);

/// Border, fill and check transition for the binary state.
const Duration _checkFillAnimation = Duration(milliseconds: 120);

/// Completion circle used by reminder rows, plan rows and the preview popover
/// (`docs/design/05-components.md` §4).
///
/// The glyph is [size] (14 by default); the tappable area is always 24×24.
///
/// With [progress] null the circle animates between the binary [checked]
/// states. When [progress] is set (0..1) the caller drives the fill instead:
/// the ring fades out, the solid circle grows from [_checkFillStartScale] and
/// the check mark scales up.
class AppCheckCircle extends StatefulWidget {
  const AppCheckCircle({
    super.key,
    required this.checked,
    this.onTap,
    this.size = 14,
    this.progress,
    this.borderColor,
  });

  final bool checked;
  final VoidCallback? onTap;
  final double size;

  /// External fill progress. Null keeps the binary [checked] behaviour.
  final double? progress;

  /// Unchecked border colour; defaults to `subWeak` (overdue cards pass
  /// `danger`).
  final Color? borderColor;

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
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final pressDuration = reduceMotion ? Duration.zero : _checkPressAnimation;
    final fillDuration = reduceMotion ? Duration.zero : _checkFillAnimation;
    final progress = widget.progress?.clamp(0.0, 1.0).toDouble();
    final borderColor = widget.borderColor ?? palette.subWeak;
    final checkIcon = Icon(
      LucideIcons.check,
      size: widget.size - _checkIconInset,
      color: Colors.white,
    );

    final Widget glyph;
    if (progress == null) {
      glyph = AnimatedContainer(
        key: const ValueKey('check-circle-glyph'),
        duration: fillDuration,
        curve: Curves.easeOut,
        width: widget.size,
        height: widget.size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: widget.checked ? palette.accent : Colors.transparent,
          shape: BoxShape.circle,
          border: Border.all(
            color: widget.checked ? Colors.transparent : borderColor,
            width: _checkBorder,
          ),
        ),
        child: AnimatedScale(
          scale: widget.checked ? 1 : _checkHiddenScale,
          duration: fillDuration,
          curve: Curves.easeOut,
          child: AnimatedOpacity(
            opacity: widget.checked ? 1 : 0,
            duration: fillDuration,
            curve: Curves.easeOut,
            child: checkIcon,
          ),
        ),
      );
    } else {
      glyph = SizedBox(
        key: const ValueKey('check-circle-glyph'),
        width: widget.size,
        height: widget.size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Opacity(
              key: const ValueKey('check-circle-ring'),
              opacity: 1 - progress,
              child: Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: borderColor, width: _checkBorder),
                ),
              ),
            ),
            Opacity(
              key: const ValueKey('check-circle-fill'),
              opacity: progress,
              child: Transform.scale(
                scale:
                    _checkFillStartScale +
                    (1 - _checkFillStartScale) * progress,
                child: Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    color: palette.accent,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
            Opacity(
              opacity: progress,
              child: Transform.scale(
                scale: _checkHiddenScale + (1 - _checkHiddenScale) * progress,
                child: checkIcon,
              ),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      width: _checkHitSize,
      height: _checkHitSize,
      child: Semantics(
        checked: widget.checked,
        enabled: enabled,
        child: FocusableActionDetector(
          enabled: enabled,
          mouseCursor: enabled
              ? SystemMouseCursors.click
              : SystemMouseCursors.basic,
          shortcuts: const {
            SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
            SingleActivator(LogicalKeyboardKey.numpadEnter): ActivateIntent(),
            SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
          },
          actions: {
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                widget.onTap?.call();
                return null;
              },
            ),
            ButtonActivateIntent: CallbackAction<ButtonActivateIntent>(
              onInvoke: (_) {
                widget.onTap?.call();
                return null;
              },
            ),
          },
          child: MouseRegion(
            cursor: enabled
                ? SystemMouseCursors.click
                : SystemMouseCursors.basic,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onTap,
              onTapDown: enabled ? (_) => _setPressed(true) : null,
              onTapUp: enabled ? (_) => _setPressed(false) : null,
              onTapCancel: enabled ? () => _setPressed(false) : null,
              child: Center(
                child: AnimatedScale(
                  scale: _pressed ? _checkPressedScale : 1,
                  duration: pressDuration,
                  curve: Curves.easeOut,
                  child: glyph,
                ),
              ),
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

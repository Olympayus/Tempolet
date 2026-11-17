import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/app_tokens.dart';

/// Invisible hit target around the 16px square selection glyph. Matches the
/// completion circle's 24×24 target.
const double _checkboxHitSize = 24;

const double _checkboxGlyphSize = 16;

const double _checkboxBorder = 1.5;

const double _checkboxRadius = 4;

/// The white check mark inside a selected square.
const double _checkboxCheckSize = 11;

const Duration _checkboxAnimation = Duration(milliseconds: 120);

/// Square multi-select checkbox used by list rows in selection mode.
///
/// The glyph is 16×16; the tappable area is always 24×24, matching the
/// completion circle. The fill animates over 120ms, or instantly when the
/// platform asks for reduced motion.
class AppListCheckbox extends StatefulWidget {
  const AppListCheckbox({super.key, required this.checked, this.onTap});

  final bool checked;
  final VoidCallback? onTap;

  @override
  State<AppListCheckbox> createState() => _AppListCheckboxState();
}

class _AppListCheckboxState extends State<AppListCheckbox> {
  @override
  Widget build(BuildContext context) {
    final palette = _paletteOf(context);
    final enabled = widget.onTap != null;
    final duration = MediaQuery.of(context).disableAnimations
        ? Duration.zero
        : _checkboxAnimation;
    final glyph = AnimatedContainer(
      key: const ValueKey('list-checkbox-glyph'),
      duration: duration,
      curve: Curves.easeOut,
      width: _checkboxGlyphSize,
      height: _checkboxGlyphSize,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: widget.checked ? palette.accent : null,
        borderRadius: BorderRadius.circular(_checkboxRadius),
        border: widget.checked
            ? null
            : Border.all(color: palette.subWeak, width: _checkboxBorder),
      ),
      child: widget.checked
          ? const Icon(
              LucideIcons.check,
              size: _checkboxCheckSize,
              color: Colors.white,
            )
          : null,
    );

    return SizedBox(
      width: _checkboxHitSize,
      height: _checkboxHitSize,
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
              child: Center(child: glyph),
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

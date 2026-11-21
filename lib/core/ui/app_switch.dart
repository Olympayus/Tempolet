import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../layout.dart';
import '../theme/app_tokens.dart';
import 'touch_target.dart';

const double _switchWidth = 40;
const double _switchHeight = 24;
const double _switchThumb = 20;
const double _switchInset = 2;

const Duration _switchAnimation = Duration(milliseconds: 90);

/// iOS-style 40×24 desktop switch (`docs/design/05-components.md`).
///
/// The parent owns the state: [onChanged] always reports the negated value and
/// the caller feeds the new one back through [value].
class AppSwitch extends StatelessWidget {
  const AppSwitch({super.key, required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = _paletteOf(context);
    final visual = SizedBox(
      width: _switchWidth,
      height: _switchHeight,
      child: AnimatedContainer(
        duration: _switchAnimation,
        curve: Curves.easeOut,
        padding: const EdgeInsets.all(_switchInset),
        decoration: BoxDecoration(
          color: value ? palette.accent : palette.subWeak,
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
        child: AnimatedAlign(
          duration: _switchAnimation,
          curve: Curves.easeOut,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: _switchThumb,
            height: _switchThumb,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: kCardShadow,
            ),
          ),
        ),
      ),
    );
    // The 40×24 visual is unchanged; touch layouts tap across 44×44.
    final target = isTouchLayout(resolveAppLayout(context))
        ? TouchTarget(child: visual)
        : visual;
    return Semantics(
      toggled: value,
      child: FocusableActionDetector(
        mouseCursor: SystemMouseCursors.click,
        shortcuts: _activateShortcuts,
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              onChanged(!value);
              return null;
            },
          ),
          ButtonActivateIntent: CallbackAction<ButtonActivateIntent>(
            onInvoke: (_) {
              onChanged(!value);
              return null;
            },
          ),
        },
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onChanged(!value),
            child: target,
          ),
        ),
      ),
    );
  }
}

/// Enter/Space toggle the focused switch.
const Map<ShortcutActivator, Intent> _activateShortcuts = {
  SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
  SingleActivator(LogicalKeyboardKey.numpadEnter): ActivateIntent(),
  SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
};

AppPalette _paletteOf(BuildContext context) {
  final theme = Theme.of(context);
  return (theme.brightness == Brightness.light
          ? AppPalette.light
          : AppPalette.dark)
      .withAccent(theme.colorScheme.primary);
}

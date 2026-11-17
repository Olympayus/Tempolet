import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/app_tokens.dart';

/// Height of the self-drawn title bar (`docs/design/10-ui-refinement.md` §4).
const double kTitlebarHeight = 32;

/// Width of each of the three window buttons; the native hit-test in
/// `windows/runner/win32_window.cpp` uses the same 46 logical px.
const double kTitlebarButtonWidth = 46;

/// Windows' close-button hover red.
const Color kTitlebarCloseHover = Color(0xFFC42B1C);

/// App name shown at the left end of the title bar.
const String kTitlebarAppName = 'Tempolet';

// rgba(0,0,0,.06) on paper and rgba(255,255,255,.06) in the dark.
const Color _hoverFillLight = Color(0x0F000000);
const Color _hoverFillDark = Color(0x0FFFFFFF);

const double _iconSize = 12;

/// Which title bar button the native pointer is over.
///
/// The runner owns title bar hit-testing, so this is pushed from C++ over the
/// `tempolet/titlebar` channel; Flutter only paints the hover state.
enum TitlebarHover { none, min, max, close }

/// The 32px self-drawn title bar (design `10-ui-refinement` §4, decision D60).
///
/// Visual only: the runner answers `WM_NCHITTEST` and turns clicks into the
/// matching system command, so the buttons sit under [IgnorePointer] and never
/// receive pointer events themselves. Dragging, double-click maximize, resize
/// borders, Snap and the system menu are all native.
class AppTitlebar extends StatelessWidget {
  const AppTitlebar({
    super.key,
    required this.maximized,
    required this.hover,
    required this.onMinimize,
    required this.onMaximizeRestore,
    required this.onClose,
  });

  /// Whether the window is maximized; the middle button then shows "restore".
  final bool maximized;

  /// Button currently hovered, as reported by the native title bar.
  final TitlebarHover hover;

  final VoidCallback onMinimize;
  final VoidCallback onMaximizeRestore;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette =
        (theme.brightness == Brightness.light
                ? AppPalette.light
                : AppPalette.dark)
            .withAccent(theme.colorScheme.primary);
    final hoverFill = theme.brightness == Brightness.light
        ? _hoverFillLight
        : _hoverFillDark;

    return SizedBox(
      height: kTitlebarHeight,
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              key: const ValueKey('titlebar-surface'),
              decoration: BoxDecoration(
                color: palette.rail,
                border: Border(bottom: BorderSide(color: palette.line)),
              ),
            ),
          ),
          Row(
            children: [
              const SizedBox(width: 14),
              Text(
                kTitlebarAppName,
                style: AppTextStyles.secondary.copyWith(color: palette.sub),
              ),
              const Spacer(),
              // C++ owns the clicks and hover; this row is paint only.
              IgnorePointer(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _TitlebarButton(
                      buttonKey: const ValueKey('titlebar-min'),
                      icon: LucideIcons.minus,
                      background: hover == TitlebarHover.min
                          ? hoverFill
                          : Colors.transparent,
                      foreground: palette.ink,
                      onTap: onMinimize,
                    ),
                    _TitlebarButton(
                      buttonKey: const ValueKey('titlebar-max'),
                      icon: maximized ? LucideIcons.copy : LucideIcons.square,
                      background: hover == TitlebarHover.max
                          ? hoverFill
                          : Colors.transparent,
                      foreground: palette.ink,
                      onTap: onMaximizeRestore,
                    ),
                    _TitlebarButton(
                      buttonKey: const ValueKey('titlebar-close'),
                      icon: LucideIcons.x,
                      background: hover == TitlebarHover.close
                          ? kTitlebarCloseHover
                          : Colors.transparent,
                      foreground: hover == TitlebarHover.close
                          ? Colors.white
                          : palette.ink,
                      onTap: onClose,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TitlebarButton extends StatelessWidget {
  const _TitlebarButton({
    required this.buttonKey,
    required this.icon,
    required this.background,
    required this.foreground,
    required this.onTap,
  });

  final Key buttonKey;
  final IconData icon;
  final Color background;
  final Color foreground;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        key: buttonKey,
        width: kTitlebarButtonWidth,
        height: kTitlebarHeight,
        decoration: BoxDecoration(color: background),
        child: Icon(icon, size: _iconSize, color: foreground),
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
// The 0.5.x bridge is still the app's window API for v0.1.x (see
// desktop/window_service.dart); v0.1.3 only adds the maximize listener here.
import 'package:window_manager/legacy.dart';

import '../core/platform.dart';
import '../core/ui/app_titlebar.dart';
import '../desktop/titlebar_channel.dart';
import 'features/shell/icon_rail.dart';

/// App chrome: the self-drawn 32px title bar (desktop), the 54px icon rail
/// plus the routed content area.
class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  TitlebarChannel? _titlebar;
  _MaximizeListener? _maximizeListener;
  TitlebarHover _hover = TitlebarHover.none;
  bool _maximized = false;

  bool get _hasDesktopChrome => isDesktopTarget(defaultTargetPlatform);

  @override
  void initState() {
    super.initState();
    if (!_hasDesktopChrome) return;

    final titlebar = TitlebarChannel()..initialize();
    titlebar.hover.addListener(_onHoverChanged);
    _titlebar = titlebar;

    final listener = _MaximizeListener(_syncMaximized);
    windowManager.addListener(listener);
    _maximizeListener = listener;
    unawaited(_syncMaximized());
  }

  @override
  void dispose() {
    _titlebar?.hover.removeListener(_onHoverChanged);
    _titlebar?.dispose();
    if (_maximizeListener != null) {
      windowManager.removeListener(_maximizeListener!);
    }
    super.dispose();
  }

  void _onHoverChanged() {
    final hover = _titlebar?.hover.value ?? TitlebarHover.none;
    if (hover == _hover) return;
    setState(() => _hover = hover);
  }

  Future<void> _syncMaximized() async {
    final maximized = await windowManager.isMaximized();
    if (!mounted || maximized == _maximized) return;
    setState(() => _maximized = maximized);
  }

  Future<void> _toggleMaximize() async {
    if (await windowManager.isMaximized()) {
      await windowManager.unmaximize();
    } else {
      await windowManager.maximize();
    }
  }

  void _onDestinationSelected(int index) {
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = Row(
      children: [
        IconRail(
          selectedIndex: widget.navigationShell.currentIndex,
          onSelected: _onDestinationSelected,
        ),
        Expanded(child: widget.navigationShell),
      ],
    );

    if (!_hasDesktopChrome) {
      return Scaffold(body: content);
    }

    return Scaffold(
      body: Column(
        children: [
          AppTitlebar(
            maximized: _maximized,
            hover: _hover,
            onMinimize: () => unawaited(windowManager.minimize()),
            onMaximizeRestore: () => unawaited(_toggleMaximize()),
            onClose: () => unawaited(windowManager.close()),
          ),
          Expanded(child: content),
        ],
      ),
    );
  }
}

/// Keeps the Flutter title bar's middle button in sync with the native window
/// state, however the window was maximized (button, double-click, Snap, Aero).
class _MaximizeListener extends WindowListener {
  _MaximizeListener(this.onChanged);

  final VoidCallback onChanged;

  @override
  void onWindowMaximize() => onChanged();

  @override
  void onWindowUnmaximize() => onChanged();
}

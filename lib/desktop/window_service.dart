import 'dart:io';

import 'package:launch_at_startup/launch_at_startup.dart';
// window_manager 0.6 moved to the nativeapi Window API; the legacy bridge
// keeps the stable 0.5.x API for v0.1.0 (migrate in v0.2.0).
import 'package:window_manager/legacy.dart';

/// Pure rule: closing the window hides to tray when the setting is on.
bool shouldHideOnClose(bool minimizeToTray) => minimizeToTray;

class WindowService {
  WindowService({this.minimizeToTray = _defaultSetting});

  static bool _defaultSetting() => true;

  final bool Function() minimizeToTray;
  _CloseListener? _listener;

  Future<void> initialize({
    required bool Function() minimizeToTray,
    required Future<void> Function() onHidden,
  }) async {
    await windowManager.ensureInitialized();
    await windowManager.setPreventClose(true);
    _listener = _CloseListener(
      minimizeToTray: minimizeToTray,
      onHidden: onHidden,
    );
    windowManager.addListener(_listener!);
  }

  Future<void> showWindow() async {
    if (await windowManager.isMinimized()) {
      await windowManager.restore();
    }
    await windowManager.show();
    await windowManager.focus();
  }

  Future<void> dispose() async {
    if (_listener != null) {
      windowManager.removeListener(_listener!);
      _listener = null;
    }
  }
}

class _CloseListener extends WindowListener {
  _CloseListener({required this.minimizeToTray, required this.onHidden});

  final bool Function() minimizeToTray;
  final Future<void> Function() onHidden;

  @override
  void onWindowClose() {
    if (shouldHideOnClose(minimizeToTray())) {
      windowManager.hide();
      onHidden();
    } else {
      windowManager.destroy();
    }
  }
}

/// Applies the startup-registration setting to Windows.
Future<void> syncLaunchAtStartup(bool enabled) async {
  launchAtStartup.setup(
    appName: 'Tempolet',
    appPath: Platform.resolvedExecutable,
  );
  if (enabled) {
    await launchAtStartup.enable();
  } else {
    await launchAtStartup.disable();
  }
}

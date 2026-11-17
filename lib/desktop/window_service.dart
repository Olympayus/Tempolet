import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show Rect, Size;

import 'package:flutter/foundation.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:shared_preferences/shared_preferences.dart';
// window_manager 0.6 moved to the nativeapi Window API; the legacy bridge
// keeps the stable 0.5.x API for v0.1.0 (migrate in v0.2.0).
import 'package:window_manager/legacy.dart';

import '../core/platform.dart';

/// Pure rule: closing the window hides to tray when the setting is on.
bool shouldHideOnClose(bool minimizeToTray) => minimizeToTray;

/// Desktop window defaults.
const Size defaultWindowSize = Size(1280, 820);
const Size minimumWindowSize = Size(960, 600);

/// SharedPreferences key holding the last window bounds.
const String windowBoundsPrefKey = 'window_bounds';

/// Virtual desktop envelope used to reject stale saved bounds. Windows uses
/// signed virtual coordinates (a monitor left of the primary has negative x),
/// so this is deliberately far wider than any single display. A saved window
/// that does not intersect it at all is treated as off-screen.
const Rect virtualDesktopEnvelope = Rect.fromLTRB(
  -16384,
  -16384,
  16384,
  16384,
);

/// Serialises bounds for SharedPreferences.
String encodeWindowBounds(Rect bounds) =>
    '${bounds.left},${bounds.top},${bounds.width},${bounds.height}';

/// Parses [encodeWindowBounds] output; malformed or non-finite data is
/// ignored so a corrupted preference cannot keep the app from starting.
Rect? decodeWindowBounds(String? raw) {
  if (raw == null) return null;
  final parts = raw.split(',');
  if (parts.length != 4) return null;
  final values = <double>[];
  for (final part in parts) {
    final value = double.tryParse(part);
    if (value == null || !value.isFinite) return null;
    values.add(value);
  }
  return Rect.fromLTWH(values[0], values[1], values[2], values[3]);
}

/// Moves [bounds] fully inside [virtualDesktopEnvelope], preserving its size.
/// Never throws: bounds larger than the envelope pin their leading edge to the
/// envelope edge instead of producing an inverted `clamp` range.
Rect clampWindowBounds(Rect bounds) {
  final maxLeft = math.max(
    virtualDesktopEnvelope.left,
    virtualDesktopEnvelope.right - bounds.width,
  );
  final maxTop = math.max(
    virtualDesktopEnvelope.top,
    virtualDesktopEnvelope.bottom - bounds.height,
  );
  return Rect.fromLTWH(
    bounds.left.clamp(virtualDesktopEnvelope.left, maxLeft),
    bounds.top.clamp(virtualDesktopEnvelope.top, maxTop),
    bounds.width,
    bounds.height,
  );
}

/// Pure restore rule: accepts saved bounds only when they are finite, at
/// least [minimumWindowSize], no larger than the virtual desktop (a corrupted
/// saved size must not crash the clamp) and intersect the virtual desktop
/// (otherwise a disconnected monitor could strand the window). Accepted bounds
/// are clamped fully back on-screen.
Rect? restoreWindowBounds(Rect? saved) {
  if (saved == null) return null;
  if (!saved.left.isFinite ||
      !saved.top.isFinite ||
      !saved.width.isFinite ||
      !saved.height.isFinite) {
    return null;
  }
  if (saved.width < minimumWindowSize.width ||
      saved.height < minimumWindowSize.height) {
    return null;
  }
  if (saved.width > virtualDesktopEnvelope.width ||
      saved.height > virtualDesktopEnvelope.height) {
    return null;
  }
  if (saved.intersect(virtualDesktopEnvelope).isEmpty) return null;
  return clampWindowBounds(saved);
}

class WindowService {
  WindowService({
    required this.prefs,
    this.minimizeToTray = _defaultSetting,
  });

  static bool _defaultSetting() => true;

  final SharedPreferences prefs;
  final bool Function() minimizeToTray;
  _CloseListener? _listener;

  Future<void> initialize({
    required bool Function() minimizeToTray,
    required Future<void> Function() onHidden,
  }) async {
    await windowManager.ensureInitialized();
    // v0.1.3 (D60): the app draws its own 32px title bar. The runner owns the
    // hit-testing — including the Win11 Snap preview over the maximize button —
    // so the native frame and caption are removed here; see
    // windows/runner/win32_window.cpp.
    await windowManager.setTitleBarStyle(TitleBarStyle.hidden);
    await windowManager.setAsFrameless();
    await windowManager.setMinimumSize(minimumWindowSize);
    final saved = restoreWindowBounds(
      decodeWindowBounds(prefs.getString(windowBoundsPrefKey)),
    );
    if (saved != null) {
      await windowManager.setBounds(saved);
    } else {
      await windowManager.setSize(defaultWindowSize);
    }
    await windowManager.setPreventClose(true);
    _listener = _CloseListener(
      minimizeToTray: minimizeToTray,
      onHidden: onHidden,
      persistBounds: persistBounds,
    );
    windowManager.addListener(_listener!);
  }

  /// Stores the current bounds before the window hides, is destroyed, or the
  /// app quits through the tray.
  Future<void> persistBounds() async {
    final bounds = await windowManager.getBounds();
    if (!bounds.left.isFinite ||
        !bounds.top.isFinite ||
        !bounds.width.isFinite ||
        !bounds.height.isFinite) {
      return;
    }
    if (bounds.width <= 0 || bounds.height <= 0) return;
    await prefs.setString(windowBoundsPrefKey, encodeWindowBounds(bounds));
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

/// Runs the close sequence after the native close callback. Persistence is
/// best-effort: a failed bounds write must never leave the window un-closable
/// while `setPreventClose(true)` is active. Window effects are injected so the
/// sequence is testable without touching window_manager.
Future<void> runWindowClose({
  required Future<void> Function() persistBounds,
  required bool Function() minimizeToTray,
  required Future<void> Function() onHidden,
  required Future<void> Function() hideWindow,
  required Future<void> Function() destroyWindow,
}) async {
  try {
    await persistBounds();
  } catch (error, stackTrace) {
    debugPrint('Window bounds persist failed: $error\n$stackTrace');
  }
  if (shouldHideOnClose(minimizeToTray())) {
    await hideWindow();
    await onHidden();
  } else {
    await destroyWindow();
  }
}

class _CloseListener extends WindowListener {
  _CloseListener({
    required this.minimizeToTray,
    required this.onHidden,
    required this.persistBounds,
  });

  final bool Function() minimizeToTray;
  final Future<void> Function() onHidden;
  final Future<void> Function() persistBounds;

  @override
  void onWindowClose() {
    // Persisting bounds is async; keep the native close callback sync and let
    // the hide/destroy run after the write completes.
    unawaited(_close());
  }

  Future<void> _close() => runWindowClose(
    persistBounds: persistBounds,
    minimizeToTray: minimizeToTray,
    onHidden: onHidden,
    hideWindow: windowManager.hide,
    destroyWindow: windowManager.destroy,
  );
}

/// Applies the startup-registration setting to Windows.
Future<void> syncLaunchAtStartup(bool enabled) async {
  // The setting is desktop-only, but the Settings page is still reachable on
  // Android and calls this directly. launch_at_startup has no Android
  // implementation (its no-op backend throws UnsupportedError), so guard at
  // the service boundary to keep every call site safe.
  if (!isDesktopTarget(defaultTargetPlatform)) return;

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

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Three layout shells from `docs/superpowers/specs/2026-11-20-tempolet-v0.1.5-design.md` §8.1.
///
/// Desktop keeps the title bar + rail; tablets get the rail without the
/// title bar; phones get the floating bottom dock. The layout is resolved from
/// the platform and the window's shortest side, so rotation and split-screen
/// switch shells automatically.
enum AppLayout { desktop, tablet, phone }

/// Breakpoint: an Android device whose shortest side is at least 600dp is a
/// tablet. Phone landscape therefore stays on the phone shell.
const double kTabletBreakpoint = 600;

/// Forced layout for gallery previews and tests. Production never sets this;
/// `resolveAppLayout` falls through to the platform/size rule.
///
/// A plain variable (not a provider) keeps the resolution callable from
/// `AppShell.build` and from dialogs without threading a container.
AppLayout? debugLayoutOverride;

/// Desktop is decided by the host OS rather than `defaultTargetPlatform`:
/// under `flutter test` that value is Android, and the existing desktop
/// goldens must keep the desktop shell unless a test forces a layout.
bool get _desktopHost =>
    !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

/// Pure size rule for mobile hosts: shortest side >= 600dp is a tablet,
/// everything else (including phone landscape) is a phone. Desktop is decided
/// by the host OS in [resolveAppLayout], not here.
AppLayout resolveAppLayoutForSize(Size size) =>
    size.shortestSide >= kTabletBreakpoint ? AppLayout.tablet : AppLayout.phone;

AppLayout resolveAppLayout(BuildContext context) {
  final override = debugLayoutOverride;
  if (override != null) return override;
  if (_desktopHost) return AppLayout.desktop;
  return resolveAppLayoutForSize(MediaQuery.sizeOf(context));
}

bool isTouchLayout(AppLayout layout) => layout != AppLayout.desktop;

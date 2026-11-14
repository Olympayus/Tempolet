import 'package:flutter/foundation.dart';

/// Whether the current target platform has the desktop chrome (window
/// manager, tray icon, launch-at-startup) available.
bool isDesktopTarget(TargetPlatform platform) => switch (platform) {
      TargetPlatform.windows ||
      TargetPlatform.macOS ||
      TargetPlatform.linux =>
        true,
      _ => false,
    };

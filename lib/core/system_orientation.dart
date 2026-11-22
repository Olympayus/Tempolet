import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'layout.dart';

/// Screen orientations allowed for [layout].
///
/// Phones stay portrait; tablets and desktops are free to rotate. Applied by
/// `AppShell` on Android only (desktop windows are not orientation-bound).
List<DeviceOrientation> preferredOrientationsFor(AppLayout layout) =>
    switch (layout) {
      AppLayout.phone => const [DeviceOrientation.portraitUp],
      AppLayout.tablet || AppLayout.desktop => const [],
    };

/// Ignores the system font scale: the app renders at a fixed 1.0 text scale.
TextScaler clampAppTextScaler(TextScaler scaler) => TextScaler.noScaling;

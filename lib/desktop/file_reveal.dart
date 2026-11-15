import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../core/platform.dart';

/// Reveals the folder where the local database lives.
///
/// Only Windows opens a file manager (Explorer); the settings page is also
/// reachable on mobile, where this is a no-op. Other desktop targets are
/// intentionally left alone in v0.1.2.
Future<void> openDataFolder() async {
  if (!isDesktopTarget(defaultTargetPlatform)) return;
  if (defaultTargetPlatform != TargetPlatform.windows) return;

  final dir = await getApplicationSupportDirectory();
  await Process.run('explorer', [dir.path]);
}

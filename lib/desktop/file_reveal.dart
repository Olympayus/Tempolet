import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../core/platform.dart';

/// Reveals the folder where Tempolet keeps its local data.
///
/// drift_flutter creates `tempolet.sqlite` in the application documents
/// directory (see `data/database/database.dart`), and the note vault lives in
/// `documents/Tempolet` (see `core/paths.dart`), so the About row opens that
/// documents directory.
///
/// Only Windows opens a file manager (Explorer); the settings page is also
/// reachable on mobile, where this is a no-op. Other desktop targets are
/// intentionally left alone in v0.1.2. [platform], [resolveFolder] and
/// [launch] are injectable so tests can exercise the wiring without opening
/// Explorer.
Future<void> openDataFolder({
  TargetPlatform? platform,
  Future<Directory> Function()? resolveFolder,
  Future<ProcessResult> Function(String executable, List<String> arguments)?
  launch,
}) async {
  final target = platform ?? defaultTargetPlatform;
  if (!isDesktopTarget(target) || target != TargetPlatform.windows) return;

  final dir = await (resolveFolder ?? getApplicationDocumentsDirectory)();
  await (launch ?? Process.run)('explorer', [dir.path]);
}

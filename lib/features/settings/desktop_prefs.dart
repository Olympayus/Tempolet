import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/prefs.dart';

/// Whether closing the window hides the app to the tray (default on).
final minimizeToTrayEnabledProvider =
    NotifierProvider<MinimizeToTrayController, bool>(MinimizeToTrayController.new);

class MinimizeToTrayController extends Notifier<bool> {
  static const prefKey = 'minimize_to_tray';

  @override
  bool build() => ref.watch(sharedPreferencesProvider).getBool(prefKey) ?? true;

  void set(bool value) {
    state = value;
    ref.read(sharedPreferencesProvider).setBool(prefKey, value);
  }
}

/// Whether the app registers itself to start with Windows (default off).
final launchAtStartupEnabledProvider =
    NotifierProvider<LaunchAtStartupController, bool>(LaunchAtStartupController.new);

class LaunchAtStartupController extends Notifier<bool> {
  static const prefKey = 'launch_at_startup';

  @override
  bool build() =>
      ref.watch(sharedPreferencesProvider).getBool(prefKey) ?? false;

  void set(bool value) {
    state = value;
    ref.read(sharedPreferencesProvider).setBool(prefKey, value);
  }
}

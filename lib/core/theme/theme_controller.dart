import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../prefs.dart';
import 'theme_settings.dart';

final themeControllerProvider =
    NotifierProvider<ThemeController, ThemeSettings>(ThemeController.new);

class ThemeController extends Notifier<ThemeSettings> {
  static const modeKey = 'theme_mode';
  static const accentKey = 'accent_color';

  @override
  ThemeSettings build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return ThemeSettings(
      mode: _parseMode(prefs.getString(modeKey)),
      accent: Color(prefs.getInt(accentKey) ?? defaultAccent.toARGB32()),
    );
  }

  void setMode(ThemeMode mode) {
    state = state.copyWith(mode: mode);
    ref.read(sharedPreferencesProvider).setString(modeKey, mode.name);
  }

  void setAccent(Color accent) {
    state = state.copyWith(accent: accent);
    ref.read(sharedPreferencesProvider).setInt(accentKey, accent.toARGB32());
  }

  static ThemeMode _parseMode(String? raw) => switch (raw) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tempolet/core/prefs.dart';
import 'package:tempolet/core/theme/theme_controller.dart';
import 'package:tempolet/core/theme/theme_settings.dart';

Future<ProviderContainer> _container([
  Map<String, Object> initial = const {},
]) async {
  SharedPreferences.setMockInitialValues(initial);
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('defaults to system mode with the default accent', () async {
    final container = await _container();
    final settings = container.read(themeControllerProvider);
    expect(settings.mode, ThemeMode.system);
    expect(settings.accent, defaultAccent);
  });

  test('setMode updates state and persists theme_mode', () async {
    final container = await _container();
    container.read(themeControllerProvider.notifier).setMode(ThemeMode.dark);
    expect(container.read(themeControllerProvider).mode, ThemeMode.dark);
    final prefs = container.read(sharedPreferencesProvider);
    expect(prefs.getString('theme_mode'), 'dark');
  });

  test('setAccent updates state and persists accent_color as ARGB int', () async {
    final container = await _container();
    const green = Color(0xFF34C759);
    container.read(themeControllerProvider.notifier).setAccent(green);
    expect(container.read(themeControllerProvider).accent, green);
    final prefs = container.read(sharedPreferencesProvider);
    expect(prefs.getInt('accent_color'), green.toARGB32());
  });

  test('restores mode and accent from stored preferences', () async {
    final container = await _container({
      'theme_mode': 'light',
      'accent_color': 0xFF34C759,
    });
    final settings = container.read(themeControllerProvider);
    expect(settings.mode, ThemeMode.light);
    expect(settings.accent, const Color(0xFF34C759));
  });

  test('unknown stored mode falls back to system', () async {
    final container = await _container({'theme_mode': 'python'});
    expect(container.read(themeControllerProvider).mode, ThemeMode.system);
  });
}

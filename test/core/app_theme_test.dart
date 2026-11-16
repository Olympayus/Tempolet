import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tempolet/core/theme/app_theme.dart';
import 'package:tempolet/core/theme/app_tokens.dart';

void main() {
  const defaultAccent = Color(0xFF007AFF);
  const extremeAccents = [Color(0xFFFFEB3B), Color(0xFF0D47A1)];

  for (final accent in extremeAccents) {
    test('light theme keeps light brightness for accent $accent', () {
      expect(AppTheme.light(accent).colorScheme.brightness, Brightness.light);
    });

    test('dark theme keeps dark brightness for accent $accent', () {
      expect(AppTheme.dark(accent).colorScheme.brightness, Brightness.dark);
    });
  }

  test('accent color drives the color scheme primary', () {
    expect(
      AppTheme.light(const Color(0xFFAF52DE)).colorScheme.primary,
      const Color(0xFFAF52DE),
    );
  });

  test('scaffold background uses the paper token', () {
    expect(
      AppTheme.light(defaultAccent).scaffoldBackgroundColor,
      AppPalette.light.bg,
    );
  });

  test('scaffold background follows the color scheme surface', () {
    final theme = AppTheme.light(defaultAccent);
    expect(theme.scaffoldBackgroundColor, theme.colorScheme.surface);
  });
}

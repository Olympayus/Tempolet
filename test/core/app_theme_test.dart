import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tempolet/core/theme/app_theme.dart';

double _contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  const extremeSeeds = [Color(0xFFFFEB3B), Color(0xFF0D47A1)];

  for (final seed in extremeSeeds) {
    test('light theme keeps primary/onPrimary readable for seed $seed', () {
      final theme = AppTheme.light(seed);
      expect(theme.colorScheme.brightness, Brightness.light);
      expect(
        _contrastRatio(theme.colorScheme.primary, theme.colorScheme.onPrimary),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('dark theme keeps primary/onPrimary readable for seed $seed', () {
      final theme = AppTheme.dark(seed);
      expect(theme.colorScheme.brightness, Brightness.dark);
      expect(
        _contrastRatio(theme.colorScheme.primary, theme.colorScheme.onPrimary),
        greaterThanOrEqualTo(4.5),
      );
    });
  }

  test('scaffold background follows the color scheme surface', () {
    final theme = AppTheme.light(const Color(0xFF007AFF));
    expect(theme.scaffoldBackgroundColor, theme.colorScheme.surface);
  });
}

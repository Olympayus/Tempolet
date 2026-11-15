import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tempolet/core/theme/app_tokens.dart';

void main() {
  test('palette carries the spec tokens', () {
    expect(AppPalette.light.accent, const Color(0xFF007AFF));
    expect(AppPalette.light.line, const Color(0xFFEDEDF0));
    expect(AppPalette.light.festival, const Color(0xFFC22F2F));
    expect(AppPalette.dark.bg, const Color(0xFF101114));
    expect(AppPalette.dark.festival, const Color(0xFFFF8F8A));
  });

  test('withAccent only changes accent and tint', () {
    final p = AppPalette.light.withAccent(const Color(0xFFAF52DE));
    expect(p.accent, const Color(0xFFAF52DE));
    expect(p.ink, AppPalette.light.ink);
  });

  test('text styles are Inter with tabular figures', () {
    expect(AppTextStyles.body.fontFamily, 'Inter');
    expect(AppTextStyles.body.fontFeatures, isNotEmpty);
    expect(AppTextStyles.display.fontSize, 28);
    expect(AppTextStyles.caption.fontSize, 11);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tempolet/core/theme/app_tokens.dart';

void main() {
  test('palette carries the spec tokens', () {
    expect(AppPalette.light.accent, const Color(0xFF007AFF));
    expect(AppPalette.light.line, const Color(0xFFEDEDF0));
    expect(AppPalette.light.festival, const Color(0xFFC22F2F));
    expect(AppPalette.dark.bg, const Color(0xFF191C22));
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

  test('v0.1.3 sizes and type additions', () {
    expect(AppSizes.row, 46);
    expect(AppSizes.rowTall, 64);
    expect(AppSizes.field, 34);
    expect(AppSizes.header, 64);
    expect(AppSizes.control, 30);
    expect(AppRadii.group, 12);
    expect(AppTextStyles.section.fontSize, 15);
    expect(AppTextStyles.section.fontWeight, FontWeight.w600);
    expect(AppTextStyles.rowTitle.fontSize, 14);
    expect(AppTextStyles.rowTitle.fontWeight, FontWeight.w500);
    expect(AppTextStyles.hint.fontSize, 13);
    expect(AppTextStyles.display.letterSpacing, -0.6);
    expect(AppTextStyles.title.letterSpacing, -0.2);
    expect(AppTextStyles.headline.letterSpacing, -0.1);
    expect(AppTextStyles.body.letterSpacing, 0);
    expect(AppPalette.light.block, const Color(0xFFF2F2F5));
    expect(AppPalette.dark.block, const Color(0xFF262A33));
    expect(AppPalette.light.subMuted, const Color(0xFFAEAEB2));
    expect(AppPalette.dark.subMuted, const Color(0xFF6F7680));
  });

  test('v0.1.4 surfaces', () {
    expect(AppPalette.dark.nav, const Color(0xFF0B0C0F));
    expect(AppPalette.dark.side, const Color(0xFF121419));
    expect(AppPalette.dark.bg, const Color(0xFF191C22));
    expect(AppPalette.dark.surfaceSelected, const Color(0x0CFFFFFF));
    expect(AppPalette.light.nav, const Color(0xFFECEDF0));
    expect(AppPalette.light.side, const Color(0xFFF2F3F5));
    expect(AppPalette.light.bg, const Color(0xFFFFFFFF));
    expect(AppPalette.light.surfaceSelected, const Color(0xFFF7F7FA));
    expect(AppPalette.dark.card, const Color(0xFF20232A));
    expect(AppPalette.dark.block, const Color(0xFF262A33));
    expect(AppPalette.light.block, const Color(0xFFF2F2F5));
    final tinted = AppPalette.dark.withAccent(const Color(0xFFFF0000));
    expect(tinted.nav, AppPalette.dark.nav);
    expect(tinted.side, AppPalette.dark.side);
    expect(tinted.surfaceSelected, AppPalette.dark.surfaceSelected);
  });
}

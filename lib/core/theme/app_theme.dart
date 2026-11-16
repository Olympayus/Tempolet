import 'package:flutter/material.dart';

import 'app_tokens.dart';

/// Palette-driven dual theme builder (design spec `docs/design/01-tokens.md`).
abstract final class AppTheme {
  static ThemeData light(Color accent) => _build(accent, Brightness.light);

  static ThemeData dark(Color accent) => _build(accent, Brightness.dark);

  static ThemeData _build(Color accent, Brightness brightness) {
    final p =
        (brightness == Brightness.light ? AppPalette.light : AppPalette.dark)
            .withAccent(accent);
    final scheme = ColorScheme(
      brightness: brightness,
      primary: accent,
      onPrimary: Colors.white,
      secondary: p.sub,
      onSecondary: p.ink,
      error: p.danger,
      onError: Colors.white,
      surface: p.bg,
      onSurface: p.ink,
      outline: p.sub,
      outlineVariant: p.lineStrong,
      surfaceContainerLowest: p.card,
      surfaceContainerLow: p.chip,
      surfaceContainerHighest: p.chip,
      onSurfaceVariant: p.sub,
    );
    return ThemeData(
      colorScheme: scheme,
      scaffoldBackgroundColor: p.bg,
      fontFamily: 'Inter',
      fontFamilyFallback: const ['NotoSansSC'],
      textTheme: const TextTheme(
        displayLarge: AppTextStyles.display,
        titleLarge: AppTextStyles.title,
        titleMedium: AppTextStyles.headline,
        bodyMedium: AppTextStyles.body,
        bodySmall: AppTextStyles.secondary,
        labelSmall: AppTextStyles.caption,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.dialog),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.card,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.field),
          borderSide: BorderSide(color: p.lineStrong),
        ),
      ),
    );
  }
}

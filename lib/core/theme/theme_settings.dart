import 'package:flutter/material.dart';

/// Default accent color (design spec §4.2).
const defaultAccent = Color(0xFF007AFF);

@immutable
class ThemeSettings {
  const ThemeSettings({required this.mode, required this.accent});

  final ThemeMode mode;
  final Color accent;

  ThemeSettings copyWith({ThemeMode? mode, Color? accent}) => ThemeSettings(
        mode: mode ?? this.mode,
        accent: accent ?? this.accent,
      );

  @override
  bool operator ==(Object other) =>
      other is ThemeSettings && other.mode == mode && other.accent == accent;

  @override
  int get hashCode => Object.hash(mode, accent);
}

import 'package:flutter/material.dart';

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

int timeToMinutes(TimeOfDay t) => t.hour * 60 + t.minute;

/// [m] is clamped to 0..1439; 1440 (end of day) maps to 23:59 because
/// [TimeOfDay] cannot represent 24:00.
TimeOfDay minutesToTimeOfDay(int m) {
  final clamped = m.clamp(0, 1439);
  return TimeOfDay(hour: clamped ~/ 60, minute: clamped % 60);
}

/// Rounds [minute] to the nearest [step] and clamps to 0..1440.
int snapMinutes(int minute, {int step = 5}) {
  final snapped = ((minute + step ~/ 2) ~/ step) * step;
  return snapped.clamp(0, 1440);
}

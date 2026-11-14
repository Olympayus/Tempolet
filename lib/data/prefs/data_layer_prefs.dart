import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/prefs.dart';
import '../../core/utils/dates.dart';

/// User-chosen vault directory path; `null` means use the platform default.
final vaultPathProvider =
    NotifierProvider<VaultPathController, String?>(VaultPathController.new);

class VaultPathController extends Notifier<String?> {
  static const prefKey = 'vault_path';

  @override
  String? build() => ref.watch(sharedPreferencesProvider).getString(prefKey);

  void set(String? value) {
    state = value;
    final prefs = ref.read(sharedPreferencesProvider);
    if (value == null) {
      prefs.remove(prefKey);
    } else {
      prefs.setString(prefKey, value);
    }
  }
}

/// Monday the term starts on, stored as an ISO date (`YYYY-MM-DD`).
final termStartMondayProvider =
    NotifierProvider<TermStartMondayController, DateTime?>(
        TermStartMondayController.new);

class TermStartMondayController extends Notifier<DateTime?> {
  static const prefKey = 'term_start_monday';

  @override
  DateTime? build() {
    final raw = ref.watch(sharedPreferencesProvider).getString(prefKey);
    if (raw == null) return null;
    final parsed = DateTime.tryParse(raw);
    return parsed == null ? null : dateOnly(parsed);
  }

  void set(DateTime? value) {
    final day = value == null ? null : dateOnly(value);
    state = day;
    final prefs = ref.read(sharedPreferencesProvider);
    if (day == null) {
      prefs.remove(prefKey);
    } else {
      prefs.setString(prefKey, day.toIso8601String().substring(0, 10));
    }
  }
}

/// Whether the courses/term component is enabled (default off).
final courseComponentEnabledProvider =
    NotifierProvider<CourseComponentEnabledController, bool>(
        CourseComponentEnabledController.new);

class CourseComponentEnabledController extends Notifier<bool> {
  static const prefKey = 'course_component_enabled';

  @override
  bool build() =>
      ref.watch(sharedPreferencesProvider).getBool(prefKey) ?? false;

  void set(bool value) {
    state = value;
    ref.read(sharedPreferencesProvider).setBool(prefKey, value);
  }
}

/// Version of the holiday seed data last applied; `null` means never seeded.
final holidaySeedVersionProvider =
    NotifierProvider<HolidaySeedVersionController, String?>(
        HolidaySeedVersionController.new);

class HolidaySeedVersionController extends Notifier<String?> {
  static const prefKey = 'holiday_seed_version';

  @override
  String? build() => ref.watch(sharedPreferencesProvider).getString(prefKey);

  void set(String? value) {
    state = value;
    final prefs = ref.read(sharedPreferencesProvider);
    if (value == null) {
      prefs.remove(prefKey);
    } else {
      prefs.setString(prefKey, value);
    }
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/prefs.dart';

/// Default lead time applied when creating an event.
///
/// External semantics: `0` = at the start (the factory default), `null` = no
/// reminder, `N` = N minutes before. Storage keeps that distinction with a
/// sentinel: an unset key reads as `0`, the raw value `-1` reads as `null`,
/// and anything else is the stored minute count. Stored events always carry a
/// concrete value or null — the scheduler never falls back to this default
/// (ledger ruling R6).
final defaultReminderOffsetProvider =
    NotifierProvider<DefaultReminderOffsetController, int?>(
  DefaultReminderOffsetController.new,
);

class DefaultReminderOffsetController extends Notifier<int?> {
  static const prefKey = 'default_remind_offset';
  static const noReminderSentinel = -1;

  @override
  int? build() {
    final raw = ref.watch(sharedPreferencesProvider).getInt(prefKey);
    if (raw == null) return 0;
    if (raw == noReminderSentinel) return null;
    return raw;
  }

  void set(int? minutes) {
    state = minutes;
    ref
        .read(sharedPreferencesProvider)
        .setInt(prefKey, minutes ?? noReminderSentinel);
  }
}

final notificationSoundEnabledProvider =
    NotifierProvider<NotificationSoundController, bool>(
  NotificationSoundController.new,
);

class NotificationSoundController extends Notifier<bool> {
  static const prefKey = 'notification_sound';

  @override
  bool build() => ref.watch(sharedPreferencesProvider).getBool(prefKey) ?? true;

  void set(bool value) {
    state = value;
    ref.read(sharedPreferencesProvider).setBool(prefKey, value);
  }
}

final overdueSummaryEnabledProvider =
    NotifierProvider<OverdueSummaryController, bool>(
  OverdueSummaryController.new,
);

class OverdueSummaryController extends Notifier<bool> {
  static const prefKey = 'overdue_summary';

  @override
  bool build() => ref.watch(sharedPreferencesProvider).getBool(prefKey) ?? true;

  void set(bool value) {
    state = value;
    ref.read(sharedPreferencesProvider).setBool(prefKey, value);
  }
}

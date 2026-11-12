import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/prefs.dart';

/// Default lead time applied when creating an event; null means "no
/// notification". Stored events always carry a concrete value or null — the
/// scheduler never falls back to this default (ledger ruling R6).
final defaultReminderOffsetProvider =
    NotifierProvider<DefaultReminderOffsetController, int?>(
  DefaultReminderOffsetController.new,
);

class DefaultReminderOffsetController extends Notifier<int?> {
  static const prefKey = 'default_remind_offset';

  @override
  int? build() => ref.watch(sharedPreferencesProvider).getInt(prefKey);

  void set(int? minutes) {
    state = minutes;
    final prefs = ref.read(sharedPreferencesProvider);
    if (minutes == null) {
      prefs.remove(prefKey);
    } else {
      prefs.setInt(prefKey, minutes);
    }
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

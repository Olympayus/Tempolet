import 'dart:async';
import 'dart:ui' show Locale;

import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/l10n/generated/app_localizations.dart';
import '../core/l10n/locale_controller.dart';
import '../core/layout.dart';
import '../core/platform/android_capabilities.dart';
import '../core/prefs.dart';
import '../core/router/app_router.dart';
import '../core/utils/dates.dart';
import '../data/database/database.dart';
import '../data/repositories/event_repository.dart';
import '../features/calendar/calendar_state.dart';
import 'notification_payload.dart';
import 'notification_scheduler.dart';

/// A user-facing notice raised while routing a notification (shown as a
/// SnackBar by the shell).
class NotificationNotice extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? value) => state = value;
}

final notificationNoticeProvider =
    NotifierProvider<NotificationNotice, String?>(NotificationNotice.new);

/// SharedPreferences key: the runtime notification permission prompt runs at
/// most once per install.
const String notificationPermissionAskedKey = 'notification_permission_asked';

AppLocalizations _l10nOf(ProviderContainer container) {
  final locale = container.read(localeControllerProvider) ?? const Locale('zh');
  return lookupAppLocalizations(locale);
}

/// Handles a notification payload: completes/snoozes for actions, otherwise
/// selects the event's day and opens the calendar. Phone lands on the month
/// view, tablet on the day view (`v0.1.5 design` §8.10). A missing event
/// falls back to today and raises a notice.
Future<void> routeNotificationPayload(
  ProviderContainer container,
  String payload, {
  required AppLayout layout,
  void Function(String message)? onNotice,
}) async {
  final repo = container.read(eventRepositoryProvider);
  final scheduler = container.read(notificationSchedulerProvider);
  final mode = layout == AppLayout.phone
      ? CalendarViewMode.month
      : CalendarViewMode.day;

  final doneId = doneEventId(payload);
  if (doneId != null) {
    await repo.setCompleted(doneId, true);
    final event = await repo.getById(doneId);
    if (event != null) await scheduler.cancelEvent(event);
    return;
  }

  final snoozeId = snoozeEventId(payload);
  if (snoozeId != null) {
    await scheduler.snooze(snoozeId);
    return;
  }

  final eventId = eventIdFromPayload(payload);
  if (eventId != null) {
    final event = await repo.getById(eventId);
    if (event == null) {
      container
          .read(selectedDayProvider.notifier)
          .select(dateOnly(DateTime.now()));
      container.read(calendarViewModeProvider.notifier).set(mode);
      onNotice?.call(_l10nOf(container).notificationEventMissing);
    } else {
      container.read(selectedDayProvider.notifier).select(dateOnly(event.date));
      container.read(calendarViewModeProvider.notifier).set(mode);
    }
  }
  container.read(routerProvider).go('/calendar');
}

/// Requests the Android notification permission the first time an event with
/// a reminder is saved. Refusal never blocks the save.
Future<void> requestNotificationPermissionIfNeeded(
  ProviderContainer container,
  Event event,
) async {
  if (event.reminderOffsetMinutes == null) return;
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
  final prefs = container.read(sharedPreferencesProvider);
  if (prefs.getBool(notificationPermissionAskedKey) == true) return;
  await prefs.setBool(notificationPermissionAskedKey, true);
  await container.read(notificationServiceProvider).requestPermissions();
  // Record the request so a later "no rationale" reads as permanently denied.
  await container
      .read(androidCapabilitiesProvider)
      .markNotificationPermissionRequested();
}

/// Time/timezone change (or a headless wake-up): silently re-plan everything.
Future<void> rescheduleOnTimeChange(NotificationScheduler scheduler) =>
    scheduler.reconcile();

/// Cache read synchronously by the notification service's schedule mode.
bool exactAlarmsAllowedCache = true;

Future<void> refreshExactAlarms(ProviderContainer container) async {
  try {
    exactAlarmsAllowedCache = await container
        .read(androidCapabilitiesProvider)
        .canScheduleExactAlarms();
  } catch (_) {
    exactAlarmsAllowedCache = true;
  }
}

/// Routes a done/snooze action parked by the background isolate while the app
/// was terminated. Consumed once on launch and on resume.
Future<void> consumePendingNotificationAction(
  ProviderContainer container, {
  required AppLayout layout,
  void Function(String message)? onNotice,
}) async {
  final prefs = container.read(sharedPreferencesProvider);
  final action = prefs.getString(pendingNotificationActionKey);
  if (action == null || action.isEmpty) return;
  await prefs.remove(pendingNotificationActionKey);
  await routeNotificationPayload(
    container,
    action,
    layout: layout,
    onNotice: onNotice,
  );
}

/// True when a time/timezone receiver could not run its headless reconcile.
bool takeReschedulePending(ProviderContainer container) {
  final prefs = container.read(sharedPreferencesProvider);
  if (prefs.getBool(notificationReschedulePendingKey) != true) return false;
  unawaited(prefs.remove(notificationReschedulePendingKey));
  return true;
}

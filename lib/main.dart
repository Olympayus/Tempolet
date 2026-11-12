import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/prefs.dart';
import 'core/router/app_router.dart';
import 'core/utils/dates.dart';
import 'data/repositories/event_repository.dart';
import 'features/calendar/calendar_state.dart';
import 'notifications/flutter_local_notifications_service.dart';
import 'notifications/notification_payload.dart';
import 'notifications/notification_scheduler.dart';

void main() => runTempolet();

Future<void> runTempolet() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();

  final service = FlutterLocalNotificationsService();
  late final ProviderContainer container;
  await service.initialize(
    onTap: (payload) => _handleNotificationPayload(container, payload),
  );

  container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      notificationServiceProvider.overrideWithValue(service),
    ],
  );

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const TempoletApp(),
    ),
  );

  final scheduler = container.read(notificationSchedulerProvider);
  unawaited(scheduler.reconcile());
  _scheduleDailySummary(container);
}

Future<void> _handleNotificationPayload(
  ProviderContainer container,
  String payload,
) async {
  final repo = container.read(eventRepositoryProvider);
  final scheduler = container.read(notificationSchedulerProvider);

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
    if (event != null) {
      container.read(selectedDayProvider.notifier).select(dateOnly(event.date));
      container.read(calendarViewModeProvider.notifier).set(CalendarViewMode.day);
    }
  }
  // Unknown or summary payloads just bring the app to the calendar.
  container.read(routerProvider).go('/calendar');
}

void _scheduleDailySummary(ProviderContainer container) {
  final now = DateTime.now();
  var next = DateTime(now.year, now.month, now.day, 8);
  if (!next.isAfter(now)) next = next.add(const Duration(days: 1));

  Timer(next.difference(now), () async {
    try {
      await container
          .read(notificationSchedulerProvider)
          .maybeShowOverdueSummary(DateTime.now());
    } finally {
      _scheduleDailySummary(container);
    }
  });
}

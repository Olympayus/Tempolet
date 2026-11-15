import 'dart:async';
import 'dart:ui' show Locale, PlatformDispatcher;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/legacy.dart' show windowManager;

import 'app.dart';
import 'core/l10n/generated/app_localizations.dart';
import 'core/l10n/locale_controller.dart';
import 'core/platform.dart';
import 'core/prefs.dart';
import 'core/router/app_router.dart';
import 'core/utils/dates.dart';
import 'data/holidays/holiday_seed_service.dart';
import 'data/repositories/event_repository.dart';
import 'data/repositories/holiday_repository.dart';
import 'desktop/tray_service.dart';
import 'desktop/window_service.dart';
import 'features/calendar/calendar_state.dart';
import 'features/settings/desktop_prefs.dart';
import 'notifications/flutter_local_notifications_service.dart';
import 'notifications/notification_payload.dart';
import 'notifications/notification_scheduler.dart';

void main() => runTempolet();

Future<void> runTempolet() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();

  late final ProviderContainer container;
  final service = FlutterLocalNotificationsService(
    locale: () => _activeLocale(container),
  );
  await service.initialize(
    onTap: (payload) => _handleNotificationPayload(container, payload),
  );

  container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      notificationServiceProvider.overrideWithValue(service),
    ],
  );

  // Import the bundled holiday data once per version. A failure here must not
  // keep the calendar from opening.
  try {
    await HolidaySeedService(
      repository: container.read(holidayRepositoryProvider),
      prefs: prefs,
    ).seedIfNeeded(assetPath: 'assets/holidays/2026.json', version: '2026');
  } catch (error, stackTrace) {
    debugPrint('Holiday seed failed: $error\n$stackTrace');
  }

  // Desktop chrome: window close behaviour and the tray. Initialisation
  // order matters — window manager, then tray, then notifications.
  // Mobile targets have none of these plugins, so skip the whole block.
  if (isDesktopTarget(defaultTargetPlatform)) {
    final window = WindowService();
    await window.initialize(
      minimizeToTray: () => container.read(minimizeToTrayEnabledProvider),
      onHidden: () async {},
    );
    final tray = TrayService();
    final l10n = lookupAppLocalizations(_activeLocale(container));
    await tray.initialize(
      onShow: window.showWindow,
      onQuit: () async {
        await tray.dispose();
        await windowManager.destroy();
      },
      showLabel: l10n.trayShow,
      quitLabel: l10n.trayQuit,
    );
    await syncLaunchAtStartup(container.read(launchAtStartupEnabledProvider));
  }

  runApp(
    UncontrolledProviderScope(container: container, child: const TempoletApp()),
  );

  final scheduler = container.read(notificationSchedulerProvider);
  unawaited(scheduler.reconcile());
  _scheduleDailySummary(container);
}

/// The locale actually shown by the app: the stored preference, otherwise the
/// platform locale, resolved against the supported locales like MaterialApp.
Locale _activeLocale(ProviderContainer container) {
  final locale =
      container.read(localeControllerProvider) ??
      PlatformDispatcher.instance.locale;
  for (final supported in AppLocalizations.supportedLocales) {
    if (supported.languageCode == locale.languageCode) return supported;
  }
  return AppLocalizations.supportedLocales.first;
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
      container
          .read(calendarViewModeProvider.notifier)
          .set(CalendarViewMode.day);
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

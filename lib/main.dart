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
import 'core/layout.dart';
import 'core/platform.dart';
import 'core/prefs.dart';
import 'data/holidays/holiday_seed_service.dart';
import 'data/repositories/holiday_repository.dart';
import 'desktop/tray_service.dart';
import 'desktop/window_service.dart';
import 'features/settings/desktop_prefs.dart';
import 'features/settings/notification_prefs.dart';
import 'notifications/flutter_local_notifications_service.dart';
import 'notifications/notification_payload.dart';
import 'notifications/notification_router.dart';
import 'notifications/notification_scheduler.dart';

void main() => runTempolet();

Future<void> runTempolet() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();

  late final ProviderContainer container;
  final service = FlutterLocalNotificationsService(
    locale: () => _activeLocale(container),
    exactAlarmsAllowed: () => exactAlarmsAllowedCache,
    soundEnabled: () => container.read(notificationSoundEnabledProvider),
  );

  container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      notificationServiceProvider.overrideWithValue(service),
    ],
  );

  // Must come after the container exists: initialisation reads the locale
  // through it to create the notification channels.
  await service.initialize(
    onTap: (payload) => _handleNotificationPayload(container, payload),
  );
  await refreshExactAlarms(container);

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
    final window = WindowService(prefs: prefs);
    await window.initialize(
      minimizeToTray: () => container.read(minimizeToTrayEnabledProvider),
      onHidden: () async {},
    );
    final tray = TrayService();
    final l10n = lookupAppLocalizations(_activeLocale(container));
    await tray.initialize(
      onShow: window.showWindow,
      onQuit: () async {
        try {
          await tray.dispose();
          await window.persistBounds();
        } catch (error, stackTrace) {
          // Quitting must succeed even if the tray or bounds write fails.
          debugPrint('Tray quit preparation failed: $error\n$stackTrace');
        } finally {
          await windowManager.destroy();
        }
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
  if (takeReschedulePending(container)) {
    unawaited(scheduler.reconcile());
  }
  _scheduleDailySummary(container);

  final launchPayload = await service.takeLaunchPayload();
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    if (launchPayload != null && launchPayload.isNotEmpty) {
      await _handleNotificationPayload(container, launchPayload);
    }
    final view = WidgetsBinding.instance.platformDispatcher.implicitView;
    final size = view == null
        ? const Size(1280, 800)
        : view.physicalSize / view.devicePixelRatio;
    await consumePendingNotificationAction(
      container,
      layout: resolveAppLayoutForSize(size),
      onNotice: (message) =>
          container.read(notificationNoticeProvider.notifier).set(message),
    );
  });
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
) {
  final view = WidgetsBinding.instance.platformDispatcher.implicitView;
  final size = view == null
      ? const Size(1280, 800)
      : view.physicalSize / view.devicePixelRatio;
  return routeNotificationPayload(
    container,
    payload,
    layout: resolveAppLayoutForSize(size),
    onNotice: (message) =>
        container.read(notificationNoticeProvider.notifier).set(message),
  );
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

/// Headless entry point run by `TimeChangeReceiver` after a system time or
/// timezone change: build a minimal container and silently re-plan.
@pragma('vm:entry-point')
Future<void> notificationRescheduleEntrypoint() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final service = FlutterLocalNotificationsService();
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      notificationServiceProvider.overrideWithValue(service),
    ],
  );
  try {
    await service.initialize(onTap: (_) {});
    await rescheduleOnTimeChange(container.read(notificationSchedulerProvider));
  } catch (_) {
    await prefs.setBool(notificationReschedulePendingKey, true);
  } finally {
    container.dispose();
  }
}

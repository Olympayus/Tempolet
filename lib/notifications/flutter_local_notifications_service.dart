import 'dart:async';
import 'dart:io';
import 'dart:ui' show Locale;

import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../core/l10n/generated/app_localizations.dart';
import 'android_notification_details.dart';
import 'notification_payload.dart';
import 'notification_service.dart';

/// Localized Windows toast action labels: mark done, snooze 10 minutes.
(String, String) actionLabelsFor(Locale locale) {
  final l10n = lookupAppLocalizations(locale);
  return (l10n.notifActionDone, l10n.notifActionRemind);
}

/// Background isolate entry point for the Android notification actions
/// (`done:` / `snooze:`). The action is parked in prefs and consumed by the
/// main isolate on next launch/resume.
@pragma('vm:entry-point')
void notificationActionCallback(NotificationResponse response) {
  final action = response.actionId ?? response.payload;
  if (action == null || action.isEmpty) return;
  SharedPreferences.getInstance().then(
    (prefs) => prefs.setString('pending_notification_action', action),
  );
}

/// Headless entry point invoked by `TimeChangeReceiver` after a system time
/// or timezone change; it marks the scheduler dirty for the next launch.
/// Task 12 replaces this with the full reconcile call.
@pragma('vm:entry-point')
Future<void> notificationRescheduleEntrypoint() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('notification_reschedule_pending', true);
}

/// Real notification backend (design spec §3.2). Windows is the v0.1.0
/// target; Android settings are present so the shared code path compiles.
class FlutterLocalNotificationsService implements NotificationService {
  FlutterLocalNotificationsService({
    FlutterLocalNotificationsPlugin? plugin,
    Locale Function()? locale,
    bool Function()? exactAlarmsAllowed,
    bool Function()? soundEnabled,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin(),
       _locale = locale ?? (() => const Locale('zh')),
       _exactAlarmsAllowed = exactAlarmsAllowed ?? (() => true),
       _soundEnabled = soundEnabled ?? (() => true);

  final FlutterLocalNotificationsPlugin _plugin;
  final Locale Function() _locale;
  final bool Function() _exactAlarmsAllowed;
  final bool Function() _soundEnabled;
  final Map<int, Timer> _fallbackTimers = {};
  void Function(String payload)? _onTap;

  /// Lightweight runtime log (temp dir) — Windows toast delivery is hard to
  /// observe after the fact, so scheduling and callback events are recorded.
  static void _log(String message) {
    try {
      final file = File(
        '${Directory.systemTemp.path}${Platform.pathSeparator}tempolet-notify.log',
      );
      file.writeAsStringSync(
        '${DateTime.now().toIso8601String()} $message\n',
        mode: FileMode.append,
        flush: true,
      );
    } catch (_) {
      // Logging must never break notifications.
    }
  }

  @override
  Future<void> initialize({
    required void Function(String payload) onTap,
  }) async {
    _onTap = onTap;

    tzdata.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      // Keep the default (UTC) — notifications still fire, just with the
      // wrong wall clock label if the platform lookup fails.
    }

    const settings = InitializationSettings(
      windows: WindowsInitializationSettings(
        appName: 'Tempolet',
        appUserModelId: 'com.tempolet.app',
        guid: '9d2f5f34-6b3e-4a52-9f3f-1d6f1b8e9c41',
      ),
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );

    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        _log('tap payload=$payload');
        if (payload != null && payload.isNotEmpty) {
          _onTap?.call(payload);
        }
      },
      onDidReceiveBackgroundNotificationResponse: notificationActionCallback,
    );
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      final l10n = lookupAppLocalizations(_locale());
      await android.createNotificationChannel(
        AndroidNotificationChannel(
          androidChannelSoundId,
          l10n.notificationChannelSound,
          description: l10n.notificationChannelDescription,
          importance: Importance.high,
        ),
      );
      await android.createNotificationChannel(
        AndroidNotificationChannel(
          androidChannelSilentId,
          l10n.notificationChannelSilent,
          description: l10n.notificationChannelDescription,
          importance: Importance.high,
          playSound: false,
        ),
      );
    }
    _log('initialized (tz=${tz.local.name})');
  }

  @override
  Future<bool> requestPermissions() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }
    // Windows shows toasts without a runtime permission prompt.
    return true;
  }

  NotificationDetails _details(ReminderNotification notification) {
    final eventId = eventIdFromPayload(notification.payload);
    final (doneLabel, remindLabel) = actionLabelsFor(_locale());
    final androidDetails = androidNotificationDetailsFor(
      locale: _locale(),
      sound: _soundEnabled(),
      eventId: eventId,
    );
    return NotificationDetails(
      android: androidDetails.android,
      windows: WindowsNotificationDetails(
        actions: [
          if (eventId != null) ...[
            WindowsAction(content: doneLabel, arguments: donePayload(eventId)),
            WindowsAction(
              content: remindLabel,
              arguments: snoozePayload(eventId),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Future<void> schedule(ReminderNotification notification) async {
    final when = tz.TZDateTime.from(notification.at, tz.local);
    if (!when.isAfter(tz.TZDateTime.now(tz.local))) {
      await showNow(notification);
      return;
    }
    var mode = scheduleModeFor(_exactAlarmsAllowed());
    try {
      try {
        await _plugin.zonedSchedule(
          id: notification.id,
          title: notification.title,
          body: notification.body,
          scheduledDate: when,
          notificationDetails: _details(notification),
          androidScheduleMode: mode,
          payload: notification.payload,
        );
      } on PlatformException catch (error) {
        if (mode == AndroidScheduleMode.inexactAllowWhileIdle) rethrow;
        _log('exact schedule rejected, retrying inexact: $error');
        mode = AndroidScheduleMode.inexactAllowWhileIdle;
        await _plugin.zonedSchedule(
          id: notification.id,
          title: notification.title,
          body: notification.body,
          scheduledDate: when,
          notificationDetails: _details(notification),
          androidScheduleMode: mode,
          payload: notification.payload,
        );
      }
      _log('zonedSchedule ok id=${notification.id} at=$when mode=$mode');
    } catch (error) {
      _log('zonedSchedule FAILED id=${notification.id} at=$when error=$error');
      // Fallback: in-process timer plus an immediate toast. Keeps reminders
      // working while the app runs (including in the tray) even if the
      // platform scheduler rejects the request.
      _fallbackTimers[notification.id]?.cancel();
      final delay = notification.at.difference(DateTime.now());
      _fallbackTimers[notification.id] = Timer(
        delay.isNegative ? Duration.zero : delay,
        () => showNow(notification),
      );
    }
  }

  @override
  Future<void> showNow(ReminderNotification notification) async {
    _log('showNow id=${notification.id}');
    await _plugin.show(
      id: notification.id,
      title: notification.title,
      body: notification.body,
      notificationDetails: _details(notification),
      payload: notification.payload,
    );
  }

  @override
  Future<void> cancel(int id) async {
    _fallbackTimers.remove(id)?.cancel();
    await _plugin.cancel(id: id);
  }
}

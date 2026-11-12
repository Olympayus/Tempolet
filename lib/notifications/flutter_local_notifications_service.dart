import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'notification_payload.dart';
import 'notification_service.dart';

/// Real notification backend (design spec §3.2). Windows is the v0.1.0
/// target; Android settings are present so the shared code path compiles.
class FlutterLocalNotificationsService implements NotificationService {
  FlutterLocalNotificationsService([FlutterLocalNotificationsPlugin? plugin])
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  final Map<int, Timer> _fallbackTimers = {};
  void Function(String payload)? _onTap;

  @override
  Future<void> initialize({required void Function(String payload) onTap}) async {
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
        if (payload != null && payload.isNotEmpty) {
          _onTap?.call(payload);
        }
      },
    );
  }

  @override
  Future<bool> requestPermissions() async {
    final android =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }
    // Windows shows toasts without a runtime permission prompt.
    return true;
  }

  NotificationDetails _details(ReminderNotification notification) {
    final eventId = eventIdFromPayload(notification.payload);
    return NotificationDetails(
      windows: WindowsNotificationDetails(
        actions: [
          if (eventId != null) ...[
            WindowsAction(
              content: '完成',
              arguments: donePayload(eventId),
            ),
            WindowsAction(
              content: '10 分钟后提醒',
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
    try {
      await _plugin.zonedSchedule(
        id: notification.id,
        title: notification.title,
        body: notification.body,
        scheduledDate: when,
        notificationDetails: _details(notification),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: notification.payload,
      );
    } catch (_) {
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

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Notification permission states surfaced in Settings (`v0.1.5 design`
/// §8.10).
enum NotificationPermissionState { granted, denied, permanentlyDenied }

/// Android capability probes and system-settings jumps used by Settings and
/// the notification flow.
abstract class AndroidCapabilities {
  Future<NotificationPermissionState> notificationPermission();
  Future<bool> canScheduleExactAlarms();
  Future<void> openNotificationSettings();
  Future<void> openExactAlarmSettings();

  /// Records that the app asked for POST_NOTIFICATIONS, so a later "no
  /// rationale" result can be read as permanently denied.
  Future<void> markNotificationPermissionRequested();
}

/// Platform-channel implementation. On hosts without the channel (tests,
/// desktop) it reports the permissive state so callers never fail merely
/// because Android is absent.
class MethodChannelAndroidCapabilities implements AndroidCapabilities {
  const MethodChannelAndroidCapabilities();

  static const MethodChannel _channel = MethodChannel(
    'tempolet/android_capabilities',
  );

  @override
  Future<NotificationPermissionState> notificationPermission() async {
    try {
      final value = await _channel.invokeMethod<String>(
        'notificationPermission',
      );
      return switch (value) {
        'granted' => NotificationPermissionState.granted,
        'permanentlyDenied' => NotificationPermissionState.permanentlyDenied,
        _ => NotificationPermissionState.denied,
      };
    } on MissingPluginException {
      return NotificationPermissionState.granted;
    } on PlatformException {
      return NotificationPermissionState.granted;
    }
  }

  @override
  Future<bool> canScheduleExactAlarms() async {
    try {
      return await _channel.invokeMethod<bool>('canScheduleExactAlarms') ??
          true;
    } on MissingPluginException {
      return true;
    } on PlatformException {
      return true;
    }
  }

  @override
  Future<void> openNotificationSettings() async {
    try {
      await _channel.invokeMethod<void>('openNotificationSettings');
    } on MissingPluginException {
      // Host tests have no Android settings to open.
    } on PlatformException {
      // Leave the row as a plain explanation when the jump is unavailable.
    }
  }

  @override
  Future<void> openExactAlarmSettings() async {
    try {
      await _channel.invokeMethod<void>('openExactAlarmSettings');
    } on MissingPluginException {
      // Host tests have no Android settings to open.
    } on PlatformException {
      // Leave the row as a plain explanation when the jump is unavailable.
    }
  }

  @override
  Future<void> markNotificationPermissionRequested() async {
    try {
      await _channel.invokeMethod<void>('markNotificationPermissionRequested');
    } on MissingPluginException {
      // Host tests do not track Android permission prompts.
    } on PlatformException {
      // Non-fatal: the row simply keeps reporting `denied`.
    }
  }
}

final androidCapabilitiesProvider = Provider<AndroidCapabilities>(
  (ref) => const MethodChannelAndroidCapabilities(),
);

final notificationPermissionProvider =
    FutureProvider<NotificationPermissionState>(
      (ref) => ref.watch(androidCapabilitiesProvider).notificationPermission(),
    );

final exactAlarmAvailableProvider = FutureProvider<bool>(
  (ref) => ref.watch(androidCapabilitiesProvider).canScheduleExactAlarms(),
);

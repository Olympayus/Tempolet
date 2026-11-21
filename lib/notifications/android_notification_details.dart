import 'dart:ui' show Locale;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../core/l10n/generated/app_localizations.dart';
import 'notification_payload.dart';

/// Android channel ids (`v0.1.5 design` §8.10). Channel sound is fixed at
/// creation, so sound and silent reminders use separate channels.
const String androidChannelSoundId = 'tempolet_reminders_sound';
const String androidChannelSilentId = 'tempolet_reminders_silent';

String androidChannelId(bool sound) =>
    sound ? androidChannelSoundId : androidChannelSilentId;

/// Exact alarms need the special "Alarms & reminders" permission; without it
/// the scheduler falls back to inexact (may be minutes late).
AndroidScheduleMode scheduleModeFor(bool exact) => exact
    ? AndroidScheduleMode.exactAllowWhileIdle
    : AndroidScheduleMode.inexactAllowWhileIdle;

/// Android notification details shared by scheduling and `showNow`: the
/// sound-dependent channel, high importance/priority and the 「完成」/
/// 「10 分钟后」 actions.
NotificationDetails androidNotificationDetailsFor({
  required Locale locale,
  required bool sound,
  String? eventId,
}) {
  final l10n = lookupAppLocalizations(locale);
  return NotificationDetails(
    android: AndroidNotificationDetails(
      androidChannelId(sound),
      sound ? l10n.notificationChannelSound : l10n.notificationChannelSilent,
      channelDescription: l10n.notificationChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.reminder,
      playSound: sound,
      visibility: NotificationVisibility.public,
      actions: [
        if (eventId != null) ...[
          AndroidNotificationAction(
            donePayload(eventId),
            l10n.notifActionDone,
            cancelNotification: true,
          ),
          AndroidNotificationAction(
            snoozePayload(eventId),
            l10n.notifActionRemind,
            showsUserInterface: false,
          ),
        ],
      ],
    ),
  );
}

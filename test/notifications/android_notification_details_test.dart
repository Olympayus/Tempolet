import 'dart:ui' show Locale;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tempolet/notifications/android_notification_details.dart';

void main() {
  test('Android details use channel, actions and sound setting', () {
    final loud = androidNotificationDetailsFor(
      locale: const Locale('zh'),
      sound: true,
      eventId: 'e1',
    );
    expect(loud.android!.channelId, androidChannelSoundId);
    expect(
      loud.android!.actions!.map((action) => action.title),
      containsAll(['完成', '10 分钟后']),
    );

    final silent = androidNotificationDetailsFor(
      locale: const Locale('zh'),
      sound: false,
      eventId: 'e1',
    );
    expect(silent.android!.channelId, androidChannelSilentId);
    expect(silent.android!.importance, Importance.high);
    expect(silent.android!.priority, Priority.high);
  });

  test('exact alarm capability selects the schedule mode', () {
    expect(scheduleModeFor(true), AndroidScheduleMode.exactAllowWhileIdle);
    expect(scheduleModeFor(false), AndroidScheduleMode.inexactAllowWhileIdle);
  });
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('manifest declares notification permissions, label and receivers', () {
    final xml = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();
    expect(xml, contains('POST_NOTIFICATIONS'));
    expect(xml, contains('SCHEDULE_EXACT_ALARM'));
    expect(xml, contains('RECEIVE_BOOT_COMPLETED'));
    expect(xml, contains('VIBRATE'));
    expect(xml, contains('ScheduledNotificationReceiver'));
    expect(xml, contains('ScheduledNotificationBootReceiver'));
    expect(xml, contains('ActionBroadcastReceiver'));
    expect(xml, contains('TimeChangeReceiver'));
    expect(xml, contains('android:label="Tempolet"'));
    expect(xml, isNot(contains('screenOrientation')));
  });
}

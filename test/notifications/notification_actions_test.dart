import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:tempolet/notifications/flutter_local_notifications_service.dart';

void main() {
  test('English action labels', () {
    expect(
      actionLabelsFor(const Locale('en')),
      ('Done', 'In 10 minutes'),
    );
  });

  test('Chinese action labels', () {
    expect(actionLabelsFor(const Locale('zh')), ('完成', '10 分钟后'));
  });
}

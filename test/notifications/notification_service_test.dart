import 'package:flutter_test/flutter_test.dart';
import 'package:tempolet/notifications/notification_payload.dart';
import 'package:tempolet/notifications/notification_service.dart';

class FakeNotificationService implements NotificationService {
  final scheduled = <ReminderNotification>[];
  final cancelled = <int>[];
  int? shownNowCount;

  @override
  Future<void> initialize({required void Function(String payload) onTap}) async {}

  @override
  Future<bool> requestPermissions() async => true;

  @override
  Future<void> schedule(ReminderNotification notification) async {
    scheduled.add(notification);
  }

  @override
  Future<void> showNow(ReminderNotification notification) async {}

  @override
  Future<void> cancel(int id) async {
    cancelled.add(id);
  }
}

void main() {
  group('payloads', () {
    test('event payload round-trips', () {
      final payload = eventPayload('abc-123');
      expect(payload, 'event:abc-123');
      expect(eventIdFromPayload(payload), 'abc-123');
    });

    test('unknown payloads decode to null', () {
      expect(eventIdFromPayload('garbage'), isNull);
      expect(eventIdFromPayload('event:'), isNull);
      expect(eventIdFromPayload(''), isNull);
    });

    test('action payloads decode', () {
      expect(doneEventId('done:abc'), 'abc');
      expect(snoozeEventId('snooze:abc'), 'abc');
      expect(doneEventId('event:abc'), isNull);
      expect(snoozeEventId('event:abc'), isNull);
    });

    test('overdue summary payload is stable', () {
      expect(overdueSummaryPayload, 'summary:overdue');
    });
  });

  group('reminderBody', () {
    test('composes time, remaining and note', () {
      final body = reminderBody(
        timeLabel: '今天 09:00–10:00',
        remainingLabel: '还有 10 分钟开始',
        note: '会议室 B',
      );
      expect(body, '今天 09:00–10:00 · 还有 10 分钟开始 · 会议室 B');
    });

    test('omits the note when empty', () {
      final body = reminderBody(
        timeLabel: '今天 09:00',
        remainingLabel: '还有 5 分钟开始',
      );
      expect(body, '今天 09:00 · 还有 5 分钟开始');
    });

    test('omits the remaining label when empty', () {
      final body = reminderBody(timeLabel: '今天 09:00');
      expect(body, '今天 09:00');
    });
  });

  group('fake service records calls', () {
    test('fake records schedule and cancel', () async {
      final fake = FakeNotificationService();
      await fake.initialize(onTap: (_) {});
      await fake.schedule(ReminderNotification(
        id: 1,
        title: 't',
        body: 'b',
        payload: 'event:x',
        at: DateTime(2026, 11, 11, 9, 0),
      ));
      await fake.cancel(1);

      expect(fake.scheduled, hasLength(1));
      expect(fake.scheduled.single.id, 1);
      expect(fake.cancelled, [1]);
    });
  });
}

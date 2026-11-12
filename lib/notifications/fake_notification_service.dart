import 'package:tempolet/notifications/notification_service.dart';

/// Recording fake used by scheduler tests.
class FakeNotificationService implements NotificationService {
  final List<String> calls = [];
  final List<ReminderNotification> scheduled = [];
  final List<int> cancelled = [];
  final List<ReminderNotification> shownNow = [];

  void clear() {
    calls.clear();
    scheduled.clear();
    cancelled.clear();
    shownNow.clear();
  }

  @override
  Future<void> initialize({required void Function(String payload) onTap}) async {}

  @override
  Future<bool> requestPermissions() async => true;

  @override
  Future<void> schedule(ReminderNotification notification) async {
    calls.add('schedule:${notification.id}@${notification.at.toIso8601String()}');
    scheduled.add(notification);
  }

  @override
  Future<void> showNow(ReminderNotification notification) async {
    calls.add('showNow:${notification.payload}');
    shownNow.add(notification);
  }

  @override
  Future<void> cancel(int id) async {
    calls.add('cancel:$id');
    cancelled.add(id);
  }
}

/// A scheduled system notification.
class ReminderNotification {
  const ReminderNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.payload,
    required this.at,
  });

  final int id;
  final String title;
  final String body;
  final String payload;
  final DateTime at;
}

/// Platform-facing notification API. Business code depends on this
/// interface only; the flutter_local_notifications implementation lives in
/// `flutter_local_notifications_service.dart`.
abstract class NotificationService {
  Future<void> initialize({required void Function(String payload) onTap});
  Future<bool> requestPermissions();
  Future<void> schedule(ReminderNotification notification);
  Future<void> showNow(ReminderNotification notification);
  Future<void> cancel(int id);
}

/// Composes the notification body from already-localized parts, e.g.
/// `今天 09:00–10:00 · 还有 10 分钟开始 · 会议室 B`.
String reminderBody({
  required String timeLabel,
  String remainingLabel = '',
  String? note,
}) {
  final parts = <String>[
    timeLabel,
    if (remainingLabel.isNotEmpty) remainingLabel,
    if ((note ?? '').trim().isNotEmpty) note!.trim(),
  ];
  return parts.join(' · ');
}

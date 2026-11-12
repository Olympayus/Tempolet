/// Notification payload conventions (design spec §3.2).
///
/// - `event:<uuid>`  — the notification fires; opening it jumps to the event.
/// - `done:<uuid>`   — "完成" action, mark the event complete.
/// - `snooze:<uuid>` — "10 分钟后提醒" action.
/// - `summary:overdue` — the daily overdue summary.
String eventPayload(String eventId) => 'event:$eventId';

String? _suffixAfter(String payload, String prefix) {
  if (!payload.startsWith(prefix)) return null;
  final value = payload.substring(prefix.length);
  return value.isEmpty ? null : value;
}

String? eventIdFromPayload(String payload) => _suffixAfter(payload, 'event:');

String? doneEventId(String payload) => _suffixAfter(payload, 'done:');

String? snoozeEventId(String payload) => _suffixAfter(payload, 'snooze:');

const overdueSummaryPayload = 'summary:overdue';

String donePayload(String eventId) => 'done:$eventId';

String snoozePayload(String eventId) => 'snooze:$eventId';

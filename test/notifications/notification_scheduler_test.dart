import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tempolet/data/database/database.dart';
import 'package:tempolet/data/repositories/event_repository.dart';
import 'package:tempolet/notifications/fake_notification_service.dart';
import 'package:tempolet/notifications/notification_payload.dart';
import 'package:tempolet/notifications/notification_scheduler.dart';

void main() {
  late AppDatabase db;
  late EventRepository repo;
  late FakeNotificationService service;
  late NotificationScheduler scheduler;
  late bool summaryEnabled;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = EventRepository(db);
    service = FakeNotificationService();
    summaryEnabled = true;
    scheduler = NotificationScheduler(
      service: service,
      repo: repo,
      overdueSummaryEnabled: () => summaryEnabled,
    );
  });

  tearDown(() async {
    await db.close();
  });

  Future<Event> createTomorrow({int offset = 10, int startMinute = 540}) {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    return repo.create(
      title: 'Sync',
      kind: 'reminder',
      date: tomorrow,
      startMinute: startMinute,
      reminderOffsetMinutes: offset,
    );
  }

  test('schedules at start minus the lead time', () async {
    final event = await createTomorrow(offset: 10, startMinute: 540);
    await scheduler.syncEvent(event);

    expect(service.scheduled, hasLength(1));
    final notification = service.scheduled.single;
    final expected = DateTime(
        event.date.year, event.date.month, event.date.day, 8, 50);
    expect(notification.at, expected);
    expect(notification.payload, eventPayload(event.id));
    expect(notification.id, event.notificationId);
  });

  test('skips completed events but still cancels them', () async {
    final event = await createTomorrow();
    await repo.setCompleted(event.id, true);
    final completed = (await repo.getById(event.id))!;

    await scheduler.syncEvent(completed);

    expect(service.scheduled, isEmpty);
    expect(service.cancelled, [event.notificationId]);
  });

  test('null reminder offset means no notification', () async {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final event = await repo.create(
      title: 'No alert',
      kind: 'plan',
      date: tomorrow,
      startMinute: 540,
      endMinute: 600,
    );

    await scheduler.syncEvent(event);
    expect(service.scheduled, isEmpty);
  });

  test('sync is idempotent: cancel then schedule every time', () async {
    final event = await createTomorrow();
    await scheduler.syncEvent(event);
    await scheduler.syncEvent(event);
    await scheduler.syncEvent(event);

    final at = _expectedAt(event);
    expect(service.calls, [
      'cancel:${event.notificationId}',
      'schedule:${event.notificationId}@$at',
      'cancel:${event.notificationId}',
      'schedule:${event.notificationId}@$at',
      'cancel:${event.notificationId}',
      'schedule:${event.notificationId}@$at',
    ]);
  });

  test('reconcile twice produces the same call sequence', () async {
    await createTomorrow();
    await createTomorrow(startMinute: 600);

    await scheduler.reconcile();
    final first = [...service.calls];
    service.clear();
    await scheduler.reconcile();

    expect(service.calls, first);
  });

  test('snooze schedules the same event ten minutes from now', () async {
    final event = await createTomorrow();
    final before = DateTime.now();
    await scheduler.snooze(event.id);

    expect(service.scheduled, hasLength(1));
    final at = service.scheduled.single.at;
    expect(at.isAfter(before.add(const Duration(minutes: 9))), isTrue);
    expect(at.isBefore(before.add(const Duration(minutes: 11))), isTrue);
    expect(service.scheduled.single.payload, eventPayload(event.id));
  });

  test('overdue summary fires when yesterday has unfinished events', () async {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    await repo.create(
      title: 'Forgotten',
      kind: 'reminder',
      date: yesterday,
      startMinute: 540,
    );

    await scheduler.maybeShowOverdueSummary(DateTime.now());

    expect(service.shownNow, hasLength(1));
    expect(service.shownNow.single.payload, overdueSummaryPayload);
  });

  test('overdue summary is silent when disabled or nothing is overdue',
      () async {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final event = await repo.create(
      title: 'Forgotten',
      kind: 'reminder',
      date: yesterday,
      startMinute: 540,
    );

    summaryEnabled = false;
    await scheduler.maybeShowOverdueSummary(DateTime.now());
    expect(service.shownNow, isEmpty);

    summaryEnabled = true;
    await repo.setCompleted(event.id, true);
    await scheduler.maybeShowOverdueSummary(DateTime.now());
    expect(service.shownNow, isEmpty);
  });
}

String _expectedAt(Event event) {
  final at = DateTime(event.date.year, event.date.month, event.date.day, 8, 50);
  return at.toIso8601String();
}

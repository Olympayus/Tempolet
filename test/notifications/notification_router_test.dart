import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tempolet/core/layout.dart';
import 'package:tempolet/core/prefs.dart';
import 'package:tempolet/core/utils/dates.dart';
import 'package:tempolet/data/database/database.dart';
import 'package:tempolet/data/repositories/event_repository.dart';
import 'package:tempolet/features/calendar/calendar_state.dart';
import 'package:tempolet/notifications/fake_notification_service.dart';
import 'package:tempolet/notifications/notification_payload.dart';
import 'package:tempolet/notifications/notification_router.dart';
import 'package:tempolet/notifications/notification_scheduler.dart';

final _day = DateTime(2026, 11, 20);

Future<({ProviderContainer container, Event event})> _containerWithEvent({
  bool delete = false,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final db = AppDatabase(NativeDatabase.memory());
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      databaseProvider.overrideWithValue(db),
      notificationServiceProvider.overrideWithValue(FakeNotificationService()),
      todayProvider.overrideWithValue(DateTime(2026, 11, 16)),
    ],
  );
  addTearDown(() async {
    container.dispose();
    await db.close();
  });
  final repo = EventRepository(db);
  final event = await repo.create(
    title: 'Routed',
    kind: 'reminder',
    date: _day,
    startMinute: 540,
    reminderOffsetMinutes: 0,
  );
  if (delete) await repo.hardDelete(event.id);
  return (container: container, event: event);
}

void main() {
  test('tap routes phone to month and tablet to day', () async {
    final phone = await _containerWithEvent();
    await routeNotificationPayload(
      phone.container,
      eventPayload(phone.event.id),
      layout: AppLayout.phone,
    );
    expect(
      phone.container.read(calendarViewModeProvider),
      CalendarViewMode.month,
    );
    expect(phone.container.read(selectedDayProvider), _day);

    final tablet = await _containerWithEvent();
    await routeNotificationPayload(
      tablet.container,
      eventPayload(tablet.event.id),
      layout: AppLayout.tablet,
    );
    expect(
      tablet.container.read(calendarViewModeProvider),
      CalendarViewMode.day,
    );
    expect(tablet.container.read(selectedDayProvider), _day);
  });

  test('deleted event falls back to today and notices', () async {
    final result = await _containerWithEvent();
    final container = result.container;
    String? notice;
    await routeNotificationPayload(
      container,
      eventPayload('missing'),
      layout: AppLayout.phone,
      onNotice: (message) => notice = message,
    );
    expect(container.read(selectedDayProvider), dateOnly(DateTime.now()));
    expect(notice, isNotNull);
  });

  test('done payload completes and snooze reschedules', () async {
    final result = await _containerWithEvent();
    final container = result.container;
    final repo = container.read(eventRepositoryProvider);
    final event = result.event;

    await routeNotificationPayload(
      container,
      donePayload(event.id),
      layout: AppLayout.tablet,
    );
    final completed = await repo.getById(event.id);
    expect(completed!.isCompleted, isTrue);

    final other = await repo.create(
      title: 'Snoozable',
      kind: 'reminder',
      date: _day,
      startMinute: 600,
      reminderOffsetMinutes: 0,
    );
    await routeNotificationPayload(
      container,
      snoozePayload(other.id),
      layout: AppLayout.tablet,
    );
  });
}

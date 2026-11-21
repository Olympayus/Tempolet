import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tempolet/app.dart';
import 'package:tempolet/core/l10n/generated/app_localizations.dart';
import 'package:tempolet/core/platform/android_capabilities.dart';
import 'package:tempolet/core/prefs.dart';
import 'package:tempolet/data/database/database.dart';
import 'package:tempolet/data/repositories/event_repository.dart';
import 'package:tempolet/features/events/event_editor_sheet.dart';
import 'package:tempolet/notifications/fake_notification_service.dart';
import 'package:tempolet/notifications/notification_router.dart';
import 'package:tempolet/notifications/notification_scheduler.dart';

class _CountingScheduler extends NotificationScheduler {
  _CountingScheduler({required super.service, required super.repo});

  int reconcileCalls = 0;

  @override
  Future<void> reconcile() async {
    reconcileCalls++;
  }
}

class _GrantingCapabilities implements AndroidCapabilities {
  @override
  Future<NotificationPermissionState> notificationPermission() async =>
      NotificationPermissionState.granted;

  @override
  Future<bool> canScheduleExactAlarms() async => true;

  @override
  Future<void> openNotificationSettings() async {}

  @override
  Future<void> openExactAlarmSettings() async {}

  @override
  Future<void> markNotificationPermissionRequested() async {}
}

void main() {
  late AppDatabase db;
  late ProviderContainer container;
  late FakeNotificationService fake;
  late EventRepository repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    db = AppDatabase(NativeDatabase.memory());
    repo = EventRepository(db);
    fake = FakeNotificationService();
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        databaseProvider.overrideWithValue(db),
        notificationServiceProvider.overrideWithValue(fake),
        androidCapabilitiesProvider.overrideWithValue(_GrantingCapabilities()),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await db.close();
    });
  });

  test('permission is requested once when saving a reminder', () async {
    final event = await repo.create(
      title: 'Reminder',
      kind: 'reminder',
      date: DateTime(2026, 11, 20),
      startMinute: 540,
      reminderOffsetMinutes: 0,
    );
    await requestNotificationPermissionIfNeeded(container, event);
    await requestNotificationPermissionIfNeeded(container, event);
    expect(fake.requestPermissionCalls, 1);
  });

  test('events without a reminder never request permission', () async {
    final event = await repo.create(
      title: 'Plan',
      kind: 'plan',
      date: DateTime(2026, 11, 20),
      startMinute: 540,
      endMinute: 600,
    );
    await requestNotificationPermissionIfNeeded(container, event);
    expect(fake.requestPermissionCalls, 0);
  });

  test('time change silently reconciles', () async {
    final scheduler = _CountingScheduler(service: fake, repo: repo);
    await rescheduleOnTimeChange(scheduler);
    expect(scheduler.reconcileCalls, 1);
  });

  testWidgets('saving a reminder from the editor prompts once', (tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showEventEditor(
                    context,
                    date: DateTime(2026, 11, 20),
                    startMinute: 540,
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('editor-title')),
      'New reminder',
    );
    await tester.tap(find.byKey(const ValueKey('editor-save')));
    await tester.pumpAndSettle();
    expect(fake.requestPermissionCalls, 1);
  });

  testWidgets('resume triggers reconcile', (tester) async {
    final scheduler = _CountingScheduler(service: fake, repo: repo);
    final resumed = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(
          container.read(sharedPreferencesProvider),
        ),
        databaseProvider.overrideWithValue(db),
        notificationServiceProvider.overrideWithValue(fake),
        notificationSchedulerProvider.overrideWithValue(scheduler),
        androidCapabilitiesProvider.overrideWithValue(_GrantingCapabilities()),
      ],
    );
    addTearDown(resumed.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(container: resumed, child: const TempoletApp()),
    );
    await tester.pumpAndSettle();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(scheduler.reconcileCalls, 1);
  });
}

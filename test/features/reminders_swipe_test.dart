import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tempolet/core/l10n/generated/app_localizations.dart';
import 'package:tempolet/core/layout.dart';
import 'package:tempolet/core/prefs.dart';
import 'package:tempolet/data/database/database.dart';
import 'package:tempolet/data/repositories/event_repository.dart';
import 'package:tempolet/features/calendar/calendar_state.dart';
import 'package:tempolet/features/reminders/reminders_page.dart';
import 'package:tempolet/notifications/fake_notification_service.dart';
import 'package:tempolet/notifications/notification_scheduler.dart';

final _today = DateTime(2026, 11, 16);

Widget _pageApp(ProviderContainer container) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const RemindersPage(),
    ),
  );
}

Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 30)),
  );
  await tester.pumpAndSettle();
}

void _usePhone(WidgetTester tester) {
  tester.view.physicalSize = const Size(375, 812);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  debugLayoutOverride = AppLayout.phone;
  addTearDown(() => debugLayoutOverride = null);
}

void main() {
  late AppDatabase db;
  late ProviderContainer container;
  late EventRepository repo;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    db = AppDatabase(NativeDatabase.memory());
    repo = EventRepository(db);
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        databaseProvider.overrideWithValue(db),
        notificationServiceProvider.overrideWithValue(
          FakeNotificationService(),
        ),
        todayProvider.overrideWithValue(_today),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<Event> seed() => repo.create(
    title: 'Swipe me',
    kind: 'reminder',
    date: _today,
    startMinute: 540,
    reminderOffsetMinutes: 0,
  );

  testWidgets('phone reminders row swipe exposes edit/delete and delete '
      'confirms', (tester) async {
    final event = await seed();
    _usePhone(tester);
    await tester.pumpWidget(_pageApp(container));
    await _settle(tester);

    await tester.drag(
      find.byKey(ValueKey('reminders-row-${event.id}')),
      const Offset(-120, 0),
    );
    await tester.pumpAndSettle();
    expect(find.text('编辑'), findsOneWidget);
    expect(find.text('删除'), findsOneWidget);

    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('delete-confirm')), findsOneWidget);
  });

  testWidgets('phone reminders header has a create button', (tester) async {
    _usePhone(tester);
    await tester.pumpWidget(_pageApp(container));
    await _settle(tester);
    expect(find.byKey(const ValueKey('reminders-create')), findsOneWidget);
  });
}

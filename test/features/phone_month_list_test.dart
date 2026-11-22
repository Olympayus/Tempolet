import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tempolet/core/l10n/generated/app_localizations.dart';
import 'package:tempolet/core/layout.dart';
import 'package:tempolet/core/prefs.dart';
import 'package:tempolet/core/router/app_router.dart';
import 'package:tempolet/data/database/database.dart';
import 'package:tempolet/data/repositories/event_repository.dart';
import 'package:tempolet/features/calendar/calendar_state.dart';
import 'package:tempolet/features/calendar/phone_calendar.dart';
import 'package:tempolet/notifications/fake_notification_service.dart';
import 'package:tempolet/notifications/notification_scheduler.dart';

final _today = DateTime(2026, 11, 16);

Widget _app(ProviderContainer container) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(body: PhoneCalendarPage()),
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
    title: 'Phone row',
    kind: 'reminder',
    date: _today,
    startMinute: 540,
    reminderOffsetMinutes: 0,
  );

  testWidgets('completing a month-list row retains it with a strike, undo '
      'restores', (tester) async {
    final event = await seed();
    _usePhone(tester);
    await tester.pumpWidget(_app(container));
    await _settle(tester);

    await tester.tap(find.byKey(ValueKey('phone-day-complete-${event.id}')));
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.byKey(ValueKey('phone-day-row-${event.id}')), findsOneWidget);
    expect(
      find.byKey(ValueKey('phone-day-strike-${event.id}')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(ValueKey('phone-day-complete-${event.id}')));
    await tester.pumpAndSettle();
    expect(find.byKey(ValueKey('phone-day-strike-${event.id}')), findsNothing);
  });

  testWidgets('a completion keeps its slot among several rows', (tester) async {
    final first = await repo.create(
      title: 'First',
      kind: 'reminder',
      date: _today,
      startMinute: 540,
      reminderOffsetMinutes: 0,
    );
    final second = await repo.create(
      title: 'Second',
      kind: 'reminder',
      date: _today,
      startMinute: 600,
      reminderOffsetMinutes: 0,
    );
    _usePhone(tester);
    await tester.pumpWidget(_app(container));
    await _settle(tester);

    await tester.tap(find.byKey(ValueKey('phone-day-complete-${first.id}')));
    await tester.pump(const Duration(milliseconds: 250));
    final firstY = tester
        .getTopLeft(find.byKey(ValueKey('phone-day-row-${first.id}')))
        .dy;
    final secondY = tester
        .getTopLeft(find.byKey(ValueKey('phone-day-row-${second.id}')))
        .dy;
    expect(firstY, lessThan(secondY));
    expect(find.text('2 项'), findsOneWidget);
  });

  testWidgets('retained rows stay on their selected day', (tester) async {
    final event = await seed();
    _usePhone(tester);
    await tester.pumpWidget(_app(container));
    await _settle(tester);

    await tester.tap(find.byKey(ValueKey('phone-day-complete-${event.id}')));
    await tester.pump(const Duration(milliseconds: 250));
    expect(
      find.byKey(ValueKey('phone-day-strike-${event.id}')),
      findsOneWidget,
    );

    container
        .read(selectedDayProvider.notifier)
        .select(_today.add(const Duration(days: 1)));
    await tester.pumpAndSettle();
    expect(find.byKey(ValueKey('phone-day-row-${event.id}')), findsNothing);
    expect(find.byKey(ValueKey('phone-day-strike-${event.id}')), findsNothing);
  });

  testWidgets('leaving for the completed page clears retention', (
    tester,
  ) async {
    final event = await seed();
    final router = GoRouter(
      initialLocation: '/calendar',
      routes: [
        GoRoute(
          path: '/calendar',
          builder: (context, state) =>
              const Scaffold(body: PhoneCalendarPage()),
          routes: [
            GoRoute(
              path: 'completed',
              builder: (context, state) => const Scaffold(
                body: SizedBox(key: ValueKey('completed-stub')),
              ),
            ),
          ],
        ),
      ],
    );
    final routed = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        databaseProvider.overrideWithValue(db),
        notificationServiceProvider.overrideWithValue(
          FakeNotificationService(),
        ),
        todayProvider.overrideWithValue(_today),
        routerProvider.overrideWithValue(router),
      ],
    );
    addTearDown(routed.dispose);
    addTearDown(router.dispose);

    _usePhone(tester);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: routed,
        child: MaterialApp.router(
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await _settle(tester);

    await tester.tap(find.byKey(ValueKey('phone-day-complete-${event.id}')));
    await tester.pump(const Duration(milliseconds: 250));
    expect(
      find.byKey(ValueKey('phone-day-strike-${event.id}')),
      findsOneWidget,
    );

    router.go('/calendar/completed');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('completed-stub')), findsOneWidget);

    router.go('/calendar');
    await tester.pumpAndSettle();
    expect(find.byKey(ValueKey('phone-day-strike-${event.id}')), findsNothing);
  });

  testWidgets('month-list row swipe exposes edit/delete and delete confirms', (
    tester,
  ) async {
    final event = await seed();
    _usePhone(tester);
    await tester.pumpWidget(_app(container));
    await _settle(tester);

    await tester.drag(
      find.byKey(ValueKey('phone-day-row-${event.id}')),
      const Offset(-120, 0),
    );
    await tester.pumpAndSettle();
    expect(find.text('编辑'), findsOneWidget);
    expect(find.text('删除'), findsOneWidget);

    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('delete-confirm')), findsOneWidget);
  });

  testWidgets('swiping the month grid slides to the next month', (
    tester,
  ) async {
    _usePhone(tester);
    await tester.pumpWidget(_app(container));
    await _settle(tester);

    final pager = find.byKey(const ValueKey('phone-month-pages'));
    final gesture = await tester.startGesture(tester.getCenter(pager));
    await gesture.moveBy(const Offset(0, -120));
    await tester.pump();
    await gesture.moveBy(const Offset(0, -100));
    await tester.pump();

    // Both months are on screen while the finger moves: the grid slides
    // instead of swapping pages outright.
    expect(
      find.byKey(const ValueKey('phone-month-page-2026-11')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('phone-month-page-2026-12')),
      findsOneWidget,
    );
    expect(
      tester
          .getTopLeft(find.byKey(const ValueKey('phone-month-page-2026-11')))
          .dy,
      lessThan(tester.getTopLeft(pager).dy),
    );

    await gesture.moveBy(const Offset(0, -150));
    await tester.pump();
    await gesture.up();
    await _settle(tester);

    expect(container.read(selectedDayProvider), DateTime(2026, 12, 16));
  });

  testWidgets('swiping to a shorter month clamps the day of month', (
    tester,
  ) async {
    container
        .read(selectedDayProvider.notifier)
        .select(DateTime(2026, 1, 31));
    _usePhone(tester);
    await tester.pumpWidget(_app(container));
    await _settle(tester);

    await tester.fling(
      find.byKey(const ValueKey('phone-month-pages')),
      const Offset(0, -300),
      1200,
    );
    await _settle(tester);

    expect(container.read(selectedDayProvider), DateTime(2026, 2, 28));
  });

  testWidgets('Today slides the grid back to the selected month', (
    tester,
  ) async {
    _usePhone(tester);
    await tester.pumpWidget(_app(container));
    await _settle(tester);

    await tester.fling(
      find.byKey(const ValueKey('phone-month-pages')),
      const Offset(0, -300),
      1200,
    );
    await _settle(tester);
    expect(container.read(selectedDayProvider), DateTime(2026, 12, 16));

    await tester.tap(find.byKey(const ValueKey('phone-calendar-today')));
    await _settle(tester);

    expect(container.read(selectedDayProvider), DateTime(2026, 11, 16));
    expect(
      tester
          .getRect(find.byKey(const ValueKey('phone-month-page-2026-11')))
          .top,
      closeTo(
        tester.getRect(find.byKey(const ValueKey('phone-month-pages'))).top,
        0.5,
      ),
    );
  });
}

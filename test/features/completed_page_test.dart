import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tempolet/app.dart';
import 'package:tempolet/core/l10n/generated/app_localizations.dart';
import 'package:tempolet/core/prefs.dart';
import 'package:tempolet/core/utils/dates.dart';
import 'package:tempolet/data/database/database.dart';
import 'package:tempolet/data/repositories/event_repository.dart';
import 'package:tempolet/features/completed/completed_page.dart';
import 'package:tempolet/notifications/fake_notification_service.dart';
import 'package:tempolet/notifications/notification_scheduler.dart';

Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 30)),
  );
  await tester.pumpAndSettle();
}

Widget _pageApp(ProviderContainer container) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const CompletedPage(),
    ),
  );
}

void _useWindow(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  late AppDatabase db;
  late ProviderContainer container;
  late EventRepository repo;
  late FakeNotificationService notifications;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    db = AppDatabase(NativeDatabase.memory());
    repo = EventRepository(db);
    notifications = FakeNotificationService();
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        databaseProvider.overrideWithValue(db),
        notificationServiceProvider.overrideWithValue(notifications),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<Event> seed(
    String title, {
    String kind = 'reminder',
    int? startMinute = 540,
    int? endMinute,
  }) {
    return repo.create(
      title: title,
      kind: kind,
      date: dateOnly(DateTime.now()),
      startMinute: startMinute,
      endMinute: endMinute,
      reminderOffsetMinutes: 0,
    );
  }

  Future<void> completeAt(String id, DateTime at) async {
    await (db.update(db.events)..where((t) => t.id.equals(id))).write(
      EventsCompanion(isCompleted: const Value(true), completedAt: Value(at)),
    );
  }

  testWidgets('groups items into 今天, 昨天 and 更早 in completion order', (
    tester,
  ) async {
    final today = dateOnly(DateTime.now());
    final yesterday = DateTime(today.year, today.month, today.day - 1);
    final earlier = DateTime(today.year, today.month, today.day - 3);

    final newest = await seed(
      'Today task',
      kind: 'plan',
      startMinute: 600,
      endMinute: 660,
    );
    final middle = await seed('Yesterday task');
    final oldest = await seed('Earlier task');
    await completeAt(
      newest.id,
      DateTime(today.year, today.month, today.day, 9, 30),
    );
    await completeAt(
      middle.id,
      DateTime(yesterday.year, yesterday.month, yesterday.day, 18),
    );
    await completeAt(
      oldest.id,
      DateTime(earlier.year, earlier.month, earlier.day, 12),
    );

    await tester.pumpWidget(_pageApp(container));
    await _settle(tester);

    expect(find.byKey(const ValueKey('completed-page')), findsOneWidget);
    expect(find.byKey(const ValueKey('completed-back')), findsOneWidget);
    expect(find.byKey(const ValueKey('completed-clear')), findsOneWidget);
    expect(find.text('已完成'), findsOneWidget);

    expect(find.text('今天'), findsOneWidget);
    expect(find.text('昨天'), findsOneWidget);
    expect(find.text('更早'), findsOneWidget);

    expect(find.text('Today task'), findsOneWidget);
    expect(find.text('Yesterday task'), findsOneWidget);
    expect(find.text('Earlier task'), findsOneWidget);
    expect(find.text('计划'), findsOneWidget);
    expect(find.text('提醒'), findsNWidgets(2));
    expect(find.text('09:30'), findsOneWidget);
    expect(find.text('18:00'), findsOneWidget);
    expect(find.text('12:00'), findsOneWidget);

    double rowTop(String id) =>
        tester.getTopLeft(find.byKey(ValueKey('completed-restore-$id'))).dy;
    expect(rowTop(newest.id), lessThan(rowTop(middle.id)));
    expect(rowTop(middle.id), lessThan(rowTop(oldest.id)));
  });

  testWidgets('restore clears the completion and returns the item to its day', (
    tester,
  ) async {
    final today = dateOnly(DateTime.now());
    final event = await seed('Call back');
    await completeAt(
      event.id,
      DateTime(today.year, today.month, today.day, 10),
    );

    await tester.pumpWidget(_pageApp(container));
    await _settle(tester);

    await tester.tap(find.byKey(ValueKey('completed-restore-${event.id}')));
    await _settle(tester);

    expect(find.byKey(ValueKey('completed-restore-${event.id}')), findsNothing);
    final restored = await tester.runAsync(() => repo.getById(event.id));
    expect(restored!.isCompleted, isFalse);
    expect(restored.completedAt, isNull);
    final dayEvents = await tester.runAsync(() => repo.eventsOnDay(today));
    expect(dayEvents!.map((e) => e.id), [event.id]);
    expect(notifications.cancelled, contains(event.notificationId));
  });

  testWidgets('delete asks for confirmation and hard deletes the row', (
    tester,
  ) async {
    final today = dateOnly(DateTime.now());
    final event = await seed('Delete me');
    await completeAt(
      event.id,
      DateTime(today.year, today.month, today.day, 10),
    );

    await tester.pumpWidget(_pageApp(container));
    await _settle(tester);

    await tester.tap(find.byKey(ValueKey('completed-delete-${event.id}')));
    await tester.pumpAndSettle();
    expect(find.text('删除后无法恢复'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('completed-confirm-cancel')));
    await _settle(tester);
    expect(
      find.byKey(ValueKey('completed-restore-${event.id}')),
      findsOneWidget,
    );
    expect(await tester.runAsync(() => repo.getById(event.id)), isNotNull);

    await tester.tap(find.byKey(ValueKey('completed-delete-${event.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('completed-confirm-delete')));
    await _settle(tester);

    expect(find.byKey(ValueKey('completed-restore-${event.id}')), findsNothing);
    expect(await tester.runAsync(() => repo.getById(event.id)), isNull);
    expect(notifications.cancelled, contains(event.notificationId));
  });

  testWidgets('clear asks for confirmation, cancels and empties the list', (
    tester,
  ) async {
    final today = dateOnly(DateTime.now());
    final first = await seed('Done A');
    final second = await seed('Done B');
    await completeAt(first.id, DateTime(today.year, today.month, today.day, 9));
    await completeAt(
      second.id,
      DateTime(today.year, today.month, today.day, 10),
    );

    await tester.pumpWidget(_pageApp(container));
    await _settle(tester);

    await tester.tap(find.byKey(const ValueKey('completed-clear')));
    await tester.pumpAndSettle();
    expect(find.text('删除后无法恢复'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('completed-confirm-cancel')));
    await _settle(tester);
    expect(
      await tester.runAsync(() => db.select(db.events).get()),
      hasLength(2),
    );

    await tester.tap(find.byKey(const ValueKey('completed-clear')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('completed-confirm-delete')));
    await _settle(tester);

    expect(find.text('Done A'), findsNothing);
    expect(find.text('Done B'), findsNothing);
    expect(await tester.runAsync(() => db.select(db.events).get()), isEmpty);
    expect(
      notifications.cancelled,
      containsAll([first.notificationId, second.notificationId]),
    );
  });

  testWidgets('sidebar link opens the completed page and back returns', (
    tester,
  ) async {
    _useWindow(tester, const Size(1600, 900));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TempoletApp(),
      ),
    );
    await _settle(tester);

    expect(find.byKey(const ValueKey('calendar-page')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('sidebar-completed-link')));
    await _settle(tester);

    expect(find.byKey(const ValueKey('completed-page')), findsOneWidget);
    expect(find.byKey(const ValueKey('calendar-page')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('completed-back')));
    await _settle(tester);

    expect(find.byKey(const ValueKey('completed-page')), findsNothing);
    expect(find.byKey(const ValueKey('calendar-page')), findsOneWidget);
  });
}

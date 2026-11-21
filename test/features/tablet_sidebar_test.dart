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
import 'package:tempolet/features/calendar/calendar_page.dart';
import 'package:tempolet/features/calendar/calendar_state.dart';
import 'package:tempolet/features/completed/completed_page.dart';
import 'package:tempolet/features/reminders/reminders_page.dart';
import 'package:tempolet/notifications/fake_notification_service.dart';
import 'package:tempolet/notifications/notification_scheduler.dart';

final _today = DateTime(2026, 11, 16);

Widget _app(ProviderContainer container, Widget page) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: _PageHost(page),
    ),
  );
}

class _PageHost extends StatelessWidget {
  const _PageHost(this.page);

  final Widget page;

  @override
  Widget build(BuildContext context) => Scaffold(body: page);
}

Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 30)),
  );
  await tester.pumpAndSettle();
}

void _useLayout(WidgetTester tester, AppLayout layout, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  debugLayoutOverride = layout;
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

  Future<Event> seed({bool completed = false}) async {
    final event = await repo.create(
      title: 'Tablet row',
      kind: 'reminder',
      date: _today,
      startMinute: 540,
      reminderOffsetMinutes: 0,
    );
    if (completed) await repo.setCompleted(event.id, true);
    return event;
  }

  testWidgets('tablet sidebar swipe + retention; desktop unchanged', (
    tester,
  ) async {
    final event = await seed();
    _useLayout(tester, AppLayout.tablet, const Size(1280, 800));
    await tester.pumpWidget(_app(container, const CalendarPage()));
    await _settle(tester);

    await tester.drag(
      find.byKey(ValueKey('sidebar-row-${event.id}')),
      const Offset(-120, 0),
    );
    await tester.pumpAndSettle();
    expect(find.text('编辑'), findsOneWidget);

    await tester.tap(find.byKey(ValueKey('sidebar-complete-${event.id}')));
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.byKey(ValueKey('sidebar-row-${event.id}')), findsOneWidget);
    final completed = await tester.runAsync(() => repo.getById(event.id));
    expect(completed!.isCompleted, isTrue);

    // The retained row's circle is the undo affordance.
    await tester.tap(find.byKey(ValueKey('sidebar-complete-${event.id}')));
    await tester.pumpAndSettle();
    final undone = await tester.runAsync(() => repo.getById(event.id));
    expect(undone!.isCompleted, isFalse);
  });

  testWidgets('tablet sidebar keeps a completion in its time slot', (
    tester,
  ) async {
    final first = await seed();
    final second = await repo.create(
      title: 'Later row',
      kind: 'reminder',
      date: _today,
      startMinute: 600,
      reminderOffsetMinutes: 0,
    );
    _useLayout(tester, AppLayout.tablet, const Size(1280, 800));
    await tester.pumpWidget(_app(container, const CalendarPage()));
    await _settle(tester);

    await tester.tap(find.byKey(ValueKey('sidebar-complete-${first.id}')));
    await tester.pump(const Duration(milliseconds: 250));
    final firstY = tester
        .getTopLeft(find.byKey(ValueKey('sidebar-row-${first.id}')))
        .dy;
    final secondY = tester
        .getTopLeft(find.byKey(ValueKey('sidebar-row-${second.id}')))
        .dy;
    expect(firstY, lessThan(secondY));
  });

  testWidgets('tablet sidebar retains only on its selected day', (
    tester,
  ) async {
    final event = await seed();
    _useLayout(tester, AppLayout.tablet, const Size(1280, 800));
    await tester.pumpWidget(_app(container, const CalendarPage()));
    await _settle(tester);

    await tester.tap(find.byKey(ValueKey('sidebar-complete-${event.id}')));
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.byKey(ValueKey('sidebar-row-${event.id}')), findsOneWidget);

    container
        .read(selectedDayProvider.notifier)
        .select(_today.add(const Duration(days: 1)));
    await tester.pumpAndSettle();
    expect(find.byKey(ValueKey('sidebar-row-${event.id}')), findsNothing);
  });

  testWidgets('desktop sidebar rows do not swipe', (tester) async {
    final event = await seed();
    _useLayout(tester, AppLayout.desktop, const Size(1280, 800));
    await tester.pumpWidget(_app(container, const CalendarPage()));
    await _settle(tester);

    await tester.drag(
      find.byKey(ValueKey('sidebar-row-${event.id}')),
      const Offset(-120, 0),
    );
    await tester.pumpAndSettle();
    expect(find.text('编辑'), findsNothing);
  });

  testWidgets('tablet reminders touch rows also swipe; desktop rows do not', (
    tester,
  ) async {
    final event = await seed();
    _useLayout(tester, AppLayout.tablet, const Size(1280, 800));
    await tester.pumpWidget(_app(container, const RemindersPage()));
    await _settle(tester);
    await tester.drag(
      find.byKey(ValueKey('reminders-row-${event.id}')),
      const Offset(-120, 0),
    );
    await tester.pumpAndSettle();
    expect(find.text('编辑'), findsOneWidget);

    debugLayoutOverride = AppLayout.desktop;
    await tester.pumpWidget(_app(container, const RemindersPage()));
    await _settle(tester);
    await tester.drag(
      find.byKey(ValueKey('reminders-row-${event.id}')),
      const Offset(-120, 0),
    );
    await tester.pumpAndSettle();
    expect(find.text('编辑'), findsNothing);
  });

  testWidgets('portrait tablet hides sidebar and reminders left column by '
      'default', (tester) async {
    await seed();
    _useLayout(tester, AppLayout.tablet, const Size(800, 1280));
    await tester.pumpWidget(_app(container, const CalendarPage()));
    await _settle(tester);
    expect(find.byKey(const ValueKey('calendar-sidebar')), findsNothing);

    await tester.pumpWidget(_app(container, const RemindersPage()));
    await _settle(tester);
    expect(find.byKey(const ValueKey('reminders-left-column')), findsNothing);
    expect(find.byKey(const ValueKey('reminders-left-toggle')), findsOneWidget);
  });

  testWidgets('tablet completed content is 760 wide', (tester) async {
    await seed(completed: true);
    _useLayout(tester, AppLayout.tablet, const Size(1280, 800));
    await tester.pumpWidget(_app(container, const CompletedPage()));
    await _settle(tester);
    expect(
      tester.getSize(find.byKey(const ValueKey('completed-content'))).width,
      760,
    );
  });
}

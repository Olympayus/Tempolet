import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tempolet/core/l10n/generated/app_localizations.dart';
import 'package:tempolet/core/prefs.dart';
import 'package:tempolet/data/database/database.dart';
import 'package:tempolet/data/repositories/event_repository.dart';
import 'package:tempolet/features/calendar/calendar_page.dart';
import 'package:tempolet/features/calendar/calendar_state.dart';
import 'package:tempolet/features/events/fields/segmented_date_field.dart';
import 'package:tempolet/notifications/fake_notification_service.dart';
import 'package:tempolet/notifications/notification_scheduler.dart';

Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 30)),
  );
  await tester.pumpAndSettle();
}

Widget _app(ProviderContainer container) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const CalendarPage(),
    ),
  );
}

void _useWindow(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

const _sidebar = ValueKey('calendar-sidebar');

/// Text inside the sidebar, ignoring the month grid that renders the same
/// events behind it.
Finder _sidebarText(String text) =>
    find.descendant(of: find.byKey(_sidebar), matching: find.text(text));

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
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  testWidgets('defaults open on wide windows and persists the toggle', (
    tester,
  ) async {
    _useWindow(tester, const Size(1600, 900));
    await tester.pumpWidget(_app(container));
    await _settle(tester);

    expect(find.byKey(_sidebar), findsOneWidget);
    expect(
      find.byKey(const ValueKey('sidebar-completed-link')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('sidebar-add')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('calendar-sidebar-toggle')));
    await tester.pumpAndSettle();

    expect(find.byKey(_sidebar), findsNothing);
    expect(prefs.getBool('sidebar_open'), isFalse);
  });

  testWidgets('is collapsed by default below 1180px', (tester) async {
    _useWindow(tester, const Size(1000, 800));
    await tester.pumpWidget(_app(container));
    await _settle(tester);

    expect(find.byKey(_sidebar), findsNothing);
    expect(prefs.getBool('sidebar_open'), isNull);
  });

  testWidgets('opens exactly at the 1180px breakpoint', (tester) async {
    _useWindow(tester, const Size(1180, 800));
    await tester.pumpWidget(_app(container));
    await _settle(tester);

    expect(find.byKey(_sidebar), findsOneWidget);
  });

  testWidgets('an explicit choice overrides the width default', (tester) async {
    _useWindow(tester, const Size(1000, 800));
    await tester.pumpWidget(_app(container));
    await _settle(tester);
    expect(find.byKey(_sidebar), findsNothing);

    await tester.tap(find.byKey(const ValueKey('calendar-sidebar-toggle')));
    await tester.pumpAndSettle();
    expect(find.byKey(_sidebar), findsOneWidget);
    expect(prefs.getBool('sidebar_open'), isTrue);

    // Crossing the breakpoint must not undo the user's explicit choice.
    tester.view.physicalSize = const Size(1600, 900);
    await tester.pumpAndSettle();
    expect(find.byKey(_sidebar), findsOneWidget);
  });

  testWidgets('day view hides the sidebar even when it is open', (
    tester,
  ) async {
    _useWindow(tester, const Size(1600, 900));
    await tester.pumpWidget(_app(container));
    await _settle(tester);
    expect(find.byKey(_sidebar), findsOneWidget);

    container.read(calendarViewModeProvider.notifier).set(CalendarViewMode.day);
    await tester.pumpAndSettle();
    expect(find.byKey(_sidebar), findsNothing);
    expect(find.byKey(const ValueKey('calendar-sidebar-toggle')), findsNothing);

    container
        .read(calendarViewModeProvider.notifier)
        .set(CalendarViewMode.month);
    await tester.pumpAndSettle();
    expect(find.byKey(_sidebar), findsOneWidget);
  });

  testWidgets('lists the selected day and opens rows and add in the editor', (
    tester,
  ) async {
    const longTitle = 'A very long standup title that must stay on one line';
    final reminder = await repo.create(
      title: longTitle,
      kind: 'reminder',
      date: DateTime(2026, 11, 12),
      startMinute: 540,
    );
    await repo.create(
      title: 'Deep work',
      kind: 'plan',
      date: DateTime(2026, 11, 12),
      startMinute: 600,
      endMinute: 660,
    );
    container.read(selectedDayProvider.notifier).select(DateTime(2026, 11, 12));
    _useWindow(tester, const Size(1600, 900));
    await tester.pumpWidget(_app(container));
    await _settle(tester);

    expect(_sidebarText('11月12日 周四 · 2 项'), findsOneWidget);
    expect(_sidebarText('09:00'), findsOneWidget);
    expect(_sidebarText('10:00–11:00'), findsOneWidget);
    expect(find.byKey(ValueKey('sidebar-row-${reminder.id}')), findsOneWidget);
    expect(
      find.byKey(ValueKey('sidebar-complete-${reminder.id}')),
      findsOneWidget,
    );

    final title = tester.widget<Text>(_sidebarText(longTitle));
    expect(title.maxLines, 1);
    expect(title.overflow, TextOverflow.ellipsis);

    // Tapping a row edits the existing event.
    await tester.tap(find.byKey(ValueKey('sidebar-row-${reminder.id}')));
    await _settle(tester);
    expect(find.byKey(const ValueKey('editor-title')), findsOneWidget);
    expect(
      tester
          .widget<SegmentedDateField>(find.byKey(const ValueKey('editor-date')))
          .value,
      DateTime(2026, 11, 12),
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('editor-title')))
          .controller
          ?.text,
      longTitle,
    );

    await tester.tap(find.text('取消'));
    await _settle(tester);

    // The footer button creates a new item on the selected day.
    await tester.tap(find.byKey(const ValueKey('sidebar-add')));
    await _settle(tester);
    expect(find.byKey(const ValueKey('editor-title')), findsOneWidget);
    expect(
      tester
          .widget<SegmentedDateField>(find.byKey(const ValueKey('editor-date')))
          .value,
      DateTime(2026, 11, 12),
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('editor-title')))
          .controller
          ?.text,
      isEmpty,
    );
  });

  testWidgets('shows a single gray line when the selected day is empty', (
    tester,
  ) async {
    _useWindow(tester, const Size(1600, 900));
    await tester.pumpWidget(_app(container));
    await _settle(tester);

    expect(_sidebarText('无安排'), findsOneWidget);
  });

  testWidgets('checking a row completes the event and removes it', (
    tester,
  ) async {
    final event = await repo.create(
      title: 'Call back',
      kind: 'reminder',
      date: DateTime(2026, 11, 12),
      startMinute: 750,
    );
    container.read(selectedDayProvider.notifier).select(DateTime(2026, 11, 12));
    _useWindow(tester, const Size(1600, 900));
    await tester.pumpWidget(_app(container));
    await _settle(tester);

    await tester.tap(find.byKey(ValueKey('sidebar-complete-${event.id}')));
    await tester.pump(const Duration(milliseconds: 150));
    await _settle(tester);

    expect(find.byKey(ValueKey('sidebar-row-${event.id}')), findsNothing);
    final rows = await tester.runAsync(() => db.select(db.events).get());
    expect(rows!.single.isCompleted, isTrue);
  });

  testWidgets('dismissing during the fade still writes the completion', (
    tester,
  ) async {
    final event = await repo.create(
      title: 'Call back',
      kind: 'reminder',
      date: DateTime(2026, 11, 12),
      startMinute: 750,
    );
    container.read(selectedDayProvider.notifier).select(DateTime(2026, 11, 12));
    _useWindow(tester, const Size(1600, 900));
    await tester.pumpWidget(_app(container));
    await _settle(tester);

    await tester.tap(find.byKey(ValueKey('sidebar-complete-${event.id}')));
    await tester.pump(const Duration(milliseconds: 20));
    // Tear the page down before the 120ms fade finishes; the write must still
    // happen without touching `ref` after disposal.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 200));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );

    final rows = await tester.runAsync(() => db.select(db.events).get());
    expect(rows!.single.isCompleted, isTrue);
  });
}

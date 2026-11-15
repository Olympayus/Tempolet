import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tempolet/core/l10n/generated/app_localizations.dart';
import 'package:tempolet/core/prefs.dart';
import 'package:tempolet/data/database/database.dart';
import 'package:tempolet/data/repositories/category_repository.dart';
import 'package:tempolet/data/repositories/event_repository.dart';
import 'package:tempolet/features/events/event_draft.dart';
import 'package:tempolet/features/events/event_editor_sheet.dart';
import 'package:tempolet/notifications/fake_notification_service.dart';
import 'package:tempolet/notifications/notification_scheduler.dart';

late AppDatabase _db;
late ProviderContainer _container;
late FakeNotificationService _fake;

/// Creates the in-memory database, provider container and notification fake
/// shared by every test in this file.
Future<EventRepository> _init({
  Map<String, Object> prefsValues = const {},
}) async {
  SharedPreferences.setMockInitialValues(prefsValues);
  final prefs = await SharedPreferences.getInstance();
  _db = AppDatabase(NativeDatabase.memory());
  _fake = FakeNotificationService();
  _container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      databaseProvider.overrideWithValue(_db),
      notificationServiceProvider.overrideWithValue(_fake),
    ],
  );
  addTearDown(() async {
    _container.dispose();
    await _db.close();
  });
  return EventRepository(_db);
}

Future<void> _pumpEditor(
  WidgetTester tester, {
  Event? existing,
  DateTime? date,
  int? startMinute,
  int? endMinute,
  EventKind? initialKind,
  Locale locale = const Locale('en'),
}) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: _container,
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showEventEditor(
                  context,
                  existing: existing,
                  date: date,
                  startMinute: startMinute,
                  endMinute: endMinute,
                  initialKind: initialKind,
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
}

Future<void> _enter(WidgetTester tester, String key, String text) async {
  await tester.enterText(find.byKey(ValueKey(key)), text);
  await tester.pump();
}

Future<void> _save(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(const ValueKey('editor-save')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('editor-save')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('plan defaults to 30 minutes and clamps end at 24:00', (
    tester,
  ) async {
    final repo = await _init();
    await _pumpEditor(
      tester,
      date: DateTime(2026, 11, 15),
      initialKind: EventKind.plan,
      startMinute: 23 * 60 + 45,
    );

    expect(find.byKey(const ValueKey('editor-start')), findsOneWidget);
    expect(find.byKey(const ValueKey('editor-end')), findsOneWidget);
    expect(find.byKey(const ValueKey('start-stepper')), findsOneWidget);
    expect(find.byKey(const ValueKey('end-stepper')), findsOneWidget);

    await _enter(tester, 'editor-title', '深夜');
    await _save(tester);

    final events = await tester.runAsync(
      () => repo.eventsOnDay(DateTime(2026, 11, 15)),
    );
    expect(events!.single.startMinute, 1425);
    expect(events.single.endMinute, 1440);
  });

  testWidgets('reminder prefills one time field and stores segmented input', (
    tester,
  ) async {
    final repo = await _init();
    await _pumpEditor(
      tester,
      date: DateTime(2026, 11, 15),
      initialKind: EventKind.reminder,
      startMinute: 540,
    );

    final segmented = tester.widget<SegmentedButton<EventKind>>(
      find.byType(SegmentedButton<EventKind>),
    );
    expect(segmented.selected, {EventKind.reminder});
    expect(find.byKey(const ValueKey('end-stepper')), findsNothing);

    await _enter(tester, 'start-hour', '10');
    await _enter(tester, 'start-minute', '15');
    await _enter(tester, 'editor-title', 'Standup');
    await _save(tester);

    final events = await tester.runAsync(
      () => repo.eventsOnDay(DateTime(2026, 11, 15)),
    );
    expect(events!.single.startMinute, 615);
    expect(events.single.endMinute, isNull);
  });

  testWidgets('switching to plan adds a default 30 minute end', (tester) async {
    final repo = await _init();
    await _pumpEditor(
      tester,
      date: DateTime(2026, 11, 15),
      initialKind: EventKind.reminder,
      startMinute: 540,
    );

    await tester.tap(find.text('Plan'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('end-stepper')), findsOneWidget);

    await _enter(tester, 'editor-title', 'Focus');
    await _save(tester);

    final events = await tester.runAsync(
      () => repo.eventsOnDay(DateTime(2026, 11, 15)),
    );
    expect(events!.single.startMinute, 540);
    expect(events.single.endMinute, 570);
  });

  testWidgets('segmented date clamps the day to the month end', (tester) async {
    final repo = await _init();
    await _pumpEditor(
      tester,
      date: DateTime(2026, 11, 15),
      initialKind: EventKind.reminder,
      startMinute: 540,
    );

    await _enter(tester, 'date-year', '2027');
    await _enter(tester, 'date-month', '2');
    await _enter(tester, 'date-day', '31');
    await _enter(tester, 'editor-title', 'Clamped');
    await _save(tester);

    final events = await tester.runAsync(
      () => repo.eventsOnDay(DateTime(2027, 2, 28)),
    );
    expect(events, hasLength(1));
    expect(events!.single.date, DateTime(2027, 2, 28));
  });

  testWidgets('mini calendar fills the date back into the field', (
    tester,
  ) async {
    final repo = await _init();
    await _pumpEditor(
      tester,
      date: DateTime(2026, 11, 15),
      initialKind: EventKind.reminder,
      startMinute: 540,
    );

    await tester.tap(find.byKey(const ValueKey('date-calendar')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('mini-day-2026-11-20')));
    await tester.pumpAndSettle();

    await _enter(tester, 'editor-title', 'Picked');
    await _save(tester);

    final events = await tester.runAsync(
      () => repo.eventsOnDay(DateTime(2026, 11, 20)),
    );
    expect(events, hasLength(1));
  });

  testWidgets('plan end accepts 24:00 but forces the minute to zero', (
    tester,
  ) async {
    final repo = await _init();
    await _pumpEditor(
      tester,
      date: DateTime(2026, 11, 15),
      initialKind: EventKind.plan,
      startMinute: 540,
      endMinute: 600,
    );

    await _enter(tester, 'end-hour', '24');
    await _enter(tester, 'end-minute', '30');
    await _enter(tester, 'editor-title', 'Midnight');
    await _save(tester);

    final events = await tester.runAsync(
      () => repo.eventsOnDay(DateTime(2026, 11, 15)),
    );
    expect(events!.single.endMinute, 1440);
  });

  testWidgets('saving writes the selected category id', (tester) async {
    await _init();
    final category = await CategoryRepository(_db).create(name: 'Work');
    await _pumpEditor(
      tester,
      date: DateTime(2026, 11, 15),
      initialKind: EventKind.reminder,
      startMinute: 540,
    );

    await tester.tap(find.byKey(const ValueKey('editor-category')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Work').last);
    await tester.pumpAndSettle();

    await _enter(tester, 'editor-title', 'Categorised');
    await _save(tester);

    final rows = await tester.runAsync(() => _db.select(_db.events).get());
    expect(rows!.single.categoryId, category.id);
  });

  testWidgets('importance is gone from the editor', (tester) async {
    await _init();
    await _pumpEditor(
      tester,
      date: DateTime(2026, 11, 15),
      initialKind: EventKind.reminder,
      startMinute: 540,
      locale: const Locale('zh'),
    );

    expect(find.text('重要程度'), findsNothing);
    expect(find.text('新建'), findsOneWidget);
    expect(find.text('年'), findsOneWidget);
    expect(find.text('月'), findsOneWidget);
    expect(find.text('日'), findsOneWidget);
  });

  testWidgets('empty title blocks saving and shows an error', (tester) async {
    await _init();
    await _pumpEditor(
      tester,
      date: DateTime(2026, 11, 15),
      initialKind: EventKind.reminder,
      startMinute: 540,
    );

    await _save(tester);

    expect(find.text('Please enter a title'), findsOneWidget);
    final rows = await tester.runAsync(() => _db.select(_db.events).get());
    expect(rows!, isEmpty);
  });

  testWidgets('a plan end before the start is rejected', (tester) async {
    await _init();
    await _pumpEditor(
      tester,
      date: DateTime(2026, 11, 15),
      initialKind: EventKind.plan,
      startMinute: 600,
      endMinute: 660,
    );

    await _enter(tester, 'end-hour', '09');
    await _enter(tester, 'end-minute', '00');
    await _enter(tester, 'editor-title', 'Backwards');
    await _save(tester);

    expect(find.text('End time must be after start time'), findsOneWidget);
    final rows = await tester.runAsync(() => _db.select(_db.events).get());
    expect(rows!, isEmpty);
  });

  testWidgets('editing an existing event updates it', (tester) async {
    final repo = await _init();
    final existing = await repo.create(
      title: 'Old',
      kind: 'reminder',
      date: DateTime(2026, 11, 15),
      startMinute: 540,
    );
    await _pumpEditor(tester, existing: existing);

    expect(find.text('Edit'), findsOneWidget);
    await _enter(tester, 'editor-title', 'New');
    await _save(tester);

    final rows = await tester.runAsync(() => _db.select(_db.events).get());
    expect(rows!.single.title, 'New');
  });

  testWidgets('deleting asks for confirmation first', (tester) async {
    final repo = await _init();
    final existing = await repo.create(
      title: 'Bye',
      kind: 'reminder',
      date: DateTime(2026, 11, 15),
      startMinute: 540,
    );
    await _pumpEditor(tester, existing: existing);

    await tester.ensureVisible(find.byKey(const ValueKey('editor-delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('editor-delete')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('confirm-delete')), findsOneWidget);
    var rows = await tester.runAsync(() => _db.select(_db.events).get());
    expect(rows!.single.deletedAt, isNull);

    await tester.tap(find.byKey(const ValueKey('confirm-delete')));
    await tester.pumpAndSettle();

    rows = await tester.runAsync(() => _db.select(_db.events).get());
    expect(rows!.single.deletedAt, isNotNull);
  });

  testWidgets('saving a future reminder registers a notification', (
    tester,
  ) async {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final repo = await _init(prefsValues: {'default_remind_offset': 5});
    await _pumpEditor(
      tester,
      date: tomorrow,
      startMinute: 540,
      initialKind: EventKind.reminder,
    );

    await _enter(tester, 'editor-title', 'Remind me');
    await _save(tester);

    final rows = await tester.runAsync(() => repo.eventsOnDay(tomorrow));
    expect(rows, hasLength(1));
    expect(_fake.scheduled, hasLength(1));
    expect(_fake.scheduled.single.payload, startsWith('event:'));
    expect(
      _fake.scheduled.single.at,
      DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 8, 55),
    );
  });
}

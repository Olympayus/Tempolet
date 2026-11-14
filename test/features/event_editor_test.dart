import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tempolet/core/l10n/generated/app_localizations.dart';
import 'package:tempolet/core/prefs.dart';
import 'package:tempolet/data/database/database.dart';
import 'package:tempolet/data/repositories/event_repository.dart';
import 'package:tempolet/features/events/event_draft.dart';
import 'package:tempolet/features/events/event_editor_sheet.dart';
import 'package:tempolet/notifications/fake_notification_service.dart';
import 'package:tempolet/notifications/notification_scheduler.dart';

late AppDatabase _db;
late ProviderContainer _container;
late FakeNotificationService _fake;

Future<void> _pumpHost(
  WidgetTester tester, {
  Event? existing,
  DateTime? date,
  int? startMinute,
  int? endMinute,
  EventKind? initialKind,
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

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: _container,
      child: MaterialApp(
        locale: const Locale('en'),
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

void main() {
  testWidgets('drag-style entry prefills kind and time range', (tester) async {
    await _pumpHost(
      tester,
      date: DateTime(2026, 11, 11),
      startMinute: 570,
      endMinute: 630,
      initialKind: EventKind.plan,
    );

    expect(find.text('09:30'), findsOneWidget);
    expect(find.text('10:30'), findsOneWidget);
    final segmented = tester.widget<SegmentedButton<EventKind>>(
      find.byType(SegmentedButton<EventKind>),
    );
    expect(segmented.selected, {EventKind.plan});
  });

  testWidgets('tap-style entry prefills a reminder at a time', (tester) async {
    await _pumpHost(
      tester,
      date: DateTime(2026, 11, 11),
      startMinute: 540,
      initialKind: EventKind.reminder,
    );

    expect(find.text('09:00'), findsOneWidget);
    final segmented = tester.widget<SegmentedButton<EventKind>>(
      find.byType(SegmentedButton<EventKind>),
    );
    expect(segmented.selected, {EventKind.reminder});
  });

  testWidgets('saving creates an event that shows up in the day stream',
      (tester) async {
    await _pumpHost(
      tester,
      date: DateTime(2026, 11, 11),
      startMinute: 540,
      initialKind: EventKind.reminder,
    );

    await tester.enterText(
        find.byKey(const ValueKey('editor-title')), 'Standup');
    await tester.ensureVisible(find.byKey(const ValueKey('editor-save')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('editor-save')));
    await tester.pumpAndSettle();

    final rows = await tester.runAsync(() => _db.select(_db.events).get());
    expect(rows!, hasLength(1));
    expect(rows.single.title, 'Standup');
    expect(rows.single.startMinute, 540);
  });

  testWidgets('empty title blocks saving and shows an error', (tester) async {
    await _pumpHost(
      tester,
      date: DateTime(2026, 11, 11),
      startMinute: 540,
      initialKind: EventKind.reminder,
    );

    await tester.ensureVisible(find.byKey(const ValueKey('editor-save')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('editor-save')));
    await tester.pumpAndSettle();

    expect(find.text('Please enter a title'), findsOneWidget);
    final rows = await tester.runAsync(() => _db.select(_db.events).get());
    expect(rows!, isEmpty);
  });

  testWidgets('editing an existing event updates it', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final db = AppDatabase(NativeDatabase.memory());
    final repo = EventRepository(db);
    final existing = await repo.create(
      title: 'Old',
      kind: 'reminder',
      date: DateTime(2026, 11, 11),
      startMinute: 540,
    );

    _db = db;
    _container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        databaseProvider.overrideWithValue(db),
        notificationServiceProvider
            .overrideWithValue(FakeNotificationService()),
      ],
    );
    addTearDown(() async {
      _container.dispose();
      await db.close();
    });

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: _container,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showEventEditor(context, existing: existing),
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
        find.byKey(const ValueKey('editor-title')), 'New');
    await tester.ensureVisible(find.byKey(const ValueKey('editor-save')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('editor-save')));
    await tester.pumpAndSettle();

    final rows = await tester.runAsync(() => _db.select(_db.events).get());
    expect(rows!.single.title, 'New');
  });

  testWidgets('deleting an existing event hides it', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final db = AppDatabase(NativeDatabase.memory());
    final repo = EventRepository(db);
    final existing = await repo.create(
      title: 'Bye',
      kind: 'reminder',
      date: DateTime(2026, 11, 11),
      startMinute: 540,
    );

    _db = db;
    _container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        databaseProvider.overrideWithValue(db),
        notificationServiceProvider
            .overrideWithValue(FakeNotificationService()),
      ],
    );
    addTearDown(() async {
      _container.dispose();
      await db.close();
    });

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: _container,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showEventEditor(context, existing: existing),
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

    await tester.ensureVisible(find.byKey(const ValueKey('editor-delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('editor-delete')));
    await tester.pumpAndSettle();

    final rows = await tester.runAsync(() => _db.select(_db.events).get());
    expect(rows!, hasLength(1));
    expect(rows.single.deletedAt, isNotNull);
  });

  testWidgets('saving a future reminder registers a notification',
      (tester) async {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    await _pumpHost(
      tester,
      date: tomorrow,
      startMinute: 540,
      initialKind: EventKind.reminder,
      prefsValues: {'default_remind_offset': 5},
    );

    await tester.enterText(
        find.byKey(const ValueKey('editor-title')), 'Remind me');
    await tester.ensureVisible(find.byKey(const ValueKey('editor-save')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('editor-save')));
    await tester.pumpAndSettle();

    final rows = await tester.runAsync(() => _db.select(_db.events).get());
    expect(rows!, hasLength(1));
    expect(_fake.scheduled, hasLength(1));
    expect(_fake.scheduled.single.payload, startsWith('event:'));
    expect(
      _fake.scheduled.single.at,
      DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 8, 55),
    );
  });
}

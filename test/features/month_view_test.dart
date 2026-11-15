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
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const CalendarPage(),
    ),
  );
}

void main() {
  late AppDatabase db;
  late ProviderContainer container;
  late EventRepository repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
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
    container.read(selectedDayProvider.notifier).select(DateTime(2026, 11, 11));
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<Event> seed(
    String title, {
    int? startMinute = 540,
    String kind = 'reminder',
  }) {
    return repo.create(
      title: title,
      kind: kind,
      date: DateTime(2026, 11, 11),
      startMinute: startMinute,
    );
  }

  testWidgets('grid has no adjacent-month cells and shows an ellipsis', (
    tester,
  ) async {
    await seed('E1', startMinute: 540);
    await seed('E2', startMinute: 600);
    await seed('E3', startMinute: 660);
    await tester.pumpWidget(_app(container));
    await _settle(tester);

    expect(find.textContaining('E3'), findsNothing);
    expect(find.byKey(const ValueKey('month-more-2026-11-11')), findsOneWidget);
    expect(find.textContaining('Oct'), findsNothing);
  });

  testWidgets('single click opens preview without changing view mode', (
    tester,
  ) async {
    await tester.pumpWidget(_app(container));
    await _settle(tester);

    await tester.tap(find.byKey(const ValueKey('day-2026-11-11')));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('month-preview')), findsOneWidget);
    expect(container.read(calendarViewModeProvider), CalendarViewMode.month);
  });

  testWidgets('double click selects the day and opens the sidebar', (
    tester,
  ) async {
    await tester.pumpWidget(_app(container));
    await _settle(tester);

    final cell = find.byKey(const ValueKey('day-2026-11-11'));
    await tester.tap(cell);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(cell);
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(container.read(selectedDayProvider), DateTime(2026, 11, 11));
    expect(container.read(sidebarPreferenceProvider), isTrue);
    expect(find.byKey(const ValueKey('month-preview')), findsNothing);
  });

  testWidgets('header navigation moves the month grid', (tester) async {
    await tester.pumpWidget(_app(container));
    await _settle(tester);
    expect(find.byKey(const ValueKey('day-2026-11-01')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('calendar-next')));
    await _settle(tester);

    expect(find.byKey(const ValueKey('day-2026-12-01')), findsOneWidget);
    expect(find.byKey(const ValueKey('day-2026-11-01')), findsNothing);
  });

  testWidgets('checking a preview row completes the event', (tester) async {
    final event = await seed('Buy milk', startMinute: 540);
    await tester.pumpWidget(_app(container));
    await _settle(tester);

    await tester.tap(find.byKey(const ValueKey('day-2026-11-11')));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(ValueKey('preview-complete-${event.id}')));
    await tester.pump(const Duration(milliseconds: 150));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );

    expect(find.byKey(const ValueKey('editor-save')), findsNothing);
    final events = await tester.runAsync(
      () => repo.eventsOnDay(DateTime(2026, 11, 11)),
    );
    expect(events!.single.isCompleted, isTrue);
  });
}

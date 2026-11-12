import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tempolet/core/l10n/generated/app_localizations.dart';
import 'package:tempolet/core/prefs.dart';
import 'package:tempolet/data/database/database.dart';
import 'package:tempolet/data/repositories/event_repository.dart';
import 'package:tempolet/features/calendar/calendar_state.dart';
import 'package:tempolet/features/calendar/time_grid.dart';
import 'package:tempolet/features/calendar/week_view.dart';

Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)));
  await tester.pumpAndSettle();
}

Widget _app(ProviderContainer container, Widget child) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
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
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  testWidgets('renders seven day headers for the week of 2026-11-11',
      (tester) async {
    await tester.pumpWidget(
      _app(container, WeekView(weekStart: DateTime(2026, 11, 11))),
    );
    await _settle(tester);

    // Mon 9 … Sun 15
    for (final day in ['9', '10', '11', '12', '13', '14', '15']) {
      expect(find.text(day), findsOneWidget);
    }
    expect(find.byKey(const ValueKey('week-day-2026-11-11')), findsOneWidget);
  });

  testWidgets('starts scrolled to 08:00', (tester) async {
    await tester.pumpWidget(
      _app(container, WeekView(weekStart: DateTime(2026, 11, 11))),
    );
    await _settle(tester);

    final scroll = tester
        .widget<SingleChildScrollView>(find.byKey(const ValueKey('week-scroll')));
    expect(scroll.controller!.offset, closeTo(kDefaultScrollOffset, 0.5));
  });

  testWidgets('renders events inside their day column', (tester) async {
    await repo.create(
      title: 'WeekItem',
      kind: 'reminder',
      date: DateTime(2026, 11, 11),
      startMinute: 540,
    );

    await tester.pumpWidget(
      _app(container, WeekView(weekStart: DateTime(2026, 11, 11))),
    );
    await _settle(tester);

    expect(find.text('WeekItem'), findsOneWidget);
  });

  testWidgets('tapping a day header opens that day in day view',
      (tester) async {
    await tester.pumpWidget(
      _app(container, WeekView(weekStart: DateTime(2026, 11, 11))),
    );
    await _settle(tester);

    await tester.tap(find.byKey(const ValueKey('week-day-2026-11-11')));
    await _settle(tester);

    expect(container.read(selectedDayProvider), DateTime(2026, 11, 11));
    expect(container.read(calendarViewModeProvider), CalendarViewMode.day);
  });
}

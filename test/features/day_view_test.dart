import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tempolet/core/prefs.dart';
import 'package:tempolet/core/l10n/generated/app_localizations.dart';
import 'package:tempolet/data/database/database.dart';
import 'package:tempolet/data/repositories/event_repository.dart';
import 'package:tempolet/features/calendar/day_view.dart';
import 'package:tempolet/features/calendar/time_grid.dart';

Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)));
  await tester.pumpAndSettle();
}

Widget _app(AppDatabase db, ProviderContainer container, Widget child) {
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
  group('time grid maths', () {
    test('minuteToY maps one hour to one kHourHeight', () {
      expect(minuteToY(60), 56);
      expect(minuteToY(8 * 60), 8 * 56);
    });

    test('yToMinute inverts minuteToY', () {
      expect(yToMinute(56), 60);
      expect(yToMinute(0), 0);
    });

    test('drag selection snaps both ends to 5 minutes', () {
      final selection = selectionFromDrag(542, 658);
      expect(selection.start, 540);
      expect(selection.end, 660);
    });

    test('reversed drags are ordered', () {
      final selection = selectionFromDrag(658, 542);
      expect(selection.start, 540);
      expect(selection.end, 660);
    });
  });

  group('day view', () {
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

    Future<Event> seed({
      required String title,
      DateTime? day,
      int startMinute = 540,
      String kind = 'reminder',
    }) {
      return repo.create(
        title: title,
        kind: kind,
        date: day ?? DateTime(2026, 11, 11),
        startMinute: startMinute,
      );
    }

    testWidgets('starts scrolled to 08:00', (tester) async {
      await tester.pumpWidget(
          _app(db, container, DayView(day: DateTime(2026, 11, 11))));
      await _settle(tester);

      final scroll =
          tester.widget<SingleChildScrollView>(find.byKey(const ValueKey('day-scroll')));
      expect(scroll.controller!.offset, closeTo(kDefaultScrollOffset, 0.5));
    });

    testWidgets('tapping an empty slot opens a reminder at the snapped minute',
        (tester) async {
      await tester.pumpWidget(_app(db, container, DayView(day: DateTime(2026, 11, 11))));
      await _settle(tester);

      final rect = tester.getRect(find.byKey(const ValueKey('day-scroll')));
      // Content y = 504 → 09:00; subtract the scroll offset to get the screen y.
      final x = rect.center.dx;
      final y = rect.top + (minuteToY(9 * 60) - kDefaultScrollOffset);

      await tester.tapAt(Offset(x, y));
      await _settle(tester);

      expect(find.byKey(const ValueKey('editor-save')), findsOneWidget);
      expect(find.text('09:00'), findsWidgets);
    });

    testWidgets('the completion circle persists through the repository',
        (tester) async {
      final event = await seed(title: 'Standup');

      await tester.pumpWidget(_app(db, container, DayView(day: DateTime(2026, 11, 11))));
      await _settle(tester);

      await tester.tap(find.byKey(ValueKey('complete-${event.id}')));
      await _settle(tester);

      final rows = await tester.runAsync(() => db.select(db.events).get());
      expect(rows!.single.isCompleted, isTrue);
      expect(rows.single.completedAt, isNotNull);
    });

    testWidgets('yesterday\'s event is marked overdue', (tester) async {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      await seed(title: 'Old thing', day: yesterday);

      await tester.pumpWidget(_app(
        db,
        container,
        DayView(day: yesterday),
      ));
      await _settle(tester);

      expect(find.textContaining('Overdue'), findsOneWidget);
    });
  });
}
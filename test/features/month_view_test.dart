import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tempolet/core/l10n/generated/app_localizations.dart';
import 'package:tempolet/data/database/database.dart';
import 'package:tempolet/features/calendar/calendar_state.dart';
import 'package:tempolet/features/calendar/month_view.dart';

Future<void> _seedEvent(
  AppDatabase db, {
  required String title,
  required DateTime day,
  required int startMinute,
}) async {
  final now = DateTime.now();
  await db.into(db.events).insert(
        EventsCompanion.insert(
          id: title,
          title: title,
          kind: 'reminder',
          date: DateTime(day.year, day.month, day.day),
          startMinute: Value(startMinute),
          notificationId: title.hashCode & 0x7FFFFFFF,
          createdAt: now,
          updatedAt: now,
        ),
      );
}

Future<void> _settle(WidgetTester tester) async {
  // Drift streams resolve through real async I/O, which fake-async pumping
  // does not drive on its own.
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
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  group('month grid maths', () {
    test('firstDayOfMonth normalises to the first', () {
      expect(firstDayOfMonth(DateTime(2026, 11, 11, 5, 6)),
          DateTime(2026, 11, 1));
    });

    test('2026-11 grid starts on Oct 26 and ends on Dec 6', () {
      final days = monthGridDays(DateTime(2026, 11));
      expect(days, hasLength(42));
      expect(days.first, DateTime(2026, 10, 26));
      expect(days.last, DateTime(2026, 12, 6));
    });

    test('2028-02 (leap) has 29 in-month days', () {
      final days = monthGridDays(DateTime(2028, 2));
      expect(
        days.where((d) => d!.month == 2).length,
        29,
      );
    });
  });

  testWidgets('cells show two rows plus a +N overflow marker', (tester) async {
    await _seedEvent(db, title: 'E1', day: DateTime(2026, 11, 11), startMinute: 540);
    await _seedEvent(db, title: 'E2', day: DateTime(2026, 11, 11), startMinute: 600);
    await _seedEvent(db, title: 'E3', day: DateTime(2026, 11, 11), startMinute: 660);

    await tester.pumpWidget(_app(db, container,
        MonthView(month: DateTime(2026, 11))));
    await _settle(tester);

    expect(find.textContaining('E1'), findsOneWidget);
    expect(find.textContaining('E2'), findsOneWidget);
    expect(find.textContaining('E3'), findsNothing);
    expect(find.text('+1'), findsOneWidget);
  });

  testWidgets('holidays render in red under the day number', (tester) async {
    await db.into(db.holidays).insert(
          HolidaysCompanion.insert(
            date: DateTime(2026, 11, 11),
            name: 'Test Holiday',
          ),
        );

    await tester.pumpWidget(_app(db, container,
        MonthView(month: DateTime(2026, 11))));
    await _settle(tester);

    final holiday = tester.widget<Text>(find.text('Test Holiday'));
    expect(holiday.style?.color,
        Theme.of(tester.element(find.text('Test Holiday'))).colorScheme.error);
  });

  testWidgets('tapping a day selects it and switches to the day view',
      (tester) async {
    await tester.pumpWidget(_app(db, container,
        MonthView(month: DateTime(2026, 11))));
    await _settle(tester);

    await tester.tap(find.byKey(const ValueKey('day-2026-11-11')));
    await _settle(tester);

    expect(container.read(selectedDayProvider), DateTime(2026, 11, 11));
    expect(container.read(calendarViewModeProvider), CalendarViewMode.day);
  });

  testWidgets('hovering a day shows a summary without changing selection',
      (tester) async {
    await _seedEvent(db, title: 'HoverRow', day: DateTime(2026, 11, 11), startMinute: 540);

    await tester.pumpWidget(_app(db, container,
        MonthView(month: DateTime(2026, 11))));
    await _settle(tester);

    final before = container.read(selectedDayProvider);
    final center = tester.getCenter(find.byKey(const ValueKey('day-2026-11-11')));

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    await gesture.moveTo(center);
    await _settle(tester);

    expect(find.byKey(const ValueKey('day-summary-popover')), findsOneWidget);
    expect(container.read(selectedDayProvider), before);

    await gesture.moveTo(const Offset(1, 1));
    await _settle(tester);
    expect(find.byKey(const ValueKey('day-summary-popover')), findsNothing);
  });
}

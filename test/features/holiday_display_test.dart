import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tempolet/core/l10n/generated/app_localizations.dart';
import 'package:tempolet/core/prefs.dart';
import 'package:tempolet/core/theme/app_tokens.dart';
import 'package:tempolet/core/utils/dates.dart';
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
      locale: const Locale('zh'),
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

  Future<void> insertHoliday(
    DateTime date,
    String name, {
    required bool isWorkday,
  }) {
    return db
        .into(db.holidays)
        .insert(
          HolidaysCompanion.insert(
            date: dateOnly(date),
            name: name,
            isWorkday: Value(isWorkday),
            source: const Value('seed'),
            updatedAt: Value(DateTime.now()),
          ),
        );
  }

  Future<Event> seed(String title, {int startMinute = 540}) {
    return repo.create(
      title: title,
      kind: 'reminder',
      date: DateTime(2026, 11, 11),
      startMinute: startMinute,
    );
  }

  testWidgets('month cell shows the festival name and 休/班 pills', (
    tester,
  ) async {
    await insertHoliday(
      DateTime(2026, 11, 11),
      'Test Holiday',
      isWorkday: false,
    );
    await insertHoliday(DateTime(2026, 11, 12), '班', isWorkday: true);

    await tester.pumpWidget(_app(container));
    await _settle(tester);

    final name = tester.widget<Text>(find.text('Test Holiday'));
    expect(name.style?.color, AppPalette.light.festival);

    final offPill = tester.widget<Text>(find.text('休'));
    expect(offPill.style?.color, AppPalette.light.festival);
    final offBadge = tester.widget<Container>(
      find.byKey(const ValueKey('holiday-badge-2026-11-11')),
    );
    expect(
      (offBadge.decoration! as BoxDecoration).color,
      AppPalette.light.festivalTint,
    );

    // A 调休 workday gets the gray pill only, never the festival name.
    final workPill = tester.widget<Text>(find.text('班'));
    expect(workPill.style?.color, AppPalette.light.sub);
    final workBadge = tester.widget<Container>(
      find.byKey(const ValueKey('holiday-badge-2026-11-12')),
    );
    expect(
      (workBadge.decoration! as BoxDecoration).color,
      AppPalette.light.chip,
    );
  });

  testWidgets('holiday info never consumes one of the two event rows', (
    tester,
  ) async {
    // Match month_view_test: the 8/10 + 32 density needs the taller viewport
    // to show two event rows; keep the width under the sidebar breakpoint.
    tester.view.physicalSize = const Size(1100, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await insertHoliday(
      DateTime(2026, 11, 11),
      'Test Holiday',
      isWorkday: false,
    );
    await seed('E1', startMinute: 540);
    await seed('E2', startMinute: 600);
    await seed('E3', startMinute: 660);

    await tester.pumpWidget(_app(container));
    await _settle(tester);

    expect(find.text('Test Holiday'), findsOneWidget);
    expect(find.text('休'), findsOneWidget);
    expect(find.text('E1'), findsOneWidget);
    expect(find.text('E2'), findsOneWidget);
    // The third event still overflows into the ellipsis, exactly as it does
    // on days without holiday data.
    expect(find.text('E3'), findsNothing);
    expect(find.byKey(const ValueKey('month-more-2026-11-11')), findsOneWidget);
  });

  testWidgets('day header appends the holiday name with festival styling', (
    tester,
  ) async {
    await insertHoliday(
      DateTime(2026, 11, 11),
      'Test Holiday',
      isWorkday: false,
    );
    container.read(calendarViewModeProvider.notifier).set(CalendarViewMode.day);

    await tester.pumpWidget(_app(container));
    await _settle(tester);

    final title = tester.widget<Text>(
      find.byKey(const ValueKey('calendar-title')),
    );
    final span = title.textSpan! as TextSpan;
    expect(span.toPlainText(), '2026年11月11日 · Test Holiday');
    final holidaySpan = span.children!.last as TextSpan;
    expect(holidaySpan.text, ' · Test Holiday');
    expect(holidaySpan.style?.color, AppPalette.light.festival);
  });

  testWidgets('month preview header appends the holiday name', (tester) async {
    await insertHoliday(
      DateTime(2026, 11, 11),
      'Test Holiday',
      isWorkday: false,
    );

    await tester.pumpWidget(_app(container));
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('month-day-2026-11-11')));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    final title = tester.widget<Text>(find.text('11月11日 周三 · Test Holiday'));
    final holidaySpan =
        (title.textSpan! as TextSpan).children!.last as TextSpan;
    expect(holidaySpan.style?.color, AppPalette.light.festival);
  });

  testWidgets('week headers show only the 休/班 pill, never the name', (
    tester,
  ) async {
    await insertHoliday(
      DateTime(2026, 11, 11),
      'Test Holiday',
      isWorkday: false,
    );
    await insertHoliday(DateTime(2026, 11, 12), '班', isWorkday: true);
    container
        .read(calendarViewModeProvider.notifier)
        .set(CalendarViewMode.week);

    await tester.pumpWidget(_app(container));
    await _settle(tester);

    expect(find.text('休'), findsOneWidget);
    expect(find.text('班'), findsOneWidget);
    expect(find.text('Test Holiday'), findsNothing);
  });
}

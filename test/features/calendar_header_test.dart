import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tempolet/core/l10n/generated/app_localizations.dart';
import 'package:tempolet/core/prefs.dart';
import 'package:tempolet/core/utils/dates.dart';
import 'package:tempolet/data/database/database.dart';
import 'package:tempolet/features/calendar/calendar_header.dart';
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

Widget _app(ProviderContainer container, {bool reduceMotion = false}) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: reduceMotion
          ? (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: child!,
            )
          : null,
      home: const CalendarPage(),
    ),
  );
}

/// Text inside the shared header, ignoring any legacy headers still rendered
/// by the month/week/day bodies (removed by tasks 6-8).
Finder _headerText(String text) =>
    find.descendant(of: find.byType(CalendarHeader), matching: find.text(text));

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    db = AppDatabase(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        databaseProvider.overrideWithValue(db),
        notificationServiceProvider.overrideWithValue(
          FakeNotificationService(),
        ),
      ],
    );
    container.read(selectedDayProvider.notifier).select(DateTime(2026, 11, 10));
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  testWidgets('header shows the month title and switches views', (
    tester,
  ) async {
    await tester.pumpWidget(_app(container));
    await _settle(tester);

    expect(_headerText('November 2026'), findsOneWidget);
    expect(
      tester
          .getSize(
            find.descendant(
              of: find.byType(CalendarHeader),
              matching: find.byType(SegmentedButton<CalendarViewMode>),
            ),
          )
          .height,
      26,
    );

    await tester.tap(_headerText('Week'));
    await tester.pumpAndSettle();
    expect(container.read(calendarViewModeProvider), CalendarViewMode.week);
    expect(_headerText('Nov 9 – 15, 2026'), findsOneWidget);

    await tester.tap(_headerText('Day'));
    await tester.pumpAndSettle();
    expect(container.read(calendarViewModeProvider), CalendarViewMode.day);
    expect(_headerText('Nov 10, 2026'), findsOneWidget);

    await tester.tap(_headerText('Month'));
    await tester.pumpAndSettle();
    expect(container.read(calendarViewModeProvider), CalendarViewMode.month);
    expect(_headerText('November 2026'), findsOneWidget);
  });

  testWidgets('month arrows clamp the selected day', (tester) async {
    container.read(selectedDayProvider.notifier).select(DateTime(2026, 1, 31));
    await tester.pumpWidget(_app(container));
    await _settle(tester);

    await tester.tap(find.byKey(const ValueKey('calendar-prev')));
    await tester.pumpAndSettle();
    expect(container.read(selectedDayProvider), DateTime(2025, 12, 31));
    expect(_headerText('December 2025'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('calendar-next')));
    await tester.pumpAndSettle();
    expect(container.read(selectedDayProvider), DateTime(2026, 1, 31));

    // February has no 31st, so the day-of-month clamps to 28.
    await tester.tap(find.byKey(const ValueKey('calendar-next')));
    await tester.pumpAndSettle();
    expect(container.read(selectedDayProvider), DateTime(2026, 2, 28));
    expect(_headerText('February 2026'), findsOneWidget);
  });

  testWidgets('week and day arrows shift by their own step', (tester) async {
    container
        .read(calendarViewModeProvider.notifier)
        .set(CalendarViewMode.week);
    container.read(selectedDayProvider.notifier).select(DateTime(2026, 11, 11));
    await tester.pumpWidget(_app(container));
    await _settle(tester);

    await tester.tap(find.byKey(const ValueKey('calendar-next')));
    await tester.pumpAndSettle();
    expect(container.read(selectedDayProvider), DateTime(2026, 11, 18));

    container.read(calendarViewModeProvider.notifier).set(CalendarViewMode.day);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('calendar-prev')));
    await tester.pumpAndSettle();
    expect(container.read(selectedDayProvider), DateTime(2026, 11, 17));
  });

  testWidgets('today selects the current date', (tester) async {
    container.read(selectedDayProvider.notifier).select(DateTime(2026, 3, 4));
    await tester.pumpWidget(_app(container));
    await _settle(tester);

    await tester.tap(_headerText('Today'));
    await tester.pumpAndSettle();

    expect(container.read(selectedDayProvider), dateOnly(DateTime.now()));
  });

  testWidgets('new opens the editor on the selected date', (tester) async {
    container.read(selectedDayProvider.notifier).select(DateTime(2026, 11, 12));
    await tester.pumpWidget(_app(container));
    await _settle(tester);

    await tester.tap(find.byKey(const ValueKey('calendar-new')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('editor-save')), findsOneWidget);
    expect(find.text('Nov 12, 2026'), findsOneWidget);
  });

  testWidgets('sidebar toggle flips the preference and hides in day mode', (
    tester,
  ) async {
    // Wide enough to host the 280px sidebar (the engine default 800px sits
    // below the app's 960px minimum and would squeeze the header).
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_app(container));
    await _settle(tester);

    expect(
      find.byKey(const ValueKey('calendar-sidebar-toggle')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('calendar-sidebar-toggle')));
    await tester.pump();
    expect(container.read(sidebarPreferenceProvider), isTrue);
    await tester.tap(find.byKey(const ValueKey('calendar-sidebar-toggle')));
    await tester.pump();
    expect(container.read(sidebarPreferenceProvider), isFalse);

    container.read(calendarViewModeProvider.notifier).set(CalendarViewMode.day);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('calendar-sidebar-toggle')), findsNothing);
  });

  testWidgets(
    'content cross-fades in 120ms and instantly with reduced motion',
    (tester) async {
      await tester.pumpWidget(_app(container));
      await _settle(tester);

      expect(find.byType(CalendarHeader), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AnimatedSwitcher),
          matching: find.byType(CalendarHeader),
        ),
        findsNothing,
      );
      expect(
        tester.widget<AnimatedSwitcher>(find.byType(AnimatedSwitcher)).duration,
        const Duration(milliseconds: 120),
      );

      await tester.pumpWidget(_app(container, reduceMotion: true));
      await tester.pumpAndSettle();
      expect(
        tester.widget<AnimatedSwitcher>(find.byType(AnimatedSwitcher)).duration,
        Duration.zero,
      );
    },
  );
}

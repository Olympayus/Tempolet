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
import 'package:tempolet/features/calendar/calendar_header.dart';
import 'package:tempolet/features/calendar/calendar_state.dart';
import 'package:tempolet/features/calendar/time_grid.dart';
import 'package:tempolet/features/calendar/week_view.dart';
import 'package:tempolet/notifications/fake_notification_service.dart';
import 'package:tempolet/notifications/notification_scheduler.dart';

Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 30)),
  );
  await tester.pumpAndSettle();
}

Widget _app(ProviderContainer container, Widget child) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    ),
  );
}

/// Reads the time shown by the editor's start/end stepper. Hour-grid tick
/// labels behind the dialog must not satisfy these assertions.
String _stepperText(WidgetTester tester, String key) {
  return tester
      .widget<Text>(
        find.descendant(
          of: find.byKey(ValueKey(key)),
          matching: find.byType(Text),
        ),
      )
      .data!;
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
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<Event> seed({
    required String title,
    required DateTime day,
    String kind = 'reminder',
    int startMinute = 540,
    int? endMinute,
  }) {
    return repo.create(
      title: title,
      kind: kind,
      date: day,
      startMinute: startMinute,
      endMinute: endMinute,
    );
  }

  Future<void> pumpWeek(WidgetTester tester, DateTime day) async {
    container.read(selectedDayProvider.notifier).select(day);
    await tester.pumpWidget(_app(container, const WeekView()));
    await _settle(tester);
  }

  group('week view', () {
    testWidgets(
      'week header single click selects, double click opens day view',
      (tester) async {
        container
            .read(calendarViewModeProvider.notifier)
            .set(CalendarViewMode.week);
        await pumpWeek(tester, DateTime(2026, 11, 11));

        await tester.tap(find.byKey(const ValueKey('week-day-2026-11-11')));
        await tester.pump(const Duration(milliseconds: 350));
        expect(container.read(selectedDayProvider), DateTime(2026, 11, 11));
        expect(container.read(calendarViewModeProvider), CalendarViewMode.week);

        await tester.tap(find.byKey(const ValueKey('week-day-2026-11-12')));
        await tester.pump(const Duration(milliseconds: 50));
        await tester.tap(find.byKey(const ValueKey('week-day-2026-11-12')));
        await tester.pump(const Duration(milliseconds: 350));
        expect(container.read(selectedDayProvider), DateTime(2026, 11, 12));
        expect(container.read(calendarViewModeProvider), CalendarViewMode.day);
      },
    );

    testWidgets('today column has a tint', (tester) async {
      await pumpWeek(tester, dateOnly(DateTime.now()));

      expect(find.byKey(const ValueKey('week-today-column')), findsOneWidget);
      final tint = tester.widget<ColoredBox>(
        find.descendant(
          of: find.byKey(const ValueKey('week-today-column')),
          matching: find.byType(ColoredBox),
        ),
      );
      expect(tint.color, AppPalette.light.todayColumn);
    });

    testWidgets('renders seven keyed headers for the week of 2026-11-11', (
      tester,
    ) async {
      await pumpWeek(tester, DateTime(2026, 11, 11));

      for (final day in ['09', '10', '11', '12', '13', '14', '15']) {
        expect(find.byKey(ValueKey('week-day-2026-11-$day')), findsOneWidget);
      }
      expect(find.text('周一'), findsOneWidget);
      expect(find.text('11月9日'), findsOneWidget);
    });

    testWidgets('starts scrolled to the default viewport', (tester) async {
      await pumpWeek(tester, DateTime(2026, 11, 11));

      final scroll = tester.widget<SingleChildScrollView>(
        find.byKey(const ValueKey('week-scroll')),
      );
      expect(scroll.controller!.offset, closeTo(kDefaultScrollOffset, 0.5));
    });

    testWidgets('renders events inside their day column', (tester) async {
      await seed(title: 'WeekItem', day: DateTime(2026, 11, 11));

      await pumpWeek(tester, DateTime(2026, 11, 11));

      expect(find.text('WeekItem'), findsOneWidget);
    });

    testWidgets(
      'tapping an empty slot opens a reminder at the snapped minute',
      (tester) async {
        await pumpWeek(tester, DateTime(2026, 11, 11));

        final column = tester.getRect(
          find.byKey(const ValueKey('week-column-2026-11-11')),
        );
        await tester.tapAt(
          Offset(column.left + 20, column.top + minuteToY(9 * 60)),
        );
        await _settle(tester);

        expect(find.byKey(const ValueKey('editor-save')), findsOneWidget);
        expect(find.byKey(const ValueKey('end-stepper')), findsNothing);
        expect(_stepperText(tester, 'start-stepper'), '09:00');
      },
    );

    testWidgets('dragging an empty slot opens a plan over the dragged range', (
      tester,
    ) async {
      await pumpWeek(tester, DateTime(2026, 11, 11));

      final column = tester.getRect(
        find.byKey(const ValueKey('week-column-2026-11-11')),
      );
      await tester.dragFrom(
        Offset(column.left + 20, column.top + minuteToY(9 * 60)),
        const Offset(0, 34),
      );
      await _settle(tester);

      expect(find.byKey(const ValueKey('editor-save')), findsOneWidget);
      expect(find.byKey(const ValueKey('end-stepper')), findsOneWidget);
      // The hour-grid ticks behind the dialog also read 09:00/10:00, so read
      // the editor's own steppers to prove the drag range was prefilled.
      expect(_stepperText(tester, 'start-stepper'), '09:00');
      expect(_stepperText(tester, 'end-stepper'), '10:00');
    });

    testWidgets('dragging an empty slot shows the accent selection preview', (
      tester,
    ) async {
      await pumpWeek(tester, DateTime(2026, 11, 11));

      final column = tester.getRect(
        find.byKey(const ValueKey('week-column-2026-11-11')),
      );
      final gesture = await tester.startGesture(
        Offset(column.left + 20, column.top + minuteToY(9 * 60)),
      );
      await gesture.moveBy(const Offset(0, 34));
      await tester.pump();

      final preview = tester.widget<Container>(
        find.byKey(const ValueKey('week-create-preview')),
      );
      final decoration = preview.decoration! as BoxDecoration;
      expect(decoration.color!.a, closeTo(.08, 0.001));

      // The preview must start at the press point (09:00) and span the
      // dragged hour, not begin after the touch slop.
      final previewRect = tester.getRect(
        find.byKey(const ValueKey('week-create-preview')),
      );
      expect(previewRect.top, closeTo(column.top + minuteToY(9 * 60), 0.5));
      expect(previewRect.height, closeTo(kHourHeight, 0.5));

      await gesture.up();
      await _settle(tester);
    });

    testWidgets('tapping a plan opens the shared editor', (tester) async {
      final plan = await seed(
        title: 'Deep work',
        day: DateTime(2026, 11, 11),
        kind: 'plan',
        startMinute: 780,
        endMinute: 840,
      );
      await pumpWeek(tester, DateTime(2026, 11, 11));

      await tester.tap(find.byKey(ValueKey('week-plan-${plan.id}')));
      await _settle(tester);

      expect(find.byKey(const ValueKey('editor-title')), findsOneWidget);
      expect(find.text('Deep work'), findsWidgets);
    });

    testWidgets('dragging a plan moves it with five-minute snapping', (
      tester,
    ) async {
      final plan = await seed(
        title: 'Move me',
        day: DateTime(2026, 11, 12),
        kind: 'plan',
        startMinute: 540,
        endMinute: 600,
      );
      await pumpWeek(tester, DateTime(2026, 11, 11));

      await tester.drag(
        find.byKey(ValueKey('week-plan-${plan.id}')),
        const Offset(0, 34),
      );
      await _settle(tester);

      final rows = await tester.runAsync(() => repo.getById(plan.id));
      expect(rows!.startMinute, 600);
      expect(rows.endMinute, 660);
    });

    testWidgets('dragging the bottom edge resizes the plan end', (
      tester,
    ) async {
      final plan = await seed(
        title: 'Resize me',
        day: DateTime(2026, 11, 12),
        kind: 'plan',
        startMinute: 540,
        endMinute: 600,
      );
      await pumpWeek(tester, DateTime(2026, 11, 11));

      final rect = tester.getRect(find.byKey(ValueKey('week-plan-${plan.id}')));
      final gesture = await tester.startGesture(
        Offset(rect.center.dx, rect.bottom - 2),
      );
      await gesture.moveBy(const Offset(0, 34));
      await gesture.up();
      await _settle(tester);

      final rows = await tester.runAsync(() => repo.getById(plan.id));
      expect(rows!.startMinute, 540);
      expect(rows.endMinute, 660);
    });

    testWidgets('overlapping plans split into lanes', (tester) async {
      final first = await seed(
        title: 'LaneOne',
        day: DateTime(2026, 11, 11),
        kind: 'plan',
        startMinute: 540,
        endMinute: 600,
      );
      final second = await seed(
        title: 'LaneTwo',
        day: DateTime(2026, 11, 11),
        kind: 'plan',
        startMinute: 540,
        endMinute: 600,
      );
      await pumpWeek(tester, DateTime(2026, 11, 11));

      final column = tester.getRect(
        find.byKey(const ValueKey('week-column-2026-11-11')),
      );
      final firstRect = tester.getRect(
        find.byKey(ValueKey('week-plan-${first.id}')),
      );
      final secondRect = tester.getRect(
        find.byKey(ValueKey('week-plan-${second.id}')),
      );

      expect(firstRect.width, closeTo(secondRect.width, 0.1));
      expect(firstRect.width, lessThan(column.width));
      expect(firstRect.left, isNot(closeTo(secondRect.left, 0.1)));
    });

    testWidgets('shows the now line even when today is not in the week', (
      tester,
    ) async {
      await pumpWeek(tester, DateTime(2020, 6, 10));

      expect(find.byKey(const ValueKey('week-now-line')), findsOneWidget);
    });

    testWidgets('follows the week selected by the shared header arrows', (
      tester,
    ) async {
      container
          .read(calendarViewModeProvider.notifier)
          .set(CalendarViewMode.week);
      container
          .read(selectedDayProvider.notifier)
          .select(DateTime(2026, 11, 11));

      await tester.pumpWidget(
        _app(
          container,
          const Column(
            children: [
              CalendarHeader(),
              Expanded(child: WeekView()),
            ],
          ),
        ),
      );
      await _settle(tester);

      expect(find.byKey(const ValueKey('week-day-2026-11-09')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('calendar-next')));
      await _settle(tester);

      expect(container.read(selectedDayProvider), DateTime(2026, 11, 18));
      expect(find.byKey(const ValueKey('week-day-2026-11-16')), findsOneWidget);
      expect(find.byKey(const ValueKey('week-day-2026-11-09')), findsNothing);
    });
  });
}

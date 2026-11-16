import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tempolet/core/l10n/generated/app_localizations.dart';
import 'package:tempolet/core/prefs.dart';
import 'package:tempolet/core/theme/app_tokens.dart';
import 'package:tempolet/core/ui/app_check_circle.dart';
import 'package:tempolet/core/utils/dates.dart';
import 'package:tempolet/data/database/database.dart';
import 'package:tempolet/data/repositories/event_repository.dart';
import 'package:tempolet/features/calendar/calendar_page.dart';
import 'package:tempolet/features/calendar/calendar_state.dart';
import 'package:tempolet/features/calendar/day_view.dart';
import 'package:tempolet/features/calendar/time_grid.dart';
import 'package:tempolet/features/events/fields/segmented_time_field.dart';
import 'package:tempolet/notifications/fake_notification_service.dart';
import 'package:tempolet/notifications/notification_scheduler.dart';

Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 30)),
  );
  await tester.pumpAndSettle();
}

/// Reads the time held by the editor's start/end segmented field. Hour-grid
/// tick labels behind the dialog must not satisfy these assertions.
String _stepperText(WidgetTester tester, String key) {
  final field = tester.widget<SegmentedTimeField>(
    find.descendant(
      of: find.byKey(ValueKey(key)),
      matching: find.byType(SegmentedTimeField),
    ),
  );
  return formatMinuteOfDay(field.value!);
}

Widget _app(
  ProviderContainer container,
  Widget home, {
  Locale locale = const Locale('zh'),
}) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    ),
  );
}

/// Gives the test a desktop-width window so the 216px day overview rail
/// (shown from 1100px) is part of the layout.
void _useWideWindow(WidgetTester tester) {
  tester.view.physicalSize = const Size(1400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// A viewport short enough that the 07:00 default offset is not clamped by
/// the end of the 24h canvas.
void _useShorterWindow(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 480);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  late AppDatabase db;
  late ProviderContainer container;
  late EventRepository repo;
  late FakeNotificationService notifications;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    db = AppDatabase(NativeDatabase.memory());
    repo = EventRepository(db);
    notifications = FakeNotificationService();
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        databaseProvider.overrideWithValue(db),
        notificationServiceProvider.overrideWithValue(notifications),
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
    int? reminderOffsetMinutes,
  }) {
    return repo.create(
      title: title,
      kind: kind,
      date: day,
      startMinute: startMinute,
      endMinute: endMinute,
      reminderOffsetMinutes: reminderOffsetMinutes,
    );
  }

  Future<void> pumpDay(
    WidgetTester tester,
    DateTime day, {
    Locale locale = const Locale('zh'),
  }) async {
    container.read(selectedDayProvider.notifier).select(day);
    await tester.pumpWidget(
      _app(container, const Scaffold(body: DayView()), locale: locale),
    );
    await _settle(tester);
  }

  group('day view', () {
    testWidgets('starts scrolled to the default viewport', (tester) async {
      _useShorterWindow(tester);
      await pumpDay(tester, DateTime(2026, 11, 11));

      final scroll = tester.widget<SingleChildScrollView>(
        find.byKey(const ValueKey('day-scroll')),
      );
      expect(scroll.controller!.offset, closeTo(kDefaultScrollOffset, 0.5));
    });

    testWidgets(
      'tapping an empty slot opens a reminder at the snapped minute',
      (tester) async {
        await pumpDay(tester, DateTime(2026, 11, 11));

        final rect = tester.getRect(find.byKey(const ValueKey('day-scroll')));
        final x = rect.center.dx;
        final y = rect.top + (minuteToY(9 * 60) - kDefaultScrollOffset);

        await tester.tapAt(Offset(x, y));
        await _settle(tester);

        expect(find.byKey(const ValueKey('editor-save')), findsOneWidget);
        expect(find.byKey(const ValueKey('end-stepper')), findsNothing);
        expect(find.text('09:00'), findsWidgets);
      },
    );

    testWidgets('dragging an empty slot opens a plan over the dragged range', (
      tester,
    ) async {
      await pumpDay(tester, DateTime(2026, 11, 11));

      final rect = tester.getRect(find.byKey(const ValueKey('day-scroll')));
      final offset = tester
          .widget<SingleChildScrollView>(
            find.byKey(const ValueKey('day-scroll')),
          )
          .controller!
          .offset;
      final x = rect.center.dx;
      final startY = rect.top + (minuteToY(9 * 60) - offset);

      await tester.dragFrom(Offset(x, startY), const Offset(0, 68));
      await _settle(tester);

      expect(find.byKey(const ValueKey('editor-save')), findsOneWidget);
      // Only plans expose an end time in the editor. The hour-grid ticks
      // behind the dialog also read 09:00/10:00, so read the editor's own
      // steppers to prove the drag range was prefilled.
      expect(find.byKey(const ValueKey('end-stepper')), findsOneWidget);
      expect(_stepperText(tester, 'start-stepper'), '09:00');
      expect(_stepperText(tester, 'end-stepper'), '10:00');
    });

    testWidgets('dragging a plan to the bottom clamps its end to midnight', (
      tester,
    ) async {
      final plan = await seed(
        title: 'Late plan',
        day: DateTime(2026, 11, 11),
        kind: 'plan',
        startMinute: 540,
        endMinute: 570,
      );
      await pumpDay(tester, DateTime(2026, 11, 11));

      await tester.drag(
        find.byKey(ValueKey('plan-${plan.id}')),
        const Offset(0, 1000),
      );
      await _settle(tester);

      final rows = await tester.runAsync(() => repo.getById(plan.id));
      expect(rows!.startMinute, 1410);
      expect(rows.endMinute, 1440);
    });

    testWidgets(
      'dragging a plan re-registers its notification at the new time',
      (tester) async {
        final day = DateTime(2030, 1, 2);
        final plan = await seed(
          title: 'Notify me',
          day: day,
          kind: 'plan',
          startMinute: 540,
          endMinute: 600,
          reminderOffsetMinutes: 10,
        );
        await pumpDay(tester, day);

        await tester.drag(
          find.byKey(ValueKey('plan-${plan.id}')),
          const Offset(0, 68),
        );
        await _settle(tester);

        expect(notifications.scheduled, hasLength(1));
        expect(notifications.scheduled.single.at, DateTime(2030, 1, 2, 9, 50));
      },
    );

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
      await pumpDay(tester, DateTime(2026, 11, 11));

      final timeline = tester.getRect(find.byKey(const ValueKey('day-scroll')));
      final firstRect = tester.getRect(
        find.byKey(ValueKey('plan-${first.id}')),
      );
      final secondRect = tester.getRect(
        find.byKey(ValueKey('plan-${second.id}')),
      );

      expect(firstRect.width, closeTo(secondRect.width, 0.1));
      expect(firstRect.width, lessThan(timeline.width));
      expect(firstRect.left, isNot(closeTo(secondRect.left, 0.1)));
    });

    testWidgets('tapping a plan opens the editor dialog', (tester) async {
      final plan = await seed(
        title: 'Deep work',
        day: DateTime(2026, 11, 11),
        kind: 'plan',
        startMinute: 540,
        endMinute: 600,
      );
      await pumpDay(tester, DateTime(2026, 11, 11));

      await tester.tap(find.byKey(ValueKey('plan-${plan.id}')));
      await _settle(tester);

      expect(find.byKey(const ValueKey('editor-title')), findsOneWidget);
      expect(find.text('Deep work'), findsWidgets);
    });

    testWidgets('completing a reminder removes it from the day', (
      tester,
    ) async {
      final reminder = await seed(
        title: 'Call back',
        day: DateTime(2026, 11, 11),
        startMinute: 750,
      );
      await pumpDay(tester, DateTime(2026, 11, 11));

      expect(find.byKey(ValueKey('reminder-${reminder.id}')), findsOneWidget);

      await tester.tap(find.byKey(ValueKey('complete-${reminder.id}')));
      await tester.pump(const Duration(milliseconds: 150));
      await _settle(tester);

      expect(find.byKey(ValueKey('reminder-${reminder.id}')), findsNothing);
      final rows = await tester.runAsync(() => db.select(db.events).get());
      expect(rows!.single.isCompleted, isTrue);
    });

    testWidgets(
      'yesterday\'s events are marked overdue with the danger token',
      (tester) async {
        final yesterday = dateOnly(DateTime.now())
            .subtract(const Duration(days: 1));
        await seed(title: 'Old reminder', day: yesterday, startMinute: 750);
        await seed(
          title: 'Old plan',
          day: yesterday,
          kind: 'plan',
          startMinute: 540,
          endMinute: 600,
        );

        await pumpDay(tester, yesterday);

        final reminderTime = tester.widget<Text>(find.text('12:30'));
        expect(reminderTime.style?.color, AppPalette.light.danger);
        final planTime = tester.widget<Text>(find.text('09:00–10:00'));
        expect(planTime.style?.color, AppPalette.light.danger);
      },
    );

    testWidgets('shows the now line only on today', (tester) async {
      await pumpDay(tester, dateOnly(DateTime.now()));
      expect(find.byKey(const ValueKey('day-now-line')), findsOneWidget);

      // Switching to another day disposes the today-only now line.
      container
          .read(selectedDayProvider.notifier)
          .select(DateTime(2026, 11, 11));
      await _settle(tester);
      expect(find.byKey(const ValueKey('day-now-line')), findsNothing);
    });

    testWidgets('follows the day selected by the shared header arrows', (
      tester,
    ) async {
      await seed(
        title: 'FirstDay',
        day: DateTime(2026, 11, 11),
        startMinute: 540,
      );
      await seed(
        title: 'SecondDay',
        day: DateTime(2026, 11, 12),
        startMinute: 540,
      );
      container
          .read(calendarViewModeProvider.notifier)
          .set(CalendarViewMode.day);
      container
          .read(selectedDayProvider.notifier)
          .select(DateTime(2026, 11, 11));

      await tester.pumpWidget(_app(container, const CalendarPage()));
      await _settle(tester);
      expect(find.text('FirstDay'), findsOneWidget);
      expect(find.text('SecondDay'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('calendar-next')));
      await _settle(tester);

      expect(container.read(selectedDayProvider), DateTime(2026, 11, 12));
      expect(find.text('FirstDay'), findsNothing);
      expect(find.text('SecondDay'), findsOneWidget);
    });

    testWidgets('right rail is a day overview without a week block', (
      tester,
    ) async {
      _useWideWindow(tester);
      final day = DateTime(2026, 11, 11);
      await seed(
        title: 'PlanA',
        day: day,
        kind: 'plan',
        startMinute: 540,
        endMinute: 600,
      );
      await seed(
        title: 'PlanB',
        day: day,
        kind: 'plan',
        startMinute: 660,
        endMinute: 720,
      );

      await pumpDay(tester, day, locale: const Locale('en'));

      expect(find.text('当日概览'), findsOneWidget);
      expect(find.text('次日预览'), findsOneWidget);
      expect(find.text('本周'), findsNothing);
      // Plural text still runs through the Task 19 l10n migration.
      expect(find.text('2 plans'), findsOneWidget);
    });

    testWidgets('renders plan, reminder and the day overview on wide windows', (
      tester,
    ) async {
      _useWideWindow(tester);
      final today = dateOnly(DateTime.now());
      final plan = await seed(
        title: 'PlanOne',
        day: today,
        kind: 'plan',
        startMinute: 540,
        endMinute: 600,
      );
      final reminder = await seed(
        title: 'RemindOne',
        day: today,
        startMinute: 750,
      );

      await pumpDay(tester, today);

      expect(find.byKey(ValueKey('plan-${plan.id}')), findsOneWidget);
      expect(find.byKey(ValueKey('reminder-${reminder.id}')), findsOneWidget);
      expect(find.text('当日概览'), findsOneWidget);
      expect(find.text('次日预览'), findsOneWidget);
      // Chinese count output is preserved verbatim.
      expect(find.text('1 个计划'), findsOneWidget);
      expect(find.text('1 个提醒'), findsOneWidget);
      expect(find.text('明日'), findsNothing);

      // Dispose the today-only now line before the test ends so its periodic
      // timer is cancelled.
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('day overview stays hidden below 1100px', (tester) async {
      await seed(
        title: 'PlanOne',
        day: DateTime(2026, 11, 11),
        kind: 'plan',
        startMinute: 540,
        endMinute: 600,
      );

      await pumpDay(tester, DateTime(2026, 11, 11));

      expect(find.text('当日概览'), findsNothing);
      expect(find.text('次日预览'), findsNothing);
    });

    testWidgets('next-day preview caps at three rows', (tester) async {
      _useWideWindow(tester);
      final day = DateTime(2026, 11, 11);
      final tomorrow = DateTime(2026, 11, 12);
      for (var i = 1; i <= 4; i++) {
        await seed(
          title: 'Tomorrow$i',
          day: tomorrow,
          startMinute: 8 * 60 + i * 10,
        );
      }

      await pumpDay(tester, day);

      expect(find.text('次日预览'), findsOneWidget);
      expect(find.text('Tomorrow1'), findsOneWidget);
      expect(find.text('Tomorrow3'), findsOneWidget);
      expect(find.text('Tomorrow4'), findsNothing);
    });

    testWidgets('overview rows are read-only compact rows', (tester) async {
      _useWideWindow(tester);
      final day = DateTime(2026, 11, 11);
      final tomorrow = DateTime(2026, 11, 12);
      final plan = await seed(
        title: 'PreviewPlan',
        day: tomorrow,
        kind: 'plan',
        startMinute: 540,
        endMinute: 600,
      );
      final reminder = await seed(
        title: 'PreviewReminder',
        day: tomorrow,
        startMinute: 750,
      );

      await pumpDay(tester, day);

      final rail = find.byKey(const ValueKey('day-overview'));
      expect(tester.getSize(rail).width, 216);
      // No check circle in the read-only preview.
      expect(
        find.descendant(of: rail, matching: find.byType(AppCheckCircle)),
        findsNothing,
      );
      // Plans use the horizontal 9×2.5 compact bar; reminders use a 6px dot.
      expect(
        tester.getSize(find.byKey(ValueKey('overview-plan-marker-${plan.id}'))),
        const Size(9, 2.5),
      );
      expect(
        tester.getSize(
          find.byKey(ValueKey('overview-reminder-marker-${reminder.id}')),
        ),
        const Size(6, 6),
      );
      // Rows are 34 high.
      expect(
        tester.getSize(find.byKey(ValueKey('overview-row-${plan.id}'))).height,
        34,
      );
      // Count numerals are 22/700.
      final count = tester.widget<Text>(
        find.byKey(const ValueKey('overview-plans-count')),
      );
      expect(count.style?.fontSize, 22);
      expect(count.style?.fontWeight, FontWeight.w700);
    });
  });
}

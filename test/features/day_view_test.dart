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
import 'package:tempolet/features/calendar/day_view.dart';
import 'package:tempolet/features/calendar/time_grid.dart';
import 'package:tempolet/notifications/fake_notification_service.dart';
import 'package:tempolet/notifications/notification_scheduler.dart';

Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 30)),
  );
  await tester.pumpAndSettle();
}

Widget _app(ProviderContainer container, Widget home) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    ),
  );
}

/// Gives the test a desktop-width window so the 216px stats rail (shown from
/// 1100px) is part of the layout.
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

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    db = AppDatabase(NativeDatabase.memory());
    repo = EventRepository(db);
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        databaseProvider.overrideWithValue(db),
        notificationServiceProvider.overrideWithValue(FakeNotificationService()),
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

  Future<void> pumpDay(WidgetTester tester, DateTime day) async {
    container.read(selectedDayProvider.notifier).select(day);
    await tester.pumpWidget(_app(container, const Scaffold(body: DayView())));
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

    testWidgets('tapping an empty slot opens a reminder at the snapped minute',
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
    });

    testWidgets('dragging an empty slot opens a plan over the dragged range',
        (tester) async {
      await pumpDay(tester, DateTime(2026, 11, 11));

      final rect = tester.getRect(find.byKey(const ValueKey('day-scroll')));
      final x = rect.center.dx;
      final startY = rect.top + (minuteToY(9 * 60) - kDefaultScrollOffset);

      await tester.dragFrom(Offset(x, startY), const Offset(0, 34));
      await _settle(tester);

      expect(find.byKey(const ValueKey('editor-save')), findsOneWidget);
      // Only plans expose an end time in the editor.
      expect(find.byKey(const ValueKey('end-stepper')), findsOneWidget);
      expect(find.text('09:00'), findsWidgets);
      expect(find.text('10:00'), findsWidgets);
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

    testWidgets('completing a reminder removes it from the day', (tester) async {
      final reminder = await seed(
        title: 'Call back',
        day: DateTime(2026, 11, 11),
        startMinute: 750,
      );
      await pumpDay(tester, DateTime(2026, 11, 11));

      expect(
        find.byKey(ValueKey('reminder-${reminder.id}')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(ValueKey('complete-${reminder.id}')));
      await tester.pump(const Duration(milliseconds: 150));
      await _settle(tester);

      expect(
        find.byKey(ValueKey('reminder-${reminder.id}')),
        findsNothing,
      );
      final rows = await tester.runAsync(() => db.select(db.events).get());
      expect(rows!.single.isCompleted, isTrue);
    });

    testWidgets('yesterday\'s events are marked overdue with the danger token',
        (tester) async {
      final yesterday = dateOnly(DateTime.now()).subtract(
        const Duration(days: 1),
      );
      await seed(
        title: 'Old reminder',
        day: yesterday,
        startMinute: 750,
      );
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
    });

    testWidgets('shows the now line only on today', (tester) async {
      await pumpDay(tester, dateOnly(DateTime.now()));
      expect(find.byKey(const ValueKey('day-now-line')), findsOneWidget);

      // Switching to another day disposes the today-only now line.
      container.read(selectedDayProvider.notifier).select(DateTime(2026, 11, 11));
      await _settle(tester);
      expect(find.byKey(const ValueKey('day-now-line')), findsNothing);
    });

    testWidgets('follows the day selected by the shared header arrows',
        (tester) async {
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

    testWidgets('renders plan, reminder and the stats rail on wide windows',
        (tester) async {
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
      expect(find.text('1 个计划'), findsOneWidget);
      expect(find.text('1 个提醒'), findsOneWidget);
      expect(find.text('明日'), findsOneWidget);

      // Dispose the today-only now line before the test ends so its periodic
      // timer is cancelled.
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('stats rail stays hidden below 1100px', (tester) async {
      await seed(
        title: 'PlanOne',
        day: DateTime(2026, 11, 11),
        kind: 'plan',
        startMinute: 540,
        endMinute: 600,
      );

      await pumpDay(tester, DateTime(2026, 11, 11));

      expect(find.text('1 个计划'), findsNothing);
      expect(find.text('明日'), findsNothing);
    });

    testWidgets('tomorrow preview caps at six rows', (tester) async {
      _useWideWindow(tester);
      final day = DateTime(2026, 11, 11);
      final tomorrow = DateTime(2026, 11, 12);
      for (var i = 1; i <= 7; i++) {
        await seed(
          title: 'Tomorrow$i',
          day: tomorrow,
          startMinute: 8 * 60 + i * 10,
        );
      }

      await pumpDay(tester, day);

      expect(find.text('明日'), findsOneWidget);
      expect(find.text('Tomorrow6'), findsOneWidget);
      expect(find.text('Tomorrow7'), findsNothing);
    });
  });
}

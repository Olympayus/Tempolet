import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tempolet/core/l10n/generated/app_localizations.dart';
import 'package:tempolet/core/prefs.dart';
import 'package:tempolet/core/theme/app_tokens.dart';
import 'package:tempolet/core/ui/app_check_circle.dart';
import 'package:tempolet/data/database/database.dart';
import 'package:tempolet/data/repositories/event_repository.dart';
import 'package:tempolet/features/calendar/calendar_state.dart';
import 'package:tempolet/features/calendar/mini_month_calendar.dart';
import 'package:tempolet/features/reminders/reminders_page.dart';
import 'package:tempolet/notifications/fake_notification_service.dart';
import 'package:tempolet/notifications/notification_scheduler.dart';

final _today = DateTime(2026, 11, 16);

Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 30)),
  );
  await tester.pumpAndSettle();
}

Widget _pageApp(ProviderContainer container) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const RemindersPage(),
    ),
  );
}

void main() {
  late AppDatabase db;
  late ProviderContainer container;
  late EventRepository repo;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    db = AppDatabase(NativeDatabase.memory());
    repo = EventRepository(db);
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        databaseProvider.overrideWithValue(db),
        notificationServiceProvider.overrideWithValue(
          FakeNotificationService(),
        ),
        todayProvider.overrideWithValue(_today),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  /// Rebuilds the container around a different wall-clock day; the database
  /// and repository stay in place.
  void setToday(DateTime day) {
    container.dispose();
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        databaseProvider.overrideWithValue(db),
        notificationServiceProvider.overrideWithValue(
          FakeNotificationService(),
        ),
        todayProvider.overrideWithValue(day),
      ],
    );
  }

  Future<Event> seed(
    String title, {
    String kind = 'reminder',
    required DateTime date,
    int? startMinute = 540,
    int? endMinute,
  }) {
    return repo.create(
      title: title,
      kind: kind,
      date: date,
      startMinute: startMinute,
      endMinute: endMinute,
      reminderOffsetMinutes: 0,
    );
  }

  Future<void> openDateMode(WidgetTester tester) async {
    await tester.pumpWidget(_pageApp(container));
    await _settle(tester);
    await tester.tap(find.text('日期'));
    await _settle(tester);
  }

  testWidgets('date mode lists dates from earliest overdue through today+6', (
    tester,
  ) async {
    await seed('Old task', date: DateTime(2026, 11, 14));
    await seed('Today task', date: _today, startMinute: 600);
    await seed('Last day', date: DateTime(2026, 11, 22), startMinute: 700);

    await openDateMode(tester);

    expect(find.byKey(const ValueKey('reminders-date-mode')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('reminders-date-mode-placeholder')),
      findsNothing,
    );
    expect(find.textContaining('11月14日'), findsOneWidget);
    expect(find.textContaining('11月22日'), findsOneWidget);
    expect(find.byKey(const ValueKey('date-group-2026-11-14')), findsOneWidget);
    expect(find.byKey(const ValueKey('date-group-2026-11-22')), findsOneWidget);
    expect(find.byKey(const ValueKey('date-group-2026-11-13')), findsNothing);
    expect(find.byKey(const ValueKey('date-group-2026-11-23')), findsNothing);
  });

  testWidgets('an empty day renders one grey row that opens the editor', (
    tester,
  ) async {
    await seed('Today task', date: _today, startMinute: 600);

    await openDateMode(tester);

    final empty = find.byKey(const ValueKey('empty-day-2026-11-18'));
    expect(empty, findsOneWidget);
    expect(find.byKey(const ValueKey('date-group-2026-11-18')), findsNothing);
    expect(
      find.descendant(of: empty, matching: find.text('无安排')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: empty, matching: find.textContaining('11月18日')),
      findsOneWidget,
    );

    await tester.tap(empty);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('editor-title')), findsOneWidget);
  });

  testWidgets('the current month remainder expands its remaining days', (
    tester,
  ) async {
    await seed('Today task', date: _today, startMinute: 600);
    await seed('Late month', date: DateTime(2026, 11, 25), startMinute: 600);

    await openDateMode(tester);

    expect(find.text('本月剩余'), findsOneWidget);
    expect(find.textContaining('11月23日'), findsOneWidget);

    final summary = find.byKey(const ValueKey('month-summary-remaining'));
    await tester.ensureVisible(summary);
    await tester.pumpAndSettle();
    await tester.tap(summary);
    await _settle(tester);

    expect(find.byKey(const ValueKey('date-group-2026-11-25')), findsOneWidget);
    expect(find.text('Late month'), findsOneWidget);
  });

  testWidgets('future months list six rows with years and dim empty months', (
    tester,
  ) async {
    await seed('Today task', date: _today, startMinute: 600);
    await seed('December task', date: DateTime(2026, 12, 5), startMinute: 600);

    await openDateMode(tester);

    expect(find.text('未来 6 个月'), findsOneWidget);
    expect(find.textContaining('2026年12月'), findsOneWidget);
    expect(find.textContaining('2027年1月'), findsOneWidget);
    expect(find.textContaining('2027年5月'), findsOneWidget);
    expect(find.byKey(const ValueKey('month-summary-2027-06')), findsNothing);

    final emptyLabel = tester.widget<Text>(
      find.byKey(const ValueKey('month-summary-2027-01-label')),
    );
    expect(emptyLabel.style?.color, AppPalette.light.subWeak);
    final filledLabel = tester.widget<Text>(
      find.byKey(const ValueKey('month-summary-2026-12-label')),
    );
    expect(filledLabel.style?.color, AppPalette.light.ink);
  });

  testWidgets('a non-empty month expands inline and an empty month does not', (
    tester,
  ) async {
    await seed('Today task', date: _today, startMinute: 600);
    await seed('December task', date: DateTime(2026, 12, 5), startMinute: 600);

    await openDateMode(tester);

    final december = find.byKey(const ValueKey('month-summary-2026-12'));
    await tester.ensureVisible(december);
    await tester.pumpAndSettle();
    await tester.tap(december);
    await _settle(tester);

    expect(find.byKey(const ValueKey('date-group-2026-12-05')), findsOneWidget);
    expect(find.text('December task'), findsOneWidget);
    expect(find.byKey(const ValueKey('empty-day-2026-12-01')), findsOneWidget);

    final january = find.byKey(const ValueKey('month-summary-2027-01'));
    await tester.ensureVisible(january);
    await tester.pumpAndSettle();
    await tester.tap(january);
    await _settle(tester);

    expect(find.byKey(const ValueKey('empty-day-2027-01-01')), findsNothing);
  });

  testWidgets('an overdue day marks its group and suffixes the row time', (
    tester,
  ) async {
    await seed('Late task', date: DateTime(2026, 11, 15), startMinute: 540);

    await openDateMode(tester);

    expect(
      find.byKey(const ValueKey('date-group-overdue-2026-11-15')),
      findsOneWidget,
    );
    final time = tester.widget<Text>(find.text('09:00 逾期'));
    expect(time.style?.color, AppPalette.light.danger);
  });

  testWidgets('mini calendar selection updates the timeline title', (
    tester,
  ) async {
    await seed('Today task', date: _today, startMinute: 600);

    await openDateMode(tester);

    await tester.tap(find.byKey(const ValueKey('mini-day-2026-11-19')));
    await _settle(tester);

    final title = tester.widget<Text>(
      find.byKey(const ValueKey('reminders-timeline-title')),
    );
    expect(title.data, contains('11月19日'));
    expect(container.read(selectedDayProvider), DateTime(2026, 11, 19));
  });

  testWidgets('picking a date outside the band expands its month', (
    tester,
  ) async {
    await seed('Today task', date: _today, startMinute: 600);
    await seed('December task', date: DateTime(2026, 12, 5), startMinute: 600);

    await openDateMode(tester);

    await tester.tap(find.byKey(const ValueKey('mini-month-next')));
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('mini-day-2026-12-05')));
    await _settle(tester);

    expect(find.byKey(const ValueKey('date-group-2026-12-05')), findsOneWidget);
  });

  testWidgets('a mini-calendar pick inside the month remainder expands it', (
    tester,
  ) async {
    await seed('Late month', date: DateTime(2026, 11, 25), startMinute: 600);

    await openDateMode(tester);

    final list = tester.widget<SingleChildScrollView>(
      find.byKey(const ValueKey('reminders-date-mode')),
    );
    final controller = list.controller!;
    expect(controller.offset, 0);

    await tester.tap(find.byKey(const ValueKey('mini-day-2026-11-25')));
    await _settle(tester);

    expect(find.byKey(const ValueKey('date-group-2026-11-25')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('reminders-date-mode')),
        matching: find.text('Late month'),
      ),
      findsOneWidget,
    );
    // The first expansion builds the day anchor in the same pass, so the
    // post-frame ensureVisible must have scrolled the date list.
    expect(controller.offset, greaterThan(0));
  });

  testWidgets(
    'a future month straddling the band keeps its whole-month count',
    (tester) async {
      setToday(DateTime(2026, 11, 28));
      await seed('Band dec', date: DateTime(2026, 12, 2), startMinute: 600);

      await openDateMode(tester);

      // 12-02 sits inside the band (11-28 through 12-04).
      expect(
        find.byKey(const ValueKey('date-group-2026-12-02')),
        findsOneWidget,
      );

      final row = find.byKey(const ValueKey('month-summary-2026-12'));
      expect(row, findsOneWidget);
      final label = tester.widget<Text>(
        find.byKey(const ValueKey('month-summary-2026-12-label')),
      );
      expect(label.style?.color, AppPalette.light.ink);
      expect(
        find.descendant(of: row, matching: find.text('无安排')),
        findsNothing,
      );
      expect(
        find.descendant(of: row, matching: find.text('1 项')),
        findsOneWidget,
      );

      await tester.ensureVisible(row);
      await tester.pumpAndSettle();
      await tester.tap(row);
      await _settle(tester);

      // The month expands; the band-covered 12-02 stays in the band and the
      // expansion starts on 12-05.
      expect(
        find.byKey(const ValueKey('empty-day-2026-12-05')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'a mini-calendar pick after the band expands a partially covered future month',
    (tester) async {
      setToday(DateTime(2026, 11, 28));
      await seed('Band dec', date: DateTime(2026, 12, 2), startMinute: 600);

      await openDateMode(tester);

      await tester.tap(find.byKey(const ValueKey('mini-month-next')));
      await _settle(tester);
      await tester.tap(find.byKey(const ValueKey('mini-day-2026-12-05')));
      await _settle(tester);

      expect(
        find.byKey(const ValueKey('empty-day-2026-12-05')),
        findsOneWidget,
      );
    },
  );

  testWidgets('completing the earliest overdue event shrinks the band start', (
    tester,
  ) async {
    final earliest = await seed(
      'Earliest',
      date: DateTime(2026, 11, 13),
      startMinute: 600,
    );
    await seed('Later', date: DateTime(2026, 11, 15), startMinute: 600);

    await openDateMode(tester);
    expect(find.byKey(const ValueKey('date-group-2026-11-13')), findsOneWidget);
    // 11-14 is inside the original band as an empty day.
    expect(find.byKey(const ValueKey('empty-day-2026-11-14')), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byKey(ValueKey('date-row-${earliest.id}')),
        matching: find.byType(AppCheckCircle),
      ),
    );
    await _settle(tester);

    expect(find.byKey(const ValueKey('date-group-2026-11-13')), findsNothing);
    // The band now starts on 11-15, so neither former band day is rendered at
    // all (an old band start of 11-13 would render both as empty-day rows).
    expect(find.byKey(const ValueKey('empty-day-2026-11-13')), findsNothing);
    expect(find.byKey(const ValueKey('empty-day-2026-11-14')), findsNothing);
    expect(find.byKey(const ValueKey('date-group-2026-11-15')), findsOneWidget);
  });

  testWidgets('completing the only event in an expanded month collapses it', (
    tester,
  ) async {
    final event = await seed(
      'December task',
      date: DateTime(2026, 12, 5),
      startMinute: 600,
    );

    await openDateMode(tester);
    final row = find.byKey(const ValueKey('month-summary-2026-12'));
    await tester.ensureVisible(row);
    await tester.pumpAndSettle();
    await tester.tap(row);
    await _settle(tester);
    expect(find.byKey(ValueKey('date-row-${event.id}')), findsOneWidget);

    final rowEvent = find.byKey(ValueKey('date-row-${event.id}'));
    await tester.ensureVisible(rowEvent);
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: rowEvent, matching: find.byType(AppCheckCircle)),
    );
    await _settle(tester);

    final label = tester.widget<Text>(
      find.byKey(const ValueKey('month-summary-2026-12-label')),
    );
    expect(label.style?.color, AppPalette.light.subWeak);
    expect(find.byKey(const ValueKey('date-group-2026-12-05')), findsNothing);
    expect(find.byKey(const ValueKey('empty-day-2026-12-05')), findsNothing);
  });

  testWidgets('the left column hosts the shared mini calendar and timeline', (
    tester,
  ) async {
    final timed = await seed('Timeline task', date: _today, startMinute: 540);

    await tester.pumpWidget(_pageApp(container));
    await _settle(tester);

    expect(
      tester.getSize(find.byKey(const ValueKey('reminders-left-column'))).width,
      204,
    );
    final calendar = find.byKey(const ValueKey('reminders-mini-calendar'));
    expect(calendar, findsOneWidget);
    expect(tester.getSize(calendar).width, 180);
    final timeline = find.byKey(const ValueKey('reminders-timeline'));
    expect(timeline, findsOneWidget);
    expect(find.byType(MiniMonthCalendar), findsOneWidget);

    final title = tester.widget<Text>(
      find.byKey(const ValueKey('reminders-timeline-title')),
    );
    expect(title.data, contains('11月16日'));

    // The 11px HH:MM tick fits inside the 40px gutter (no right clipping) and
    // items start at x=44.
    final timelineLeft = tester.getTopLeft(timeline).dx;
    final tick = tester.getRect(find.text('07:00'));
    expect(tick.left - timelineLeft, 8);
    expect(tick.right - timelineLeft, lessThanOrEqualTo(40));

    final event = find.byKey(ValueKey('reminders-timeline-event-${timed.id}'));
    expect(event, findsOneWidget);
    expect(tester.getTopLeft(event).dx - timelineLeft, 44);
  });
}

import 'package:drift/native.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
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
import 'package:tempolet/features/events/fields/segmented_time_field.dart';
import 'package:tempolet/notifications/fake_notification_service.dart';
import 'package:tempolet/notifications/notification_scheduler.dart';

Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 30)),
  );
  await tester.pumpAndSettle();
}

/// Touch plan moves/resizes are armed by a long press (`v0.1.5 design` §8.4).
Future<void> _longPressDragAt(
  WidgetTester tester,
  Offset start,
  Offset offset,
) async {
  final gesture = await tester.startGesture(start);
  await tester.pump(const Duration(milliseconds: 600));
  await gesture.moveBy(offset);
  await tester.pump();
  await gesture.up();
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
        // Pin "today" so the selected/wash assertions do not depend on the
        // machine clock.
        todayProvider.overrideWithValue(DateTime(2026, 11, 11)),
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

  Future<void> pumpWeek(
    WidgetTester tester,
    DateTime day, {
    double width = 1000,
    double? sidebarWidth,
  }) async {
    // The app's minimum desktop width is 960px; the engine default 800px
    // leaves 109px columns, well below the 150px two-line card breakpoint.
    tester.view.physicalSize = Size(width, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    container.read(selectedDayProvider.notifier).select(day);
    final view = sidebarWidth == null
        ? const WeekView()
        : Row(
            children: [
              SizedBox(width: sidebarWidth),
              const Expanded(child: WeekView()),
            ],
          );
    await tester.pumpWidget(_app(container, view));
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

    testWidgets('selected day shows an accent tint pill without a border', (
      tester,
    ) async {
      await pumpWeek(tester, DateTime(2026, 11, 11));

      await tester.tap(find.byKey(const ValueKey('week-day-2026-11-12')));
      await tester.pump(const Duration(milliseconds: 350));

      final pill = tester.widget<Container>(
        find.byKey(const ValueKey('week-day-date-2026-11-12')),
      );
      final decoration = pill.decoration! as BoxDecoration;
      expect(decoration.border, isNull);
      final theme = Theme.of(tester.element(find.byType(WeekView)));
      expect(
        decoration.color,
        theme.colorScheme.primary.withValues(alpha: .11),
      );
    });

    testWidgets(
      'selected today still washes its column and today has no extra wash',
      (tester) async {
        // Today is pinned to 2026-11-11, so the default selected day is both
        // today and selected.
        await pumpWeek(tester, DateTime(2026, 11, 11));

        final todayColumn = find.byKey(
          const ValueKey('week-selected-column-2026-11-11'),
        );
        expect(todayColumn, findsOneWidget);
        expect(
          tester.widget<ColoredBox>(todayColumn).color,
          AppPalette.light.surfaceSelected,
        );
        // No separate today-only column wash: exactly one selected overlay.
        expect(find.byKey(const ValueKey('week-today-column')), findsNothing);
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is ColoredBox &&
                widget.color == AppPalette.light.surfaceSelected,
          ),
          findsOneWidget,
        );

        await tester.tap(find.byKey(const ValueKey('week-day-2026-11-12')));
        await tester.pump();

        expect(
          find.byKey(const ValueKey('week-selected-column-2026-11-12')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('week-selected-column-2026-11-11')),
          findsNothing,
        );
      },
    );

    testWidgets(
      'header tap selects immediately and second tap within 300ms opens day view',
      (tester) async {
        container
            .read(calendarViewModeProvider.notifier)
            .set(CalendarViewMode.week);
        await pumpWeek(tester, DateTime(2026, 11, 11));

        // tap another day once -> selected immediately (one pump, no 300ms wait)
        await tester.tap(find.byKey(const ValueKey('week-day-2026-11-12')));
        await tester.pump();
        expect(container.read(selectedDayProvider), DateTime(2026, 11, 12));
        // tap again within threshold -> day view
        await tester.tap(find.byKey(const ValueKey('week-day-2026-11-12')));
        await tester.pump();
        expect(container.read(calendarViewModeProvider), CalendarViewMode.day);
      },
    );

    testWidgets('week header and axis gutter use the side surface', (
      tester,
    ) async {
      await pumpWeek(tester, DateTime(2026, 11, 11));

      final header = tester.widget<Container>(
        find.byKey(const ValueKey('week-header-band')),
      );
      expect((header.decoration as BoxDecoration).color, AppPalette.light.side);

      final gutter = tester.widget<Container>(
        find.byKey(const ValueKey('hour-grid-gutter')),
      );
      expect((gutter.decoration as BoxDecoration).color, AppPalette.light.side);
    });

    testWidgets('renders seven keyed headers for the week of 2026-11-11', (
      tester,
    ) async {
      await pumpWeek(tester, DateTime(2026, 11, 11));

      for (final day in ['09', '10', '11', '12', '13', '14', '15']) {
        expect(find.byKey(ValueKey('week-day-2026-11-$day')), findsOneWidget);
      }
      expect(
        tester
            .getSize(find.byKey(const ValueKey('week-day-2026-11-09')))
            .height,
        52,
      );
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

    testWidgets('narrow columns use two-line reminder cards', (tester) async {
      final reminder = await seed(
        title: 'Narrow item',
        day: DateTime(2026, 11, 11),
      );

      // A 1000px window leaves ~136px columns, below the 150px two-line
      // breakpoint; the <900 content-width fallback does not apply.
      await pumpWeek(tester, DateTime(2026, 11, 11), width: 1000);

      expect(find.byKey(const ValueKey('week-card-two-line')), findsOneWidget);
      // The compact card drops the completion circle.
      expect(find.byKey(ValueKey('complete-${reminder.id}')), findsNothing);
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
        const Offset(0, 68),
        kind: PointerDeviceKind.mouse,
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
        kind: PointerDeviceKind.mouse,
      );
      await gesture.moveBy(const Offset(0, 68));
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

    testWidgets('a touch drag on a column scrolls the week grid', (
      tester,
    ) async {
      await pumpWeek(tester, DateTime(2026, 11, 11));

      final scroll = find.byKey(const ValueKey('week-scroll'));
      final before = tester
          .widget<SingleChildScrollView>(scroll)
          .controller!
          .offset;

      await tester.drag(
        find.byKey(const ValueKey('week-column-2026-11-11')),
        const Offset(0, -120),
      );
      await tester.pumpAndSettle();

      expect(
        tester.widget<SingleChildScrollView>(scroll).controller!.offset,
        greaterThan(before),
      );
      expect(find.byKey(const ValueKey('editor-save')), findsNothing);
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

      await _longPressDragAt(
        tester,
        tester.getCenter(find.byKey(ValueKey('week-plan-${plan.id}'))),
        const Offset(0, 68),
      );
      await _settle(tester);

      final rows = await tester.runAsync(() => repo.getById(plan.id));
      expect(rows!.startMinute, 600);
      expect(rows.endMinute, 660);
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
        await pumpWeek(tester, day);

        await _longPressDragAt(
          tester,
          tester.getCenter(find.byKey(ValueKey('week-plan-${plan.id}'))),
          const Offset(0, 68),
        );
        await _settle(tester);

        expect(notifications.scheduled, hasLength(1));
        expect(notifications.scheduled.single.at, DateTime(2030, 1, 2, 9, 50));
      },
    );

    testWidgets('completing a week reminder removes it from the grid', (
      tester,
    ) async {
      final reminder = await seed(
        title: 'Week reminder',
        day: DateTime(2026, 11, 11),
        startMinute: 750,
      );
      // 1300px leaves ~179px columns, wide enough for the single-line card
      // with its completion circle.
      await pumpWeek(tester, DateTime(2026, 11, 11), width: 1300);

      expect(find.byKey(const ValueKey('week-card-two-line')), findsNothing);
      expect(find.byKey(ValueKey('reminder-${reminder.id}')), findsOneWidget);
      expect(find.byKey(ValueKey('complete-${reminder.id}')), findsOneWidget);

      await tester.tap(find.byKey(ValueKey('complete-${reminder.id}')));
      await tester.pump(const Duration(milliseconds: 150));
      await _settle(tester);

      expect(find.byKey(ValueKey('reminder-${reminder.id}')), findsNothing);
      final rows = await tester.runAsync(() => repo.getById(reminder.id));
      expect(rows!.isCompleted, isTrue);
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
      await _longPressDragAt(
        tester,
        Offset(rect.center.dx, rect.bottom - 2),
        const Offset(0, 68),
      );
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
      // Wide enough that the seven-column grid is used (>=900 content width).
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
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

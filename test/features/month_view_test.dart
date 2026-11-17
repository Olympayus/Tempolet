import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/gestures.dart';
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
import 'package:tempolet/features/calendar/calendar_page.dart';
import 'package:tempolet/features/calendar/calendar_state.dart';
import 'package:tempolet/features/calendar/month_preview_popover.dart';
import 'package:tempolet/features/calendar/month_view.dart';
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
      locale: const Locale('en'),
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

  Future<Event> seed(
    String title, {
    int? startMinute = 540,
    String kind = 'reminder',
  }) {
    return repo.create(
      title: title,
      kind: kind,
      date: DateTime(2026, 11, 11),
      startMinute: startMinute,
    );
  }

  testWidgets('grid has no adjacent-month cells and shows an ellipsis', (
    tester,
  ) async {
    await seed('E1', startMinute: 540);
    await seed('E2', startMinute: 600);
    await seed('E3', startMinute: 660);
    await tester.pumpWidget(_app(container));
    await _settle(tester);

    expect(find.textContaining('E3'), findsNothing);
    expect(find.byKey(const ValueKey('month-more-2026-11-11')), findsOneWidget);
    expect(find.textContaining('Oct'), findsNothing);
  });

  testWidgets('holiday info shares the day row and keeps both event rows', (
    tester,
  ) async {
    // The 8/10 + 32 density needs a taller window to fit two event rows; keep
    // the width under the sidebar breakpoint so the sidebar does not duplicate
    // the same event titles in this assertion. The 960×600 minimum is covered
    // by the height-aware test below.
    tester.view.physicalSize = const Size(1100, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await db
        .into(db.holidays)
        .insert(
          HolidaysCompanion.insert(
            date: DateTime(2026, 11, 11),
            name: 'Test Holiday',
            isWorkday: const Value(false),
            source: const Value('seed'),
            updatedAt: Value(DateTime.now()),
          ),
        );
    await seed('E1', startMinute: 540);
    await seed('E2', startMinute: 600);
    await seed('E3', startMinute: 660);
    await tester.pumpWidget(_app(container));
    await _settle(tester);

    expect(find.text('Test Holiday'), findsOneWidget);
    expect(find.text('Off'), findsOneWidget);
    expect(find.text('E1'), findsOneWidget);
    expect(find.text('E2'), findsOneWidget);
    expect(find.text('E3'), findsNothing);
    expect(find.byKey(const ValueKey('month-more-2026-11-11')), findsOneWidget);
  });

  testWidgets('960x600 keeps the overflow row and one event inside the cell', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(960, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (var i = 0; i < 5; i++) {
      await seed('H$i', startMinute: 480 + i * 15);
    }
    await tester.pumpWidget(_app(container));
    await _settle(tester);

    expect(tester.takeException(), isNull);
    final cell = find.byKey(const ValueKey('month-day-2026-11-11'));
    final more = find.byKey(const ValueKey('month-more-2026-11-11'));
    expect(more, findsOneWidget);

    final cellRect = tester.getRect(cell);
    final moreRect = tester.getRect(more);
    expect(moreRect.top, greaterThanOrEqualTo(cellRect.top));
    expect(moreRect.left, greaterThanOrEqualTo(cellRect.left));
    expect(moreRect.right, lessThanOrEqualTo(cellRect.right));
    expect(moreRect.bottom, lessThanOrEqualTo(cellRect.bottom));

    // Only the rows that fit render; the first one must be fully inside the
    // cell rather than clipped in half.
    final first = find.text('H0');
    expect(first, findsOneWidget);
    expect(find.text('H1'), findsNothing);
    final textRect = tester.getRect(first);
    expect(textRect.top, greaterThanOrEqualTo(cellRect.top));
    expect(textRect.bottom, lessThanOrEqualTo(cellRect.bottom));
    expect(textRect.bottom, lessThanOrEqualTo(moreRect.top));
  });

  testWidgets('weekday band uses the side surface', (tester) async {
    await tester.pumpWidget(_app(container));
    await _settle(tester);

    final band = tester.widget<ColoredBox>(
      find.byKey(const ValueKey('month-weekday-band')),
    );
    expect(band.color, AppPalette.light.side);
  });

  testWidgets('single click selects the day and does not open the sidebar', (
    tester,
  ) async {
    await tester.pumpWidget(_app(container));
    await _settle(tester);

    await tester.tap(find.byKey(const ValueKey('month-day-2026-11-19')));
    await tester.pump();

    expect(container.read(selectedDayProvider), DateTime(2026, 11, 19));
    expect(container.read(sidebarPreferenceProvider), isNot(true));
    expect(find.byKey(const ValueKey('month-preview')), findsNothing);
    expect(find.byType(MonthPreviewPopover), findsNothing);
  });

  testWidgets('hovering 350ms opens the preview, leaving 200ms closes it', (
    tester,
  ) async {
    await tester.pumpWidget(_app(container));
    await _settle(tester);

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(gesture.removePointer);
    await gesture.moveTo(
      tester.getCenter(find.byKey(const ValueKey('month-day-2026-11-19'))),
    );
    await tester.pump(const Duration(milliseconds: 340));
    expect(find.byKey(const ValueKey('month-preview')), findsNothing);
    await tester.pump(const Duration(milliseconds: 20));
    expect(find.byKey(const ValueKey('month-preview')), findsOneWidget);
    await gesture.moveTo(const Offset(2, 2));
    await tester.pump(const Duration(milliseconds: 210));
    expect(find.byKey(const ValueKey('month-preview')), findsNothing);
  });

  testWidgets('sweeping across cells never opens a preview until rest', (
    tester,
  ) async {
    await tester.pumpWidget(_app(container));
    await _settle(tester);

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(gesture.removePointer);
    for (final day in ['2026-11-18', '2026-11-19', '2026-11-20']) {
      await gesture.moveTo(
        tester.getCenter(find.byKey(ValueKey('month-day-$day'))),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(const ValueKey('month-preview')), findsNothing);
    }
    await tester.pump(const Duration(milliseconds: 360));
    expect(find.byKey(const ValueKey('month-preview')), findsOneWidget);
  });

  testWidgets('a preview closed before its first frame leaves no orphan', (
    tester,
  ) async {
    await tester.pumpWidget(_app(container));
    await _settle(tester);

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(gesture.removePointer);
    await gesture.moveTo(
      tester.getCenter(find.byKey(const ValueKey('month-day-2026-11-19'))),
    );
    // Fire the hover timer without pumping a frame: the overlay entry exists
    // while its builder (and thus its close handle) has not run yet.
    await tester.binding.delayed(kMonthPreviewHoverDelay);
    expect(find.byKey(const ValueKey('month-preview')), findsNothing);

    // Enter another cell during that sub-frame window; the stale entry must
    // be dismissed instead of mounting when the next frame builds it.
    await gesture.moveTo(
      tester.getCenter(find.byKey(const ValueKey('month-day-2026-11-20'))),
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('month-preview')), findsNothing);

    await tester.pump(const Duration(milliseconds: 360));
    expect(find.byKey(const ValueKey('month-preview')), findsOneWidget);
  });

  testWidgets('header navigation moves the month grid', (tester) async {
    await tester.pumpWidget(_app(container));
    await _settle(tester);
    expect(find.byKey(const ValueKey('month-day-2026-11-01')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('calendar-next')));
    await _settle(tester);

    expect(find.byKey(const ValueKey('month-day-2026-12-01')), findsOneWidget);
    expect(find.byKey(const ValueKey('month-day-2026-11-01')), findsNothing);
  });

  testWidgets('checking a preview row completes the event', (tester) async {
    final event = await seed('Buy milk', startMinute: 540);
    await tester.pumpWidget(_app(container));
    await _settle(tester);

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(gesture.removePointer);
    await gesture.moveTo(
      tester.getCenter(find.byKey(const ValueKey('month-day-2026-11-11'))),
    );
    await tester.pump(const Duration(milliseconds: 360));
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.byKey(ValueKey('preview-row-${event.id}')),
        matching: find.byType(AppCheckCircle),
      ),
    );
    await tester.pump(const Duration(milliseconds: 150));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );

    expect(find.byKey(const ValueKey('editor-save')), findsNothing);
    final completed = await tester.runAsync(() => repo.getById(event.id));
    expect(completed!.isCompleted, isTrue);
  });
}

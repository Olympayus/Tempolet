import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tempolet/core/l10n/generated/app_localizations.dart';
import 'package:tempolet/core/prefs.dart';
import 'package:tempolet/core/ui/app_check_circle.dart';
import 'package:tempolet/data/database/database.dart';
import 'package:tempolet/data/repositories/event_repository.dart';
import 'package:tempolet/features/calendar/calendar_state.dart';
import 'package:tempolet/features/calendar/month_preview_popover.dart';
import 'package:tempolet/features/calendar/month_view.dart';
import 'package:tempolet/features/events/event_list_row.dart';
import 'package:tempolet/notifications/fake_notification_service.dart';
import 'package:tempolet/notifications/notification_scheduler.dart';

Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 30)),
  );
  await tester.pumpAndSettle();
}

String _dayKey(DateTime day) =>
    '${day.year}-${day.month.toString().padLeft(2, '0')}-'
    '${day.day.toString().padLeft(2, '0')}';

Widget _app(ProviderContainer container) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(body: MonthView()),
    ),
  );
}

Finder _cell(DateTime day) =>
    find.byKey(ValueKey('month-day-${_dayKey(day)}'));

Finder _row(String eventId) =>
    find.byKey(ValueKey('preview-row-$eventId'));

Finder _checkCircle(String eventId) => find.descendant(
  of: _row(eventId),
  matching: find.byType(AppCheckCircle),
);

Finder _inPreview(Finder matching) => find.descendant(
  of: find.byKey(const ValueKey('month-preview')),
  matching: matching,
);

void main() {
  late AppDatabase db;
  late ProviderContainer container;
  late EventRepository repo;
  late Event alpha;
  late Event bravo;

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
        todayProvider.overrideWithValue(DateTime(2026, 11, 16)),
      ],
    );
    alpha = await repo.create(
      title: 'Alpha',
      kind: 'plan',
      date: DateTime(2026, 11, 11),
      startMinute: 540,
      endMinute: 600,
    );
    bravo = await repo.create(
      title: 'Bravo',
      kind: 'reminder',
      date: DateTime(2026, 11, 11),
      startMinute: 630,
    );
    await repo.create(
      title: 'Charlie',
      kind: 'reminder',
      date: DateTime(2026, 11, 11),
      startMinute: 750,
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<void> pumpMonth(WidgetTester tester) async {
    await tester.pumpWidget(_app(container));
    await _settle(tester);
  }

  Future<void> openPreview(WidgetTester tester, DateTime day) async {
    await pumpMonth(tester);
    await tester.tap(_cell(day));
    // The single-click recognizer waits out the double-click window.
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
  }

  testWidgets('clicking a day opens an anchored popover, not a dialog', (
    tester,
  ) async {
    await pumpMonth(tester);
    final barriersBefore = find.byType(ModalBarrier).evaluate().length;
    await tester.tap(_cell(DateTime(2026, 11, 17)));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(find.byType(MonthPreviewPopover), findsOneWidget);
    expect(find.byType(Dialog), findsNothing);
    // No scrim: the popover adds no ModalBarrier to the route.
    expect(find.byType(ModalBarrier).evaluate().length, barriersBefore);

    final cellRect = tester.getRect(_cell(DateTime(2026, 11, 17)));
    final panel = find.byKey(const ValueKey('month-preview'));
    final popRect = tester.getRect(panel);
    expect(popRect.width, 340);
    expect(popRect.left, moreOrLessEquals(cellRect.left, epsilon: 0.5));
    expect(
      popRect.top,
      moreOrLessEquals(cellRect.bottom + 8, epsilon: 0.5),
    );
  });

  testWidgets('flips above the anchor when there is no room below', (
    tester,
  ) async {
    await openPreview(tester, DateTime(2026, 11, 30));

    final cellRect = tester.getRect(_cell(DateTime(2026, 11, 30)));
    final popRect = tester.getRect(
      find.byKey(const ValueKey('month-preview')),
    );
    expect(popRect.top, lessThan(cellRect.top));
    expect(popRect.bottom, lessThanOrEqualTo(cellRect.top));
    expect(popRect.top, greaterThanOrEqualTo(8));
  });

  testWidgets('shows the day header, count and EventListRow rows', (
    tester,
  ) async {
    await openPreview(tester, DateTime(2026, 11, 11));

    expect(find.byKey(const ValueKey('month-preview')), findsOneWidget);
    expect(_inPreview(find.text('Nov 11 Wed')), findsOneWidget);
    expect(_inPreview(find.text('· 3 items')), findsOneWidget);
    expect(_inPreview(find.text('09:00–10:00')), findsOneWidget);
    expect(_inPreview(find.text('Alpha')), findsOneWidget);
    expect(_inPreview(find.text('Bravo')), findsOneWidget);
    expect(_inPreview(find.text('Charlie')), findsOneWidget);
    expect(find.byType(EventListRow), findsNWidgets(3));
    expect(_row(alpha.id), findsOneWidget);
    expect(_row(bravo.id), findsOneWidget);
    expect(_checkCircle(alpha.id), findsOneWidget);
    expect(_checkCircle(bravo.id), findsOneWidget);
  });

  testWidgets('close button closes the popover', (tester) async {
    await openPreview(tester, DateTime(2026, 11, 11));

    await tester.tap(find.byKey(const ValueKey('month-preview-close')));
    await _settle(tester);

    expect(find.byType(MonthPreviewPopover), findsNothing);
  });

  testWidgets('escape closes the popover', (tester) async {
    await openPreview(tester, DateTime(2026, 11, 11));

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await _settle(tester);

    expect(find.byType(MonthPreviewPopover), findsNothing);
  });

  testWidgets('tapping outside closes the popover', (tester) async {
    await openPreview(tester, DateTime(2026, 11, 11));

    await tester.tapAt(const Offset(10, 10));
    await _settle(tester);

    expect(find.byType(MonthPreviewPopover), findsNothing);
  });

  testWidgets('tapping a row opens the shared editor', (tester) async {
    await openPreview(tester, DateTime(2026, 11, 11));

    await tester.tap(_inPreview(find.text('Bravo')));
    await _settle(tester);

    expect(find.byKey(const ValueKey('editor-save')), findsOneWidget);
  });

  testWidgets('checking a row completes the event in place', (tester) async {
    await openPreview(tester, DateTime(2026, 11, 11));

    await tester.tap(_checkCircle(alpha.id));
    await tester.pump(const Duration(milliseconds: 150));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );

    final completed = await tester.runAsync(() => repo.getById(alpha.id));
    expect(completed!.isCompleted, isTrue);
  });

  testWidgets(
    'completion state follows its event when an earlier row appears',
    (tester) async {
      await openPreview(tester, DateTime(2026, 11, 11));

      // Complete the 10:30 row, then insert an 08:00 row above it. Unkeyed
      // rows would carry the 'completing' state down to a different event.
      await tester.tap(_checkCircle(bravo.id));
      await tester.pump(const Duration(milliseconds: 150));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );

      final earlier = await repo.create(
        title: 'Aardvark',
        kind: 'reminder',
        date: DateTime(2026, 11, 11),
        startMinute: 480,
      );
      await _settle(tester);

      await tester.tap(_checkCircle(alpha.id));
      await tester.pump(const Duration(milliseconds: 150));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );

      final completed = await tester.runAsync(() => repo.getById(alpha.id));
      final open = await tester.runAsync(() => repo.getById(earlier.id));
      expect(completed!.isCompleted, isTrue);
      expect(open!.isCompleted, isFalse);
    },
  );

  testWidgets('closing during the fade still writes the completion', (
    tester,
  ) async {
    await openPreview(tester, DateTime(2026, 11, 11));

    await tester.tap(_checkCircle(alpha.id));
    await tester.pump(const Duration(milliseconds: 20));
    // Tear the popover down before the 120ms fade finishes; the write must
    // still happen without touching `ref` after disposal.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 200));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );

    final completed = await tester.runAsync(() => repo.getById(alpha.id));
    expect(completed!.isCompleted, isTrue);
  });

  testWidgets('long days scroll inside the popover and keep it dismissible', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(500, 360);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (var i = 0; i < 9; i++) {
      await repo.create(
        title: 'Extra$i',
        kind: 'reminder',
        date: DateTime(2026, 11, 11),
        startMinute: 480 + i * 15,
      );
    }

    await openPreview(tester, DateTime(2026, 11, 11));

    expect(find.byKey(const ValueKey('month-preview-scroll')), findsOneWidget);
    final scrollable = find.descendant(
      of: find.byKey(const ValueKey('month-preview-scroll')),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(find.text('Extra8'), 50,
        scrollable: scrollable);
    expect(find.text('Extra8'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // The header stays pinned while the rows scroll, so × remains tappable.
    await tester.tap(find.byKey(const ValueKey('month-preview-close')));
    await _settle(tester);
    expect(find.byType(MonthPreviewPopover), findsNothing);
  });
}

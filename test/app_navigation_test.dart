import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tempolet/app.dart';
import 'package:tempolet/core/layout.dart';
import 'package:tempolet/core/prefs.dart';
import 'package:tempolet/data/database/database.dart';
import 'package:tempolet/data/repositories/event_repository.dart';
import 'package:tempolet/features/shell/icon_rail.dart';

Future<void> pumpApp(
  WidgetTester tester, {
  AppLayout? layout,
  Size? size,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  debugLayoutOverride = layout;
  addTearDown(() => debugLayoutOverride = null);
  if (size != null) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        eventsInRangeProvider.overrideWith(
          (ref, arg) => Stream.value(const <Event>[]),
        ),
        holidaysProvider.overrideWith((ref) => Stream.value(const <Holiday>[])),
      ],
      child: const TempoletApp(),
    ),
  );
  await tester.pumpAndSettle();
}

/// The rail's selected branch, read straight off the rail widget.
int railSelectedIndex(WidgetTester tester) =>
    tester.widget<IconRail>(find.byType(IconRail)).selectedIndex;

GoRouter routerOf(WidgetTester tester) =>
    GoRouter.of(tester.element(find.byType(IconRail)));

void main() {
  testWidgets('icon rail boots to calendar and switches to settings', (
    tester,
  ) async {
    await pumpApp(tester);

    expect(find.byKey(const ValueKey('rail-calendar')), findsOneWidget);
    expect(find.byKey(const ValueKey('calendar-page')), findsOneWidget);
    expect(find.byKey(const ValueKey('settings-page')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('rail-settings')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('settings-page')), findsOneWidget);
    expect(find.byKey(const ValueKey('calendar-page')), findsNothing);
  });

  testWidgets('rail has calendar, reminders and settings destinations', (
    tester,
  ) async {
    await pumpApp(tester);

    expect(find.byKey(const ValueKey('rail-calendar')), findsOneWidget);
    expect(find.byKey(const ValueKey('rail-reminders')), findsOneWidget);
    expect(find.byKey(const ValueKey('rail-settings')), findsOneWidget);
  });

  testWidgets('rail matches the 56 wide / 27 items / 8 gap spec', (
    tester,
  ) async {
    await pumpApp(tester);

    expect(tester.getSize(find.byKey(const ValueKey('icon-rail'))).width, 56);

    final calendar = find.byKey(const ValueKey('rail-calendar'));
    final reminders = find.byKey(const ValueKey('rail-reminders'));
    final calendarHit = find.byKey(const ValueKey('rail-calendar-hit'));
    expect(tester.getSize(calendarHit), const Size(27, 27));
    expect(tester.getSize(calendar), const Size(27, 27));
    expect(tester.getSize(reminders), const Size(27, 27));
    expect(tester.getTopLeft(calendar).dy, 16);
    expect(
      tester.getTopLeft(reminders).dy - tester.getBottomLeft(calendar).dy,
      8,
    );
  });

  testWidgets('tablet rail keeps 27 visual inside a 44 hit target', (
    tester,
  ) async {
    await pumpApp(
      tester,
      layout: AppLayout.tablet,
      size: const Size(1280, 800),
    );

    expect(tester.getSize(find.byKey(const ValueKey('icon-rail'))).width, 56);
    final calendarHit = find.byKey(const ValueKey('rail-calendar-hit'));
    final remindersHit = find.byKey(const ValueKey('rail-reminders-hit'));
    expect(tester.getSize(calendarHit), const Size(44, 44));
    expect(tester.getSize(remindersHit), const Size(44, 44));
    expect(
      tester.getSize(find.byKey(const ValueKey('rail-calendar'))),
      const Size(27, 27),
    );
    expect(tester.getTopLeft(calendarHit).dy, 16);
    expect(
      tester.getTopLeft(remindersHit).dy - tester.getBottomLeft(calendarHit).dy,
      8,
    );
  });

  testWidgets('completed keeps the entry branch highlighted', (tester) async {
    await pumpApp(tester);

    routerOf(tester).go('/reminders/completed');
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('completed-page')), findsOneWidget);
    expect(railSelectedIndex(tester), 1);

    routerOf(tester).go('/calendar/completed');
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('completed-page')), findsOneWidget);
    expect(railSelectedIndex(tester), 0);
  });

  testWidgets('completed back returns to the entry branch', (tester) async {
    await pumpApp(tester);

    routerOf(tester).go('/reminders/completed');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('completed-back')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('reminders-page')), findsOneWidget);
    expect(railSelectedIndex(tester), 1);
  });

  testWidgets('reminders header completed button opens the reminders branch', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.byKey(const ValueKey('rail-reminders')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('reminders-page')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('reminders-view-completed')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('completed-page')), findsOneWidget);
    expect(railSelectedIndex(tester), 1);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tempolet/app.dart';
import 'package:tempolet/core/prefs.dart';
import 'package:tempolet/data/database/database.dart';
import 'package:tempolet/data/repositories/event_repository.dart';

Future<void> pumpApp(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

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

  testWidgets('rail is 54px wide', (tester) async {
    await pumpApp(tester);

    expect(tester.getSize(find.byKey(const ValueKey('icon-rail'))).width, 54);
  });
}

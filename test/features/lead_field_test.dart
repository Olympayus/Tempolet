import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tempolet/core/l10n/generated/app_localizations.dart';
import 'package:tempolet/features/events/fields/lead_field.dart';

Widget _host(int? value, ValueChanged<int?> onChanged) {
  return MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: 240,
          child: LeadField(value: value, onChanged: onChanged),
        ),
      ),
    ),
  );
}

Future<void> _selectOption(WidgetTester tester, String label) async {
  await tester.tap(find.byKey(const ValueKey('lead-dropdown')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('null means no reminder and standards map to minutes', (
    tester,
  ) async {
    int? value;
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) => _host(value, (next) {
          setState(() => value = next);
        }),
      ),
    );

    expect(find.text('No reminder'), findsOneWidget);

    await _selectOption(tester, 'At start');
    expect(value, 0);

    await _selectOption(tester, '5 min before');
    expect(value, 5);

    await _selectOption(tester, 'No reminder');
    expect(value, isNull);
  });

  testWidgets('custom row stores day/hour/minute as total minutes', (
    tester,
  ) async {
    int? value;
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) => _host(value, (next) {
          setState(() => value = next);
        }),
      ),
    );

    await _selectOption(tester, 'Custom…');
    expect(find.byKey(const ValueKey('lead-custom-day')), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('lead-custom-hour')), '1');
    await tester.pump();
    expect(value, 60);

    await tester.enterText(find.byKey(const ValueKey('lead-custom-day')), '2');
    await tester.enterText(find.byKey(const ValueKey('lead-custom-hour')), '0');
    await tester.enterText(
      find.byKey(const ValueKey('lead-custom-minute')),
      '30',
    );
    await tester.pump();
    expect(value, 2 * 1440 + 30);
  });

  testWidgets('an external custom value collapses into a readable label', (
    tester,
  ) async {
    await tester.pumpWidget(_host(90, (_) {}));

    final dropdown = tester.widget<DropdownButton<int?>>(
      find.byKey(const ValueKey('lead-dropdown')),
    );
    expect(dropdown.value, 90);
    expect(find.text('1h 30m before'), findsOneWidget);
  });
}

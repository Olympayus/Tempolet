import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tempolet/core/l10n/generated/app_localizations.dart';
import 'package:tempolet/core/layout.dart';
import 'package:tempolet/core/prefs.dart';
import 'package:tempolet/core/theme/app_theme.dart';
import 'package:tempolet/features/settings/settings_page.dart';

void main() {
  testWidgets('phone accent picker is a bottom sheet with advanced RGB/HEX', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    debugLayoutOverride = AppLayout.phone;
    addTearDown(() => debugLayoutOverride = null);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('zh'),
          theme: AppTheme.light(Colors.blue),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const SettingsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('settings-row-accent')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('accent-picker-sheet')), findsOneWidget);
    expect(find.byKey(const ValueKey('accent-advanced')), findsOneWidget);
    expect(find.byKey(const ValueKey('accent-hex')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('accent-advanced')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('accent-hex')), findsOneWidget);
  });
}

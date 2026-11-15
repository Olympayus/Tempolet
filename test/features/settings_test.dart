import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tempolet/core/l10n/generated/app_localizations.dart';
import 'package:tempolet/core/l10n/locale_controller.dart';
import 'package:tempolet/core/prefs.dart';
import 'package:tempolet/core/theme/theme_controller.dart';
import 'package:tempolet/core/theme/theme_settings.dart';
import 'package:tempolet/features/settings/desktop_prefs.dart';
import 'package:tempolet/features/settings/notification_prefs.dart';
import 'package:tempolet/features/settings/settings_page.dart';

/// Text currently held by the color picker field with [key].
String _fieldText(WidgetTester tester, String key) {
  final field = tester.widget<TextField>(find.byKey(ValueKey(key)));
  return field.controller!.text;
}

Future<void> _openPicker(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('accent-swatch')));
  await tester.pumpAndSettle();
}

Future<void> _selectDropdown(WidgetTester tester, String label) async {
  await tester.tap(find.byKey(const ValueKey('lead-dropdown')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

void main() {
  late ProviderContainer container;
  late SharedPreferences prefs;

  Future<void> pumpSettings(
    WidgetTester tester, {
    Locale locale = const Locale('en'),
    Map<String, Object> initialPrefs = const {},
  }) async {
    SharedPreferences.setMockInitialValues(initialPrefs);
    prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const SettingsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('default reminder offset semantics', () {
    test('an unset preference reads as at-start (0)', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      expect(container.read(defaultReminderOffsetProvider), 0);
    });

    test('the stored -1 sentinel reads as no reminder', () async {
      SharedPreferences.setMockInitialValues({'default_remind_offset': -1});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      expect(container.read(defaultReminderOffsetProvider), isNull);
    });

    test('set(null) stores the sentinel instead of removing the key', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      container.read(defaultReminderOffsetProvider.notifier).set(null);
      expect(prefs.getInt('default_remind_offset'), -1);
      expect(container.read(defaultReminderOffsetProvider), isNull);

      container.read(defaultReminderOffsetProvider.notifier).set(15);
      expect(prefs.getInt('default_remind_offset'), 15);
      expect(container.read(defaultReminderOffsetProvider), 15);
    });
  });

  testWidgets('settings shows version and groups', (tester) async {
    await pumpSettings(tester, locale: const Locale('zh'));

    expect(find.text('0.1.2'), findsOneWidget);
    expect(find.text('设置'), findsOneWidget);
    expect(find.text('外观'), findsOneWidget);
    expect(find.text('通知'), findsOneWidget);
    expect(find.text('桌面'), findsOneWidget);
    expect(find.text('关于'), findsOneWidget);
  });

  testWidgets('accent row is a single swatch opening the picker', (
    tester,
  ) async {
    await pumpSettings(tester);

    expect(find.byKey(const ValueKey('accent-swatch')), findsOneWidget);
    expect(find.byKey(const ValueKey('accent-preset')), findsNothing);

    await _openPicker(tester);
    expect(find.byKey(const ValueKey('color-picker')), findsOneWidget);

    // Make the restore assertion meaningful by moving away from the default.
    await tester.enterText(find.byKey(const ValueKey('color-hex')), '#123456');
    await tester.pump();
    expect(find.text('#123456'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('color-restore')));
    await tester.pumpAndSettle();
    expect(find.text('#007AFF'), findsOneWidget);
  });

  testWidgets('RGB and HEX inputs stay in sync and confirm applies the color', (
    tester,
  ) async {
    await pumpSettings(tester);
    await _openPicker(tester);

    await tester.enterText(find.byKey(const ValueKey('color-hex')), '#FF9500');
    await tester.pump();
    expect(_fieldText(tester, 'color-r'), '255');
    expect(_fieldText(tester, 'color-g'), '149');
    expect(_fieldText(tester, 'color-b'), '0');

    await tester.enterText(find.byKey(const ValueKey('color-r')), '0');
    await tester.pump();
    expect(_fieldText(tester, 'color-hex'), '#009500');

    await tester.tap(find.byKey(const ValueKey('color-confirm')));
    await tester.pumpAndSettle();

    expect(
      container.read(themeControllerProvider).accent,
      const Color(0xFF009500),
    );
    expect(prefs.getInt('accent_color'), 0xFF009500);
  });

  testWidgets('cancelling the picker keeps the current accent', (tester) async {
    await pumpSettings(tester);
    await _openPicker(tester);

    await tester.enterText(find.byKey(const ValueKey('color-hex')), '#FF0000');
    await tester.tap(find.byKey(const ValueKey('color-cancel')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('color-picker')), findsNothing);
    expect(container.read(themeControllerProvider).accent, defaultAccent);
  });

  testWidgets('selecting the dark theme updates the controller', (
    tester,
  ) async {
    await pumpSettings(tester);

    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();

    expect(container.read(themeControllerProvider).mode, ThemeMode.dark);
    expect(prefs.getString('theme_mode'), 'dark');
  });

  testWidgets('switching language persists and changes locale', (tester) async {
    await pumpSettings(tester);

    await tester.tap(find.byKey(const ValueKey('language-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('中文').last);
    await tester.pumpAndSettle();

    expect(container.read(localeControllerProvider), const Locale('zh'));
    expect(prefs.getString('locale'), 'zh');
  });

  testWidgets('default reminder lead time persists with the sentinel', (
    tester,
  ) async {
    await pumpSettings(tester);

    await _selectDropdown(tester, '10 min before');
    expect(container.read(defaultReminderOffsetProvider), 10);
    expect(prefs.getInt('default_remind_offset'), 10);

    await _selectDropdown(tester, 'No reminder');
    expect(container.read(defaultReminderOffsetProvider), isNull);
    expect(prefs.getInt('default_remind_offset'), -1);
  });

  testWidgets('notification switches persist', (tester) async {
    await pumpSettings(tester);

    await tester.ensureVisible(find.byKey(const ValueKey('switch-sound')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('switch-sound')));
    await tester.pumpAndSettle();
    expect(container.read(notificationSoundEnabledProvider), isFalse);
    expect(prefs.getBool('notification_sound'), isFalse);

    await tester.ensureVisible(find.byKey(const ValueKey('switch-overdue')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('switch-overdue')));
    await tester.pumpAndSettle();
    expect(container.read(overdueSummaryEnabledProvider), isFalse);
    expect(prefs.getBool('overdue_summary'), isFalse);

    expect(
      find.text('Notifications require the app to keep running'),
      findsOneWidget,
    );
  });

  testWidgets('tray and startup toggles persist their prefs keys', (
    tester,
  ) async {
    await pumpSettings(tester);

    await tester.ensureVisible(find.byKey(const ValueKey('switch-tray')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('switch-tray')));
    await tester.pumpAndSettle();
    expect(container.read(minimizeToTrayEnabledProvider), isFalse);
    expect(prefs.getBool('minimize_to_tray'), isFalse);

    await tester.ensureVisible(find.byKey(const ValueKey('switch-startup')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('switch-startup')));
    await tester.pumpAndSettle();
    expect(container.read(launchAtStartupEnabledProvider), isTrue);
    expect(prefs.getBool('launch_at_startup'), isTrue);
  });

  testWidgets('about group offers the data folder action', (tester) async {
    await pumpSettings(tester);

    expect(find.text('0.1.2'), findsOneWidget);
    expect(find.byKey(const ValueKey('open-data-folder')), findsOneWidget);

    await tester.ensureVisible(find.byKey(const ValueKey('open-data-folder')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('open-data-folder')));
    await tester.pumpAndSettle();
  });
}

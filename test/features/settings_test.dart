import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tempolet/core/l10n/generated/app_localizations.dart';
import 'package:tempolet/core/l10n/locale_controller.dart';
import 'package:tempolet/core/prefs.dart';
import 'package:tempolet/core/theme/theme_controller.dart';
import 'package:tempolet/data/database/database.dart';
import 'package:tempolet/features/settings/desktop_prefs.dart';
import 'package:tempolet/features/settings/notification_prefs.dart';
import 'package:tempolet/features/settings/settings_page.dart';
import 'package:drift/native.dart';

void main() {
  late ProviderContainer container;
  late SharedPreferences prefs;
  late AppDatabase db;

  Future<void> pumpSettings(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    db = AppDatabase(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        databaseProvider.overrideWithValue(db),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await db.close();
    });

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SettingsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('selecting the dark theme updates the controller', (tester) async {
    await pumpSettings(tester);

    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();

    expect(container.read(themeControllerProvider).mode, ThemeMode.dark);
    expect(prefs.getString('theme_mode'), 'dark');
  });

  testWidgets('tapping a preset accent updates and persists it', (tester) async {
    await pumpSettings(tester);

    await tester.tap(find.byKey(const ValueKey('accent-0xFFAF52DE')));
    await tester.pumpAndSettle();

    expect(container.read(themeControllerProvider).accent,
        const Color(0xFFAF52DE));
    expect(prefs.getInt('accent_color'), 0xFFAF52DE);
  });

  testWidgets('switching language persists and changes locale', (tester) async {
    await pumpSettings(tester);

    await tester.tap(find.text('中文'));
    await tester.pumpAndSettle();

    expect(container.read(localeControllerProvider), const Locale('zh'));
    expect(prefs.getString('locale'), 'zh');
  });

  testWidgets('default reminder lead time persists', (tester) async {
    await pumpSettings(tester);

    await tester.tap(find.text('10 min before'));
    await tester.pumpAndSettle();

    expect(container.read(defaultReminderOffsetProvider), 10);
    expect(prefs.getInt('default_remind_offset'), 10);
  });

  testWidgets('notification sound toggle persists', (tester) async {
    await pumpSettings(tester);

    await tester.tap(find.byKey(const ValueKey('switch-sound')));
    await tester.pumpAndSettle();

    expect(container.read(notificationSoundEnabledProvider), isFalse);
    expect(prefs.getBool('notification_sound'), isFalse);
  });

  testWidgets('overdue summary toggle persists', (tester) async {
    await pumpSettings(tester);

    await tester.tap(find.byKey(const ValueKey('switch-overdue')));
    await tester.pumpAndSettle();

    expect(container.read(overdueSummaryEnabledProvider), isFalse);
    expect(prefs.getBool('overdue_summary'), isFalse);
  });

  testWidgets('tray and startup toggles persist their prefs keys',
      (tester) async {
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
}

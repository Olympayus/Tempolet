import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tempolet/core/app_info.dart';
import 'package:tempolet/core/l10n/generated/app_localizations.dart';
import 'package:tempolet/core/l10n/locale_controller.dart';
import 'package:tempolet/core/prefs.dart';
import 'package:tempolet/core/theme/app_theme.dart';
import 'package:tempolet/core/theme/app_tokens.dart';
import 'package:tempolet/core/theme/theme_controller.dart';
import 'package:tempolet/core/theme/theme_settings.dart';
import 'package:tempolet/core/ui/app_hairline.dart';
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

/// The semantic palette the page currently renders with.
AppPalette _palette(WidgetTester tester) {
  final context = tester.element(find.byKey(const ValueKey('settings-page')));
  final theme = Theme.of(context);
  return (theme.brightness == Brightness.light
          ? AppPalette.light
          : AppPalette.dark)
      .withAccent(theme.colorScheme.primary);
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
          theme: AppTheme.light(defaultAccent),
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

    expect(find.text(kAppVersion), findsOneWidget);
    expect(find.text('设置'), findsOneWidget);
    expect(find.text('外观'), findsOneWidget);
    expect(find.text('通知'), findsOneWidget);
    expect(find.text('桌面'), findsOneWidget);
    expect(find.text('关于'), findsOneWidget);
  });

  testWidgets('page is a 760-wide column with the title 24 above the groups', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpSettings(tester, locale: const Locale('zh'));

    expect(
      tester.getSize(find.byKey(const ValueKey('settings-content'))).width,
      760,
    );

    final title = tester.widget<Text>(find.text('设置'));
    expect(title.style?.fontSize, 28);
    expect(title.style?.fontWeight, FontWeight.w700);

    final gap =
        tester.getTopLeft(find.text('外观')).dy -
        tester.getBottomLeft(find.text('设置')).dy;
    expect(gap, moreOrLessEquals(24));
  });

  testWidgets('groups use a 12-radius card container spaced 28 apart', (
    tester,
  ) async {
    await pumpSettings(tester, locale: const Locale('zh'));

    final box = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey('settings-group-appearance')),
    );
    final decoration = box.decoration as BoxDecoration;
    expect(decoration.color, AppPalette.light.card);
    expect(decoration.borderRadius, BorderRadius.circular(AppRadii.group));
    expect((decoration.border! as Border).top.color, AppPalette.light.line);

    final section = tester.widget<Text>(find.text('外观'));
    expect(section.style?.fontSize, 15);
    expect(section.style?.fontWeight, FontWeight.w600);

    final gap =
        tester.getTopLeft(find.text('通知')).dy -
        tester
            .getBottomLeft(
              find.byKey(const ValueKey('settings-group-appearance')),
            )
            .dy;
    expect(gap, moreOrLessEquals(28));

    // Only between rows: 11 rows across four groups carry seven hairlines.
    expect(find.byType(AppHairline), findsNWidgets(7));
  });

  testWidgets('settings rows are 64 high with title and hint', (tester) async {
    await pumpSettings(tester, locale: const Locale('zh'));

    expect(find.byKey(const ValueKey('switch-sound')), findsOneWidget);
    final row = tester.getSize(
      find.byKey(const ValueKey('settings-row-sound')),
    );
    expect(row.height, greaterThanOrEqualTo(64));
    expect(find.text('每天早上汇总未完成事项'), findsOneWidget);
  });

  testWidgets('hover fill is inset so it never covers the card border', (
    tester,
  ) async {
    await pumpSettings(tester, locale: const Locale('zh'));

    final fill = tester.widget<Container>(
      find
          .descendant(
            of: find.byKey(const ValueKey('settings-row-sound')),
            matching: find.byType(Container),
          )
          .first,
    );
    final decoration = fill.decoration! as BoxDecoration;
    expect(decoration.borderRadius, BorderRadius.circular(AppRadii.block));
    // All four sides: the first/last hoverable rows sit flush against the
    // card's top/bottom border too, so a horizontal-only inset would still
    // let the fill paint over it.
    expect(
      fill.margin,
      const EdgeInsets.all(1),
      reason: 'the hover fill must leave every 1px card border visible',
    );
  });

  testWidgets('every setting row is at least 64 high', (tester) async {
    await pumpSettings(tester, locale: const Locale('zh'));

    const rowKeys = [
      'settings-row-theme',
      'settings-row-accent',
      'settings-row-language',
      'settings-row-lead',
      'settings-row-sound',
      'settings-row-overdue',
      'settings-row-tray',
      'settings-row-startup',
      'settings-row-version',
      'settings-row-data',
    ];
    for (final key in rowKeys) {
      final size = tester.getSize(find.byKey(ValueKey(key)));
      expect(size.height, greaterThanOrEqualTo(64), reason: key);
    }
  });

  testWidgets('exactly the five §8 settings carry hints', (tester) async {
    await pumpSettings(tester, locale: const Locale('zh'));

    for (final hint in const [
      '新建提醒时默认使用的提前量',
      '每天早上汇总未完成事项',
      '关闭窗口后继续在托盘运行',
      '登录 Windows 后自动启动',
      '用于今天、选中状态与主按钮',
    ]) {
      expect(find.text(hint), findsOneWidget, reason: hint);
    }

    final hint = tester.widget<Text>(find.text('每天早上汇总未完成事项'));
    expect(hint.style?.fontSize, 13);
    expect(hint.style?.color, _palette(tester).sub);

    final title = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const ValueKey('settings-row-overdue')),
        matching: find.text('超时未完成次日汇总'),
      ),
    );
    expect(title.style?.fontSize, 14);
    expect(title.style?.fontWeight, FontWeight.w500);
  });

  testWidgets('controls use the shared 28/36/40 primitives', (tester) async {
    await pumpSettings(tester);

    expect(find.byType(SegmentedButton<ThemeMode>), findsNothing);
    expect(find.byType(DropdownButton<String>), findsNothing);
    expect(find.byType(Switch), findsNothing);
    expect(find.byType(ListTile), findsNothing);

    final themeSegment = find.byKey(const ValueKey('theme-segmented'));
    expect(tester.getSize(themeSegment).height, 28);
    for (final icon in [
      LucideIcons.sun,
      LucideIcons.moon,
      LucideIcons.monitor,
    ]) {
      expect(
        find.descendant(of: themeSegment, matching: find.byIcon(icon)),
        findsOneWidget,
      );
    }

    expect(
      tester.getSize(find.byKey(const ValueKey('switch-sound'))),
      const Size(40, 24),
    );

    for (final rowKey in ['settings-row-language', 'settings-row-lead']) {
      final trigger = find.descendant(
        of: find.byKey(ValueKey(rowKey)),
        matching: find.byKey(const ValueKey('app-dropdown-trigger')),
      );
      expect(trigger, findsOneWidget, reason: rowKey);
      final size = tester.getSize(trigger);
      expect(size.height, 36, reason: rowKey);
      expect(size.width, greaterThanOrEqualTo(160), reason: rowKey);
    }
  });

  testWidgets('accent row is an 18px circle, HEX and chevron, all tappable', (
    tester,
  ) async {
    await pumpSettings(tester);

    final row = find.byKey(const ValueKey('settings-row-accent'));
    expect(
      tester.getSize(find.byKey(const ValueKey('accent-swatch'))),
      const Size(18, 18),
    );
    expect(
      find.descendant(of: row, matching: find.text('#007AFF')),
      findsOneWidget,
    );
    final hex = tester.widget<Text>(find.text('#007AFF'));
    expect(hex.style?.fontSize, 13);
    expect(
      find.descendant(of: row, matching: find.byIcon(LucideIcons.chevronRight)),
      findsOneWidget,
    );

    // Tapping the title area (not the swatch) still opens the picker.
    await tester.tapAt(tester.getTopLeft(row) + const Offset(12, 32));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('color-picker')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('color-cancel')));
    await tester.pumpAndSettle();
  });

  testWidgets('notifications start with a non-tappable 11/sub Windows note', (
    tester,
  ) async {
    await pumpSettings(tester, locale: const Locale('zh'));

    const noteText = 'Windows 不会弹权限请求；收不到提醒请在系统设置中允许通知';
    final note = tester.widget<Text>(find.text(noteText));
    expect(note.style?.fontSize, 11);
    expect(note.style?.color, _palette(tester).sub);

    final noteRow = find.byKey(const ValueKey('settings-row-windows-note'));
    expect(noteRow, findsOneWidget);
    expect(
      find.descendant(of: noteRow, matching: find.byType(GestureDetector)),
      findsNothing,
    );
    expect(find.text('通知需要应用保持运行'), findsNothing);
  });

  testWidgets('about shows a 13/sub version and a 13/accent data link', (
    tester,
  ) async {
    await pumpSettings(tester, locale: const Locale('zh'));

    final version = tester.widget<Text>(find.text(kAppVersion));
    expect(version.style?.fontSize, 13);
    expect(version.style?.color, _palette(tester).sub);

    final link = tester.widget<Text>(find.text('打开文件夹 ›'));
    expect(link.style?.fontSize, 13);
    expect(link.style?.color, _palette(tester).accent);
    expect(find.byKey(const ValueKey('open-data-folder')), findsOneWidget);
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
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('color-picker')),
        matching: find.text('#007AFF'),
      ),
      findsOneWidget,
    );
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
      find.text(
        "Windows doesn't ask for notification permission; if reminders don't "
        'appear, allow notifications in system settings',
      ),
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

    expect(find.text(kAppVersion), findsOneWidget);
    expect(find.byKey(const ValueKey('open-data-folder')), findsOneWidget);

    await tester.ensureVisible(find.byKey(const ValueKey('open-data-folder')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('open-data-folder')));
    await tester.pumpAndSettle();
  });
}

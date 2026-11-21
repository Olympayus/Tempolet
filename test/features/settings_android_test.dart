import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tempolet/core/l10n/generated/app_localizations.dart';
import 'package:tempolet/core/layout.dart';
import 'package:tempolet/core/platform/android_capabilities.dart';
import 'package:tempolet/core/prefs.dart';
import 'package:tempolet/core/theme/app_theme.dart';
import 'package:tempolet/features/settings/settings_page.dart';

class _FakeCapabilities implements AndroidCapabilities {
  _FakeCapabilities({
    this.permission = NotificationPermissionState.granted,
    this.exact = true,
  });

  NotificationPermissionState permission;
  bool exact;
  int openNotificationCalls = 0;
  int openExactCalls = 0;

  @override
  Future<NotificationPermissionState> notificationPermission() async =>
      permission;

  @override
  Future<bool> canScheduleExactAlarms() async => exact;

  @override
  Future<void> openNotificationSettings() async {
    openNotificationCalls++;
  }

  @override
  Future<void> openExactAlarmSettings() async {
    openExactCalls++;
  }

  @override
  Future<void> markNotificationPermissionRequested() async {}
}

void main() {
  Future<_FakeCapabilities> pumpSettings(
    WidgetTester tester, {
    NotificationPermissionState permission =
        NotificationPermissionState.granted,
    bool exactAlarms = true,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final fake = _FakeCapabilities(permission: permission, exact: exactAlarms);
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        androidCapabilitiesProvider.overrideWithValue(fake),
      ],
    );
    addTearDown(container.dispose);
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    debugLayoutOverride = AppLayout.tablet;
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
    return fake;
  }

  testWidgets('denied and permanently denied rows are visible; granted hides', (
    tester,
  ) async {
    await pumpSettings(tester, permission: NotificationPermissionState.denied);
    expect(
      find.byKey(const ValueKey('settings-row-notification-permission')),
      findsOneWidget,
    );

    await pumpSettings(
      tester,
      permission: NotificationPermissionState.permanentlyDenied,
    );
    expect(find.textContaining('已被系统关闭'), findsOneWidget);

    await pumpSettings(tester);
    expect(
      find.byKey(const ValueKey('settings-row-notification-permission')),
      findsNothing,
    );
  });

  testWidgets('exact alarm row appears only when unavailable', (tester) async {
    await pumpSettings(tester, exactAlarms: false);
    expect(
      find.byKey(const ValueKey('settings-row-exact-alarm')),
      findsOneWidget,
    );

    await pumpSettings(tester, exactAlarms: true);
    expect(
      find.byKey(const ValueKey('settings-row-exact-alarm')),
      findsNothing,
    );
  });
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tempolet/core/prefs.dart';
import 'package:tempolet/desktop/window_service.dart';
import 'package:tempolet/features/settings/desktop_prefs.dart';

void main() {
  test('shouldHideOnClose follows the minimise-to-tray setting', () {
    expect(shouldHideOnClose(true), isTrue);
    expect(shouldHideOnClose(false), isFalse);
  });

  test('desktop prefs restore from SharedPreferences', () async {
    SharedPreferences.setMockInitialValues({
      'minimize_to_tray': false,
      'launch_at_startup': true,
    });
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    expect(container.read(minimizeToTrayEnabledProvider), isFalse);
    expect(container.read(launchAtStartupEnabledProvider), isTrue);
  });

  test('desktop prefs default to tray-on, startup-off', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    expect(container.read(minimizeToTrayEnabledProvider), isTrue);
    expect(container.read(launchAtStartupEnabledProvider), isFalse);
  });
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tempolet/core/prefs.dart';
import 'package:tempolet/data/prefs/data_layer_prefs.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('vault path persists and clears', () async {
    SharedPreferences.setMockInitialValues({'vault_path': r'D:\Notes'});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
    ]);
    addTearDown(container.dispose);

    expect(container.read(vaultPathProvider), r'D:\Notes');
    container.read(vaultPathProvider.notifier).set(null);
    expect(container.read(vaultPathProvider), isNull);
    expect(prefs.getString('vault_path'), isNull);
  });

  test('term start monday round-trips as ISO date', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
    ]);
    addTearDown(container.dispose);

    container.read(termStartMondayProvider.notifier).set(DateTime(2026, 9, 7));
    expect(prefs.getString('term_start_monday'), '2026-09-07');
    expect(container.read(termStartMondayProvider), DateTime(2026, 9, 7));
  });

  test('course component defaults off', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
    ]);
    addTearDown(container.dispose);
    expect(container.read(courseComponentEnabledProvider), isFalse);
  });

  test('holiday seed version persists', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
    ]);
    addTearDown(container.dispose);

    expect(container.read(holidaySeedVersionProvider), isNull);
    container.read(holidaySeedVersionProvider.notifier).set('2026.1');
    expect(prefs.getString('holiday_seed_version'), '2026.1');
    expect(container.read(holidaySeedVersionProvider), '2026.1');
  });
}

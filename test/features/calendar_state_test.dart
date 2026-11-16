import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tempolet/core/prefs.dart';
import 'package:tempolet/features/calendar/calendar_state.dart';

Future<ProviderContainer> _container() async {
  final prefs = await SharedPreferences.getInstance();
  return ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('SelectedDayController', () {
    test('shiftDays moves by calendar days across month boundaries', () async {
      final container = await _container();
      addTearDown(container.dispose);

      final notifier = container.read(selectedDayProvider.notifier)
        ..select(DateTime(2026, 11, 30))
        ..shiftDays(1);
      expect(container.read(selectedDayProvider), DateTime(2026, 12, 1));

      notifier.shiftDays(-3);
      expect(container.read(selectedDayProvider), DateTime(2026, 11, 28));
    });

    test('shiftMonths clamps the day to the target month', () async {
      final container = await _container();
      addTearDown(container.dispose);

      final notifier = container.read(selectedDayProvider.notifier)
        ..select(DateTime(2026, 1, 31))
        ..shiftMonths(1);
      expect(container.read(selectedDayProvider), DateTime(2026, 2, 28));

      notifier
        ..select(DateTime(2028, 1, 31))
        ..shiftMonths(1);
      expect(container.read(selectedDayProvider), DateTime(2028, 2, 29));
    });

    test('shiftMonths crosses year boundaries', () async {
      final container = await _container();
      addTearDown(container.dispose);

      final notifier = container.read(selectedDayProvider.notifier)
        ..select(DateTime(2026, 12, 15))
        ..shiftMonths(1);
      expect(container.read(selectedDayProvider), DateTime(2027, 1, 15));

      notifier.shiftMonths(-2);
      expect(container.read(selectedDayProvider), DateTime(2026, 11, 15));
    });
  });

  group('sidebarPreferenceProvider', () {
    test('starts unset and persists choices under sidebar_open', () async {
      final container = await _container();
      addTearDown(container.dispose);

      expect(container.read(sidebarPreferenceProvider), isNull);

      container.read(sidebarPreferenceProvider.notifier).set(true);
      expect(container.read(sidebarPreferenceProvider), isTrue);
      expect(
        container.read(sharedPreferencesProvider).getBool('sidebar_open'),
        isTrue,
      );
    });

    test('reads a persisted value on build', () async {
      SharedPreferences.setMockInitialValues({'sidebar_open': false});
      final container = await _container();
      addTearDown(container.dispose);

      expect(container.read(sidebarPreferenceProvider), isFalse);
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tempolet/core/l10n/locale_controller.dart';
import 'package:tempolet/core/prefs.dart';

Future<ProviderContainer> _container([
  Map<String, Object> initial = const {},
]) async {
  SharedPreferences.setMockInitialValues(initial);
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('defaults to null (follow system)', () async {
    final container = await _container();
    expect(container.read(localeControllerProvider), isNull);
  });

  test('setLocale(zh) updates state and persists zh', () async {
    final container = await _container();
    container.read(localeControllerProvider.notifier).setLocale(const Locale('zh'));
    expect(container.read(localeControllerProvider), const Locale('zh'));
    final prefs = container.read(sharedPreferencesProvider);
    expect(prefs.getString('locale'), 'zh');
  });

  test('setLocale(null) persists system', () async {
    final container = await _container({'locale': 'en'});
    container.read(localeControllerProvider.notifier).setLocale(null);
    expect(container.read(localeControllerProvider), isNull);
    final prefs = container.read(sharedPreferencesProvider);
    expect(prefs.getString('locale'), 'system');
  });

  test('restores stored locale', () async {
    final container = await _container({'locale': 'en'});
    expect(container.read(localeControllerProvider), const Locale('en'));
  });
}

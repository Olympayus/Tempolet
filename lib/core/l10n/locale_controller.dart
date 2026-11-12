import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../prefs.dart';

final localeControllerProvider =
    NotifierProvider<LocaleController, Locale?>(LocaleController.new);

class LocaleController extends Notifier<Locale?> {
  static const prefKey = 'locale';

  @override
  Locale? build() {
    final raw = ref.watch(sharedPreferencesProvider).getString(prefKey);
    return switch (raw) {
      'en' => const Locale('en'),
      'zh' => const Locale('zh'),
      _ => null,
    };
  }

  void setLocale(Locale? locale) {
    state = locale;
    ref
        .read(sharedPreferencesProvider)
        .setString(prefKey, locale?.languageCode ?? 'system');
  }
}

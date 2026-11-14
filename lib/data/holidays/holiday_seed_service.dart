import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

import '../prefs/data_layer_prefs.dart';
import '../repositories/holiday_repository.dart';

/// Imports the bundled holiday JSON once per [version].
///
/// The seed version lives in the same preference as
/// [HolidaySeedVersionController], so a version bump re-runs the (idempotent)
/// import while unchanged versions skip the asset read entirely.
class HolidaySeedService {
  HolidaySeedService({
    required this.repository,
    required this.prefs,
    Future<String> Function(String assetPath)? loadAsset,
  }) : _loadAsset = loadAsset ?? rootBundle.loadString;

  final HolidayRepository repository;
  final SharedPreferences prefs;
  final Future<String> Function(String assetPath) _loadAsset;

  Future<void> seedIfNeeded({
    required String assetPath,
    required String version,
  }) async {
    final prefKey = HolidaySeedVersionController.prefKey;
    if (prefs.getString(prefKey) == version) return;

    final json = await _loadAsset(assetPath);
    await repository.seedFromJson(json);
    await prefs.setString(prefKey, version);
  }
}

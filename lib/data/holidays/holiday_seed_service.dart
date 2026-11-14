import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

import '../prefs/data_layer_prefs.dart';
import '../repositories/holiday_repository.dart';

/// Imports the bundled holiday JSON once per [version].
///
/// The applied version is stored in the same preference as
/// [HolidaySeedVersionController]. The raw JSON is also kept as a snapshot so
/// a restart can prime the repository's in-memory seed cache without reading
/// the asset again; if the snapshot is missing, the import re-runs even when
/// the version matches.
class HolidaySeedService {
  HolidaySeedService({
    required this.repository,
    required this.prefs,
    Future<String> Function(String assetPath)? loadAsset,
  }) : _loadAsset = loadAsset ?? rootBundle.loadString;

  static const snapshotPrefKey = 'holiday_seed_snapshot';

  final HolidayRepository repository;
  final SharedPreferences prefs;
  final Future<String> Function(String assetPath) _loadAsset;

  Future<void> seedIfNeeded({
    required String assetPath,
    required String version,
  }) async {
    final versionKey = HolidaySeedVersionController.prefKey;
    if (prefs.getString(versionKey) == version) {
      final snapshot = prefs.getString(snapshotPrefKey);
      if (snapshot != null) {
        repository.primeSeedCacheFromJson(snapshot);
        return;
      }
      // Version matches but the snapshot is gone: reseed to restore both the
      // cache and the snapshot.
    }

    final json = await _loadAsset(assetPath);
    await repository.seedFromJson(json);
    await prefs.setString(snapshotPrefKey, json);
    await prefs.setString(versionKey, version);
  }
}

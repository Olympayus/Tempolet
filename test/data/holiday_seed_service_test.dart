import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tempolet/data/database/database.dart';
import 'package:tempolet/data/holidays/holiday_seed_service.dart';
import 'package:tempolet/data/repositories/holiday_repository.dart';

const _assetPath = 'assets/holidays/2026.json';
const _assetJson = '''
{
  "year": 2026,
  "days": [
    {"name": "元旦", "date": "2026-01-01", "isOffDay": true},
    {"name": "元旦", "date": "2026-01-04", "isOffDay": false}
  ]
}
''';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late HolidayRepository repository;
  late SharedPreferences prefs;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repository = HolidayRepository(db);
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  tearDown(() async {
    await db.close();
  });

  test('seeds once per version and records the applied version', () async {
    var loads = 0;
    final service = HolidaySeedService(
      repository: repository,
      prefs: prefs,
      loadAsset: (path) async {
        expect(path, _assetPath);
        loads++;
        return _assetJson;
      },
    );

    await service.seedIfNeeded(assetPath: _assetPath, version: '2026.1');

    expect(loads, 1);
    expect(prefs.getString('holiday_seed_version'), '2026.1');
    expect(prefs.getString(HolidaySeedService.snapshotPrefKey), _assetJson);
    expect(await repository.isWorkday(DateTime(2026, 1, 1)), isFalse);
    expect(await repository.isWorkday(DateTime(2026, 1, 4)), isTrue);
    expect(await db.select(db.holidays).get(), hasLength(2));

    // Same version: primes the cache from the snapshot, no asset load.
    await service.seedIfNeeded(assetPath: _assetPath, version: '2026.1');
    expect(loads, 1);

    // New version: reloads and re-seeds without duplicating rows.
    await service.seedIfNeeded(assetPath: _assetPath, version: '2026.2');
    expect(loads, 2);
    expect(prefs.getString('holiday_seed_version'), '2026.2');
    expect(prefs.getString(HolidaySeedService.snapshotPrefKey), _assetJson);
    expect(await db.select(db.holidays).get(), hasLength(2));
  });

  test('a matching version primes the seed cache from the snapshot', () async {
    final first = HolidaySeedService(
      repository: repository,
      prefs: prefs,
      loadAsset: (_) async => _assetJson,
    );
    await first.seedIfNeeded(assetPath: _assetPath, version: '2026.1');
    await repository.setManual(
      date: DateTime(2026, 1, 1),
      name: '自定义',
      isWorkday: true,
    );

    // Restart simulation: a fresh repository has an empty seed cache while
    // the preference and the database keep their contents.
    final restartedRepository = HolidayRepository(db);
    var loads = 0;
    final restarted = HolidaySeedService(
      repository: restartedRepository,
      prefs: prefs,
      loadAsset: (_) async {
        loads++;
        return _assetJson;
      },
    );

    await restarted.seedIfNeeded(assetPath: _assetPath, version: '2026.1');

    expect(loads, 0);
    await restartedRepository.clearManual(DateTime(2026, 1, 1));
    final row = await (db.select(db.holidays)
          ..where((t) => t.date.equals(DateTime(2026, 1, 1))))
        .getSingle();
    expect(row.name, '元旦');
    expect(row.isWorkday, isFalse);
    expect(row.source, 'seed');
  });

  test('reseeds when the version matches but the snapshot is missing',
      () async {
    SharedPreferences.setMockInitialValues(
      {'holiday_seed_version': '2026.1'},
    );
    prefs = await SharedPreferences.getInstance();
    var loads = 0;
    final service = HolidaySeedService(
      repository: repository,
      prefs: prefs,
      loadAsset: (_) async {
        loads++;
        return _assetJson;
      },
    );

    await service.seedIfNeeded(assetPath: _assetPath, version: '2026.1');

    expect(loads, 1);
    expect(await db.select(db.holidays).get(), hasLength(2));
    expect(prefs.getString(HolidaySeedService.snapshotPrefKey), _assetJson);
  });

  test('does not record the version when the asset fails to load', () async {
    final service = HolidaySeedService(
      repository: repository,
      prefs: prefs,
      loadAsset: (_) async => throw StateError('asset unavailable'),
    );

    await expectLater(
      service.seedIfNeeded(assetPath: _assetPath, version: '2026.1'),
      throwsA(isA<StateError>()),
    );

    expect(prefs.getString('holiday_seed_version'), isNull);
    expect(prefs.getString(HolidaySeedService.snapshotPrefKey), isNull);
    expect(await db.select(db.holidays).get(), isEmpty);
  });
}

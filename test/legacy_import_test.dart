import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zerotrust_fitness/core/storage/fitness_vault.dart';
import 'package:zerotrust_fitness/features/legacy_import/legacy_fitness_import.dart';

import 'support.dart';

/// The fixture's raw SQLCipher key (and its rows' AES-GCM key).
final legacyKey = Uint8List.fromList(List.generate(32, (i) => i));

/// A copy of the fixture, since opening can write to it.
Future<String> fixtureCopy() async {
  final dir = await Directory.systemTemp.createTemp('fitness-legacy');
  final path = '${dir.path}/vault.sqlite';
  await File('test/fixtures/legacy_vault.sqlite').copy(path);
  addTearDown(() => dir.delete(recursive: true));
  return path;
}

Future<String> cloudBlob(Map<String, Object?> payload, List<int> key) =>
    LegacyCipher.encrypt(jsonEncode(payload), key);

final cloudPayload = <String, Object?>{
  'version': 2,
  'workouts': [
    // Same workout as on the phone, with an older edit.
    {'type': 'Running', 'duration': 25, 'intensity': 7, 'timestamp': '2026-10-01T07:30:00.000'},
    // Only in the cloud (logged on another phone).
    {'type': 'Swimming', 'duration': 40, 'intensity': 6, 'timestamp': '2026-09-20T09:00:00.000'},
  ],
  'daily_metric_map': {
    '2026-10-01': {'steps': 1, 'heart_points': 1},
    '2026-09-20': {'steps': 3000, 'heart_points': 40},
  },
  'achievements': [
    {'id': 'first_workout', 'unlocked_at': '2026-10-01T07:31:00Z'},
    {'id': 'swimmer', 'unlocked_at': '2026-09-20T10:00:00Z'},
  ],
};

class _Cloud implements LegacyCloudBackup {
  _Cloud(this.blob);
  final String? blob;
  @override
  Future<String?> fetch() async => blob;
}

class _Storage implements LegacySecureStorage {
  bool deleted = false;
  @override
  Future<List<int>?> storedDatabaseKey() async => null;
  @override
  Future<void> deleteLeftovers() async => deleted = true;
}

void main() {
  group('old phone database (real SQLCipher 4 file)', () {
    test('reads every table with the account key', () async {
      final data = await readLegacyLocalVault(await fixtureCopy(), [legacyKey]);
      expect(data, isNotNull);
      // The undecryptable row is skipped, as the old app skipped it.
      expect(data!.workouts.map((w) => w['type']), ['Running', 'Cycling']);
      expect(data.workouts[1]['distance_m'], 15000.0);
      expect(data.days['2026-10-01'],
          {'steps': 9000, 'steps_hc': 8000, 'steps_manual': 1000, 'heart_points': 42, 'weight_kg': 71.5});
      expect(data.days['2026-10-02']!['steps'], 4000);
      expect(data.achievements.keys, ['first_workout']);
      expect(data.goals.single.metricKey, 'steps');
      expect(data.goals.single.targetValue, 10000);
      expect(data.templates.single.name, 'Morning run');
      expect(data.templates.single.data['duration_minutes'], 25);
    });

    test('a wrong key reads nothing; the stored key is tried next', () async {
      final path = await fixtureCopy();
      final wrong = List<int>.filled(32, 9);
      expect(await readLegacyLocalVault(path, [wrong]), isNull);
      final data = await readLegacyLocalVault(path, [wrong, legacyKey]);
      expect(data!.workouts, hasLength(2));
    });

    test('no file, no data', () async {
      expect(await readLegacyLocalVault('/nonexistent/vault.sqlite', [legacyKey]),
          isNull);
    });
  });

  group('old cloud backup', () {
    test('decrypts and reads a version 2 backup', () async {
      final data = await readLegacyCloudBackup(
          await cloudBlob(cloudPayload, legacyKey), [legacyKey]);
      expect(data.workouts, hasLength(2));
      expect(data.days['2026-09-20'], {'steps': 3000, 'heart_points': 40});
      expect(data.achievements.keys, containsAll(['first_workout', 'swimmer']));
    });

    test('rebuilds days from a version 1 backup', () async {
      final data = await readLegacyCloudBackup(
          await cloudBlob({
            'steps': [
              {'timestamp': '2026-08-01T10:00:00', 'value': 500},
              {'timestamp': '2026-08-01T12:00:00', 'value': 700},
            ],
            'heart_points': {
              'records': [
                {'timestamp': '2026-08-01T10:00:00', 'metric': 'exercise_time_min', 'value': 15},
              ],
            },
          }, legacyKey),
          [legacyKey]);
      expect(data.days['2026-08-01'], {'steps': 1200, 'heart_points': 15});
    });

    test('a backup no key opens is reported, not silently dropped', () async {
      final blob = await cloudBlob(cloudPayload, List<int>.filled(32, 9));
      expect(() => readLegacyCloudBackup(blob, [legacyKey]),
          throwsA(isA<LegacyBackupUnreadable>()));
    });
  });

  group('importing across devices', () {
    late FakeSyncBackend server;
    late Uint8List appKey;
    late Uint8List idKey;

    setUp(() async {
      server = FakeSyncBackend();
      appKey = await KeyHierarchy.appKey(legacyKey, 'fitness');
      idKey = await FitnessVault.deriveIdKey(appKey);
    });

    Future<(ItemSyncEngine, FitnessVault)> device(String id) async {
      final store = InMemoryItemStore();
      final engine = await ItemSyncEngine.fromVault(
        appId: 'fitness',
        appKey: appKey,
        deviceId: id,
        store: store,
        backend: server,
      );
      final vault = FitnessVault(
          store: store, writer: _EngineWriter(engine), idKey: idKey);
      return (engine, vault);
    }

    Future<void> runImport(ItemSyncEngine engine, FitnessVault vault,
        {required String? localPath, required String? blob}) async {
      final ledger = MemoryLedger();
      for (final importer in fitnessLegacyImporters(
        vault: vault,
        cloud: _Cloud(blob),
        secureStorage: _Storage(),
        localPath: () async => localPath ?? '/nonexistent/vault.sqlite',
      )) {
        await importer.run(engine: engine, ledger: ledger, legacyKey: legacyKey);
      }
      await engine.sync();
    }

    test('phone and tablet end up with one copy of everything', () async {
      final blob = await cloudBlob(cloudPayload, legacyKey);
      final (phone, phoneVault) = await device('phone');
      await runImport(phone, phoneVault,
          localPath: await fixtureCopy(), blob: blob);

      final (tablet, tabletVault) = await device('tablet');
      await runImport(tablet, tabletVault, localPath: null, blob: blob);
      await phone.sync();

      for (final v in [phoneVault, tabletVault]) {
        final workouts = await v.fetchWorkouts();
        expect(workouts.map((w) => w.data['type']).toList(),
            ['Cycling', 'Running', 'Swimming']);
        // The phone's copy of the shared workout wins over the backup's.
        expect(workouts.firstWhere((w) => w.data['type'] == 'Running')
            .data['duration'], 30);

        final days = {
          for (final d in await v.fetchDailyMetrics())
            d['date_key']: d['metrics'] as Map
        };
        expect(days.keys, containsAll(['2026-10-01', '2026-10-02', '2026-09-20']));
        // The phone's day, with its manual split, not the backup's.
        expect(days['2026-10-01']!['steps_manual'], 1000);
        expect((await v.fetchAchievements()).map((a) => a['id']),
            containsAll(['first_workout', 'swimmer']));
        expect((await v.fetchGoals()).single['metric_key'], 'steps');
        expect((await v.fetchTemplates()).single.name, 'Morning run');
      }
    });

    test('a real edit made after the import wins on every device', () async {
      final blob = await cloudBlob(cloudPayload, legacyKey);
      final (phone, phoneVault) = await device('phone');
      await runImport(phone, phoneVault, localPath: null, blob: blob);
      final swim = (await phoneVault.fetchWorkouts())
          .firstWhere((w) => w.data['type'] == 'Swimming');
      await phoneVault.saveWorkout({...swim.data, 'duration': 55}, id: swim.id);
      await phone.sync();

      // A second device imports the same backup later.
      final (tablet, tabletVault) = await device('tablet');
      await runImport(tablet, tabletVault, localPath: null, blob: blob);
      final onTablet = (await tabletVault.fetchWorkouts())
          .firstWhere((w) => w.data['type'] == 'Swimming');
      expect(onTablet.data['duration'], 55);
    });

    test('an account with no old data imports nothing', () async {
      final (phone, phoneVault) = await device('phone');
      await runImport(phone, phoneVault, localPath: null, blob: null);
      expect((await phoneVault.countsByKind()).values,
          everyElement(0));
      expect(server.rows, isEmpty);
    });
  });
}

class _EngineWriter implements FitnessItemWriter {
  _EngineWriter(this.engine);
  final ItemSyncEngine engine;
  @override
  Future<void> save(String itemId, Map<String, Object?> json) =>
      engine.save(itemId, json);
  @override
  Future<void> delete(String itemId) => engine.delete(itemId);
}

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zerotrust_fitness/app/vault_providers.dart';
import 'package:zerotrust_fitness/features/legacy_import/legacy_fitness_import.dart';
import 'package:zerotrust_fitness/features/legacy_import/legacy_import_banner.dart';
import 'package:zerotrust_fitness/main.dart';

import 'support.dart';
import 'package:zerotrust_fitness/l10n/l10n.dart';

/// The account's legacy key (what the core kept as the DEK at upgrade).
final _accountKey = Uint8List.fromList(List.generate(32, (i) => i));

const _oldPassword = 'the password from before';
final _salt = base64Url.encode(List<int>.generate(16, (i) => 90 + i));

class _Cloud implements LegacyCloudBackup {
  _Cloud(this.blobs, {this.salt = true});
  final List<String> blobs;
  final bool salt;
  int fetches = 0;
  @override
  Future<List<String>> fetchAll() async {
    fetches++;
    return blobs;
  }

  @override
  Future<String?> legacySalt() async => salt ? _salt : null;
}

class _NoSecureStorage implements LegacySecureStorage {
  @override
  Future<List<int>?> storedDatabaseKey() async => null;
  @override
  Future<void> deleteLeftovers() async {}
}

/// A backup the account's key doesn't open, as on a phone whose old app
/// derived its key differently: only the old password opens it.
Future<String> _lockedBackup() async {
  final oldKey = await Kdf.deriveMasterKey(
      password: _oldPassword, salt: base64Url.decode(_salt));
  return LegacyCipher.encrypt(
    jsonEncode({
      'version': 2,
      'workouts': [
        {'type': 'Running', 'duration': 30, 'timestamp': '2026-10-01T07:30:00.000'},
      ],
      'daily_metric_map': {
        '2026-10-01': {'steps': 9000, 'heart_points': 42},
      },
    }),
    oldKey,
  );
}

ProviderContainer _container(
  LegacyCloudBackup cloud, {
  String localPath = '/nonexistent/vault.sqlite',
}) {
  final container = ProviderContainer(overrides: [
    ztAppConfigProvider.overrideWithValue(fitnessAppConfig),
    ztSyncBackendProvider.overrideWithValue(FakeSyncBackend()),
    ztDeviceIdStoreProvider
        .overrideWithValue(InMemoryDeviceIdStore()..id = 'phone'),
    ztPreferencesStoreProvider.overrideWithValue(InMemoryPreferencesStore()),
    ztLocalStoreProvider.overrideWith((ref) async {
      final appKey = ref.watch(vaultControllerProvider
          .select((v) => v is VaultUnlocked ? v.appKey : null));
      if (appKey == null) throw const VaultIsLocked();
      final store = await ZtLocalStore.open(appKey: appKey);
      ref.onDispose(store.close);
      return store;
    }),
    legacyCloudBackupProvider.overrideWithValue(cloud),
    legacySecureStorageProvider.overrideWithValue(_NoSecureStorage()),
    legacyLocalVaultPathProvider.overrideWithValue(() async => localPath),
  ]);
  addTearDown(container.dispose);
  return container;
}

Future<void> _unlock(ProviderContainer container) async {
  await container.read(vaultControllerProvider.notifier).unlock(
      Uint8List.fromList(_accountKey), legacyDek: true);
}

Future<LegacyImportStatus> _settled(ProviderContainer container) async {
  container.listen(legacyImportProvider, (_, __) {});
  for (var i = 0; i < 200; i++) {
    final s = container.read(legacyImportProvider);
    if (!s.running && (s.done || s.error != null)) return s;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail('import never finished');
}

void main() {
  test('old data the account key cannot open needs the old password, once',
      () async {
    final cloud = _Cloud([await _lockedBackup()]);
    final container = _container(cloud);
    await _unlock(container);

    // The dashboard doesn't wait for the import.
    await container.read(fitnessVaultProvider.future);
    var status = await _settled(container);
    expect(status.done, isFalse);
    expect(status.problem, LegacyImportProblem.locked);

    // Try again runs again and says why it still failed (never silent).
    final fetches = cloud.fetches;
    expect(await container.read(legacyImportProvider.notifier).retry(),
        isA<LegacyBackupUnreadable>());
    expect(cloud.fetches, fetches + 1);

    // A wrong password: still locked, and Skip is offered.
    expect(
        await container
            .read(legacyImportProvider.notifier)
            .retryWithPassword('not it at all'),
        isA<LegacyBackupUnreadable>());
    status = container.read(legacyImportProvider);
    expect(status.passwordTried, isTrue);

    // The old password opens it.
    expect(
        await container
            .read(legacyImportProvider.notifier)
            .retryWithPassword(_oldPassword),
        isNull);
    status = container.read(legacyImportProvider);
    expect(status.done, isTrue);
    expect(status.imported, 2);
    final vault = await container.read(fitnessVaultProvider.future);
    expect((await vault.fetchWorkouts()).single.data['type'], 'Running');
    // Done: the legacy key isn't kept any more.
    expect((container.read(vaultControllerProvider) as VaultUnlocked).legacyKey,
        isNull);
  });

  test('skipping what no password opens finishes the rest', () async {
    final container = _container(_Cloud([await _lockedBackup()]));
    await _unlock(container);
    await _settled(container);
    final controller = container.read(legacyImportProvider.notifier);
    await controller.retryWithPassword('not it at all');
    expect(await controller.skipUnreadable(), isNull);
    expect(container.read(legacyImportProvider).done, isTrue);
  });

  test('with no old salt, Skip still names the source that is locked',
      () async {
    // The fixture's key is the account key above; unlock with another so
    // the phone's old database stays locked.
    final dir = await Directory.systemTemp.createTemp('fitness-legacy');
    addTearDown(() => dir.delete(recursive: true));
    final path = '${dir.path}/vault.sqlite';
    await File('test/fixtures/legacy_vault.sqlite').copy(path);
    final container =
        _container(_Cloud(const [], salt: false), localPath: path);
    await container.read(vaultControllerProvider.notifier).unlock(
        Uint8List.fromList(List.filled(32, 5)), legacyDek: true);
    await _settled(container);
    final controller = container.read(legacyImportProvider.notifier);
    expect(
        await controller.retryWithPassword('anything'),
        isA<LegacyBackupUnreadable>()
            .having((e) => e.source, 'source', 'phone'));
    expect(await controller.skipUnreadable(), isNull);
    expect(container.read(legacyImportProvider).done, isTrue);
  });

  testWidgets('the banner asks for the old password and reports the result',
      (tester) async {
    late ProviderContainer container;
    await tester.runAsync(() async {
      container = _container(_Cloud([await _lockedBackup()]));
      await _unlock(container);
      await _settled(container);
    });
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        localizationsDelegates: const [AppL10n.delegate, ...ZtLanguages.delegates],
        supportedLocales: ZtLanguages.supported,
          home: Scaffold(body: Column(children: [LegacyImportBanner()]))),
    ));
    await tester.pump();
    expect(find.textContaining('locked with the password'), findsOneWidget);

    await tester.tap(find.text('Enter password'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), _oldPassword);
    await tester.tap(find.text('Unlock'));
    await tester.pump();
    // Busy while it works: the button is disabled, not silently ignored.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    for (var i = 0; i < 300 && !container.read(legacyImportProvider).done; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump(const Duration(milliseconds: 20));
    }
    await tester.pump();
    expect(container.read(legacyImportProvider).done, isTrue);
    expect(find.text('Your data from the previous version is here.'),
        findsOneWidget);
    expect(find.textContaining('locked with the password'), findsNothing);
    await tester.pump(const Duration(seconds: 10)); // sync timers
  });
}

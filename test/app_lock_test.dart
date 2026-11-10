import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthState, User;
import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zerotrust_fitness/app/auth_providers.dart';
import 'package:zerotrust_fitness/app/vault_providers.dart';
import 'package:zerotrust_fitness/features/legacy_import/legacy_fitness_import.dart';
import 'package:zerotrust_fitness/main.dart';

import 'fake_account_backend.dart';
import 'support.dart';

class _NoCloud implements LegacyCloudBackup {
  @override
  Future<List<String>> fetchAll() async => const [];
  @override
  Future<String?> legacySalt() async => null;
}

class _NoSecureStorage implements LegacySecureStorage {
  @override
  Future<List<int>?> storedDatabaseKey() async => null;
  @override
  Future<void> deleteLeftovers() async {}
}

final _user = User(
  id: 'user-1',
  appMetadata: const {},
  userMetadata: const {},
  aud: 'authenticated',
  createdAt: '2026-11-09T00:00:00Z',
  email: 'edo@example.com',
);

void main() {
  late ProviderContainer container;

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'has_seen_get_started_landing': true,
      'health_setup_offered': true,
    });
    container = ProviderContainer(overrides: [
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
      authStateChangesProvider
          .overrideWith((ref) => const Stream<AuthState>.empty()),
      currentUserProvider.overrideWith((ref) => _user),
      accountServiceProvider.overrideWith((ref) =>
          AccountService(FakeAccountBackend(onUserChanged: (_) {}))),
      legacyCloudBackupProvider.overrideWithValue(_NoCloud()),
      legacySecureStorageProvider.overrideWithValue(_NoSecureStorage()),
      legacyLocalVaultPathProvider
          .overrideWithValue(() async => '/nonexistent/vault.sqlite'),
    ]);
  });

  tearDown(() => container.dispose());

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 30; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  /// The test font is wider than real fonts, so some rows overflow here
  /// that don't on a phone; those aren't what this test is about.
  void ignoreOverflows() {
    final original = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains('overflowed')) return;
      original?.call(details);
    };
    addTearDown(() => FlutterError.onError = original);
  }

  testWidgets('auto-lock with a screen pushed returns to the lock screen cleanly',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    ignoreOverflows();
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const ZeroTrustFitnessApp(),
    ));
    await tester.runAsync(() => container
        .read(vaultControllerProvider.notifier)
        .unlock(Uint8List.fromList(List.generate(32, (i) => i))));
    await settle(tester);
    // Set here, not in runAsync, so the auto-lock timer runs on test time.
    container.read(ztAutoLockProvider.notifier).set(const Duration(minutes: 1));
    await tester.pump();
    expect(container.read(openFitnessVaultProvider), isNotNull);

    // A screen pushed over the dashboard, as manual entry or Settings are.
    tester.state<NavigatorState>(find.byType(Navigator).first).push(
          MaterialPageRoute<void>(
              builder: (_) => const Scaffold(body: Text('Editing'))),
        );
    await settle(tester);
    expect(find.text('Editing'), findsOneWidget);

    // Idle past the auto-lock time: it locks, the screen is gone, no errors.
    await tester.pump(const Duration(minutes: 1, seconds: 1));
    await settle(tester);
    expect(container.read(vaultControllerProvider), isA<VaultLocked>());
    expect(find.text('Editing'), findsNothing);
    expect(find.textContaining('is locked'), findsOneWidget);
    await tester.pump(const Duration(seconds: 10)); // retry timers
  });
}

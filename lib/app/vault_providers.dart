import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zerotrust_fitness/core/storage/fitness_vault.dart';
import 'package:zerotrust_fitness/features/legacy_import/legacy_fitness_import.dart';

/// The unlocked vault's Fitness data. Waits for the core's store and sync
/// engine, so saves go through sync. Errors with [VaultIsLocked] while
/// locked.
final fitnessVaultProvider = FutureProvider<FitnessVault>((ref) async {
  final unlocked = ref.watch(vaultControllerProvider
      .select((s) => s is VaultUnlocked ? s.appKey : null));
  if (unlocked == null) throw const VaultIsLocked();
  // Copy before any await: locking zeroes the vault's buffer.
  final appKey = Uint8List.fromList(unlocked);
  final idKey = await FitnessVault.deriveIdKey(appKey);
  appKey.fillRange(0, appKey.length, 0);
  ref.onDispose(() => idKey.fillRange(0, idKey.length, 0));

  final store = await ref.watch(ztLocalStoreProvider.future);
  await ref.watch(ztSyncEngineProvider.future);
  return FitnessVault(
    store: store,
    writer: SyncControllerWriter(ref.read(ztSyncControllerProvider.notifier)),
    idKey: idKey,
  );
});

/// The open vault, or null while locked or opening. Not `.value`, which
/// keeps the previous (closed) vault while it reopens.
final openFitnessVaultProvider = Provider<FitnessVault?>(
  (ref) => switch (ref.watch(fitnessVaultProvider)) {
    AsyncData(:final value) => value,
    _ => null,
  },
);

/// Bumps whenever the vault's items change, here or from sync, so screens
/// reload.
final fitnessVaultChangesProvider = StreamProvider<Set<String>>((ref) {
  final vault = ref.watch(openFitnessVaultProvider);
  return vault?.changes ?? const Stream.empty();
});

final legacyCloudBackupProvider =
    Provider<LegacyCloudBackup>((ref) => SupabaseLegacyCloudBackup());
final legacySecureStorageProvider = Provider<LegacySecureStorage>(
    (ref) => const FlutterLegacySecureStorage());
final legacyLocalVaultPathProvider =
    Provider<Future<String> Function()>((ref) => legacyLocalVaultPath);

/// Brings data from versions before the core into the synced store, once
/// per device: the phone's old encrypted database first, then the old cloud
/// backup. Returns how many items were added. Accounts created on the core
/// have nothing to import, and devices that already imported skip it.
///
/// Health Connect refreshes wait for this, so a day written from Health
/// Connect never hides the same day's older manual entries.
final legacyImportProvider = FutureProvider<int>((ref) async {
  final vault = await ref.watch(fitnessVaultProvider.future);
  // Make sure the sync controller has picked up the open engine.
  ref.read(ztSyncControllerProvider);
  final results =
      await ref.read(ztSyncControllerProvider.notifier).importLegacy(
            fitnessLegacyImporters(
              vault: vault,
              cloud: ref.read(legacyCloudBackupProvider),
              secureStorage: ref.read(legacySecureStorageProvider),
              localPath: ref.read(legacyLocalVaultPathProvider),
            ),
          );
  // Both imports are done: the old keys left in secure storage (one of
  // them the raw database key) aren't needed any more.
  await ref.read(legacySecureStorageProvider).deleteLeftovers();
  return results.fold<int>(0, (sum, r) => sum + r.imported);
});

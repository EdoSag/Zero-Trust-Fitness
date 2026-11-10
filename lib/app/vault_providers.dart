import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthException, PostgrestException;
import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zerotrust_fitness/core/storage/fitness_vault.dart';
import 'package:zerotrust_fitness/features/legacy_import/legacy_fitness_import.dart';

/// The unlocked vault's Fitness data. Waits for the core's store and sync
/// engine, so saves go through sync. Errors with [VaultIsLocked] while
/// locked.
final fitnessVaultProvider = FutureProvider<FitnessVault>((ref) async {
  final unlocked = ref.watch(
    vaultControllerProvider.select((s) => s is VaultUnlocked ? s.appKey : null),
  );
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

final legacyCloudBackupProvider = Provider<LegacyCloudBackup>(
  (ref) => SupabaseLegacyCloudBackup(),
);
final legacySecureStorageProvider = Provider<LegacySecureStorage>(
  (ref) => const FlutterLegacySecureStorage(),
);
final legacyLocalVaultPathProvider = Provider<Future<String> Function()>(
  (ref) => legacyLocalVaultPath,
);

/// Why bringing over old data stopped, for the banner.
enum LegacyImportProblem {
  /// The server couldn't be reached. Trying again later works.
  offline,

  /// Old data that none of the keys opens: needs the old password once.
  locked,

  /// Anything else.
  failed,
}

class LegacyImportStatus {
  const LegacyImportStatus({
    this.running = false,
    this.done = false,
    this.imported = 0,
    this.error,
    this.passwordTried = false,
  });

  /// An import is running (the first one after unlock, or a retry).
  final bool running;

  /// Every old source is brought over (or there was none).
  final bool done;

  /// Items the last finished run added.
  final int imported;

  /// Why the last run failed, if it did.
  final Object? error;

  /// The old password was typed this session and still didn't open it.
  final bool passwordTried;

  LegacyImportProblem? get problem => switch (error) {
    null => null,
    LegacyBackupUnreadable() => LegacyImportProblem.locked,
    SocketException() ||
    TimeoutException() ||
    HttpException() ||
    PostgrestException() ||
    AuthException() => LegacyImportProblem.offline,
    final Object e when '${e.runtimeType}' == 'ClientException' =>
      LegacyImportProblem.offline,
    _ => LegacyImportProblem.failed,
  };

  LegacyImportStatus copyWith({bool? running}) => LegacyImportStatus(
    running: running ?? this.running,
    done: done,
    imported: imported,
    error: error,
    passwordTried: passwordTried,
  );
}

/// Brings data from versions before the core into the synced store, once
/// per device: the phone's old encrypted database first, then the old cloud
/// backup. Accounts created on the core have nothing to import, and devices
/// that already imported skip it.
///
/// Runs in the background after each unlock; the dashboard doesn't wait for
/// it. Health Connect refreshes do (see `BottomNavShell.legacyImportPending`),
/// so a day written from Health Connect never hides the same day's older
/// manual entries.
final legacyImportProvider =
    NotifierProvider<LegacyImportController, LegacyImportStatus>(
      LegacyImportController.new,
    );

class LegacyImportController extends Notifier<LegacyImportStatus> {
  int _generation = 0;

  /// Keys derived from the old password, kept only until the import
  /// finishes or the vault locks.
  List<Uint8List> _extraKeys = const [];

  @override
  LegacyImportStatus build() {
    final vault = ref.watch(openFitnessVaultProvider);
    final generation = ++_generation;
    ref.onDispose(_forgetExtraKeys);
    if (vault == null) return const LegacyImportStatus();
    // Not during build: the run updates the state.
    scheduleMicrotask(() => _run(vault, generation));
    return const LegacyImportStatus(running: true);
  }

  /// Runs the import again. Returns why it failed, or null.
  Future<Object?> retry() async {
    final vault = ref.read(openFitnessVaultProvider);
    if (vault == null || state.running) return null;
    state = state.copyWith(running: true);
    return _run(vault, _generation, passwordTried: state.passwordTried);
  }

  /// Derives the keys earlier versions made from [password] and runs the
  /// import with them. Returns why it failed, or null.
  Future<Object?> retryWithPassword(String password) async {
    final vault = ref.read(openFitnessVaultProvider);
    if (vault == null || state.running) return null;
    final generation = _generation;
    state = state.copyWith(running: true);
    try {
      final salt = await ref.read(legacyCloudBackupProvider).legacySalt();
      if (salt == null) throw const LegacyBackupUnreadable('cloud');
      final keys = await legacyKeysFromPassword(password, salt);
      if (generation != _generation) return const VaultIsLocked();
      _forgetExtraKeys();
      _extraKeys = keys;
    } on Object catch (e) {
      if (generation == _generation) {
        state = LegacyImportStatus(error: e, passwordTried: true);
      }
      return e;
    }
    return _run(vault, generation, passwordTried: true);
  }

  /// Gives up on the old data no key opens (after the old password didn't
  /// open it either), so the rest is brought over and the banner goes. The
  /// old file stays on the phone.
  Future<Object?> skipUnreadable() async {
    final error = state.error;
    if (error is! LegacyBackupUnreadable || state.running) return null;
    final store = await ref.read(ztLocalStoreProvider.future);
    if (store case final LegacyImportLedger ledger) {
      await ledger.markLegacyImportDone(legacySourceFor(error.source));
    }
    return retry();
  }

  Future<Object?> _run(
    FitnessVault vault,
    int generation, {
    bool passwordTried = false,
  }) async {
    try {
      // Make sure the sync controller has picked up the open engine.
      ref.read(ztSyncControllerProvider);
      final results = await ref
          .read(ztSyncControllerProvider.notifier)
          .importLegacy(
            fitnessLegacyImporters(
              vault: vault,
              cloud: ref.read(legacyCloudBackupProvider),
              secureStorage: ref.read(legacySecureStorageProvider),
              localPath: ref.read(legacyLocalVaultPathProvider),
              extraKeys: _extraKeys,
            ),
          );
      // Both imports are done: the old keys left in secure storage (one of
      // them the raw database key) aren't needed any more.
      await ref.read(legacySecureStorageProvider).deleteLeftovers();
      _forgetExtraKeys();
      final imported = results.fold<int>(0, (sum, r) => sum + r.imported);
      if (generation == _generation) {
        state = LegacyImportStatus(done: true, imported: imported);
      }
      return null;
    } on Object catch (e) {
      if (e is! VaultIsLocked) debugPrint('Legacy import failed: $e');
      if (generation == _generation) {
        state = LegacyImportStatus(error: e, passwordTried: passwordTried);
      }
      return e;
    }
  }

  void _forgetExtraKeys() {
    for (final key in _extraKeys) {
      key.fillRange(0, key.length, 0);
    }
    _extraKeys = const [];
  }
}

import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zerotrust_fitness/core/storage/fitness_vault.dart';

/// Writes straight to [store], the way the sync engine's save does.
class StoreWriter implements FitnessItemWriter {
  StoreWriter(this.store);
  final LocalItemStore store;
  var _t = DateTime.utc(2026, 11, 1);
  final saved = <String>[];

  DateTime _next() => _t = _t.add(const Duration(seconds: 1));

  @override
  Future<void> save(String itemId, Map<String, Object?> json) async {
    saved.add(itemId);
    await store.put(
        LocalItem(itemId: itemId, updatedAt: _next(), json: json, dirty: true));
  }

  @override
  Future<void> delete(String itemId) => store.put(LocalItem(
      itemId: itemId, updatedAt: _next(), deleted: true, dirty: true));
}

FitnessVault testVault({LocalItemStore? store, List<int>? idKey}) {
  final s = store ?? InMemoryItemStore();
  return FitnessVault(
    store: s,
    writer: StoreWriter(s),
    idKey: idKey ?? List<int>.filled(32, 7),
  );
}

/// In-memory `vault_items` for one account, enough for end-to-end import
/// tests across devices.
class FakeSyncBackend implements SyncBackend {
  final Map<String, RemoteItem> rows = {};
  int _tick = 0;

  @override
  Future<List<RemoteItem>> pull(String app, {DateTime? since}) async => rows
      .values
      .where((r) => since == null || r.syncedAt!.isAfter(since))
      .toList()
    ..sort((a, b) => a.syncedAt!.compareTo(b.syncedAt!));

  @override
  Future<List<RemoteItem>> fetch(String app, Set<String> itemIds) async =>
      [for (final id in itemIds) if (rows[id] case final r?) r];

  @override
  Future<Set<String>> pushAll(String app, List<RemoteItem> items) async {
    final accepted = <String>{};
    for (final item in items) {
      final existing = rows[item.itemId];
      if (existing != null && item.updatedAt.isBefore(existing.updatedAt)) {
        continue;
      }
      rows[item.itemId] = RemoteItem(
        itemId: item.itemId,
        updatedAt: item.updatedAt,
        deviceId: item.deviceId,
        dataBlob: item.dataBlob,
        signature: item.signature,
        deleted: item.deleted,
        syncedAt: DateTime.now().toUtc().add(Duration(microseconds: ++_tick)),
      );
      accepted.add(item.itemId);
    }
    return accepted;
  }

  @override
  Future<void> Function() subscribe(
          String app, void Function(RemoteItem) onChange) =>
      () async {};
}

class MemoryLedger implements LegacyImportLedger {
  final Set<String> done = {};
  @override
  Future<bool> legacyImportDone(String source) async => done.contains(source);
  @override
  Future<void> markLegacyImportDone(String source) async => done.add(source);
}

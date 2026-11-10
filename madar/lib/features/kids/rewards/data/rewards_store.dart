import '../../../../core/db/repositories/key_value_repository.dart';
import '../domain/rewards_ledger.dart';

/// The little bit of storage the rewards need, so a test can kill the "phone"
/// between two writes.
abstract interface class KidsKeyStore {
  Future<Object?> read(String key);
  Future<void> write(String key, Object? json);
  Future<void> remove(String key);
}

/// The app's key/value repository (encrypted database on the device).
class KeyValueKidsStore implements KidsKeyStore {
  KeyValueKidsStore(this._kv);
  final KeyValueRepository _kv;

  @override
  Future<Object?> read(String key) => _kv.getJson(key);

  @override
  Future<void> write(String key, Object? json) => _kv.setJson(key, json);

  @override
  Future<void> remove(String key) => _kv.remove(key);
}

/// Keeps the ledger on the device with write-then-confirm:
///
/// 1. the new ledger goes to a pending slot,
/// 2. then to the real slot,
/// 3. then the pending slot is cleared.
///
/// A phone that dies after 1 or 2 loses nothing: [load] finds the pending
/// ledger, merges it in and finishes the job. A star is shown to the child
/// only after step 2 succeeded.
class RewardsStore {
  RewardsStore(this._store);

  final KidsKeyStore _store;

  static const String ledgerKey = 'kids.rewards.ledger';
  static const String pendingKey = 'kids.rewards.pending';

  Future<RewardsLedger> load() async {
    var main = RewardsLedger.fromJson(await _store.read(ledgerKey));
    final pendingJson = await _store.read(pendingKey);
    if (pendingJson != null) {
      final merged = main.union(RewardsLedger.fromJson(pendingJson));
      if (merged.count != main.count) {
        main = merged;
        await _store.write(ledgerKey, main.toJson());
      }
      await _store.remove(pendingKey);
    }
    return main;
  }

  /// Stores [next] (which must hold every star of the current ledger).
  Future<void> save(RewardsLedger next) async {
    final json = next.toJson();
    await _store.write(pendingKey, json);
    await _store.write(ledgerKey, json);
    await _store.remove(pendingKey);
  }
}

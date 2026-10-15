import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/db/encryption.dart' show SecretStore, FlutterSecretStore;
import '../domain/lock_record.dart';

/// Secure storage of the [LockRecord] (PIN hash, fingerprint switch,
/// wrong-PIN counter).
abstract interface class LockVault {
  /// The stored record ([LockRecord.empty] when none). Throws when secure
  /// storage itself fails.
  Future<LockRecord> read();

  Future<void> write(LockRecord record);

  Future<void> clear();
}

/// [LockVault] in the same Keystore-backed flutter_secure_storage namespace
/// as the database key. Android's "Clear data" removes both; the shell's
/// "start fresh" recovery only replaces the database key, so the PIN keeps
/// guarding the fresh database.
class SecretLockVault implements LockVault {
  SecretLockVault([SecretStore? store]) : _store = store ?? const FlutterSecretStore();

  /// Secure-storage entry holding the record.
  static const storageKey = 'madar.lock.v1';

  final SecretStore _store;

  @override
  Future<LockRecord> read() async => LockRecord.decode(await _store.read(storageKey));

  @override
  Future<void> write(LockRecord record) => _store.write(storageKey, record.encode());

  @override
  Future<void> clear() => _store.delete(storageKey);
}

/// In-memory [LockVault] for tests and previews.
class MemoryLockVault implements LockVault {
  MemoryLockVault([this.record = LockRecord.empty]);

  LockRecord record;

  /// When set, every call throws it (a broken Keystore).
  Object? failWith;
  int writes = 0;

  @override
  Future<LockRecord> read() async {
    if (failWith != null) throw failWith!;
    return record;
  }

  @override
  Future<void> write(LockRecord record) async {
    if (failWith != null) throw failWith!;
    writes++;
    this.record = record;
  }

  @override
  Future<void> clear() async {
    if (failWith != null) throw failWith!;
    record = LockRecord.empty;
  }
}

/// The synchronous [LockHint] (read on the first frame).
abstract interface class LockHintStore {
  LockHint read();

  Future<void> write(LockHint hint);
}

/// [LockHintStore] in SharedPreferences.
class PrefsLockHintStore implements LockHintStore {
  const PrefsLockHintStore(this._prefs);

  static const key = 'madar.lock.hint.v1';

  final SharedPreferences _prefs;

  @override
  LockHint read() => LockHint.decode(_prefs.getString(key));

  /// Throws when the platform reports the write failed (`false`): the
  /// controller relies on the hint never being weaker than the vault.
  @override
  Future<void> write(LockHint hint) async {
    final ok = hint == LockHint.none ? await _prefs.remove(key) : await _prefs.setString(key, hint.encode());
    if (!ok) throw StateError('Madar lock: the lock hint could not be saved');
  }
}

/// In-memory [LockHintStore] for tests and previews.
class MemoryLockHintStore implements LockHintStore {
  MemoryLockHintStore([this.hint = LockHint.none]);

  LockHint hint;

  @override
  LockHint read() => hint;

  @override
  Future<void> write(LockHint hint) async => this.hint = hint;
}

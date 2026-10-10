import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'db_errors.dart';

/// Minimal secret storage used by [DatabaseKeyStore]. Production uses
/// [FlutterSecretStore]; tests use [MemorySecretStore].
abstract interface class SecretStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);

  /// Erases every entry, even when the store can no longer decrypt them
  /// (its Keystore key was lost to a device transfer or a Keystore reset).
  /// Only used by "delete all data" after a normal [delete] failed.
  Future<void> forceClear();
}

/// Android Keystore-backed options for flutter_secure_storage v11.
///
/// v11 removed Jetpack `EncryptedSharedPreferences`; the default cipher pair is
/// AES-256-GCM data encryption with the AES key wrapped by an RSA-OAEP key that
/// never leaves the Android Keystore. On top of the defaults:
/// * `resetOnError: false` – the plugin must never silently erase the key
///   (that would make the database permanently unreadable); we surface the
///   error instead ([DatabaseKeyProblem.storageUnavailable]).
/// * `migrateWithBackup: true` – crash-safe migration if the plugin ever
///   changes algorithms.
/// * `storageNamespace` – isolates Madar's entries, Keystore aliases included.
const madarAndroidSecureOptions = AndroidOptions(
  resetOnError: false,
  migrateOnAlgorithmChange: true,
  migrateWithBackup: true,
  storageNamespace: 'madar_vault',
);

/// [SecretStore] over flutter_secure_storage.
class FlutterSecretStore implements SecretStore {
  const FlutterSecretStore([this.storage = const FlutterSecureStorage(aOptions: madarAndroidSecureOptions)]);

  final FlutterSecureStorage storage;

  @override
  Future<String?> read(String key) => storage.read(key: key);

  @override
  Future<void> write(String key, String value) => storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => storage.delete(key: key);

  /// The same namespace with `resetOnError: true`: the plugin may then drop
  /// entries it cannot decrypt instead of failing every call.
  @override
  Future<void> forceClear() =>
      FlutterSecureStorage(aOptions: madarAndroidSecureOptions.copyWith(resetOnError: true)).deleteAll();
}

/// In-memory [SecretStore] for tests and previews.
class MemorySecretStore implements SecretStore {
  MemorySecretStore([Map<String, String>? initial]) : values = {...?initial};

  final Map<String, String> values;

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<void> forceClear() async => values.clear();
}

/// Owns the 256-bit SQLCipher key of the Madar database.
///
/// The key is generated with [Random.secure] on first run, stored as 64 lower
/// case hex characters in secure storage and handed to `openMadarDatabase`.
class DatabaseKeyStore {
  DatabaseKeyStore({SecretStore? store, Random? random})
    : _store = store ?? const FlutterSecretStore(),
      _random = random ?? Random.secure();

  /// Secure-storage entry holding the key.
  static const storageKey = 'madar.db.key.v1';

  /// Key length in bytes (SQLCipher raw key).
  static const keyLength = 32;

  static final _hexKey = RegExp(r'^[0-9a-fA-F]{64}$');

  final SecretStore _store;
  final Random _random;
  Future<String>? _pending;

  /// Whether [key] is a valid raw key (64 hex characters).
  static bool isValidKey(String key) => _hexKey.hasMatch(key);

  /// A fresh random key as 64 lower-case hex characters.
  static String generateKey(Random random) {
    final buffer = StringBuffer();
    for (var i = 0; i < keyLength; i++) {
      buffer.write(random.nextInt(256).toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }

  /// The stored key, or null when none exists yet.
  ///
  /// Throws [DatabaseKeyException] when storage fails or holds a malformed
  /// value.
  Future<String?> readKey() async {
    final String? value;
    try {
      value = await _store.read(storageKey);
    } catch (e) {
      throw DatabaseKeyException(DatabaseKeyProblem.storageUnavailable, 'Reading the database key failed', e);
    }
    if (value == null) return null;
    if (!isValidKey(value)) {
      throw const DatabaseKeyException(DatabaseKeyProblem.malformed, 'Stored database key is not 64 hex characters');
    }
    return value;
  }

  /// Whether a key is stored.
  Future<bool> hasKey() async => await readKey() != null;

  /// Returns the stored key, generating and persisting one on first run.
  ///
  /// The new key is read back before it is returned, so a database is never
  /// created with a key that did not reach secure storage. Concurrent calls
  /// share one generation.
  Future<String> obtainKey() => _pending ??= _obtain().whenComplete(() => _pending = null);

  Future<String> _obtain() async {
    final existing = await readKey();
    if (existing != null) return existing;
    final key = generateKey(_random);
    try {
      await _store.write(storageKey, key);
    } catch (e) {
      throw DatabaseKeyException(DatabaseKeyProblem.storageUnavailable, 'Writing the database key failed', e);
    }
    final stored = await readKey();
    if (stored != key) {
      throw const DatabaseKeyException(
        DatabaseKeyProblem.storageUnavailable,
        'Secure storage did not persist the database key',
      );
    }
    return key;
  }

  /// Forgets the key ("delete all data"). The database file becomes
  /// unreadable, so delete it too (see `deleteMadarDatabaseFiles`).
  ///
  /// When secure storage cannot even delete (it can no longer decrypt its
  /// own entries), the whole store is force-cleared so a fresh key can be
  /// created; only when that fails too is [DatabaseKeyProblem.storageUnavailable]
  /// thrown.
  Future<void> wipe() async {
    try {
      await _store.delete(storageKey);
      return;
    } catch (_) {
      // Fall through to the forced clear.
    }
    try {
      await _store.forceClear();
    } catch (e) {
      throw DatabaseKeyException(DatabaseKeyProblem.storageUnavailable, 'Deleting the database key failed', e);
    }
  }
}

/// The app's key store. Override in tests with
/// `DatabaseKeyStore(store: MemorySecretStore())`.
final databaseKeyStoreProvider = Provider<DatabaseKeyStore>((ref) => DatabaseKeyStore());

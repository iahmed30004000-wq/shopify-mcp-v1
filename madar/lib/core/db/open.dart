import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart' show Database;

import 'database.dart';
import 'db_errors.dart';
import 'encryption.dart';

/// File name of the encrypted database inside the app-support directory.
const madarDatabaseFileName = 'madar.db';

/// `getApplicationSupportDirectory()/madar.db` (private to the app, excluded
/// from the user-visible documents folder).
Future<File> madarDatabaseFile() async {
  final dir = await getApplicationSupportDirectory();
  return File(p.join(dir.path, madarDatabaseFileName));
}

/// Opens (creating on first run) the SQLCipher-encrypted Madar database on a
/// background isolate.
///
/// [key] is the 64-hex-character raw key from [DatabaseKeyStore]. The setup
/// callback applies `PRAGMA key` before anything else touches the file, checks
/// `PRAGMA cipher_version` (must be non-empty on Android – throws
/// [CipherUnavailableError] otherwise; host tests use the system SQLite),
/// proves the key decrypts the file (throws [DatabaseKeyException] with
/// [DatabaseKeyProblem.wrongKey] otherwise) and then sets foreign keys and
/// WAL journaling. Migrations and first-run seeding ([seed], pass null to skip)
/// run before this future completes, so every error surfaces here.
Future<MadarDatabase> openMadarDatabase({
  required String key,
  File? file,
  SeedOptions? seed = const SeedOptions(),
  bool logStatements = false,
  @visibleForTesting bool? requireCipher,
}) async {
  if (!DatabaseKeyStore.isValidKey(key)) {
    throw const DatabaseKeyException(DatabaseKeyProblem.malformed, 'The database key must be 64 hex characters');
  }
  final target = file ?? await madarDatabaseFile();
  final executor = NativeDatabase.createInBackground(
    target,
    logStatements: logStatements,
    setup: _encryptedSetup(key, requireCipher ?? Platform.isAndroid),
  );
  return _openAndVerify(MadarDatabase(executor, seed: seed));
}

/// Unencrypted in-memory database for tests and previews, seeded by default.
/// Runs on the calling isolate; the result is ready to use.
Future<MadarDatabase> openInMemoryMadarDatabase({SeedOptions? seed = const SeedOptions(), bool logStatements = false}) {
  return _openAndVerify(
    MadarDatabase(
      NativeDatabase.memory(logStatements: logStatements, setup: _applyPragmas),
      seed: seed,
    ),
  );
}

/// Reads the key (creating it on first run) and opens the database.
///
/// If a database file exists but the key is gone, this throws
/// [DatabaseKeyException] with [DatabaseKeyProblem.missing] instead of
/// silently creating a new key – the UI should offer "delete all data".
Future<MadarDatabase> unlockMadarDatabase({
  required DatabaseKeyStore keyStore,
  File? file,
  SeedOptions? seed = const SeedOptions(),
}) async {
  final target = file ?? await madarDatabaseFile();
  final String? key;
  if (await target.exists()) {
    key = await keyStore.readKey();
    if (key == null) {
      throw const DatabaseKeyException(
        DatabaseKeyProblem.missing,
        'A database file exists but secure storage has no key for it',
      );
    }
  } else {
    key = await keyStore.obtainKey();
  }
  return openMadarDatabase(key: key, file: target, seed: seed);
}

/// Deletes the database file and its WAL/SHM/journal companions. Close the
/// database first.
Future<void> deleteMadarDatabaseFiles({File? file}) async {
  final target = file ?? await madarDatabaseFile();
  for (final suffix in const ['', '-wal', '-shm', '-journal']) {
    final f = File('${target.path}$suffix');
    if (await f.exists()) await f.delete();
  }
}

/// "Delete all data": removes the database files and forgets the key. The
/// database must already be closed.
Future<void> deleteAllMadarData({required DatabaseKeyStore keyStore, File? file}) async {
  await deleteMadarDatabaseFiles(file: file);
  await keyStore.wipe();
}

Future<MadarDatabase> _openAndVerify(MadarDatabase db) async {
  try {
    // Forces the lazy open: setup, migrations and seeding run now.
    await db.customSelect('SELECT 1').get();
    return db;
  } catch (e, st) {
    await db.close().catchError((Object _) {});
    Error.throwWithStackTrace(unwrapDatabaseError(e), st);
  }
}

/// Builds the setup callback run on the background isolate. It must capture
/// only sendable values ([hexKey], [requireCipher]).
DatabaseSetup _encryptedSetup(String hexKey, bool requireCipher) {
  return (Database db) {
    // Must be the very first statement on the connection.
    db.execute("PRAGMA key = \"x'$hexKey'\"");

    final result = db.select('PRAGMA cipher_version');
    final cipherVersion = result.isEmpty ? '' : '${result.first.columnAt(0) ?? ''}';
    if (requireCipher && cipherVersion.isEmpty) {
      throw CipherUnavailableError(
        'SQLCipher is not linked into this build (PRAGMA cipher_version returned nothing). '
        'Madar refuses to store data unencrypted; check the sqlite3 build hook '
        '(hooks.user_defines.sqlite3.source.android = sqlcipher).',
      );
    }

    try {
      // Reading the schema is the first real page read: with SQLCipher a
      // wrong key fails here with SQLITE_NOTADB.
      db.select('SELECT count(*) FROM sqlite_master');
    } on SqliteException catch (e) {
      throw DatabaseKeyException(
        DatabaseKeyProblem.wrongKey,
        'The key does not decrypt the database file, or the file is corrupted',
        '${e.resultCode}: ${e.message}',
      );
    }

    db.execute('PRAGMA journal_mode = WAL');
    _applyPragmas(db);
  };
}

void _applyPragmas(Database db) {
  db
    ..execute('PRAGMA foreign_keys = ON')
    ..execute('PRAGMA synchronous = NORMAL')
    ..execute('PRAGMA temp_store = MEMORY')
    ..execute('PRAGMA busy_timeout = 5000');
}

import 'package:drift/isolate.dart' show DriftRemoteException;

import '../i18n/gen/app_localizations.dart';

/// SQLCipher is not linked into the running app, so the database would be
/// stored in plain text. Madar refuses to open in that case.
///
/// It is a [StateError] because it signals a broken build (the `sqlite3`
/// build hook did not pick the `sqlcipher` source), not a user mistake.
class CipherUnavailableError extends StateError {
  CipherUnavailableError(super.message);
}

/// What went wrong with the database key.
enum DatabaseKeyProblem {
  /// A database file exists but secure storage holds no key for it.
  missing,

  /// The stored key is not 64 hexadecimal characters.
  malformed,

  /// The key does not decrypt the file (or the file is corrupted).
  wrongKey,

  /// Secure storage threw or did not persist the key.
  storageUnavailable,
}

/// Failure to obtain or use the database encryption key.
class DatabaseKeyException implements Exception {
  const DatabaseKeyException(this.problem, this.message, [this.cause]);

  final DatabaseKeyProblem problem;
  final String message;
  final Object? cause;

  @override
  String toString() => 'DatabaseKeyException(${problem.name}): $message${cause == null ? '' : ' – $cause'}';
}

/// Why a snapshot could not be restored.
enum SnapshotProblem {
  /// Not a Madar snapshot (wrong shape, missing `format` / `tables`).
  notASnapshot,

  /// Written by a newer schema than this app understands.
  newerSchema,

  /// Mentions a table this schema does not have.
  unknownTable,

  /// Mentions a column this schema does not have.
  unknownColumn,

  /// A value is not a JSON scalar (null, bool, number, string).
  invalidValue,

  /// SQLite rejected the data (constraint violation …); nothing was changed.
  rejected,
}

/// A snapshot failed validation or was rejected by the database. Restores are
/// transactional, so the current data is untouched when this is thrown.
class SnapshotException implements Exception {
  const SnapshotException(this.problem, this.message, [this.cause]);

  final SnapshotProblem problem;
  final String message;
  final Object? cause;

  @override
  String toString() => 'SnapshotException(${problem.name}): $message${cause == null ? '' : ' – $cause'}';
}

/// Unwraps errors that crossed the drift background isolate so callers can
/// match on Madar's own exception types.
Object unwrapDatabaseError(Object error) {
  var current = error;
  while (current is DriftRemoteException) {
    current = current.remoteCause;
  }
  return current;
}

/// Localised, user-facing description of a database-layer error.
String describeDatabaseError(L10n l10n, Object error) {
  final e = unwrapDatabaseError(error);
  return switch (e) {
    CipherUnavailableError() => l10n.dbErrorCipherUnavailable,
    DatabaseKeyException(problem: DatabaseKeyProblem.missing) => l10n.dbErrorKeyMissing,
    DatabaseKeyException(problem: DatabaseKeyProblem.malformed) => l10n.dbErrorKeyMalformed,
    DatabaseKeyException(problem: DatabaseKeyProblem.wrongKey) => l10n.dbErrorWrongKey,
    DatabaseKeyException(problem: DatabaseKeyProblem.storageUnavailable) => l10n.dbErrorKeyStorage,
    SnapshotException(problem: SnapshotProblem.newerSchema) => l10n.dbErrorSnapshotNewer,
    SnapshotException(problem: SnapshotProblem.rejected) => l10n.dbErrorSnapshotRejected,
    SnapshotException() => l10n.dbErrorSnapshotInvalid,
    _ => l10n.dbErrorUnknown,
  };
}

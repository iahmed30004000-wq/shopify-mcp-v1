/// The few Realtime Database calls online play makes, behind an interface:
/// [FirebaseRtdbClient] (firebase_database on a secondary Firebase app), and
/// an in-memory database with the security rules in the tests.
library;

import 'package:flutter/foundation.dart';

import 'online_config.dart';

/// A child of a listened list.
@immutable
final class RtdbChild {
  const RtdbChild(this.key, this.value);

  final String key;
  final Object? value;
}

enum RtdbErrorKind {
  /// The security rules refused the read / write.
  permissionDenied,

  /// No connection.
  network,

  /// Firebase refused the project settings.
  setup,

  /// Anonymous sign-in failed.
  signIn,

  /// The database lets any signed-in user read everything (the console's
  /// "test mode"): the online-play rules were never pasted. Nothing is
  /// written to such a database.
  rulesOpen,

  unknown,
}

final class RtdbException implements Exception {
  const RtdbException(this.kind, [this.message]);

  final RtdbErrorKind kind;
  final String? message;

  @override
  String toString() => 'RtdbException(${kind.name}${message == null ? '' : ': $message'})';
}

/// The server's clock in a write (Firebase's `ServerValue.timestamp`).
const Map<String, String> rtdbServerTimestamp = {'.sv': 'timestamp'};

/// One signed-in connection to the user's database.
abstract class RtdbClient {
  /// The anonymous user's id (after [signIn]).
  String? get uid;

  /// Signs in anonymously (once); the uid.
  Future<String> signIn();

  /// Whether the database connection is up (`.info/connected`).
  ValueListenable<bool> get connected;

  /// The server's clock (local clock + `.info/serverTimeOffset`).
  DateTime serverNow();

  Future<Object?> read(String path);

  Future<void> set(String path, Object? value);

  /// A multi-path update relative to [path].
  Future<void> update(String path, Map<String, Object?> values);

  /// Appends [value] under a new chronological key; the key.
  Future<String> push(String path, Object? value);

  Future<void> remove(String path);

  /// Existing children, then each new one.
  Stream<RtdbChild> childAdded(String path);

  /// The value now and after every change.
  Stream<Object?> watch(String path);

  /// Drops the connection (listeners end).
  Future<void> close();
}

/// Opens a client for a config (Firebase in production).
typedef RtdbClientFactory = Future<RtdbClient> Function(OnlineConfig config);

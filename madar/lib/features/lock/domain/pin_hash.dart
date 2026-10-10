import 'dart:convert';
import 'dart:isolate';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'sha256.dart';

/// Rules for the app-lock PIN: 4–8 Western digits (the keypad converts
/// Arabic-Indic input before it gets here).
abstract final class PinRules {
  static const int minLength = 4;
  static const int maxLength = 8;

  static final RegExp _digits = RegExp(r'^[0-9]+$');

  /// Whether [pin] is an acceptable PIN.
  static bool isValid(String pin) => pin.length >= minLength && pin.length <= maxLength && _digits.hasMatch(pin);

  /// Whether [pin] is so guessable that the setup flow warns about it
  /// (all one digit, or a straight ascending / descending run).
  static bool isWeak(String pin) {
    if (!isValid(pin)) return true;
    final d = pin.codeUnits.map((c) => c - 0x30).toList();
    if (d.every((x) => x == d.first)) return true;
    var up = true, down = true;
    for (var i = 1; i < d.length; i++) {
      if (d[i] != (d[i - 1] + 1) % 10) up = false;
      if (d[i] != (d[i - 1] + 9) % 10) down = false;
    }
    return up || down;
  }
}

/// A salted PBKDF2-HMAC-SHA256 hash of the PIN – the only form in which the
/// PIN is ever stored (in flutter_secure_storage, never in plain text).
@immutable
class PinHash {
  const PinHash({required this.salt, required this.hash, required this.iterations, required this.length});

  static const String algorithm = 'pbkdf2-hmac-sha256';

  final Uint8List salt;
  final Uint8List hash;
  final int iterations;

  /// Number of digits (the lock screen shows that many dots and checks the
  /// PIN as soon as it is complete).
  final int length;

  Map<String, Object?> toJson() => {
    'alg': algorithm,
    'it': iterations,
    'salt': base64Encode(salt),
    'hash': base64Encode(hash),
    'len': length,
  };

  /// Parses [toJson]'s output; null when it is malformed.
  static PinHash? fromJson(Object? json) {
    if (json is! Map) return null;
    try {
      if (json['alg'] != algorithm) return null;
      final it = json['it'];
      final len = json['len'];
      final salt = base64Decode(json['salt'] as String);
      final hash = base64Decode(json['hash'] as String);
      if (it is! int || it < 1 || len is! int || len < PinRules.minLength || len > PinRules.maxLength) return null;
      if (salt.length < 8 || hash.length != Sha256.digestSize) return null;
      return PinHash(salt: salt, hash: hash, iterations: it, length: len);
    } catch (_) {
      return null;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is PinHash &&
      other.iterations == iterations &&
      other.length == length &&
      listEquals(other.salt, salt) &&
      listEquals(other.hash, hash);

  @override
  int get hashCode => Object.hash(iterations, length, Object.hashAll(salt), Object.hashAll(hash));
}

/// Runs PBKDF2 somewhere (a background isolate in the app, inline in tests).
typedef Pbkdf2Runner = Future<Uint8List> Function({
  required List<int> password,
  required List<int> salt,
  required int iterations,
});

/// Hashes and verifies PINs.
///
/// [iterations] defaults to [defaultIterations] (≥ 100 000, ≈ 0.1 s on a
/// desktop core and a few hundred milliseconds on a phone). The derivation
/// runs on a background isolate so the lock screen keeps animating.
class PinHasher {
  PinHasher({this.iterations = defaultIterations, Random? random, Pbkdf2Runner? runner})
    : _random = random ?? Random.secure(),
      _run = runner ?? isolateRunner;

  static const int defaultIterations = 120000;
  static const int saltLength = 16;

  final int iterations;
  final Random _random;
  final Pbkdf2Runner _run;

  /// PBKDF2 on a short-lived background isolate.
  static Future<Uint8List> isolateRunner({
    required List<int> password,
    required List<int> salt,
    required int iterations,
  }) {
    final p = List<int>.of(password), s = List<int>.of(salt);
    return Isolate.run(() => Pbkdf2Sha256.derive(password: p, salt: s, iterations: iterations));
  }

  /// PBKDF2 on the calling isolate (tests).
  static Future<Uint8List> inlineRunner({
    required List<int> password,
    required List<int> salt,
    required int iterations,
  }) async => Pbkdf2Sha256.derive(password: password, salt: salt, iterations: iterations);

  /// A fresh salted hash of [pin]. Throws [ArgumentError] for an invalid PIN.
  Future<PinHash> hash(String pin) async {
    if (!PinRules.isValid(pin)) throw ArgumentError.value('•' * pin.length, 'pin', 'must be 4–8 digits');
    final salt = Uint8List(saltLength);
    for (var i = 0; i < saltLength; i++) {
      salt[i] = _random.nextInt(256);
    }
    final h = await _run(password: utf8.encode(pin), salt: salt, iterations: iterations);
    return PinHash(salt: salt, hash: h, iterations: iterations, length: pin.length);
  }

  /// Whether [pin] matches [stored] (constant-time comparison).
  Future<bool> verify(String pin, PinHash stored) async {
    if (!PinRules.isValid(pin) || pin.length != stored.length) {
      // Same cost as a real check, so timing never tells the length apart.
      await _run(password: utf8.encode(pin), salt: stored.salt, iterations: stored.iterations);
      return false;
    }
    final h = await _run(password: utf8.encode(pin), salt: stored.salt, iterations: stored.iterations);
    return constantTimeEquals(h, stored.hash);
  }

  /// Whether a hash made with fewer iterations than today's default should
  /// be refreshed after a successful check.
  bool needsRehash(PinHash stored) => stored.iterations < iterations;

  /// Compares two byte lists without an early exit.
  static bool constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }
}

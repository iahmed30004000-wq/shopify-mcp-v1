import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'pin_hash.dart';

/// Wrong-PIN back-off: the first [freeAttempts] − 1 mistakes cost nothing;
/// from the [freeAttempts]-th wrong PIN on, each one locks the keypad for
/// [base] × 2^(n − [freeAttempts]) (30 s, 1 min, 2 min, 4 min …), capped
/// at [max]. A successful unlock (PIN or biometrics) resets the count.
abstract final class PinBackoff {
  static const int freeAttempts = 5;
  static const Duration base = Duration(seconds: 30);
  static const Duration max = Duration(hours: 1);

  /// The lockout that follows the [failures]-th consecutive wrong PIN.
  static Duration lockoutAfter(int failures) {
    if (failures < freeAttempts) return Duration.zero;
    final exponent = math.min(failures - freeAttempts, 20);
    final ms = base.inMilliseconds * math.pow(2, exponent);
    return ms >= max.inMilliseconds ? max : Duration(milliseconds: ms.toInt());
  }

  /// Wrong PINs still allowed before the next lockout (0 once locking).
  static int remainingBeforeLockout(int failures) => math.max(0, freeAttempts - failures);
}

/// Everything the app lock keeps in secure storage: the PIN hash, whether
/// fingerprint unlock is on, and the wrong-PIN counter with its lockout
/// (kept there so closing the app never resets the back-off).
@immutable
class LockRecord {
  const LockRecord({this.pin, this.biometrics = false, this.failures = 0, this.lockedUntil});

  static const LockRecord empty = LockRecord();

  final PinHash? pin;
  final bool biometrics;
  final int failures;
  final DateTime? lockedUntil;

  bool get hasPin => pin != null;

  /// Whether the keypad is locked at [now].
  bool lockedOutAt(DateTime now) => lockedUntil != null && now.isBefore(lockedUntil!);

  /// Time left of the lockout at [now].
  Duration remainingLockout(DateTime now) {
    final until = lockedUntil;
    if (until == null || !now.isBefore(until)) return Duration.zero;
    return until.difference(now);
  }

  /// The record after a wrong PIN at [now].
  LockRecord afterFailure(DateTime now) {
    final n = failures + 1;
    final wait = PinBackoff.lockoutAfter(n);
    return copyWith(
      failures: n,
      lockedUntil: wait > Duration.zero ? now.add(wait) : null,
      clearLockedUntil: wait == Duration.zero,
    );
  }

  /// The record after a successful unlock.
  LockRecord afterSuccess() => copyWith(failures: 0, clearLockedUntil: true);

  /// The record with a lockout the wall clock can't stretch. A lockout that
  /// reaches further than its own back-off step means the clock was turned
  /// back (or corrected by the network) after it began: it restarts at
  /// [now] with that step instead of keeping the keypad closed for hours or
  /// days. A lockout without enough failures behind it is dropped.
  LockRecord normalizedAt(DateTime now) {
    final until = lockedUntil;
    if (until == null) return this;
    final step = PinBackoff.lockoutAfter(failures);
    if (step == Duration.zero) return copyWith(clearLockedUntil: true);
    if (until.difference(now) > step) return copyWith(lockedUntil: now.add(step));
    return this;
  }

  LockRecord copyWith({
    PinHash? pin,
    bool clearPin = false,
    bool? biometrics,
    int? failures,
    DateTime? lockedUntil,
    bool clearLockedUntil = false,
  }) => LockRecord(
    pin: clearPin ? null : (pin ?? this.pin),
    biometrics: biometrics ?? this.biometrics,
    failures: failures ?? this.failures,
    lockedUntil: clearLockedUntil ? null : (lockedUntil ?? this.lockedUntil),
  );

  String encode() => jsonEncode({
    'v': 1,
    'pin': pin?.toJson(),
    'bio': biometrics,
    'fails': failures,
    'until': lockedUntil?.millisecondsSinceEpoch,
  });

  /// Parses [encode]'s output. A missing or unreadable entry is [empty]; a
  /// damaged PIN hash is dropped (the lock then disarms rather than locking
  /// the owner out for good).
  static LockRecord decode(String? raw) {
    if (raw == null || raw.isEmpty) return empty;
    try {
      final j = jsonDecode(raw);
      if (j is! Map) return empty;
      final until = j['until'];
      final fails = j['fails'];
      return LockRecord(
        pin: PinHash.fromJson(j['pin']),
        biometrics: j['bio'] == true,
        failures: fails is int && fails > 0 ? fails : 0,
        lockedUntil: until is int ? DateTime.fromMillisecondsSinceEpoch(until) : null,
      );
    } catch (_) {
      return empty;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is LockRecord &&
      other.pin == pin &&
      other.biometrics == biometrics &&
      other.failures == failures &&
      other.lockedUntil == lockedUntil;

  @override
  int get hashCode => Object.hash(pin, biometrics, failures, lockedUntil);
}

/// The non-secret "is a lock configured?" hint kept in SharedPreferences so
/// the very first frame can already be covered (secure storage is
/// asynchronous). Secure storage stays the source of truth: the controller
/// reconciles the hint once the record is read.
@immutable
class LockHint {
  const LockHint({this.pin = false, this.biometrics = false});

  static const LockHint none = LockHint();

  final bool pin;
  final bool biometrics;

  String encode() => jsonEncode({'pin': pin, 'bio': biometrics});

  static LockHint decode(String? raw) {
    if (raw == null) return none;
    try {
      final j = jsonDecode(raw);
      if (j is! Map) return none;
      return LockHint(pin: j['pin'] == true, biometrics: j['bio'] == true);
    } catch (_) {
      return none;
    }
  }

  static LockHint of(LockRecord r) => LockHint(pin: r.hasPin, biometrics: r.biometrics && r.hasPin);

  @override
  bool operator ==(Object other) => other is LockHint && other.pin == pin && other.biometrics == biometrics;

  @override
  int get hashCode => Object.hash(pin, biometrics);
}

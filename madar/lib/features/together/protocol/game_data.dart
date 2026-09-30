/// Game data – the only thing that may ever travel between devices.
///
/// [GameData] is an immutable JSON tree that has passed [GameDataPolicy]:
/// plain JSON values only, bounded in size and depth, keys that look like
/// game fields (and never like personal data), strings that are short and
/// never look like an e-mail address, a phone / account number or a link.
/// A game can narrow the policy further with an explicit key whitelist.
library;

import 'dart:convert';

import '../../../core/import/sha256.dart';

/// Why data was refused.
enum TogetherRejection {
  /// Not JSON at all (a Dart object, a NaN, a non-string map key…).
  notJson,

  /// A key that names personal data (name, phone, health, money…).
  forbiddenKey,

  /// A key outside the game's whitelist.
  keyNotAllowed,

  /// A key that is not a plain identifier.
  invalidKey,

  /// A string longer than the policy allows.
  stringTooLong,

  /// A string that looks like personal data (e-mail, number, link).
  personalText,
  tooDeep,
  tooLarge,
  numberOutOfRange,

  /// An envelope or body field that the protocol does not define.
  unknownField,
  missingField,
  wrongType,

  /// Not a Together envelope (wrong magic, unknown kind).
  notAnEnvelope,

  /// A protocol version this build does not speak.
  unsupportedVersion,
}

/// Thrown when anything but whitelisted game data would be sent, or is
/// received.
final class TogetherDataRejected implements Exception {
  const TogetherDataRejected(this.reason, [this.path = '']);

  final TogetherRejection reason;

  /// Where in the data (e.g. `b.m.hand[2]`).
  final String path;

  @override
  String toString() => 'TogetherDataRejected(${reason.name}${path.isEmpty ? '' : ' at $path'})';
}

/// What game data may contain.
final class GameDataPolicy {
  const GameDataPolicy({
    this.allowedKeys,
    this.maxStringLength = 128,
    this.maxDepth = 12,
    this.maxNodes = 20000,
    this.maxBytes = 128 * 1024,
  });

  static const GameDataPolicy standard = GameDataPolicy();

  /// When set, every map key anywhere in the data must be one of these (the
  /// game's own field names). The denylist applies either way.
  final Set<String>? allowedKeys;
  final int maxStringLength;
  final int maxDepth;
  final int maxNodes;

  /// Encoded (UTF-8 JSON) size.
  final int maxBytes;

  /// Largest integer magnitude (exact in a double; same on every platform).
  static const int maxSafeInt = 9007199254740991;

  /// Key words that unambiguously name personal data. A key is split into
  /// words (camelCase, snake_case, digits) and refused when any word is here
  /// – even if a game whitelists it. Words that games use for their own
  /// state (health points, in-game coins, weight in physics, contacts in
  /// collisions…) are deliberately absent: the per-game whitelist
  /// ([allowedKeys]) is the strict filter, this list is the backstop.
  static const Set<String> forbiddenWords = {
    // identity
    'name', 'names', 'firstname', 'lastname', 'surname', 'nickname', 'fullname', 'username', 'email',
    'phone', 'mobile', 'address', 'birthday', 'birthdate', 'dob', 'avatar', 'profile', 'photo', 'selfie',
    // location
    'location', 'latitude', 'longitude', 'lat', 'lng', 'gps',
    // secrets
    'password', 'passcode', 'passphrase', 'pin', 'otp', 'secret', 'credential', 'credentials', 'cvv',
    // health records
    'medical', 'medication', 'medications', 'medicine', 'dose', 'doses', 'diagnosis', 'symptom',
    'symptoms', 'glucose', 'cholesterol', 'bmi', 'allergy', 'allergies', 'doctor', 'appointment',
    'blood', 'vitals', 'illness', 'disease', 'pregnancy',
    // money records
    'iban', 'bank', 'salary', 'wallet', 'wallets', 'transaction', 'transactions', 'income', 'expense',
    'expenses', 'debt', 'debts', 'loan', 'mortgage', 'invoice', 'payment', 'account',
    // private writing & faith records
    'diary', 'journal', 'memo', 'prayer', 'prayers', 'worry', 'worries',
  };

  static final RegExp _keyPattern = RegExp(r'^[A-Za-z_][A-Za-z0-9_]{0,39}$');
  static final RegExp _wordSplit = RegExp(r'[A-Z]?[a-z]+|[A-Z]+(?![a-z])|[0-9]+');
  static final RegExp _control = RegExp('[\u0000-\u001F\u007F‪-‮⁦-⁩]');
  static final RegExp _email = RegExp(r'\S+@\S+\.\S+');
  static final RegExp _link = RegExp(r'(://|www\.|\.com\b|\.net\b|\.org\b)', caseSensitive: false);
  static final RegExp _separators = RegExp(r'[\s\-().+]');
  static final RegExp _digitRun = RegExp('[0-9٠-٩۰-۹]{7,}');

  /// The words of a key (lower case).
  static List<String> keyWords(String key) => [for (final m in _wordSplit.allMatches(key)) m[0]!.toLowerCase()];

  /// Checks [key]; throws [TogetherDataRejected] when it is not allowed.
  void checkKey(String key, String path) {
    if (!_keyPattern.hasMatch(key)) throw TogetherDataRejected(TogetherRejection.invalidKey, path);
    if (keyWords(key).any(forbiddenWords.contains) || forbiddenWords.contains(key.toLowerCase())) {
      throw TogetherDataRejected(TogetherRejection.forbiddenKey, path);
    }
    final allowed = allowedKeys;
    if (allowed != null && !allowed.contains(key)) throw TogetherDataRejected(TogetherRejection.keyNotAllowed, path);
  }

  /// Checks a string value.
  void checkString(String s, String path) {
    if (s.length > maxStringLength) throw TogetherDataRejected(TogetherRejection.stringTooLong, path);
    if (_control.hasMatch(s)) throw TogetherDataRejected(TogetherRejection.personalText, path);
    if (_email.hasMatch(s) || _link.hasMatch(s)) throw TogetherDataRejected(TogetherRejection.personalText, path);
    // Phone / account / card numbers, however they are spaced.
    if (_digitRun.hasMatch(s.replaceAll(_separators, ''))) {
      throw TogetherDataRejected(TogetherRejection.personalText, path);
    }
  }

  /// A deep, unmodifiable copy of [json] that passes this policy; throws
  /// [TogetherDataRejected] otherwise.
  Object? sanitize(Object? json, {String path = ''}) {
    var nodes = 0;
    Object? walk(Object? v, String at, int depth) {
      if (++nodes > maxNodes) throw TogetherDataRejected(TogetherRejection.tooLarge, at);
      if (depth > maxDepth) throw TogetherDataRejected(TogetherRejection.tooDeep, at);
      switch (v) {
        case null:
        case bool():
          return v;
        case int():
          if (v.abs() > maxSafeInt) throw TogetherDataRejected(TogetherRejection.numberOutOfRange, at);
          return v;
        case double():
          if (!v.isFinite || v.abs() > maxSafeInt) {
            throw TogetherDataRejected(TogetherRejection.numberOutOfRange, at);
          }
          return v;
        case String():
          checkString(v, at);
          return v;
        case List():
          return List<Object?>.unmodifiable([for (var i = 0; i < v.length; i++) walk(v[i], '$at[$i]', depth + 1)]);
        case Map():
          final out = <String, Object?>{};
          for (final e in v.entries) {
            final k = e.key;
            if (k is! String) throw TogetherDataRejected(TogetherRejection.notJson, at);
            final p = at.isEmpty ? k : '$at.$k';
            checkKey(k, p);
            out[k] = walk(e.value, p, depth + 1);
          }
          return Map<String, Object?>.unmodifiable(out);
        default:
          // DateTime, Duration, records, custom classes, Sets, typed data…
          throw TogetherDataRejected(TogetherRejection.notJson, at);
      }
    }

    final copy = walk(json, path, 0);
    if (utf8.encode(jsonEncode(copy)).length > maxBytes) throw TogetherDataRejected(TogetherRejection.tooLarge, path);
    return copy;
  }
}

/// Validated, immutable game data (a state, a move, an input, a config).
final class GameData {
  const GameData._(this.value);

  /// Validates [json] against [policy] (throws [TogetherDataRejected]).
  factory GameData(Object? json, {GameDataPolicy policy = GameDataPolicy.standard}) =>
      GameData._(policy.sanitize(json));

  static const GameData empty = GameData._(<String, Object?>{});

  /// The JSON tree (unmodifiable).
  final Object? value;

  /// [value] as a map (throws when it is not one).
  Map<String, Object?> get map => value! as Map<String, Object?>;

  /// Stable hash of the data ([StateHash]).
  String get hash => StateHash.of(value);

  /// Canonical JSON (sorted keys, normalised numbers).
  String get canonical => StateHash.canonical(value);

  @override
  bool operator ==(Object other) => other is GameData && other.canonical == canonical;

  @override
  int get hashCode => canonical.hashCode;

  @override
  String toString() => 'GameData($canonical)';
}

/// Canonical JSON and its hash: equal game states give equal hashes on both
/// devices, whatever the map order or number representation.
abstract final class StateHash {
  /// 16 lower-case hex digits: the first 64 bits of SHA-256 of [canonical].
  static String of(Object? json) => Sha256.hex(utf8.encode(canonical(json))).substring(0, 16);

  static final RegExp pattern = RegExp(r'^[0-9a-f]{16}$');

  static String canonical(Object? json) {
    final b = StringBuffer();
    void write(Object? v) {
      switch (v) {
        case null:
          b.write('null');
        case bool():
          b.write(v ? 'true' : 'false');
        case int():
          b.write(v);
        case double():
          // 3.0 and 3 are the same number on the wire.
          if (v == v.truncateToDouble() && v.abs() <= GameDataPolicy.maxSafeInt) {
            b.write(v.toInt());
          } else {
            b.write(v.toString());
          }
        case String():
          b.write(jsonEncode(v));
        case List():
          b.write('[');
          for (var i = 0; i < v.length; i++) {
            if (i > 0) b.write(',');
            write(v[i]);
          }
          b.write(']');
        case Map():
          final keys = [for (final k in v.keys) k.toString()]..sort();
          b.write('{');
          for (var i = 0; i < keys.length; i++) {
            if (i > 0) b.write(',');
            b
              ..write(jsonEncode(keys[i]))
              ..write(':');
            write(v[keys[i]]);
          }
          b.write('}');
        default:
          throw const TogetherDataRejected(TogetherRejection.notJson);
      }
    }

    write(json);
    return b.toString();
  }
}

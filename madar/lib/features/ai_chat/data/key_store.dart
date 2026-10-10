/// The user's API keys: only in the platform's encrypted secure storage
/// (Android Keystore), never in the database, settings, logs, exports or
/// backups. The rest of the app only ever sees the last four characters.
library;

import '../../../core/db/encryption.dart' show SecretStore;
import '../domain/ai_models.dart';

/// Why a pasted key can't be saved.
enum AiKeyProblem {
  empty,
  tooShort,
  spaces,

  /// A character no key has (not printable ASCII) – HTTP can't carry it.
  invalidChars,

  /// Clearly the other service's key: saving it would send it to the wrong
  /// company.
  wrongProvider,
}

class AiKeyStore {
  AiKeyStore(this._store);

  final SecretStore _store;

  /// Secure-storage entry of [p]'s key.
  static String storageKey(AiProviderId p) => 'madar.ai.${p.name}.apiKey.v1';

  /// Invisible characters a copy from a web page or an Arabic keyboard
  /// often brings along: direction marks and isolates, zero-width
  /// characters, soft hyphens and byte-order marks.
  static final RegExp _invisible = RegExp('[\u00AD\u061C\u180E\u200B-\u200F\u202A-\u202E\u2060-\u2064\u2066-\u2069\uFEFF]');

  /// Printable ASCII without spaces: every character a key can have.
  static final RegExp _keyChars = RegExp(r'^[\x21-\x7E]+$');

  /// Removes what a paste often brings along: spaces, line breaks,
  /// invisible marks, quotes, a "Bearer " prefix or an
  /// `ANTHROPIC_API_KEY=` assignment.
  static String clean(String raw) {
    var k = raw.replaceAll(_invisible, '').trim();
    final eq = RegExp(r'^[A-Z_]+\s*=\s*').firstMatch(k);
    if (eq != null) k = k.substring(eq.end);
    if (k.toLowerCase().startsWith('bearer ')) k = k.substring(7);
    k = k.trim();
    if (k.length >= 2 && (k.startsWith('"') && k.endsWith('"') || k.startsWith("'") && k.endsWith("'"))) {
      k = k.substring(1, k.length - 1).trim();
    }
    return k;
  }

  /// A problem with [key] for [p] (null = looks fine). Only obvious
  /// mistakes are caught; the service has the final word ("Test key").
  static AiKeyProblem? check(AiProviderId p, String key) {
    if (key.isEmpty) return AiKeyProblem.empty;
    if (RegExp(r'\s').hasMatch(key)) return AiKeyProblem.spaces;
    if (!_keyChars.hasMatch(key)) return AiKeyProblem.invalidChars;
    if (key.length < 20) return AiKeyProblem.tooShort;
    if (looksLikeOther(p, key)) return AiKeyProblem.wrongProvider;
    return null;
  }

  /// Whether [key] is clearly a key of the service other than [p]
  /// (Anthropic keys start `sk-ant-`, OpenAI keys `sk-` without it).
  static bool looksLikeOther(AiProviderId p, String key) {
    final anthropicLike = key.startsWith('sk-ant-');
    return switch (p) {
      AiProviderId.openai => anthropicLike,
      AiProviderId.anthropic => key.startsWith('sk-') && !anthropicLike,
    };
  }

  /// The service [key] clearly belongs to when it is not [p] (for the
  /// "this looks like a … key" message).
  static AiProviderId? otherOwner(AiProviderId p, String key) =>
      looksLikeOther(p, key) ? AiProviderId.values.firstWhere((x) => x != p) : null;

  /// Last check before [key] goes out to [p]'s service: HTTP can carry it
  /// and it isn't the other service's key. Checked on every call, so a key
  /// saved by an older version can't leak either.
  static bool sendable(AiProviderId p, String key) => _keyChars.hasMatch(key) && !looksLikeOther(p, key);

  /// `••••abcd`: the only form a key is ever shown in.
  static String mask(String key) => key.length <= 4 ? '••••' : '••••${key.substring(key.length - 4)}';

  /// `••••abcd` from a hint (the last four characters), `••••` without.
  static String maskHint(String? hint) => '••••${hint ?? ''}';

  /// The last four characters (null when no key).
  static String? hintOf(String? key) => key == null || key.isEmpty
      ? null
      : key.length <= 4
      ? key
      : key.substring(key.length - 4);

  Future<String?> read(AiProviderId p) async {
    final v = await _store.read(storageKey(p));
    return v == null || v.isEmpty ? null : v;
  }

  Future<bool> has(AiProviderId p) async => await read(p) != null;

  /// Last four characters of [p]'s key, or null.
  Future<String?> hint(AiProviderId p) async => hintOf(await read(p));

  /// Saves [raw] (cleaned) for [p]; throws [ArgumentError] (without the
  /// key in its text) when [check] finds a problem – including the other
  /// service's key, which would otherwise be sent to the wrong company.
  Future<void> save(AiProviderId p, String raw) async {
    final key = clean(raw);
    final problem = check(p, key);
    if (problem != null) throw ArgumentError.value('••••', 'key', problem.name);
    await _store.write(storageKey(p), key);
  }

  Future<void> delete(AiProviderId p) => _store.delete(storageKey(p));

  /// Removes every AI key (for "delete all data").
  Future<void> deleteAll() async {
    for (final p in AiProviderId.values) {
      await delete(p);
    }
  }
}

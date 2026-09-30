/// The user's API keys: only in the platform's encrypted secure storage
/// (Android Keystore), never in the database, settings, logs, exports or
/// backups. The rest of the app only ever sees the last four characters.
library;

import '../../../core/db/encryption.dart' show SecretStore;
import '../domain/ai_models.dart';

/// Why a pasted key can't be saved.
enum AiKeyProblem { empty, tooShort, spaces, wrongProvider }

class AiKeyStore {
  AiKeyStore(this._store);

  final SecretStore _store;

  /// Secure-storage entry of [p]'s key.
  static String storageKey(AiProviderId p) => 'madar.ai.${p.name}.apiKey.v1';

  /// Removes what a paste often brings along: spaces, line breaks,
  /// quotes, a "Bearer " prefix or an `ANTHROPIC_API_KEY=` assignment.
  static String clean(String raw) {
    var k = raw.trim();
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
    if (key.length < 20) return AiKeyProblem.tooShort;
    final anthropicLike = key.startsWith('sk-ant-');
    if (p == AiProviderId.openai && anthropicLike) return AiKeyProblem.wrongProvider;
    if (p == AiProviderId.anthropic && key.startsWith('sk-') && !anthropicLike) return AiKeyProblem.wrongProvider;
    return null;
  }

  /// `••••abcd`: the only form a key is ever shown in.
  static String mask(String key) => key.length <= 4 ? '••••' : '••••${key.substring(key.length - 4)}';

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

  /// Saves [raw] (cleaned) for [p]; throws [ArgumentError] when [check]
  /// finds a blocking problem (a provider mismatch is only a warning).
  Future<void> save(AiProviderId p, String raw) async {
    final key = clean(raw);
    final problem = check(p, key);
    if (problem != null && problem != AiKeyProblem.wrongProvider) throw ArgumentError.value('••••', 'key', problem.name);
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

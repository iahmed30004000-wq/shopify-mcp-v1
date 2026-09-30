/// Riverpod wiring of the AI chat. Tests override [aiTransportProvider] (or
/// [aiProviderRegistryProvider]), [aiSecretStoreProvider],
/// [aiContextPickerProvider] and [aiClockProvider].
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/db/encryption.dart' show FlutterSecretStore, SecretStore;
import '../../../core/db/repositories/key_value_repository.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../../../core/providers.dart';
import '../../data/data.dart' show ExportPreviewMode, showExportPreviewSheet;
import '../domain/ai_models.dart';
import '../domain/ai_settings.dart';
import '../domain/conversation.dart';
import 'ai_provider.dart';
import 'anthropic_provider.dart';
import 'conversation_store.dart';
import 'key_store.dart';
import 'openai_provider.dart';
import 'transport.dart';

/// "Now" for message times.
final aiClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Fresh ids for conversations and messages.
final aiIdProvider = Provider<String Function()>((ref) {
  const uuid = Uuid();
  return uuid.v4;
});

/// Encrypted secure storage (Android Keystore) for the API keys.
final aiSecretStoreProvider = Provider<SecretStore>((ref) => const FlutterSecretStore());

final aiKeyStoreProvider = Provider<AiKeyStore>((ref) => AiKeyStore(ref.watch(aiSecretStoreProvider)));

/// The network (dart:io HttpClient).
final aiTransportProvider = Provider<AiTransport>((ref) => IoAiTransport());

/// The providers by id.
class AiProviderRegistry {
  AiProviderRegistry(this._providers);

  factory AiProviderRegistry.http(AiTransport transport) => AiProviderRegistry({
    AiProviderId.anthropic: AnthropicProvider(transport),
    AiProviderId.openai: OpenAiProvider(transport),
  });

  final Map<AiProviderId, AiProvider> _providers;

  AiProvider operator [](AiProviderId id) => _providers[id]!;
}

final aiProviderRegistryProvider = Provider<AiProviderRegistry>(
  (ref) => AiProviderRegistry.http(ref.watch(aiTransportProvider)),
);

/// Shows the user exactly which summary sections would be sent and returns
/// the approved Markdown (null = cancelled). [andSend]: opened by Send (the
/// message goes out right after the approval). Defaults to the data
/// centre's summary preview in select mode.
typedef AiContextPicker = Future<String?> Function(BuildContext context, {required bool andSend});

final aiContextPickerProvider = Provider<AiContextPicker>(
  (ref) => (context, {required andSend}) => showExportPreviewSheet(
    context,
    mode: ExportPreviewMode.select,
    confirmLabel: andSend ? L10n.of(context).aiChatContextUseAndSend : L10n.of(context).aiChatContextUse,
  ),
);

final conversationStoreProvider = Provider<ConversationStore>(
  (ref) => ConversationStore(ref.watch(databaseProvider)),
);

/// The conversation list, newest first.
final conversationIndexProvider = StreamProvider.autoDispose<List<ConversationMeta>>(
  (ref) => ref.watch(conversationStoreProvider).watchIndex(),
);

/// The AI settings (loaded once, saved on every change).
final aiSettingsProvider = AsyncNotifierProvider<AiSettingsController, AiSettings>(AiSettingsController.new);

class AiSettingsController extends AsyncNotifier<AiSettings> {
  static final KvKey<AiSettings> _key = KvKey.json<AiSettings>(
    AiSettings.storageKey,
    fromJson: AiSettings.fromJson,
    toJson: (s) => s.toJson(),
  );

  KeyValueRepository get _kv => KeyValueRepository(ref.read(databaseProvider));

  @override
  Future<AiSettings> build() async {
    try {
      return await _kv.get(_key) ?? const AiSettings();
    } catch (_) {
      return const AiSettings();
    }
  }

  AiSettings get current => state.value ?? const AiSettings();

  /// Applies [change] now and saves it.
  Future<void> change(AiSettings Function(AiSettings s) change) async {
    final next = change(current);
    if (next == current) return;
    state = AsyncData(next);
    try {
      await _kv.set(_key, next);
    } catch (_) {}
  }
}

/// The last four characters of each saved key (null = none). The keys
/// themselves never enter provider state.
final aiKeyHintsProvider = AsyncNotifierProvider<AiKeyHintsController, Map<AiProviderId, String?>>(
  AiKeyHintsController.new,
);

class AiKeyHintsController extends AsyncNotifier<Map<AiProviderId, String?>> {
  AiKeyStore get _store => ref.read(aiKeyStoreProvider);

  @override
  Future<Map<AiProviderId, String?>> build() async {
    final store = ref.watch(aiKeyStoreProvider);
    return {for (final p in AiProviderId.values) p: await _safe(() => store.hint(p))};
  }

  static Future<String?> _safe(Future<String?> Function() f) async {
    try {
      return await f();
    } catch (_) {
      return null;
    }
  }

  Future<void> save(AiProviderId p, String raw) async {
    await _store.save(p, raw);
    state = AsyncData({...?state.value, p: AiKeyStore.hintOf(AiKeyStore.clean(raw))});
  }

  /// Deletes [p]'s key; returns a function that puts it back (undo). The
  /// key stays only inside that closure, in memory.
  Future<Future<void> Function()?> delete(AiProviderId p) async {
    final old = await _store.read(p);
    await _store.delete(p);
    state = AsyncData({...?state.value, p: null});
    if (old == null) return null;
    return () async {
      await _store.save(p, old);
      state = AsyncData({...?state.value, p: AiKeyStore.hintOf(old)});
    };
  }
}

/// A one-off "Test key" / "Refresh models" call, only on the user's tap.
Future<List<AiModelInfo>> refreshAiModels(WidgetRef ref, AiProviderId p, {AiCancelToken? cancel}) async {
  final key = await ref.read(aiKeyStoreProvider).read(p);
  if (key == null) throw const AiException(AiErrorKind.noKey);
  final models = await ref.read(aiProviderRegistryProvider)[p].listModels(apiKey: key, cancel: cancel);
  await ref.read(aiSettingsProvider.notifier).change((s) => s.withFetched(p, models));
  return models;
}

Future<void> testAiKey(WidgetRef ref, AiProviderId p, {AiCancelToken? cancel}) async {
  final key = await ref.read(aiKeyStoreProvider).read(p);
  if (key == null) throw const AiException(AiErrorKind.noKey);
  await ref.read(aiProviderRegistryProvider)[p].testKey(key, cancel: cancel);
}


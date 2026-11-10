/// Wiring of Part 15, step A. Everything here is safe by default: until a
/// real engine exists the probe says «unsupported», the engines are stubs
/// that are never ready, and [activeModelPathProvider] is the bridge.
///
/// **The daily chat is not wired to this yet** (Part 7 keeps its offline
/// parser as the first reader). It will read [activeModelPathProvider] and
/// call [modelRouterProvider] later; nothing in `day_chat` or `ai_chat`
/// imports this feature today (a test checks).
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/db/repositories/key_value_repository.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../../../core/providers.dart';
import '../../../core/settings/app_settings.dart';
import '../../lock/application/lock_controller.dart';
import '../../lock/data/biometric_auth.dart';
import '../../lock/presentation/lock_texts.dart';
import '../../quran/data/quran_providers.dart';
import '../../reading/data/chunked_downloader.dart';
import '../domain/capability_check.dart';
import '../domain/model_catalog.dart';
import '../domain/model_path.dart';
import '../domain/model_router.dart';
import '../domain/on_device_model.dart';
import '../domain/religious_guard.dart';
import 'model_download_manager.dart';
import 'model_http.dart';
import 'model_storage.dart';
import 'ondevice_probe_client.dart';

// -------------------------------------------------------------- the phone --

/// The native probe (override with a fake in tests).
final onDeviceProbeProvider = Provider<OnDeviceProbe>((ref) => MethodChannelOnDeviceProbe());

/// False until a real engine has been measured on the owner's phone: the
/// capability screen shows «يلزم قياس على الجوال» while this is false.
final onDeviceEngineMeasuredProvider = Provider<bool>((ref) => false);

/// The numbers the capability check compares against (placeholders until
/// measured, see [CapabilityThresholds]).
final capabilityThresholdsProvider = Provider<CapabilityThresholds>((ref) => const CapabilityThresholds());

// ------------------------------------------------------------ his choice --

final onDevicePrefsProvider = AsyncNotifierProvider<OnDevicePrefsController, PathPrefs>(
  OnDevicePrefsController.new,
);

class OnDevicePrefsController extends AsyncNotifier<PathPrefs> {
  static final KvKey<PathPrefs> _key = KvKey<PathPrefs>(
    PathPrefs.storageKey,
    decode: PathPrefs.fromJson,
    encode: (v) => v.toJson(),
  );

  KeyValueRepository get _kv => KeyValueRepository(ref.read(databaseProvider));

  @override
  Future<PathPrefs> build() async {
    try {
      return await _kv.get(_key) ?? const PathPrefs();
    } catch (_) {
      return const PathPrefs();
    }
  }

  PathPrefs get current => state.value ?? const PathPrefs();

  Future<void> change(PathPrefs Function(PathPrefs s) change) async {
    final next = change(current);
    if (next == current) return;
    state = AsyncData(next);
    try {
      await _kv.set(_key, next);
    } catch (_) {}
  }
}

// ------------------------------------------------------- the weights (opt) --

/// Where the optional weights live: the app's private files directory.
final modelStorageRootProvider = Provider<Future<Directory> Function()>(
  (ref) =>
      () async => Directory(p.join((await getApplicationSupportDirectory()).path, 'ondevice_models')),
);

/// The fingerprint before a big download. Fails closed: no fingerprint set
/// up in Madar, no download.
final authGateProvider = Provider<AuthGate>((ref) {
  return _LockAuthGate(() {
    final arabic = ref.read(appSettingsProvider).isArabic;
    final l = lookupL10n(Locale(arabic ? 'ar' : 'en'));
    return ref
        .read(lockControllerProvider.notifier)
        .authenticateWithBiometrics(LockTexts.settingsPrompt(l), unlock: false);
  });
});

class _LockAuthGate implements AuthGate {
  _LockAuthGate(this._prompt);

  final Future<BiometricOutcome> Function() _prompt;

  @override
  Future<bool> confirm() async {
    try {
      return await _prompt() == BiometricOutcome.success;
    } catch (_) {
      return false;
    }
  }
}

final modelDownloadManagerProvider = Provider<ModelDownloadManager>((ref) {
  final root = ref.watch(modelStorageRootProvider);
  final probe = ref.watch(onDeviceProbeProvider);
  final sink = DirectoryModelSink(root);
  final store = FileDownloadStateStore(root);
  final manager = ModelDownloadManager(
    auth: ref.watch(authGateProvider),
    store: store,
    sink: sink,
    newDownloader: () => ChunkedDownloader(
      client: IoRangeHttpClient(),
      store: store,
      space: ProbeFreeSpace(probe),
      sink: sink,
      connectivity: const WifiConnectivityProbe(),
    ),
  );
  ref.onDispose(manager.dispose);
  return manager;
});

/// The models the screen offers (override in tests with a verified entry).
final modelCatalogProvider = Provider<List<ModelCatalogEntry>>((ref) => ModelCatalog.entries);

/// Where each catalogue model stands, kept live from the manager.
final modelInstallsProvider = NotifierProvider<ModelInstalls, Map<String, ModelInstallState>>(ModelInstalls.new);

class ModelInstalls extends Notifier<Map<String, ModelInstallState>> {
  @override
  Map<String, ModelInstallState> build() {
    final manager = ref.watch(modelDownloadManagerProvider);
    final entries = ref.watch(modelCatalogProvider);
    final sub = manager.changes.listen((s) => state = {...state, s.entryId: s});
    ref.onDispose(sub.cancel);
    unawaited(_load(manager, entries));
    return {for (final e in entries) e.id: ModelInstallState.none(e.id)};
  }

  Future<void> _load(ModelDownloadManager manager, List<ModelCatalogEntry> entries) async {
    for (final e in entries) {
      try {
        final s = await manager.stateOf(e);
        if (!ref.mounted) return;
        state = {...state, e.id: s};
      } catch (_) {
        // A damaged note reads as «not installed».
      }
    }
  }
}

bool _languageWeightsInstalled(List<ModelCatalogEntry> entries, Map<String, ModelInstallState> m) => entries.any(
  (e) => e.kind == ModelKind.language && m[e.id]?.status == ModelInstallStatus.installed,
);

// -------------------------------------------------- what it can run, why --

/// The phone's own answer plus whether the weights are already there. Read
/// again by invalidating this provider («افحص من جديد»).
final deviceCapabilitiesProvider = FutureProvider<DeviceCapabilities>((ref) async {
  final entries = ref.watch(modelCatalogProvider);
  final installed = ref.watch(modelInstallsProvider.select((m) => _languageWeightsInstalled(entries, m)));
  final caps = await ref.watch(onDeviceProbeProvider).probe();
  return caps.copyWith(weightsInstalled: caps.weightsInstalled || installed);
});

final pathChoiceProvider = FutureProvider<PathChoice>((ref) async {
  final caps = await ref.watch(deviceCapabilitiesProvider.future);
  final prefs = await ref.watch(onDevicePrefsProvider.future);
  return CapabilityCheck.choose(caps, prefs, thresholds: ref.watch(capabilityThresholdsProvider));
});

/// The path the daily chat will use. **The bridge** while the check is still
/// running or has failed: the floor that always works.
final activeModelPathProvider = Provider<ModelPath>((ref) => ref.watch(pathChoiceProvider).value?.path ?? ModelPath.bridge);

// ------------------------------------------------------------ the router --

/// The engines by path. Stubs (never ready) until step B plugs the real ones
/// in behind `OnDeviceModel`.
final onDeviceModelsProvider = Provider<Map<ModelPath, OnDeviceModel>>(
  (ref) => const {
    ModelPath.aicore: StubOnDeviceModel(ModelPath.aicore),
    ModelPath.inAppEngine: StubOnDeviceModel(ModelPath.inAppEngine),
  },
);

/// The bundled Quran, folded, for the religious guard. Fails closed: while
/// it is not loaded (or failed to load) there is no router, so no model
/// answer can reach the screen.
final quranVerseIndexProvider = FutureProvider<QuranVerseIndex>((ref) async {
  final text = await ref.watch(quranTextProvider.future);
  final meta = await ref.watch(quranMetaProvider.future);
  return QuranVerseIndex.fromQuran(text, meta);
});

/// What the daily chat calls: `ref.read(modelRouterProvider.future)` then
/// `router.run(request)`. Reads the active path at the moment of each call.
final modelRouterProvider = FutureProvider<ModelRouter>((ref) async {
  final index = await ref.watch(quranVerseIndexProvider.future);
  return ModelRouter(
    activePath: () => ref.read(activeModelPathProvider),
    models: ref.watch(onDeviceModelsProvider),
    guard: ReligiousOutputGuard(index),
  );
});

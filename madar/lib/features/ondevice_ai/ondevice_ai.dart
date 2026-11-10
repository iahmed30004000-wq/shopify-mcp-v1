/// «الموديل على الجوال» (Part 15, step A): the frame around an on-device
/// model, proved without the real phone.
///
/// * [CapabilityCheck] – which of the three ways (AICore, an engine inside
///   Madar, the Part 3 bridge) this phone gets, and a reason he can read;
/// * [ModelRouter] – runs a request on the active way, falls back to the
///   bridge when the model fails, cuts a very long input by a written
///   policy, and passes every output through [ReligiousOutputGuard] (no
///   ruling, no verse, no hadith from memory) and `HealthGuard`;
/// * [OnDeviceModel] – the one interface the real engines will plug into in
///   step B (only a never-ready stub exists today);
/// * [ModelDownloadManager] – the optional, resumable, removable, fingerprint-
///   gated download of the weights over Part 17's `ChunkedDownloader`;
/// * [OnDeviceSettingsScreen] – `/settings/ondevice`.
///
/// The daily chat is NOT wired to this yet: its offline parser stays the
/// first reader. It will read [activeModelPathProvider] and
/// [modelRouterProvider] later.
library;

export 'data/model_download_manager.dart'
    show AuthGate, ModelDownloadManager, ModelFileSink, ModelInstallState, ModelInstallStatus, StartRefusal, StartResult;
export 'data/ondevice_probe_client.dart' show MethodChannelOnDeviceProbe, OnDeviceProbe;
export 'data/ondevice_providers.dart';
export 'domain/capability_check.dart';
export 'domain/input_policy.dart';
export 'domain/model_catalog.dart';
export 'domain/model_path.dart';
export 'domain/model_router.dart';
export 'domain/on_device_model.dart';
export 'domain/religious_guard.dart';
export 'presentation/ondevice_labels.dart' show OnDeviceLabels;
export 'presentation/ondevice_settings_screen.dart' show OnDeviceSettingsScreen;

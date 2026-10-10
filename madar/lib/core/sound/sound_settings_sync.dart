import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../settings/app_settings.dart';
import 'profiles.dart';
import 'sound_api.dart';

/// Applies [AppSettings] to the sound and haptics services.
///
/// Pure logic (no Flutter bindings): feed it settings, platform brightness
/// and foreground state; it issues only the calls whose inputs changed.
///
/// * `soundEnabled` → [SoundService.enabled]
/// * `hapticsEnabled` → [HapticsService.enabled]
/// * `volumes` → [SoundService.setVolume] per category
/// * effective theme (follows the system when `followSystem`) → profile via
///   [SoundProfiles.idForTheme] → [SoundService.setProfile]
/// * `ambientEnabled` (and sound on, app in foreground) →
///   [SoundService.startAmbient] / [SoundService.stopAmbient]
class SoundSettingsSync {
  SoundSettingsSync({required this.sound, required this.haptics});

  final SoundService sound;
  final HapticsService haptics;

  AppSettings? _settings;
  Brightness _brightness = Brightness.dark;
  bool _foreground = true;
  String? _profile;
  bool _ambientOn = false;

  AppSettings? get settings => _settings;

  /// Sound profile id currently requested.
  String? get profileId => _profile;

  bool get ambientRequested => _ambientOn;

  void apply(AppSettings next) {
    final prev = _settings;
    _settings = next;
    if (prev == null || prev.soundEnabled != next.soundEnabled || sound.enabled != next.soundEnabled) {
      sound.enabled = next.soundEnabled;
    }
    if (prev == null || prev.hapticsEnabled != next.hapticsEnabled || haptics.enabled != next.hapticsEnabled) {
      haptics.enabled = next.hapticsEnabled;
    }
    for (final c in SoundCategory.values) {
      final v = next.volumes[c] ?? 1.0;
      if (prev == null || prev.volumes[c] != v) sound.setVolume(c, v);
    }
    _applyProfile();
    _applyAmbient();
  }

  void setPlatformBrightness(Brightness brightness) {
    if (_brightness == brightness) return;
    _brightness = brightness;
    _applyProfile();
  }

  void setForeground(bool foreground) {
    if (_foreground == foreground) return;
    _foreground = foreground;
    if (sound case final SoundLifecycleAware aware) aware.onAppLifecycleChanged(foreground: foreground);
    _applyAmbient();
  }

  void _applyProfile() {
    final s = _settings;
    if (s == null) return;
    final id = SoundProfiles.idForTheme(s.effectiveTheme(_brightness));
    if (id == _profile) return;
    _profile = id;
    unawaited(sound.setProfile(id));
  }

  void _applyAmbient() {
    final s = _settings;
    final want = s != null && s.ambientEnabled && s.soundEnabled && _foreground;
    if (want == _ambientOn) return;
    _ambientOn = want;
    unawaited(want ? sound.startAmbient() : sound.stopAmbient());
  }
}

/// Keeps the sound + haptics services in step with [appSettingsProvider],
/// the platform brightness and the app lifecycle, and installs the [Fx]
/// facade. The app shell only needs to watch it once, e.g. in the root
/// widget's build: `ref.watch(soundSettingsSyncProvider);`.
final soundSettingsSyncProvider = Provider<SoundSettingsSync>((ref) {
  final sync = SoundSettingsSync(
    sound: ref.watch(soundServiceProvider),
    haptics: ref.watch(hapticsServiceProvider),
  );
  Fx.install(ref.watch(feedbackProvider));
  final binding = WidgetsBinding.instance;
  final observer = _SoundLifecycleObserver(sync, binding);
  binding.addObserver(observer);
  sync.setPlatformBrightness(binding.platformDispatcher.platformBrightness);
  ref.listen<AppSettings>(appSettingsProvider, (_, next) => sync.apply(next), fireImmediately: true);
  ref.onDispose(() => binding.removeObserver(observer));
  return sync;
});

class _SoundLifecycleObserver with WidgetsBindingObserver {
  _SoundLifecycleObserver(this.sync, this.binding);

  final SoundSettingsSync sync;
  final WidgetsBinding binding;

  @override
  void didChangePlatformBrightness() => sync.setPlatformBrightness(binding.platformDispatcher.platformBrightness);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        sync.setForeground(true);
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        sync.setForeground(false);
      case AppLifecycleState.inactive:
        // Transient (dialogs, app switcher peek) – keep playing.
        break;
    }
  }
}

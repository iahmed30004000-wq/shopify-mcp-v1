import 'package:flutter/foundation.dart';

/// Every UI sound in Madar. All are synthesised procedurally at start-up and
/// re-voiced per theme (see `SoundProfile`).
enum Sfx {
  tap,
  toggleOn,
  toggleOff,
  sheetOpen,
  sheetClose,
  complete,
  levelUp,
  delete,
  undo,
  swipe,
  pickUp,
  drop,
  error,
  notify,
  navigate,
  back,
  prayerLit,
  sparkle,
  countTick,
}

/// Volume categories with independent sliders.
enum SoundCategory { ui, ambient, games, prayer }

/// Haptic patterns, each synced to a sound.
enum Haptic { none, selection, light, medium, heavy, success, warning, error, tick }

/// Default sound → haptic pairing ("haptics synced to every sound").
const Map<Sfx, Haptic> sfxHaptics = {
  Sfx.tap: Haptic.selection,
  Sfx.toggleOn: Haptic.light,
  Sfx.toggleOff: Haptic.light,
  Sfx.sheetOpen: Haptic.light,
  Sfx.sheetClose: Haptic.selection,
  Sfx.complete: Haptic.success,
  Sfx.levelUp: Haptic.heavy,
  Sfx.delete: Haptic.medium,
  Sfx.undo: Haptic.light,
  Sfx.swipe: Haptic.selection,
  Sfx.pickUp: Haptic.medium,
  Sfx.drop: Haptic.light,
  Sfx.error: Haptic.error,
  Sfx.notify: Haptic.medium,
  Sfx.navigate: Haptic.selection,
  Sfx.back: Haptic.selection,
  Sfx.prayerLit: Haptic.heavy,
  Sfx.sparkle: Haptic.none,
  Sfx.countTick: Haptic.tick,
};

/// Audio engine abstraction. The real implementation is backed by
/// flutter_soloud; tests use [SilentSoundService].
abstract class SoundService {
  Future<void> init();

  /// Fire-and-forget UI sound on the [SoundCategory.ui] bus.
  void play(Sfx sfx, {double volume = 1.0, double pitch = 1.0});

  /// Re-synthesise the UI kit with a different timbre profile (per theme).
  Future<void> setProfile(String profileId);

  /// Deep-space ambient soundscape for the home screen.
  Future<void> startAmbient();
  Future<void> stopAmbient();

  /// Soft swell of the ambient bed during planet fly-ins (0..1).
  void swell(double amount);

  /// Global switch and per-category volumes (0..1).
  bool get enabled;
  set enabled(bool value);
  double volumeOf(SoundCategory category);
  void setVolume(SoundCategory category, double value);

  /// Mutes ambient + games while the adhan plays or during prayer. Soft UI
  /// feedback stays audible by default (see `PrayerMutePolicy` in
  /// soloud_sound_service.dart); the prayer bus itself is never muted.
  void setPrayerMute(bool muted);
  bool get prayerMuted;

  Future<void> dispose();
}

/// No-op engine for tests, silent mode and platforms without audio.
class SilentSoundService implements SoundService {
  final _volumes = {for (final c in SoundCategory.values) c: 1.0};
  @override
  bool enabled = true;
  @override
  bool prayerMuted = false;
  final List<Sfx> played = [];

  @override
  Future<void> init() async {}
  @override
  void play(Sfx sfx, {double volume = 1.0, double pitch = 1.0}) {
    if (kDebugMode) played.add(sfx);
  }

  @override
  Future<void> setProfile(String profileId) async {}
  @override
  Future<void> startAmbient() async {}
  @override
  Future<void> stopAmbient() async {}
  @override
  void swell(double amount) {}
  @override
  double volumeOf(SoundCategory category) => _volumes[category]!;
  @override
  void setVolume(SoundCategory category, double value) => _volumes[category] = value;
  @override
  void setPrayerMute(bool muted) => prayerMuted = muted;
  @override
  Future<void> dispose() async {}
}

/// Haptics abstraction (platform HapticFeedback in production).
abstract class HapticsService {
  bool get enabled;
  set enabled(bool value);
  void fire(Haptic haptic);
}

/// Combined sound + haptic feedback – the only API widgets should call.
///
/// Widgets without a `WidgetRef` use the static facade [Fx]; everything is
/// wired to the same instance at bootstrap.
class FeedbackService {
  FeedbackService(this.sound, this.haptics);

  final SoundService sound;
  final HapticsService haptics;

  void fire(Sfx sfx, {double volume = 1.0, double pitch = 1.0, Haptic? haptic}) {
    sound.play(sfx, volume: volume, pitch: pitch);
    haptics.fire(haptic ?? sfxHaptics[sfx] ?? Haptic.none);
  }
}

/// Static facade: `Fx.fire(Sfx.tap)`.
abstract final class Fx {
  static FeedbackService? _instance;

  static void install(FeedbackService service) => _instance = service;

  static FeedbackService? get instance => _instance;

  static void fire(Sfx sfx, {double volume = 1.0, double pitch = 1.0, Haptic? haptic}) =>
      _instance?.fire(sfx, volume: volume, pitch: pitch, haptic: haptic);
}

/// Optional capability of a [SoundService] (additive to the contract): react
/// to the app moving between foreground and background – e.g. pause the
/// ambient bed while hidden and pre-warm the output device on return so the
/// first tap is instant. `SoundSettingsSync` drives it from the app
/// lifecycle; services that don't implement it are simply not notified.
abstract interface class SoundLifecycleAware {
  void onAppLifecycleChanged({required bool foreground});
}

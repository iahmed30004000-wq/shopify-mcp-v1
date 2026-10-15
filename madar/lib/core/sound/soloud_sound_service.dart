import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'ambient.dart';
import 'audio_engine.dart';
import 'profiles.dart';
import 'sound_api.dart';
import 'sound_kit.dart';
import 'synth/wav.dart';

/// Lifecycle of [SoloudSoundService].
enum SoundEngineStatus {
  /// [SoundService.init] not called yet.
  idle,

  /// Opening the output device.
  starting,

  /// Engine up (the UI kit may still be synthesising – see
  /// [SoloudSoundService.kitReady]).
  ready,

  /// No audio available (tests, missing native library, no output device):
  /// every call is a silent no-op.
  silent,

  disposed,
}

/// What prayer mute silences.
///
/// Default: the ambient bed and games go quiet while the adhan plays or
/// during prayer; soft interface sounds **stay** (marking a prayer as prayed
/// still deserves its luminous bell, and the UI must keep confirming
/// actions). The prayer bus itself (adhan) is never muted by prayer mute.
final class PrayerMutePolicy {
  const PrayerMutePolicy({this.muteUi = false, this.muteAmbient = true, this.muteGames = true});

  final bool muteUi;
  final bool muteAmbient;
  final bool muteGames;

  bool mutes(SoundCategory c) => switch (c) {
        SoundCategory.ui => muteUi,
        SoundCategory.ambient => muteAmbient,
        SoundCategory.games => muteGames,
        SoundCategory.prayer => false,
      };
}

/// Per-[Sfx] voice limits and retrigger debounce.
final class SfxPolyphony {
  const SfxPolyphony();

  /// Maximum simultaneous voices of one sound; the oldest is faded out
  /// (12 ms) when exceeded.
  int maxVoices(Sfx sfx) => switch (sfx) {
        Sfx.tap || Sfx.countTick || Sfx.sparkle => 3,
        Sfx.levelUp || Sfx.prayerLit => 1,
        _ => 2,
      };

  /// Retriggers closer than this are dropped – fast scrolling or double
  /// taps never machine-gun.
  Duration minInterval(Sfx sfx) => switch (sfx) {
        Sfx.tap => const Duration(milliseconds: 28),
        Sfx.countTick => const Duration(milliseconds: 32),
        Sfx.swipe || Sfx.sparkle => const Duration(milliseconds: 45),
        Sfx.navigate || Sfx.back => const Duration(milliseconds: 60),
        Sfx.toggleOn || Sfx.toggleOff => const Duration(milliseconds: 40),
        Sfx.levelUp || Sfx.prayerLit => const Duration(milliseconds: 250),
        _ => const Duration(milliseconds: 25),
      };
}

/// A sound loaded for [SoloudSoundService.playClip] (games, adhan…).
final class SoundClip {
  const SoundClip._(this.source, this.name, this.duration);

  final int source;
  final String name;

  /// Length when known (PCM WAV), else `null`.
  final Duration? duration;
}

typedef SoundTimerFactory = Timer Function(Duration delay, void Function() callback);

/// [SoundService] on flutter_soloud with procedurally synthesised kits.
///
/// * **Buses** – ui / ambient / games / prayer volumes are independent;
///   one-shots take the bus gain at trigger time, long voices (ambient,
///   looping clips) follow volume changes with short fades.
/// * **Global enable** silences everything (ambient fades out and pauses).
/// * **Prayer mute** – see [PrayerMutePolicy] (ambient + games by default;
///   UI stays).
/// * **Profiles** – [setProfile] re-synthesises the kit on a background
///   isolate, loads it, then swaps sources atomically; old sources are
///   released after their voices have rung out. The ambient bed follows the
///   profile with a slow cross-fade.
/// * **Polyphony** – [SfxPolyphony] caps voices per sound and debounces
///   retriggers; retriggering a tap costs one table lookup and one FFI call.
/// * **Fallback** – if the engine cannot start (tests, missing native
///   library, no device) the service degrades to [SoundEngineStatus.silent]
///   and never throws.
/// * Nothing here synthesises on the UI isolate.
class SoloudSoundService implements SoundService, SoundLifecycleAware {
  SoloudSoundService({
    AudioEngine? engine,
    String profileId = SoundProfiles.defaultId,
    bool? nativeAudio,
    Future<SoundKit> Function(String profileId)? renderKit,
    Future<Uint8List> Function(String profileId)? renderAmbient,
    Duration Function()? clock,
    SoundTimerFactory? timer,
    this.prayerMutePolicy = const PrayerMutePolicy(),
    this.polyphony = const SfxPolyphony(),
    this.initTimeout = const Duration(seconds: 6),
  })  : _engine = engine ?? SoloudAudioEngine(),
        _nativeAudio = nativeAudio ?? !_runningInFlutterTest,
        _renderKit = renderKit ?? SoundKitRenderer.renderInBackground,
        _renderAmbient = renderAmbient ?? AmbientSoundscape.renderInBackground,
        _clock = clock ?? _monotonicClock(),
        _timer = timer ?? Timer.new,
        _targetProfile = SoundProfiles.normalize(profileId);

  final AudioEngine _engine;
  final bool _nativeAudio;
  final Future<SoundKit> Function(String) _renderKit;
  final Future<Uint8List> Function(String) _renderAmbient;
  final Duration Function() _clock;
  final SoundTimerFactory _timer;
  final PrayerMutePolicy prayerMutePolicy;
  final SfxPolyphony polyphony;
  final Duration initTimeout;

  /// Ambient bed: master level and resting low-pass cutoff (Hz). A swell
  /// opens the filter by up to ~2.2 octaves.
  static const double ambientLevel = 0.9;
  static const double ambientCutoffHz = 2600;

  static bool get _runningInFlutterTest {
    if (kIsWeb) return false;
    try {
      return Platform.environment.containsKey('FLUTTER_TEST');
    } catch (_) {
      return false;
    }
  }

  static Duration Function() _monotonicClock() {
    final sw = Stopwatch()..start();
    return () => sw.elapsed;
  }

  SoundEngineStatus _status = SoundEngineStatus.idle;
  Future<void>? _initFuture;

  /// Engine starts tried so far, and when the last one failed: a failed or
  /// timed-out start is retried when the app returns to the foreground
  /// (at most [maxInitAttempts] times, [initRetryBackoff] apart).
  int _initAttempts = 0;
  Duration? _lastInitFailure;
  static const maxInitAttempts = 3;
  static const initRetryBackoff = Duration(seconds: 10);

  int get initAttempts => _initAttempts;

  bool _enabled = true;
  bool _prayerMuted = false;
  bool _foreground = true;
  final Map<SoundCategory, double> _volumes = {for (final c in SoundCategory.values) c: 1.0};

  // UI kit.
  String _targetProfile;
  String? _kitProfile;
  Map<Sfx, int> _kit = const {};
  Map<Sfx, Duration> _kitLengths = const {};
  int _kitGen = 0;
  Future<void>? _kitLoad;
  final Map<Sfx, List<(int, Duration)>> _voices = {};
  final Map<Sfx, Duration> _lastStart = {};
  final Set<Timer> _timers = {};

  // In-flight syntheses, shared by concurrent requests for the same profile.
  final Map<String, Future<SoundKit>> _kitRenders = {};
  final Map<String, Future<Uint8List>> _ambientRenders = {};

  /// Makes every native source name unique (SoLoud warns on duplicates).
  int _loadSeq = 0;

  // Ambient.
  bool _ambientWanted = false;
  int? _ambientVoice;
  int? _ambientSource;
  String? _ambientProfile;
  bool _ambientPaused = false;
  int _ambientGen = 0;
  Timer? _swellTimer;
  Timer? _ambientPauseTimer;
  Timer? _ambientUnloadTimer;

  // Clips (games / adhan).
  final Map<int, _ClipVoice> _clipVoices = {};

  SoundEngineStatus get status => _status;
  bool get isSilent => _status == SoundEngineStatus.silent;

  /// Profile whose kit is currently loaded (null until the first kit is in).
  String? get loadedProfile => _kitProfile;

  /// Profile most recently requested.
  String get requestedProfile => _targetProfile;

  /// Completes when the most recently requested kit is loaded (or failed).
  Future<void> get kitReady => _kitLoad ?? Future<void>.value();

  bool get ambientPlaying => _ambientVoice != null && !_ambientPaused;

  // ---------------------------------------------------------------------------
  // Lifecycle

  @override
  Future<void> init() => _initFuture ??= _init();

  Future<void> _init() async {
    if (_status == SoundEngineStatus.disposed) return;
    if (!_nativeAudio) {
      _status = SoundEngineStatus.silent;
      return;
    }
    _status = SoundEngineStatus.starting;
    _initAttempts++;
    final start = _engine.init();
    try {
      await start.timeout(initTimeout);
    } catch (e) {
      _log('engine unavailable, running silent', e);
      _status = _status == SoundEngineStatus.disposed ? SoundEngineStatus.disposed : SoundEngineStatus.silent;
      _lastInitFailure = _clock();
      if (e is TimeoutException) {
        // A start that finishes after the timeout must not keep holding the
        // audio device while the service is silent; a later retry starts
        // (or adopts) the engine again.
        unawaited(
          start.then((_) async {
            if (_status == SoundEngineStatus.silent || _status == SoundEngineStatus.disposed) {
              await _safe(_engine.shutdown);
            }
          }, onError: (Object _) {}),
        );
      }
      return;
    }
    if (_status == SoundEngineStatus.disposed) {
      await _safe(_engine.shutdown);
      return;
    }
    _status = SoundEngineStatus.ready;
    _kitLoad = _loadKit(_targetProfile);
    if (_ambientWanted) unawaited(_ensureAmbient());
  }

  @override
  Future<void> dispose() async {
    if (_status == SoundEngineStatus.disposed) return;
    final wasReady = _status == SoundEngineStatus.ready;
    _status = SoundEngineStatus.disposed;
    _kitGen++;
    _ambientGen++;
    for (final t in [..._timers, _swellTimer, _ambientPauseTimer, _ambientUnloadTimer]) {
      t?.cancel();
    }
    _timers.clear();
    _voices.clear();
    _clipVoices.clear();
    _kit = const {};
    _ambientVoice = null;
    if (wasReady) await _safe(_engine.shutdown);
  }

  @override
  void onAppLifecycleChanged({required bool foreground}) {
    if (_foreground == foreground) return;
    _foreground = foreground;
    _applyAmbientGain(foreground ? const Duration(milliseconds: 1200) : const Duration(milliseconds: 300));
    if (foreground && _status == SoundEngineStatus.ready) unawaited(_safe(_engine.prewarm));
    if (foreground && _shouldRetryInit) {
      _initFuture = null;
      unawaited(init());
    }
  }

  /// A failed or timed-out start (busy audio device, restarted audio
  /// server) is retried on return to the foreground instead of leaving the
  /// whole session silent.
  bool get _shouldRetryInit {
    final failed = _lastInitFailure;
    return _status == SoundEngineStatus.silent &&
        _nativeAudio &&
        failed != null &&
        _initAttempts < maxInitAttempts &&
        _clock() - failed >= initRetryBackoff;
  }

  // ---------------------------------------------------------------------------
  // Switches and buses

  @override
  bool get enabled => _enabled;

  @override
  set enabled(bool value) {
    if (_enabled == value) return;
    _enabled = value;
    _applyAmbientGain(const Duration(milliseconds: 600));
    _refreshClipVoices();
  }

  @override
  double volumeOf(SoundCategory category) => _volumes[category]!;

  @override
  void setVolume(SoundCategory category, double value) {
    final v = value.isNaN ? 0.0 : value.clamp(0.0, 1.0);
    if (_volumes[category] == v) return;
    _volumes[category] = v;
    if (category == SoundCategory.ambient) _applyAmbientGain(const Duration(milliseconds: 150));
    _refreshClipVoices();
  }

  @override
  bool get prayerMuted => _prayerMuted;

  @override
  void setPrayerMute(bool muted) {
    if (_prayerMuted == muted) return;
    _prayerMuted = muted;
    _applyAmbientGain(const Duration(milliseconds: 900));
    _refreshClipVoices();
  }

  /// Effective gain of a bus right now (enable × prayer mute × volume).
  double busGain(SoundCategory category, {bool bypassGlobalSwitch = false}) {
    if (!_enabled && !bypassGlobalSwitch) return 0;
    if (_prayerMuted && prayerMutePolicy.mutes(category)) return 0;
    return _volumes[category]!;
  }

  // ---------------------------------------------------------------------------
  // UI sounds

  @override
  void play(Sfx sfx, {double volume = 1.0, double pitch = 1.0}) {
    if (_status != SoundEngineStatus.ready) return;
    final source = _kit[sfx];
    if (source == null) return;
    final gain = busGain(SoundCategory.ui) * volume.clamp(0.0, 1.0);
    if (gain <= 0.0005) return;

    final now = _clock();
    final last = _lastStart[sfx];
    if (last != null && now - last < polyphony.minInterval(sfx)) return;

    final list = _voices.putIfAbsent(sfx, () => []);
    final length = _kitLengths[sfx] ?? const Duration(seconds: 1);
    while (list.isNotEmpty && now - list.first.$2 > length) {
      list.removeAt(0); // finished on its own
    }
    if (list.length >= polyphony.maxVoices(sfx)) {
      final oldest = list.removeAt(0).$1;
      _engine.fadeVolume(oldest, 0, const Duration(milliseconds: 12));
      _engine.stopAfter(oldest, const Duration(milliseconds: 14));
    }
    final voice = _engine.play(source, volume: gain, speed: pitch.isNaN ? 1.0 : pitch.clamp(0.5, 2.0));
    _lastStart[sfx] = now;
    if (voice >= 0) list.add((voice, now));
  }

  @override
  Future<void> setProfile(String profileId) {
    final id = SoundProfiles.normalize(profileId);
    if (id == _targetProfile && (_kitLoad != null || _status != SoundEngineStatus.ready)) return kitReady;
    _targetProfile = id;
    if (_status != SoundEngineStatus.ready) return Future<void>.value(); // init() loads it
    if (id == _kitProfile) {
      // Back to the kit that is already loaded: just cancel the pending one.
      _kitGen++;
      if (_ambientWanted) unawaited(_ensureAmbient());
      return _kitLoad = Future<void>.value();
    }
    return _kitLoad = _loadKit(id);
  }

  Future<void> _loadKit(String id) async {
    final gen = ++_kitGen;
    SoundKit kit;
    try {
      // (Block bodies: returning the removed future from whenComplete would
      // make the future wait on itself.)
      kit = await (_kitRenders[id] ??= _renderKit(id).whenComplete(() {
        _kitRenders.remove(id);
      }));
    } catch (e) {
      _log('kit synthesis failed for $id', e);
      return;
    }
    if (gen != _kitGen || _status != SoundEngineStatus.ready) return;
    final loaded = <Sfx, int>{};
    final lengths = <Sfx, Duration>{};
    try {
      for (final sfx in Sfx.values) {
        final wav = kit.wavs[sfx];
        if (wav == null) continue;
        loaded[sfx] = await _engine.load('madar/${kit.profileId}/${sfx.name}#${_loadSeq++}.wav', wav);
        lengths[sfx] = _durationOf(wav) ?? const Duration(seconds: 1);
        if (gen != _kitGen || _status != SoundEngineStatus.ready) break;
      }
    } catch (e) {
      _log('kit load failed for $id', e);
      _unloadLater(loaded.values, Duration.zero);
      return;
    }
    if (gen != _kitGen || _status != SoundEngineStatus.ready) {
      _unloadLater(loaded.values, Duration.zero);
      return;
    }
    // Atomic swap: from here on every play() uses the new kit. Voices of the
    // old kit ring out before their sources are released.
    final old = _kit;
    _kit = loaded;
    _kitLengths = lengths;
    _kitProfile = kit.profileId;
    _voices.clear();
    _unloadLater(old.values, const Duration(milliseconds: 1500));
    if (_ambientWanted) unawaited(_ensureAmbient());
  }

  // ---------------------------------------------------------------------------
  // Ambient

  @override
  Future<void> startAmbient() async {
    _ambientWanted = true;
    if (_status == SoundEngineStatus.starting) await _initFuture;
    await _ensureAmbient();
  }

  @override
  Future<void> stopAmbient() async {
    _ambientWanted = false;
    _ambientGen++;
    _swellTimer?.cancel();
    _ambientPauseTimer?.cancel();
    final v = _ambientVoice;
    _ambientVoice = null;
    _ambientPaused = false;
    if (v != null) {
      _engine.fadeVolume(v, 0, const Duration(milliseconds: 1200));
      _engine.stopAfter(v, const Duration(milliseconds: 1260));
    }
    // Keep the loop loaded briefly so toggling back is instant.
    _ambientUnloadTimer?.cancel();
    if (_ambientSource == null || _status != SoundEngineStatus.ready) return;
    _ambientUnloadTimer = _timer(const Duration(seconds: 20), () {
      final src = _ambientSource;
      if (_ambientWanted || src == null || _status != SoundEngineStatus.ready) return;
      _ambientSource = null;
      _ambientProfile = null;
      unawaited(_safe(() => _engine.unload(src)));
    });
  }

  Future<void> _ensureAmbient() async {
    if (!_ambientWanted || _status != SoundEngineStatus.ready) return;
    _ambientUnloadTimer?.cancel();
    final profile = _kitProfile ?? _targetProfile;
    if (_ambientVoice != null && _ambientProfile == profile) {
      _applyAmbientGain(const Duration(milliseconds: 1500));
      return;
    }
    final gen = ++_ambientGen;
    var src = _ambientProfile == profile ? _ambientSource : null;
    if (src == null) {
      Uint8List wav;
      try {
        wav = await (_ambientRenders[profile] ??= _renderAmbient(profile).whenComplete(() {
          _ambientRenders.remove(profile);
        }));
      } catch (e) {
        _log('ambient synthesis failed', e);
        return;
      }
      if (gen != _ambientGen || !_ambientWanted || _status != SoundEngineStatus.ready) return;
      try {
        src = await _engine.load('madar/ambient/$profile#${_loadSeq++}.wav', wav);
      } catch (e) {
        _log('ambient load failed', e);
        return;
      }
      if (gen != _ambientGen || !_ambientWanted || _status != SoundEngineStatus.ready) {
        final s = src;
        unawaited(_safe(() => _engine.unload(s)));
        return;
      }
      _engine.enableLowPass(src);
    }
    final oldVoice = _ambientVoice;
    final oldSource = _ambientSource;
    final target = _ambientTarget;
    final voice = _engine.play(
      src,
      volume: 0,
      looping: true,
      protect: true,
      paused: target <= 0,
      lowPassHz: ambientCutoffHz,
    );
    if (voice < 0) return;
    _ambientVoice = voice;
    _ambientSource = src;
    _ambientProfile = profile;
    _ambientPaused = target <= 0;
    final fadeIn = oldVoice == null ? const Duration(milliseconds: 2500) : const Duration(seconds: 3);
    if (target > 0) _engine.fadeVolume(voice, target, fadeIn);
    if (oldVoice != null) {
      _engine.fadeVolume(oldVoice, 0, const Duration(seconds: 3));
      _engine.stopAfter(oldVoice, const Duration(milliseconds: 3100));
    }
    if (oldSource != null && oldSource != src) _unloadLater([oldSource], const Duration(milliseconds: 3400));
  }

  double get _ambientTarget {
    if (!_foreground) return 0;
    return busGain(SoundCategory.ambient) * ambientLevel;
  }

  void _applyAmbientGain(Duration fade) {
    final v = _ambientVoice;
    if (v == null) return;
    final target = _ambientTarget;
    _ambientPauseTimer?.cancel();
    if (target <= 0) {
      _swellTimer?.cancel();
      _engine.fadeVolume(v, 0, fade);
      // Pause once silent so the mixer stops rendering the loop.
      _ambientPauseTimer = _timer(fade + const Duration(milliseconds: 60), () {
        if (_ambientVoice == v && _ambientTarget <= 0) {
          _engine.setPaused(v, true);
          _ambientPaused = true;
        }
      });
    } else {
      if (_ambientPaused) {
        _engine.setPaused(v, false);
        _ambientPaused = false;
      }
      _engine.fadeVolume(v, target, fade);
    }
  }

  @override
  void swell(double amount) {
    final v = _ambientVoice;
    if (v == null || _ambientPaused || amount.isNaN) return;
    final a = amount.clamp(0.0, 1.0);
    final base = _ambientTarget;
    if (a <= 0 || base <= 0) return;
    const rise = Duration(milliseconds: 380);
    _engine.fadeVolume(v, math.min(1.0, base * (1 + 0.7 * a)), rise);
    _engine.setLowPass(v, ambientCutoffHz * math.pow(2.0, 2.2 * a), fade: rise);
    _swellTimer?.cancel();
    _swellTimer = _timer(const Duration(milliseconds: 1200), () {
      if (_ambientVoice != v) return;
      const settle = Duration(milliseconds: 1800);
      if (!_ambientPaused) _engine.fadeVolume(v, _ambientTarget, settle);
      _engine.setLowPass(v, ambientCutoffHz, fade: settle);
    });
  }

  // ---------------------------------------------------------------------------
  // Clips (games music/effects, adhan) – additive API beyond SoundService.

  /// Loads an arbitrary audio file (WAV/MP3/FLAC…) for [playClip]. Returns
  /// `null` when silent or on failure.
  Future<SoundClip?> loadClip(String name, Uint8List bytes) async {
    if (_status == SoundEngineStatus.idle || _status == SoundEngineStatus.starting) await init();
    if (_status != SoundEngineStatus.ready) return null;
    try {
      final src = await _engine.load('madar/clip/$name#${_loadSeq++}', bytes);
      return SoundClip._(src, name, _durationOf(bytes));
    } catch (e) {
      _log('clip load failed: $name', e);
      return null;
    }
  }

  /// Plays [clip] on [category]'s bus. Returns a voice id for [stopClip],
  /// or `null` if nothing plays. The adhan may pass [bypassGlobalSwitch] so
  /// it stays audible when interface sounds are switched off.
  int? playClip(
    SoundClip clip, {
    SoundCategory category = SoundCategory.games,
    double volume = 1.0,
    double pitch = 1.0,
    double pan = 0.0,
    bool loop = false,
    bool bypassGlobalSwitch = false,
  }) {
    if (_status != SoundEngineStatus.ready) return null;
    final v = volume.clamp(0.0, 1.0);
    final voice = _engine.play(
      clip.source,
      volume: busGain(category, bypassGlobalSwitch: bypassGlobalSwitch) * v,
      pan: pan.clamp(-1.0, 1.0),
      speed: pitch.clamp(0.5, 2.0),
      looping: loop,
      protect: loop || category == SoundCategory.prayer,
    );
    if (voice < 0) return null;
    _pruneClipVoices();
    _clipVoices[voice] = _ClipVoice(category, v, bypassGlobalSwitch, loop ? null : clip.duration, _clock());
    return voice;
  }

  void stopClip(int voice, {Duration fade = const Duration(milliseconds: 80)}) {
    if (_clipVoices.remove(voice) == null || _status != SoundEngineStatus.ready) return;
    _engine.fadeVolume(voice, 0, fade);
    _engine.stopAfter(voice, fade + const Duration(milliseconds: 10));
  }

  Future<void> unloadClip(SoundClip clip) async {
    if (_status != SoundEngineStatus.ready) return;
    await _safe(() => _engine.unload(clip.source));
  }

  void _pruneClipVoices() {
    final now = _clock();
    _clipVoices.removeWhere((_, c) => c.length != null && now - c.started > c.length! + const Duration(milliseconds: 200));
  }

  void _refreshClipVoices() {
    if (_status != SoundEngineStatus.ready) return;
    _pruneClipVoices();
    for (final MapEntry(key: voice, value: c) in _clipVoices.entries) {
      _engine.fadeVolume(voice, busGain(c.category, bypassGlobalSwitch: c.bypass) * c.volume, const Duration(milliseconds: 150));
    }
  }

  // ---------------------------------------------------------------------------

  void _unloadLater(Iterable<int> sources, Duration delay) {
    final list = sources.toList(growable: false);
    if (list.isEmpty) return;
    void run() {
      if (_status != SoundEngineStatus.ready) return;
      for (final s in list) {
        unawaited(_safe(() => _engine.unload(s)));
      }
    }

    if (delay == Duration.zero) {
      run();
      return;
    }
    late final Timer t;
    t = _timer(delay, () {
      _timers.remove(t);
      run();
    });
    _timers.add(t);
  }

  static Duration? _durationOf(Uint8List bytes) {
    try {
      return Wav.parse(bytes).duration;
    } catch (_) {
      return null;
    }
  }

  static Future<void> _safe(Future<void> Function() f) async {
    try {
      await f();
    } catch (e) {
      _log('engine call failed', e);
    }
  }

  static void _log(String what, Object e) {
    if (kDebugMode) debugPrint('SoloudSoundService: $what: $e');
  }
}

final class _ClipVoice {
  _ClipVoice(this.category, this.volume, this.bypass, this.length, this.started);

  final SoundCategory category;
  final double volume;
  final bool bypass;
  final Duration? length;
  final Duration started;
}

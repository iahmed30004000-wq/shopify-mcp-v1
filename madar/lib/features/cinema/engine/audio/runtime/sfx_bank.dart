import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../../core/sound/synth/rng.dart';
import '../../../../../core/sound/synth/wav.dart';
import '../../core/audio.dart';
import '../sfx/sfx_synth.dart';
import 'cue_source.dart';
import 'mixer.dart';

/// The era's procedural sound-effect kit on the games bus.
///
/// * Rendered once per game on a background isolate, then played with one
///   mixer call per trigger (no allocation in steady state).
/// * Each call varies the pitch by ±3 % (on top of the caller's [pitch])
///   so repeated effects never sound machine-gunned; polyphony is capped per
///   sound (the oldest voice is faded out) and retriggers closer than a few
///   milliseconds are dropped.
/// * Gain = games bus (sound switch × games volume × prayer mute) × volume;
///   prayer mute also cuts any effect still ringing.
final class ProceduralSfxBank implements SfxBank {
  ProceduralSfxBank(this.context, {CinemaMixer? mixer, CueSource? source, Duration Function()? clock})
    : mixer = mixer ?? mixerFor(context.sound),
      source = source ?? CachingCueSource.shared,
      _clock = clock ?? _stopwatch(),
      _rng = SynthRandom(context.seed ^ 0x5FB);

  final CinemaAudioContext context;
  final CinemaMixer mixer;
  final CueSource source;
  final Duration Function() _clock;
  final SynthRandom _rng;

  /// Effects level under the games bus gain.
  static const double level = 0.95;

  /// Random pitch spread per call (±).
  static const double pitchSpread = 0.03;

  bool _ready = false;
  bool _disposed = false;
  bool _prayerMuted = false;
  Future<void>? _preparing;
  final Map<String, _Clip> _clips = {};

  static Duration Function() _stopwatch() {
    final sw = Stopwatch()..start();
    return () => sw.elapsed;
  }

  /// Keys currently loaded (tests / diagnostics).
  Iterable<String> get loadedKeys => _clips.keys;

  @override
  Future<void> prepare() => _preparing ??= _prepare();

  Future<void> _prepare() async {
    if (!mixer.isLive || _disposed) {
      _ready = true;
      return;
    }
    await _loadKit();
    _ready = true;
  }

  bool _kitRequested = false;

  Future<void> _loadKit() async {
    if (_kitRequested) return;
    _kitRequested = true;
    try {
      final kit = await source.renderSfx(context.era, 1);
      for (final e in kit.entries) {
        if (_disposed) break;
        final id = await mixer.load('sfx-${context.era.name}-${e.key}', e.value);
        if (id == null) continue;
        _clips[e.key] = _Clip(id, _lengthOf(e.value), _maxVoices(e.key), _minGap(e.key));
      }
    } catch (e) {
      if (kDebugMode) debugPrint('ProceduralSfxBank: kit failed: $e');
    }
    if (_disposed) _unloadAll();
  }

  @override
  bool get isReady => _ready;

  @override
  void play(CinemaSound sound, {double volume = 1, double pitch = 1, double pan = 0}) =>
      _play(sfxKey(sound), volume: volume, pitch: pitch, pan: pan);

  /// Plays one of the extra effects (crowd, whistle, gong…).
  void playExtra(CinemaSfx sound, {double volume = 1, double pitch = 1, double pan = 0}) =>
      _play(extraKey(sound), volume: volume, pitch: pitch, pan: pan);

  void _play(String key, {required double volume, required double pitch, required double pan}) {
    if (!_ready || _disposed || _prayerMuted) return;
    final clip = _clips[key];
    if (clip == null) {
      // Sound came up after prepare(): fetch the kit now (it plays from the
      // next trigger on).
      if (!_kitRequested && mixer.isLive) unawaited(_loadKit());
      return;
    }
    final gain = mixer.gamesGain * level * volume.clamp(0.0, 1.0);
    if (gain <= 0.0005) return;
    final now = _clock();
    if (clip.lastStart != null && now - clip.lastStart! < clip.minGap) return;
    clip.prune(now);
    if (clip.voices.length >= clip.maxVoices) {
      final oldest = clip.voices.removeAt(0);
      mixer.fade(oldest.$1, 0, const Duration(milliseconds: 15), thenStop: true);
    }
    final p = (pitch.isNaN ? 1.0 : pitch) * (1 + pitchSpread * _rng.bipolar());
    final v = mixer.play(clip.source, volume: gain, pan: pan.isNaN ? 0 : pan.clamp(-1.0, 1.0), speed: p.clamp(0.5, 2.0));
    clip.lastStart = now;
    if (v >= 0) clip.voices.add((v, now));
  }

  @override
  void setPrayerMuted(bool muted) {
    if (_prayerMuted == muted) return;
    _prayerMuted = muted;
    if (!muted) return;
    for (final c in _clips.values) {
      for (final (v, _) in c.voices) {
        mixer.fade(v, 0, const Duration(milliseconds: 120), thenStop: true);
      }
      c.voices.clear();
    }
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _unloadAll();
  }

  void _unloadAll() {
    for (final c in _clips.values) {
      for (final (v, _) in c.voices) {
        mixer.stop(v);
      }
      mixer.unload(c.source);
    }
    _clips.clear();
  }

  static Duration _lengthOf(Uint8List wav) {
    try {
      return Wav.parse(wav).duration;
    } catch (_) {
      return const Duration(seconds: 1);
    }
  }

  static int _maxVoices(String key) => switch (key) {
    'sound:explosion' || 'extra:crowdCheer' || 'extra:crowdAww' || 'extra:applause' || 'extra:gong' => 2,
    'sound:projector' || 'extra:drumroll' => 1,
    'sound:tick' || 'sound:typewriter' || 'sound:tap' || 'sound:coin' || 'sound:cardDeal' || 'sound:piecePlace' => 4,
    _ => 3,
  };

  static Duration _minGap(String key) => switch (key) {
    'sound:explosion' => const Duration(milliseconds: 60),
    'sound:tick' || 'sound:typewriter' => const Duration(milliseconds: 25),
    'sound:projector' || 'extra:drumroll' => const Duration(milliseconds: 300),
    _ => const Duration(milliseconds: 20),
  };
}

final class _Clip {
  _Clip(this.source, this.length, this.maxVoices, this.minGap);

  final int source;
  final Duration length;
  final int maxVoices;
  final Duration minGap;
  final List<(int, Duration)> voices = [];
  Duration? lastStart;

  void prune(Duration now) {
    while (voices.isNotEmpty && now - voices.first.$2 > length) {
      voices.removeAt(0);
    }
  }
}

/// Plays an extra effect on any [SfxBank] (silently ignored by banks that
/// do not have the extras, e.g. test fakes).
extension CinemaSfxExtras on SfxBank {
  void playExtra(CinemaSfx sound, {double volume = 1, double pitch = 1, double pan = 0}) {
    final self = this;
    if (self is ProceduralSfxBank) self.playExtra(sound, volume: volume, pitch: pitch, pan: pan);
  }
}

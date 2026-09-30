import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../core/audio.dart';
import '../music/score.dart';
import '../music/stingers.dart';
import '../synth/renderer.dart';
import 'cue_source.dart';
import 'mixer.dart';

/// The Film Reel Engine's conductor: procedurally composed, period-styled
/// cues with adaptive layers, bar-quantised cross-fades and on-the-beat
/// stingers transposed onto the sounding chord.
///
/// * Every mood is composed and rendered on a background isolate the first
///   time it is wanted (the opening mood first), then kept in a small LRU
///   under [budgetBytes]; the rest are prefetched one at a time.
/// * Each cue is 2–4 stems (bed / lead / hot…) scheduled on the mixer's
///   engine clock so they stay sample-locked; [setIntensity] fades layers.
/// * A new mood starts on the next bar line (a jingle on the next beat);
///   the old one fades out around it.
/// * The games bus gain (sound switch, games volume, prayer mute) is polled
///   in [update] and followed with short fades; prayer mute also silences
///   stingers, and the bed resumes where it is afterwards.
/// * No timers: all scheduling happens in [update] from the game loop.
final class ProceduralMusicDirector implements MusicDirector {
  ProceduralMusicDirector(
    this.context, {
    CinemaMixer? mixer,
    CueSource? source,
    this.budgetBytes = 24 << 20,
    this.prefetch = true,
  }) : mixer = mixer ?? mixerFor(context.sound),
       source = source ?? CachingCueSource.shared;

  final CinemaAudioContext context;
  final CinemaMixer mixer;
  final CueSource source;

  /// Memory cap for loaded cues (bytes of 16-bit PCM kept by the mixer).
  final int budgetBytes;

  /// Render the other moods in the background after the first one.
  final bool prefetch;

  /// Music level under the games bus gain (leaves room for effects).
  static const double level = 0.8;

  /// Pause-menu duck (−12 dB).
  static const double duckGain = 0.25;
  static const double stingerLevel = 0.9;

  /// Scheduling lead: comfortably more than one mix buffer.
  static const Duration lead = Duration(milliseconds: 60);

  /// Longest wait for a bar line before falling back to the next beat.
  static const Duration maxBarWait = Duration(milliseconds: 2400);

  /// Prefetch order after the opening cue.
  static const prefetchOrder = [
    MusicMood.adventure,
    MusicMood.action,
    MusicMood.tension,
    MusicMood.boss,
    MusicMood.victory,
    MusicMood.defeat,
    MusicMood.calm,
    MusicMood.title,
  ];

  /// Diagnostics (bounded): "start adventure intro", "stinger hit +5" …
  final List<String> log = [];

  bool _disposed = false;
  bool _ready = false;
  Future<void>? _preparing;
  MusicMood? _mood;
  double _intensity = 0.5;
  bool _ducked = false;
  bool _prayerMuted = false;
  bool _paused = false;
  double _lastGain = -1;
  _Pending? _pending;
  _Playback? _current;
  final List<_Playback> _fading = [];
  final List<Stinger> _stingerQueue = [];
  final List<(int, Duration)> _stingerVoices = [];
  final Map<MusicMood, _LoadedCue> _cues = {};
  final List<MusicMood> _renderQueue = [];
  MusicMood? _rendering;
  _LoadedStingers? _stingers;
  int _clock = 0;
  final Completer<void> _firstCue = Completer<void>();

  bool get _live => mixer.isLive && !_disposed;

  // ---------------------------------------------------------------------------
  // MusicDirector

  @override
  Future<void> prepare() => _preparing ??= _prepare();

  Future<void> _prepare() async {
    if (!_live) {
      _ready = true;
      return;
    }
    final stingers = _ensureStingers();
    // Whatever was cued first renders first; otherwise start with the
    // main gameplay mood.
    _want(_pending?.mood ?? _mood ?? MusicMood.adventure, urgent: true);
    await Future.wait([stingers, _firstCue.future]);
    _ready = true;
    _service();
  }

  @override
  bool get isReady => _ready;

  @override
  MusicMood? get mood => _mood;

  @override
  double get intensity => _intensity;

  @override
  void cue(MusicMood mood, {double intensity = 0.5, Duration fade = const Duration(milliseconds: 600)}) {
    if (_disposed) return;
    _intensity = intensity.clamp(0.0, 1.0);
    _note('cue ${mood.name} ${_intensity.toStringAsFixed(2)}');
    if (_mood == mood && (_current?.mood == mood || _pending?.mood == mood)) {
      _applyVolumes(const Duration(milliseconds: 900));
      return;
    }
    _mood = mood;
    _pending = _Pending(mood, fade);
    if (_live) {
      unawaited(_ensureStingers());
      _want(mood, urgent: true);
      _service();
    }
  }

  @override
  void setIntensity(double intensity) {
    final v = intensity.clamp(0.0, 1.0);
    if ((v - _intensity).abs() < 1e-4) return;
    _intensity = v;
    _applyVolumes(const Duration(milliseconds: 900));
  }

  @override
  void stinger(Stinger stinger) {
    if (_disposed || _prayerMuted || !_live) return;
    if (_stingerQueue.length < 4) _stingerQueue.add(stinger);
  }

  @override
  void setDucked(bool ducked) {
    if (_ducked == ducked) return;
    _ducked = ducked;
    _applyVolumes(const Duration(milliseconds: 300));
  }

  @override
  void setPrayerMuted(bool muted) {
    if (_prayerMuted == muted) return;
    _prayerMuted = muted;
    if (muted) {
      _stingerQueue.clear();
      for (final (v, _) in _stingerVoices) {
        mixer.fade(v, 0, const Duration(milliseconds: 120), thenStop: true);
      }
      _stingerVoices.clear();
    }
    _applyVolumes(muted ? const Duration(milliseconds: 400) : const Duration(milliseconds: 900));
  }

  @override
  void pause() {
    if (_paused || _disposed) return;
    _paused = true;
    final cur = _current;
    if (cur != null) {
      _fadeOut(cur, const Duration(milliseconds: 80), mixer.now);
      _current = null;
      // Resume re-enters the loop (no intro) once back – unless another
      // cue was already on its way.
      _pending ??= _Pending(cur.mood, const Duration(milliseconds: 700), skipIntro: true);
    }
  }

  @override
  void resume() {
    if (!_paused || _disposed) return;
    _paused = false;
    _service();
  }

  @override
  void update(double dt) {
    if (_disposed) return;
    _service();
  }

  @override
  void stop({Duration fade = const Duration(milliseconds: 400)}) {
    _note('stop');
    _mood = null;
    _pending = null;
    _stingerQueue.clear();
    final cur = _current;
    _current = null;
    if (cur != null && mixer.isLive) _fadeOut(cur, fade, mixer.now);
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    if (!_firstCue.isCompleted) _firstCue.complete();
    for (final p in [?_current, ..._fading]) {
      for (final v in p.voices) {
        mixer.stop(v.voice);
      }
    }
    for (final (v, _) in _stingerVoices) {
      mixer.stop(v);
    }
    _current = null;
    _fading.clear();
    _stingerVoices.clear();
    for (final c in _cues.values) {
      c.unload(mixer);
    }
    _cues.clear();
    _stingers?.unload(mixer);
    _stingers = null;
  }

  // ---------------------------------------------------------------------------
  // Diagnostics for tests and debug overlays.

  /// Moods currently loaded in the mixer.
  Iterable<MusicMood> get loadedMoods => _cues.keys;

  /// Bytes of audio currently loaded.
  int get loadedBytes => _cues.values.fold(0, (a, c) => a + c.bytes);

  /// The mood that is actually sounding (null while waiting for a render).
  MusicMood? get playingMood => _current?.mood;

  // ---------------------------------------------------------------------------
  // Scheduling

  void _service() {
    if (!_live) return;
    final g = mixer.gamesGain;
    if ((g - _lastGain).abs() > 0.001) {
      final first = _lastGain < 0;
      _lastGain = g;
      if (!first) _applyVolumes(const Duration(milliseconds: 150));
    }
    final p = _pending;
    if (p != null && !_paused) {
      final cue = _cues[p.mood];
      if (cue != null) {
        _pending = null;
        _start(cue, p);
      }
    }
    if (_stingerQueue.isNotEmpty) _playStingers();
    if (_fading.isNotEmpty) {
      final now = mixer.now;
      _fading.removeWhere((f) => f.endsAt != null && now > f.endsAt!);
    }
  }

  void _start(_LoadedCue cue, _Pending p) {
    final now = mixer.now;
    final cur = _current;
    final jingle = !cue.info.loops;
    var at = now + lead;
    if (cur != null) {
      at = jingle ? cur.nextBeat(now + lead) : cur.nextBar(now + lead);
      if (at - now > maxBarWait) at = cur.nextBeat(now + lead);
    }
    final gameplay = p.mood == MusicMood.adventure || p.mood == MusicMood.action || p.mood == MusicMood.tension || p.mood == MusicMood.calm;
    final withIntro = cue.info.introSeconds > 0 && !p.skipIntro && (jingle || cur == null || !gameplay);
    final introLen = withIntro ? _dur(cue.info.introSeconds) : Duration.zero;
    final pb = _Playback(cue, p.mood, loopAt: at + introLen, info: cue.info);
    final fadeIn = withIntro || p.fade < const Duration(milliseconds: 60)
        ? const Duration(milliseconds: 20)
        : Duration(microseconds: p.fade.inMicroseconds ~/ 2);
    for (var i = 0; i < cue.stems.length; i++) {
      final s = cue.stems[i];
      final target = _target(s.spec, jingle);
      if (withIntro && s.intro != null) {
        final v = mixer.play(s.intro!, volume: 0, pan: s.spec.pan, at: at, protect: true);
        if (v >= 0) {
          mixer.fade(v, target, fadeIn, at: at);
          pb.voices.add(_Voice(v, s.spec));
        }
      }
      final lv = mixer.play(s.loop, volume: 0, pan: s.spec.pan, loop: true, at: pb.loopAt, protect: true);
      if (lv >= 0) {
        mixer.fade(lv, target, withIntro ? const Duration(milliseconds: 8) : fadeIn, at: pb.loopAt);
        pb.voices.add(_Voice(lv, s.spec));
      }
    }
    if (cur != null) {
      final half = Duration(microseconds: p.fade.inMicroseconds ~/ 2);
      var fadeAt = at - half;
      if (fadeAt < now) fadeAt = now;
      _fadeOut(cur, p.fade < const Duration(milliseconds: 20) ? const Duration(milliseconds: 20) : p.fade, fadeAt);
    }
    cue.lastUsed = ++_clock;
    _current = pb;
    _note('start ${p.mood.name}${withIntro ? ' intro' : ''} +${((at - now).inMilliseconds)}ms');
  }

  void _fadeOut(_Playback pb, Duration fade, Duration at) {
    for (final v in pb.voices) {
      mixer.fade(v.voice, 0, fade, at: at, thenStop: true);
    }
    pb.endsAt = at + fade + const Duration(milliseconds: 50);
    _fading.add(pb);
  }

  double _target(StemSpec spec, bool jingle) {
    if (_prayerMuted) return 0;
    final layer = spec.layerGain(jingle ? math.max(_intensity, 0.9) : _intensity);
    return (level * spec.gain * layer * (_ducked ? duckGain : 1.0) * mixer.gamesGain).clamp(0.0, 1.0);
  }

  void _applyVolumes(Duration fade) {
    final cur = _current;
    if (cur == null || !_live) return;
    final jingle = !cur.info.loops;
    for (final v in cur.voices) {
      mixer.fade(v.voice, _target(v.spec, jingle), fade);
    }
  }

  void _playStingers() {
    final kit = _stingers;
    final pendingJingle = _pending != null && (_pending!.mood == MusicMood.victory || _pending!.mood == MusicMood.defeat);
    final curJingle = _current != null && !_current!.info.loops && mixer.now < _current!.loopAt;
    for (final s in _stingerQueue) {
      // The victory / defeat jingles open with their own hit.
      if ((s == Stinger.victory || s == Stinger.defeat) && (pendingJingle || curJingle)) {
        _note('stinger ${s.name} (in jingle)');
        continue;
      }
      if (kit == null || _prayerMuted) continue;
      final clips = kit.kit.clips[s];
      if (clips == null) continue;
      final now = mixer.now;
      final cur = _current;
      var at = now + const Duration(milliseconds: 40);
      var semis = 0;
      var minor = context.score.minor;
      if (cur != null && now >= cur.startAt) {
        at = cur.nextBeat(at);
        if (at - now > const Duration(milliseconds: 450)) at = cur.nextHalfBeat(now + const Duration(milliseconds: 40));
        final chord = cur.info.chordAt(cur.beatAt(at));
        if (chord != null && clips.tonal) {
          semis = ((chord.rootPc - kit.kit.keyPc) % 12 + 12) % 12;
          if (semis > 6) semis -= 12;
          minor = chord.minor;
        }
      }
      final vol = (mixer.gamesGain * stingerLevel * (_ducked ? 0.5 : 1.0)).clamp(0.0, 1.0);
      if (vol <= 0.0005) continue;
      final tonal = minor ? kit.minor[s] : kit.major[s];
      final speed = math.pow(2.0, semis / 12.0).toDouble();
      if (tonal != null) _trackStinger(mixer.play(tonal, volume: vol, speed: speed, at: at), at);
      final drums = kit.drums[s];
      if (drums != null) _trackStinger(mixer.play(drums, volume: vol, at: at), at);
      _note('stinger ${s.name} ${semis >= 0 ? '+' : ''}$semis${minor ? 'm' : ''}');
    }
    _stingerQueue.clear();
  }

  void _trackStinger(int voice, Duration at) {
    if (voice < 0) return;
    _stingerVoices.add((voice, at));
    while (_stingerVoices.length > 4) {
      final (old, _) = _stingerVoices.removeAt(0);
      mixer.fade(old, 0, const Duration(milliseconds: 30), thenStop: true);
    }
  }

  // ---------------------------------------------------------------------------
  // Rendering and loading

  Future<void>? _stingerLoad;

  /// Loads the stinger kit once (also when sound comes up after prepare).
  Future<void> _ensureStingers() => _stingerLoad ??= _loadStingers();

  Future<void> _loadStingers() async {
    try {
      final kit = await source.renderStingers(context.score, 1);
      if (_disposed) return;
      final loaded = _LoadedStingers(kit);
      for (final e in kit.clips.entries) {
        final c = e.value;
        final n = e.key.name;
        if (c.major != null) loaded.major[e.key] = await mixer.load('stinger-$n-maj', c.major!);
        if (c.minor != null) {
          loaded.minor[e.key] = identical(c.minor, c.major) ? loaded.major[e.key] : await mixer.load('stinger-$n-min', c.minor!);
        }
        if (c.drums != null) loaded.drums[e.key] = await mixer.load('stinger-$n-drums', c.drums!);
        if (_disposed) break;
      }
      if (_disposed) {
        loaded.unload(mixer);
        return;
      }
      _stingers = loaded;
    } catch (e) {
      _warn('stingers', e);
    }
  }

  void _want(MusicMood mood, {bool urgent = false}) {
    if (_cues.containsKey(mood) || _rendering == mood) return;
    _renderQueue.remove(mood);
    if (urgent) {
      _renderQueue.insert(0, mood);
    } else {
      _renderQueue.add(mood);
    }
    _pump();
  }

  void _pump() {
    if (_rendering != null || _renderQueue.isEmpty || _disposed) return;
    final mood = _renderQueue.removeAt(0);
    _rendering = mood;
    unawaited(_render(mood));
  }

  Future<void> _render(MusicMood mood) async {
    try {
      final r = await source.renderCue(context.score, mood, context.seed);
      if (_disposed) return;
      _makeRoom(r.bytes, keep: mood);
      final loaded = await _LoadedCue.load(mixer, r);
      if (_disposed) {
        loaded?.unload(mixer);
        return;
      }
      if (loaded != null) {
        loaded.lastUsed = ++_clock;
        _cues[mood] = loaded;
        _note('loaded ${mood.name} ${(r.bytes / 1e6).toStringAsFixed(1)}MB ${r.renderMs}ms');
      }
    } catch (e) {
      _warn('render ${mood.name}', e);
    } finally {
      _rendering = null;
      // prepare() waits for the first render, successful or not.
      if (!_firstCue.isCompleted) _firstCue.complete();
    }
    if (_disposed) return;
    _service();
    if (prefetch) {
      for (final m in prefetchOrder) {
        if (_cues.containsKey(m) || _renderQueue.contains(m)) continue;
        if (loadedBytes + _estimate(m) > budgetBytes) break;
        _renderQueue.add(m);
      }
    }
    _pump();
  }

  int _estimate(MusicMood m) {
    if (_cues.isEmpty) return 0;
    return _cues.values.fold(0, (a, c) => a + c.bytes) ~/ _cues.length;
  }

  /// Evicts least-recently-used cues (never the playing or wanted one).
  void _makeRoom(int incoming, {required MusicMood keep}) {
    while (loadedBytes + incoming > budgetBytes) {
      final protected = {keep, ?_current?.mood, ?_pending?.mood, for (final f in _fading) f.mood};
      final victims = _cues.entries.where((e) => !protected.contains(e.key)).toList()
        ..sort((a, b) => a.value.lastUsed.compareTo(b.value.lastUsed));
      if (victims.isEmpty) return;
      final v = victims.first;
      v.value.unload(mixer);
      _cues.remove(v.key);
      _note('evict ${v.key.name}');
    }
  }

  static Duration _dur(double seconds) => Duration(microseconds: (seconds * 1e6).round());

  void _note(String s) {
    if (log.length >= 200) log.removeRange(0, 100);
    log.add(s);
  }

  static void _warn(String what, Object e) {
    if (kDebugMode) debugPrint('ProceduralMusicDirector: $what failed: $e');
  }
}

final class _Pending {
  _Pending(this.mood, this.fade, {this.skipIntro = false});

  final MusicMood mood;
  final Duration fade;
  final bool skipIntro;
}

final class _Voice {
  _Voice(this.voice, this.spec);

  final int voice;
  final StemSpec spec;
}

/// One cue sounding on the engine clock.
final class _Playback {
  _Playback(this.cue, this.mood, {required this.loopAt, required this.info})
    : startAt = loopAt - Duration(microseconds: (info.introSeconds * 1e6).round());

  final _LoadedCue cue;
  final MusicMood mood;
  final CueInfo info;

  /// Engine time the loop (first pass) starts; bar lines sit at
  /// `loopAt + k · bar` for every integer k (intros are whole bars).
  final Duration loopAt;

  /// Approximate start (intro start when an intro plays).
  final Duration startAt;
  final List<_Voice> voices = [];
  Duration? endsAt;

  double beatAt(Duration t) => (t - loopAt).inMicroseconds / 1e6 / info.beatSeconds;

  Duration _grid(Duration t, double unit) {
    final rel = (t - loopAt).inMicroseconds / 1e6;
    final k = (rel / unit - 1e-6).ceilToDouble();
    return loopAt + Duration(microseconds: (k * unit * 1e6).round());
  }

  Duration nextBar(Duration t) => _grid(t, info.barSeconds);
  Duration nextBeat(Duration t) => _grid(t, info.beatSeconds);
  Duration nextHalfBeat(Duration t) => _grid(t, info.beatSeconds / 2);
}

final class _StemSources {
  _StemSources(this.spec, this.intro, this.loop);

  final StemSpec spec;
  final int? intro;
  final int loop;
}

final class _LoadedCue {
  _LoadedCue(this.info, this.stems, this.bytes);

  final CueInfo info;
  final List<_StemSources> stems;
  final int bytes;
  int lastUsed = 0;

  static Future<_LoadedCue?> load(CinemaMixer mixer, RenderedCue r) async {
    final stems = <_StemSources>[];
    final loadedIds = <int>[];
    final tag = '${r.info.style.name}-${r.info.mood.name}';
    for (var i = 0; i < r.stems.length; i++) {
      final s = r.stems[i];
      int? intro;
      if (s.intro != null) {
        intro = await mixer.load('$tag-${s.spec.name}-intro', s.intro!, stream: true);
        if (intro == null) break;
        loadedIds.add(intro);
      }
      final loop = await mixer.load('$tag-${s.spec.name}-loop', s.loop, stream: true);
      if (loop == null) break;
      loadedIds.add(loop);
      stems.add(_StemSources(s.spec, intro, loop));
    }
    if (stems.length != r.stems.length) {
      for (final id in loadedIds) {
        mixer.unload(id);
      }
      return null;
    }
    return _LoadedCue(r.info, stems, r.bytes);
  }

  void unload(CinemaMixer mixer) {
    for (final s in stems) {
      if (s.intro != null) mixer.unload(s.intro!);
      mixer.unload(s.loop);
    }
  }
}

final class _LoadedStingers {
  _LoadedStingers(this.kit);

  final StingerKit kit;
  final Map<Stinger, int?> major = {}, minor = {}, drums = {};

  void unload(CinemaMixer mixer) {
    for (final id in {...major.values, ...minor.values, ...drums.values}) {
      if (id != null) mixer.unload(id);
    }
  }
}

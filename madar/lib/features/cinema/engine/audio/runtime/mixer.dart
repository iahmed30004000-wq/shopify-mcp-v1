import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

import '../../../../../core/sound/soloud_sound_service.dart';
import '../../../../../core/sound/sound_api.dart';

/// The slice of a sample-accurate mixer the cinema audio needs. Sources
/// and voices are plain ints so the director and the SFX bank can be unit
/// tested against a fake clock ([FakeCinemaMixer] in the tests).
///
/// Implementations never throw from the synchronous calls.
abstract interface class CinemaMixer {
  /// True when sound can actually be heard (engine up). When false every
  /// call is a cheap no-op and nothing is rendered.
  bool get isLive;

  /// Effective gain of the games bus right now: global switch × prayer
  /// mute × games volume.
  double get gamesGain;

  /// The engine clock that [play] `at:` times refer to.
  Duration get now;

  /// Loads a PCM WAV. [stream] keeps it compressed (16-bit) in memory and
  /// decodes while playing (long music stems); otherwise it is decoded up
  /// front (short effects, lowest latency). Returns null on failure.
  Future<int?> load(String name, Uint8List wav, {bool stream = false});

  void unload(int source);

  /// Starts [source] now, or sample-accurately at engine time [at].
  /// Returns a voice id (−1 when nothing plays).
  int play(int source, {double volume = 1, double pan = 0, double speed = 1, bool loop = false, Duration? at, bool protect = false});

  /// Moves the voice's volume to [to] over [over], starting at engine time
  /// [at] (default: now). With [thenStop] the voice stops when the fade ends.
  void fade(int voice, double to, Duration over, {Duration? at, bool thenStop = false});

  void stop(int voice);
}

/// Mixer for silent contexts (tests, no audio device): never live.
final class SilentCinemaMixer implements CinemaMixer {
  const SilentCinemaMixer();

  @override
  bool get isLive => false;
  @override
  double get gamesGain => 0;
  @override
  Duration get now => Duration.zero;
  @override
  Future<int?> load(String name, Uint8List wav, {bool stream = false}) async => null;
  @override
  void unload(int source) {}
  @override
  int play(int source, {double volume = 1, double pan = 0, double speed = 1, bool loop = false, Duration? at, bool protect = false}) => -1;
  @override
  void fade(int voice, double to, Duration over, {Duration? at, bool thenStop = false}) {}
  @override
  void stop(int voice) {}
}

/// [CinemaMixer] on flutter_soloud, gated by [SoloudSoundService]'s games
/// bus. Music is scheduled on SoLoud's engine clock (`playScheduled`,
/// `fadeScheduled`), so stems start together to the sample and stingers land
/// exactly on the beat.
final class SoloudCinemaMixer implements CinemaMixer {
  SoloudCinemaMixer(this.service);

  final SoloudSoundService service;

  SoLoud get _s => SoLoud.instance;
  final Map<int, AudioSource> _sources = {};
  final Map<int, SoundHandle> _voices = {};
  int _nextSource = 0;
  int _seq = 0;

  @override
  bool get isLive {
    if (service.status != SoundEngineStatus.ready) return false;
    try {
      return _s.isInitialized;
    } catch (_) {
      return false;
    }
  }

  @override
  double get gamesGain => service.busGain(SoundCategory.games);

  @override
  Duration get now {
    try {
      return _s.getEngineTime();
    } catch (_) {
      return Duration.zero;
    }
  }

  @override
  Future<int?> load(String name, Uint8List wav, {bool stream = false}) async {
    if (!isLive) return null;
    try {
      final src = await _s.loadMem('madar/cinema/$name#${_seq++}.wav', wav, mode: stream ? LoadMode.disk : LoadMode.memory);
      final id = _nextSource++;
      _sources[id] = src;
      return id;
    } catch (e) {
      _log('load $name', e);
      return null;
    }
  }

  @override
  void unload(int source) {
    final src = _sources.remove(source);
    if (src == null) return;
    try {
      unawaited(_s.disposeSource(src).catchError((Object e) => _log('unload', e)));
    } catch (e) {
      _log('unload', e);
    }
  }

  @override
  int play(int source, {double volume = 1, double pan = 0, double speed = 1, bool loop = false, Duration? at, bool protect = false}) {
    final src = _sources[source];
    if (src == null || !isLive) return -1;
    try {
      final v = volume.clamp(0.0, 1.0);
      final p = pan.clamp(-1.0, 1.0);
      final sp = speed.clamp(0.5, 2.0);
      final SoundHandle h;
      if (at == null) {
        h = _s.play(src, volume: v, pan: p, looping: loop, scale: sp);
      } else {
        h = _s.playScheduled(src, at, volume: v, pan: p, scale: sp, looping: loop);
      }
      if (h.isError) return -1;
      if (protect) _s.setProtectVoice(h, true);
      if (_voices.length > 128) _voices.removeWhere((_, hh) => !_s.getIsValidVoiceHandle(hh));
      _voices[h.id] = h;
      return h.id;
    } catch (e) {
      _log('play', e);
      return -1;
    }
  }

  @override
  void fade(int voice, double to, Duration over, {Duration? at, bool thenStop = false}) {
    final h = _voices[voice];
    if (h == null) return;
    try {
      final v = to.clamp(0.0, 1.0);
      if (at != null || thenStop) {
        _s.fadeScheduled(h, at ?? now, v, over, thenStop: thenStop);
      } else if (over == Duration.zero) {
        _s.setVolume(h, v);
      } else {
        _s.fadeVolume(h, v, over);
      }
      if (thenStop) _voices.remove(voice);
    } catch (e) {
      _log('fade', e);
    }
  }

  @override
  void stop(int voice) {
    final h = _voices.remove(voice);
    if (h == null) return;
    try {
      unawaited(_s.stop(h).catchError((Object e) => _log('stop', e)));
    } catch (e) {
      _log('stop', e);
    }
  }

  static void _log(String op, Object e) {
    if (kDebugMode) debugPrint('SoloudCinemaMixer.$op failed: $e');
  }
}

/// The mixer for a [SoundService]: SoLoud when the app's real service is
/// running, silence otherwise.
CinemaMixer mixerFor(SoundService sound) => sound is SoloudSoundService ? SoloudCinemaMixer(sound) : const SilentCinemaMixer();

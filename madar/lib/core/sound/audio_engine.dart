import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

/// The narrow slice of a native mixer that [SoloudSoundService] needs.
///
/// Sources and voices are plain ints so the service logic (buses, polyphony,
/// prayer mute, swells, atomic profile swaps) can be unit-tested against a
/// fake engine without the native library.
///
/// Implementations must never throw from the synchronous per-voice calls –
/// a failed call is a silent no-op (UI feedback must never crash the app).
abstract interface class AudioEngine {
  /// Opens the output device. May throw; the service then degrades to silent.
  Future<void> init();

  /// Loads WAV bytes; returns a source id (≥ 0).
  Future<int> load(String name, Uint8List wav);

  Future<void> unload(int source);

  /// Must be called before [play] for voices of [source] to accept
  /// [setLowPass] (per-voice resonant low-pass).
  void enableLowPass(int source);

  /// Starts a voice; returns its id or −1 if nothing plays. [lowPassHz]
  /// (for sources passed to [enableLowPass]) sets the initial cutoff with a
  /// Butterworth (Q ≈ 0.707) response before the first sample is heard.
  int play(
    int source, {
    double volume = 1.0,
    double pan = 0.0,
    double speed = 1.0,
    bool looping = false,
    bool paused = false,
    bool protect = false,
    double? lowPassHz,
  });

  void setVolume(int voice, double volume);
  void fadeVolume(int voice, double to, Duration time);
  void setPaused(int voice, bool paused);

  void stop(int voice);

  /// Stops [voice] after [delay] (use after a fade-out).
  void stopAfter(int voice, Duration delay);

  /// Moves the voice's low-pass cutoff (Hz), optionally gliding.
  void setLowPass(int voice, double hz, {Duration fade = Duration.zero});

  /// Starts the output device ahead of the next sound (e.g. on resume) so
  /// the first tap is not delayed by device start-up.
  Future<void> prewarm();

  Future<void> shutdown();
}

/// [AudioEngine] backed by flutter_soloud 5.1 (`SoLoud.instance`).
final class SoloudAudioEngine implements AudioEngine {
  SoloudAudioEngine({
    this.sampleRate = 44100,
    this.bufferSize = 1024,
    this.maxVoices = 32,
    this.deviceIdleTimeout = const Duration(seconds: 30),
  });

  final int sampleRate;

  /// Mix buffer in frames – 1024 @ 44.1 kHz ≈ 23 ms, a good balance between
  /// tap latency and underrun safety on mid-range Android devices.
  final int bufferSize;
  final int maxVoices;

  /// How long the output device stays open after the last sound: long
  /// enough that a browsing session never pays the device start-up latency
  /// on a tap, short enough to release the audio wakelock soon after the
  /// user leaves (the ambient bed is paused in background).
  final Duration deviceIdleTimeout;

  SoLoud get _s => SoLoud.instance;
  final Map<int, AudioSource> _sources = {};
  final Map<int, (SoundHandle, int)> _voices = {};
  int _nextSource = 0;

  @override
  Future<void> init() async {
    _s.setAudioDeviceIdleTimeout(deviceIdleTimeout);
    if (!_s.isInitialized) {
      await _s.init(sampleRate: sampleRate, bufferSize: bufferSize, channels: Channels.stereo);
    }
    _s.setMaxActiveVoiceCount(maxVoices);
    // Last line of defence against summed voices clipping the output.
    try {
      final limiter = _s.filters.limiterFilter;
      if (!limiter.isActive) limiter.activate();
    } catch (e) {
      _log('limiter', e);
    }
  }

  @override
  Future<int> load(String name, Uint8List wav) async {
    final src = await _s.loadMem(name, wav);
    final id = _nextSource++;
    _sources[id] = src;
    return id;
  }

  @override
  Future<void> unload(int source) async {
    final src = _sources.remove(source);
    if (src == null) return;
    _voices.removeWhere((_, v) => v.$2 == source);
    try {
      await _s.disposeSource(src);
    } catch (e) {
      _log('unload', e);
    }
  }

  @override
  void enableLowPass(int source) {
    final src = _sources[source];
    if (src == null) return;
    try {
      final f = src.filters.biquadFilter;
      if (!f.isActive) f.activate();
    } catch (e) {
      _log('enableLowPass', e);
    }
  }

  @override
  int play(
    int source, {
    double volume = 1.0,
    double pan = 0.0,
    double speed = 1.0,
    bool looping = false,
    bool paused = false,
    bool protect = false,
    double? lowPassHz,
  }) {
    final src = _sources[source];
    if (src == null) return -1;
    try {
      final h = _s.play(src, volume: volume, pan: pan, looping: looping, paused: paused || lowPassHz != null, scale: speed);
      if (h.isError) return -1;
      if (protect) _s.setProtectVoice(h, true);
      if (lowPassHz != null) {
        try {
          final f = src.filters.biquadFilter;
          if (f.isActive) {
            f.type(soundHandle: h).value = 0; // low-pass
            f.resonance(soundHandle: h).value = 0.707;
            f.frequency(soundHandle: h).value = lowPassHz.clamp(20.0, 16000.0);
          }
        } catch (e) {
          _log('lowPass', e);
        }
        if (!paused) _s.setPause(h, false);
      }
      if (_voices.length > 256) _voices.removeWhere((_, v) => !_s.getIsValidVoiceHandle(v.$1));
      _voices[h.id] = (h, source);
      return h.id;
    } catch (e) {
      _log('play', e);
      return -1;
    }
  }

  void _withVoice(int voice, String op, void Function(SoundHandle h) f) {
    final v = _voices[voice];
    if (v == null) return;
    try {
      f(v.$1);
    } catch (e) {
      _log(op, e);
    }
  }

  @override
  void setVolume(int voice, double volume) => _withVoice(voice, 'setVolume', (h) => _s.setVolume(h, volume));

  @override
  void fadeVolume(int voice, double to, Duration time) => _withVoice(voice, 'fadeVolume', (h) => _s.fadeVolume(h, to, time));

  @override
  void setPaused(int voice, bool paused) => _withVoice(voice, 'setPaused', (h) {
        if (_s.getIsValidVoiceHandle(h)) _s.setPause(h, paused);
      });

  @override
  void stop(int voice) {
    final v = _voices.remove(voice);
    if (v == null) return;
    try {
      unawaited(_s.stop(v.$1).catchError((Object e) => _log('stop', e)));
    } catch (e) {
      _log('stop', e);
    }
  }

  @override
  void stopAfter(int voice, Duration delay) {
    _withVoice(voice, 'stopAfter', (h) => _s.scheduleStop(h, delay));
    _voices.remove(voice);
  }

  @override
  void setLowPass(int voice, double hz, {Duration fade = Duration.zero}) {
    final v = _voices[voice];
    if (v == null) return;
    final src = _sources[v.$2];
    if (src == null) return;
    try {
      final param = src.filters.biquadFilter.frequency(soundHandle: v.$1);
      final f = hz.clamp(20.0, 16000.0);
      if (fade == Duration.zero) {
        param.value = f;
      } else {
        param.fadeFilterParameter(to: f, time: fade);
      }
    } catch (e) {
      _log('setLowPass', e);
    }
  }

  @override
  Future<void> prewarm() async {
    try {
      if (_s.isInitialized) await _s.startAudioDevice();
    } catch (e) {
      _log('prewarm', e);
    }
  }

  @override
  Future<void> shutdown() async {
    _voices.clear();
    _sources.clear();
    try {
      if (_s.isInitialized) await _s.deinitAsync();
    } catch (e) {
      _log('shutdown', e);
    }
  }

  static void _log(String op, Object e) {
    if (kDebugMode) debugPrint('SoloudAudioEngine.$op failed: $e');
  }
}

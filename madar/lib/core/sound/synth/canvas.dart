import 'dart:math' as math;
import 'dart:typed_data';

import 'buffer.dart';
import 'dynamics.dart';
import 'reverb.dart';
import 'rng.dart';
import 'wav.dart';

/// A timeline on which a sound profile composes one UI sound.
///
/// Instruments render mono voices; [place] pans them into a stereo dry mix
/// and feeds a reverb send. [finish] then reverberates, trims the tail,
/// level-matches to a loudness target, limits to −1 dBFS and applies
/// click-free fades.
final class SfxCanvas {
  SfxCanvas({
    required this.sampleRate,
    required this.maxSeconds,
    required int seed,
    this.room = const ReverbSpec(),
    this.minSeconds = 0.04,
  })  : rng = SynthRandom(seed),
        _maxFrames = math.max(1, (maxSeconds * sampleRate).round()) {
    _dry = StereoBuffer(sampleRate, _maxFrames);
    _send = Float64List(_maxFrames);
  }

  final int sampleRate;

  /// Hard cap on the rendered length, reverb tail included.
  final double maxSeconds;
  final double minSeconds;
  final ReverbSpec room;

  /// Seeded randomness for noise, humanisation and scattering.
  final SynthRandom rng;

  final int _maxFrames;
  late final StereoBuffer _dry;
  late final Float64List _send;
  bool _usesReverb = false;

  /// Places a mono voice at [atSec] with [gain], equal-power [pan] (−1…1,
  /// optionally gliding to [panTo]) and a reverb [send] level.
  void place(Float64List voice, double atSec, {double gain = 1.0, double pan = 0.0, double? panTo, double send = 0.2}) {
    final at = (atSec * sampleRate).round();
    if (at >= _maxFrames) return;
    _dry.addMono(voice, offset: at, gain: gain, pan: pan, panTo: panTo);
    if (send > 0) {
      _usesReverb = true;
      final n = math.min(voice.length, _maxFrames - at);
      final g = gain * send;
      for (var i = 0; i < n; i++) {
        _send[at + i] += voice[i] * g;
      }
    }
  }

  /// Renders the final stereo buffer.
  ///
  /// [loudnessDb] is the target momentary loudness (see
  /// [Loudness.momentaryDb]); [wet] the reverb return level.
  StereoBuffer finish({required double loudnessDb, double wet = 1.0, double ceilingDb = -1.0}) {
    final mix = _dry;
    if (_usesReverb && wet > 0) {
      Reverb(sampleRate, room).process(_send, mix.left, mix.right, wet: wet);
    }
    // Trim to the audible tail (−66 dB below peak), keep ≥ minSeconds.
    final pk = mix.peak();
    if (pk <= 0) return mix.truncated(math.max(1, (minSeconds * sampleRate).round()));
    final end = mix.audibleEnd(pk * dbToGain(-66));
    final minFrames = (minSeconds * sampleRate).round();
    final fadeFrames = math.max((0.012 * sampleRate).round(), (end * 0.18).round());
    final length = math.min(_maxFrames, math.max(minFrames, end + (0.004 * sampleRate).round()));
    final out = mix.truncated(length)..fadeIn((0.0008 * sampleRate).round());
    // Level match, then guarantee the ceiling.
    final loud = Loudness.momentaryDb(out);
    if (loud.isFinite) out.scale(dbToGain(loudnessDb - loud));
    SoftLimiter(ceilingDb: ceilingDb).process(out);
    out.fadeOut(math.min(fadeFrames, length ~/ 2));
    return out;
  }
}

/// Encodes a finished stereo buffer as PCM16 WAV (with deterministic TPDF
/// dither seeded by [seed]).
Uint8List encodeStereoWav(StereoBuffer b, {int seed = 1}) =>
    Wav.encodePcm16([b.left, b.right], sampleRate: b.sampleRate, dither: SynthRandom(seed));

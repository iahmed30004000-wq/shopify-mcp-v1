import 'dart:typed_data';

import '../sound_api.dart';
import '../synth/synth.dart';

/// Timing and loudness design targets shared by every profile, so a tap in
/// Desert feels as present as a tap in Lapis.
abstract final class SfxSpecs {
  /// Hard cap on each sound's length (reverb tail included). All UI sounds
  /// live between 40 and 900 ms.
  static double maxSeconds(Sfx sfx) => switch (sfx) {
        Sfx.tap => 0.16,
        Sfx.toggleOn => 0.34,
        Sfx.toggleOff => 0.28,
        Sfx.sheetOpen => 0.46,
        Sfx.sheetClose => 0.38,
        Sfx.complete => 0.9,
        Sfx.levelUp => 0.9,
        Sfx.delete => 0.42,
        Sfx.undo => 0.34,
        Sfx.swipe => 0.22,
        Sfx.pickUp => 0.24,
        Sfx.drop => 0.3,
        Sfx.error => 0.6,
        Sfx.notify => 0.8,
        Sfx.navigate => 0.13,
        Sfx.back => 0.13,
        Sfx.prayerLit => 0.9,
        Sfx.sparkle => 0.6,
        Sfx.countTick => 0.07,
      };

  /// Target momentary loudness (dBFS, 30 ms RMS). Frequent, incidental
  /// sounds sit low; rewards and the prayer bell are the most present –
  /// and still leave headroom below the −1 dBFS ceiling.
  static double loudnessDb(Sfx sfx) => switch (sfx) {
        Sfx.tap => -25,
        Sfx.toggleOn => -23,
        Sfx.toggleOff => -25,
        Sfx.sheetOpen => -27,
        Sfx.sheetClose => -28,
        Sfx.complete => -18,
        Sfx.levelUp => -16,
        Sfx.delete => -23,
        Sfx.undo => -24,
        Sfx.swipe => -29,
        Sfx.pickUp => -24,
        Sfx.drop => -23,
        Sfx.error => -22,
        Sfx.notify => -19,
        Sfx.navigate => -28,
        Sfx.back => -29,
        Sfx.prayerLit => -16,
        Sfx.sparkle => -25,
        Sfx.countTick => -30,
      };
}

/// A complete timbral voicing of every [Sfx], matched to one theme.
///
/// Implementations compose each sound on an [SfxCanvas] from the procedural
/// [Instruments]. Their `voice` methods switch exhaustively over [Sfx], so
/// adding a new sound to the contract is a compile error until every profile
/// voices it.
abstract class SoundProfile {
  const SoundProfile();

  /// Stable id (`lapis`, `emerald`, `desert`, `aurora`, `pearl`).
  String get id;

  /// Scale that colours melodic sounds.
  Maqam get maqam;

  /// Tonic of [maqam] in Hz.
  double get tonicHz;

  /// The room the profile's sounds ring in.
  ReverbSpec get room;

  /// Reverb return level.
  double get wet => 1.0;

  /// Frequency of scale [degree] (0 = tonic; ≥ 7 or < 0 change octave).
  double note(int degree, {int octave = 0, double cents = 0}) =>
      maqam.hz(tonicHz, degree, octave: octave, detuneCents: cents);

  double maxSeconds(Sfx sfx) => SfxSpecs.maxSeconds(sfx);
  double loudnessDb(Sfx sfx) => SfxSpecs.loudnessDb(sfx);

  /// Composes [sfx] onto [c].
  void voice(Sfx sfx, SfxCanvas c);

  /// Deterministic seed for ([id], [sfx]).
  int seedFor(Sfx sfx) => fnv1a('$id/${sfx.name}');

  /// Renders [sfx] to a finished stereo buffer.
  StereoBuffer render(Sfx sfx, {int sampleRate = 44100}) {
    final c = SfxCanvas(
      sampleRate: sampleRate,
      maxSeconds: maxSeconds(sfx),
      seed: seedFor(sfx),
      room: room,
    );
    voice(sfx, c);
    return c.finish(loudnessDb: loudnessDb(sfx), wet: wet);
  }

  /// Renders [sfx] to PCM16 WAV bytes.
  Uint8List renderWav(Sfx sfx, {int sampleRate = 44100}) =>
      encodeStereoWav(render(sfx, sampleRate: sampleRate), seed: seedFor(sfx) ^ 0x5A5A);
}

/// 32-bit FNV-1a – a stable string hash (unlike `String.hashCode`, which is
/// not guaranteed across Dart versions).
int fnv1a(String s) {
  var h = 0x811C9DC5;
  for (final u in s.codeUnits) {
    h ^= u;
    h = (h * 0x01000193) & 0xFFFFFFFF;
  }
  return h;
}

/// Gestures shared by several profiles.
abstract final class Gestures {
  /// Band-passed air moving past the listener.
  static void whoosh(
    SfxCanvas c, {
    double at = 0,
    required double dur,
    required double fromHz,
    required double toHz,
    double q = 0.8,
    double amp = 1.0,
    double peakAt = 0.45,
    double lowMix = 0.25,
    double pan = 0,
    double? panTo,
    double send = 0.25,
  }) {
    final v = Instruments.noiseSweep(
      c.sampleRate,
      rng: c.rng,
      durSec: dur,
      fromHz: fromHz,
      toHz: toHz,
      q: q,
      amp: amp,
      peakAt: peakAt,
      lowMix: lowMix,
    );
    c.place(v, at, pan: pan, panTo: panTo, send: send);
  }

  /// Scatters [count] voices produced by [voice] over [spanSec], choosing
  /// pitches from [freqs], with random stereo placement and a gentle
  /// diminuendo – sparkles and glitter.
  static void scatter(
    SfxCanvas c, {
    required List<double> freqs,
    required int count,
    required double spanSec,
    required Float64List Function(double hz) voice,
    double start = 0,
    double gain = 1.0,
    double spread = 0.65,
    double send = 0.45,
  }) {
    for (var i = 0; i < count; i++) {
      final t = start + (count == 1 ? 0 : spanSec * (i / (count - 1)) * c.rng.range(0.75, 1.0));
      final hz = freqs[c.rng.nextInt(freqs.length)];
      final g = gain * (1.0 - 0.45 * i / count) * c.rng.range(0.7, 1.0);
      c.place(voice(hz), t, gain: g, pan: c.rng.range(-spread, spread), send: send);
    }
  }
}

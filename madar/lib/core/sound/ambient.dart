import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'profiles.dart';
import 'synth/synth.dart';

/// Musical description of one profile's deep-space bed.
final class AmbientSpec {
  const AmbientSpec({
    required this.chordA,
    required this.chordB,
    required this.bellDegrees,
    this.bellModes = Modes.crystal,
    this.padCutoff = 440,
    this.padCutoffRange = 1.6,
    this.windAmount = 0.12,
    this.windCenter = 650,
    this.hissAmount = 0.018,
    this.bellsPerLoop = 4,
  });

  /// Two chords (scale degree, octave) the pads slowly breathe between.
  final List<(int, int)> chordA;
  final List<(int, int)> chordB;

  /// (degree, octave) pool for the rare shimmer bells.
  final List<(int, int)> bellDegrees;
  final List<Mode> bellModes;

  /// Base low-pass cutoff (Hz) of the pads and its sweep range in octaves.
  final double padCutoff;
  final double padCutoffRange;

  final double windAmount;
  final double windCenter;

  /// Faint high "stellar hiss" (≈3 kHz) that gives the bed air on small
  /// speakers.
  final double hissAmount;
  final int bellsPerLoop;
}

/// Procedurally generated deep-space soundscape: slow detuned pads through a
/// moving low-pass, distant wind, a sub drone and rare soft shimmer bells.
///
/// **Seamless by construction.** Rather than cross-fading a tail into the
/// head (which comb-filters sustained tones), every source is made periodic
/// in the loop length *L*: oscillator frequencies are quantised to an integer
/// number of cycles per loop, LFOs complete whole cycles, noise is a hash of
/// the position modulo *L*, and each bell also sounds one loop earlier. The
/// render starts with a pre-roll long enough for the filters and reverb to
/// reach their periodic steady state, so sample `L−1` flows into sample `0`
/// exactly.
abstract final class AmbientSoundscape {
  static const int defaultSampleRate = 24000;
  static const double defaultLoopSeconds = 28;

  /// Target overall RMS of the bed (dBFS) – quiet; the ambient volume slider
  /// scales it further.
  static const double targetRmsDb = -27;

  static const double _prerollSeconds = 6;

  static AmbientSpec specFor(String profileId) => switch (SoundProfiles.normalize(profileId)) {
        // I (D A E𝄳) ↔ IV (G D B) – Rast's neutral third glows in the pad.
        'lapis' => const AmbientSpec(
            chordA: [(0, -2), (4, -2), (2, -1)],
            chordB: [(3, -2), (0, -1), (5, -1)],
            bellDegrees: [(0, 0), (4, 0), (2, 0), (0, 1), (4, 1)],
            bellModes: Modes.glass,
          ),
        // Bayati i ↔ VI in open, spacious voicings – warm and woody.
        'emerald' => const AmbientSpec(
            chordA: [(0, -2), (4, -1), (2, 0)],
            chordB: [(5, -2), (2, -1), (0, 0)],
            bellDegrees: [(0, 1), (4, 0), (7, 0), (2, 1)],
            bellModes: Modes.kalimba,
            padCutoff: 380,
            windAmount: 0.1,
            windCenter: 560,
            hissAmount: 0.012,
          ),
        // Hijaz tonic ↔ iv, more desert wind.
        'desert' => const AmbientSpec(
            chordA: [(0, -1), (4, -1), (2, 0)],
            chordB: [(3, -1), (5, -1), (0, 0)],
            bellDegrees: [(0, 1), (4, 1), (2, 1), (7, 1)],
            bellModes: Modes.zill,
            padCutoff: 400,
            windAmount: 0.2,
            windCenter: 800,
            hissAmount: 0.022,
            bellsPerLoop: 3,
          ),
        // 'Ajam I ↔ vi, brighter and more open.
        'aurora' => const AmbientSpec(
            chordA: [(0, -2), (4, -2), (2, -1)],
            chordB: [(5, -2), (0, -1), (2, -1)],
            bellDegrees: [(0, 1), (4, 1), (2, 1), (6, 1), (0, 2)],
            padCutoff: 540,
            padCutoffRange: 1.9,
            windAmount: 0.09,
            windCenter: 1000,
            hissAmount: 0.024,
            bellsPerLoop: 5,
          ),
        // Nahawand i ↔ VI, light and airy.
        _ => const AmbientSpec(
            chordA: [(0, -2), (4, -2), (2, -1)],
            chordB: [(5, -2), (0, -1), (2, -1)],
            bellDegrees: [(0, 0), (4, 0), (7, 0), (2, 1)],
            padCutoff: 500,
            windAmount: 0.08,
            windCenter: 1100,
            hissAmount: 0.02,
          ),
      };

  /// Renders the loop as PCM16 stereo WAV bytes.
  static Uint8List renderWav(String profileId, {int sampleRate = defaultSampleRate, double loopSeconds = defaultLoopSeconds}) {
    final b = render(profileId, sampleRate: sampleRate, loopSeconds: loopSeconds);
    return Wav.encodePcm16([b.left, b.right], sampleRate: sampleRate, dither: SynthRandom(fnv1a('ambient-dither')));
  }

  /// [renderWav] on a background isolate (≈0.3–1 s of CPU on a phone).
  static Future<Uint8List> renderInBackground(
    String profileId, {
    int sampleRate = defaultSampleRate,
    double loopSeconds = defaultLoopSeconds,
  }) =>
      Isolate.run(() => renderWav(profileId, sampleRate: sampleRate, loopSeconds: loopSeconds),
          debugName: 'madar-ambient-$profileId');

  /// Renders exactly one loop (`round(loopSeconds·sr)` frames, rounded to a
  /// multiple of 16 so control-rate updates stay periodic).
  ///
  /// [loops] > 1 captures several consecutive periods – used by tests to
  /// prove that period *n* and *n+1* are sample-identical (i.e. the loop is
  /// seamless).
  static StereoBuffer render(
    String profileId, {
    int sampleRate = defaultSampleRate,
    double loopSeconds = defaultLoopSeconds,
    int loops = 1,
  }) {
    final profile = SoundProfiles.byId(profileId);
    final spec = specFor(profile.id);
    final sr = sampleRate;
    final loop = ((loopSeconds * sr) / 16).round() * 16;
    final loopSec = loop / sr;
    final pre = ((_prerollSeconds * sr) / 16).round() * 16;
    final total = pre + loop * loops;
    final seed = fnv1a('ambient/${profile.id}');
    final rng = SynthRandom(seed);

    final dryL = Float64List(total);
    final dryR = Float64List(total);
    final send = Float64List(total);

    // Quantise a frequency to a whole number of cycles per loop.
    double q(double hz) => math.max(1, (hz * loopSec).round()) / loopSec;

    // ---- Pads: two chords × three tones × two detuned saws. ----------------
    final tones = [...spec.chordA, ...spec.chordB];
    final nOsc = tones.length * 2;
    final phase = Float64List(nOsc);
    final inc = Float64List(nOsc);
    for (var t = 0; t < tones.length; t++) {
      final (deg, oct) = tones[t];
      final f = profile.note(deg, octave: oct);
      for (var v = 0; v < 2; v++) {
        final cents = v == 0 ? -6.0 : 6.0;
        inc[t * 2 + v] = q(f * math.pow(2.0, cents / 1200)) / sr;
        phase[t * 2 + v] = rng.nextDouble();
      }
    }
    final toneGain = Float64List(tones.length);
    final tonePanL = Float64List(tones.length);
    final tonePanR = Float64List(tones.length);
    for (var t = 0; t < tones.length; t++) {
      final p = (t % 3 - 1) * 0.55; // spread each chord L-C-R
      final a = (p + 1) * math.pi / 4;
      tonePanL[t] = math.cos(a);
      tonePanR[t] = math.sin(a);
    }
    final breathCycles = [for (var t = 0; t < tones.length; t++) 1 + t % 3];
    final breathPhase = [for (var t = 0; t < tones.length; t++) rng.nextDouble()];
    final svfL = Svf(sampleRate: sr, cutoff: spec.padCutoff, q: 0.9);
    final svfR = Svf(sampleRate: sr, cutoff: spec.padCutoff, q: 0.9);

    // ---- Sub drone. ---------------------------------------------------------
    var droneHz = profile.tonicHz;
    while (droneHz >= 100) {
      droneHz /= 2;
    }
    while (droneHz < 50) {
      droneHz *= 2;
    }
    final dInc1 = q(droneHz) / sr;
    final dInc2 = q(droneHz * 2) / sr;
    final dInc3 = q(droneHz * 3) / sr;
    var dp1 = 0.0, dp2 = 0.0, dp3 = 0.0;

    // ---- Wind. ----------------------------------------------------------------
    final windL = Svf(sampleRate: sr, cutoff: spec.windCenter, q: 1.4);
    final windR = Svf(sampleRate: sr, cutoff: spec.windCenter, q: 1.4);
    final seedWL = rng.nextUint32();
    final seedWR = rng.nextUint32();
    var pinkL = 0.0, pinkR = 0.0;
    final pinkA = 1.0 - math.exp(-2 * math.pi * 900 / sr);
    final windPhase = rng.nextDouble();
    final hissL = Svf(sampleRate: sr, cutoff: 3200, q: 0.8);
    final hissR = Svf(sampleRate: sr, cutoff: 3400, q: 0.8);
    var hiss = 0.0;

    const twoPi = 2 * math.pi;
    const padLevel = 0.16;
    const droneLevel = 0.09;
    var wA = 1.0, wB = 0.0, gust = 0.5, gustR = 0.5;
    final nA = spec.chordA.length;

    for (var k = 0; k < total; k++) {
      // Position within the loop (periodic modulation source).
      var p = (k - pre) % loop;
      if (p < 0) p += loop;
      if ((p & 15) == 0 || k == 0) {
        final x = p / loop; // 0..1 around the loop
        // Chord morph: one full A → B → A cycle per loop.
        wA = 0.5 + 0.5 * math.cos(twoPi * x);
        wB = 1 - wA;
        for (var t = 0; t < tones.length; t++) {
          final breath = 0.75 + 0.25 * math.sin(twoPi * (breathCycles[t] * x + breathPhase[t]));
          toneGain[t] = (t < nA ? wA : wB) * breath;
        }
        final sweep = 0.5 + 0.35 * math.sin(twoPi * x) + 0.15 * math.sin(twoPi * (3 * x + 0.25));
        final cut = spec.padCutoff * math.pow(2.0, spec.padCutoffRange * sweep);
        svfL.set(cut, 0.9);
        svfR.set(cut * 1.08, 0.9);
        final wc = spec.windCenter * math.pow(2.0, 1.2 * math.sin(twoPi * (2 * x + windPhase)));
        windL.set(wc, 1.4);
        windR.set(wc * 1.15, 1.4);
        final g = 0.5 + 0.5 * math.sin(twoPi * (3 * x + windPhase));
        gust = 0.35 + 0.65 * g * g;
        final g2 = 0.5 + 0.5 * math.sin(twoPi * (5 * x + windPhase + 0.4));
        gustR = 0.35 + 0.65 * g2 * g2;
        hiss = spec.hissAmount * (0.6 + 0.4 * math.sin(twoPi * (x + windPhase + 0.6)));
      }

      // Pads.
      var padL = 0.0, padR = 0.0;
      for (var t = 0; t < tones.length; t++) {
        var s = 0.0;
        for (var v = 0; v < 2; v++) {
          final o = t * 2 + v;
          final ph = phase[o];
          final dt = inc[o];
          var y = 2.0 * ph - 1.0;
          if (ph < dt) {
            final u = ph / dt;
            y -= u + u - u * u - 1.0;
          } else if (ph > 1.0 - dt) {
            final u = (ph - 1.0) / dt;
            y -= u * u + u + u + 1.0;
          }
          s += y;
          final np = ph + dt;
          phase[o] = np >= 1.0 ? np - 1.0 : np;
        }
        final g = toneGain[t];
        padL += s * g * tonePanL[t];
        padR += s * g * tonePanR[t];
      }
      svfL.process(padL);
      svfR.process(padR);
      final pl = svfL.low * padLevel;
      final pr = svfR.low * padLevel;

      // Sub drone (+ gentle harmonics so small speakers imply it).
      final drone = droneLevel *
          (SineTable.wrapped(dp1) + 0.55 * SineTable.wrapped(dp2) + 0.22 * SineTable.wrapped(dp3)) *
          (0.85 + 0.15 * wA);
      dp1 += dInc1;
      if (dp1 >= 1.0) dp1 -= 1.0;
      dp2 += dInc2;
      if (dp2 >= 1.0) dp2 -= 1.0;
      dp3 += dInc3;
      if (dp3 >= 1.0) dp3 -= 1.0;

      // Distant wind: position-hashed noise → pinkish → moving band-pass.
      pinkL += pinkA * (_hashNoise(p, seedWL) - pinkL);
      pinkR += pinkA * (_hashNoise(p, seedWR) - pinkR);
      windL.process(pinkL);
      windR.process(pinkR);
      final wl = windL.band * spec.windAmount * gust;
      final wr = windR.band * spec.windAmount * gustR;
      hissL.process(_hashNoise(p, seedWR ^ 0x5bd1e995));
      hissR.process(_hashNoise(p, seedWL ^ 0x5bd1e995));
      final hl = hissL.band * hiss;
      final hr = hissR.band * hiss;

      dryL[k] = pl + drone + wl + hl;
      dryR[k] = pr + drone + wr + hr;
      send[k] = 0.35 * (pl + pr) + 0.2 * (wl + wr) + 0.5 * (hl + hr);
    }

    // ---- Rare shimmer bells (each also sounds one loop earlier). -----------
    for (var b = 0; b < spec.bellsPerLoop; b++) {
      final t = rng.range(0.08, 0.92) * loopSec;
      final (deg, oct) = spec.bellDegrees[rng.nextInt(spec.bellDegrees.length)];
      final hz = profile.note(deg, octave: oct);
      final amp = rng.range(0.05, 0.09);
      final pan = rng.range(-0.7, 0.7);
      final voice = Instruments.modal(sr, freq: hz, modes: spec.bellModes, t60: 2.8, amp: amp, attackMs: 4, maxSec: 4.5);
      final a = (pan + 1) * math.pi / 4;
      final gl = math.cos(a) * math.sqrt2, gr = math.sin(a) * math.sqrt2;
      final start = pre + (t * sr).round();
      for (var m = -1; m < loops; m++) {
        final at = start + m * loop;
        for (var i = 0; i < voice.length; i++) {
          final k = at + i;
          if (k < 0) continue;
          if (k >= total) break;
          final v = voice[i];
          dryL[k] += v * gl * 0.45;
          dryR[k] += v * gr * 0.45;
          send[k] += v;
        }
      }
    }

    // ---- Deep reverb. ---------------------------------------------------------
    Reverb(sr, const ReverbSpec(roomSize: 0.88, damping: 0.5, preDelayMs: 30)).process(send, dryL, dryR, wet: 0.9);

    // ---- Capture one steady-state loop, level it, protect the ceiling. -------
    final out = StereoBuffer.fromChannels(
      sr,
      Float64List.fromList(Float64List.sublistView(dryL, pre, total)),
      Float64List.fromList(Float64List.sublistView(dryR, pre, total)),
    );
    var e = 0.0;
    for (var i = 0; i < loop; i++) {
      e += 0.5 * (out.left[i] * out.left[i] + out.right[i] * out.right[i]);
    }
    // Level from the first period only, so every period gets the same gain.
    final rms = math.sqrt(e / loop);
    if (rms > 0) out.scale(dbToGain(targetRmsDb) / rms);
    const SoftLimiter(ceilingDb: -1).process(out);
    return out;
  }

  /// Stateless white noise in [-1, 1): a 32-bit integer hash of the loop
  /// position, so the noise repeats *exactly* every loop.
  static double _hashNoise(int position, int seed) {
    var h = (position * 0x9E3779B1 + seed) & 0xFFFFFFFF;
    h ^= h >> 16;
    h = (h * 0x85EBCA6B) & 0xFFFFFFFF;
    h ^= h >> 13;
    h = (h * 0xC2B2AE35) & 0xFFFFFFFF;
    h ^= h >> 16;
    return h * (2.0 / 4294967296.0) - 1.0;
  }
}

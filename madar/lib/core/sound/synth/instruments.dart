import 'dart:math' as math;
import 'dart:typed_data';

import 'envelope.dart';
import 'filters.dart';
import 'oscillators.dart';
import 'rng.dart';

/// One vibrating mode of a struck object.
final class Mode {
  const Mode(this.ratio, this.gain, this.decay);

  /// Frequency relative to the fundamental.
  final double ratio;

  /// Relative amplitude.
  final double gain;

  /// Decay time relative to the instrument's `t60`.
  final double decay;
}

/// Mode tables for struck / plucked objects. Ratios come from measured
/// spectra (glass, kalimba tines, marimba bars, circular membranes, bells).
abstract final class Modes {
  /// Wine-glass / glass bell: strongly inharmonic, long ringing partials.
  static const glass = [
    Mode(1.0, 1.0, 1.0),
    Mode(2.32, 0.42, 0.72),
    Mode(4.25, 0.2, 0.45),
    Mode(6.63, 0.09, 0.3),
    Mode(9.38, 0.04, 0.2),
  ];

  /// Crystal ping: nearly pure with a faint octave and twelfth.
  static const crystal = [
    Mode(1.0, 1.0, 1.0),
    Mode(2.0, 0.16, 0.7),
    Mode(3.01, 0.06, 0.45),
    Mode(5.43, 0.035, 0.22),
  ];

  /// Kalimba tine: fundamental plus fast-dying inharmonic "tang".
  static const kalimba = [
    Mode(1.0, 1.0, 1.0),
    Mode(5.93, 0.2, 0.16),
    Mode(13.8, 0.06, 0.05),
  ];

  /// Tuned wooden bar (marimba): 1 : 3.93 : 9.24.
  static const wood = [
    Mode(1.0, 1.0, 1.0),
    Mode(3.93, 0.28, 0.28),
    Mode(9.24, 0.07, 0.1),
  ];

  /// Hollow wooden block / tongue drum knock.
  static const woodBlock = [
    Mode(1.0, 1.0, 1.0),
    Mode(1.58, 0.5, 0.6),
    Mode(2.46, 0.25, 0.35),
    Mode(3.9, 0.08, 0.2),
  ];

  /// Ideal circular membrane (Bessel zeros) – frame-drum body.
  static const membrane = [
    Mode(1.594, 0.55, 0.6),
    Mode(2.136, 0.4, 0.45),
    Mode(2.296, 0.3, 0.4),
    Mode(2.653, 0.2, 0.3),
    Mode(2.918, 0.14, 0.25),
    Mode(3.156, 0.09, 0.2),
  ];

  /// Small brass zill (riq jingles).
  static const zill = [
    Mode(1.0, 1.0, 1.0),
    Mode(1.47, 0.8, 0.85),
    Mode(2.09, 0.65, 0.7),
    Mode(2.56, 0.45, 0.55),
    Mode(3.37, 0.3, 0.45),
  ];

  /// Singing bowl – slow, warm, few partials.
  static const bowl = [
    Mode(1.0, 1.0, 1.0),
    Mode(2.71, 0.4, 0.8),
    Mode(5.13, 0.16, 0.55),
    Mode(8.19, 0.06, 0.35),
  ];

  /// A tuned bell (hum, prime, tierce, quint, nominal, upper partials).
  /// [tierceCents] sets the bell's characteristic third: 300 = minor
  /// (Western minster), 350 = neutral (Rast colour), 400 = major.
  static List<Mode> bell({double tierceCents = 300}) => [
        const Mode(0.5, 0.3, 1.25),
        const Mode(1.0, 0.85, 1.0),
        Mode(math.pow(2.0, tierceCents / 1200).toDouble(), 0.42, 0.72),
        const Mode(1.5, 0.22, 0.6),
        const Mode(2.0, 0.55, 0.5),
        const Mode(2.52, 0.16, 0.36),
        const Mode(2.67, 0.12, 0.3),
        const Mode(3.01, 0.08, 0.24),
      ];
}

/// Procedural instruments. Each returns a fresh mono buffer sized to its
/// natural length (capped by `maxSec`) that a `SfxCanvas` then places, pans
/// and reverberates. All are deterministic given their inputs.
abstract final class Instruments {
  static const double _twoPi = 2.0 * math.pi;

  static int _frames(int sr, double sec) => math.max(1, (sec * sr).round());

  /// Bank of exponentially decaying sinusoids – struck glass, wood, metal and
  /// membranes. Each mode is a two-pole resonator (`y = 2r·cos w·y₁ − r²·y₂`)
  /// which costs three multiply-adds per sample and starts at zero phase, so
  /// onsets never click.
  static Float64List modal(
    int sr, {
    required double freq,
    required List<Mode> modes,
    double t60 = 1.0,
    double amp = 1.0,
    double attackMs = 0.6,
    double maxSec = 1.0,
    double brightness = 1.0,
  }) {
    var longest = 0.0;
    for (final m in modes) {
      longest = math.max(longest, m.decay * t60);
    }
    final n = _frames(sr, math.min(maxSec, longest * 1.35 + attackMs / 1000));
    final out = Float64List(n);
    final nyquist = sr * 0.45;
    for (final m in modes) {
      final f = freq * m.ratio;
      if (f >= nyquist || f <= 0) continue;
      // Brightness < 1 tilts upper modes down.
      final g = amp * m.gain * math.pow(brightness.clamp(0.05, 4.0), math.log(m.ratio) / math.ln2);
      final t = math.max(0.004, m.decay * t60);
      final r = math.pow(10.0, -3.0 / (t * sr)).toDouble();
      final w = _twoPi * f / sr;
      final c = 2.0 * r * math.cos(w);
      final r2 = r * r;
      final len = math.min(n, (t * sr * 1.34).round() + 2);
      var y2 = 0.0;
      var y1 = g * r * math.sin(w);
      if (len > 1) out[1] += y1;
      for (var i = 2; i < len; i++) {
        final y = c * y1 - r2 * y2;
        out[i] += y;
        y2 = y1;
        y1 = y;
      }
    }
    if (attackMs > 0) Fades.fadeIn(out, _frames(sr, attackMs / 1000));
    return out;
  }

  /// Two-operator FM bell (Chowning). A non-integer [ratio] gives the
  /// inharmonic, glassy spectra; the modulation [index] decays faster than
  /// the amplitude so the tone mellows as it rings.
  static Float64List fmBell(
    int sr, {
    required double freq,
    double ratio = 1.4,
    double index = 2.0,
    double indexT60 = 0.25,
    double t60 = 1.0,
    double attackMs = 1.0,
    double amp = 1.0,
    double maxSec = 0.9,
    double glideCents = 0,
    double glideMs = 40,
  }) {
    final n = _frames(sr, math.min(maxSec, t60 * 1.3 + attackMs / 1000));
    final out = Float64List(n);
    final kAmp = decayFactor(t60, sr);
    final kIdx = decayFactor(indexT60, sr);
    final idxScale = index / _twoPi; // table phases are in cycles
    var env = amp;
    var idx = idxScale;
    var pc = 0.0, pm = 0.0;
    final dm = freq * ratio / sr;
    final dc = freq / sr;
    // Pitch glide into the note: the frequency ratio relaxes exponentially
    // from 2^(glideCents/1200) to 1.
    final glideK = glideCents == 0 ? 0.0 : decayFactor(glideMs / 1000, sr);
    var glide = math.pow(2.0, glideCents / 1200).toDouble() - 1.0;
    for (var i = 0; i < n; i++) {
      final mod = SineTable.wrapped(pm) * idx;
      out[i] = env * SineTable.at(pc + mod);
      pc += dc * (1.0 + glide);
      if (pc >= 1.0) pc -= 1.0;
      pm += dm;
      if (pm >= 1.0) pm -= 1.0;
      env *= kAmp;
      idx *= kIdx;
      glide *= glideK;
    }
    Fades.fadeIn(out, _frames(sr, attackMs / 1000));
    return out;
  }

  /// Karplus–Strong plucked string with Jaffe–Smith extensions: all-pass
  /// fractional tuning, pluck-position comb, dynamic-level excitation filter
  /// and a body resonance – oud (short, woody) to kanun (bright, long).
  ///
  /// [courses] = 2 renders a doubled course (two strings detuned by
  /// [courseCents]) like a real oud.
  static Float64List pluck(
    int sr, {
    required double freq,
    required SynthRandom rng,
    double t60 = 1.0,
    double brightness = 0.6,
    double pluckPos = 0.18,
    double amp = 1.0,
    double maxSec = 0.9,
    double bodyHz = 0,
    double bodyGainDb = 4,
    int courses = 1,
    double courseCents = 3,
  }) {
    final n = _frames(sr, math.min(maxSec, t60 * 1.1));
    final out = Float64List(n);
    for (var s = 0; s < courses; s++) {
      final cents = courses == 1 ? 0.0 : (s == 0 ? -courseCents / 2 : courseCents / 2);
      final f = freq * math.pow(2.0, cents / 1200);
      _ksString(out, sr, f, rng, t60, brightness, pluckPos, amp / courses, s * (sr ~/ 2000));
    }
    if (bodyHz > 0) {
      Biquad(BiquadType.peaking, frequency: bodyHz, sampleRate: sr, q: 1.1, gainDb: bodyGainDb).processBuffer(out);
    }
    DcBlocker().processBuffer(out);
    Fades.fadeIn(out, _frames(sr, 0.0006));
    return out;
  }

  static void _ksString(
    Float64List out,
    int sr,
    double freq,
    SynthRandom rng,
    double t60,
    double brightness,
    double pluckPos,
    double amp,
    int offset,
  ) {
    final period = sr / freq;
    // Loop delay = D (integer) + 0.5 (averaging filter) + frac (all-pass).
    final d = math.max(2, (period - 0.5 - 0.1).floor());
    final frac = period - 0.5 - d;
    final apC = (1.0 - frac) / (1.0 + frac);
    final rho = math.pow(10.0, -3.0 / (freq * t60)).toDouble();

    // Excitation: filtered noise burst with a pluck-position comb.
    final exc = Float64List(d);
    final lp = OnePoleLowPass(700 + brightness * 9000, sr);
    for (var i = 0; i < d; i++) {
      exc[i] = lp.process(rng.bipolar());
    }
    final m = math.max(1, (pluckPos * d).round());
    for (var i = d - 1; i >= m; i--) {
      exc[i] -= exc[i - m];
    }
    var mean = 0.0;
    for (var i = 0; i < d; i++) {
      mean += exc[i];
    }
    mean /= d;
    var pk = 1e-9;
    for (var i = 0; i < d; i++) {
      exc[i] -= mean;
      pk = math.max(pk, exc[i].abs());
    }
    final eg = amp / pk;

    final line = Float64List(d + 1);
    var w = 0;
    var apX1 = 0.0, apY1 = 0.0;
    var prev = 0.0;
    final n = out.length;
    for (var i = offset; i < n; i++) {
      final k = i - offset;
      // Read the sample written D steps ago.
      var r = w - d;
      if (r < 0) r += line.length;
      final cur = line[r];
      final avg = 0.5 * (cur + prev);
      prev = cur;
      // First-order all-pass for fractional delay.
      final ap = apC * avg + apX1 - apC * apY1;
      apX1 = avg;
      apY1 = ap;
      final y = (k < d ? exc[k] * eg : 0.0) + rho * ap;
      line[w] = y;
      if (++w >= line.length) w = 0;
      out[i] += y;
    }
  }

  /// Frame drum (daf / bendir / riq). [tone] blends from a deep "dum"
  /// (0: centre stroke with pitch drop) to a crisp "tek" (1: rim stroke);
  /// [jingles] adds riq zills.
  static Float64List frameDrum(
    int sr, {
    required SynthRandom rng,
    double freq = 92,
    double t60 = 0.5,
    double tone = 0.0,
    double jingles = 0.0,
    double amp = 1.0,
    double maxSec = 0.7,
  }) {
    final n = _frames(sr, math.min(maxSec, t60 * 1.2 + 0.02));
    final out = Float64List(n);
    final dumGain = amp * (1.0 - 0.75 * tone);
    // Fundamental with a short pitch drop – the "boom".
    if (dumGain > 0.001) {
      final k = decayFactor(t60 * (1.0 - 0.6 * tone), sr);
      final kp = decayFactor(0.06, sr);
      var env = dumGain;
      var bend = 0.45;
      var ph = 0.0;
      for (var i = 0; i < n; i++) {
        out[i] += env * SineTable.wrapped(ph);
        ph += freq * (1.0 + bend) / sr;
        if (ph >= 1.0) ph -= 1.0;
        env *= k;
        bend *= kp;
      }
    }
    // Membrane overtones – stronger for rim strokes.
    final body = modal(
      sr,
      freq: freq,
      modes: Modes.membrane,
      t60: t60 * (0.55 - 0.3 * tone),
      amp: amp * (0.35 + 0.6 * tone),
      maxSec: maxSec,
      attackMs: 0.3,
    );
    _addInto(out, body, 0, 1.0);
    // Skin slap: short band-passed noise.
    final slapLen = _frames(sr, 0.012 + 0.01 * tone);
    final svf = Svf(sampleRate: sr, cutoff: 800 + 2400 * tone, q: 0.9);
    final slapGain = amp * (0.25 + 0.55 * tone);
    for (var i = 0; i < slapLen && i < n; i++) {
      svf.process(rng.bipolar());
      final e = math.pow(1.0 - i / slapLen, 2.0);
      out[i] += svf.band * slapGain * e;
    }
    if (jingles > 0) {
      final z = zills(sr, rng: rng, amp: amp * jingles, maxSec: maxSec);
      _addInto(out, z, 0, 1.0);
    }
    // The decaying, pitch-bent fundamental is asymmetric → remove its DC.
    DcBlocker(r: 1 - 2 * math.pi * 18 / sr).processBuffer(out);
    Fades.fadeIn(out, _frames(sr, 0.0004));
    return out;
  }

  /// A shake of small brass zills (riq jingles / sparkle metal).
  static Float64List zills(
    int sr, {
    required SynthRandom rng,
    double freq = 3900,
    double t60 = 0.22,
    double amp = 1.0,
    int hits = 3,
    double spreadMs = 11,
    double maxSec = 0.5,
  }) {
    final n = _frames(sr, math.min(maxSec, t60 * 1.3 + hits * spreadMs / 1000));
    final out = Float64List(n);
    for (var h = 0; h < hits; h++) {
      final at = _frames(sr, h * spreadMs / 1000 * rng.range(0.8, 1.25)) - 1;
      final g = amp * math.pow(0.62, h) * rng.range(0.8, 1.0);
      final f = freq * rng.range(0.97, 1.03);
      final m = modal(sr, freq: f, modes: Modes.zill, t60: t60, amp: g * 0.5, maxSec: maxSec, attackMs: 0.2, brightness: 0.6);
      _addInto(out, m, at, 1.0);
      // Metallic noise shimmer.
      final bp = Svf(sampleRate: sr, cutoff: 5200, q: 1.1);
      final len = _frames(sr, 0.025);
      for (var i = 0; i < len && at + i < n; i++) {
        bp.process(rng.bipolar());
        out[at + i] += bp.band * g * 0.14 * (1 - i / len);
      }
    }
    return out;
  }

  /// Band-passed noise sweep: whooshes, wind, breaths. The centre frequency
  /// glides exponentially from [fromHz] to [toHz]; the envelope rises to its
  /// peak at [peakAt] (fraction of the duration) and falls smoothly.
  static Float64List noiseSweep(
    int sr, {
    required SynthRandom rng,
    required double durSec,
    double fromHz = 500,
    double toHz = 3000,
    double q = 0.9,
    double amp = 1.0,
    double peakAt = 0.4,
    double lowMix = 0.25,
    double tailPower = 1.6,
  }) {
    final n = _frames(sr, durSec);
    final out = Float64List(n);
    final svf = Svf(sampleRate: sr, cutoff: fromHz, q: q);
    final peak = (peakAt.clamp(0.02, 0.98) * n).round();
    final ratio = toHz / fromHz;
    // Slightly pink excitation (softer than white).
    final pink = OnePoleLowPass(2500, sr);
    for (var i = 0; i < n; i++) {
      if ((i & 7) == 0) svf.set(fromHz * math.pow(ratio, i / n), q);
      final w = rng.bipolar();
      svf.process(0.6 * w + 0.8 * pink.process(w));
      double e;
      if (i < peak) {
        final t = i / peak;
        e = math.sin(0.5 * math.pi * t);
        e *= e;
      } else {
        final t = (i - peak) / math.max(1, n - peak);
        e = math.pow(0.5 + 0.5 * math.cos(math.pi * t), tailPower).toDouble();
      }
      out[i] = amp * e * (svf.band + lowMix * svf.low);
    }
    return out;
  }

  /// A sine (plus optional [harmonics]) gliding from [fromHz] to [toHz]
  /// over [glideSec], with an attack and an exponential decay – blips,
  /// swooshes with pitch, subs and soft synth tones.
  static Float64List glide(
    int sr, {
    required double fromHz,
    required double toHz,
    required double durSec,
    double glideSec = 0.05,
    double attackMs = 2,
    double t60 = 0.3,
    double amp = 1.0,
    List<double> harmonics = const [],
    double vibratoHz = 0,
    double vibratoCents = 0,
  }) {
    final n = _frames(sr, durSec);
    final out = Float64List(n);
    final k = decayFactor(t60, sr);
    final gl = math.max(1, (glideSec * sr).round());
    final ratio = toHz / fromHz;
    var env = amp;
    final phases = Float64List(harmonics.length + 1);
    var vib = 0.0;
    // cents → ratio via 1 + x·ln2/1200 (exact to < 0.01 cent for vibrato).
    final vibDepth = vibratoCents * math.ln2 / 1200;
    var f = fromHz;
    for (var i = 0; i < n; i++) {
      if (i < gl) {
        // Ease-out glide.
        final t = i / gl;
        f = fromHz * math.pow(ratio, 1.0 - (1.0 - t) * (1.0 - t));
      } else if (i == gl) {
        f = toHz;
      }
      var fv = f;
      if (vibratoHz > 0) {
        fv *= 1.0 + vibDepth * SineTable.wrapped(vib);
        vib += vibratoHz / sr;
        if (vib >= 1.0) vib -= 1.0;
      }
      var s = SineTable.wrapped(phases[0]);
      phases[0] += fv / sr;
      if (phases[0] >= 1.0) phases[0] -= 1.0;
      for (var h = 0; h < harmonics.length; h++) {
        final hf = fv * (h + 2);
        if (hf < sr * 0.45) {
          s += harmonics[h] * SineTable.wrapped(phases[h + 1]);
          phases[h + 1] += hf / sr;
          if (phases[h + 1] >= 1.0) phases[h + 1] -= 1.0;
        }
      }
      out[i] = s * env;
      env *= k;
    }
    Fades.fadeIn(out, _frames(sr, attackMs / 1000));
    Fades.fadeOut(out, _frames(sr, math.min(0.02, durSec * 0.3)));
    return out;
  }

  /// Detuned polyBLEP saw ensemble through a sweeping low-pass – the airy
  /// "aurora" shimmer and the ambient pads.
  static Float64List pad(
    int sr, {
    required double freq,
    required double durSec,
    required SynthRandom rng,
    int voices = 3,
    double detuneCents = 14,
    double cutoffFrom = 600,
    double cutoffTo = 3200,
    double q = 0.8,
    Adsr env = const Adsr(attack: 0.04, decay: 0.2, sustain: 0.7, release: 0.2),
    double amp = 1.0,
    double sineOctaveMix = 0.25,
  }) {
    final e = env.render(sr, math.max(0.0, durSec - env.release));
    final n = e.length;
    final out = Float64List(n);
    final saws = [
      for (var v = 0; v < voices; v++)
        PolyBlepSaw(
          frequency: freq * math.pow(2.0, (voices == 1 ? 0 : (v / (voices - 1) - 0.5) * 2 * detuneCents) / 1200),
          sampleRate: sr,
          phase: rng.nextDouble(),
        ),
    ];
    final oct = SineOsc(frequency: freq * 2, sampleRate: sr);
    final svf = Svf(sampleRate: sr, cutoff: cutoffFrom, q: q);
    final ratio = cutoffTo / cutoffFrom;
    final norm = 1.0 / math.sqrt(voices.toDouble());
    for (var i = 0; i < n; i++) {
      if ((i & 15) == 0) {
        final t = i / n;
        svf.set(cutoffFrom * math.pow(ratio, math.sin(0.5 * math.pi * t)), q);
      }
      var s = 0.0;
      for (var v = 0; v < saws.length; v++) {
        s += saws[v].next();
      }
      svf.process(s * norm);
      out[i] = amp * e[i] * (svf.low + sineOctaveMix * oct.next());
    }
    return out;
  }

  /// Short percussive click (mallet contact / key tick): a burst of
  /// band-passed noise a few milliseconds long.
  static Float64List click(
    int sr, {
    required SynthRandom rng,
    double centerHz = 3000,
    double q = 1.2,
    double durMs = 5,
    double amp = 1.0,
  }) {
    final n = _frames(sr, durMs / 1000);
    final out = Float64List(n);
    final svf = Svf(sampleRate: sr, cutoff: centerHz, q: q);
    for (var i = 0; i < n; i++) {
      svf.process(rng.bipolar());
      final t = i / n;
      out[i] = amp * svf.band * (1 - t) * (1 - t);
    }
    Fades.fadeIn(out, math.max(1, n ~/ 8));
    return out;
  }

  static void _addInto(Float64List dst, Float64List src, int at, double gain) {
    final n = math.min(src.length, dst.length - at);
    for (var i = 0; i < n; i++) {
      dst[at + i] += src[i] * gain;
    }
  }
}

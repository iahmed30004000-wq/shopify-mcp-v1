import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/sound/synth/synth.dart';

double _rms(Float64List x, [int start = 0, int? end]) {
  final e = end ?? x.length;
  var s = 0.0;
  for (var i = start; i < e; i++) {
    s += x[i] * x[i];
  }
  return math.sqrt(s / math.max(1, e - start));
}

Float64List _sine(double hz, int sr, int n, [double amp = 1]) =>
    Float64List.fromList(List.generate(n, (i) => amp * math.sin(2 * math.pi * hz * i / sr)));

/// Fundamental estimate by normalised autocorrelation with parabolic
/// interpolation, searching lags for [minHz]..[maxHz].
double _pitch(Float64List x, int sr, {int start = 0, int len = 8192, double minHz = 60, double maxHz = 2000}) {
  final minLag = (sr / maxHz).floor();
  final maxLag = (sr / minHz).ceil();
  final ac = Float64List(maxLag + 2);
  for (var lag = minLag - 1; lag <= maxLag + 1; lag++) {
    var s = 0.0;
    for (var i = start; i < start + len; i++) {
      s += x[i] * x[i + lag];
    }
    ac[lag] = s;
  }
  var best = minLag;
  for (var lag = minLag; lag <= maxLag; lag++) {
    if (ac[lag] > ac[best]) best = lag;
  }
  final a = ac[best - 1], b = ac[best], c = ac[best + 1];
  final shift = 0.5 * (a - c) / (a - 2 * b + c);
  return sr / (best + shift);
}

void main() {
  group('SynthRandom', () {
    test('is deterministic per seed and differs across seeds', () {
      final a = SynthRandom(42), b = SynthRandom(42), c = SynthRandom(43);
      final sa = List.generate(100, (_) => a.nextUint32());
      final sb = List.generate(100, (_) => b.nextUint32());
      final sc = List.generate(100, (_) => c.nextUint32());
      expect(sa, sb);
      expect(sa, isNot(sc));
    });

    test('doubles lie in [0,1) with a sane mean', () {
      final r = SynthRandom(7);
      var sum = 0.0;
      for (var i = 0; i < 20000; i++) {
        final d = r.nextDouble();
        expect(d, inInclusiveRange(0.0, 0.9999999999));
        sum += d;
      }
      expect(sum / 20000, closeTo(0.5, 0.02));
    });
  });

  group('oscillators', () {
    test('SineTable matches math.sin to within 1e-6', () {
      for (var i = 0; i < 1000; i++) {
        final p = i / 997.0 - 0.3;
        expect(SineTable.at(p), closeTo(math.sin(2 * math.pi * p), 1e-6));
      }
    });

    test('polyBLEP saw is bounded and zero-mean', () {
      final saw = PolyBlepSaw(frequency: 1234, sampleRate: 44100);
      var sum = 0.0;
      for (var i = 0; i < 44100; i++) {
        final y = saw.next();
        expect(y.abs(), lessThanOrEqualTo(1.05));
        sum += y;
      }
      expect(sum / 44100, closeTo(0, 0.01));
    });
  });

  group('filters', () {
    test('biquad low-pass passes lows and attenuates highs', () {
      const sr = 44100;
      final low = _sine(100, sr, 8820);
      final high = _sine(8000, sr, 8820);
      Biquad(BiquadType.lowPass, frequency: 1000, sampleRate: sr).processBuffer(low);
      Biquad(BiquadType.lowPass, frequency: 1000, sampleRate: sr).processBuffer(high);
      expect(_rms(low, 4000), closeTo(1 / math.sqrt2, 0.02));
      expect(gainToDb(_rms(high, 4000) * math.sqrt2), lessThan(-30));
    });

    test('SVF band-pass peaks (gain = Q) at its centre and stays stable under sweeps', () {
      const sr = 44100;
      final svf = Svf(sampleRate: sr, cutoff: 1000, q: 2);
      final x = _sine(1000, sr, 8820);
      var peak = 0.0;
      for (var i = 0; i < x.length; i++) {
        svf.process(x[i]);
        if (i > 4000) peak = math.max(peak, svf.band.abs());
      }
      expect(peak, closeTo(2.0, 0.08)); // constant-skirt band-pass: gain Q at fc
      final r = SynthRandom(1);
      final sweep = Svf(sampleRate: sr, cutoff: 50, q: 5);
      for (var i = 0; i < 44100; i++) {
        if (i % 8 == 0) sweep.set(50 * math.pow(300, (i % 4410) / 4410).toDouble(), 5);
        sweep.process(r.bipolar());
        expect(sweep.low.isFinite, isTrue);
        expect(sweep.low.abs(), lessThan(50));
      }
    });
  });

  group('SoftLimiter', () {
    test('guarantees the −1 dBFS ceiling on hot material', () {
      const sr = 44100;
      final l = _sine(440, sr, 4410, 2.5);
      final r = _sine(660, sr, 4410, 1.7);
      final b = StereoBuffer.fromChannels(sr, l, r);
      const SoftLimiter().process(b);
      expect(b.peak(), lessThanOrEqualTo(dbToGain(-1)));
      // Still loud – limited, not muted.
      expect(b.peak(), greaterThan(dbToGain(-3)));
    });

    test('leaves material below the knee untouched', () {
      const sr = 44100;
      final l = _sine(440, sr, 2000, 0.3);
      final copy = Float64List.fromList(l);
      final b = StereoBuffer.fromChannels(sr, l, Float64List.fromList(l));
      const SoftLimiter().process(b);
      expect(b.left, copy);
    });

    test('holds the ceiling for a single-sample spike at the very start', () {
      final l = Float64List(1000)..[0] = 4.0;
      final b = StereoBuffer.fromChannels(44100, l, Float64List(1000));
      const SoftLimiter().process(b);
      expect(b.peak(), lessThanOrEqualTo(dbToGain(-1)));
    });
  });

  group('Reverb', () {
    test('an impulse produces a decaying, decorrelated stereo tail', () {
      const sr = 44100;
      final send = Float64List(sr)..[0] = 1.0;
      final l = Float64List(sr), r = Float64List(sr);
      Reverb(sr, const ReverbSpec(roomSize: 0.6)).process(send, l, r);
      final early = _rms(l, 2000, 8000);
      final late = _rms(l, 30000, 36000);
      expect(early, greaterThan(0));
      expect(late, lessThan(early * 0.5));
      var diff = 0.0;
      for (var i = 0; i < sr; i++) {
        diff += (l[i] - r[i]).abs();
      }
      expect(diff, greaterThan(0.01), reason: 'left and right tails differ');
      for (final v in l) {
        expect(v.isFinite, isTrue);
      }
    });
  });

  group('instruments', () {
    test('Karplus–Strong pluck is in tune (±0.7 %)', () {
      const sr = 44100;
      for (final hz in [146.83, 293.66, 440.0, 587.33]) {
        final x = Instruments.pluck(sr, freq: hz, rng: SynthRandom(9), t60: 1.5, maxSec: 0.6);
        final f = _pitch(x, sr, start: 2000, len: 8192, minHz: hz * 0.7, maxHz: hz * 1.4);
        expect(f, closeTo(hz, hz * 0.007), reason: 'pluck at $hz Hz measured $f');
      }
    });

    test('modal resonator rings at the requested frequency and decays', () {
      const sr = 44100;
      final x = Instruments.modal(sr, freq: 523.25, modes: const [Mode(1, 1, 1)], t60: 0.5, maxSec: 0.8);
      expect(_pitch(x, sr, start: 500, len: 4096, minHz: 300, maxHz: 900), closeTo(523.25, 2));
      expect(_rms(x, 0, 2000), greaterThan(_rms(x, 15000, 17000) * 10));
      expect(x.first, 0.0, reason: 'zero-phase onset: no click');
    });

    test('FM bell, glide, pad, noise sweep and drum are finite, bounded and non-silent', () {
      const sr = 44100;
      final r = SynthRandom(5);
      final voices = {
        'fm': Instruments.fmBell(sr, freq: 880, glideCents: 300),
        'glide': Instruments.glide(sr, fromHz: 300, toHz: 600, durSec: 0.2, harmonics: const [0.2], vibratoHz: 5, vibratoCents: 10),
        'pad': Instruments.pad(sr, freq: 220, durSec: 0.3, rng: r),
        'sweep': Instruments.noiseSweep(sr, rng: r, durSec: 0.3),
        'drum': Instruments.frameDrum(sr, rng: r, jingles: 0.5),
        'zills': Instruments.zills(sr, rng: r),
        'click': Instruments.click(sr, rng: r),
      };
      voices.forEach((name, x) {
        expect(x, isNotEmpty, reason: name);
        var pk = 0.0;
        for (final v in x) {
          expect(v.isFinite, isTrue, reason: name);
          pk = math.max(pk, v.abs());
        }
        expect(pk, greaterThan(1e-3), reason: '$name is audible');
        expect(pk, lessThan(8), reason: '$name is bounded');
      });
    });
  });

  group('Maqam', () {
    test('degrees, quarter tones and octave wrapping', () {
      expect(Maqam.rast.centsOf(2), 350);
      expect(Maqam.bayati.centsOf(1), 150);
      expect(Maqam.hijaz.centsOf(2) - Maqam.hijaz.centsOf(1), greaterThan(250), reason: 'augmented second');
      expect(Maqam.rast.centsOf(7), 1200);
      expect(Maqam.rast.centsOf(-1), 1050 - 1200);
      expect(Maqam.ajam.hz(440, 7), closeTo(880, 1e-9));
      expect(Maqam.nahawand.hz(440, 0, octave: -1), closeTo(220, 1e-9));
      expect(midiHz(69), 440);
    });
  });

  group('envelopes and buffers', () {
    test('ADSR rises, holds its sustain and lands on zero', () {
      final e = const Adsr(attack: 0.01, decay: 0.05, sustain: 0.5, release: 0.05).render(1000, 0.2);
      expect(e.length, 250);
      expect(e.reduce(math.max), lessThanOrEqualTo(1.0));
      expect(e[150], closeTo(0.5, 0.02));
      expect(e.last, closeTo(0, 1e-12));
    });

    test('equal-power pan keeps the centre at unity per channel', () {
      final b = StereoBuffer(44100, 4)..addMono(Float64List.fromList([1, 1, 1, 1]));
      expect(b.left[0], closeTo(1, 1e-9));
      expect(b.right[0], closeTo(1, 1e-9));
      final hard = StereoBuffer(44100, 1)..addMono(Float64List.fromList([1]), pan: -1);
      expect(hard.right[0], closeTo(0, 1e-9));
      expect(hard.left[0], closeTo(math.sqrt2, 1e-9));
    });
  });
}

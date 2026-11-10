import 'dart:math' as math;
import 'dart:typed_data';

import '../../../../../core/sound/synth/oscillators.dart';

/// Small DSP kernels shared by the cinema voices. Everything is offline,
/// deterministic and allocation-light (one output buffer per note).

const double twoPi = 2.0 * math.pi;

int framesFor(int sr, double seconds) => math.max(1, (seconds * sr).round());

/// −60 dB per [t60] seconds as a per-sample multiplier.
double t60Factor(double t60, int sr) => t60 <= 0 ? 0.0 : math.pow(10.0, -3.0 / (t60 * sr)).toDouble();

/// Adds a bank of two-pole resonators (struck/plucked modes) into [out].
///
/// Each mode rings with decay [t60s] until [holdN] samples, then with the
/// damped decay [dampT60s] (a damper / hand muting the string). Modes start
/// at zero phase, so onsets never click.
void addModes(
  Float64List out,
  int sr, {
  required List<double> freqs,
  required List<double> gains,
  required List<double> t60s,
  required List<double> dampT60s,
  int holdN = 1 << 30,
  int start = 0,
}) {
  final n = out.length;
  final nyq = sr * 0.46;
  for (var m = 0; m < freqs.length; m++) {
    final f = freqs[m];
    final g = gains[m];
    if (f <= 20 || f >= nyq || g == 0) continue;
    final w = twoPi * f / sr;
    final r1 = t60Factor(t60s[m], sr);
    final r2 = t60Factor(math.min(dampT60s[m], t60s[m]), sr);
    final cw = math.cos(w);
    final c1 = 2 * r1 * cw, q1 = r1 * r1;
    final c2 = 2 * r2 * cw, q2 = r2 * r2;
    // Stop once the mode is 80 dB down.
    final natural = (t60s[m] * 1.34 * sr).round();
    final dampedEnd = holdN + (math.min(dampT60s[m], t60s[m]) * 1.34 * sr).round();
    final end = math.min(n, start + math.min(natural, dampedEnd) + 2);
    var y2 = 0.0;
    var y1 = g * math.sin(w);
    final h = math.min(end, start + holdN);
    var i = start + 1;
    if (i < end) out[i] += y1;
    for (i = start + 2; i < h; i++) {
      final y = c1 * y1 - q1 * y2;
      out[i] += y;
      y2 = y1;
      y1 = y;
    }
    for (; i < end; i++) {
      final y = c2 * y1 - q2 * y2;
      out[i] += y;
      y2 = y1;
      y1 = y;
    }
  }
}

/// Envelope with raised-cosine attack, exponential decay to [sustain], a
/// hold until [holdN] and an exponential release that lands on exactly 0.
final class Env {
  Env(int sr, {double attack = 0.005, double decay = 0.1, this.sustain = 1.0, double release = 0.08, required this.holdN})
    : attackN = math.max(1, (attack * sr).round()),
      releaseN = math.max(1, (release * sr).round()),
      _kd = math.exp(math.log(0.01) / math.max(1, decay * sr));

  final int attackN;
  final int releaseN;
  final double sustain;
  final int holdN;
  final double _kd;
  double _level = 0;
  double _relStart = 0;
  int _i = 0;

  int get length => holdN + releaseN;

  double next() {
    final i = _i++;
    if (i < holdN) {
      if (i < attackN) {
        _level = 0.5 - 0.5 * math.cos(math.pi * (i + 1) / attackN);
      } else {
        _level = sustain + (_level - sustain) * _kd;
      }
      _relStart = _level;
      return _level;
    }
    final r = i - holdN;
    if (r >= releaseN) return 0;
    final t = (r + 1) / releaseN;
    return _relStart * math.exp(-4.0 * t) * (0.5 + 0.5 * math.cos(math.pi * t));
  }
}

/// Band-limited sawtooth / square / pulse with a settable increment.
final class Osc {
  Osc([this.phase = 0]);

  double phase;

  /// polyBLEP saw for increment [dt] (cycles per sample).
  double saw(double dt) {
    final t = phase;
    var y = 2.0 * t - 1.0;
    y -= polyBlep(t, dt);
    phase = t + dt;
    if (phase >= 1.0) phase -= 1.0;
    return y;
  }

  /// polyBLEP pulse with [duty] (0.5 = square).
  double pulse(double dt, double duty) {
    final t = phase;
    var y = t < duty ? 1.0 : -1.0;
    y += polyBlep(t, dt);
    var t2 = t + 1.0 - duty;
    if (t2 >= 1.0) t2 -= 1.0;
    y -= polyBlep(t2, dt);
    phase = t + dt;
    if (phase >= 1.0) phase -= 1.0;
    return y;
  }

  double tri(double dt) {
    final t = phase;
    final y = t < 0.5 ? 4.0 * t - 1.0 : 3.0 - 4.0 * t;
    phase = t + dt;
    if (phase >= 1.0) phase -= 1.0;
    return y;
  }

  double sine(double dt) {
    final y = SineTable.wrapped(phase);
    phase += dt;
    if (phase >= 1.0) phase -= 1.0;
    return y;
  }
}

/// Zavalishin state-variable filter with cheap cutoff updates (call
/// [setCutoff] every few samples, not every sample).
final class Filter {
  Filter(this.sr, {double cutoff = 1000, double q = 0.707}) {
    set(cutoff, q);
  }

  final int sr;
  double _g = 0, _k = 0, _a1 = 0, _a2 = 0, _a3 = 0;
  double _ic1 = 0, _ic2 = 0;
  double low = 0, band = 0, high = 0;

  void set(double cutoff, double q) {
    final f = cutoff.clamp(20.0, sr * 0.45);
    _g = math.tan(math.pi * f / sr);
    _k = 1.0 / q;
    _a1 = 1.0 / (1.0 + _g * (_g + _k));
    _a2 = _g * _a1;
    _a3 = _g * _a2;
  }

  void process(double v0) {
    final v3 = v0 - _ic2;
    final v1 = _a1 * _ic1 + _a2 * v3;
    final v2 = _ic2 + _a2 * _ic1 + _a3 * v3;
    _ic1 = 2.0 * v1 - _ic1;
    _ic2 = 2.0 * v2 - _ic2;
    low = v2;
    band = v1;
    high = v0 - _k * v1 - v2;
  }

  double lp(double x) {
    process(x);
    return low;
  }

  double bp(double x) {
    process(x);
    return band;
  }

  double hp(double x) {
    process(x);
    return high;
  }
}

/// One-pole smoother / tone control.
final class OnePole {
  OnePole(int sr, double hz) : _a = 1.0 - math.exp(-twoPi * hz / sr);

  final double _a;
  double z = 0;

  double lp(double x) => z += _a * (x - z);
  double hp(double x) => x - (z += _a * (x - z));
}

/// Raised-cosine fade-in / fade-out in place.
void fadeEdges(Float64List x, int inN, int outN) {
  final a = math.min(inN, x.length);
  for (var i = 0; i < a; i++) {
    x[i] *= 0.5 - 0.5 * math.cos(math.pi * i / a);
  }
  final b = math.min(outN, x.length);
  final s = x.length - b;
  for (var i = 0; i < b; i++) {
    x[s + i] *= 0.5 + 0.5 * math.cos(math.pi * (i + 1) / b);
  }
}

/// Soft saturation (tanh-like, unity slope at 0).
double soft(double x) {
  if (x > 3) return 1;
  if (x < -3) return -1;
  final x2 = x * x;
  return x * (27 + x2) / (27 + 9 * x2);
}

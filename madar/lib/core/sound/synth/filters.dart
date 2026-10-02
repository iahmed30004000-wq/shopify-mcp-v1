import 'dart:math' as math;
import 'dart:typed_data';

/// One-pole low-pass (6 dB/oct) – cheap smoothing and tone darkening.
final class OnePoleLowPass {
  OnePoleLowPass(double cutoffHz, int sampleRate) {
    setCutoff(cutoffHz, sampleRate);
  }

  double _a = 0;
  double _z = 0;

  void setCutoff(double cutoffHz, int sampleRate) {
    _a = 1.0 - math.exp(-2.0 * math.pi * cutoffHz / sampleRate);
  }

  double process(double x) => _z += _a * (x - _z);

  void processBuffer(Float64List x) {
    var z = _z;
    final a = _a;
    for (var i = 0; i < x.length; i++) {
      z += a * (x[i] - z);
      x[i] = z;
    }
    _z = z;
  }

  void reset() => _z = 0;
}

/// One-pole high-pass (6 dB/oct).
final class OnePoleHighPass {
  OnePoleHighPass(double cutoffHz, int sampleRate) : _lp = OnePoleLowPass(cutoffHz, sampleRate);

  final OnePoleLowPass _lp;

  double process(double x) => x - _lp.process(x);

  void processBuffer(Float64List x) {
    for (var i = 0; i < x.length; i++) {
      x[i] = x[i] - _lp.process(x[i]);
    }
  }
}

/// DC blocker (`y = x − x₁ + R·y₁`).
final class DcBlocker {
  DcBlocker({this.r = 0.995});

  final double r;
  double _x1 = 0;
  double _y1 = 0;

  double process(double x) {
    final y = x - _x1 + r * _y1;
    _x1 = x;
    _y1 = y;
    return y;
  }

  void processBuffer(Float64List x) {
    for (var i = 0; i < x.length; i++) {
      x[i] = process(x[i]);
    }
  }
}

enum BiquadType { lowPass, highPass, bandPass, peaking, lowShelf, highShelf }

/// RBJ "Audio EQ Cookbook" biquad, transposed direct form II.
final class Biquad {
  Biquad(this.type, {required double frequency, required int sampleRate, double q = 0.7071, double gainDb = 0}) {
    configure(frequency: frequency, sampleRate: sampleRate, q: q, gainDb: gainDb);
  }

  final BiquadType type;
  double _b0 = 1, _b1 = 0, _b2 = 0, _a1 = 0, _a2 = 0;
  double _z1 = 0, _z2 = 0;

  void configure({required double frequency, required int sampleRate, double q = 0.7071, double gainDb = 0}) {
    final f = frequency.clamp(10.0, sampleRate * 0.49);
    final w0 = 2.0 * math.pi * f / sampleRate;
    final cw = math.cos(w0);
    final sw = math.sin(w0);
    final alpha = sw / (2.0 * q);
    final big = math.pow(10.0, gainDb / 40.0).toDouble();
    double b0, b1, b2, a0, a1, a2;
    switch (type) {
      case BiquadType.lowPass:
        b0 = (1 - cw) / 2;
        b1 = 1 - cw;
        b2 = (1 - cw) / 2;
        a0 = 1 + alpha;
        a1 = -2 * cw;
        a2 = 1 - alpha;
      case BiquadType.highPass:
        b0 = (1 + cw) / 2;
        b1 = -(1 + cw);
        b2 = (1 + cw) / 2;
        a0 = 1 + alpha;
        a1 = -2 * cw;
        a2 = 1 - alpha;
      case BiquadType.bandPass:
        // Constant 0 dB peak gain.
        b0 = alpha;
        b1 = 0;
        b2 = -alpha;
        a0 = 1 + alpha;
        a1 = -2 * cw;
        a2 = 1 - alpha;
      case BiquadType.peaking:
        b0 = 1 + alpha * big;
        b1 = -2 * cw;
        b2 = 1 - alpha * big;
        a0 = 1 + alpha / big;
        a1 = -2 * cw;
        a2 = 1 - alpha / big;
      case BiquadType.lowShelf:
        final s = 2 * math.sqrt(big) * alpha;
        b0 = big * ((big + 1) - (big - 1) * cw + s);
        b1 = 2 * big * ((big - 1) - (big + 1) * cw);
        b2 = big * ((big + 1) - (big - 1) * cw - s);
        a0 = (big + 1) + (big - 1) * cw + s;
        a1 = -2 * ((big - 1) + (big + 1) * cw);
        a2 = (big + 1) + (big - 1) * cw - s;
      case BiquadType.highShelf:
        final s = 2 * math.sqrt(big) * alpha;
        b0 = big * ((big + 1) + (big - 1) * cw + s);
        b1 = -2 * big * ((big - 1) + (big + 1) * cw);
        b2 = big * ((big + 1) + (big - 1) * cw - s);
        a0 = (big + 1) - (big - 1) * cw + s;
        a1 = 2 * ((big - 1) - (big + 1) * cw);
        a2 = (big + 1) - (big - 1) * cw - s;
    }
    _b0 = b0 / a0;
    _b1 = b1 / a0;
    _b2 = b2 / a0;
    _a1 = a1 / a0;
    _a2 = a2 / a0;
  }

  double process(double x) {
    final y = _b0 * x + _z1;
    _z1 = _b1 * x - _a1 * y + _z2;
    _z2 = _b2 * x - _a2 * y;
    return y;
  }

  void processBuffer(Float64List x, [int start = 0, int? end]) {
    final b0 = _b0, b1 = _b1, b2 = _b2, a1 = _a1, a2 = _a2;
    var z1 = _z1, z2 = _z2;
    final e = end ?? x.length;
    for (var i = start; i < e; i++) {
      final v = x[i];
      final y = b0 * v + z1;
      z1 = b1 * v - a1 * y + z2;
      z2 = b2 * v - a2 * y;
      x[i] = y;
    }
    _z1 = z1;
    _z2 = z2;
  }

  void reset() => _z1 = _z2 = 0;
}

/// Topology-preserving state-variable filter (Zavalishin / Simper). Stable
/// under fast cutoff modulation, so it drives every swept sound: whooshes,
/// wind and the pads' moving low-pass.
final class Svf {
  Svf({required this.sampleRate, double cutoff = 1000, double q = 0.7071}) {
    set(cutoff, q);
  }

  final int sampleRate;
  double _g = 0, _k = 0, _a1 = 0, _a2 = 0, _a3 = 0;
  double _ic1 = 0, _ic2 = 0;

  /// Outputs of the last [process] call.
  double low = 0, band = 0, high = 0;

  void set(double cutoff, double q) {
    final f = cutoff.clamp(10.0, sampleRate * 0.45);
    _g = math.tan(math.pi * f / sampleRate);
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
}

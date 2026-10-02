import 'dart:math' as math;
import 'dart:typed_data';

/// Linear-interpolated sine lookup. Phases are expressed in *cycles* (1.0 is
/// one full turn), which keeps phase accumulators free of `2π` factors.
///
/// 4096 points + linear interpolation gives < −130 dB error – far below the
/// 16-bit noise floor – at a fraction of the cost of `math.sin`.
abstract final class SineTable {
  static const int size = 4096;
  static final Float64List _table = _build();

  static Float64List _build() {
    final t = Float64List(size + 1);
    for (var i = 0; i <= size; i++) {
      t[i] = math.sin(2.0 * math.pi * i / size);
    }
    return t;
  }

  /// `sin(2π·phase)` for any real [phase].
  static double at(double phase) {
    final p = phase - phase.floorToDouble();
    final x = p * size;
    final i = x.toInt();
    final a = _table[i];
    return a + (_table[i + 1] - a) * (x - i);
  }

  /// Fast path for phases already wrapped into `[0, 1)`.
  static double wrapped(double p) {
    final x = p * size;
    final i = x.toInt();
    final a = _table[i];
    return a + (_table[i + 1] - a) * (x - i);
  }
}

/// PolyBLEP residual (Välimäki & Huovilainen) – subtracts the aliasing of a
/// naive discontinuity. [t] is the phase in cycles, [dt] the phase increment.
double polyBlep(double t, double dt) {
  if (t < dt) {
    final x = t / dt;
    return x + x - x * x - 1.0;
  }
  if (t > 1.0 - dt) {
    final x = (t - 1.0) / dt;
    return x * x + x + x + 1.0;
  }
  return 0.0;
}

/// Band-limited ("soft") sawtooth via polyBLEP.
final class PolyBlepSaw {
  PolyBlepSaw({required double frequency, required this.sampleRate, double phase = 0})
      : _phase = phase - phase.floorToDouble(),
        _dt = frequency / sampleRate;

  final int sampleRate;
  double _phase;
  double _dt;

  set frequency(double hz) => _dt = hz / sampleRate;

  double next() {
    final t = _phase;
    var y = 2.0 * t - 1.0;
    y -= polyBlep(t, _dt);
    _phase = t + _dt;
    if (_phase >= 1.0) _phase -= 1.0;
    return y;
  }
}

/// Triangle oscillator. Its harmonics fall at 12 dB/octave, so a naive
/// implementation is already soft enough for UI sounds.
final class TriangleOsc {
  TriangleOsc({required double frequency, required this.sampleRate, double phase = 0})
      : _phase = phase - phase.floorToDouble(),
        _dt = frequency / sampleRate;

  final int sampleRate;
  double _phase;
  double _dt;

  set frequency(double hz) => _dt = hz / sampleRate;

  double next() {
    final t = _phase;
    final y = t < 0.5 ? 4.0 * t - 1.0 : 3.0 - 4.0 * t;
    _phase = t + _dt;
    if (_phase >= 1.0) _phase -= 1.0;
    return y;
  }
}

/// Sine oscillator with a settable frequency (for glides / vibrato).
final class SineOsc {
  SineOsc({required double frequency, required this.sampleRate, double phase = 0})
      : _phase = phase - phase.floorToDouble(),
        _dt = frequency / sampleRate;

  final int sampleRate;
  double _phase;
  double _dt;

  set frequency(double hz) => _dt = hz / sampleRate;

  double next() {
    final y = SineTable.wrapped(_phase);
    _phase += _dt;
    if (_phase >= 1.0) _phase -= 1.0;
    return y;
  }
}

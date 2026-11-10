import 'dart:math' as math;

import 'compass_math.dart';

/// Smoothing factor of a first-order low-pass with time constant [tau]
/// (seconds) over a step of [dt] seconds.
double lowPassAlpha(double dt, double tau) {
  if (dt <= 0) return 0;
  if (tau <= 0) return 1;
  return dt / (tau + dt);
}

/// The "1€ filter" (Casiez, Roussel & Vogel, CHI 2012) on the circle:
/// heavy smoothing while the heading is still (jitter disappears), a cutoff
/// that rises with the angular speed while turning (little lag). All
/// arithmetic is on signed shortest turns, so 359° → 1° is a 2° step, never a
/// 358° swing.
class CircularOneEuroFilter {
  CircularOneEuroFilter({this.minCutoff = 0.8, this.beta = 0.02, this.derivativeCutoff = 1.2});

  /// Cutoff (Hz) at rest.
  final double minCutoff;

  /// Cutoff increase per °/s of angular speed.
  final double beta;

  /// Cutoff (Hz) of the speed estimate.
  final double derivativeCutoff;

  double? _value;
  double _speed = 0;

  /// The filtered angle in [0, 360) (null before the first sample).
  double? get value => _value;

  /// The smoothed angular speed (°/s, signed).
  double get speed => _speed;

  /// Feeds [angle] (degrees) observed [dt] seconds after the previous one.
  double filter(double angle, double dt) {
    final prev = _value;
    if (prev == null || dt > 1.0) {
      // First sample, or a gap long enough that the old state is stale.
      _speed = 0;
      return _value = CircularMath.wrap360(angle);
    }
    if (dt <= 0) return prev;
    final step = CircularMath.delta(prev, angle);
    final rawSpeed = step / dt;
    _speed += lowPassAlpha(dt, 1 / (2 * math.pi * derivativeCutoff)) * (rawSpeed - _speed);
    final cutoff = minCutoff + beta * _speed.abs();
    final a = lowPassAlpha(dt, 1 / (2 * math.pi * cutoff));
    return _value = CircularMath.wrap360(prev + a * step);
  }

  void reset() {
    _value = null;
    _speed = 0;
  }
}

/// First-order low-pass of a vector with a time constant (seconds).
class Vec3LowPass {
  Vec3LowPass(this.tau);

  final double tau;
  Vec3? _value;

  Vec3? get value => _value;

  Vec3 add(Vec3 v, double dt) {
    final prev = _value;
    if (prev == null || dt > 1.0) return _value = v;
    return _value = prev.lerp(v, lowPassAlpha(dt, tau));
  }

  void reset() => _value = null;
}

/// Exponentially weighted mean and standard deviation of a scalar.
class EwmStats {
  EwmStats(this.tau);

  final double tau;
  double? _mean;
  double _var = 0;

  double? get mean => _mean;
  double get std => math.sqrt(math.max(0.0, _var));

  void add(double x, double dt) {
    final m = _mean;
    if (m == null || dt > 1.0) {
      _mean = x;
      _var = 0;
      return;
    }
    final a = lowPassAlpha(dt, tau);
    final d = x - m;
    _mean = m + a * d;
    _var = (1 - a) * (_var + a * d * d);
  }

  void reset() {
    _mean = null;
    _var = 0;
  }
}

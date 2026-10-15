import 'dart:math' as math;

import 'circular_filter.dart';
import 'compass_math.dart';
import 'heading.dart';
import 'tilt_compass.dart';

/// Turns raw accelerometer + magnetometer samples into [HeadingReading]s:
/// light low-pass of both vectors, tilt compensation ([TiltCompass]), a 1€
/// filter on the unit circle for the heading, and running statistics for
/// the accuracy estimate (field-strength spread, heading jitter,
/// steadiness). Pure Dart – fed by the sensor plugin in production and by
/// synthetic vectors in tests.
class HeadingEngine {
  HeadingEngine({
    this.landscape = false,
    double gravityTau = 0.08,
    double magneticTau = 0.03,
    CircularOneEuroFilter? filter,
  }) : _gravity = Vec3LowPass(gravityTau),
       _magnetic = Vec3LowPass(magneticTau),
       _filter = filter ?? CircularOneEuroFilter();

  /// Whether the screen is in landscape (the forward axis is then the
  /// device's x axis; which end is chosen from gravity).
  final bool landscape;

  final Vec3LowPass _gravity;
  final Vec3LowPass _magnetic;
  final CircularOneEuroFilter _filter;
  final EwmStats _field = EwmStats(1.0);
  final EwmStats _shake = EwmStats(0.4);
  double _jitterSq = 0;
  Duration? _lastAccel;
  Duration? _lastMag;
  int? _turns;

  /// Gravity estimate (low-passed accelerometer), if any.
  Vec3? get gravity => _gravity.value;

  void addAccelerometer(Vec3 a, Duration t) {
    final dt = _dt(_lastAccel, t);
    _lastAccel = t;
    _gravity.add(a, dt);
    _shake.add((a.length - TiltCompass.g0).abs(), dt);
  }

  /// Feeds a magnetometer sample; returns a reading once gravity is known
  /// and the geometry is solvable.
  HeadingReading? addMagnetometer(Vec3 b, Duration t) {
    final dt = _dt(_lastMag, t);
    _lastMag = t;
    final m = _magnetic.add(b, dt);
    final g = _gravity.value;
    if (g == null) return null;
    final turns = landscape ? (_turns = TiltCompass.landscapeTurns(g, previous: _turns)) : 0;
    final s = TiltCompass.solve(g, m, quarterTurns: turns);
    if (s == null) return null;
    _field.add(s.fieldMicroTesla, dt);
    final smooth = _filter.filter(s.heading, dt);
    final dev = CircularMath.delta(smooth, s.heading);
    _jitterSq += lowPassAlpha(dt, 0.8) * (dev * dev - _jitterSq);
    final shake = _shake.mean ?? 0;
    return HeadingReading(
      heading: smooth,
      rawHeading: s.heading,
      fieldMicroTesla: _field.mean ?? s.fieldMicroTesla,
      fieldSpread: _field.std,
      dip: s.dip,
      jitter: math.sqrt(math.max(0.0, _jitterSq)),
      pitch: s.pitch,
      roll: s.roll,
      pointing: s.pointing,
      steady: shake < 1.0,
      timestamp: t,
    );
  }

  void reset() {
    _gravity.reset();
    _magnetic.reset();
    _filter.reset();
    _field.reset();
    _shake.reset();
    _jitterSq = 0;
    _lastAccel = null;
    _lastMag = null;
    _turns = null;
  }

  static double _dt(Duration? last, Duration now) {
    if (last == null) return 0;
    final d = (now - last).inMicroseconds / 1e6;
    return d < 0 ? 0 : d;
  }
}

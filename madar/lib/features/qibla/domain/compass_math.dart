import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// A 3-vector in a sensor's frame (Android device axes: x right, y toward
/// the top of the screen, z out of the screen).
@immutable
class Vec3 {
  const Vec3(this.x, this.y, this.z);

  static const zero = Vec3(0, 0, 0);

  final double x, y, z;

  Vec3 operator +(Vec3 o) => Vec3(x + o.x, y + o.y, z + o.z);
  Vec3 operator -(Vec3 o) => Vec3(x - o.x, y - o.y, z - o.z);
  Vec3 operator *(double k) => Vec3(x * k, y * k, z * k);
  Vec3 operator -() => Vec3(-x, -y, -z);

  double dot(Vec3 o) => x * o.x + y * o.y + z * o.z;

  Vec3 cross(Vec3 o) => Vec3(y * o.z - z * o.y, z * o.x - x * o.z, x * o.y - y * o.x);

  double get length => math.sqrt(x * x + y * y + z * z);

  /// Unit vector (zero stays zero).
  Vec3 get normalized {
    final l = length;
    return l < 1e-12 ? Vec3.zero : this * (1 / l);
  }

  /// Linear interpolation toward [o] by [t].
  Vec3 lerp(Vec3 o, double t) => Vec3(x + (o.x - x) * t, y + (o.y - y) * t, z + (o.z - z) * t);

  bool get isFinite => x.isFinite && y.isFinite && z.isFinite;

  @override
  bool operator ==(Object other) => other is Vec3 && other.x == x && other.y == y && other.z == z;

  @override
  int get hashCode => Object.hash(x, y, z);

  @override
  String toString() => 'Vec3(${x.toStringAsFixed(3)}, ${y.toStringAsFixed(3)}, ${z.toStringAsFixed(3)})';
}

/// Angles on the circle (degrees).
abstract final class CircularMath {
  static const double degPerRad = 180 / math.pi;
  static const double radPerDeg = math.pi / 180;

  /// [deg] in [0, 360).
  static double wrap360(double deg) {
    final w = deg % 360;
    return w < 0 ? w + 360 : (w >= 360 ? 0 : w);
  }

  /// [deg] in (−180, 180] – the signed shortest turn.
  static double wrap180(double deg) {
    final w = wrap360(deg);
    return w > 180 ? w - 360 : w;
  }

  /// Signed shortest turn from [from] to [to] (positive = clockwise).
  static double delta(double from, double to) => wrap180(to - from);

  /// The representative of [angle] (mod 360) closest to [reference] – for
  /// driving continuous animations (a needle never spins the long way round
  /// when a reading crosses 359° → 0°).
  static double unwrapNear(double angle, double reference) => reference + wrap180(angle - reference);

  /// Circular mean of [angles] (degrees), or null when they cancel out.
  static double? mean(Iterable<double> angles) {
    var s = 0.0, c = 0.0;
    var n = 0;
    for (final a in angles) {
      s += math.sin(a * radPerDeg);
      c += math.cos(a * radPerDeg);
      n++;
    }
    if (n == 0 || (s.abs() < 1e-9 && c.abs() < 1e-9)) return null;
    return wrap360(math.atan2(s, c) * degPerRad);
  }

  /// Circular standard deviation of [angles] (degrees).
  static double spread(Iterable<double> angles) {
    var s = 0.0, c = 0.0;
    var n = 0;
    for (final a in angles) {
      s += math.sin(a * radPerDeg);
      c += math.cos(a * radPerDeg);
      n++;
    }
    if (n == 0) return 0;
    final r = (math.sqrt(s * s + c * c) / n).clamp(1e-9, 1.0);
    return math.sqrt(-2 * math.log(r)) * degPerRad;
  }
}

/// The eight compass points (N, NE … NW), clockwise from north.
enum CompassPoint {
  north,
  northEast,
  east,
  southEast,
  south,
  southWest,
  west,
  northWest;

  /// The nearest point to [bearing] (degrees from true north).
  static CompassPoint of(double bearing) => values[((CircularMath.wrap360(bearing) + 22.5) ~/ 45) % 8];

  /// The point's own bearing.
  double get bearing => index * 45.0;
}

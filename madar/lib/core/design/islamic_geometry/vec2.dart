import 'dart:math' as math;

/// Minimal 2-D vector for the pure geometry layer (no Flutter types, so the
/// whole pattern generator can be unit-tested and run off the UI isolate).
class Vec2 {
  const Vec2(this.x, this.y);

  static const zero = Vec2(0, 0);

  final double x;
  final double y;

  /// Unit vector at [angle] radians (counter-clockwise in a y-up frame,
  /// clockwise on screen where y points down).
  factory Vec2.polar(double angle, [double radius = 1]) => Vec2(math.cos(angle) * radius, math.sin(angle) * radius);

  Vec2 operator +(Vec2 o) => Vec2(x + o.x, y + o.y);
  Vec2 operator -(Vec2 o) => Vec2(x - o.x, y - o.y);
  Vec2 operator -() => Vec2(-x, -y);
  Vec2 operator *(double k) => Vec2(x * k, y * k);

  double get length => math.sqrt(x * x + y * y);
  double get angle => math.atan2(y, x);
  bool get isFinite => x.isFinite && y.isFinite;

  double dot(Vec2 o) => x * o.x + y * o.y;

  /// z-component of the 3-D cross product.
  double cross(Vec2 o) => x * o.y - y * o.x;

  Vec2 normalized() {
    final l = length;
    return l < 1e-12 ? zero : Vec2(x / l, y / l);
  }

  /// Rotated by [a] radians about the origin.
  Vec2 rotated(double a) {
    final c = math.cos(a), s = math.sin(a);
    return Vec2(x * c - y * s, x * s + y * c);
  }

  double distanceTo(Vec2 o) => (this - o).length;

  @override
  bool operator ==(Object other) => other is Vec2 && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => 'Vec2($x, $y)';
}

/// 2D vectors and collision tests (continuous / swept where it matters).
library;

import 'dart:math' as math;

/// An immutable 2D vector (y grows downwards, like the screen).
final class Vec2 {
  const Vec2(this.x, this.y);

  static const Vec2 zero = Vec2(0, 0);

  final double x;
  final double y;

  Vec2 operator +(Vec2 o) => Vec2(x + o.x, y + o.y);
  Vec2 operator -(Vec2 o) => Vec2(x - o.x, y - o.y);
  Vec2 operator *(double k) => Vec2(x * k, y * k);
  Vec2 operator /(double k) => Vec2(x / k, y / k);
  Vec2 operator -() => Vec2(-x, -y);

  double dot(Vec2 o) => x * o.x + y * o.y;
  double cross(Vec2 o) => x * o.y - y * o.x;
  double get length => math.sqrt(x * x + y * y);
  double get length2 => x * x + y * y;

  Vec2 get normalized {
    final l = length;
    return l == 0 ? Vec2.zero : Vec2(x / l, y / l);
  }

  /// Perpendicular (rotated +90° in screen coordinates).
  Vec2 get perp => Vec2(-y, x);

  Vec2 rotate(double a) {
    final c = math.cos(a), s = math.sin(a);
    return Vec2(x * c - y * s, x * s + y * c);
  }

  /// Reflection of this velocity off a surface with unit [normal].
  Vec2 reflect(Vec2 normal) => this - normal * (2 * dot(normal));

  static Vec2 fromAngle(double a, [double len = 1]) => Vec2(math.cos(a) * len, math.sin(a) * len);

  List<double> toJson() => [(x * 10000).roundToDouble() / 10000, (y * 10000).roundToDouble() / 10000];

  @override
  bool operator ==(Object other) => other is Vec2 && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => '(${x.toStringAsFixed(2)}, ${y.toStringAsFixed(2)})';
}

/// Axis-aligned box.
final class Aabb {
  const Aabb(this.left, this.top, this.right, this.bottom);

  Aabb.fromCenter(Vec2 c, double halfW, double halfH) : this(c.x - halfW, c.y - halfH, c.x + halfW, c.y + halfH);

  final double left;
  final double top;
  final double right;
  final double bottom;

  double get width => right - left;
  double get height => bottom - top;
  Vec2 get center => Vec2((left + right) / 2, (top + bottom) / 2);

  bool contains(Vec2 p) => p.x >= left && p.x <= right && p.y >= top && p.y <= bottom;

  bool overlaps(Aabb o) => left < o.right && o.left < right && top < o.bottom && o.top < bottom;

  Aabb inflate(double d) => Aabb(left - d, top - d, right + d, bottom + d);

  Vec2 clamp(Vec2 p) => Vec2(p.x.clamp(left, right), p.y.clamp(top, bottom));
}

/// A time of impact along a sweep (`t` in [0, 1]) and the contact normal.
final class SweepHit {
  const SweepHit(this.t, this.normal);
  final double t;
  final Vec2 normal;
}

/// Earliest `t` in [0, 1] where the ray `p + t·d` hits the circle, or null.
double? rayCircle(Vec2 p, Vec2 d, Vec2 c, double r) {
  final m = p - c;
  final a = d.length2;
  final b = m.dot(d);
  final cc = m.length2 - r * r;
  if (cc <= 0) return 0; // starts inside
  if (a == 0 || b > 0) return null;
  final disc = b * b - a * cc;
  if (disc < 0) return null;
  final t = (-b - math.sqrt(disc)) / a;
  return t >= 0 && t <= 1 ? t : null;
}

/// Swept circle (centre [p], radius [r], displacement [d]) against a box.
///
/// Exact: the Minkowski sum of the box and the circle is a rounded box; the
/// ray is tested against its flat faces and its four corner circles. When
/// the circle already overlaps the box the hit is at `t = 0` with the
/// normal of least penetration.
SweepHit? sweepCircleAabb(Vec2 p, Vec2 d, double r, Aabb box) {
  // Already overlapping?
  final closest = box.clamp(p);
  final off = p - closest;
  if (off.length2 < r * r) {
    if (off.length2 > 1e-12) return SweepHit(0, off.normalized);
    // Centre inside the box: push out through the nearest face.
    final dl = p.x - box.left, dr = box.right - p.x, dt = p.y - box.top, db = box.bottom - p.y;
    final m = [dl, dr, dt, db].reduce(math.min);
    final n = m == dl ? const Vec2(-1, 0) : (m == dr ? const Vec2(1, 0) : (m == dt ? const Vec2(0, -1) : const Vec2(0, 1)));
    return SweepHit(0, n);
  }
  SweepHit? best;
  void consider(double t, Vec2 n) {
    if (t < 0 || t > 1) return;
    if (best == null || t < best!.t) best = SweepHit(t, n);
  }

  // Faces of the expanded box, restricted to the original box's extent.
  if (d.x > 0) {
    final t = (box.left - r - p.x) / d.x;
    final y = p.y + d.y * t;
    if (y >= box.top && y <= box.bottom) consider(t, const Vec2(-1, 0));
  } else if (d.x < 0) {
    final t = (box.right + r - p.x) / d.x;
    final y = p.y + d.y * t;
    if (y >= box.top && y <= box.bottom) consider(t, const Vec2(1, 0));
  }
  if (d.y > 0) {
    final t = (box.top - r - p.y) / d.y;
    final x = p.x + d.x * t;
    if (x >= box.left && x <= box.right) consider(t, const Vec2(0, -1));
  } else if (d.y < 0) {
    final t = (box.bottom + r - p.y) / d.y;
    final x = p.x + d.x * t;
    if (x >= box.left && x <= box.right) consider(t, const Vec2(0, 1));
  }
  // Rounded corners.
  for (final c in [
    Vec2(box.left, box.top),
    Vec2(box.right, box.top),
    Vec2(box.left, box.bottom),
    Vec2(box.right, box.bottom),
  ]) {
    final t = rayCircle(p, d, c, r);
    if (t != null) consider(t, ((p + d * t) - c).normalized);
  }
  return best;
}

/// Closest point to [p] on segment [a]–[b].
Vec2 closestOnSegment(Vec2 p, Vec2 a, Vec2 b) {
  final ab = b - a;
  final l2 = ab.length2;
  if (l2 == 0) return a;
  final t = ((p - a).dot(ab) / l2).clamp(0.0, 1.0);
  return a + ab * t;
}

/// Whether segment [a]–[b] passes within [r] of [c].
bool segmentHitsCircle(Vec2 a, Vec2 b, Vec2 c, double r) => (closestOnSegment(c, a, b) - c).length2 <= r * r;

/// Whether two circles overlap.
bool circlesOverlap(Vec2 a, double ra, Vec2 b, double rb) => (a - b).length2 < (ra + rb) * (ra + rb);

/// Shortest offset from [a] to [b] on a torus of size [w]×[h].
Vec2 wrapDelta(Vec2 a, Vec2 b, double w, double h) {
  var dx = b.x - a.x, dy = b.y - a.y;
  if (dx > w / 2) dx -= w;
  if (dx < -w / 2) dx += w;
  if (dy > h / 2) dy -= h;
  if (dy < -h / 2) dy += h;
  return Vec2(dx, dy);
}

/// Wraps [p] into `[0, w) × [0, h)`.
Vec2 wrapPoint(Vec2 p, double w, double h) => Vec2(((p.x % w) + w) % w, ((p.y % h) + h) % h);

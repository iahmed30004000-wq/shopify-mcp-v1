/// Exact tangram geometry.
///
/// Every tan edge runs at a multiple of 45°, so with the square tan's side
/// as the unit all coordinates live in Z[√2]. Coordinates are stored scaled
/// by 4 ("quarter units") as `a + b√2` with integer `a`, `b`, which keeps
/// rotations, snapping, convex clipping and areas exact: no floating point
/// tolerance is involved in deciding whether a silhouette is covered.
library;

import 'dart:math' as math;

/// Scale between stored integers and tan units (square side = 1).
const int kTanScale = 4;

/// The number `a + b√2`.
final class Surd implements Comparable<Surd> {
  const Surd(this.a, [this.b = 0]);

  static const Surd zero = Surd(0);

  final int a;
  final int b;

  Surd operator +(Surd o) => Surd(a + o.a, b + o.b);
  Surd operator -(Surd o) => Surd(a - o.a, b - o.b);
  Surd operator -() => Surd(-a, -b);
  Surd operator *(Surd o) => Surd(a * o.a + 2 * b * o.b, a * o.b + b * o.a);

  /// Exact halving (both parts must be even).
  Surd half() {
    assert(a.isEven && b.isEven, 'odd surd halved: $this');
    return Surd(a ~/ 2, b ~/ 2);
  }

  /// Multiplication by √2/2 (requires even `a`).
  Surd timesHalfRoot2() {
    assert(a.isEven, 'odd surd rotated: $this');
    return Surd(b, a ~/ 2);
  }

  /// -1, 0 or 1, computed exactly.
  int get sign {
    if (a >= 0 && b >= 0) return (a == 0 && b == 0) ? 0 : 1;
    if (a <= 0 && b <= 0) return -1;
    final a2 = a * a, b2 = 2 * b * b;
    if (a > 0) return a2 > b2 ? 1 : (a2 < b2 ? -1 : 0);
    return a2 > b2 ? -1 : (a2 < b2 ? 1 : 0);
  }

  bool get isZero => a == 0 && b == 0;

  double toDouble() => a + b * math.sqrt2;

  @override
  int compareTo(Surd other) => (this - other).sign;

  @override
  bool operator ==(Object other) => other is Surd && other.a == a && other.b == b;

  @override
  int get hashCode => Object.hash(a, b);

  List<int> toJson() => [a, b];

  static Surd fromJson(Object? j) {
    final l = j! as List;
    return Surd((l[0] as num).toInt(), (l[1] as num).toInt());
  }

  @override
  String toString() => b == 0 ? '$a' : (a == 0 ? '$b√2' : '($a${b < 0 ? '' : '+'}$b√2)');
}

/// A point with exact coordinates (quarter units).
final class SPoint {
  const SPoint(this.x, this.y);

  /// From integers (quarter units, rational part only).
  SPoint.ints(int x, int y) : x = Surd(x), y = Surd(y);

  final Surd x;
  final Surd y;

  SPoint operator +(SPoint o) => SPoint(x + o.x, y + o.y);
  SPoint operator -(SPoint o) => SPoint(x - o.x, y - o.y);

  /// Rotation by `k` × 45° (counter-clockwise in a y-up frame, clockwise on
  /// a y-down screen).
  SPoint rotate(int k) {
    var p = this;
    final q = ((k % 8) + 8) % 8;
    for (var i = 0; i < q ~/ 2; i++) {
      p = SPoint(-p.y, p.x);
    }
    if (q.isOdd) p = SPoint((p.x - p.y).timesHalfRoot2(), (p.x + p.y).timesHalfRoot2());
    return p;
  }

  /// Mirror across the vertical axis.
  SPoint mirror() => SPoint(-x, y);

  /// Tan-unit doubles for rendering.
  (double, double) toDouble() => (x.toDouble() / kTanScale, y.toDouble() / kTanScale);

  @override
  bool operator ==(Object other) => other is SPoint && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  List<Object> toJson() => [x.toJson(), y.toJson()];

  static SPoint fromJson(Object? j) {
    final l = j! as List;
    return SPoint(Surd.fromJson(l[0]), Surd.fromJson(l[1]));
  }

  @override
  String toString() => '($x, $y)';
}

/// Cross product of `(b - a) × (c - a)`.
Surd cross3(SPoint a, SPoint b, SPoint c) => (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x);

/// Twice the signed area (positive for the orientation used by the tans).
Surd area2(List<SPoint> poly) {
  var s = Surd.zero;
  for (var i = 0; i < poly.length; i++) {
    final p = poly[i], q = poly[(i + 1) % poly.length];
    s = s + (p.x * q.y - q.x * p.y);
  }
  return s;
}

/// The line through an edge: 0 horizontal (y = c), 1 vertical (x = c),
/// 2 falling diagonal (x − y = c), 3 rising diagonal (x + y = c).
({int family, Surd c}) _lineOf(SPoint p, SPoint q) {
  final dx = q.x - p.x, dy = q.y - p.y;
  if (dy.isZero) return (family: 0, c: p.y);
  if (dx.isZero) return (family: 1, c: p.x);
  if (dx == dy) return (family: 2, c: p.x - p.y);
  if (dx == -dy) return (family: 3, c: p.x + p.y);
  throw ArgumentError('edge $p→$q is not a multiple of 45°');
}

/// Exact intersection of two non-parallel 45°-family lines.
SPoint _intersect(({int family, Surd c}) l1, ({int family, Surd c}) l2) {
  final (f1, c1) = (l1.family, l1.c);
  final (f2, c2) = (l2.family, l2.c);
  if (f1 > f2) return _intersect(l2, l1);
  switch ((f1, f2)) {
    case (0, 1):
      return SPoint(c2, c1);
    case (0, 2):
      return SPoint(c2 + c1, c1);
    case (0, 3):
      return SPoint(c2 - c1, c1);
    case (1, 2):
      return SPoint(c1, c1 - c2);
    case (1, 3):
      return SPoint(c1, c2 - c1);
    case (2, 3):
      return SPoint((c1 + c2).half(), (c2 - c1).half());
  }
  throw StateError('parallel lines $l1 $l2');
}

/// Sutherland–Hodgman clipping of [subject] by the convex [clip] polygon
/// (both with positive orientation). Exact.
List<SPoint> clipConvex(List<SPoint> subject, List<SPoint> clip) {
  var out = subject;
  for (var i = 0; i < clip.length && out.isNotEmpty; i++) {
    final a = clip[i], b = clip[(i + 1) % clip.length];
    final line = _lineOf(a, b);
    final input = out;
    out = <SPoint>[];
    for (var j = 0; j < input.length; j++) {
      final cur = input[j], prev = input[(j - 1 + input.length) % input.length];
      final curIn = cross3(a, b, cur).sign >= 0;
      final prevIn = cross3(a, b, prev).sign >= 0;
      if (curIn) {
        if (!prevIn) out.add(_intersect(_lineOf(prev, cur), line));
        out.add(cur);
      } else if (prevIn) {
        out.add(_intersect(_lineOf(prev, cur), line));
      }
    }
  }
  return out;
}

/// Twice the area of the intersection of two convex polygons.
Surd overlapArea2(List<SPoint> p, List<SPoint> q) {
  final r = clipConvex(p, q);
  if (r.length < 3) return Surd.zero;
  return area2(r);
}

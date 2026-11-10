import 'dart:math' as math;

import 'vec2.dart';

/// Signed area (positive for counter-clockwise in a y-up frame).
double signedArea(List<Vec2> poly) {
  var s = 0.0;
  for (var i = 0; i < poly.length; i++) {
    s += poly[i].cross(poly[(i + 1) % poly.length]);
  }
  return s / 2;
}

/// Regular [n]-gon with side [side], centred at [c], first vertex at
/// [firstAngle] radians; counter-clockwise.
List<Vec2> regularPolygon(Vec2 c, int n, double side, double firstAngle) {
  final r = side / (2 * math.sin(math.pi / n));
  return List<Vec2>.generate(n, (k) => c + Vec2.polar(firstAngle + 2 * math.pi * k / n, r), growable: false);
}

/// Ray / ray intersection: where `a + t·da` meets `b + s·db` with both
/// t and s positive; null when parallel or behind either origin.
Vec2? intersectRays(Vec2 a, Vec2 da, Vec2 b, Vec2 db) {
  final det = da.x * -db.y - da.y * -db.x;
  if (det.abs() < 1e-10) return null;
  final dx = b.x - a.x, dy = b.y - a.y;
  final t = (dx * -db.y - dy * -db.x) / det;
  final s = (da.x * dy - da.y * dx) / det;
  if (t <= 1e-9 || s <= 1e-9) return null;
  return Vec2(a.x + da.x * t, a.y + da.y * t);
}

bool pointInPolygon(Vec2 p, List<Vec2> poly) {
  var inside = false;
  for (var i = 0, j = poly.length - 1; i < poly.length; j = i++) {
    final a = poly[i], b = poly[j];
    if ((a.y > p.y) != (b.y > p.y) && p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x) {
      inside = !inside;
    }
  }
  return inside;
}

/// The "polygons in contact" (Hankin / Kaplan) decoration of one tile.
///
/// At every edge midpoint two rays leave into the tile, each making
/// [theta] with the edge, one towards each end. The ray towards a vertex
/// meets the matching ray of the next edge's midpoint; joining
/// `M0, P1, M1, P2, …` gives one closed outline per tile. Because both
/// tiles sharing an edge use the same midpoint and angle, the lines of
/// neighbours continue straight through it.
///
/// Returns 2·n points, starting at the midpoint of edge 0. [poly] must be
/// counter-clockwise (see [signedArea]).
List<Vec2> hankinOutline(List<Vec2> poly, double theta) {
  final n = poly.length;
  final mid = List<Vec2>.generate(n, (i) => (poly[i] + poly[(i + 1) % n]) * 0.5, growable: false);
  final along = List<Vec2>.generate(n, (i) => (poly[(i + 1) % n] - poly[i]).normalized(), growable: false);
  final inward = List<Vec2>.generate(n, (i) => Vec2(-along[i].y, along[i].x), growable: false);
  final ct = math.cos(theta), st = math.sin(theta);

  var centroid = Vec2.zero;
  for (final v in poly) {
    centroid = centroid + v;
  }
  centroid = centroid * (1 / n);

  final reach = poly.fold<double>(0, (m, v) => math.max(m, v.distanceTo(centroid))) * 1.0001;

  final out = <Vec2>[];
  for (var i = 0; i < n; i++) {
    final j = (i + 1) % n;
    // Ray from mid[i] towards vertex j, and from mid[j] back towards it.
    final fwd = along[i] * ct + inward[i] * st;
    final back = along[j] * -ct + inward[j] * st;
    var p = intersectRays(mid[i], fwd, mid[j], back);
    final between = (mid[i] + mid[j]) * 0.5;
    if (p == null) {
      // Parallel rays. If they lie on one line pointing at each other (an
      // angle equal to the corner, e.g. 60 degrees in a triangle) the rays
      // meet half-way along the midline; otherwise they never meet.
      final gap = mid[j] - mid[i];
      p = gap.cross(fwd).abs() < 1e-9 && gap.dot(fwd) > 0 ? between : poly[j] + (centroid - poly[j]) * 0.5;
    } else if (!p.isFinite || p.distanceTo(centroid) > reach) {
      // Near-parallel rays meet far outside the tile: keep the shape sane.
      p = between;
    }
    out
      ..add(mid[i])
      ..add(p);
  }
  return out;
}

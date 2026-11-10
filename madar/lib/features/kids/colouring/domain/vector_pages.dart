// The built-in colouring pages: Islamic geometric patterns, made from the
// finished library in lib/core/design/islamic_geometry (Hankin "polygons in
// contact"). The library gives, for each tile, a star outline; here those
// outlines become REGIONS a child can fill:
//
//  * the inside of each star;
//  * the pieces left around every corner of the tiling: where the tiles
//    around a corner are all present those pieces are joined into one region
//    (the shape real patterns have), at the edge of a patch they stay single;
//  * for a lone medallion, a smaller star and a small centre inside it.
//
// Pure Dart (the library's geometry has no Flutter types), deterministic, and
// every region is a simple closed polygon in the unit square.
import 'dart:math' as math;

import 'package:madar/core/design/islamic_geometry/islamic_geometry.dart';

class VectorRegion {
  VectorRegion(this.points) : area = _area(points).abs();

  /// A closed polygon (the last point joins the first), in the unit square.
  final List<Vec2> points;
  final double area;

  bool contains(Vec2 p) {
    var inside = false;
    for (var i = 0, j = points.length - 1; i < points.length; j = i++) {
      final a = points[i], b = points[j];
      if ((a.y > p.y) != (b.y > p.y) && p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x) {
        inside = !inside;
      }
    }
    return inside;
  }

  static double _area(List<Vec2> pts) {
    var s = 0.0;
    for (var i = 0; i < pts.length; i++) {
      s += pts[i].cross(pts[(i + 1) % pts.length]);
    }
    return s / 2;
  }
}

class VectorPage {
  VectorPage(this.id, List<VectorRegion> regions) : regions = List.unmodifiable(regions);

  /// Stable id, also the name of its saved colours.
  final String id;

  /// Largest first: paint in this order and small regions land on top of the
  /// big ones they sit inside.
  final List<VectorRegion> regions;

  /// The region under [p] (unit-square coordinates): the smallest one that
  /// contains it, or null.
  int? regionAt(Vec2 p) {
    int? best;
    for (var i = 0; i < regions.length; i++) {
      if (regions[i].contains(p) && (best == null || regions[i].area < regions[best].area)) best = i;
    }
    return best;
  }
}

abstract final class VectorPages {
  /// The pages Madar ships, in gallery order.
  static List<VectorPage> get builtIn => _all ??= [
    _medallion('khatam', PatternFamily.square4, 0.785),
    _medallion('rosette', PatternFamily.rosette12, 0.95),
    _medallion('girih', PatternFamily.girih10, 0.46),
    _medallion('hexstar', PatternFamily.hex6, 1.05),
    _patch('lattice_square', PatternFamily.square4, 0.785, 2),
    _patch('lattice_hex', PatternFamily.hex6, 1.05, 2),
  ];

  static List<VectorPage>? _all;

  static VectorPage? byId(String id) {
    for (final p in builtIn) {
      if (p.id == id) return p;
    }
    return null;
  }

  // ---- builders -------------------------------------------------------------

  static VectorPage _medallion(String id, PatternFamily family, double angle) {
    final g = PatternGeometry.build(PatternSpec(family: family, contactAngle: angle));
    final polys = <List<Vec2>>[];
    final tile = g.tiles[0];
    final star = g.lines[0].points;
    polys.add(star);
    for (final k in _kites(tile, star)) {
      polys.add(k.polygon);
    }
    polys.add([for (final p in star) p * 0.5]);
    final r = g.medallionRadius * 0.14;
    final n = family.medallionSymmetry;
    polys.add([for (var i = 0; i < n; i++) Vec2.polar(2 * math.pi * i / n + math.pi / n, r)]);
    return VectorPage(id, _normalise(polys));
  }

  static VectorPage _patch(String id, PatternFamily family, double angle, int cells) {
    final g = PatternGeometry.build(PatternSpec(family: family, contactAngle: angle));
    final polys = <List<Vec2>>[];
    final kites = <_Kite>[];
    for (var i = 0; i < cells; i++) {
      for (var j = 0; j < cells; j++) {
        final shift = g.translation1 * i.toDouble() + g.translation2 * j.toDouble();
        for (var t = 0; t < g.tiles.length; t++) {
          final tile = [for (final p in g.tiles[t]) p + shift];
          final star = [for (final p in g.lines[t].points) p + shift];
          polys.add(star);
          kites.addAll(_kites(tile, star));
        }
      }
    }
    polys.addAll(_mergeKites(kites));
    return VectorPage(id, _normalise(polys));
  }

  /// One piece for every corner of [tile]: its corner, the two edge midpoints
  /// next to it and the star's point between them.
  static List<_Kite> _kites(List<Vec2> tile, List<Vec2> star) {
    final n = tile.length;
    final out = <_Kite>[];
    for (var i = 0; i < n; i++) {
      final v = (i + 1) % n;
      final corner = tile[v];
      final mPrev = star[2 * i], tip = star[2 * i + 1], mNext = star[2 * v];
      final toNext = tile[(v + 1) % n] - corner, toPrev = tile[i] - corner;
      var sweep = math.atan2(toNext.cross(toPrev), toNext.dot(toPrev));
      if (sweep < 0) sweep += 2 * math.pi;
      out.add(_Kite(corner, mPrev, tip, mNext, sweep));
    }
    return out;
  }

  /// Joins the pieces that meet at a corner when they close a full turn.
  static List<List<Vec2>> _mergeKites(List<_Kite> kites) {
    final byCorner = <(int, int), List<_Kite>>{};
    for (final k in kites) {
      final key = ((k.corner.x * 1e5).round(), (k.corner.y * 1e5).round());
      byCorner.putIfAbsent(key, () => []).add(k);
    }
    final out = <List<Vec2>>[];
    for (final group in byCorner.values) {
      final total = group.fold<double>(0, (s, k) => s + k.sweep);
      if ((total - 2 * math.pi).abs() < 1e-3 && group.length > 1) {
        group.sort((a, b) => a.startAngle.compareTo(b.startAngle));
        out.add([
          for (final k in group) ...[k.mNext, k.tip],
        ]);
      } else {
        for (final k in group) {
          out.add(k.polygon);
        }
      }
    }
    return out;
  }

  /// Fits the polygons into the unit square (4 % margin), drops repeated
  /// points and pieces with no area, and orders them largest first.
  static List<VectorRegion> _normalise(List<List<Vec2>> polys) {
    var minX = double.infinity, minY = double.infinity, maxX = -double.infinity, maxY = -double.infinity;
    for (final poly in polys) {
      for (final p in poly) {
        minX = math.min(minX, p.x);
        minY = math.min(minY, p.y);
        maxX = math.max(maxX, p.x);
        maxY = math.max(maxY, p.y);
      }
    }
    final span = math.max(maxX - minX, maxY - minY);
    final k = 0.92 / span;
    final ox = 0.5 - (maxX + minX) / 2 * k, oy = 0.5 - (maxY + minY) / 2 * k;
    final regions = <VectorRegion>[];
    for (final poly in polys) {
      final pts = <Vec2>[];
      for (final p in poly) {
        final q = Vec2(p.x * k + ox, p.y * k + oy);
        if (pts.isEmpty || pts.last.distanceTo(q) > 1e-7) pts.add(q);
      }
      while (pts.length > 1 && pts.first.distanceTo(pts.last) <= 1e-7) {
        pts.removeLast();
      }
      if (pts.length < 3) continue;
      final r = VectorRegion(pts);
      if (r.area > 1e-5) regions.add(r);
    }
    regions.sort((a, b) => b.area.compareTo(a.area));
    return regions;
  }
}

class _Kite {
  const _Kite(this.corner, this.mPrev, this.tip, this.mNext, this.sweep);

  final Vec2 corner, mPrev, tip, mNext;

  /// The tile's angle at [corner].
  final double sweep;

  /// Direction (from the corner) where this piece's turn starts.
  double get startAngle => (mNext - corner).angle;

  List<Vec2> get polygon => [mPrev, corner, mNext, tip];
}

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import 'islamic_star_painter.dart';

/// Where two strands of the rosette cross, and which one passes over.
@immutable
class GirihCrossing {
  const GirihCrossing({required this.point, required this.overDirection, required this.overStrand, required this.underStrand});

  /// Crossing point in unit coordinates (rosette radius 1, centre 0,0).
  final Offset point;

  /// Unit direction of the strand that passes over.
  final Offset overDirection;
  final int overStrand;
  final int underStrand;
}

/// Pure geometry of an interlaced n-fold rosette in unit coordinates.
///
/// * outer strands: the {n/2} star polygon (for n = 8, the two squares of the
///   Rub el Hizb) on radius [outerRadius];
/// * inner strands: the classical sharp {n/k} star whose tips touch the
///   outer star's inner corners;
/// * crossings: every strand crossing with an alternating over/under
///   assignment along each strand (true interlace, not just draw order).
@immutable
class GirihRosetteGeometry {
  const GirihRosetteGeometry._(this.folds, this.strands, this.crossings, this.innerRadius);

  static const double outerRadius = 0.9;

  final int folds;

  /// Closed polygons (each a strand) in unit coordinates.
  final List<List<Offset>> strands;
  final List<GirihCrossing> crossings;

  /// Radius of the inner star's tips.
  final double innerRadius;

  static final Map<int, GirihRosetteGeometry> _cache = {};

  /// Memoised geometry for [folds] (5..16).
  static GirihRosetteGeometry of(int folds) => _cache.putIfAbsent(folds, () => _build(folds));

  static int innerStep(int n) => math.min(math.max(2, n ~/ 2 - 1), (n - 1) ~/ 2);

  static GirihRosetteGeometry _build(int n) {
    assert(n >= 5 && n <= 16, 'rosette folds must be 5..16');
    final strands = <List<Offset>>[];
    Offset polar(double r, double a) => Offset(math.cos(a) * r, math.sin(a) * r);
    List<List<Offset>> starPolygon(int k, double r, double phase) {
      final cycles = <List<Offset>>[];
      final g = _gcd(n, k);
      for (var start = 0; start < g; start++) {
        final cycle = <Offset>[];
        var i = start;
        do {
          cycle.add(polar(r, phase - math.pi / 2 + 2 * math.pi * i / n));
          i = (i + k) % n;
        } while (i != start);
        cycles.add(cycle);
      }
      return cycles;
    }

    // Outer {n/2}: vertices between the inner star's tips.
    strands.addAll(starPolygon(2, outerRadius, math.pi / n));
    // Inner {n/k}: tips touch the outer star's inner corners.
    final innerR = outerRadius * IslamicGeometry.starPolygonInnerRatio(n, 2);
    strands.addAll(starPolygon(innerStep(n), innerR, 0));

    // Collect edges.
    final edges = <({int strand, Offset a, Offset b})>[];
    for (var s = 0; s < strands.length; s++) {
      final poly = strands[s];
      for (var i = 0; i < poly.length; i++) {
        edges.add((strand: s, a: poly[i], b: poly[(i + 1) % poly.length]));
      }
    }

    // All proper crossings (not shared vertices / touching tips).
    final hits = <({int e1, int e2, double t1, double t2, Offset p})>[];
    for (var i = 0; i < edges.length; i++) {
      for (var j = i + 1; j < edges.length; j++) {
        final hit = _intersect(edges[i].a, edges[i].b, edges[j].a, edges[j].b);
        if (hit != null) hits.add((e1: i, e2: j, t1: hit.$1, t2: hit.$2, p: hit.$3));
      }
    }

    // Alternate over/under along each edge.
    final perEdge = <int, List<(double, int)>>{};
    for (var h = 0; h < hits.length; h++) {
      perEdge.putIfAbsent(hits[h].e1, () => []).add((hits[h].t1, h));
      perEdge.putIfAbsent(hits[h].e2, () => []).add((hits[h].t2, h));
    }
    final overVotes = <int, List<int>>{};
    for (final entry in perEdge.entries) {
      final list = entry.value..sort((a, b) => a.$1.compareTo(b.$1));
      for (var k = 0; k < list.length; k++) {
        if ((k + entry.key).isEven) overVotes.putIfAbsent(list[k].$2, () => []).add(entry.key);
      }
    }
    final crossings = <GirihCrossing>[];
    for (var h = 0; h < hits.length; h++) {
      final votes = overVotes[h] ?? const <int>[];
      final overEdge = votes.length == 1 ? votes.single : hits[h].e1;
      final underEdge = overEdge == hits[h].e1 ? hits[h].e2 : hits[h].e1;
      final e = edges[overEdge];
      final d = e.b - e.a;
      crossings.add(GirihCrossing(
        point: hits[h].p,
        overDirection: d / d.distance,
        overStrand: e.strand,
        underStrand: edges[underEdge].strand,
      ));
    }
    return GirihRosetteGeometry._(n, List.unmodifiable(strands), List.unmodifiable(crossings), innerR);
  }

  static int _gcd(int a, int b) => b == 0 ? a : _gcd(b, a % b);

  static (double, double, Offset)? _intersect(Offset p1, Offset p2, Offset p3, Offset p4) {
    const eps = 1e-6;
    final d1 = p2 - p1;
    final d2 = p4 - p3;
    final denom = d1.dx * d2.dy - d1.dy * d2.dx;
    if (denom.abs() < eps) return null;
    final w = p3 - p1;
    final t = (w.dx * d2.dy - w.dy * d2.dx) / denom;
    final u = (w.dx * d1.dy - w.dy * d1.dx) / denom;
    const m = 1e-4;
    if (t <= m || t >= 1 - m || u <= m || u >= 1 - m) return null;
    return (t, u, p1 + d1 * t);
  }
}

/// Interlaced girih rosette: strapwork bands that weave over and under,
/// inside a double ring. Vector only – crisp at any DPR.
class GirihRosettePainter extends CustomPainter {
  const GirihRosettePainter({
    this.folds = 8,
    required this.strandColor,
    this.strandInnerColor,
    this.ringColor,
    this.fillColor,
    this.centerColor,
    this.bandWidth,
    this.rotation = 0,
  });

  final int folds;
  final Color strandColor;

  /// Thin line running inside each strap (the engraved groove).
  final Color? strandInnerColor;
  final Color? ringColor;

  /// Fill of the inner star.
  final Color? fillColor;
  final Color? centerColor;

  /// Strap width in logical pixels (default: 5.5% of the radius).
  final double? bandWidth;
  final double rotation;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final geo = GirihRosetteGeometry.of(folds);
    final radius = size.shortestSide / 2;
    final center = size.center(Offset.zero);
    final w = bandWidth ?? math.max(1.2, radius * 0.055);
    final gap = w * 0.55;

    Offset map(Offset u) {
      final c = math.cos(rotation), s = math.sin(rotation);
      return center + Offset(u.dx * c - u.dy * s, u.dx * s + u.dy * c) * (radius - w);
    }

    Path poly(List<Offset> pts) => Path()..addPolygon(pts.map(map).toList(), true);

    final bounds = Offset.zero & size;
    canvas.saveLayer(bounds.inflate(2), Paint());

    // Ring.
    final ring = ringColor;
    if (ring != null) {
      final rp = Paint()
        ..color = ring
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.45;
      canvas.drawCircle(center, radius - w * 0.5, rp);
      canvas.drawCircle(center, (radius - w) * 0.97 - w * 0.4, rp..strokeWidth = w * 0.25);
    }

    // Inner star fill (below the straps).
    final fill = fillColor;
    if (fill != null) {
      final inner = IslamicGeometry.starPath(
        center: center,
        radius: geo.innerRadius * (radius - w),
        points: folds,
        innerRatio: IslamicGeometry.starPolygonInnerRatio(folds, GirihRosetteGeometry.innerStep(folds)),
        rotation: rotation,
      );
      canvas.drawPath(inner, Paint()..color = fill);
    }

    final clear = Paint()
      ..blendMode = BlendMode.clear
      ..style = PaintingStyle.stroke
      ..strokeWidth = w + gap * 2
      ..strokeJoin = StrokeJoin.miter
      ..strokeMiterLimit = 10;
    final band = Paint()
      ..color = strandColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..strokeJoin = StrokeJoin.miter
      ..strokeMiterLimit = 10;
    final groove = strandInnerColor == null
        ? null
        : (Paint()
          ..color = strandInnerColor!
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(0.5, w * 0.28)
          ..strokeJoin = StrokeJoin.miter
          ..strokeMiterLimit = 10);

    void drawStrap(Path p) {
      canvas.drawPath(p, clear);
      canvas.drawPath(p, band);
      if (groove != null) canvas.drawPath(p, groove);
    }

    for (final strand in geo.strands) {
      drawStrap(poly(strand));
    }

    // Weave: redraw the "over" strand across each crossing.
    final half = (w + gap * 2) * 1.6 / (radius - w);
    for (final x in geo.crossings) {
      final a = x.point - x.overDirection * half;
      final b = x.point + x.overDirection * half;
      final p = Path()
        ..moveTo(map(a).dx, map(a).dy)
        ..lineTo(map(b).dx, map(b).dy);
      canvas.drawPath(p, clear..strokeCap = StrokeCap.butt);
      canvas.drawPath(p, band..strokeCap = StrokeCap.butt);
      if (groove != null) canvas.drawPath(p, groove..strokeCap = StrokeCap.butt);
    }

    final centerC = centerColor;
    if (centerC != null) {
      final r = radius * 0.07;
      canvas.drawCircle(
        center,
        r,
        Paint()..shader = ui.Gradient.radial(center, r, [centerC, centerC.withValues(alpha: 0.6)]),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(GirihRosettePainter old) =>
      old.folds != folds ||
      old.strandColor != strandColor ||
      old.strandInnerColor != strandInnerColor ||
      old.ringColor != ringColor ||
      old.fillColor != fillColor ||
      old.centerColor != centerColor ||
      old.bandWidth != bandWidth ||
      old.rotation != rotation;
}

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/widgets.dart' show Matrix4;

import 'book_direction.dart';
import 'turn_logic.dart';

/// The numbers behind one frame of a page curl. Pure geometry: no canvas, no
/// widgets, so every figure can be tested.
///
/// Model: the finger holds the point [grab] of the leaf (a corner or a spot
/// on the free edge) and has dragged it to [touch]. The leaf folds along the
/// perpendicular bisector of grab-touch (the "fold line"). The part of the
/// leaf on the grab side is lifted and lands, mirrored, on the other side
/// (the "back" of the page, so grab maps exactly onto touch); the part on the
/// touch side (towards the spine) stays flat. What the lifted part leaves
/// uncovered shows the page underneath.
///
/// [touch] is first limited so the leaf never stretches: it cannot be further
/// from either spine corner than the grab point is (the leaf is hinged there).
class CurlGeometry {
  CurlGeometry._({
    required this.leaf,
    required this.spine,
    required this.grab,
    required this.touch,
    required this.backBounds,
    required this.isFlat,
    required this.foldNormal,
    required this.foldPoint,
    required this.shadowExtent,
  });

  factory CurlGeometry({
    required Rect leaf,
    required SpineSide spine,
    required Offset grab,
    required Offset touch,
    Rect? backBounds,
    double? shadowExtent,
  }) {
    final p = constrainTouch(leaf: leaf, spine: spine, grab: grab, touch: touch);
    final d = p - grab;
    final len = d.distance;
    final flat = len < 0.01;
    return CurlGeometry._(
      leaf: leaf,
      spine: spine,
      grab: grab,
      touch: p,
      backBounds: backBounds ?? leaf,
      isFlat: flat,
      foldNormal: flat ? towardSpine(spine) : d / len,
      foldPoint: Offset((grab.dx + p.dx) / 2, (grab.dy + p.dy) / 2),
      shadowExtent: shadowExtent ?? leaf.width * 0.07,
    );
  }

  final Rect leaf;
  final SpineSide spine;

  /// The held point of the leaf at rest.
  final Offset grab;

  /// Where the finger has taken it (after the no-stretch limit).
  final Offset touch;

  /// Where the back of the leaf may show (the leaf itself for a single page;
  /// the whole spread when it can cross the centre).
  final Rect backBounds;

  /// Nothing lifted yet (touch == grab).
  final bool isFlat;

  /// Unit vector from [grab] to [touch], perpendicular to the fold line.
  final Offset foldNormal;

  /// The middle of grab-touch: a point on the fold line.
  final Offset foldPoint;

  /// How far the soft shadows reach.
  final double shadowExtent;

  /// The x of the spine line.
  double get spineX => spine == SpineSide.left ? leaf.left : leaf.right;

  /// The leaf's free-edge outward normal.
  Offset get freeEdgeNormal => -towardSpine(spine);

  /// Distance of [p] from the fold line, positive on the touch side.
  double _side(Offset p) => (p - foldPoint).dx * foldNormal.dx + (p - foldPoint).dy * foldNormal.dy;

  /// The part of the leaf that stays flat (spine side of the fold).
  late final List<Offset> flatPolygon =
      isFlat ? rectPolygon(leaf) : clipHalfPlane(rectPolygon(leaf), foldPoint, foldNormal, keepPositive: true);

  /// The part of the leaf that is lifted, at its ORIGINAL place: the area it
  /// uncovers, where the page underneath shows.
  late final List<Offset> revealedPolygon =
      isFlat ? const <Offset>[] : clipHalfPlane(rectPolygon(leaf), foldPoint, foldNormal, keepPositive: false);

  /// The lifted part after it has been folded over: the visible back of the
  /// page, clipped to [backBounds].
  late final List<Offset> backPolygon = () {
    if (revealedPolygon.length < 3) return const <Offset>[];
    var poly = [for (final v in revealedPolygon) reflect(v)];
    poly = clipHalfPlane(poly, backBounds.topLeft, const Offset(1, 0), keepPositive: true);
    poly = clipHalfPlane(poly, backBounds.bottomRight, const Offset(1, 0), keepPositive: false);
    poly = clipHalfPlane(poly, backBounds.topLeft, const Offset(0, 1), keepPositive: true);
    poly = clipHalfPlane(poly, backBounds.bottomRight, const Offset(0, 1), keepPositive: false);
    return poly.length < 3 ? const <Offset>[] : poly;
  }();

  /// The two ends of the fold line inside the leaf (null while flat or when
  /// the fold has left the leaf).
  late final (Offset, Offset)? foldSegment = () {
    if (isFlat) return null;
    final hits = <Offset>[];
    for (final v in revealedPolygon) {
      if (_side(v).abs() < 1e-6) hits.add(v);
    }
    if (hits.length < 2) return null;
    final t = Offset(-foldNormal.dy, foldNormal.dx);
    hits.sort((a, b) => (a.dx * t.dx + a.dy * t.dy).compareTo(b.dx * t.dx + b.dy * t.dy));
    return (hits.first, hits.last);
  }();

  /// True once nothing of the leaf is flat any more.
  bool get isFullyTurned => !isFlat && polygonArea(flatPolygon) < 0.5;

  /// The soft shadow the lifted part throws on the page underneath: a band
  /// of [shadowExtent] along the fold, on the revealed side.
  late final List<Offset> revealedShadowPolygon = () {
    if (revealedPolygon.length < 3) return const <Offset>[];
    final poly = clipHalfPlane(revealedPolygon, foldPoint - foldNormal * shadowExtent, foldNormal, keepPositive: true);
    return poly.length < 3 ? const <Offset>[] : poly;
  }();

  Rect get revealedShadowRect => boundsOf(revealedShadowPolygon);

  /// Direction (unit) the shadow of the folded-over edge falls: away from the
  /// back face, towards the spine. It is the free-edge normal, mirrored.
  Offset get edgeShadowDirection => reflectVector(freeEdgeNormal);

  /// The shadow the folded-over edge throws on the flat page (and, in a
  /// spread, on the facing page) beyond it.
  late final List<Offset> edgeShadowPolygon = () {
    if (isFlat) return const <Offset>[];
    final v = edgeShadowDirection;
    var poly = rectPolygon(backBounds);
    poly = clipHalfPlane(poly, touch, v, keepPositive: true);
    poly = clipHalfPlane(poly, touch + v * shadowExtent, v, keepPositive: false);
    poly = clipHalfPlane(poly, foldPoint, foldNormal, keepPositive: true);
    return poly.length < 3 ? const <Offset>[] : poly;
  }();

  Rect get edgeShadowRect => boundsOf(edgeShadowPolygon);

  /// Mirror image of [p] across the fold line.
  Offset reflect(Offset p) {
    final k = 2 * _side(p);
    return Offset(p.dx - k * foldNormal.dx, p.dy - k * foldNormal.dy);
  }

  /// Mirror image of a direction (no translation).
  Offset reflectVector(Offset v) {
    final k = 2 * (v.dx * foldNormal.dx + v.dy * foldNormal.dy);
    return Offset(v.dx - k * foldNormal.dx, v.dy - k * foldNormal.dy);
  }

  /// Maps the back of the leaf to the screen. With [throughSpine] the content
  /// is first mirrored across the spine: used when the back is the real
  /// facing page of the next spread (it is then upright, not mirrored).
  Matrix4 backTransform({bool throughSpine = false}) {
    final out = Float64List(16);
    writeBackTransform(out, throughSpine: throughSpine);
    return Matrix4.fromFloat64List(out);
  }

  /// Allocation-free version for painters: fills a 16-element column-major
  /// matrix.
  void writeBackTransform(Float64List out, {bool throughSpine = false}) {
    // Fold reflection: x' = a x + c y + tx ; y' = b x + d y + ty.
    final nx = foldNormal.dx, ny = foldNormal.dy;
    final nm = nx * foldPoint.dx + ny * foldPoint.dy;
    var a = 1 - 2 * nx * nx;
    var b = -2 * nx * ny;
    var c = b;
    var d = 1 - 2 * ny * ny;
    var tx = 2 * nm * nx;
    var ty = 2 * nm * ny;
    if (throughSpine) {
      // Then compose with the spine mirror applied first: x -> 2 sx - x.
      final sx = 2 * spineX;
      final a2 = -a;
      final b2 = -b;
      final tx2 = a * sx + tx;
      final ty2 = b * sx + ty;
      a = a2;
      b = b2;
      tx = tx2;
      ty = ty2;
      // c and d are unchanged (y is untouched by the spine mirror).
    }
    out
      ..[0] = a
      ..[1] = b
      ..[2] = 0
      ..[3] = 0
      ..[4] = c
      ..[5] = d
      ..[6] = 0
      ..[7] = 0
      ..[8] = 0
      ..[9] = 0
      ..[10] = 1
      ..[11] = 0
      ..[12] = tx
      ..[13] = ty
      ..[14] = 0
      ..[15] = 1;
  }

  // ---- static helpers --------------------------------------------------

  /// The no-stretch limit: the leaf is hinged at both spine corners, so the
  /// touch point may not be further from either than the grab point is.
  static Offset constrainTouch({
    required Rect leaf,
    required SpineSide spine,
    required Offset grab,
    required Offset touch,
  }) {
    final sx = spine == SpineSide.left ? leaf.left : leaf.right;
    final corners = [Offset(sx, leaf.top), Offset(sx, leaf.bottom)];
    var p = touch;
    for (var pass = 0; pass < 3; pass++) {
      for (final s in corners) {
        final r = (grab - s).distance;
        final v = p - s;
        final dist = v.distance;
        if (dist > r && dist > 0) p = s + v / dist * r;
      }
    }
    return p;
  }

  static List<Offset> rectPolygon(Rect r) => [r.topLeft, r.topRight, r.bottomRight, r.bottomLeft];

  static Rect boundsOf(List<Offset> poly) {
    if (poly.isEmpty) return Rect.zero;
    var l = poly.first.dx, r = l, t = poly.first.dy, b = t;
    for (final p in poly) {
      l = math.min(l, p.dx);
      r = math.max(r, p.dx);
      t = math.min(t, p.dy);
      b = math.max(b, p.dy);
    }
    return Rect.fromLTRB(l, t, r, b);
  }

  static double polygonArea(List<Offset> poly) {
    if (poly.length < 3) return 0;
    var s = 0.0;
    for (var i = 0; i < poly.length; i++) {
      final a = poly[i], b = poly[(i + 1) % poly.length];
      s += a.dx * b.dy - b.dx * a.dy;
    }
    return s.abs() / 2;
  }

  /// Sutherland-Hodgman clip of a convex polygon to one half-plane: keeps
  /// the points with (p - point) . normal >= 0 (or <= 0).
  static List<Offset> clipHalfPlane(
    List<Offset> poly,
    Offset point,
    Offset normal, {
    required bool keepPositive,
  }) {
    if (poly.isEmpty) return const <Offset>[];
    double dist(Offset p) {
      final d = (p.dx - point.dx) * normal.dx + (p.dy - point.dy) * normal.dy;
      return keepPositive ? d : -d;
    }

    final out = <Offset>[];
    for (var i = 0; i < poly.length; i++) {
      final cur = poly[i];
      final nxt = poly[(i + 1) % poly.length];
      final dc = dist(cur), dn = dist(nxt);
      final curIn = dc >= -1e-9, nxtIn = dn >= -1e-9;
      if (curIn) out.add(cur);
      if (curIn != nxtIn) {
        final t = dc / (dc - dn);
        out.add(Offset(cur.dx + (nxt.dx - cur.dx) * t, cur.dy + (nxt.dy - cur.dy) * t));
      }
    }
    return out;
  }
}

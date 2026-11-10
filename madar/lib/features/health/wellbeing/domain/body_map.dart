import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// Which face of the body map a point sits on.
enum BodySide { front, back }

/// A tapped spot on the body map, normalised to the figure's box: [x] 0 →
/// the figure's left edge *as drawn* (the viewer's left), 1 → its right edge;
/// [y] 0 → top of the head, 1 → soles. The box is always 1 wide × 2 high, so
/// the points survive any screen size. Stored in `pain_entries.body_points`
/// as `{"x":0.42,"y":0.31,"side":"front"}`.
///
/// The map is a picture, not text: it is never mirrored in right-to-left
/// layouts (the figure faces the viewer on the front, turns away on the back).
@immutable
class BodyPoint {
  const BodyPoint(this.x, this.y, this.side);

  final double x;
  final double y;
  final BodySide side;

  Map<String, Object?> toJson() => {'x': _round(x), 'y': _round(y), 'side': side.name};

  static double _round(double v) => (v * 1000).round() / 1000;

  /// Tolerant reader: accepts `x/y` numbers or numeric strings and a missing
  /// side (front). Returns null for anything that is not a point.
  static BodyPoint? fromJson(Object? json) {
    if (json is! Map) return null;
    double? n(Object? v) => v is num ? v.toDouble() : (v is String ? double.tryParse(v) : null);
    final x = n(json['x']);
    final y = n(json['y']);
    if (x == null || y == null || !x.isFinite || !y.isFinite) return null;
    final side = json['side'] == 'back' ? BodySide.back : BodySide.front;
    return BodyPoint(x.clamp(0.0, 1.0), y.clamp(0.0, 1.0), side);
  }

  static List<BodyPoint> listFrom(List<Object?> raw) => [for (final r in raw) ?fromJson(r)];

  static List<Object?> encodeAll(Iterable<BodyPoint> points) => [for (final p in points) p.toJson()];

  /// Distance in figure units (the box is 1 × 2, so y counts double).
  double distanceTo(BodyPoint o) {
    final dx = x - o.x;
    final dy = (y - o.y) * BodyFigure.aspect;
    return math.sqrt(dx * dx + dy * dy);
  }

  @override
  bool operator ==(Object other) => other is BodyPoint && other.x == x && other.y == y && other.side == side;

  @override
  int get hashCode => Object.hash(x, y, side);

  @override
  String toString() => 'BodyPoint(${x.toStringAsFixed(3)}, ${y.toStringAsFixed(3)}, ${side.name})';
}

/// Named areas of the figure. Tapping the map suggests the matching location
/// tag when the user has one with that name (the seeded vocabulary).
enum BodyRegion { head, neck, shoulders, chest, abdomen, upperBack, lowerBack, arms, hands, hips, legs, knees, feet }

/// One capsule / ellipse of the silhouette in figure units (x 0–1, y 0–1 of
/// a 1 × 2 box). The painter unions them into one outline.
@immutable
class BodyShape {
  const BodyShape.ellipse(this.cx, this.cy, this.rx, this.ry) : kind = BodyShapeKind.ellipse, x2 = 0, y2 = 0, r2 = 0;

  /// A tapered limb from (cx, cy) with half-width [rx] to (x2, y2) with
  /// half-width [r2] (rounded ends).
  const BodyShape.limb(this.cx, this.cy, this.rx, this.x2, this.y2, this.r2) : kind = BodyShapeKind.limb, ry = 0;

  /// A torso-like quad: top y [cy] with half-width [rx], bottom y [y2] with
  /// half-width [r2], waist at the middle pinched to [ry].
  const BodyShape.trunk(this.cy, this.rx, this.ry, this.y2, this.r2) : kind = BodyShapeKind.trunk, cx = 0.5, x2 = 0.5;

  final BodyShapeKind kind;
  final double cx, cy, rx, ry, x2, y2, r2;
}

enum BodyShapeKind { ellipse, limb, trunk }

/// The gender-neutral figure (original geometry drawn for Madar): soft,
/// even proportions, no anatomical detail beyond a few quiet guide lines.
abstract final class BodyFigure {
  /// Height ÷ width of the figure box.
  static const double aspect = 2.0;

  /// Joints overlap but never coincide exactly (path unions drop
  /// coincident circles).
  static const List<BodyShape> shapes = [
    // Head and neck.
    BodyShape.ellipse(0.5, 0.068, 0.092, 0.056),
    BodyShape.limb(0.5, 0.11, 0.045, 0.5, 0.165, 0.05),
    // Trunk: shoulders → waist → hips.
    BodyShape.trunk(0.172, 0.215, 0.155, 0.5, 0.175),
    // Shoulders rounded into the arms.
    BodyShape.ellipse(0.3, 0.19, 0.075, 0.03),
    BodyShape.ellipse(0.7, 0.19, 0.075, 0.03),
    // Arms (upper, fore) and hands.
    BodyShape.limb(0.275, 0.2, 0.05, 0.215, 0.35, 0.042),
    BodyShape.limb(0.215, 0.352, 0.04, 0.175, 0.49, 0.034),
    BodyShape.ellipse(0.162, 0.525, 0.036, 0.034),
    BodyShape.limb(0.725, 0.2, 0.05, 0.785, 0.35, 0.042),
    BodyShape.limb(0.785, 0.352, 0.04, 0.825, 0.49, 0.034),
    BodyShape.ellipse(0.838, 0.525, 0.036, 0.034),
    // Legs (thigh, shin) and feet.
    BodyShape.limb(0.405, 0.49, 0.085, 0.4, 0.71, 0.06),
    BodyShape.limb(0.4, 0.712, 0.058, 0.395, 0.92, 0.042),
    BodyShape.ellipse(0.39, 0.945, 0.05, 0.022),
    BodyShape.limb(0.595, 0.49, 0.085, 0.6, 0.71, 0.06),
    BodyShape.limb(0.6, 0.712, 0.058, 0.605, 0.92, 0.042),
    BodyShape.ellipse(0.61, 0.945, 0.05, 0.022),
  ];

  /// The named area under a tap, or null outside the figure's bands. Pure
  /// band maths (no path hit test), deliberately forgiving at the edges.
  static BodyRegion? regionAt(double x, double y, BodySide side) {
    if (x < 0 || x > 1 || y < 0 || y > 1) return null;
    final dx = (x - 0.5).abs();
    if (y < 0.125) return dx < 0.14 ? BodyRegion.head : null;
    if (y < 0.168) return dx < 0.12 ? BodyRegion.neck : (dx < 0.3 ? BodyRegion.shoulders : null);
    // Arms and hands hang outside the trunk.
    final trunkHalf = _trunkHalfWidth(y);
    if (y < 0.5 && dx > trunkHalf + 0.01) {
      if (y < 0.235 && dx < 0.3) return BodyRegion.shoulders;
      return dx < 0.42 ? BodyRegion.arms : null;
    }
    if (y >= 0.48 && y < 0.58 && dx > 0.25) return dx < 0.42 ? BodyRegion.hands : null;
    if (y < 0.235) {
      if (dx > 0.13) return BodyRegion.shoulders;
      return side == BodySide.front ? BodyRegion.chest : BodyRegion.upperBack;
    }
    if (side == BodySide.front) {
      if (y < 0.33) return BodyRegion.chest;
      if (y < 0.455) return BodyRegion.abdomen;
    } else {
      if (y < 0.34) return BodyRegion.upperBack;
      if (y < 0.47) return BodyRegion.lowerBack;
    }
    if (y < 0.56) return BodyRegion.hips;
    if (dx > 0.22) return null;
    if (y < 0.66) return BodyRegion.legs;
    if (y < 0.765) return BodyRegion.knees;
    if (y < 0.915) return BodyRegion.legs;
    return BodyRegion.feet;
  }

  static double _trunkHalfWidth(double y) {
    const top = 0.172, bottom = 0.5;
    if (y <= top) return 0.215;
    if (y >= bottom) return 0.175;
    final t = (y - top) / (bottom - top);
    // Shoulders 0.215 → waist 0.155 → hips 0.175 (quadratic through the waist).
    final a = 0.215, b = 0.155, c = 0.175;
    return (1 - t) * (1 - t) * a + 2 * (1 - t) * t * (2 * b - (a + c) / 2) + t * t * c;
  }
}

/// A hot spot of the location heat map: nearby points of the same side merged.
@immutable
class HeatSpot {
  const HeatSpot({required this.x, required this.y, required this.side, required this.count, required this.meanScore});

  final double x;
  final double y;
  final BodySide side;

  /// How many logged points fell here.
  final int count;

  /// Mean pain score of those points' entries (0–10).
  final double meanScore;
}

/// Merges body points into [HeatSpot]s (greedy clustering within [radius]
/// figure units). Pure, deterministic.
abstract final class BodyHeat {
  static const double defaultRadius = 0.07;

  static List<HeatSpot> cluster(Iterable<(BodyPoint point, int score)> points, {double radius = defaultRadius}) {
    final clusters = <_Cluster>[];
    for (final (p, score) in points) {
      _Cluster? best;
      var bestD = double.infinity;
      for (final c in clusters) {
        if (c.side != p.side) continue;
        final d = BodyPoint(c.x, c.y, c.side).distanceTo(p);
        if (d <= radius && d < bestD) {
          best = c;
          bestD = d;
        }
      }
      if (best == null) {
        clusters.add(_Cluster(p.side)..add(p, score));
      } else {
        best.add(p, score);
      }
    }
    final spots = [
      for (final c in clusters) HeatSpot(x: c.x, y: c.y, side: c.side, count: c.count, meanScore: c.scoreSum / c.count),
    ];
    spots.sort((a, b) => b.count.compareTo(a.count));
    return spots;
  }
}

class _Cluster {
  _Cluster(this.side);

  final BodySide side;
  double sx = 0, sy = 0;
  int count = 0;
  double scoreSum = 0;

  double get x => sx / count;
  double get y => sy / count;

  void add(BodyPoint p, int score) {
    sx += p.x;
    sy += p.y;
    count++;
    scoreSum += score;
  }
}

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

/// Pure star geometry shared by every Madar ornament (unit-tested).
abstract final class IslamicGeometry {
  /// Inner/outer radius ratio of the outline of the star polygon {n/k}
  /// (e.g. {8/3} ≈ 0.541, the Rub el Hizb {8/2} ≈ 0.765).
  static double starPolygonInnerRatio(int n, int k) {
    assert(n >= 3 && k >= 1 && k < n / 2, 'invalid star polygon {$n/$k}');
    return math.cos(math.pi * k / n) / math.cos(math.pi * (k - 1) / n);
  }

  /// A pleasing default density for an [points]-point star: {n/k} with
  /// k = n/2 − 1 (at least 2), which gives the sharp classical stars.
  static double defaultInnerRatio(int points) {
    if (points < 5) return 0.5;
    final k = math.max(2, points ~/ 2 - 1);
    return starPolygonInnerRatio(points, math.min(k, (points - 1) ~/ 2));
  }

  /// Vertices of a star alternating outer ([radius]) and inner
  /// ([radius] × [innerRatio]) points; the first tip points up, turned by
  /// [rotation] radians (clockwise).
  static List<Offset> starVertices({
    required Offset center,
    required double radius,
    int points = 8,
    double innerRatio = 0.5,
    double rotation = 0,
  }) {
    assert(points >= 3);
    return List<Offset>.generate(points * 2, (i) {
      final r = i.isEven ? radius : radius * innerRatio;
      final a = rotation - math.pi / 2 + i * math.pi / points;
      return center + Offset(math.cos(a) * r, math.sin(a) * r);
    }, growable: false);
  }

  static Path polygon(List<Offset> vertices) => Path()..addPolygon(vertices, true);

  /// Closed outline of an n-point star.
  static Path starPath({
    required Offset center,
    required double radius,
    int points = 8,
    double? innerRatio,
    double rotation = 0,
  }) => polygon(
    starVertices(
      center: center,
      radius: radius,
      points: points,
      innerRatio: innerRatio ?? defaultInnerRatio(points),
      rotation: rotation,
    ),
  );

  /// The two squares of the Rub el Hizb (۞), the second turned 45°.
  static List<List<Offset>> rubElHizbSquares({required Offset center, required double radius, double rotation = 0}) {
    List<Offset> square(double turn) => List<Offset>.generate(4, (i) {
      final a = rotation + turn - math.pi / 2 + i * math.pi / 2;
      return center + Offset(math.cos(a) * radius, math.sin(a) * radius);
    }, growable: false);
    return [square(0), square(math.pi / 4)];
  }

  /// Union outline of the Rub el Hizb (an {8/2} octagram).
  static Path rubElHizbOutline({required Offset center, required double radius, double rotation = 0}) =>
      starPath(center: center, radius: radius, points: 8, innerRatio: starPolygonInnerRatio(8, 2), rotation: rotation);
}

enum IslamicStarStyle {
  /// A single n-point star outline.
  star,

  /// Rub el Hizb: two interlaced squares with a central circle.
  rubElHizb,
}

/// Vector n-point Islamic star / Rub el Hizb. Crisp at any DPR.
class IslamicStarPainter extends CustomPainter {
  const IslamicStarPainter({
    this.points = 8,
    this.innerRatio,
    this.style = IslamicStarStyle.star,
    this.fillColor,
    this.fillGradient,
    this.strokeColor,
    this.strokeWidth = 1.2,
    this.rotation = 0,
    this.glowColor,
    this.glowSigma = 6,
    this.centerDotColor,
  });

  final int points;

  /// Inner radius ratio; defaults to [IslamicGeometry.defaultInnerRatio].
  final double? innerRatio;
  final IslamicStarStyle style;
  final Color? fillColor;

  /// Optional two-stop gradient fill (top-start → bottom-end); wins over
  /// [fillColor].
  final List<Color>? fillGradient;
  final Color? strokeColor;
  final double strokeWidth;

  /// Clockwise rotation in radians.
  final double rotation;
  final Color? glowColor;
  final double glowSigma;

  /// Optional dot in the middle (a jewel in the star).
  final Color? centerDotColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final center = size.center(Offset.zero);
    final margin = strokeWidth / 2 + (glowColor != null ? glowSigma * 0.5 : 0);
    final radius = math.max(0.0, size.shortestSide / 2 - margin);
    final outline = switch (style) {
      IslamicStarStyle.star => IslamicGeometry.starPath(
        center: center,
        radius: radius,
        points: points,
        innerRatio: innerRatio,
        rotation: rotation,
      ),
      IslamicStarStyle.rubElHizb => IslamicGeometry.rubElHizbOutline(
        center: center,
        radius: radius,
        rotation: rotation,
      ),
    };

    final glow = glowColor;
    if (glow != null) {
      canvas.drawPath(
        outline,
        Paint()
          ..color = glow
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, glowSigma),
      );
    }

    final gradient = fillGradient;
    if (gradient != null && gradient.length >= 2) {
      final bounds = Rect.fromCircle(center: center, radius: radius);
      canvas.drawPath(outline, Paint()..shader = ui.Gradient.linear(bounds.topLeft, bounds.bottomRight, gradient));
    } else if (fillColor != null) {
      canvas.drawPath(outline, Paint()..color = fillColor!);
    }

    final stroke = strokeColor;
    if (stroke != null && strokeWidth > 0) {
      final paint = Paint()
        ..color = stroke
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeJoin = StrokeJoin.miter
        ..strokeMiterLimit = 8
        ..isAntiAlias = true;
      if (style == IslamicStarStyle.rubElHizb) {
        for (final square in IslamicGeometry.rubElHizbSquares(center: center, radius: radius, rotation: rotation)) {
          canvas.drawPath(IslamicGeometry.polygon(square), paint);
        }
        canvas.drawCircle(center, radius * 0.3, paint);
      } else {
        canvas.drawPath(outline, paint);
      }
    }

    final dot = centerDotColor;
    if (dot != null) {
      canvas.drawCircle(center, math.max(1.0, radius * 0.14), Paint()..color = dot);
    }
  }

  @override
  bool shouldRepaint(IslamicStarPainter old) =>
      old.points != points ||
      old.innerRatio != innerRatio ||
      old.style != style ||
      old.fillColor != fillColor ||
      old.fillGradient != fillGradient ||
      old.strokeColor != strokeColor ||
      old.strokeWidth != strokeWidth ||
      old.rotation != rotation ||
      old.glowColor != glowColor ||
      old.glowSigma != glowSigma ||
      old.centerDotColor != centerDotColor;
}

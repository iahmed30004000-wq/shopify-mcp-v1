import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../painters/islamic_star_painter.dart' show IslamicGeometry;
import 'pattern_picture_cache.dart';
import 'vec2.dart';

/// Which way the ring fills.
enum StarRingDirection {
  /// Follows the reading direction: clockwise in LTR, anticlockwise in RTL
  /// (the ring mirrors with the rest of the screen, like a progress bar).
  auto,
  clockwise,
  anticlockwise,
}

/// Pure outline of an n-point star at unit radius, starting at the top tip,
/// with the cumulative perimeter so a fraction maps to a point.
class StarRingGeometry {
  StarRingGeometry._(this.points, this.innerRatio, this.clockwise, this.xs, this.ys, this.cum);

  factory StarRingGeometry(int points, {double? innerRatio, bool clockwise = true}) {
    final n = points < 3 ? 3 : points;
    final ratio = (innerRatio ?? IslamicGeometry.defaultInnerRatio(n)).clamp(0.2, 0.98).toDouble();
    final m = n * 2;
    final xs = Float64List(m), ys = Float64List(m);
    for (var i = 0; i < m; i++) {
      final a = -math.pi / 2 + i * math.pi / n;
      final r = i.isEven ? 1.0 : ratio;
      xs[i] = math.cos(a) * r * (clockwise ? 1 : -1);
      ys[i] = math.sin(a) * r;
    }
    final cum = Float64List(m + 1);
    for (var k = 1; k <= m; k++) {
      final a = k - 1, b = k % m;
      cum[k] = cum[k - 1] + math.sqrt(math.pow(xs[b] - xs[a], 2) + math.pow(ys[b] - ys[a], 2));
    }
    final total = cum[m];
    for (var k = 0; k <= m; k++) {
      cum[k] /= total;
    }
    return StarRingGeometry._(n, ratio, clockwise, xs, ys, cum);
  }

  final int points;
  final double innerRatio;
  final bool clockwise;

  /// Vertices (2·points) at unit radius; vertex 0 is the top tip.
  final Float64List xs, ys;

  /// Perimeter fraction at each vertex; length 2·points + 1, last is 1.
  final Float64List cum;

  int get vertexCount => points * 2;

  /// Point at perimeter fraction [t] (clamped 0..1), starting at the top tip.
  Vec2 pointAt(double t) {
    final f = t.isNaN ? 0.0 : t.clamp(0.0, 1.0);
    final m = vertexCount;
    var k = 1;
    while (k < m && cum[k] < f) {
      k++;
    }
    final a = k - 1, b = k % m;
    final span = cum[k] - cum[a];
    final u = span <= 0 ? 0.0 : (f - cum[a]) / span;
    return Vec2(xs[a] + (xs[b] - xs[a]) * u, ys[a] + (ys[b] - ys[a]) * u);
  }
}

/// Paints a star-shaped progress ring. Allocation-free after the first
/// paint at a size: the track is a cached picture and the filled arc reuses
/// one scratch [ui.Path] and [Paint].
class StarProgressRingPainter extends CustomPainter {
  StarProgressRingPainter({
    required this.value,
    required this.trackColor,
    required this.progressColor,
    this.points = 8,
    this.strokeWidth = 4,
    this.clockwise = true,
    this.innerRatio,
    this.glowColor,
  }) : _geometry = _geometryFor(points, innerRatio, clockwise),
       _trackConfig = ('ringTrack', points, innerRatio, clockwise, trackColor, strokeWidth);

  /// 0..1; NaN counts as 0.
  final double value;
  final Color trackColor, progressColor;
  final int points;
  final double strokeWidth;
  final bool clockwise;
  final double? innerRatio;
  final Color? glowColor;
  final StarRingGeometry _geometry;
  final Object _trackConfig;

  static final Map<(int, double?, bool), StarRingGeometry> _geometries = {};
  static StarRingGeometry _geometryFor(int points, double? ratio, bool clockwise) =>
      _geometries.putIfAbsent((points, ratio, clockwise), () => StarRingGeometry(points, innerRatio: ratio, clockwise: clockwise));

  static final ui.Path _scratch = ui.Path();
  static final Paint _arc = Paint()
    ..style = PaintingStyle.stroke
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = StrokeCap.round
    ..isAntiAlias = true;
  static final Paint _halo = Paint()..style = PaintingStyle.stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = size.shortestSide / 2 - strokeWidth / 2 - (glowColor != null ? 3 : 0);
    if (radius <= 0) return;
    final centre = size.center(Offset.zero);

    canvas.drawPicture(
      PatternPictureCache.find(_trackConfig, size) ??
          PatternPictureCache.record(_trackConfig, size, (c) {
            final g = _geometry;
            final p = ui.Path()..moveTo(centre.dx + g.xs[0] * radius, centre.dy + g.ys[0] * radius);
            for (var i = 1; i < g.vertexCount; i++) {
              p.lineTo(centre.dx + g.xs[i] * radius, centre.dy + g.ys[i] * radius);
            }
            p.close();
            c.drawPath(
              p,
              Paint()
                ..color = trackColor
                ..style = PaintingStyle.stroke
                ..strokeWidth = strokeWidth
                ..strokeJoin = StrokeJoin.round
                ..isAntiAlias = true,
            );
          }),
    );

    final v = value.isNaN ? 0.0 : value.clamp(0.0, 1.0);
    if (v <= 0) return;
    final g = _geometry;
    _scratch.reset();
    _scratch.moveTo(centre.dx + g.xs[0] * radius, centre.dy + g.ys[0] * radius);
    final m = g.vertexCount;
    for (var k = 1; k <= m; k++) {
      final b = k % m;
      if (g.cum[k] <= v) {
        _scratch.lineTo(centre.dx + g.xs[b] * radius, centre.dy + g.ys[b] * radius);
      } else {
        final a = k - 1;
        final u = (v - g.cum[a]) / (g.cum[k] - g.cum[a]);
        _scratch.lineTo(
          centre.dx + (g.xs[a] + (g.xs[b] - g.xs[a]) * u) * radius,
          centre.dy + (g.ys[a] + (g.ys[b] - g.ys[a]) * u) * radius,
        );
        break;
      }
    }
    if (v >= 1) _scratch.close();

    final glow = glowColor;
    if (glow != null) {
      _halo
        ..color = glow
        ..strokeWidth = strokeWidth * 1.8
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
      canvas.drawPath(_scratch, _halo);
    }
    _arc
      ..color = progressColor
      ..strokeWidth = strokeWidth;
    canvas.drawPath(_scratch, _arc);
  }

  @override
  bool shouldRepaint(StarProgressRingPainter old) =>
      old.value != value ||
      old.trackColor != trackColor ||
      old.progressColor != progressColor ||
      old.points != points ||
      old.strokeWidth != strokeWidth ||
      old.clockwise != clockwise ||
      old.innerRatio != innerRatio ||
      old.glowColor != glowColor;
}

/// A progress ring shaped as an 8- or 12-point star outline (any n >= 5 works).
/// Fills from the top tip; [direction] defaults to the reading direction.
/// Under reduced motion the value changes without animating.
class StarProgressRing extends StatelessWidget {
  const StarProgressRing({
    super.key,
    required this.value,
    required this.progressColor,
    required this.trackColor,
    this.points = 8,
    this.size = 96,
    this.strokeWidth = 4,
    this.innerRatio,
    this.direction = StarRingDirection.auto,
    this.glowColor,
    this.child,
    this.semanticLabel,
    this.semanticValue,
    this.animationDuration = const Duration(milliseconds: 420),
  });

  final double value;
  final Color progressColor, trackColor;
  final int points;
  final double size;
  final double strokeWidth;
  final double? innerRatio;
  final StarRingDirection direction;
  final Color? glowColor;

  /// Centred inside the ring (a number, an icon).
  final Widget? child;

  /// Already-localised text for screen readers (the caller owns the strings).
  final String? semanticLabel;
  final String? semanticValue;
  final Duration animationDuration;

  /// The fill direction for [direction] under [textDirection].
  static bool resolveClockwise(StarRingDirection direction, TextDirection textDirection) => switch (direction) {
    StarRingDirection.clockwise => true,
    StarRingDirection.anticlockwise => false,
    StarRingDirection.auto => textDirection == TextDirection.ltr,
  };

  @override
  Widget build(BuildContext context) {
    final clockwise = resolveClockwise(direction, Directionality.of(context));
    final reduced = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final target = value.isNaN ? 0.0 : value.clamp(0.0, 1.0);
    return Semantics(
      label: semanticLabel,
      value: semanticValue,
      container: semanticLabel != null || semanticValue != null,
      child: SizedBox.square(
        dimension: size,
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(end: target),
          duration: reduced ? Duration.zero : animationDuration,
          curve: Curves.easeOutCubic,
          builder: (context, v, child) => CustomPaint(
            painter: StarProgressRingPainter(
              value: v,
              trackColor: trackColor,
              progressColor: progressColor,
              points: points,
              strokeWidth: strokeWidth,
              clockwise: clockwise,
              innerRatio: innerRatio,
              glowColor: glowColor,
            ),
            child: child,
          ),
          child: child == null ? null : Center(child: child),
        ),
      ),
    );
  }
}

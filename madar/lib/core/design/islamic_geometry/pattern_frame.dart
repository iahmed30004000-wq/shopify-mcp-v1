import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'pattern_geometry.dart';
import 'pattern_picture_cache.dart';
import 'pattern_spec.dart';

/// A border made of the pattern: [child] sits inside a band of [thickness]
/// holding a clipped slice of the tiling, with a hairline on both edges.
class PatternFrame extends StatelessWidget {
  const PatternFrame({
    super.key,
    required this.spec,
    required this.color,
    required this.child,
    this.thickness = 14,
    this.radius = 18,
    this.opacity = 1,
    this.edgeColor,
  });

  final PatternSpec spec;
  final Color color;
  final Widget child;

  /// Band width; the child is padded by exactly this much on every side.
  final double thickness;
  final double radius;
  final double opacity;

  /// Colour of the two edge hairlines (defaults to [color]).
  final Color? edgeColor;

  @override
  Widget build(BuildContext context) => CustomPaint(
    foregroundPainter: PatternFramePainter(
      spec: spec,
      color: color,
      thickness: thickness,
      radius: radius,
      opacity: opacity,
      edgeColor: edgeColor,
    ),
    child: Padding(padding: EdgeInsets.all(thickness), child: child),
  );
}

class PatternFramePainter extends CustomPainter {
  PatternFramePainter({
    required this.spec,
    required this.color,
    required this.thickness,
    this.radius = 18,
    this.opacity = 1,
    this.edgeColor,
  }) : _config = ('frame', spec, color, thickness, radius, opacity, edgeColor);

  final PatternSpec spec;
  final Color color;
  final double thickness;
  final double radius;
  final double opacity;
  final Color? edgeColor;
  final Object _config;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || thickness <= 0) return;
    canvas.drawPicture(
      PatternPictureCache.find(_config, size) ?? PatternPictureCache.record(_config, size, (c) => _draw(c, size)),
    );
  }

  void _draw(Canvas canvas, Size size) {
    final g = PatternGeometry.cached(spec);
    final a = opacity.clamp(0.0, 1.0);
    final t = math.min(thickness, math.min(size.width, size.height) / 2);
    final outer = RRect.fromRectXY(Offset.zero & size, radius, radius);
    final innerRadius = math.max(0.0, radius - t);
    final inner = RRect.fromRectXY(Rect.fromLTWH(t, t, size.width - 2 * t, size.height - 2 * t), innerRadius, innerRadius);
    final ring = Path()
      ..fillType = PathFillType.evenOdd
      ..addRRect(outer)
      ..addRRect(inner);

    // About 1.6 motifs across the band; cells wholly inside the hole are skipped.
    final path = buildTiledPath(g, area: Offset.zero & size, cell: t * 1.6, origin: Offset(t, t), hole: inner.outerRect);

    canvas.save();
    canvas.clipPath(ring);
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: color.a * a)
        ..style = PaintingStyle.stroke
        ..strokeWidth = spec.resolvedLineWidth
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round
        ..isAntiAlias = true,
    );
    canvas.restore();

    final edge = Paint()
      ..color = (edgeColor ?? color).withValues(alpha: (edgeColor ?? color).a * a)
      ..style = PaintingStyle.stroke
      ..strokeWidth = spec.resolvedLineWidth
      ..isAntiAlias = true;
    canvas.drawRRect(outer.deflate(spec.resolvedLineWidth / 2), edge);
    canvas.drawRRect(inner, edge);
  }

  @override
  bool shouldRepaint(PatternFramePainter old) => old._config != _config;
}

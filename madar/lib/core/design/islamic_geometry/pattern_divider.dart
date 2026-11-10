import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'medallion_path.dart';
import 'pattern_geometry.dart';
import 'pattern_picture_cache.dart';
import 'pattern_spec.dart';

/// A horizontal rule made of a repeating medallion of [spec]'s family, with
/// a hairline between motifs. Symmetric, so it needs no RTL handling.
class PatternDivider extends StatelessWidget {
  const PatternDivider({super.key, required this.spec, required this.color, this.height = 20, this.opacity = 1});

  final PatternSpec spec;
  final Color color;

  /// Height in logical pixels; also the motif diameter.
  final double height;
  final double opacity;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(painter: PatternDividerPainter(spec: spec, color: color, opacity: opacity)),
    ),
  );
}

class PatternDividerPainter extends CustomPainter {
  PatternDividerPainter({required this.spec, required this.color, this.opacity = 1})
    : _config = ('divider', spec, color, opacity);

  final PatternSpec spec;
  final Color color;
  final double opacity;
  final Object _config;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    canvas.drawPicture(
      PatternPictureCache.find(_config, size) ?? PatternPictureCache.record(_config, size, (c) => _draw(c, size)),
    );
  }

  void _draw(Canvas canvas, Size size) {
    final g = PatternGeometry.cached(spec);
    final a = opacity.clamp(0.0, 1.0);
    final radius = math.max(1.0, size.height / 2 - spec.resolvedLineWidth);
    final spacing = size.height * 1.6;
    final n = math.max(1, ((size.width - 2 * radius) / spacing).floor() + 1);
    final span = (n - 1) * spacing;
    final x0 = (size.width - span) / 2;
    final cy = size.height / 2;

    final line = Paint()
      ..color = color.withValues(alpha: color.a * a)
      ..style = PaintingStyle.stroke
      ..strokeWidth = spec.resolvedLineWidth
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;
    final soft = Paint()
      ..color = color.withValues(alpha: color.a * a * 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = spec.resolvedLineWidth * 0.7
      ..strokeCap = StrokeCap.round;

    // Hairlines between motifs and out to both ends.
    final gap = radius * 1.15;
    canvas.drawLine(Offset(0, cy), Offset(math.max(0, x0 - gap), cy), soft);
    canvas.drawLine(Offset(math.min(size.width, x0 + span + gap), cy), Offset(size.width, cy), soft);
    for (var i = 0; i < n; i++) {
      final cx = x0 + i * spacing;
      if (i < n - 1) canvas.drawLine(Offset(cx + gap, cy), Offset(cx + spacing - gap, cy), soft);
      canvas.drawPath(medallionBoundaryPath(g, Offset(cx, cy), radius), soft);
      canvas.drawPath(medallionLinesPath(g, Offset(cx, cy), radius), line);
    }
  }

  @override
  bool shouldRepaint(PatternDividerPainter old) => old._config != _config;
}

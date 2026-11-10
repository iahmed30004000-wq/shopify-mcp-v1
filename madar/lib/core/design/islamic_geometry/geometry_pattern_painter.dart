import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

import 'pattern_geometry.dart';
import 'pattern_picture_cache.dart';
import 'pattern_spec.dart';

/// Tiled fill of a procedural pattern: backgrounds, textures, lattices.
///
/// The first paint at a size builds the geometry (cached per spec) and
/// records one [ui.Picture]; every later paint is a single `drawPicture`
/// with no allocation. Colours are parameters, never read from a theme.
class GeometryPatternPainter extends CustomPainter {
  GeometryPatternPainter({
    required this.spec,
    required this.color,
    this.opacity = 1,
    this.alignment = Alignment.center,
    this.fillColor,
    this.glowColor,
    this.glowSigma = 3,
    super.repaint,
  }) : _config = ('tile', spec, color, opacity, alignment, fillColor, glowColor, glowSigma);

  final PatternSpec spec;
  final Color color;

  /// 0..1, multiplied into [color]'s alpha.
  final double opacity;

  /// Where lattice point (0, 0) sits in the painted box (centre by default).
  final Alignment alignment;

  /// Optional soft fill of each pattern outline (inlay look).
  final Color? fillColor;

  /// Optional blurred halo behind the lines (costly to raster: keep it for
  /// small areas or behind a `RepaintBoundary`).
  final Color? glowColor;
  final double glowSigma;

  final Object _config;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final picture = PatternPictureCache.find(_config, size) ?? PatternPictureCache.record(_config, size, (c) => _draw(c, size));
    canvas.drawPicture(picture);
  }

  void _draw(Canvas canvas, Size size) {
    final g = PatternGeometry.cached(spec);
    final cell = effectiveCellPx(g, size.width, size.height, spec.resolvedRepeat);
    final origin = alignment.alongSize(size);
    final pad = spec.resolvedLineWidth + (glowColor != null ? glowSigma * 3 : 0);
    final path = buildTiledPath(g, area: (Offset.zero & size).inflate(pad), cell: cell, origin: origin);
    final a = opacity.clamp(0.0, 1.0);

    final fill = fillColor;
    if (fill != null) {
      canvas.drawPath(path, Paint()..color = fill.withValues(alpha: fill.a * a));
    }
    final glow = glowColor;
    if (glow != null) {
      canvas.drawPath(
        path,
        Paint()
          ..color = glow.withValues(alpha: glow.a * a)
          ..style = PaintingStyle.stroke
          ..strokeWidth = spec.resolvedLineWidth * 2
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, glowSigma),
      );
    }
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
  }

  @override
  bool shouldRepaint(GeometryPatternPainter old) => old._config != _config;
}

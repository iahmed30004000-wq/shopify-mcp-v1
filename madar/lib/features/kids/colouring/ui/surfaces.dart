// The two things a child can paint on: a built-in geometric page (vector
// regions) and a picture (raster, flood fill). Each reports taps in its own
// terms; the board around them is shared.
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../learn/ui/kids_tokens.dart';
import '../domain/vector_pages.dart';

/// Paints [page] with [colours] (region -> ARGB) and its outlines. Paths are
/// built once per page, never per frame.
class VectorPagePainter extends CustomPainter {
  VectorPagePainter(this.page, this.colours, {this.lineWidth = 3}) : _paths = _pathsFor(page);

  final VectorPage page;
  final Map<int, int> colours;
  final double lineWidth;
  final List<Path> _paths;

  static final Expando<List<Path>> _cache = Expando();

  static List<Path> _pathsFor(VectorPage page) => _cache[page] ??= [
    for (final r in page.regions) Path()..addPolygon([for (final p in r.points) Offset(p.x, p.y)], true),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width, size.height);
    final fill = Paint()..isAntiAlias = true;
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = lineWidth / size.shortestSide
      ..color = KidsColors.night800
      ..isAntiAlias = true;
    for (var i = 0; i < _paths.length; i++) {
      fill.color = Color(colours[i] ?? 0xFFFFFFFF);
      canvas.drawPath(_paths[i], fill);
    }
    for (final p in _paths) {
      canvas.drawPath(p, line);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(VectorPagePainter old) => old.page != page || old.colours != colours || old.lineWidth != lineWidth;
}

/// Paints a ready picture (the colour layer x the grey art) into the box.
class PicturePainter extends CustomPainter {
  const PicturePainter(this.image);

  final ui.Image image;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Offset.zero & size,
      Paint()..filterQuality = FilterQuality.medium,
    );
  }

  @override
  bool shouldRepaint(PicturePainter old) => old.image != image;
}

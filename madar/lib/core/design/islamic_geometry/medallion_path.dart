import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import 'pattern_geometry.dart';

/// The medallion's lines (closed outlines) as one path, scaled so the
/// medallion fits a circle of [radius] around [centre].
ui.Path medallionLinesPath(PatternGeometry g, Offset centre, double radius) {
  final k = g.medallionRadius <= 0 ? 0.0 : radius / g.medallionRadius;
  final path = ui.Path();
  for (final line in g.medallionLines) {
    final pts = line.points;
    path.moveTo(centre.dx + pts.first.x * k, centre.dy + pts.first.y * k);
    for (var i = 1; i < pts.length; i++) {
      path.lineTo(centre.dx + pts[i].x * k, centre.dy + pts[i].y * k);
    }
    path.close();
  }
  return path;
}

/// The medallion's region boundary, scaled like [medallionLinesPath].
ui.Path medallionBoundaryPath(PatternGeometry g, Offset centre, double radius) {
  final k = g.medallionRadius <= 0 ? 0.0 : radius / g.medallionRadius;
  final b = g.medallionBoundary;
  final path = ui.Path()..moveTo(centre.dx + b.first.x * k, centre.dy + b.first.y * k);
  for (var i = 1; i < b.length; i++) {
    path.lineTo(centre.dx + b[i].x * k, centre.dy + b[i].y * k);
  }
  return path..close();
}

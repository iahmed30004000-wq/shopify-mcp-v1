import 'dart:math' as math;
import 'dart:ui';

import '../ink/ink_build.dart';

/// Hand shapes of the white cartoon glove.
enum HandShape { open, fist, point, thumbsUp, wave, grip, peace }

/// Puffy four-fingered gloves with a rolled cuff and three stitches, and
/// big bulb-toed shoes with a shine – the two props that make a
/// rubber-hose character read at a glance. Drawn in the pen's space.
abstract final class Extremities {
  /// Which way the thumb must point so it faces the character's front (+x
  /// in design space) for a forearm at [angle].
  static double thumbFront(double angle) {
    final s = math.sin(angle);
    return s.abs() < 0.2 ? -1 : -s.sign;
  }

  /// A glove at the wrist ([x], [y]) pointing along [angle]; [size] ≈ the
  /// palm radius. [thumb] = ±1 side of the thumb.
  static void glove(
    InkBuild b, {
    required double x,
    required double y,
    required double angle,
    required double size,
    required Color fill,
    HandShape shape = HandShape.open,
    double thumb = -1,
    int salt = 0,
    bool cuff = true,
  }) {
    final pen = b.pen
      ..save()
      ..translate(x + b.ja(salt, 0.3), y + b.ja(salt + 1, 0.3))
      ..rotate(angle + b.j(salt + 2) * 0.03)
      ..scale(size);
    final t = thumb;
    b.layer();
    if (cuff) {
      b.shape(fill);
      pen
        ..moveTo(-0.08, -0.42)
        ..lineTo(0.3, -0.64)
        ..quadTo(0.44, 0, 0.3, 0.64)
        ..lineTo(-0.08, 0.42)
        ..quadTo(0.0, 0, -0.08, -0.42)
        ..close();
    }
    switch (shape) {
      case HandShape.open || HandShape.wave:
        final spread = shape == HandShape.wave ? 0.5 : 0.32;
        final len = shape == HandShape.wave ? 0.85 : 0.72;
        b.shape(fill);
        pen.ellipse(0.9, 0, 0.6, 0.6);
        for (var i = -1; i <= 1; i++) {
          final a = i * spread + b.j(salt + 5 + i) * 0.05;
          final bx = 1.1, by = i * 0.3;
          b.shape(fill);
          pen.capsule(bx, by, bx + math.cos(a) * len, by + math.sin(a) * len, 0.2, 0.23);
        }
        b.shape(fill);
        pen.capsule(0.72, t * 0.42, 1.0, t * 0.98, 0.19, 0.21);
      case HandShape.fist || HandShape.grip:
        b.shape(fill);
        pen.ellipse(0.95, 0, 0.66, 0.64);
        b.shape(fill);
        pen.capsule(0.7, t * 0.46, 1.12, t * 0.36, 0.2, 0.22);
      case HandShape.point:
        b.shape(fill);
        pen.ellipse(0.92, 0, 0.62, 0.6);
        b.shape(fill);
        pen.capsule(1.25, -t * 0.18, 2.05, -t * 0.26, 0.17, 0.19);
        b.shape(fill);
        pen.capsule(0.7, t * 0.44, 1.08, t * 0.4, 0.19, 0.21);
      case HandShape.thumbsUp:
        b.shape(fill);
        pen.ellipse(0.95, 0, 0.64, 0.62);
        b.shape(fill);
        pen.capsule(0.85, t * 0.45, 0.8, t * 1.25, 0.2, 0.22);
      case HandShape.peace:
        b.shape(fill);
        pen.ellipse(0.92, 0, 0.62, 0.6);
        b.shape(fill);
        pen.capsule(1.2, -t * 0.2, 1.95, -t * 0.55, 0.16, 0.18);
        b.shape(fill);
        pen.capsule(1.25, -t * 0.02, 2.05, -t * 0.02, 0.16, 0.18);
    }
    // Details: stitches on the back, knuckle creases, the cuff's roll.
    final w = b.lw / size;
    if (cuff) {
      b.brushQuad(3, 0.2, -0.5, 0.3, 0, 0.2, 0.5, w * 0.8 * size, taperIn: 0.3, taperOut: 0.3);
    }
    switch (shape) {
      case HandShape.fist || HandShape.grip || HandShape.thumbsUp:
        for (var i = -1; i <= 1; i++) {
          final yy = i * 0.26 - t * 0.08;
          b.brushQuad(3, 1.38, yy - 0.1, 1.46, yy, 1.38, yy + 0.1, w * 0.7 * size, taperIn: 0.4, taperOut: 0.4);
        }
      case HandShape.open || HandShape.wave || HandShape.point || HandShape.peace:
        for (var i = -1; i <= 1; i++) {
          final yy = i * 0.2 - t * 0.12;
          b.brushQuad(3, 0.62, yy, 0.8, yy * 1.05 - 0.02, 0.98, yy * 1.1, w * 0.65 * size, taperIn: 0.5, taperOut: 0.5);
        }
    }
    b.endLayer();
    pen.restore();
  }

  /// A cartoon shoe whose ankle sits at ([x], [y]); [dir] = ±1 which way the
  /// toe points, [pitch] = toe up (negative) / down (positive) in radians,
  /// [size] ≈ half the shoe length.
  static void shoe(
    InkBuild b, {
    required double x,
    required double y,
    required double size,
    required Color fill,
    double dir = 1,
    double pitch = 0,
    int salt = 0,
    Color? spat,
  }) {
    final pen = b.pen
      ..save()
      ..translate(x + b.ja(salt, 0.3), y)
      ..scale(dir * size, size)
      ..rotate(pitch * dir);
    b.layer();
    // Heel + big bulb toe on a flat sole: one inked silhouette.
    b.shape(fill);
    pen
      ..moveTo(-0.62, 0.5)
      ..lineTo(1.12, 0.5)
      ..cubicTo(1.52 + b.j(salt + 1) * 0.03, 0.5, 1.56, -0.12, 1.08, -0.4)
      ..cubicTo(0.78, -0.58, 0.42, -0.5, 0.26, -0.32)
      ..lineTo(0.2, -0.36)
      ..cubicTo(-0.1, -0.5, -0.66, -0.44, -0.7, 0.06)
      ..quadTo(-0.72, 0.42, -0.62, 0.5)
      ..close();
    if (spat != null) {
      b.shape(spat);
      pen.roundRect(-0.52, -0.46, 0.46, 0.24, 0.18);
    }
    // Sole edge, toe cap seam and the shine.
    b.inkLine(b.lw * 0.55);
    pen
      ..moveTo(-0.6, 0.36)
      ..lineTo(1.2, 0.36);
    b.brushQuad(3, 0.55, -0.34, 0.66, 0.0, 0.62, 0.34, b.lw * 0.6, taperIn: 0.4, taperOut: 0.4);
    b.brushQuad(
      3,
      0.78,
      -0.3,
      1.04,
      -0.36,
      1.26,
      -0.12,
      b.lw * 1.0,
      color: b.colors.shine,
      taperIn: 0.5,
      taperOut: 0.5,
    );
    if (spat != null) {
      b.inkFill();
      pen
        ..circle(0.3, -0.12, 0.07)
        ..circle(0.3, 0.08, 0.07);
    }
    b.endLayer();
    pen.restore();
  }
}

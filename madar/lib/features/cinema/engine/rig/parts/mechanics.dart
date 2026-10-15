import 'dart:math' as math;
import 'dart:ui';

import '../ink/ink_build.dart';

/// Inked machine parts: gears, coil springs, rivets, bolts, sparks and
/// wind-up keys – for automatons, factories and props.
abstract final class Mechanics {
  /// A spur gear of outer radius [r] with [teeth] teeth turned by [angle].
  /// [holes] > 0 cuts round lightening holes; the hub is always drawn.
  static void gear(
    InkBuild b,
    double cx,
    double cy,
    double r,
    int teeth,
    double angle, {
    required Color fill,
    Color? hub,
    int holes = 4,
    double toothDepth = 0.18,
    bool shaded = true,
  }) {
    final pen = b.pen;
    final ro = r, ri = r * (1 - toothDepth);
    final step = math.pi * 2 / teeth;
    b.layer();
    b.shape(fill);
    for (var k = 0; k < teeth; k++) {
      final a = angle + k * step;
      final p0 = a - step * 0.3, p1 = a - step * 0.16, p2 = a + step * 0.16, p3 = a + step * 0.3;
      final j = b.ja(k, 0.25);
      if (k == 0) {
        pen.moveTo(cx + math.cos(p0) * ri, cy + math.sin(p0) * ri);
      } else {
        pen.lineTo(cx + math.cos(p0) * ri, cy + math.sin(p0) * ri);
      }
      pen
        ..lineTo(cx + math.cos(p1) * (ro + j), cy + math.sin(p1) * (ro + j))
        ..lineTo(cx + math.cos(p2) * (ro + j), cy + math.sin(p2) * (ro + j))
        ..lineTo(cx + math.cos(p3) * ri, cy + math.sin(p3) * ri);
      final pn = a + step * 0.7;
      pen.quadTo(
        cx + math.cos(a + step * 0.5) * ri * 0.98,
        cy + math.sin(a + step * 0.5) * ri * 0.98,
        cx + math.cos(pn) * ri,
        cy + math.sin(pn) * ri,
      );
    }
    pen.close();
    if (shaded) {
      final c = b.contour(0)..clear();
      c.ellipse(pen, cx, cy, ri, ri, samples: 28);
      c.writeCrescent(b.shade(), kShadowX, kShadowY, r * 0.28);
    }
    // Rim line, holes, hub.
    b.brushQuad(
      2,
      cx - ri * 0.72,
      cy - ri * 0.38,
      cx - ri * 0.62,
      cy - ri * 0.78,
      cx - ri * 0.1,
      cy - ri * 0.8,
      b.lw * 0.8,
      color: b.colors.shine,
    );
    for (var k = 0; k < holes; k++) {
      final a = angle * 1 + k * math.pi * 2 / holes + math.pi / holes;
      b.fill(b.colors.dark);
      pen.circle(cx + math.cos(a) * ri * 0.55, cy + math.sin(a) * ri * 0.55, ri * 0.17);
    }
    b.fill(hub ?? b.colors.dark);
    pen.circle(cx, cy, ri * 0.24);
    b.inkLine(b.lw * 0.8);
    pen.circle(cx, cy, ri * 0.24);
    b.fill(b.colors.shine);
    pen.circle(cx - ri * 0.07, cy - ri * 0.07, ri * 0.06);
    b.endLayer();
  }

  /// A coil spring from ([x0], [y0]) to ([x1], [y1]), [coils] turns, [w]
  /// wide, drawn as one thick-to-thin ink line.
  static void coil(
    InkBuild b,
    double x0,
    double y0,
    double x1,
    double y1,
    double w,
    int coils, {
    double weight = 1.4,
    Color? color,
    int salt = 0,
  }) {
    var dx = x1 - x0, dy = y1 - y0;
    final len = math.max(1e-6, math.sqrt(dx * dx + dy * dy));
    dx /= len;
    dy /= len;
    final nx = -dy, ny = dx;
    final c = b.contour(2)..clear(closed: false);
    final n = math.min(coils * 8, c.capacity - 1);
    for (var i = 0; i <= n; i++) {
      final t = i / n;
      final s = math.sin(t * coils * math.pi * 2) * w / 2;
      final back = math.cos(t * coils * math.pi * 2) * w * 0.12;
      c.addPen(b.pen, x0 + dx * (len * t + back) + nx * s, y0 + dy * (len * t + back) + ny * s);
    }
    b.layer();
    b.brush(c, b.lw * weight, color: color, taperIn: 0.05, taperOut: 0.05, minWidth: 0.5);
    b.endLayer();
  }

  /// A round rivet head with a glint.
  static void rivet(InkBuild b, double x, double y, double r) {
    final pen = b.pen;
    b.inkFill(b.colors.dark);
    pen.circle(x, y, r);
    b.fill(b.colors.shine);
    pen.circle(x - r * 0.35, y - r * 0.35, r * 0.35);
  }

  /// A crackle of sparks (a star burst with flying chips) at ([x], [y]).
  static void sparks(InkBuild b, double x, double y, double size, int salt) {
    final pen = b.pen;
    b.layer();
    b.shape(b.colors.hot, ink: 0.7);
    pen.star(x, y, 6, size, size * 0.35, rot: b.j(salt) * 0.6, round: 0);
    for (var i = 0; i < 4; i++) {
      final a = b.j(salt + 1 + i) * math.pi;
      final d = size * (1.4 + 0.6 * b.j(salt + 10 + i).abs());
      b.inkLine(b.lw * 0.7);
      pen
        ..moveTo(x + math.cos(a) * size * 1.1, y + math.sin(a) * size * 1.1)
        ..lineTo(x + math.cos(a) * d, y + math.sin(a) * d);
    }
    b.endLayer();
  }

  /// A wind-up key whose bow spins about the shaft ([spin] radians): the
  /// bow is foreshortened by cos(spin), like a real turning key.
  static void windKey(
    InkBuild b,
    double x,
    double y,
    double size,
    double spin, {
    required Color fill,
    double dir = -1,
  }) {
    final pen = b.pen;
    final f = math.cos(spin);
    final w = size * (0.25 + 0.75 * f.abs());
    b.layer();
    b.shape(fill);
    pen.roundRect(
      x + math.min(0, dir) * size * 0.9,
      y - size * 0.09,
      x + math.max(0, dir) * size * 0.9,
      y + size * 0.09,
      size * 0.05,
    );
    final bx = x + dir * size * 1.2;
    b.shape(fill);
    pen
      ..ellipse(bx, y - size * 0.34, w * 0.3, size * 0.36)
      ..ellipse(bx, y + size * 0.34, w * 0.3, size * 0.36);
    b.shape(fill);
    pen.ellipse(bx, y, w * 0.18, size * 0.16);
    if (w > size * 0.4) {
      b.fill(b.colors.dark);
      pen
        ..ellipse(bx, y - size * 0.36, w * 0.14, size * 0.18)
        ..ellipse(bx, y + size * 0.36, w * 0.14, size * 0.18);
    }
    b.endLayer();
  }
}

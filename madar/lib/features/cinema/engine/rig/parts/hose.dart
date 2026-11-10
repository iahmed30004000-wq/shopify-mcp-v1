import 'dart:math' as math;
import 'dart:ui';

import '../ink/ink_build.dart';
import '../ink/ink_list.dart';

/// Result of drawing a hose: the tangent at the tip (for gloves and shoes).
final class HoseTip {
  double x = 0, y = 0, angle = 0;
}

/// Rubber-hose limbs: no elbows, no knees – a tube of fixed length that
/// bows into a smooth arc when its ends come closer and thins as it
/// stretches. The bow's middle can be pushed by a follow-through spring
/// ([midX], [midY]) so the hose whips and settles like rubber.
abstract final class Hose {
  static final HoseTip _tip = HoseTip();

  /// Draws a hose in the current pen space from the root to the tip and
  /// returns the tip tangent. [bend] = which side the bow goes (+1/-1, in
  /// design space: +1 bows toward +x·y-rotated normal). [fill] = null draws
  /// a solid ink hose (the 1930s default); a colour draws an inked tube
  /// filled with it. [ribs] adds accordion bands (robots, bellows).
  static HoseTip draw(
    InkBuild b, {
    required double rootX,
    required double rootY,
    required double tipX,
    required double tipY,
    required double length,
    required double width,
    double bend = 1,
    double midX = 0,
    double midY = 0,
    Color? fill,
    int ribs = 0,
    int salt = 0,
    double taper = 0,
  }) {
    final pen = b.pen;
    var dx = tipX - rootX, dy = tipY - rootY;
    var c = math.sqrt(dx * dx + dy * dy);
    if (c < 1e-6) {
      dx = 0;
      dy = 1;
      c = 1e-6;
    }
    var sag = 0.0;
    var w = width;
    if (c < length) {
      sag = math.min(math.sqrt(3 * c * (length - c) / 8), length * 0.42);
    } else {
      w = width * math.max(0.62, math.sqrt(length / c));
    }
    final nx = -dy / c * bend, ny = dx / c * bend;
    final mx = rootX + dx / 2 + nx * sag + midX + b.ja(salt, 0.6);
    final my = rootY + dy / 2 + ny * sag + midY + b.ja(salt + 1, 0.6);
    // Quadratic through the bow's middle at t = 0.5.
    final cx = 2 * mx - (rootX + tipX) / 2;
    final cy = 2 * my - (rootY + tipY) / 2;

    b.layer();
    if (taper > 0) {
      // A tapered tube (tails): brush ribbon, thick at the root.
      final ct = b.contour(3)..clear(closed: false);
      ct.quad(pen, rootX, rootY, cx, cy, tipX, tipY, samples: 12);
      if (fill == null) {
        ct.writeBrush(b.inkFill(), w, taperIn: 0, taperOut: taper, minWidth: 0.3);
      } else {
        ct.writeBrush(b.inkFill(), w + b.lw * 2, taperIn: 0, taperOut: taper, minWidth: 0.35);
        ct.writeBrush(b.fill(fill), w, taperIn: 0, taperOut: taper, minWidth: 0.2);
      }
    } else {
      if (b.colors.neon) {
        pen.target(b.list.detail(InkOp.glow, b.colors.glow, w + b.lw * 3));
        _curve(b, rootX, rootY, cx, cy, tipX, tipY);
      }
      if (b.rimLine((fill == null ? w : w + b.lw * 1.6) * 1.05) != null) {
        _curve(b, rootX, rootY, cx, cy, tipX, tipY);
      }
      b.inkLine(fill == null ? w : w + b.lw * 1.6);
      _curve(b, rootX, rootY, cx, cy, tipX, tipY);
      if (fill != null) {
        b.stroke(fill, w - b.lw * 0.4);
        _curve(b, rootX, rootY, cx, cy, tipX, tipY);
      }
      if (ribs > 0) {
        b.inkLine(b.lw * 0.8);
        for (var i = 1; i <= ribs; i++) {
          final t = i / (ribs + 1), m = 1 - t;
          final px = m * m * rootX + 2 * m * t * cx + t * t * tipX;
          final py = m * m * rootY + 2 * m * t * cy + t * t * tipY;
          var tx = 2 * m * (cx - rootX) + 2 * t * (tipX - cx);
          var ty = 2 * m * (cy - rootY) + 2 * t * (tipY - cy);
          final tl = math.max(1e-6, math.sqrt(tx * tx + ty * ty));
          tx /= tl;
          ty /= tl;
          final hw = (fill == null ? w : w + b.lw) * 0.5;
          pen
            ..moveTo(px - ty * hw + tx * hw * 0.25, py + tx * hw + ty * hw * 0.25)
            ..quadTo(
              px - tx * hw * 0.1,
              py - ty * hw * 0.1,
              px + ty * hw + tx * hw * 0.25,
              py - tx * hw + ty * hw * 0.25,
            );
        }
      }
    }
    b.endLayer();

    final tx = tipX - cx, ty = tipY - cy;
    _tip
      ..x = tipX
      ..y = tipY
      ..angle = math.atan2(ty, tx);
    return _tip;
  }

  static void _curve(InkBuild b, double x0, double y0, double cx, double cy, double x1, double y1) {
    b.pen
      ..moveTo(x0, y0)
      ..quadTo(cx, cy, x1, y1);
  }
}

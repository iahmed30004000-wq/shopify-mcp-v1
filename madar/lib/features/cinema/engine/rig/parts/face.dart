import 'dart:math' as math;
import 'dart:ui';

import '../../core/rig.dart';
import '../ink/ink_build.dart';
import '../ink/ink_pen.dart';

/// Mouth shape presets (talk cycles through the open ones).
enum MouthShape { auto, closed, smile, grin, open, oh, grimace, wavy, smirk, frown, tongue }

/// Nose styles.
enum NoseStyle { none, button, snout, beak }

/// Eye-lid / pupil state for special moments (overrides the expression).
enum EyeState { auto, shut, squeeze, cross, spiral, heavy }

/// A cartoon face drawn on a head of radius [r] centred at ([cx], [cy]) in
/// the pen's design space. The character sets the fields each drawing and
/// calls [draw]. [turn] (0 = front, 1 = full three-quarter toward +x)
/// slides and foreshortens the features, so a front view and a side view
/// are the same drawing.
final class Face {
  double cx = 0, cy = 0, r = 30;
  double turn = 0;
  RigExpression expression = RigExpression.neutral;
  RigEyes eyes = RigEyes.pieCut;

  /// Eye size relative to the head (1 = the classic big pie eyes).
  double eyeScale = 1;

  /// Horizontal gap between the eyes (relative to eye width; 0 = touching).
  double eyeGap = 0.08;

  /// Vertical position of the eyes (relative to r, negative = up).
  double eyeY = -0.12;

  /// 0 open … 1 closed.
  double blink = 0;

  /// Pupil direction, each axis in -1..1.
  double lookX = 0, lookY = 0;

  EyeState eyeState = EyeState.auto;

  /// Spin of spiral eyes (radians).
  double spin = 0;

  /// Tremble (scared) offset applied to the pupils, local units.
  double tremble = 0;

  bool brows = true;
  NoseStyle nose = NoseStyle.button;
  double noseScale = 1;

  /// Colour of the lids (the skin around the eyes).
  Color skin = const Color(0xFFFFFFFF);
  Color? noseColor;

  MouthShape mouth = MouthShape.auto;

  /// 0..1 how open the mouth is (talk / shout); used when [mouth] is auto
  /// or open.
  double mouthOpen = 0;

  /// Mouth position below the centre (relative to r) and width (relative).
  double mouthY = 0.52;
  double mouthW = 0.78;

  /// Hide the mouth (beaks, masks).
  bool drawMouth = true;

  /// Eyelashes (count per eye, 0 = none).
  int lashes = 0;

  int salt = 0;

  // Resolved per draw.
  double _ew = 0, _eh = 0;

  void draw(InkBuild b) {
    final e = expression;
    final t = turn.clamp(0.0, 1.0);
    // Eye metrics.
    var ew = r * 0.25 * eyeScale, eh = r * 0.42 * eyeScale;
    switch (e) {
      case RigExpression.surprised:
        ew *= 1.12;
        eh *= 1.22;
      case RigExpression.scared:
        ew *= 1.1;
        eh *= 1.14;
      case RigExpression.happy:
        eh *= 0.96;
      default:
    }
    if (eyes == RigEyes.dots) {
      ew *= 0.42;
      eh *= 0.5;
    }
    _ew = ew;
    _eh = eh;
    final fx = cx + t * r * 0.3;
    final ey = cy + eyeY * r;
    final spacing = ew * (1 + eyeGap);
    // Far eye (−x) shrinks and tucks in when turned.
    final farScale = 1 - 0.2 * t, nearScale = 1 + 0.04 * t;
    final farX = fx - spacing * (1 - 0.3 * t);
    final nearX = fx + spacing;

    final state = _resolvedEyeState();
    _eye(b, farX, ey, farScale, -1, state);
    _eye(b, nearX, ey, nearScale, 1, state);

    if (brows) {
      _brow(b, farX, ey - eh * farScale, farScale, -1);
      _brow(b, nearX, ey - eh * nearScale, nearScale, 1);
    }
    if (nose != NoseStyle.none) _nose(b, fx + t * r * 0.28, ey + eh * 0.95);
    if (drawMouth) _mouth(b, fx + t * r * 0.18, cy + mouthY * r, r * mouthW * (1 - 0.12 * t));
  }

  EyeState _resolvedEyeState() {
    if (eyeState != EyeState.auto) return eyeState;
    if (expression == RigExpression.dizzy) return EyeState.spiral;
    return EyeState.auto;
  }

  // ---------------------------------------------------------------- eyes

  void _eye(InkBuild b, double x, double y, double s, int side, EyeState state) {
    final pen = b.pen;
    final ew = _ew * s, eh = _eh * s;
    final e = expression;
    final lw = b.lw;
    if (state == EyeState.squeeze) {
      // Screwed shut: > <
      final d = side * -1.0;
      b.layer();
      final c = b.contour(2)..clear(closed: false);
      c
        ..quad(pen, x - d * ew * 0.9, y - eh * 0.55, x + d * ew * 0.2, y - eh * 0.1, x + d * ew * 0.8, y, samples: 6)
        ..quad(
          pen,
          x + d * ew * 0.8,
          y,
          x + d * ew * 0.2,
          y + eh * 0.1,
          x - d * ew * 0.9,
          y + eh * 0.45,
          samples: 6,
          skipFirst: true,
        );
      b.brush(c, lw * 1.5, taperIn: 0.3, taperOut: 0.3);
      b.endLayer();
      return;
    }
    if (state == EyeState.shut || (blink >= 0.95 && state == EyeState.auto && eyes != RigEyes.dots)) {
      b.layer();
      final smile = e == RigExpression.happy ? -1.0 : 1.0;
      b.brushQuad(2, x - ew, y + eh * 0.1, x, y + eh * 0.1 + smile * eh * 0.45, x + ew, y + eh * 0.1, lw * 1.3);
      b.endLayer();
      return;
    }
    if (eyes == RigEyes.dots) {
      b.layer();
      b.inkFill(b.colors.dark);
      pen.ellipse(x + lookX * ew * 0.3, y + lookY * eh * 0.2, ew, eh);
      b.fill(b.colors.shine);
      pen.ellipse(x + lookX * ew * 0.3 - ew * 0.35, y - eh * 0.4, ew * 0.28, eh * 0.22);
      b.endLayer();
      return;
    }
    // The white.
    b.layer();
    final c = b.contour(1)..clear();
    final lean = side * 0.06;
    pen
      ..save()
      ..translate(x, y)
      ..rotate(lean);
    c.ellipse(pen, 0, 0, ew, eh, samples: 24);
    pen.restore();
    c.wobble(b.amp * 0.35, b.frame, b.seedFor(salt + side), 31);
    b.blob(c, b.colors.eyeWhite, ink: 0.72);

    if (state == EyeState.cross) {
      b.brushQuad(2, x - ew * 0.6, y - eh * 0.5, x, y, x + ew * 0.6, y + eh * 0.5, lw * 1.2);
      b.brushQuad(2, x + ew * 0.6, y - eh * 0.5, x, y, x - ew * 0.6, y + eh * 0.5, lw * 1.2);
      b.endLayer();
      return;
    }
    if (state == EyeState.spiral) {
      final sc = b.contour(2)..clear(closed: false);
      for (var i = 0; i <= 22; i++) {
        final k = i / 22;
        final a = spin * side + k * math.pi * 4.2;
        sc.addPen(pen, x + math.cos(a) * ew * 0.8 * k, y + math.sin(a) * eh * 0.8 * k);
      }
      b.brush(sc, lw * 0.9, taperIn: 0.1, taperOut: 0.25);
      b.endLayer();
      return;
    }

    // Pupil: pie-cut (the wedge faces up-forward), round, with look/tremble.
    var pw = ew * 0.6, ph = eh * 0.6;
    if (e == RigExpression.scared || e == RigExpression.surprised) {
      pw *= 0.55;
      ph *= 0.5;
    }
    final maxX = ew - pw * 0.92, maxY = eh - ph * 0.92;
    var bx = lookX, by = lookY + 0.25;
    switch (e) {
      case RigExpression.sly:
        bx += 0.6;
        by -= 0.1;
      case RigExpression.angry || RigExpression.determined:
        bx -= side * 0.25;
        by += 0.05;
      case RigExpression.happy:
        by -= 0.2;
      default:
    }
    final px = x + bx.clamp(-1.0, 1.0) * maxX + tremble * b.j(salt + 40 + side);
    final py = y + by.clamp(-1.0, 1.0) * maxY + tremble * b.j(salt + 42 + side);
    if (eyes == RigEyes.pieCut) {
      const wedge = 0.95;
      const dirA = -math.pi * 0.33;
      final start = dirA + wedge / 2;
      b.inkFill(b.colors.dark);
      _wedge(pen, px, py, pw, ph, start, math.pi * 2 - wedge);
    } else {
      b.inkFill(b.colors.dark);
      pen.ellipse(px, py, pw, ph);
      b.fill(b.colors.shine);
      pen.ellipse(px + pw * 0.3, py - ph * 0.4, pw * 0.26, ph * 0.22);
    }

    // Lids: upper (blink / heavy / angry slant) and lower (happy squint).
    var upper = blink.clamp(0.0, 1.0);
    var slant = 0.0;
    var lower = 0.0;
    switch (e) {
      case RigExpression.angry:
        upper = math.max(upper, 0.36);
        slant = -side * 0.55;
      case RigExpression.determined:
        upper = math.max(upper, 0.3);
        slant = -side * 0.3;
      case RigExpression.sly:
        upper = math.max(upper, 0.46);
        slant = side * 0.2;
        lower = 0.18;
      case RigExpression.happy:
        lower = 0.34;
      case RigExpression.scared:
        slant = side * 0.25;
        upper = math.max(upper, 0.08);
      default:
    }
    if (eyeState == EyeState.heavy) upper = math.max(upper, 0.5);
    if (upper > 0.02) _lid(b, x, y, ew, eh, upper, slant, true);
    if (lower > 0.02) _lid(b, x, y, ew, eh, lower, 0, false);
    if (lashes > 0) {
      for (var i = 0; i < lashes; i++) {
        final a = -math.pi / 2 + (i - (lashes - 1) / 2) * 0.45 + 0.35;
        final lx = x + math.cos(a) * ew * 0.9, ly = y - eh * (1 - 2 * upper) * 0.95 + math.sin(a) * eh * 0.1;
        b.brushQuad(
          2,
          lx,
          ly,
          lx + math.cos(a) * ew * 0.35,
          ly - eh * 0.28,
          lx + math.cos(a) * ew * 0.7,
          ly - eh * 0.3,
          lw * 0.9,
          taperIn: 0.05,
          taperOut: 0.7,
        );
      }
    }
    b.endLayer();
  }

  /// An eyelid covering the eye from the top (or bottom) down to [amount].
  void _lid(InkBuild b, double x, double y, double ew, double eh, double amount, double slant, bool upper) {
    final pen = b.pen;
    final c = b.contour(2)..clear();
    // Lid edge: y = edge + slant·dx (upper) – clamp the eye oval to it.
    final edge = upper ? y - eh + amount * 2 * eh : y + eh - amount * 2 * eh;
    for (var i = 0; i < 24; i++) {
      final a = -math.pi / 2 + i * math.pi * 2 / 24;
      final ex = math.cos(a) * ew * 0.98, ey = math.sin(a) * eh * 0.98;
      final lineY = edge + slant * ex * eh / ew * 0.8 + (upper ? 1 : -1) * (1 - (ex / ew) * (ex / ew)) * eh * 0.12;
      final yy = upper ? math.min(y + ey, lineY) : math.max(y + ey, lineY);
      c.addPen(pen, x + ex, yy);
    }
    c.writeSmooth(b.fill(skin));
    // The lid line.
    final hw = ew * 0.98;
    final l0 = edge + slant * -hw * eh / ew * 0.8, l1 = edge + slant * hw * eh / ew * 0.8;
    final mid = edge + (upper ? 1 : -1) * eh * 0.12;
    b.brushQuad(
      3,
      x - hw,
      l0,
      x,
      mid * 2 - (l0 + l1) / 2,
      x + hw,
      l1,
      b.lw * (upper ? 1.15 : 0.8),
      taperIn: 0.25,
      taperOut: 0.25,
    );
  }

  static void _wedge(InkPen pen, double cx, double cy, double rx, double ry, double start, double sweep) {
    pen
      ..moveTo(cx, cy)
      ..lineTo(cx + math.cos(start) * rx, cy + math.sin(start) * ry);
    final segs = (sweep.abs() / (math.pi / 2)).ceil();
    final step = sweep / segs;
    final k = 4 / 3 * math.tan(step / 4);
    var a = start;
    for (var i = 0; i < segs; i++) {
      final a2 = a + step;
      final c1x = cx + (math.cos(a) - k * math.sin(a)) * rx, c1y = cy + (math.sin(a) + k * math.cos(a)) * ry;
      final c2x = cx + (math.cos(a2) + k * math.sin(a2)) * rx, c2y = cy + (math.sin(a2) - k * math.cos(a2)) * ry;
      pen.cubicTo(c1x, c1y, c2x, c2y, cx + math.cos(a2) * rx, cy + math.sin(a2) * ry);
      a = a2;
    }
    pen.close();
  }

  // --------------------------------------------------------------- brows

  void _brow(InkBuild b, double x, double top, double s, int side) {
    final e = expression;
    final ew = _ew * s;
    // (height above the eye, inner tilt: + = inner end down, arch)
    var lift = 0.35, tilt = 0.0, arch = 0.25, thick = 1.4;
    switch (e) {
      case RigExpression.angry:
        lift = 0.05;
        tilt = 0.55;
        arch = -0.05;
        thick = 1.9;
      case RigExpression.determined:
        lift = 0.12;
        tilt = 0.32;
        arch = 0.05;
        thick = 1.7;
      case RigExpression.scared:
        lift = 0.55;
        tilt = -0.5;
        arch = 0.15;
      case RigExpression.surprised:
        lift = 0.85;
        tilt = -0.1;
        arch = 0.5;
      case RigExpression.happy:
        lift = 0.5;
        tilt = -0.12;
        arch = 0.45;
      case RigExpression.sly:
        lift = side > 0 ? 0.6 : 0.12;
        tilt = side > 0 ? -0.2 : 0.3;
        arch = 0.3;
      case RigExpression.dizzy:
        lift = 0.4;
        tilt = side * 0.3;
      default:
    }
    final y = top - ew * lift;
    final inner = x - side * ew * 0.85, outer = x + side * ew * 0.95;
    final yi = y + tilt * ew * 0.6, yo = y - tilt * ew * 0.25;
    b.layer();
    b.brushQuad(
      2,
      inner,
      yi,
      (inner + outer) / 2,
      (yi + yo) / 2 - arch * ew,
      outer,
      yo,
      b.lw * thick,
      taperIn: 0.15,
      taperOut: 0.7,
      press: 0.4,
      wobble: b.amp * 0.3,
      salt: salt + 60 + side,
    );
    b.endLayer();
  }

  // ---------------------------------------------------------------- nose

  void _nose(InkBuild b, double x, double y) {
    final pen = b.pen;
    final s = r * noseScale;
    b.layer();
    switch (nose) {
      case NoseStyle.button:
        b.shape(noseColor ?? b.colors.dark, ink: 0.6);
        pen.ellipse(x, y, s * 0.13, s * 0.1);
        b.fill(b.colors.shine);
        pen.ellipse(x - s * 0.045, y - s * 0.04, s * 0.04, s * 0.028);
      case NoseStyle.snout:
        b.shape(noseColor ?? skin, ink: 0.8);
        pen.ellipse(x + s * 0.05, y + s * 0.02, s * 0.24, s * 0.16);
        b.inkFill(b.colors.dark);
        pen
          ..ellipse(x - s * 0.04, y + s * 0.03, s * 0.04, s * 0.05)
          ..ellipse(x + s * 0.14, y + s * 0.03, s * 0.04, s * 0.05);
      case NoseStyle.beak || NoseStyle.none:
    }
    b.endLayer();
  }

  // --------------------------------------------------------------- mouth

  MouthShape _shape() {
    if (mouth != MouthShape.auto) return mouth;
    if (mouthOpen > 0.15) return MouthShape.open;
    return switch (expression) {
      RigExpression.neutral => MouthShape.smile,
      RigExpression.happy => MouthShape.grin,
      RigExpression.angry => MouthShape.grimace,
      RigExpression.scared => MouthShape.wavy,
      RigExpression.surprised => MouthShape.oh,
      RigExpression.dizzy => MouthShape.tongue,
      RigExpression.determined => MouthShape.smirk,
      RigExpression.sly => MouthShape.smirk,
    };
  }

  void _mouth(InkBuild b, double x, double y, double w) {
    final pen = b.pen;
    final shape = _shape();
    final lw = b.lw;
    final hw = w / 2;
    b.layer();
    switch (shape) {
      case MouthShape.closed || MouthShape.auto:
        b.brushQuad(2, x - hw * 0.5, y, x, y + w * 0.02, x + hw * 0.5, y, lw * 1.2);
      case MouthShape.smile || MouthShape.smirk || MouthShape.frown:
        final k = shape == MouthShape.frown ? -0.3 : 0.32;
        final lift = shape == MouthShape.smirk ? 0.22 : 0.0;
        final x0 = x - hw * 0.85, x1 = x + hw * 0.85;
        final y0 = y - (shape == MouthShape.frown ? -w * 0.05 : w * 0.06);
        final y1 = y0 - lift * w;
        b.brushQuad(2, x0, y0, x, y + k * w, x1, y1, lw * 1.35, taperIn: 0.3, taperOut: 0.3, press: 0.2);
        if (shape != MouthShape.frown) {
          // Dimples.
          b.brushQuad(
            3,
            x1 - w * 0.02,
            y1 - w * 0.1,
            x1 + w * 0.08,
            y1 - w * 0.02,
            x1 + w * 0.02,
            y1 + w * 0.08,
            lw * 0.9,
          );
          if (shape == MouthShape.smile) {
            b.brushQuad(
              3,
              x0 + w * 0.02,
              y0 - w * 0.1,
              x0 - w * 0.08,
              y0 - w * 0.02,
              x0 - w * 0.02,
              y0 + w * 0.08,
              lw * 0.9,
            );
          }
        }
      case MouthShape.wavy:
        final c = b.contour(2)..clear(closed: false);
        for (var i = 0; i <= 12; i++) {
          final k = i / 12;
          c.addPen(pen, x - hw * 0.7 + k * hw * 1.4, y + math.sin(k * math.pi * 4 + b.frame * 1.3) * w * 0.05);
        }
        b.brush(c, lw * 1.2, taperIn: 0.15, taperOut: 0.15);
      case MouthShape.grin || MouthShape.open || MouthShape.oh || MouthShape.grimace || MouthShape.tongue:
        final open = switch (shape) {
          MouthShape.grin => 0.5 + mouthOpen * 0.4,
          MouthShape.oh => 0.75,
          MouthShape.grimace => 0.34,
          MouthShape.tongue => 0.45,
          _ => 0.2 + mouthOpen * 0.8,
        };
        double lx, rx, ly, ry, topY, botY;
        if (shape == MouthShape.oh) {
          lx = x - hw * 0.34;
          rx = x + hw * 0.34;
          ly = ry = y + w * 0.08;
          topY = y - w * 0.28;
          botY = y + w * 0.46;
        } else if (shape == MouthShape.grimace) {
          lx = x - hw;
          rx = x + hw;
          ly = ry = y + w * 0.06;
          topY = y - w * 0.04;
          botY = y + w * open * 0.9;
        } else {
          lx = x - hw * 0.9;
          rx = x + hw * 0.9;
          ly = y - w * 0.08;
          ry = y - w * 0.1;
          topY = y + w * 0.02;
          botY = y + w * (0.18 + open * 0.62);
        }
        // Interior.
        final mc = b.contour(2)..clear();
        mc
          ..quad(pen, lx, ly, x, topY * 2 - (ly + ry) / 2, rx, ry, samples: 8)
          ..quad(pen, rx, ry, x, botY * 2 - (ly + ry) / 2, lx, ly, samples: 10, skipFirst: true);
        mc.length--; // drop the duplicated start point
        b.blob(mc, b.colors.dark, ink: 0.72);
        // Teeth along the top.
        if (shape == MouthShape.grin || shape == MouthShape.grimace) {
          final th = shape == MouthShape.grimace ? (botY - topY) * 0.55 : (botY - topY) * 0.26;
          final tc = b.contour(3)..clear();
          final tcy = topY * 2 - (ly + ry) / 2;
          for (var i = 0; i <= 8; i++) {
            final k = 0.08 + i / 8 * 0.84, m = 1 - k;
            tc.addPen(
              pen,
              m * m * lx + 2 * m * k * x + k * k * rx,
              m * m * ly + 2 * m * k * tcy + k * k * ry + lw * 0.3,
            );
          }
          for (var i = 8; i >= 0; i--) {
            final k = 0.08 + i / 8 * 0.84, m = 1 - k;
            final sag = math.sin(k * math.pi);
            tc.addPen(
              pen,
              m * m * lx + 2 * m * k * x + k * k * rx,
              m * m * ly + 2 * m * k * tcy + k * k * ry + th * (0.55 + 0.45 * sag),
            );
          }
          tc.writeSmooth(b.fill(b.colors.teeth));
          if (shape == MouthShape.grimace) {
            // Tooth gaps + the bottom row.
            for (var i = 1; i <= 3; i++) {
              final gx = lx + (rx - lx) * i / 4;
              b.inkLine(lw * 0.6);
              pen
                ..moveTo(gx, topY + lw * 0.2)
                ..lineTo(gx, topY + th * 0.9);
            }
          }
        }
        // Tongue sitting in the bottom of the mouth.
        if (shape != MouthShape.grimace) {
          final tcx = shape == MouthShape.tongue ? x + w * 0.1 : x + w * 0.06;
          final bcy = botY * 2 - (ly + ry) / 2;
          final tg = b.contour(3)..clear();
          for (var i = 0; i <= 8; i++) {
            final k = 0.24 + i / 8 * 0.52, m = 1 - k;
            tg.addPen(
              pen,
              m * m * rx + 2 * m * k * x + k * k * lx,
              m * m * ry + 2 * m * k * bcy + k * k * ly - lw * 0.3,
            );
          }
          final tongueH = (botY - topY) * (shape == MouthShape.tongue ? 1.1 : 0.42);
          final hang = shape == MouthShape.tongue ? w * 0.35 : 0.0;
          tg
            ..addPen(pen, tcx - w * 0.2, botY - tongueH * 0.55 + hang * 0.3)
            ..addPen(pen, tcx, botY - tongueH * 0.75 + hang)
            ..addPen(pen, tcx + w * 0.2, botY - tongueH * 0.5 + hang * 0.3);
          if (shape == MouthShape.tongue) {
            tg.writeSmooth(b.shape(b.colors.tongue, ink: 0.6));
          } else {
            tg.writeSmooth(b.fill(b.colors.tongue));
          }
        }
    }
    b.endLayer();
  }
}

extension on InkBuild {
  int seedFor(int salt) => seed + salt * 7919;
}

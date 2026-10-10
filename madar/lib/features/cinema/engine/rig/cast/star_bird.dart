import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import '../../core/era_skin.dart';
import '../../core/rig.dart';
import '../hose_rig.dart';
import '../ink/contour.dart';
import '../ink/ink_build.dart';
import '../motion/spring.dart';
import '../parts/emanata.dart';
import '../parts/extremities.dart';
import '../parts/face.dart';
import '../parts/hose.dart';
import '../ink/ink_pen.dart';

/// **Nujaym** (نُجيم, "little star") – the plucky star-bird of *Flappy
/// Orbit*. An original design: a round, ink-black bird with a white
/// heart-shaped face mask (fitted round big pie eyes) and belly, a short
/// stubby beak with a smile crease, aviator goggles pushed up on the crown,
/// a polka-dot bandana knotted at the back of the neck whose swallow-tails
/// stream behind him (white in B&W, the accent colour elsewhere), a
/// five-point star bobbing on a spring crest, rubber-hose wings that end
/// in white feather "gloves", and tiny spats on hose legs.
///
/// He lives in the air: [RigAction.idle] is a hover, [RigAction.jump] is
/// one strong flap (call it on every tap), [RigAction.fall] holds the wings
/// up, [RigAction.run] is a streamlined dash, [RigAction.cheer] a
/// loop-the-loop, [RigAction.hurt] pops loose feathers,
/// [RigAction.defeated] tumbles. [pitch] (radians, + = nose down) can be
/// driven from the vertical speed; by default it follows the action.
class StarBird extends HoseRig {
  StarBird({double height = 90, int seed = 0})
    : super(
        RigSpec(
          id: 'nujaym',
          body: RigBody.ball,
          height: height,
          fill: PaletteRole.ink,
          trim: PaletteRole.paper,
          accent: PaletteRole.accent,
          limbWidth: 0.065,
          bounciness: 1.3,
          seed: seed,
        ),
      ) {
    for (final w in wings) {
      w.snap(0, -height * 0.7);
    }
    for (var i = 0; i < scarf.length; i++) {
      scarf[i].snap(knotX - height * 0.06 * (i + 1), knotY + height * 0.03 * (i + 1));
    }
    crest.snap(0, -height);
  }

  /// Where the bandana is knotted (design space, standing frame).
  double get knotX => -spec.height * 0.265;
  double get knotY => -spec.height * 0.47;

  /// Nose-down pitch override (radians); `null` = pose-driven.
  double? pitch;

  final Spring1 _pitch = Spring1();
  final Spring2 _bob = Spring2();
  final List<Spring2> wings = [Spring2(), Spring2()];
  final List<Spring2> feet = [Spring2(), Spring2()];
  final List<Spring2> scarf = [for (var i = 0; i < 4; i++) Spring2()];
  final Spring2 crest = Spring2();
  double _flap = 0;
  double _spin = 0;
  double _beak = 0;
  final Face face = Face();
  late final Contour _c = Contour(64);

  // Loose feathers (hurt): age, x, y, vx, vy, spin.
  final List<double> _feathers = List<double>.filled(3 * 6, 2);

  double get u => spec.height / 100;

  @override
  void onAction(RigAction action, RigAction previous) {
    super.onAction(action, previous);
    if (action == RigAction.jump) {
      _flap = math.pi * 1.5; // top of the stroke → sweep down
      crest.kick(0, spec.height * 2.2);
      _bob.kick(0, -spec.height * 0.6);
    }
    if (action == RigAction.hurt) {
      for (var i = 0; i < 3; i++) {
        final k = i * 6;
        _feathers[k] = 0;
        _feathers[k + 1] = -spec.height * 0.05 * i;
        _feathers[k + 2] = -spec.height * 0.5;
        _feathers[k + 3] = (-0.8 + i * 0.7) * spec.height;
        _feathers[k + 4] = -spec.height * (1.2 + 0.3 * i);
        _feathers[k + 5] = i * 2.0;
      }
    }
  }

  @override
  double oneShotLength(RigAction action) => switch (action) {
    RigAction.jump => 0,
    RigAction.cheer => 0,
    _ => super.oneShotLength(action),
  };

  @override
  bool get fastAction => action != RigAction.talk && action != RigAction.taunt || actionTime < 0.2;

  @override
  void animate(double h) {
    final hh = spec.height, uu = u;
    final t = actionTime;
    // Wing beat rate and amplitude.
    var rate = 2.6, lo = 0.5, hi = 2.5, tp = 0.1, beak = talkLevel;
    var legSwing = 0.0;
    switch (action) {
      case RigAction.idle || RigAction.walk:
        rate = 2.8;
      case RigAction.jump:
        rate = t < 0.22 ? 5.5 : 3.2;
        tp = -0.25;
        beak = 0.5;
      case RigAction.fall:
        rate = 0;
        tp = 0.35;
        legSwing = 1;
      case RigAction.run:
        rate = 4.2;
        lo = 1.6;
        hi = 2.7;
        tp = 0.32;
      case RigAction.land:
        rate = 1.5;
        tp = -0.1;
      case RigAction.hurt:
        rate = 7;
        tp = -0.45;
        beak = 0.8;
      case RigAction.attack:
        rate = 3;
        tp = 0.7 * Bounce.span(t, 0, 0.15);
        beak = 1;
      case RigAction.cheer:
        rate = 5;
        beak = 0.8;
      case RigAction.taunt:
        rate = 2.2;
        tp = -0.12;
        beak = 0.6;
      case RigAction.talk:
        rate = 2.4;
        beak = math.max(talkLevel, (math.sin(time * 18) * 0.5 + 0.5) * (math.sin(time * 5) * 0.3 + 0.7));
      case RigAction.defeated:
        rate = 0;
        tp = 0;
        legSwing = 1;
    }
    if (rate > 0) _flap += h * rate * math.pi * 2;
    // Wing angle ψ: 0 = straight up … π = straight down.
    double psi;
    if (action == RigAction.fall) {
      psi = 0.45 + math.sin(time * 9) * 0.12;
    } else if (action == RigAction.defeated) {
      psi = 2.3 + math.sin(time * 2) * 0.1;
    } else {
      final s = math.sin(_flap);
      psi = (lo + hi) / 2 - s * (hi - lo) / 2;
    }
    _beak += (beak - _beak) * math.min(1, h * 20);
    // Body bob: lift on the downstroke.
    final bobY = action == RigAction.defeated ? 0.0 : -math.cos(_flap) * 3.2 * uu * (rate > 0 ? 1 : 0);
    _bob.step(h, 0, bobY, 20, 0.5);
    // Spin (cheer: loop-the-loop; defeated: slow tumble).
    if (action == RigAction.cheer) {
      final loop = (t % 1.4) / 0.7;
      _spin = loop < 1 ? Bounce.smooth(loop) * math.pi * 2 : 0;
    } else if (action == RigAction.defeated) {
      _spin += h * 2.2;
    } else {
      _spin = 0;
    }
    // Nose follows the climb / dive when the game feeds a velocity.
    final vPitch = velocity == Offset.zero ? 0.0 : (velocity.dy / (hh * 9)).clamp(-0.45, 0.7);
    _pitch.step(h, pitch ?? tp + vPitch, 14, 0.55);
    final pt = _pitch.value;

    // Wing hands around their shoulders (in the body frame).
    final lw = hh * 0.24;
    for (var i = 0; i < 2; i++) {
      final side = i == 0 ? -1.0 : 1.0;
      final ps = psi + (i == 0 ? 0.18 : 0);
      final tn = turn;
      final sx = side * math.sin(ps) * (1 - tn) + (-0.62 - 0.2 * math.sin(ps)) * tn;
      final rootX = Bounce.lerp(side * hh * 0.24, i == 0 ? -hh * 0.14 : -hh * 0.08, tn);
      wings[i].step(h, rootX + sx * lw, -hh * 0.5 - math.cos(ps) * lw * 0.9, 38, 0.5);
    }
    // Feet dangle below the body with lag.
    for (var i = 0; i < 2; i++) {
      final side = i == 0 ? -1.0 : 1.0;
      final swing = math.sin(time * 11 + i * 1.7) * 4 * uu * legSwing;
      final tx = side * 6 * uu - pt * 12 * uu + swing - speed * 0.02;
      feet[i].step(h, tx, (action == RigAction.land ? 0 : -2 * uu) + math.cos(_flap + i) * 1.5 * uu, 22, 0.35);
    }
    // Bandana tails stream from the knot at the back of the neck (wind from
    // speed and the flap). Each link rides a spring but is tethered to the
    // one before like a rope, so the tails can whip but never stretch.
    var px = knotX, py = knotY;
    final wind = 0.55 + (speed.abs() / hh).clamp(0.0, 3.0) * 0.35 + (action == RigAction.run ? 0.5 : 0);
    final seg = hh * 0.075;
    for (var i = 0; i < scarf.length; i++) {
      final c = scarf[i];
      final flutter = math.sin(time * 13 - i * 1.3) * hh * 0.03 * (i + 1) / 4;
      final droop = (1.2 - wind).clamp(0.0, 1.0);
      c.step(h, px - seg * (0.4 + 0.6 * math.min(1, wind)), py + seg * 0.9 * droop + flutter, 30 - i * 3.0, 0.4);
      final dx = c.x - px, dy = c.y - py;
      final d = math.sqrt(dx * dx + dy * dy);
      if (d > seg) {
        c.x = px + dx / d * seg;
        c.y = py + dy / d * seg;
      }
      px = c.x;
      py = c.y;
    }
    // Crest star on its spring.
    crest.step(h, -hh * 0.03 - pt * hh * 0.1, -hh * 1.0, 16, 0.18);
    // Loose feathers.
    for (var i = 0; i < 3; i++) {
      final k = i * 6;
      if (_feathers[k] > 1.5) continue;
      _feathers[k] += h;
      _feathers[k + 1] += _feathers[k + 3] * h;
      _feathers[k + 2] += _feathers[k + 4] * h;
      _feathers[k + 3] *= 1 - h * 2.5;
      _feathers[k + 4] = _feathers[k + 4] * (1 - h * 3) + hh * 0.9 * h;
      _feathers[k + 5] += h * 5;
    }
  }

  @override
  void build(RigPaintContext ctx) {
    final b = ink;
    final hh = spec.height;
    b.begin(ctx, size: hh, boilFrame: boilFrame);
    final c = b.colors;
    final pen = b.pen;
    final body = c.fill(spec.fill), white = c.fill(spec.trim);
    final tn = turn;
    final s = squashAmount;
    final sy = (1 - s).clamp(0.65, 1.4), sx = 1 / sy;
    final cy = -hh * 0.5 + _bob.y;
    pen
      ..reset()
      ..translate(0, cy)
      ..scale(sx, sy)
      ..translate(0, -cy)
      ..scale(dir, 1);
    setBounds(-hh * 0.62, -hh * 1.12, hh * 0.62, hh * 0.02);
    b.shadeAcross(Rect.fromLTWH(-hh * 0.35, -hh * 0.85, hh * 0.7, hh * 0.7));
    final r = hh * 0.29;
    final spin = _spin + _pitch.value;

    // Loose feathers behind.
    if (emanata) _looseFeathers(b);
    // Everything rotates about the body centre with the pitch / spin.
    pen
      ..save()
      ..rotateAbout(spin, 0, cy);

    // Scarf tails (behind).
    _bandanaTails(b, cy);
    // Far wing, legs.
    _wing(b, 0, cy);
    for (var i = 0; i < 2; i++) {
      final f = feet[i];
      final side = i == 0 ? -1.0 : 1.0;
      Hose.draw(
        b,
        rootX: side * hh * 0.07 + tn * hh * 0.02,
        rootY: cy + r * 0.85,
        tipX: f.x,
        tipY: f.y - hh * 0.03,
        length: hh * 0.24,
        width: hh * 0.045,
        bend: side,
        midX: -f.vx * 0.01,
        salt: 30 + i * 3,
      );
      Extremities.shoe(
        b,
        x: f.x,
        y: f.y - hh * 0.03,
        size: hh * 0.05,
        fill: white,
        pitch: 0.2,
        salt: 40 + i * 2,
        spat: body,
      );
    }
    // Tail feathers: three black plumes with white tips, fanned behind.
    b.layer();
    for (var i = -1; i <= 1; i++) {
      final a = math.pi * 1.06 + i * 0.3 + math.sin(time * 6 + i) * 0.06;
      final len = r * (0.72 - i.abs() * 0.14);
      _leaf(pen, b.shape(body), -r * 0.7, cy + r * 0.3, a, len, r * 0.34);
    }
    for (var i = -1; i <= 1; i++) {
      final a = math.pi * 1.06 + i * 0.3 + math.sin(time * 6 + i) * 0.06;
      final len = r * (0.72 - i.abs() * 0.14);
      final ca = math.cos(a), sa = math.sin(a);
      b.brushQuad(
        3,
        -r * 0.7 + ca * len * 0.25,
        cy + r * 0.3 + sa * len * 0.25,
        -r * 0.7 + ca * len * 0.55,
        cy + r * 0.3 + sa * len * 0.55 + r * 0.02,
        -r * 0.7 + ca * len * 0.85,
        cy + r * 0.3 + sa * len * 0.85,
        b.lw * 0.6,
        color: c.shine,
        taperIn: 0.3,
        taperOut: 0.7,
      );
    }
    b.endLayer();

    // Crest: a spring stalk and its star.
    final topX = r * 0.1 * tn, topY = cy - r * 0.95;
    Hose.draw(
      b,
      rootX: topX,
      rootY: topY,
      tipX: crest.x,
      tipY: cy - r * 0.95 - (cy - crest.y) * 0.0 + (crest.y - (-hh * 1.0)) - hh * 0.12,
      length: hh * 0.15,
      width: hh * 0.025,
      bend: 1,
      midX: -crest.vx * 0.02,
      salt: 50,
    );
    final starX = crest.x, starY = cy - r * 0.95 + (crest.y + hh * 1.0) - hh * 0.12;
    b.layer();
    b.shape(white);
    pen.star(starX, starY - hh * 0.05, 5, hh * 0.085, hh * 0.04, rot: -math.pi / 2 + crest.vx * 0.002, round: 0.3);
    b.brushQuad(
      3,
      starX - hh * 0.03,
      starY - hh * 0.09,
      starX - hh * 0.01,
      starY - hh * 0.105,
      starX + hh * 0.01,
      starY - hh * 0.1,
      b.lw * 0.7,
    );
    b.endLayer();

    // The ball body: ink-black back, one white front (face mask + bib).
    final bc = _c..clear();
    bc.blob(pen, 0, cy, r * 1.04, r, taper: 0.06, samples: 40);
    bc.wobble(b.amp, b.frame, b.seed, 1);
    b.layer();
    b.blob(bc, body, depth: r * 0.25);
    // Shine on the black.
    b.brushQuad(
      2,
      -r * 0.7,
      cy - r * 0.2,
      -r * 0.62,
      cy - r * 0.62,
      -r * 0.3,
      cy - r * 0.84,
      b.lw * 1.4,
      color: c.shine,
      taperIn: 0.4,
      taperOut: 0.4,
    );
    b.endLayer();

    // In a side view the near wing's up-stroke passes behind the face (the
    // face stays readable); the down-stroke sweeps in front of the body.
    final wingUp = tn > 0.3 && wings[1].y < -hh * 0.52;
    if (wingUp) _wing(b, 1, cy);

    // Face geometry: the white heart mask is fitted round the eyes exactly
    // where [Face] puts them, so the pie eyes always sit inside it.
    final faceR = r * 0.8, es = 1.05;
    final fx = r * (0.02 + 0.12 * tn), fy = cy - r * 0.28;
    final ew = faceR * 0.25 * es, eh = faceR * 0.42 * es;
    final ef = fx + tn * faceR * 0.3;
    final sp = ew * 1.1;
    final farX = ef - sp * (1 - 0.3 * tn), nearX = ef + sp;
    final ey = fy + r * 0.02 - 0.1 * faceR;
    b.layer();
    b.shape(white, ink: 0.75);
    pen
      ..ellipse(farX, ey + r * 0.04, ew * (1 - 0.2 * tn) * 2, eh * 1.25)
      ..ellipse(nearX, ey + r * 0.04, ew * 2, eh * 1.25);
    b.shape(white, ink: 0.75);
    pen.ellipse(ef + r * 0.04, ey + r * 0.44, r * 0.46, r * 0.3);
    b.shape(white, ink: 0.75);
    pen.ellipse(fx * 0.7, cy + r * 0.52, r * 0.56 * (1 - 0.12 * tn), r * 0.42);
    b.endLayer();

    _bandana(b, cy, r, ef);

    face
      ..cx = fx
      ..cy = fy + r * 0.02
      ..r = faceR
      ..turn = tn
      ..expression = expression
      ..eyes = RigEyes.pieCut
      ..eyeScale = es
      ..eyeGap = 0.1
      ..eyeY = -0.1
      ..blink = blinkAmount
      ..lookX = lookSpring.x
      ..lookY = (lookSpring.y + (action == RigAction.fall ? 0.7 : 0)).clamp(-1.0, 1.0)
      ..eyeState = switch (action) {
        RigAction.hurt when actionTime < 0.4 => EyeState.squeeze,
        RigAction.defeated => EyeState.cross,
        RigAction.taunt => EyeState.shut,
        _ => EyeState.auto,
      }
      ..spin = time * 6
      ..tremble = expression == RigExpression.scared ? hh * 0.006 : 0
      ..nose = NoseStyle.none
      ..skin = white
      ..drawMouth = false
      ..salt = 300;
    // The face is small on a small bird: ink it with a finer pen so the
    // pie eyes and the beak read instead of drowning in outline.
    final lw0 = b.lw;
    b.lw = lw0 * 0.62;
    face.draw(b);
    _beakDraw(b, ef + r * (0.04 + 0.2 * tn), ey + eh * 1.02, r);
    b.lw = lw0;
    _goggles(b, cy, r);

    // Near wing on top (down-stroke / front view).
    if (!wingUp) _wing(b, 1, cy);
    pen.restore();

    if (emanata) {
      if (expression == RigExpression.dizzy || action == RigAction.defeated) {
        Emanata.dizzyStars(b, 0, cy - r * 1.3, r * 0.9, time);
      }
      if (expression == RigExpression.scared) Emanata.sweat(b, r * 0.9, cy - r * 0.6, hh * 0.06, 1, (time * 1.6) % 1);
      if (action == RigAction.run || (action == RigAction.jump && actionTime < 0.25)) {
        Emanata.speedLines(b, -r * 1.2, cy - r * 0.6, cy + r * 0.8, 1, action == RigAction.run ? 1 : 0.6);
      }
      if (action == RigAction.cheer) Emanata.sparkles(b, 0, cy - r * 0.3, r * 1.6, time);
      if (expression == RigExpression.surprised && expressionTime < 0.9) {
        Emanata.shock(b, 0, cy - r * 0.2, r * 1.05, Bounce.backOut(expressionTime / 0.25));
      }
    }
    b.endLayer();
  }

  void _wing(InkBuild b, int i, double cy) {
    final hh = spec.height;
    final tn = turn;
    final side = i == 0 ? -1.0 : 1.0;
    final rootX = Bounce.lerp(side * hh * 0.22, i == 0 ? -hh * 0.14 : -hh * 0.07, tn);
    final rootY = cy + hh * (i == 0 ? -0.02 : 0.03);
    final w = wings[i];
    final tip = Hose.draw(
      b,
      rootX: rootX,
      rootY: rootY,
      tipX: w.x,
      tipY: w.y + (cy + hh * 0.5),
      length: hh * 0.26,
      width: hh * 0.06,
      bend: side * (w.y < -hh * 0.5 ? -1 : 1),
      midX: -w.vx * 0.012,
      midY: -w.vy * 0.012,
      salt: 60 + i * 3,
    );
    // Feathers fan out along the wing's reach (root → tip), away from the
    // body, so an up-stroke never covers the face.
    final reach = math.atan2(tip.y - rootY, tip.x - rootX);
    final ang = math.atan2(
      0.7 * math.sin(reach) + 0.3 * math.sin(tip.angle),
      0.7 * math.cos(reach) + 0.3 * math.cos(tip.angle),
    );
    _featherGlove(b, tip.x, tip.y, ang, hh * 0.075, i);
  }

  /// A wing "glove": a cuff and four white feathers fanning out.
  void _featherGlove(InkBuild b, double x, double y, double angle, double s, int i) {
    final pen = b.pen
      ..save()
      ..translate(x, y)
      ..rotate(angle)
      ..scale(s);
    final white = b.colors.fill(spec.trim);
    b.layer();
    // Four long leaf-shaped primaries fanning from a cuff.
    for (var k = 0; k < 4; k++) {
      final a = (k - 1.5) * 0.36 + b.j(70 + k + i * 4) * 0.04;
      final len = 1.85 - (k - 1.5).abs() * 0.3;
      final ca = math.cos(a), sa = math.sin(a);
      final tx = 0.3 + ca * len, ty = sa * len;
      final mx = 0.3 + ca * len * 0.5, my = sa * len * 0.5;
      const w = 0.82;
      b.shape(white);
      pen
        ..moveTo(0.3 - sa * 0.2, ca * 0.2)
        ..quadTo(mx - sa * w, my + ca * w, tx, ty)
        ..quadTo(mx + sa * w, my - ca * w, 0.3 + sa * 0.2, -ca * 0.2)
        ..close();
    }
    b.shape(white);
    pen
      ..moveTo(-0.1, -0.42)
      ..lineTo(0.35, -0.6)
      ..quadTo(0.5, 0, 0.35, 0.6)
      ..lineTo(-0.1, 0.42)
      ..quadTo(0, 0, -0.1, -0.42)
      ..close();
    for (var k = 0; k < 4; k++) {
      final a = (k - 1.5) * 0.36;
      final len = 1.85 - (k - 1.5).abs() * 0.3;
      b.brushQuad(
        3,
        0.55 + math.cos(a) * 0.1,
        math.sin(a) * 0.1,
        0.4 + math.cos(a) * len * 0.5,
        math.sin(a) * len * 0.5,
        0.3 + math.cos(a) * len * 0.78,
        math.sin(a) * len * 0.78,
        b.lw * 0.5,
        taperIn: 0.2,
        taperOut: 0.8,
      );
    }
    b.brushQuad(3, 0.22, -0.48, 0.32, 0, 0.22, 0.48, b.lw * 0.7);
    b.endLayer();
    pen.restore();
  }

  /// A leaf / plume from (x0, y0) along [angle], [len] long, [w] wide.
  static void _leaf(InkPen pen, Path into, double x0, double y0, double angle, double len, double w) {
    pen.target(into);
    final ca = math.cos(angle), sa = math.sin(angle);
    final tx = x0 + ca * len, ty = y0 + sa * len;
    final mx = x0 + ca * len * 0.45, my = y0 + sa * len * 0.45;
    pen
      ..moveTo(x0 - sa * w * 0.2, y0 + ca * w * 0.2)
      ..quadTo(mx - sa * w, my + ca * w, tx, ty)
      ..quadTo(mx + sa * w, my - ca * w, x0 + sa * w * 0.2, y0 - ca * w * 0.2)
      ..close();
  }

  /// A short, stubby beak under the eyes (a rounded cone, never a spike),
  /// with a smile crease at its root that follows the expression.
  void _beakDraw(InkBuild b, double x, double y, double r) {
    final pen = b.pen;
    final fill = b.colors.fill(PaletteRole.midtone);
    final open = _beak.clamp(0.0, 1.0);
    final tn = turn;
    final len = r * (0.24 + 0.2 * tn);
    final droop = r * (0.06 + 0.04 * (1 - tn));
    // Lower mandible (drops open), under the upper one.
    b.layer();
    b.shape(fill, ink: 0.85);
    pen
      ..save()
      ..rotateAbout(open * 0.55, x - r * 0.06, y + r * 0.04)
      ..moveTo(x - r * 0.12, y + r * 0.02)
      ..quadTo(x + len * 0.55, y + r * 0.04, x + len * 0.78, y + droop + r * 0.02)
      ..quadTo(x + len * 0.3, y + r * 0.2, x - r * 0.1, y + r * 0.13)
      ..close()
      ..restore();
    if (open > 0.15) {
      b.fill(b.colors.dark);
      pen
        ..moveTo(x - r * 0.06, y + r * 0.03)
        ..quadTo(x + len * 0.3, y + r * 0.03 + open * r * 0.2, x + len * 0.62, y + r * 0.03 + open * r * 0.16)
        ..lineTo(x + len * 0.62, y + r * 0.03)
        ..close();
    }
    b.endLayer();
    // Upper mandible: plump, rounded at the tip, a nostril and a shine.
    b.layer();
    b.shape(fill, ink: 0.85);
    pen
      ..moveTo(x - r * 0.16, y - r * 0.1)
      ..cubicTo(x + len * 0.3, y - r * 0.22, x + len * 1.02, y - r * 0.08, x + len, y + droop)
      ..quadTo(x + len * 0.9, y + droop + r * 0.07, x + len * 0.6, y + r * 0.07)
      ..quadTo(x + len * 0.2, y + r * 0.09, x - r * 0.15, y + r * 0.06)
      ..close();
    b.inkFill();
    pen.ellipse(x + len * 0.28, y - r * 0.06, r * 0.03, r * 0.022);
    b.brushQuad(
      3,
      x + len * 0.05,
      y - r * 0.11,
      x + len * 0.4,
      y - r * 0.15,
      x + len * 0.72,
      y - r * 0.06,
      b.lw * 0.7,
      color: b.colors.shine,
    );
    // Smile crease at the root of the beak.
    final up = switch (expression) {
      RigExpression.angry || RigExpression.scared || RigExpression.dizzy => -1.0,
      RigExpression.surprised => 0.0,
      _ => 1.0,
    };
    if (up != 0) {
      b.brushQuad(
        3,
        x - r * 0.1,
        y + r * 0.07,
        x - r * 0.2,
        y + r * (0.07 + 0.02 * up),
        x - r * 0.27,
        y + r * (0.07 - 0.07 * up),
        b.lw * 0.8,
        taperIn: 0.2,
        taperOut: 0.7,
      );
    }
    b.endLayer();
  }

  /// Aviator goggles pushed up on the crown, their strap round the head.
  void _goggles(InkBuild b, double cy, double r) {
    final pen = b.pen;
    final rim = b.colors.fill(PaletteRole.midtone);
    final tn = turn;
    final lx = r * (0.04 + 0.26 * tn);
    b.layer();
    b.shape(rim, ink: 0.7);
    pen
      ..moveTo(-r * 0.78, cy - r * 0.62)
      ..quadTo(lx - r * 0.1, cy - r * 1.1, r * 0.8, cy - r * 0.6)
      ..lineTo(r * 0.76, cy - r * 0.5)
      ..quadTo(lx - r * 0.1, cy - r * 0.97, -r * 0.74, cy - r * 0.51)
      ..close();
    for (var i = 0; i < 2; i++) {
      final far = i == 0;
      final gx = lx + (far ? -r * 0.19 * (1 - 0.35 * tn) : r * 0.19);
      final gy = cy - r * (far ? 0.95 : 0.93);
      final gr = r * (far ? 0.14 * (1 - 0.2 * tn) : 0.15);
      b.shape(rim, ink: 0.8);
      pen.circle(gx, gy, gr);
      b.fill(b.colors.glass);
      pen.circle(gx, gy, gr * 0.62);
      b.fill(b.colors.shine);
      pen.ellipse(gx - gr * 0.2, gy - gr * 0.22, gr * 0.2, gr * 0.14);
    }
    b.endLayer();
  }

  /// The polka-dot bandana: collar under the chin, a flap on the bib and a
  /// knot at the back of the neck (the tails are drawn behind the body).
  void _bandana(InkBuild b, double cy, double r, double ef) {
    final pen = b.pen;
    final fill = _bandanaFill(b);
    final dot = _bandanaWhite ? b.colors.ink : b.colors.fill(spec.trim);
    final by = cy + spec.height * 0.5;
    b.layer();
    // Collar: dips under the chin and rises to the back of the neck.
    b.shape(fill, ink: 0.85);
    pen
      ..moveTo(-r * 1.02, cy + r * 0.02)
      ..quadTo(ef - r * 0.1, cy + r * 0.56, r * 0.98, cy + r * 0.24)
      ..lineTo(r * 0.93, cy + r * 0.38)
      ..quadTo(ef - r * 0.1, cy + r * 0.74, -r * 1.0, cy + r * 0.17)
      ..close();
    // Flap on the bib.
    final fx = ef + r * 0.02, fy = cy + r * 0.4;
    final sw = math.sin(time * 5) * r * 0.03 + squashAmount * r * 0.1;
    b.shape(fill, ink: 0.85);
    pen
      ..moveTo(fx - r * 0.28, fy - r * 0.02)
      ..quadTo(fx - r * 0.18, fy + r * 0.26, fx + sw, fy + r * 0.44)
      ..quadTo(fx + r * 0.2, fy + r * 0.22, fx + r * 0.3, fy - r * 0.04)
      ..close();
    // Knot at the back of the neck.
    b.shape(fill, ink: 0.85);
    pen.ellipse(knotX, knotY + by, r * 0.13, r * 0.11, -0.4);
    // Polka dots.
    b.fill(dot);
    pen
      ..circle(fx - r * 0.1, fy + r * 0.08, r * 0.045)
      ..circle(fx + r * 0.1, fy + r * 0.07, r * 0.045)
      ..circle(fx + r * 0.01, fy + r * 0.24, r * 0.04)
      ..circle(ef - r * 0.45, cy + r * 0.36, r * 0.04)
      ..circle(ef + r * 0.52, cy + r * 0.34, r * 0.04)
      ..circle(knotX + r * 0.02, knotY + by - r * 0.01, r * 0.035);
    b.endLayer();
  }

  final Float64List _rib = Float64List(2 * 8);
  bool _bandanaWhite = false;

  /// The bandana is the accent colour (red in Technicolor); where the
  /// era's accent is too dark to read on a black bird (1930s B&W) it turns
  /// white with ink polka dots.
  Color _bandanaFill(InkBuild b) {
    final accent = b.colors.fill(spec.accent);
    _bandanaWhite = accent.computeLuminance() < 0.1;
    return _bandanaWhite ? b.colors.fill(spec.trim) : accent;
  }

  /// Two swallow-tailed bandana tails following the rope of springs.
  void _bandanaTails(InkBuild b, double cy) {
    final pen = b.pen;
    final hh = spec.height;
    final fill = _bandanaFill(b);
    final by = cy + hh * 0.5;
    final m = scarf.length + 1;
    b.layer();
    for (var t = 0; t < 2; t++) {
      final k = t == 0 ? 1.0 : 0.78;
      final drop = t == 0 ? 0.0 : hh * 0.018;
      _rib[0] = knotX;
      _rib[1] = knotY + by;
      for (var i = 0; i < scarf.length; i++) {
        _rib[2 + i * 2] = knotX + (scarf[i].x - knotX) * k;
        _rib[3 + i * 2] = knotY + by + (scarf[i].y - knotY) * k + drop * (i + 1);
      }
      b.shape(fill, ink: 0.85);
      // Upper edge out, swallowtail notch, lower edge back.
      for (var pass = 0; pass < 2; pass++) {
        final side = pass == 0 ? 1.0 : -1.0;
        for (var n = 0; n < m; n++) {
          final i = pass == 0 ? n : m - 1 - n;
          final a = math.max(0, i - 1), c = math.min(m - 1, i + 1);
          var tx = _rib[c * 2] - _rib[a * 2], ty = _rib[c * 2 + 1] - _rib[a * 2 + 1];
          final tl = math.max(1e-6, math.sqrt(tx * tx + ty * ty));
          tx /= tl;
          ty /= tl;
          final w = hh * (0.024 + 0.004 * i / (m - 1)) * side;
          final px = _rib[i * 2] - ty * w, py = _rib[i * 2 + 1] + tx * w;
          if (pass == 0 && n == 0) {
            pen.moveTo(px, py);
          } else {
            pen.lineTo(px, py);
          }
          if (pass == 0 && i == m - 1) {
            pen.lineTo(_rib[i * 2] - tx * hh * 0.03, _rib[i * 2 + 1] - ty * hh * 0.03);
          }
        }
      }
      pen.close();
    }
    b.endLayer();
  }

  void _looseFeathers(InkBuild b) {
    final pen = b.pen;
    final hh = spec.height;
    for (var i = 0; i < 3; i++) {
      final k = i * 6;
      final age = _feathers[k];
      if (age > 1.5) continue;
      final x = _feathers[k + 1], y = _feathers[k + 2], a = _feathers[k + 5];
      final s = hh * 0.07 * (1 - age / 1.6);
      b.layer();
      b.shape(b.colors.fill(spec.fill), ink: 0.6);
      pen.capsule(
        x - math.cos(a) * s,
        y - math.sin(a) * s,
        x + math.cos(a) * s,
        y + math.sin(a) * s,
        s * 0.2,
        s * 0.35,
      );
      b.endLayer();
    }
  }
}

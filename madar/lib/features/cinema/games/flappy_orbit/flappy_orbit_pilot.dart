import 'dart:math' as math;
import 'dart:ui';

import '../../engine/cinema_engine.dart';
import '../../engine/rig/rig_kit.dart';

/// **Falak** (فَلَك, "orbit") – the hero of *Flappy Orbit*. An original
/// rubber-hose design: a little pilot whose head is a brass astrolabe (a
/// graduated disc with a turning star-pointer ring and a suspension loop on
/// the crown), pie-cut eyes and a button mouth drawn on its face, a scarf
/// streaming from the neck, hose arms on the handlebars, hose legs dangling
/// either side of a rickety one-man rocket-kite: a riveted tin cigar with a
/// porthole, diamond kite fins at the tail, a bunting ribbon tail on a rope
/// of springs, a wind-up key that spins as it burns, and a sputtering
/// exhaust flame.
///
/// Origin: bottom centre under the rocket; the rocket's axis is at
/// [axisY] above it. Actions: [RigAction.idle] = on the pad, winding the
/// key; [RigAction.jump] = one boost (every tap); [RigAction.fall] = nose
/// down; [RigAction.run] = full burn (launch); [RigAction.hurt] = a knock;
/// [RigAction.cheer] = the loop-the-loop pose; [RigAction.defeated] =
/// sputtering tumble. [pitch] (radians, + = nose down) can be driven from
/// the vertical speed; by default it follows the action and [velocity].
class OrbitPilot extends HoseRig {
  OrbitPilot({double height = 84, int seed = 0})
    : super(
        RigSpec(
          id: 'falak',
          body: RigBody.bean,
          height: height,
          fill: PaletteRole.paper,
          trim: PaletteRole.paper,
          accent: PaletteRole.accent,
          limbWidth: 0.07,
          bounciness: 1.2,
          seed: seed,
        ),
      ) {
    final hh = height;
    for (final s in hands) {
      s.snap(hh * 0.2, axisY - hh * 0.24);
    }
    for (var i = 0; i < 2; i++) {
      feet[i].snap(-hh * 0.02, axisY + hh * 0.08);
    }
    for (var i = 0; i < tail.length; i++) {
      tail[i].snap(-hh * (0.62 + 0.09 * (i + 1)), axisY + hh * 0.02 * (i + 1));
    }
    for (var i = 0; i < scarf.length; i++) {
      scarf[i].snap(-hh * 0.1 - hh * 0.08 * (i + 1), axisY - hh * 0.48 + hh * 0.02 * (i + 1));
    }
  }

  /// The rocket's axis (design space) above the origin.
  double get axisY => -spec.height * 0.5;

  /// Nose-down pitch override (radians); `null` = pose-driven.
  double? pitch;

  /// Exhaust 0..1 (eased toward the action's burn).
  double thrust = 0;

  /// Winding the key on the pad (idle only).
  bool winding = true;

  final Spring1 _pitch = Spring1();
  final Spring1 _lean = Spring1();
  final Spring2 _torso = Spring2();
  final Spring1 _loop = Spring1();
  final List<Spring2> hands = [Spring2(), Spring2()];
  final List<Spring2> feet = [Spring2(), Spring2()];
  final List<Spring2> tail = [for (var i = 0; i < 5; i++) Spring2()];
  final List<Spring2> scarf = [for (var i = 0; i < 3; i++) Spring2()];
  final List<HandShape> _handShape = [HandShape.grip, HandShape.grip];
  final Face face = Face();
  late final Contour _c = Contour(64);

  double keySpin = 0;
  double reteSpin = 0;
  double _crank = 0;
  double _spin = 0;
  double _sputter = 0;
  double _mouthOpen = 0;

  double get u => spec.height / 100;

  @override
  void onAction(RigAction action, RigAction previous) {
    super.onAction(action, previous);
    switch (action) {
      case RigAction.jump:
        _loop.kick(spec.height * 1.6);
        _torso.kick(-spec.height * 0.4, spec.height * 0.5);
      case RigAction.hurt:
        _loop.kick(-spec.height * 2.4);
        _torso.kick(spec.height * 0.6, -spec.height * 0.3);
      case RigAction.run:
        _torso.kick(-spec.height * 0.8, 0);
      default:
    }
  }

  @override
  double oneShotLength(RigAction action) => switch (action) {
    RigAction.jump => 0,
    RigAction.cheer => 0,
    RigAction.hurt => 0.55,
    _ => super.oneShotLength(action),
  };

  @override
  bool get fastAction => action != RigAction.idle || actionTime < 0.3 || squashSpring.velocity.abs() > 1.2;

  @override
  void animate(double h) {
    final hh = spec.height, uu = u;
    final t = actionTime;
    var burn = 0.0, lean = 0.1, tp = 0.0, mouth = talkLevel;
    var legSwing = 1.0;
    final onPad = action == RigAction.idle && winding;
    switch (action) {
      case RigAction.idle:
        burn = onPad ? 0.0 : 0.35;
        lean = onPad ? 0.25 : 0.05;
        tp = 0;
        legSwing = onPad ? 0.2 : 0.8;
      case RigAction.walk:
        burn = 0.4;
      case RigAction.jump:
        burn = t < 0.3 ? 1 : 0.45;
        lean = -0.3;
        tp = t < 0.22 ? -0.42 : -0.12;
        mouth = t < 0.3 ? 0.7 : 0.2;
      case RigAction.fall:
        burn = 0.18;
        lean = 0.32;
        tp = 0.42;
        mouth = 0.5;
      case RigAction.run:
        burn = 1;
        lean = -0.4;
        tp = -0.05;
        mouth = 0.6;
      case RigAction.land:
        burn = 0.3;
        lean = 0.1;
      case RigAction.hurt:
        burn = 0;
        lean = 0.5;
        tp = -0.5 + t * 0.6;
        mouth = 0.9;
      case RigAction.attack:
        burn = 1;
        lean = -0.2;
      case RigAction.cheer:
        burn = 1;
        lean = -0.35;
        mouth = 0.8;
      case RigAction.taunt:
        burn = 0.4;
        lean = -0.15;
        mouth = 0.5;
      case RigAction.talk:
        burn = 0.35;
        mouth = math.max(talkLevel, (math.sin(time * 18) * 0.5 + 0.5) * (math.sin(time * 5) * 0.3 + 0.7));
      case RigAction.defeated:
        _sputter += h;
        burn = (math.sin(_sputter * 26) > 0.55 ? 0.55 : 0.0) * math.max(0.0, 1 - t / 2.2);
        lean = 0.65;
        tp = 0;
        legSwing = 1.4;
    }
    thrust += (burn - thrust) * math.min(1, h * (burn > thrust ? 26 : 9));
    _mouthOpen += (mouth - _mouthOpen) * math.min(1, h * 18);
    _lean.step(h, lean, 18, 0.5);
    _torso.step(h, 0, 0, 24, 0.42);
    _loop.step(h, 0, 20, 0.3);
    // The key spins with the burn (and with the crank on the pad); the
    // astrolabe's star ring turns slowly, racing when dizzy.
    if (onPad) {
      _crank += h * 7;
      keySpin = _crank * 0.5;
    } else {
      keySpin += h * (2.5 + thrust * 16);
    }
    reteSpin += h * (expression == RigExpression.dizzy || action == RigAction.defeated ? 7 : 0.7);
    // Tumble when defeated.
    if (action == RigAction.defeated) {
      _spin += h * math.max(0.4, 3.2 - t * 0.9);
    } else {
      _spin = 0;
    }
    // Pitch follows the pose and the climb / dive when the game feeds a
    // velocity.
    final vPitch = velocity == Offset.zero ? 0.0 : (velocity.dy / (hh * 10)).clamp(-0.45, 0.65);
    _pitch.step(h, pitch ?? tp + vPitch, 13, 0.6);

    // Hands: both on the handlebars in flight; on the pad the near hand
    // cranks the key at the tail.
    final barX = hh * 0.2, barY = axisY - hh * 0.25;
    for (var i = 0; i < 2; i++) {
      var tx = barX + (i == 0 ? -hh * 0.04 : hh * 0.02), ty = barY + (i == 0 ? hh * 0.02 : 0);
      _handShape[i] = HandShape.grip;
      if (onPad && i == 1) {
        final kx = -hh * 0.72, ky = axisY + hh * 0.12;
        tx = kx + math.cos(_crank) * hh * 0.11;
        ty = ky + math.sin(_crank) * hh * 0.11;
        _handShape[i] = HandShape.fist;
      } else if (action == RigAction.cheer && i == 1) {
        tx = hh * 0.02 + math.sin(time * 9) * hh * 0.05;
        ty = axisY - hh * 0.9;
        _handShape[i] = HandShape.wave;
      } else if (action == RigAction.hurt && i == 1) {
        tx = -hh * 0.1;
        ty = axisY - hh * 0.75;
        _handShape[i] = HandShape.open;
      } else if (action == RigAction.defeated) {
        tx = -hh * 0.05 + i * hh * 0.1;
        ty = axisY - hh * 0.05;
        _handShape[i] = HandShape.open;
      }
      hands[i].step(h, tx, ty, 30, 0.45);
    }
    // Feet dangle either side of the rocket, swinging with the ride.
    for (var i = 0; i < 2; i++) {
      final side = i == 0 ? -1.0 : 1.0;
      final swing = math.sin(time * 6.5 + i * 1.9) * 4 * uu * legSwing;
      final tx = -hh * 0.02 + side * hh * 0.03 + swing - _pitch.value * hh * 0.1;
      final ty = axisY + hh * (onPad ? 0.02 : 0.1) + math.cos(time * 6.5 + i) * 2 * uu * legSwing;
      feet[i].step(h, tx, ty, 20, 0.35);
    }
    // The bunting tail streams from the exhaust nozzle; the scarf from the
    // neck. Each link rides a spring but is tethered like a rope.
    final wind = 0.5 + thrust * 0.9 + (speed.abs() / hh).clamp(0.0, 3.0) * 0.3;
    _rope(tail, -hh * 0.64, axisY + hh * 0.04, hh * 0.1, wind, h, 11, 1.0);
    _rope(scarf, -hh * 0.06, axisY - hh * 0.5, hh * 0.085, wind * 0.9, h, 13, 0.6);
  }

  void _rope(List<Spring2> links, double rx, double ry, double seg, double wind, double h, double salt, double droopK) {
    var px = rx, py = ry;
    final droop = (1.3 - wind).clamp(0.0, 1.0) * droopK;
    for (var i = 0; i < links.length; i++) {
      final c = links[i];
      final flutter = math.sin(time * salt - i * 1.4) * seg * 0.35 * (i + 1) / links.length;
      c.step(h, px - seg * (0.45 + 0.55 * math.min(1, wind)), py + seg * droop + flutter, 30 - i * 3.0, 0.4);
      final dx = c.x - px, dy = c.y - py;
      final d = math.sqrt(dx * dx + dy * dy);
      if (d > seg) {
        c.x = px + dx / d * seg;
        c.y = py + dy / d * seg;
      }
      px = c.x;
      py = c.y;
    }
  }

  @override
  void build(RigPaintContext ctx) {
    final b = ink;
    final hh = spec.height;
    b.begin(ctx, size: hh, boilFrame: boilFrame);
    final c = b.colors;
    final pen = b.pen;
    final tn = turn;
    final ay = axisY;
    final tin = _mix(c.fill(PaletteRole.midtone), c.fill(PaletteRole.paper), 0.42);
    final dark = c.fill(PaletteRole.shadow);
    final brass = _mix(c.fill(PaletteRole.midtone), c.fill(PaletteRole.highlight), 0.35);
    final paper = c.fill(PaletteRole.paper);
    final s = squashAmount;
    final sy = (1 - s).clamp(0.7, 1.35), sx = 1 / sy;
    pen
      ..reset()
      ..translate(0, ay)
      ..scale(sx, sy)
      ..translate(0, -ay)
      ..scale(dir, 1);
    setBounds(-hh * 1.1, -hh * 1.28, hh * 0.75, hh * 0.12);
    b.shadeAcross(Rect.fromLTWH(-hh * 0.6, -hh * 1.1, hh * 1.2, hh * 1.2));
    final r = hh * 0.17; // rocket radius
    final rot = _pitch.value + _spin;
    pen
      ..save()
      ..rotateAbout(rot, 0, ay);

    // Behind everything: the ribbon tail, the exhaust, the far leg and arm.
    _bunting(b, c);
    _flame(b, c, ay, r);
    if (emanata && thrust > 0.6 && action != RigAction.defeated) {
      Emanata.speedLines(b, -hh * 0.75, ay - r * 0.8, ay + r * 0.9, 1, (thrust - 0.6) * 2.2);
    }
    final hipX = -hh * 0.08, hipY = ay - r - hh * 0.02;
    _leg(b, 0, hipX, hipY, dark, paper);
    _scarf(b, c);
    _arm(b, 0, hipX, hipY, paper);

    // The rocket: a riveted tin cigar with a nose cone, kite fins, a
    // porthole, a stripe and the wind-up key.
    b.layer();
    // Fins (diamond kites) above and below the tail.
    for (final side in const [-1.0, 1.0]) {
      b.shape(paper, ink: 0.9);
      pen
        ..moveTo(-hh * 0.3, ay + side * r * 0.8)
        ..lineTo(-hh * 0.58, ay + side * (r + hh * 0.24) + b.ja(60, 0.5))
        ..lineTo(-hh * 0.7, ay + side * r * 0.9)
        ..close();
      b.inkLine(b.lw * 0.5);
      pen
        ..moveTo(-hh * 0.34, ay + side * r * 0.85)
        ..lineTo(-hh * 0.6, ay + side * (r + hh * 0.2));
    }
    // Body.
    final body = _c..clear();
    body.ellipse(pen, -hh * 0.05, ay, hh * 0.56, r, samples: 36);
    body.wobble(b.amp * 0.7, b.frame, b.seed, 2);
    b.blob(body, tin, depth: r * 0.42, threshold: 0.2);
    // Nose cone.
    b.shape(dark);
    pen
      ..moveTo(hh * 0.4, ay - r * 0.78)
      ..quadTo(hh * 0.62, ay - r * 0.3, hh * 0.68, ay)
      ..quadTo(hh * 0.62, ay + r * 0.3, hh * 0.4, ay + r * 0.78)
      ..close();
    // Nozzle cup at the tail.
    b.shape(dark);
    pen
      ..moveTo(-hh * 0.56, ay - r * 0.5)
      ..lineTo(-hh * 0.66, ay - r * 0.62)
      ..lineTo(-hh * 0.66, ay + r * 0.62)
      ..lineTo(-hh * 0.56, ay + r * 0.5)
      ..close();
    // Stripe behind the cone and a porthole.
    b.fill(dark);
    pen.roundRect(hh * 0.3, ay - r * 0.92, hh * 0.36, ay + r * 0.92, hh * 0.01);
    b.shape(brass, ink: 0.8);
    pen.circle(hh * 0.16, ay - r * 0.1, r * 0.4);
    b.fill(c.glass);
    pen.circle(hh * 0.16, ay - r * 0.1, r * 0.26);
    b.fill(c.shine);
    pen.ellipse(hh * 0.13, ay - r * 0.2, r * 0.08, r * 0.05, -0.6);
    // Rivets along the seam.
    for (var i = 0; i < 4; i++) {
      Mechanics.rivet(b, -hh * 0.44 + i * hh * 0.17, ay + r * 0.55, hh * 0.016);
    }
    // Shine along the top.
    b.brushQuad(2, -hh * 0.4, ay - r * 0.62, -hh * 0.05, ay - r * 0.82, hh * 0.25, ay - r * 0.66, b.lw * 1.2, color: c.shine, taperIn: 0.3, taperOut: 0.3);
    b.endLayer();
    // The wind-up key under the tail.
    Mechanics.windKey(b, -hh * 0.46, ay + r * 0.95, hh * 0.1, keySpin, fill: brass);
    // Handlebars.
    b.layer();
    b.inkLine(b.lw * 0.9);
    pen
      ..moveTo(hh * 0.12, ay - r * 0.9)
      ..quadTo(hh * 0.16, ay - r - hh * 0.14, hh * 0.24, ay - r - hh * 0.22);
    b.endLayer();

    // The pilot: torso leaning on its spring, head, scarf.
    final lean = _lean.value;
    final tx = hipX + _torso.x * 0.02, ty = hipY + _torso.y * 0.02;
    pen
      ..save()
      ..translate(tx, ty)
      ..rotate(lean);
    final torso = _c..clear();
    torso.blob(pen, hh * 0.02, -hh * 0.17, hh * 0.13, hh * 0.18, taper: 0.22, bend: 0.1, samples: 28);
    torso.wobble(b.amp, b.frame, b.seed, 5);
    b.layer();
    b.blob(torso, c.fill(spec.accent), depth: hh * 0.05, threshold: 0.25);
    // Jacket buttons and a collar.
    b.fill(paper);
    pen
      ..circle(hh * 0.07, -hh * 0.2, hh * 0.013)
      ..circle(hh * 0.065, -hh * 0.13, hh * 0.013);
    b.shape(paper, ink: 0.7);
    pen
      ..moveTo(-hh * 0.06, -hh * 0.31)
      ..lineTo(hh * 0.02, -hh * 0.25)
      ..lineTo(hh * 0.1, -hh * 0.32)
      ..close();
    b.endLayer();
    // Head: the astrolabe.
    final hx = hh * 0.06 + hh * 0.04 * tn, hy = -hh * 0.5 + _loop.value * 0.004;
    _astrolabe(b, c, hx, hy, hh * 0.21, brass, paper);
    pen.restore();

    // Near leg and arm in front of the rocket.
    _leg(b, 1, hipX, hipY, dark, paper);
    _arm(b, 1, hipX, hipY, paper);
    pen.restore();

    if (emanata) {
      final cx = hipX, top = ay - hh * 0.95;
      if (expression == RigExpression.dizzy || action == RigAction.defeated) {
        Emanata.dizzyStars(b, cx, top - hh * 0.05, hh * 0.3, time);
      }
      if (expression == RigExpression.scared) Emanata.sweat(b, cx + hh * 0.3, top + hh * 0.2, hh * 0.06, 1, (time * 1.6) % 1);
      if (action == RigAction.hurt && actionTime < 0.25) Emanata.impact(b, hh * 0.1, ay, hh * 0.5);
      if (action == RigAction.hurt) Mechanics.sparks(b, -hh * 0.6, ay + r * 0.5, hh * 0.07, 70 + (actionTime * 20).floor());
      if (action == RigAction.cheer) Emanata.sparkles(b, cx, top + hh * 0.1, hh * 0.6, time);
      if (expression == RigExpression.surprised && expressionTime < 0.9) {
        Emanata.shock(b, cx, top + hh * 0.2, hh * 0.3, Bounce.backOut(expressionTime / 0.25));
      }
      if (action == RigAction.idle && winding && ((time * 0.5) % 3) < 1) {
        Emanata.note(b, cx + hh * 0.3, top + hh * 0.1, hh * 0.08, (time * 0.5) % 1);
      }
    }
    b.endLayer();
  }

  /// A hose arm from the shoulder to the hand with a glove.
  void _arm(InkBuild b, int i, double hipX, double hipY, Color glove) {
    final hh = spec.height;
    final lean = _lean.value;
    final sx = hipX + hh * 0.02 + (i == 0 ? -hh * 0.05 : hh * 0.05), sy = hipY - hh * 0.3;
    // Shoulder rotates with the torso lean about the hip.
    final rx = hipX + (sx - hipX) * math.cos(lean) - (sy - hipY) * math.sin(lean);
    final ry = hipY + (sx - hipX) * math.sin(lean) + (sy - hipY) * math.cos(lean);
    final hs = hands[i];
    final tip = Hose.draw(
      b,
      rootX: rx,
      rootY: ry,
      tipX: hs.x,
      tipY: hs.y,
      length: hh * 0.34,
      width: hh * spec.limbWidth,
      bend: i == 0 ? -1 : 1,
      midX: (-hs.vx * 0.015).clamp(-hh * 0.1, hh * 0.1),
      midY: (-hs.vy * 0.015).clamp(-hh * 0.1, hh * 0.1),
      salt: 10 + i * 4,
    );
    Extremities.glove(
      b,
      x: tip.x,
      y: tip.y,
      angle: tip.angle,
      size: hh * 0.07,
      fill: glove,
      shape: handOverride(i) ?? _handShape[i],
      thumb: Extremities.thumbFront(tip.angle) * (i == 0 ? -1 : 1),
      salt: 20 + i * 8,
    );
  }

  /// A hose leg dangling from the hip with a shoe.
  void _leg(InkBuild b, int i, double hipX, double hipY, Color shoe, Color spat) {
    final hh = spec.height;
    final f = feet[i];
    Hose.draw(
      b,
      rootX: hipX + (i == 0 ? -hh * 0.03 : hh * 0.03),
      rootY: hipY + hh * 0.02,
      tipX: f.x,
      tipY: f.y,
      length: hh * 0.3,
      width: hh * spec.limbWidth * 1.05,
      bend: i == 0 ? 1 : -1,
      midX: (-f.vx * 0.012).clamp(-hh * 0.08, hh * 0.08),
      salt: 30 + i * 4,
    );
    Extremities.shoe(b, x: f.x, y: f.y, size: hh * 0.07, fill: shoe, pitch: 0.25 + _pitch.value * 0.3, salt: 40 + i * 4, spat: spat);
  }

  /// The brass astrolabe head: the mater disc with a graduated rim, the
  /// turning rete (a star-pointer ring), the face, and the suspension loop
  /// on the crown bobbing on its spring.
  void _astrolabe(InkBuild b, InkColors c, double x, double y, double r, Color brass, Color paper) {
    final pen = b.pen;
    final tn = turn;
    // Suspension loop (the "throne") on a short neck of brass.
    final loopY = y - r - r * 0.28 + _loop.value * 0.01;
    b.layer();
    b.shape(brass, ink: 0.9);
    pen.roundRect(x - r * 0.14, y - r - r * 0.1, x + r * 0.14, y - r + r * 0.12, r * 0.03);
    b.shape(brass, ink: 0.9);
    pen.circle(x, loopY, r * 0.3);
    b.shape(paper, ink: 0.8);
    pen.circle(x, loopY, r * 0.13);
    // A little ribbon through the loop.
    b.shape(c.fill(spec.accent), ink: 0.7);
    pen
      ..moveTo(x + r * 0.2, loopY - r * 0.05)
      ..quadTo(x + r * 0.5 + _loop.value * 0.003, loopY - r * 0.4, x + r * 0.62, loopY - r * 0.1 + b.ja(80, 0.6))
      ..quadTo(x + r * 0.45, loopY + r * 0.1, x + r * 0.26, loopY + r * 0.12)
      ..close();
    b.endLayer();
    // The disc.
    final disc = _c..clear();
    disc.ellipse(pen, x, y, r * (1 - 0.06 * tn), r, samples: 36);
    disc.wobble(b.amp * 0.6, b.frame, b.seed, 7);
    b.layer();
    b.blob(disc, paper, depth: r * 0.3, threshold: 0.3);
    // Graduated rim: a ring with ticks.
    b.inkLine(b.lw * 0.55);
    pen.ellipse(x, y, r * 0.84 * (1 - 0.06 * tn), r * 0.84);
    for (var i = 0; i < 16; i++) {
      final a = i * math.pi * 2 / 16;
      final long = i % 4 == 0;
      final r0 = r * (long ? 0.84 : 0.9), r1 = r * 0.99;
      pen
        ..moveTo(x + math.cos(a) * r0 * (1 - 0.06 * tn), y + math.sin(a) * r0)
        ..lineTo(x + math.cos(a) * r1 * (1 - 0.06 * tn), y + math.sin(a) * r1);
    }
    // The rete: a thin ring with three star pointers, turning.
    b.inkLine(b.lw * 0.45);
    final rr = r * 0.76;
    pen.ellipse(x + r * 0.02, y + r * 0.04, rr * (1 - 0.06 * tn), rr);
    for (var i = 0; i < 3; i++) {
      final a = reteSpin + i * math.pi * 2 / 3;
      final px = x + r * 0.02 + math.cos(a) * rr * (1 - 0.06 * tn), py = y + r * 0.04 + math.sin(a) * rr;
      final qx = x + r * 0.02 + math.cos(a) * rr * 0.62 * (1 - 0.06 * tn), qy = y + r * 0.04 + math.sin(a) * rr * 0.62;
      pen
        ..moveTo(px, py)
        ..lineTo(qx, qy);
      b.inkFill();
      pen.star(qx, qy, 4, r * 0.07, r * 0.025, rot: a);
      b.inkLine(b.lw * 0.45);
    }
    b.endLayer();
    // Face on the disc.
    face
      ..cx = x
      ..cy = y
      ..r = r * 0.92
      ..turn = tn
      ..expression = expression
      ..eyes = RigEyes.pieCut
      ..eyeScale = 1.05
      ..eyeGap = 0.2
      ..eyeY = -0.08
      ..blink = blinkAmount
      ..lookX = lookSpring.x
      ..lookY = (lookSpring.y + (action == RigAction.fall ? 0.6 : action == RigAction.jump ? -0.3 : 0)).clamp(-1.0, 1.0)
      ..eyeState = switch (action) {
        RigAction.hurt when actionTime < 0.35 => EyeState.squeeze,
        RigAction.defeated => EyeState.cross,
        _ => EyeState.auto,
      }
      ..spin = time * 6
      ..tremble = expression == RigExpression.scared ? spec.height * 0.006 : 0
      ..nose = NoseStyle.button
      ..noseScale = 0.8
      ..noseColor = brass
      ..skin = paper
      ..mouth = switch (action) {
        RigAction.defeated => MouthShape.tongue,
        RigAction.hurt => MouthShape.grimace,
        RigAction.cheer => MouthShape.grin,
        _ => MouthShape.auto,
      }
      ..mouthOpen = _mouthOpen
      ..mouthY = 0.5
      ..mouthW = 0.7
      ..salt = 300;
    final lw0 = b.lw;
    b.lw = lw0 * 0.7;
    face.draw(b);
    b.lw = lw0;
  }

  /// The pilot's scarf streaming back from the neck.
  void _scarf(InkBuild b, InkColors c) {
    final pen = b.pen;
    final hh = spec.height;
    // A white silk aviator's scarf (it reads against the dark jacket).
    final fill = c.fill(spec.trim);
    b.layer();
    b.shape(fill, ink: 0.8);
    final px = -hh * 0.06, py = axisY - hh * 0.5;
    pen.moveTo(px, py - hh * 0.03);
    for (var i = 0; i < scarf.length; i++) {
      pen.lineTo(scarf[i].x, scarf[i].y - hh * 0.03 * (1 - i / scarf.length));
    }
    pen.lineTo(scarf.last.x - hh * 0.03, scarf.last.y + hh * 0.02);
    for (var i = scarf.length - 1; i >= 0; i--) {
      pen.lineTo(scarf[i].x, scarf[i].y + hh * 0.035);
    }
    pen
      ..lineTo(px, py + hh * 0.035)
      ..close();
    b.endLayer();
  }

  /// The bunting ribbon tail: a string from the nozzle with little flags.
  void _bunting(InkBuild b, InkColors c) {
    final pen = b.pen;
    final hh = spec.height;
    b.layer();
    b.inkLine(b.lw * 0.5);
    final px = -hh * 0.64, py = axisY + hh * 0.04;
    pen.moveTo(px, py);
    for (final l in tail) {
      pen.lineTo(l.x, l.y);
    }
    for (var i = 0; i < tail.length; i++) {
      final l = tail[i];
      final ax = i == 0 ? px : tail[i - 1].x, ay = i == 0 ? py : tail[i - 1].y;
      final mx = (ax + l.x) / 2, my = (ay + l.y) / 2;
      var dx = l.x - ax, dy = l.y - ay;
      final d = math.max(1e-6, math.sqrt(dx * dx + dy * dy));
      dx /= d;
      dy /= d;
      final fl = hh * 0.07;
      b.shape(i.isEven ? c.fill(spec.accent) : c.fill(PaletteRole.paper), ink: 0.7);
      pen
        ..moveTo(mx - dx * fl * 0.5, my - dy * fl * 0.5)
        ..lineTo(mx + dx * fl * 0.5, my + dy * fl * 0.5)
        ..lineTo(mx - dy * fl * 1.1 + dx * fl * 0.05, my + dx * fl * 1.1 + dy * fl * 0.05)
        ..close();
    }
    b.endLayer();
  }

  /// The exhaust flame behind the nozzle, sized by [thrust].
  void _flame(InkBuild b, InkColors c, double ay, double r) {
    if (thrust < 0.04) return;
    final pen = b.pen;
    final hh = spec.height;
    final len = hh * (0.12 + 0.5 * thrust) * (1 + 0.1 * b.j(90));
    final w = r * (0.5 + 0.35 * thrust);
    final x0 = -hh * 0.66;
    b.layer();
    b.shape(c.hot, ink: 0.7);
    pen
      ..moveTo(x0, ay - w)
      ..quadTo(x0 - len * 0.55, ay - w * 0.9 + b.ja(91, 1.5), x0 - len, ay + b.ja(92, 1.2))
      ..quadTo(x0 - len * 0.55, ay + w * 0.9 + b.ja(93, 1.5), x0, ay + w)
      ..close();
    b.fill(c.fill(PaletteRole.paper));
    pen
      ..moveTo(x0, ay - w * 0.45)
      ..quadTo(x0 - len * 0.3, ay - w * 0.3, x0 - len * 0.5, ay + b.ja(94, 0.8))
      ..quadTo(x0 - len * 0.3, ay + w * 0.3, x0, ay + w * 0.45)
      ..close();
    b.endLayer();
  }
}

Color _mix(Color a, Color b, double t) => Color.lerp(a, b, t)!;

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
import '../parts/hats.dart';
import '../parts/hose.dart';

/// **Zajil** (زاجل, "the messenger") – the camel courier of *Caravan Dash*.
/// An original design: a lanky one-humped camel on four rubber-hose legs in
/// white spats, a long hose neck, dreamy heavy-lidded eyes with lashes,
/// soft lips that chew, a fez with a swinging tassel, a striped saddle
/// blanket with a parcel on the hump and a mail satchel that bounces.
///
/// Gaits: [RigAction.walk] is a camel's *pace* (both legs of a side move
/// together – true to life), [RigAction.run] a rocking gallop.
/// [RigAction.idle] chews the cud, [RigAction.cheer] rears up waving the
/// forelegs, [RigAction.attack] is a hind-leg buck, [RigAction.defeated]
/// folds down onto the sand. The origin is under the middle of the body.
class CamelCourier extends HoseRig {
  CamelCourier({double height = 120, int seed = 0})
    : super(
        RigSpec(
          id: 'zajil',
          body: RigBody.bean,
          height: height,
          fill: PaletteRole.midtone,
          trim: PaletteRole.paper,
          accent: PaletteRole.accent,
          limbWidth: 0.055,
          bounciness: 1.1,
          seed: seed,
        ),
      ) {
    for (var i = 0; i < 4; i++) {
      feet[i].snap(_legX(i), 0);
    }
    head.snap(height * 0.3, -height * 0.78);
    for (final c in tassel) {
      c.snap(height * 0.2, -height * 0.9);
    }
  }

  final Spring2 bodyBob = Spring2();
  final Spring1 bodyPitch = Spring1();
  final Spring2 head = Spring2();
  final Spring1 headTilt = Spring1();
  final Spring1 satchel = Spring1();
  final Spring1 tail = Spring1();
  final List<Spring2> feet = [Spring2(), Spring2(), Spring2(), Spring2()];
  final List<Spring2> tassel = [Spring2(), Spring2(), Spring2()];
  final Float64List _pitch = Float64List(4);
  double _chew = 0;
  double _lips = 0;
  final Face face = Face();
  late final Contour _c = Contour(72);

  double get u => spec.height / 100;

  // Legs: 0 far-hind, 1 far-fore, 2 near-hind, 3 near-fore.
  double _legX(int i) => (i.isOdd ? 19 : -19) * spec.height / 100 + (i < 2 ? -2 : 2) * spec.height / 100;

  @override
  double oneShotLength(RigAction action) => switch (action) {
    RigAction.attack => 0.6,
    _ => super.oneShotLength(action),
  };

  @override
  void update(double dt) {
    final hh = spec.height;
    final cadence = switch (action) {
      RigAction.walk => (speed.abs() / (hh * 0.55)).clamp(0.8, 1.8),
      RigAction.run => (speed.abs() / (hh * 1.1)).clamp(1.4, 3.0),
      _ => 0.0,
    };
    cycle += dt * cadence * math.pi * 2;
    super.update(dt);
  }

  @override
  void animate(double h) {
    final uu = u;
    final t = actionTime;
    final hop = Bounce.hop(beat);
    var bobY = 0.0, pitch = 0.0, hx = 30 * uu, hy = -80 * uu, tilt = 0.0, chew = 0.0, lips = talkLevel;
    final ph = cycle;
    for (var i = 0; i < 4; i++) {
      _pitch[i] = 0;
    }
    switch (action) {
      case RigAction.idle:
        bobY = (1 - hop) * 1.5 * uu;
        chew = 1;
        hx += math.sin(beat * math.pi) * 1.5 * uu;
        hy += (1 - hop) * 1.5 * uu;
        tilt = -0.08 + math.sin(time * 0.7) * 0.05;
        for (var i = 0; i < 4; i++) {
          _foot(h, i, _legX(i), 0, 40);
        }
      case RigAction.walk:
        // The pace: far legs together, then the near pair.
        bobY = -2 * uu * math.sin(ph * 2).abs();
        hx += math.sin(ph * 2) * 3 * uu + 3 * uu;
        hy += math.cos(ph * 2) * 1.5 * uu;
        for (var i = 0; i < 4; i++) {
          final p = ph + (i < 2 ? 0 : math.pi);
          final sn = math.sin(p);
          _foot(h, i, _legX(i) - 12 * uu * math.cos(p), -9 * uu * math.max(0.0, sn), 44);
          _pitch[i] = -0.3 * sn;
        }
      case RigAction.run:
        // Rotary gallop: hinds then fores, the body rocking over them.
        pitch = math.sin(ph) * 0.1;
        bobY = -5 * uu * math.max(0.0, math.sin(ph - 0.6)) - 2 * uu;
        hx += 8 * uu + math.sin(ph) * 4 * uu;
        hy += 4 * uu + math.cos(ph) * 3 * uu;
        tilt = 0.15;
        const off = [0.12, 0.62, 0.0, 0.5];
        for (var i = 0; i < 4; i++) {
          final p = ph + off[i] * math.pi * 2;
          final sn = math.sin(p);
          _foot(h, i, _legX(i) - 20 * uu * math.cos(p) + 4 * uu, sn > 0 ? -16 * uu * sn : 0, 50);
          _pitch[i] = -0.5 * sn;
        }
      case RigAction.jump || RigAction.fall:
        final up = action == RigAction.jump;
        pitch = up ? -0.12 : 0.08;
        hx += up ? 12 * uu : 4 * uu;
        hy += up ? 4 * uu : -6 * uu;
        tilt = up ? 0.25 : -0.2;
        lips = up ? 0.6 : 0.3;
        for (var i = 0; i < 4; i++) {
          final fore = i.isOdd;
          final dangle = up ? 0.0 : math.sin(time * 14 + i) * 3 * uu;
          _foot(h, i, _legX(i) + (fore ? 12 : -12) * uu * (up ? 1 : 0.3), (up ? -20 : -4) * uu + dangle, 36);
          _pitch[i] = up ? (fore ? 0.6 : -0.6) : 0.2;
        }
      case RigAction.land:
        bobY = 6 * uu * (1 - Bounce.span(t, 0, 0.3));
        for (var i = 0; i < 4; i++) {
          _foot(h, i, _legX(i) * 1.15, 0, 50);
        }
      case RigAction.hurt:
        final k = 1 - Bounce.span(t, 0.1, 0.6);
        pitch = -0.15 * k;
        hx -= 12 * uu * k;
        hy -= 4 * uu * k;
        tilt = -0.5 * k;
        lips = 0.9 * k;
        for (var i = 0; i < 4; i++) {
          _foot(h, i, _legX(i) * (1 + 0.25 * k), 0, 44);
        }
      case RigAction.attack:
        // Buck: head down, both hind legs kick out behind.
        final k = Bounce.span(t, 0.08, 0.2) * (1 - Bounce.span(t, 0.35, 0.6));
        pitch = 0.22 * k;
        hx += 6 * uu * k;
        hy += 18 * uu * k;
        tilt = 0.3 * k;
        for (var i = 0; i < 4; i++) {
          if (i.isOdd) {
            _foot(h, i, _legX(i) + 4 * uu * k, 0, 44);
          } else {
            _foot(h, i, _legX(i) - 26 * uu * k, -18 * uu * k, 40);
            _pitch[i] = -0.8 * k;
          }
        }
      case RigAction.cheer:
        // Rears up on the hind legs, forelegs pedalling.
        pitch = -0.55;
        bobY = -hop * 4 * uu;
        hx -= 6 * uu;
        hy -= 16 * uu;
        tilt = -0.3;
        lips = 0.7;
        for (var i = 0; i < 4; i++) {
          if (i.isOdd) {
            final p = time * 9 + i;
            _foot(h, i, _legX(i) + 6 * uu + math.cos(p) * 6 * uu, -52 * uu + math.sin(p) * 6 * uu, 30);
            _pitch[i] = 0.3;
          } else {
            _foot(h, i, _legX(i) + 14 * uu, 0, 44);
          }
        }
      case RigAction.taunt:
        tilt = -0.35;
        hy -= 6 * uu;
        lips = (math.sin(time * 30) * 0.5 + 0.5) * 0.8;
        for (var i = 0; i < 4; i++) {
          _foot(h, i, _legX(i), 0, 40);
        }
        _pitch[3] = -0.4 * Bounce.hop(beat * 2);
      case RigAction.talk:
        lips = math.max(talkLevel, (math.sin(time * 18) * 0.5 + 0.5) * (math.sin(time * 4.7) * 0.3 + 0.7));
        tilt = math.sin(beat * math.pi) * 0.06;
        for (var i = 0; i < 4; i++) {
          _foot(h, i, _legX(i), 0, 40);
        }
      case RigAction.defeated:
        final k = Bounce.out(t / 0.6);
        bobY = 22 * uu * k;
        hx += 6 * uu * k;
        hy += 26 * uu * k;
        tilt = 0.4 * k;
        lips = 0.5;
        for (var i = 0; i < 4; i++) {
          _foot(h, i, _legX(i) + (i.isOdd ? 10 : -6) * uu * k, 0, 30);
          _pitch[i] = 1.2 * k * (i.isOdd ? -1 : 1);
        }
    }
    bodyBob.step(h, 0, bobY, 22, 0.5);
    bodyPitch.step(h, pitch, 14, 0.5);
    head.step(h, hx, hy + bodyBob.y * 0.6, 17, 0.38);
    headTilt.step(h, tilt, 15, 0.45);
    _chew += h * chew * 5;
    _lips += (lips - _lips) * math.min(1, h * 18);
    satchel.step(h, -bodyPitch.value * 0.6, 12, 0.2);
    satchel.kick(-bodyBob.vy * h * 0.06);
    tail.step(h, math.sin(time * 2.2) * 0.25 + (action == RigAction.run ? 0.9 : 0), 10, 0.3);
    // Tassel hangs from the fez on a chain.
    var px = head.x - 4 * uu, py = head.y - 14 * uu;
    for (var i = 0; i < tassel.length; i++) {
      final c = tassel[i];
      c.step(h, px - 2 * uu - speed * 0.004, py + 4.5 * uu, 26 - i * 4.0, 0.3);
      c.kick(-head.vx * h * 0.8, -head.vy * h * 0.8);
      px = c.x;
      py = c.y;
    }
  }

  void _foot(double h, int i, double x, double y, double omega) => feet[i].step(h, x, y, omega, 0.7);

  @override
  void build(RigPaintContext ctx) {
    final b = ink;
    final hh = spec.height, uu = u;
    b.begin(ctx, size: hh, boilFrame: boilFrame);
    final c = b.colors;
    final pen = b.pen;
    final hide = c.fill(spec.fill), light = c.fill(PaletteRole.paper);
    if (!identical(_farFrom, hide)) {
      _farFrom = hide;
      _far = Color.lerp(hide, c.fill(PaletteRole.shadow), 0.3)!;
    }
    final red = c.fill(spec.accent), teal = c.fill(PaletteRole.accent2);
    final s = squashAmount;
    final sy = (1 - s).clamp(0.7, 1.35), sx = 1 / sy;
    pen
      ..reset()
      ..scale(sx, sy)
      ..scale(dir, 1);
    setBounds(-hh * 0.55, -hh * 1.08, hh * 0.6, 0);
    b.shadeAcross(Rect.fromLTWH(-hh * 0.45, -hh * 0.95, hh * 0.9, hh * 0.9));
    final bx = 0.0, by = -48 * uu + bodyBob.y;
    final tn = turn;

    // Tail (behind), far legs.
    pen
      ..save()
      ..rotateAbout(bodyPitch.value, bx, by);
    final tailA = math.pi * 0.62 + tail.value * 0.4;
    final tx = bx - 27 * uu, ty = by - 4 * uu;
    Hose.draw(
      b,
      rootX: tx,
      rootY: ty,
      tipX: tx + math.cos(tailA) * 20 * uu,
      tipY: ty + math.sin(tailA) * 20 * uu,
      length: 22 * uu,
      width: hh * 0.03,
      bend: 1,
      fill: hide,
      salt: 50,
      taper: 0.5,
    );
    b.layer();
    for (var k = -1; k <= 1; k++) {
      final ex = tx + math.cos(tailA) * 20 * uu, ey = ty + math.sin(tailA) * 20 * uu;
      b.brushQuad(
        2,
        ex,
        ey,
        ex + math.cos(tailA + k * 0.3) * 4 * uu,
        ey + math.sin(tailA + k * 0.3) * 5 * uu,
        ex + math.cos(tailA + k * 0.4) * 7 * uu,
        ey + math.sin(tailA + k * 0.4) * 8 * uu,
        b.lw * 1.4,
        taperIn: 0.1,
        taperOut: 0.8,
      );
    }
    b.endLayer();
    pen.restore();
    _leg(b, 0, bx, by);
    _leg(b, 1, bx, by);

    // Body + hump.
    pen
      ..save()
      ..rotateAbout(bodyPitch.value, bx, by);
    final bc = _c..clear();
    bc.blob(pen, bx, by, 29 * uu, 15 * uu, bend: -0.05, box: 0.1, samples: 44);
    bc.wobble(b.amp, b.frame, b.seed, 1);
    b.layer();
    b.blob(bc, hide, depth: 7 * uu);
    final hc = b.contour(1)..clear();
    hc.blob(pen, bx - 5 * uu, by - 13 * uu, 13 * uu, 12 * uu, taper: 0.25, samples: 30);
    hc.wobble(b.amp, b.frame, b.seed, 2);
    b.blob(hc, hide, depth: 4 * uu);
    // Belly patch.
    b.fill(light);
    pen.ellipse(bx + 2 * uu, by + 9 * uu, 18 * uu, 5 * uu);
    b.endLayer();

    // Saddle blanket with stripes and fringe.
    b.layer();
    b.shape(red);
    pen
      ..moveTo(bx - 20 * uu, by - 6 * uu)
      ..quadTo(bx - 14 * uu, by - 16 * uu, bx - 8 * uu, by - 17 * uu)
      ..quadTo(bx - 1 * uu, by - 17 * uu, bx + 9 * uu, by - 7 * uu)
      ..lineTo(bx + 10 * uu, by + 4 * uu)
      ..quadTo(bx - 5 * uu, by + 7 * uu, bx - 21 * uu, by + 4 * uu)
      ..close();
    for (var k = 0; k < 2; k++) {
      b.fill(teal);
      final yy = by - 2 * uu + k * 4 * uu;
      pen
        ..moveTo(bx - 20.5 * uu, yy)
        ..lineTo(bx + 9.5 * uu, yy)
        ..lineTo(bx + 9.7 * uu, yy + 1.6 * uu)
        ..lineTo(bx - 20.7 * uu, yy + 1.6 * uu)
        ..close();
    }
    for (var k = 0; k < 8; k++) {
      final fx = bx - 20 * uu + k * 4.2 * uu;
      b.inkLine(b.lw * 0.6);
      pen
        ..moveTo(fx, by + 5 * uu)
        ..lineTo(fx + b.ja(60 + k, 0.5), by + 8 * uu);
    }
    b.endLayer();
    // Parcel tied on the hump.
    b.layer();
    b.shape(light);
    pen.roundRect(bx - 13 * uu, by - 36 * uu, bx + 1 * uu, by - 25 * uu, 1.5 * uu);
    b.inkLine(b.lw * 0.7);
    pen
      ..moveTo(bx - 5.5 * uu, by - 34 * uu)
      ..lineTo(bx - 5.5 * uu, by - 22 * uu)
      ..moveTo(bx - 13 * uu, by - 28 * uu)
      ..lineTo(bx + 2 * uu, by - 28 * uu);
    b.inkLine(b.lw * 0.7);
    pen
      ..moveTo(bx - 5.5 * uu, by - 34 * uu)
      ..quadTo(bx - 9 * uu, by - 38 * uu, bx - 7.5 * uu, by - 34.5 * uu)
      ..moveTo(bx - 5.5 * uu, by - 34 * uu)
      ..quadTo(bx - 2 * uu, by - 38 * uu, bx - 3.5 * uu, by - 34.5 * uu);
    b.fill(red);
    pen.roundRect(bx - 11 * uu, by - 32 * uu, bx - 7.5 * uu, by - 29 * uu, 0.3 * uu);
    b.endLayer();
    pen.restore();

    // Neck (a rubber hose in hide colour) and the head.
    final nrX = bx + 24 * uu, nrY = by - 6 * uu + bodyPitch.value * 20 * uu;
    final hx = head.x, hy = head.y;
    Hose.draw(
      b,
      rootX: nrX,
      rootY: nrY,
      tipX: hx - 3 * uu,
      tipY: hy + 5 * uu,
      length: 40 * uu,
      width: 10 * uu,
      bend: -1,
      midX: -head.vx * 0.01,
      midY: -head.vy * 0.01,
      fill: hide,
      salt: 70,
    );
    // Satchel strap and bag.
    final sa = satchel.value;
    b.layer();
    b.stroke(c.fill(PaletteRole.ink), b.lw * 1.2);
    pen
      ..moveTo(nrX - 4 * uu, nrY - 8 * uu)
      ..quadTo(nrX + 2 * uu, nrY + 2 * uu, nrX - 2 * uu + math.sin(sa) * 6 * uu, nrY + 8 * uu);
    b.endLayer();
    pen
      ..save()
      ..rotateAbout(sa, nrX - 2 * uu, nrY + 4 * uu);
    b.layer();
    b.shape(light);
    pen.roundRect(nrX - 9 * uu, nrY + 6 * uu, nrX + 5 * uu, nrY + 17 * uu, 2.5 * uu);
    b.shape(teal);
    pen
      ..moveTo(nrX - 9 * uu, nrY + 7 * uu)
      ..lineTo(nrX + 5 * uu, nrY + 7 * uu)
      ..lineTo(nrX + 4 * uu, nrY + 12 * uu)
      ..quadTo(nrX - 2 * uu, nrY + 14 * uu, nrX - 8 * uu, nrY + 12 * uu)
      ..close();
    b.fill(c.fill(PaletteRole.highlight));
    pen.roundRect(nrX - 6 * uu, nrY + 3 * uu, nrX + 1 * uu, nrY + 8 * uu, 0.5 * uu);
    b.endLayer();
    pen.restore();

    // Head frame.
    pen
      ..save()
      ..translate(hx, hy)
      ..rotate(headTilt.value);
    final r = 12.5 * uu;
    // Ears flop behind.
    b.layer();
    for (var k = 0; k < 2; k++) {
      b.shape(hide);
      pen.ellipse(
        -0.7 * r - k * 0.25 * r,
        -0.62 * r + k * 0.1 * r,
        0.42 * r,
        0.2 * r,
        -0.5 - k * 0.4 + head.vy * 0.002,
      );
    }
    b.endLayer();
    // Skull + muzzle, lips.
    b.layer();
    final sk = _c..clear();
    sk.blob(pen, 0, 0, r * 1.02, r * 0.92, taper: 0.1, samples: 32);
    sk.wobble(b.amp * 0.8, b.frame, b.seed, 3);
    b.blob(sk, hide, depth: r * 0.28);
    final mz = b.contour(1)..clear();
    mz.blob(pen, 1.1 * r, 0.45 * r, 0.9 * r, 0.62 * r, taper: 0.12, samples: 28);
    b.blob(mz, light, depth: r * 0.16);
    b.endLayer();
    // Lower lip (chews side to side, drops when talking).
    final chew = math.sin(_chew) * 0.12 * r;
    final open = _lips.clamp(0.0, 1.0);
    b.layer();
    b.shape(light, ink: 0.8);
    pen.ellipse(1.25 * r + chew, 0.95 * r + open * 0.35 * r, 0.55 * r, 0.24 * r + open * 0.1 * r);
    if (open > 0.1) {
      b.fill(c.dark);
      pen.ellipse(1.35 * r + chew * 0.5, 0.82 * r + open * 0.15 * r, 0.42 * r, 0.06 * r + open * 0.16 * r);
    }
    b.endLayer();
    b.layer();
    // Upper lip split, nostril, the smile line.
    b.brushQuad(2, 1.95 * r, 0.62 * r, 1.9 * r, 0.75 * r, 1.84 * r, 0.82 * r, b.lw * 0.9);
    b.brushQuad(2, 1.62 * r, 0.12 * r, 1.78 * r, 0.14 * r, 1.84 * r, 0.3 * r, b.lw * 1.1);
    b.brushQuad(2, 0.7 * r, 0.62 * r, 1.2 * r, 0.9 * r, 1.84 * r, 0.8 * r, b.lw * 1.0, taperIn: 0.6, taperOut: 0.2);
    b.endLayer();
    face
      ..cx = 0.35 * r
      ..cy = -0.15 * r
      ..r = 0.95 * r
      ..turn = math.max(tn, 0.6)
      ..expression = expression
      ..eyes = RigEyes.pieCut
      ..eyeScale = 1.18
      ..eyeGap = 0.05
      ..eyeY = -0.05
      ..blink = blinkAmount
      ..lookX = lookSpring.x
      ..lookY = lookSpring.y
      ..eyeState = switch (action) {
        RigAction.hurt when actionTime < 0.4 => EyeState.squeeze,
        RigAction.defeated => EyeState.spiral,
        RigAction.taunt => EyeState.shut,
        _ => expression == RigExpression.neutral || expression == RigExpression.happy ? EyeState.heavy : EyeState.auto,
      }
      ..spin = time * 6
      ..lashes = 2
      ..nose = NoseStyle.none
      ..skin = hide
      ..drawMouth = false
      ..salt = 400;
    face.draw(b);
    // Fez, tilted back.
    Hats.fez(b, -0.15 * r, -0.78 * r, 1.25 * r, -0.28, fill: red);
    pen.restore();
    // Tassel on its chain (in world design space).
    b.layer();
    final tx0 = hx + math.cos(headTilt.value - 0.28 - math.pi / 2) * 0.95 * r - 0.3 * r;
    final ty0 = hy + math.sin(headTilt.value - 0.28 - math.pi / 2) * 0.95 * r - 0.5 * r;
    final tc = b.contour(2)..clear(closed: false);
    tc.add(pen.x(tx0, ty0), pen.y(tx0, ty0));
    for (final p in tassel) {
      tc.addPen(pen, p.x, p.y);
    }
    b.brush(tc, b.lw * 0.9, taperIn: 0, taperOut: 0, minWidth: 1);
    final end = tassel.last;
    b.shape(c.fill(PaletteRole.ink), ink: 0.5);
    pen.capsule(end.x, end.y, end.x - 0.6 * uu, end.y + 4.5 * uu, 0.9 * uu, 1.8 * uu);
    b.endLayer();

    _leg(b, 2, bx, by);
    _leg(b, 3, bx, by);

    if (emanata) {
      if (action == RigAction.defeated || expression == RigExpression.dizzy) {
        Emanata.dizzyStars(b, hx, hy - 1.6 * r, r * 1.2, time);
      }
      if (action == RigAction.run) {
        Emanata.speedLines(b, bx - 30 * uu, by - 18 * uu, by + 14 * uu, 1, 0.9);
        final p = (cycle / (math.pi * 2)) % 1;
        Emanata.dust(b, feet[0].x - 6 * uu, 0, hh * 0.08, p);
        Emanata.dust(b, feet[2].x - 6 * uu, 0, hh * 0.07, (p + 0.5) % 1);
      }
      if (expression == RigExpression.scared) Emanata.sweat(b, hx, hy - r, hh * 0.05, -1, (time * 1.6) % 1);
      if (action == RigAction.cheer) Emanata.sparkles(b, hx, hy - r, r * 2, time);
      if (action == RigAction.idle && (time % 7.0) > 5.2) {
        Emanata.note(b, hx + 2 * r, hy - 0.5 * r, hh * 0.07, ((time % 7.0) - 5.2) / 1.8);
      }
    }
    b.endLayer();
  }

  Color _far = const Color(0xFF000000);
  Color? _farFrom;

  void _leg(InkBuild b, int i, double bx, double by) {
    final hh = spec.height, uu = u;
    final c = b.colors;
    final hide = c.fill(spec.fill), trim = c.fill(spec.trim);
    final f = feet[i];
    final fore = i.isOdd;
    final rootX = bx + (fore ? 17 : -18) * uu + (i < 2 ? -2 : 2) * uu;
    final rootY = by + 8 * uu + (fore ? -1 : 1) * bodyPitch.value * 18 * uu;
    final ankleY = math.min(f.y - hh * 0.035, 0.0);
    Hose.draw(
      b,
      rootX: rootX,
      rootY: rootY,
      tipX: f.x,
      tipY: ankleY,
      length: 42 * uu,
      width: hh * 0.058,
      bend: fore ? -1 : 1,
      midX: -f.vx * 0.008,
      fill: i < 2 ? _far : hide,
      salt: 10 + i * 3,
    );
    Extremities.shoe(
      b,
      x: f.x,
      y: ankleY,
      size: hh * 0.048,
      fill: c.fill(PaletteRole.ink),
      pitch: _pitch[i],
      salt: 30 + i * 2,
      spat: trim,
    );
  }
}

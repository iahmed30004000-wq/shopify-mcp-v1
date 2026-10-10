import 'dart:math' as math;
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
import '../parts/mechanics.dart';

/// **Sarab** (سراب, "mirage") – the hover-bike courier of *Neon Souk Racer*.
/// An original design: a rubber-hose rider in a round helmet with the
/// visor flipped up and a long scarf, crouched on a teardrop hover-bike with
/// a wrap-around windscreen, a headlamp, a star emblem, fins, a glowing
/// under-strip, pulsing hover rings and a flickering thruster.
///
/// The origin is on the ground under the bike (it hovers above it).
/// [RigAction.run] tucks in at full throttle, [RigAction.jump] pops the
/// nose up with the rider standing on the pegs, [RigAction.attack] is a
/// boost, [RigAction.cheer] a wheelie with a fist pump, [RigAction.taunt] a
/// peace-sign wave, [RigAction.defeated] drops the bike, smoking. [lean]
/// (−1..1) banks into turns; [throttle] (0..1) sizes the flame (default
/// from the action and speed).
class NeonRider extends HoseRig {
  NeonRider({double height = 110, int seed = 0})
    : super(
        RigSpec(
          id: 'sarab',
          body: RigBody.bean,
          height: height,
          fill: PaletteRole.paper,
          trim: PaletteRole.paper,
          accent: PaletteRole.accent,
          limbWidth: 0.06,
          bounciness: 0.9,
          seed: seed,
        ),
      ) {
    for (final c in scarf) {
      c.snap(-height * 0.2, -height * 0.7);
    }
    timing = RigTiming.auto;
  }

  /// Banking into a turn (−1..1).
  double lean = 0;

  /// Thruster override (0..1); `null` = from the action and speed.
  double? throttle;

  final Spring2 _bike = Spring2();
  final Spring1 _pitch = Spring1();
  final Spring1 _wobble = Spring1();
  final Spring2 _rider = Spring2();
  final Spring2 _head = Spring2();
  final List<Spring2> hands = [Spring2(), Spring2()];
  final List<Spring2> scarf = [for (var i = 0; i < 5; i++) Spring2()];
  final Spring1 _flame = Spring1();
  double _rings = 0;
  final Face face = Face();
  late final Contour _c = Contour(64);

  double get u => spec.height / 100;

  @override
  double oneShotLength(RigAction action) => switch (action) {
    RigAction.attack => 0.8,
    _ => super.oneShotLength(action),
  };

  @override
  bool get fastAction => true;

  @override
  void onAction(RigAction action, RigAction previous) {
    super.onAction(action, previous);
    if (action == RigAction.hurt) _wobble.kick(9);
  }

  @override
  void animate(double h) {
    final uu = u;
    final t = actionTime;
    var bikeY = math.sin(time * 4.2) * 1.6 * uu, pitch = 0.0, riderX = 0.0, riderY = 0.0, flame = 0.35;
    var h0x = 24 * uu, h0y = -47 * uu, h1x = 26 * uu, h1y = -46 * uu;
    final spd = (speed.abs() / spec.height).clamp(0.0, 3.0);
    switch (action) {
      case RigAction.idle:
        riderY = math.sin(time * 4.2 - 0.6) * 1.2 * uu;
      case RigAction.walk:
        flame = 0.5;
        pitch = 0.03;
      case RigAction.run:
        flame = 0.75 + spd * 0.1;
        pitch = 0.06;
        riderX = 3 * uu;
        riderY = 3 * uu;
      case RigAction.jump:
        pitch = -0.32;
        riderY = -6 * uu;
        flame = 0.9;
      case RigAction.fall:
        pitch = 0.2;
        riderY = 2 * uu;
        flame = 0.2;
      case RigAction.land:
        bikeY = 5 * uu * (1 - Bounce.span(t, 0, 0.3));
        riderY = 3 * uu * (1 - Bounce.span(t, 0, 0.3));
      case RigAction.hurt:
        riderX = -5 * uu * (1 - Bounce.span(t, 0, 0.6));
        riderY = -4 * uu * (1 - Bounce.span(t, 0, 0.6));
        h1x = 10 * uu;
        h1y = -72 * uu;
        flame = 0.1;
      case RigAction.attack:
        final k = Bounce.span(t, 0, 0.1) * (1 - Bounce.span(t, 0.6, 0.8));
        flame = 0.4 + 0.8 * k;
        riderX = 4 * uu * k;
        riderY = 5 * uu * k;
        pitch = -0.05 * k;
      case RigAction.cheer:
        pitch = -0.28 + math.sin(time * 5) * 0.04;
        flame = 0.8;
        h1x = 6 * uu;
        h1y = -84 * uu - Bounce.hop(beat * 2) * 4 * uu;
      case RigAction.taunt:
        h1x = 0;
        h1y = -80 * uu + math.sin(time * 12) * 2 * uu;
        riderX = -2 * uu;
      case RigAction.talk:
        h1x = 30 * uu;
        h1y = -58 * uu - math.sin(beat * math.pi).abs() * 6 * uu;
      case RigAction.defeated:
        final k = Bounce.out(t / 0.7);
        bikeY = 12 * uu * k;
        pitch = 0.12 * k;
        flame = 0;
        riderY = 8 * uu * k;
        riderX = 6 * uu * k;
        h0y = h1y = -40 * uu;
    }
    _bike.step(h, 0, bikeY, 16, 0.4);
    _pitch.step(h, pitch + lean * 0.05, 10, 0.5);
    _wobble.step(h, 0, 14, 0.18);
    _rider.step(h, riderX, riderY, 22, 0.45);
    _head.step(h, 0, 0, 14, 0.3);
    _head.kick(-_rider.vx * h * 6, -_rider.vy * h * 6);
    hands[0].step(h, h0x, h0y, 30, 0.5);
    hands[1].step(h, h1x, h1y, 30, 0.5);
    _flame.step(h, throttle ?? flame, 20, 0.6);
    _rings += h * (1.2 + spd * 0.4);
    var px = -2 * uu, py = -72 * uu;
    final wind = 0.8 + spd * 0.6;
    for (var i = 0; i < scarf.length; i++) {
      final c = scarf[i];
      final flutter = math.sin(time * 14 - i * 1.4) * spec.height * 0.02 * (i + 1) / 5;
      c.step(h, px - spec.height * 0.07 * wind, py + spec.height * 0.015 + flutter, 30 - i * 3.0, 0.4);
      px = c.x;
      py = c.y;
    }
  }

  @override
  void build(RigPaintContext ctx) {
    final b = ink;
    final hh = spec.height, uu = u;
    b.begin(ctx, size: hh, boilFrame: boilFrame);
    final c = b.colors;
    final pen = b.pen;
    final pal = c.palette;
    final body = c.fill(PaletteRole.accent), dark = c.fill(PaletteRole.shadow), jacket = c.fill(PaletteRole.accent2);
    final glass = c.glass;
    final s = squashAmount;
    final sy = (1 - s).clamp(0.75, 1.3), sx = 1 / sy;
    final bikeY = _bike.y;
    pen
      ..reset()
      ..translate(0, -24 * uu)
      ..scale(sx, sy)
      ..translate(0, 24 * uu)
      ..scale(dir, 1);
    setBounds(-hh * 0.75, -hh * 1.02, hh * 0.62, 0);
    b.shadeAcross(Rect.fromLTWH(-hh * 0.5, -hh * 0.9, hh, hh * 0.9));
    final wob = _wobble.value * 0.08 * math.sin(time * 30);

    // Hover rings below (under everything).
    if (action != RigAction.defeated) {
      b.layer();
      for (var i = 0; i < 3; i++) {
        final p = (_rings + i / 3) % 1;
        final w = 26 * uu + p * 14 * uu, y = -12 * uu + bikeY + p * 11 * uu;
        final ringW = b.lw * (1.2 - p);
        if (ringW <= 0.1) continue;
        b.stroke(c.neon ? pal.accent2 : c.ink, ringW);
        pen.ellipse(2 * uu, y, w, 2.4 * uu * (1 - p * 0.3));
      }
      b.endLayer();
    }

    pen
      ..save()
      ..translate(0, bikeY)
      ..rotateAbout(_pitch.value + wob, 0, -24 * uu);

    // Thruster flame.
    final fl = _flame.value.clamp(0.0, 1.5);
    if (fl > 0.05) {
      final len = (14 + 30 * fl) * uu * (1 + 0.15 * b.j(700));
      b.layer();
      b.shape(c.hot, ink: 0.7);
      pen
        ..moveTo(-47 * uu, -30 * uu)
        ..quadTo(-47 * uu - len * 0.55, -31 * uu + b.ja(701, 2), -47 * uu - len, -25 * uu)
        ..quadTo(-47 * uu - len * 0.55, -19 * uu + b.ja(702, 2), -47 * uu, -20 * uu)
        ..close();
      b.fill(c.puff);
      pen
        ..moveTo(-47 * uu, -28 * uu)
        ..quadTo(-47 * uu - len * 0.35, -27 * uu, -47 * uu - len * 0.55, -25 * uu)
        ..quadTo(-47 * uu - len * 0.35, -23 * uu, -47 * uu, -22 * uu)
        ..close();
      b.endLayer();
    }
    // Scarf streaming behind the rider.
    _scarfDraw(b, jacket);

    // Far leg (behind the bike) and the far hand.
    final hipX = -8 * uu + _rider.x, hipY = -38 * uu + _rider.y;
    Hose.draw(
      b,
      rootX: hipX - 2 * uu,
      rootY: hipY,
      tipX: 4 * uu,
      tipY: -26 * uu,
      length: 24 * uu,
      width: hh * 0.055,
      bend: -1,
      fill: jacket,
      salt: 10,
    );

    // The bike.
    final bc = _c..clear();
    bc.cubic(pen, -48 * uu, -32 * uu, -30 * uu, -40 * uu, 20 * uu, -38 * uu, 52 * uu, -26 * uu, samples: 14);
    bc.cubic(
      pen,
      52 * uu,
      -26 * uu,
      56 * uu,
      -22 * uu,
      50 * uu,
      -14 * uu,
      36 * uu,
      -13 * uu,
      samples: 6,
      skipFirst: true,
    );
    bc.cubic(
      pen,
      36 * uu,
      -13 * uu,
      10 * uu,
      -11 * uu,
      -30 * uu,
      -12 * uu,
      -46 * uu,
      -17 * uu,
      samples: 10,
      skipFirst: true,
    );
    bc.cubic(
      pen,
      -46 * uu,
      -17 * uu,
      -52 * uu,
      -20 * uu,
      -52 * uu,
      -28 * uu,
      -48 * uu,
      -32 * uu,
      samples: 6,
      skipFirst: true,
    );
    bc.length--;
    bc.wobble(b.amp * 0.6, b.frame, b.seed, 1);
    b.layer();
    // Tail fin.
    b.shape(body);
    pen
      ..moveTo(-40 * uu, -34 * uu)
      ..lineTo(-50 * uu, -48 * uu)
      ..quadTo(-44 * uu, -48 * uu, -30 * uu, -36 * uu)
      ..close();
    b.blob(bc, body, depth: 7 * uu, threshold: 0.3);
    // Under-strip, stripes, the star emblem.
    b.fill(c.hot);
    pen.roundRect(-36 * uu, -15.5 * uu, 34 * uu, -12.5 * uu, 1.5 * uu);
    b.fill(pal.paper);
    pen
      ..moveTo(-44 * uu, -27 * uu)
      ..quadTo(0, -31 * uu, 44 * uu, -24 * uu)
      ..lineTo(43 * uu, -22 * uu)
      ..quadTo(0, -28.5 * uu, -44 * uu, -24.5 * uu)
      ..close();
    b.fill(c.eyeWhite);
    pen.star(-18 * uu, -22 * uu, 5, 4.5 * uu, 2 * uu, round: 0.2);
    b.endLayer();
    // Thruster nozzle, headlamp, seat, windscreen, handlebar.
    b.layer();
    b.shape(dark);
    pen.roundRect(-52 * uu, -31 * uu, -44 * uu, -19 * uu, 2 * uu);
    b.fill(c.hot);
    pen.ellipse(-52 * uu, -25 * uu, 1.5 * uu, 4.5 * uu);
    b.endLayer();
    b.layer();
    b.shape(dark);
    pen.roundRect(-22 * uu, -40 * uu, 2 * uu, -35 * uu, 2.5 * uu);
    b.shape(c.hot, ink: 0.8);
    pen.circle(48 * uu, -21 * uu, 3.2 * uu);
    b.fill(c.eyeWhite);
    pen.circle(47 * uu, -22 * uu, 1.4 * uu);
    b.endLayer();
    b.layer();
    b.shape(glass, ink: 0.7);
    pen
      ..moveTo(16 * uu, -37 * uu)
      ..quadTo(22 * uu, -52 * uu, 32 * uu, -54 * uu)
      ..quadTo(34 * uu, -44 * uu, 34 * uu, -33 * uu)
      ..close();
    b.brushQuad(3, 22 * uu, -40 * uu, 25 * uu, -48 * uu, 30 * uu, -50 * uu, b.lw * 0.8, color: c.shine);
    b.endLayer();
    b.layer();
    b.stroke(c.dark, b.lw * 1.6);
    pen
      ..moveTo(20 * uu, -36 * uu)
      ..quadTo(22 * uu, -44 * uu, 26 * uu, -47 * uu);
    b.endLayer();

    // Rider: torso, head, near leg, arms.
    final shX = 6 * uu + _rider.x * 1.2, shY = -60 * uu + _rider.y;
    b.layer();
    final tc = b.contour(1)..clear();
    pen
      ..save()
      ..translate((hipX + shX) / 2, (hipY + shY) / 2)
      ..rotate(math.atan2(shX - hipX, hipY - shY) * 0.9);
    tc.blob(pen, 0, 0, 10 * uu, 14 * uu, taper: 0.15, samples: 28);
    pen.restore();
    tc.wobble(b.amp * 0.6, b.frame, b.seed, 2);
    b.blob(tc, jacket, depth: 4 * uu, threshold: 0.3);
    // A lightning stripe on the jacket.
    b.fill(pal.paper);
    final mx = (hipX + shX) / 2, my = (hipY + shY) / 2;
    pen
      ..moveTo(mx - 1 * uu, my - 10 * uu)
      ..lineTo(mx + 4 * uu, my - 2 * uu)
      ..lineTo(mx + 0.5 * uu, my - 1 * uu)
      ..lineTo(mx + 3 * uu, my + 8 * uu)
      ..lineTo(mx - 3 * uu, my - 2 * uu)
      ..lineTo(mx + 0.5 * uu, my - 3 * uu)
      ..close();
    b.endLayer();
    _riderHead(b, shX + 4 * uu + _head.x, shY - 16 * uu + _head.y);
    // Near leg to the peg, boot.
    Hose.draw(
      b,
      rootX: hipX + 2 * uu,
      rootY: hipY + 2 * uu,
      tipX: 8 * uu,
      tipY: -27 * uu,
      length: 24 * uu,
      width: hh * 0.058,
      bend: -1,
      fill: jacket,
      salt: 14,
    );
    Extremities.shoe(b, x: 8 * uu, y: -27 * uu, size: hh * 0.05, fill: dark, pitch: 0.15, salt: 20);
    // Arms (far arm first so the near one overlaps it).
    for (var i = 0; i < 2; i++) {
      final hs = hands[i];
      final tip = Hose.draw(
        b,
        rootX: shX + (i == 0 ? -2 : 2) * uu,
        rootY: shY + 2 * uu,
        tipX: hs.x,
        tipY: hs.y,
        length: 30 * uu,
        width: hh * 0.055,
        bend: i == 1 && action == RigAction.cheer ? 1 : -1,
        midX: -hs.vx * 0.01,
        midY: -hs.vy * 0.01,
        fill: jacket,
        salt: 30 + i * 3,
      );
      final shape =
          handOverride(i) ??
          switch (action) {
            RigAction.cheer when i == 1 => HandShape.fist,
            RigAction.taunt when i == 1 => HandShape.peace,
            RigAction.talk when i == 1 => HandShape.point,
            RigAction.hurt when i == 1 => HandShape.wave,
            _ => HandShape.grip,
          };
      Extremities.glove(
        b,
        x: tip.x,
        y: tip.y,
        angle: tip.angle,
        size: hh * 0.06,
        fill: c.fill(spec.trim),
        shape: shape,
        thumb: Extremities.thumbFront(tip.angle),
        salt: 40 + i * 9,
      );
    }
    pen.restore();

    if (emanata) {
      if (action == RigAction.run || action == RigAction.attack) {
        Emanata.speedLines(b, -55 * uu, -60 * uu + bikeY, -12 * uu + bikeY, 1, action == RigAction.attack ? 1 : 0.8);
      }
      if (action == RigAction.hurt && actionTime < 0.3) {
        Mechanics.sparks(b, -10 * uu, -14 * uu + bikeY, hh * 0.06, 720);
      }
      if (action == RigAction.defeated) {
        Emanata.steam(b, -48 * uu, -30 * uu + bikeY, hh * 0.05, (time * 0.9) % 1, drift: -0.2);
        Emanata.dizzyStars(b, 14 * uu, -92 * uu + bikeY, 12 * uu, time);
      }
      if (action == RigAction.land && actionTime < 0.2) {
        Mechanics.sparks(b, 20 * uu, -8 * uu, hh * 0.04, 730);
      }
    }
    b.endLayer();
  }

  void _riderHead(InkBuild b, double x, double y) {
    final c = b.colors;
    final pen = b.pen;
    // A big rubber-hose head (the face must read at racing size).
    final r = 14 * u;
    final skin = c.skinLight, helmet = c.fill(PaletteRole.midtone);
    b.layer();
    final hc = b.contour(1)..clear();
    hc.blob(pen, x, y, r, r * 0.95, samples: 30);
    hc.wobble(b.amp * 0.6, b.frame, b.seed, 5);
    b.blob(hc, skin, depth: r * 0.25, threshold: 0.3);
    b.endLayer();
    face
      ..cx = x + r * 0.05
      ..cy = y + r * 0.12
      ..r = r * 0.9
      ..turn = 0.7
      ..expression = action == RigAction.run && expression == RigExpression.neutral
          ? RigExpression.determined
          : expression
      ..eyes = RigEyes.pieCut
      ..eyeScale = 1.2
      ..eyeY = -0.02
      ..blink = blinkAmount
      ..lookX = lookSpring.x
      ..lookY = lookSpring.y
      ..eyeState = switch (action) {
        RigAction.hurt when actionTime < 0.4 => EyeState.squeeze,
        RigAction.defeated => EyeState.cross,
        _ => EyeState.auto,
      }
      ..spin = time * 6
      ..nose = NoseStyle.button
      ..noseScale = 0.8
      ..skin = skin
      ..mouth = action == RigAction.cheer || action == RigAction.taunt ? MouthShape.grin : MouthShape.auto
      ..mouthOpen = action == RigAction.talk ? (math.sin(time * 18) * 0.5 + 0.5) : talkLevel
      ..mouthY = 0.55
      ..mouthW = 0.7
      ..salt = 600;
    face.draw(b);
    // Helmet dome, flipped-up visor, stripe, chin strap.
    b.layer();
    b.shape(helmet);
    pen
      ..moveTo(x - r * 1.12, y + r * 0.05)
      ..cubicTo(x - r * 1.2, y - r * 1.45, x + r * 1.15, y - r * 1.45, x + r * 1.1, y - r * 0.25)
      ..lineTo(x + r * 0.6, y - r * 0.3)
      ..quadTo(x - r * 0.1, y - r * 0.5, x - r * 0.72, y + r * 0.1)
      ..quadTo(x - r * 0.9, y + r * 0.35, x - r * 1.12, y + r * 0.05)
      ..close();
    b.fill(c.palette.accent);
    pen
      ..moveTo(x - r * 0.95, y - r * 0.55)
      ..quadTo(x - r * 0.1, y - r * 1.25, x + r * 0.7, y - r * 0.85)
      ..lineTo(x + r * 0.75, y - r * 0.65)
      ..quadTo(x - r * 0.1, y - r * 1.02, x - r * 1.0, y - r * 0.3)
      ..close();
    b.endLayer();
    b.layer();
    b.shape(c.glass, ink: 0.8);
    pen
      ..moveTo(x - r * 0.4, y - r * 1.02)
      ..quadTo(x + r * 0.5, y - r * 1.35, x + r * 1.25, y - r * 0.7)
      ..lineTo(x + r * 1.05, y - r * 0.5)
      ..quadTo(x + r * 0.4, y - r * 1.02, x - r * 0.3, y - r * 0.8)
      ..close();
    b.brushQuad(
      3,
      x - r * 0.5,
      y - r * 0.9,
      x - r * 0.8,
      y - r * 0.2,
      x - r * 0.4,
      y + r * 0.6,
      b.lw * 0.9,
      taperIn: 0.1,
      taperOut: 0.3,
    );
    b.endLayer();
  }

  void _scarfDraw(InkBuild b, Color fill) {
    final pen = b.pen;
    final uu = u;
    final ox = -2 * uu + _rider.x, oy = -70 * uu + _rider.y;
    final tc = b.contour(2)..clear(closed: false);
    tc.addPen(pen, ox, oy);
    for (final p in scarf) {
      tc.addPen(pen, p.x + _rider.x, p.y + _rider.y);
    }
    b.layer();
    tc.writeBrush(b.inkFill(), spec.height * 0.05 + b.lw * 2, taperIn: 0, taperOut: 0.2, minWidth: 0.6);
    tc.writeBrush(
      b.fill(b.colors.fill(PaletteRole.accent)),
      spec.height * 0.05,
      taperIn: 0,
      taperOut: 0.2,
      minWidth: 0.5,
    );
    b.endLayer();
  }
}

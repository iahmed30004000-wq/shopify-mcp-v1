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
import '../parts/hats.dart';
import '../parts/hose.dart';
import '../parts/mechanics.dart';

/// Which attack [RigAction.attack] performs.
enum BossAttack {
  /// Both fists raised overhead, then slammed on the floor in front.
  slam,

  /// One ribbed arm shoots out far past its length.
  punch,

  /// The furnace mouth gapes and blasts (the game spawns the projectile at
  /// [ClockworkBoss.mouthAnchor]).
  blast,
}

/// **Baron Zunbruk** (البارون زُنبُرك, "Baron Mainspring") – the clockwork
/// foreman of *Metropolis Machine*. An original automaton: a riveted boiler
/// body riding a single gear-wheel, a ten-hour clock dial for a belly (a nod
/// to the film's shift clock), porthole eyes under riveted brows, a
/// coil-spring moustache, a furnace-grate mouth that glows, a smokestack
/// top hat that puffs, ribbed hose arms with huge gloves and a wind-up key
/// turning in his back.
///
/// Boss rush: [phase] 0 (pristine, smug) → 1 (dented, leaking steam,
/// cracked lens, key racing) → 2 (plating gone: gears spinning inside, the
/// hat knocked off and a spring boinging out of his head, one eye dangling
/// on a spring, sparks). Set [attack] before `act(RigAction.attack)`;
/// [windUp] (0..1) shows a tell before the attack starts. Anchors for hit
/// boxes and projectiles: [fistAnchor], [mouthAnchor], [coreAnchor].
class ClockworkBoss extends HoseRig {
  ClockworkBoss({double height = 280, int seed = 0})
    : super(
        RigSpec(
          id: 'zunbruk',
          body: RigBody.tall,
          height: height,
          fill: PaletteRole.midtone,
          trim: PaletteRole.paper,
          accent: PaletteRole.accent2,
          limbWidth: 0.08,
          bounciness: 0.8,
          seed: seed,
        ),
      ) {
    for (var i = 0; i < 2; i++) {
      hands[i].snap((i == 0 ? -1 : 1) * height * 0.42, -height * 0.4);
    }
    timing = RigTiming.auto;
  }

  int _phase = 0;

  /// Damage phase 0..2 (see the class doc).
  int get phase => _phase;
  set phase(int value) {
    final v = value.clamp(0, 2);
    if (v == _phase) return;
    _phase = v;
    squash(0.25);
    flash(0.12);
    _popTime = 0;
    markDirty();
  }

  BossAttack attack = BossAttack.slam;

  /// Attack tell (0..1): arms draw back, eyes glow, steam builds.
  double windUp = 0;

  final Spring2 _body = Spring2();
  final Spring1 _lean = Spring1();
  final Spring2 _head = Spring2();
  final Spring1 _jaw = Spring1();
  final List<Spring2> hands = [Spring2(), Spring2()];
  final Spring2 _eyeDangle = Spring2();
  final Spring2 _headSpring = Spring2();
  double _wheel = 0, _key = 0, _clock = 0, _popTime = 10;
  final List<HandShape> _shape = [HandShape.fist, HandShape.fist];
  final Face face = Face();
  late final Contour _c = Contour(64);

  double get u => spec.height / 100;

  // Anchors (character space, updated each drawing).
  Offset _fist0 = Offset.zero, _fist1 = Offset.zero, _mouth = Offset.zero, _core = Offset.zero;

  /// Fist [i] (0 = back, 1 = front) in character space.
  Offset fistAnchor(int i) => i == 0 ? _fist0 : _fist1;

  /// The furnace mouth (projectile origin).
  Offset get mouthAnchor => _mouth;

  /// The clock-dial core (the weak spot).
  Offset get coreAnchor => _core;

  @override
  double oneShotLength(RigAction action) => switch (action) {
    RigAction.attack => attack == BossAttack.slam ? 0.9 : 0.7,
    RigAction.hurt => 0.55,
    RigAction.land => 0.35,
    _ => 0,
  };

  @override
  void onAction(RigAction action, RigAction previous) {
    super.onAction(action, previous);
    if (action == RigAction.hurt) _head.kick(-spec.height * 0.6, -spec.height * 0.3);
  }

  @override
  void animate(double h) {
    final hh = spec.height, uu = u;
    final t = actionTime;
    final ph = _phase;
    // Wheel turns with speed; the key and clock with the phase's frenzy.
    _wheel += h * speed / (hh * 0.12);
    _key += h * (2.2 + ph * 3.5 + windUp * 8) * (action == RigAction.defeated ? math.max(0, 1 - t / 2.5) : 1);
    final tick = action == RigAction.defeated ? 0.0 : (ph == 2 ? 14.0 : 0.0);
    _clock = ph == 2 ? _clock + h * tick : beat.floorToDouble() * 0.6;
    _popTime += h;

    final hop = Bounce.hop(beat), contact = Bounce.contact(beat);
    var bodyY = (1 - hop) * 2 * uu, lean = 0.0, jaw = talkLevel;
    final shX = hh * 0.3, shY = -hh * 0.62;
    var h0x = -shX - hh * 0.06, h0y = shY + hh * 0.3, h1x = shX + hh * 0.06, h1y = shY + hh * 0.3;
    _shape[0] = HandShape.fist;
    _shape[1] = HandShape.fist;
    switch (action) {
      case RigAction.idle:
        lean = math.sin(beat * math.pi) * 0.03;
        h0y += math.sin(beat * math.pi) * 3 * uu;
        h1y -= math.sin(beat * math.pi) * 3 * uu;
        _shape[1] = HandShape.open;
        if (contact > 0.5) squashSpring.value = math.max(squashSpring.value, contact * 0.03);
      case RigAction.walk || RigAction.run:
        lean = 0.1 + (speed.abs() / hh).clamp(0.0, 1.0) * 0.1;
        final sw = math.sin(time * 7);
        h0x += sw * hh * 0.08;
        h1x -= sw * hh * 0.08;
      case RigAction.attack:
        switch (attack) {
          case BossAttack.slam:
            final up = Bounce.span(t, 0, 0.4), down = Bounce.span(t, 0.4, 0.52), rec = Bounce.span(t, 0.62, 0.9);
            final k = up * (1 - down);
            final s = down * (1 - rec);
            h0x = Bounce.lerp(-hh * 0.12, hh * 0.28, s);
            h1x = Bounce.lerp(hh * 0.12, hh * 0.5, s);
            h0y = h1y = Bounce.lerp(shY - hh * 0.45 * k, -hh * 0.06, s);
            lean = -0.1 * k + 0.22 * s;
            bodyY = 4 * uu * s;
            jaw = 0.4 * k + 0.9 * s;
          case BossAttack.punch:
            final wind = Bounce.span(t, 0, 0.25), out = Bounce.span(t, 0.25, 0.35), rec = Bounce.span(t, 0.45, 0.7);
            final reach = out * (1 - rec);
            h1x = shX - hh * 0.12 * wind * (1 - out) + hh * 0.95 * reach;
            h1y = shY + hh * 0.05;
            h0x = hh * 0.02;
            h0y = shY + hh * 0.12;
            lean = -0.08 * wind * (1 - out) + 0.18 * reach;
            jaw = 0.5 * reach;
          case BossAttack.blast:
            final open = Bounce.span(t, 0.1, 0.3) * (1 - Bounce.span(t, 0.5, 0.7));
            jaw = open;
            lean = 0.08 * open;
            h0x = -shX - hh * 0.14;
            h1x = shX + hh * 0.14;
            h0y = h1y = shY + hh * 0.05;
            _shape[0] = _shape[1] = HandShape.open;
        }
      case RigAction.taunt:
        final fast = Bounce.hop(beat * 2);
        bodyY = (1 - fast) * 3 * uu;
        lean = -0.12;
        jaw = 0.5 + 0.5 * fast;
        h0x = -hh * 0.12;
        h1x = hh * 0.14;
        h0y = h1y = -hh * 0.42;
        _shape[0] = _shape[1] = HandShape.open;
      case RigAction.talk:
        jaw = math.max(talkLevel, (math.sin(time * 16) * 0.5 + 0.5) * 0.8);
        h1x = shX + hh * 0.2;
        h1y = shY + hh * 0.05 - math.sin(beat * math.pi).abs() * hh * 0.08;
        _shape[1] = HandShape.point;
      case RigAction.cheer:
        h0y = h1y = shY - hh * 0.38 + Bounce.hop(beat) * hh * 0.04;
        h0x = -shX - hh * 0.1;
        h1x = shX + hh * 0.1;
        jaw = 0.8;
      case RigAction.hurt:
        final k = 1 - Bounce.span(t, 0.05, 0.55);
        lean = -0.22 * k;
        h0x -= hh * 0.12 * k;
        h1x -= hh * 0.02 * k;
        h0y = h1y = shY - hh * 0.25 * k;
        _shape[0] = _shape[1] = HandShape.open;
        jaw = 0.9 * k;
      case RigAction.jump || RigAction.fall:
        bodyY = -4 * uu;
        h0y = h1y = shY - hh * 0.12;
        jaw = 0.4;
      case RigAction.land:
        bodyY = 5 * uu * (1 - Bounce.span(t, 0, 0.35));
        h0y = h1y = shY + hh * 0.1;
      case RigAction.defeated:
        final k = Bounce.out(t / 0.8);
        bodyY = 10 * uu * k;
        lean = -0.2 * k;
        h0x = -shX - hh * 0.05;
        h1x = shX + hh * 0.1;
        h0y = h1y = -hh * 0.05;
        _shape[0] = _shape[1] = HandShape.open;
        jaw = 0.55 * k;
    }
    // The tell: fists draw back and shake.
    if (windUp > 0 && action != RigAction.attack) {
      final sh = math.sin(time * 40) * windUp * 1.5 * uu;
      h0x -= hh * 0.08 * windUp;
      h1x -= hh * 0.04 * windUp;
      h0y -= hh * 0.08 * windUp + sh;
      h1y -= hh * 0.08 * windUp - sh;
      lean -= 0.06 * windUp;
    }
    _body.step(h, 0, bodyY, 20, 0.5);
    _lean.step(h, lean, 12, 0.55);
    _jaw.step(h, jaw, 30, 0.6);
    _head.step(h, 0, 0, 13, 0.28);
    _head.kick(-_body.vx * h * 6, -_body.vy * h * 8);
    hands[0].step(h, h0x, h0y, 26, 0.5);
    hands[1].step(h, h1x, h1y, 26, 0.5);
    _eyeDangle.step(h, 0, hh * 0.1, 10, 0.18);
    _eyeDangle.kick(-_head.vx * h * 20, -_head.vy * h * 20);
    _headSpring.step(h, 0, 0, 14, 0.12);
    if (contact > 0.9 && ph == 2) _headSpring.kick(math.sin(time) * hh * 0.1, -hh * 0.2);
  }

  @override
  void build(RigPaintContext ctx) {
    final b = ink;
    final hh = spec.height, uu = u;
    b.begin(ctx, size: hh, boilFrame: boilFrame);
    final c = b.colors;
    final pen = b.pen;
    final metal = c.fill(spec.fill), dark = c.fill(PaletteRole.shadow), paper = c.fill(PaletteRole.paper);
    final brass = c.fill(spec.accent), white = c.fill(spec.trim);
    final tn = turn;
    final ph = _phase;
    final s = squashAmount;
    final sy = (1 - s).clamp(0.7, 1.3), sx = 1 / sy;
    pen
      ..reset()
      ..scale(sx, sy)
      ..scale(dir, 1);
    setBounds(-hh * 0.75, -hh * 1.12, hh * 0.75 + (action == RigAction.attack ? hh * 0.9 : 0), 0);
    b.shadeAcross(Rect.fromLTWH(-hh * 0.4, -hh, hh * 0.8, hh));
    final shake = action == RigAction.hurt ? b.j(900) * 2 * uu * (1 - actionTime / 0.55).clamp(0.0, 1.0) : 0.0;

    // --- the wheel and the bellows ---
    final wr = hh * 0.13;
    Mechanics.gear(b, shake, -wr, wr, 12, _wheel, fill: dark, hub: brass, holes: 5);
    final bodyCy = -hh * 0.44 + _body.y;
    final hipY = bodyCy + hh * 0.17;
    b.layer();
    for (var i = 0; i < 3; i++) {
      final y0 = -wr * 1.4 - i * ((-wr * 1.4 - hipY) / 3).abs();
      b.shape(metal, ink: 0.8);
      pen.ellipse(shake, y0 - hh * 0.02, hh * (0.1 + i * 0.025), hh * 0.035);
    }
    b.endLayer();

    // --- lean frame ---
    pen
      ..save()
      ..rotateAbout(_lean.value, 0, hipY)
      ..translate(shake, 0);
    final shX = hh * 0.3, shY = -hh * 0.62 + _body.y;

    // Wind-up key (behind), far arm.
    Mechanics.windKey(b, -hh * 0.27, bodyCy - hh * 0.05, hh * 0.1, _key, fill: brass);
    _arm(b, 0, -shX * (1 - tn * 0.6), shY, white);

    // --- the boiler body ---
    final bc = _c..clear();
    bc.blob(pen, 0, bodyCy, hh * 0.29, hh * 0.21, taper: 0.1, box: 0.45, samples: 48);
    bc.wobble(b.amp, b.frame, b.seed, 1);
    b.layer();
    b.blob(bc, metal, depth: hh * 0.07);
    // Bands top and bottom.
    for (var k = 0; k < 2; k++) {
      final by = k == 0 ? bodyCy - hh * 0.155 : bodyCy + hh * 0.15;
      b.fill(dark);
      pen.roundRect(-hh * 0.285, by - hh * 0.022, hh * 0.285, by + hh * 0.022, hh * 0.01);
    }
    b.endLayer();
    b.layer();
    for (var i = 0; i < 9; i++) {
      final rx = -hh * 0.25 + i * hh * 0.0625;
      if (ph >= 1 && i == 6) continue; // a popped rivet
      Mechanics.rivet(b, rx, bodyCy - hh * 0.155, hh * 0.01);
      Mechanics.rivet(b, rx, bodyCy + hh * 0.15, hh * 0.01);
    }
    b.endLayer();

    // Belly: the ten-hour dial – or, in phase 2, the works.
    final dialX = hh * 0.03 * tn, dialY = bodyCy + hh * 0.005;
    _core = Offset(pen.x(dialX, dialY), pen.y(dialX, dialY));
    if (ph < 2) {
      _dial(b, dialX, dialY, hh * 0.115, paper, brass);
    } else {
      b.layer();
      b.shape(c.dark, ink: 0.9);
      pen
        ..moveTo(-hh * 0.2, bodyCy - hh * 0.12)
        ..lineTo(hh * 0.12, bodyCy - hh * 0.13)
        ..lineTo(hh * 0.2, bodyCy - hh * 0.02)
        ..lineTo(hh * 0.15, bodyCy + hh * 0.13)
        ..lineTo(-hh * 0.18, bodyCy + hh * 0.12)
        ..lineTo(-hh * 0.22, bodyCy)
        ..close();
      b.endLayer();
      Mechanics.gear(b, -hh * 0.07, bodyCy - hh * 0.02, hh * 0.085, 10, time * 3, fill: brass, holes: 3, shaded: false);
      Mechanics.gear(
        b,
        hh * 0.08,
        bodyCy + hh * 0.03,
        hh * 0.065,
        8,
        -time * 3.8,
        fill: metal,
        holes: 0,
        shaded: false,
      );
      // The dial hangs out on a spring.
      final hx = hh * 0.2 + math.sin(time * 5) * hh * 0.02, hy = bodyCy + hh * 0.2 + math.cos(time * 4) * hh * 0.015;
      Mechanics.coil(b, hh * 0.08, bodyCy + hh * 0.03, hx, hy - hh * 0.06, hh * 0.035, 4, weight: 1.1);
      _dial(b, hx, hy, hh * 0.075, paper, brass, crooked: 0.4);
      if (emanata) Mechanics.sparks(b, -hh * 0.16, bodyCy - hh * 0.1, hh * 0.035 * (1 + 0.3 * b.j(901)), 910);
    }
    // Damage marks.
    if (ph >= 1) {
      b.layer();
      final cr = b.contour(2)..clear(closed: false);
      cr
        ..addPen(pen, -hh * 0.27, bodyCy - hh * 0.06)
        ..addPen(pen, -hh * 0.21, bodyCy - hh * 0.03)
        ..addPen(pen, -hh * 0.23, bodyCy + hh * 0.01)
        ..addPen(pen, -hh * 0.17, bodyCy + hh * 0.04)
        ..addPen(pen, -hh * 0.19, bodyCy + hh * 0.08);
      b.brush(cr, b.lw * 0.9, taperIn: 0.1, taperOut: 0.6);
      // A loose panel hanging by one bolt.
      b.shape(metal, ink: 0.8);
      pen
        ..save()
        ..rotateAbout(0.5 + math.sin(time * 3) * 0.06, hh * 0.22, bodyCy + hh * 0.08)
        ..roundRect(hh * 0.2, bodyCy + hh * 0.07, hh * 0.3, bodyCy + hh * 0.13, hh * 0.01)
        ..restore();
      b.endLayer();
      Mechanics.rivet(b, hh * 0.22, bodyCy + hh * 0.08, hh * 0.012);
      b.endLayer();
    }

    // --- neck spring and head ---
    final neckY = bodyCy - hh * 0.2;
    final headX = hh * 0.03 * tn + _head.x, headY = neckY - hh * 0.17 + _head.y;
    Mechanics.coil(b, 0, neckY, headX * 0.8, headY + hh * 0.07, hh * 0.08, 3, weight: 1.6, color: c.ink);
    _headDraw(b, headX, headY, metal, dark, brass);

    // Near arm on top.
    _arm(b, 1, shX * (1 - tn * 0.4), shY, white);
    pen.restore();

    // Steam: from the stack, the leaks, the tell.
    if (emanata) {
      final puff = hh * 0.045;
      if (ph < 2) {
        final stackX = pen.x(headX + hh * 0.02, 0), stackY = headY - hh * 0.3;
        Emanata.steam(b, stackX, stackY, puff * (1 + ph * 0.4), (time * (0.8 + ph * 0.5)) % 1, drift: -0.5);
      }
      if (ph >= 1 || windUp > 0.3) {
        Emanata.steam(b, -hh * 0.3, bodyCy - hh * 0.05, puff * 0.8, (time * 1.7) % 1, drift: -0.8);
      }
      if (action == RigAction.defeated || expression == RigExpression.dizzy) {
        Emanata.dizzyStars(b, headX, headY - hh * 0.18, hh * 0.14, time);
      }
      if (action == RigAction.attack && attack == BossAttack.slam && actionTime > 0.42 && actionTime < 0.62) {
        Emanata.impact(b, hh * 0.38, -hh * 0.03, hh * 0.2);
        Emanata.dust(b, hh * 0.2, 0, hh * 0.12, (actionTime - 0.42) * 3);
        Emanata.dust(b, hh * 0.6, 0, hh * 0.12, (actionTime - 0.42) * 3);
      }
      if (action == RigAction.hurt && actionTime < 0.25) {
        Mechanics.sparks(b, hh * 0.05, bodyCy - hh * 0.1, hh * 0.06, 920);
      }
    }
    b.endLayer();
  }

  void _dial(InkBuild b, double x, double y, double r, Color face, Color rim, {double crooked = 0}) {
    final pen = b.pen;
    b.layer();
    b.shape(rim);
    pen.circle(x, y, r * 1.14);
    b.endLayer();
    b.layer();
    b.shape(face, ink: 0.8);
    pen.circle(x, y, r);
    // Art-deco ten-hour dial: ten ticks, a sunburst.
    for (var i = 0; i < 10; i++) {
      final a = -math.pi / 2 + i * math.pi / 5 + crooked;
      final r0 = r * (i.isEven ? 0.68 : 0.76), r1 = r * 0.9;
      b.inkLine(b.lw * (i.isEven ? 0.9 : 0.6));
      pen
        ..moveTo(x + math.cos(a) * r0, y + math.sin(a) * r0)
        ..lineTo(x + math.cos(a) * r1, y + math.sin(a) * r1);
    }
    // Hands: hour and minute (ticking on the beat; racing in phase 2).
    final m = _clock * 1.3 + crooked, hr = _clock * 0.11 + 2.1 + crooked;
    b.inkFill();
    pen
      ..capsule(
        x,
        y,
        x + math.cos(m - math.pi / 2) * r * 0.78,
        y + math.sin(m - math.pi / 2) * r * 0.78,
        r * 0.05,
        r * 0.02,
      )
      ..capsule(
        x,
        y,
        x + math.cos(hr - math.pi / 2) * r * 0.5,
        y + math.sin(hr - math.pi / 2) * r * 0.5,
        r * 0.07,
        r * 0.03,
      );
    Mechanics.rivet(b, x, y, r * 0.09);
    b.brushQuad(
      3,
      x - r * 0.62,
      y - r * 0.3,
      x - r * 0.55,
      y - r * 0.62,
      x - r * 0.25,
      y - r * 0.72,
      b.lw * 0.9,
      color: b.colors.shine,
    );
    b.endLayer();
  }

  void _arm(InkBuild b, int i, double rootX, double rootY, Color glove) {
    final hh = spec.height;
    final hs = hands[i];
    final tip = Hose.draw(
      b,
      rootX: rootX,
      rootY: rootY,
      tipX: hs.x,
      tipY: hs.y + _body.y,
      length: hh * 0.42,
      width: hh * 0.075,
      bend: i == 0 ? 1 : -1,
      midX: (-hs.vx * 0.015).clamp(-hh * 0.1, hh * 0.1),
      midY: (-hs.vy * 0.015).clamp(-hh * 0.1, hh * 0.1),
      fill: ink.colors.fill(spec.fill),
      ribs: 5,
      salt: 20 + i * 5,
    );
    // Shoulder cap.
    final pen = ink.pen;
    ink.layer();
    ink.shape(ink.colors.fill(PaletteRole.shadow));
    pen.circle(rootX, rootY, hh * 0.055);
    Mechanics.rivet(ink, rootX, rootY, hh * 0.012);
    ink.endLayer();
    Extremities.glove(
      b,
      x: tip.x,
      y: tip.y,
      angle: tip.angle,
      size: hh * 0.085,
      fill: glove,
      shape: handOverride(i) ?? _shape[i],
      thumb: Extremities.thumbFront(tip.angle) * (i == 0 ? -1 : 1),
      salt: 40 + i * 9,
    );
    final p = Offset(pen.x(tip.x, tip.y), pen.y(tip.x, tip.y));
    if (i == 0) {
      _fist0 = p;
    } else {
      _fist1 = p;
    }
  }

  void _headDraw(InkBuild b, double x, double y, Color metal, Color dark, Color brass) {
    final pen = b.pen;
    final hh = spec.height;
    final c = b.colors;
    final r = hh * 0.215;
    final tn = turn;
    final ph = _phase;
    // Dome head.
    final hc = _c..clear();
    hc.blob(pen, x, y, r * 1.1, r * 0.9, taper: 0.12, box: 0.3, samples: 40);
    hc.wobble(b.amp, b.frame, b.seed, 5);
    b.layer();
    b.blob(hc, metal, depth: r * 0.28);
    // Ear bolts.
    b.shape(dark);
    pen
      ..circle(x - r * 1.1, y + r * 0.05, r * 0.2)
      ..circle(x + r * 1.1, y + r * 0.05, r * 0.2);
    b.endLayer();
    b.layer();
    for (var i = 0; i < 5; i++) {
      final a = math.pi + i * math.pi / 4;
      Mechanics.rivet(b, x + math.cos(a) * r * 0.9, y + math.sin(a) * r * 0.72 + r * 0.05, r * 0.05);
    }
    b.endLayer();

    // Face: porthole eyes (one dangling in phase 2).
    final angry = windUp > 0.2 || action == RigAction.attack;
    face
      ..cx = x
      ..cy = y + r * 0.02
      ..r = r * 1.02
      ..turn = tn
      ..expression = angry && expression == RigExpression.neutral ? RigExpression.angry : expression
      ..eyes = RigEyes.pieCut
      ..eyeScale = 0.84
      ..eyeGap = 0.55
      ..eyeY = -0.16
      ..blink = blinkAmount
      ..lookX = lookSpring.x
      ..lookY = lookSpring.y
      ..eyeState = switch (action) {
        RigAction.hurt when actionTime < 0.35 => EyeState.squeeze,
        RigAction.defeated => EyeState.cross,
        RigAction.taunt => EyeState.shut,
        _ => EyeState.auto,
      }
      ..spin = time * 6
      ..rim = c.fill(PaletteRole.paper)
      ..browWeight = 1.9
      ..nose = NoseStyle.button
      ..noseScale = 1.3
      ..skin = metal
      ..drawMouth = false
      ..salt = 500;
    face.draw(b);
    if (ph >= 1) {
      // A cracked lens.
      final ex = x + r * 0.2 + tn * r * 0.3, ey = y - r * 0.1;
      b.layer();
      b.brushQuad(
        2,
        ex - r * 0.12,
        ey - r * 0.2,
        ex + r * 0.02,
        ey - r * 0.05,
        ex + r * 0.08,
        ey + r * 0.2,
        b.lw * 0.6,
      );
      b.endLayer();
    }
    if (ph == 2) {
      // One eye sprung out on a coil.
      final ex = x - r * 0.35, ey = y - r * 0.1;
      final dx = ex - r * 0.3 + _eyeDangle.x, dy = ey + _eyeDangle.y + r * 0.4;
      Mechanics.coil(b, ex, ey, dx, dy - r * 0.2, r * 0.18, 4, weight: 0.9);
      b.layer();
      b.shape(brass);
      pen.circle(dx, dy, r * 0.28);
      b.shape(c.eyeWhite, ink: 0.7);
      pen.circle(dx, dy, r * 0.2);
      b.inkFill(c.dark);
      pen.circle(dx + r * 0.05, dy + r * 0.06, r * 0.1);
      b.endLayer();
    }

    // Moustache: two coil-spring curls under the nose.
    final mx = x + tn * r * 0.3, my = y + r * 0.3;
    final twitch = _jaw.value * r * 0.08;
    b.layer();
    for (var sd = -1; sd <= 1; sd += 2) {
      final ct = b.contour(2)..clear(closed: false);
      final droop = ph == 2 ? r * 0.2 : 0.0;
      ct.cubic(
        pen,
        mx,
        my,
        mx + sd * r * 0.22,
        my - r * 0.06 - twitch,
        mx + sd * r * 0.48,
        my + r * 0.04 + droop,
        mx + sd * r * 0.52,
        my - r * 0.14 + droop,
        samples: 10,
      );
      for (var i = 1; i <= 10; i++) {
        final a = -math.pi / 2 + sd * i * 0.55;
        final rr = r * 0.09 * (1 - i / 14);
        ct.addPen(pen, mx + sd * r * 0.43 + math.cos(a) * rr * sd, my - r * 0.14 + droop + r * 0.09 + math.sin(a) * rr);
      }
      b.brush(ct, b.lw * 1.35, taperIn: 0.1, taperOut: 0.7, press: 0.3);
    }
    b.endLayer();

    // Furnace-grate mouth with a hinged jaw.
    final jaw = _jaw.value.clamp(0.0, 1.0);
    final mw = r * 0.9, top = my + r * 0.2, bot = top + r * (0.2 + 0.48 * jaw);
    _mouth = Offset(pen.x(mx, (top + bot) / 2), pen.y(mx, (top + bot) / 2));
    b.layer();
    b.shape(c.hot, ink: 0.9);
    pen
      ..moveTo(mx - mw / 2, top)
      ..lineTo(mx + mw / 2, top)
      ..quadTo(mx + mw / 2, bot, mx, bot)
      ..quadTo(mx - mw / 2, bot, mx - mw / 2, top)
      ..close();
    // Grate bars.
    for (var i = 1; i <= 4; i++) {
      final gx = mx - mw / 2 + mw * i / 5;
      b.inkLine(b.lw * 0.9);
      pen
        ..moveTo(gx, top + r * 0.04)
        ..lineTo(gx, bot - r * 0.06 * (1 - (i - 2.5).abs() / 2.5));
    }
    // Jagged teeth, top and bottom.
    b.fill(c.teeth);
    pen.moveTo(mx - mw / 2, top);
    for (var i = 0; i < 6; i++) {
      final x0 = mx - mw / 2 + mw * i / 6;
      pen
        ..lineTo(x0 + mw / 12, top + r * 0.1)
        ..lineTo(x0 + mw / 6, top);
    }
    pen.close();
    b.endLayer();

    // Hat: a smokestack top hat (knocked off in phase 2 → a spring boings).
    if (ph < 2) {
      Hats.topHat(
        b,
        x + r * 0.05,
        y - r * 0.8,
        r * 1.35,
        r * 1.1,
        -0.06 + _head.x * 0.004,
        fill: c.fill(PaletteRole.ink),
        band: brass,
      );
    } else {
      final sx = x + _headSpring.x, sy = y - r * 0.8;
      Mechanics.coil(b, x, y - r * 0.75, sx, sy - r * 0.7 + _headSpring.y * 0.3, r * 0.3, 5, weight: 1.3);
      if (emanata && _popTime < 0.6) Emanata.shock(b, x, y - r * 0.2, r * 1.3, Bounce.backOut(_popTime / 0.2));
    }
  }
}

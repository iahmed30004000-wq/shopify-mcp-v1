import 'dart:math' as math;
import 'dart:ui';

import '../../engine/cinema_engine.dart';
import '../../engine/rig/rig_kit.dart';

/// Which attack [RigAction.attack] performs.
enum CloudAttack {
  /// Cheeks puff up, then he blows a gust across the sky.
  gust,

  /// The baton rises, then flicks a thunder-note at the hero.
  thunder,
}

/// **Maestro Ghaym** (المايسترو غَيم, "Maestro Cloud") – the grumpy
/// conductor-cloud of *Flappy Orbit*. An original design: a cumulus in a
/// wing collar and bow tie, heavy ink brows over pie eyes in a pince-nez,
/// a big button nose, wild cloud-tuft hair, rubber-hose arms in white
/// gloves, one holding a baton he waves on the beat. He floats; the game
/// moves him.
///
/// Boss rush: [phase] 0 (grey and grumbling) → 1 (dark, raining, hair
/// standing up) → 2 (a thunderhead: lightning in his hair, sparks, and he
/// [whirl]s with the stage). Set [attack] before `act(RigAction.attack)`;
/// [windUp] (0..1) is the tell (cheeks inflate / baton rises). Anchors in
/// character space, updated each drawing: ([mouthX], [mouthY]) where gusts
/// start, ([batonX], [batonY]) where thunder-notes leave the baton.
class ConductorCloud extends HoseRig {
  ConductorCloud({double height = 150, int seed = 0})
    : super(
        RigSpec(
          id: 'ghaym',
          body: RigBody.ball,
          height: height,
          fill: PaletteRole.midtone,
          trim: PaletteRole.paper,
          accent: PaletteRole.accent2,
          limbWidth: 0.06,
          bounciness: 1.1,
          seed: seed,
        ),
      ) {
    hands[0].snap(-height * 0.6, -height * 0.5);
    hands[1].snap(height * 0.55, -height * 0.6);
    timing = RigTiming.auto;
  }

  int _phase = 0;

  /// Damage phase 0..2 (see the class doc).
  int get phase => _phase;
  set phase(int value) {
    final v = value.clamp(0, 2);
    if (v == _phase) return;
    _phase = v;
    squash(0.3);
    flash(0.12);
    _hair.kick(spec.height * 3);
    markDirty();
  }

  CloudAttack attack = CloudAttack.gust;

  /// Attack tell (0..1).
  double windUp = 0;

  /// Rotation of the whole cloud (phase 2 whirls with the stage).
  double whirl = 0;

  /// Whirl speed (rad/s) the game sets while the stage spins.
  double whirlSpeed = 0;

  /// Deflation 0..1 while defeated (the game drives it as he blows away).
  double deflate = 0;

  final Spring2 _bob = Spring2();
  final Spring1 _cheek = Spring1();
  final Spring1 _hair = Spring1();
  final Spring1 _tilt = Spring1();
  final Spring1 _baton = Spring1(-0.6);
  final List<Spring2> hands = [Spring2(), Spring2()];
  final List<HandShape> _shape = [HandShape.fist, HandShape.grip];
  final Face face = Face();
  double _mouthOpen = 0;
  double _blow = 0;

  // Anchors (character space, updated each drawing).
  double mouthX = 0, mouthY = 0, batonX = 0, batonY = 0;

  double get u => spec.height / 100;

  @override
  double oneShotLength(RigAction action) => switch (action) {
    RigAction.attack => attack == CloudAttack.gust ? 0.9 : 0.7,
    RigAction.hurt => 0.6,
    _ => super.oneShotLength(action),
  };

  @override
  void onAction(RigAction action, RigAction previous) {
    super.onAction(action, previous);
    switch (action) {
      case RigAction.hurt:
        _tilt.kick(-6);
        _hair.kick(spec.height * 2);
      case RigAction.attack:
        if (attack == CloudAttack.gust) _cheek.kick(-12);
        _tilt.kick(attack == CloudAttack.gust ? 3 : -4);
      case RigAction.defeated:
        _tilt.kick(4);
      default:
    }
  }

  @override
  void animate(double h) {
    final hh = spec.height;
    final t = actionTime;
    final ph = _phase;
    whirl += h * whirlSpeed;
    final hop = Bounce.hop(beat);
    var bobY = -hop * hh * 0.025, cheek = 0.0, mouth = talkLevel, blow = 0.0, hair = 0.3 + ph * 0.35;
    final shX = hh * 0.52, shY = -hh * 0.5;
    // Rest pose: far hand on the hip of the cloud, near hand conducting.
    var h0x = -shX - hh * 0.12, h0y = shY + hh * 0.1;
    final conduct = math.sin(beat * math.pi / 2);
    var batonA = -0.7 + conduct * 0.55;
    var h1x = shX + hh * 0.22 + conduct * hh * 0.05, h1y = shY - hh * 0.12 + Bounce.hop(beat * 2) * hh * 0.06;
    _shape[0] = HandShape.fist;
    _shape[1] = HandShape.grip;
    switch (action) {
      case RigAction.idle || RigAction.walk || RigAction.run:
        if (windUp > 0) {
          if (attack == CloudAttack.gust) {
            cheek = windUp;
            mouth = 0;
            h0x = -hh * 0.2;
            h0y = shY + hh * 0.05;
            h1x = hh * 0.36;
            h1y = shY + hh * 0.12;
            batonA = -1.3;
            _shape[0] = _shape[1] = HandShape.open;
          } else {
            // The baton rises straight overhead, quivering at the top.
            h1x = hh * 0.12 + windUp * hh * 0.06;
            h1y = shY - hh * 0.5 - windUp * hh * 0.38 + math.sin(time * 30) * hh * 0.01 * windUp;
            batonA = -1.65 - windUp * 0.35;
            h0x = -shX - hh * 0.08;
            h0y = shY - hh * 0.2 * windUp;
            mouth = 0.3 * windUp;
          }
          hair += windUp * 0.5;
        }
      case RigAction.attack:
        switch (attack) {
          case CloudAttack.gust:
            final out = Bounce.span(t, 0, 0.12), fade = Bounce.span(t, 0.55, 0.9);
            blow = out * (1 - fade);
            mouth = 0.9 * blow;
            cheek = -0.2 * out * (1 - fade);
            h0x = -hh * 0.25;
            h0y = shY + hh * 0.15;
            h1x = hh * 0.3;
            h1y = shY + hh * 0.22;
            batonA = -1.0;
            _shape[0] = _shape[1] = HandShape.open;
          case CloudAttack.thunder:
            // The baton slashes from overhead down and forward.
            final slash = Bounce.span(t, 0, 0.14), rec = Bounce.span(t, 0.4, 0.7);
            final k = slash * (1 - rec);
            h1x = Bounce.lerp(hh * 0.18, shX + hh * 0.06, k);
            h1y = Bounce.lerp(shY - hh * 0.88, shY + hh * 0.1, k);
            batonA = Bounce.lerp(-2.0, 0.55, k);
            h0x = -shX - hh * 0.12 - k * hh * 0.08;
            h0y = shY - hh * 0.15 + k * hh * 0.1;
            mouth = 0.8 * k;
            _shape[0] = HandShape.point;
        }
      case RigAction.hurt:
        final k = Bounce.span(t, 0, 0.1) * (1 - Bounce.span(t, 0.35, 0.6));
        mouth = 0.6 * k;
        h0x = -shX - hh * 0.12 - k * hh * 0.06;
        h0y = shY - hh * 0.3 * k;
        h1x = shX + hh * 0.12 + k * hh * 0.06;
        h1y = shY - hh * 0.35 * k;
        batonA = -0.3;
        _shape[0] = _shape[1] = HandShape.open;
        bobY += k * hh * 0.08;
      case RigAction.taunt:
        final fast = Bounce.hop(beat * 2);
        mouth = 0.4 + 0.5 * fast;
        h1x = shX + hh * 0.3;
        h1y = shY - hh * 0.35 - fast * hh * 0.15;
        batonA = -1.4 + fast * 0.6;
        h0x = -shX - hh * 0.15;
        h0y = shY - hh * 0.05;
        _shape[0] = HandShape.fist;
        hair += 0.3;
      case RigAction.talk:
        mouth = math.max(talkLevel, (math.sin(time * 16) * 0.5 + 0.5) * 0.8);
      case RigAction.cheer:
        h0y = h1y = shY - hh * 0.6;
        _shape[0] = _shape[1] = HandShape.open;
      case RigAction.defeated:
        final k = Bounce.out(t / 0.8);
        bobY = hh * 0.15 * k;
        h0x = -shX - hh * 0.1;
        h1x = shX + hh * 0.1;
        h0y = h1y = shY + hh * 0.35 * k;
        batonA = 1.2;
        _shape[0] = _shape[1] = HandShape.open;
        mouth = 0.5;
        hair = 0.1;
      default:
    }
    if (ph == 2 && action != RigAction.defeated) {
      // The thunderhead's arms spread as he whirls.
      final sp = (whirlSpeed.abs() / 3).clamp(0.0, 1.0);
      h0x = Bounce.lerp(h0x, -shX - hh * 0.35, sp);
      h1x = Bounce.lerp(h1x, shX + hh * 0.35, sp);
      h0y = Bounce.lerp(h0y, shY - hh * 0.1, sp);
      h1y = Bounce.lerp(h1y, shY - hh * 0.1, sp);
    }
    _bob.step(h, 0, bobY, 18, 0.5);
    _cheek.step(h, cheek, 22, 0.55);
    _hair.step(h, hair, 14, 0.4);
    _tilt.step(h, 0, 16, 0.4);
    _baton.step(h, batonA, 26, 0.6);
    _mouthOpen += (mouth - _mouthOpen) * math.min(1, h * 20);
    _blow += (blow - _blow) * math.min(1, h * 24);
    for (var i = 0; i < 2; i++) {
      final target = i == 0 ? h0x : h1x;
      final ty = i == 0 ? h0y : h1y;
      hands[i].step(h, target, ty, 28 - i * 4.0, 0.45);
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
    final ph = _phase;
    final cy = -hh * 0.5 + _bob.y;
    final w = hh * 0.5, hv = hh * 0.34;
    final grey0 = _mix(c.fill(PaletteRole.midtone), c.fill(PaletteRole.paper), 0.5);
    final grey1 = c.fill(PaletteRole.midtone);
    final grey2 = _mix(c.fill(PaletteRole.midtone), c.fill(PaletteRole.shadow), 0.5);
    final body = ph == 0 ? grey0 : (ph == 1 ? grey1 : grey2);
    final paper = c.fill(PaletteRole.paper);
    final brass = _mix(c.fill(PaletteRole.midtone), c.fill(PaletteRole.highlight), 0.4);
    final s = squashAmount + deflate * 0.35;
    final sy = (1 - s).clamp(0.5, 1.4), sx = (1 / sy) * (1 - deflate * 0.3);
    pen
      ..reset()
      ..translate(0, cy)
      ..scale(sx, sy)
      ..rotate(whirl + _tilt.value * 0.08)
      ..translate(0, -cy)
      ..scale(dir, 1);
    setBounds(-hh * 0.95, -hh * 1.25, hh * 0.95, hh * 0.15);
    b.shadeAcross(Rect.fromLTWH(-w, cy - hv * 1.2, w * 2, hv * 2.6));

    // Rain under a stormy cloud (behind).
    if (ph >= 1 && action != RigAction.defeated) {
      b.layer();
      b.inkLine(b.lw * 0.5);
      for (var i = 0; i < 6; i++) {
        final k = ((time * 1.6 + i * 0.37) % 1);
        final x = -w * 0.8 + i * w * 0.32 + b.ja(20 + i, 0.5);
        final y0 = cy + hv * 0.95 + k * hh * 0.45;
        pen
          ..moveTo(x, y0)
          ..lineTo(x - hh * 0.02, y0 + hh * (0.06 + 0.04 * (1 - k)));
      }
      b.endLayer();
    }
    // Far arm.
    _arm(b, 0, cy, w, paper, brass);

    // The cumulus body: puffs merged into one inked silhouette, a flat
    // underside, a shading crescent along the bottom.
    b.layer();
    for (var i = 0; i < 7; i++) {
      final k = i / 6;
      final a = math.pi + k * math.pi;
      final rx = w * 0.78, ry = hv * 0.95;
      final pr = hh * (0.17 + 0.07 * math.sin(k * math.pi)) * (1 + 0.05 * b.j(i));
      b.shape(body);
      pen.circle(math.cos(a) * rx + b.ja(i, 0.4), cy + math.sin(a) * ry * 0.75 + hv * 0.15, pr);
    }
    b.shape(body);
    pen.roundRect(-w * 0.95, cy - hv * 0.1, w * 0.95, cy + hv * 0.9, hh * 0.14);
    b.shape(body);
    pen.circle(0, cy - hv * 0.2, hh * 0.3);
    b.shade();
    pen
      ..moveTo(-w * 0.9, cy + hv * 0.4)
      ..quadTo(0, cy + hv * 0.75, w * 0.9, cy + hv * 0.35)
      ..lineTo(w * 0.85, cy + hv * 0.9)
      ..quadTo(0, cy + hv * 1.05, -w * 0.85, cy + hv * 0.9)
      ..close();
    b.endLayer();

    // Hair: cloud tufts standing up with his temper; lightning in phase 2.
    final hairK = _hair.value.clamp(0.0, 1.5);
    b.layer();
    for (var i = -2; i <= 2; i++) {
      final x = i * hh * 0.11 + hh * 0.04 * tn;
      final len = hh * (0.12 + 0.16 * hairK) * (1 - 0.15 * i.abs());
      b.brushQuad(
        2,
        x,
        cy - hv * 0.95,
        x + i * hh * 0.03 + math.sin(time * 5 + i) * hh * 0.01,
        cy - hv * 0.95 - len * 0.6,
        x + i * hh * 0.06,
        cy - hv * 0.95 - len,
        b.lw * 1.6,
        taperIn: 0.05,
        taperOut: 0.85,
      );
    }
    b.endLayer();
    if (ph == 2 && ((time * 7).floor() % 3 != 1) && action != RigAction.defeated) {
      b.layer();
      b.shape(c.hot, ink: 0.8);
      final bx = -hh * 0.1, by = cy - hv * 1.35;
      pen
        ..moveTo(bx, by)
        ..lineTo(bx + hh * 0.1, by - hh * 0.12)
        ..lineTo(bx + hh * 0.05, by - hh * 0.12)
        ..lineTo(bx + hh * 0.16, by - hh * 0.3)
        ..lineTo(bx + hh * 0.07, by - hh * 0.16)
        ..lineTo(bx + hh * 0.12, by - hh * 0.16)
        ..close();
      b.endLayer();
    }

    // Wing collar, bow tie and lapels under the chin.
    final cx = hh * 0.02 + hh * 0.1 * tn, chinY = cy + hv * 0.42;
    b.layer();
    b.shape(paper, ink: 0.8);
    pen
      ..moveTo(cx - hh * 0.13, chinY - hh * 0.04)
      ..lineTo(cx, chinY + hh * 0.1)
      ..lineTo(cx + hh * 0.13, chinY - hh * 0.04)
      ..lineTo(cx + hh * 0.09, chinY + hh * 0.16)
      ..lineTo(cx - hh * 0.09, chinY + hh * 0.16)
      ..close();
    b.shape(c.fill(PaletteRole.shadow), ink: 0.8);
    pen
      ..moveTo(cx - hh * 0.3, chinY - hh * 0.02)
      ..lineTo(cx - hh * 0.1, chinY + hh * 0.02)
      ..lineTo(cx - hh * 0.14, chinY + hh * 0.2)
      ..close()
      ..moveTo(cx + hh * 0.3, chinY - hh * 0.02)
      ..lineTo(cx + hh * 0.1, chinY + hh * 0.02)
      ..lineTo(cx + hh * 0.14, chinY + hh * 0.2)
      ..close();
    final bs = hh * 0.05;
    b.shape(c.fill(spec.accent));
    pen
      ..moveTo(cx, chinY)
      ..lineTo(cx - bs * 1.4, chinY - bs * 0.8)
      ..lineTo(cx - bs * 1.4, chinY + bs * 0.8)
      ..close()
      ..moveTo(cx, chinY)
      ..lineTo(cx + bs * 1.4, chinY - bs * 0.8)
      ..lineTo(cx + bs * 1.4, chinY + bs * 0.8)
      ..close();
    b.shape(c.fill(spec.accent));
    pen.ellipse(cx, chinY, bs * 0.4, bs * 0.45);
    b.endLayer();

    // Face: heavy brows, a pince-nez, a big nose, a frown; cheeks puff
    // before a gust.
    final fr = hh * 0.3;
    final fx = hh * 0.02, fy = cy - hv * 0.15;
    final cheek = _cheek.value;
    if (cheek > 0.05) {
      b.layer();
      for (final side in const [-1.0, 1.0]) {
        b.shape(body, ink: 0.8);
        pen.ellipse(fx + side * fr * 0.72 + fr * 0.2 * tn, fy + fr * 0.4, fr * 0.3 * cheek, fr * 0.26 * cheek);
      }
      b.endLayer();
    }
    face
      ..cx = fx
      ..cy = fy
      ..r = fr
      ..turn = tn
      ..expression = switch (action) {
        RigAction.defeated => RigExpression.dizzy,
        RigAction.hurt => RigExpression.surprised,
        _ => expression,
      }
      ..eyes = RigEyes.pieCut
      ..eyeScale = 0.95
      ..eyeGap = 0.35
      ..eyeY = -0.02
      ..blink = blinkAmount
      ..lookX = lookSpring.x
      ..lookY = lookSpring.y
      ..eyeState = switch (action) {
        RigAction.hurt when actionTime < 0.3 => EyeState.squeeze,
        RigAction.defeated => EyeState.cross,
        RigAction.attack when attack == CloudAttack.gust => EyeState.squeeze,
        _ => EyeState.auto,
      }
      ..spin = time * 6
      ..brows = true
      ..browWeight = 1.7
      ..rim = brass
      ..nose = NoseStyle.button
      ..noseScale = 1.5
      ..noseColor = _mix(body, c.fill(PaletteRole.shadow), 0.25)
      ..skin = body
      ..mouth = switch (action) {
        RigAction.attack when attack == CloudAttack.gust => MouthShape.oh,
        RigAction.defeated => MouthShape.wavy,
        RigAction.hurt => MouthShape.oh,
        _ => _mouthOpen > 0.25 ? MouthShape.open : MouthShape.frown,
      }
      ..mouthOpen = _mouthOpen
      ..mouthY = 0.62
      ..mouthW = 0.55
      ..salt = 500;
    face.draw(b);
    // Pince-nez bridge.
    b.layer();
    b.inkLine(b.lw * 0.6);
    final ew = fr * 0.25 * 0.95, sp = ew * 1.35;
    pen
      ..moveTo(fx + fr * 0.3 * tn - sp * (1 - 0.3 * tn) + ew * 1.2, fy - fr * 0.05)
      ..quadTo(fx + fr * 0.3 * tn, fy - fr * 0.15, fx + fr * 0.3 * tn + sp - ew * 1.2, fy - fr * 0.05);
    b.endLayer();
    // The mouth anchor (character space).
    final mx = fx + fr * 0.18 * tn + fr * 0.2 * tn, my = fy + fr * 0.62;
    mouthX = pen.x(mx, my);
    mouthY = pen.y(mx, my);
    // Blowing: wind lines streaming from the mouth.
    if (_blow > 0.05 && emanata) {
      b.layer();
      for (var i = 0; i < 3; i++) {
        final y = my + (i - 1) * fr * 0.25;
        final len = hh * (0.32 + 0.08 * i) * _blow;
        b.brushQuad(2, mx + fr * 0.3, y, mx + fr * 0.3 + len * 0.5, y + (i - 1) * fr * 0.1, mx + fr * 0.3 + len, y + (i - 1) * fr * 0.2, b.lw * 0.9, taperIn: 0.1, taperOut: 0.8);
      }
      b.endLayer();
    }

    // Near arm with the baton.
    _arm(b, 1, cy, w, paper, brass);

    if (emanata) {
      if (expression == RigExpression.dizzy || action == RigAction.defeated) {
        Emanata.dizzyStars(b, 0, cy - hv * 1.3, hh * 0.35, time);
      }
      if (action == RigAction.hurt) {
        Emanata.sweat(b, fx + fr * 1.1, fy - fr * 0.4, hh * 0.07, 1, (actionTime * 2) % 1);
        Emanata.sweat(b, fx - fr * 1.1, fy - fr * 0.4, hh * 0.07, -1, (actionTime * 2 + 0.3) % 1);
      }
      if (action == RigAction.hurt && actionTime < 0.2) Emanata.impact(b, -w * 0.55, cy - hv * 0.5, hh * 0.3);
      if (ph >= 1 && action == RigAction.idle) {
        Emanata.steam(b, -w * 0.9, cy - hv * 0.3, hh * 0.05, (time * 1.3) % 1, drift: -0.4);
      }
      if (ph == 2 && action != RigAction.defeated) {
        Mechanics.sparks(b, w * 0.9 + b.ja(31, 2), cy - hv * 0.6, hh * 0.05, 30 + (time * 6).floor());
      }
      if (action == RigAction.taunt || (action == RigAction.idle && windUp == 0 && ph == 0)) {
        Emanata.note(b, w * 0.85, cy - hv * 0.9, hh * 0.09, (time * 0.7) % 1);
      }
    }
    b.endLayer();
  }

  /// A hose arm from the cloud's side to the hand; the near hand holds the
  /// baton.
  void _arm(InkBuild b, int i, double cy, double w, Color glove, Color brass) {
    final hh = spec.height;
    final pen = b.pen;
    final side = i == 0 ? -1.0 : 1.0;
    final hs = hands[i];
    final tip = Hose.draw(
      b,
      rootX: side * w * 0.8,
      rootY: cy + hh * 0.02,
      tipX: hs.x,
      tipY: hs.y,
      length: hh * 0.55,
      width: hh * spec.limbWidth,
      bend: i == 0 ? 1 : -1,
      midX: (-hs.vx * 0.015).clamp(-hh * 0.15, hh * 0.15),
      midY: (-hs.vy * 0.015).clamp(-hh * 0.15, hh * 0.15),
      salt: 10 + i * 4,
    );
    if (i == 1 && action != RigAction.defeated) {
      // Baton: a tapered stick with a cork ball at the grip.
      final a = _baton.value;
      final len = hh * 0.42;
      final x1 = tip.x + math.cos(a) * len, y1 = tip.y + math.sin(a) * len;
      b.layer();
      b.brushQuad(2, tip.x, tip.y, (tip.x + x1) / 2, (tip.y + y1) / 2, x1, y1, b.lw * 1.7, taperIn: 0.02, taperOut: 0.75, press: 0.2);
      b.shape(brass, ink: 0.8);
      pen.circle(tip.x - math.cos(a) * hh * 0.04, tip.y - math.sin(a) * hh * 0.04, hh * 0.035);
      b.endLayer();
      batonX = pen.x(x1, y1);
      batonY = pen.y(x1, y1);
    }
    Extremities.glove(
      b,
      x: tip.x,
      y: tip.y,
      angle: i == 1 && action != RigAction.defeated ? _baton.value : tip.angle,
      size: hh * 0.075,
      fill: glove,
      shape: handOverride(i) ?? _shape[i],
      thumb: Extremities.thumbFront(tip.angle) * (i == 0 ? -1 : 1),
      salt: 20 + i * 8,
    );
  }
}

Color _mix(Color a, Color b, double t) => Color.lerp(a, b, t)!;

import 'dart:math' as math;
import 'dart:ui';

import '../../engine/cinema_engine.dart';
import '../../engine/rig/rig_kit.dart';
import 'metropolis_rules.dart';

// The five machines of Metropolis Machine, as rubber-hose rigs: each one
// reads its [BossBrain] (mode, tell, attack, phase, hurt) and poses itself
// on springs, then draws with the ink toolkit – riveted iron, dials with
// pie-cut eyes, grate mouths, hose cables – so it boils, shades (pen
// hatching in the 1920s) and flashes like the cast. Everything is original:
// art-deco machines with faces, nodding to the mood of a 1927 machine city.
//
// Design space faces +x = toward the hero; the rigs set `facing = -1` so the
// drawing is mirrored to look left, where the hero fights. World x of a
// design point: standX - designX.

Color _mix(Color a, Color b, double t) => Color.lerp(a, b, t)!;

/// Shared behaviour of the machines: the brain-driven mood, hurt shake,
/// drawing rate and the face setup.
abstract class MachineRig extends HoseRig {
  MachineRig(super.spec, this.brain) {
    facing = -1;
    facingSpring.snap(-1);
    timing = RigTiming.auto;
  }

  final BossBrain brain;
  final Face face = Face();
  late final Contour body = Contour(64);

  double get hh => spec.height;

  /// Design x of a world x.
  double dx(double worldX) => brain.standX - worldX;

  RigExpression get mood {
    if (!brain.alive) return RigExpression.dizzy;
    if (brain.hurtLeft > 0) return RigExpression.scared;
    if (brain.windUp > 0.25 || brain.mode == BossMode.attack) return RigExpression.angry;
    if (brain.vulnerable) return RigExpression.surprised;
    return RigExpression.sly;
  }

  EyeState get eyeStateFor {
    if (!brain.alive) return EyeState.cross;
    if (brain.hurtLeft > 0.1) return EyeState.squeeze;
    return EyeState.auto;
  }

  /// Hurt tremble in design units (re-rolled per drawing).
  double shake(int salt) => brain.hurtLeft > 0 ? ink.j(salt) * hh * 0.012 : 0;

  @override
  bool get fastAction => switch (brain.mode) {
    BossMode.attack || BossMode.telegraph || BossMode.dying || BossMode.entering => true,
    _ => brain.hurtLeft > 0 || squashSpring.velocity.abs() > 1.2,
  };

  /// Sets the common face fields on [face] (eyes only; mouths are machine parts).
  void setupFace(InkBuild b, double cx, double cy, double r, {double gap = 0.6, double scale = 0.9, Color? rim, double browWeight = 1.6}) {
    face
      ..cx = cx
      ..cy = cy
      ..r = r
      ..turn = 0
      ..expression = mood
      ..eyes = RigEyes.pieCut
      ..eyeScale = scale
      ..eyeGap = gap
      ..eyeY = 0
      ..blink = blinkAmount
      ..lookX = lookSpring.x
      ..lookY = lookSpring.y
      ..eyeState = eyeStateFor
      ..spin = time * 6
      ..rim = rim ?? b.colors.fill(PaletteRole.paper)
      ..brows = true
      ..browWeight = browWeight
      ..nose = NoseStyle.none
      ..skin = b.colors.fill(PaletteRole.midtone)
      ..drawMouth = false
      ..salt = 500;
    face.draw(b);
  }

  /// A riveted iron plate.
  void plate(InkBuild b, double l, double t, double r, double bt, Color fill, {double radius = 4, int rivets = 4, double ink = 1, bool shade = true}) {
    final pen = b.pen;
    b.layer();
    b.shape(fill, ink: ink);
    pen.roundRect(l, t, r, bt, radius);
    if (shade) {
      final c = b.contour(0)..clear();
      c.ellipse(pen, (l + r) / 2, (t + bt) / 2, (r - l) / 2, (bt - t) / 2, samples: 24);
      c.writeCrescent(b.shade(), kShadowX, kShadowY, math.min(r - l, bt - t) * 0.18);
    }
    if (rivets > 0) {
      final rr = math.min(r - l, bt - t) * 0.045 + hh * 0.006;
      final inset = rr * 2.2;
      for (var i = 0; i < rivets; i++) {
        final k = rivets == 1 ? 0.5 : i / (rivets - 1);
        final x = l + inset + (r - l - 2 * inset) * k;
        Mechanics.rivet(b, x, t + inset, rr);
        Mechanics.rivet(b, x, bt - inset, rr);
      }
    }
    b.endLayer();
  }

  /// A grate mouth: a dark slot with bars and a row of jagged teeth on top.
  void grateMouth(InkBuild b, double x, double top, double w, double open, {int bars = 4, bool teeth = true}) {
    final c = b.colors;
    final pen = b.pen;
    final hgt = hh * (0.035 + 0.11 * open);
    final bot = top + hgt;
    b.layer();
    b.shape(open > 0.35 ? c.hot : c.dark, ink: 0.9);
    pen
      ..moveTo(x - w / 2, top)
      ..lineTo(x + w / 2, top)
      ..quadTo(x + w / 2, bot, x, bot)
      ..quadTo(x - w / 2, bot, x - w / 2, top)
      ..close();
    b.inkLine(b.lw * 0.8);
    for (var i = 1; i <= bars; i++) {
      final gx = x - w / 2 + w * i / (bars + 1);
      pen
        ..moveTo(gx, top + hgt * 0.1)
        ..lineTo(gx, bot - hgt * 0.25 * (1 - ((i - (bars + 1) / 2).abs() / ((bars + 1) / 2))));
    }
    if (teeth) {
      b.fill(c.teeth);
      pen.moveTo(x - w / 2, top);
      const n = 6;
      for (var i = 0; i < n; i++) {
        final x0 = x - w / 2 + w * i / n;
        pen
          ..lineTo(x0 + w / (2 * n), top + hh * 0.028)
          ..lineTo(x0 + w / n, top);
      }
      pen.close();
    }
    b.endLayer();
  }

  /// Emanata common to every machine: steam when hurt, stars when beaten,
  /// sparks when hit.
  void feelings(InkBuild b, double headX, double headY, double headR) {
    if (!emanata) return;
    if (!brain.alive) Emanata.dizzyStars(b, headX, headY - headR * 0.6, headR * 0.9, time);
    if (brain.hurtLeft > 0.2) Mechanics.sparks(b, headX + headR * 0.4, headY + headR * 0.5, hh * 0.05, 930);
    if (brain.phase >= 1 && brain.alive) {
      Emanata.steam(b, headX - headR * 0.8, headY - headR * 0.3, hh * 0.05 * (1 + brain.phase * 0.3), (time * 1.3) % 1, drift: -0.5);
    }
  }
}

// ---------------------------------------------------------------------------
// 1. The Clock-Press
// ---------------------------------------------------------------------------

/// **The Clock-Press** (المِكبَس الساعاتي): a riveted art-deco column with a
/// plain twelve-hour dial for a face and a grille mouth, an overhead rail across the
/// hall and a piston hammer that slides along it, winds up with a ratchet
/// and stamps the floor where the hero stood. The hammer head rests on the
/// floor after a stamp – that is when the wrench can reach its gear hub.
class ClockPressRig extends MachineRig {
  ClockPressRig(BossBrain brain, {int seed = 0})
    : super(RigSpec(id: 'clock_press', body: RigBody.tall, height: brain.kind.height, fill: PaletteRole.midtone, seed: seed), brain) {
    _carriage.snap(dx(MetroStage.heroStartX));
  }

  final Spring1 _carriage = Spring1();
  final Spring1 _lean = Spring1();
  double _hammerY = 0;
  double _dial = 0;
  double _hatch = 0;

  /// Hammer bottom in design space (0 = on the floor). Negative = up.
  double get hammerY => _hammerY;
  double get hammerDesignX => _carriage.value;

  @override
  void animate(double h) {
    final rest = -hh * 0.62;
    var target = rest, lean = 0.0;
    var cx = _carriage.value;
    switch (brain.mode) {
      case BossMode.entering:
        target = rest;
        cx = dx(MetroStage.heroStartX);
      case BossMode.telegraph:
        cx = dx(brain.targetX);
        if (brain.attack == AttackKind.cogToss) {
          target = rest;
          _hatch = math.min(1, _hatch + h * 3);
        } else {
          target = rest - hh * 0.2 * Bounce.smooth(brain.windUp);
        }
        lean = -0.03 * brain.windUp;
      case BossMode.attack:
        final t = brain.timer;
        if (brain.attack == AttackKind.stampSweep) {
          final stepAt = 0.45 * brain.step;
          final k = ((t - stepAt) / 0.12).clamp(0.0, 1.0);
          cx = dx(brain.targetX + 60.0 * brain.step);
          target = Bounce.lerp(rest - hh * 0.2, 0, Bounce.inn(k));
          if (t - stepAt > 0.3 && brain.step < 2) target = rest - hh * 0.2;
        } else if (brain.attack == AttackKind.cogToss) {
          target = rest;
          _hatch = math.max(0, _hatch - h * 2);
        } else {
          cx = dx(brain.targetX);
          target = Bounce.lerp(rest - hh * 0.2, 0, Bounce.inn((t / 0.12).clamp(0.0, 1.0)));
        }
        lean = 0.05;
      case BossMode.open:
        target = brain.attack == AttackKind.cogToss ? rest : 0;
        cx = dx(brain.weakX);
        lean = 0.02;
      case BossMode.recover:
        target = Bounce.lerp(0, rest, Bounce.smooth(brain.progress));
      case BossMode.idle:
        target = rest;
        cx = dx((brain.targetX + MetroStage.heroStartX) / 2);
      case BossMode.dying:
        target = rest + hh * 0.3 * Bounce.out(brain.progress);
        lean = -0.12 * Bounce.out(brain.progress * 2);
      case BossMode.dead:
        target = rest + hh * 0.3;
        lean = -0.12;
    }
    final quick = brain.mode == BossMode.attack;
    _hammerY += (target - _hammerY) * math.min(1, h * (quick ? 60 : 9));
    _carriage.step(h, cx, brain.mode == BossMode.attack ? 40 : 14, 0.8);
    _lean.step(h, lean, 10, 0.5);
    _dial += h * (0.6 + brain.phase * 0.8 + brain.windUp * 4);
  }

  @override
  void build(RigPaintContext ctx) {
    final b = ink;
    b.begin(ctx, size: hh, boilFrame: boilFrame);
    final c = b.colors;
    final pen = b.pen;
    final iron = c.fill(PaletteRole.midtone);
    final dark = c.fill(PaletteRole.shadow);
    final brass = _mix(c.fill(PaletteRole.accent2), c.fill(PaletteRole.paper), 0.3);
    final paper = c.fill(PaletteRole.paper);
    final s = squashAmount;
    final sy = (1 - s).clamp(0.8, 1.2), sx = 1 / sy;
    final ph = brain.phase;
    pen
      ..reset()
      ..scale(sx, sy)
      ..scale(dir, 1);
    setBounds(-hh * 0.3, -hh * 1.05, hh * 1.3, 0);
    b.shadeAcross(Rect.fromLTWH(-hh * 0.3, -hh, hh * 0.6, hh));
    final sh = shake(900);

    // --- the rail across the hall ---
    final railY = -hh * 0.93;
    b.layer();
    b.shape(dark, ink: 0.9);
    pen.roundRect(hh * 0.1, railY - hh * 0.03, hh * 1.3, railY + hh * 0.03, hh * 0.01);
    b.inkLine(b.lw * 0.6);
    for (var i = 0; i < 9; i++) {
      final x = hh * 0.22 + i * hh * 0.13;
      pen
        ..moveTo(x, railY - hh * 0.03)
        ..lineTo(x + hh * 0.05, railY + hh * 0.03);
    }
    b.endLayer();

    // --- the column, leaning on hurt / wind-up ---
    pen
      ..save()
      ..rotateAbout(_lean.value, 0, 0)
      ..translate(sh, 0);
    plate(b, -hh * 0.26, -hh * 0.09, hh * 0.2, 0, dark, radius: hh * 0.01, rivets: 5);
    final col = body..clear();
    col.blob(pen, -hh * 0.03, -hh * 0.55, hh * 0.18, hh * 0.47, taper: 0.06, box: 0.9, samples: 48);
    col.wobble(b.amp, b.frame, b.seed, 1);
    b.layer();
    b.blob(col, iron, depth: hh * 0.06, threshold: 0.2);
    // Riveted bands and deco flutes between them.
    for (final by in [-hh * 0.3, -hh * 0.96]) {
      b.fill(dark);
      pen.roundRect(-hh * 0.2, by - hh * 0.018, hh * 0.145, by + hh * 0.018, hh * 0.006);
    }
    b.inkLine(b.lw * 0.5);
    for (var i = -1; i <= 1; i++) {
      pen
        ..moveTo(-hh * 0.03 + i * hh * 0.07, -hh * 0.93)
        ..lineTo(-hh * 0.03 + i * hh * 0.07 + b.ja(10 + i, 0.5), -hh * 0.33);
    }
    b.endLayer();
    b.layer();
    for (var i = 0; i < 6; i++) {
      final rx = -hh * 0.18 + i * hh * 0.065;
      if (ph >= 1 && i == 4) continue;
      Mechanics.rivet(b, rx, -hh * 0.3, hh * 0.009);
      Mechanics.rivet(b, rx, -hh * 0.96, hh * 0.009);
    }
    b.endLayer();
    // Stepped crown.
    plate(b, -hh * 0.22, -hh * 1.02, hh * 0.16, -hh * 0.94, dark, radius: hh * 0.008, rivets: 3, shade: false);
    plate(b, -hh * 0.16, -hh * 1.07, hh * 0.1, -hh * 1.0, dark, radius: hh * 0.008, rivets: 0, shade: false);
    // The cog hatch on the crown (opens for a toss).
    b.layer();
    b.shape(brass, ink: 0.8);
    pen
      ..save()
      ..rotateAbout(-1.4 * _hatch, hh * 0.1, -hh * 1.0)
      ..roundRect(-hh * 0.02, -hh * 1.045, hh * 0.1, -hh * 1.0, hh * 0.006)
      ..restore();
    b.endLayer();
    if (ph >= 1) {
      // Dents and a popped rivet trail of steam.
      b.layer();
      final cr = b.contour(2)..clear(closed: false);
      cr
        ..addPen(pen, -hh * 0.2, -hh * 0.5)
        ..addPen(pen, -hh * 0.12, -hh * 0.46)
        ..addPen(pen, -hh * 0.15, -hh * 0.4)
        ..addPen(pen, -hh * 0.06, -hh * 0.36);
      b.brush(cr, b.lw * 0.9, taperIn: 0.1, taperOut: 0.6);
      b.endLayer();
    }
    // The dial face.
    final dialX = -hh * 0.03, dialY = -hh * 0.7, dr = hh * 0.13;
    b.layer();
    b.shape(brass);
    pen.circle(dialX, dialY, dr * 1.16);
    b.shape(paper, ink: 0.8);
    pen.circle(dialX, dialY, dr);
    for (var i = 0; i < 12; i++) {
      final a = -math.pi / 2 + i * math.pi / 6;
      b.inkLine(b.lw * (i % 3 == 0 ? 0.9 : 0.55));
      pen
        ..moveTo(dialX + math.cos(a) * dr * 0.74, dialY + math.sin(a) * dr * 0.74)
        ..lineTo(dialX + math.cos(a) * dr * 0.9, dialY + math.sin(a) * dr * 0.9);
    }
    final m = _dial * 1.6, hr = _dial * 0.15 + 1.2;
    b.inkFill();
    pen
      ..capsule(dialX, dialY, dialX + math.cos(m - math.pi / 2) * dr * 0.7, dialY + math.sin(m - math.pi / 2) * dr * 0.7, dr * 0.05, dr * 0.02)
      ..capsule(dialX, dialY, dialX + math.cos(hr - math.pi / 2) * dr * 0.45, dialY + math.sin(hr - math.pi / 2) * dr * 0.45, dr * 0.07, dr * 0.03);
    Mechanics.rivet(b, dialX, dialY, dr * 0.08);
    if (ph >= 2) {
      // Shattered glass.
      b.inkLine(b.lw * 0.6);
      for (var i = 0; i < 5; i++) {
        final a = 0.4 + i * 1.1 + b.j(30 + i) * 0.2;
        pen
          ..moveTo(dialX + dr * 0.2 * math.cos(a), dialY + dr * 0.2 * math.sin(a))
          ..lineTo(dialX + dr * (0.9 + 0.1 * b.j(40 + i)) * math.cos(a + 0.2), dialY + dr * 0.95 * math.sin(a + 0.2));
      }
    }
    b.brushQuad(3, dialX - dr * 0.6, dialY - dr * 0.3, dialX - dr * 0.5, dialY - dr * 0.65, dialX - dr * 0.2, dialY - dr * 0.72, b.lw * 0.9, color: c.shine);
    b.endLayer();
    // Eyes above the dial, mouth below.
    setupFace(b, dialX, -hh * 0.86, hh * 0.085, gap: 0.9, scale: 1.05, rim: brass);
    final jaw = brain.mode == BossMode.attack ? 0.9 : (brain.windUp * 0.6 + (brain.vulnerable ? 0.3 : 0) + (brain.hurtLeft > 0 ? 0.8 : 0)).clamp(0.0, 1.0);
    grateMouth(b, dialX, -hh * 0.53, hh * 0.2, jaw, bars: 3);
    feelings(b, dialX, -hh * 0.86, hh * 0.1);
    pen.restore();

    // --- the carriage and the hammer ---
    final hx = _carriage.value;
    final headBottom = _hammerY;
    b.layer();
    b.shape(dark);
    pen.roundRect(hx - hh * 0.1, railY - hh * 0.06, hx + hh * 0.1, railY + hh * 0.06, hh * 0.012);
    // Wheels on the rail.
    for (final k in const [-0.06, 0.06]) {
      b.shape(brass);
      pen.circle(hx + k * hh, railY - hh * 0.03, hh * 0.022);
    }
    b.endLayer();
    // Piston rod from the carriage to the head.
    final headTop = headBottom - hh * 0.18;
    b.layer();
    b.shape(iron, ink: 0.9);
    pen.roundRect(hx - hh * 0.035, railY, hx + hh * 0.035, headTop + hh * 0.02, hh * 0.01);
    b.shape(dark, ink: 0.8);
    pen.roundRect(hx - hh * 0.055, railY + hh * 0.04, hx + hh * 0.055, railY + hh * 0.14, hh * 0.01);
    b.inkLine(b.lw * 0.5);
    for (var i = 0; i < 3; i++) {
      final y = railY + hh * 0.2 + i * hh * 0.12;
      if (y > headTop) break;
      pen
        ..moveTo(hx - hh * 0.035, y)
        ..lineTo(hx + hh * 0.035, y + b.ja(50 + i, 0.4));
    }
    b.endLayer();
    // The head: a block with a gear hub (the weak spot) on its face.
    final impact = brain.mode == BossMode.attack && brain.timer > 0.12 && brain.timer < 0.3;
    final hsq = impact ? 0.12 : 0.0;
    pen
      ..save()
      ..translate(hx, headBottom)
      ..scale(1 + hsq, 1 - hsq);
    plate(b, -hh * 0.2, -hh * 0.18, hh * 0.2, 0, dark, radius: hh * 0.012, rivets: 4);
    Mechanics.gear(b, 0, -hh * 0.09, hh * 0.065, 10, _dial * 2, fill: brass, hub: brain.vulnerable ? c.hot : c.dark, holes: 0, shaded: false);
    if (brain.vulnerable && emanata) {
      // The hub glows: strike here.
      b.layer();
      b.shape(c.hot.withValues(alpha: 0.35 + 0.25 * math.sin(time * 14)), ink: 0);
      pen.circle(0, -hh * 0.09, hh * 0.1);
      b.endLayer();
    }
    pen.restore();
    // Ratchet tick marks shaking off the rod while winding up.
    if (emanata && brain.mode == BossMode.telegraph && brain.attack != AttackKind.cogToss) {
      Emanata.shock(b, hx, railY + hh * 0.1, hh * 0.08, brain.windUp, count: 5);
    }
    if (emanata && brain.mode == BossMode.attack && brain.attack != AttackKind.cogToss && brain.timer > 0.1 && brain.timer < 0.32) {
      Emanata.impact(b, hx, -hh * 0.1, hh * 0.16);
      Emanata.dust(b, hx - hh * 0.22, 0, hh * 0.09, (brain.timer - 0.1) * 4);
      Emanata.dust(b, hx + hh * 0.22, 0, hh * 0.09, (brain.timer - 0.1) * 4);
    }
    if (emanata && ph >= 1) Emanata.steam(b, -hh * 0.03, -hh * 1.07, hh * 0.05 * (1 + ph * 0.4), (time * 1.1) % 1, drift: -0.4);
    b.endLayer();
  }
}

// ---------------------------------------------------------------------------
// 2. The Boiler-Heart
// ---------------------------------------------------------------------------

/// **The Boiler-Heart** (القلب المِرجَل): a riveted boiler on a firebox,
/// with a heart-shaped pressure gauge for a face (the needles are its pie
/// eyes), a furnace-door mouth that opens to blast steam along the floor and
/// a whistle on the dome. Its floor vents hiss before they fire. After a
/// blast the door hangs open and the valve wheel inside is the weak spot.
class BoilerRig extends MachineRig {
  BoilerRig(BossBrain brain, {int seed = 0})
    : super(RigSpec(id: 'boiler_heart', body: RigBody.ball, height: brain.kind.height, fill: PaletteRole.midtone, seed: seed), brain);

  final Spring1 _door = Spring1();
  final Spring1 _pulse = Spring1();
  final Spring1 _lid = Spring1();
  double _whistle = 0;

  @override
  void animate(double h) {
    var door = 0.0, lid = 0.0;
    switch (brain.mode) {
      case BossMode.telegraph:
        door = brain.attack == AttackKind.blast ? 0.5 * brain.windUp : 0.1;
        lid = brain.attack == AttackKind.whistle ? brain.windUp : 0;
      case BossMode.attack:
        door = brain.attack == AttackKind.blast ? 1 : 0.2;
        lid = brain.attack == AttackKind.whistle ? 1 : 0;
      case BossMode.open:
        door = 0.95;
      case BossMode.dying:
        door = 1;
        lid = 1;
      default:
    }
    _door.step(h, door, 16, 0.55);
    _lid.step(h, lid, 14, 0.4);
    final beatRate = 1.2 + brain.phase * 0.8 + brain.windUp * 2;
    final pulse = math.pow(math.max(0.0, math.sin(time * beatRate * math.pi)), 6).toDouble();
    _pulse.step(h, pulse, 30, 0.6);
    _whistle = lid;
  }

  @override
  void build(RigPaintContext ctx) {
    final b = ink;
    b.begin(ctx, size: hh, boilFrame: boilFrame);
    final c = b.colors;
    final pen = b.pen;
    final iron = c.fill(PaletteRole.midtone);
    final dark = c.fill(PaletteRole.shadow);
    final brass = _mix(c.fill(PaletteRole.accent2), c.fill(PaletteRole.paper), 0.3);
    final paper = c.fill(PaletteRole.paper);
    final ph = brain.phase;
    final s = squashAmount + _pulse.value * 0.03;
    final sy = (1 - s).clamp(0.8, 1.2), sx = 1 / sy;
    pen
      ..reset()
      ..scale(sx, sy)
      ..scale(dir, 1);
    setBounds(-hh * 0.6, -hh * 1.25, hh * 0.6, 0);
    b.shadeAcross(Rect.fromLTWH(-hh * 0.5, -hh, hh, hh));
    final sh = shake(901);
    pen.translate(sh, 0);

    // Pipes behind, with elbows and a gauge.
    b.layer();
    b.shape(dark, ink: 0.8);
    pen.roundRect(-hh * 0.5, -hh * 0.9, -hh * 0.42, -hh * 0.1, hh * 0.03);
    b.shape(dark, ink: 0.8);
    pen.roundRect(-hh * 0.5, -hh * 0.94, -hh * 0.22, -hh * 0.86, hh * 0.03);
    b.shape(brass);
    pen.circle(-hh * 0.46, -hh * 0.5, hh * 0.045);
    b.endLayer();

    // Firebox base.
    plate(b, -hh * 0.46, -hh * 0.28, hh * 0.44, 0, dark, radius: hh * 0.012, rivets: 6);
    // The boiler drum.
    final drum = body..clear();
    drum.blob(pen, -hh * 0.03, -hh * 0.62, hh * 0.4, hh * 0.35, taper: 0.02, box: 0.35, samples: 48);
    drum.wobble(b.amp, b.frame, b.seed, 1);
    b.layer();
    b.blob(drum, iron, depth: hh * 0.09, threshold: 0.2);
    for (final y in [-hh * 0.76, -hh * 0.48]) {
      b.fill(dark);
      pen.roundRect(-hh * 0.42, y - hh * 0.02, hh * 0.37, y + hh * 0.02, hh * 0.008);
    }
    b.endLayer();
    b.layer();
    for (var i = 0; i < 8; i++) {
      final x = -hh * 0.36 + i * hh * 0.1;
      if (ph >= 1 && i == 5) continue;
      Mechanics.rivet(b, x, -hh * 0.76, hh * 0.012);
      Mechanics.rivet(b, x, -hh * 0.48, hh * 0.012);
    }
    b.endLayer();
    if (ph >= 2) {
      // Red-hot patches on the drum.
      b.layer();
      b.shape(c.hot.withValues(alpha: 0.5), ink: 0);
      pen.ellipse(-hh * 0.25, -hh * 0.6, hh * 0.1, hh * 0.07, 0.4);
      b.shape(c.hot.withValues(alpha: 0.4), ink: 0);
      pen.ellipse(hh * 0.22, -hh * 0.5, hh * 0.07, hh * 0.05, -0.3);
      b.endLayer();
    }
    // Dome and whistle.
    b.layer();
    b.shape(iron);
    pen.ellipse(-hh * 0.03, -hh * 0.97, hh * 0.2, hh * 0.08);
    b.shape(dark);
    pen.roundRect(-hh * 0.08, -hh * 1.05 - hh * 0.04 * _lid.value, hh * 0.02, -hh * 0.96, hh * 0.008);
    b.shape(brass);
    pen.roundRect(-hh * 0.12, -hh * 1.16 - hh * 0.04 * _lid.value, hh * 0.06, -hh * 1.04 - hh * 0.04 * _lid.value, hh * 0.01);
    b.endLayer();

    // The heart gauge (face).
    final gx = hh * 0.12, gy = -hh * 0.64, gr = hh * 0.17 * (1 + _pulse.value * 0.08);
    b.layer();
    b.shape(brass);
    pen
      ..moveTo(gx, gy + gr * 1.12)
      ..cubicTo(gx - gr * 1.4, gy + gr * 0.2, gx - gr * 1.1, gy - gr * 1.0, gx, gy - gr * 0.45)
      ..cubicTo(gx + gr * 1.1, gy - gr * 1.0, gx + gr * 1.4, gy + gr * 0.2, gx, gy + gr * 1.12)
      ..close();
    b.shape(paper, ink: 0.8);
    pen
      ..moveTo(gx, gy + gr * 0.92)
      ..cubicTo(gx - gr * 1.15, gy + gr * 0.15, gx - gr * 0.9, gy - gr * 0.8, gx, gy - gr * 0.35)
      ..cubicTo(gx + gr * 0.9, gy - gr * 0.8, gx + gr * 1.15, gy + gr * 0.15, gx, gy + gr * 0.92)
      ..close();
    if (ph >= 1) {
      b.inkLine(b.lw * 0.6);
      pen
        ..moveTo(gx - gr * 0.3, gy - gr * 0.5)
        ..lineTo(gx - gr * 0.1, gy - gr * 0.1)
        ..lineTo(gx - gr * 0.25, gy + gr * 0.3);
    }
    // Pressure arc with a red zone.
    b.fill(c.fill(PaletteRole.accent).withValues(alpha: 0.5));
    pen
      ..moveTo(gx + gr * 0.3, gy + gr * 0.55)
      ..quadTo(gx + gr * 0.7, gy + gr * 0.35, gx + gr * 0.72, gy)
      ..lineTo(gx + gr * 0.58, gy + gr * 0.05)
      ..quadTo(gx + gr * 0.55, gy + gr * 0.3, gx + gr * 0.28, gy + gr * 0.42)
      ..close();
    b.endLayer();
    setupFace(b, gx, gy - gr * 0.05, gr * 0.62, gap: 0.5, scale: 1.0, rim: brass);
    // The furnace-door mouth, hinged at the bottom.
    final doorX = hh * 0.32, doorTop = -hh * 0.24, doorW = hh * 0.22, doorH = hh * 0.2;
    final open = _door.value.clamp(0.0, 1.0);
    b.layer();
    b.shape(open > 0.6 ? c.hot : c.dark, ink: 0.9);
    pen
      ..moveTo(doorX - doorW / 2, doorTop + doorH)
      ..lineTo(doorX - doorW / 2, doorTop + doorH * 0.35)
      ..quadTo(doorX, doorTop - doorH * 0.2, doorX + doorW / 2, doorTop + doorH * 0.35)
      ..lineTo(doorX + doorW / 2, doorTop + doorH)
      ..close();
    if (open > 0.5) {
      // The valve wheel inside (the weak spot).
      b.shape(brass);
      pen.circle(doorX, doorTop + doorH * 0.55, doorH * 0.26);
      b.inkLine(b.lw * 0.6);
      for (var i = 0; i < 3; i++) {
        final a = i * math.pi / 3 + time * 2;
        pen
          ..moveTo(doorX + math.cos(a) * doorH * 0.26, doorTop + doorH * 0.55 + math.sin(a) * doorH * 0.26)
          ..lineTo(doorX - math.cos(a) * doorH * 0.26, doorTop + doorH * 0.55 - math.sin(a) * doorH * 0.26);
      }
      Mechanics.rivet(b, doorX, doorTop + doorH * 0.55, doorH * 0.07);
    }
    // The door itself swings down (hinge at the bottom edge).
    pen
      ..save()
      ..translate(doorX, doorTop + doorH)
      ..scale(1, 1 - open * 0.92);
    b.shape(iron);
    pen
      ..moveTo(-doorW / 2 - hh * 0.01, 0)
      ..lineTo(-doorW / 2 - hh * 0.01, -doorH * 0.65)
      ..quadTo(0, -doorH * 1.2, doorW / 2 + hh * 0.01, -doorH * 0.65)
      ..lineTo(doorW / 2 + hh * 0.01, 0)
      ..close();
    b.fill(c.teeth);
    pen.moveTo(-doorW / 2, -doorH * 0.1);
    for (var i = 0; i < 5; i++) {
      final x0 = -doorW / 2 + doorW * i / 5;
      pen
        ..lineTo(x0 + doorW / 10, -doorH * 0.32)
        ..lineTo(x0 + doorW / 5, -doorH * 0.1);
    }
    pen.close();
    b.inkLine(b.lw * 0.7);
    for (var i = 1; i < 4; i++) {
      pen
        ..moveTo(-doorW / 2 + doorW * i / 4, -doorH * 0.9)
        ..lineTo(-doorW / 2 + doorW * i / 4, -doorH * 0.35);
    }
    pen.restore();
    b.endLayer();
    // Steam: the whistle, the leaks, the tell.
    if (emanata) {
      if (_whistle > 0.3) {
        for (var i = 0; i < 2; i++) {
          Emanata.steam(b, -hh * 0.03, -hh * 1.2, hh * 0.07 * _whistle, (time * 2.2 + i * 0.5) % 1, drift: 0.4);
        }
        Emanata.note(b, -hh * 0.2, -hh * 1.2, hh * 0.08, time * 0.9);
      }
      if (ph >= 1) Emanata.steam(b, hh * 0.14, -hh * 0.76, hh * 0.045, (time * 1.6) % 1, drift: 0.6);
      if (brain.mode == BossMode.attack && brain.attack == AttackKind.blast) {
        for (var i = 0; i < 3; i++) {
          Emanata.steam(b, doorX + hh * 0.1 + i * hh * 0.1, doorTop + doorH * 0.9, hh * 0.08, (time * 3 + i * 0.33) % 1, drift: 1.2);
        }
      }
      feelings(b, gx, gy, gr);
    }
    b.endLayer();
  }
}

// ---------------------------------------------------------------------------
// 3. The Switchboard-Spider
// ---------------------------------------------------------------------------

/// **The Switchboard-Spider** (عنكبوت لوحة التحويل): a telephone
/// switchboard cabinet on six plug-cable legs, hanging from two ceiling
/// cables, with a row of lamps for eyes and an operator's horn for a mouth.
/// A seventh cable – the stinger – rears up and plunges its jack plug into
/// the floor where the hero stood; stuck there, the plug is the weak spot.
class SpiderRig extends MachineRig {
  SpiderRig(BossBrain brain, {int seed = 0})
    : super(RigSpec(id: 'switchboard_spider', body: RigBody.ball, height: brain.kind.height, fill: PaletteRole.midtone, seed: seed), brain) {
    for (var i = 0; i < 6; i++) {
      final side = i < 3 ? 1.0 : -1.0;
      final k = i % 3;
      _feet[i].snap(side * hh * (0.3 + k * 0.22), 0);
    }
    _stinger.snap(hh * 0.35, -hh * 0.3);
    _bodyY.snap(-hh * 0.58);
  }

  final List<Spring2> _feet = [for (var i = 0; i < 6; i++) Spring2()];
  final Spring2 _stinger = Spring2();
  final Spring1 _bodyY = Spring1();
  final Spring1 _horn = Spring1();
  double _lamps = 0;

  @override
  void animate(double h) {
    var bodyY = -hh * 0.58, horn = 0.0;
    var stX = hh * 0.35, stY = -hh * 0.3;
    final shuffle = math.sin(time * 2.2);
    for (var i = 0; i < 6; i++) {
      final side = i < 3 ? 1.0 : -1.0;
      final k = i % 3;
      var fx = side * hh * (0.3 + k * 0.22) + shuffle * hh * 0.02 * (k.isEven ? 1 : -1);
      var fy = 0.0;
      if (brain.mode == BossMode.attack && brain.attack == AttackKind.drop) {
        fy = -hh * 0.2 * math.sin(brain.progress * math.pi);
        fx *= 0.8;
      }
      if (brain.mode == BossMode.telegraph && brain.attack == AttackKind.drop) fx *= 1 - 0.25 * brain.windUp;
      _feet[i].step(h, fx, fy, 22, 0.5);
    }
    switch (brain.mode) {
      case BossMode.telegraph:
        switch (brain.attack) {
          case AttackKind.stab:
            stX = dx(brain.targetX);
            stY = -hh * 1.15 - hh * 0.1 * brain.windUp;
            horn = 0.3 + 0.3 * brain.windUp;
          case AttackKind.sweep:
            stX = hh * 0.1;
            stY = -hh * 0.9;
          case AttackKind.drop:
            bodyY = -hh * 0.45;
            horn = 0.6 * brain.windUp;
          case AttackKind.sparks:
            horn = 0.8;
            stY = -hh * 0.5;
          default:
        }
      case BossMode.attack:
        switch (brain.attack) {
          case AttackKind.stab:
            stX = dx(brain.targetX);
            stY = 0;
            horn = 1;
          case AttackKind.sweep:
            final k = Bounce.smooth(brain.progress);
            stX = Bounce.lerp(hh * 0.1, hh * 1.6, k);
            stY = -hh * 0.04;
            horn = 0.7;
          case AttackKind.drop:
            bodyY = -hh * 0.58 - hh * 0.55 * math.sin(brain.progress * math.pi);
            horn = 1;
          case AttackKind.sparks:
            horn = 1;
          default:
        }
      case BossMode.open:
        if (brain.attack == AttackKind.stab) {
          stX = dx(brain.targetX);
          stY = 0;
        } else {
          bodyY = -hh * 0.42;
        }
        horn = 0.4;
      case BossMode.dying:
        bodyY = -hh * 0.2;
        horn = 1;
      case BossMode.dead:
        bodyY = -hh * 0.2;
      default:
    }
    final quick = brain.mode == BossMode.attack && brain.attack == AttackKind.stab;
    _stinger.step(h, stX, stY, quick ? 44 : 12, 0.6);
    _bodyY.step(h, bodyY, 18, 0.4);
    _horn.step(h, horn, 20, 0.5);
    _lamps += h * (3 + brain.phase * 4 + brain.windUp * 8);
  }

  @override
  void build(RigPaintContext ctx) {
    final b = ink;
    b.begin(ctx, size: hh, boilFrame: boilFrame);
    final c = b.colors;
    final pen = b.pen;
    final wood = _mix(c.fill(PaletteRole.midtone), c.fill(PaletteRole.shadow), 0.3);
    final brass = _mix(c.fill(PaletteRole.accent2), c.fill(PaletteRole.paper), 0.3);
    final cable = _mix(c.fill(PaletteRole.shadow), c.ink, 0.3);
    final ph = brain.phase;
    final s = squashAmount;
    final sy = (1 - s).clamp(0.75, 1.25), sx = 1 / sy;
    pen
      ..reset()
      ..scale(sx, sy)
      ..scale(dir, 1);
    setBounds(-hh * 1.0, -hh * 1.6, hh * 1.8, 0);
    b.shadeAcross(Rect.fromLTWH(-hh * 0.5, -hh, hh, hh));
    final sh = shake(902);
    final by = _bodyY.value;
    final bw = hh * 0.72, bh = hh * 0.5;

    // Ceiling cables.
    b.layer();
    b.inkLine(b.lw * 0.8);
    for (final k in const [-0.22, 0.2]) {
      pen
        ..moveTo(k * hh + sh, by - bh / 2)
        ..quadTo(k * hh * 1.3 + sh, by - hh * 0.6, k * hh * 1.1, -hh * 1.6);
    }
    b.endLayer();

    // Legs: cables to jack plugs on the floor.
    for (var i = 0; i < 6; i++) {
      final f = _feet[i];
      final side = i < 3 ? 1.0 : -1.0;
      final rootX = side * bw * (0.18 + (i % 3) * 0.14) + sh, rootY = by + bh * 0.3;
      _cableLeg(b, rootX, rootY, f.x, f.y, hh * 0.75, cable, brass, bend: side, salt: 20 + i * 3, stuck: f.y > -2);
    }
    // The stinger cable from the top front.
    final st = _stinger;
    final stuck = (brain.mode == BossMode.open || brain.mode == BossMode.attack) && brain.attack == AttackKind.stab && st.y > -hh * 0.05;
    _cableLeg(b, bw * 0.4 + sh, by - bh * 0.35, st.x, st.y, hh * 1.5, cable, brass, bend: -1, salt: 40, stuck: stuck, plug: hh * 0.07, glow: brain.vulnerable && brain.attack == AttackKind.stab);

    // The cabinet.
    pen
      ..save()
      ..translate(sh, by);
    plate(b, -bw / 2, -bh / 2, bw / 2, bh / 2, wood, radius: hh * 0.02, rivets: 4);
    // Jack sockets in rows.
    b.layer();
    for (var r = 0; r < 2; r++) {
      for (var i = 0; i < 6; i++) {
        final x = -bw * 0.38 + i * bw * 0.152, y = bh * 0.02 + r * bh * 0.16;
        b.fill(c.dark);
        pen.circle(x, y, hh * 0.016);
        if (((i + r * 3 + (_lamps * 0.5).floor()) % 4) == 0) {
          b.fill(brass);
          pen.circle(x, y, hh * 0.008);
        }
      }
    }
    if (ph >= 1) {
      // A dangling cord with a plug.
      b.brushQuad(2, bw * 0.2, bh * 0.3, bw * 0.3, bh * 0.7 + math.sin(time * 3) * hh * 0.02, bw * 0.22, bh * 0.95, b.lw * 0.8, color: cable, taperIn: 0.02, taperOut: 0.02);
      b.shape(brass);
      pen.roundRect(bw * 0.19, bh * 0.92, bw * 0.25, bh * 1.05, hh * 0.006);
    }
    b.endLayer();
    // Lamp row on top: three small lamps blinking in sequence, big eyes middle.
    b.layer();
    for (var i = 0; i < 5; i++) {
      if (i == 1 || i == 3) continue;
      final x = -bw * 0.42 + i * bw * 0.21;
      final on = ((_lamps.floor() + i) % 3) == 0 || brain.windUp > 0.5;
      final broken = ph >= 1 && i == 4;
      b.shape(brass);
      pen.circle(x, -bh * 0.42, hh * 0.04);
      b.shape(broken ? c.dark : (on ? c.hot : c.fill(PaletteRole.paper)), ink: 0.7);
      pen.circle(x, -bh * 0.42, hh * 0.026);
      if (broken) {
        b.inkLine(b.lw * 0.5);
        pen
          ..moveTo(x - hh * 0.02, -bh * 0.44)
          ..lineTo(x + hh * 0.02, -bh * 0.4);
      }
    }
    b.endLayer();
    setupFace(b, 0, -bh * 0.4, hh * 0.09, gap: 1.1, scale: 1.0, rim: brass);
    // The horn mouth: a flared cone that opens with the jaw.
    final hv = _horn.value.clamp(0.0, 1.0);
    final mx = bw * 0.02, my = bh * 0.52;
    b.layer();
    b.shape(brass);
    pen
      ..moveTo(mx - hh * 0.04, my - hh * 0.02)
      ..lineTo(mx + hh * 0.04, my - hh * 0.02)
      ..lineTo(mx + hh * (0.09 + 0.08 * hv), my + hh * (0.08 + 0.1 * hv))
      ..quadTo(mx, my + hh * (0.12 + 0.12 * hv), mx - hh * (0.09 + 0.08 * hv), my + hh * (0.08 + 0.1 * hv))
      ..close();
    b.fill(c.dark);
    pen.ellipse(mx, my + hh * (0.07 + 0.09 * hv), hh * (0.05 + 0.05 * hv), hh * (0.02 + 0.05 * hv));
    b.endLayer();
    if (emanata && (brain.mode == BossMode.attack && brain.attack == AttackKind.sparks || ph >= 2)) {
      Mechanics.sparks(b, -bw * 0.3, -bh * 0.5, hh * 0.04 * (1 + 0.5 * b.j(905)), 940);
      if (ph >= 2) Mechanics.sparks(b, bw * 0.35, bh * 0.1, hh * 0.035 * (1 + 0.5 * b.j(906)), 950);
    }
    feelings(b, 0, -bh * 0.5, hh * 0.12);
    if (emanata && ph >= 2) Emanata.steam(b, -bw * 0.2, -bh * 0.5, hh * 0.05, (time * 1.5) % 1, drift: -0.5);
    pen.restore();
    b.endLayer();
  }

  /// A cable from ([rx], [ry]) to a jack plug at ([tx], [ty]).
  void _cableLeg(InkBuild b, double rx, double ry, double tx, double ty, double length, Color cable, Color brass, {required double bend, int salt = 0, bool stuck = false, double? plug, bool glow = false}) {
    final c = b.colors;
    final pen = b.pen;
    final tip = Hose.draw(b, rootX: rx, rootY: ry, tipX: tx, tipY: ty - (plug ?? hh * 0.05), length: length, width: hh * 0.035, bend: bend, fill: cable, ribs: 0, salt: salt);
    final ps = plug ?? hh * 0.05;
    pen
      ..save()
      ..translate(tip.x, tip.y)
      ..rotate(tip.angle - math.pi / 2);
    b.layer();
    b.shape(brass);
    pen.roundRect(-ps * 0.5, -ps * 0.2, ps * 0.5, ps * 0.55, ps * 0.1);
    b.shape(glow ? c.hot : c.fill(PaletteRole.shadow), ink: 0.8);
    pen.roundRect(-ps * 0.3, ps * 0.5, ps * 0.3, ps * 1.05, ps * 0.12);
    b.inkLine(b.lw * 0.5);
    pen
      ..moveTo(-ps * 0.3, ps * 0.7)
      ..lineTo(ps * 0.3, ps * 0.7)
      ..moveTo(-ps * 0.3, ps * 0.88)
      ..lineTo(ps * 0.3, ps * 0.88);
    b.endLayer();
    pen.restore();
    if (emanata && stuck) Emanata.dust(b, tx, ty, hh * 0.06, ((time * 1.4) % 1) * 0.5 + 0.2);
  }
}

// ---------------------------------------------------------------------------
// 4. The Lift-Titan
// ---------------------------------------------------------------------------

/// **The Lift-Titan** (عملاق المصعد): the hall's great lift machine come
/// alive – a riveted cage car for a torso riding a tall shaft (a
/// counterweight runs the other way), a floor-indicator dial for a face with
/// lamp eyes, a cage-door grille for a mouth, a bell on its head and two
/// cable arms ending in hook hands. It grabs across the hall at the hero's
/// height, punches the floor and shakes bolts down from the shaft; after a
/// move it leans in and its dial is open to the wrench.
class TitanRig extends MachineRig {
  TitanRig(BossBrain brain, {int seed = 0})
    : super(RigSpec(id: 'lift_titan', body: RigBody.tall, height: brain.kind.height, fill: PaletteRole.midtone, seed: seed), brain) {
    _cageY.snap(-hh * 0.45);
    _hands[0].snap(-hh * 0.1, -hh * 0.3);
    _hands[1].snap(hh * 0.45, -hh * 0.5);
  }

  final Spring1 _cageY = Spring1();
  final List<Spring2> _hands = [Spring2(), Spring2()];
  final Spring1 _doors = Spring1();
  final Spring1 _bell = Spring1();
  double _motor = 0;

  double get cageY => _cageY.value;

  @override
  void animate(double h) {
    final tall = brain.phase == 2;
    var cy = tall ? -hh * 0.72 : -hh * 0.45;
    var h0x = -hh * 0.1, h0y = cy + hh * 0.25, h1x = hh * 0.45, h1y = cy + hh * 0.05;
    var doors = 0.0, bell = 0.0;
    final hero = dx(brain.targetX);
    switch (brain.mode) {
      case BossMode.telegraph:
        switch (brain.attack) {
          case AttackKind.grab:
            h1x = hh * 0.25;
            h1y = -(MetroStage.groundY - brain.targetY) - hh * 0.12 - hh * 0.1 * brain.windUp;
            bell = brain.windUp;
            doors = 0.5;
          case AttackKind.punch:
            h1x = hh * 0.4;
            h1y = cy - hh * 0.3 * brain.windUp;
            doors = 0.3;
          case AttackKind.boltRain:
            cy -= hh * 0.03 * math.sin(time * 30) * brain.windUp;
            h0y = cy - hh * 0.1;
            h1y = cy - hh * 0.1;
            doors = 0.6 * brain.windUp;
          default:
        }
      case BossMode.attack:
        switch (brain.attack) {
          case AttackKind.grab:
            final k = brain.phase == 2 && brain.step == 1 ? ((brain.timer - 0.5) / 0.4).clamp(0.0, 1.0) : (brain.timer / 0.45).clamp(0.0, 1.0);
            h1x = Bounce.lerp(hh * 0.25, hh * 1.5, Bounce.out(k));
            h1y = -(MetroStage.groundY - brain.targetY) - hh * 0.12;
            doors = 1;
          case AttackKind.punch:
            h1x = hero;
            h1y = -hh * 0.03;
            doors = 1;
          case AttackKind.boltRain:
            cy += hh * 0.02 * math.sin(time * 40);
            h0y = cy - hh * 0.3;
            h1y = cy - hh * 0.3;
            doors = 0.8;
          default:
        }
      case BossMode.open:
        cy = tall ? -hh * 0.6 : -hh * 0.32;
        doors = 1;
        h1x = hh * 0.5;
        h1y = cy + hh * 0.35;
      case BossMode.dying:
        cy = -hh * 0.2;
        doors = 1;
        h0y = -hh * 0.05;
        h1y = -hh * 0.05;
      case BossMode.dead:
        cy = -hh * 0.2;
        h0y = -hh * 0.05;
        h1y = -hh * 0.05;
      default:
    }
    final quick = brain.mode == BossMode.attack;
    _cageY.step(h, cy, quick ? 30 : 9, 0.5);
    _hands[0].step(h, h0x, h0y, 18, 0.5);
    _hands[1].step(h, h1x, h1y, quick ? 34 : 16, 0.55);
    _doors.step(h, doors, 20, 0.5);
    _bell.step(h, bell, 26, 0.3);
    _motor += h * (2 + brain.phase * 2);
  }

  @override
  void build(RigPaintContext ctx) {
    final b = ink;
    b.begin(ctx, size: hh, boilFrame: boilFrame);
    final c = b.colors;
    final pen = b.pen;
    final iron = c.fill(PaletteRole.midtone);
    final dark = c.fill(PaletteRole.shadow);
    final brass = _mix(c.fill(PaletteRole.accent2), c.fill(PaletteRole.paper), 0.3);
    final paper = c.fill(PaletteRole.paper);
    final ph = brain.phase;
    final s = squashAmount;
    final sy = (1 - s).clamp(0.8, 1.2), sx = 1 / sy;
    pen
      ..reset()
      ..scale(sx, sy)
      ..scale(dir, 1);
    setBounds(-hh * 0.6, -hh * 1.3, hh * 1.7, 0);
    b.shadeAcross(Rect.fromLTWH(-hh * 0.4, -hh, hh * 0.8, hh));
    final sh = shake(903);
    final cy = _cageY.value;

    // The shaft: two rails with braces, a motor box on top, a counterweight.
    b.layer();
    for (final x in [-hh * 0.42, -hh * 0.06]) {
      b.shape(dark, ink: 0.8);
      pen.roundRect(x - hh * 0.02, -hh * 1.25, x + hh * 0.02, 0, hh * 0.006);
    }
    b.inkLine(b.lw * 0.6);
    for (var i = 0; i < 6; i++) {
      final y = -hh * 0.15 - i * hh * 0.2;
      pen
        ..moveTo(-hh * 0.4, y)
        ..lineTo(-hh * 0.08, y - hh * 0.12 * (i.isEven ? 1 : -1));
    }
    b.endLayer();
    plate(b, -hh * 0.52, -hh * 1.3, hh * 0.04, -hh * 1.18, dark, radius: hh * 0.01, rivets: 3, shade: false);
    Mechanics.gear(b, -hh * 0.24, -hh * 1.24, hh * 0.06, 9, _motor, fill: brass, holes: 0, shaded: false);
    // Counterweight runs opposite to the cage.
    final cwY = -hh * 1.1 - (cy + hh * 0.45) * 0.8;
    plate(b, -hh * 0.4, cwY - hh * 0.1, -hh * 0.2, cwY + hh * 0.1, iron, radius: hh * 0.008, rivets: 2, shade: false);
    b.layer();
    b.inkLine(b.lw * 0.7);
    pen
      ..moveTo(-hh * 0.3, cwY - hh * 0.1)
      ..lineTo(-hh * 0.3, -hh * 1.22)
      ..moveTo(-hh * 0.2, -hh * 1.22)
      ..lineTo(-hh * 0.2 + sh, cy - hh * 0.3);
    b.endLayer();

    // Far arm (cable + hook).
    _arm(b, 0, -hh * 0.3 + sh, cy - hh * 0.2, dark, brass);

    // The cage torso.
    pen
      ..save()
      ..translate(sh, cy);
    final cw = hh * 0.44, chh = hh * 0.42;
    plate(b, -cw / 2, -chh / 2, cw / 2, chh / 2, iron, radius: hh * 0.015, rivets: 4);
    // Cage bars and the sliding doors (the mouth).
    final open = _doors.value.clamp(0.0, 1.0);
    b.layer();
    b.shape(c.dark, ink: 0.8);
    pen.roundRect(-cw * 0.36, -chh * 0.1, cw * 0.36, chh * 0.42, hh * 0.006);
    if (open > 0.3) {
      b.fill(c.teeth);
      pen.moveTo(-cw * 0.36, -chh * 0.1);
      for (var i = 0; i < 6; i++) {
        final x0 = -cw * 0.36 + cw * 0.72 * i / 6;
        pen
          ..lineTo(x0 + cw * 0.06, -chh * 0.1 + chh * 0.1 * open)
          ..lineTo(x0 + cw * 0.12, -chh * 0.1);
      }
      pen.close();
    }
    // Doors slide apart.
    for (final side in const [-1.0, 1.0]) {
      final x = side * (cw * 0.18 + cw * 0.2 * open);
      b.shape(iron, ink: 0.8);
      pen.roundRect(x - cw * 0.18, -chh * 0.1, x + cw * 0.18, chh * 0.42, hh * 0.004);
      b.inkLine(b.lw * 0.5);
      for (var i = 0; i < 3; i++) {
        final lx = x - cw * 0.12 + i * cw * 0.12;
        pen
          ..moveTo(lx, -chh * 0.08)
          ..lineTo(lx, chh * 0.4);
      }
    }
    b.endLayer();
    // The floor-indicator dial: a half-moon gauge above the doors.
    final gy = -chh * 0.26, gr = cw * 0.3;
    b.layer();
    b.shape(brass);
    pen
      ..moveTo(-gr * 1.15, gy + gr * 0.15)
      ..quadTo(-gr * 1.15, gy - gr * 1.05, 0, gy - gr * 1.05)
      ..quadTo(gr * 1.15, gy - gr * 1.05, gr * 1.15, gy + gr * 0.15)
      ..close();
    b.shape(paper, ink: 0.8);
    pen
      ..moveTo(-gr, gy + gr * 0.05)
      ..quadTo(-gr, gy - gr * 0.9, 0, gy - gr * 0.9)
      ..quadTo(gr, gy - gr * 0.9, gr, gy + gr * 0.05)
      ..close();
    for (var i = 0; i < 7; i++) {
      final a = math.pi + i * math.pi / 6;
      b.inkLine(b.lw * 0.6);
      pen
        ..moveTo(math.cos(a) * gr * 0.72, gy + math.sin(a) * gr * 0.72)
        ..lineTo(math.cos(a) * gr * 0.86, gy + math.sin(a) * gr * 0.86);
    }
    // The needle points at the cage's height.
    final na = math.pi + math.pi * ((-cy - hh * 0.2) / (hh * 0.6)).clamp(0.05, 0.95);
    b.inkFill();
    pen.capsule(0, gy, math.cos(na) * gr * 0.7, gy + math.sin(na) * gr * 0.7, gr * 0.06, gr * 0.02);
    Mechanics.rivet(b, 0, gy, gr * 0.08);
    if (brain.vulnerable && emanata) {
      b.shape(c.hot.withValues(alpha: 0.3 + 0.2 * math.sin(time * 12)), ink: 0);
      pen.circle(0, gy - gr * 0.3, gr * 1.3);
    }
    b.endLayer();
    // Head box with lamp eyes and the bell.
    plate(b, -cw * 0.34, -chh * 0.5 - hh * 0.16, cw * 0.34, -chh * 0.5 + hh * 0.01, dark, radius: hh * 0.01, rivets: 2, shade: false);
    setupFace(b, 0, -chh * 0.5 - hh * 0.075, hh * 0.08, gap: 0.8, scale: 0.95, rim: brass);
    // Bell on top, swinging on the tell.
    final bellA = math.sin(time * 18) * 0.4 * _bell.value;
    pen
      ..save()
      ..rotateAbout(bellA, 0, -chh * 0.5 - hh * 0.17);
    b.layer();
    b.shape(brass);
    pen
      ..moveTo(-hh * 0.05, -chh * 0.5 - hh * 0.17)
      ..quadTo(-hh * 0.05, -chh * 0.5 - hh * 0.25, 0, -chh * 0.5 - hh * 0.26)
      ..quadTo(hh * 0.05, -chh * 0.5 - hh * 0.25, hh * 0.05, -chh * 0.5 - hh * 0.17)
      ..close();
    b.inkFill();
    pen.circle(0, -chh * 0.5 - hh * 0.165, hh * 0.012);
    b.endLayer();
    pen.restore();
    if (ph >= 1) {
      // A loose panel and sparks from the motor.
      b.layer();
      b.shape(iron, ink: 0.8);
      pen
        ..save()
        ..rotateAbout(0.35 + math.sin(time * 2.5) * 0.05, -cw * 0.5, chh * 0.3)
        ..roundRect(-cw * 0.5, chh * 0.3, -cw * 0.3, chh * 0.42, hh * 0.004)
        ..restore();
      b.endLayer();
    }
    feelings(b, 0, -chh * 0.5 - hh * 0.08, hh * 0.1);
    pen.restore();
    if (emanata && ph >= 2) Mechanics.sparks(b, -hh * 0.24, -hh * 1.24, hh * 0.04 * (1 + 0.4 * b.j(907)), 960);
    // Near arm on top.
    _arm(b, 1, cw * 0.4 + sh, cy - chh * 0.3, dark, brass);
    if (emanata && brain.mode == BossMode.telegraph && brain.attack == AttackKind.boltRain) {
      for (var i = 0; i < 3; i++) {
        Emanata.dust(b, hh * 0.3 + i * hh * 0.4, -hh * 1.2, hh * 0.08, ((time * 1.2 + i * 0.3) % 1));
      }
    }
    b.endLayer();
  }

  void _arm(InkBuild b, int i, double rootX, double rootY, Color cable, Color brass) {
    final hs = _hands[i];
    final tip = Hose.draw(b, rootX: rootX, rootY: rootY, tipX: hs.x, tipY: hs.y, length: hh * 0.6, width: hh * 0.05, bend: i == 0 ? 1 : -1, midX: (-hs.vx * 0.01).clamp(-hh * 0.1, hh * 0.1), midY: (-hs.vy * 0.01).clamp(-hh * 0.1, hh * 0.1), fill: cable, ribs: 4, salt: 60 + i * 5);
    // Hook hand: a crane hook with a clamp.
    final pen = b.pen
      ..save()
      ..translate(tip.x, tip.y)
      ..rotate(tip.angle);
    final s = hh * 0.07;
    b.layer();
    b.shape(brass);
    pen.roundRect(-s * 0.4, -s * 0.5, s * 0.5, s * 0.5, s * 0.15);
    b.shape(brass);
    pen
      ..moveTo(s * 0.4, -s * 0.4)
      ..quadTo(s * 1.5, -s * 0.9, s * 1.6, 0)
      ..quadTo(s * 1.5, s * 0.9, s * 0.9, s * 0.95)
      ..lineTo(s * 0.9, s * 0.5)
      ..quadTo(s * 1.1, s * 0.4, s * 1.05, 0)
      ..quadTo(s * 1.0, -s * 0.3, s * 0.4, -s * 0.1)
      ..close();
    Mechanics.rivet(b, 0, 0, s * 0.14);
    b.endLayer();
    pen.restore();
  }
}

// ---------------------------------------------------------------------------
// 5. The Mother-Dynamo
// ---------------------------------------------------------------------------

/// **The Mother-Dynamo** (الدينامو الأم): the generator at the heart of the
/// city – a wide riveted housing in front of a great flywheel, one huge
/// porthole eye with shutter plates (the weak spot, when they open), a
/// terminal-box mouth of sparking contacts, exhaust stacks, piston arms that
/// stamp the floor, and a railed cockpit on top where the Baron rides. It
/// combines every earlier move and winds the tempo up phase by phase.
class DynamoRig extends MachineRig {
  DynamoRig(BossBrain brain, {int seed = 0})
    : super(RigSpec(id: 'mother_dynamo', body: RigBody.ball, height: brain.kind.height, fill: PaletteRole.midtone, seed: seed), brain);

  /// The hazards (for the piston heads).
  HazardPool? hazards;

  final Spring1 _shutter = Spring1();
  final Spring1 _lean = Spring1();
  double _wheel = 0;
  double _wobble = 0;

  /// Design x of the cockpit's centre: over the housing's crown, inside the
  /// stage (further out, the right curtain hid the Baron all fight long).
  static const double _cockpitX = 0.04;

  /// The cockpit's floor in character space (where the Baron stands).
  Offset get cockpitAnchor => Offset(dir * hh * _cockpitX, -hh * 0.98 + _lean.value * hh * 0.1);

  @override
  void animate(double h) {
    // The shutter plates narrow the great eye to a slit while it attacks
    // and fly wide open – the weak spot – after each move.
    var shutter = 0.72, lean = 0.0;
    switch (brain.mode) {
      case BossMode.telegraph:
        shutter = 0.72 - 0.25 * brain.windUp;
        lean = -0.03 * brain.windUp;
      case BossMode.attack:
        shutter = 0.5;
        lean = 0.04;
      case BossMode.open:
        shutter = 1;
        lean = 0.06;
      case BossMode.dying:
        shutter = 1;
        lean = -0.15 * Bounce.out(brain.progress * 1.5);
      case BossMode.dead:
        shutter = 1;
        lean = -0.15;
      default:
    }
    _shutter.step(h, shutter, 14, 0.5);
    _lean.step(h, lean, 8, 0.5);
    final rate = brain.alive ? (1.2 + brain.phase * 1.4 + brain.windUp * 3) : math.max(0, 2.0 - brain.progress * 2.5);
    _wheel += h * rate;
    _wobble = brain.phase >= 2 ? math.sin(time * 9) * 0.04 : 0;
  }

  @override
  void build(RigPaintContext ctx) {
    final b = ink;
    b.begin(ctx, size: hh, boilFrame: boilFrame);
    final c = b.colors;
    final pen = b.pen;
    final iron = c.fill(PaletteRole.midtone);
    final dark = c.fill(PaletteRole.shadow);
    final brass = _mix(c.fill(PaletteRole.accent2), c.fill(PaletteRole.paper), 0.3);
    final ph = brain.phase;
    final s = squashAmount;
    final sy = (1 - s).clamp(0.8, 1.2), sx = 1 / sy;
    pen
      ..reset()
      ..scale(sx, sy)
      ..scale(dir, 1);
    setBounds(-hh * 0.9, -hh * 1.4, hh * 1.4, 0);
    b.shadeAcross(Rect.fromLTWH(-hh * 0.6, -hh, hh * 1.2, hh));
    final sh = shake(904);

    // The flywheel behind (wobbling in phase 2).
    pen
      ..save()
      ..translate(-hh * 0.2 + sh, -hh * 0.56)
      ..scale(1 + _wobble, 1 - _wobble);
    b.layer();
    b.shape(dark, ink: 0.9);
    pen.circle(0, 0, hh * 0.42);
    b.shape(iron, ink: 0.8);
    pen.circle(0, 0, hh * 0.34);
    b.inkLine(b.lw * 1.1);
    for (var i = 0; i < 6; i++) {
      final a = _wheel + i * math.pi / 3;
      pen
        ..moveTo(math.cos(a) * hh * 0.08, math.sin(a) * hh * 0.08)
        ..lineTo(math.cos(a) * hh * 0.33, math.sin(a) * hh * 0.33);
    }
    b.shape(brass);
    pen.circle(0, 0, hh * 0.08);
    b.endLayer();
    pen.restore();

    // Piston arms from the housing top to the floor (read from the hazards).
    final pool = hazards;
    if (pool != null) {
      for (final hz in pool.items) {
        if (!hz.active || hz.kind != HazardKind.piston) continue;
        final px = dx(hz.x);
        // Lift during the tell, drop at arming, rest on the floor while armed.
        final lift = hz.armed ? hh * 0.0 : hh * (0.55 + 0.15 * hz.telegraphProgress);
        final headBottom = -lift;
        b.layer();
        b.shape(dark, ink: 0.8);
        pen.roundRect(px - hh * 0.035, -hh * 1.05, px + hh * 0.035, headBottom - hh * 0.1, hh * 0.01);
        b.endLayer();
        plate(b, px - hh * 0.13, headBottom - hh * 0.12, px + hh * 0.13, headBottom, dark, radius: hh * 0.01, rivets: 3, shade: false);
        if (emanata && hz.armed && hz.lifeProgress < 0.6) {
          Emanata.dust(b, px - hh * 0.16, 0, hh * 0.08, hz.lifeProgress * 1.5);
          Emanata.dust(b, px + hh * 0.16, 0, hh * 0.08, hz.lifeProgress * 1.5);
        }
      }
    }
    // Overhead beam that carries the pistons.
    plate(b, -hh * 0.2, -hh * 1.1, hh * 1.4, -hh * 1.02, dark, radius: hh * 0.008, rivets: 6, shade: false);

    // The housing, leaning.
    pen
      ..save()
      ..rotateAbout(_lean.value, 0, 0)
      ..translate(sh, 0);
    plate(b, -hh * 0.5, -hh * 0.12, hh * 0.46, 0, dark, radius: hh * 0.012, rivets: 6);
    final hull = body..clear();
    hull.blob(pen, -hh * 0.03, -hh * 0.5, hh * 0.42, hh * 0.4, taper: 0.12, box: 0.5, samples: 48);
    hull.wobble(b.amp, b.frame, b.seed, 1);
    b.layer();
    b.blob(hull, iron, depth: hh * 0.1, threshold: 0.2);
    b.fill(dark);
    pen.roundRect(-hh * 0.5, -hh * 0.3, hh * 0.42, -hh * 0.26, hh * 0.006);
    b.endLayer();
    b.layer();
    for (var i = 0; i < 9; i++) {
      Mechanics.rivet(b, -hh * 0.46 + i * hh * 0.11, -hh * 0.28, hh * 0.012);
    }
    b.endLayer();
    if (ph >= 1) {
      // A blown panel: the works show.
      b.layer();
      b.shape(c.dark, ink: 0.9);
      pen
        ..moveTo(-hh * 0.45, -hh * 0.72)
        ..lineTo(-hh * 0.22, -hh * 0.75)
        ..lineTo(-hh * 0.2, -hh * 0.5)
        ..lineTo(-hh * 0.42, -hh * 0.47)
        ..close();
      b.endLayer();
      Mechanics.gear(b, -hh * 0.33, -hh * 0.62, hh * 0.07, 9, _wheel * 2, fill: brass, holes: 0, shaded: false);
      Mechanics.gear(b, -hh * 0.24, -hh * 0.55, hh * 0.05, 7, -_wheel * 2.8, fill: iron, holes: 0, shaded: false);
    }
    // Exhaust stacks.
    for (final x in [-hh * 0.4, hh * 0.36]) {
      plate(b, x - hh * 0.05, -hh * 1.0, x + hh * 0.05, -hh * 0.8, dark, radius: hh * 0.01, rivets: 1, shade: false);
    }
    // Cockpit rail on top (the Baron rides here).
    b.layer();
    b.inkLine(b.lw * 0.9);
    const k0 = _cockpitX - 0.18, k1 = _cockpitX + 0.18;
    pen
      ..moveTo(hh * k0, -hh * 0.98)
      ..lineTo(hh * k0, -hh * 1.12)
      ..lineTo(hh * k1, -hh * 1.12)
      ..lineTo(hh * k1, -hh * 0.98);
    for (var i = 1; i < 4; i++) {
      final x = hh * k0 + i * hh * 0.09;
      pen
        ..moveTo(x, -hh * 0.98)
        ..lineTo(x, -hh * 1.12);
    }
    b.shape(iron, ink: 0.8);
    pen.roundRect(hh * (k0 - 0.04), -hh * 1.0, hh * (k1 + 0.04), -hh * 0.94, hh * 0.006);
    b.endLayer();

    // The great eye: a porthole with shutter plates.
    final ex = hh * 0.12, ey = -hh * 0.62, er = hh * 0.15;
    b.layer();
    b.shape(brass);
    pen.circle(ex, ey, er * 1.2);
    b.endLayer();
    _bigEye(b, ex, ey, er, iron);
    final open = _shutter.value.clamp(0.0, 1.0);
    b.layer();
    for (final side in const [-1.0, 1.0]) {
      final slide = er * 1.25 * open;
      b.shape(dark, ink: 0.8);
      pen
        ..save()
        ..translate(ex + side * slide, ey)
        ..moveTo(0, -er * 1.15)
        ..lineTo(side * er * 1.2, -er * 1.15)
        ..lineTo(side * er * 1.2, er * 1.15)
        ..lineTo(0, er * 1.15)
        ..close()
        ..restore();
    }
    b.inkLine(b.lw * 1.0);
    pen.circle(ex, ey, er * 1.2);
    if (brain.vulnerable && emanata) {
      b.shape(c.hot.withValues(alpha: 0.3 + 0.2 * math.sin(time * 12)), ink: 0);
      pen.circle(ex, ey, er * 1.6);
    }
    b.endLayer();
    // The terminal-box mouth with sparking contacts.
    final jaw = (brain.windUp * 0.7 + (brain.mode == BossMode.attack ? 0.9 : 0) + (brain.hurtLeft > 0 ? 0.8 : 0)).clamp(0.0, 1.0);
    grateMouth(b, hh * 0.1, -hh * 0.36, hh * 0.3, jaw, bars: 5);
    b.layer();
    for (var i = 0; i < 4; i++) {
      final x = -hh * 0.02 + i * hh * 0.08;
      b.shape(brass);
      pen.circle(x, -hh * 0.22, hh * 0.018);
    }
    b.endLayer();
    if (emanata && (ph >= 2 || brain.mode == BossMode.attack && brain.attack == AttackKind.sparks)) {
      Mechanics.sparks(b, hh * 0.05, -hh * 0.22, hh * 0.04 * (1 + 0.5 * b.j(908)), 970);
      Mechanics.sparks(b, hh * 0.3, -hh * 0.24, hh * 0.035 * (1 + 0.5 * b.j(909)), 980);
    }
    if (emanata) {
      for (final x in [-hh * 0.4, hh * 0.36]) {
        Emanata.steam(b, x, -hh * 1.02, hh * 0.06 * (1 + ph * 0.3), (time * (0.9 + ph * 0.4) + x) % 1, drift: -0.3);
      }
      if (ph >= 1) Emanata.steam(b, -hh * 0.3, -hh * 0.75, hh * 0.05, (time * 1.7) % 1, drift: -0.8);
    }
    feelings(b, ex, ey, er * 1.4);
    pen.restore();
    b.endLayer();
  }

  /// One huge pie-cut eye in the porthole: white, a pupil that follows the
  /// hero, a wedge of light cut from it, a heavy riveted brow, a lid that
  /// drops on blinks and squeezes shut when hurt.
  void _bigEye(InkBuild b, double x, double y, double r, Color skin) {
    final c = b.colors;
    final pen = b.pen;
    final state = eyeStateFor;
    b.layer();
    b.shape(c.eyeWhite, ink: 0.9);
    pen.circle(x, y, r);
    if (state == EyeState.cross) {
      b.inkLine(b.lw * 1.4);
      pen
        ..moveTo(x - r * 0.5, y - r * 0.5)
        ..lineTo(x + r * 0.5, y + r * 0.5)
        ..moveTo(x + r * 0.5, y - r * 0.5)
        ..lineTo(x - r * 0.5, y + r * 0.5);
    } else if (state == EyeState.squeeze || blinkAmount > 0.95) {
      b.shape(skin, ink: 0.8);
      pen.circle(x, y, r * 1.02);
      b.brushQuad(2, x - r * 0.8, y + r * 0.05, x, y + r * 0.25, x + r * 0.8, y + r * 0.05, b.lw * 1.4);
    } else {
      final px = x + lookSpring.x * r * 0.42, py = y + lookSpring.y * r * 0.3;
      final pr = r * (brain.windUp > 0.3 ? 0.36 : 0.46);
      b.inkFill(c.dark);
      pen.ellipse(px, py, pr, pr * 1.08);
      // The pie-cut wedge of light.
      b.fill(c.eyeWhite);
      pen
        ..moveTo(px, py)
        ..lineTo(px - pr * 1.1, py - pr * 0.9)
        ..lineTo(px - pr * 0.3, py - pr * 1.15)
        ..close();
      // Upper lid for the mood.
      final lid = switch (mood) {
        RigExpression.angry => 0.35,
        RigExpression.sly => 0.45,
        RigExpression.surprised => -0.1,
        _ => 0.15,
      };
      if (lid > 0) {
        b.shape(skin, ink: 0.7);
        pen
          ..moveTo(x - r * 1.05, y - r * 1.05)
          ..lineTo(x + r * 1.05, y - r * 1.05)
          ..lineTo(x + r * 1.05, y - r * (1 - lid * 1.4))
          ..quadTo(x, y - r * (1 - lid * 0.8), x - r * 1.05, y - r * (1 - lid * 1.6))
          ..close();
      }
    }
    b.endLayer();
    // Riveted brow plate, tilted with the mood.
    final tilt = switch (mood) {
      RigExpression.angry => 0.32,
      RigExpression.sly => 0.18,
      RigExpression.surprised => -0.18,
      RigExpression.scared => -0.25,
      _ => 0.0,
    };
    b.layer();
    b.shape(c.fill(PaletteRole.shadow));
    pen
      ..save()
      ..rotateAbout(tilt, x, y - r * 1.1)
      ..roundRect(x - r * 1.1, y - r * 1.3, x + r * 1.1, y - r * 1.0, r * 0.08)
      ..restore();
    b.endLayer();
  }
}

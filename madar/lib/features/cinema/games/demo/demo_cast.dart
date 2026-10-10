import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../../engine/cinema_engine.dart';
import '../../engine/rig/rig_kit.dart';
import 'demo_sets.dart';

// The cast of "Rehearsal": the era's star from the rig cast as the hero,
// Baron Zunbruk as the mini boss in every era (he re-skins), the rolling
// hazards (one design per era, inked with the toolkit) and the boss's
// floor-shaking shockwave. Everything is pooled.

/// Who stars in each era, and how they move.
abstract final class DemoHero {
  /// The era's cast member (every one implements [RigCharacter]).
  static RigCharacter build(Era era) => switch (era) {
    Era.silent => RigCast.bean(height: 118),
    Era.rubberHose => RigCast.starBird(height: 104),
    Era.noir => RigCast.detectiveCat(height: 126),
    Era.technicolor => RigCast.camelCourier(height: 130),
    Era.grindhouse => ToonRig(
      const RigSpec(
        id: 'demo_stunt',
        body: RigBody.pear,
        height: 120,
        fill: PaletteRole.midtone,
        trim: PaletteRole.paper,
        accent: PaletteRole.accent,
        bounciness: 1.1,
      ),
      look: const ToonLook(hair: ToonHair.sprout, bowTie: false, buttons: 3, ears: false, hat: ToonHat.boater, hatFill: PaletteRole.accent2),
    ),
    Era.vhs => RigCast.neonRider(height: 112),
  };

  /// The star-bird flaps rather than jumps: a lighter arc.
  static double gravity(Era era) => era == Era.rubberHose ? 1500 : 2300;
  static double jumpSpeed(Era era) => era == Era.rubberHose ? 740 : 940;

  /// Ground speed fed to the rig (cadence) and to the set (scroll).
  static double runSpeed(Era era) => switch (era) {
    Era.technicolor => 260,
    Era.vhs => 320,
    Era.noir => 170,
    _ => 190,
  };

  /// Half-width of the hero's hit box in world units.
  static double halfWidth(Era era) => switch (era) {
    Era.technicolor => 34,
    Era.vhs => 36,
    _ => 22,
  };
}

/// What a hazard is.
enum HazardKind {
  /// Rolls in from the right along the floor (tumbling).
  roller,

  /// The boss's slam: a dust wave racing along the boards.
  wave,
}

/// A pooled hazard: launched and recycled, never re-created. The roller's
/// drawing is cached (it tumbles by canvas rotation); the wave redraws at
/// 24 fps as it grows.
class Hazard extends PositionComponent with HasGameReference<CinemaGame> {
  Hazard(this.era, {int seed = 0})
    : _roller = InkSketch(size: 56, extent: const Rect.fromLTRB(-34, -34, 34, 34), seed: seed, draw: _rollerFor(era)),
      _wave = _WaveProp(seed: seed);

  final Era era;
  final InkSketch _roller;
  final _WaveProp _wave;

  bool active = false;
  bool scored = false;
  HazardKind kind = HazardKind.roller;
  double speed = 0;
  double radius = 26;
  double spin = 0;
  double vy = 0;
  double hop = 0;
  bool flying = false;
  double age = 0;
  double? _landSpeed;
  bool _lands = false;

  /// Height of the obstacle the hero must clear.
  double get clearHeight => kind == HazardKind.wave ? 40 : radius * 1.9;

  /// Hit half-width.
  double get hitHalf => kind == HazardKind.wave ? 30 : radius * 0.9;

  /// Starts the hazard at ([x], [y]) moving left at [speed]; with [vy] it
  /// flies first and rolls on at [landSpeed] (default: [speed]) once down.
  void launch(
    double x,
    double speed, {
    HazardKind kind = HazardKind.roller,
    double y = DemoStage.groundY,
    double vy = 0,
    double? landSpeed,
  }) {
    active = true;
    scored = false;
    flying = vy != 0;
    this.kind = kind;
    this.speed = speed;
    this.vy = vy;
    _landSpeed = landSpeed;
    _lands = vy != 0;
    age = 0;
    hop = 0;
    position.setValues(x, y);
    if (kind == HazardKind.wave) _wave.markDirty();
  }

  void bounceAway() {
    flying = true;
    _lands = false;
    vy = -560;
    speed = -140;
  }

  @override
  void update(double dt) {
    if (!active) return;
    age += dt;
    position.x -= speed * dt;
    if (kind == HazardKind.wave) {
      _wave.age = age;
      if (age > 2.2 || position.x < -120) active = false;
      return;
    }
    spin -= speed * dt / radius * 0.7;
    if (flying) {
      vy += 1900 * dt;
      position.y += vy * dt;
      if (_lands && position.y >= DemoStage.groundY) {
        position.y = DemoStage.groundY;
        flying = false;
        vy = 0;
        hop = 0.9;
        speed = _landSpeed ?? speed;
      }
      if (position.y > 980) active = false;
    } else {
      // A rolling thing hops a little on the boards.
      hop = (hop + dt * speed / 42) % 1;
    }
    if (position.x < -90 || position.x > 700) active = false;
  }

  @override
  void render(Canvas canvas) {
    if (!active) return;
    final ctx = game.rigPaint;
    if (kind == HazardKind.wave) {
      _wave.paint(canvas, ctx);
      return;
    }
    final lift = flying ? 0.0 : math.sin(hop * math.pi).abs() * 9;
    final sq = flying ? 1.0 : 1 - 0.08 * math.max(0, 1 - hop * 4);
    canvas
      ..save()
      ..translate(0, -radius - lift)
      ..scale(1 / sq, sq)
      ..rotate(spin);
    _roller.paint(canvas, ctx);
    canvas.restore();
  }

  @override
  void onRemove() {
    _roller.dispose();
    _wave.dispose();
    super.onRemove();
  }

  /// The era's rolling hazard, drawn in the toolkit (radius 26).
  static void Function(InkBuild b) _rollerFor(Era era) => switch (era) {
    Era.silent => _cog,
    Era.rubberHose => _barrel,
    Era.noir => _trashCan,
    Era.technicolor => _tumbleweed,
    Era.grindhouse => _tyre,
    Era.vhs => _wireBall,
  };

  static void _cog(InkBuild b) {
    final c = b.colors;
    Mechanics.gear(b, 0, 0, 27, 10, 0, fill: c.fill(PaletteRole.midtone), hub: c.fill(PaletteRole.shadow), holes: 5);
  }

  static void _barrel(InkBuild b) {
    final pen = b.pen;
    final c = b.colors;
    final wood = c.fill(PaletteRole.midtone), band = c.fill(PaletteRole.shadow);
    b.layer();
    b.shape(wood);
    pen
      ..moveTo(-20, -27)
      ..quadTo(-32, 0, -20, 27)
      ..lineTo(20, 27)
      ..quadTo(32, 0, 20, -27)
      ..close();
    final ct = b.contour(0)..clear();
    ct.ellipse(pen, 0, 0, 26, 27, samples: 28);
    ct.writeCrescent(b.shade(), kShadowX, kShadowY, 9);
    b.fill(band);
    pen
      ..roundRect(-14, -28, -8, 28, 1.5)
      ..roundRect(8, -28, 14, 28, 1.5);
    b.inkLine(b.lw * 0.5);
    for (final y in const [-16.0, -5.0, 6.0, 17.0]) {
      final bow = y.abs() * 0.12;
      pen
        ..moveTo(-24 + bow, y)
        ..quadTo(0, y + (y < 0 ? -2 : 2), 24 - bow, y);
    }
    b.inkFill(band);
    pen.circle(0, 2, 3);
    b.endLayer();
  }

  static void _trashCan(InkBuild b) {
    final pen = b.pen;
    final c = b.colors;
    final tin = _mix(c.fill(PaletteRole.midtone), c.fill(PaletteRole.paper), 0.15), dark = c.fill(PaletteRole.shadow);
    b.layer();
    b.shape(tin);
    pen
      ..moveTo(-24, -24)
      ..lineTo(24, -24)
      ..lineTo(20, 27)
      ..lineTo(-20, 27)
      ..close();
    b.shape(tin);
    pen.roundRect(-27, -30, 27, -20, 4);
    b.shape(tin);
    pen.roundRect(-6, -36, 6, -29, 2);
    final ct = b.contour(0)..clear();
    ct.ellipse(pen, 0, 0, 23, 27, samples: 28);
    ct.writeCrescent(b.shade(), kShadowX, kShadowY, 9);
    b.inkLine(b.lw * 0.5);
    for (final y in const [-10.0, 2.0, 14.0]) {
      pen
        ..moveTo(-23 + (y + 24) * 0.07, y)
        ..lineTo(23 - (y + 24) * 0.07, y + b.ja(30, 0.6));
    }
    // A dent.
    b.fill(dark.withValues(alpha: 0.35));
    pen.ellipse(9, 8, 6, 8, 0.4);
    b.endLayer();
  }

  static void _tumbleweed(InkBuild b) {
    final pen = b.pen;
    final c = b.colors;
    final twig = _mix(c.fill(PaletteRole.midtone), c.fill(PaletteRole.shadow), 0.45);
    b.layer();
    b.shape(_mix(c.fill(PaletteRole.midtone), c.fill(PaletteRole.paper), 0.4).withValues(alpha: 0.55), ink: 0);
    pen.circle(0, 0, 25);
    b.endLayer();
    b.layer();
    for (var i = 0; i < 14; i++) {
      final a = i * math.pi * 2 / 14 + b.j(i) * 0.2;
      final r0 = 6 + 8 * boilHash01(0, b.seed, i), r1 = 24 + b.j(20 + i) * 2;
      final ca = math.cos(a), sa = math.sin(a);
      final mid = a + 0.5 + b.j(40 + i) * 0.3;
      b.brushQuad(2, ca * r0, sa * r0, math.cos(mid) * (r0 + r1) * 0.55, math.sin(mid) * (r0 + r1) * 0.55, ca * r1, sa * r1, b.lw * 0.6, color: twig, taperIn: 0.1, taperOut: 0.5);
    }
    b.inkLine(b.lw * 0.5);
    pen.circle(0, 0, 25);
    b.endLayer();
  }

  static void _tyre(InkBuild b) {
    final pen = b.pen;
    final c = b.colors;
    final rubber = _mix(c.fill(PaletteRole.ink), c.fill(PaletteRole.shadow), 0.3);
    b.layer();
    b.shape(rubber);
    pen.circle(0, 0, 27);
    final ct = b.contour(0)..clear();
    ct.ellipse(pen, 0, 0, 27, 27, samples: 28);
    ct.writeCrescent(b.shade(), kShadowX, kShadowY, 7);
    b.fill(_mix(c.fill(PaletteRole.midtone), c.fill(PaletteRole.paper), 0.3));
    pen.circle(0, 0, 13);
    b.fill(c.fill(PaletteRole.shadow));
    pen.circle(0, 0, 5);
    b.inkLine(b.lw * 0.5);
    for (var i = 0; i < 12; i++) {
      final a = i * math.pi / 6;
      pen
        ..moveTo(math.cos(a) * 21, math.sin(a) * 21)
        ..lineTo(math.cos(a + 0.12) * 27, math.sin(a + 0.12) * 27);
    }
    b.fill(c.shine.withValues(alpha: 0.35));
    pen.ellipse(-8, -9, 4, 2.5, -0.7);
    b.endLayer();
  }

  static void _wireBall(InkBuild b) {
    final pen = b.pen;
    final c = b.colors;
    b.layer();
    b.shape(_mix(c.palette.backdrop, c.palette.ink, 0.5), ink: 0.9);
    pen.circle(0, 0, 26);
    b.endLayer();
    b.layer();
    b.inkLine(b.lw * 0.8);
    pen
      ..ellipse(0, 0, 26, 10)
      ..ellipse(0, 0, 10, 26)
      ..ellipse(0, 0, 26, 20, 0.8);
    b.inkFill(c.palette.accent);
    pen.circle(0, 0, 4);
    b.endLayer();
  }
}

/// The slam's dust wave: a bank of dust that rolls along the boards with a
/// curling crest and flying splinters, redrawn at 24 fps.
class _WaveProp extends InkProp {
  _WaveProp({super.seed}) : super(size: 96, id: 'wave');

  double age = 0;

  @override
  double get drawFps => 24;

  @override
  Rect get bounds => const Rect.fromLTRB(-70, -70, 70, 10);

  @override
  void build(InkBuild b) {
    final grow = 0.55 + 0.45 * math.min(1.0, age * 2.5);
    final fade = (1 - (age - 1.6) / 0.6).clamp(0.0, 1.0);
    final k = 0.42 + 0.08 * math.sin(age * 22);
    for (var i = 0; i < 3; i++) {
      Emanata.dust(b, (i - 1) * 24.0, (i == 1 ? -6 : 0), 36 * grow * fade, k + i * 0.06);
    }
    b.layer();
    b.brushQuad(2, 34, -4, 4, -50 * grow * fade, -40, -10 * grow, b.lw * 1.1, taperIn: 0.15, taperOut: 0.35);
    b.endLayer();
    b.layer();
    for (var i = 0; i < 4; i++) {
      final a = -2.6 + i * 0.5 + b.j(70 + i) * 0.2;
      final r = (30 + 14 * i) * grow * fade;
      b.inkFill();
      b.pen.ellipse(math.cos(a) * r, math.sin(a) * r - 6, 2.4, 1.4, a);
    }
    b.endLayer();
  }
}

Color _mix(Color a, Color b, double t) => Color.lerp(a, b, t)!;

/// A pool of dust / steam puffs anywhere on stage (landings, stomps).
class PuffPool extends Component with HasGameReference<CinemaGame> {
  PuffPool({super.priority, int count = 6}) {
    for (var i = 0; i < count; i++) {
      final p = InkPuff(size: 30, life: 0.7, seed: i)..time = 10;
      _puffs.add(p);
      _x.add(0);
      _y.add(0);
    }
  }

  final List<InkPuff> _puffs = [];
  final List<double> _x = [];
  final List<double> _y = [];

  /// Starts a puff at ([x], [y]) in world units.
  void spawn(double x, double y, {double size = 30, double life = 0.7, double driftY = -30}) {
    for (var i = 0; i < _puffs.length; i++) {
      final p = _puffs[i];
      if (!p.done) continue;
      p
        ..size = size
        ..life = life
        ..drift = Offset(0, driftY)
        ..restart();
      _x[i] = x;
      _y[i] = y;
      return;
    }
  }

  @override
  void update(double dt) {
    for (final p in _puffs) {
      if (!p.done) p.update(dt);
    }
  }

  @override
  void render(Canvas canvas) {
    final ctx = game.rigPaint;
    for (var i = 0; i < _puffs.length; i++) {
      final p = _puffs[i];
      if (p.done) continue;
      canvas
        ..save()
        ..translate(_x[i], _y[i]);
      p.paint(canvas, ctx);
      canvas.restore();
    }
  }

  @override
  void onRemove() {
    for (final p in _puffs) {
      p.dispose();
    }
    super.onRemove();
  }
}

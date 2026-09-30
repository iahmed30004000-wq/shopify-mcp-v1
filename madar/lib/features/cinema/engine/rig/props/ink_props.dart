import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../../core/cinema_game.dart';
import '../../core/era_skin.dart';
import '../../core/rig.dart';
import '../ink/boil.dart';
import '../ink/ink_build.dart';
import '../motion/spring.dart';
import '../parts/face.dart';
import '../parts/mechanics.dart';

/// An inked scenery prop in the same hand-drawn style as the characters:
/// boiling lines, era ink and shading, cached drawings replayed per frame.
///
/// Origin = the prop's centre (a crate's: its bottom centre). Sizes are in
/// world units. Put one in a Flame world with [PropComponent].
abstract class InkProp {
  InkProp({required this.size, required String id, int seed = 0}) : ink = InkBuild(seed: seedOf(id) ^ seed);

  final InkBuild ink;

  /// Nominal size (diameter / width) in local units.
  double size;

  /// Animation time (seconds).
  double time = 0;

  /// Shading on/off (turn off for small or far props to save material
  /// draws; the ink line stays).
  bool shaded = true;

  int _key = -1, _boil = -1;
  EraSkin? _skin;
  double _scale = -1;
  bool _dirty = true;

  /// Drawings per second when animated (0 = only on boil changes).
  double get drawFps => 0;

  void update(double dt) => time += dt;

  void markDirty() => _dirty = true;

  void paint(Canvas canvas, RigPaintContext ctx) {
    final clock = ctx.clock;
    // Video eras (no boil) draw animated props per video frame.
    final fps = ctx.skin.ink.boilFps <= 0 && drawFps > 0 ? ctx.skin.grade.projectionFps : drawFps;
    final key = fps > 0 ? (clock.time * fps).floor() : 0;
    if (_dirty || key != _key || clock.boilFrame != _boil || !identical(ctx.skin, _skin) || ctx.pixelScale != _scale) {
      _dirty = false;
      _key = key;
      _boil = clock.boilFrame;
      _skin = ctx.skin;
      _scale = ctx.pixelScale;
      ink.time = time;
      ink.begin(ctx, size: size * sizeWeight);
      if (shaded) ink.shadeAcross(bounds);
      build(ink);
      ink.endLayer();
    }
    ink.list.replay(canvas);
  }

  /// How heavy the line is relative to a 100-unit character (big props get
  /// a lighter pen than their size suggests).
  double get sizeWeight => 0.8;

  void build(InkBuild b);

  Rect get bounds;

  void dispose() => ink.list.dispose();
}

/// Mood of a prop face.
enum PropMood { none, sleepy, happy, surprised, grumpy }

void _propFace(InkBuild b, Face f, double x, double y, double r, PropMood mood, double time, Color skin) {
  if (mood == PropMood.none) return;
  f
    ..cx = x
    ..cy = y
    ..r = r
    ..turn = 0
    ..expression = switch (mood) {
      PropMood.happy => RigExpression.happy,
      PropMood.surprised => RigExpression.surprised,
      PropMood.grumpy => RigExpression.angry,
      _ => RigExpression.neutral,
    }
    ..eyes = RigEyes.pieCut
    ..eyeScale = 0.8
    ..eyeGap = 0.25
    ..eyeY = -0.05
    ..blink = (time % 4.3) < 0.12 ? 1 : 0
    ..lookX = math.sin(time * 0.6) * 0.5
    ..lookY = 0.2
    ..eyeState = mood == PropMood.sleepy ? EyeState.shut : EyeState.auto
    ..brows = mood == PropMood.grumpy || mood == PropMood.surprised
    ..nose = NoseStyle.none
    ..skin = skin
    ..mouth = switch (mood) {
      PropMood.sleepy => MouthShape.smile,
      PropMood.happy => MouthShape.grin,
      PropMood.surprised => MouthShape.oh,
      PropMood.grumpy => MouthShape.frown,
      PropMood.none => MouthShape.closed,
    }
    ..mouthY = 0.5
    ..mouthW = 0.6
    ..salt = 900;
  f.draw(b);
}

/// A puffy cumulus cloud with a flat bottom (optionally a face).
class InkCloud extends InkProp {
  InkCloud({required super.size, this.mood = PropMood.none, this.puffs = 5, super.seed}) : super(id: 'cloud');

  PropMood mood;
  final int puffs;
  final Face _face = Face();

  @override
  double get drawFps => mood == PropMood.none ? 0 : 12;

  @override
  Rect get bounds => Rect.fromLTRB(-size * 0.55, -size * 0.42, size * 0.55, size * 0.16);

  @override
  void build(InkBuild b) {
    final pen = b.pen;
    final w = size;
    final fill = b.colors.puff;
    b.layer();
    for (var i = 0; i < puffs; i++) {
      final k = puffs == 1 ? 0.5 : i / (puffs - 1);
      final x = -w * 0.38 + k * w * 0.76;
      final r = w * (0.14 + 0.1 * math.sin(k * math.pi)) * (1 + 0.06 * boilNoise(0, b.seed, i));
      final y = -r * 0.55 + math.sin(time * 0.8 + i) * w * 0.004;
      b.shape(fill);
      pen.circle(x + b.ja(i, 0.3), y, r);
    }
    b.shape(fill);
    pen.roundRect(-w * 0.46, -w * 0.12, w * 0.46, w * 0.12, w * 0.12);
    // Shade along the underside.
    b.shade();
    pen
      ..moveTo(-w * 0.44, w * 0.02)
      ..quadTo(0, w * 0.1, w * 0.44, w * 0.0)
      ..lineTo(w * 0.42, w * 0.1)
      ..quadTo(0, w * 0.14, -w * 0.42, w * 0.1)
      ..close();
    b.endLayer();
    _propFace(b, _face, w * 0.02, -w * 0.08, w * 0.2, mood, time, fill);
  }
}

/// A five-point star that twinkles (and may smile).
class InkStar extends InkProp {
  InkStar({required super.size, this.mood = PropMood.none, this.spin = 0.4, super.seed}) : super(id: 'star');

  PropMood mood;

  /// Rotation speed (rad/s) of the twinkle wobble.
  double spin;
  final Face _face = Face();

  @override
  double get drawFps => 12;

  @override
  Rect get bounds => Rect.fromCircle(center: Offset.zero, radius: size * 0.62);

  @override
  void build(InkBuild b) {
    final pen = b.pen;
    final r = size * 0.5 * (1 + 0.06 * math.sin(time * 5));
    final rot = -math.pi / 2 + math.sin(time * spin * 2) * 0.12;
    final ct = b.contour(0)..clear();
    for (var i = 0; i < 40; i++) {
      final k = i / 40;
      final a = rot + k * math.pi * 2;
      // Puffy star radius: sharp enough to read, round enough to be cute.
      final tip = math.cos(k * math.pi * 10);
      final rr = r * (0.52 + 0.48 * math.pow((tip + 1) / 2, 1.6));
      ct.addPen(pen, math.cos(a) * rr, math.sin(a) * rr);
    }
    ct.wobble(b.amp * 0.4, b.frame, b.seed, 1);
    b.layer();
    b.blob(ct, b.colors.puff, depth: r * 0.2, threshold: 0.3);
    b.endLayer();
    // Sparkle marks.
    b.layer();
    for (var i = 0; i < 4; i++) {
      final a = i * math.pi / 2 + math.pi / 4;
      final on = ((time * 3).floor() + i) % 3 != 0;
      if (!on) continue;
      b.brushQuad(
        2,
        math.cos(a) * r * 1.05,
        math.sin(a) * r * 1.05,
        math.cos(a) * r * 1.2,
        math.sin(a) * r * 1.2,
        math.cos(a) * r * 1.35,
        math.sin(a) * r * 1.35,
        b.lw * 0.9,
      );
    }
    b.endLayer();
    _propFace(b, _face, 0, r * 0.05, r * 0.42, mood, time, b.colors.puff);
  }
}

/// A turning spur gear.
class InkGear extends InkProp {
  InkGear({required super.size, this.teeth = 12, this.speed = 0.8, this.fill = PaletteRole.midtone, super.seed})
    : super(id: 'gear');

  final int teeth;

  /// Angular speed (rad/s); negative turns the other way.
  double speed;
  PaletteRole fill;
  double angle = 0;

  @override
  double get drawFps => speed == 0 ? 0 : 24;

  @override
  void update(double dt) {
    super.update(dt);
    angle += speed * dt;
  }

  @override
  Rect get bounds => Rect.fromCircle(center: Offset.zero, radius: size * 0.52);

  @override
  void build(InkBuild b) {
    Mechanics.gear(b, 0, 0, size * 0.5, teeth, angle, fill: b.colors.fill(fill), shaded: shaded);
  }
}

/// A wooden crate (origin = bottom centre) that squashes when hit.
class InkCrate extends InkProp {
  InkCrate({required super.size, this.fill = PaletteRole.midtone, super.seed}) : super(id: 'crate');

  PaletteRole fill;
  final Spring1 _sq = Spring1();

  /// Knock it (squash / wobble).
  void hit([double amount = 0.3]) {
    _sq.kick(amount * 10);
    markDirty();
  }

  @override
  double get drawFps => _sq.value.abs() > 0.002 || _sq.velocity.abs() > 0.02 ? 24 : 0;

  @override
  void update(double dt) {
    super.update(dt);
    final steps = math.max(1, (dt * 120).ceil());
    for (var i = 0; i < steps; i++) {
      _sq.step(dt / steps, 0, 22, 0.3);
    }
  }

  @override
  Rect get bounds => Rect.fromLTRB(-size * 0.55, -size * 1.05, size * 0.55, 0);

  @override
  void build(InkBuild b) {
    final pen = b.pen;
    final c = b.colors;
    final s = size / 2;
    final sy = (1 - _sq.value).clamp(0.7, 1.3);
    pen
      ..reset()
      ..scale(1 / sy, sy);
    final wood = c.fill(fill), dark = c.fill(PaletteRole.shadow);
    b.layer();
    b.shape(wood);
    pen.roundRect(-s, -2 * s, s, 0, s * 0.06);
    b.shade();
    pen
      ..moveTo(s * 0.55, -2 * s)
      ..lineTo(s, -2 * s)
      ..lineTo(s, 0)
      ..lineTo(-s, 0)
      ..lineTo(-s, -s * 0.2)
      ..lineTo(s * 0.55, -s * 0.2)
      ..close();
    // Frame boards.
    b.inkLine(b.lw * 0.8);
    pen
      ..roundRect(-s * 0.84, -2 * s * 0.92, s * 0.84, -s * 0.16, s * 0.04)
      ..moveTo(-s * 0.84, -s * 0.2)
      ..lineTo(s * 0.84, -2 * s * 0.9);
    b.fill(dark);
    pen
      ..moveTo(-s * 0.84, -s * 0.2)
      ..lineTo(-s * 0.84, -s * 0.46)
      ..lineTo(s * 0.62, -2 * s * 0.92)
      ..lineTo(s * 0.84, -2 * s * 0.92)
      ..lineTo(s * 0.84, -2 * s * 0.8)
      ..lineTo(-s * 0.6, -s * 0.16)
      ..close();
    // Grain and nails.
    for (var i = 0; i < 3; i++) {
      final y = -2 * s * (0.3 + i * 0.22);
      b.brushQuad(
        3,
        -s * 0.7,
        y,
        -s * 0.2,
        y + b.ja(20 + i, 0.8),
        s * 0.1 - i * s * 0.2,
        y - s * 0.02,
        b.lw * 0.45,
        color: dark,
      );
    }
    for (final kx in const [-0.92, 0.92]) {
      for (final ky in const [-1.9, -0.1]) {
        Mechanics.rivet(b, kx * s, ky * s, s * 0.05);
      }
    }
    b.endLayer();
  }
}

/// A crescent moon with a sleepy face (noir rooftops, night skies).
class InkMoon extends InkProp {
  InkMoon({required super.size, this.mood = PropMood.sleepy, super.seed}) : super(id: 'moon');

  PropMood mood;

  @override
  double get drawFps => 6;

  @override
  Rect get bounds => Rect.fromCircle(center: Offset.zero, radius: size * 0.55);

  @override
  void build(InkBuild b) {
    final pen = b.pen;
    final c = b.colors;
    final r = size * 0.5;
    final ct = b.contour(0)..clear();
    // Outer arc (right side) then the inner arc back.
    for (var i = 0; i <= 20; i++) {
      final a = -math.pi * 0.62 + i / 20 * math.pi * 1.24;
      ct.addPen(pen, math.cos(a) * r, math.sin(a) * r);
    }
    for (var i = 19; i >= 1; i--) {
      final a = -math.pi * 0.62 + i / 20 * math.pi * 1.24;
      ct.addPen(pen, -r * 0.28 + math.cos(a) * r * 0.86, math.sin(a) * r * 0.8);
    }
    ct.wobble(b.amp * 0.5, b.frame, b.seed, 3);
    b.layer();
    b.blob(ct, c.puff, depth: r * 0.14);
    b.endLayer();
    // Profile face on the inner curve: a closed lid, nose bump, smile.
    if (mood != PropMood.none) {
      final ex = r * 0.68, ey = -r * 0.3;
      b.layer();
      if (mood == PropMood.sleepy) {
        b.brushQuad(2, ex - r * 0.1, ey, ex, ey + r * 0.07, ex + r * 0.1, ey, b.lw);
        final zp = (time * 0.5) % 1;
        for (var i = 0; i < 2; i++) {
          final zx = -r * 0.1 - zp * r * 0.5 - i * r * 0.25, zy = -r * 0.7 - zp * r * 0.4 - i * r * 0.2;
          final zs = r * (0.08 + 0.03 * i);
          b.inkLine(b.lw * 0.7);
          pen
            ..moveTo(zx - zs, zy - zs)
            ..lineTo(zx + zs, zy - zs)
            ..lineTo(zx - zs, zy + zs)
            ..lineTo(zx + zs, zy + zs);
        }
      } else {
        b.inkFill(c.dark);
        pen.ellipse(ex, ey, r * 0.05, r * 0.08);
      }
      b.brushQuad(2, r * 0.52, r * 0.22, r * 0.62, r * 0.36, r * 0.76, r * 0.3, b.lw);
      b.inkFill(c.dark);
      pen.circle(r * 0.56, r * 0.02, r * 0.03);
      b.endLayer();
    }
  }
}

/// A puff of smoke or steam that swells, drifts and fades out.
class InkPuff extends InkProp {
  InkPuff({required super.size, this.life = 0.9, this.drift = const Offset(0, -30), super.seed}) : super(id: 'puff');

  /// Seconds from appearance to vanishing.
  double life;
  Offset drift;

  bool get done => time >= life;

  /// Restarts the puff (pooling).
  void restart() {
    time = 0;
    markDirty();
  }

  @override
  double get drawFps => 24;

  @override
  Rect get bounds => Rect.fromCircle(center: Offset.zero, radius: size);

  @override
  void build(InkBuild b) {
    if (done) return;
    final pen = b.pen;
    final k = (time / life).clamp(0.0, 1.0);
    final grow = math.sin(math.min(1.0, k * 1.3) * math.pi * 0.92 + 0.08);
    final ox = drift.dx * k, oy = drift.dy * k;
    b.layer();
    for (var i = 0; i < 3; i++) {
      final a = i * 2.1 + 0.4;
      b.shape(b.colors.puff, ink: 0.7);
      pen.circle(ox + math.cos(a) * size * 0.3 * (0.6 + k), oy + math.sin(a) * size * 0.22, size * 0.32 * grow);
    }
    b.endLayer();
  }
}

/// A game's own inked prop: [draw] builds the drawing with the ink toolkit
/// (layers, shapes, brush strokes, crescents) and gets the same boil,
/// era colours, shading and caching as the built-in props. Create the
/// callback once (not per frame).
///
/// ```dart
/// final barrel = InkSketch(size: 60, extent: Rect.fromCircle(center: Offset.zero, radius: 32), draw: (b) {
///   b.layer();
///   b.shape(b.colors.fill(PaletteRole.midtone));
///   b.pen.circle(0, 0, 30);
///   b.endLayer();
/// });
/// ```
class InkSketch extends InkProp {
  InkSketch({required super.size, required this.draw, required this.extent, this.fps = 0, super.seed})
    : super(id: 'sketch');

  final void Function(InkBuild b) draw;

  /// Local bounds of the drawing.
  final Rect extent;

  /// Drawings per second when the sketch animates with [time] (0 = only
  /// on boil changes).
  final double fps;

  @override
  double get drawFps => fps;

  @override
  Rect get bounds => extent;

  @override
  void build(InkBuild b) => draw(b);
}

/// Puts an [InkProp] into a Flame world (anchor = the prop's origin).
class PropComponent extends PositionComponent with HasGameReference<CinemaGame> {
  PropComponent({required this.prop, super.position, super.priority}) : super(anchor: Anchor.topLeft);

  final InkProp prop;

  @override
  void update(double dt) => prop.update(dt);

  @override
  void render(Canvas canvas) => prop.paint(canvas, game.rigPaint);

  @override
  void onRemove() {
    prop.dispose();
    super.onRemove();
  }
}

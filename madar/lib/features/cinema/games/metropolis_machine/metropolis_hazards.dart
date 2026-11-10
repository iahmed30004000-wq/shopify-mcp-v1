import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../../engine/cinema_engine.dart';
import '../../engine/rig/rig_kit.dart';
import 'metropolis_rules.dart';

// Painters of the pooled hazards and the lift platforms. Telegraph markers
// (where the press will land, which column the cable targets, the height a
// hook will sweep) go behind the cast; the dangers themselves (steam
// columns, dust waves, rivets, sparks, bolts, cogs) are inked sketches in
// front of it, one cached drawing per pool slot, redrawn at 24 fps while
// they move. Reused paints and paths only.

Color _mix(Color a, Color b, double t) => Color.lerp(a, b, t)!;

/// Telegraph markers on the floor and in the air (behind the cast).
class HazardTelegraphs extends Component with HasGameReference<CinemaGame> {
  HazardTelegraphs(this.pool, {super.priority});

  final HazardPool pool;
  final Paint _fill = Paint();
  final Paint _line = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  final Path _path = Path();

  @override
  void render(Canvas canvas) {
    final pal = game.skin.palette;
    final t = game.clock.time;
    final boil = game.clock.boilFrame;
    for (final h in pool.items) {
      if (!h.active || h.armed) continue;
      final k = h.telegraphProgress;
      final pulse = 0.5 + 0.5 * math.sin(t * (8 + 10 * k));
      switch (h.kind) {
        case HazardKind.stamp || HazardKind.piston:
          // The head's shadow grows on the floor; a boiling target cross.
          final w = h.w * (0.5 + 0.5 * k);
          _fill.color = pal.ink.withValues(alpha: 0.18 + 0.25 * k);
          canvas.drawOval(Rect.fromCenter(center: Offset(h.x, h.y - 2), width: w, height: w * 0.22), _fill);
          _line
            ..color = pal.ink.withValues(alpha: 0.35 + 0.5 * pulse * k)
            ..strokeWidth = 2.2;
          final r = h.w * 0.32;
          final j = boilNoise(boil, h.salt, 1) * 2;
          _path
            ..reset()
            ..moveTo(h.x - r, h.y - 8 + j)
            ..lineTo(h.x + r, h.y - 4 - j)
            ..moveTo(h.x - r * 0.9, h.y - 2 - j)
            ..lineTo(h.x + r * 0.9, h.y - 10 + j);
          canvas.drawPath(_path, _line);
        case HazardKind.cableStab:
          // A dotted plumb line from above and a glow where it will land.
          _line
            ..color = pal.ink.withValues(alpha: 0.25 + 0.5 * k * pulse)
            ..strokeWidth = 2;
          for (var y = h.y - h.h - 120.0; y < h.y - 10; y += 16) {
            canvas.drawLine(Offset(h.x, y), Offset(h.x, y + 7), _line);
          }
          _fill.color = pal.ink.withValues(alpha: 0.15 + 0.3 * k);
          canvas.drawOval(Rect.fromCenter(center: Offset(h.x, h.y - 2), width: h.w * (0.8 + k), height: h.w * 0.25), _fill);
        case HazardKind.steamJet:
          // The vent cap rattles and leaks.
          _line
            ..color = pal.ink.withValues(alpha: 0.5)
            ..strokeWidth = 2;
          final jx = boilNoise(boil, h.salt, 3) * 3 * k;
          canvas.drawLine(Offset(h.x - 22 + jx, h.y - 6), Offset(h.x + 22 + jx, h.y - 6), _line);
          for (var i = 0; i < 3; i++) {
            final a = (t * 3 + i * 0.33) % 1;
            _fill.color = pal.paper.withValues(alpha: (0.55 - a * 0.5) * k);
            canvas.drawCircle(Offset(h.x - 12 + i * 12 + math.sin(a * 6) * 4, h.y - 8 - a * 50), 5 + a * 9, _fill);
          }
        case HazardKind.grab:
          // Where the hook will sweep.
          _line
            ..color = pal.ink.withValues(alpha: 0.2 + 0.4 * k * pulse)
            ..strokeWidth = 2;
          final y = h.y - h.h * 0.5;
          for (var x = MetroStage.heroMinX - 10; x < h.x; x += 18) {
            canvas.drawLine(Offset(x, y), Offset(x + 8, y), _line);
          }
        case HazardKind.bolt:
          // Dust shakes loose where a bolt will fall.
          _fill.color = pal.paper.withValues(alpha: 0.3 * k);
          canvas.drawCircle(Offset(h.x, h.y - h.h + 10), 6 + 6 * pulse, _fill);
        default:
      }
    }
  }
}

/// The dangers themselves, inked, in front of the cast.
class HazardSketches extends Component with HasGameReference<CinemaGame> {
  HazardSketches(this.pool, {super.priority}) {
    for (var i = 0; i < pool.items.length; i++) {
      final h = pool.items[i];
      _sketches.add(
        InkSketch(size: 70, extent: const Rect.fromLTRB(-160, -420, 160, 30), fps: 24, seed: i, draw: (b) => _draw(b, h))..shaded = false,
      );
    }
  }

  final HazardPool pool;
  final List<InkSketch> _sketches = [];
  final Paint _glow = Paint();

  @override
  void update(double dt) {
    for (var i = 0; i < pool.items.length; i++) {
      final h = pool.items[i];
      if (h.active) _sketches[i].update(dt);
    }
  }

  @override
  void render(Canvas canvas) {
    final ctx = game.rigPaint;
    final pal = game.skin.palette;
    for (var i = 0; i < pool.items.length; i++) {
      final h = pool.items[i];
      if (!h.active) continue;
      final wantsSketch = switch (h.kind) {
        HazardKind.stamp || HazardKind.piston || HazardKind.cableStab || HazardKind.grab => h.armed,
        HazardKind.cableSweep => false,
        _ => true,
      };
      if (!wantsSketch) continue;
      if (h.kind.parryable && h.armed) {
        // Parryable things glow so they read as "hit me".
        _glow.color = (h.parried ? pal.highlight : pal.footlight).withValues(alpha: 0.28);
        canvas.drawCircle(Offset(h.x, h.y - h.h / 2), h.w * 0.9, _glow);
      }
      canvas
        ..save()
        ..translate(h.x, h.y);
      _sketches[i].paint(canvas, ctx);
      canvas.restore();
    }
  }

  @override
  void onRemove() {
    for (final s in _sketches) {
      s.dispose();
    }
    super.onRemove();
  }

  static void _draw(InkBuild b, Hazard h) {
    if (!h.active) return;
    final c = b.colors;
    final pen = b.pen;
    final age = h.age;
    switch (h.kind) {
      case HazardKind.stamp || HazardKind.piston:
        // Impact: a burst of dust and splinters at the floor.
        final k = h.lifeProgress;
        Emanata.dust(b, -h.w * 0.4, 0, h.w * 0.3, k);
        Emanata.dust(b, h.w * 0.4, 0, h.w * 0.3, k);
        b.layer();
        for (var i = 0; i < 5; i++) {
          final a = -math.pi * (0.2 + i * 0.15) + b.j(i) * 0.1;
          final r = h.w * (0.5 + 0.5 * k);
          b.inkFill();
          pen.ellipse(math.cos(a) * r, math.sin(a) * r * 0.8 - 6, 3, 1.6, a);
        }
        b.endLayer();
      case HazardKind.shockwave:
        // A bank of dust rolling along the floor with a curling crest.
        final dir = h.vx >= 0 ? 1.0 : -1.0;
        final grow = 0.6 + 0.4 * math.min(1.0, age * 3);
        final fade = (1 - (h.lifeProgress - 0.7) / 0.3).clamp(0.0, 1.0);
        for (var i = 0; i < 3; i++) {
          Emanata.dust(b, (i - 1) * h.w * 0.25 * dir, (i == 1 ? -4 : 0), h.h * 0.55 * grow * fade, 0.42 + i * 0.07 + 0.08 * math.sin(age * 20));
        }
        b.layer();
        b.brushQuad(2, dir * h.w * 0.3, -4, dir * h.w * 0.05, -h.h * 0.9 * grow * fade, -dir * h.w * 0.35, -h.h * 0.25 * grow, b.lw * 1.1, taperIn: 0.15, taperOut: 0.35);
        b.endLayer();
      case HazardKind.steamJet:
        // A column of steam from the vent, bulging as it rises.
        final k = h.lifeProgress;
        final hgt = h.h * (k < 0.15 ? k / 0.15 : (k > 0.8 ? (1 - k) / 0.2 : 1.0));
        b.layer();
        final n = 7;
        for (var i = 0; i < n; i++) {
          final y = -hgt * (i + 0.5) / n;
          final r = h.w * (0.3 + 0.22 * i / n) * (1 + 0.1 * b.j(10 + i));
          final x = math.sin(age * 9 + i * 1.7) * h.w * 0.08;
          b.shape(c.puff, ink: 0.7);
          pen.circle(x, y, r);
        }
        b.endLayer();
        b.layer();
        b.inkLine(b.lw * 0.6);
        pen
          ..moveTo(-h.w * 0.18, -hgt * 0.2)
          ..quadTo(-h.w * 0.1 + b.ja(20, 2), -hgt * 0.6, -h.w * 0.22, -hgt * 0.9)
          ..moveTo(h.w * 0.15, -hgt * 0.1)
          ..quadTo(h.w * 0.25 + b.ja(21, 2), -hgt * 0.5, h.w * 0.1, -hgt * 0.8);
        b.endLayer();
      case HazardKind.steamBlast:
        // A rolling bank of steam hugging the floor.
        final dir = h.vx >= 0 ? 1.0 : -1.0;
        b.layer();
        for (var i = 0; i < 4; i++) {
          final x = -dir * h.w * (0.35 - i * 0.22), r = h.h * (0.34 + 0.08 * (i == 1 || i == 2 ? 1 : 0)) * (1 + 0.08 * math.sin(age * 12 + i));
          b.shape(c.puff, ink: 0.7);
          pen.circle(x, -r * 0.95, r);
        }
        b.endLayer();
        b.layer();
        b.brushQuad(2, dir * h.w * 0.25, -h.h * 0.5, dir * h.w * 0.1, -h.h * 0.9, -dir * h.w * 0.15, -h.h * 0.75, b.lw * 0.8, taperIn: 0.2, taperOut: 0.6);
        b.endLayer();
      case HazardKind.rivet:
        // A red-hot rivet with a trail; a glint when it flies back.
        final a = math.atan2(h.vy, h.vx);
        b.layer();
        pen
          ..save()
          ..rotate(a);
        b.shape(h.parried ? c.fill(PaletteRole.paper) : c.hot, ink: 0.9);
        pen.roundRect(-h.w * 0.4, -h.w * 0.25, h.w * 0.3, h.w * 0.25, h.w * 0.1);
        b.shape(h.parried ? c.fill(PaletteRole.paper) : c.hot, ink: 0.9);
        pen.circle(h.w * 0.3, 0, h.w * 0.32);
        b.inkLine(b.lw * 0.7);
        for (var i = 0; i < 3; i++) {
          pen
            ..moveTo(-h.w * 0.6, (i - 1) * h.w * 0.2)
            ..lineTo(-h.w * (1.1 + 0.3 * i), (i - 1) * h.w * 0.28);
        }
        pen.restore();
        b.endLayer();
        if (h.parried) Emanata.sparkles(b, 0, -h.w * 0.2, h.w * 0.8, age);
      case HazardKind.cableStab:
        // Impact dust where the plug struck; the Dynamo's own cable and
        // plug drop from the beam (param 1), the Spider's stinger is its rig.
        final k = h.lifeProgress;
        if (h.param == 1) {
          _plugOnCable(b, 0, -400 + b.ja(50, 3), 0, -h.h * 0.1, h.w);
        }
        Emanata.dust(b, -h.w * 0.5, 0, h.w * 0.5, k);
        Emanata.dust(b, h.w * 0.5, 0, h.w * 0.5, k);
      case HazardKind.cableSweep:
        if (h.param == 1) {
          final dir = h.vx >= 0 ? 1.0 : -1.0;
          _plugOnCable(b, -dir * 160, -420, 0, -h.h * 0.3, h.w * 0.5);
          Emanata.dust(b, 0, 0, h.w * 0.4, ((age * 2) % 1));
        }
      case HazardKind.bolt:
        // A hex bolt tumbling down with motion lines.
        b.layer();
        pen
          ..save()
          ..rotate(age * 5);
        b.shape(c.fill(PaletteRole.shadow));
        pen.polygon([for (var i = 0; i < 6; i++) ...[math.cos(i * math.pi / 3) * h.w * 0.5, math.sin(i * math.pi / 3) * h.w * 0.5 - h.h * 0.7]]);
        b.shape(c.fill(PaletteRole.midtone), ink: 0.8);
        pen.roundRect(-h.w * 0.2, -h.h * 0.55, h.w * 0.2, 0, h.w * 0.08);
        b.inkLine(b.lw * 0.5);
        for (var i = 0; i < 3; i++) {
          final y = -h.h * 0.45 + i * h.h * 0.14;
          pen
            ..moveTo(-h.w * 0.2, y)
            ..lineTo(h.w * 0.2, y - 2);
        }
        pen.restore();
        b.endLayer();
        if (h.vy > 200) {
          b.layer();
          for (var i = 0; i < 3; i++) {
            b.inkLine(b.lw * 0.5);
            pen
              ..moveTo((i - 1) * h.w * 0.4, -h.h - 10)
              ..lineTo((i - 1) * h.w * 0.4 + b.ja(30 + i), -h.h - 34 - i * 6);
          }
          b.endLayer();
        }
      case HazardKind.spark:
        // A crackling ball of sparks rolling along.
        Mechanics.sparks(b, 0, -h.h * 0.5, h.w * 0.42 * (1 + 0.15 * b.j(40)), 41);
        b.layer();
        b.shape(h.parried ? c.fill(PaletteRole.paper) : c.hot, ink: 0.8);
        pen.circle(0, -h.h * 0.5, h.w * 0.25);
        b.endLayer();
      case HazardKind.cog:
        Mechanics.gear(b, 0, -h.h * 0.5, h.w * 0.5, 8, age * 9, fill: c.fill(h.parried ? PaletteRole.paper : PaletteRole.midtone), holes: 0, shaded: false);
      case HazardKind.grab:
        // Speed lines along the hook's path.
        final dir = h.vx >= 0 ? 1.0 : -1.0;
        Emanata.speedLines(b, dir * h.w * 0.5, -h.h, 0, dir, 0.9);
    }
  }
}

/// A cable from ([x0], [y0]) down to a jack plug whose tip is at ([x1], [y1]).
void _plugOnCable(InkBuild b, double x0, double y0, double x1, double y1, double size) {
  final c = b.colors;
  final pen = b.pen;
  final cable = _mix(c.fill(PaletteRole.shadow), c.ink, 0.3);
  final brass = _mix(c.fill(PaletteRole.accent2), c.fill(PaletteRole.paper), 0.3);
  b.layer();
  b.stroke(cable, b.lw * 1.4);
  pen
    ..moveTo(x0, y0)
    ..quadTo((x0 + x1) / 2 + b.ja(60, 4), (y0 + y1) / 2, x1, y1 - size * 0.8);
  b.shape(brass);
  pen.roundRect(x1 - size * 0.3, y1 - size * 0.9, x1 + size * 0.3, y1 - size * 0.35, size * 0.08);
  b.shape(c.fill(PaletteRole.shadow), ink: 0.8);
  pen.roundRect(x1 - size * 0.18, y1 - size * 0.4, x1 + size * 0.18, y1, size * 0.08);
  b.endLayer();
}

/// The lift cars of the Lift-Titan hall (and the Dynamo's one): a riveted
/// cage on a cable up to the shaft top, a sheave turning at the top.
class PlatformPainter extends Component with HasGameReference<CinemaGame> {
  PlatformPainter(this.platforms, {super.priority}) {
    _car = InkSketch(
      size: 90,
      extent: const Rect.fromLTRB(-50, -30, 50, 24),
      draw: (b) {
        final c = b.colors;
        final pen = b.pen;
        final iron = _mix(c.fill(PaletteRole.midtone), c.fill(PaletteRole.shadow), 0.3);
        final dark = c.fill(PaletteRole.shadow);
        b.layer();
        b.shape(iron);
        pen.roundRect(-45, 0, 45, 14, 3);
        b.shape(dark);
        pen.roundRect(-47, -3, 47, 2, 1);
        // Railing.
        b.inkLine(b.lw * 0.7);
        pen
          ..moveTo(-42, -2)
          ..lineTo(-42, -26)
          ..lineTo(42, -26 + b.ja(2, 0.5))
          ..lineTo(42, -2)
          ..moveTo(-14, -2)
          ..lineTo(-14, -26)
          ..moveTo(14, -2)
          ..lineTo(14, -26);
        Mechanics.rivet(b, -36, 8, 2.2);
        Mechanics.rivet(b, -12, 8, 2.2);
        Mechanics.rivet(b, 12, 8, 2.2);
        Mechanics.rivet(b, 36, 8, 2.2);
        // Suspension bracket.
        b.shape(dark);
        pen
          ..moveTo(-6, -26)
          ..lineTo(6, -26)
          ..lineTo(0, -40)
          ..close();
        b.endLayer();
      },
    );
  }

  final List<MovingPlatform> platforms;
  late final InkSketch _car;
  final Paint _line = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;

  @override
  void render(Canvas canvas) {
    final ctx = game.rigPaint;
    final pal = game.skin.palette;
    for (final p in platforms) {
      if (!p.active) continue;
      _line
        ..color = pal.ink
        ..strokeWidth = 2.4;
      canvas.drawLine(Offset(p.x, p.y - 38), Offset(p.x, -400), _line);
      canvas
        ..save()
        ..translate(p.x, p.y);
      _car.paint(canvas, ctx);
      canvas.restore();
    }
  }

  @override
  void onRemove() {
    _car.dispose();
    super.onRemove();
  }
}

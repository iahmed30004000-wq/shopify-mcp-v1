import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../../engine/cinema_engine.dart';
import '../../engine/rig/rig_kit.dart';
import 'flappy_orbit_gates.dart';

// The painted set of "Flappy Orbit": a dusk sky with a sleepy moon and
// twinkling stars, a far skyline of domes and stepped towers that bounces
// on the beat, rooftops with water towers and chimneys sliding by, the
// rooftop ledge the hero launches from (and crashes onto), all inked with
// the rig toolkit so scenery and cast come from the same pen. Nothing is
// allocated per frame: drawings rebuild on boil frames and replay between.

Color _mix(Color a, Color b, double t) => Color.lerp(a, b, t)!;

/// A prop placed on a set tile at ([x], [y]) in world units.
class PlacedProp {
  PlacedProp(this.prop, this.x, this.y);

  final InkProp prop;
  final double x, y;
}

/// One parallax plane: cached inked props repeating every [period] units,
/// sliding by [parallax] × the world's scroll. With [bounce] the plane
/// squashes on the beat about [groundY] (the cartoon skyline dancing).
class ParallaxLayer extends Component with HasGameReference<CinemaGame> {
  ParallaxLayer({
    required this.parallax,
    required this.period,
    required this.props,
    required this.scroll,
    this.beat,
    this.bounce = 0,
    this.groundY = OrbitStage.groundY,
    super.priority,
  }) {
    OrbitAllocations.note();
  }

  final double parallax;
  final double period;
  final List<PlacedProp> props;
  final double Function() scroll;
  final double Function()? beat;
  final double bounce;
  final double groundY;

  @override
  void update(double dt) {
    for (final p in props) {
      p.prop.update(dt);
    }
  }

  @override
  void render(Canvas canvas) {
    final off = (scroll() * parallax) % period;
    final ctx = game.rigPaint;
    final copies = ((OrbitStage.paintRight - OrbitStage.paintLeft) / period).ceil() + 1;
    canvas.save();
    if (bounce > 0 && beat != null) {
      final k = Bounce.contact(beat!());
      final sy = 1 - bounce * k, sx = 1 + bounce * 0.5 * k;
      canvas
        ..translate(0, groundY)
        ..scale(sx, sy)
        ..translate(0, -groundY);
    }
    for (final p in props) {
      final b = p.prop.bounds;
      for (var k = -1; k <= copies; k++) {
        final x = p.x + k * period - off;
        if (x + b.right < OrbitStage.paintLeft || x + b.left > OrbitStage.paintRight) continue;
        canvas
          ..save()
          ..translate(x, p.y);
        p.prop.paint(canvas, ctx);
        canvas.restore();
      }
    }
    canvas.restore();
  }

  @override
  void onRemove() {
    for (final p in props) {
      p.prop.dispose();
    }
    super.onRemove();
  }
}

/// The dusk sky: a vertical gradient (built once) and a soft glow low on
/// the horizon.
class DuskSky extends Component with HasGameReference<CinemaGame> {
  DuskSky({super.priority}) {
    OrbitAllocations.note();
  }

  final Paint _fill = Paint();
  Shader? _gradient;
  static const Rect _rect = Rect.fromLTRB(OrbitStage.paintLeft - 200, -500, OrbitStage.paintRight + 200, OrbitStage.height + 500);

  @override
  void render(Canvas canvas) {
    final pal = game.skin.palette;
    _gradient ??= Gradient.linear(
      const Offset(0, -200),
      const Offset(0, OrbitStage.groundY),
      [_mix(pal.backdrop, pal.shadow, 0.35), pal.backdrop, _mix(pal.backdrop, pal.paper, 0.55)],
      const [0, 0.5, 1],
    );
    _fill.shader = _gradient;
    canvas.drawRect(_rect, _fill);
    _fill.shader = null;
  }
}

/// A sketch helper: a tile [w] wide whose drawing stands on y = 0.
InkSketch _tile(double w, double h, void Function(InkBuild b) draw, {double fps = 0, int seed = 0}) =>
    InkSketch(size: 120, extent: Rect.fromLTRB(-20, -h, w + 20, 6), fps: fps, seed: seed, draw: draw);

/// A flat-topped silhouette block with setbacks.
void _block(InkBuild b, double x, double w, double h, Color fill, {double ink = 0.6, int steps = 0}) {
  final pen = b.pen;
  b.shape(fill, ink: ink);
  var l = x;
  final r = x + w;
  pen
    ..moveTo(l, 4)
    ..lineTo(l, -h * (steps == 0 ? 1 : 0.62));
  for (var i = 0; i < steps; i++) {
    l += w * 0.1;
    pen
      ..lineTo(l, -h * (0.62 + 0.38 * i / steps))
      ..lineTo(l, -h * (0.62 + 0.38 * (i + 1) / steps));
  }
  pen.lineTo(l, -h);
  var rr = r;
  for (var i = steps - 1; i >= 0; i--) {
    rr = r - w * 0.1 * (i + 1);
    pen
      ..lineTo(rr, -h * (0.62 + 0.38 * (i + 1) / steps))
      ..lineTo(rr, -h * (0.62 + 0.38 * i / steps));
  }
  pen
    ..lineTo(r, steps == 0 ? -h : -h * 0.62)
    ..lineTo(r, 4)
    ..close();
}

/// Rows of lit windows inside a block.
void _windows(InkBuild b, double x, double w, double h, double cell, Color lit, {double litShare = 0.5, int salt = 0}) {
  final pen = b.pen;
  final cols = (w / cell).floor(), rows = (h / cell).floor();
  b.fill(lit);
  for (var r = 0; r < rows; r++) {
    for (var c = 0; c < cols; c++) {
      if (boilHash01(0, b.seed + salt, r * 31 + c) > litShare) continue;
      final wx = x + cell * (c + 0.3), wy = -cell * (r + 0.75);
      pen.roundRect(wx, wy, wx + cell * 0.42, wy + cell * 0.5, cell * 0.06);
    }
  }
}

/// A dome on a drum with a finial.
void _dome(InkBuild b, double x, double w, double h, Color fill) {
  final pen = b.pen;
  b.shape(fill, ink: 0.6);
  pen.roundRect(x - w * 0.5, -h * 0.55, x + w * 0.5, 4, 2);
  b.shape(fill, ink: 0.6);
  pen
    ..moveTo(x - w * 0.5, -h * 0.55)
    ..cubicTo(x - w * 0.55, -h * 0.95, x + w * 0.55, -h * 0.95, x + w * 0.5, -h * 0.55)
    ..close();
  b.shape(fill, ink: 0.6);
  pen.roundRect(x - 2, -h * 1.08, x + 2, -h * 0.9, 1);
  b.shape(fill, ink: 0.6);
  pen.circle(x, -h * 1.1, 3.5);
}

/// A slender tower with a balcony and a pointed cap.
void _tower(InkBuild b, double x, double h, Color fill) {
  final pen = b.pen;
  b.shape(fill, ink: 0.6);
  pen.roundRect(x - 7, -h, x + 7, 4, 2);
  b.shape(fill, ink: 0.6);
  pen.roundRect(x - 12, -h * 0.72, x + 12, -h * 0.66, 2);
  b.shape(fill, ink: 0.6);
  pen
    ..moveTo(x - 9, -h)
    ..lineTo(x, -h - 22)
    ..lineTo(x + 9, -h)
    ..close();
}

/// A water tower on four legs with a conical roof.
void _waterTower(InkBuild b, double x, double y, double s, Color tank, Color legs) {
  final pen = b.pen;
  b.layer();
  b.shape(legs, ink: 0.7);
  for (final k in const [-0.3, -0.12, 0.12, 0.3]) {
    pen
      ..moveTo(x + k * s, y - s * 0.55)
      ..lineTo(x + k * s * 1.25 - s * 0.02, y)
      ..lineTo(x + k * s * 1.25 + s * 0.02, y)
      ..lineTo(x + k * s + s * 0.04, y - s * 0.55)
      ..close();
  }
  b.endLayer();
  b.layer();
  b.shape(tank);
  pen.roundRect(x - s * 0.36, y - s * 1.1, x + s * 0.36, y - s * 0.5, s * 0.05);
  b.shape(tank);
  pen
    ..moveTo(x - s * 0.42, y - s * 1.08)
    ..lineTo(x, y - s * 1.36)
    ..lineTo(x + s * 0.42, y - s * 1.08)
    ..close();
  final c = b.contour(0)..clear();
  c.ellipse(pen, x, y - s * 0.8, s * 0.36, s * 0.3, samples: 24);
  c.writeCrescent(b.shade(), kShadowX, kShadowY, s * 0.1);
  b.inkLine(b.lw * 0.6);
  for (final k in const [0.62, 0.75, 0.95]) {
    pen
      ..moveTo(x - s * 0.36, y - s * k)
      ..lineTo(x + s * 0.36, y - s * k);
  }
  b.endLayer();
}

/// A rooftop box with a parapet, a door and a chimney.
void _rooftop(InkBuild b, double x, double w, double h, Color wall, Color dark, {bool chimney = true, int salt = 0}) {
  final pen = b.pen;
  b.layer();
  b.shape(wall);
  pen.roundRect(x, -h, x + w, 4, 2);
  b.shape(wall);
  pen.roundRect(x - 6, -h - 8, x + w + 6, -h + 4, 2);
  final c = b.contour(0)..clear();
  c.ellipse(pen, x + w / 2, -h / 2, w / 2, h / 2, samples: 24);
  c.writeCrescent(b.shade(), kShadowX, kShadowY, w * 0.12);
  // A door and a window on the wall.
  b.fill(dark);
  pen.roundRect(x + w * 0.15, -h * 0.55, x + w * 0.32, 0, 3);
  b.shape(b.colors.puff, ink: 0.7);
  pen.roundRect(x + w * 0.55, -h * 0.7, x + w * 0.82, -h * 0.4, 2);
  b.inkLine(b.lw * 0.5);
  pen
    ..moveTo(x + w * 0.685, -h * 0.7)
    ..lineTo(x + w * 0.685, -h * 0.4)
    ..moveTo(x + w * 0.55, -h * 0.55)
    ..lineTo(x + w * 0.82, -h * 0.55);
  if (chimney) {
    b.shape(dark);
    pen.roundRect(x + w * 0.7, -h - 34, x + w * 0.88, -h, 2);
    b.shape(dark);
    pen.roundRect(x + w * 0.66, -h - 40, x + w * 0.92, -h - 32, 2);
  }
  b.endLayer();
}

/// A laundry line between two poles with clothes that swing.
void _laundry(InkBuild b, double x0, double x1, double y, double sway, Color cloth, Color pole) {
  final pen = b.pen;
  b.layer();
  b.shape(pole, ink: 0.8);
  pen.roundRect(x0 - 2, y - 2, x0 + 2, 60, 1);
  b.shape(pole, ink: 0.8);
  pen.roundRect(x1 - 2, y - 2, x1 + 2, 60, 1);
  b.inkLine(b.lw * 0.5);
  pen
    ..moveTo(x0, y)
    ..quadTo((x0 + x1) / 2, y + 10, x1, y);
  for (var i = 0; i < 4; i++) {
    final k = (i + 1) / 5;
    final cx = x0 + (x1 - x0) * k, cy = y + 10 * 4 * k * (1 - k);
    final s = sway * (1 + 0.3 * i);
    b.shape(i.isEven ? cloth : b.colors.puff, ink: 0.7);
    if (i == 1) {
      pen
        ..moveTo(cx - 9, cy)
        ..lineTo(cx + 9, cy)
        ..lineTo(cx + 12 + s, cy + 26)
        ..lineTo(cx - 6 + s, cy + 26)
        ..close();
    } else {
      pen
        ..moveTo(cx - 8, cy)
        ..lineTo(cx + 8, cy)
        ..lineTo(cx + 7 + s, cy + 20)
        ..lineTo(cx - 7 + s, cy + 20)
        ..close();
    }
  }
  b.endLayer();
}

/// Builds the set components of the game (back to front).
List<Component> buildOrbitSet(CinemaGame game, double Function() scroll, double Function() beat) {
  final sky = DuskSky(priority: -60);
  final moon = InkMoon(size: 110, mood: PropMood.sleepy);
  final starA = InkStar(size: 26, spin: 0.3);
  final starB = InkStar(size: 20, spin: 0.5, seed: 3);
  final starC = InkStar(size: 16, spin: 0.4, seed: 5);
  final cloudA = InkCloud(size: 150, mood: PropMood.happy, seed: 1);
  final cloudB = InkCloud(size: 100, seed: 2);
  final cloudC = InkCloud(size: 120, mood: PropMood.sleepy, seed: 4);
  final far = _tile(600, 420, (b) {
    final c = b.colors;
    final dark = _mix(c.fill(PaletteRole.shadow), c.fill(PaletteRole.backdrop), 0.4);
    final lit = _mix(c.fill(PaletteRole.paper), c.palette.footlight, 0.5);
    b.layer();
    _block(b, 0, 60, 200, dark);
    _block(b, 70, 110, 330, dark, steps: 3);
    _dome(b, 230, 90, 160, dark);
    _tower(b, 300, 300, dark);
    _block(b, 330, 80, 230, dark, steps: 1);
    _dome(b, 455, 60, 120, dark);
    _block(b, 500, 100, 280, dark, steps: 2);
    _windows(b, 4, 52, 180, 12, lit, litShare: 0.45, salt: 1);
    _windows(b, 74, 102, 300, 12, lit, litShare: 0.4, salt: 2);
    _windows(b, 334, 72, 205, 12, lit, litShare: 0.5, salt: 3);
    _windows(b, 504, 92, 250, 12, lit, litShare: 0.42, salt: 4);
    b.endLayer();
  }, seed: 1)..shaded = false;
  final mid = _tile(520, 260, (b) {
    final c = b.colors;
    final wall = _mix(c.fill(PaletteRole.midtone), c.fill(PaletteRole.paper), 0.3);
    final dark = c.fill(PaletteRole.shadow);
    _rooftop(b, 0, 120, 90, wall, dark, salt: 1);
    _waterTower(b, 190, 0, 70, _mix(wall, c.fill(PaletteRole.paper), 0.3), dark);
    _rooftop(b, 250, 150, 120, wall, dark, chimney: false, salt: 2);
    _laundry(b, 262, 388, -150, math.sin(b.time * 2.2) * 4, c.fill(PaletteRole.accent2), dark);
    _rooftop(b, 420, 90, 70, wall, dark, salt: 3);
    // An antenna.
    b.layer();
    b.inkLine(b.lw * 0.6);
    b.pen
      ..moveTo(455, -70)
      ..lineTo(455, -130)
      ..moveTo(440, -115)
      ..lineTo(470, -115)
      ..moveTo(445, -125)
      ..lineTo(465, -125);
    b.endLayer();
  }, fps: 12, seed: 2);
  final ledge = _tile(240, 100, (b) {
    final c = b.colors;
    final stone = _mix(c.fill(PaletteRole.midtone), c.fill(PaletteRole.paper), 0.45);
    final dark = c.fill(PaletteRole.shadow);
    b.layer();
    b.shape(stone);
    b.pen.roundRect(0, 0, 240, 100, 0);
    b.shade();
    b.pen.roundRect(0, 60, 240, 100, 0);
    // Cornice.
    b.shape(stone);
    b.pen.roundRect(-4, -8, 244, 4, 2);
    b.inkLine(b.lw * 0.6);
    b.pen
      ..moveTo(0, 22)
      ..lineTo(240, 22 + b.ja(3, 0.6))
      ..moveTo(0, 48)
      ..lineTo(240, 48 + b.ja(4, 0.6));
    for (var i = 0; i < 5; i++) {
      final x = 24 + i * 48.0 + (i.isOdd ? 12 : 0);
      b.pen
        ..moveTo(x, 22)
        ..lineTo(x, 48);
    }
    // A drainpipe.
    b.shape(dark, ink: 0.7);
    b.pen.roundRect(200, -6, 208, 100, 2);
    b.endLayer();
  }, seed: 3);
  return [
    sky,
    ParallaxLayer(
      priority: -50,
      parallax: 0.06,
      period: 700,
      scroll: scroll,
      props: [
        PlacedProp(moon, 300, 150),
        PlacedProp(starA, 60, 90),
        PlacedProp(starB, 180, 60),
        PlacedProp(starC, 420, 120),
        PlacedProp(starB, 560, 200),
      ],
    ),
    ParallaxLayer(
      priority: -45,
      parallax: 0.12,
      period: 760,
      scroll: scroll,
      props: [PlacedProp(cloudA, 120, 250), PlacedProp(cloudB, 420, 200), PlacedProp(cloudC, 650, 320)],
    ),
    ParallaxLayer(
      priority: -40,
      parallax: 0.22,
      period: 600,
      scroll: scroll,
      beat: beat,
      bounce: 0.035,
      props: [PlacedProp(far, 0, OrbitStage.groundY)],
    ),
    ParallaxLayer(
      priority: -30,
      parallax: 0.5,
      period: 520,
      scroll: scroll,
      beat: beat,
      bounce: 0.05,
      props: [PlacedProp(mid, 0, OrbitStage.groundY)],
    ),
    ParallaxLayer(priority: -20, parallax: 1, period: 240, scroll: scroll, props: [PlacedProp(ledge, 0, OrbitStage.groundY)]),
  ];
}

/// The launch pad: a wooden trestle with a bull's-eye target and a lamp,
/// standing on the ledge (origin = its base centre).
class LaunchPad extends InkProp {
  LaunchPad({super.seed}) : super(size: 110, id: 'pad') {
    OrbitAllocations.note();
  }

  @override
  double get drawFps => 12;

  @override
  Rect get bounds => const Rect.fromLTRB(-80, -90, 80, 6);

  @override
  void build(InkBuild b) {
    final pen = b.pen;
    final c = b.colors;
    final wood = _mix(c.fill(PaletteRole.midtone), c.fill(PaletteRole.shadow), 0.3);
    final dark = c.fill(PaletteRole.shadow);
    b.layer();
    // Trestle legs and the deck.
    b.shape(wood, ink: 0.8);
    pen
      ..moveTo(-60, 0)
      ..lineTo(-44, -36)
      ..lineTo(-36, -36)
      ..lineTo(-52, 0)
      ..close()
      ..moveTo(60, 0)
      ..lineTo(44, -36)
      ..lineTo(36, -36)
      ..lineTo(52, 0)
      ..close();
    b.shape(wood, ink: 0.8);
    pen.roundRect(-66, -44, 66, -34, 3);
    b.inkLine(b.lw * 0.5);
    for (var i = -2; i <= 2; i++) {
      pen
        ..moveTo(i * 26.0, -44)
        ..lineTo(i * 26.0 + b.ja(10 + i, 0.5), -34);
    }
    // Cradle blocks the rocket rests on.
    b.shape(dark, ink: 0.8);
    pen
      ..roundRect(-30, -58, -18, -44, 2)
      ..roundRect(18, -58, 30, -44, 2);
    b.endLayer();
    // A lamp on a post that blinks.
    b.layer();
    b.shape(dark, ink: 0.8);
    pen.roundRect(-72, -84, -66, -44, 2);
    final on = ((time * 2).floor() % 2) == 0;
    b.shape(on ? c.hot : c.fill(PaletteRole.midtone), ink: 0.8);
    pen.circle(-69, -90, 8);
    if (on) {
      b.brushQuad(2, -84, -96, -86, -100, -88, -104, b.lw * 0.7);
      b.brushQuad(2, -54, -96, -52, -100, -50, -104, b.lw * 0.7);
    }
    b.endLayer();
  }
}

/// A cream pie on a plate (origin = plate centre on the ledge): the hero's
/// landing spot when all is lost. [splat] (0..1) blows the cream out.
class PiePlate extends InkProp {
  PiePlate({super.seed}) : super(size: 90, id: 'pie') {
    OrbitAllocations.note();
  }

  double _splat = 0;

  double get splat => _splat;
  set splat(double v) {
    if (v == _splat) return;
    _splat = v.clamp(0.0, 1.0);
    markDirty();
  }

  @override
  double get drawFps => 12;

  @override
  Rect get bounds => const Rect.fromLTRB(-60, -70, 60, 8);

  @override
  void build(InkBuild b) {
    final pen = b.pen;
    final c = b.colors;
    final crust = _mix(c.fill(PaletteRole.midtone), c.fill(PaletteRole.paper), 0.25);
    final cream = c.puff;
    final plate = _mix(c.fill(PaletteRole.paper), c.fill(PaletteRole.highlight), 0.5);
    final k = _splat;
    b.layer();
    b.shape(plate, ink: 0.8);
    pen.ellipse(0, 0, 54, 9);
    b.endLayer();
    b.layer();
    // Crust: a fluted dish.
    b.shape(crust);
    pen
      ..moveTo(-44, -4)
      ..lineTo(-38, -22)
      ..lineTo(38, -22)
      ..lineTo(44, -4)
      ..close();
    b.inkLine(b.lw * 0.5);
    for (var i = -3; i <= 3; i++) {
      pen
        ..moveTo(i * 11.0, -22)
        ..quadTo(i * 11.0 + 3, -14, i * 11.0 + 1.5, -6);
    }
    // Cream: a mound that flattens and spreads when splatted.
    final ct = b.contour(0)..clear();
    ct.blob(pen, 0, -26 - 10 * (1 - k), 38 + 22 * k, 16 + 4 * (1 - k), taper: -0.2, samples: 28);
    ct.wobble(b.amp * 0.9, b.frame, b.seed, 2);
    b.blob(ct, cream, depth: 8, threshold: 0.3);
    // Swirl on top and a cherry (it flies off at the splat).
    b.brushQuad(2, -14, -36 + 8 * k, 0, -46 + 8 * k, 12, -34 + 8 * k, b.lw * 0.8, taperIn: 0.1, taperOut: 0.5);
    if (k < 0.5) {
      b.shape(c.fill(PaletteRole.accent2), ink: 0.8);
      pen.circle(0, -50 - 6 * (1 - k), 6);
      b.inkLine(b.lw * 0.5);
      pen
        ..moveTo(0, -56)
        ..quadTo(4, -62, 8, -64);
    }
    b.endLayer();
    if (k > 0.1) {
      // Blobs of cream flung out.
      b.layer();
      for (var i = 0; i < 5; i++) {
        final a = -math.pi * 0.95 + i * math.pi * 0.22;
        final d = 40 + 30 * k + 8 * b.j(20 + i);
        b.shape(cream, ink: 0.7);
        pen.circle(math.cos(a) * d, -20 + math.sin(a) * d * 0.6 + k * 10, 6 + 3 * (i % 2));
      }
      b.endLayer();
    }
  }
}

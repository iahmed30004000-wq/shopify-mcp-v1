import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../../engine/cinema_engine.dart';
import '../../engine/rig/rig_kit.dart';

// The painted sets of "Rehearsal": one per era, every flat inked with the
// rig toolkit (boil, era ink, halftone / hatch / cel shading, neon glow) so
// scenery and cast come from the same pen. Each set is a sky painter plus
// parallax planes of cached props on a repeating tile; nothing is allocated
// per frame (drawings rebuild on boil frames, replays in between).

/// World-unit constants shared with the game.
abstract final class DemoStage {
  static const double width = 360;
  static const double height = 800;
  static const double groundY = 640;

  /// Painted beyond the design width because the camera "contains" the
  /// world: a wider play area shows a little more set at the sides.
  static const double paintLeft = -80;
  static const double paintRight = 440;
}

Color _mix(Color a, Color b, double t) => Color.lerp(a, b, t)!;

/// Builds the era's set components for [game] (back to front priorities).
/// [scroll] reads the world's travel in units (the hero runs in place; the
/// set moves the other way with parallax).
List<Component> buildDemoSet(CinemaGame game, double Function() scroll) => switch (game.era) {
  Era.silent => _silent(game, scroll),
  Era.rubberHose => _rubberHose(game, scroll),
  Era.noir => _noir(game, scroll),
  Era.technicolor => _technicolor(game, scroll),
  Era.grindhouse => _grindhouse(game, scroll),
  Era.vhs => _vhs(game, scroll),
};

// ---------------------------------------------------------------------------
// Layers

/// A prop placed on a set tile at ([x], [y]) in world units.
class PlacedProp {
  PlacedProp(this.prop, this.x, this.y);

  final InkProp prop;
  final double x, y;
}

/// One parallax plane: cached inked props repeating every [period] units,
/// sliding by [parallax] × the world's scroll.
class SetLayer extends Component with HasGameReference<CinemaGame> {
  SetLayer({required this.parallax, required this.period, required this.props, required this.scroll, super.priority});

  final double parallax;
  final double period;
  final List<PlacedProp> props;
  final double Function() scroll;

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
    final copies = (DemoStage.paintRight / period).ceil() + 1;
    for (final p in props) {
      final b = p.prop.bounds;
      for (var k = -1; k <= copies; k++) {
        final x = p.x + k * period - off;
        if (x + b.right < DemoStage.paintLeft || x + b.left > DemoStage.paintRight) continue;
        canvas
          ..save()
          ..translate(x, p.y);
        p.prop.paint(canvas, ctx);
        canvas.restore();
      }
    }
  }

  @override
  void onRemove() {
    for (final p in props) {
      p.prop.dispose();
    }
    super.onRemove();
  }
}

/// The sky and anything cheaper to paint with a plain canvas (gradients,
/// beams, rain, a grid). Paints and shaders are cached.
class SkyPlane extends Component with HasGameReference<CinemaGame> {
  SkyPlane({required this.paint, required this.scroll, super.priority});

  final void Function(Canvas canvas, SkyKit kit) paint;
  final double Function() scroll;
  late final SkyKit _kit = SkyKit(game, scroll);

  @override
  void render(Canvas canvas) => paint(canvas, _kit);
}

/// Reusable paints for the sky planes.
class SkyKit {
  SkyKit(this.game, this.scroll);

  final CinemaGame game;
  final double Function() scroll;
  final Paint fill = Paint();
  final Paint line = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  final Path path = Path();
  Shader? gradient;
  Shader? glow;

  EraPalette get pal => game.skin.palette;
  double get t => game.clock.time;

  static const Rect skyRect = Rect.fromLTRB(DemoStage.paintLeft, -300, DemoStage.paintRight, DemoStage.groundY + 2);

  /// Vertical gradient over the sky rect (built once).
  void sky(Canvas canvas, List<Color> colors, List<double> stops) {
    gradient ??= Gradient.linear(const Offset(0, -200), const Offset(0, DemoStage.groundY), colors, stops);
    fill.shader = gradient;
    canvas.drawRect(skyRect, fill);
    fill.shader = null;
  }
}

// ---------------------------------------------------------------------------
// Shared ink vocabulary

/// A rounded mound from [x0] to [x1], crest at [top], base at [base]; the
/// lee side gets a shading crescent (halftone / hatch / cel per era).
void _mound(InkBuild b, double x0, double x1, double top, double base, Color fill, {double ink = 1, bool shade = true, int salt = 0}) {
  final pen = b.pen;
  final cx = (x0 + x1) / 2;
  final j0 = b.ja(salt, 0.8), j1 = b.ja(salt + 1, 0.8);
  b.shape(fill, ink: ink);
  pen
    ..moveTo(x0, base + 6)
    ..lineTo(x0, base)
    ..cubicTo(x0 + (cx - x0) * 0.35, base, cx - (cx - x0) * 0.45, top + j0, cx, top + j1)
    ..cubicTo(cx + (x1 - cx) * 0.45, top + j0, x1 - (x1 - cx) * 0.35, base, x1, base)
    ..lineTo(x1, base + 6)
    ..close();
  if (shade) {
    final w = x1 - cx, h = base - top;
    b.shade();
    pen
      ..moveTo(cx + w * 0.12, top + h * 0.12)
      ..cubicTo(cx + w * 0.55, top + h * 0.22, x1 - w * 0.2, base - h * 0.3, x1 - w * 0.02, base)
      ..lineTo(cx + w * 0.42, base)
      ..cubicTo(cx + w * 0.55, base - h * 0.4, cx + w * 0.38, top + h * 0.3, cx + w * 0.12, top + h * 0.12)
      ..close();
  }
}

/// A flat-topped silhouette block (tower, mesa, building) with setbacks.
void _block(InkBuild b, double x, double w, double h, Color fill, {double ink = 0.6, int steps = 0, double setback = 0.1}) {
  final pen = b.pen;
  b.shape(fill, ink: ink);
  var l = x;
  final r = x + w;
  pen.moveTo(l, 4);
  pen.lineTo(l, -h * (steps == 0 ? 1 : 0.62));
  for (var i = 0; i < steps; i++) {
    l += w * setback;
    pen
      ..lineTo(l, -h * (0.62 + 0.38 * i / steps))
      ..lineTo(l, -h * (0.62 + 0.38 * (i + 1) / steps));
  }
  pen.lineTo(l, -h);
  var rr = r;
  for (var i = steps - 1; i >= 0; i--) {
    rr = r - w * setback * (i + 1);
    final yy = -h * (0.62 + 0.38 * (i + 1) / steps);
    pen
      ..lineTo(rr, yy)
      ..lineTo(rr, -h * (0.62 + 0.38 * i / steps));
  }
  pen
    ..lineTo(r, steps == 0 ? -h : -h * 0.62)
    ..lineTo(r, 4)
    ..close();
}

/// Rows of lit windows inside a block ([lit] fraction, seeded).
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

/// A palm: a segmented trunk leaning by [lean], fronds swaying with [sway].
void _palm(InkBuild b, double x, double y, double h, double lean, double sway, Color trunk, Color leaf) {
  final pen = b.pen;
  final tx = x + lean * h * 0.35, ty = y - h;
  b.layer();
  b.shape(trunk);
  pen
    ..moveTo(x - h * 0.05, y)
    ..quadTo(x + lean * h * 0.1, y - h * 0.5, tx - h * 0.025, ty)
    ..lineTo(tx + h * 0.025, ty)
    ..quadTo(x + lean * h * 0.1 + h * 0.06, y - h * 0.5, x + h * 0.07, y)
    ..close();
  b.inkLine(b.lw * 0.5);
  for (var i = 1; i < 7; i++) {
    final k = i / 7;
    final sx = x + lean * h * 0.35 * k * k + lean * h * 0.1 * (1 - k) * k, sy = y - h * k;
    pen
      ..moveTo(sx - h * 0.05 * (1 - k * 0.4), sy)
      ..quadTo(sx + h * 0.01, sy + h * 0.02, sx + h * 0.06 * (1 - k * 0.4), sy);
  }
  b.endLayer();
  b.layer();
  for (var i = 0; i < 6; i++) {
    final a = -math.pi * 0.95 + i * math.pi * 0.95 / 5 + sway * 0.12 + b.ja(40 + i, 0.02);
    final len = h * (0.42 + 0.08 * (i == 2 || i == 3 ? 1 : 0));
    final ex = tx + math.cos(a) * len, ey = ty + math.sin(a) * len + len * 0.5 + sway * h * 0.05;
    final cx = tx + math.cos(a) * len * 0.6, cy = ty + math.sin(a) * len * 0.6 - len * 0.25;
    b.shape(leaf);
    pen
      ..moveTo(tx, ty)
      ..quadTo(cx - h * 0.02, cy - h * 0.08, ex, ey)
      ..quadTo(cx + h * 0.03, cy + h * 0.1, tx, ty + h * 0.02)
      ..close();
  }
  b.shape(leaf);
  pen.circle(tx, ty, h * 0.06);
  b.endLayer();
}

/// A puffy cartoon tree: a shaded canopy on a bent trunk.
void _tree(InkBuild b, double x, double y, double h, Color trunk, Color leaf, {int salt = 0}) {
  final pen = b.pen;
  b.layer();
  b.shape(trunk);
  pen
    ..moveTo(x - h * 0.08, y)
    ..quadTo(x - h * 0.05, y - h * 0.3, x - h * 0.03, y - h * 0.55)
    ..lineTo(x + h * 0.04, y - h * 0.55)
    ..quadTo(x + h * 0.07, y - h * 0.3, x + h * 0.1, y)
    ..close();
  b.endLayer();
  b.layer();
  final c = b.contour(0)..clear();
  final cy = y - h * 0.68;
  for (var i = 0; i < 30; i++) {
    final a = i / 30 * math.pi * 2;
    final bump = 1 + 0.08 * math.sin(a * 5 + salt);
    c.addPen(pen, x + math.cos(a) * h * 0.34 * bump, cy + math.sin(a) * h * 0.28 * bump);
  }
  c.wobble(b.amp, b.frame, b.seed, 50 + salt);
  b.blob(c, leaf, depth: h * 0.09);
  b.endLayer();
}

/// A telephone pole; the wire sags to the next pole [span] units away.
void _pole(InkBuild b, double x, double y, double h, double span, Color wood) {
  final pen = b.pen;
  b.layer();
  b.shape(wood);
  pen.roundRect(x - h * 0.03, y - h, x + h * 0.03, y, h * 0.01);
  b.shape(wood);
  pen.roundRect(x - h * 0.16, y - h * 0.92, x + h * 0.16, y - h * 0.88, h * 0.01);
  b.endLayer();
  b.layer();
  for (final k in const [-0.12, 0.12]) {
    b.brushQuad(2, x + k * h, y - h * 0.9, x + k * h + span * 0.5, y - h * 0.9 + h * 0.18 + b.ja(60, 2), x + k * h + span, y - h * 0.9, b.lw * 0.55, taperIn: 0.02, taperOut: 0.02);
  }
  b.endLayer();
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

/// A saguaro cactus with two arms (and a grumpy little face).
void _cactus(InkBuild b, double x, double y, double h, Color fill, Face face, double time, {bool withFace = true}) {
  final pen = b.pen;
  b.layer();
  b.shape(fill);
  pen.capsule(x, y + h * 0.1, x, y - h, h * 0.13, h * 0.12);
  b.shape(fill);
  pen.capsule(x - h * 0.3, y - h * 0.45, x - h * 0.3, y - h * 0.72, h * 0.08);
  b.shape(fill);
  pen.capsule(x - h * 0.3, y - h * 0.45, x - h * 0.05, y - h * 0.45, h * 0.08);
  b.shape(fill);
  pen.capsule(x + h * 0.3, y - h * 0.3, x + h * 0.3, y - h * 0.6, h * 0.08);
  b.shape(fill);
  pen.capsule(x + h * 0.05, y - h * 0.3, x + h * 0.3, y - h * 0.3, h * 0.08);
  final c = b.contour(0)..clear();
  c.ellipse(pen, x, y - h * 0.45, h * 0.13, h * 0.55, samples: 28);
  c.writeCrescent(b.shade(), kShadowX, kShadowY, h * 0.07);
  b.inkLine(b.lw * 0.45);
  for (var i = 0; i < 3; i++) {
    final k = -0.06 + i * 0.06;
    pen
      ..moveTo(x + k * h, y - h * 0.1)
      ..lineTo(x + k * h * 0.9, y - h * 0.9);
  }
  b.endLayer();
  if (withFace) {
    face
      ..cx = x
      ..cy = y - h * 0.78
      ..r = h * 0.11
      ..expression = RigExpression.angry
      ..eyes = RigEyes.pieCut
      ..eyeScale = 0.75
      ..eyeGap = 0.3
      ..blink = (time % 4.7) < 0.12 ? 1 : 0
      ..lookX = -0.6
      ..lookY = 0.1
      ..brows = true
      ..nose = NoseStyle.none
      ..skin = fill
      ..mouth = MouthShape.frown
      ..mouthY = 0.5
      ..mouthW = 0.5
      ..salt = 410;
    face.draw(b);
  }
}

/// A picket fence from [x0] to [x1].
void _fence(InkBuild b, double x0, double x1, double y, double h, Color fill) {
  final pen = b.pen;
  b.layer();
  for (var x = x0; x < x1; x += h * 0.55) {
    b.shape(fill, ink: 0.8);
    pen
      ..moveTo(x, y)
      ..lineTo(x, y - h * 0.8)
      ..lineTo(x + h * 0.14, y - h)
      ..lineTo(x + h * 0.28, y - h * 0.8)
      ..lineTo(x + h * 0.28, y)
      ..close();
  }
  for (final k in const [0.3, 0.62]) {
    b.shape(fill, ink: 0.8);
    pen.roundRect(x0 - h * 0.1, y - h * k - h * 0.06, x1 + h * 0.1, y - h * k + h * 0.06, h * 0.02);
  }
  b.endLayer();
}

/// A flower with a round centre, five petals and a stem.
void _flower(InkBuild b, double x, double y, double s, Color petal, Color centre, Color stem, double sway) {
  final pen = b.pen;
  final hx = x + sway * s * 0.3, hy = y - s * 1.6;
  b.layer();
  b.stroke(stem, b.lw * 0.9);
  pen
    ..moveTo(x, y)
    ..quadTo(x - s * 0.2, y - s * 0.9, hx, hy);
  b.shape(stem, ink: 0.8);
  pen.ellipse(x - s * 0.25, y - s * 0.6, s * 0.28, s * 0.14, -0.6);
  b.endLayer();
  b.layer();
  for (var i = 0; i < 5; i++) {
    final a = i * math.pi * 2 / 5 - math.pi / 2 + sway * 0.1;
    b.shape(petal);
    pen.ellipse(hx + math.cos(a) * s * 0.42, hy + math.sin(a) * s * 0.42, s * 0.3, s * 0.2, a);
  }
  b.endLayer();
  b.layer();
  b.shape(centre);
  pen.circle(hx, hy, s * 0.24);
  b.endLayer();
}

/// A grinning sun with turning rays and pie-cut eyes.
class _SunProp extends InkProp {
  _SunProp({required super.size, this.face = true, this.rays = 12}) : super(id: 'sun');

  final bool face;
  final int rays;
  final Face _face = Face();

  @override
  double get drawFps => 12;

  @override
  Rect get bounds => Rect.fromCircle(center: Offset.zero, radius: size * 0.9);

  @override
  void build(InkBuild b) {
    final pen = b.pen;
    final c = b.colors;
    final r = size * 0.5;
    final mono = c.palette.ink == c.palette.accent || b.skin.era.isMonochrome;
    final fill = _mix(c.fill(PaletteRole.paper), c.palette.accent, mono ? 0.08 : 0.32);
    final rot = time * 0.22;
    b.layer();
    for (var i = 0; i < rays; i++) {
      final a = rot + i * math.pi * 2 / rays;
      final len = r * (1.5 + 0.12 * b.j(i)) + (i.isEven ? r * 0.12 : 0);
      b.shape(fill);
      pen
        ..moveTo(math.cos(a - 0.13) * r * 0.96, math.sin(a - 0.13) * r * 0.96)
        ..lineTo(math.cos(a) * len, math.sin(a) * len)
        ..lineTo(math.cos(a + 0.13) * r * 0.96, math.sin(a + 0.13) * r * 0.96)
        ..close();
    }
    b.endLayer();
    b.layer();
    final ct = b.contour(0)..clear();
    ct.ellipse(pen, 0, 0, r, r, samples: 32);
    ct.wobble(b.amp * 0.6, b.frame, b.seed, 7);
    b.blob(ct, fill, depth: r * 0.2);
    b.endLayer();
    if (!face) return;
    _face
      ..cx = 0
      ..cy = 0
      ..r = r * 0.8
      ..turn = 0
      ..expression = RigExpression.happy
      ..eyes = RigEyes.pieCut
      ..eyeScale = 0.72
      ..eyeGap = 0.4
      ..eyeY = -0.08
      ..blink = (time % 5.1) < 0.12 ? 1 : 0
      ..lookX = math.sin(time * 0.5) * 0.4
      ..lookY = 0.3
      ..brows = false
      ..nose = NoseStyle.none
      ..skin = fill
      ..mouth = MouthShape.grin
      ..mouthY = 0.42
      ..mouthW = 0.62
      ..salt = 300;
    _face.draw(b);
  }
}

/// A sketch with a face slot (cacti, signs).
class _FacedSketch extends InkProp {
  _FacedSketch({required super.size, required this.extent, required this.draw, this.fps = 12}) : super(id: 'faced');

  final Rect extent;
  final double fps;
  final void Function(InkBuild b, Face face, double time) draw;
  final Face face = Face();

  @override
  double get drawFps => fps;

  @override
  Rect get bounds => extent;

  @override
  void build(InkBuild b) => draw(b, face, time);
}

InkSketch _tile(double w, double h, void Function(InkBuild b) draw, {double fps = 0, double top = 0}) =>
    InkSketch(size: 120, extent: Rect.fromLTRB(0, -h + top, w, top + 4), fps: fps, draw: draw);

// ---------------------------------------------------------------------------
// 1920s: the machine hall (Metropolis mood – stepped towers, a shift clock,
// great gears under an iron floor, steam).

List<Component> _silent(CinemaGame game, double Function() scroll) {
  final pal = game.skin.palette;
  final sky = SkyPlane(
    priority: -40,
    scroll: scroll,
    paint: (canvas, k) {
      k.sky(canvas, [_mix(pal.shadow, pal.ink, 0.25), _mix(pal.backdrop, pal.shadow, 0.45), pal.backdrop], const [0, 0.55, 1]);
      // Shafts of light from the hall's high windows.
      k.fill.color = pal.highlight.withValues(alpha: 0.07);
      for (var i = 0; i < 3; i++) {
        final x = 20 + i * 150 - (k.scroll() * 0.08) % 150;
        k.path
          ..reset()
          ..moveTo(x, -300)
          ..lineTo(x + 70, -300)
          ..lineTo(x + 170, DemoStage.groundY)
          ..lineTo(x + 70, DemoStage.groundY)
          ..close();
        canvas.drawPath(k.path, k.fill);
      }
    },
  );
  final far = _tile(420, 420, (b) {
    final c = b.colors;
    final dark = _mix(c.fill(PaletteRole.shadow), c.fill(PaletteRole.backdrop), 0.35);
    final lit = _mix(c.fill(PaletteRole.paper), c.palette.footlight, 0.4);
    b.layer();
    _block(b, 0, 70, 330, dark, steps: 2, setback: 0.12);
    _block(b, 90, 110, 400, dark, steps: 3, setback: 0.1);
    _block(b, 215, 60, 250, dark, steps: 1, setback: 0.2);
    _block(b, 290, 120, 360, dark, steps: 2, setback: 0.14);
    // Clock tower face (the ten-hour shift clock of a machine city).
    b.shape(_mix(c.fill(PaletteRole.paper), c.fill(PaletteRole.midtone), 0.3), ink: 0.8);
    b.pen.circle(145, -330, 30);
    b.inkLine(b.lw * 0.5);
    for (var i = 0; i < 10; i++) {
      final a = i * math.pi * 2 / 10 - math.pi / 2;
      b.pen
        ..moveTo(145 + math.cos(a) * 24, -330 + math.sin(a) * 24)
        ..lineTo(145 + math.cos(a) * 27, -330 + math.sin(a) * 27);
    }
    b.inkLine(b.lw * 0.9);
    b.pen
      ..moveTo(145, -330)
      ..lineTo(145 + 14, -330 - 12)
      ..moveTo(145, -330)
      ..lineTo(145 - 6, -330 - 20);
    _windows(b, 4, 62, 300, 14, lit, litShare: 0.45, salt: 1);
    _windows(b, 94, 102, 370, 14, lit, litShare: 0.4, salt: 2);
    _windows(b, 219, 52, 225, 14, lit, litShare: 0.5, salt: 3);
    _windows(b, 294, 112, 330, 14, lit, litShare: 0.42, salt: 4);
    b.endLayer();
  })..shaded = false;
  final stackA = InkSketch(
    size: 120,
    extent: const Rect.fromLTRB(-40, -300, 60, 4),
    fps: 12,
    draw: (b) {
      final c = b.colors;
      final iron = _mix(c.fill(PaletteRole.midtone), c.fill(PaletteRole.shadow), 0.45);
      b.layer();
      b.shape(iron);
      b.pen
        ..moveTo(-26, 0)
        ..lineTo(-18, -240)
        ..lineTo(18, -240)
        ..lineTo(26, 0)
        ..close();
      b.shape(iron);
      b.pen.roundRect(-24, -250, 24, -236, 3);
      final ct = b.contour(0)..clear();
      ct.ellipse(b.pen, 0, -120, 22, 125, samples: 28);
      ct.writeCrescent(b.shade(), kShadowX, kShadowY, 12);
      for (var i = 0; i < 4; i++) {
        final y = -40.0 - i * 50;
        Mechanics.rivet(b, -18 + i * 1.2, y, 2.2);
        Mechanics.rivet(b, 18 - i * 1.2, y, 2.2);
      }
      b.endLayer();
      final sketchTime = b.time;
      for (var i = 0; i < 2; i++) {
        Emanata.steam(b, 0, -250, 34, (sketchTime * 0.45 + i * 0.5) % 1, drift: 0.5);
      }
    },
  );
  final gearA = InkGear(size: 230, teeth: 16, speed: 0.35);
  final gearB = InkGear(size: 150, teeth: 11, speed: -0.55, fill: PaletteRole.shadow);
  final gearC = InkGear(size: 100, teeth: 9, speed: 0.8);
  final floor = _tile(240, 170, (b) {
    final c = b.colors;
    final plate = _mix(c.fill(PaletteRole.midtone), c.fill(PaletteRole.shadow), 0.55);
    b.layer();
    b.shape(plate);
    b.pen.roundRect(0, 0, 240, 170, 0);
    b.shade();
    b.pen.roundRect(0, 90, 240, 170, 0);
    b.inkLine(b.lw * 0.7);
    b.pen
      ..moveTo(120, 0)
      ..lineTo(120 + b.ja(3), 170)
      ..moveTo(0, 46)
      ..lineTo(240, 46 + b.ja(4));
    for (var i = 0; i < 6; i++) {
      Mechanics.rivet(b, 12 + i * 44.0, 10, 2.6);
      Mechanics.rivet(b, 30 + i * 44.0, 36, 2.6);
    }
    for (var i = 0; i < 4; i++) {
      Mechanics.rivet(b, 112, 70 + i * 28.0, 2.6);
    }
    b.endLayer();
  });
  return [
    sky,
    SetLayer(priority: -30, parallax: 0.12, period: 420, scroll: scroll, props: [PlacedProp(far, 0, DemoStage.groundY - 60)]),
    SetLayer(
      priority: -20,
      parallax: 0.3,
      period: 520,
      scroll: scroll,
      props: [PlacedProp(stackA, 70, DemoStage.groundY - 40), PlacedProp(stackA, 400, DemoStage.groundY - 20)],
    ),
    SetLayer(
      priority: -15,
      parallax: 0.55,
      period: 560,
      scroll: scroll,
      props: [
        PlacedProp(gearA, 120, DemoStage.groundY + 10),
        PlacedProp(gearB, 300, DemoStage.groundY - 10),
        PlacedProp(gearC, 450, DemoStage.groundY + 20),
      ],
    ),
    SetLayer(priority: -10, parallax: 1, period: 240, scroll: scroll, props: [PlacedProp(floor, 0, DemoStage.groundY)]),
  ];
}

// ---------------------------------------------------------------------------
// 1930s: the cartoon countryside (a grinning sun, rolling hills, trees with
// bumpy canopies, a picket fence, flowers that nod, stage boards).

List<Component> _rubberHose(CinemaGame game, double Function() scroll) {
  final pal = game.skin.palette;
  final sky = SkyPlane(
    priority: -40,
    scroll: scroll,
    paint: (canvas, k) => k.sky(canvas, [_mix(pal.backdrop, pal.shadow, 0.3), pal.backdrop, _mix(pal.backdrop, pal.paper, 0.6)], const [0, 0.55, 1]),
  );
  final sun = _SunProp(size: 120);
  final cloudA = InkCloud(size: 150, mood: PropMood.sleepy);
  final cloudB = InkCloud(size: 100);
  final hills = _tile(520, 230, (b) {
    final c = b.colors;
    b.layer();
    _mound(b, -40, 330, -200, 0, _mix(c.fill(PaletteRole.midtone), c.fill(PaletteRole.paper), 0.25), salt: 1);
    _mound(b, 250, 600, -150, 0, _mix(c.fill(PaletteRole.midtone), c.fill(PaletteRole.paper), 0.25), salt: 3);
    b.endLayer();
    b.layer();
    _mound(b, 120, 470, -110, 10, _mix(c.fill(PaletteRole.midtone), c.fill(PaletteRole.paper), 0.55), salt: 5);
    b.endLayer();
  }, top: 0);
  final trees = _tile(520, 220, (b) {
    final c = b.colors;
    final trunk = c.fill(PaletteRole.shadow), leaf = c.fill(PaletteRole.midtone);
    _tree(b, 60, 0, 150, trunk, leaf, salt: 1);
    _tree(b, 330, 0, 190, trunk, leaf, salt: 2);
    _tree(b, 430, 0, 120, trunk, leaf, salt: 3);
    _fence(b, 110, 290, 0, 42, c.fill(PaletteRole.paper));
  });
  final flowers = _FacedSketch(
    size: 60,
    extent: const Rect.fromLTRB(-40, -80, 300, 6),
    fps: 12,
    draw: (b, face, time) {
      final c = b.colors;
      for (var i = 0; i < 4; i++) {
        final x = i * 85.0 + (i.isOdd ? 20 : 0);
        _flower(
          b,
          x,
          0,
          18 + (i % 2) * 5,
          i.isEven ? c.fill(PaletteRole.paper) : c.fill(PaletteRole.accent2),
          c.fill(PaletteRole.accent),
          c.fill(PaletteRole.shadow),
          math.sin(time * 2.1 + i),
        );
      }
    },
  );
  final floor = _tile(240, 170, (b) {
    final c = b.colors;
    final board = _mix(c.fill(PaletteRole.midtone), c.fill(PaletteRole.shadow), 0.3);
    b.layer();
    b.shape(board);
    b.pen.roundRect(0, 0, 240, 170, 0);
    b.shade();
    b.pen
      ..moveTo(0, 110)
      ..lineTo(240, 118)
      ..lineTo(240, 170)
      ..lineTo(0, 170)
      ..close();
    b.inkLine(b.lw * 0.6);
    for (var i = 1; i < 5; i++) {
      final y = 14.0 + i * (16 + i * 5);
      b.pen
        ..moveTo(0, y)
        ..lineTo(240, y + b.ja(10 + i, 1.5));
    }
    for (var i = 0; i < 5; i++) {
      final x = i * 48.0 + (i.isEven ? 0 : 24);
      b.pen
        ..moveTo(x, 2)
        ..lineTo(x - 10, 30);
    }
    b.inkFill(_mix(c.fill(PaletteRole.shadow), c.ink, 0.4));
    b.pen
      ..ellipse(70, 60, 5, 3)
      ..ellipse(190, 100, 4, 2.5);
    b.endLayer();
  });
  return [
    sky,
    SetLayer(priority: -32, parallax: 0.04, period: 720, scroll: scroll, props: [PlacedProp(sun, 250, 215)]),
    SetLayer(
      priority: -30,
      parallax: 0.1,
      period: 640,
      scroll: scroll,
      props: [PlacedProp(cloudA, 70, 150), PlacedProp(cloudB, 430, 260)],
    ),
    SetLayer(priority: -25, parallax: 0.25, period: 520, scroll: scroll, props: [PlacedProp(hills, 0, DemoStage.groundY + 2)]),
    SetLayer(priority: -20, parallax: 0.5, period: 520, scroll: scroll, props: [PlacedProp(trees, 0, DemoStage.groundY + 2)]),
    SetLayer(priority: -10, parallax: 1, period: 240, scroll: scroll, props: [PlacedProp(floor, 0, DemoStage.groundY)]),
    SetLayer(priority: -8, parallax: 1, period: 340, scroll: scroll, props: [PlacedProp(flowers, 10, DemoStage.groundY + 6)]),
  ];
}

// ---------------------------------------------------------------------------
// 1940s: the rooftops at night (a sleepy moon, searchlights, a skyline of lit
// windows, water towers, chimneys, washing on the line, rain).

List<Component> _noir(CinemaGame game, double Function() scroll) {
  final pal = game.skin.palette;
  final sky = SkyPlane(
    priority: -40,
    scroll: scroll,
    paint: (canvas, k) {
      k.sky(canvas, [_mix(pal.backdrop, pal.ink, 0.6), pal.backdrop, _mix(pal.backdrop, pal.shadow, 0.5)], const [0, 0.6, 1]);
      // Two searchlights sweeping the sky.
      k.fill.color = pal.highlight.withValues(alpha: 0.075);
      for (var i = 0; i < 2; i++) {
        final base = Offset(60 + i * 250, DemoStage.groundY - 20);
        final a = -math.pi / 2 + math.sin(k.t * (0.35 + i * 0.1) + i * 2) * 0.55;
        final dir = Offset(math.cos(a), math.sin(a));
        final side = Offset(-dir.dy, dir.dx) * 40;
        final tip = base + dir * 900;
        k.path
          ..reset()
          ..moveTo(base.dx, base.dy)
          ..lineTo(tip.dx - side.dx, tip.dy - side.dy)
          ..lineTo(tip.dx + side.dx, tip.dy + side.dy)
          ..close();
        canvas.drawPath(k.path, k.fill);
      }
      // Rain.
      k.line
        ..color = pal.paper.withValues(alpha: 0.16)
        ..strokeWidth = 1.2;
      final drop = (k.t * 900) % 60;
      for (var i = 0; i < 26; i++) {
        final x = (i * 37.0 + (k.scroll() * 0.3) % 37 + i * 9) % 560 - 100 + drop * 0.4;
        final y = (i * 173.0 + drop + i * 30) % 700 - 60;
        canvas.drawLine(Offset(x, y), Offset(x - 9, y + 34), k.line);
      }
    },
  );
  final moon = InkMoon(size: 110);
  final starA = InkStar(size: 20);
  final starB = InkStar(size: 14, spin: 0.7);
  final skyline = _tile(460, 400, (b) {
    final c = b.colors;
    final dark = _mix(c.fill(PaletteRole.shadow), c.fill(PaletteRole.backdrop), 0.4);
    final lit = _mix(c.fill(PaletteRole.paper), c.palette.footlight, 0.5);
    b.layer();
    _block(b, 0, 90, 260, dark, steps: 1, setback: 0.15);
    _block(b, 110, 70, 360, dark, steps: 2, setback: 0.12);
    _block(b, 200, 120, 200, dark);
    _block(b, 340, 100, 300, dark, steps: 1, setback: 0.2);
    b.inkLine(b.lw * 0.5);
    b.pen
      ..moveTo(145, -360)
      ..lineTo(145, -400)
      ..moveTo(260, -200)
      ..lineTo(260, -230)
      ..moveTo(252, -222)
      ..lineTo(268, -222);
    _windows(b, 4, 82, 240, 13, lit, litShare: 0.33, salt: 11);
    _windows(b, 114, 62, 330, 13, lit, litShare: 0.3, salt: 12);
    _windows(b, 204, 112, 180, 13, lit, litShare: 0.36, salt: 13);
    _windows(b, 344, 92, 270, 13, lit, litShare: 0.3, salt: 14);
    b.endLayer();
    _waterTower(b, 250, -200, 60, _mix(dark, c.fill(PaletteRole.midtone), 0.2), dark);
  })..shaded = false;
  final rooftop = _FacedSketch(
    size: 120,
    extent: const Rect.fromLTRB(-20, -260, 560, 6),
    fps: 8,
    draw: (b, face, time) {
      final c = b.colors;
      final brick = _mix(c.fill(PaletteRole.shadow), c.fill(PaletteRole.midtone), 0.5);
      // Chimney stacks with smoke.
      b.layer();
      for (final x in const [40.0, 70.0]) {
        b.shape(brick);
        b.pen.roundRect(x - 12, -120, x + 12, 0, 2);
        b.shape(brick);
        b.pen.roundRect(x - 15, -128, x + 15, -116, 2);
      }
      b.shade();
      b.pen.roundRect(62, -116, 82, 0, 0);
      b.endLayer();
      for (final x in const [40.0, 70.0]) {
        Emanata.steam(b, x, -130, 26, (time * 0.3 + x * 0.01) % 1, drift: 0.4);
      }
      // Stairwell bulkhead with a door.
      b.layer();
      b.shape(brick);
      b.pen.roundRect(400, -110, 500, 0, 3);
      b.shape(brick);
      b.pen
        ..moveTo(392, -108)
        ..lineTo(450, -132)
        ..lineTo(508, -108)
        ..close();
      b.shade();
      b.pen.roundRect(470, -108, 500, 0, 0);
      b.fill(_mix(c.fill(PaletteRole.ink), c.fill(PaletteRole.shadow), 0.5));
      b.pen.roundRect(430, -80, 462, 0, 2);
      b.fill(_mix(c.fill(PaletteRole.paper), c.palette.footlight, 0.5));
      b.pen.circle(457, -42, 2.5);
      b.endLayer();
      // Washing line.
      b.layer();
      b.brushQuad(2, 70, -200, 240, -170 + math.sin(time * 1.1) * 3, 400, -215, b.lw * 0.5, taperIn: 0.02, taperOut: 0.02);
      b.endLayer();
      b.layer();
      for (var i = 0; i < 3; i++) {
        final x = 130.0 + i * 95, y = -190.0 + i * 6;
        final sw = math.sin(time * 1.6 + i) * 6;
        b.shape(c.fill(PaletteRole.paper), ink: 0.7);
        b.pen
          ..moveTo(x - 18, y)
          ..lineTo(x + 18, y)
          ..lineTo(x + 22 + sw, y + 44)
          ..quadTo(x + sw, y + 52, x - 22 + sw, y + 44)
          ..close();
      }
      b.endLayer();
      _waterTower(b, 330, -2, 110, _mix(brick, c.fill(PaletteRole.midtone), 0.3), brick);
    },
  );
  final floor = _tile(240, 170, (b) {
    final c = b.colors;
    final tar = _mix(c.fill(PaletteRole.shadow), c.fill(PaletteRole.ink), 0.45);
    final brick = _mix(c.fill(PaletteRole.shadow), c.fill(PaletteRole.midtone), 0.45);
    b.layer();
    b.shape(tar);
    b.pen.roundRect(0, 0, 240, 170, 0);
    b.endLayer();
    // Parapet ledge along the front.
    b.layer();
    b.shape(brick);
    b.pen.roundRect(0, 118, 240, 170, 0);
    b.shape(_mix(brick, c.fill(PaletteRole.paper), 0.25));
    b.pen.roundRect(0, 110, 240, 122, 0);
    b.inkLine(b.lw * 0.45);
    for (var r = 0; r < 3; r++) {
      final y = 134.0 + r * 12;
      b.pen
        ..moveTo(0, y)
        ..lineTo(240, y);
      for (var i = 0; i < 6; i++) {
        final x = i * 40.0 + (r.isOdd ? 20 : 0);
        b.pen
          ..moveTo(x, y)
          ..lineTo(x, y + 12);
      }
    }
    b.endLayer();
    // Puddle reflections.
    b.layer();
    b.fill(c.fill(PaletteRole.paper).withValues(alpha: 0.12));
    b.pen
      ..ellipse(60, 50, 34, 6)
      ..ellipse(180, 84, 24, 4);
    b.endLayer();
  });
  return [
    sky,
    SetLayer(
      priority: -34,
      parallax: 0.03,
      period: 760,
      scroll: scroll,
      props: [PlacedProp(moon, 270, 120), PlacedProp(starA, 90, 90), PlacedProp(starB, 170, 210), PlacedProp(starB, 560, 150)],
    ),
    SetLayer(priority: -30, parallax: 0.12, period: 460, scroll: scroll, props: [PlacedProp(skyline, 0, DemoStage.groundY - 150)]),
    SetLayer(priority: -20, parallax: 0.5, period: 580, scroll: scroll, props: [PlacedProp(rooftop, 0, DemoStage.groundY + 2)]),
    SetLayer(priority: -10, parallax: 1, period: 240, scroll: scroll, props: [PlacedProp(floor, 0, DemoStage.groundY)]),
  ];
}

// ---------------------------------------------------------------------------
// 1950s: the Technicolor desert (a blazing sun, cumulus, dunes in cel
// shadow, a domed city on the horizon, palms, a grumpy cactus).

List<Component> _technicolor(CinemaGame game, double Function() scroll) {
  final pal = game.skin.palette;
  final sky = SkyPlane(
    priority: -40,
    scroll: scroll,
    paint: (canvas, k) {
      k.sky(canvas, [_mix(pal.backdrop, pal.accent2, 0.55), pal.backdrop, _mix(pal.backdrop, pal.paper, 0.3)], const [0, 0.5, 1]);
      k.glow ??= Gradient.radial(const Offset(262, 170), 150, [pal.footlight.withValues(alpha: 0.5), pal.footlight.withValues(alpha: 0)]);
      k.fill.shader = k.glow;
      canvas.drawCircle(const Offset(262, 170), 150, k.fill);
      k.fill.shader = null;
    },
  );
  final sun = _SunProp(size: 96, face: false, rays: 16);
  final cloudA = InkCloud(size: 150, mood: PropMood.happy);
  final cloudB = InkCloud(size: 110);
  final cloudC = InkCloud(size: 80, puffs: 4);
  final horizon = _tile(520, 150, (b) {
    final c = b.colors;
    final city = _mix(c.fill(PaletteRole.midtone), c.fill(PaletteRole.accent2), 0.35);
    b.layer();
    for (final (x, w, h) in const [(40.0, 60.0, 50.0), (130.0, 90.0, 40.0), (300.0, 70.0, 56.0), (420.0, 50.0, 36.0)]) {
      b.shape(city, ink: 0.5);
      b.pen.roundRect(x, -h, x + w, 4, 2);
      b.shape(city, ink: 0.5);
      b.pen.ellipse(x + w / 2, -h, w * 0.42, w * 0.36);
    }
    for (final x in const [110.0, 250.0, 395.0]) {
      b.shape(city, ink: 0.5);
      b.pen
        ..moveTo(x - 5, 4)
        ..lineTo(x - 3, -110)
        ..lineTo(x + 3, -110)
        ..lineTo(x + 5, 4)
        ..close();
      b.shape(city, ink: 0.5);
      b.pen.ellipse(x, -112, 7, 6);
    }
    b.endLayer();
  })..shaded = false;
  final dunes = _tile(560, 220, (b) {
    final c = b.colors;
    b.layer();
    _mound(b, -60, 360, -170, 0, _mix(c.fill(PaletteRole.midtone), c.fill(PaletteRole.paper), 0.3), salt: 1);
    _mound(b, 280, 640, -120, 0, _mix(c.fill(PaletteRole.midtone), c.fill(PaletteRole.paper), 0.3), salt: 3);
    b.endLayer();
    b.layer();
    _mound(b, 100, 500, -90, 10, _mix(c.fill(PaletteRole.midtone), c.fill(PaletteRole.paper), 0.08), salt: 5);
    b.endLayer();
  });
  final oasis = _FacedSketch(
    size: 120,
    extent: const Rect.fromLTRB(-80, -260, 560, 8),
    fps: 12,
    draw: (b, face, time) {
      final c = b.colors;
      final trunk = _mix(c.fill(PaletteRole.midtone), c.fill(PaletteRole.shadow), 0.5);
      final leaf = c.fill(PaletteRole.accent2);
      _palm(b, 60, 0, 220, 0.25, math.sin(time * 1.3), trunk, leaf);
      _palm(b, 120, 0, 150, -0.2, math.sin(time * 1.3 + 1), trunk, leaf);
      _cactus(b, 400, 0, 110, _mix(c.fill(PaletteRole.accent2), c.fill(PaletteRole.shadow), 0.25), face, time);
      // A signpost pointing on.
      b.layer();
      b.shape(trunk);
      b.pen.roundRect(495, -90, 503, 0, 2);
      b.shape(c.fill(PaletteRole.paper));
      b.pen
        ..moveTo(470, -92)
        ..lineTo(530, -92)
        ..lineTo(542, -80)
        ..lineTo(530, -68)
        ..lineTo(470, -68)
        ..close();
      b.inkLine(b.lw * 0.5);
      b.pen
        ..moveTo(480, -80)
        ..lineTo(520, -80);
      b.endLayer();
    },
  );
  final floor = _tile(240, 170, (b) {
    final c = b.colors;
    final sand = _mix(c.fill(PaletteRole.midtone), c.fill(PaletteRole.paper), 0.18);
    b.layer();
    b.shape(sand);
    b.pen.roundRect(0, 0, 240, 170, 0);
    b.shade();
    b.pen
      ..moveTo(0, 120)
      ..quadTo(120, 100, 240, 124)
      ..lineTo(240, 170)
      ..lineTo(0, 170)
      ..close();
    b.endLayer();
    b.layer();
    for (var i = 0; i < 5; i++) {
      final y = 20.0 + i * 28;
      b.brushQuad(2, 10 + i * 20.0, y, 60 + i * 20.0, y - 6 + b.ja(20 + i), 110 + i * 20.0, y, b.lw * 0.5, color: _mix(sand, c.ink, 0.35));
    }
    b.inkFill(_mix(sand, c.ink, 0.45));
    b.pen
      ..ellipse(200, 40, 5, 3)
      ..ellipse(30, 150, 4, 2.5)
      ..ellipse(150, 95, 3, 2);
    b.endLayer();
  });
  return [
    sky,
    SetLayer(priority: -36, parallax: 0.03, period: 800, scroll: scroll, props: [PlacedProp(sun, 262, 170)]),
    SetLayer(
      priority: -33,
      parallax: 0.08,
      period: 700,
      scroll: scroll,
      props: [PlacedProp(cloudA, 80, 120), PlacedProp(cloudB, 420, 230), PlacedProp(cloudC, 240, 300)],
    ),
    SetLayer(priority: -30, parallax: 0.14, period: 520, scroll: scroll, props: [PlacedProp(horizon, 0, DemoStage.groundY - 130)]),
    SetLayer(priority: -25, parallax: 0.28, period: 560, scroll: scroll, props: [PlacedProp(dunes, 0, DemoStage.groundY + 2)]),
    SetLayer(priority: -20, parallax: 0.55, period: 600, scroll: scroll, props: [PlacedProp(oasis, 0, DemoStage.groundY + 2)]),
    SetLayer(priority: -10, parallax: 1, period: 240, scroll: scroll, props: [PlacedProp(floor, 0, DemoStage.groundY)]),
  ];
}

// ---------------------------------------------------------------------------
// 1970s: the desert highway at sundown (a heat-haze sun, mesas, poles and
// sagging wires, a billboard, a vulture, cracked asphalt).

List<Component> _grindhouse(CinemaGame game, double Function() scroll) {
  final pal = game.skin.palette;
  final sky = SkyPlane(
    priority: -40,
    scroll: scroll,
    paint: (canvas, k) {
      k.sky(canvas, [_mix(pal.backdrop, pal.ink, 0.3), _mix(pal.accent, pal.backdrop, 0.45), _mix(pal.footlight, pal.accent, 0.4)], const [0, 0.55, 1]);
      k.glow ??= Gradient.radial(const Offset(120, 400), 220, [pal.footlight.withValues(alpha: 0.7), pal.footlight.withValues(alpha: 0)]);
      k.fill.shader = k.glow;
      canvas.drawCircle(const Offset(120, 400), 220, k.fill);
      k.fill.shader = null;
      // The low sun, banded by the haze.
      k.fill.color = _mix(pal.footlight, pal.paper, 0.5);
      for (var i = 0; i < 7; i++) {
        final y = 330.0 + i * 14;
        final hw = math.sqrt(math.max(0, 70 * 70 - (y - 400) * (y - 400)));
        canvas.drawRect(Rect.fromLTRB(120 - hw, y, 120 + hw, y + 9 + i * 0.5), k.fill);
      }
    },
  );
  final mesas = _tile(560, 200, (b) {
    final c = b.colors;
    final rock = _mix(c.fill(PaletteRole.shadow), c.fill(PaletteRole.accent), 0.3);
    b.layer();
    _block(b, 0, 150, 150, rock, ink: 0.6, steps: 1, setback: 0.12);
    _block(b, 220, 90, 110, rock, ink: 0.6, steps: 1, setback: 0.18);
    _block(b, 360, 190, 170, rock, ink: 0.6, steps: 2, setback: 0.1);
    b.shade();
    b.pen
      ..moveTo(60, -140)
      ..lineTo(150, -150)
      ..lineTo(150, 0)
      ..lineTo(80, 0)
      ..close();
    b.shade();
    b.pen
      ..moveTo(450, -160)
      ..lineTo(550, -170)
      ..lineTo(550, 0)
      ..lineTo(470, 0)
      ..close();
    b.endLayer();
  });
  final roadside = _FacedSketch(
    size: 120,
    extent: const Rect.fromLTRB(-60, -300, 620, 8),
    fps: 6,
    draw: (b, face, time) {
      final c = b.colors;
      final wood = _mix(c.fill(PaletteRole.shadow), c.fill(PaletteRole.midtone), 0.35);
      _pole(b, 40, 0, 250, 300, wood);
      _pole(b, 340, 0, 250, 300, wood);
      // A vulture hunched on the wire.
      b.layer();
      b.shape(c.fill(PaletteRole.ink), ink: 0.5);
      b.pen.ellipse(190, -210, 11, 8);
      b.shape(c.fill(PaletteRole.ink), ink: 0.5);
      b.pen.circle(199, -219, 5);
      b.inkFill(c.fill(PaletteRole.accent));
      b.pen
        ..moveTo(203, -219)
        ..lineTo(210, -216)
        ..lineTo(203, -214)
        ..close();
      b.endLayer();
      // Billboard with a starburst (no words – just the glamour).
      b.layer();
      b.shape(wood);
      b.pen.roundRect(470, -150, 478, 0, 2);
      b.shape(wood);
      b.pen.roundRect(540, -150, 548, 0, 2);
      b.shape(c.fill(PaletteRole.paper));
      b.pen.roundRect(430, -230, 590, -140, 4);
      b.shape(c.fill(PaletteRole.accent));
      b.pen.star(470, -185, 8, 26, 14, round: 0.2);
      b.shape(c.fill(PaletteRole.accent2));
      b.pen.roundRect(510, -200, 575, -188, 3);
      b.shape(c.fill(PaletteRole.accent2));
      b.pen.roundRect(510, -176, 560, -166, 3);
      b.endLayer();
      _cactus(b, 250, 0, 90, _mix(c.fill(PaletteRole.accent2), c.fill(PaletteRole.shadow), 0.4), face, time, withFace: false);
      _cactus(b, 600, 0, 60, _mix(c.fill(PaletteRole.accent2), c.fill(PaletteRole.shadow), 0.4), face, time, withFace: false);
    },
  );
  final floor = _tile(240, 170, (b) {
    final c = b.colors;
    final asphalt = _mix(c.fill(PaletteRole.shadow), c.fill(PaletteRole.ink), 0.3);
    final gravel = _mix(c.fill(PaletteRole.midtone), c.fill(PaletteRole.shadow), 0.3);
    b.layer();
    b.shape(gravel);
    b.pen.roundRect(0, 0, 240, 36, 0);
    b.endLayer();
    b.layer();
    b.shape(asphalt);
    b.pen.roundRect(0, 30, 240, 170, 0);
    b.fill(_mix(c.fill(PaletteRole.paper), c.palette.footlight, 0.4));
    b.pen.roundRect(30, 96, 130, 104, 2);
    b.inkLine(b.lw * 0.4);
    b.pen
      ..moveTo(160, 40)
      ..lineTo(175 + b.ja(5, 2), 70)
      ..lineTo(168, 95)
      ..moveTo(170, 72)
      ..lineTo(190, 80);
    b.inkFill(_mix(gravel, c.ink, 0.4));
    b.pen
      ..ellipse(40, 14, 4, 2.5)
      ..ellipse(120, 24, 3, 2)
      ..ellipse(200, 10, 5, 3);
    b.endLayer();
  });
  return [
    sky,
    SetLayer(priority: -30, parallax: 0.12, period: 560, scroll: scroll, props: [PlacedProp(mesas, 0, DemoStage.groundY - 110)]),
    SetLayer(priority: -20, parallax: 0.5, period: 600, scroll: scroll, props: [PlacedProp(roadside, 0, DemoStage.groundY + 2)]),
    SetLayer(priority: -10, parallax: 1, period: 240, scroll: scroll, props: [PlacedProp(floor, 0, DemoStage.groundY)]),
  ];
}

// ---------------------------------------------------------------------------
// 1980s: the neon souk (a striped sun on the horizon, wireframe hills, souk
// arches and palms in glowing tube, a lantern string, a grid floor).

List<Component> _vhs(CinemaGame game, double Function() scroll) {
  final pal = game.skin.palette;
  final sky = SkyPlane(
    priority: -40,
    scroll: scroll,
    paint: (canvas, k) {
      k.sky(canvas, [pal.ink, pal.backdrop, _mix(pal.backdrop, pal.midtone, 0.5)], const [0, 0.6, 1]);
      // Stars.
      k.fill.color = pal.paper.withValues(alpha: 0.7);
      for (var i = 0; i < 26; i++) {
        final x = (i * 97.0 + 13 - (k.scroll() * 0.02) % 560) % 560 - 90;
        final y = (i * 61.0) % 330 + 10;
        final tw = 0.5 + 0.5 * math.sin(k.t * 3 + i);
        canvas.drawCircle(Offset(x, y), 1 + tw * 1.2, k.fill);
      }
      // Horizon glow.
      k.glow ??= Gradient.radial(const Offset(180, 330), 260, [pal.accent.withValues(alpha: 0.35), pal.accent.withValues(alpha: 0)]);
      k.fill.shader = k.glow;
      canvas.drawCircle(const Offset(180, 330), 260, k.fill);
      k.fill.shader = null;
    },
  );
  final sun = InkSketch(
    size: 160,
    extent: const Rect.fromLTRB(-100, -100, 100, 100),
    draw: (b) {
      final c = b.colors;
      const r = 92.0;
      b.layer();
      for (var i = 0; i < 9; i++) {
        final y0 = -r + i * r * 2 / 9, y1 = y0 + r * 2 / 9 - 2 - i * 0.8;
        final hw0 = math.sqrt(math.max(1, r * r - y0 * y0)), hw1 = math.sqrt(math.max(1, r * r - y1 * y1));
        final hw = math.max(hw0, hw1);
        b.shape(_mix(c.palette.accent, c.palette.footlight, i / 9), ink: 0.9);
        b.pen.roundRect(-hw, y0, hw, y1, 3);
      }
      b.endLayer();
    },
  )..shaded = false;
  final hills = _tile(560, 220, (b) {
    final c = b.colors;
    final dark = c.fill(PaletteRole.shadow);
    b.layer();
    for (final (x, w, h) in const [(0.0, 220.0, 150.0), (170.0, 260.0, 190.0), (380.0, 220.0, 120.0)]) {
      b.shape(dark, ink: 0.9);
      b.pen
        ..moveTo(x, 4)
        ..lineTo(x + w * 0.5, -h)
        ..lineTo(x + w, 4)
        ..close();
      b.inkLine(b.lw * 0.5);
      b.pen
        ..moveTo(x + w * 0.5, -h)
        ..lineTo(x + w * 0.5, 4)
        ..moveTo(x + w * 0.25, -h * 0.5)
        ..lineTo(x + w * 0.75, -h * 0.5);
    }
    b.endLayer();
  })..shaded = false;
  final souk = InkSketch(
    size: 120,
    extent: const Rect.fromLTRB(-40, -320, 600, 8),
    fps: 12,
    draw: (b) {
      final c = b.colors;
      final wall = c.fill(PaletteRole.shadow);
      final time = b.time;
      // Three horseshoe arches with crescents on top.
      b.layer();
      b.shape(wall, ink: 0.9);
      b.pen.roundRect(0, -210, 330, 4, 6);
      b.endLayer();
      b.layer();
      for (var i = 0; i < 3; i++) {
        final x = 55.0 + i * 110;
        b.shape(_mix(c.palette.backdrop, c.palette.ink, 0.5), ink: 0.9);
        b.pen
          ..moveTo(x - 36, 0)
          ..lineTo(x - 36, -110)
          ..cubicTo(x - 40, -165, x + 40, -165, x + 36, -110)
          ..lineTo(x + 36, 0)
          ..close();
      }
      b.endLayer();
      b.layer();
      b.inkLine(b.lw * 0.9);
      b.pen
        ..moveTo(0, -215)
        ..lineTo(330, -215);
      for (var i = 0; i < 3; i++) {
        final x = 55.0 + i * 110;
        b.pen
          ..moveTo(x - 30, -232)
          ..cubicTo(x - 20, -270, x + 20, -270, x + 30, -232)
          ..moveTo(x - 20, -236)
          ..cubicTo(x - 12, -262, x + 12, -262, x + 20, -236);
      }
      b.endLayer();
      // Palms in tube.
      _palm(b, 420, 0, 230, 0.2, math.sin(time * 1.2), wall, c.fill(PaletteRole.accent2));
      _palm(b, 520, 0, 170, -0.25, math.sin(time * 1.2 + 2), wall, c.fill(PaletteRole.accent2));
      // Lantern string.
      b.layer();
      b.brushQuad(2, 330, -205, 420, -170, 500, -225, b.lw * 0.5, taperIn: 0.02, taperOut: 0.02);
      b.endLayer();
      b.layer();
      for (var i = 0; i < 4; i++) {
        final x = 350.0 + i * 40, y = -200.0 + 20 * math.sin((i + 0.5) / 4 * math.pi);
        final sw = math.sin(time * 2 + i) * 3;
        b.shape(c.palette.accent, ink: 0.8);
        b.pen.roundRect(x - 7 + sw, y + 4, x + 7 + sw, y + 24, 3);
        b.shape(c.palette.accent, ink: 0.8);
        b.pen.roundRect(x - 4 + sw, y + 24, x + 4 + sw, y + 30, 1);
      }
      b.endLayer();
    },
  )..shaded = false;
  final floor = _tile(240, 170, (b) {
    final c = b.colors;
    b.layer();
    b.shape(_mix(c.palette.backdrop, c.palette.ink, 0.35), ink: 0);
    b.pen.roundRect(0, 0, 240, 170, 0);
    b.endLayer();
    b.layer();
    b.inkLine(b.lw * 0.7);
    for (final y in const [0.0, 10.0, 24.0, 44.0, 72.0, 110.0, 160.0]) {
      b.pen
        ..moveTo(0, y)
        ..lineTo(240, y);
    }
    for (var i = 0; i < 6; i++) {
      final x = i * 40.0;
      b.pen
        ..moveTo(x, 0)
        ..lineTo(x, 170);
    }
    b.endLayer();
  })..shaded = false;
  return [
    sky,
    SetLayer(priority: -36, parallax: 0.02, period: 900, scroll: scroll, props: [PlacedProp(sun, 180, 330)]),
    SetLayer(priority: -30, parallax: 0.12, period: 560, scroll: scroll, props: [PlacedProp(hills, 0, DemoStage.groundY - 100)]),
    SetLayer(priority: -20, parallax: 0.5, period: 640, scroll: scroll, props: [PlacedProp(souk, 0, DemoStage.groundY + 2)]),
    SetLayer(priority: -10, parallax: 1, period: 240, scroll: scroll, props: [PlacedProp(floor, 0, DemoStage.groundY)]),
  ];
}

import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../../engine/cinema_engine.dart';
import '../../engine/rig/rig_kit.dart';
import 'metropolis_rules.dart';

// The machine city of Metropolis Machine, inked with the rig toolkit so the
// set boils and hatches like the cast: a sky of light shafts, stepped
// towers with a ten-hour shift clock, a catwalk where the shift change
// trudges past, one wall of machinery per hall (gears, pipes, cable
// panels, lift shafts, turbines) that slides to the next hall on the
// conveyor between bosses, pumping pistons, and riveted floor plates.
// Everything is cached; nothing is allocated per frame.

/// What the set reads from the game each frame.
abstract interface class MetroSetState {
  /// World travel in units (the floor scrolls on the conveyor).
  double get scroll;

  /// Current hall 0..4 and how far it has slid toward the next (0..1).
  int get hall;
  double get hallSlide;

  /// 0 = the city is dark (the machines have it), 1 = the lights are back.
  double get cityLights;

  /// Where the shift-change crowd is (x offset of the marching line) and
  /// whether it is on stage.
  double get crowdX;
  bool get crowdVisible;
}

Color _mix(Color a, Color b, double t) => Color.lerp(a, b, t)!;

/// Builds the set for [game] (back to front).
List<Component> buildMetroSet(CinemaGame game, MetroSetState state) => [
  _Sky(game, state, priority: -40),
  _FarCity(game, state, priority: -32),
  _Catwalk(state, priority: -28),
  _Crowd(state, priority: -26),
  _HallWall(state, priority: -22),
  _Pistons(state, priority: -16),
  _Floor(state, priority: -10),
  _Vents(state, priority: -9),
];

// ---------------------------------------------------------------------------
// Sky

class _Sky extends Component with HasGameReference<CinemaGame> {
  _Sky(this.game, this.state, {super.priority});

  @override
  final CinemaGame game;
  final MetroSetState state;
  final Paint _fill = Paint();
  final Path _path = Path();
  Shader? _gradient;
  Shader? _dawn;

  static const Rect _rect = Rect.fromLTRB(MetroStage.paintLeft, -320, MetroStage.paintRight, MetroStage.groundY + 4);

  @override
  void render(Canvas canvas) {
    final pal = game.skin.palette;
    _gradient ??= Gradient.linear(
      const Offset(0, -260),
      const Offset(0, MetroStage.groundY),
      [_mix(pal.shadow, pal.ink, 0.35), _mix(pal.backdrop, pal.shadow, 0.5), pal.backdrop],
      const [0, 0.55, 1],
    );
    _fill.shader = _gradient;
    canvas.drawRect(_rect, _fill);
    _fill.shader = null;
    final lights = state.cityLights;
    if (lights > 0) {
      _dawn ??= Gradient.linear(
        const Offset(0, -260),
        const Offset(0, MetroStage.groundY),
        [_mix(pal.paper, pal.footlight, 0.4), _mix(pal.backdrop, pal.paper, 0.5), pal.backdrop],
        const [0, 0.55, 1],
      );
      _fill
        ..shader = _dawn
        ..color = Color.fromRGBO(255, 255, 255, lights * 0.85);
      canvas.drawRect(_rect, _fill);
      _fill
        ..shader = null
        ..color = const Color(0xFFFFFFFF);
    }
    // Shafts of light from the high windows, swaying slowly.
    final t = game.clock.time;
    _fill.color = pal.highlight.withValues(alpha: 0.06 + 0.06 * lights);
    for (var i = 0; i < 3; i++) {
      final sway = math.sin(t * 0.17 + i * 2.1) * 18;
      final x = -20.0 + i * 170 - (state.scroll * 0.06) % 170 + sway;
      _path
        ..reset()
        ..moveTo(x, -320)
        ..lineTo(x + 60, -320)
        ..lineTo(x + 190, MetroStage.groundY)
        ..lineTo(x + 70, MetroStage.groundY)
        ..close();
      canvas.drawPath(_path, _fill);
    }
  }
}

// ---------------------------------------------------------------------------
// Parallax plane of cached props on a repeating tile

class _Plane extends Component with HasGameReference<CinemaGame> {
  _Plane({required this.parallax, required this.period, required this.scroll, super.priority});

  final double parallax;
  final double period;
  final double Function() scroll;
  final List<(InkProp, double, double)> props = [];

  void place(InkProp prop, double x, double y) => props.add((prop, x, y));

  @override
  void update(double dt) {
    for (final p in props) {
      p.$1.update(dt);
    }
  }

  @override
  void render(Canvas canvas) {
    final off = (scroll() * parallax) % period;
    final ctx = game.rigPaint;
    final copies = (MetroStage.paintRight / period).ceil() + 1;
    for (final (prop, px, py) in props) {
      final b = prop.bounds;
      for (var k = -1; k <= copies; k++) {
        final x = px + k * period - off;
        if (x + b.right < MetroStage.paintLeft || x + b.left > MetroStage.paintRight) continue;
        canvas
          ..save()
          ..translate(x, py);
        prop.paint(canvas, ctx);
        canvas.restore();
      }
    }
  }

  @override
  void onRemove() {
    for (final p in props) {
      p.$1.dispose();
    }
    super.onRemove();
  }
}

/// A flat-topped silhouette block with art-deco setbacks.
void _tower(InkBuild b, double x, double w, double h, Color fill, {double ink = 0.6, int steps = 2, double setback = 0.1}) {
  final pen = b.pen;
  b.shape(fill, ink: ink);
  var l = x;
  final r = x + w;
  pen
    ..moveTo(l, 4)
    ..lineTo(l, -h * 0.62);
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
    ..lineTo(r, -h * 0.62)
    ..lineTo(r, 4)
    ..close();
}

void _windows(InkBuild b, double x, double w, double h, double cell, Color lit, Color dark, {double litShare = 0.5, int salt = 0}) {
  final pen = b.pen;
  final cols = (w / cell).floor(), rows = (h / cell).floor();
  for (var pass = 0; pass < 2; pass++) {
    b.fill(pass == 0 ? dark : lit);
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final on = boilHash01(0, b.seed + salt, r * 31 + c) <= litShare;
        if (on != (pass == 1)) continue;
        final wx = x + cell * (c + 0.3), wy = -cell * (r + 0.75);
        pen.roundRect(wx, wy, wx + cell * 0.42, wy + cell * 0.5, cell * 0.06);
      }
    }
  }
}

// ---------------------------------------------------------------------------
// The far city with the ten-hour shift clock

class _FarCity extends _Plane {
  _FarCity(this.game, this.state, {super.priority}) : super(parallax: 0.1, period: 500, scroll: () => state.scroll) {
    _tile = InkSketch(
      size: 120,
      extent: const Rect.fromLTRB(0, -470, 500, 4),
      fps: 2,
      draw: _draw,
    )..shaded = false;
    place(_tile, 0, MetroStage.groundY - 110);
  }

  @override
  final CinemaGame game;
  final MetroSetState state;
  late final InkSketch _tile;
  double _lightsDrawn = -1;
  int _hallDrawn = -1;

  @override
  void update(double dt) {
    super.update(dt);
    if ((state.cityLights - _lightsDrawn).abs() > 0.08 || state.hall != _hallDrawn) {
      _lightsDrawn = state.cityLights;
      _hallDrawn = state.hall;
      _tile.markDirty();
    }
  }

  void _draw(InkBuild b) {
    final c = b.colors;
    final lights = state.cityLights;
    final dark = _mix(c.fill(PaletteRole.shadow), c.fill(PaletteRole.backdrop), 0.3 + 0.2 * lights);
    final darkWin = _mix(dark, c.ink, 0.35);
    final lit = _mix(c.fill(PaletteRole.paper), c.palette.footlight, 0.45);
    final share = 0.22 + 0.6 * lights;
    b.layer();
    _tower(b, 0, 80, 300, dark, steps: 2, setback: 0.12);
    _tower(b, 95, 120, 440, dark, steps: 3, setback: 0.1);
    _tower(b, 230, 70, 260, dark, steps: 1, setback: 0.2);
    _tower(b, 320, 130, 380, dark, steps: 2, setback: 0.14);
    _tower(b, 460, 60, 220, dark, steps: 1, setback: 0.2);
    // Bridges between the towers.
    b.shape(dark, ink: 0.5);
    b.pen.roundRect(80, -200, 95, -190, 2);
    b.shape(dark, ink: 0.5);
    b.pen.roundRect(215, -150, 230, -140, 2);
    _windows(b, 4, 72, 270, 14, lit, darkWin, litShare: share, salt: 1);
    _windows(b, 100, 110, 410, 14, lit, darkWin, litShare: share * 0.9, salt: 2);
    _windows(b, 234, 62, 235, 14, lit, darkWin, litShare: share, salt: 3);
    _windows(b, 324, 122, 350, 14, lit, darkWin, litShare: share * 0.85, salt: 4);
    _windows(b, 464, 52, 195, 14, lit, darkWin, litShare: share, salt: 5);
    b.endLayer();
    // The ten-hour shift clock on the tallest tower: the hour hand climbs a
    // notch per machine beaten.
    const cx = 155.0, cy = -372.0, r = 34.0;
    b.layer();
    b.shape(_mix(c.fill(PaletteRole.paper), c.fill(PaletteRole.midtone), 0.25), ink: 0.9);
    b.pen.circle(cx, cy, r);
    b.inkLine(b.lw * 0.5);
    for (var i = 0; i < 10; i++) {
      final a = i * math.pi * 2 / 10 - math.pi / 2;
      b.pen
        ..moveTo(cx + math.cos(a) * r * 0.82, cy + math.sin(a) * r * 0.82)
        ..lineTo(cx + math.cos(a) * r * 0.94, cy + math.sin(a) * r * 0.94);
    }
    final hour = -math.pi / 2 + (state.hall + 1) * math.pi * 2 / 10;
    final minute = -math.pi / 2 + (b.time * 0.4) % (math.pi * 2);
    b.inkFill();
    b.pen
      ..capsule(cx, cy, cx + math.cos(hour) * r * 0.5, cy + math.sin(hour) * r * 0.5, r * 0.07, r * 0.03)
      ..capsule(cx, cy, cx + math.cos(minute) * r * 0.74, cy + math.sin(minute) * r * 0.74, r * 0.05, r * 0.02);
    Mechanics.rivet(b, cx, cy, r * 0.08);
    b.endLayer();
  }
}

// ---------------------------------------------------------------------------
// The catwalk and the shift change

class _Catwalk extends _Plane {
  _Catwalk(MetroSetState state, {super.priority}) : super(parallax: 0.22, period: 300, scroll: () => state.scroll) {
    final tile = InkSketch(
      size: 120,
      extent: const Rect.fromLTRB(0, -70, 300, 60),
      draw: (b) {
        final c = b.colors;
        final iron = _mix(c.fill(PaletteRole.shadow), c.fill(PaletteRole.backdrop), 0.25);
        final pen = b.pen;
        b.layer();
        b.shape(iron, ink: 0.7);
        pen.roundRect(0, 0, 300, 10, 1);
        // Railing.
        b.inkLine(b.lw * 0.55);
        pen
          ..moveTo(0, -34)
          ..lineTo(300, -34 + b.ja(3, 0.6))
          ..moveTo(0, -18)
          ..lineTo(300, -18);
        for (var i = 0; i < 6; i++) {
          final x = 8.0 + i * 50;
          pen
            ..moveTo(x, -36)
            ..lineTo(x, 0);
        }
        // Struts below.
        for (var i = 0; i < 3; i++) {
          final x = 30.0 + i * 100;
          b.shape(iron, ink: 0.6);
          pen
            ..moveTo(x - 4, 10)
            ..lineTo(x + 4, 10)
            ..lineTo(x + 22, 56)
            ..lineTo(x + 14, 56)
            ..close();
          b.shape(iron, ink: 0.6);
          pen
            ..moveTo(x - 4, 10)
            ..lineTo(x + 4, 10)
            ..lineTo(x - 14, 56)
            ..lineTo(x - 22, 56)
            ..close();
        }
        b.endLayer();
      },
    )..shaded = false;
    place(tile, 0, MetroStage.groundY - 250);
  }
}

/// A line of shift workers trudging along the catwalk, silhouettes with
/// lunch pails and caps, legs walking on eights.
class _Crowd extends Component with HasGameReference<CinemaGame> {
  _Crowd(this.state, {super.priority}) {
    _tile = InkSketch(
      size: 80,
      extent: const Rect.fromLTRB(-20, -70, 380, 6),
      fps: 8,
      draw: _draw,
    )..shaded = false;
  }

  final MetroSetState state;
  late final InkSketch _tile;

  void _draw(InkBuild b) {
    final c = b.colors;
    final pen = b.pen;
    final ink = _mix(c.fill(PaletteRole.shadow), c.ink, 0.5);
    final t = b.time;
    for (var i = 0; i < 7; i++) {
      final x = i * 52.0 + (i.isOdd ? 8 : 0);
      final ph = t * 7 + i * 1.3;
      final bob = math.sin(ph * 2).abs() * 2;
      final h = 46.0 + (i % 3) * 4;
      b.layer();
      // Body, head and cap.
      b.shape(ink, ink: 0.4);
      pen.roundRect(x - 7, -h * 0.72 - bob, x + 7, -h * 0.28 - bob, 3);
      b.shape(ink, ink: 0.4);
      pen.circle(x + 1, -h * 0.84 - bob, h * 0.11);
      b.shape(ink, ink: 0.4);
      pen.roundRect(x - 7, -h * 0.94 - bob, x + 8, -h * 0.9 - bob, 1);
      // Legs.
      final sw = math.sin(ph) * 6;
      b.stroke(ink, 3.2);
      pen
        ..moveTo(x - 3, -h * 0.3 - bob)
        ..lineTo(x - 3 + sw, 0)
        ..moveTo(x + 3, -h * 0.3 - bob)
        ..lineTo(x + 3 - sw, 0);
      // An arm and a lunch pail.
      b.stroke(ink, 2.6);
      pen
        ..moveTo(x + 6, -h * 0.6 - bob)
        ..lineTo(x + 11, -h * 0.4 - bob);
      b.shape(ink, ink: 0.4);
      pen.roundRect(x + 8, -h * 0.4 - bob, x + 15, -h * 0.3 - bob, 1);
      b.endLayer();
    }
  }

  @override
  void update(double dt) => _tile.update(dt);

  @override
  void render(Canvas canvas) {
    if (!state.crowdVisible) return;
    canvas
      ..save()
      ..translate(state.crowdX, MetroStage.groundY - 250);
    _tile.paint(canvas, game.rigPaint);
    canvas.restore();
  }

  @override
  void onRemove() {
    _tile.dispose();
    super.onRemove();
  }
}

// ---------------------------------------------------------------------------
// The hall walls (one per machine), sliding on the conveyor

class _HallWall extends Component with HasGameReference<CinemaGame> {
  _HallWall(this.state, {super.priority}) {
    _walls = [
      _wall(_pressHall),
      _wall(_boilerHall),
      _wall(_spiderHall),
      _wall(_liftHall),
      _wall(_dynamoHall),
    ];
    _gearA = InkGear(size: 210, teeth: 15, speed: 0.3);
    _gearB = InkGear(size: 140, teeth: 11, speed: -0.5, fill: PaletteRole.shadow);
  }

  final MetroSetState state;
  late final List<InkSketch> _walls;
  late final InkGear _gearA, _gearB;
  static const double width = 520;

  static InkSketch _wall(void Function(InkBuild b) draw) =>
      InkSketch(size: 120, extent: const Rect.fromLTRB(-20, -520, width + 20, 8), fps: 6, draw: draw)..shaded = false;

  @override
  void update(double dt) {
    _walls[state.hall].update(dt);
    if (state.hallSlide > 0 && state.hall + 1 < _walls.length) _walls[state.hall + 1].update(dt);
    _gearA.update(dt);
    _gearB.update(dt);
  }

  @override
  void render(Canvas canvas) {
    final ctx = game.rigPaint;
    final slide = state.hallSlide;
    final base = MetroStage.groundY - 20;
    void wall(int i, double x) {
      canvas
        ..save()
        ..translate(x, base);
      _walls[i].paint(canvas, ctx);
      canvas.restore();
    }

    wall(state.hall, -80 - slide * (width + 60));
    if (slide > 0 && state.hall + 1 < _walls.length) wall(state.hall + 1, -80 + (width + 60) * (1 - slide));
    // The great gears of the press hall turn behind it.
    if (state.hall == 0 && slide < 1) {
      final off = -slide * (width + 60);
      canvas
        ..save()
        ..translate(110 + off, MetroStage.groundY + 6);
      _gearA.paint(canvas, ctx);
      canvas.restore();
      canvas
        ..save()
        ..translate(268 + off, MetroStage.groundY - 16);
      _gearB.paint(canvas, ctx);
      canvas.restore();
    }
  }

  @override
  void onRemove() {
    for (final w in _walls) {
      w.dispose();
    }
    _gearA.dispose();
    _gearB.dispose();
    super.onRemove();
  }

  // --- hall 0: the press hall – an overhead crane and stacks ---
  static void _pressHall(InkBuild b) {
    final c = b.colors;
    final pen = b.pen;
    final iron = _mix(c.fill(PaletteRole.midtone), c.fill(PaletteRole.shadow), 0.5);
    final dark = c.fill(PaletteRole.shadow);
    b.layer();
    // Two smokestacks.
    for (final x in const [60.0, 420.0]) {
      b.shape(iron);
      pen
        ..moveTo(x - 24, 0)
        ..lineTo(x - 16, -300)
        ..lineTo(x + 16, -300)
        ..lineTo(x + 24, 0)
        ..close();
      b.shape(iron);
      pen.roundRect(x - 22, -310, x + 22, -296, 3);
      for (var i = 0; i < 5; i++) {
        final y = -40.0 - i * 55;
        Mechanics.rivet(b, x - 16 + i * 1.3, y, 2.2);
        Mechanics.rivet(b, x + 16 - i * 1.3, y, 2.2);
      }
    }
    // Crane gantry.
    b.shape(dark, ink: 0.7);
    pen.roundRect(100, -340, 400, -326, 2);
    b.inkLine(b.lw * 0.5);
    for (var i = 0; i < 7; i++) {
      final x = 110.0 + i * 42;
      pen
        ..moveTo(x, -326)
        ..lineTo(x + 21, -340)
        ..lineTo(x + 42, -326);
    }
    // A hook on a chain.
    pen
      ..moveTo(250, -326)
      ..lineTo(250, -250);
    b.shape(dark, ink: 0.7);
    pen
      ..moveTo(244, -250)
      ..quadTo(240, -228, 252, -226)
      ..quadTo(262, -228, 258, -240)
      ..lineTo(252, -240)
      ..quadTo(250, -232, 256, -250)
      ..close();
    b.endLayer();
    final time = b.time;
    for (final x in const [60.0, 420.0]) {
      Emanata.steam(b, x, -310, 30, (time * 0.4 + x * 0.001) % 1, drift: 0.5);
    }
  }

  // --- hall 1: the boiler hall – pipes, gauges, a tank with a ladder ---
  static void _boilerHall(InkBuild b) {
    final c = b.colors;
    final pen = b.pen;
    final iron = _mix(c.fill(PaletteRole.midtone), c.fill(PaletteRole.shadow), 0.5);
    final dark = c.fill(PaletteRole.shadow);
    final brass = _mix(c.fill(PaletteRole.accent2), c.fill(PaletteRole.paper), 0.3);
    b.layer();
    // Big horizontal pipes with elbows.
    for (var i = 0; i < 3; i++) {
      final y = -300.0 + i * 60;
      b.shape(iron, ink: 0.8);
      pen.roundRect(0, y - 11, width, y + 11, 11);
      b.inkLine(b.lw * 0.45);
      for (var k = 0; k < 6; k++) {
        final x = 40.0 + k * 90 + i * 20;
        pen
          ..moveTo(x, y - 11)
          ..lineTo(x, y + 11)
          ..moveTo(x + 8, y - 11)
          ..lineTo(x + 8, y + 11);
      }
    }
    // Risers down to the floor.
    for (final x in const [90.0, 380.0]) {
      b.shape(iron, ink: 0.8);
      pen.roundRect(x - 10, -300, x + 10, 0, 6);
      b.shape(brass);
      pen.circle(x, -150, 14);
      b.inkLine(b.lw * 0.5);
      pen
        ..moveTo(x - 10, -150)
        ..lineTo(x + 10, -150)
        ..moveTo(x, -160)
        ..lineTo(x, -140);
    }
    // A tank with a ladder and a gauge.
    b.shape(iron);
    pen.roundRect(200, -230, 300, 0, 14);
    b.shape(dark);
    pen.roundRect(196, -170, 304, -162, 2);
    b.shape(dark);
    pen.roundRect(196, -70, 304, -62, 2);
    b.shape(brass);
    pen.circle(250, -120, 22);
    b.shape(c.fill(PaletteRole.paper), ink: 0.7);
    pen.circle(250, -120, 16);
    b.inkFill();
    pen.capsule(250, -120, 258, -131, 2, 1);
    b.inkLine(b.lw * 0.55);
    pen
      ..moveTo(312, 0)
      ..lineTo(312, -220)
      ..moveTo(326, 0)
      ..lineTo(326, -220);
    for (var i = 0; i < 9; i++) {
      final y = -20.0 - i * 24;
      pen
        ..moveTo(312, y)
        ..lineTo(326, y);
    }
    b.endLayer();
    final time = b.time;
    Emanata.steam(b, 90, -300, 22, (time * 0.6) % 1, drift: 0.3);
  }

  // --- hall 2: the switchboard hall – cable bundles, lamp panels ---
  static void _spiderHall(InkBuild b) {
    final c = b.colors;
    final pen = b.pen;
    final dark = c.fill(PaletteRole.shadow);
    final wood = _mix(c.fill(PaletteRole.midtone), c.fill(PaletteRole.shadow), 0.35);
    final brass = _mix(c.fill(PaletteRole.accent2), c.fill(PaletteRole.paper), 0.3);
    final time = b.time;
    b.layer();
    // A wall of switchboard panels.
    for (var i = 0; i < 4; i++) {
      final x = 20.0 + i * 125;
      b.shape(wood, ink: 0.7);
      pen.roundRect(x, -330, x + 110, 0, 4);
      for (var r = 0; r < 8; r++) {
        for (var k = 0; k < 5; k++) {
          b.fill(c.dark);
          pen.circle(x + 15 + k * 20, -310 + r * 36, 4);
        }
      }
      // Blinking lamps along the top.
      for (var k = 0; k < 4; k++) {
        final on = ((time * 3).floor() + k + i) % 5 == 0;
        b.shape(on ? c.hot : brass, ink: 0.6);
        pen.circle(x + 20 + k * 24, -318, 6);
      }
    }
    b.endLayer();
    // Cable bundles sagging across the top, insulators on them.
    b.layer();
    for (var i = 0; i < 3; i++) {
      final y = -400.0 + i * 22;
      b.brushQuad(2, -20, y, width / 2, y + 60 + b.ja(5 + i, 3), width + 20, y - 10, b.lw * (0.7 + i * 0.1), color: dark, taperIn: 0.02, taperOut: 0.02);
    }
    for (final x in const [120.0, 300.0, 440.0]) {
      b.shape(brass, ink: 0.6);
      pen.ellipse(x, -368 + (x / width) * 40, 7, 10);
    }
    b.endLayer();
  }

  // --- hall 3: the lift hall – shafts, counterweights, a girder lattice ---
  static void _liftHall(InkBuild b) {
    final c = b.colors;
    final pen = b.pen;
    final iron = _mix(c.fill(PaletteRole.midtone), c.fill(PaletteRole.shadow), 0.55);
    final dark = c.fill(PaletteRole.shadow);
    final time = b.time;
    b.layer();
    for (var i = 0; i < 3; i++) {
      final x = 40.0 + i * 180;
      // Shaft rails and braces.
      for (final rx in [x, x + 90]) {
        b.shape(dark, ink: 0.7);
        pen.roundRect(rx - 5, -440, rx + 5, 0, 2);
      }
      b.inkLine(b.lw * 0.45);
      for (var k = 0; k < 9; k++) {
        final y = -30.0 - k * 48;
        pen
          ..moveTo(x, y)
          ..lineTo(x + 90, y - 24 * (k.isEven ? 1 : -1));
      }
      // A counterweight gliding in the shaft.
      final cy = -200.0 + math.sin(time * 0.5 + i * 2) * 120;
      b.shape(iron);
      pen.roundRect(x + 30, cy - 30, x + 60, cy + 30, 3);
      Mechanics.rivet(b, x + 45, cy - 20, 2.5);
      Mechanics.rivet(b, x + 45, cy + 20, 2.5);
      b.inkLine(b.lw * 0.5);
      pen
        ..moveTo(x + 45, cy - 30)
        ..lineTo(x + 45, -440);
      // The sheave on top.
      b.shape(dark, ink: 0.7);
      pen.circle(x + 45, -448, 14);
    }
    b.endLayer();
  }

  // --- hall 4: the dynamo hall – turbines, cable trays, a transformer ---
  static void _dynamoHall(InkBuild b) {
    final c = b.colors;
    final pen = b.pen;
    final iron = _mix(c.fill(PaletteRole.midtone), c.fill(PaletteRole.shadow), 0.5);
    final dark = c.fill(PaletteRole.shadow);
    final brass = _mix(c.fill(PaletteRole.accent2), c.fill(PaletteRole.paper), 0.3);
    final time = b.time;
    b.layer();
    // Turbine cylinders lying on saddles.
    for (var i = 0; i < 2; i++) {
      final x = 30.0 + i * 270, y = -120.0;
      b.shape(iron);
      pen.roundRect(x, y - 70, x + 220, y + 70, 60);
      b.shape(dark);
      pen.roundRect(x + 40, y - 74, x + 52, y + 74, 3);
      b.shape(dark);
      pen.roundRect(x + 160, y - 74, x + 172, y + 74, 3);
      for (var k = 0; k < 4; k++) {
        Mechanics.rivet(b, x + 70 + k * 24, y - 50, 2.4);
        Mechanics.rivet(b, x + 70 + k * 24, y + 50, 2.4);
      }
      // Saddle legs.
      b.shape(dark, ink: 0.7);
      pen.roundRect(x + 30, y + 60, x + 60, 0, 2);
      b.shape(dark, ink: 0.7);
      pen.roundRect(x + 160, y + 60, x + 190, 0, 2);
    }
    // Transformer with insulators between them.
    b.shape(iron);
    pen.roundRect(236, -260, 300, -200, 6);
    for (var k = 0; k < 3; k++) {
      final x = 246.0 + k * 22;
      b.shape(brass, ink: 0.6);
      pen.ellipse(x, -270, 5, 9);
      b.shape(brass, ink: 0.6);
      pen.ellipse(x, -284, 4, 7);
    }
    // Cable trays overhead with bundles.
    b.shape(dark, ink: 0.7);
    pen.roundRect(0, -380, width, -366, 2);
    b.inkLine(b.lw * 0.5);
    for (var k = 0; k < 11; k++) {
      final x = 20.0 + k * 48;
      pen
        ..moveTo(x, -366)
        ..lineTo(x + 24, -380);
    }
    b.endLayer();
    // Sparks crawling along the transformer in the final hall.
    if (((time * 4).floor() % 3) == 0) Mechanics.sparks(b, 268, -292, 9, 33);
  }
}

// ---------------------------------------------------------------------------
// Pumping pistons behind the floor line

class _Pistons extends _Plane {
  _Pistons(MetroSetState state, {super.priority}) : super(parallax: 0.6, period: 360, scroll: () => state.scroll) {
    final tile = InkSketch(
      size: 120,
      extent: const Rect.fromLTRB(-20, -150, 380, 8),
      fps: 12,
      draw: (b) {
        final c = b.colors;
        final pen = b.pen;
        final iron = _mix(c.fill(PaletteRole.midtone), c.fill(PaletteRole.shadow), 0.4);
        final dark = c.fill(PaletteRole.shadow);
        final t = b.time;
        for (var i = 0; i < 2; i++) {
          final x = 70.0 + i * 220;
          final ph = t * 2.4 + i * math.pi;
          final lift = (math.sin(ph) * 0.5 + 0.5) * 50;
          b.layer();
          // Cylinder.
          b.shape(dark, ink: 0.8);
          pen.roundRect(x - 26, -70, x + 26, 0, 4);
          // Piston rod and crosshead.
          b.shape(iron, ink: 0.8);
          pen.roundRect(x - 7, -130 + lift, x + 7, -66, 3);
          b.shape(iron);
          pen.roundRect(x - 20, -140 + lift, x + 20, -124 + lift, 3);
          Mechanics.rivet(b, x - 12, -132 + lift, 2.2);
          Mechanics.rivet(b, x + 12, -132 + lift, 2.2);
          // Flywheel beside it.
          b.endLayer();
          Mechanics.gear(b, x + 70, -40, 28, 10, ph * 0.5, fill: iron, hub: dark, holes: 3, shaded: false);
          b.layer();
          b.inkLine(b.lw * 0.7);
          pen
            ..moveTo(x + 70 + math.cos(ph * 0.5) * 18, -40 + math.sin(ph * 0.5) * 18)
            ..lineTo(x + 14, -132 + lift);
          b.endLayer();
        }
      },
    )..shaded = false;
    place(tile, 0, MetroStage.groundY - 2);
  }
}

// ---------------------------------------------------------------------------
// The floor and the vents

class _Floor extends _Plane {
  _Floor(MetroSetState state, {super.priority}) : super(parallax: 1, period: 240, scroll: () => state.scroll) {
    final tile = InkSketch(
      size: 120,
      extent: const Rect.fromLTRB(0, 0, 240, 180),
      draw: (b) {
        final c = b.colors;
        final pen = b.pen;
        final plate = _mix(c.fill(PaletteRole.midtone), c.fill(PaletteRole.shadow), 0.5);
        b.layer();
        b.shape(plate);
        pen.roundRect(0, 0, 240, 180, 0);
        b.shade();
        pen.roundRect(0, 96, 240, 180, 0);
        b.inkLine(b.lw * 0.7);
        pen
          ..moveTo(120, 0)
          ..lineTo(120 + b.ja(3), 180)
          ..moveTo(0, 48)
          ..lineTo(240, 48 + b.ja(4));
        for (var i = 0; i < 6; i++) {
          Mechanics.rivet(b, 12 + i * 44.0, 10, 2.6);
          Mechanics.rivet(b, 32 + i * 44.0, 38, 2.6);
        }
        for (var i = 0; i < 4; i++) {
          Mechanics.rivet(b, 112, 72 + i * 28.0, 2.6);
        }
        // Tread diamonds on the front plates.
        b.inkLine(b.lw * 0.4);
        for (var i = 0; i < 5; i++) {
          final x = 20.0 + i * 48;
          pen
            ..moveTo(x, 110)
            ..lineTo(x + 10, 120)
            ..lineTo(x, 130)
            ..lineTo(x - 10, 120)
            ..close();
        }
        b.endLayer();
      },
    );
    place(tile, 0, MetroStage.groundY);
  }
}

/// Vent grates in the floor (boiler and dynamo halls).
class _Vents extends Component with HasGameReference<CinemaGame> {
  _Vents(this.state, {super.priority}) {
    _grate = InkSketch(
      size: 60,
      extent: const Rect.fromLTRB(-30, -8, 30, 12),
      draw: (b) {
        final c = b.colors;
        final pen = b.pen;
        final dark = c.fill(PaletteRole.shadow);
        b.layer();
        b.shape(dark);
        pen.roundRect(-26, -5, 26, 7, 3);
        b.fill(c.dark);
        pen.roundRect(-22, -2, 22, 4, 1);
        b.inkLine(b.lw * 0.6);
        for (var i = -3; i <= 3; i++) {
          pen
            ..moveTo(i * 6.0, -2)
            ..lineTo(i * 6.0, 4);
        }
        Mechanics.rivet(b, -24, 1, 1.8);
        Mechanics.rivet(b, 24, 1, 1.8);
        b.endLayer();
      },
    )..shaded = false;
  }

  final MetroSetState state;
  late final InkSketch _grate;

  bool get _visible => state.hall == 1 || state.hall == 4;

  @override
  void render(Canvas canvas) {
    if (!_visible || state.hallSlide > 0) return;
    final ctx = game.rigPaint;
    for (final x in MetroStage.vents) {
      canvas
        ..save()
        ..translate(x, MetroStage.groundY);
      _grate.paint(canvas, ctx);
      canvas.restore();
    }
  }

  @override
  void onRemove() {
    _grate.dispose();
    super.onRemove();
  }
}

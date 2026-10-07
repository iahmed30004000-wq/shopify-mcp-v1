import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../../engine/cinema_engine.dart';
import '../../engine/rig/rig_kit.dart';
import 'flappy_orbit_logic.dart';

/// World-unit constants shared by the game's files.
abstract final class OrbitStage {
  static const double width = 360;
  static const double height = 800;

  /// Where the rocket hangs (it only moves vertically).
  static const double heroX = 112;

  /// Top of the rooftop ledge (the set's ground line).
  static const double groundY = 700;

  /// Painted beyond the design width: the camera "contains" the world and
  /// the stage spins in the last boss phase.
  static const double paintLeft = -140;
  static const double paintRight = 500;
}

/// Counts the game's own allocation sites (drawings, pools, paints) so a
/// test can prove the hot paths allocate nothing: every constructor below
/// bumps it; update/render never do.
abstract final class OrbitAllocations {
  static int count = 0;
  static void note() => count++;
}

Color _mix(Color a, Color b, double t) => Color.lerp(a, b, t)!;

/// The gates: pooled [GateSlot]s from the [GateSpawner], each drawn as a
/// hanging prop above the gap and a standing prop below it, both inked
/// once per kind and variant and replayed everywhere (they boil at 12 fps
/// and animate with time). Props pulse on the beat ([beat] is fed by the
/// game) and the whole pair sways with the slot's swing.
class GateField extends Component with HasGameReference<CinemaGame> {
  GateField({required this.spawner, required this.beat, super.priority}) {
    for (final kind in GateKind.values) {
      for (var v = 0; v < 2; v++) {
        _tops.add(_sketch(kind, true, v));
        _bottoms.add(_sketch(kind, false, v));
      }
    }
    OrbitAllocations.note();
  }

  final GateSpawner spawner;

  /// Beats since the music started (for the sway and the pulse).
  final double Function() beat;
  final List<InkSketch> _tops = [];
  final List<InkSketch> _bottoms = [];

  static const double _reach = 860;

  InkSketch _sketch(GateKind kind, bool top, int variant) => InkSketch(
    size: 120,
    extent: top ? const Rect.fromLTRB(-50, -_reach, 50, 6) : const Rect.fromLTRB(-50, -6, 50, _reach),
    fps: 12,
    seed: variant * 17 + kind.index * 3,
    draw: switch (kind) {
      GateKind.horns => top ? _hornTop : _hornBottom,
      GateKind.chimney => top ? _cloudPillar : _chimney,
      GateKind.flags => top ? _buntingDrop : _flagpole,
      GateKind.balloons => top ? _balloonsHanging : _balloonsRising,
    },
  );

  @override
  void update(double dt) {
    for (final p in _tops) {
      p.update(dt);
    }
    for (final p in _bottoms) {
      p.update(dt);
    }
  }

  @override
  void render(Canvas canvas) {
    final ctx = game.rigPaint;
    final bt = beat();
    final pulse = Bounce.contact(bt);
    for (final g in spawner.pool) {
      if (!g.active) continue;
      if (g.x + 60 < OrbitStage.paintLeft || g.x - 60 > OrbitStage.paintRight) continue;
      final i = g.kind.index * 2 + g.variant;
      final top = g.topEdgeAt(bt), bottom = g.bottomEdgeAt(bt);
      canvas
        ..save()
        ..translate(g.x, top)
        ..scale(1 + 0.045 * pulse, 1 + 0.02 * pulse);
      _tops[i].paint(canvas, ctx);
      canvas
        ..restore()
        ..save()
        ..translate(g.x, bottom)
        ..scale(1 + 0.045 * pulse, 1 + 0.02 * pulse);
      _bottoms[i].paint(canvas, ctx);
      canvas.restore();
    }
  }

  @override
  void onRemove() {
    for (final p in _tops) {
      p.dispose();
    }
    for (final p in _bottoms) {
      p.dispose();
    }
    super.onRemove();
  }

  // ------------------------------------------------------------- drawings
  // Origin = the gap edge; a "top" prop extends upward (negative y), a
  // "bottom" prop downward. Each is a solid obstacle 38 units either side of
  // its axis at the gap, inked in the house style.

  static Color _brass(InkBuild b) => _mix(b.colors.fill(PaletteRole.midtone), b.colors.fill(PaletteRole.highlight), 0.4);

  /// A brass horn hanging bell-down: tube, a curl, three valves, the bell
  /// flaring to the gap edge.
  static void _hornTop(InkBuild b) => _horn(b, -1);

  /// The same horn standing bell-up on the rooftops.
  static void _hornBottom(InkBuild b) => _horn(b, 1);

  static void _horn(InkBuild b, double d) {
    final pen = b.pen;
    final brass = _brass(b);
    final dark = b.colors.fill(PaletteRole.shadow);
    final sway = math.sin(b.time * 2.1) * 2;
    b.layer();
    // Tube from far away to the bell.
    b.shape(brass);
    pen.roundRect(-11, d > 0 ? 120 : -_reach, 11, d > 0 ? _reach : -120, 6);
    // A curl in the tube.
    b.shape(brass);
    pen.circle(0, d * 240, 34);
    b.shape(b.colors.fill(PaletteRole.backdrop), ink: 0.9);
    pen.circle(0, d * 240, 14);
    // Valves.
    for (var i = -1; i <= 1; i++) {
      b.shape(brass);
      pen.roundRect(-5 + i * 14, d * 330 - 16, 5 + i * 14, d * 330 + 16, 3);
      b.shape(dark, ink: 0.7);
      pen.circle(i * 14, d * (330 - 22), 5);
    }
    // The bell: flares from the tube to the gap edge.
    b.shape(brass);
    pen
      ..moveTo(-11, d * 124)
      ..cubicTo(-14, d * 70, -42 + sway, d * 30, -44 + sway, d * 2)
      ..lineTo(44 + sway, d * 2)
      ..cubicTo(42 + sway, d * 30, 14, d * 70, 11, d * 124)
      ..close();
    b.shape(dark);
    pen.ellipse(sway, d * 3, 44, 7);
    b.fill(b.colors.dark);
    pen.ellipse(sway, d * 3, 34, 4);
    // Shine and a shading crescent on the bell.
    final ct = b.contour(0)..clear();
    ct.ellipse(pen, 0, d * 60, 30, 60, samples: 24);
    ct.writeCrescent(b.shade(), kShadowX, kShadowY, 12);
    b.brushQuad(2, -20, d * 100, -30 + sway * 0.5, d * 60, -36 + sway, d * 22, b.lw, color: b.colors.shine, taperIn: 0.3, taperOut: 0.3);
    b.endLayer();
  }

  /// A pillar of stacked cloud puffs hanging from the sky, its lowest puff
  /// flat on the gap; rain streaks drip from it.
  static void _cloudPillar(InkBuild b) {
    final pen = b.pen;
    final fill = b.colors.puff;
    b.layer();
    for (var i = 0; i < 9; i++) {
      final y = -30 - i * 95.0;
      final r = 38 + 8 * math.sin(i * 1.7) + b.ja(i, 0.8);
      b.shape(fill);
      pen.circle(-16 + 10 * math.sin(i * 2.3), y, r * 0.8);
      b.shape(fill);
      pen.circle(14 + 8 * math.cos(i * 1.9), y - 20, r * 0.75);
      b.shape(fill);
      pen.circle(0, y + 25, r * 0.7);
    }
    b.shape(fill);
    pen.roundRect(-44, -40, 44, 0, 18);
    b.shade();
    pen
      ..moveTo(-40, -12)
      ..quadTo(0, -2, 40, -12)
      ..lineTo(40, 0)
      ..lineTo(-40, 0)
      ..close();
    b.endLayer();
    // Drips.
    b.layer();
    b.inkLine(b.lw * 0.5);
    for (var i = 0; i < 4; i++) {
      final k = (b.time * 1.4 + i * 0.27) % 1;
      final x = -30 + i * 20.0;
      pen
        ..moveTo(x, 2 + k * 14)
        ..lineTo(x - 1, 8 + k * 14);
    }
    b.endLayer();
  }

  /// A brick chimney stack with a cap and a column of smoke rising to the
  /// gap edge.
  static void _chimney(InkBuild b) {
    final pen = b.pen;
    final c = b.colors;
    final brick = _mix(c.fill(PaletteRole.midtone), c.fill(PaletteRole.shadow), 0.3);
    final dark = c.fill(PaletteRole.shadow);
    b.layer();
    b.shape(brick);
    pen.roundRect(-28, 150, 28, _reach, 3);
    b.shape(dark);
    pen.roundRect(-36, 136, 36, 156, 3);
    b.shape(brick);
    pen.roundRect(-20, 112, 20, 140, 2);
    final ct = b.contour(0)..clear();
    ct.ellipse(pen, 0, 480, 28, 330, samples: 28);
    ct.writeCrescent(b.shade(), kShadowX, kShadowY, 10);
    b.inkLine(b.lw * 0.45);
    for (var r = 0; r < 14; r++) {
      final y = 170 + r * 36.0;
      pen
        ..moveTo(-28, y)
        ..lineTo(28, y + b.ja(40 + r, 0.4));
      final off = r.isEven ? 0.0 : 14.0;
      for (var k = -1; k <= 1; k++) {
        pen
          ..moveTo(k * 28 + off - 14, y)
          ..lineTo(k * 28 + off - 14, y + 36);
      }
    }
    b.endLayer();
    // Smoke: puffs rising from the cap to the gap edge (the top puff sits
    // on the edge), each with its own crescent.
    b.layer();
    final rise = (b.time * 18) % 26;
    for (var i = 0; i < 4; i++) {
      final y = 106 - i * 26.0 - rise * (i == 3 ? 0 : 1) + (i == 3 ? 0 : 0);
      final r = 18 + i * 7.0;
      final cc = b.contour(1)..clear();
      cc.ellipse(pen, (i.isEven ? -6 : 6) + b.ja(50 + i, 1.5), y.clamp(8.0, 120.0), r, r * 0.9, samples: 20);
      b.blob(cc, c.puff, depth: r * 0.3, ink: 0.8);
    }
    final top = b.contour(1)..clear();
    top.ellipse(pen, 0, 22, 44, 24, samples: 24);
    b.blob(top, c.puff, depth: 9, ink: 0.85);
    b.brushQuad(2, -10, 18, 6, 2, 22, 14, b.lw * 0.7, taperIn: 0.1, taperOut: 0.8);
    b.endLayer();
  }

  /// A rope hanging from the sky, bunting flags on both sides, a tassel at
  /// the gap.
  static void _buntingDrop(InkBuild b) {
    final pen = b.pen;
    final c = b.colors;
    final rope = c.fill(PaletteRole.shadow);
    b.layer();
    b.shape(rope, ink: 0.9);
    pen.roundRect(-4, -_reach, 4, -14, 2);
    for (var i = 0; i < 14; i++) {
      final y = -40 - i * 58.0;
      final side = i.isEven ? -1.0 : 1.0;
      final wave = math.sin(b.time * 4 + i) * 5;
      b.shape(i % 3 == 0 ? c.fill(PaletteRole.accent2) : c.fill(PaletteRole.paper), ink: 0.8);
      pen
        ..moveTo(side * 3, y - 18)
        ..lineTo(side * 3, y + 18)
        ..lineTo(side * (40 + wave), y + wave * 0.4)
        ..close();
      if (i % 3 == 1) {
        b.fill(c.dark);
        pen.circle(side * 18, y, 3.5);
      }
    }
    // Tassel.
    b.shape(rope, ink: 0.9);
    pen.ellipse(0, -14, 9, 7);
    for (var k = -2; k <= 2; k++) {
      b.brushQuad(2, k * 3.0, -9, k * 5.0 + b.ja(60 + k, 1), -2, k * 7.0, 2, b.lw * 0.9, taperIn: 0.05, taperOut: 0.7);
    }
    b.endLayer();
  }

  /// A flagpole with a finial, a big waving flag at the top.
  static void _flagpole(InkBuild b) {
    final pen = b.pen;
    final c = b.colors;
    final pole = _mix(c.fill(PaletteRole.midtone), c.fill(PaletteRole.shadow), 0.5);
    b.layer();
    b.shape(pole, ink: 0.9);
    pen.roundRect(-6, 10, 6, _reach, 3);
    b.shape(_brass(b));
    pen.circle(0, 6, 9);
    // Base plinth.
    b.shape(pole);
    pen.roundRect(-30, 400, 30, 430, 4);
    b.endLayer();
    // The flag: a rectangle whose free edge waves with time.
    b.layer();
    final t = b.time * 5;
    b.shape(c.fill(PaletteRole.paper), ink: 0.85);
    pen.moveTo(6, 16);
    for (var i = 0; i <= 6; i++) {
      final k = i / 6;
      pen.lineTo(6 + k * 70, 16 + math.sin(t + k * 4) * 6 * k);
    }
    for (var i = 6; i >= 0; i--) {
      final k = i / 6;
      pen.lineTo(6 + k * 70, 62 + math.sin(t + k * 4 + 0.6) * 6 * k);
    }
    pen.close();
    // A star on the flag.
    b.inkFill();
    pen.star(40, 39 + math.sin(t + 2) * 3, 5, 12, 5.5, round: 0.2);
    b.endLayer();
    // A couple of pennants further down the pole.
    b.layer();
    for (var i = 0; i < 3; i++) {
      final y = 110 + i * 40.0;
      b.shape(i.isEven ? c.fill(PaletteRole.accent2) : c.fill(PaletteRole.paper), ink: 0.8);
      pen
        ..moveTo(6, y)
        ..lineTo(6, y + 20)
        ..lineTo(34 + math.sin(t + i) * 3, y + 10)
        ..close();
    }
    b.endLayer();
  }

  /// A bunch of balloons hanging on strings from above, the lowest balloon
  /// on the gap edge.
  static void _balloonsHanging(InkBuild b) => _balloons(b, -1);

  /// A bunch of balloons rising on strings from a rooftop crate.
  static void _balloonsRising(InkBuild b) => _balloons(b, 1);

  static void _balloons(InkBuild b, double d) {
    final pen = b.pen;
    final c = b.colors;
    final string = c.fill(PaletteRole.shadow);
    final bob = math.sin(b.time * 2.6) * 3;
    // Strings.
    b.layer();
    b.inkLine(b.lw * 0.45);
    for (var i = -1; i <= 1; i++) {
      pen
        ..moveTo(i * 6.0, d * 70)
        ..quadTo(i * 14.0, d * 400, i * 4.0, d * _reach);
    }
    b.shape(string, ink: 0.8);
    pen.ellipse(0, d * 74, 5, 4);
    b.endLayer();
    // Balloons: five overlapping ovals, the nearest the gap on the edge.
    b.layer();
    const xs = [-22.0, 20.0, -6.0, 24.0, -20.0];
    const ys = [26.0, 30.0, 56.0, 76.0, 82.0];
    const rs = [22.0, 20.0, 24.0, 18.0, 17.0];
    for (var i = 4; i >= 0; i--) {
      final fill = i.isEven ? c.fill(PaletteRole.paper) : c.fill(PaletteRole.accent2);
      final x = xs[i] + b.ja(70 + i, 0.8), y = d * ys[i] + bob * (i.isEven ? 1 : -1);
      final ct = b.contour(0)..clear();
      ct.ellipse(pen, x, y, rs[i], rs[i] * 1.18, samples: 24);
      ct.wobble(b.amp * 0.5, b.frame, b.seed, 80 + i);
      b.blob(ct, fill, depth: rs[i] * 0.35, threshold: 0.2);
      b.fill(c.shine);
      pen.ellipse(x - rs[i] * 0.35, y - rs[i] * 0.45, rs[i] * 0.18, rs[i] * 0.1, -0.7);
      // Knot toward the strings.
      b.inkFill();
      pen
        ..moveTo(x - 3, y - d * rs[i] * 1.18)
        ..lineTo(x + 3, y - d * rs[i] * 1.18)
        ..lineTo(x, y - d * (rs[i] * 1.18 + 5))
        ..close();
    }
    b.endLayer();
  }
}

/// The Maestro's projectiles: thunder-notes (quavers whose stems are
/// lightning bolts, aimed at the hero) and gusts (bands of curling wind
/// that shove the rocket up or down). Pooled; two shared drawings.
class BossAttacks extends Component with HasGameReference<CinemaGame> {
  BossAttacks({super.priority}) {
    _note = InkSketch(size: 60, extent: const Rect.fromLTRB(-30, -40, 30, 30), fps: 24, draw: _drawNote);
    _gust = InkSketch(size: 120, extent: const Rect.fromLTRB(-90, -60, 90, 60), fps: 12, draw: _drawGust);
    OrbitAllocations.note();
  }

  static const int noteCount = 4;
  static const int gustCount = 2;
  static const double noteRadius = 17;
  static const double gustHalfHeight = 52;

  /// Notes are lobbed: gravity pulls them down onto their mark.
  static const double noteGravity = 900;

  /// A gust starts slowly and accelerates across the sky.
  static const double gustSpeed0 = 150;
  static const double gustAccel = 700;
  static const double gustSpeedMax = 560;

  late final InkSketch _note;
  late final InkSketch _gust;

  // Notes: active, x, y, vx, vy, age, spin.
  final List<bool> _nActive = List.filled(noteCount, false);
  final List<double> _nx = List.filled(noteCount, 0);
  final List<double> _ny = List.filled(noteCount, 0);
  final List<double> _nvx = List.filled(noteCount, 0);
  final List<double> _nvy = List.filled(noteCount, 0);
  final List<double> _nage = List.filled(noteCount, 0);
  // Gusts: active, x, y, dir (+1 pushes down, -1 up), age, shoved.
  final List<bool> _gActive = List.filled(gustCount, false);
  final List<double> _gx = List.filled(gustCount, 0);
  final List<double> _gy = List.filled(gustCount, 0);
  final List<double> _gdir = List.filled(gustCount, 1);
  final List<double> _gage = List.filled(gustCount, 0);
  final List<bool> _gShoved = List.filled(gustCount, false);

  /// Called when a note strikes the hero.
  void Function()? onNoteHit;

  /// Called when a gust catches the hero ([dir] +1 = down, -1 = up).
  void Function(double dir)? onGust;

  /// The hero's hit circle, set by the game each tick.
  double heroX = OrbitStage.heroX, heroY = 360, heroRadius = 20;

  /// The lane a gust is about to blow along (shown while the Maestro
  /// inhales); `null` hides it. [lanePreview] 0..1 fades it in.
  double? laneY;
  double lanePreview = 0;
  final Paint _lanePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;

  int get activeNotes {
    var n = 0;
    for (final a in _nActive) {
      if (a) n++;
    }
    return n;
  }

  int get activeGusts {
    var n = 0;
    for (final a in _gActive) {
      if (a) n++;
    }
    return n;
  }

  double noteX(int i) => _nx[i];
  double noteY(int i) => _ny[i];
  bool noteActive(int i) => _nActive[i];
  double gustX(int i) => _gx[i];
  double gustY(int i) => _gy[i];
  double gustDir(int i) => _gdir[i];
  bool gustActive(int i) => _gActive[i];

  /// Lobs a note from ([x], [y]) so that it lands on ([tx], [ty]) after
  /// [flightTime] seconds (an arc the hero can read).
  void fireNote(double x, double y, double tx, double ty, {double flightTime = 0.85}) {
    for (var i = 0; i < noteCount; i++) {
      if (_nActive[i]) continue;
      final t = math.max(0.3, flightTime);
      _nActive[i] = true;
      _nx[i] = x;
      _ny[i] = y;
      _nvx[i] = (tx - x) / t;
      _nvy[i] = (ty - y) / t - 0.5 * noteGravity * t;
      _nage[i] = 0;
      return;
    }
  }

  /// Where note [i] will be when it reaches [atX] (its mark), for dodging.
  double noteYAt(int i, double atX) {
    final vx = _nvx[i];
    if (vx.abs() < 1e-6) return _ny[i];
    final t = math.max(0.0, (atX - _nx[i]) / vx);
    return _ny[i] + _nvy[i] * t + 0.5 * noteGravity * t * t;
  }

  /// Blows a gust from [x] across the band centred on [y].
  void blowGust(double x, double y, double dir) {
    for (var i = 0; i < gustCount; i++) {
      if (_gActive[i]) continue;
      _gActive[i] = true;
      _gx[i] = x;
      _gy[i] = y;
      _gdir[i] = dir;
      _gage[i] = 0;
      _gShoved[i] = false;
      return;
    }
  }

  void clear() {
    for (var i = 0; i < noteCount; i++) {
      _nActive[i] = false;
    }
    for (var i = 0; i < gustCount; i++) {
      _gActive[i] = false;
    }
  }

  @override
  void update(double dt) {
    _note.update(dt);
    _gust.update(dt);
    for (var i = 0; i < noteCount; i++) {
      if (!_nActive[i]) continue;
      _nage[i] += dt;
      _nvy[i] += noteGravity * dt;
      _nx[i] += _nvx[i] * dt;
      _ny[i] += _nvy[i] * dt;
      if (_nx[i] < OrbitStage.paintLeft || _ny[i] < -200 || _ny[i] > OrbitStage.height + 200) {
        _nActive[i] = false;
        continue;
      }
      final dx = _nx[i] - heroX, dy = _ny[i] - heroY;
      final r = noteRadius + heroRadius;
      if (dx * dx + dy * dy < r * r) {
        _nActive[i] = false;
        onNoteHit?.call();
      }
    }
    for (var i = 0; i < gustCount; i++) {
      if (!_gActive[i]) continue;
      _gage[i] += dt;
      _gx[i] -= math.min(gustSpeedMax, gustSpeed0 + gustAccel * _gage[i]) * dt;
      if (_gx[i] < OrbitStage.paintLeft - 60) {
        _gActive[i] = false;
        continue;
      }
      if (!_gShoved[i] && (_gx[i] - heroX).abs() < 70 && (_gy[i] - heroY).abs() < gustHalfHeight + heroRadius * 0.5) {
        _gShoved[i] = true;
        onGust?.call(_gdir[i]);
      }
    }
  }

  @override
  void render(Canvas canvas) {
    final ctx = game.rigPaint;
    final lane = laneY;
    if (lane != null && lanePreview > 0.02) {
      // Faint dashes along the lane the gust will take.
      final pal = game.skin.palette;
      _lanePaint
        ..color = pal.ink.withValues(alpha: 0.35 * lanePreview)
        ..strokeWidth = 3 / math.max(0.4, ctx.pixelScale);
      final phase = (game.clock.time * 260) % 40;
      for (var k = 0; k < 3; k++) {
        final y = lane + (k - 1) * 34.0;
        for (var x = OrbitStage.paintRight - phase; x > OrbitStage.paintLeft; x -= 40) {
          canvas.drawLine(Offset(x, y), Offset(x - 18, y), _lanePaint);
        }
      }
    }
    for (var i = 0; i < gustCount; i++) {
      if (!_gActive[i]) continue;
      final grow = math.min(1.0, _gage[i] * 4);
      canvas
        ..save()
        ..translate(_gx[i], _gy[i])
        ..scale(grow, _gdir[i] * grow);
      _gust.paint(canvas, ctx);
      canvas.restore();
    }
    for (var i = 0; i < noteCount; i++) {
      if (!_nActive[i]) continue;
      canvas
        ..save()
        ..translate(_nx[i], _ny[i])
        ..rotate(math.sin(_nage[i] * 14) * 0.25);
      _note.paint(canvas, ctx);
      canvas.restore();
    }
  }

  @override
  void onRemove() {
    _note.dispose();
    _gust.dispose();
    super.onRemove();
  }

  /// A quaver whose stem is a lightning bolt.
  static void _drawNote(InkBuild b) {
    final pen = b.pen;
    final c = b.colors;
    final flick = b.j((b.time * 24).floor());
    b.layer();
    b.shape(c.hot, ink: 0.9);
    pen
      ..moveTo(8, 10)
      ..lineTo(14, -6)
      ..lineTo(7, -5 + flick)
      ..lineTo(16, -30)
      ..lineTo(6, -30)
      ..lineTo(13, -36)
      ..lineTo(1, -36)
      ..lineTo(0, -8)
      ..lineTo(5, -8)
      ..close();
    b.shape(c.hot, ink: 0.9);
    pen
      ..moveTo(13, -36)
      ..quadTo(30, -30, 26, -14)
      ..quadTo(24, -22, 14, -24)
      ..close();
    b.endLayer();
    b.layer();
    final ct = b.contour(0)..clear();
    ct.ellipse(pen, 0, 12, 13, 10, samples: 20);
    ct.wobble(b.amp * 0.5, b.frame, b.seed, 3);
    b.blob(ct, c.dark, ink: 0.8);
    b.fill(c.shine);
    pen.ellipse(-4, 8, 3, 1.8, -0.5);
    b.endLayer();
    // A crackle around it.
    Mechanics.sparks(b, -16, -18, 5, 40 + (b.time * 12).floor());
  }

  /// A band of curling wind lines racing leftward.
  static void _drawGust(InkBuild b) {
    final pen = b.pen;
    final t = b.time * 9;
    b.layer();
    for (var i = 0; i < 4; i++) {
      final y = -42 + i * 28.0 + b.ja(10 + i, 1.5);
      final x0 = 70 - i * 10.0;
      final len = 110 + 20 * math.sin(t + i);
      b.brushQuad(2, x0, y, x0 - len * 0.5, y - 6 + math.sin(t * 0.7 + i) * 4, x0 - len, y, b.lw * 1.1, taperIn: 0.08, taperOut: 0.5);
      // A curl at the leading end.
      final cx = x0 - len - 6, cy = y - 8;
      final ct = b.contour(1)..clear(closed: false);
      for (var k = 0; k <= 12; k++) {
        final a = k / 12 * math.pi * 1.7 + 0.5;
        final r = 9.0 * (1 - k / 14);
        ct.addPen(pen, cx + math.cos(a) * r, cy + math.sin(a) * r);
      }
      b.brush(ct, b.lw * 0.9, taperIn: 0.1, taperOut: 0.6);
    }
    b.endLayer();
  }
}

/// A pool of dust / smoke / cream puffs anywhere on stage.
class PuffPool extends Component with HasGameReference<CinemaGame> {
  PuffPool({super.priority, int count = 8}) {
    for (var i = 0; i < count; i++) {
      final p = InkPuff(size: 30, life: 0.7, seed: i)..time = 10;
      _puffs.add(p);
      _x.add(0);
      _y.add(0);
      _vx.add(0);
    }
    OrbitAllocations.note();
  }

  final List<InkPuff> _puffs = [];
  final List<double> _x = [];
  final List<double> _y = [];
  final List<double> _vx = [];

  /// Starts a puff at ([x], [y]) in world units; [vx] carries it sideways.
  void spawn(double x, double y, {double size = 30, double life = 0.7, double driftY = -30, double vx = 0}) {
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
      _vx[i] = vx;
      return;
    }
  }

  @override
  void update(double dt) {
    for (var i = 0; i < _puffs.length; i++) {
      final p = _puffs[i];
      if (p.done) continue;
      p.update(dt);
      _x[i] += _vx[i] * dt;
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

/// A burst of little stars (confetti for the loop-the-loop and the Maestro's
/// exit), drawn with one cached star path and plain paints.
class StarBurst extends Component with HasGameReference<CinemaGame> {
  StarBurst({super.priority, int count = 28}) : _n = count {
    _x = List.filled(count, 0);
    _y = List.filled(count, 0);
    _vx = List.filled(count, 0);
    _vy = List.filled(count, 0);
    _age = List.filled(count, 9);
    _life = List.filled(count, 1);
    _size = List.filled(count, 1);
    _spin = List.filled(count, 0);
    const n = 5;
    for (var i = 0; i <= n * 2; i++) {
      final k = i % (n * 2);
      final a = -math.pi / 2 + k * math.pi / n;
      final r = k.isEven ? 1.0 : 0.45;
      if (i == 0) {
        _star.moveTo(math.cos(a) * r, math.sin(a) * r);
      } else {
        _star.lineTo(math.cos(a) * r, math.sin(a) * r);
      }
    }
    _star.close();
    OrbitAllocations.note();
  }

  final int _n;
  late final List<double> _x, _y, _vx, _vy, _age, _life, _size, _spin;
  final Path _star = Path();
  final Paint _fill = Paint();
  final Paint _ink = Paint()
    ..style = PaintingStyle.stroke
    ..strokeJoin = StrokeJoin.round;
  int _next = 0;

  int get alive {
    var n = 0;
    for (var i = 0; i < _n; i++) {
      if (_age[i] < _life[i]) n++;
    }
    return n;
  }

  /// Emits [count] stars from ([x], [y]).
  void burst(double x, double y, {int count = 12, double speed = 260, double size = 9}) {
    for (var k = 0; k < count; k++) {
      final i = _next;
      _next = (_next + 1) % _n;
      final a = (k / count) * math.pi * 2 + boilHash01(k, i, 1) * 0.8;
      final v = speed * (0.5 + boilHash01(k, i, 2));
      _x[i] = x;
      _y[i] = y;
      _vx[i] = math.cos(a) * v;
      _vy[i] = math.sin(a) * v - speed * 0.4;
      _age[i] = 0;
      _life[i] = 0.9 + boilHash01(k, i, 3) * 0.6;
      _size[i] = size * (0.6 + boilHash01(k, i, 4) * 0.8);
      _spin[i] = (boilHash01(k, i, 5) - 0.5) * 8;
    }
  }

  @override
  void update(double dt) {
    for (var i = 0; i < _n; i++) {
      if (_age[i] >= _life[i]) continue;
      _age[i] += dt;
      _vy[i] += 500 * dt;
      _vx[i] *= 1 - dt * 1.2;
      _x[i] += _vx[i] * dt;
      _y[i] += _vy[i] * dt;
    }
  }

  @override
  void render(Canvas canvas) {
    final pal = game.skin.palette;
    final lw = 2.2 / math.max(0.4, game.rigPaint.pixelScale);
    _ink
      ..color = pal.ink
      ..strokeWidth = lw * 1.6;
    for (var i = 0; i < _n; i++) {
      if (_age[i] >= _life[i]) continue;
      final k = _age[i] / _life[i];
      final s = _size[i] * (k < 0.15 ? k / 0.15 : 1 - math.max(0.0, k - 0.7) / 0.3);
      if (s <= 0.2) continue;
      _fill.color = i.isEven ? pal.highlight : pal.accent2;
      canvas
        ..save()
        ..translate(_x[i], _y[i])
        ..rotate(_age[i] * _spin[i])
        ..scale(s);
      _ink.strokeWidth = lw * 1.6 / s;
      canvas
        ..drawPath(_star, _ink)
        ..drawPath(_star, _fill)
        ..restore();
    }
  }
}

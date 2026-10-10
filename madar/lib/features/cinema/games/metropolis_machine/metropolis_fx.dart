import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/painting.dart' show TextPainter, TextSpan, TextStyle, TextDirection, FontWeight;

import '../../engine/cinema_engine.dart';
import '../../engine/rig/rig_kit.dart';
import 'metropolis_rules.dart';

// Procedural feedback drawn in code and pooled up front: dust and steam
// puffs (inked), sparks (short hot strokes), bursting gears (cached inked
// cogs tumbling under gravity) and the cartoon word that pops over the hero
// ("Parry!"). Nothing here allocates while the show runs.

/// A pool of inked dust / steam puffs anywhere on stage.
class MetroPuffs extends Component with HasGameReference<CinemaGame> {
  MetroPuffs({super.priority, int count = 10}) {
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

  int get capacity => _puffs.length;

  /// Starts a puff at ([x], [y]) in world units.
  void spawn(double x, double y, {double size = 30, double life = 0.7, double driftY = -30, double driftX = 0}) {
    for (var i = 0; i < _puffs.length; i++) {
      final p = _puffs[i];
      if (!p.done) continue;
      p
        ..size = size
        ..life = life
        ..drift = Offset(driftX, driftY)
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

/// Hot sparks: short strokes flung from a point, falling and fading.
class MetroSparks extends Component with HasGameReference<CinemaGame> {
  MetroSparks({super.priority, int capacity = 72})
    : _x = Float64List(capacity),
      _y = Float64List(capacity),
      _vx = Float64List(capacity),
      _vy = Float64List(capacity),
      _life = Float64List(capacity),
      _max = Float64List(capacity);

  final Float64List _x, _y, _vx, _vy, _life, _max;
  final Paint _paint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  final math.Random _rng = math.Random(5);
  int _next = 0;

  int get capacity => _x.length;

  int get alive {
    var n = 0;
    for (var i = 0; i < _life.length; i++) {
      if (_life[i] > 0) n++;
    }
    return n;
  }

  /// Flings [count] sparks from ([x], [y]) at about [speed] units/s,
  /// biased by ([dirX], [dirY]).
  void burst(double x, double y, {int count = 12, double speed = 320, double dirX = 0, double dirY = -0.6, double life = 0.55}) {
    for (var k = 0; k < count; k++) {
      final i = _next;
      _next = (_next + 1) % _x.length;
      final a = _rng.nextDouble() * math.pi * 2;
      final s = speed * (0.4 + _rng.nextDouble() * 0.8);
      _x[i] = x;
      _y[i] = y;
      _vx[i] = math.cos(a) * s + dirX * speed;
      _vy[i] = math.sin(a) * s + dirY * speed;
      _max[i] = _life[i] = life * (0.6 + _rng.nextDouble() * 0.7);
    }
  }

  @override
  void update(double dt) {
    for (var i = 0; i < _x.length; i++) {
      if (_life[i] <= 0) continue;
      _life[i] -= dt;
      _vy[i] += 1500 * dt;
      _x[i] += _vx[i] * dt;
      _y[i] += _vy[i] * dt;
      if (_y[i] > MetroStage.groundY) {
        _y[i] = MetroStage.groundY;
        _vy[i] = -_vy[i] * 0.4;
        _vx[i] *= 0.7;
      }
    }
  }

  @override
  void render(Canvas canvas) {
    final pal = game.skin.palette;
    final hot = Color.lerp(pal.highlight, pal.footlight, 0.5)!;
    for (var i = 0; i < _x.length; i++) {
      if (_life[i] <= 0) continue;
      final k = (_life[i] / _max[i]).clamp(0.0, 1.0);
      _paint
        ..color = (k > 0.5 ? hot : pal.ink).withValues(alpha: 0.35 + 0.65 * k)
        ..strokeWidth = 1.2 + 2.2 * k;
      final tx = _vx[i] * 0.02, ty = _vy[i] * 0.02;
      canvas.drawLine(Offset(_x[i] - tx, _y[i] - ty), Offset(_x[i] + tx * 0.5, _y[i] + ty * 0.5), _paint);
    }
  }
}

/// Gears and bolts bursting out of a beaten machine: a few cached inked
/// cogs of three sizes, tumbling under gravity and bouncing off the floor.
class MetroGearBurst extends Component with HasGameReference<CinemaGame> {
  MetroGearBurst({super.priority, int capacity = 14})
    : _x = Float64List(capacity),
      _y = Float64List(capacity),
      _vx = Float64List(capacity),
      _vy = Float64List(capacity),
      _angle = Float64List(capacity),
      _spin = Float64List(capacity),
      _life = Float64List(capacity),
      _kind = Int32List(capacity) {
    for (var i = 0; i < 3; i++) {
      final r = 12.0 + i * 8;
      _cogs.add(
        InkSketch(
          size: r * 2.2,
          extent: Rect.fromCircle(center: Offset.zero, radius: r * 1.2),
          seed: i,
          draw: (b) => Mechanics.gear(b, 0, 0, r, 7 + i * 2, 0, fill: b.colors.fill(i == 1 ? PaletteRole.shadow : PaletteRole.midtone), holes: i == 0 ? 0 : 3, shaded: i == 2),
        )..shaded = i == 2,
      );
    }
  }

  final Float64List _x, _y, _vx, _vy, _angle, _spin, _life;
  final Int32List _kind;
  final List<InkSketch> _cogs = [];
  final math.Random _rng = math.Random(9);
  int _next = 0;

  int get alive {
    var n = 0;
    for (var i = 0; i < _life.length; i++) {
      if (_life[i] > 0) n++;
    }
    return n;
  }

  void burst(double x, double y, {int count = 8, double speed = 420}) {
    for (var k = 0; k < count; k++) {
      final i = _next;
      _next = (_next + 1) % _x.length;
      final a = -math.pi * (0.15 + _rng.nextDouble() * 0.7);
      final s = speed * (0.5 + _rng.nextDouble() * 0.8);
      _x[i] = x + (_rng.nextDouble() - 0.5) * 60;
      _y[i] = y;
      _vx[i] = math.cos(a) * s;
      _vy[i] = math.sin(a) * s;
      _angle[i] = _rng.nextDouble() * math.pi;
      _spin[i] = (_rng.nextDouble() - 0.5) * 14;
      _life[i] = 2.4 + _rng.nextDouble();
      _kind[i] = _rng.nextInt(3);
    }
  }

  @override
  void update(double dt) {
    for (final c in _cogs) {
      c.update(dt);
    }
    for (var i = 0; i < _x.length; i++) {
      if (_life[i] <= 0) continue;
      _life[i] -= dt;
      _vy[i] += 1700 * dt;
      _x[i] += _vx[i] * dt;
      _y[i] += _vy[i] * dt;
      _angle[i] += _spin[i] * dt;
      final r = 12.0 + _kind[i] * 8;
      if (_y[i] > MetroStage.groundY - r) {
        _y[i] = MetroStage.groundY - r;
        _vy[i] = -_vy[i] * 0.45;
        _vx[i] *= 0.6;
        _spin[i] *= 0.5;
        if (_vy[i].abs() < 40) _vy[i] = 0;
      }
    }
  }

  @override
  void render(Canvas canvas) {
    final ctx = game.rigPaint;
    for (var i = 0; i < _x.length; i++) {
      if (_life[i] <= 0) continue;
      canvas
        ..save()
        ..translate(_x[i], _y[i])
        ..rotate(_angle[i]);
      _cogs[_kind[i]].paint(canvas, ctx);
      canvas.restore();
    }
  }

  @override
  void onRemove() {
    for (final c in _cogs) {
      c.dispose();
    }
    super.onRemove();
  }
}

/// A cartoon word that pops up over a point and drifts away ("Parry!",
/// "Reel recovered!"). One text painter, re-laid out only when the text
/// changes.
class MetroFlashText extends Component with HasGameReference<CinemaGame> {
  MetroFlashText({super.priority});

  final TextPainter _tp = TextPainter(textDirection: TextDirection.rtl, textAlign: TextAlign.center);
  final Paint _fill = Paint();
  final Paint _stroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeJoin = StrokeJoin.round;
  final Path _path = Path();
  String _text = '';
  String _laidOut = '';
  double _age = 10;
  double _x = 0, _y = 0;
  static const double life = 1.3;

  bool get showing => _age < life;

  void show(String text, double x, double y) {
    _text = text;
    _x = x;
    _y = y;
    _age = 0;
  }

  @override
  void update(double dt) {
    if (_age < life) _age += dt;
  }

  @override
  void render(Canvas canvas) {
    if (!showing || _text.isEmpty) return;
    final skin = game.skin;
    final pal = skin.palette;
    if (_laidOut != _text) {
      _laidOut = _text;
      _tp
        ..textDirection = game.env.direction
        ..text = TextSpan(
          text: _text,
          style: TextStyle(fontFamily: skin.titles.fontFamily, fontWeight: FontWeight.w700, fontSize: 30, color: pal.ink, height: 1.1),
        )
        ..layout(maxWidth: 300);
    }
    final k = _age / life;
    final pop = k < 0.18 ? Bounce.backOut(k / 0.18, 2.4) : 1.0;
    final fade = k > 0.7 ? 1 - (k - 0.7) / 0.3 : 1.0;
    final y = _y - 30 * k;
    final w = _tp.width + 28, h = _tp.height + 14;
    canvas
      ..save()
      ..translate(_x, y)
      ..scale(pop, pop)
      ..rotate(-0.08);
    // A jagged burst behind the word.
    _path.reset();
    const n = 14;
    for (var i = 0; i <= n * 2; i++) {
      final kk = i % (n * 2);
      final a = kk * math.pi / n;
      final rx = (kk.isEven ? w * 0.62 : w * 0.5), ry = (kk.isEven ? h * 0.95 : h * 0.65);
      final px = math.cos(a) * rx, py = math.sin(a) * ry;
      if (i == 0) {
        _path.moveTo(px, py);
      } else {
        _path.lineTo(px, py);
      }
    }
    _path.close();
    _fill.color = pal.paper.withValues(alpha: fade);
    _stroke
      ..color = pal.ink.withValues(alpha: fade)
      ..strokeWidth = 2.5;
    canvas
      ..drawPath(_path, _fill)
      ..drawPath(_path, _stroke);
    _tp.paint(canvas, Offset(-_tp.width / 2, -_tp.height / 2));
    canvas.restore();
  }

  @override
  void onRemove() {
    _tp.dispose();
    super.onRemove();
  }
}

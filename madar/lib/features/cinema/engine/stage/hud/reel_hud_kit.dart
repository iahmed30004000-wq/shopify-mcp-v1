import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/painting.dart' show TextPainter, TextSpan, TextDirection;

import '../../core/cinema_env.dart';
import '../../core/era_skin.dart';
import '../../core/stage.dart';
import '../stage_materials.dart';
import 'hud_paint.dart';

/// The era's HUD kit (createHudKit): a rolling score plaque, lives as film
/// reels, a boss bar that is a burning film strip, a stopwatch timer, a
/// film-strip progress bar, the pause button and free labels – all drawn in
/// code in the era's frame style (see [HudPlaque]) and painted inside the
/// film frame, so they get grain and flicker like everything else.
///
/// Items animate themselves from [HudModel] changes (count-up and roll,
/// reel unspooling on a lost life, film burning back on boss damage). No
/// allocation per frame: paths, paints and text painters are reused, text is
/// re-laid out only when it changes.
class ReelHudKit implements HudKit {
  ReelHudKit(this.env);

  final CinemaEnv env;

  @override
  HudItem score() => ScoreHudItem(env);

  @override
  HudItem lives() => ReelLivesHudItem(env);

  @override
  HudItem bossBar() => BurningFilmBossBar(env);

  @override
  HudItem timer() => StopwatchHudItem(env);

  @override
  HudItem progress() => FilmProgressHudItem(env);

  @override
  HudItem pauseButton(VoidCallback onPressed) => PauseHudItem(env, onPressed);

  @override
  HudItem label(String Function() text) => LabelHudItem(env, text);
}

double _hash(double x) {
  final s = math.sin(x * 12.9898 + 78.233) * 43758.5453;
  return s - s.floorToDouble();
}

// ---------------------------------------------------------------------------
// Score
// ---------------------------------------------------------------------------

/// Score plaque: an odometer that counts up in quick steps (each step rolls
/// the changed digits), pops on gains, and hangs a "best" tab with a crown
/// under it once a best score is known (the crown lights when it is beaten).
class ScoreHudItem extends HudItem {
  ScoreHudItem(this.env);

  final CinemaEnv env;
  final RollingDigits _digits = RollingDigits();
  final RollingDigits _bestDigits = RollingDigits();
  final HudPlaque _plaque = HudPlaque();
  final HudPlaque _tab = HudPlaque();
  final Paint _p = Paint();
  final Paint _s = Paint()
    ..style = PaintingStyle.stroke
    ..strokeJoin = StrokeJoin.round;
  final Path _icon = Path();

  int _shown = 0;
  int _from = 0;
  bool _init = false;
  double _roll = 1;
  double _step = 0;
  double _pop = 0;
  int _cols = 0;
  double _scale = 0;
  bool _hasBest = false;
  Size _size = Size.zero;

  void _configure(HudContext ctx) {
    if (ctx.scale == _scale) return;
    _scale = ctx.scale;
    final color = HudPlaque.textColor(ctx);
    _digits.configure(hudTextStyle(ctx.skin, 24 * ctx.scale, color, glow: HudPlaque.glows(ctx)), env.languageCode);
    _bestDigits.configure(hudTextStyle(ctx.skin, 12.5 * ctx.scale, color), env.languageCode);
    _cols = 0;
  }

  @override
  Size layoutSize(HudContext ctx) {
    _configure(ctx);
    final target = ctx.model.score;
    if (!_init) {
      _init = true;
      _shown = _from = target;
    }
    final cols = math.max(2, RollingDigits.digitCount(math.max(_shown, target)));
    final hasBest = (ctx.model.best ?? 0) > 0;
    if (cols != _cols || hasBest != _hasBest) {
      _cols = cols;
      _hasBest = hasBest;
      final s = ctx.scale;
      _size = Size(20 * s + 22 * s + _digits.widthFor(cols), 42 * s + (hasBest ? 16 * s : 0));
    }
    return _size;
  }

  @override
  void update(double dt, HudContext ctx) {
    final target = ctx.model.score;
    if (!_init) return;
    if (_shown != target) {
      _step -= dt;
      if (_step <= 0) {
        final diff = target - _shown;
        final int inc = (diff < 0 ? -1 : 1) * math.max<int>(1, (diff.abs() / 6).ceil());
        _from = _shown;
        _shown += inc;
        _roll = 0;
        _step = 0.055;
        if (inc > 0) _pop = 1;
      }
    }
    _roll = math.min(1, _roll + dt / 0.11);
    _pop = math.max(0, _pop - dt * 3.2);
  }

  @override
  void paint(Canvas canvas, Rect rect, HudContext ctx) {
    if (rect.isEmpty) return;
    final s = ctx.scale;
    final m = StageMaterials.of(ctx.skin);
    final rtl = ctx.direction == TextDirection.rtl;
    final main = Rect.fromLTWH(rect.left, rect.top, rect.width, 42 * s);
    final k = 1 + 0.14 * math.sin(_pop * math.pi);
    canvas
      ..save()
      ..translate(main.center.dx, main.center.dy)
      ..scale(k)
      ..translate(-main.center.dx, -main.center.dy);
    if (_hasBest) {
      final best = ctx.model.best!;
      final beaten = ctx.model.score > best;
      final shown = beaten ? ctx.model.score : best;
      final tabW = 22 * s + _bestDigits.widthFor(RollingDigits.digitCount(shown));
      final tab = Rect.fromLTWH(rtl ? main.right - tabW - 10 * s : main.left + 10 * s, main.bottom - 3 * s, tabW, 19 * s);
      _tab.paint(canvas, tab, ctx, flash: beaten ? 0.3 + 0.3 * math.sin(ctx.clock.time * 6) : 0);
      _crown(
        canvas,
        Offset(rtl ? tab.right - 10 * s : tab.left + 10 * s, tab.center.dy + 1 * s),
        5.5 * s,
        beaten ? m.gilt : m.giltDark,
        m.ink,
      );
      final digitsRight = rtl ? tab.right - 18 * s : tab.right - 5 * s;
      _bestDigits.paint(canvas, digitsRight, tab.center.dy + 1 * s, shown, shown, 1, RollingDigits.digitCount(shown));
    }
    _plaque.paint(canvas, main, ctx, flash: _pop * 0.35);
    // A star ticket stub at the start side.
    final ic = Offset(rtl ? main.right - 17 * s : main.left + 17 * s, main.center.dy);
    _star(canvas, ic, 8.5 * s, ctx);
    final right = rtl ? main.right - 30 * s : main.right - 10 * s;
    _digits.paint(canvas, right, main.center.dy + 1 * s, _from, _shown, _roll, _cols);
    canvas.restore();
  }

  void _star(Canvas canvas, Offset c, double r, HudContext ctx) {
    final m = StageMaterials.of(ctx.skin);
    _icon.reset();
    for (var i = 0; i < 10; i++) {
      final rr = i.isEven ? r : r * 0.45;
      final a = -math.pi / 2 + math.pi * i / 5 + math.sin(ctx.clock.boilFrame * 1.7) * 0.04;
      final x = c.dx + math.cos(a) * rr, y = c.dy + math.sin(a) * rr;
      i == 0 ? _icon.moveTo(x, y) : _icon.lineTo(x, y);
    }
    _icon.close();
    if (ctx.skin.titles.frame == TitleFrame.osd) {
      _s
        ..color = m.neonA
        ..strokeWidth = 1.6 * ctx.scale;
      canvas.drawPath(_icon, _s);
      return;
    }
    _p.color = ctx.skin.era.isMonochrome ? m.ink : ctx.skin.palette.accent;
    canvas.drawPath(_icon, _p);
    _s
      ..color = m.ink
      ..strokeWidth = 1.4 * ctx.scale;
    canvas.drawPath(_icon, _s);
  }

  void _crown(Canvas canvas, Offset c, double r, Color fill, Color ink) {
    _icon
      ..reset()
      ..moveTo(c.dx - r, c.dy + r * 0.6)
      ..lineTo(c.dx - r, c.dy - r * 0.5)
      ..lineTo(c.dx - r * 0.45, c.dy)
      ..lineTo(c.dx, c.dy - r * 0.8)
      ..lineTo(c.dx + r * 0.45, c.dy)
      ..lineTo(c.dx + r, c.dy - r * 0.5)
      ..lineTo(c.dx + r, c.dy + r * 0.6)
      ..close();
    _p.color = fill;
    canvas.drawPath(_icon, _p);
    _s
      ..color = ink
      ..strokeWidth = 1.1 * _scale;
    canvas.drawPath(_icon, _s);
  }

  @override
  void dispose() {
    _digits.dispose();
    _bestDigits.dispose();
  }
}

// ---------------------------------------------------------------------------
// Lives: film reels
// ---------------------------------------------------------------------------

/// Paints one film reel (face on): flange with five windows, the wound film
/// seen through them ([film] 0..1), hub; [angle] spins it.
class ReelGlyph {
  final Paint _p = Paint();
  final Paint _s = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  final Path _path = Path();

  void paint(Canvas canvas, Offset c, double r, double angle, double film, HudContext ctx, {double alpha = 1, double scale = 1}) {
    final m = StageMaterials.of(ctx.skin);
    final pal = ctx.skin.palette;
    final neon = ctx.skin.titles.frame == TitleFrame.osd;
    final flange = switch (ctx.skin.titles.frame) {
      TitleFrame.plain => const Color(0xFF9A9AA2),
      TitleFrame.marquee => m.gilt,
      TitleFrame.osd => m.wall,
      _ => ctx.skin.era.isMonochrome ? m.paper : Color.lerp(m.paper, m.gilt, 0.3)!,
    };
    final filmColor = neon ? m.neonA : pal.ink;
    Color a(Color x) => x.withValues(alpha: x.a * alpha);
    // Drop shadow.
    if (!neon) {
      _p.color = a(pal.ink.withValues(alpha: 0.7));
      canvas.drawCircle(c + Offset(0, 2.4 * ctx.scale), r, _p);
    }
    _p.color = a(flange);
    canvas.drawCircle(c, r, _p);
    // Windows: film (dark) behind them when wound, empty (pale) when not.
    final win = Color.lerp(Color.lerp(flange, pal.shadow, 0.55)!, filmColor, film)!;
    _p.color = a(win);
    for (var i = 0; i < 5; i++) {
      final t = angle + math.pi * 2 * i / 5;
      canvas.drawCircle(c + Offset(math.cos(t), math.sin(t)) * r * 0.54, r * 0.24, _p);
    }
    // Hub.
    _p.color = a(neon ? m.neonB : pal.ink);
    canvas.drawCircle(c, r * 0.2, _p);
    _p.color = a(flange);
    canvas.drawCircle(c, r * 0.08, _p);
    _s
      ..color = a(neon ? m.neonB : pal.ink)
      ..strokeWidth = (neon ? 1.8 : 2.2) * ctx.scale * scale;
    canvas.drawCircle(c, r, _s);
    if (neon) {
      _s
        ..color = a(m.neonB.withValues(alpha: 0.3))
        ..strokeWidth = 5 * ctx.scale;
      canvas.drawCircle(c, r, _s);
    } else {
      // Lit rim.
      _s
        ..color = a(pal.highlight.withValues(alpha: 0.8))
        ..strokeWidth = 1.2 * ctx.scale;
      _path
        ..reset()
        ..addArc(Rect.fromCircle(center: c, radius: r - 2.4 * ctx.scale), math.pi * 1.1, math.pi * 0.55);
      canvas.drawPath(_path, _s);
    }
  }

  /// A loose ribbon of film leaving the reel (sprocket dots along it).
  void ribbon(Canvas canvas, Offset from, Offset to, double wave, double width, HudContext ctx, {double alpha = 1}) {
    final pal = ctx.skin.palette;
    final neon = ctx.skin.titles.frame == TitleFrame.osd;
    final d = to - from;
    final n = Offset(-d.dy, d.dx) / math.max(1, d.distance);
    _path
      ..reset()
      ..moveTo(from.dx, from.dy)
      ..cubicTo(
        from.dx + d.dx * 0.33 + n.dx * wave,
        from.dy + d.dy * 0.33 + n.dy * wave,
        from.dx + d.dx * 0.66 - n.dx * wave,
        from.dy + d.dy * 0.66 - n.dy * wave,
        to.dx,
        to.dy,
      );
    _s
      ..color = (neon ? StageMaterials.of(ctx.skin).neonA : pal.ink).withValues(alpha: alpha)
      ..strokeWidth = width;
    canvas.drawPath(_path, _s);
    _s
      ..color = pal.paper.withValues(alpha: 0.85 * alpha)
      ..strokeWidth = width * 0.22;
    for (final metric in _path.computeMetrics()) {
      // Sprocket dots (path metrics allocate: only during the short
      // lose-a-life animation).
      for (var t = width; t < metric.length - 2; t += width * 1.1) {
        final tan = metric.getTangentForOffset(t);
        if (tan == null) continue;
        canvas.drawCircle(tan.position, width * 0.12, _p..color = pal.paper.withValues(alpha: 0.85 * alpha));
      }
    }
  }
}

/// Lives as film reels in a row (start side first): wound reels turn on
/// twos; the reel of a lost life spins, swells and unspools a ribbon of film
/// before it sits there empty and faded.
class ReelLivesHudItem extends HudItem {
  ReelLivesHudItem(this.env);

  final CinemaEnv env;
  final ReelGlyph _reel = ReelGlyph();
  Size _size = Size.zero;
  int _max = -1;
  double _scale = 0;
  int _lastLives = -1;
  final List<double> _lost = List.filled(12, 1);
  final List<double> _gain = List.filled(12, 1);

  @override
  Size layoutSize(HudContext ctx) {
    final n = ctx.model.maxLives.clamp(0, 12);
    if (n != _max || ctx.scale != _scale) {
      _max = n;
      _scale = ctx.scale;
      _size = n == 0 ? Size.zero : Size(n * 31 * ctx.scale, 38 * ctx.scale);
    }
    return _size;
  }

  @override
  void update(double dt, HudContext ctx) {
    final lives = ctx.model.lives.clamp(0, 12);
    if (_lastLives >= 0 && lives != _lastLives) {
      if (lives < _lastLives) {
        for (var i = lives; i < _lastLives; i++) {
          _lost[i] = 0;
        }
      } else {
        for (var i = _lastLives; i < lives; i++) {
          _gain[i] = 0;
          _lost[i] = 1;
        }
      }
    }
    _lastLives = lives;
    for (var i = 0; i < 12; i++) {
      if (_lost[i] < 1) _lost[i] = math.min(1, _lost[i] + dt / 0.95);
      if (_gain[i] < 1) _gain[i] = math.min(1, _gain[i] + dt / 0.5);
    }
  }

  @override
  void paint(Canvas canvas, Rect rect, HudContext ctx) {
    if (rect.isEmpty || _max <= 0) return;
    final s = ctx.scale;
    final rtl = ctx.direction == TextDirection.rtl;
    final cell = rect.width / _max;
    final lives = ctx.model.lives;
    final boil = ctx.clock.boilFrame;
    for (var i = 0; i < _max; i++) {
      final cx = rtl ? rect.right - cell * (i + 0.5) : rect.left + cell * (i + 0.5);
      final c = Offset(cx, rect.center.dy - 1 * s);
      final r = 13.5 * s;
      final alive = i < lives;
      final lost = _lost[i];
      if (alive) {
        final g = _gain[i];
        final k = g < 1 ? 0.4 + 0.6 * _easeOutBack(g) : 1.0;
        // The reel in use (the last one) turns faster.
        final speed = i == lives - 1 ? 0.52 : 0.2;
        _reel.paint(canvas, c, r * k, boil * speed + i, 1, ctx);
      } else if (lost < 1) {
        // Unspooling: spin, swell, a ribbon of film flying loose.
        final e = lost;
        final swell = 1 + 0.35 * math.sin(e * math.pi);
        final dir = rtl ? -1.0 : 1.0;
        _reel.ribbon(
          canvas,
          c,
          c + Offset(dir * (8 + 34 * e) * s, (10 + 26 * e) * s),
          10 * s * math.sin(e * 9),
          5.5 * s,
          ctx,
          alpha: 1 - e,
        );
        _reel.paint(canvas, c, r * swell, e * 14, 1 - e, ctx, alpha: 1 - 0.65 * e);
      } else {
        _reel.paint(canvas, c, r * 0.92, i * 0.7, 0, ctx, alpha: 0.35);
      }
    }
  }

  static double _easeOutBack(double t) {
    const c1 = 1.70158, c3 = c1 + 1;
    final x = t - 1;
    return 1 + c3 * x * x * x + c1 * x * x;
  }
}

// ---------------------------------------------------------------------------
// Boss bar: a burning film strip
// ---------------------------------------------------------------------------

/// The boss's health as a strip of film under the boss's name plate. Damage
/// burns it back from the end: a charred, jagged edge with a glowing ember
/// line, a ghost of the lost frames that keeps burning for a moment, sparks
/// and curls of smoke. At zero the strip is gone.
class BurningFilmBossBar extends HudItem {
  BurningFilmBossBar(this.env);

  final CinemaEnv env;
  final HudPlaque _plate = HudPlaque();
  final TextPainter _name = TextPainter(textDirection: TextDirection.rtl, maxLines: 1, ellipsis: '…');
  final Paint _p = Paint();
  final Paint _add = Paint()..blendMode = BlendMode.plus;
  final Paint _s = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  final Path _edge = Path();
  String? _laidOut;
  double _scale = 0;
  Size _size = Size.zero;
  double _hp = -1;
  double _ghost = -1;
  double _hit = 0;
  double _ghostHold = 0;

  static const int _frames = 12;

  @override
  Size layoutSize(HudContext ctx) {
    final hp = ctx.model.bossHealth;
    if (hp == null) {
      _hp = -1;
      return Size.zero;
    }
    final name = ctx.model.bossName ?? '';
    if (name != _laidOut || ctx.scale != _scale) {
      _laidOut = name;
      _scale = ctx.scale;
      _name
        ..textDirection = ctx.direction
        ..text = TextSpan(
          text: name,
          style: hudTextStyle(ctx.skin, 13.5 * ctx.scale, HudPlaque.textColor(ctx), glow: HudPlaque.glows(ctx)),
        )
        ..layout(maxWidth: 200 * ctx.scale);
      _size = Size(250 * ctx.scale, (name.isEmpty ? 30 : 52) * ctx.scale);
    }
    return _size;
  }

  @override
  void update(double dt, HudContext ctx) {
    final hp = ctx.model.bossHealth;
    if (hp == null) return;
    final target = hp.clamp(0.0, 1.0);
    if (_hp < 0) {
      _hp = _ghost = target;
    }
    if (target < _hp - 1e-4) {
      _hit = 1;
      _ghostHold = 0.45;
    }
    // The strip snaps to the new length; the ghost of the burnt frames
    // lingers, then burns away.
    _hp = target;
    if (_ghost < _hp) _ghost = _hp;
    if (_ghostHold > 0) {
      _ghostHold -= dt;
    } else {
      _ghost = math.max(_hp, _ghost - dt * 0.9);
    }
    _hit = math.max(0, _hit - dt * 4);
  }

  @override
  void paint(Canvas canvas, Rect rect, HudContext ctx) {
    if (rect.isEmpty || _hp < 0) return;
    final s = ctx.scale;
    final m = StageMaterials.of(ctx.skin);
    final pal = ctx.skin.palette;
    final rtl = ctx.direction == TextDirection.rtl;
    final neon = ctx.skin.titles.frame == TitleFrame.osd;
    final t = ctx.clock.time;
    final boil = ctx.clock.boilFrame;
    final shake = _hit > 0 ? math.sin(t * 90) * 2.5 * s * _hit : 0.0;
    final strip = Rect.fromLTWH(rect.left + shake, rect.bottom - 28 * s, rect.width, 26 * s);
    // Name plate at the start side.
    if ((_laidOut ?? '').isNotEmpty) {
      final pw = _name.width + 22 * s;
      final plate = Rect.fromLTWH(rtl ? rect.right - pw : rect.left, rect.top, pw, 23 * s);
      _plate.paint(canvas, plate, ctx);
      _name.paint(canvas, Offset(plate.center.dx - _name.width / 2, plate.center.dy - _name.height / 2 + 0.5 * s));
    }
    // Remaining film runs from the start edge to the flame front (the
    // ghost edge); the frames between the health line and the front are
    // scorched and still burning.
    final len = strip.width * _hp;
    final frontLen = strip.width * _ghost;
    double xAt(double d) => rtl ? strip.right - d : strip.left + d;
    final burnX = xAt(len);
    final frontX = xAt(frontLen);
    final keep = rtl
        ? Rect.fromLTRB(frontX, strip.top, strip.right, strip.bottom)
        : Rect.fromLTRB(strip.left, strip.top, frontX, strip.bottom);
    // The empty gate the film ran through.
    final gate = RRect.fromRectAndRadius(strip.inflate(1.5 * s), Radius.circular(4 * s));
    _p.color = pal.ink.withValues(alpha: neon ? 0.45 : 0.16);
    canvas.drawRRect(gate, _p);
    _s
      ..color = (neon ? m.neonB : pal.ink).withValues(alpha: 0.35)
      ..strokeWidth = 1 * s;
    canvas.drawRRect(gate, _s);
    if (frontLen > 0.5) {
      canvas
        ..save()
        ..clipRect(keep.inflate(0.5));
      // Film base.
      _p.color = neon ? m.wall : pal.ink;
      canvas.drawRRect(RRect.fromRectAndRadius(strip, Radius.circular(3 * s)), _p);
      // Frames: exposed panes in the villain colour with frame lines.
      final fw = strip.width / _frames;
      final inner = Rect.fromLTRB(strip.left, strip.top + 6.5 * s, strip.right, strip.bottom - 6.5 * s);
      for (var i = 0; i < _frames; i++) {
        final r = Rect.fromLTWH(strip.left + fw * i + 1.4 * s, inner.top, fw - 2.8 * s, inner.height);
        final tone = 0.78 + 0.22 * _hash(i * 3.3 + (boil % 3));
        _p.color = neon
            ? m.neonA.withValues(alpha: 0.75 * tone)
            : Color.lerp(pal.accent2, pal.highlight, ctx.skin.era.isMonochrome ? 0.35 : 0.12)!.withValues(alpha: tone);
        canvas.drawRect(r, _p);
        // A tiny silhouette of the boss in every frame.
        _p.color = (neon ? m.neonB : pal.ink).withValues(alpha: 0.55);
        final bc = Offset(r.center.dx + (_hash(i + 1.0) - 0.5) * 3 * s, r.center.dy + 1 * s);
        canvas.drawOval(Rect.fromCenter(center: bc, width: r.width * 0.42, height: r.height * 0.62), _p);
      }
      // Sprocket holes.
      _p.color = neon ? m.neonB.withValues(alpha: 0.8) : pal.paper.withValues(alpha: 0.9);
      for (var x = strip.left + 3 * s; x < strip.right - 3 * s; x += 7 * s) {
        canvas
          ..drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, strip.top + 2 * s, 3.4 * s, 2.8 * s), Radius.circular(0.8 * s)), _p)
          ..drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, strip.bottom - 4.8 * s, 3.4 * s, 2.8 * s), Radius.circular(0.8 * s)), _p);
      }
      // Scorched frames between the health line and the flame front.
      if (frontLen > len + 0.5) {
        final scorch = Rect.fromLTRB(math.min(burnX, frontX), strip.top, math.max(burnX, frontX), strip.bottom);
        _p.color = const Color(0xFF4A220C).withValues(alpha: 0.72);
        canvas.drawRect(scorch, _p);
        final ember = neon ? m.neonA : m.glow;
        for (var k = 0; k < 9; k++) {
          final hx = _hash(k * 2.1 + (boil % 4) * 0.7);
          final hy = _hash(k * 5.3 + 1.1);
          final a = 0.4 + 0.6 * _hash(k + (t * 18).floorToDouble());
          _add.color = ember.withValues(alpha: a);
          canvas.drawCircle(Offset(scorch.left + scorch.width * hx, scorch.top + scorch.height * hy), (1.2 + hy) * s, _add);
        }
      }
      // Hit flash.
      if (_hit > 0) {
        _p.color = pal.highlight.withValues(alpha: 0.7 * _hit);
        canvas.drawRect(strip, _p);
      }
      canvas.restore();
      // Outline of the remaining film.
      _s
        ..color = neon ? m.neonB : pal.ink
        ..strokeWidth = 2 * s;
      canvas.drawRRect(RRect.fromRectAndRadius(keep, Radius.circular(3 * s)), _s);
    }
    if (_ghost < 1 && _ghost > 0) _burnEdge(canvas, strip, frontX, rtl ? -1 : 1, ctx);
  }

  /// The charred, glowing edge where the film is burning back.
  void _burnEdge(Canvas canvas, Rect strip, double x, double dir, HudContext ctx) {
    final s = ctx.scale;
    final m = StageMaterials.of(ctx.skin);
    final pal = ctx.skin.palette;
    final boil = ctx.clock.boilFrame;
    final t = ctx.clock.time;
    // Jagged scorch line (re-inked on the boil).
    _edge.reset();
    const n = 7;
    for (var i = 0; i <= n; i++) {
      final y = strip.top - 1 * s + (strip.height + 2 * s) * i / n;
      final j = (_hash(i * 1.7 + boil * 0.31) - 0.5) * 5 * s;
      final px = x - dir * (2 * s + j.abs());
      i == 0 ? _edge.moveTo(px, y) : _edge.lineTo(px, y);
    }
    _s
      ..color = Color.lerp(pal.ink, const Color(0xFF3A1E0C), 0.6)!
      ..strokeWidth = 6 * s;
    canvas.drawPath(_edge, _s);
    final ember = ctx.skin.titles.frame == TitleFrame.osd ? m.neonA : m.glow;
    _s
      ..color = ember.withValues(alpha: 0.8 + 0.2 * math.sin(t * 23))
      ..strokeWidth = 2.4 * s;
    canvas.drawPath(_edge, _s);
    _add.color = ember.withValues(alpha: 0.35);
    canvas.drawCircle(Offset(x, strip.center.dy), 12 * s, _add);
    // Sparks.
    _p.color = pal.highlight;
    for (var k = 0; k < 4; k++) {
      final ph = (t * 1.6 + k / 4) % 1;
      final sx = x + dir * (4 + 10 * ph) * s + math.sin(k * 5 + t * 7) * 3 * s;
      final sy = strip.center.dy - ph * 16 * s + (k - 1.5) * 4 * s;
      canvas.drawCircle(Offset(sx, sy), (1.4 - ph) * s, _p);
    }
    // Curls of smoke rising.
    for (var k = 0; k < 3; k++) {
      final ph = (t * 0.7 + k / 3) % 1;
      _p.color = pal.shadow.withValues(alpha: 0.4 * (1 - ph));
      canvas.drawCircle(Offset(x + math.sin(ph * 6 + k) * 5 * s, strip.top - ph * 22 * s), (3 + ph * 7) * s, _p);
    }
  }

  @override
  void dispose() => _name.dispose();
}

// ---------------------------------------------------------------------------
// Timer, progress, pause, label
// ---------------------------------------------------------------------------

/// Countdown on a plaque with a stopwatch whose hand sweeps each second;
/// under ten seconds the plaque blinks in the accent colour and ticks.
class StopwatchHudItem extends HudItem {
  StopwatchHudItem(this.env);

  final CinemaEnv env;
  final HudPlaque _plaque = HudPlaque();
  final TextPainter _text = TextPainter(textDirection: TextDirection.ltr);
  final Paint _p = Paint();
  final Paint _s = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  int _shownSeconds = -1;
  bool _urgent = false;
  double _scale = 0;
  Size _size = Size.zero;

  @override
  Size layoutSize(HudContext ctx) {
    final left = ctx.model.timeLeft;
    if (left == null) {
      _shownSeconds = -1;
      return Size.zero;
    }
    final secs = (left.inMilliseconds / 1000).ceil();
    final urgent = secs <= 10;
    if (secs != _shownSeconds || ctx.scale != _scale || urgent != _urgent) {
      _shownSeconds = secs;
      _urgent = urgent;
      _scale = ctx.scale;
      final txt = '${secs ~/ 60}:${(secs % 60).toString().padLeft(2, '0')}';
      final color = urgent && ctx.skin.titles.frame != TitleFrame.plain ? ctx.skin.palette.accent : HudPlaque.textColor(ctx);
      _text
        ..text = TextSpan(
          text: hudDigits(txt, env.languageCode),
          style: hudTextStyle(ctx.skin, 20 * ctx.scale, color, glow: HudPlaque.glows(ctx)),
        )
        ..layout();
      _size = Size(_text.width + 44 * ctx.scale, 40 * ctx.scale);
    }
    return _size;
  }

  @override
  void paint(Canvas canvas, Rect rect, HudContext ctx) {
    final left = ctx.model.timeLeft;
    if (left == null || rect.isEmpty) return;
    final s = ctx.scale;
    final pal = ctx.skin.palette;
    final m = StageMaterials.of(ctx.skin);
    final frac = (left.inMilliseconds % 1000) / 1000;
    final blink = _urgent ? (frac > 0.5 ? 1.0 : 0.0) : 0.0;
    final rtl = ctx.direction == TextDirection.rtl;
    canvas.save();
    if (_urgent) {
      final k = 1 + 0.06 * blink;
      canvas
        ..translate(rect.center.dx, rect.center.dy)
        ..scale(k)
        ..translate(-rect.center.dx, -rect.center.dy);
    }
    _plaque.paint(canvas, rect, ctx, flash: blink * 0.5);
    final c = Offset(rtl ? rect.right - 19 * s : rect.left + 19 * s, rect.center.dy + 1 * s);
    final r = 10 * s;
    final ink = ctx.skin.titles.frame == TitleFrame.osd ? m.neonB : pal.ink;
    // Stopwatch: crown, face, ticks, sweeping hand.
    _p.color = ink;
    canvas.drawRect(Rect.fromCenter(center: c - Offset(0, r + 2.5 * s), width: 4 * s, height: 3.4 * s), _p);
    _p.color = ctx.skin.titles.frame == TitleFrame.osd ? m.wall : pal.paper;
    canvas.drawCircle(c, r, _p);
    _s
      ..color = ink
      ..strokeWidth = 2 * s;
    canvas.drawCircle(c, r, _s);
    _s.strokeWidth = 1 * s;
    for (var i = 0; i < 8; i++) {
      final a = math.pi * 2 * i / 8;
      final d = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(c + d * r * 0.72, c + d * r * 0.9, _s);
    }
    final a = -math.pi / 2 + (1 - frac) * math.pi * 2;
    _s
      ..color = _urgent ? pal.accent : ink
      ..strokeWidth = 1.8 * s;
    canvas.drawLine(c, c + Offset(math.cos(a), math.sin(a)) * r * 0.78, _s);
    final tx = rtl ? rect.right - 34 * s - _text.width : rect.left + 34 * s;
    _text.paint(canvas, Offset(tx, rect.center.dy - _text.height / 2 + 1 * s));
    canvas.restore();
  }

  @override
  void dispose() => _text.dispose();
}

/// Level progress as a film strip running from the start side: the
/// exposed frames light up and a small reel rides the head.
class FilmProgressHudItem extends HudItem {
  FilmProgressHudItem(this.env);

  final CinemaEnv env;
  final ReelGlyph _reel = ReelGlyph();
  final Paint _p = Paint();
  final Paint _s = Paint()..style = PaintingStyle.stroke;
  double _shown = -1;
  double _scale = 0;
  Size _size = Size.zero;

  @override
  Size layoutSize(HudContext ctx) {
    if (ctx.model.progress == null) return Size.zero;
    if (ctx.scale != _scale) {
      _scale = ctx.scale;
      _size = Size(180 * ctx.scale, 24 * ctx.scale);
    }
    return _size;
  }

  @override
  void update(double dt, HudContext ctx) {
    final p = ctx.model.progress;
    if (p == null) return;
    final target = p.clamp(0.0, 1.0);
    _shown = _shown < 0 ? target : _shown + (target - _shown) * (1 - math.exp(-dt * 8));
  }

  @override
  void paint(Canvas canvas, Rect rect, HudContext ctx) {
    if (ctx.model.progress == null || rect.isEmpty || _shown < 0) return;
    final s = ctx.scale;
    final pal = ctx.skin.palette;
    final m = StageMaterials.of(ctx.skin);
    final neon = ctx.skin.titles.frame == TitleFrame.osd;
    final rtl = ctx.direction == TextDirection.rtl;
    final strip = Rect.fromLTWH(rect.left + 10 * s, rect.center.dy - 6 * s, rect.width - 20 * s, 12 * s);
    _p.color = neon ? m.wall : pal.ink;
    canvas.drawRRect(RRect.fromRectAndRadius(strip.inflate(1.5 * s), Radius.circular(3 * s)), _p);
    // Frames: exposed (lit) up to the head.
    final n = 14;
    final fw = strip.width / n;
    final head = strip.width * _shown;
    for (var i = 0; i < n; i++) {
      final d0 = fw * i;
      final lit = d0 + fw * 0.5 < head;
      final x = rtl ? strip.right - d0 - fw : strip.left + d0;
      _p.color = lit ? (neon ? m.neonB : (ctx.skin.era.isMonochrome ? pal.paper : m.gilt)) : pal.shadow.withValues(alpha: 0.6);
      canvas.drawRect(Rect.fromLTWH(x + 1.2 * s, strip.top + 3 * s, fw - 2.4 * s, strip.height - 6 * s), _p);
    }
    _p.color = pal.paper.withValues(alpha: neon ? 0.5 : 0.85);
    for (var x = strip.left + 2 * s; x < strip.right - 2 * s; x += 5 * s) {
      canvas
        ..drawRect(Rect.fromLTWH(x, strip.top + 0.6 * s, 2 * s, 1.6 * s), _p)
        ..drawRect(Rect.fromLTWH(x, strip.bottom - 2.2 * s, 2 * s, 1.6 * s), _p);
    }
    _s
      ..color = neon ? m.neonB : pal.ink
      ..strokeWidth = 1.6 * s;
    canvas.drawRRect(RRect.fromRectAndRadius(strip.inflate(1.5 * s), Radius.circular(3 * s)), _s);
    final hx = rtl ? strip.right - head : strip.left + head;
    _reel.paint(canvas, Offset(hx, strip.center.dy), 9 * s, ctx.clock.boilFrame * 0.5, 1, ctx);
  }
}

/// The era's pause button (a medallion, a deco button, a noir disc, a
/// marquee light, a neon ⏸); squashes when pressed.
class PauseHudItem extends HudItem {
  PauseHudItem(this.env, this.onPressed);

  final CinemaEnv env;
  final VoidCallback onPressed;
  final HudPlaque _plaque = HudPlaque();
  final Paint _p = Paint();
  double _press = 0;

  @override
  bool get interactive => true;

  @override
  bool onTap(Offset local, HudContext ctx) {
    _press = 1;
    onPressed();
    return true;
  }

  @override
  Size layoutSize(HudContext ctx) => Size.square(44 * ctx.scale);

  @override
  void update(double dt, HudContext ctx) => _press = math.max(0, _press - dt * 5);

  @override
  void paint(Canvas canvas, Rect rect, HudContext ctx) {
    final s = ctx.scale;
    final k = 1 - 0.14 * math.sin(_press * math.pi);
    final r = Rect.fromCenter(center: rect.center, width: rect.width * k, height: rect.height * k);
    _plaque.paint(canvas, r, ctx, round: true);
    _p.color = HudPlaque.textColor(ctx);
    final c = r.center + Offset(0, 0.5 * s);
    final bw = r.width * 0.12, bh = r.height * 0.4;
    canvas
      ..drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: c - Offset(bw * 0.95, 0), width: bw, height: bh), Radius.circular(bw * 0.4)),
        _p,
      )
      ..drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: c + Offset(bw * 0.95, 0), width: bw, height: bh), Radius.circular(bw * 0.4)),
        _p,
      );
  }
}

/// Free text on the era's plaque (re-laid out only when it changes).
class LabelHudItem extends HudItem {
  LabelHudItem(this.env, this.text);

  final CinemaEnv env;
  final String Function() text;
  final HudPlaque _plaque = HudPlaque();
  final TextPainter _tp = TextPainter(textDirection: TextDirection.rtl, maxLines: 1, ellipsis: '…');
  String? _shown;
  double _scale = 0;
  Size _size = Size.zero;

  @override
  Size layoutSize(HudContext ctx) {
    final t = text();
    if (t != _shown || ctx.scale != _scale) {
      _shown = t;
      _scale = ctx.scale;
      if (t.isEmpty) {
        _size = Size.zero;
      } else {
        _tp
          ..textDirection = ctx.direction
          ..text = TextSpan(
            text: hudDigits(t, env.languageCode),
            style: hudTextStyle(ctx.skin, 17 * ctx.scale, HudPlaque.textColor(ctx), glow: HudPlaque.glows(ctx)),
          )
          ..layout(maxWidth: 220 * ctx.scale);
        _size = Size(_tp.width + 26 * ctx.scale, 38 * ctx.scale);
      }
    }
    return _size;
  }

  @override
  void paint(Canvas canvas, Rect rect, HudContext ctx) {
    if ((_shown ?? '').isEmpty || rect.isEmpty) return;
    _plaque.paint(canvas, rect, ctx);
    _tp.paint(canvas, rect.center - Offset(_tp.width / 2, _tp.height / 2 - 1));
  }

  @override
  void dispose() => _tp.dispose();
}

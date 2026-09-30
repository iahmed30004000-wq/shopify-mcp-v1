import 'dart:math' as math;
import 'package:flutter/painting.dart';

import '../core/cinema_env.dart';
import '../core/stage.dart';

/// Minimal [HudKit]: paper plaques with inked text, hearts, a round pause
/// button, a boss bar. Placeholder – the stage agent replaces it.
class PlaceholderHudKit implements HudKit {
  PlaceholderHudKit(this.env);

  final CinemaEnv env;

  @override
  HudItem score() => _ScoreItem(env);

  @override
  HudItem lives() => _LivesItem();

  @override
  HudItem bossBar() => _BossBarItem(env);

  @override
  HudItem timer() => _TextItem(env, (m) {
    final t = m.timeLeft;
    if (t == null) return null;
    final s = t.inSeconds;
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  });

  @override
  HudItem progress() => _ProgressItem();

  @override
  HudItem pauseButton(VoidCallback onPressed) => _PauseItem(onPressed);

  @override
  HudItem label(String Function() text) => _TextItem(env, (_) => text());
}

/// Western → Arabic-Indic digits for Arabic.
String hudDigits(String s, String languageCode) {
  if (languageCode != 'ar') return s;
  final b = StringBuffer();
  for (final c in s.codeUnits) {
    b.writeCharCode(c >= 0x30 && c <= 0x39 ? 0x0660 + c - 0x30 : c);
  }
  return b.toString();
}

void _plaque(Canvas canvas, Rect r, HudContext ctx, Paint fill, Paint stroke) {
  final pal = ctx.skin.palette;
  final rr = RRect.fromRectAndRadius(r, Radius.circular(r.height * 0.3));
  fill
    ..shader = null
    ..color = pal.ink;
  canvas.drawRRect(rr.shift(Offset(0, 2.5 * ctx.scale)), fill);
  fill.color = pal.paper;
  canvas.drawRRect(rr, fill);
  stroke
    ..color = pal.ink
    ..strokeWidth = 2.4 * ctx.scale;
  canvas.drawRRect(rr, stroke);
}

class _ScoreItem extends HudItem {
  _ScoreItem(this.env);

  final CinemaEnv env;
  final TextPainter _tp = TextPainter(textDirection: TextDirection.ltr);
  final Paint _fill = Paint();
  final Paint _stroke = Paint()..style = PaintingStyle.stroke;
  int _shown = -1;
  double _pop = 0;
  Size _size = Size.zero;

  void _relayout(HudContext ctx) {
    if (ctx.model.score == _shown) return;
    if (_shown >= 0 && ctx.model.score > _shown) _pop = 1;
    _shown = ctx.model.score;
    final titles = ctx.skin.titles;
    _tp
      ..text = TextSpan(
        text: hudDigits(_shown.toString(), env.languageCode),
        style: TextStyle(
          fontFamily: titles.fontFamily,
          fontWeight: titles.weight,
          fontSize: 22 * ctx.scale,
          color: ctx.skin.palette.ink,
          height: 1.1,
          letterSpacing: 1.5,
        ),
      )
      ..layout();
    _size = Size(_tp.width + 28 * ctx.scale, 40 * ctx.scale);
  }

  @override
  Size layoutSize(HudContext ctx) {
    _relayout(ctx);
    return _size;
  }

  @override
  void update(double dt, HudContext ctx) => _pop = math.max(0, _pop - dt * 4);

  @override
  void paint(Canvas canvas, Rect rect, HudContext ctx) {
    final s = 1 + 0.18 * math.sin(_pop * math.pi);
    canvas
      ..save()
      ..translate(rect.center.dx, rect.center.dy)
      ..scale(s)
      ..translate(-rect.center.dx, -rect.center.dy);
    _plaque(canvas, rect, ctx, _fill, _stroke);
    _tp.paint(canvas, rect.center - Offset(_tp.width / 2, _tp.height / 2));
    canvas.restore();
  }
}

class _LivesItem extends HudItem {
  final Paint _fill = Paint();
  final Paint _stroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeJoin = StrokeJoin.round;
  final Path _heart = Path();
  Size _size = Size.zero;
  int _max = -1;

  @override
  Size layoutSize(HudContext ctx) {
    if (ctx.model.maxLives != _max) {
      _max = ctx.model.maxLives;
      _size = Size(_max * 30 * ctx.scale, 36 * ctx.scale);
    }
    return _size;
  }

  @override
  void paint(Canvas canvas, Rect rect, HudContext ctx) {
    final pal = ctx.skin.palette;
    final m = ctx.model;
    final w = rect.width / math.max(1, m.maxLives);
    for (var i = 0; i < m.maxLives; i++) {
      final c = Offset(rect.left + w * (i + 0.5), rect.center.dy);
      final r = 11.0 * ctx.scale * (1 + 0.05 * math.sin(ctx.clock.time * 6 + i));
      _heart
        ..reset()
        ..moveTo(c.dx, c.dy + r * 0.9)
        ..cubicTo(c.dx - r * 1.6, c.dy - r * 0.1, c.dx - r * 0.7, c.dy - r * 1.3, c.dx, c.dy - r * 0.45)
        ..cubicTo(c.dx + r * 0.7, c.dy - r * 1.3, c.dx + r * 1.6, c.dy - r * 0.1, c.dx, c.dy + r * 0.9)
        ..close();
      final alive = i < m.lives;
      _fill.color = alive ? pal.accent : pal.paper.withValues(alpha: 0.35);
      canvas.drawPath(_heart, _fill);
      _stroke
        ..color = pal.ink
        ..strokeWidth = 2.2 * ctx.scale;
      canvas.drawPath(_heart, _stroke);
      if (alive) {
        _fill.color = pal.highlight;
        canvas.drawCircle(c + Offset(-r * 0.45, -r * 0.35), r * 0.18, _fill);
      }
    }
  }
}

class _PauseItem extends HudItem {
  _PauseItem(this.onPressed);

  final VoidCallback onPressed;
  final Paint _fill = Paint();
  final Paint _stroke = Paint()..style = PaintingStyle.stroke;

  @override
  bool get interactive => true;

  @override
  bool onTap(Offset local, HudContext ctx) {
    onPressed();
    return true;
  }

  @override
  Size layoutSize(HudContext ctx) => Size.square(40 * ctx.scale);

  @override
  void paint(Canvas canvas, Rect rect, HudContext ctx) {
    final pal = ctx.skin.palette;
    final c = rect.center;
    final r = rect.width / 2;
    _fill.color = pal.ink;
    canvas.drawCircle(c + Offset(0, 2.5 * ctx.scale), r, _fill);
    _fill.color = pal.paper;
    canvas.drawCircle(c, r, _fill);
    _stroke
      ..color = pal.ink
      ..strokeWidth = 2.4 * ctx.scale;
    canvas.drawCircle(c, r, _stroke);
    _fill.color = pal.ink;
    final bw = r * 0.22, bh = r * 0.9;
    canvas
      ..drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: c - Offset(bw, 0), width: bw, height: bh), Radius.circular(bw / 2)), _fill)
      ..drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: c + Offset(bw, 0), width: bw, height: bh), Radius.circular(bw / 2)), _fill);
  }
}

class _BossBarItem extends HudItem {
  _BossBarItem(this.env);

  final CinemaEnv env;
  final Paint _fill = Paint();
  final Paint _stroke = Paint()..style = PaintingStyle.stroke;

  @override
  Size layoutSize(HudContext ctx) => ctx.model.bossHealth == null ? Size.zero : Size(220 * ctx.scale, 26 * ctx.scale);

  @override
  void paint(Canvas canvas, Rect rect, HudContext ctx) {
    final hp = ctx.model.bossHealth;
    if (hp == null || rect.isEmpty) return;
    _plaque(canvas, rect, ctx, _fill, _stroke);
    final inner = rect.deflate(6 * ctx.scale);
    _fill.color = ctx.skin.palette.accent2;
    canvas.drawRect(Rect.fromLTWH(inner.left, inner.top, inner.width * hp.clamp(0.0, 1.0), inner.height), _fill);
  }
}

class _ProgressItem extends HudItem {
  final Paint _fill = Paint();

  @override
  Size layoutSize(HudContext ctx) => ctx.model.progress == null ? Size.zero : Size(160 * ctx.scale, 10 * ctx.scale);

  @override
  void paint(Canvas canvas, Rect rect, HudContext ctx) {
    final p = ctx.model.progress;
    if (p == null || rect.isEmpty) return;
    _fill.color = ctx.skin.palette.ink;
    canvas.drawRRect(RRect.fromRectAndRadius(rect, Radius.circular(rect.height / 2)), _fill);
    _fill.color = ctx.skin.palette.paper;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(rect.left, rect.top, rect.width * p.clamp(0.0, 1.0), rect.height), Radius.circular(rect.height / 2)),
      _fill,
    );
  }
}

class _TextItem extends HudItem {
  _TextItem(this.env, this.text);

  final CinemaEnv env;
  final String? Function(HudModel model) text;
  final TextPainter _tp = TextPainter(textDirection: TextDirection.rtl);
  final Paint _fill = Paint();
  final Paint _stroke = Paint()..style = PaintingStyle.stroke;
  String? _shown;
  Size _size = Size.zero;

  @override
  Size layoutSize(HudContext ctx) {
    final t = text(ctx.model);
    if (t != _shown) {
      _shown = t;
      if (t == null) {
        _size = Size.zero;
      } else {
        _tp
          ..textDirection = ctx.direction
          ..text = TextSpan(
            text: hudDigits(t, env.languageCode),
            style: TextStyle(
              fontFamily: ctx.skin.titles.fontFamily,
              fontSize: 18 * ctx.scale,
              color: ctx.skin.palette.ink,
              fontWeight: ctx.skin.titles.weight,
            ),
          )
          ..layout();
        _size = Size(_tp.width + 24 * ctx.scale, 36 * ctx.scale);
      }
    }
    return _size;
  }

  @override
  void paint(Canvas canvas, Rect rect, HudContext ctx) {
    if (_shown == null || rect.isEmpty) return;
    _plaque(canvas, rect, ctx, _fill, _stroke);
    _tp.paint(canvas, rect.center - Offset(_tp.width / 2, _tp.height / 2));
  }
}

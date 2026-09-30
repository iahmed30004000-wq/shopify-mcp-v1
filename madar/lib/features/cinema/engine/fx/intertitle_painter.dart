import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../core/cinema_shaders.dart';
import '../core/era_skin.dart';
import '../core/film_clock.dart';
import '../core/shader_uniforms.dart';
import '../core/stage.dart';
import 'line_boil.dart';

/// Paints intertitle cards in the era's frame style – everything drawn in
/// code (no images), text already localised by the game.
///
/// | TitleFrame | era | look |
/// |---|---|---|
/// | ornate | 1920s | black card, cream double rules with scrollwork corners, the orbit emblem |
/// | artDeco | 1930s, 1950s | aged card stock, sunburst, stepped corners, fan and chevrons |
/// | plain | 1940s | black card, long hairline rules, slatted light |
/// | marquee | 1970s | a sign board ringed with chasing bulbs over 70s stripes |
/// | osd | 1980s | neon tubes over a perspective grid, the deck's on-screen display |
///
/// Arabic + English: [IntertitleCard.text] is the headline and
/// [IntertitleCard.subtitle] the second line (bilingual cards pass the
/// other language there). Letter spacing is applied to Latin-only lines
/// (it would break Arabic joining). Ornaments boil at the ink's rate.
///
/// Usage (e.g. from CinemaTransitions.paint): one painter per game,
/// `paint(canvas, screenRect, card, clock, appear: a, opacity: a)`; the card
/// fills [bounds]. Text is re-laid out only when the card or width changes;
/// ornaments are rebuilt only when the boil frame, size or [appear] change.
class IntertitlePainter {
  IntertitlePainter({required this.skin, this.direction = TextDirection.rtl, this.boil = true});

  final EraSkin skin;
  TextDirection direction;

  /// Ornaments re-ink on twos (false under reduced motion).
  bool boil;

  final ShaderPool _paperPool = ShaderPool(CinemaShader.paper, maxInstances: 2);
  final TextPainter _title = TextPainter(textAlign: TextAlign.center);
  final TextPainter _subtitle = TextPainter(textAlign: TextAlign.center);
  final TextPainter _glow = TextPainter(textAlign: TextAlign.center);
  final Paint _fill = Paint();
  final Paint _stroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  final Paint _layer = Paint();
  final Paint _blur = Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
  final Path _ink = Path();
  final Path _line = Path();
  final Path _accent = Path();
  final Path _rays = Path();
  final Path _tri = Path();
  final BoilPen _pen = BoilPen(amplitude: 0.7, seed: 11);

  IntertitleCard? _laidOut;
  double _laidOutWidth = -1;
  int _ornFrame = -1;
  Rect _ornRect = Rect.zero;
  double _ornAppear = -1;
  IntertitleKind? _ornKind;

  static final RegExp _arabic = RegExp('[؀-ۿݐ-ݿﭐ-﷿ﹰ-﻿]');

  EraPalette get _pal => skin.palette;

  /// The card's content panel inside [bounds] (for hit areas or overlays).
  Rect panelRect(Rect bounds, IntertitleCard card) {
    _layoutText(card, bounds.width);
    return _panel(bounds, card);
  }

  /// Paints [card] filling [bounds]. [appear] (0..1) draws the ornaments
  /// in; [opacity] fades the whole card.
  void paint(Canvas canvas, Rect bounds, IntertitleCard card, FilmClock clock, {double appear = 1, double opacity = 1}) {
    if (bounds.isEmpty || opacity <= 0.001) return;
    final fading = opacity < 0.999;
    if (fading) canvas.saveLayer(bounds, _layer..color = Color.fromRGBO(0, 0, 0, opacity.clamp(0.0, 1.0)));
    _layoutText(card, bounds.width);
    final panel = _panel(bounds, card);
    final frame = boil ? clock.boilFrame : 0;
    final a = appear.clamp(0.0, 1.0);
    final rebuild = frame != _ornFrame || panel != _ornRect || (a - _ornAppear).abs() > 0.004 || card.kind != _ornKind;
    if (rebuild) {
      _ornFrame = frame;
      _ornRect = panel;
      _ornAppear = a;
      _ornKind = card.kind;
      _ink.reset();
      _line.reset();
      _accent.reset();
      _rays.reset();
    }
    switch (skin.titles.frame) {
      case TitleFrame.ornate:
        _ornate(canvas, bounds, panel, card, clock, a, rebuild);
      case TitleFrame.artDeco:
        _deco(canvas, bounds, panel, card, clock, a, rebuild);
      case TitleFrame.plain:
        _plain(canvas, bounds, panel, card, clock, a, rebuild);
      case TitleFrame.marquee:
        _marquee(canvas, bounds, panel, card, clock, a, rebuild);
      case TitleFrame.osd:
        _osd(canvas, bounds, panel, card, clock, a, rebuild);
    }
    if (fading) canvas.restore();
  }

  // ---------------------------------------------------------------------------
  // Text.

  double _titleScale(IntertitleKind kind) => switch (kind) {
    IntertitleKind.title || IntertitleKind.theEnd || IntertitleKind.gameOver => 0.115,
    IntertitleKind.chapter || IntertitleKind.intermission => 0.095,
    IntertitleKind.dialogue => 0.072,
  };

  Color get _textColor => switch (skin.titles.frame) {
    TitleFrame.artDeco => _pal.ink,
    _ => _pal.paper,
  };

  Color get _subColor => switch (skin.titles.frame) {
    TitleFrame.artDeco => Color.lerp(_pal.shadow, _pal.ink, 0.35)!,
    TitleFrame.marquee => _pal.footlight,
    TitleFrame.osd => _pal.accent2,
    _ => Color.lerp(_pal.paper, _pal.ink, 0.25)!,
  };

  void _layoutText(IntertitleCard card, double width) {
    if (identical(card, _laidOut) && width == _laidOutWidth) return;
    _laidOut = card;
    _laidOutWidth = width;
    final t = skin.titles;
    final size = (width * _titleScale(card.kind)).clamp(20.0, 64.0);
    final maxW = width * 0.72;
    TextStyle style(String text, double fontSize, FontWeight weight, Color color, double spacing, {Paint? paint}) => TextStyle(
      fontFamily: t.fontFamily,
      fontWeight: weight,
      fontSize: fontSize,
      height: _arabic.hasMatch(text) ? 1.45 : 1.2,
      letterSpacing: _arabic.hasMatch(text) ? 0 : spacing,
      color: paint == null ? color : null,
      foreground: paint,
    );
    _title
      ..textDirection = direction
      ..text = TextSpan(text: card.text, style: style(card.text, size, t.weight, _textColor, t.letterSpacing + 1.5))
      ..layout(maxWidth: maxW);
    final sub = card.subtitle ?? '';
    _subtitle
      ..textDirection = direction
      ..text = TextSpan(text: sub, style: style(sub, size * 0.46, FontWeight.w600, _subColor, 2.5))
      ..layout(maxWidth: maxW);
    if (skin.titles.frame == TitleFrame.osd || skin.titles.frame == TitleFrame.marquee) {
      final osd = skin.titles.frame == TitleFrame.osd;
      final glowPaint = Paint()
        ..color = osd ? _pal.accent : _pal.accent2
        ..maskFilter = osd ? const MaskFilter.blur(BlurStyle.normal, 5) : null;
      _glow
        ..textDirection = direction
        ..text = TextSpan(text: card.text, style: style(card.text, size, t.weight, _pal.accent, t.letterSpacing + 1.5, paint: glowPaint))
        ..layout(maxWidth: maxW);
    }
  }

  double get _contentHeight => _title.height + (_hasSub ? _subtitle.height + _title.height * 0.42 : 0);
  bool get _hasSub => (_laidOut?.subtitle ?? '').isNotEmpty;

  Rect _panel(Rect bounds, IntertitleCard card) {
    final w = bounds.width * 0.88;
    final h = math.min(math.max(_contentHeight + bounds.width * 0.5, bounds.width * 1.02), bounds.height * 0.86);
    final osd = skin.titles.frame == TitleFrame.osd;
    final centre = osd ? Offset(bounds.center.dx, bounds.top + bounds.height * 0.4) : bounds.center;
    return Rect.fromCenter(center: centre, width: w, height: osd ? _contentHeight + bounds.width * 0.3 : h);
  }

  /// Gap between the headline and the second line.
  double get _gap => _title.height * 0.42;

  /// y of the divider between the two lines (for ornaments).
  double _dividerY(Rect panel, {double shift = 0}) => panel.center.dy - _contentHeight / 2 + shift + _title.height + _gap / 2;

  void _paintText(Canvas canvas, Rect panel, {Offset shift = Offset.zero, bool glow = false, bool subtitle = true}) {
    var y = panel.center.dy - _contentHeight / 2 + shift.dy;
    final cx = panel.center.dx + shift.dx;
    if (glow) _glow.paint(canvas, Offset(cx - _glow.width / 2, y));
    _title.paint(canvas, Offset(cx - _title.width / 2, y));
    y += _title.height + _gap;
    if (_hasSub && subtitle) _subtitle.paint(canvas, Offset(cx - _subtitle.width / 2, y));
  }

  /// Paints the paper stock (paper.frag, flat colour fallback).
  void _paper(Canvas canvas, Rect rect, FilmClock clock, Color paper, Color stain, {double age = 0.55, double seed = 3, double stains = 0.35}) {
    final s = _paperPool.next(clock);
    if (s != null) {
      PaperUniforms.write(s, rect: rect, paper: paper, stain: stain, age: age, seed: seed, stainAmount: stains);
      _fill
        ..shader = s
        ..color = const Color(0xFFFFFFFF);
    } else {
      _fill
        ..shader = null
        ..color = paper;
    }
    canvas.drawRect(rect, _fill);
    _fill.shader = null;
  }

  // ---------------------------------------------------------------------------
  // 1920s – ornate.

  void _ornate(Canvas canvas, Rect bounds, Rect panel, IntertitleCard card, FilmClock clock, double a, bool rebuild) {
    final ink = _pal.ink;
    final cream = _pal.paper;
    final card0 = Color.lerp(ink, cream, 0.06)!;
    _paper(canvas, bounds, clock, card0, ink, age: 0.25, seed: 5, stains: 0.2);
    final medal = panel.width * 0.085;
    final top = Offset(panel.center.dx, panel.top);
    final bottom = Offset(panel.center.dx, panel.bottom);
    if (rebuild) {
      _pen.begin(_line, _ornFrame);
      // Double rule with coved corners, drawn on from the middle outwards.
      _covedRect(panel, 20, a);
      _pen.begin(_accent, _ornFrame);
      _covedRect(panel.deflate(8), 14, a);
      _covedRect(panel.deflate(13), 11, a);
      _pen.begin(_ink, _ornFrame);
      final s = panel.width * 0.1 * (0.35 + 0.65 * a);
      for (var i = 0; i < 4; i++) {
        final cx = i.isEven ? panel.left : panel.right;
        final cy = i < 2 ? panel.top : panel.bottom;
        _scroll(Offset(cx, cy), Offset(i.isEven ? 1 : -1, i < 2 ? 1 : -1), s);
      }
      // Medallions on the top and bottom rules, wings along them.
      final m = medal * (0.5 + 0.5 * a);
      _emblem(top, m * 0.62);
      for (final dir in const [-1.0, 1.0]) {
        _pen
          ..brush(top + Offset(dir * m * 1.1, 0), top + Offset(dir * m * 2.2, -m * 0.55), top + Offset(dir * m * 3.4, -m * 0.1), m * 0.2, taper: 0.9)
          ..circle(top + Offset(dir * m * 3.55, -m * 0.05), m * 0.09)
          ..brush(bottom + Offset(dir * m * 0.9, 0), bottom + Offset(dir * m * 1.8, m * 0.45), bottom + Offset(dir * m * 2.8, m * 0.08), m * 0.16, taper: 0.9);
      }
      _pen
        ..moveTo(bottom.dx, bottom.dy - m * 0.42)
        ..lineTo(bottom.dx + m * 0.42, bottom.dy)
        ..lineTo(bottom.dx, bottom.dy + m * 0.42)
        ..lineTo(bottom.dx - m * 0.42, bottom.dy)
        ..close();
      if (_hasSub) _fleuron(Offset(panel.center.dx, _dividerY(panel)), panel.width * 0.16 * a);
    }
    // Knock the rules out behind the medallions.
    _fill
      ..shader = null
      ..color = card0;
    canvas
      ..drawCircle(top, medal, _fill)
      ..drawRect(Rect.fromCenter(center: bottom, width: medal * 1.4, height: 30), _fill);
    _stroke
      ..color = cream.withValues(alpha: 0.95)
      ..strokeWidth = 2.6;
    canvas.drawPath(_line, _stroke);
    _stroke.strokeWidth = 1.1;
    canvas.drawPath(_accent, _stroke);
    _stroke.strokeWidth = 1.4;
    canvas
      ..drawCircle(top, medal * 0.92, _stroke)
      ..drawCircle(top, medal * 0.78, _stroke);
    _fill.color = cream.withValues(alpha: 0.95);
    canvas.drawPath(_ink, _fill);
    _paintText(canvas, panel);
  }

  void _covedRect(Rect r, double cove, double a) {
    // Each side is drawn from its midpoint outwards by [a].
    final c = cove;
    final hx = (r.width / 2 - c) * a;
    final hy = (r.height / 2 - c) * a;
    final m = r.center;
    _pen
      ..moveTo(m.dx - hx, r.top)
      ..lineTo(m.dx + hx, r.top)
      ..moveTo(m.dx - hx, r.bottom)
      ..lineTo(m.dx + hx, r.bottom)
      ..moveTo(r.left, m.dy - hy)
      ..lineTo(r.left, m.dy + hy)
      ..moveTo(r.right, m.dy - hy)
      ..lineTo(r.right, m.dy + hy);
    if (a < 0.98) return;
    // Coves: quarter circles curving inward at each corner.
    _pen
      ..moveTo(r.left + c, r.top)
      ..quadTo(r.left + c, r.top + c, r.left, r.top + c)
      ..moveTo(r.right - c, r.top)
      ..quadTo(r.right - c, r.top + c, r.right, r.top + c)
      ..moveTo(r.left + c, r.bottom)
      ..quadTo(r.left + c, r.bottom - c, r.left, r.bottom - c)
      ..moveTo(r.right - c, r.bottom)
      ..quadTo(r.right - c, r.bottom - c, r.right, r.bottom - c);
  }

  /// A corner scroll: a curling brush stroke into the card with a spiral end
  /// and a berry.
  void _scroll(Offset corner, Offset dir, double s) {
    final p0 = corner + Offset(dir.dx * s * 0.25, dir.dy * s * 0.25);
    final p1 = corner + Offset(dir.dx * s * 1.6, dir.dy * s * 0.35);
    final c = corner + Offset(dir.dx * s * 0.9, dir.dy * s * 1.1);
    _pen.brush(p0, c, p1, s * 0.16, taper: 0.9);
    final q1 = corner + Offset(dir.dx * s * 0.35, dir.dy * s * 1.6);
    final c2 = corner + Offset(dir.dx * s * 1.1, dir.dy * s * 0.9);
    _pen.brush(p0, c2, q1, s * 0.16, taper: 0.9);
    // Spiral curls at both tips.
    _curl(p1, Offset(dir.dx, 0), s * 0.26);
    _curl(q1, Offset(0, dir.dy), s * 0.26);
    _pen.circle(corner + Offset(dir.dx * s * 0.62, dir.dy * s * 0.62), s * 0.1);
  }

  void _curl(Offset tip, Offset dir, double r) {
    final n = Offset(-dir.dy, dir.dx);
    final a = tip;
    final b = tip + dir * r + n * r;
    final c = tip + n * r * 1.4;
    _pen.brush(a, tip + dir * r * 1.2, b, r * 0.35, taper: 0.8, segments: 6);
    _pen.brush(b, tip + dir * r * 0.2 + n * r * 1.9, c, r * 0.28, taper: 0.9, segments: 6);
  }

  void _fleuron(Offset c, double w) {
    if (w <= 1) return;
    _pen
      ..brush(c + Offset(-w, 0), c + Offset(-w * 0.5, -w * 0.06), c + Offset(-w * 0.12, 0), w * 0.035, taper: 0.95)
      ..brush(c + Offset(w * 0.12, 0), c + Offset(w * 0.5, -w * 0.06), c + Offset(w, 0), w * 0.035, taper: 0.95)
      // diamond
      ..moveTo(c.dx, c.dy - w * 0.07)
      ..lineTo(c.dx + w * 0.07, c.dy)
      ..lineTo(c.dx, c.dy + w * 0.07)
      ..lineTo(c.dx - w * 0.07, c.dy)
      ..close()
      ..circle(c + Offset(-w * 0.14, 0), w * 0.022)
      ..circle(c + Offset(w * 0.14, 0), w * 0.022);
  }

  /// Madar's orbit emblem: a planet, its tilted ring and a moon.
  void _emblem(Offset c, double r) {
    _pen.circle(c, r * 0.55);
    final save = _pen.path;
    _pen.begin(_accent, _ornFrame);
    _ringPath(c, r * 1.25, r * 0.42, -0.35);
    _pen.begin(save, _ornFrame);
    _pen.circle(c + Offset(r * 1.15, -r * 0.62), r * 0.16);
  }

  void _ringPath(Offset c, double rx, double ry, double tilt) {
    const k = 0.5523;
    final cs = math.cos(tilt), sn = math.sin(tilt);
    Offset p(double x, double y) => Offset(c.dx + x * cs - y * sn, c.dy + x * sn + y * cs);
    final a = p(rx, 0), b = p(0, ry), d = p(-rx, 0), e = p(0, -ry);
    final a1 = p(rx, ry * k), b1 = p(rx * k, ry), b2 = p(-rx * k, ry), d1 = p(-rx, ry * k);
    final d2 = p(-rx, -ry * k), e1 = p(-rx * k, -ry), e2 = p(rx * k, -ry), a2 = p(rx, -ry * k);
    _pen
      ..moveTo(a.dx, a.dy)
      ..cubicTo(a1.dx, a1.dy, b1.dx, b1.dy, b.dx, b.dy)
      ..cubicTo(b2.dx, b2.dy, d1.dx, d1.dy, d.dx, d.dy)
      ..cubicTo(d2.dx, d2.dy, e1.dx, e1.dy, e.dx, e.dy)
      ..cubicTo(e2.dx, e2.dy, a2.dx, a2.dy, a.dx, a.dy);
  }

  // ---------------------------------------------------------------------------
  // 1930s / 1950s – art deco.

  void _deco(Canvas canvas, Rect bounds, Rect panel, IntertitleCard card, FilmClock clock, double a, bool rebuild) {
    final ink = _pal.ink;
    final colour = !skin.era.isMonochrome;
    // Behind the panel: card stock (1930s) or a lush velvet ground in the
    // colour eras (a 1950s main title), with sunburst rays.
    if (colour) {
      _velvet(canvas, bounds, panel);
    } else {
      _paper(canvas, bounds, clock, _pal.paper, _pal.shadow, age: 0.4, seed: 9, stains: 0.12);
    }
    if (rebuild) {
      final origin = Offset(panel.center.dx, panel.bottom + panel.height * 0.12);
      const rays = 36;
      final far = bounds.longestSide * 1.3 * a;
      for (var i = 0; i < rays; i += 2) {
        final a0 = math.pi + i * math.pi / rays;
        final a1 = a0 + math.pi / rays;
        _rays
          ..moveTo(origin.dx, origin.dy)
          ..lineTo(origin.dx + math.cos(a0) * far, origin.dy + math.sin(a0) * far)
          ..lineTo(origin.dx + math.cos(a1) * far, origin.dy + math.sin(a1) * far)
          ..close();
      }
    }
    _fill
      ..shader = null
      ..color = colour ? _raysColour : ink.withValues(alpha: 0.07);
    canvas.save();
    canvas.clipRect(bounds);
    canvas.drawPath(_rays, _fill);
    canvas.restore();
    // The panel itself: a lighter card with stepped corners.
    if (rebuild) {
      _pen.begin(_line, _ornFrame);
      _steppedRect(panel, 20);
      _pen.begin(_ink, _ornFrame);
      _steppedRect(panel.deflate(8), 14);
      // Fan on the top edge.
      final fanC = Offset(panel.center.dx, panel.top + 2);
      final fr = panel.width * 0.17 * (0.3 + 0.7 * a);
      for (var k = 0; k < 3; k++) {
        final r = fr * (1 - k * 0.28);
        _arc(fanC, r);
      }
      _pen.begin(_accent, _ornFrame);
      for (var k = 0; k <= 8; k++) {
        final ang = math.pi + k * math.pi / 8;
        _pen.line(fanC, fanC + Offset(math.cos(ang), math.sin(ang)) * fr, bow: 0);
      }
      // Chevrons on the bottom edge and speed lines on the sides.
      final chev = Offset(panel.center.dx, panel.bottom + panel.width * 0.075);
      final cw = panel.width * 0.08 * a;
      for (var k = 0; k < 3; k++) {
        final y = chev.dy - k * cw * 0.45;
        _pen
          ..moveTo(chev.dx - cw, y)
          ..lineTo(chev.dx, y + cw * 0.5)
          ..lineTo(chev.dx + cw, y);
      }
      for (final side in [panel.left + 14, panel.right - 14]) {
        final h = panel.height * 0.18 * a;
        for (var k = -1; k <= 1; k++) {
          _pen.line(Offset(side + k * 4.0, panel.center.dy - h), Offset(side + k * 4.0, panel.center.dy + h), bow: 0);
        }
      }
    }
    // Panel fill (slightly lighter stock) under the rules.
    _fill
      ..shader = null
      ..color = Color.lerp(_pal.paper, _pal.highlight, colour ? 0.1 : 0.45)!;
    canvas.drawRect(panel.deflate(4), _fill);
    // Deco friezes: an ink band with a sawtooth of stock along the top and
    // bottom of the panel.
    final inner = panel.deflate(8);
    final bandH = panel.width * 0.045;
    for (var b = 0; b < 2; b++) {
      final y = b == 0 ? inner.top + 6.0 : inner.bottom - 6 - bandH;
      final band = Rect.fromLTWH(inner.left + 16, y, inner.width - 32, bandH);
      _fill.color = colour ? _pal.accent2 : ink;
      canvas.drawRect(band, _fill);
      _fill.color = Color.lerp(_pal.paper, _pal.highlight, colour ? 0.1 : 0.45)!;
      final n = (band.width / (bandH * 1.2)).floor();
      final step = band.width / n;
      _tri.reset();
      for (var k = 0; k < n; k++) {
        final x = band.left + k * step;
        _tri
          ..moveTo(x + step * 0.15, band.bottom - 2)
          ..lineTo(x + step * 0.5, band.top + 3)
          ..lineTo(x + step * 0.85, band.bottom - 2)
          ..close();
      }
      canvas.drawPath(_tri, _fill);
    }
    // Fan fill.
    final fanC = Offset(panel.center.dx, panel.top + 2);
    final fr = panel.width * 0.17 * (0.3 + 0.7 * a);
    _fill.color = colour ? _pal.accent : _pal.midtone;
    canvas.drawArc(Rect.fromCircle(center: fanC, radius: fr), math.pi, math.pi, true, _fill);
    _fill.color = colour ? _pal.accent2 : _pal.shadow;
    canvas.drawArc(Rect.fromCircle(center: fanC, radius: fr * 0.44), math.pi, math.pi, true, _fill);
    _stroke
      ..color = ink
      ..strokeWidth = 3.4;
    canvas.drawPath(_line, _stroke);
    _stroke.strokeWidth = 1.8;
    canvas.drawPath(_ink, _stroke);
    _stroke
      ..strokeWidth = 1.1
      ..color = ink.withValues(alpha: 0.8);
    canvas.drawPath(_accent, _stroke);
    // A small diamond rule between the lines.
    if (_hasSub) {
      final y = _dividerY(panel);
      final w = panel.width * 0.12;
      _stroke
        ..color = ink
        ..strokeWidth = 1.4;
      canvas
        ..drawLine(Offset(panel.center.dx - w, y), Offset(panel.center.dx - 7, y), _stroke)
        ..drawLine(Offset(panel.center.dx + 7, y), Offset(panel.center.dx + w, y), _stroke);
      _fill.color = colour ? _pal.accent : ink;
      canvas
        ..save()
        ..translate(panel.center.dx, y)
        ..rotate(math.pi / 4)
        ..drawRect(const Rect.fromLTWH(-3.5, -3.5, 7, 7), _fill)
        ..restore();
    }
    _paintText(canvas, panel);
  }

  // Velvet ground of the colour-era deco card (cached per size).
  ui.Gradient? _velvetShader;
  Rect _velvetRect = Rect.zero;
  late final Color _raysColour = _pal.footlight.withValues(alpha: 0.2);

  void _velvet(Canvas canvas, Rect bounds, Rect panel) {
    if (_velvetShader == null || bounds != _velvetRect) {
      _velvetRect = bounds;
      _velvetShader = ui.Gradient.radial(
        panel.center,
        bounds.longestSide * 0.72,
        [Color.lerp(_pal.curtain, _pal.accent, 0.4)!, _pal.curtain, _pal.curtainShade],
        const [0, 0.42, 1],
      );
    }
    _fill
      ..shader = _velvetShader
      ..color = const Color(0xFFFFFFFF);
    canvas.drawRect(bounds, _fill);
    _fill.shader = null;
  }

  void _steppedRect(Rect r, double step) {
    final s = step, h = step / 2;
    _pen
      ..moveTo(r.left + s, r.top)
      ..lineTo(r.right - s, r.top)
      ..lineTo(r.right - s, r.top + h)
      ..lineTo(r.right - h, r.top + h)
      ..lineTo(r.right - h, r.top + s)
      ..lineTo(r.right, r.top + s)
      ..lineTo(r.right, r.bottom - s)
      ..lineTo(r.right - h, r.bottom - s)
      ..lineTo(r.right - h, r.bottom - h)
      ..lineTo(r.right - s, r.bottom - h)
      ..lineTo(r.right - s, r.bottom)
      ..lineTo(r.left + s, r.bottom)
      ..lineTo(r.left + s, r.bottom - h)
      ..lineTo(r.left + h, r.bottom - h)
      ..lineTo(r.left + h, r.bottom - s)
      ..lineTo(r.left, r.bottom - s)
      ..lineTo(r.left, r.top + s)
      ..lineTo(r.left + h, r.top + s)
      ..lineTo(r.left + h, r.top + h)
      ..lineTo(r.left + s, r.top + h)
      ..close();
  }

  void _arc(Offset c, double r) {
    // Upper half circle as two quadratic-ish cubic arcs.
    const k = 0.5523;
    _pen
      ..moveTo(c.dx - r, c.dy)
      ..cubicTo(c.dx - r, c.dy - r * k, c.dx - r * k, c.dy - r, c.dx, c.dy - r)
      ..cubicTo(c.dx + r * k, c.dy - r, c.dx + r, c.dy - r * k, c.dx + r, c.dy);
  }

  // ---------------------------------------------------------------------------
  // 1940s – plain (noir).

  void _plain(Canvas canvas, Rect bounds, Rect panel, IntertitleCard card, FilmClock clock, double a, bool rebuild) {
    final ink = _pal.ink;
    final paper = _pal.paper;
    _fill
      ..shader = null
      ..color = ink;
    canvas.drawRect(bounds, _fill);
    if (bounds != _nightRect || panel != _nightPanel) _buildNight(bounds, panel);
    // A pool of light behind the words, cut by blind slats.
    _fill
      ..shader = _lightPool
      ..color = const Color(0xFFFFFFFF);
    canvas.drawRect(bounds, _fill);
    _fill.shader = null;
    canvas.save();
    canvas.clipRect(bounds);
    canvas.translate(bounds.center.dx, bounds.center.dy);
    canvas.rotate(-0.42);
    _fill.color = ink.withValues(alpha: 0.55);
    final span = bounds.longestSide;
    for (var y = -span; y < span; y += 46) {
      canvas.drawRect(Rect.fromLTWH(-span, y + 30, span * 2, 16), _fill);
    }
    canvas.restore();
    // Beyond the window: haze over the city, the rooftops against it, a few
    // windows still lit.
    _fill
      ..shader = _haze
      ..color = const Color(0xFFFFFFFF);
    canvas.drawRect(bounds, _fill);
    _fill
      ..shader = null
      ..color = ink;
    canvas.drawPath(_skyline, _fill);
    _fill.color = _windowColour;
    canvas.drawPath(_windows, _fill);
    if (rebuild) {
      _pen.begin(_line, _ornFrame);
      final y0 = panel.center.dy - _contentHeight / 2 - panel.width * 0.1;
      final y1 = panel.center.dy + _contentHeight / 2 + panel.width * 0.1;
      final half = panel.width * 0.5 * a;
      for (final y in [y0, y1]) {
        _pen
          ..line(Offset(panel.center.dx - half, y), Offset(panel.center.dx - 14, y), bow: 0)
          ..line(Offset(panel.center.dx + 14, y), Offset(panel.center.dx + half, y), bow: 0);
        _pen
          ..moveTo(panel.center.dx, y - 5)
          ..lineTo(panel.center.dx + 5, y)
          ..lineTo(panel.center.dx, y + 5)
          ..lineTo(panel.center.dx - 5, y)
          ..close();
      }
    }
    _stroke
      ..color = paper.withValues(alpha: 0.85)
      ..strokeWidth = 1.2;
    canvas.drawPath(_line, _stroke);
    _paintText(canvas, panel);
  }

  // The noir card's night: cached per size (never rebuilt per frame).
  final Path _skyline = Path();
  final Path _windows = Path();
  Rect _nightRect = Rect.zero;
  Rect _nightPanel = Rect.zero;
  ui.Gradient? _haze;
  ui.Gradient? _lightPool;
  late final Color _windowColour = Color.lerp(_pal.paper, _pal.footlight, 0.4)!.withValues(alpha: 0.75);

  double _rnd(int i, int k) => (LineBoil.jitter(97, i * 13 + k, 0) + 1) / 2;

  void _buildNight(Rect b, Rect panel) {
    _nightRect = b;
    _nightPanel = panel;
    final ink = _pal.ink;
    _lightPool = ui.Gradient.radial(panel.center, panel.width * 0.75, [Color.lerp(ink, _pal.paper, 0.16)!, ink.withValues(alpha: 0)]);
    // (Bright enough to survive the noir print's crushed toe.)
    final horizon = b.bottom - b.height * 0.36;
    _haze = ui.Gradient.linear(Offset(0, horizon), Offset(0, b.bottom), [
      ink.withValues(alpha: 0),
      Color.lerp(ink, _pal.paper, 0.78)!,
      Color.lerp(ink, _pal.paper, 0.5)!,
    ], const [0, 0.62, 1]);
    // Rooftops: stepped blocks, water towers and spires, lit windows.
    _skyline.reset();
    _windows.reset();
    final base = b.bottom + 2;
    final unit = b.width / 412;
    var x = b.left - 6;
    var i = 0;
    _skyline.moveTo(x, base);
    while (x < b.right + 6) {
      final w = b.width * (0.08 + 0.1 * _rnd(i, 1));
      final h = b.height * (0.07 + 0.17 * _rnd(i, 2)) * (i.isEven ? 1 : 0.8);
      final top = base - h;
      _skyline.lineTo(x, top);
      switch ((_rnd(i, 3) * 4).floor()) {
        case 0: // stepped cornice
          _skyline
            ..lineTo(x + w * 0.18, top)
            ..lineTo(x + w * 0.18, top - h * 0.1)
            ..lineTo(x + w * 0.82, top - h * 0.1)
            ..lineTo(x + w * 0.82, top);
        case 1: // water tower on legs
          final c = x + w * 0.5;
          final tw = w * 0.34;
          _skyline
            ..lineTo(c - tw * 0.5, top)
            ..lineTo(c - tw * 0.42, top - 14 * unit)
            ..lineTo(c - tw * 0.5, top - 14 * unit)
            ..lineTo(c - tw * 0.5, top - 30 * unit)
            ..lineTo(c, top - 38 * unit)
            ..lineTo(c + tw * 0.5, top - 30 * unit)
            ..lineTo(c + tw * 0.5, top - 14 * unit)
            ..lineTo(c + tw * 0.42, top - 14 * unit)
            ..lineTo(c + tw * 0.5, top);
        case 2: // spire with an aerial
          final c = x + w * 0.5;
          _skyline
            ..lineTo(c - w * 0.2, top)
            ..lineTo(c - w * 0.08, top - h * 0.3)
            ..lineTo(c - 1.2 * unit, top - h * 0.3)
            ..lineTo(c - 0.6 * unit, top - h * 0.55)
            ..lineTo(c + 0.6 * unit, top - h * 0.55)
            ..lineTo(c + 1.2 * unit, top - h * 0.3)
            ..lineTo(c + w * 0.08, top - h * 0.3)
            ..lineTo(c + w * 0.2, top);
        default: // flat roof with a chimney
          _skyline
            ..lineTo(x + w * 0.7, top)
            ..lineTo(x + w * 0.7, top - 10 * unit)
            ..lineTo(x + w * 0.78, top - 10 * unit)
            ..lineTo(x + w * 0.78, top);
      }
      _skyline.lineTo(x + w, top);
      // Windows: a grid, most of them dark at this hour.
      final ww = 3.2 * unit, wh = 4.6 * unit, gx = 7.5 * unit, gy = 10 * unit;
      for (var row = 0; top + 8 * unit + row * gy < base - wh; row++) {
        for (var col = 0; x + 5 * unit + col * gx < x + w - ww - 3 * unit; col++) {
          if (_rnd(i * 41 + row * 7 + col, 5) > 0.86) {
            _windows.addRect(Rect.fromLTWH(x + 5 * unit + col * gx, top + 8 * unit + row * gy, ww, wh));
          }
        }
      }
      x += w;
      i++;
    }
    _skyline
      ..lineTo(x, base)
      ..close();
  }

  // ---------------------------------------------------------------------------
  // 1970s – marquee.

  void _marquee(Canvas canvas, Rect bounds, Rect panel, IntertitleCard card, FilmClock clock, double a, bool rebuild) {
    final ink = _pal.ink;
    _fill
      ..shader = null
      ..color = ink;
    canvas.drawRect(bounds, _fill);
    // 70s stripes sweeping across behind the sign.
    canvas.save();
    canvas.clipRect(bounds);
    canvas.translate(bounds.center.dx, panel.center.dy);
    canvas.rotate(-0.18);
    final len = bounds.longestSide * 1.4 * a;
    for (var i = 0; i < 3; i++) {
      _fill.color = switch (i) {
        0 => _pal.footlight,
        1 => _pal.accent,
        _ => _pal.curtain,
      };
      canvas.drawRect(Rect.fromLTWH(-len / 2, -panel.height * 0.36 + i * 22, len, 16), _fill);
    }
    canvas.restore();
    // The sign board.
    final board = RRect.fromRectAndRadius(panel.deflate(panel.width * 0.02), Radius.circular(panel.width * 0.05));
    _fill.color = _pal.curtainShade;
    canvas.drawRRect(board, _fill);
    _stroke
      ..color = _pal.footlight
      ..strokeWidth = 3;
    canvas.drawRRect(board, _stroke);
    _stroke
      ..color = _pal.accent
      ..strokeWidth = 1.5;
    canvas.drawRRect(board.deflate(12), _stroke);
    // Chasing bulbs around the board.
    final r = board.outerRect.deflate(6);
    const pitch = 22.0;
    final nx = (r.width / pitch).floor();
    final ny = (r.height / pitch).floor();
    final chase = (clock.time * 7).floor();
    var idx = 0;
    void bulb(double x, double y) {
      final lit = (idx + chase) % 3 != 0;
      idx++;
      if (lit) {
        _blur.color = _pal.footlight.withValues(alpha: 0.7);
        canvas.drawCircle(Offset(x, y), 6.5, _blur);
      }
      _fill.color = lit ? Color.lerp(_pal.footlight, const Color(0xFFFFFFFF), 0.55)! : Color.lerp(_pal.footlight, ink, 0.6)!;
      canvas.drawCircle(Offset(x, y), 3.6, _fill);
    }

    for (var i = 0; i <= nx; i++) {
      bulb(r.left + r.width * i / nx, r.top);
      bulb(r.right - r.width * i / nx, r.bottom);
    }
    for (var i = 1; i < ny; i++) {
      bulb(r.right, r.top + r.height * i / ny);
      bulb(r.left, r.bottom - r.height * i / ny);
    }
    // Title with a hard drop shadow (the glow painter holds the shadow copy).
    final y = panel.center.dy - _contentHeight / 2;
    _glow.paint(canvas, Offset(panel.center.dx - _glow.width / 2 + 3.5, y + 3.5));
    _paintText(canvas, panel);
  }

  // ---------------------------------------------------------------------------
  // 1980s – OSD / neon.

  Rect _osdRect = Rect.zero;
  ui.Gradient? _osdGlow;
  ui.Gradient? _osdSun;

  void _osd(Canvas canvas, Rect bounds, Rect panel, IntertitleCard card, FilmClock clock, double a, bool rebuild) {
    final ink = _pal.ink;
    _fill
      ..shader = null
      ..color = ink;
    canvas.drawRect(bounds, _fill);
    // Perspective grid to the horizon.
    final horizon = bounds.top + bounds.height * 0.7;
    final sunR = bounds.width * 0.22;
    final sun = Offset(bounds.center.dx, horizon);
    if (bounds != _osdRect) {
      _osdRect = bounds;
      _osdGlow = ui.Gradient.linear(Offset(0, horizon - bounds.height * 0.25), Offset(0, horizon), [
        ink.withValues(alpha: 0),
        _pal.midtone.withValues(alpha: 0.55),
      ]);
      _osdSun = ui.Gradient.linear(sun - Offset(0, sunR), sun, [_pal.footlight, _pal.accent]);
    }
    _fill.shader = _osdGlow;
    canvas.drawRect(Rect.fromLTRB(bounds.left, horizon - bounds.height * 0.25, bounds.right, horizon), _fill);
    _fill.shader = null;
    // Striped sun on the horizon.
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(bounds.left, horizon - sunR, bounds.right, horizon));
    _fill.shader = _osdSun;
    canvas.drawCircle(sun, sunR, _fill);
    _fill.shader = null;
    _fill.color = ink;
    for (var k = 0; k < 6; k++) {
      final y = horizon - sunR * 0.12 - k * sunR * 0.14;
      canvas.drawRect(Rect.fromLTRB(sun.dx - sunR, y, sun.dx + sunR, y + 2 + k * 0.4 * (6 - k) * 0.25), _fill);
    }
    canvas.restore();
    _stroke
      ..color = _pal.accent.withValues(alpha: 0.85)
      ..strokeWidth = 1.2;
    final scroll = (clock.time * 0.6) % 1;
    for (var k = 0; k < 12; k++) {
      final t = (k + scroll) / 12;
      final y = horizon + (bounds.bottom - horizon) * t * t;
      canvas.drawLine(Offset(bounds.left, y), Offset(bounds.right, y), _stroke);
    }
    for (var k = -8; k <= 8; k++) {
      canvas.drawLine(Offset(bounds.center.dx + k * 14, horizon), Offset(bounds.center.dx + k * bounds.width * 0.18, bounds.bottom), _stroke);
    }
    // Neon tube frame around the words.
    final tube = RRect.fromRectAndRadius(
      Rect.fromCenter(center: panel.center, width: panel.width * (0.4 + 0.6 * a), height: _contentHeight + panel.width * 0.2),
      const Radius.circular(18),
    );
    _blur
      ..color = _pal.accent2.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7;
    canvas.drawRRect(tube, _blur);
    _blur.style = PaintingStyle.fill;
    _stroke
      ..color = Color.lerp(_pal.accent2, const Color(0xFFFFFFFF), 0.6)!
      ..strokeWidth = 2.2;
    canvas.drawRRect(tube, _stroke);
    // Deck OSD: a play triangle and a tracking meter, top start corner.
    final m = bounds.width * 0.07;
    final rtl = direction == TextDirection.rtl;
    final x0 = rtl ? bounds.right - m - 26 : bounds.left + m;
    final y0 = bounds.top + bounds.height * 0.08;
    _fill.color = _pal.paper;
    _tri
      ..reset()
      ..moveTo(x0, y0)
      ..lineTo(x0 + 22, y0 + 12)
      ..lineTo(x0, y0 + 24)
      ..close();
    canvas.drawPath(_tri, _fill);
    final mx = rtl ? x0 - 18 - 8 * 9 : x0 + 34;
    for (var k = 0; k < 8; k++) {
      final on = k < 5 + ((clock.time * 3).floor() % 3);
      _fill.color = on ? _pal.paper : _pal.paper.withValues(alpha: 0.25);
      canvas.drawRect(Rect.fromLTWH(mx + k * 9, y0 + 7, 6, 10), _fill);
    }
    _paintText(canvas, panel, glow: true);
  }

  void dispose() {
    _paperPool.dispose();
    _title.dispose();
    _subtitle.dispose();
    _glow.dispose();
  }
}

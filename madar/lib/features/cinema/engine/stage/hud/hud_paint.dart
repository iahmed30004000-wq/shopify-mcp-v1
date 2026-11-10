import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/painting.dart' show TextPainter, TextSpan, TextStyle, TextDirection, Shadow;

import '../../core/era_skin.dart';
import '../../core/stage.dart';
import '../stage_materials.dart';

/// Western → Arabic-Indic digits for Arabic (HUD numbers follow the
/// reading language, ENGINE.md §7).
String hudDigits(String s, String languageCode) {
  if (languageCode != 'ar') return s;
  final b = StringBuffer();
  for (final c in s.codeUnits) {
    b.writeCharCode(c >= 0x30 && c <= 0x39 ? 0x0660 + c - 0x30 : c);
  }
  return b.toString();
}

/// The HUD's text style for [skin] at [size] (the era's title font).
TextStyle hudTextStyle(EraSkin skin, double size, Color color, {bool glow = false, FontWeight? weight}) => TextStyle(
  fontFamily: skin.titles.fontFamily,
  fontWeight: weight ?? skin.titles.weight,
  fontSize: size,
  height: 1.05,
  color: color,
  shadows: glow ? [Shadow(color: color.withValues(alpha: 0.9), blurRadius: size * 0.35)] : null,
);

/// Tabular, rolling digits (an odometer): ten cached glyph painters per
/// style; a changing digit slides up out of its window while the new one
/// slides in from below. Allocation-free after [configure].
class RollingDigits {
  final List<TextPainter> _glyphs = List.generate(10, (_) => TextPainter(textDirection: TextDirection.ltr));
  TextStyle? _style;
  String _lang = '';
  double glyphWidth = 0;
  double glyphHeight = 0;

  void configure(TextStyle style, String languageCode) {
    if (style == _style && languageCode == _lang) return;
    _style = style;
    _lang = languageCode;
    glyphWidth = 0;
    for (var d = 0; d < 10; d++) {
      _glyphs[d]
        ..text = TextSpan(text: hudDigits('$d', languageCode), style: style)
        ..layout();
      glyphWidth = math.max(glyphWidth, _glyphs[d].width);
      glyphHeight = math.max(glyphHeight, _glyphs[d].height);
    }
  }

  static int digitCount(int v) {
    var n = 1;
    var x = v.abs();
    while (x >= 10) {
      x ~/= 10;
      n++;
    }
    return n;
  }

  double widthFor(int digits) => digits * glyphWidth;

  /// Paints [to] (rolling in from [from] by [t] 0..1), right edge at
  /// [right], vertically centred on [centerY]; [digits] columns.
  void paint(Canvas canvas, double right, double centerY, int from, int to, double t, int digits) {
    final h = glyphHeight;
    final top = centerY - h / 2;
    final e = t >= 1 ? 1.0 : 1 - math.pow(1 - t, 3).toDouble();
    var f = from, g = to;
    for (var i = 0; i < digits; i++) {
      final x = right - glyphWidth * (i + 1);
      final fd = (i == 0 || f > 0) ? f % 10 : -1;
      final gd = (i == 0 || g > 0) ? g % 10 : -1;
      f ~/= 10;
      g ~/= 10;
      if (fd == gd || e >= 1) {
        if (gd >= 0) _glyph(canvas, gd, x, top);
        continue;
      }
      canvas
        ..save()
        ..clipRect(Rect.fromLTWH(x - 1, top - 1, glyphWidth + 2, h + 2));
      if (fd >= 0) _glyph(canvas, fd, x, top - h * e);
      if (gd >= 0) _glyph(canvas, gd, x, top + h * (1 - e));
      canvas.restore();
    }
  }

  void _glyph(Canvas canvas, int d, double x, double y) {
    final p = _glyphs[d];
    p.paint(canvas, Offset(x + (glyphWidth - p.width) / 2, y));
  }

  void dispose() {
    for (final g in _glyphs) {
      g.dispose();
    }
  }
}

/// Era plaques behind HUD numbers and labels, by [TitleFrame]:
/// ornate card (1920s), rubber-hose deco plaque with an ink drop shadow
/// (1930s / 1950s), noir label (1940s), marquee letterboard with bulbs
/// (1970s), VHS on-screen-display brackets (1980s).
class HudPlaque {
  final Paint _fill = Paint();
  final Paint _stroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = StrokeCap.round;
  final Path _path = Path();

  /// Text colour on this era's plaque.
  static Color textColor(HudContext ctx) {
    final m = StageMaterials.of(ctx.skin);
    return switch (ctx.skin.titles.frame) {
      TitleFrame.plain => m.paper,
      TitleFrame.osd => m.neonB,
      _ => m.ink,
    };
  }

  /// Whether text on this plaque glows (neon).
  static bool glows(HudContext ctx) => ctx.skin.titles.frame == TitleFrame.osd;

  void paint(Canvas canvas, Rect r, HudContext ctx, {double flash = 0, bool round = false}) {
    final m = StageMaterials.of(ctx.skin);
    final s = ctx.scale;
    final pal = ctx.skin.palette;
    switch (ctx.skin.titles.frame) {
      case TitleFrame.ornate:
        _cutCorners(r, 5 * s, round: round);
        _fill.color = pal.ink.withValues(alpha: 0.6);
        canvas
          ..save()
          ..translate(0, 2.5 * s)
          ..drawPath(_path, _fill)
          ..restore();
        _fill.color = Color.lerp(m.paper, pal.highlight, flash)!;
        canvas.drawPath(_path, _fill);
        _stroke
          ..color = m.ink
          ..strokeWidth = 2 * s;
        canvas.drawPath(_path, _stroke);
        _cutCorners(r.deflate(3.2 * s), 3.5 * s, round: round);
        _stroke.strokeWidth = 0.9 * s;
        canvas.drawPath(_path, _stroke);
      case TitleFrame.artDeco:
        final rr = RRect.fromRectAndRadius(r, Radius.circular(round ? r.shortestSide / 2 : r.height * 0.34));
        _fill.color = m.ink;
        canvas.drawRRect(rr.shift(Offset(0, 3.2 * s)), _fill);
        _fill.color = Color.lerp(m.paper, pal.highlight, flash)!;
        canvas.drawRRect(rr, _fill);
        // A lit band along the top, like a gloss on painted tin.
        _fill.color = pal.highlight.withValues(alpha: 0.55);
        canvas
          ..save()
          ..clipRRect(rr)
          ..drawRect(Rect.fromLTWH(r.left, r.top, r.width, r.height * 0.22), _fill)
          ..restore();
        _stroke
          ..color = m.ink
          ..strokeWidth = 2.6 * s;
        canvas.drawRRect(rr, _stroke);
      case TitleFrame.plain:
        // A brushed-steel nameplate: on the noir set (black on black) it
        // needs a real edge, so a dark drop, a bright bevel and a thin
        // inner rule.
        final rr = RRect.fromRectAndRadius(r, Radius.circular(round ? r.shortestSide / 2 : 3 * s));
        _fill.color = m.wallDark.withValues(alpha: 0.85);
        canvas.drawRRect(rr.shift(Offset(0, 2 * s)), _fill);
        _fill.color = Color.lerp(m.plaque, pal.midtone, flash)!.withValues(alpha: 0.92);
        canvas.drawRRect(rr, _fill);
        _stroke
          ..color = m.giltLight.withValues(alpha: 0.95)
          ..strokeWidth = 1.5 * s;
        canvas.drawRRect(rr, _stroke);
        _stroke
          ..color = m.gilt.withValues(alpha: 0.7)
          ..strokeWidth = 0.8 * s;
        canvas.drawRRect(rr.deflate(3 * s), _stroke);
      case TitleFrame.marquee:
        final rr = RRect.fromRectAndRadius(r, Radius.circular(round ? r.shortestSide / 2 : 4 * s));
        _fill.color = m.ink;
        canvas.drawRRect(rr.shift(Offset(0, 2.5 * s)), _fill);
        _fill.color = Color.lerp(m.plaque, pal.highlight, flash)!;
        canvas.drawRRect(rr, _fill);
        if (!round) {
          // Letterboard slots.
          _stroke
            ..color = m.ink.withValues(alpha: 0.16)
            ..strokeWidth = 0.8 * s;
          for (var y = r.top + 5 * s; y < r.bottom - 3 * s; y += 4.5 * s) {
            canvas.drawLine(Offset(r.left + 4 * s, y), Offset(r.right - 4 * s, y), _stroke);
          }
        }
        _stroke
          ..color = m.giltDark
          ..strokeWidth = 3 * s;
        canvas.drawRRect(rr, _stroke);
        _stroke
          ..color = m.ink
          ..strokeWidth = 1.2 * s;
        canvas.drawRRect(rr.inflate(1.5 * s), _stroke);
      case TitleFrame.osd:
        final rr = RRect.fromRectAndRadius(r, Radius.circular(round ? r.shortestSide / 2 : 2 * s));
        _fill.color = m.plaque.withValues(alpha: 0.55 + 0.3 * flash);
        canvas.drawRRect(rr, _fill);
        // Neon corner brackets.
        final k = math.min(r.height * 0.36, 9 * s);
        _path
          ..reset()
          ..moveTo(r.left, r.top + k)
          ..lineTo(r.left, r.top)
          ..lineTo(r.left + k, r.top)
          ..moveTo(r.right - k, r.top)
          ..lineTo(r.right, r.top)
          ..lineTo(r.right, r.top + k)
          ..moveTo(r.right, r.bottom - k)
          ..lineTo(r.right, r.bottom)
          ..lineTo(r.right - k, r.bottom)
          ..moveTo(r.left + k, r.bottom)
          ..lineTo(r.left, r.bottom)
          ..lineTo(r.left, r.bottom - k);
        _stroke
          ..color = m.neonA.withValues(alpha: 0.35)
          ..strokeWidth = 4.5 * s;
        canvas.drawPath(_path, _stroke);
        _stroke
          ..color = Color.lerp(m.neonA, const Color(0xFFFFFFFF), 0.4)!
          ..strokeWidth = 1.6 * s;
        canvas.drawPath(_path, _stroke);
    }
  }

  void _cutCorners(Rect r, double k, {bool round = false}) {
    _path.reset();
    if (round) {
      _path.addOval(r);
      return;
    }
    _path
      ..moveTo(r.left + k, r.top)
      ..lineTo(r.right - k, r.top)
      ..lineTo(r.right, r.top + k)
      ..lineTo(r.right, r.bottom - k)
      ..lineTo(r.right - k, r.bottom)
      ..lineTo(r.left + k, r.bottom)
      ..lineTo(r.left, r.bottom - k)
      ..lineTo(r.left, r.top + k)
      ..close();
  }
}

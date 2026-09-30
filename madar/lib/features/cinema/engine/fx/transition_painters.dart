import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/painting.dart' show TextPainter, TextSpan, TextStyle, TextDirection, TextAlign;

import '../core/cinema_shaders.dart';
import '../core/era_skin.dart';
import '../core/film_clock.dart';
import '../core/shader_uniforms.dart';

/// The iris wipe (iris.frag) with a plain-Canvas fallback: a mask outside an
/// opening of the era's shape (circle, heart, star, keyhole) around a focus
/// point, with a hand-inked boiling edge, the lens penumbra and a rim of
/// light. [openness] 0 = closed to black, 1 = fully open.
///
/// For CinemaTransitions (stage agent) or any game moment ("iris in on the
/// hero"). One instance per game; allocation-free per frame.
class IrisPainter {
  IrisPainter({required this.skin});

  final EraSkin skin;
  final ShaderPool _pool = ShaderPool(CinemaShader.iris, maxInstances: 2);
  final Paint _paint = Paint();
  final Path _mask = Path()..fillType = PathFillType.evenOdd;

  /// The radius at which [bounds] is fully uncovered around [focus].
  static double openRadius(Rect bounds, Offset focus) {
    final dx = math.max((focus.dx - bounds.left).abs(), (bounds.right - focus.dx).abs());
    final dy = math.max((focus.dy - bounds.top).abs(), (bounds.bottom - focus.dy).abs());
    return math.sqrt(dx * dx + dy * dy) + 48;
  }

  void paint(
    Canvas canvas,
    Rect bounds,
    double openness,
    FilmClock clock, {
    Offset? focus,
    IrisShape? shape,
    Color? color,
    bool boil = true,
  }) {
    final o = openness.clamp(0.0, 1.0);
    if (o >= 1) return;
    final c = focus ?? bounds.center;
    final radius = openRadius(bounds, c) * o;
    final ink = color ?? skin.palette.ink;
    final s = _pool.next(clock);
    if (s != null) {
      IrisUniforms.write(
        s,
        rect: bounds,
        centre: c,
        radius: radius,
        color: ink,
        shape: shape ?? skin.titles.irisShape,
        softness: 1.4,
        wobble: skin.era.isMonochrome ? 2.6 : 1.6,
        boilFrame: boil ? clock.boilFrame : 0,
        rim: 0.45,
      );
      _paint
        ..shader = s
        ..color = const Color(0xFFFFFFFF);
      canvas.drawRect(bounds, _paint);
      return;
    }
    _paint
      ..shader = null
      ..color = ink;
    _mask
      ..reset()
      ..addRect(bounds)
      ..addOval(Rect.fromCircle(center: c, radius: radius));
    canvas.drawPath(_mask, _paint);
  }

  void dispose() => _pool.dispose();
}

/// The film melting in the gate (burn.frag): a blister that runs away into a
/// bubbling hole with a white-hot rim and a brown scorch, showing the
/// projector's light. [progress] 0 = intact, 1 = burnt through. Fallback: a
/// growing disc.
class BurnPainter {
  BurnPainter({required this.skin});

  final EraSkin skin;
  final ShaderPool _pool = ShaderPool(CinemaShader.burn, maxInstances: 2);
  final Paint _paint = Paint();

  void paint(Canvas canvas, Rect bounds, double progress, FilmClock clock, {Offset? origin, Color? hole, double seed = 0}) {
    final p = progress.clamp(0.0, 1.0);
    if (p <= 0) return;
    final o = origin ?? Offset(bounds.left + bounds.width * 0.62, bounds.top + bounds.height * 0.42);
    final holeColour = hole ?? const Color(0xFFFFF8EC);
    final s = _pool.next(clock);
    if (s != null) {
      BurnUniforms.write(
        s,
        rect: bounds,
        progress: p,
        origin: o,
        edgeColor: skin.palette.footlight,
        holeColor: holeColour,
        edgeWidth: 12,
        seed: seed,
      );
      _paint
        ..shader = s
        ..color = const Color(0xFFFFFFFF);
      canvas.drawRect(bounds, _paint);
      return;
    }
    _paint
      ..shader = null
      ..color = holeColour;
    canvas.drawCircle(o, p * p * bounds.longestSide * 1.2, _paint);
  }

  void dispose() => _pool.dispose();
}

/// A projectionist's countdown leader (the classic "8 … 3" before a reel):
/// grey field, double ring and cross-hairs, a sweep wedge running round once
/// per second, and the number. The numeral is passed in already formatted
/// (Arabic-Indic digits in Arabic).
class LeaderPainter {
  LeaderPainter({required this.skin, this.direction = TextDirection.rtl});

  final EraSkin skin;
  final TextDirection direction;
  final Paint _fill = Paint();
  final Paint _stroke = Paint()..style = PaintingStyle.stroke;
  final TextPainter _numeral = TextPainter(textAlign: TextAlign.center);
  final TextPainter _caption = TextPainter(textAlign: TextAlign.center);
  String _laidOut = '';
  double _laidSize = 0;
  String _laidCaption = '';

  /// Paints the leader frame. [sweep] is the fraction of the current second
  /// (0..1); [numeral] the formatted count; [caption] an optional line under
  /// the ring (e.g. `reelCaption(l10n, "١")`).
  void paint(Canvas canvas, Rect bounds, String numeral, double sweep, {String? caption}) {
    final pal = skin.palette;
    final grey = Color.lerp(pal.ink, pal.paper, 0.52)!;
    final dark = Color.lerp(pal.ink, pal.paper, 0.3)!;
    final light = Color.lerp(pal.ink, pal.paper, 0.92)!;
    _fill
      ..shader = null
      ..color = grey;
    canvas.drawRect(bounds, _fill);
    final c = bounds.center;
    final r = bounds.shortestSide * 0.42;
    // The sweep: a darker wedge from twelve o'clock, clockwise.
    _fill.color = dark;
    canvas.drawArc(Rect.fromCircle(center: c, radius: bounds.longestSide), -math.pi / 2, sweep.clamp(0.0, 1.0) * 2 * math.pi, true, _fill);
    // Cross-hairs and rings.
    _stroke
      ..color = light
      ..strokeWidth = 2.2;
    canvas
      ..drawLine(Offset(bounds.left, c.dy), Offset(bounds.right, c.dy), _stroke)
      ..drawLine(Offset(c.dx, bounds.top), Offset(c.dx, bounds.bottom), _stroke)
      ..drawCircle(c, r, _stroke..strokeWidth = 4)
      ..drawCircle(c, r * 0.84, _stroke..strokeWidth = 2);
    // Registration ticks.
    _stroke.strokeWidth = 2;
    for (var i = 0; i < 12; i++) {
      final a = i * math.pi / 6;
      final d = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(c + d * r * 1.04, c + d * r * 1.12, _stroke);
    }
    final size = r * 1.05;
    if (numeral != _laidOut || size != _laidSize) {
      _laidOut = numeral;
      _laidSize = size;
      _numeral
        ..textDirection = direction
        ..text = TextSpan(
          text: numeral,
          style: TextStyle(fontFamily: 'ReemKufi', fontSize: size, fontWeight: FontWeight.w700, color: light, height: 1),
        )
        ..layout();
    }
    _numeral.paint(canvas, c - Offset(_numeral.width / 2, _numeral.height / 2));
    if (caption != null && caption.isNotEmpty) {
      if (caption != _laidCaption) {
        _laidCaption = caption;
        _caption
          ..textDirection = direction
          ..text = TextSpan(
            text: caption,
            style: TextStyle(fontFamily: 'ReemKufi', fontSize: r * 0.2, fontWeight: FontWeight.w600, color: light),
          )
          ..layout();
      }
      _caption.paint(canvas, Offset(c.dx - _caption.width / 2, c.dy + r * 1.22));
    }
  }

  void dispose() {
    _numeral.dispose();
    _caption.dispose();
  }
}

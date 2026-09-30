import 'dart:math' as math;
import 'package:flutter/animation.dart' show Curves;
import 'package:flutter/painting.dart';

import '../core/cinema_env.dart';
import '../core/cinema_shaders.dart';
import '../core/film_clock.dart';
import '../core/shader_uniforms.dart';
import '../core/stage.dart';
import '../core/tween.dart';

/// Minimal [CinemaTransitions]: iris in/out (iris.frag, era iris shape) and
/// intertitle cards on aged paper (paper.frag) with a double ink border.
/// Placeholder – the stage agent replaces it (burn / wipe / glitch styles,
/// animated ornaments, typewriter reveals…).
class PlaceholderTransitions implements CinemaTransitions {
  PlaceholderTransitions(this.env);

  final CinemaEnv env;

  final CinemaTween _cover = CinemaTween(0);
  final CinemaTween _card = CinemaTween(0);
  final CinemaDelay _hold = CinemaDelay();
  IntertitleCard? _current;
  Offset? _focus;
  Size _screen = Size.zero;
  Rect _play = Rect.zero;
  FilmClock? _clock;

  final ShaderPool _iris = ShaderPool(CinemaShader.iris, maxInstances: 1);
  final ShaderPool _paper = ShaderPool(CinemaShader.paper, maxInstances: 1);
  final Paint _paint = Paint();
  final Paint _stroke = Paint()..style = PaintingStyle.stroke;
  final Paint _layer = Paint();
  final Path _mask = Path()..fillType = PathFillType.evenOdd;
  final TextPainter _title = TextPainter(textAlign: TextAlign.center);
  final TextPainter _subtitle = TextPainter(textAlign: TextAlign.center);
  IntertitleCard? _laidOut;
  double _laidOutWidth = 0;

  @override
  bool get isActive => _cover.isActive || _current != null;

  @override
  double get coverage => math.max(_cover.value, _card.value);

  @override
  void layout(Size screen, Rect playRect) {
    _screen = screen;
    _play = playRect;
  }

  Offset get _centre => _focus ?? (_play.isEmpty ? _screen.center(Offset.zero) : _play.center);

  @override
  Future<void> irisIn({Offset? focus, Duration? duration}) {
    _focus = focus;
    if (_cover.value < 1 && !_cover.isActive) _cover.jumpTo(1);
    return _cover.animateTo(0, duration ?? const Duration(milliseconds: 950), curve: Curves.easeInOutCubic);
  }

  @override
  Future<void> irisOut({Offset? focus, Duration? duration}) {
    _focus = focus;
    return _cover.animateTo(1, duration ?? const Duration(milliseconds: 850), curve: Curves.easeInCubic);
  }

  @override
  Future<void> intertitle(IntertitleCard card, {Duration? hold}) async {
    _current = card;
    final read = hold ?? Duration(milliseconds: (1400 + (card.text.length + (card.subtitle?.length ?? 0)) * 55).clamp(1400, 4200));
    await _card.animateTo(1, const Duration(milliseconds: 280), curve: Curves.easeOut);
    if (!identical(_current, card)) return;
    await _hold.start(read);
    if (!identical(_current, card)) return;
    await _card.animateTo(0, const Duration(milliseconds: 280), curve: Curves.easeIn);
    if (identical(_current, card)) _current = null;
  }

  @override
  void cover() => _cover.jumpTo(1);

  @override
  void clear() {
    _cover.jumpTo(0);
    _card.jumpTo(0);
    _hold.cancel();
    _current = null;
  }

  @override
  void update(double dt, FilmClock clock) {
    _clock = clock;
    _cover.update(dt);
    _card.update(dt);
    _hold.update(dt);
  }

  @override
  void paint(Canvas canvas) {
    final clock = _clock;
    if (clock == null || _screen.isEmpty) return;
    final pal = env.skin.palette;
    final full = Offset.zero & _screen;
    final cover = _cover.value;
    if (cover > 0.001) {
      final c = _centre;
      final far = [full.topLeft, full.topRight, full.bottomLeft, full.bottomRight]
          .map((p) => (p - c).distance)
          .reduce(math.max);
      final radius = (1 - cover) * (far + 40);
      final s = _iris.next(clock);
      if (s != null) {
        IrisUniforms.write(
          s,
          rect: full,
          centre: c,
          radius: radius,
          color: pal.ink,
          shape: env.skin.titles.irisShape,
          softness: 1.5,
          wobble: 2.5,
          boilFrame: clock.boilFrame,
        );
        _paint
          ..shader = s
          ..color = const Color(0xFFFFFFFF);
      } else {
        _paint
          ..shader = null
          ..color = pal.ink;
      }
      if (s != null) {
        canvas.drawRect(full, _paint);
      } else {
        _mask
          ..reset()
          ..addRect(full)
          ..addOval(Rect.fromCircle(center: c, radius: radius));
        canvas.drawPath(_mask, _paint);
      }
    }
    final card = _current;
    final a = _card.value;
    if (card != null && a > 0.001) _paintCard(canvas, clock, card, a);
  }

  void _paintCard(Canvas canvas, FilmClock clock, IntertitleCard card, double a) {
    final pal = env.skin.palette;
    final titles = env.skin.titles;
    final full = Offset.zero & _screen;
    _paint
      ..shader = null
      ..color = pal.ink.withValues(alpha: a);
    canvas.drawRect(full, _paint);

    final w = _screen.width * 0.84;
    if (!identical(card, _laidOut) || w != _laidOutWidth) {
      _laidOut = card;
      _laidOutWidth = w;
      _title
        ..textDirection = env.direction
        ..text = TextSpan(
          text: card.text,
          style: TextStyle(
            fontFamily: titles.fontFamily,
            fontWeight: titles.weight,
            fontSize: _screen.width * 0.085,
            height: 1.35,
            letterSpacing: titles.letterSpacing,
            color: pal.ink,
          ),
        )
        ..layout(maxWidth: w - 56);
      _subtitle
        ..textDirection = env.direction
        ..text = TextSpan(
          text: card.subtitle ?? '',
          style: TextStyle(
            fontFamily: titles.fontFamily,
            fontSize: _screen.width * 0.045,
            height: 1.4,
            color: pal.shadow,
          ),
        )
        ..layout(maxWidth: w - 56);
    }
    final h = _title.height + (card.subtitle == null ? 0 : _subtitle.height + 18) + 84;
    final rect = Rect.fromCenter(center: full.center, width: w, height: h);
    canvas
      ..save()
      ..translate(rect.center.dx, rect.center.dy)
      ..scale(0.94 + 0.06 * a)
      ..translate(-rect.center.dx, -rect.center.dy);
    // Fade the whole card (text included) only while fading.
    final fading = a < 0.999;
    if (fading) canvas.saveLayer(rect.inflate(4), _layer..color = Color.fromRGBO(0, 0, 0, a));
    final paper = _paper.next(clock);
    if (paper != null) {
      PaperUniforms.write(paper, rect: rect, paper: pal.paper, stain: pal.shadow, age: 0.6, seed: 3);
      _paint
        ..shader = paper
        ..color = const Color(0xFFFFFFFF);
    } else {
      _paint
        ..shader = null
        ..color = pal.paper;
    }
    canvas.drawRect(rect, _paint);
    _stroke
      ..color = pal.ink
      ..strokeWidth = 3;
    canvas.drawRect(rect.deflate(10), _stroke);
    _stroke.strokeWidth = 1.2;
    canvas.drawRect(rect.deflate(16), _stroke);
    _paint
      ..shader = null
      ..color = pal.ink;
    for (final corner in [rect.deflate(10).topLeft, rect.deflate(10).topRight, rect.deflate(10).bottomLeft, rect.deflate(10).bottomRight]) {
      canvas
        ..save()
        ..translate(corner.dx, corner.dy)
        ..rotate(math.pi / 4)
        ..drawRect(const Rect.fromLTWH(-5, -5, 10, 10), _paint)
        ..restore();
    }
    var y = rect.top + 42;
    _title.paint(canvas, Offset(rect.center.dx - _title.width / 2, y));
    y += _title.height + 18;
    if (card.subtitle != null) _subtitle.paint(canvas, Offset(rect.center.dx - _subtitle.width / 2, y));
    if (fading) canvas.restore();
    canvas.restore();
  }

  @override
  void dispose() {
    clear();
    _iris.dispose();
    _paper.dispose();
    _title.dispose();
    _subtitle.dispose();
  }
}

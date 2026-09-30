import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/animation.dart' show Curves;

import '../core/cinema_env.dart';
import '../core/era_skin.dart';
import '../core/film_clock.dart';
import '../core/stage.dart';
import '../core/tween.dart';
import '../fx/intertitle_painter.dart';
import '../fx/transition_painters.dart';

/// Scene transitions in the era's style (createTransitions):
///
/// * **iris** (1920s–50s): the lens closes / opens in the era's iris shape
///   (circle, keyhole, star …) with an inked, boiling edge – iris.frag via
///   the FX agent's [IrisPainter].
/// * **burn** (1970s): closing, the print blisters and burns through in the
///   gate to black (burn.frag via [BurnPainter]); opening, the projector
///   lamp flares up on a new reel and the iris opens.
/// * **glitch** (1980s): tape tracking noise tears across the picture band
///   by band to black, and back, with a VCR ▶ in the corner.
/// * **wipe** (spare): a clock wipe.
///
/// Intertitle cards are the FX agent's [IntertitlePainter] (ornaments draw
/// in, then the card holds for the reading time and fades). Everything runs
/// on game time and is painted under the film grade.
class ReelTransitions implements CinemaTransitions {
  ReelTransitions(this.env)
    : _iris = IrisPainter(skin: env.skin),
      _burn = BurnPainter(skin: env.skin),
      _cards = IntertitlePainter(skin: env.skin, direction: env.direction, boil: !env.reducedMotion);

  final CinemaEnv env;
  final IrisPainter _iris;
  final BurnPainter _burn;
  final IntertitlePainter _cards;

  EraSkin get skin => env.skin;
  EraTransition get style => skin.titles.transition;

  final CinemaTween _cover = CinemaTween(0);
  final CinemaTween _card = CinemaTween(0);
  final CinemaTween _ornaments = CinemaTween(0);
  final CinemaDelay _hold = CinemaDelay();
  IntertitleCard? _current;
  bool _closing = false;
  Offset? _focus;
  Size _screen = Size.zero;
  Rect _play = Rect.zero;
  FilmClock? _clock;
  double _flash = 0;
  final Paint _paint = Paint();
  final Path _path = Path();

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
    _closing = false;
    if (_cover.value < 1 && !_cover.isActive) _cover.jumpTo(1);
    if (style == EraTransition.burn && !env.reducedMotion) _flash = 1;
    final d = duration ??
        switch (style) {
          EraTransition.glitch => const Duration(milliseconds: 750),
          _ => const Duration(milliseconds: 1000),
        };
    return _cover.animateTo(0, d, curve: style == EraTransition.glitch ? Curves.linear : Curves.easeInOutCubic);
  }

  @override
  Future<void> irisOut({Offset? focus, Duration? duration}) {
    _focus = focus;
    _closing = true;
    final d = duration ??
        switch (style) {
          EraTransition.burn => const Duration(milliseconds: 1300),
          EraTransition.glitch => const Duration(milliseconds: 700),
          _ => const Duration(milliseconds: 900),
        };
    return _cover.animateTo(1, d, curve: style == EraTransition.burn ? Curves.easeIn : Curves.easeInCubic);
  }

  @override
  Future<void> intertitle(IntertitleCard card, {Duration? hold}) async {
    _current = card;
    final chars = card.text.length + (card.subtitle?.length ?? 0);
    final read = hold ?? Duration(milliseconds: (1500 + chars * 55).clamp(1500, 4200));
    _ornaments.jumpTo(0);
    final appear = _card.animateTo(1, const Duration(milliseconds: 260), curve: Curves.easeOut);
    unawaited(_ornaments.animateTo(1, const Duration(milliseconds: 700), curve: Curves.easeOutCubic));
    await appear;
    if (!identical(_current, card)) return;
    await _hold.start(read);
    if (!identical(_current, card)) return;
    await _card.animateTo(0, const Duration(milliseconds: 300), curve: Curves.easeIn);
    if (identical(_current, card)) _current = null;
  }

  @override
  void cover() => _cover.jumpTo(1);

  @override
  void clear() {
    _cover.jumpTo(0);
    _card.jumpTo(0);
    _ornaments.jumpTo(0);
    _hold.cancel();
    _current = null;
    _flash = 0;
  }

  @override
  void update(double dt, FilmClock clock) {
    _clock = clock;
    _cover.update(dt);
    _card.update(dt);
    _ornaments.update(dt);
    _hold.update(dt);
    _flash = math.max(0, _flash - dt * 2.2);
  }

  @override
  void paint(Canvas canvas) {
    final clock = _clock;
    if (clock == null || _screen.isEmpty) return;
    final full = Offset.zero & _screen;
    final cover = _cover.value;
    if (cover > 0.001) {
      switch (style) {
        case EraTransition.iris:
          _iris.paint(canvas, full, 1 - cover, clock, focus: _centre, boil: !env.reducedMotion);
        case EraTransition.burn:
          if (_closing) {
            _burn.paint(canvas, full, cover, clock, origin: _centre, hole: skin.palette.ink, seed: 3);
          } else {
            _iris.paint(canvas, full, 1 - cover, clock, focus: _centre, shape: IrisShape.circle, boil: !env.reducedMotion);
          }
        case EraTransition.glitch:
          _glitch(canvas, full, cover, clock);
        case EraTransition.wipe:
          _wipe(canvas, full, cover);
      }
    }
    if (_flash > 0.01) {
      // The lamp flaring up on a fresh reel.
      _paint
        ..shader = null
        ..color = skin.palette.footlight.withValues(alpha: 0.55 * _flash * _flash);
      canvas.drawRect(full, _paint);
    }
    final card = _current;
    final a = _card.value;
    if (card != null && a > 0.001) {
      _cards.paint(canvas, full, card, clock, appear: _ornaments.value, opacity: a);
    }
  }

  /// Tracking noise tearing across the picture in bands.
  void _glitch(Canvas canvas, Rect full, double cover, FilmClock clock) {
    final ink = skin.palette.ink;
    if (env.reducedMotion) {
      _paint
        ..shader = null
        ..color = ink.withValues(alpha: cover);
      canvas.drawRect(full, _paint);
      return;
    }
    const bands = 22;
    final bh = full.height / bands;
    final t = clock.time;
    final frame = (t * 30).floor();
    for (var i = 0; i < bands; i++) {
      // Each band tears at its own moment; the middle goes first.
      final order = (_h(i * 1.93) * 0.55 + (i - bands / 2).abs() / bands * 0.45);
      final local = ((cover - order * 0.6) / 0.4).clamp(0.0, 1.0);
      if (local <= 0) continue;
      final y = full.top + bh * i;
      final shift = (1 - local) * (_h(i + frame * 0.37) - 0.5) * full.width * 0.3;
      final band = Rect.fromLTWH(full.left, y, full.width, bh + 0.5);
      if (local >= 1) {
        _paint.color = ink;
        canvas.drawRect(band, _paint);
        continue;
      }
      // Torn band: black body sliding in, chroma fringes and snow.
      _paint.color = ink.withValues(alpha: 0.35 + 0.65 * local);
      canvas.drawRect(band.shift(Offset(shift, 0)), _paint);
      _paint.color = const Color(0xFFFF2E97).withValues(alpha: 0.5 * (1 - local));
      canvas.drawRect(Rect.fromLTWH(band.left + shift - 6, y, 6, bh), _paint);
      _paint.color = const Color(0xFF19E3FF).withValues(alpha: 0.5 * (1 - local));
      canvas.drawRect(Rect.fromLTWH(band.right + shift, y, 6, bh), _paint);
      _paint.color = skin.palette.paper.withValues(alpha: 0.55 * (1 - local));
      for (var k = 0; k < 6; k++) {
        final sx = full.left + full.width * _h(i * 7.1 + k * 3.3 + frame * 0.71);
        final sw = 4 + 30 * _h(k * 2.2 + frame * 0.13 + i);
        canvas.drawRect(Rect.fromLTWH(sx, y + bh * _h(k + i * 0.5 + frame * 0.3), sw, 1.5), _paint);
      }
    }
    if (!_closing && cover > 0.05) {
      // The deck's ▶ in the top corner while the picture comes back.
      final c = Offset(full.right - 40, full.top + 60);
      _path
        ..reset()
        ..moveTo(c.dx - 7, c.dy - 9)
        ..lineTo(c.dx + 9, c.dy)
        ..lineTo(c.dx - 7, c.dy + 9)
        ..close();
      _paint.color = skin.palette.paper.withValues(alpha: 0.9);
      canvas.drawPath(_path, _paint);
    }
  }

  /// A clock wipe around the focus.
  void _wipe(Canvas canvas, Rect full, double cover) {
    final c = _centre;
    final r = IrisPainter.openRadius(full, c);
    _path
      ..reset()
      ..moveTo(c.dx, c.dy)
      ..arcTo(Rect.fromCircle(center: c, radius: r), -math.pi / 2, math.pi * 2 * cover, false)
      ..close();
    _paint
      ..shader = null
      ..color = skin.palette.ink;
    if (cover >= 0.999) {
      canvas.drawRect(full, _paint);
    } else {
      canvas
        ..save()
        ..clipRect(full)
        ..drawPath(_path, _paint)
        ..restore();
    }
  }

  static double _h(double x) {
    final s = math.sin(x * 12.9898 + 78.233) * 43758.5453;
    return s - s.floorToDouble();
  }

  @override
  void dispose() {
    clear();
    _iris.dispose();
    _burn.dispose();
    _cards.dispose();
  }
}

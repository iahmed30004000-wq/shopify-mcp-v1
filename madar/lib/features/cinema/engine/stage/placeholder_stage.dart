import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/animation.dart' show Curves;
import 'package:flutter/painting.dart' show EdgeInsets;

import '../core/cinema_env.dart';
import '../core/cinema_shaders.dart';
import '../core/era_skin.dart';
import '../core/film_clock.dart';
import '../core/shader_uniforms.dart';
import '../core/stage.dart';
import '../core/tween.dart';

/// Minimal [StageFrame]: velvet side curtains and a scalloped valance
/// (curtain.frag), a gilt proscenium line, a footlight lip with glowing
/// bulbs, an optional follow-spot (spotlight.frag). Placeholder – the stage
/// agent replaces it (and may delete this file).
class PlaceholderStage implements StageFrame {
  PlaceholderStage(this.env);

  final CinemaEnv env;
  EraSkin get skin => env.skin;
  StageStyle get style => skin.stage;

  Size _screen = Size.zero;
  Rect _play = Rect.zero;
  Rect _hud = Rect.zero;
  double _side = 0, _valance = 0, _foot = 0;
  final CinemaTween _open = CinemaTween(0);
  double _pulse = 0;
  Offset? _spot;
  FilmClock? _clock;

  final ShaderPool _curtains = ShaderPool(CinemaShader.curtain, maxInstances: 4);
  final ShaderPool _spots = ShaderPool(CinemaShader.spotlight, maxInstances: 1);
  final Paint _paint = Paint();
  final Paint _glow = Paint();
  final Paint _stroke = Paint()..style = PaintingStyle.stroke;
  final List<Shader> _bulbGlows = [];
  final List<Offset> _bulbs = [];
  Shader? _lipShader;
  Shader? _washShader;

  @override
  Rect get playRect => _play;

  @override
  Rect get hudRect => _hud;

  @override
  double get curtainOpen => _open.value;

  @override
  void layout(Size screen, EdgeInsets safe) {
    _screen = screen;
    final w = screen.width, h = screen.height;
    _side = w * style.sideWidth;
    _valance = h * style.valanceHeight;
    _foot = h * style.footlightHeight;
    _play = Rect.fromLTRB(_side * 0.72, _valance * 0.78, w - _side * 0.72, h - _foot);
    _hud = Rect.fromLTRB(
      math.max(_play.left + 10, safe.left + 10),
      math.max(_valance + 6, safe.top + 8),
      math.min(_play.right - 10, w - safe.right - 10),
      math.min(_play.bottom - 10, h - safe.bottom - _foot - 6),
    );
    // Footlight bulbs and their glows are laid out once per resize (shaders
    // cached – flicker only changes the paint alpha).
    _bulbs.clear();
    _bulbGlows.clear();
    final n = math.max(3, style.footlights);
    final lipTop = h - _foot;
    final glowColor = skin.palette.footlight;
    for (var i = 0; i < n; i++) {
      final x = w * (i + 0.5) / n;
      final c = Offset(x, lipTop + _foot * 0.28);
      _bulbs.add(c);
      _bulbGlows.add(
        Gradient.radial(c, _foot * 1.6, [glowColor.withValues(alpha: 0.55), glowColor.withValues(alpha: 0)]),
      );
    }
    _lipShader = Gradient.linear(Offset(0, lipTop), Offset(0, h), [
      Color.lerp(skin.palette.curtainShade, skin.palette.shadow, 0.35)!,
      skin.palette.curtainShade,
    ]);
    _washShader = Gradient.linear(Offset(0, lipTop), Offset(0, lipTop - h * 0.22), [
      glowColor.withValues(alpha: 0.22),
      glowColor.withValues(alpha: 0),
    ]);
  }

  @override
  Future<void> openCurtains({Duration? duration}) =>
      _open.animateTo(1, duration ?? const Duration(milliseconds: 1400), curve: Curves.easeInOutCubic);

  @override
  Future<void> closeCurtains({Duration? duration}) =>
      _open.animateTo(0, duration ?? const Duration(milliseconds: 1100), curve: Curves.easeInOutCubic);

  @override
  void spotlight(Offset? target) => _spot = style.spotlight ? target : null;

  @override
  void pulse(double amount) => _pulse = math.max(_pulse, amount.clamp(0.0, 1.0));

  @override
  void update(double dt, FilmClock clock) {
    _clock = clock;
    _open.update(dt);
    _pulse *= math.exp(-dt * 4);
  }

  @override
  void paintBack(Canvas canvas) {
    _paint
      ..shader = null
      ..color = skin.palette.curtainShade;
    canvas.drawRect(Offset.zero & _screen, _paint);
  }

  @override
  void paintFront(Canvas canvas) {
    final clock = _clock;
    if (clock == null || _screen.isEmpty) return;
    final w = _screen.width, h = _screen.height;
    final pal = skin.palette;

    // Footlight wash on the stage floor (under the curtains).
    _paint
      ..shader = _washShader
      ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.6 + 0.4 * _pulse);
    canvas.drawRect(Rect.fromLTRB(0, h - _foot - h * 0.22, w, h - _foot), _paint);

    // Follow-spot.
    final spot = _spot;
    if (spot != null) {
      final s = _spots.next(clock);
      if (s != null) {
        SpotlightUniforms.write(
          s,
          rect: _play,
          source: Offset(w * 0.5, -h * 0.1),
          target: spot,
          color: pal.footlight,
          time: clock.time,
        );
        _paint
          ..shader = s
          ..color = const Color(0xFFFFFFFF)
          ..blendMode = BlendMode.plus;
        canvas.drawRect(_play, _paint);
        _paint.blendMode = BlendMode.srcOver;
      }
    }

    // Side curtains: tied back when open, meeting in the middle when closed.
    final open = _open.value;
    final panel = _side + (w / 2 + 2 - _side) * (1 - open);
    final curtainBottom = h - _foot * 0.35;
    final folds = math.max(2, (style.curtainFolds * (0.45 + 0.55 * panel / (w / 2))).round());
    _curtain(canvas, clock, Rect.fromLTWH(0, 0, panel, curtainBottom), CurtainPanel.left, folds, open);
    _curtain(canvas, clock, Rect.fromLTWH(w - panel, 0, panel, curtainBottom), CurtainPanel.right, folds, open);

    // Gilt proscenium line around the opening.
    final gilt = Color.lerp(pal.footlight, pal.highlight, 0.2)!;
    _stroke
      ..shader = null
      ..color = gilt.withValues(alpha: 0.85)
      ..strokeWidth = 2.2;
    final frame = Rect.fromLTRB(_side * 0.55, _valance * 0.6, w - _side * 0.55, h - _foot + 1);
    canvas.drawRRect(RRect.fromRectAndRadius(frame, const Radius.circular(10)), _stroke);
    _stroke
      ..color = pal.ink.withValues(alpha: 0.7)
      ..strokeWidth = 1.2;
    canvas.drawRRect(RRect.fromRectAndRadius(frame.deflate(4), const Radius.circular(8)), _stroke);

    // Valance.
    _curtain(canvas, clock, Rect.fromLTWH(0, 0, w, _valance), CurtainPanel.valance, 7, open);

    // Footlight lip and bulbs.
    _paint
      ..shader = _lipShader
      ..color = const Color(0xFFFFFFFF);
    canvas.drawRect(Rect.fromLTRB(0, h - _foot, w, h), _paint);
    _stroke
      ..color = gilt
      ..strokeWidth = 2;
    canvas.drawLine(Offset(0, h - _foot), Offset(w, h - _foot), _stroke);
    for (var i = 0; i < _bulbs.length; i++) {
      final flick = 1 - style.footlightFlicker * 0.5 * (0.5 + 0.5 * math.sin(clock.time * 9 + i * 2.3) * math.sin(clock.time * 3.1 + i));
      _glow
        ..shader = _bulbGlows[i]
        ..color = const Color(0xFFFFFFFF).withValues(alpha: (flick * (0.75 + 0.25 * _pulse)).clamp(0.0, 1.0));
      canvas.drawCircle(_bulbs[i], _foot * 1.6, _glow);
      _paint
        ..shader = null
        ..color = Color.lerp(pal.footlight, pal.highlight, 0.5)!;
      canvas.drawCircle(_bulbs[i], _foot * 0.12, _paint);
      _paint.color = pal.ink;
      canvas.drawRect(
        Rect.fromCenter(center: _bulbs[i] + Offset(0, _foot * 0.2), width: _foot * 0.5, height: _foot * 0.18),
        _paint,
      );
    }
  }

  void _curtain(Canvas canvas, FilmClock clock, Rect rect, CurtainPanel panel, int folds, double open) {
    final s = _curtains.next(clock);
    if (s != null) {
      CurtainUniforms.write(
        s,
        rect: rect,
        palette: skin.palette,
        panel: panel,
        clock: clock,
        folds: folds,
        swayPhase: clock.time * 0.9,
        gather: panel == CurtainPanel.valance ? 0 : open,
        sheen: 0.55,
        footlight: 0.5 + 0.4 * _pulse,
      );
      _paint
        ..shader = s
        ..color = const Color(0xFFFFFFFF);
    } else {
      _paint
        ..shader = null
        ..color = skin.palette.curtain;
    }
    canvas.drawRect(rect, _paint);
  }

  @override
  void dispose() {
    _curtains.dispose();
    _spots.dispose();
  }
}

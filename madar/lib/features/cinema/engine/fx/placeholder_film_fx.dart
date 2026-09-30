import 'dart:ui' as ui;

import '../core/cinema_env.dart';
import '../core/cinema_shaders.dart';
import '../core/era_skin.dart';
import '../core/film_clock.dart';
import '../core/film_fx.dart';
import '../core/shader_uniforms.dart';

/// Minimal [FilmFx]: one pass of the era's grade shader with the skin's
/// values; plain blit when the program is missing. Placeholder – the FX
/// agent replaces it (and may delete this file).
class PlaceholderFilmFx implements FilmFx {
  PlaceholderFilmFx(this.env);

  final CinemaEnv env;

  @override
  EraSkin get skin => env.skin;

  ui.FragmentShader? _shader;
  final ui.Paint _paint = ui.Paint();
  final ui.Paint _blit = ui.Paint()..filterQuality = ui.FilterQuality.low;
  late FilmGrade _grade = skin.grade;
  double _gradeIntensity = 1;
  bool _gradeReduced = false;

  @override
  double resolutionScale = 1;

  bool get _vhs => skin.grade.process == FilmProcess.vhs;

  @override
  bool get isReady => true;

  @override
  Future<void> load() async {
    await CinemaShaders.preload();
    _shader = CinemaShaders.program(_vhs ? CinemaShader.vhs : CinemaShader.filmGrade)?.fragmentShader();
  }

  @override
  void update(double dt, FilmClock clock) {}

  @override
  void apply(ui.Canvas canvas, ui.Image frame, ui.Rect dst, FilmClock clock, FilmFrame params) {
    final s = _shader;
    if (s == null) {
      canvas.drawImageRect(
        frame,
        ui.Rect.fromLTWH(0, 0, frame.width.toDouble(), frame.height.toDouble()),
        dst,
        _blit,
      );
      return;
    }
    if (params.intensity != _gradeIntensity || params.reduceFlicker != _gradeReduced) {
      _gradeIntensity = params.intensity;
      _gradeReduced = params.reduceFlicker;
      _grade = skin.grade.scaled(params.intensity * (params.reduceFlicker ? 0.5 : 1));
    }
    if (_vhs) {
      VhsUniforms.write(s, rect: dst, image: frame, clock: clock, grade: _grade, frame: params);
    } else {
      FilmGradeUniforms.write(
        s,
        rect: dst,
        image: frame,
        clock: clock,
        palette: skin.palette,
        grade: _grade,
        frame: params,
      );
    }
    _paint.shader = s;
    canvas.drawRect(dst, _paint);
  }

  @override
  void dispose() {
    _shader?.dispose();
    _shader = null;
  }
}

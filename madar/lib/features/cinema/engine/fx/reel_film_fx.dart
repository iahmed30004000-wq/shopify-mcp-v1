import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import '../core/cinema_env.dart';
import '../core/cinema_shaders.dart';
import '../core/era_skin.dart';
import '../core/film_clock.dart';
import '../core/film_fx.dart';
import '../core/shader_uniforms.dart';
import 'era_looks.dart';
import 'film_events.dart';
import 'film_look.dart';
import 'film_settings.dart';
import 'film_stock_shader.dart';

/// The Film Reel Engine's real [FilmFx]: one full-frame pass per frame that
/// turns the rendered scene into a print of its era.
///
/// * 1920s–1970s: `film_stock.frag` – the core [FilmGrade] plus the era's
///   [FilmLook] (halftone screen, pen hatching, venetian blinds, three-strip
///   or faded dyes, bloom, soft focus, aperture) and [FilmEvents] (splices,
///   frame slips, blotches, hairs, cue marks). Falls back to
///   `film_grade.frag`, then to a plain blit, if a program is missing.
/// * 1980s: `vhs.frag` (chroma bleed, scanlines, tracking, dropouts).
///
/// Tuning (all optional, live):
/// * [strength] – the FX's own intensity knob (0 = clean print, 1 = full
///   era look), multiplied with `FilmFrame.intensity` from gameplay. Colour
///   grading always stays; wear and stylisation scale.
/// * [quality] – [FilmQuality] (resolution and shader cost); [adaptive]
///   steps it down when frames run long (on by default in profile/release).
/// * [look] – the era's [FilmLook] (swap for a per-game variant).
/// * Reduced motion (`FilmFrame.reduceFlicker`, from `CinemaEnv`): no
///   exposure flicker, weave and shake at a quarter, no line boil, no
///   frame slips or blotches, flashes capped, damage halved.
class ReelFilmFx implements FilmFx {
  ReelFilmFx(
    this.env, {
    FilmLook? look,
    FilmQuality quality = FilmQuality.balanced,
    this.strength = 1,
    bool? adaptive,
  }) : look = look ?? eraLook(env.era),
       // ignore: prefer_initializing_formals (a public named parameter)
       _quality = quality,
       adaptive = adaptive ?? (kReleaseMode || kProfileMode),
       events = FilmEvents(seed: env.seed);

  /// A FilmFx at the player's [settings] (see `createFilmFx`).
  factory ReelFilmFx.fromSettings(CinemaEnv env, FilmSettings settings, {FilmLook? look}) => ReelFilmFx(
    env,
    look: look,
    quality: settings.effectiveQuality,
    strength: settings.strength.clamp(0.0, 1.0),
    adaptive: settings.adaptive,
  );

  final CinemaEnv env;

  @override
  EraSkin get skin => env.skin;

  /// Print stylisation and reel events of this show.
  FilmLook look;

  /// FX intensity, 0..1 (see class doc).
  double strength;

  /// Steps [quality] down by itself when frames run long.
  bool adaptive;

  /// Reel events (splices, cue marks…); games may force some
  /// (`events.cueNow()`, `events.spliceNow()`).
  final FilmEvents events;

  FilmQuality _quality;
  double? _resolutionOverride;

  FilmQuality get quality => _quality;
  set quality(FilmQuality value) {
    _quality = value;
    _resolutionOverride = null;
  }

  @override
  double get resolutionScale => _resolutionOverride ?? _quality.resolutionScale;

  @override
  set resolutionScale(double value) => _resolutionOverride = value.clamp(0.25, 1.0);

  bool get isVideo => skin.grade.process == FilmProcess.vhs;

  ui.FragmentShader? _stock;
  ui.FragmentShader? _grade;
  ui.FragmentShader? _vhs;
  final ui.Paint _paint = ui.Paint();
  final ui.Paint _blit = ui.Paint()..filterQuality = ui.FilterQuality.low;
  final FilmMix _mix = FilmMix();

  // Last FilmFrame values seen by apply (update does not receive them).
  double _damage = 0;
  double _wear = 1;
  bool _reduced = false;

  // Adaptive LOD.
  double _slowTime = 0;
  double _cooldown = 3;

  /// Which pass [apply] used last (tests, debug overlays).
  FilmPass get lastPass => _lastPass;
  FilmPass _lastPass = FilmPass.none;

  /// True once [load] found a program for this era's pass (film_stock or
  /// film_grade for film, vhs for tape). Until then – or if every program
  /// failed – CinemaGame draws the scene ungraded, without the offscreen
  /// image (cheaper than grading through a plain blit).
  @override
  bool get isReady => isVideo ? _vhs != null : (_stock != null || _grade != null);

  @override
  Future<void> load() async {
    await CinemaShaders.preload();
    await FxShaders.preload();
    // Idempotent: a second load keeps the instances it already has.
    _vhs ??= CinemaShaders.program(CinemaShader.vhs)?.fragmentShader();
    _grade ??= CinemaShaders.program(CinemaShader.filmGrade)?.fragmentShader();
    _stock ??= FxShaders.program(FxShader.filmStock)?.fragmentShader();
  }

  @override
  void update(double dt, FilmClock clock) {
    events.advance(clock, look, wear: _wear, damage: _damage, reducedMotion: _reduced);
    if (adaptive) _adapt(dt);
  }

  void _adapt(double dt) {
    if (_cooldown > 0) {
      _cooldown -= dt;
      return;
    }
    // Frames longer than ~48 fps for 1.5 s of game time → one step cheaper.
    _slowTime = dt > 1 / 48 ? _slowTime + dt : math.max(0, _slowTime - dt * 0.5);
    if (_slowTime > 1.5 && _quality != FilmQuality.lowPower && _resolutionOverride == null) {
      _quality = _quality.cheaper;
      _slowTime = 0;
      _cooldown = 4;
    }
  }

  @override
  void apply(ui.Canvas canvas, ui.Image frame, ui.Rect dst, FilmClock clock, FilmFrame params) {
    final amount = (params.intensity * strength).clamp(0.0, 1.0);
    _reduced = params.reduceFlicker;
    _damage = params.damage;
    _wear = amount * (_reduced ? 0.5 : 1);
    _mix
      ..wear = _wear
      ..style = amount
      ..flicker = _reduced ? 0 : 1
      ..motion = _reduced ? 0.25 : 1
      ..boil = _reduced ? 0 : 1
      ..quality = _quality.shaderLevel;

    final grade = skin.grade;
    if (isVideo) {
      final s = _vhs;
      if (s != null) {
        VhsUniforms.write(s, rect: dst, image: frame, clock: clock, grade: _scaled(grade), frame: params);
        _draw(canvas, s, dst, FilmPass.vhs);
        return;
      }
    } else {
      final s = _stock;
      if (s != null) {
        FilmStockUniforms.write(
          s,
          rect: dst,
          image: frame,
          clock: clock,
          palette: skin.palette,
          grade: grade,
          look: look,
          frame: params,
          events: events,
          mix: _mix,
        );
        _draw(canvas, s, dst, FilmPass.stock);
        return;
      }
      final g = _grade;
      if (g != null) {
        FilmGradeUniforms.write(
          g,
          rect: dst,
          image: frame,
          clock: clock,
          palette: skin.palette,
          grade: _scaled(grade),
          frame: params,
        );
        _draw(canvas, g, dst, FilmPass.grade);
        return;
      }
    }
    canvas.drawImageRect(frame, ui.Rect.fromLTWH(0, 0, frame.width.toDouble(), frame.height.toDouble()), dst, _blit);
    _lastPass = FilmPass.blit;
  }

  void _draw(ui.Canvas canvas, ui.FragmentShader s, ui.Rect dst, FilmPass pass) {
    _paint.shader = s;
    canvas.drawRect(dst, _paint);
    _lastPass = pass;
  }

  // FilmGrade.scaled allocates: cache per wear value (it only changes when
  // the intensity or the accessibility setting does).
  FilmGrade? _scaledGrade;
  double _scaledFor = -1;

  FilmGrade _scaled(FilmGrade g) {
    if (_scaledGrade == null || _scaledFor != _wear) {
      _scaledFor = _wear;
      _scaledGrade = g.scaled(_wear);
    }
    return _scaledGrade!;
  }

  @override
  void dispose() {
    _stock?.dispose();
    _grade?.dispose();
    _vhs?.dispose();
    _stock = _grade = _vhs = null;
  }
}

/// The pass [ReelFilmFx.apply] drew with.
enum FilmPass { none, stock, grade, vhs, blit }

/// Reaches the FX knobs from a game: `game.filmFx.reel?.quality = …`,
/// `game.filmFx.reel?.events.cueNow()`. `null` for other FilmFx
/// implementations (test fakes).
extension ReelFilmFxAccess on FilmFx {
  ReelFilmFx? get reel => this is ReelFilmFx ? this as ReelFilmFx : null;
}

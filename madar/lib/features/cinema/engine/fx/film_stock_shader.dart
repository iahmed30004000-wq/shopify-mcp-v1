import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import '../core/era_skin.dart';
import '../core/film_clock.dart';
import '../core/film_fx.dart';
import 'film_events.dart';
import 'film_look.dart';

/// Shader programs owned by the FX agent beyond the core slots
/// (`CinemaShader`): same rules – asset path, exact float and sampler
/// counts (test/features/cinema/fx/film_stock_contract_test.dart checks the
/// compiled programs), layout documented in the .frag header.
enum FxShader {
  /// shaders/cinema/film_stock.frag – the era film look (1920s–1970s).
  filmStock('film_stock', floats: 68, samplers: 1);

  const FxShader(this.file, {required this.floats, this.samplers = 0});

  final String file;
  final int floats;
  final int samplers;

  String get asset => 'shaders/cinema/$file.frag';
}

/// Loads and caches the [FxShader] programs once per process. Mirrors
/// `CinemaShaders`: after the first load [preload] returns a
/// [SynchronousFuture] (never hops zones in fake-async widget tests), and a
/// program that failed stays `null` – callers fall back to film_grade.frag.
abstract final class FxShaders {
  static final Map<FxShader, ui.FragmentProgram> _programs = {};
  static Future<void>? _loading;
  static bool _done = false;

  static bool get isDone => _done;

  static Future<void> preload() {
    if (_done) return SynchronousFuture<void>(null);
    return _loading ??= _loadAll();
  }

  static Future<void> _loadAll() async {
    await Future.wait([
      for (final s in FxShader.values)
        ui.FragmentProgram.fromAsset(s.asset).then<void>(
          (p) => _programs[s] = p,
          onError: (Object e) {
            if (kDebugMode) debugPrint('FxShaders: ${s.asset} failed to load: $e');
          },
        ),
    ]);
    _done = true;
  }

  static ui.FragmentProgram? program(FxShader shader) => _programs[shader];

  @visibleForTesting
  static void debugReset() {
    _programs.clear();
    _loading = null;
    _done = false;
  }
}

/// The resolved strengths one frame is graded with (no allocation: one
/// mutable instance per FilmFx, refreshed in `apply`).
class FilmMix {
  /// Damage effects: grain, flicker, weave, dust, scratches (0..1).
  double wear = 1;

  /// Print stylisation: halftone, hatching, blinds, line boil, dyes (0..1).
  double style = 1;

  /// Exposure flicker (0 under reduced motion).
  double flicker = 1;

  /// Motion effects: weave, shake, blinds drift (a quarter under reduced
  /// motion).
  double motion = 1;

  /// The whole-frame 12 fps line boil (0 under reduced motion: lines keep
  /// still).
  double boil = 1;

  /// film_stock.frag quality level (FilmQuality.shaderLevel).
  double quality = 2;
}

/// film_stock.frag's uniform writer (layout: the .frag header). Values are
/// written straight from the era tables and scaled by [mix]; nothing is
/// allocated.
abstract final class FilmStockUniforms {
  static const shader = FxShader.filmStock;

  static void write(
    ui.FragmentShader s, {
    required ui.Rect rect,
    required ui.Image image,
    required FilmClock clock,
    required EraPalette palette,
    required FilmGrade grade,
    required FilmLook look,
    required FilmFrame frame,
    required FilmEvents events,
    required FilmMix mix,
  }) {
    _s = s;
    _i = 0;
    final w = mix.wear;
    final st = mix.style;
    final h = rect.height;
    // 0 uRect, 1 uClock
    _f(rect.left);
    _f(rect.top);
    _f(rect.width);
    _f(rect.height);
    _f(clock.time);
    _f(clock.filmFrame.toDouble());
    _f(clock.boilFrame.toDouble());
    _f(clock.seed);
    // 2 uInk (+ quality), 3 uPaper (+ age)
    _f(palette.ink.r);
    _f(palette.ink.g);
    _f(palette.ink.b);
    _f(mix.quality);
    _f(palette.paper.r);
    _f(palette.paper.g);
    _f(palette.paper.b);
    _f(look.age * w);
    // 4 uTint
    _f(grade.tint.r);
    _f(grade.tint.g);
    _f(grade.tint.b);
    _f(grade.tintStrength);
    // 5 uTone
    _f(grade.saturation);
    _f(grade.contrast);
    _f(grade.brightness);
    _f(grade.posterize);
    // 6 uGrain
    _f(grade.grain * w);
    _f(grade.grainSize);
    _f(grade.flicker * w * mix.flicker);
    _f(grade.vignette);
    // 7 uWear
    _f(grade.gateWeave * w * mix.motion);
    _f(grade.dust * w);
    _f(grade.scratches * w);
    _f(grade.halation * (mix.quality > 0 ? 1 : 0));
    // 8 uEvent
    final damage = frame.reduceFlicker ? frame.damage * 0.5 : frame.damage;
    _f(frame.safeFlash);
    _f(frame.shake * mix.motion);
    _f(frame.fade);
    _f(damage);
    // 9 uPrint
    _f(look.halftone * st);
    _f(look.halftoneCell);
    _f(look.hatch * st);
    _f(look.hatchSpacing);
    // 10 uInkFx
    _f(look.screenAngle);
    _f(look.lineBoil * st * mix.boil);
    _f(look.softFocus);
    _f(look.toe);
    // 11 uLight
    _f(look.blinds * st);
    _f(look.blindsAngle);
    _f(look.blindsPeriod);
    _f(clock.time * look.blindsDrift * mix.motion);
    // 12 uDye
    _f(look.threeStrip);
    _f(look.dyeFade);
    _f(look.blackLift);
    _f(look.bloom * (mix.quality > 0 ? 1 : 0));
    // 13 uGate
    _f(look.gateCorner);
    _f(look.hotspot);
    _f(look.colourGrain);
    _f(look.frameLine * w * mix.motion);
    // 14 uSplice
    _f(events.splice);
    _f(events.spliceY * h);
    _f(events.frameSlip * h);
    _f(events.blotch);
    // 15 uCue
    _f(events.cue);
    _f(rect.width * events.cueX);
    _f(h * events.cueY);
    _f(events.cueRadius * rect.width);
    // 16 uHair
    _f(events.hair);
    _f(rect.width * events.hairX);
    _f(h * events.hairY);
    _f(events.hairAngle);
    assert(_i == shader.floats, 'film_stock: wrote $_i floats, contract says ${shader.floats}');
    _s = null;
    s.setImageSampler(0, image, filterQuality: ui.FilterQuality.low);
  }

  // Sequential cursor (UI isolate only; no closure allocated per write).
  static ui.FragmentShader? _s;
  static int _i = 0;

  static void _f(double v) => _s!.setFloat(_i++, v);

  /// Floats written by the last [write] (tests).
  @visibleForTesting
  static int get lastWritten => _i;
}

import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import '../noise_texture.dart';
import 'star_sprite.dart';

/// The sky's fragment programs, the shared noise texture and the star
/// sprite atlas.
///
/// `ui.FragmentProgram.fromAsset` caches programs per asset, so loading here
/// never duplicates what other orbit layers load.
class SkyPrograms {
  SkyPrograms._(this.sky, this.moon, this.lensFlare, this.noise, this.starSprite);

  static const skyAsset = 'shaders/orbit/sky.frag';
  static const moonAsset = 'shaders/orbit/moon.frag';
  static const lensFlareAsset = 'shaders/orbit/lens_flare.frag';

  final ui.FragmentProgram sky;
  final ui.FragmentProgram moon;
  final ui.FragmentProgram lensFlare;

  /// Sampler 0 of every sky program (common.glsl).
  final ui.Image noise;

  /// Procedural star atlas (see [StarSprite]).
  final ui.Image starSprite;

  static SkyPrograms? _instance;
  static Future<SkyPrograms>? _loading;

  /// The loaded programs, or null until [load] completes.
  static SkyPrograms? get instance => _instance;

  /// Loads (once) every program and texture; completes with an error when a
  /// shader is unavailable (the sky then paints its gradient fallback).
  static Future<SkyPrograms> load() {
    final existing = _instance;
    if (existing != null) return Future.value(existing);
    return _loading ??= _load().then(
      (p) => _instance = p,
      onError: (Object e, StackTrace s) {
        _loading = null;
        throw e;
      },
    );
  }

  static Future<SkyPrograms> _load() async {
    final programs = await Future.wait([
      ui.FragmentProgram.fromAsset(skyAsset),
      ui.FragmentProgram.fromAsset(moonAsset),
      ui.FragmentProgram.fromAsset(lensFlareAsset),
    ]);
    final noise = await NoiseTexture.image();
    final sprite = await StarSprite.image();
    return SkyPrograms._(programs[0], programs[1], programs[2], noise, sprite);
  }

  /// Loads everything and draws each program once offscreen so pipelines
  /// exist before the first visible frame (call during the splash).
  static Future<void> warmUp() async {
    final programs = await load();
    final set = SkyShaderSet(programs);
    final flares = FlareShaderSet(programs);
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    try {
      set.warm(canvas);
      flares.warm(canvas);
      final picture = recorder.endRecording();
      try {
        final image = await picture.toImage(8, 8);
        image.dispose();
      } finally {
        picture.dispose();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Sky warm-up skipped: $e');
    } finally {
      set.dispose();
      flares.dispose();
    }
  }

  @visibleForTesting
  static void debugReset() {
    _instance = null;
    _loading = null;
  }
}

/// Reusable shader instances for one sky backdrop (uniforms are captured
/// when a draw is recorded, so one instance per draw role serves every
/// frame).
class SkyShaderSet {
  SkyShaderSet(this.programs) : sky = programs.sky.fragmentShader(), moon = programs.moon.fragmentShader() {
    sky.setImageSampler(0, programs.noise, filterQuality: ui.FilterQuality.low);
    moon.setImageSampler(0, programs.noise, filterQuality: ui.FilterQuality.low);
  }

  final SkyPrograms programs;
  final ui.FragmentShader sky;
  final ui.FragmentShader moon;

  /// Uniform float counts (after common.glsl) – see the shader headers.
  static const skyFloats = 41;
  static const moonFloats = 10;

  /// One tiny draw per program (pipeline warm-up), plus the star atlas.
  void warm(ui.Canvas canvas) {
    const r = ui.Rect.fromLTWH(0, 0, 8, 8);
    for (var i = 0; i < skyFloats; i++) {
      sky.setFloat(i, i < 2 || i == 4 ? 8 : 0.5);
    }
    for (var i = 0; i < moonFloats; i++) {
      moon.setFloat(i, i < 4 ? 4 : 0.5);
    }
    // The exact paint setups the sky uses: the moon composites with
    // "screen", its glow with "plus" (each blend mode is its own pipeline).
    canvas
      ..drawRect(r, ui.Paint()..shader = sky)
      ..drawRect(
        r,
        ui.Paint()
          ..shader = moon
          ..blendMode = ui.BlendMode.screen,
      )
      ..drawCircle(
        const ui.Offset(4, 4),
        3,
        ui.Paint()
          ..color = const ui.Color(0x40FFFFFF)
          ..blendMode = ui.BlendMode.plus,
      )
      ..drawRawAtlas(
        programs.starSprite,
        Float32List.fromList(const [0.1, 0, 0, 0]),
        Float32List.fromList(const [0, 0, 64, 64]),
        Int32List.fromList(const [0x80FFFFFF]),
        ui.BlendMode.modulate,
        null,
        ui.Paint()..blendMode = ui.BlendMode.plus,
      );
  }

  void dispose() {
    sky.dispose();
    moon.dispose();
  }
}

/// Reusable lens-flare instances: one for the core star, one for the sun.
class FlareShaderSet {
  FlareShaderSet(this.programs)
    : core = programs.lensFlare.fragmentShader(),
      sun = programs.lensFlare.fragmentShader() {
    core.setImageSampler(0, programs.noise, filterQuality: ui.FilterQuality.low);
    sun.setImageSampler(0, programs.noise, filterQuality: ui.FilterQuality.low);
  }

  final SkyPrograms programs;
  final ui.FragmentShader core;
  final ui.FragmentShader sun;

  static const flareFloats = 9;

  void warm(ui.Canvas canvas) {
    for (var i = 0; i < flareFloats; i++) {
      core.setFloat(i, i < 2 ? 8 : 0.5);
    }
    canvas.drawRect(
      const ui.Rect.fromLTWH(0, 0, 8, 8),
      ui.Paint()
        ..shader = core
        ..blendMode = ui.BlendMode.plus,
    );
  }

  void dispose() {
    core.dispose();
    sun.dispose();
  }
}

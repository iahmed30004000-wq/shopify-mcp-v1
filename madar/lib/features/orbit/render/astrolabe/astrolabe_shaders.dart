import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import '../noise_texture.dart';

/// The four fragment programs of the astrolabe plus the shared noise texture.
///
/// `ui.FragmentProgram.fromAsset` caches programs per asset, so loading here
/// never duplicates what [OrbitShaders] loads.
class AstrolabePrograms {
  AstrolabePrograms._(this.brass, this.ringText, this.prayerFire, this.coreStar, this.noise);

  static const brassAsset = 'shaders/orbit/brass.frag';
  static const ringTextAsset = 'shaders/orbit/ring_text.frag';
  static const prayerFireAsset = 'shaders/orbit/prayer_fire.frag';
  static const coreStarAsset = 'shaders/orbit/core_star.frag';

  final ui.FragmentProgram brass;
  final ui.FragmentProgram ringText;
  final ui.FragmentProgram prayerFire;
  final ui.FragmentProgram coreStar;

  /// Sampler 0 of brass / prayer_fire / core_star (common.glsl).
  final ui.Image noise;

  static AstrolabePrograms? _instance;
  static Future<AstrolabePrograms>? _loading;

  /// The loaded programs, or null until [load] completes.
  static AstrolabePrograms? get instance => _instance;

  /// Loads (once) every program; completes with an error when a shader is
  /// unavailable (the painter then falls back to gradients).
  static Future<AstrolabePrograms> load() {
    final existing = _instance;
    if (existing != null) return Future.value(existing);
    return _loading ??= _load().then((p) => _instance = p, onError: (Object e, StackTrace s) {
      _loading = null;
      throw e;
    });
  }

  static Future<AstrolabePrograms> _load() async {
    final results = await Future.wait([
      ui.FragmentProgram.fromAsset(brassAsset),
      ui.FragmentProgram.fromAsset(ringTextAsset),
      ui.FragmentProgram.fromAsset(prayerFireAsset),
      ui.FragmentProgram.fromAsset(coreStarAsset),
    ]);
    final noise = await NoiseTexture.image();
    return AstrolabePrograms._(results[0], results[1], results[2], results[3], noise);
  }

  /// Loads the programs and draws each once offscreen so their pipelines
  /// exist before the first visible frame (call during the splash).
  static Future<void> warmUp() async {
    final programs = await load();
    final set = AstrolabeShaderSet(programs);
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    try {
      set.warm(canvas);
      final picture = recorder.endRecording();
      try {
        final image = await picture.toImage(8, 8);
        image.dispose();
      } finally {
        picture.dispose();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Astrolabe warm-up skipped: $e');
    } finally {
      set.dispose();
    }
  }

  @visibleForTesting
  static void debugReset() {
    _instance = null;
    _loading = null;
  }
}

/// Reusable shader instances for one astrolabe painter. Uniform values are
/// captured when a draw is recorded, so one instance per program serves
/// every draw of a frame.
class AstrolabeShaderSet {
  AstrolabeShaderSet(this.programs)
    : brass = programs.brass.fragmentShader(),
      countdown = programs.ringText.fragmentShader(),
      mark = programs.ringText.fragmentShader(),
      fire = programs.prayerFire.fragmentShader(),
      star = programs.coreStar.fragmentShader() {
    brass.setImageSampler(0, programs.noise, filterQuality: ui.FilterQuality.low);
    fire.setImageSampler(0, programs.noise, filterQuality: ui.FilterQuality.low);
    star.setImageSampler(0, programs.noise, filterQuality: ui.FilterQuality.low);
  }

  final AstrolabePrograms programs;
  final ui.FragmentShader brass;
  final ui.FragmentShader countdown;
  final ui.FragmentShader mark;
  final ui.FragmentShader fire;
  final ui.FragmentShader star;

  /// One tiny draw per program (pipeline warm-up).
  void warm(ui.Canvas canvas) {
    const r = ui.Rect.fromLTWH(0, 0, 8, 8);
    for (var i = 0; i < 21; i++) {
      brass.setFloat(i, i < 4 ? 4 : 0.5);
    }
    for (var i = 0; i < 16; i++) {
      fire.setFloat(i, i == 5 ? 6 : 0.5);
    }
    for (var i = 0; i < 16; i++) {
      star.setFloat(i, 0.5);
    }
    for (var i = 0; i < 19; i++) {
      countdown.setFloat(i, 1);
    }
    countdown.setImageSampler(0, programs.noise, filterQuality: ui.FilterQuality.low);
    canvas
      ..drawRect(r, ui.Paint()..shader = brass)
      ..drawRect(r, ui.Paint()..shader = fire)
      ..drawRect(r, ui.Paint()..shader = star)
      ..drawRect(r, ui.Paint()..shader = countdown);
  }

  void dispose() {
    brass.dispose();
    countdown.dispose();
    mark.dispose();
    fire.dispose();
    star.dispose();
  }
}

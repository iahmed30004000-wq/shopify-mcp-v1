import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import '../../../core/domain/enums.dart';
import 'noise_texture.dart';

/// Every fragment program used by the Astrolabe Orbit.
enum OrbitShader {
  sky('shaders/orbit/sky.frag'),
  moon('shaders/orbit/moon.frag'),
  brass('shaders/orbit/brass.frag'),
  ringText('shaders/orbit/ring_text.frag'),
  planetOcean('shaders/orbit/planet_ocean.frag');

  const OrbitShader(this.asset);
  final String asset;
}

/// Maps a planet archetype to its shader (render work packages extend this as
/// they add worlds; unknown archetypes fall back to the ocean world).
OrbitShader shaderForArchetype(PlanetArchetype a) => switch (a) {
      PlanetArchetype.ocean => OrbitShader.planetOcean,
      _ => OrbitShader.planetOcean,
    };

/// Loads every orbit program once, owns the shared noise texture and warms up
/// GPU pipelines so the first real frame never janks.
class OrbitShaders {
  OrbitShaders._(this._programs, this.noise);

  final Map<OrbitShader, ui.FragmentProgram> _programs;

  /// Shared procedural noise texture (sampler 0 of every shader that includes
  /// shaders/orbit/lib/common.glsl).
  final ui.Image noise;

  static OrbitShaders? _instance;
  static Future<OrbitShaders>? _loading;

  static OrbitShaders? get instance => _instance;

  static Future<OrbitShaders> load() {
    final existing = _instance;
    if (existing != null) return Future.value(existing);
    return _loading ??= _load().then((s) => _instance = s);
  }

  static Future<OrbitShaders> _load() async {
    final noise = await NoiseTexture.image();
    final programs = <OrbitShader, ui.FragmentProgram>{};
    await Future.wait(OrbitShader.values.map((s) async {
      programs[s] = await ui.FragmentProgram.fromAsset(s.asset);
    }));
    return OrbitShaders._(programs, noise);
  }

  ui.FragmentProgram program(OrbitShader s) => _programs[s]!;

  /// A fresh shader instance with the noise sampler bound (sampler 0) when the
  /// program declares it. Callers own and must dispose the instance.
  ui.FragmentShader shader(OrbitShader s, {bool bindNoise = true}) {
    final shader = _programs[s]!.fragmentShader();
    if (bindNoise) shader.setImageSampler(0, noise, filterQuality: ui.FilterQuality.low);
    return shader;
  }

  /// Draws every program once into a tiny offscreen picture so pipeline state
  /// objects are created during the splash, not on the first visible frame.
  Future<void> warmUp() async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final created = <ui.FragmentShader>[];
    for (final s in OrbitShader.values) {
      try {
        // Every orbit program declares sampler 0 (noise or text); bind the
        // noise texture so the draw is valid.
        final shader = this.shader(s);
        created.add(shader);
        canvas.drawRect(const ui.Rect.fromLTWH(0, 0, 4, 4), ui.Paint()..shader = shader);
      } catch (e) {
        if (kDebugMode) debugPrint('Orbit warm-up skipped ${s.name}: $e');
      }
    }
    final picture = recorder.endRecording();
    try {
      final image = await picture.toImage(4, 4);
      image.dispose();
    } finally {
      picture.dispose();
      for (final s in created) {
        s.dispose();
      }
    }
  }
}

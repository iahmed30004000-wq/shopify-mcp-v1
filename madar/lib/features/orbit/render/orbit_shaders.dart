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
  planetFaith('shaders/orbit/planet_faith.frag', haloFactor: 1.5),
  planetOcean('shaders/orbit/planet_ocean.frag', haloFactor: 1.35),
  planetTerracotta('shaders/orbit/planet_terracotta.frag', haloFactor: 1.35),
  planetIndustrial('shaders/orbit/planet_industrial.frag', haloFactor: 1.35),
  planetCrystal('shaders/orbit/planet_crystal.frag', haloFactor: 1.35),
  planetVerdant('shaders/orbit/planet_verdant.frag', haloFactor: 1.35),
  planetVolcanic('shaders/orbit/planet_volcanic.frag', haloFactor: 1.35),
  planetGasGiant('shaders/orbit/planet_gas_giant.frag', haloFactor: 2.3),
  dataMoon('shaders/orbit/data_moon.frag', haloFactor: 1.6);

  const OrbitShader(this.asset, {this.haloFactor = 1});
  final String asset;

  /// Draw-rect half extent ÷ body radius, from the shader's header (planet
  /// and moon programs; 1 for the others).
  final double haloFactor;

  /// Programs that draw a world or a data moon with the planet uniform
  /// contract (see `PlanetParams`).
  bool get isBody => haloFactor > 1;
}

/// Maps a planet archetype to its shader. The two extra styles for
/// user-added planets reuse the closest world (ice → the crystal world,
/// desert → the terracotta world) with their own palette and seed, see
/// `PlanetStyle` in render/planets.
OrbitShader shaderForArchetype(PlanetArchetype a) => switch (a) {
  PlanetArchetype.faith => OrbitShader.planetFaith,
  PlanetArchetype.ocean => OrbitShader.planetOcean,
  PlanetArchetype.terracotta || PlanetArchetype.desert => OrbitShader.planetTerracotta,
  PlanetArchetype.industrial => OrbitShader.planetIndustrial,
  PlanetArchetype.crystal || PlanetArchetype.ice => OrbitShader.planetCrystal,
  PlanetArchetype.verdant => OrbitShader.planetVerdant,
  PlanetArchetype.volcanic => OrbitShader.planetVolcanic,
  PlanetArchetype.gasGiant => OrbitShader.planetGasGiant,
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

  /// Loads (once) every program and the noise texture. A failed load is not
  /// cached, so a later call retries.
  static Future<OrbitShaders> load() {
    final existing = _instance;
    if (existing != null) return Future.value(existing);
    return _loading ??= _load().then(
      (s) => _instance = s,
      onError: (Object e, StackTrace st) {
        _loading = null;
        Error.throwWithStackTrace(e, st);
      },
    );
  }

  @visibleForTesting
  static void debugReset() {
    _instance = null;
    _loading = null;
  }

  /// Makes [shaders] the loaded instance (tests of partial loads).
  @visibleForTesting
  static void debugSetInstance(OrbitShaders? shaders) {
    _instance = shaders;
    _loading = shaders == null ? null : Future.value(shaders);
  }

  /// A copy with only the programs in [keep] – as if the others had failed
  /// to compile (tests of the fallback path).
  @visibleForTesting
  OrbitShaders debugOnly(Set<OrbitShader> keep) => OrbitShaders._({
    for (final e in _programs.entries)
      if (keep.contains(e.key)) e.key: e.value,
  }, noise);

  /// Loads each program on its own: one that a driver cannot compile only
  /// takes its own worlds back to the plain lit-sphere fallback ([has] is
  /// false for it); the load fails only when nothing loads at all.
  static Future<OrbitShaders> _load() async {
    final noise = await NoiseTexture.image();
    final programs = <OrbitShader, ui.FragmentProgram>{};
    await Future.wait(
      OrbitShader.values.map((s) async {
        try {
          programs[s] = await ui.FragmentProgram.fromAsset(s.asset);
        } catch (e) {
          if (kDebugMode) debugPrint('Orbit shader ${s.name} unavailable: $e');
        }
      }),
    );
    if (programs.isEmpty) throw StateError('No orbit shader could be loaded');
    return OrbitShaders._(programs, noise);
  }

  /// Whether [s] loaded (otherwise draw the fallback).
  bool has(OrbitShader s) => _programs.containsKey(s);

  ui.FragmentProgram program(OrbitShader s) => _programs[s]!;

  /// A fresh shader instance with the noise sampler bound (sampler 0) when the
  /// program declares it. Callers own and must dispose the instance. Check
  /// [has] first.
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
      if (!has(s)) continue;
      try {
        // Every orbit program declares sampler 0 (noise or text); bind the
        // noise texture so the draw is valid.
        final shader = this.shader(s);
        created.add(shader);
        if (s.isBody) _benignBodyUniforms(shader);
        canvas.drawRect(const ui.Rect.fromLTWH(0, 0, 4, 4), ui.Paint()..shader = shader);
      } catch (e) {
        if (kDebugMode) debugPrint('Orbit warm-up skipped ${s.name}: $e');
      }
    }
    // The blended paint setups the scene draws with (each blend mode is its
    // own pipeline): a world's "screen" sky-light gradient, the dial's
    // "plus" glows and lit-arc strokes.
    const c = ui.Offset(2, 2);
    canvas
      ..drawCircle(
        c,
        2,
        ui.Paint()
          ..shader = ui.Gradient.radial(c, 2, const [ui.Color(0x00FFFFFF), ui.Color(0x40FFFFFF)])
          ..blendMode = ui.BlendMode.screen,
      )
      ..drawCircle(
        c,
        1.5,
        ui.Paint()
          ..color = const ui.Color(0x40FFFFFF)
          ..blendMode = ui.BlendMode.plus,
      )
      ..drawCircle(
        c,
        1.5,
        ui.Paint()
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = const ui.Color(0x40FFFFFF)
          ..blendMode = ui.BlendMode.plus,
      );
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

  /// A small lit sphere in the 4×4 warm-up rect (planet uniform contract), so
  /// the warm-up draw runs the real code paths instead of dividing by a zero
  /// radius.
  static void _benignBodyUniforms(ui.FragmentShader shader) {
    const values = <double>[
      4, 4, 2, 2, 1.6, 12, // uSize, uCenter, uRadius, uTime
      -0.6, 0.4, 0.69, 0.8, 0, // uLight, uScore, uPulse
      0.8, 0.35, 0, // uSpin
      0.8, 0.6, 0.3, 1, 1, 0.9, 0.6, 1, 0.2, 0.1, 0.05, 1, // uColorA/B/C
      0.1, 1, 0, 0, 0, 0, // uDetail, uSeed, uExtra
    ];
    for (var i = 0; i < values.length; i++) {
      shader.setFloat(i, values[i]);
    }
  }
}

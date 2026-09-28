import 'dart:ui' as ui;

import '../../../../core/design/themes.dart' show PlanetPalette;
import '../orbit_shaders.dart';
import 'planet_body.dart';
import 'planet_frame.dart';
import 'planet_style.dart';
import 'planet_uniforms.dart';

/// One body's GPU state: its shader instance (created once), its uniform
/// buffer and its paint.
class _Slot {
  _Slot(this.program, this.shader) : paint = ui.Paint()..shader = shader;

  final OrbitShader program;
  final ui.FragmentShader shader;
  final ui.Paint paint;
  final PlanetUniforms uniforms = PlanetUniforms();

  /// Palette cache (the ice / desert recolour costs HSL maths).
  PlanetBody? paletteFor;
  PlanetPalette? palette;

  void dispose() => shader.dispose();
}

/// Draws worlds and data moons with their fragment shaders.
///
/// Every planet and moon gets one [ui.FragmentShader] instance the first
/// time it is drawn and keeps it (a moon's by its record id, a planet's by
/// its key; a world that changes style gets the new program). Uniforms are
/// written into a per-body float buffer and copied into the shader; the
/// paint is reused. Nothing GPU-side is allocated per frame. Call [retain]
/// when the set of bodies changes and [dispose] when done.
class PlanetRenderer {
  PlanetRenderer(this.shaders);

  final OrbitShaders shaders;

  final Map<String, _Slot> _planets = {};
  final Map<String, _Slot> _moons = {};

  static const _zeroExtras = <double>[0, 0, 0, 0];

  /// Shader instances alive (tests / diagnostics).
  int get instanceCount => _planets.length + _moons.length;

  _Slot _planetSlot(PlanetBody body) {
    final program = body.shader;
    final existing = _planets[body.key];
    if (existing != null && existing.program == program) return existing;
    existing?.dispose();
    return _planets[body.key] = _Slot(program, shaders.shader(program));
  }

  _Slot _moonSlot(String id) => _moons[id] ??= _Slot(OrbitShader.dataMoon, shaders.shader(OrbitShader.dataMoon));

  /// Shader clocks wrap every [timeWrap] seconds (in double precision) so
  /// float32 `uTime` never loses the precision its slow effects need, however
  /// long the scene runs; the rare wrap is a single, imperceptible step.
  static const double timeWrap = 7200;

  /// Whether [body]'s world shader is available (else draw a fallback).
  bool canDraw(PlanetBody body) => shaders.has(body.shader);

  /// Whether the data-moon shader is available.
  bool get canDrawMoons => shaders.has(OrbitShader.dataMoon);

  /// Draws one world as [b] describes it on a canvas of [canvasSize].
  void paintPlanet(ui.Canvas canvas, ui.Size canvasSize, BodyFrame b, double time) {
    final body = b.body;
    final slot = _planetSlot(body);
    if (!identical(slot.paletteFor, body)) {
      slot.palette = body.shaderPalette;
      slot.paletteFor = body;
    }
    final pal = slot.palette!;
    slot.uniforms.set(
      canvas: canvasSize,
      center: b.center,
      radius: b.radius,
      time: time % timeWrap,
      lightX: b.lightX,
      lightY: b.lightY,
      lightZ: b.lightZ,
      score: b.score,
      pulse: b.pulse,
      spin: b.spin,
      tilt: b.tilt,
      colorA: pal.surface,
      colorB: pal.glow,
      colorC: pal.deep,
      detail: b.detail,
      seed: body.shaderSeed,
      extra: body.extras,
    );
    slot.uniforms.applyTo(slot.shader);
    _fade(slot.paint, b.opacity);
    canvas.drawRect(b.drawRect, slot.paint);
  }

  /// Paint alpha modulates the (premultiplied) shader output – a fade
  /// without a layer.
  static void _fade(ui.Paint paint, double opacity) {
    final a = opacity.clamp(0.0, 1.0);
    if (paint.color.a != a) paint.color = ui.Color.fromRGBO(0, 0, 0, a);
  }

  /// Draws one data moon (glow and shadow derived from its own colour).
  void paintMoon(ui.Canvas canvas, ui.Size canvasSize, MoonFrame m, double time) {
    final moon = m.moon;
    final slot = _moonSlot(moon.id);
    slot.uniforms
      ..set(
        canvas: canvasSize,
        center: m.center,
        radius: m.radius,
        time: time % timeWrap,
        lightX: m.lightX,
        lightY: m.lightY,
        lightZ: m.lightZ,
        score: m.score,
        pulse: m.pulse,
        spin: m.spin,
        tilt: m.tilt,
        colorA: moon.color,
        colorB: MoonStyle.derived,
        colorC: MoonStyle.derived,
        detail: m.detail,
        seed: moon.seed,
        extra: _zeroExtras,
      )
      ..setExtra(0, moon.kind.shaderLook)
      ..setExtra(1, m.selected);
    slot.uniforms.applyTo(slot.shader);
    _fade(slot.paint, m.opacity);
    canvas.drawRect(m.drawRect, slot.paint);
  }

  /// Releases the shaders of bodies that are gone.
  void retain({required Set<String> planetKeys, required Set<String> moonIds}) {
    _planets.removeWhere((k, s) {
      if (planetKeys.contains(k)) return false;
      s.dispose();
      return true;
    });
    _moons.removeWhere((k, s) {
      if (moonIds.contains(k)) return false;
      s.dispose();
      return true;
    });
  }

  /// The uniform buffer last written for a planet / moon (tests).
  PlanetUniforms? debugPlanetUniforms(String key) => _planets[key]?.uniforms;
  PlanetUniforms? debugMoonUniforms(String id) => _moons[id]?.uniforms;

  void dispose() {
    for (final s in _planets.values) {
      s.dispose();
    }
    for (final s in _moons.values) {
      s.dispose();
    }
    _planets.clear();
    _moons.clear();
  }
}

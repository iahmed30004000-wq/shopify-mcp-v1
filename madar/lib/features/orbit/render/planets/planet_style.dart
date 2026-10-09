import 'dart:math' as math;
import 'dart:ui' show Color;

import 'package:flutter/painting.dart' show HSLColor;

import '../../../../core/design/themes.dart' show PlanetPalette;
import '../../../../core/domain/enums.dart';
import '../orbit_shaders.dart';

/// How a [PlanetArchetype] is drawn by the planet layer: which world shader,
/// how far its halo reaches, how big the world is relative to its siblings,
/// and – for the two extra user styles – how its palette and seed differ from
/// the world whose shader it borrows.
///
/// Pure: no GPU objects, safe to use from tests and layout code.
abstract final class PlanetStyle {
  /// The world shader for [a] (ice → crystal, desert → terracotta).
  static OrbitShader shaderOf(PlanetArchetype a) => shaderForArchetype(a);

  /// Draw-rect half extent ÷ disc radius (the shader header's haloFactor).
  static double haloFactorOf(PlanetArchetype a) => shaderOf(a).haloFactor;

  /// Relative disc size in the system (1 = a typical world). The gas giant
  /// is a little larger (its rings add the rest of its presence), the
  /// volcanic world a little smaller and denser.
  static double sizeFactorOf(PlanetArchetype a) => switch (a) {
    PlanetArchetype.faith => 1.0,
    PlanetArchetype.ocean => 0.96,
    PlanetArchetype.terracotta => 0.96,
    PlanetArchetype.industrial => 0.95,
    PlanetArchetype.crystal => 0.92,
    PlanetArchetype.verdant => 0.96,
    PlanetArchetype.volcanic => 0.88,
    PlanetArchetype.gasGiant => 1.12,
    PlanetArchetype.ice => 0.86,
    PlanetArchetype.desert => 0.9,
  };

  /// Where a label or moon may start without touching the world, as a
  /// multiple of the disc radius: the gas giant's rings reach 2.1 R but lie
  /// slanted, so vertically ~1.3 R is clear; every other world ends at its
  /// atmosphere.
  static double clearanceOf(PlanetArchetype a) => a == PlanetArchetype.gasGiant ? 1.32 : 1.08;

  /// Inner edge of the moon lanes (disc radii): outside the halo, and for the
  /// gas giant outside the ship lanes (2.17 R).
  static double moonLaneStartOf(PlanetArchetype a) => a == PlanetArchetype.gasGiant ? 2.45 : 1.62;

  /// Added to the planet's seed so a style that borrows another world's
  /// shader never repeats that world's layout (ice ≠ Money, desert ≠
  /// Family), even for a built-in planet dressed in it.
  static double seedOffsetOf(PlanetArchetype a) => switch (a) {
    PlanetArchetype.ice => 23.17,
    PlanetArchetype.desert => 41.53,
    _ => 0,
  };

  /// Axial tilt of a planet (radians, `uSpin.y`): a stable per-planet value
  /// from its seed in 0.16..0.42; the gas giant always opens its rings
  /// clearly (0.34..0.42).
  static double axialTiltOf(PlanetArchetype a, double seed) {
    final f = _fract(seed * 0.6180339887 + 0.137);
    return a == PlanetArchetype.gasGiant ? 0.34 + 0.08 * f : 0.16 + 0.26 * f;
  }

  /// Seconds per rotation of a planet (slow, visible): 70..130 s.
  static double spinPeriodOf(double seed) => 70 + 60 * _fract(seed * 0.7548776662 + 0.31);

  /// The palette actually sent to the shader. The eight worlds use the
  /// planet's palette as it is. The two borrowed styles recolour it so the
  /// shader reads as a different world:
  /// * **ice** – the user's hue, frosted: pale glacial surface, a cold
  ///   white-cyan glow and a deep navy (not the crystal's jewel green);
  /// * **desert** – the user's hue, sun-bleached: a sandy surface, a warm
  ///   dune-gold glow and an umber shadow (not the family's terracotta).
  static PlanetPalette paletteOf(PlanetArchetype a, PlanetPalette base) {
    switch (a) {
      case PlanetArchetype.ice:
        final h = HSLColor.fromColor(base.surface);
        final hue = _towardHue(h.hue, 200, 0.45);
        return PlanetPalette(
          HSLColor.fromAHSL(1, hue, (h.saturation * 0.55).clamp(0.18, 0.5), 0.78).toColor(),
          HSLColor.fromAHSL(1, _towardHue(hue, 190, 0.5), 0.75, 0.93).toColor(),
          HSLColor.fromAHSL(1, _towardHue(hue, 225, 0.6), 0.55, 0.16).toColor(),
        );
      case PlanetArchetype.desert:
        final h = HSLColor.fromColor(base.surface);
        final hue = _towardHue(h.hue, 31, 0.6);
        return PlanetPalette(
          HSLColor.fromAHSL(1, hue, (h.saturation * 0.7).clamp(0.32, 0.5), 0.57).toColor(),
          HSLColor.fromAHSL(1, _towardHue(hue, 44, 0.6), 0.85, 0.78).toColor(),
          HSLColor.fromAHSL(1, _towardHue(hue, 20, 0.5), 0.5, 0.15).toColor(),
        );
      default:
        return base;
    }
  }

  /// Moves hue [from] toward [to] (degrees) by [t] along the shorter arc.
  static double _towardHue(double from, double to, double t) {
    var d = (to - from) % 360;
    if (d > 180) d -= 360;
    return (from + d * t + 360) % 360;
  }

  static double _fract(double x) => x - x.floorToDouble();
}

/// Glow / deep colours for a data moon: transparent means "derive from the
/// item colour" in `data_moon.frag` (its header), which keeps a person's own
/// colour the whole moon's identity.
abstract final class MoonStyle {
  static const derived = Color(0x00000000);

  /// Smallest a moon is ever drawn (logical px radius). At overview scale a
  /// world is only ~22 px across its radius, so the plain relative size put
  /// its moons at 3 px – dust, not moons, and under the 7 px a finger can
  /// aim at. Below this the whole swarm is scaled up instead.
  static const double minScreenRadius = 6;

  /// The most a moon may grow relative to its world, whatever the floor
  /// asks for (it still has to look like a moon beside its planet).
  static const double maxFactor = 0.33;

  /// Relative moon radius (of the parent's disc radius) for an item size
  /// 0..1: large enough to read at overview scale, never rivalling the world.
  /// [parentPx] (the world's radius on screen) is the level of detail: as
  /// the camera flies in, moons shrink relative to their world (to 60 % at
  /// hero scale) so they frame the surface instead of covering it; while the
  /// world is small they grow instead, so a moon is never smaller than
  /// [minScreenRadius] on screen. Without [parentPx] this is the plain
  /// geometric size (what the lane clearance is measured against).
  static double radiusFactor(double size, {double parentPx = 0}) {
    final t = ((parentPx - 50) / 170).clamp(0.0, 1.0);
    final f = (0.16 + 0.09 * size.clamp(0.0, 1.0)) * (1 - 0.4 * t * t * (3 - 2 * t));
    if (parentPx <= 0) return f;
    return math.min(maxFactor, math.max(f, minScreenRadius / parentPx));
  }
}

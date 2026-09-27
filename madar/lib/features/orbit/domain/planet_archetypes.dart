import 'dart:ui' show Color;

import 'package:flutter/painting.dart' show HSLColor;

import '../../../core/design/themes.dart' show PlanetPalette, PlanetPalettes;
import '../../../core/domain/enums.dart';

/// How each [PlanetArchetype] is rendered and what it defaults to.
///
/// Eight archetypes have their own world shader. The two extra styles for
/// user-added planets reuse a shader with a distinctive `uExtra` and palette:
/// **ice** is the crystal world with fine frosted facets and almost no gold,
/// **desert** is the terracotta world with sparse hearths.
abstract final class OrbitArchetypes {
  /// The archetype whose shader draws [a].
  static PlanetArchetype shaderFor(PlanetArchetype a) => switch (a) {
    PlanetArchetype.ice => PlanetArchetype.crystal,
    PlanetArchetype.desert => PlanetArchetype.terracotta,
    _ => a,
  };

  /// The built-in planet whose data drives [a]'s archetype-specific
  /// uniforms (the Work planet's boards light the industrial cities …).
  static String? naturalKey(PlanetArchetype a) => switch (a) {
    PlanetArchetype.faith => 'faith',
    PlanetArchetype.ocean => 'health',
    PlanetArchetype.terracotta => 'family',
    PlanetArchetype.industrial => 'work',
    PlanetArchetype.crystal => 'money',
    PlanetArchetype.verdant => 'growth',
    PlanetArchetype.volcanic => 'body',
    PlanetArchetype.gasGiant => 'travel',
    PlanetArchetype.ice || PlanetArchetype.desert => null,
  };

  /// Archetype of a built-in planet key (custom keys → null).
  static PlanetArchetype? forBuiltInKey(String key) => switch (key) {
    'faith' => PlanetArchetype.faith,
    'health' => PlanetArchetype.ocean,
    'family' => PlanetArchetype.terracotta,
    'work' => PlanetArchetype.industrial,
    'money' => PlanetArchetype.crystal,
    'growth' => PlanetArchetype.verdant,
    'body' => PlanetArchetype.volcanic,
    'travel' => PlanetArchetype.gasGiant,
    _ => null,
  };

  /// `uExtra` for a planet of style [a] that has no data of its own
  /// (a custom planet, or a built-in planet dressed in another style).
  /// Zeros mean "shader default / follow uScore".
  static List<double> styleExtras(PlanetArchetype a) => switch (a) {
    // Finer facets (x) and a whisper of gold (y) – a frosted ice world.
    PlanetArchetype.ice => const [1.55, 0.06, 0, 0],
    // Sparse hearths: a quiet desert world.
    PlanetArchetype.desert => const [0.5, 0, 0, 0],
    _ => const [0, 0, 0, 0],
  };

  /// Suggested colour for a new planet of archetype [a], derived from
  /// [PlanetPalettes] (ice and desert are tints of the Health and Faith
  /// palettes).
  static Color defaultColor(PlanetArchetype a) => switch (a) {
    PlanetArchetype.faith => PlanetPalettes.faith.surface,
    PlanetArchetype.ocean => PlanetPalettes.health.surface,
    PlanetArchetype.terracotta => PlanetPalettes.family.surface,
    PlanetArchetype.industrial => PlanetPalettes.work.surface,
    PlanetArchetype.crystal => PlanetPalettes.money.surface,
    PlanetArchetype.verdant => PlanetPalettes.growth.surface,
    PlanetArchetype.volcanic => PlanetPalettes.body.surface,
    PlanetArchetype.gasGiant => PlanetPalettes.travel.surface,
    PlanetArchetype.ice =>
      HSLColor.fromColor(PlanetPalettes.health.surface).withSaturation(0.55).withLightness(0.8).toColor(),
    PlanetArchetype.desert =>
      HSLColor.fromColor(PlanetPalettes.faith.surface).withSaturation(0.45).withLightness(0.66).toColor(),
  };

  /// The palette of a planet: the curated palette when a built-in planet
  /// keeps its signature colour, else one derived from [color].
  static PlanetPalette paletteFor(String key, int color) {
    final curated = PlanetPalettes.byKey[key];
    if (curated != null && curated.surface.toARGB32() == color) return curated;
    return PlanetPalettes.fromColor(Color(color));
  }

  /// Every archetype a user can pick for a planet, in picker order.
  static const choices = PlanetArchetype.values;
}

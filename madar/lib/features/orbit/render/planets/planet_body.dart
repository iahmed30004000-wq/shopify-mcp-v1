import 'package:flutter/foundation.dart';

import '../../../../core/design/themes.dart' show PlanetPalette;
import '../../../../core/domain/enums.dart';
import '../../domain/orbit_moons.dart';
import '../../domain/planet_scores.dart' show PlanetState;
import '../../domain/scene_snapshot.dart';
import '../orbit_shaders.dart';
import 'planet_style.dart';

/// One world as the planet layer draws it: everything the shader and the
/// label need, nothing about how the data was gathered.
///
/// Build it from the data layer with [PlanetBody.fromOrbitPlanet], or
/// directly (previews, the customise sheet, tests).
@immutable
class PlanetBody {
  const PlanetBody({
    required this.key,
    required this.name,
    required this.archetype,
    required this.palette,
    required this.score,
    this.state = PlanetState.steady,
    this.extras = const [0, 0, 0, 0],
    this.seed = 0,
    this.moons = const [],
    this.moonOverflow = 0,
  });

  /// The planet as the scene snapshot describes it.
  factory PlanetBody.fromOrbitPlanet(OrbitPlanet p) => PlanetBody(
    key: p.key,
    name: p.name,
    archetype: p.archetype,
    palette: p.palette,
    score: p.uScore,
    state: p.state,
    extras: p.extras,
    seed: p.seed,
    moons: p.moons,
    moonOverflow: p.moonOverflow,
  );

  /// Stable planet key (`faith`, `family`, `custom_<id>` …).
  final String key;

  /// Name in the current language (label, screen reader).
  final String name;
  final PlanetArchetype archetype;

  /// The planet's own palette (the user's colour).
  final PlanetPalette palette;

  /// Real balance score 0..1 – the layer springs its displayed score here.
  final double score;
  final PlanetState state;

  /// `uExtra` from the data (see each shader's header). Travel's `x` is the
  /// number of upcoming trips → that many ships on the gas giant.
  final List<double> extras;

  /// Stable per-planet noise seed.
  final double seed;

  /// Sub-items orbiting the world (people, wallets, boards, trips, modules).
  final List<OrbitMoon> moons;

  /// Items beyond the moon cap (not drawn).
  final int moonOverflow;

  /// The world shader that draws it.
  OrbitShader get shader => PlanetStyle.shaderOf(archetype);

  /// The palette sent to the shader (recoloured for ice / desert).
  PlanetPalette get shaderPalette => PlanetStyle.paletteOf(archetype, palette);

  /// `uSeed` (offset for styles that borrow another world's shader).
  double get shaderSeed => seed + PlanetStyle.seedOffsetOf(archetype);

  double get haloFactor => shader.haloFactor;

  /// Same look and data (a new object with equal content is not a change).
  bool sameAs(PlanetBody o) =>
      identical(this, o) ||
      (o.key == key &&
          o.name == name &&
          o.archetype == archetype &&
          o.palette.surface == palette.surface &&
          o.palette.glow == palette.glow &&
          o.palette.deep == palette.deep &&
          o.score == score &&
          o.state == state &&
          listEquals(o.extras, extras) &&
          o.seed == seed &&
          listEquals(o.moons, moons) &&
          o.moonOverflow == moonOverflow);

  @override
  String toString() => 'PlanetBody($key ${archetype.name} score ${score.toStringAsFixed(2)} moons ${moons.length})';
}

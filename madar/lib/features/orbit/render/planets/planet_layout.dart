import 'dart:math' as math;
import 'dart:ui' show Offset;

import '../../../../core/domain/enums.dart';
import '../../domain/scene_math.dart';
import 'planet_style.dart';

/// Where the worlds sit around the astrolabe (world units; y is up, the
/// orbital plane is x–z, the core star at the origin).
///
/// The user's planet order is the lane order: the first planet runs the
/// innermost orbit. Lanes spread evenly between [innerRadius] (just outside
/// the astrolabe) and [outerRadius]; with few planets they keep a pleasant
/// spacing instead of stretching to the edge. Worlds start a golden angle
/// apart so neighbouring lanes never begin side by side, and orbit slowly on
/// a softened Kepler law (outer worlds are slower, but only gently, so the
/// system drifts like an orrery rather than shuffling).
///
/// Pure and deterministic – the same inputs always give the same sky.
class PlanetSystemLayout {
  const PlanetSystemLayout({
    this.innerRadius = 0.76,
    this.outerRadius = 1.18,
    this.minLaneGap = 0.06,
    this.bodyRadius = 0.14,
    this.innerPeriod = 210,
    this.keplerExponent = 0.9,
    this.maxInclination = 0.045,
  });

  /// Innermost lane radius (clears the astrolabe).
  final double innerRadius;

  /// Outermost lane radius (fits the default camera on a phone).
  final double outerRadius;

  /// Lanes are never closer than this, even with many planets (the system
  /// then grows beyond [outerRadius]).
  final double minLaneGap;

  /// Disc radius of a typical world (× [PlanetStyle.sizeFactorOf]).
  final double bodyRadius;

  /// Seconds per revolution of the innermost world.
  final double innerPeriod;

  /// Period ∝ radius^k (1.5 would be Kepler; lower keeps the drift calm).
  final double keplerExponent;

  /// Largest tilt of an orbit out of the common plane (radians).
  final double maxInclination;

  static const goldenAngle = 2.399963229728653;

  /// The overview camera this layout is composed for: a phone in portrait
  /// looking down on the system at ~35°, so the orbits read as open
  /// ellipses around the astrolabe (the default [OrbitCamera]'s 21° flattens
  /// them into a band whose ends crowd), with every lane inside a 412-px
  /// wide screen and the worlds ~20–26 px.
  static const overviewCamera = OrbitCamera(elevation: 0.62, distance: 7.8, principal: Offset(0.5, 0.38));

  /// Lane radius of the [index]-th of [count] planets.
  double laneRadius(int index, int count) {
    if (count <= 1) return innerRadius + (outerRadius - innerRadius) * 0.35;
    final gap = math.max(minLaneGap, math.min((outerRadius - innerRadius) / (count - 1), 0.2));
    final span = gap * (count - 1);
    // Few planets: centre the band in the annulus instead of hugging the core.
    final start = span >= outerRadius - innerRadius
        ? innerRadius
        : innerRadius + (outerRadius - innerRadius - span) * 0.35;
    return start + gap * index;
  }

  /// Seconds per revolution on a lane of [radius].
  double periodFor(double radius) =>
      innerPeriod * math.pow(math.max(radius, 1e-3) / innerRadius, keplerExponent).toDouble();

  /// Radians per second on a lane of [radius] (prograde = positive).
  double angularSpeedFor(double radius) => 2 * math.pi / periodFor(radius);

  /// Starting angle of the [index]-th planet.
  double initialAngle(int index) => 0.62 + index * goldenAngle;

  /// Orbit tilt out of the common plane, stable per planet ([seed]).
  double inclinationOf(double seed) => maxInclination * (2 * _fract(seed * 0.5698402910 + 0.21) - 1);

  /// Line of nodes of the tilted orbit, stable per planet.
  double nodeOf(double seed) => 2 * math.pi * _fract(seed * 0.3819660113 + 0.47);

  /// Disc radius of a world of archetype [a] (world units).
  double bodyRadiusOf(PlanetArchetype a) => bodyRadius * PlanetStyle.sizeFactorOf(a);

  /// Position on a circular orbit of [radius] at [angle], tilted by
  /// [inclination] about x, then turned by [node] about y – the same maths
  /// as [OrbitElements.positionAt], without allocating an elements object.
  static V3 orbitPoint(double radius, double angle, {double inclination = 0, double node = 0, V3 center = V3.zero}) {
    var x = radius * math.cos(angle);
    var y = 0.0;
    var z = radius * math.sin(angle);
    if (inclination != 0) {
      final ci = math.cos(inclination), si = math.sin(inclination);
      final ny = y * ci - z * si;
      final nz = y * si + z * ci;
      y = ny;
      z = nz;
    }
    if (node != 0) {
      final cn = math.cos(node), sn = math.sin(node);
      final nx = x * cn + z * sn;
      final nz = -x * sn + z * cn;
      x = nx;
      z = nz;
    }
    return V3(center.x + x, center.y + y, center.z + z);
  }

  static double _fract(double x) => x - x.floorToDouble();
}

/// Lanes of the data moons around their planet (in the parent's disc radii,
/// so the whole cluster scales with the world).
///
/// Moons sit in evenly spaced lanes from [PlanetStyle.moonLaneStartOf] out to
/// [span] beyond it, each on its own inclined plane (0.2–0.62 rad, turned by
/// a per-moon node) so a family of moons reads as a 3-D swarm around the
/// world rather than one flat ring; inner moons are faster.
abstract final class MoonLayout {
  /// Radial width of the moon band (disc radii).
  static const span = 0.95;

  /// Lane of the [index]-th of [count] moons around a world of [parent].
  static double laneOf(int index, int count, PlanetArchetype parent) {
    final start = PlanetStyle.moonLaneStartOf(parent);
    if (count <= 1) return start + span * 0.3;
    return start + span * index / (count - 1);
  }

  /// Seconds per revolution on [lane] (disc radii): 26 s close in, ~46 s at
  /// the outer edge of a normal band.
  static double periodOf(double lane) => 26 * math.pow(lane / 1.62, 1.5).toDouble();

  /// Orbit tilt of a moon from its seed (radians).
  static double inclinationOf(double seed) => 0.2 + 0.42 * _fract(seed * 0.7548776662 + 0.11);

  /// Line of nodes of a moon's orbit from its seed.
  static double nodeOf(double seed) => 2 * math.pi * _fract(seed * 0.5698402910 + 0.73);

  /// Starting angle: spread by index (so a planet's moons begin evenly
  /// around it) with a small per-moon jitter.
  static double initialAngle(int index, int count, double seed) =>
      2 * math.pi * index / math.max(1, count) + 0.35 * (_fract(seed * 0.618034) - 0.5) + 0.4;

  static double _fract(double x) => x - x.floorToDouble();
}

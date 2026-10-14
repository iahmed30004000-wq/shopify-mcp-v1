import 'dart:math' as math;
import 'dart:ui' show Offset;

import '../../../../core/domain/enums.dart';
import '../../domain/scene_math.dart';
import 'planet_style.dart';

/// Where the worlds sit around the astrolabe (world units; y is up, the
/// orbital plane is x–z, the core star at the origin).
///
/// The user's planet order is the lane order: the first planet runs the
/// innermost orbit. Lanes spread evenly across the band between
/// [innerRadius] (outside the astrolabe's brass limb, with room for the
/// lane to pass over the dial without touching it) and [outerRadius] (what
/// the overview camera frames). The band *holds its width*: as worlds are
/// added the lanes compress toward each other rather than reaching further
/// out, down to [minLaneGap] – the gap at which [laneFloorCount] worlds
/// exactly fill the band. Only past that count does the system grow
/// outward, and the camera then pulls back so nothing leaves the frame.
///
/// Worlds start one even share of the circle apart (2π ÷ count) with a
/// small stable per-world offset, so the sky reads as a ring at any count
/// instead of the clumps a golden-angle scatter leaves at ten. They orbit
/// on a softened Kepler law (outer worlds are slower, but only gently, so
/// the system drifts like an orrery rather than shuffling).
///
/// Pure and deterministic – the same worlds always give the same sky.
class PlanetSystemLayout {
  const PlanetSystemLayout({
    this.innerRadius = 0.76,
    this.outerRadius = 1.18,
    this.laneFloorCount = 16,
    this.maxLaneGap = 0.2,
    this.bodyRadius = 0.14,
    this.innerPeriod = 170,
    this.keplerExponent = 0.8,
    this.maxInclination = 0.045,
  });

  /// Innermost lane radius (clears the astrolabe).
  final double innerRadius;

  /// Outermost lane radius (fits the default camera on a phone).
  final double outerRadius;

  /// How many worlds still fit inside the band `[innerRadius, outerRadius]`.
  /// It sets [minLaneGap]; beyond this count the system grows outward and
  /// the overview camera pulls back to keep it framed.
  final int laneFloorCount;

  /// Widest a lane gap ever gets (with two or three worlds), so a nearly
  /// empty sky still reads as a system and not as two distant rings.
  final double maxLaneGap;

  /// Lanes are never closer than this: the band divided among
  /// [laneFloorCount] worlds. Derived, not tuned – it is exactly the gap
  /// at which the band is full, so the band can never overflow below that
  /// count (and at ~160 px per world unit it still leaves the lane rings
  /// visibly apart).
  double get minLaneGap => (outerRadius - innerRadius) / (laneFloorCount - 1);

  /// Disc radius of a typical world (× [PlanetStyle.sizeFactorOf]).
  final double bodyRadius;

  /// Seconds per revolution of the innermost world: under three minutes, so
  /// the sky is alive whenever he looks at it. It was twice this and read as
  /// still (owner, 2026-10-10: «حركة الكواكب بطيئة»); it is still slow enough
  /// that nothing twitches at the edge of the eye.
  final double innerPeriod;

  /// Period ∝ radius^k (1.5 would be Kepler; lower keeps the drift calm).
  /// The lanes sit close together, so a small exponent also keeps the
  /// worlds' *relative* drift gentle: they hold their even spread for many
  /// minutes instead of shuffling into each other.
  final double keplerExponent;

  /// Largest tilt of an orbit out of the common plane (radians).
  final double maxInclination;

  /// How far a world may stand from its even share of the circle, as a
  /// fraction of that share: enough that the ring never looks stamped out
  /// by a machine, little enough that the smallest angular gap between two
  /// worlds is still `(1 − 2 × this) × 2π ÷ count` – at ten worlds, 29°
  /// instead of the 14° the golden-angle scatter left.
  static const double angleJitter = 0.1;

  /// Where the first world stands (radians): the old scatter's starting
  /// point, kept so the sky is turned the same way as before.
  static const double firstAngle = 0.62;

  /// The overview camera this layout is composed for: a phone in portrait
  /// looking down on the system at ~35°, so the orbits read as open
  /// ellipses around the astrolabe (the default [OrbitCamera]'s 21° flattens
  /// them into a band whose ends crowd), with every lane inside a 412-px
  /// wide screen and the worlds ~20–26 px.
  static const overviewCamera = OrbitCamera(elevation: 0.62, distance: 7.8, principal: Offset(0.5, 0.38));

  /// Lane radius of the [index]-th of [count] planets.
  ///
  /// The gap is the band divided among the worlds, held between
  /// [minLaneGap] and [maxLaneGap]. Up to [laneFloorCount] worlds the span
  /// can never exceed the band, so the outermost lane never passes
  /// [outerRadius] – that is what keeps a world from being cut off by the
  /// screen edge as worlds are added. Past that count the band grows and
  /// the camera is what gives way.
  double laneRadius(int index, int count) {
    final band = outerRadius - innerRadius;
    if (count <= 1) return innerRadius + band * 0.35;
    final gap = math.max(minLaneGap, math.min(band / (count - 1), maxLaneGap));
    final span = gap * (count - 1);
    // Few planets: centre the band in the annulus instead of hugging the core.
    final start = span >= band ? innerRadius : innerRadius + (band - span) * 0.35;
    return start + gap * index;
  }

  /// The outermost lane with [count] worlds (what the camera has to frame).
  double outermostLane(int count) => count <= 0 ? innerRadius : laneRadius(count - 1, count);

  /// Seconds per revolution on a lane of [radius].
  double periodFor(double radius) =>
      innerPeriod * math.pow(math.max(radius, 1e-3) / innerRadius, keplerExponent).toDouble();

  /// Radians per second on a lane of [radius] (prograde = positive).
  double angularSpeedFor(double radius) => 2 * math.pi / periodFor(radius);

  /// Starting angle of the [index]-th of [count] planets (of [seed]).
  ///
  /// Each world takes its own even share of the circle – `2π ÷ count` – so
  /// ten worlds stand 36° apart around the dial instead of the 14°-to-55°
  /// scatter a golden angle leaves at that count. The share is then nudged
  /// by a stable per-world offset of at most [angleJitter] of a share, so
  /// the ring breathes a little instead of looking stamped out; the nudge
  /// is bounded, so the smallest gap between any two worlds – including
  /// two on neighbouring lanes, which are only [minLaneGap] apart – can
  /// never fall below [minAngularGap].
  double initialAngle(int index, int count, double seed) {
    final share = 2 * math.pi / math.max(1, count);
    return firstAngle + index * share + share * angleJitter * (2 * _fract(seed * 0.7548776662 + 0.37) - 1);
  }

  /// Smallest angle between two of [count] worlds at rest (radians).
  double minAngularGap(int count) => count <= 1 ? 2 * math.pi : (1 - 2 * angleJitter) * 2 * math.pi / count;

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
/// The band is deliberately narrow: from [PlanetStyle.moonLaneStartOf] out
/// to [span] beyond it, so every moon stays visibly *around its own world*
/// instead of wandering a lane's width away (the planet lanes are only
/// ~0.3 disc radii apart, and the astrolabe's brass limb is barely further
/// in than the innermost lane – a wide band had the moons crossing both,
/// where they read as loose specks and vanished under the dial).
///
/// Each moon keeps its own gently inclined plane (0.2–0.44 rad, turned by a
/// per-moon node) so the family reads as a small 3-D swarm rather than one
/// flat ring; inner moons are faster.
abstract final class MoonLayout {
  /// Radial width of the moon band (disc radii).
  static const span = 0.38;

  /// Lane of the [index]-th of [count] moons around a world of [parent].
  static double laneOf(int index, int count, PlanetArchetype parent) {
    final start = PlanetStyle.moonLaneStartOf(parent);
    if (count <= 1) return start + span * 0.3;
    return start + span * index / (count - 1);
  }

  /// Seconds per revolution on [lane] (disc radii): ~42 s close in, ~57 s at
  /// the outer edge of a normal band – a moon comes round while he is
  /// looking at its world, without the 26 s whirl of the first version.
  static double periodOf(double lane) => 42 * math.pow(lane / 1.62, 1.5).toDouble();

  /// Orbit tilt of a moon from its seed (radians).
  static double inclinationOf(double seed) => 0.2 + 0.24 * _fract(seed * 0.7548776662 + 0.11);

  /// Line of nodes of a moon's orbit from its seed.
  static double nodeOf(double seed) => 2 * math.pi * _fract(seed * 0.5698402910 + 0.73);

  /// Starting angle: spread by index (so a planet's moons begin evenly
  /// around it) with a small per-moon jitter.
  static double initialAngle(int index, int count, double seed) =>
      2 * math.pi * index / math.max(1, count) + 0.35 * (_fract(seed * 0.618034) - 0.5) + 0.4;

  static double _fract(double x) => x - x.floorToDouble();
}

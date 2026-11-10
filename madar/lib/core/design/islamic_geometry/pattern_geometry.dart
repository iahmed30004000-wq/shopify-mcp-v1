import 'dart:math' as math;

import 'hankin.dart';
import 'pattern_spec.dart';
import 'tilings.dart';
import 'vec2.dart';

/// One decorated line: a closed outline (every tile yields one) in cell units.
class PatternLine {
  const PatternLine(this.points, {required this.tile});

  /// Closed: the last point connects back to the first.
  final List<Vec2> points;

  /// Index into [PatternGeometry.tiles] this line decorates (0 = medallion).
  final int tile;

  bool get closed => true;
}

/// The generated pattern for one [PatternSpec]: pure data in "cell units"
/// (the first translation vector has length 1), deterministic and finite.
///
/// To tile a plane, draw [lines] at `origin + i·t1 + j·t2` for integers i, j.
class PatternGeometry {
  PatternGeometry._({
    required this.family,
    required this.contactAngle,
    required this.lines,
    required this.tiles,
    required this.translation1,
    required this.translation2,
    required this.minX,
    required this.minY,
    required this.maxX,
    required this.maxY,
  });

  final PatternFamily family;

  /// The contact angle actually used (after clamping).
  final double contactAngle;

  /// Every decorated tile outline of one cell (the medallion's among them).
  final List<PatternLine> lines;

  /// The tile polygons of one cell (counter-clockwise); tile 0 is the
  /// medallion, centred on the origin.
  final List<List<Vec2>> tiles;

  /// Lattice translation vectors: the pattern repeats exactly under both.
  final Vec2 translation1, translation2;

  /// Bounding box of every line point of one cell (it overhangs the lattice
  /// parallelogram: neighbours overlap it, which is what makes the join
  /// seamless).
  final double minX, minY, maxX, maxY;

  double get width => maxX - minX;
  double get height => maxY - minY;

  /// Area of the lattice cell (parallelogram of the two translations).
  double get cellArea => translation1.cross(translation2).abs();

  /// Rotational symmetry order of the medallion the family promises.
  int get symmetryOrder => family.medallionSymmetry;

  /// Region boundary of the single medallion, for non-tiled use.
  List<Vec2> get medallionBoundary => tiles.first;

  /// The lines that decorate only the medallion tile.
  List<PatternLine> get medallionLines => [
    for (final l in lines)
      if (l.tile == 0) l,
  ];

  /// Radius of the smallest circle about the origin holding the medallion.
  double get medallionRadius => medallionBoundary.fold<double>(0, (m, p) => math.max(m, p.length));

  /// The largest n such that turning the medallion's lines by 2π/n maps them
  /// onto themselves (verifies [symmetryOrder] from the data, not the name).
  int measuredSymmetryOrder({double tolerance = 1e-6, int maxOrder = 24}) {
    final pts = [for (final l in medallionLines) ...l.points];
    for (var n = maxOrder; n >= 2; n--) {
      final a = 2 * math.pi / n;
      final ok = pts.every((p) {
        final r = p.rotated(a);
        return pts.any((q) => q.distanceTo(r) < tolerance);
      });
      if (ok) return n;
    }
    return 1;
  }

  /// Number of real builds so far (a cache hit does not count): lets tests
  /// and perf work prove nothing is rebuilt per frame.
  static int debugBuildCount = 0;

  static final Map<PatternSpec, PatternGeometry> _cache = {};

  /// Cached [build]: equal specs share one instance.
  static PatternGeometry cached(PatternSpec spec) => _cache.putIfAbsent(spec, () => build(spec));

  static void debugClearCache() => _cache.clear();

  /// Builds the geometry. Deterministic: no randomness, no clock, no
  /// iteration over unordered sets.
  static PatternGeometry build(PatternSpec spec) {
    debugBuildCount++;
    final theta = spec.resolvedContactAngle;
    final tiling = tilingFor(spec.family);
    final tiles = <List<Vec2>>[
      for (final t in tiling.tiles) signedArea(t) < 0 ? t.reversed.toList(growable: false) : t,
    ];
    final lines = <PatternLine>[
      for (var k = 0; k < tiles.length; k++) PatternLine(hankinOutline(tiles[k], theta), tile: k),
    ];
    var minX = double.infinity, minY = double.infinity, maxX = -double.infinity, maxY = -double.infinity;
    for (final l in lines) {
      for (final p in l.points) {
        minX = math.min(minX, p.x);
        minY = math.min(minY, p.y);
        maxX = math.max(maxX, p.x);
        maxY = math.max(maxY, p.y);
      }
    }
    return PatternGeometry._(
      family: spec.family,
      contactAngle: theta,
      lines: lines,
      tiles: tiles,
      translation1: tiling.t1,
      translation2: tiling.t2,
      minX: minX,
      minY: minY,
      maxX: maxX,
      maxY: maxY,
    );
  }
}

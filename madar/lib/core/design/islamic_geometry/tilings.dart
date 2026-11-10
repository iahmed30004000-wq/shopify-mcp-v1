import 'dart:math' as math;

import 'hankin.dart';
import 'pattern_spec.dart';
import 'vec2.dart';

/// A periodic tiling normalised so the first translation vector has length 1.
/// Tile 0 is the centred "medallion" polygon.
class Tiling {
  const Tiling(this.tiles, this.t1, this.t2);
  final List<List<Vec2>> tiles;
  final Vec2 t1, t2;
}

final double _sqrt3 = math.sqrt(3);

Tiling tilingFor(PatternFamily family) => switch (family) {
  PatternFamily.square4 => _square4(),
  PatternFamily.hex6 => _hex6(),
  PatternFamily.girih10 => _girih10(),
  PatternFamily.rosette12 => _rosette12(),
};

/// 4.8.8: octagons on a square lattice, squares in the gaps.
Tiling _square4() {
  final a = 1 / (1 + math.sqrt2);
  return Tiling(
    [
      regularPolygon(Vec2.zero, 8, a, math.pi / 8),
      regularPolygon(const Vec2(0.5, 0.5), 4, a, 0),
    ],
    const Vec2(1, 0),
    const Vec2(0, 1),
  );
}

/// 3.6.3.6 (trihexagonal): a hexagon and two triangles per cell.
Tiling _hex6() {
  const a = 0.5;
  final h = _sqrt3 * a / 2;
  return Tiling(
    [
      regularPolygon(Vec2.zero, 6, a, 0),
      [const Vec2(a, 0), Vec2(a * 1.5, h), Vec2(a * 0.5, h)],
      [Vec2(-a * 0.5, h), Vec2(a * 0.5, h), Vec2(0, 2 * h)],
    ],
    const Vec2(1, 0),
    Vec2(0.5, _sqrt3 / 2),
  );
}

/// Decagons touching along alternate edges on a 72° rhombic lattice; each
/// gap is exactly a girih bow-tie (angles 72/72/216/72/72/216).
Tiling _girih10() {
  final a = math.tan(math.pi / 10);
  const first = math.pi / 10;
  final v1 = const Vec2(1, 0);
  final v2 = Vec2.polar(2 * math.pi / 5);
  final centres = [Vec2.zero, v1, v1 + v2, v2];
  final decagons = [for (final c in centres) regularPolygon(c, 10, a, first)];

  // Bow-tie = the decagon edges around the lattice hole that no two
  // decagons share.
  final edges = <(Vec2, Vec2)>[];
  bool near(Vec2 p, Vec2 q) => p.distanceTo(q) < 1e-7;
  for (var d = 0; d < decagons.length; d++) {
    final poly = decagons[d];
    for (var i = 0; i < poly.length; i++) {
      final p = poly[i], q = poly[(i + 1) % poly.length];
      final m = (p + q) * 0.5;
      var shared = false;
      for (var e = 0; e < decagons.length && !shared; e++) {
        if (e == d) continue;
        final other = decagons[e];
        for (var k = 0; k < other.length; k++) {
          if (near(m, (other[k] + other[(k + 1) % other.length]) * 0.5)) {
            shared = true;
            break;
          }
        }
      }
      if (!shared) edges.add((p, q));
    }
  }
  final hole = (v1 + v2) * 0.5;
  edges.sort((x, y) {
    final dx = ((x.$1 + x.$2) * 0.5).distanceTo(hole);
    final dy = ((y.$1 + y.$2) * 0.5).distanceTo(hole);
    return dx.compareTo(dy);
  });
  final pool = edges.take(6).toList();
  final chain = <Vec2>[pool.first.$1, pool.first.$2];
  pool.removeAt(0);
  while (pool.isNotEmpty) {
    var progressed = false;
    for (var i = 0; i < pool.length; i++) {
      final e = pool[i];
      if (near(e.$1, chain.last)) {
        chain.add(e.$2);
      } else if (near(e.$2, chain.last)) {
        chain.add(e.$1);
      } else {
        continue;
      }
      pool.removeAt(i);
      progressed = true;
      break;
    }
    if (!progressed) break;
  }
  chain.removeLast(); // closes on the first point
  final bowtie = signedArea(chain) < 0 ? chain.reversed.toList() : chain;
  return Tiling([decagons.first, bowtie], v1, v2);
}

/// 3.12.12: dodecagons on a hexagonal lattice, triangles in the gaps.
Tiling _rosette12() {
  final a = math.tan(math.pi / 12);
  final v1 = const Vec2(1, 0);
  final v2 = Vec2.polar(math.pi / 3);
  final g1 = (v1 + v2) * (1 / 3);
  final g2 = (v1 + v2) * (2 / 3);
  return Tiling(
    [
      regularPolygon(Vec2.zero, 12, a, math.pi / 12),
      // Triangle vertices point away from the three surrounding centres.
      regularPolygon(g1, 3, a, g1.angle),
      regularPolygon(g2, 3, a, (-(v1 + v2)).angle),
    ],
    v1,
    v2,
  );
}

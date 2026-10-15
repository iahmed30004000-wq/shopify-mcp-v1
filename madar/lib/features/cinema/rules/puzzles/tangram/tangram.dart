/// Tangram: the seven tans, 45° snapping, silhouettes with exact-cover
/// validation and an exact win test.
///
/// Units: the square tan has side 1 ("tan units"); stored coordinates are
/// scaled by [kTanScale]. Rotations are multiples of 45° (`k` = 0..7).
///
/// Silhouettes are drawn on the integer lattice where every unit cell is
/// full, empty or half filled along a diagonal (see [TangramSilhouette]).
/// Each one is validated by an exact-cover search over quarter-cell
/// triangles, which also yields the reference solution used for hints.
/// Whether the player solved the puzzle is decided exactly in Z[√2]: the
/// seven placed tans must not overlap and each must lie inside the union of
/// the reference tans (their areas are equal, so the unions coincide).
library;

import '../core/puzzle_game.dart';
import 'tangram_geometry.dart';

export 'tangram_geometry.dart';

enum TanShape { largeTriangle, mediumTriangle, smallTriangle, square, parallelogram }

/// The seven pieces (ids 0..6).
enum TanPiece {
  largeA(TanShape.largeTriangle),
  largeB(TanShape.largeTriangle),
  medium(TanShape.mediumTriangle),
  smallA(TanShape.smallTriangle),
  smallB(TanShape.smallTriangle),
  square(TanShape.square),
  parallelogram(TanShape.parallelogram);

  const TanPiece(this.shape);
  final TanShape shape;
}

/// Canonical outlines in stored units (positive orientation).
List<SPoint> canonicalOutline(TanShape s) => switch (s) {
  TanShape.largeTriangle => [SPoint.ints(0, 0), SPoint.ints(8, 0), SPoint.ints(0, 8)],
  TanShape.mediumTriangle => [const SPoint(Surd.zero, Surd.zero), const SPoint(Surd(0, 4), Surd.zero), const SPoint(Surd.zero, Surd(0, 4))],
  TanShape.smallTriangle => [SPoint.ints(0, 0), SPoint.ints(4, 0), SPoint.ints(0, 4)],
  TanShape.square => [SPoint.ints(0, 0), SPoint.ints(4, 0), SPoint.ints(4, 4), SPoint.ints(0, 4)],
  TanShape.parallelogram => [SPoint.ints(0, 0), SPoint.ints(4, 0), SPoint.ints(8, 4), SPoint.ints(4, 4)],
};

/// Twice the area of each shape (stored units²): the full set is 8 tan
/// units² = 128 stored units² → 256 when doubled.
int shapeArea2(TanShape s) => switch (s) {
  TanShape.largeTriangle => 64,
  TanShape.mediumTriangle => 32,
  TanShape.smallTriangle => 16,
  TanShape.square => 32,
  TanShape.parallelogram => 32,
};

const int kTangramArea2 = 256;

/// A tan on the board: rotation, mirror (parallelogram only matters) and
/// the translation of its canonical origin vertex.
final class TanPlacement {
  const TanPlacement({required this.piece, this.rotation = 0, this.flipped = false, required this.offset});

  final TanPiece piece;
  final int rotation;
  final bool flipped;
  final SPoint offset;

  /// The outline with positive orientation.
  List<SPoint> get outline {
    var pts = canonicalOutline(piece.shape);
    if (flipped) pts = [for (final p in pts.reversed) p.mirror()];
    return [for (final p in pts) p.rotate(rotation) + offset];
  }

  /// Outline in tan-unit doubles for rendering.
  List<(double, double)> get outlineDoubles => [for (final p in outline) p.toDouble()];

  TanPlacement copyWith({TanPiece? piece, int? rotation, bool? flipped, SPoint? offset}) => TanPlacement(
    piece: piece ?? this.piece,
    rotation: rotation ?? this.rotation,
    flipped: flipped ?? this.flipped,
    offset: offset ?? this.offset,
  );

  /// Same covered region (vertex sets equal).
  bool sameRegion(TanPlacement o) {
    final a = outline.toSet(), b = o.outline.toSet();
    return a.length == b.length && a.containsAll(b);
  }

  Map<String, Object?> toJson() => {'p': piece.index, 'r': rotation, 'f': flipped, 'o': offset.toJson()};

  factory TanPlacement.fromJson(Map<String, Object?> j) => TanPlacement(
    piece: TanPiece.values[jsonInt(j, 'p')],
    rotation: jsonInt(j, 'r'),
    flipped: j['f'] == true,
    offset: SPoint.fromJson(j['o']),
  );

  @override
  bool operator ==(Object other) =>
      other is TanPlacement &&
      other.piece == piece &&
      other.rotation == rotation &&
      other.flipped == flipped &&
      other.offset == offset;

  @override
  int get hashCode => Object.hash(piece, rotation, flipped, offset);

  @override
  String toString() => 'Tan(${piece.name}, r$rotation${flipped ? ' f' : ''}, $offset)';
}

/// Exact checks shared by the library validation and the game.
abstract final class TangramRules {
  /// Whether two placements overlap with positive area.
  static bool overlaps(TanPlacement a, TanPlacement b) => overlapArea2(a.outline, b.outline).sign > 0;

  /// Whether [placements] (exactly the seven tans) cover the region of
  /// [reference] exactly.
  static bool coversExactly(List<TanPlacement> placements, List<TanPlacement> reference) {
    if (placements.length != 7) return false;
    final pieces = placements.map((p) => p.piece).toSet();
    if (pieces.length != 7) return false;
    for (var i = 0; i < placements.length; i++) {
      for (var j = i + 1; j < placements.length; j++) {
        if (overlaps(placements[i], placements[j])) return false;
      }
    }
    for (final p in placements) {
      final outline = p.outline;
      var inside = Surd.zero;
      for (final r in reference) {
        inside = inside + overlapArea2(outline, r.outline);
      }
      if (inside != Surd(shapeArea2(p.piece.shape))) return false;
    }
    return true;
  }
}

/// Snapping for drag-and-drop: vertex-to-vertex within [tolerance] tan
/// units, else to a half-unit grid.
TanPlacement snapPlacement(
  TanPiece piece, {
  required int rotation,
  bool flipped = false,
  required double x,
  required double y,
  Iterable<SPoint> anchors = const [],
  double tolerance = 0.2,
}) {
  final base = TanPlacement(piece: piece, rotation: rotation, flipped: flipped, offset: SPoint.ints(0, 0));
  final verts = base.outline;
  SPoint? best;
  var bestD = tolerance * tolerance;
  for (final v in verts) {
    final (vx, vy) = v.toDouble();
    for (final a in anchors) {
      final (ax, ay) = a.toDouble();
      final dx = vx + x - ax, dy = vy + y - ay;
      final d = dx * dx + dy * dy;
      if (d <= bestD) {
        bestD = d;
        best = a - v;
      }
    }
  }
  if (best != null) return base.copyWith(offset: best);
  // Half-unit grid: stored even integers.
  int g(double v) => (v * kTanScale / 2).round() * 2;
  return base.copyWith(offset: SPoint.ints(g(x), g(y)));
}

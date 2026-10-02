/// Tangram silhouettes: a library of original figures drawn on the integer
/// lattice, an exact-cover tiler that validates them, and a seeded
/// generator of abstract silhouettes.
///
/// Art alphabet (one character per unit cell, y grows downwards):
/// `#` full, `.` empty, and half cells split by a diagonal with the filled
/// triangle in the named corner: `◤` top-left, `◥` top-right, `◣`
/// bottom-left, `◢` bottom-right.
///
/// Every unit cell is cut by both diagonals into four quarter triangles
/// (N, E, S, W). Every tan placed with lattice-aligned legs covers whole
/// quarters, so tiling a silhouette with the seven tans is an exact-cover
/// problem over its 32 quarters (8 unit² × 4).
library;

import '../core/puzzle_game.dart';
import '../core/seeded_rng.dart';
import 'tangram.dart';

const int _qN = 1, _qE = 2, _qS = 4, _qW = 8;

int _quartersOf(String ch) => switch (ch) {
  '#' => 15,
  '◤' => _qN | _qW,
  '◥' => _qN | _qE,
  '◣' => _qS | _qW,
  '◢' => _qS | _qE,
  '.' || ' ' => 0,
  _ => throw ArgumentError('bad silhouette character "$ch"'),
};

/// A candidate lattice placement and the quarters it covers.
final class _LatticePlacement {
  _LatticePlacement(this.placement, this.quarters);
  final TanPlacement placement;
  final List<int> quarters;
}

/// Exact cover of quarter sets by the seven tans.
abstract final class TangramTiler {
  /// Orientations whose vertices stay on the integer lattice.
  static const Map<TanShape, List<(int, bool)>> latticeOrientations = {
    TanShape.largeTriangle: [(0, false), (2, false), (4, false), (6, false)],
    TanShape.smallTriangle: [(0, false), (2, false), (4, false), (6, false)],
    TanShape.mediumTriangle: [(1, false), (3, false), (5, false), (7, false)],
    TanShape.square: [(0, false)],
    TanShape.parallelogram: [(0, false), (2, false), (0, true), (2, true)],
  };

  static const List<TanShape> _shapeOrder = [
    TanShape.largeTriangle,
    TanShape.mediumTriangle,
    TanShape.parallelogram,
    TanShape.square,
    TanShape.smallTriangle,
  ];

  static bool _inside(List<(double, double)> poly, double x, double y) {
    for (var i = 0; i < poly.length; i++) {
      final (ax, ay) = poly[i];
      final (bx, by) = poly[(i + 1) % poly.length];
      if ((bx - ax) * (y - ay) - (by - ay) * (x - ax) <= 0) return false;
    }
    return true;
  }

  /// Quarter indices (`cell * 4 + q`, q: 0 N, 1 E, 2 S, 3 W) covered by a
  /// lattice-aligned [p] inside a [w]×[h] grid, or null when it leaves it.
  static List<int>? quartersOfPlacement(TanPlacement p, int w, int h) {
    final poly = <(double, double)>[];
    var minX = 1 << 20, minY = 1 << 20, maxX = -(1 << 20), maxY = -(1 << 20);
    for (final v in p.outline) {
      if (v.x.b != 0 || v.y.b != 0 || v.x.a % kTanScale != 0 || v.y.a % kTanScale != 0) return null;
      final x = v.x.a ~/ kTanScale, y = v.y.a ~/ kTanScale;
      if (x < 0 || y < 0 || x > w || y > h) return null;
      if (x < minX) minX = x;
      if (y < minY) minY = y;
      if (x > maxX) maxX = x;
      if (y > maxY) maxY = y;
      poly.add((x.toDouble(), y.toDouble()));
    }
    const centroids = [(0.5, 1 / 6), (5 / 6, 0.5), (0.5, 5 / 6), (1 / 6, 0.5)];
    final out = <int>[];
    for (var y = minY; y < maxY; y++) {
      for (var x = minX; x < maxX; x++) {
        for (var q = 0; q < 4; q++) {
          final (cx, cy) = centroids[q];
          if (_inside(poly, x + cx, y + cy)) out.add((y * w + x) * 4 + q);
        }
      }
    }
    return out;
  }

  /// Every lattice placement of [shape] fitting inside [allowed].
  static List<_LatticePlacement> _candidates(TanShape shape, List<bool> allowed, int w, int h) {
    final piece = TanPiece.values.firstWhere((p) => p.shape == shape);
    final seen = <String>{};
    final out = <_LatticePlacement>[];
    for (final (k, flip) in latticeOrientations[shape]!) {
      for (var ty = -2; ty <= h + 2; ty++) {
        for (var tx = -2; tx <= w + 2; tx++) {
          final p = TanPlacement(
            piece: piece,
            rotation: k,
            flipped: flip,
            offset: SPoint.ints(tx * kTanScale, ty * kTanScale),
          );
          final qs = quartersOfPlacement(p, w, h);
          if (qs == null || qs.isEmpty || !qs.every((q) => allowed[q])) continue;
          if (seen.add(qs.join(','))) out.add(_LatticePlacement(p, qs));
        }
      }
    }
    return out;
  }

  /// A tiling of the quarter set [target] (length `w * h * 4`) with the
  /// seven tans, or null when none exists.
  static List<TanPlacement>? tile(List<bool> target, int w, int h) {
    final total = target.where((t) => t).length;
    if (total != 32) return null;
    final cands = <TanShape, List<_LatticePlacement>>{
      for (final s in _shapeOrder) s: _candidates(s, target, w, h),
    };
    final remaining = <TanShape, int>{
      TanShape.largeTriangle: 2,
      TanShape.mediumTriangle: 1,
      TanShape.parallelogram: 1,
      TanShape.square: 1,
      TanShape.smallTriangle: 2,
    };
    // Candidates indexed by quarter.
    final byQuarter = List.generate(target.length, (_) => <(TanShape, _LatticePlacement)>[]);
    for (final e in cands.entries) {
      for (final c in e.value) {
        for (final q in c.quarters) {
          byQuarter[q].add((e.key, c));
        }
      }
    }
    final covered = List<bool>.filled(target.length, false);
    final chosen = <_LatticePlacement>[];

    bool search() {
      var q = -1;
      for (var i = 0; i < target.length; i++) {
        if (target[i] && !covered[i]) {
          q = i;
          break;
        }
      }
      if (q < 0) return chosen.length == 7;
      for (final (shape, c) in byQuarter[q]) {
        if (remaining[shape] == 0) continue;
        if (c.quarters.any((x) => covered[x])) continue;
        for (final x in c.quarters) {
          covered[x] = true;
        }
        remaining[shape] = remaining[shape]! - 1;
        chosen.add(c);
        if (search()) return true;
        chosen.removeLast();
        remaining[shape] = remaining[shape]! + 1;
        for (final x in c.quarters) {
          covered[x] = false;
        }
      }
      return false;
    }

    if (!search()) return null;
    // Assign piece identities (largeA/B, smallA/B).
    final used = <TanPiece>{};
    return [
      for (final c in chosen)
        () {
          final piece = TanPiece.values.firstWhere((p) => p.shape == c.placement.piece.shape && !used.contains(p));
          used.add(piece);
          return c.placement.copyWith(piece: piece);
        }(),
    ]..sort((a, b) => a.piece.index - b.piece.index);
  }
}

/// A target figure.
final class TangramSilhouette {
  TangramSilhouette(this.id, this.difficulty, List<String> art)
    : art = List.unmodifiable(art),
      width = art.fold(0, (m, r) => r.runes.length > m ? r.runes.length : m),
      height = art.length;

  /// Stable id (the UI localises the figure's name).
  final String id;
  final PuzzleDifficulty difficulty;
  final List<String> art;
  final int width;
  final int height;

  /// Quarter mask of the silhouette.
  late final List<bool> quarters = () {
    final out = List<bool>.filled(width * height * 4, false);
    for (var y = 0; y < height; y++) {
      final chars = art[y].runes.map(String.fromCharCode).toList();
      for (var x = 0; x < chars.length; x++) {
        final m = _quartersOf(chars[x]);
        for (var q = 0; q < 4; q++) {
          if (m & (1 << q) != 0) out[(y * width + x) * 4 + q] = true;
        }
      }
    }
    return out;
  }();

  /// Area in tan units² (must be 8).
  double get area => quarters.where((q) => q).length / 4;

  /// The reference solution found by the exact-cover tiler (null when the
  /// art cannot be tiled – rejected by the library tests).
  late final List<TanPlacement>? solution = TangramTiler.tile(quarters, width, height);

  /// Distinct vertices of the reference tans (snapping anchors).
  List<SPoint> get anchors => {
    for (final p in solution ?? const <TanPlacement>[]) ...p.outline,
  }.toList();

  /// Whether the unit cell grid is edge-connected (no floating parts).
  bool get isConnected {
    final n = quarters.length;
    final start = quarters.indexOf(true);
    if (start < 0) return false;
    final seen = List<bool>.filled(n, false)..[start] = true;
    final stack = [start];
    var count = 1;
    while (stack.isNotEmpty) {
      final i = stack.removeLast();
      for (final j in _quarterNeighbours(i, width, height)) {
        if (quarters[j] && !seen[j]) {
          seen[j] = true;
          count++;
          stack.add(j);
        }
      }
    }
    return count == quarters.where((q) => q).length;
  }

  /// A seeded abstract silhouette: the seven tans are laid one by one on
  /// the lattice, each sharing an edge with the previous ones.
  factory TangramSilhouette.random(int seed, {int size = 6}) {
    final rng = SeededRng(seed);
    while (true) {
      final grid = List<bool>.filled(size * size * 4, false);
      final order = [
        TanShape.largeTriangle,
        TanShape.largeTriangle,
        TanShape.mediumTriangle,
        TanShape.square,
        TanShape.parallelogram,
        TanShape.smallTriangle,
        TanShape.smallTriangle,
      ];
      var ok = true;
      for (var i = 0; i < order.length && ok; i++) {
        final all = TangramTiler._candidates(order[i], List<bool>.filled(size * size * 4, true), size, size);
        final fits = [
          for (final c in all)
            if (!c.quarters.any((q) => grid[q]) &&
                (i == 0 ||
                    c.quarters.any((q) => _quarterNeighbours(q, size, size).any((n) => grid[n] && !c.quarters.contains(n)))))
              c,
        ];
        if (fits.isEmpty) {
          ok = false;
          break;
        }
        // Prefer compact figures: favour placements touching more quarters.
        fits.sort((a, b) => _contacts(b.quarters, grid, size) - _contacts(a.quarters, grid, size));
        final pick = fits[rng.nextInt(fits.length < 6 ? fits.length : 6)];
        for (final q in pick.quarters) {
          grid[q] = true;
        }
      }
      if (!ok) continue;
      final art = _toArt(grid, size);
      if (art == null) continue;
      final s = TangramSilhouette('abstract$seed', PuzzleDifficulty.expert, art);
      if (s.solution != null) return s;
    }
  }

  static int _contacts(List<int> qs, List<bool> grid, int size) {
    var n = 0;
    for (final q in qs) {
      for (final m in _quarterNeighbours(q, size, size)) {
        if (grid[m]) n++;
      }
    }
    return n;
  }

  /// Converts a quarter grid back to art (null if a cell has an
  /// unrepresentable quarter pattern).
  static List<String>? _toArt(List<bool> grid, int size) {
    const byMask = {0: '.', 15: '#', _qN | _qW: '◤', _qN | _qE: '◥', _qS | _qW: '◣', _qS | _qE: '◢'};
    final rows = <String>[];
    for (var y = 0; y < size; y++) {
      final sb = StringBuffer();
      for (var x = 0; x < size; x++) {
        var m = 0;
        for (var q = 0; q < 4; q++) {
          if (grid[(y * size + x) * 4 + q]) m |= 1 << q;
        }
        final ch = byMask[m];
        if (ch == null) return null;
        sb.write(ch);
      }
      rows.add(sb.toString());
    }
    // Trim empty rows / columns.
    while (rows.isNotEmpty && rows.first.replaceAll('.', '').isEmpty) {
      rows.removeAt(0);
    }
    while (rows.isNotEmpty && rows.last.replaceAll('.', '').isEmpty) {
      rows.removeLast();
    }
    List<String> cols(List<String> r) => [for (final s in r) s];
    var trimmed = cols(rows);
    while (trimmed.isNotEmpty && trimmed.every((r) => r.startsWith('.'))) {
      trimmed = [for (final r in trimmed) r.substring(1)];
    }
    while (trimmed.isNotEmpty && trimmed.every((r) => r.endsWith('.'))) {
      trimmed = [for (final r in trimmed) r.substring(0, r.length - 1)];
    }
    return trimmed;
  }
}

/// Quarters sharing an edge with quarter [i].
List<int> _quarterNeighbours(int i, int w, int h) {
  final cell = i ~/ 4, q = i % 4;
  final x = cell % w, y = cell ~/ w;
  final out = <int>[cell * 4 + (q + 1) % 4, cell * 4 + (q + 3) % 4];
  switch (q) {
    case 0:
      if (y > 0) out.add(((y - 1) * w + x) * 4 + 2);
    case 1:
      if (x < w - 1) out.add((y * w + x + 1) * 4 + 3);
    case 2:
      if (y < h - 1) out.add(((y + 1) * w + x) * 4 + 0);
    case 3:
      if (x > 0) out.add((y * w + x - 1) * 4 + 1);
  }
  return out;
}

/// The built-in figures (original designs).
abstract final class TangramLibrary {
  static final List<TangramSilhouette> all = List.unmodifiable([
    // Easy: convex or nearly convex outlines.
    TangramSilhouette('rhombus', PuzzleDifficulty.easy, ['.◢◣.', '◢##◣', '◥##◤', '.◥◤.']),
    TangramSilhouette('rectangle', PuzzleDifficulty.easy, ['####', '####']),
    TangramSilhouette('bigTriangle', PuzzleDifficulty.easy, ['###◤', '##◤.', '#◤..', '◤...']),
    TangramSilhouette('house', PuzzleDifficulty.easy, ['.◢◣.', '◢##◣', '.##.', '.##.']),
    TangramSilhouette('tent', PuzzleDifficulty.easy, ['.◢◣.', '◢##◣', '####']),
    // Medium.
    TangramSilhouette('parallelogram', PuzzleDifficulty.medium, ['◥###◣.', '.◥###◣']),
    TangramSilhouette('trapezoid', PuzzleDifficulty.medium, ['.◢##◣.', '◢####◣']),
    TangramSilhouette('letterT', PuzzleDifficulty.medium, ['####', '.##.', '.##.']),
    TangramSilhouette('boot', PuzzleDifficulty.medium, ['##..', '##..', '####']),
    TangramSilhouette('arrow', PuzzleDifficulty.medium, ['..◣.', '###◣', '###◤', '..◤.']),
    // Hard.
    TangramSilhouette('minaret', PuzzleDifficulty.hard, ['.◢◣.', '.##.', '.##.', '◢##◣']),
    TangramSilhouette('mushroom', PuzzleDifficulty.hard, ['◢##◣', '◥##◤', '.##.']),
    TangramSilhouette('dhow', PuzzleDifficulty.hard, ['.#◣..', '.##◣.', '◥###◤']),
    TangramSilhouette('gate', PuzzleDifficulty.hard, ['####', '#..#', '#..#']),
    TangramSilhouette('chair', PuzzleDifficulty.hard, ['#...', '#...', '####', '#..#']),
    // Expert.
    TangramSilhouette('swallow', PuzzleDifficulty.expert, ['◥#◣◢#◤', '.◥##◤.', '..◥◤..']),
    TangramSilhouette('cat', PuzzleDifficulty.expert, ['◣◢...', '##...', '.#◣..', '.###◣']),
  ]);


  static TangramSilhouette byId(String id) => all.firstWhere((s) => s.id == id);

  static List<TangramSilhouette> forDifficulty(PuzzleDifficulty d) => all.where((s) => s.difficulty == d).toList();
}

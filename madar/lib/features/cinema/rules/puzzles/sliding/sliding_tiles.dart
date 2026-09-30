/// Sliding tiles (8-, 15- and 24-puzzle): only solvable permutations are
/// dealt; hints come from an optimal IDA* search (Manhattan distance plus
/// linear conflicts) when it fits a node budget and otherwise from a staged
/// solver that places the top row and left column group by group before
/// finishing the last 3×3 optimally.
///
/// Tiles are numbered 1..n²-1 in reading order; 0 is the blank, which ends
/// in the bottom-right corner.
library;

import '../core/puzzle_game.dart';
import '../core/seeded_rng.dart';

/// Pure helpers and solvers.
abstract final class SlidingSolver {
  /// The solved board of width [n].
  static List<int> goal(int n) => [for (var i = 1; i < n * n; i++) i, 0];

  static int _inversions(List<int> tiles) {
    var inv = 0;
    for (var i = 0; i < tiles.length; i++) {
      if (tiles[i] == 0) continue;
      for (var j = i + 1; j < tiles.length; j++) {
        if (tiles[j] != 0 && tiles[j] < tiles[i]) inv++;
      }
    }
    return inv;
  }

  /// Whether [tiles] (width [n]) can reach [goal].
  static bool isSolvable(List<int> tiles, int n) {
    final inv = _inversions(tiles);
    if (n.isOdd) return inv.isEven;
    final blankRowFromBottom = n - tiles.indexOf(0) ~/ n;
    return (inv + blankRowFromBottom).isOdd;
  }

  static List<int> neighbours(int cell, int n) {
    final x = cell % n, y = cell ~/ n;
    return [
      if (y > 0) cell - n,
      if (x < n - 1) cell + 1,
      if (y < n - 1) cell + n,
      if (x > 0) cell - 1,
    ];
  }

  // -------------------------------------------------------------------------
  // IDA*

  static int _manhattan(List<int> t, int n) {
    var d = 0;
    for (var i = 0; i < t.length; i++) {
      final v = t[i];
      if (v == 0) continue;
      final g = v - 1;
      d += (i % n - g % n).abs() + (i ~/ n - g ~/ n).abs();
    }
    return d;
  }

  static int _lisRemovals(List<int> seq) {
    if (seq.length < 2) return 0;
    final best = List<int>.filled(seq.length, 1);
    var lis = 1;
    for (var i = 1; i < seq.length; i++) {
      for (var j = 0; j < i; j++) {
        if (seq[j] < seq[i] && best[j] + 1 > best[i]) best[i] = best[j] + 1;
      }
      if (best[i] > lis) lis = best[i];
    }
    return seq.length - lis;
  }

  /// Linear-conflict surcharge (admissible: 2 × tiles to remove per line).
  static int _linearConflict(List<int> t, int n) {
    var lc = 0;
    final seq = <int>[];
    for (var r = 0; r < n; r++) {
      seq.clear();
      for (var c = 0; c < n; c++) {
        final v = t[r * n + c];
        if (v != 0 && (v - 1) ~/ n == r) seq.add((v - 1) % n);
      }
      lc += 2 * _lisRemovals(seq);
    }
    for (var c = 0; c < n; c++) {
      seq.clear();
      for (var r = 0; r < n; r++) {
        final v = t[r * n + c];
        if (v != 0 && (v - 1) % n == c) seq.add((v - 1) ~/ n);
      }
      lc += 2 * _lisRemovals(seq);
    }
    return lc;
  }

  /// Admissible heuristic (Manhattan + linear conflict).
  static int heuristic(List<int> tiles, int n) => _manhattan(tiles, n) + _linearConflict(tiles, n);

  /// Optimal solution by IDA*; null when [nodeBudget] is exhausted.
  /// Each entry is the cell of the tile that slides into the blank.
  static List<int>? optimal(List<int> start, int n, {int? nodeBudget}) {
    final t = List<int>.from(start);
    var blank = t.indexOf(0);
    var md = _manhattan(t, n);
    final path = <int>[];
    var nodes = 0;
    var found = false;
    const inf = 1 << 30;

    int search(int g, int bound, int prev) {
      nodes++;
      final h = md + _linearConflict(t, n);
      final f = g + h;
      if (f > bound) return f;
      if (h == 0) {
        found = true;
        return f;
      }
      if (nodeBudget != null && nodes > nodeBudget) return inf;
      var min = inf;
      for (final nb in neighbours(blank, n)) {
        if (nb == prev) continue;
        final v = t[nb];
        final gcell = v - 1;
        final before = (nb % n - gcell % n).abs() + (nb ~/ n - gcell ~/ n).abs();
        final after = (blank % n - gcell % n).abs() + (blank ~/ n - gcell ~/ n).abs();
        final oldBlank = blank;
        t[oldBlank] = v;
        t[nb] = 0;
        blank = nb;
        md += after - before;
        path.add(nb);
        final r = search(g + 1, bound, oldBlank);
        if (found) return r;
        path.removeLast();
        md -= after - before;
        blank = oldBlank;
        t[nb] = v;
        t[oldBlank] = 0;
        if (r < min) min = r;
      }
      return min;
    }

    var bound = heuristic(t, n);
    while (true) {
      final r = search(0, bound, -1);
      if (found) return List.unmodifiable(path);
      if (r >= inf || (nodeBudget != null && nodes > nodeBudget)) return null;
      bound = r;
    }
  }

  // -------------------------------------------------------------------------
  // Staged solver for 4×4 and larger.

  /// A (non-optimal) solution for any solvable board, found quickly.
  static List<int> staged(List<int> start, int n) {
    final t = List<int>.from(start);
    final locked = List<bool>.filled(n * n, false);
    final moves = <int>[];

    void play(List<int> cells) {
      for (final c in cells) {
        final b = t.indexOf(0);
        t[b] = t[c];
        t[c] = 0;
        moves.add(c);
      }
    }

    for (var k = 0; k + 3 < n; k++) {
      // Top row of the remaining region, then its left column; the last two
      // cells of each line are placed together.
      final rowCells = [for (var c = k; c < n; c++) k * n + c];
      final colCells = [for (var r = k + 1; r < n; r++) r * n + k];
      for (final line in [rowCells, colCells]) {
        final groups = <List<int>>[
          for (var i = 0; i < line.length - 2; i++) [line[i]],
          line.sublist(line.length - 2),
        ];
        for (final group in groups) {
          play(_placeGroup(t, n, locked, group));
          for (final c in group) {
            locked[c] = true;
          }
        }
      }
    }
    // Finish the bottom-right 3×3 optimally.
    final o = n - 3;
    final local = List<int>.filled(9, 0);
    for (var r = 0; r < 3; r++) {
      for (var c = 0; c < 3; c++) {
        final v = t[(o + r) * n + o + c];
        if (v == 0) {
          local[r * 3 + c] = 0;
        } else {
          final g = v - 1;
          local[r * 3 + c] = (g ~/ n - o) * 3 + (g % n - o) + 1;
        }
      }
    }
    final sub = optimal(local, 3)!;
    play([for (final c in sub) (o + c ~/ 3) * n + o + c % 3]);
    return List.unmodifiable(_cancel(moves, start.indexOf(0)));
  }

  /// Removes immediate back-and-forth pairs (a move straight back into the
  /// cell the blank just left).
  static List<int> _cancel(List<int> moves, int startBlank) {
    final out = <int>[];
    final blankBefore = <int>[];
    var blank = startBlank;
    for (final m in moves) {
      if (out.isNotEmpty && m == blankBefore.last) {
        out.removeLast();
        blankBefore.removeLast();
      } else {
        out.add(m);
        blankBefore.add(blank);
      }
      blank = m;
    }
    return out;
  }

  /// Shortest blank moves bringing the tiles meant for [targets] onto them
  /// without touching [locked] cells (BFS over blank + group positions).
  static List<int> _placeGroup(List<int> t, int n, List<bool> locked, List<int> targets) {
    final size = n * n;
    final tiles = [for (final c in targets) c + 1];
    final g = tiles.length;
    int enc(int blank, List<int> pos) {
      var k = blank;
      for (final p in pos) {
        k = k * size + p;
      }
      return k;
    }

    final startPos = [for (final v in tiles) t.indexOf(v)];
    final startBlank = t.indexOf(0);
    bool done(List<int> pos) {
      for (var i = 0; i < g; i++) {
        if (pos[i] != targets[i]) return false;
      }
      return true;
    }

    if (done(startPos)) return const [];
    final parent = <int, int>{};
    final moveOf = <int, int>{};
    final startKey = enc(startBlank, startPos);
    parent[startKey] = -1;
    final queue = <(int, List<int>)>[(startBlank, startPos)];
    var head = 0;
    while (head < queue.length) {
      final (blank, pos) = queue[head++];
      final key = enc(blank, pos);
      for (final nb in neighbours(blank, n)) {
        if (locked[nb]) continue;
        final np = List<int>.from(pos);
        for (var i = 0; i < g; i++) {
          if (np[i] == nb) np[i] = blank;
        }
        final nk = enc(nb, np);
        if (parent.containsKey(nk)) continue;
        parent[nk] = key;
        moveOf[nk] = nb;
        if (done(np)) {
          final path = <int>[];
          var k = nk;
          while (parent[k] != -1) {
            path.add(moveOf[k]!);
            k = parent[k]!;
          }
          return path.reversed.toList();
        }
        queue.add((nb, np));
      }
    }
    throw StateError('sliding: group unreachable');
  }

  /// Best available solution: optimal within [nodeBudget] (always for
  /// 3×3), else staged.
  static ({List<int> moves, bool optimal}) solve(List<int> tiles, int n, {int nodeBudget = 60000}) {
    if (n <= 3) return (moves: optimal(tiles, n)!, optimal: true);
    final best = optimal(tiles, n, nodeBudget: nodeBudget);
    if (best != null) return (moves: best, optimal: true);
    return (moves: staged(tiles, n), optimal: false);
  }
}

final class SlidingConfig {
  const SlidingConfig({this.size = 4, this.difficulty = PuzzleDifficulty.medium, this.seed = 0})
    : assert(size >= 3 && size <= 5);

  final int size;
  final PuzzleDifficulty difficulty;
  final int seed;

  Map<String, Object?> toJson() => {'size': size, 'difficulty': difficulty.name, 'seed': seed};

  factory SlidingConfig.fromJson(Map<String, Object?> j) => SlidingConfig(
    size: jsonInt(j, 'size', 4),
    difficulty: PuzzleDifficulty.values.byName(j['difficulty']! as String),
    seed: jsonInt(j, 'seed'),
  );
}

final class SlidingState extends PuzzleState {
  const SlidingState({required this.tiles, this.moves = 0});

  final List<int> tiles;

  /// Tiles moved so far.
  final int moves;

  int get blank => tiles.indexOf(0);

  @override
  Map<String, Object?> toJson() => {'tiles': tiles, 'moves': moves};

  factory SlidingState.fromJson(Map<String, Object?> j) =>
      SlidingState(tiles: List.unmodifiable(jsonInts(j['tiles'])), moves: jsonInt(j, 'moves'));
}

/// Slides the tile at [cell] – and every tile between it and the blank when
/// they share a row or column – towards the blank.
final class SlidingAction extends PuzzleAction {
  const SlidingAction(this.cell);

  final int cell;

  @override
  Map<String, Object?> toJson() => {'c': cell};

  factory SlidingAction.fromJson(Map<String, Object?> j) => SlidingAction(jsonInt(j, 'c'));

  @override
  bool operator ==(Object other) => other is SlidingAction && other.cell == cell;

  @override
  int get hashCode => cell.hashCode;

  @override
  String toString() => 'SlidingAction($cell)';
}

/// A sliding-tiles game.
final class SlidingGame extends PuzzleBase<SlidingState, SlidingAction> {
  SlidingGame._(this.config, super.initial, {super.history});

  factory SlidingGame(SlidingConfig config) =>
      SlidingGame._(config, SlidingState(tiles: List.unmodifiable(deal(config))));

  /// A game over explicit [tiles] (must be solvable).
  factory SlidingGame.fromTiles(List<int> tiles) {
    final n = _sqrt(tiles.length);
    if (!SlidingSolver.isSolvable(tiles, n)) throw ArgumentError('unsolvable permutation');
    return SlidingGame._(SlidingConfig(size: n), SlidingState(tiles: List.unmodifiable(tiles)));
  }

  factory SlidingGame.fromJson(Map<String, Object?> json) {
    checkKind(json, PuzzleKind.slidingTiles);
    return SlidingGame._(
      SlidingConfig.fromJson(jsonObject(json['config'])),
      SlidingState.fromJson(jsonObject(json['state'])),
      history: jsonHistory(json, SlidingState.fromJson),
    );
  }

  static int _sqrt(int len) {
    var n = 1;
    while (n * n < len) {
      n++;
    }
    return n;
  }

  final SlidingConfig config;

  List<int>? _plan;
  List<int>? _planFor;
  bool _planOptimal = false;

  @override
  PuzzleKind get kind => PuzzleKind.slidingTiles;

  int get size => config.size;

  /// Deals a solvable, unsolved board.
  ///
  /// Easy / medium boards are random walks of 3n² / 8n² blank moves from
  /// the goal; hard boards are long walks (40n²) and expert boards are
  /// uniformly random solvable permutations.
  static List<int> deal(SlidingConfig config) {
    final n = config.size;
    final rng = SeededRng(config.seed);
    final goal = SlidingSolver.goal(n);
    while (true) {
      List<int> tiles;
      if (config.difficulty == PuzzleDifficulty.expert) {
        tiles = List<int>.from(goal);
        rng.shuffle(tiles);
        if (!SlidingSolver.isSolvable(tiles, n)) {
          final a = tiles.indexWhere((v) => v != 0);
          final b = tiles.indexWhere((v) => v != 0, a + 1);
          final tmp = tiles[a];
          tiles[a] = tiles[b];
          tiles[b] = tmp;
        }
      } else {
        final steps = switch (config.difficulty) {
          PuzzleDifficulty.easy => 3 * n * n,
          PuzzleDifficulty.medium => 8 * n * n,
          _ => 40 * n * n,
        };
        tiles = List<int>.from(goal);
        var blank = n * n - 1, prev = -1;
        for (var i = 0; i < steps; i++) {
          final options = SlidingSolver.neighbours(blank, n).where((c) => c != prev).toList();
          final nb = rng.pick(options);
          tiles[blank] = tiles[nb];
          tiles[nb] = 0;
          prev = blank;
          blank = nb;
        }
      }
      if (!sameList(tiles, goal)) return tiles;
    }
  }

  @override
  SlidingState? transition(SlidingState s, SlidingAction a) {
    final n = size;
    if (a.cell < 0 || a.cell >= n * n) return null;
    final blank = s.blank;
    if (a.cell == blank) return null;
    final sameRow = a.cell ~/ n == blank ~/ n, sameCol = a.cell % n == blank % n;
    if (!sameRow && !sameCol) return null;
    final step = sameRow ? (a.cell > blank ? 1 : -1) : (a.cell > blank ? n : -n);
    final t = List<int>.from(s.tiles);
    var b = blank, moved = 0;
    while (b != a.cell) {
      t[b] = t[b + step];
      t[b + step] = 0;
      b += step;
      moved++;
    }
    return SlidingState(tiles: List.unmodifiable(t), moves: s.moves + moved);
  }

  @override
  bool get isSolved => sameList(state.tiles, SlidingSolver.goal(size));

  @override
  bool get isOver => isSolved;

  /// A full solution from the current board (cached between hints).
  List<int> solution() {
    if (_planFor != null && sameList(_planFor!, state.tiles)) return _plan!;
    final r = SlidingSolver.solve(state.tiles, size);
    _plan = r.moves;
    _planOptimal = r.optimal;
    _planFor = state.tiles;
    return r.moves;
  }

  @override
  PuzzleHint<SlidingAction>? hint() {
    if (isSolved) return null;
    final plan = solution();
    if (plan.isEmpty) return null;
    return PuzzleHint(SlidingAction(plan.first), technique: _planOptimal ? 'optimal' : 'staged', focus: [plan.first]);
  }

  @override
  Map<String, Object?> configJson() => config.toJson();
}

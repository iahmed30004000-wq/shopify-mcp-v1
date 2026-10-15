/// Lights Out: pressing a light toggles it and its orthogonal neighbours;
/// the goal is to switch every light off.
///
/// Boards are generated as `A·x` for a random press vector `x` (so they are
/// always solvable), and solved exactly by Gaussian elimination over GF(2).
/// On 5×5 the press matrix has a 2-dimensional null space, so every
/// solvable board has four solutions; the solver returns the one with the
/// fewest presses (the par).
library;

import '../core/puzzle_game.dart';
import '../core/seeded_rng.dart';

/// A fixed-length bit vector over GF(2) (32-bit words, web safe).
final class Gf2Vector {
  Gf2Vector(this.length) : _w = List<int>.filled((length + 31) >> 5, 0);
  Gf2Vector._(this.length, this._w);

  factory Gf2Vector.fromBools(List<bool> bits) {
    final v = Gf2Vector(bits.length);
    for (var i = 0; i < bits.length; i++) {
      if (bits[i]) v.set(i);
    }
    return v;
  }

  final int length;
  final List<int> _w;

  bool operator [](int i) => (_w[i >> 5] >> (i & 31)) & 1 == 1;
  void set(int i) => _w[i >> 5] |= 1 << (i & 31);
  void flip(int i) => _w[i >> 5] ^= 1 << (i & 31);

  void xorWith(Gf2Vector o) {
    for (var k = 0; k < _w.length; k++) {
      _w[k] ^= o._w[k];
    }
  }

  Gf2Vector copy() => Gf2Vector._(length, List<int>.from(_w));

  bool get isZero => _w.every((w) => w == 0);

  int get weight {
    var n = 0;
    for (var i = 0; i < length; i++) {
      if (this[i]) n++;
    }
    return n;
  }

  List<bool> toBools() => [for (var i = 0; i < length; i++) this[i]];
}

/// Linear algebra of the press matrix for a rows×cols board.
final class LightsOutAlgebra {
  LightsOutAlgebra(this.rows, this.cols) : n = rows * cols {
    // Row-reduce [A | I] to learn a particular-solution operator and the
    // null space. A is symmetric, so column j of A is the effect of press j.
    final a = [for (var i = 0; i < n; i++) _pressVector(i)];
    final track = [for (var i = 0; i < n; i++) Gf2Vector(n)..set(i)];
    var row = 0;
    final pivotCols = <int>[];
    for (var col = 0; col < n && row < n; col++) {
      var p = -1;
      for (var r = row; r < n; r++) {
        if (a[r][col]) {
          p = r;
          break;
        }
      }
      if (p < 0) continue;
      _swap(a, row, p);
      _swap(track, row, p);
      for (var r = 0; r < n; r++) {
        if (r != row && a[r][col]) {
          a[r].xorWith(a[row]);
          track[r].xorWith(track[row]);
        }
      }
      pivotCols.add(col);
      row++;
    }
    rank = row;
    _reduced = a;
    _track = track;
    _pivotCols = pivotCols;
    // Rows rank..n-1 of `track` span the left null space; by symmetry of A
    // they also span the (right) null space.
    nullSpace = List.unmodifiable([for (var r = rank; r < n; r++) track[r]]);
  }

  final int rows;
  final int cols;
  final int n;
  late final int rank;
  late final List<Gf2Vector> _reduced;
  late final List<Gf2Vector> _track;
  late final List<int> _pivotCols;
  late final List<Gf2Vector> nullSpace;

  static void _swap(List<Gf2Vector> l, int i, int j) {
    final t = l[i];
    l[i] = l[j];
    l[j] = t;
  }

  static final Map<int, LightsOutAlgebra> _cache = {};

  static LightsOutAlgebra of(int rows, int cols) => _cache[rows * 1000 + cols] ??= LightsOutAlgebra(rows, cols);

  /// Cells toggled by pressing [i].
  List<int> toggles(int i) {
    final x = i % cols, y = i ~/ cols;
    return [
      i,
      if (y > 0) i - cols,
      if (y < rows - 1) i + cols,
      if (x > 0) i - 1,
      if (x < cols - 1) i + 1,
    ];
  }

  Gf2Vector _pressVector(int i) {
    final v = Gf2Vector(n);
    for (final c in toggles(i)) {
      v.set(c);
    }
    return v;
  }

  /// The board produced from all-off by [presses].
  Gf2Vector apply(Gf2Vector presses) {
    final out = Gf2Vector(n);
    for (var i = 0; i < n; i++) {
      if (presses[i]) {
        for (final c in toggles(i)) {
          out.flip(c);
        }
      }
    }
    return out;
  }

  /// Whether [board] can be switched off (orthogonal to the null space).
  bool isSolvable(Gf2Vector board) {
    for (final z in nullSpace) {
      var dot = false;
      for (var i = 0; i < n; i++) {
        if (z[i] && board[i]) dot = !dot;
      }
      if (dot) return false;
    }
    return true;
  }

  /// A press vector that switches [board] off, with the fewest presses
  /// among all solutions (exhaustive over the null space when it is small).
  Gf2Vector? solve(Gf2Vector board) {
    // E·A = R (reduced); solve R·x = E·b.
    final eb = Gf2Vector(n);
    for (var r = 0; r < n; r++) {
      var dot = false;
      for (var i = 0; i < n; i++) {
        if (_track[r][i] && board[i]) dot = !dot;
      }
      if (dot) eb.set(r);
    }
    for (var r = rank; r < n; r++) {
      if (eb[r]) return null;
    }
    final x = Gf2Vector(n);
    for (var r = 0; r < rank; r++) {
      if (eb[r]) x.set(_pivotCols[r]);
    }
    assert(_reduced.isNotEmpty);
    if (nullSpace.isEmpty || nullSpace.length > 16) return x;
    var best = x;
    var bestW = x.weight;
    for (var mask = 1; mask < (1 << nullSpace.length); mask++) {
      final y = x.copy();
      for (var k = 0; k < nullSpace.length; k++) {
        if (mask & (1 << k) != 0) y.xorWith(nullSpace[k]);
      }
      final w = y.weight;
      if (w < bestW) {
        best = y;
        bestW = w;
      }
    }
    return best;
  }
}

final class LightsOutConfig {
  const LightsOutConfig({this.rows = 5, this.cols = 5, this.difficulty = PuzzleDifficulty.medium, this.seed = 0})
    : assert(rows >= 2 && cols >= 2 && rows * cols <= 400);

  final int rows;
  final int cols;
  final PuzzleDifficulty difficulty;
  final int seed;

  /// Presses used to build the board (expert: every cell with p = ½).
  int? get presses => switch (difficulty) {
    PuzzleDifficulty.easy => 4,
    PuzzleDifficulty.medium => 8,
    PuzzleDifficulty.hard => 12,
    PuzzleDifficulty.expert => null,
  };

  Map<String, Object?> toJson() => {'rows': rows, 'cols': cols, 'difficulty': difficulty.name, 'seed': seed};

  factory LightsOutConfig.fromJson(Map<String, Object?> j) => LightsOutConfig(
    rows: jsonInt(j, 'rows', 5),
    cols: jsonInt(j, 'cols', 5),
    difficulty: PuzzleDifficulty.values.byName(j['difficulty']! as String),
    seed: jsonInt(j, 'seed'),
  );
}

final class LightsOutState extends PuzzleState {
  const LightsOutState({required this.lights, this.moves = 0});

  final List<bool> lights;
  final int moves;

  int get lit => lights.where((l) => l).length;

  @override
  Map<String, Object?> toJson() => {
    'lights': [for (final l in lights) l ? 1 : 0],
    'moves': moves,
  };

  factory LightsOutState.fromJson(Map<String, Object?> j) => LightsOutState(
    lights: List.unmodifiable([for (final v in jsonInts(j['lights'])) v == 1]),
    moves: jsonInt(j, 'moves'),
  );
}

final class LightsOutAction extends PuzzleAction {
  const LightsOutAction(this.cell);
  final int cell;

  @override
  Map<String, Object?> toJson() => {'c': cell};

  factory LightsOutAction.fromJson(Map<String, Object?> j) => LightsOutAction(jsonInt(j, 'c'));

  @override
  bool operator ==(Object other) => other is LightsOutAction && other.cell == cell;

  @override
  int get hashCode => cell.hashCode;

  @override
  String toString() => 'LightsOutAction($cell)';
}

/// A Lights Out game.
final class LightsOutGame extends PuzzleBase<LightsOutState, LightsOutAction> {
  LightsOutGame._(this.config, this.par, super.initial, {super.history})
    : algebra = LightsOutAlgebra.of(config.rows, config.cols);

  factory LightsOutGame(LightsOutConfig config) {
    final algebra = LightsOutAlgebra.of(config.rows, config.cols);
    final rng = SeededRng(config.seed);
    while (true) {
      final x = Gf2Vector(algebra.n);
      final k = config.presses;
      if (k == null) {
        for (var i = 0; i < algebra.n; i++) {
          if (rng.nextBool()) x.set(i);
        }
      } else {
        final cells = List<int>.generate(algebra.n, (i) => i);
        rng.shuffle(cells);
        for (final c in cells.take(k.clamp(1, algebra.n))) {
          x.set(c);
        }
      }
      final board = algebra.apply(x);
      if (board.isZero) continue;
      final par = algebra.solve(board)!.weight;
      return LightsOutGame._(config, par, LightsOutState(lights: List.unmodifiable(board.toBools())));
    }
  }

  factory LightsOutGame.fromJson(Map<String, Object?> json) {
    checkKind(json, PuzzleKind.lightsOut);
    final config = LightsOutConfig.fromJson(jsonObject(json['config']));
    final state = LightsOutState.fromJson(jsonObject(json['state']));
    final history = jsonHistory(json, LightsOutState.fromJson);
    final algebra = LightsOutAlgebra.of(config.rows, config.cols);
    final first = history.isEmpty ? state : history.first;
    final par = algebra.solve(Gf2Vector.fromBools(first.lights))?.weight ?? 0;
    return LightsOutGame._(config, jsonInt(jsonObject(json['config']), 'par', par), state, history: history);
  }

  final LightsOutConfig config;
  final LightsOutAlgebra algebra;

  /// Fewest presses solving the initial board.
  final int par;

  @override
  PuzzleKind get kind => PuzzleKind.lightsOut;

  @override
  LightsOutState? transition(LightsOutState s, LightsOutAction a) {
    if (a.cell < 0 || a.cell >= algebra.n || isSolved) return null;
    final l = List<bool>.from(s.lights);
    for (final c in algebra.toggles(a.cell)) {
      l[c] = !l[c];
    }
    return LightsOutState(lights: List.unmodifiable(l), moves: s.moves + 1);
  }

  @override
  bool get isSolved => !state.lights.contains(true);

  @override
  bool get isOver => isSolved;

  /// The minimum set of presses that clears the current board.
  List<int> solution() {
    final x = algebra.solve(Gf2Vector.fromBools(state.lights));
    if (x == null) return const [];
    return [
      for (var i = 0; i < algebra.n; i++)
        if (x[i]) i,
    ];
  }

  @override
  PuzzleHint<LightsOutAction>? hint() {
    if (isSolved) return null;
    final s = solution();
    if (s.isEmpty) return null;
    return PuzzleHint(LightsOutAction(s.first), technique: 'linearAlgebra', focus: s);
  }

  @override
  Map<String, Object?> configJson() => {...config.toJson(), 'par': par};
}

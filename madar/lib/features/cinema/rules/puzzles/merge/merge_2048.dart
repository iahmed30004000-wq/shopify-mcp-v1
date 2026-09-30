/// 2048: slide numbered tiles, equal tiles merge once per move.
///
/// Rules implemented:
/// * every tile slides as far as possible in the chosen direction;
/// * two equal tiles meeting merge into their sum, merges resolve from the
///   leading edge (`[2,2,2,2]` → `[4,4,0,0]`) and a merged tile never merges
///   again in the same move (`[4,4,8,0]` → `[8,8,0,0]`);
/// * the score grows by the value of each merged tile;
/// * a move that changes nothing is illegal and spawns nothing;
/// * after each legal move one tile spawns on a random empty cell:
///   a 2, or a 4 with probability [Merge2048Config.fourPermille] / 1000;
/// * reaching [Merge2048Config.target] wins (the player may keep playing);
///   no legal move left loses.
library;

import 'dart:math' as math;

import '../core/grid.dart';
import '../core/puzzle_game.dart';
import '../core/seeded_rng.dart';

/// Immutable configuration of a 2048 game.
final class Merge2048Config {
  const Merge2048Config({this.size = 4, this.target = 2048, this.fourPermille = 100, this.seed = 0})
    : assert(size >= 3 && size <= 8);

  /// Difficulty presets: the target tile and how often 4s spawn.
  factory Merge2048Config.forDifficulty(PuzzleDifficulty d, {int size = 4, int seed = 0}) => switch (d) {
    PuzzleDifficulty.easy => Merge2048Config(size: size, target: 512, fourPermille: 50, seed: seed),
    PuzzleDifficulty.medium => Merge2048Config(size: size, target: 1024, fourPermille: 100, seed: seed),
    PuzzleDifficulty.hard => Merge2048Config(size: size, target: 2048, fourPermille: 100, seed: seed),
    PuzzleDifficulty.expert => Merge2048Config(size: size, target: 4096, fourPermille: 200, seed: seed),
  };

  final int size;
  final int target;
  final int fourPermille;
  final int seed;

  Map<String, Object?> toJson() => {'size': size, 'target': target, 'four': fourPermille, 'seed': seed};

  factory Merge2048Config.fromJson(Map<String, Object?> j) => Merge2048Config(
    size: jsonInt(j, 'size', 4),
    target: jsonInt(j, 'target', 2048),
    fourPermille: jsonInt(j, 'four', 100),
    seed: jsonInt(j, 'seed'),
  );
}

/// Snapshot: tile values (0 = empty), score and the spawn RNG.
final class Merge2048State extends PuzzleState {
  const Merge2048State({
    required this.size,
    required this.cells,
    required this.score,
    required this.moves,
    required this.rng,
    this.won = false,
    this.keepPlaying = false,
    this.lastSpawn = -1,
    this.merged = const [],
  });

  final int size;
  final List<int> cells;
  final int score;
  final int moves;
  final List<int> rng;
  final bool won;
  final bool keepPlaying;

  /// Cell of the tile spawned by the last move (-1 when none).
  final int lastSpawn;

  /// Cells holding a tile produced by a merge in the last move.
  final List<int> merged;

  int at(int x, int y) => cells[y * size + x];

  int get maxTile => cells.fold(0, math.max);

  @override
  Map<String, Object?> toJson() => {
    'size': size,
    'cells': cells,
    'score': score,
    'moves': moves,
    'rng': rng,
    'won': won,
    'keep': keepPlaying,
    'spawn': lastSpawn,
    'merged': merged,
  };

  factory Merge2048State.fromJson(Map<String, Object?> j) => Merge2048State(
    size: jsonInt(j, 'size', 4),
    cells: jsonInts(j['cells']),
    score: jsonInt(j, 'score'),
    moves: jsonInt(j, 'moves'),
    rng: jsonInts(j['rng']),
    won: j['won'] == true,
    keepPlaying: j['keep'] == true,
    lastSpawn: jsonInt(j, 'spawn', -1),
    merged: jsonInts(j['merged']),
  );
}

enum Merge2048ActionType { slide, keepPlaying }

final class Merge2048Action extends PuzzleAction {
  const Merge2048Action.slide(Dir4 this.direction) : type = Merge2048ActionType.slide;
  const Merge2048Action.keepPlaying() : type = Merge2048ActionType.keepPlaying, direction = null;

  final Merge2048ActionType type;
  final Dir4? direction;

  @override
  Map<String, Object?> toJson() => {'t': type.name, if (direction != null) 'd': direction!.name};

  factory Merge2048Action.fromJson(Map<String, Object?> j) => j['t'] == Merge2048ActionType.keepPlaying.name
      ? const Merge2048Action.keepPlaying()
      : Merge2048Action.slide(Dir4.values.byName(j['d']! as String));

  @override
  bool operator ==(Object other) => other is Merge2048Action && other.type == type && other.direction == direction;

  @override
  int get hashCode => Object.hash(type, direction);

  @override
  String toString() => 'Merge2048Action(${type.name}${direction == null ? '' : ' ${direction!.name}'})';
}

/// Result of sliding one board (pure function, exposed for tests and AI).
final class SlideResult {
  const SlideResult(this.cells, this.gain, this.merged, this.changed);
  final List<int> cells;
  final int gain;
  final List<int> merged;
  final bool changed;
}

/// Slides a single line towards index 0.
({List<int> line, int gain, List<int> mergedAt}) slideLine(List<int> line) {
  final out = List<int>.filled(line.length, 0);
  final mergedAt = <int>[];
  var gain = 0;
  var w = 0;
  var canMerge = false;
  for (final v in line) {
    if (v == 0) continue;
    if (canMerge && out[w - 1] == v) {
      out[w - 1] = v * 2;
      gain += v * 2;
      mergedAt.add(w - 1);
      canMerge = false;
    } else {
      out[w++] = v;
      canMerge = true;
    }
  }
  return (line: out, gain: gain, mergedAt: mergedAt);
}

/// Slides a whole [size]×[size] board in [dir].
SlideResult slideBoard(List<int> cells, int size, Dir4 dir) {
  final out = List<int>.from(cells);
  final merged = <int>[];
  var gain = 0;
  for (var k = 0; k < size; k++) {
    // Cell indices of line k ordered from the leading edge.
    final idx = List<int>.generate(size, (i) {
      return switch (dir) {
        Dir4.left => k * size + i,
        Dir4.right => k * size + (size - 1 - i),
        Dir4.up => i * size + k,
        Dir4.down => (size - 1 - i) * size + k,
      };
    });
    final r = slideLine([for (final i in idx) cells[i]]);
    for (var i = 0; i < size; i++) {
      out[idx[i]] = r.line[i];
    }
    for (final m in r.mergedAt) {
      merged.add(idx[m]);
    }
    gain += r.gain;
  }
  return SlideResult(out, gain, merged, !sameList(out, cells));
}

/// True when some slide changes [cells].
bool anyMoveAvailable(List<int> cells, int size) {
  for (var i = 0; i < cells.length; i++) {
    final v = cells[i];
    if (v == 0) return true;
    final x = i % size, y = i ~/ size;
    if (x + 1 < size && cells[i + 1] == v) return true;
    if (y + 1 < size && cells[i + size] == v) return true;
  }
  return false;
}

/// A 2048 game.
final class Merge2048Game extends PuzzleBase<Merge2048State, Merge2048Action> {
  Merge2048Game._(this.config, super.initial, {super.history});

  /// A new game: two tiles spawned from [Merge2048Config.seed].
  factory Merge2048Game(Merge2048Config config) {
    final rng = SeededRng(config.seed);
    var cells = List<int>.filled(config.size * config.size, 0);
    var spawn = -1;
    for (var i = 0; i < 2; i++) {
      final s = _spawn(cells, rng, config.fourPermille);
      cells = s.cells;
      spawn = s.at;
    }
    return Merge2048Game._(
      config,
      Merge2048State(size: config.size, cells: cells, score: 0, moves: 0, rng: rng.state, lastSpawn: spawn),
    );
  }

  /// A game starting from explicit [cells] (tests / custom boards).
  factory Merge2048Game.fromCells(List<int> cells, {Merge2048Config config = const Merge2048Config(), int score = 0}) {
    final size = math.sqrt(cells.length).round();
    final cfg = Merge2048Config(size: size, target: config.target, fourPermille: config.fourPermille, seed: config.seed);
    return Merge2048Game._(
      cfg,
      Merge2048State(
        size: size,
        cells: List.unmodifiable(cells),
        score: score,
        moves: 0,
        rng: SeededRng(cfg.seed).state,
        won: cells.any((v) => v >= cfg.target),
      ),
    );
  }

  factory Merge2048Game.fromJson(Map<String, Object?> json) {
    checkKind(json, PuzzleKind.merge2048);
    return Merge2048Game._(
      Merge2048Config.fromJson(jsonObject(json['config'])),
      Merge2048State.fromJson(jsonObject(json['state'])),
      history: jsonHistory(json, Merge2048State.fromJson),
    );
  }

  final Merge2048Config config;

  @override
  PuzzleKind get kind => PuzzleKind.merge2048;

  static ({List<int> cells, int at}) _spawn(List<int> cells, SeededRng rng, int fourPermille) {
    final empty = [
      for (var i = 0; i < cells.length; i++)
        if (cells[i] == 0) i,
    ];
    if (empty.isEmpty) return (cells: cells, at: -1);
    final at = empty[rng.nextInt(empty.length)];
    final v = rng.nextInt(1000) < fourPermille ? 4 : 2;
    final out = List<int>.from(cells);
    out[at] = v;
    return (cells: List.unmodifiable(out), at: at);
  }

  @override
  Merge2048State? transition(Merge2048State s, Merge2048Action action) {
    switch (action.type) {
      case Merge2048ActionType.keepPlaying:
        if (!s.won || s.keepPlaying) return null;
        return Merge2048State(
          size: s.size,
          cells: s.cells,
          score: s.score,
          moves: s.moves,
          rng: s.rng,
          won: true,
          keepPlaying: true,
          lastSpawn: -1,
        );
      case Merge2048ActionType.slide:
        if (_over(s)) return null;
        final r = slideBoard(s.cells, s.size, action.direction!);
        if (!r.changed) return null;
        final rng = SeededRng.fromState(s.rng);
        final sp = _spawn(r.cells, rng, config.fourPermille);
        return Merge2048State(
          size: s.size,
          cells: sp.cells,
          score: s.score + r.gain,
          moves: s.moves + 1,
          rng: rng.state,
          won: s.won || r.cells.any((v) => v >= config.target),
          keepPlaying: s.keepPlaying,
          lastSpawn: sp.at,
          merged: List.unmodifiable(r.merged),
        );
    }
  }

  bool _over(Merge2048State s) => !anyMoveAvailable(s.cells, s.size) || (s.won && !s.keepPlaying);

  /// Directions that change the board.
  List<Dir4> legalDirections() => [
    for (final d in Dir4.values)
      if (slideBoard(state.cells, state.size, d).changed) d,
  ];

  @override
  bool get isSolved => state.won;

  /// True when the board is full and nothing can merge.
  bool get isLost => !anyMoveAvailable(state.cells, state.size);

  @override
  bool get isOver => _over(state);

  @override
  PuzzleHint<Merge2048Action>? hint() {
    final s = state;
    if (s.won && !s.keepPlaying) return const PuzzleHint(Merge2048Action.keepPlaying(), technique: 'keepPlaying');
    final d = bestDirection(s.cells, s.size);
    if (d == null) return null;
    return PuzzleHint(Merge2048Action.slide(d), technique: 'expectimax');
  }

  @override
  Map<String, Object?> configJson() => config.toJson();

  // -------------------------------------------------------------------------
  // Hint AI: depth-2 expectimax over the spawn distribution.

  /// The best slide by expectimax (null when no move is possible).
  static Dir4? bestDirection(List<int> cells, int size) {
    Dir4? best;
    var bestScore = double.negativeInfinity;
    for (final d in Dir4.values) {
      final r = slideBoard(cells, size, d);
      if (!r.changed) continue;
      final v = r.gain + _chance(r.cells, size, 1);
      if (v > bestScore) {
        bestScore = v;
        best = d;
      }
    }
    return best;
  }

  static double _chance(List<int> cells, int size, int depth) {
    final empty = [
      for (var i = 0; i < cells.length; i++)
        if (cells[i] == 0) i,
    ];
    if (empty.isEmpty) return _evaluate(cells, size);
    // Sample at most 6 empty cells deterministically to bound the cost.
    final stride = math.max(1, empty.length ~/ 6);
    var total = 0.0;
    var n = 0;
    for (var k = 0; k < empty.length; k += stride) {
      final i = empty[k];
      for (final (v, p) in const [(2, 0.9), (4, 0.1)]) {
        final next = List<int>.from(cells)..[i] = v;
        total += p * _max(next, size, depth - 1);
      }
      n++;
    }
    return total / n;
  }

  static double _max(List<int> cells, int size, int depth) {
    var best = double.negativeInfinity;
    for (final d in Dir4.values) {
      final r = slideBoard(cells, size, d);
      if (!r.changed) continue;
      final v = r.gain + (depth > 0 ? _chance(r.cells, size, depth) : _evaluate(r.cells, size));
      if (v > best) best = v;
    }
    return best == double.negativeInfinity ? -100000.0 : best;
  }

  static double _log2(int v) => v == 0 ? 0 : math.log(v) / math.ln2;

  /// Board heuristic: empty cells, monotonic rows/columns, smoothness and a
  /// large tile anchored in a corner.
  static double _evaluate(List<int> cells, int size) {
    var empty = 0;
    var smooth = 0.0;
    var monoRows = 0.0, monoCols = 0.0;
    for (var y = 0; y < size; y++) {
      var inc = 0.0, dec = 0.0;
      for (var x = 0; x < size; x++) {
        final v = cells[y * size + x];
        if (v == 0) empty++;
        if (x + 1 < size) {
          final a = _log2(v), b = _log2(cells[y * size + x + 1]);
          if (a > b) {
            dec += a - b;
          } else {
            inc += b - a;
          }
          if (v != 0 && cells[y * size + x + 1] != 0) smooth -= (a - b).abs();
        }
      }
      monoRows += math.min(inc, dec);
    }
    for (var x = 0; x < size; x++) {
      var inc = 0.0, dec = 0.0;
      for (var y = 0; y + 1 < size; y++) {
        final a = _log2(cells[y * size + x]), b = _log2(cells[(y + 1) * size + x]);
        if (a > b) {
          dec += a - b;
        } else {
          inc += b - a;
        }
        if (cells[y * size + x] != 0 && cells[(y + 1) * size + x] != 0) smooth -= (a - b).abs();
      }
      monoCols += math.min(inc, dec);
    }
    final maxV = cells.fold(0, math.max);
    final corners = [cells[0], cells[size - 1], cells[size * (size - 1)], cells[size * size - 1]];
    final cornerBonus = corners.contains(maxV) ? _log2(maxV) * 4 : 0.0;
    return empty * 27.0 + smooth * 1.0 - (monoRows + monoCols) * 4.7 + cornerBonus;
  }
}

/// Souk Jewels: a match-3 puzzle.
///
/// Rules:
/// * swapping two orthogonally adjacent gems is legal only when it lines up
///   three or more gems of one colour through a swapped cell, or when one of
///   them is a star gem;
/// * runs of 3+ clear; a run of 4 creates a line gem (a horizontal run
///   creates a column-clearing gem, a vertical run a row-clearing one), an
///   L/T crossing creates a bomb (3×3) and a run of 5+ creates a star gem;
///   specials are created on the swapped cell when it is part of the run,
///   otherwise in the middle of the run;
/// * a cleared special detonates (chains included); a swapped star clears
///   every gem of the other gem's colour (two stars clear the board) and a
///   star caught in a blast clears the most common colour;
/// * gems fall, new gems drop in from the seeded RNG, and matches cascade
///   with a growing multiplier (10 points × gems × cascade + bonuses);
/// * the board never starts with a match, always offers a move, and is
///   reshuffled (seeded) whenever no legal swap remains;
/// * reaching the target score wins; running out of moves ends the game.
library;

import '../core/puzzle_game.dart';
import '../core/seeded_rng.dart';

enum JewelSpecial { none, lineRow, lineColumn, bomb, star }

/// Gem encoding: `color + 8 × special`; -1 is an empty cell.
abstract final class Gem {
  static const int empty = -1;
  static const int starColor = 7;

  static int make(int color, [JewelSpecial special = JewelSpecial.none]) => color + 8 * special.index;
  static int color(int g) => g % 8;
  static JewelSpecial special(int g) => JewelSpecial.values[g ~/ 8];
  static int star() => make(starColor, JewelSpecial.star);
}

final class JewelsConfig {
  const JewelsConfig({
    this.width = 8,
    this.height = 8,
    this.colors = 6,
    this.moves = 25,
    this.target = 1500,
    this.seed = 0,
  }) : assert(colors >= 4 && colors <= 7 && width >= 5 && height >= 5);

  factory JewelsConfig.forDifficulty(PuzzleDifficulty d, {int seed = 0}) => switch (d) {
    PuzzleDifficulty.easy => JewelsConfig(colors: 5, moves: 30, target: 1000, seed: seed),
    PuzzleDifficulty.medium => JewelsConfig(colors: 6, moves: 25, target: 1500, seed: seed),
    PuzzleDifficulty.hard => JewelsConfig(colors: 6, moves: 22, target: 2000, seed: seed),
    PuzzleDifficulty.expert => JewelsConfig(colors: 7, moves: 20, target: 2200, seed: seed),
  };

  final int width;
  final int height;
  final int colors;
  final int moves;
  final int target;
  final int seed;

  Map<String, Object?> toJson() => {
    'w': width,
    'h': height,
    'colors': colors,
    'moves': moves,
    'target': target,
    'seed': seed,
  };

  factory JewelsConfig.fromJson(Map<String, Object?> j) => JewelsConfig(
    width: jsonInt(j, 'w', 8),
    height: jsonInt(j, 'h', 8),
    colors: jsonInt(j, 'colors', 6),
    moves: jsonInt(j, 'moves', 25),
    target: jsonInt(j, 'target', 1500),
    seed: jsonInt(j, 'seed'),
  );
}

/// One wave of a move's resolution (for animation).
final class JewelStep {
  const JewelStep({required this.cascade, required this.cleared, required this.created, required this.points});
  final int cascade;
  final List<int> cleared;

  /// Cells that became special gems in this wave: cell → gem.
  final Map<int, int> created;
  final int points;
}

final class JewelsState extends PuzzleState {
  const JewelsState({
    required this.board,
    required this.rng,
    required this.movesLeft,
    this.score = 0,
    this.moves = 0,
    this.shuffles = 0,
    this.lastSteps = const [],
  });

  final List<int> board;
  final List<int> rng;
  final int movesLeft;
  final int score;
  final int moves;

  /// Automatic reshuffles so far.
  final int shuffles;

  /// Resolution waves of the last move (not serialised).
  final List<JewelStep> lastSteps;

  @override
  Map<String, Object?> toJson() => {
    'board': board,
    'rng': rng,
    'left': movesLeft,
    'score': score,
    'moves': moves,
    'shuffles': shuffles,
  };

  factory JewelsState.fromJson(Map<String, Object?> j) => JewelsState(
    board: List.unmodifiable(jsonInts(j['board'])),
    rng: jsonInts(j['rng']),
    movesLeft: jsonInt(j, 'left'),
    score: jsonInt(j, 'score'),
    moves: jsonInt(j, 'moves'),
    shuffles: jsonInt(j, 'shuffles'),
  );
}

/// Swaps cell [a] with its neighbour [b].
final class JewelsAction extends PuzzleAction {
  const JewelsAction(this.a, this.b);
  final int a;
  final int b;

  @override
  Map<String, Object?> toJson() => {'a': a, 'b': b};

  factory JewelsAction.fromJson(Map<String, Object?> j) => JewelsAction(jsonInt(j, 'a'), jsonInt(j, 'b'));

  @override
  bool operator ==(Object other) => other is JewelsAction && other.a == a && other.b == b;

  @override
  int get hashCode => Object.hash(a, b);

  @override
  String toString() => 'JewelsAction($a, $b)';
}

/// Pure board logic.
final class JewelsBoard {
  const JewelsBoard(this.width, this.height, this.colors);

  final int width;
  final int height;
  final int colors;

  int get length => width * height;

  bool adjacent(int a, int b) {
    if (a < 0 || b < 0 || a >= length || b >= length) return false;
    final ax = a % width, ay = a ~/ width, bx = b % width, by = b ~/ width;
    return (ax - bx).abs() + (ay - by).abs() == 1;
  }

  int _c(List<int> board, int i) => board[i] < 0 ? -1 : Gem.color(board[i]);

  /// Horizontal and vertical runs of 3+ equal colours.
  List<({List<int> cells, bool horizontal})> runs(List<int> board) {
    final out = <({List<int> cells, bool horizontal})>[];
    for (final horizontal in const [true, false]) {
      final lines = horizontal ? height : width;
      final len = horizontal ? width : height;
      for (var l = 0; l < lines; l++) {
        var start = 0;
        while (start < len) {
          int at(int k) => horizontal ? l * width + k : k * width + l;
          final c = _c(board, at(start));
          var end = start + 1;
          while (end < len && c >= 0 && c != Gem.starColor && _c(board, at(end)) == c) {
            end++;
          }
          if (c >= 0 && c != Gem.starColor && end - start >= 3) {
            out.add((cells: [for (var k = start; k < end; k++) at(k)], horizontal: horizontal));
          }
          start = end;
        }
      }
    }
    return out;
  }

  bool hasMatch(List<int> board) => runs(board).isNotEmpty;

  /// Whether swapping [a] and [b] is a legal move.
  bool isValidSwap(List<int> board, int a, int b) {
    if (!adjacent(a, b) || board[a] < 0 || board[b] < 0) return false;
    if (Gem.special(board[a]) == JewelSpecial.star || Gem.special(board[b]) == JewelSpecial.star) return true;
    final t = List<int>.from(board);
    t[a] = board[b];
    t[b] = board[a];
    return _matchThrough(t, a) || _matchThrough(t, b);
  }

  bool _matchThrough(List<int> board, int i) {
    final c = _c(board, i);
    if (c < 0 || c == Gem.starColor) return false;
    final x = i % width, y = i ~/ width;
    var h = 1;
    for (var k = x - 1; k >= 0 && _c(board, y * width + k) == c; k--) {
      h++;
    }
    for (var k = x + 1; k < width && _c(board, y * width + k) == c; k++) {
      h++;
    }
    if (h >= 3) return true;
    var v = 1;
    for (var k = y - 1; k >= 0 && _c(board, k * width + x) == c; k--) {
      v++;
    }
    for (var k = y + 1; k < height && _c(board, k * width + x) == c; k++) {
      v++;
    }
    return v >= 3;
  }

  /// Every legal swap (each pair once, right and down neighbours).
  List<(int, int)> validSwaps(List<int> board) {
    final out = <(int, int)>[];
    for (var i = 0; i < length; i++) {
      final x = i % width, y = i ~/ width;
      if (x + 1 < width && isValidSwap(board, i, i + 1)) out.add((i, i + 1));
      if (y + 1 < height && isValidSwap(board, i, i + width)) out.add((i, i + width));
    }
    return out;
  }

  bool hasValidMove(List<int> board) {
    for (var i = 0; i < length; i++) {
      final x = i % width, y = i ~/ width;
      if (x + 1 < width && isValidSwap(board, i, i + 1)) return true;
      if (y + 1 < height && isValidSwap(board, i, i + width)) return true;
    }
    return false;
  }

  /// A board with no match and at least one legal move.
  List<int> fresh(SeededRng rng) {
    while (true) {
      final b = List<int>.filled(length, 0);
      for (var i = 0; i < length; i++) {
        final x = i % width, y = i ~/ width;
        final banned = <int>{
          if (x >= 2 && Gem.color(b[i - 1]) == Gem.color(b[i - 2])) Gem.color(b[i - 1]),
          if (y >= 2 && Gem.color(b[i - width]) == Gem.color(b[i - 2 * width])) Gem.color(b[i - width]),
        };
        final options = [
          for (var c = 0; c < colors; c++)
            if (!banned.contains(c)) c,
        ];
        b[i] = rng.pick(options);
      }
      if (hasValidMove(b)) return b;
    }
  }

  /// Rearranges the gems (keeping specials) into a board with no match and
  /// a legal move; recolours plain gems if permutations keep failing.
  List<int> reshuffle(List<int> board, SeededRng rng) {
    final gems = List<int>.from(board);
    for (var attempt = 0; attempt < 200; attempt++) {
      rng.shuffle(gems);
      if (!hasMatch(gems) && hasValidMove(gems)) return gems;
    }
    return fresh(rng);
  }

  /// Plays the swap [a]↔[b] (must be valid) and resolves every cascade.
  ({List<int> board, int points, List<JewelStep> steps}) resolve(List<int> start, int a, int b, SeededRng rng) {
    final board = List<int>.from(start);
    final ga = board[a], gb = board[b];
    board[a] = gb;
    board[b] = ga;
    final steps = <JewelStep>[];
    var points = 0;
    var cascade = 0;
    Set<int>? pending;
    final starA = Gem.special(gb) == JewelSpecial.star; // now at a
    final starB = Gem.special(ga) == JewelSpecial.star; // now at b
    if (starA || starB) {
      if (starA && starB) {
        pending = {for (var i = 0; i < length; i++) i};
      } else {
        final starCell = starA ? a : b;
        final other = starA ? b : a;
        final color = Gem.color(board[other]);
        pending = {
          starCell,
          for (var i = 0; i < length; i++)
            if (board[i] >= 0 && Gem.color(board[i]) == color && Gem.special(board[i]) != JewelSpecial.star) i,
        };
      }
    }
    final swapped = {a, b};
    final swappedStars = {if (starA) a, if (starB) b};
    while (true) {
      final created = <int, int>{};
      var clear = pending;
      pending = null;
      if (clear == null) {
        final rs = runs(board);
        if (rs.isEmpty) break;
        clear = <int>{};
        final inRun = <int, int>{};
        for (var r = 0; r < rs.length; r++) {
          clear.addAll(rs[r].cells);
          for (final c in rs[r].cells) {
            inRun.update(c, (v) => v + 1, ifAbsent: () => 1);
          }
        }
        for (final run in rs) {
          final color = Gem.color(board[run.cells.first]);
          final crossing = run.cells.where((c) => inRun[c]! > 1).toList();
          int spot() {
            final s = run.cells.where(swapped.contains).toList();
            if (s.isNotEmpty && cascade == 0) return s.first;
            return run.cells[run.cells.length ~/ 2];
          }

          if (run.cells.length >= 5) {
            created[spot()] = Gem.star();
          } else if (crossing.isNotEmpty) {
            if (!created.containsKey(crossing.first)) created[crossing.first] = Gem.make(color, JewelSpecial.bomb);
          } else if (run.cells.length == 4) {
            final s = spot();
            if (!created.containsKey(s)) {
              created[s] = Gem.make(color, run.horizontal ? JewelSpecial.lineColumn : JewelSpecial.lineRow);
            }
          }
        }
      }
      cascade++;
      // Detonate specials among the cleared gems (chains included).
      final cleared = <int>{};
      final queue = [...clear];
      while (queue.isNotEmpty) {
        final c = queue.removeLast();
        if (!cleared.add(c) || board[c] < 0) continue;
        if (created.containsKey(c)) continue;
        final sp = Gem.special(board[c]);
        final x = c % width, y = c ~/ width;
        switch (sp) {
          case JewelSpecial.none:
            break;
          case JewelSpecial.lineRow:
            for (var k = 0; k < width; k++) {
              queue.add(y * width + k);
            }
          case JewelSpecial.lineColumn:
            for (var k = 0; k < height; k++) {
              queue.add(k * width + x);
            }
          case JewelSpecial.bomb:
            for (var dy = -1; dy <= 1; dy++) {
              for (var dx = -1; dx <= 1; dx++) {
                final nx = x + dx, ny = y + dy;
                if (nx >= 0 && ny >= 0 && nx < width && ny < height) queue.add(ny * width + nx);
              }
            }
          case JewelSpecial.star:
            // The swapped star already did its job; a star caught in a
            // blast clears the most common colour.
            if (!(cascade == 1 && swappedStars.contains(c))) {
              final color = _commonestColor(board);
              for (var i = 0; i < length; i++) {
                if (board[i] >= 0 && Gem.color(board[i]) == color) queue.add(i);
              }
            }
        }
      }
      cleared.removeWhere((c) => created.containsKey(c) || board[c] < 0);
      var gained = cleared.length * 10 * cascade;
      for (final g in created.values) {
        gained += switch (Gem.special(g)) {
          JewelSpecial.star => 50,
          JewelSpecial.bomb => 30,
          _ => 20,
        };
      }
      points += gained;
      for (final c in cleared) {
        board[c] = Gem.empty;
      }
      created.forEach((c, g) => board[c] = g);
      steps.add(
        JewelStep(
          cascade: cascade,
          cleared: List.unmodifiable(cleared.toList()..sort()),
          created: Map.unmodifiable(created),
          points: gained,
        ),
      );
      _collapse(board, rng);
      if (cascade > 200) break; // safety net; never reached in practice
    }
    return (board: board, points: points, steps: steps);
  }

  int _commonestColor(List<int> board) {
    final counts = List<int>.filled(8, 0);
    for (final g in board) {
      if (g >= 0 && Gem.color(g) != Gem.starColor) counts[Gem.color(g)]++;
    }
    var best = 0;
    for (var c = 1; c < 8; c++) {
      if (counts[c] > counts[best]) best = c;
    }
    return best;
  }

  /// Gravity and refill from the top.
  void _collapse(List<int> board, SeededRng rng) {
    for (var x = 0; x < width; x++) {
      var write = height - 1;
      for (var y = height - 1; y >= 0; y--) {
        final g = board[y * width + x];
        if (g >= 0) {
          board[write * width + x] = g;
          write--;
        }
      }
      for (var y = write; y >= 0; y--) {
        board[y * width + x] = rng.nextInt(colors);
      }
    }
  }
}

/// A Souk Jewels game.
final class JewelsGame extends PuzzleBase<JewelsState, JewelsAction> {
  JewelsGame._(this.config, super.initial, {super.history})
    : logic = JewelsBoard(config.width, config.height, config.colors);

  factory JewelsGame(JewelsConfig config) {
    final rng = SeededRng(config.seed);
    final logic = JewelsBoard(config.width, config.height, config.colors);
    final board = logic.fresh(rng);
    return JewelsGame._(
      config,
      JewelsState(board: List.unmodifiable(board), rng: rng.state, movesLeft: config.moves),
    );
  }

  factory JewelsGame.fromJson(Map<String, Object?> json) {
    checkKind(json, PuzzleKind.soukJewels);
    return JewelsGame._(
      JewelsConfig.fromJson(jsonObject(json['config'])),
      JewelsState.fromJson(jsonObject(json['state'])),
      history: jsonHistory(json, JewelsState.fromJson),
    );
  }

  final JewelsConfig config;
  final JewelsBoard logic;

  @override
  PuzzleKind get kind => PuzzleKind.soukJewels;

  bool isValidSwap(int a, int b) => logic.isValidSwap(state.board, a, b);

  List<(int, int)> validSwaps() => logic.validSwaps(state.board);

  @override
  JewelsState? transition(JewelsState s, JewelsAction a) {
    if (isOver || !logic.isValidSwap(s.board, a.a, a.b)) return null;
    final rng = SeededRng.fromState(s.rng);
    final r = logic.resolve(s.board, a.a, a.b, rng);
    var board = r.board;
    var shuffles = s.shuffles;
    if (!logic.hasValidMove(board)) {
      board = logic.reshuffle(board, rng);
      shuffles++;
    }
    return JewelsState(
      board: List.unmodifiable(board),
      rng: rng.state,
      movesLeft: s.movesLeft - 1,
      score: s.score + r.points,
      moves: s.moves + 1,
      shuffles: shuffles,
      lastSteps: List.unmodifiable(r.steps),
    );
  }

  @override
  bool get isSolved => state.score >= config.target;

  @override
  bool get isOver => isSolved || state.movesLeft <= 0;

  /// The legal swap scoring the most (exact simulation with the real RNG).
  @override
  PuzzleHint<JewelsAction>? hint() {
    if (isOver) return null;
    (int, int)? best;
    var bestPoints = -1;
    for (final (a, b) in validSwaps()) {
      final r = logic.resolve(state.board, a, b, SeededRng.fromState(state.rng));
      if (r.points > bestPoints) {
        bestPoints = r.points;
        best = (a, b);
      }
    }
    if (best == null) return null;
    return PuzzleHint(JewelsAction(best.$1, best.$2), technique: 'bestSwap', focus: [best.$1, best.$2]);
  }

  @override
  Map<String, Object?> configJson() => config.toJson();
}

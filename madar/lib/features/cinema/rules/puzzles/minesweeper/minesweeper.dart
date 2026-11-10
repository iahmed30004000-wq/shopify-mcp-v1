/// Minesweeper with a safe first click, flags, chording, a logical deducer
/// for hints and an optional no-guess board generator.
///
/// Rules:
/// * mines are placed on the first reveal, never on the clicked cell and –
///   when the board has room – never on its 8 neighbours, so the first click
///   always opens an area (a zero);
/// * revealing a zero flood-fills its neighbourhood;
/// * chording a revealed number whose adjacent flags equal the number reveals
///   every other hidden neighbour (and loses on a wrongly placed flag);
/// * the game is won when every safe cell is revealed (remaining mines are
///   then flagged automatically) and lost when a mine is revealed.
library;

import 'dart:math' as math;

import '../core/grid.dart';
import '../core/puzzle_game.dart';
import '../core/seeded_rng.dart';

final class MinesweeperConfig {
  const MinesweeperConfig({this.width = 9, this.height = 9, this.mines = 10, this.seed = 0, this.noGuess = false})
    : assert(width >= 2 && height >= 2 && mines >= 1 && mines < width * height);

  /// Board-size presets: 9×9/10, 16×16/40, 30×16/99, 30×24/180.
  factory MinesweeperConfig.forDifficulty(PuzzleDifficulty d, {int seed = 0, bool noGuess = false}) => switch (d) {
    PuzzleDifficulty.easy => MinesweeperConfig(width: 9, height: 9, mines: 10, seed: seed, noGuess: noGuess),
    PuzzleDifficulty.medium => MinesweeperConfig(width: 16, height: 16, mines: 40, seed: seed, noGuess: noGuess),
    PuzzleDifficulty.hard => MinesweeperConfig(width: 30, height: 16, mines: 99, seed: seed, noGuess: noGuess),
    PuzzleDifficulty.expert => MinesweeperConfig(width: 30, height: 24, mines: 180, seed: seed, noGuess: noGuess),
  };

  final int width;
  final int height;
  final int mines;
  final int seed;

  /// Retry mine layouts until the logical deducer can clear the board from
  /// the first click without guessing (at most [noGuessAttempts] layouts;
  /// see [MinesweeperState.logicOnly] for the outcome).
  final bool noGuess;

  /// Attempt budget for [noGuess]: generous on small boards, tight on big
  /// dense ones where logic-only layouts are rare (keeps generation well
  /// under 200 ms; the 30×24/180 expert board usually falls back).
  int get noGuessAttempts {
    if (cells <= 256) return 300;
    return mines / cells <= 0.21 ? 25 : 12;
  }

  int get cells => width * height;

  Map<String, Object?> toJson() => {'w': width, 'h': height, 'mines': mines, 'seed': seed, 'noGuess': noGuess};

  factory MinesweeperConfig.fromJson(Map<String, Object?> j) => MinesweeperConfig(
    width: jsonInt(j, 'w', 9),
    height: jsonInt(j, 'h', 9),
    mines: jsonInt(j, 'mines', 10),
    seed: jsonInt(j, 'seed'),
    noGuess: j['noGuess'] == true,
  );
}

final class MinesweeperState extends PuzzleState {
  const MinesweeperState({
    required this.mines,
    required this.numbers,
    required this.revealed,
    required this.flags,
    this.exploded = -1,
    this.moves = 0,
    this.logicOnly = false,
  });

  /// Mine map; empty until the first reveal.
  final List<bool> mines;

  /// Adjacent-mine counts; empty until the first reveal.
  final List<int> numbers;
  final List<bool> revealed;
  final List<bool> flags;

  /// The revealed mine that ended the game (-1 when none).
  final int exploded;
  final int moves;

  /// True when a no-guess layout was requested and verified: the board can
  /// be cleared from the first click by deduction alone.
  final bool logicOnly;

  bool get minesPlaced => mines.isNotEmpty;

  int get flagCount => flags.where((f) => f).length;

  @override
  Map<String, Object?> toJson() => {
    'mines': [
      for (var i = 0; i < mines.length; i++)
        if (mines[i]) i,
    ],
    'revealed': [
      for (var i = 0; i < revealed.length; i++)
        if (revealed[i]) i,
    ],
    'flags': [
      for (var i = 0; i < flags.length; i++)
        if (flags[i]) i,
    ],
    'n': revealed.length,
    'placed': mines.isNotEmpty,
    'exploded': exploded,
    'moves': moves,
    'logicOnly': logicOnly,
  };

  static List<bool> _set(int n, List<int> on) {
    final out = List<bool>.filled(n, false);
    for (final i in on) {
      out[i] = true;
    }
    return List.unmodifiable(out);
  }

  factory MinesweeperState.fromJson(Map<String, Object?> j, int width) {
    final n = jsonInt(j, 'n');
    final placed = j['placed'] == true;
    final mines = placed ? _set(n, jsonInts(j['mines'])) : const <bool>[];
    return MinesweeperState(
      mines: mines,
      numbers: placed ? computeNumbers(mines, GridShape(width, n ~/ width)) : const [],
      revealed: _set(n, jsonInts(j['revealed'])),
      flags: _set(n, jsonInts(j['flags'])),
      exploded: jsonInt(j, 'exploded', -1),
      moves: jsonInt(j, 'moves'),
      logicOnly: j['logicOnly'] == true,
    );
  }
}

/// Adjacent-mine counts for a mine map.
List<int> computeNumbers(List<bool> mines, GridShape g) => List.unmodifiable([
  for (var i = 0; i < g.length; i++) g.neighbours8(i).where((n) => mines[n]).length,
]);

enum MinesweeperActionType { reveal, flag, chord }

final class MinesweeperAction extends PuzzleAction {
  const MinesweeperAction.reveal(this.cell) : type = MinesweeperActionType.reveal;

  /// Toggles a flag.
  const MinesweeperAction.flag(this.cell) : type = MinesweeperActionType.flag;
  const MinesweeperAction.chord(this.cell) : type = MinesweeperActionType.chord;

  final MinesweeperActionType type;
  final int cell;

  @override
  Map<String, Object?> toJson() => {'t': type.name, 'c': cell};

  factory MinesweeperAction.fromJson(Map<String, Object?> j) {
    final c = jsonInt(j, 'c');
    return switch (MinesweeperActionType.values.byName(j['t']! as String)) {
      MinesweeperActionType.reveal => MinesweeperAction.reveal(c),
      MinesweeperActionType.flag => MinesweeperAction.flag(c),
      MinesweeperActionType.chord => MinesweeperAction.chord(c),
    };
  }

  @override
  bool operator ==(Object other) => other is MinesweeperAction && other.type == type && other.cell == cell;

  @override
  int get hashCode => Object.hash(type, cell);

  @override
  String toString() => 'MinesweeperAction(${type.name}, $cell)';
}

/// What the deducer proved from the visible numbers.
final class MineDeduction {
  const MineDeduction(this.safe, this.mines);
  final Set<int> safe;
  final Set<int> mines;
}

/// Logical deduction from revealed numbers (single constraints, pairwise
/// subset / overlap reasoning and the global mine count).
abstract final class MinesweeperSolver {
  /// Deduces safe cells and mines. [known] maps cell → number for revealed
  /// safe cells; every other cell is hidden.
  static MineDeduction deduce(GridShape g, Map<int, int> known, int totalMines) {
    final safe = <int>{};
    final mines = <int>{};
    var changed = true;
    while (changed) {
      changed = false;
      // Constraints: hidden undecided neighbours and the mines they hold.
      final cons = <({List<int> cells, int k})>[];
      final byCell = <int, List<int>>{};
      for (final e in known.entries) {
        final u = <int>[];
        var k = e.value;
        for (final n in g.neighbours8(e.key)) {
          if (known.containsKey(n) || safe.contains(n)) continue;
          if (mines.contains(n)) {
            k--;
          } else {
            u.add(n);
          }
        }
        if (u.isEmpty) continue;
        final idx = cons.length;
        cons.add((cells: u, k: k));
        for (final c in u) {
          (byCell[c] ??= []).add(idx);
        }
      }
      void markSafe(Iterable<int> cells) {
        for (final c in cells) {
          if (safe.add(c)) changed = true;
        }
      }

      void markMines(Iterable<int> cells) {
        for (final c in cells) {
          if (mines.add(c)) changed = true;
        }
      }

      for (final c in cons) {
        if (c.k == 0) markSafe(c.cells);
        if (c.k == c.cells.length) markMines(c.cells);
      }
      if (changed) continue;
      // Pairwise reasoning between constraints that share a cell.
      for (var a = 0; a < cons.length && !changed; a++) {
        final ca = cons[a];
        final setA = ca.cells.toSet();
        final partners = <int>{
          for (final c in ca.cells) ...byCell[c]!,
        }..remove(a);
        for (final b in partners) {
          final cb = cons[b];
          final inter = cb.cells.where(setA.contains).length;
          final onlyA = ca.cells.length - inter;
          final onlyBCells = cb.cells.where((c) => !setA.contains(c)).toList();
          final onlyB = onlyBCells.length;
          if (onlyB == 0) continue;
          final maxI = math.min(inter, math.min(ca.k, cb.k));
          final minI = math.max(0, ca.k - onlyA);
          if (cb.k - maxI == onlyB) {
            markMines(onlyBCells);
          } else if (cb.k - minI == 0) {
            markSafe(onlyBCells);
          }
          if (changed) break;
        }
      }
      if (changed) continue;
      // Global count.
      final hidden = [
        for (var i = 0; i < g.length; i++)
          if (!known.containsKey(i) && !safe.contains(i) && !mines.contains(i)) i,
      ];
      final left = totalMines - mines.length;
      if (hidden.isNotEmpty && left == 0) markSafe(hidden);
      if (hidden.isNotEmpty && left == hidden.length) markMines(hidden);
    }
    return MineDeduction(safe, mines);
  }

  /// Whether a board can be cleared from [first] by deduction alone.
  static bool solvableWithoutGuessing(GridShape g, List<bool> mines, List<int> numbers, int first) {
    final total = mines.where((m) => m).length;
    final known = <int, int>{};
    void open(int start) {
      final stack = [start];
      while (stack.isNotEmpty) {
        final c = stack.removeLast();
        if (known.containsKey(c)) continue;
        known[c] = numbers[c];
        if (numbers[c] == 0) {
          for (final n in g.neighbours8(c)) {
            if (!known.containsKey(n)) stack.add(n);
          }
        }
      }
    }

    open(first);
    final target = g.length - total;
    while (known.length < target) {
      final d = deduce(g, known, total);
      final fresh = d.safe.where((c) => !known.containsKey(c)).toList();
      if (fresh.isEmpty) return false;
      for (final c in fresh) {
        if (mines[c]) return false; // unsound deduction guard
        open(c);
      }
    }
    return true;
  }
}

/// A Minesweeper game.
final class MinesweeperGame extends PuzzleBase<MinesweeperState, MinesweeperAction> {
  MinesweeperGame(this.config, {MinesweeperState? state, super.history})
    : grid = GridShape(config.width, config.height),
      super(
        state ??
            MinesweeperState(
              mines: const [],
              numbers: const [],
              revealed: List.unmodifiable(List<bool>.filled(config.cells, false)),
              flags: List.unmodifiable(List<bool>.filled(config.cells, false)),
            ),
      );

  factory MinesweeperGame.fromJson(Map<String, Object?> json) {
    checkKind(json, PuzzleKind.minesweeper);
    final config = MinesweeperConfig.fromJson(jsonObject(json['config']));
    return MinesweeperGame(
      config,
      state: MinesweeperState.fromJson(jsonObject(json['state']), config.width),
      history: jsonHistory(json, (j) => MinesweeperState.fromJson(j, config.width)),
    );
  }

  final MinesweeperConfig config;
  final GridShape grid;

  @override
  PuzzleKind get kind => PuzzleKind.minesweeper;

  /// Places mines for a first click on [first] (deterministic per seed);
  /// `verified` tells whether a no-guess layout was found.
  ({List<bool> mines, bool verified}) layMines(int first) {
    final rng = SeededRng(config.seed ^ (first * 7919));
    final n = config.cells;
    final exclude = <int>{first};
    if (config.mines <= n - 9) exclude.addAll(grid.neighbours8(first));
    final allowed = [
      for (var i = 0; i < n; i++)
        if (!exclude.contains(i)) i,
    ];
    List<bool> draw() {
      final pool = List<int>.from(allowed);
      final mines = List<bool>.filled(n, false);
      for (var k = 0; k < config.mines; k++) {
        final j = k + rng.nextInt(pool.length - k);
        final t = pool[k];
        pool[k] = pool[j];
        pool[j] = t;
        mines[pool[k]] = true;
      }
      return mines;
    }

    var mines = draw();
    var verified = false;
    if (config.noGuess) {
      for (var attempt = 0; attempt < config.noGuessAttempts; attempt++) {
        if (attempt > 0) mines = draw();
        if (MinesweeperSolver.solvableWithoutGuessing(grid, mines, computeNumbers(mines, grid), first)) {
          verified = true;
          break;
        }
      }
    }
    return (mines: List.unmodifiable(mines), verified: verified);
  }

  @override
  MinesweeperState? transition(MinesweeperState s, MinesweeperAction a) {
    if (a.cell < 0 || a.cell >= config.cells || _ended(s)) return null;
    switch (a.type) {
      case MinesweeperActionType.flag:
        if (s.revealed[a.cell]) return null;
        return MinesweeperState(
          mines: s.mines,
          numbers: s.numbers,
          revealed: s.revealed,
          flags: List.unmodifiable(List<bool>.from(s.flags)..[a.cell] = !s.flags[a.cell]),
          exploded: s.exploded,
          moves: s.moves + 1,
          logicOnly: s.logicOnly,
        );
      case MinesweeperActionType.reveal:
        if (s.revealed[a.cell] || s.flags[a.cell]) return null;
        var mines = s.mines, numbers = s.numbers;
        var logicOnly = s.logicOnly;
        if (!s.minesPlaced) {
          final laid = layMines(a.cell);
          mines = laid.mines;
          logicOnly = laid.verified;
          numbers = computeNumbers(mines, grid);
        }
        return _open(s, mines, numbers, [a.cell], logicOnly: logicOnly);
      case MinesweeperActionType.chord:
        if (!s.revealed[a.cell] || s.numbers.isEmpty) return null;
        final ns = grid.neighbours8(a.cell);
        final flagged = ns.where((n) => s.flags[n]).length;
        if (flagged != s.numbers[a.cell]) return null;
        final targets = ns.where((n) => !s.flags[n] && !s.revealed[n]).toList();
        if (targets.isEmpty) return null;
        return _open(s, s.mines, s.numbers, targets, logicOnly: s.logicOnly);
    }
  }

  MinesweeperState _open(
    MinesweeperState s,
    List<bool> mines,
    List<int> numbers,
    List<int> starts, {
    required bool logicOnly,
  }) {
    final revealed = List<bool>.from(s.revealed);
    final flags = List<bool>.from(s.flags);
    var exploded = -1;
    for (final start in starts) {
      if (mines[start]) {
        revealed[start] = true;
        if (exploded < 0) exploded = start;
        continue;
      }
      final stack = [start];
      while (stack.isNotEmpty) {
        final c = stack.removeLast();
        if (revealed[c] || mines[c]) continue;
        revealed[c] = true;
        flags[c] = false;
        if (numbers[c] == 0) {
          for (final n in grid.neighbours8(c)) {
            if (!revealed[n] && !flags[n]) stack.add(n);
          }
        }
      }
    }
    final safeLeft = [
      for (var i = 0; i < revealed.length; i++)
        if (!revealed[i] && !mines[i]) i,
    ];
    if (exploded < 0 && safeLeft.isEmpty) {
      for (var i = 0; i < flags.length; i++) {
        flags[i] = mines[i];
      }
    }
    return MinesweeperState(
      mines: mines,
      numbers: numbers,
      revealed: List.unmodifiable(revealed),
      flags: List.unmodifiable(flags),
      exploded: exploded,
      moves: s.moves + 1,
      logicOnly: logicOnly,
    );
  }

  bool _won(MinesweeperState s) {
    if (!s.minesPlaced || s.exploded >= 0) return false;
    for (var i = 0; i < s.revealed.length; i++) {
      if (!s.revealed[i] && !s.mines[i]) return false;
    }
    return true;
  }

  bool _ended(MinesweeperState s) => s.exploded >= 0 || _won(s);

  @override
  bool get isSolved => _won(state);

  bool get isLost => state.exploded >= 0;

  @override
  bool get isOver => _ended(state);

  /// Mines not yet flagged (may go negative with too many flags).
  int get minesLeft => config.mines - state.flagCount;

  /// Deductions from the currently visible numbers.
  MineDeduction deduce() {
    final s = state;
    final known = <int, int>{
      for (var i = 0; i < s.revealed.length; i++)
        if (s.revealed[i] && s.numbers.isNotEmpty && !s.mines[i]) i: s.numbers[i],
    };
    return MinesweeperSolver.deduce(grid, known, config.mines);
  }

  @override
  PuzzleHint<MinesweeperAction>? hint() {
    final s = state;
    if (isOver) return null;
    if (!s.minesPlaced) {
      final centre = grid.index(config.width ~/ 2, config.height ~/ 2);
      return PuzzleHint(MinesweeperAction.reveal(centre), technique: 'opening', focus: [centre]);
    }
    final d = deduce();
    final safe = d.safe.where((c) => !s.revealed[c] && !s.flags[c]).toList()..sort();
    if (safe.isNotEmpty) {
      return PuzzleHint(MinesweeperAction.reveal(safe.first), technique: 'safeReveal', focus: [safe.first]);
    }
    final wrongFlag = s.flags.indexed.where((e) => e.$2 && d.safe.contains(e.$1)).map((e) => e.$1).toList();
    if (wrongFlag.isNotEmpty) {
      return PuzzleHint(MinesweeperAction.flag(wrongFlag.first), technique: 'wrongFlag', focus: [wrongFlag.first]);
    }
    final mines = d.mines.where((c) => !s.flags[c]).toList()..sort();
    if (mines.isNotEmpty) {
      return PuzzleHint(MinesweeperAction.flag(mines.first), technique: 'certainMine', focus: [mines.first]);
    }
    // No certainty: the hidden cell with the lowest local mine estimate.
    final hidden = [
      for (var i = 0; i < s.revealed.length; i++)
        if (!s.revealed[i] && !s.flags[i] && !d.mines.contains(i)) i,
    ];
    if (hidden.isEmpty) return null;
    final density = (config.mines - d.mines.length) / hidden.length;
    var best = hidden.first;
    var bestP = 2.0;
    for (final c in hidden) {
      var p = density;
      for (final n in grid.neighbours8(c)) {
        if (!s.revealed[n]) continue;
        final ns = grid.neighbours8(n);
        final unknown = ns.where((m) => !s.revealed[m] && !d.mines.contains(m)).length;
        final left = s.numbers[n] - ns.where(d.mines.contains).length;
        if (unknown > 0) p = math.max(p, left / unknown);
      }
      if (p < bestP) {
        bestP = p;
        best = c;
      }
    }
    return PuzzleHint(MinesweeperAction.reveal(best), technique: 'guess', focus: [best]);
  }

  @override
  Map<String, Object?> configJson() => config.toJson();
}

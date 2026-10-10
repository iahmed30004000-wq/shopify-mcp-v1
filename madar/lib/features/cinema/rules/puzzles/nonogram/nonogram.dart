/// Nonograms: a line solver, a generator of puzzles that the line solver
/// fully solves (hence uniquely solvable without guessing), hints and play.
///
/// Cell codes: 0 = unknown, 1 = filled, 2 = empty (crossed).
library;

import '../core/puzzle_game.dart';
import '../core/seeded_rng.dart';

const int kUnknown = 0;
const int kFilled = 1;
const int kEmpty = 2;

/// Run lengths of the filled cells of a line (empty list for a blank line).
List<int> cluesOf(List<bool> line) {
  final out = <int>[];
  var run = 0;
  for (final f in line) {
    if (f) {
      run++;
    } else if (run > 0) {
      out.add(run);
      run = 0;
    }
  }
  if (run > 0) out.add(run);
  return out;
}

/// Exact single-line solver (dynamic programming over block placements).
abstract final class NonogramLineSolver {
  /// Returns the line with every forced cell set, or null when [cells] are
  /// inconsistent with [clue].
  static List<int>? solveLine(List<int> clue, List<int> cells) {
    final n = cells.length;
    final k = clue.length;
    // Prefix sums of cells known to be empty.
    final emptyPre = List<int>.filled(n + 1, 0);
    for (var i = 0; i < n; i++) {
      emptyPre[i + 1] = emptyPre[i] + (cells[i] == kEmpty ? 1 : 0);
    }
    bool noEmpty(int a, int b) => emptyPre[b] - emptyPre[a] == 0;

    // pre[i][j]: cells [0, i) can hold exactly the first j blocks.
    final pre = List.generate(n + 1, (_) => List<bool>.filled(k + 1, false));
    pre[0][0] = true;
    for (var i = 1; i <= n; i++) {
      for (var j = 0; j <= k; j++) {
        var ok = cells[i - 1] != kFilled && pre[i - 1][j];
        if (!ok && j > 0) {
          final len = clue[j - 1];
          final s = i - len;
          if (s >= 0 && noEmpty(s, i)) {
            if (s == 0) {
              ok = j == 1;
            } else {
              ok = cells[s - 1] != kFilled && pre[s - 1][j - 1];
            }
          }
        }
        pre[i][j] = ok;
      }
    }
    // suf[i][j]: cells [i, n) can hold exactly blocks j..k-1.
    final suf = List.generate(n + 2, (_) => List<bool>.filled(k + 1, false));
    suf[n][k] = true;
    suf[n + 1][k] = true;
    for (var i = n - 1; i >= 0; i--) {
      for (var j = k; j >= 0; j--) {
        var ok = cells[i] != kFilled && suf[i + 1][j];
        if (!ok && j < k) {
          final len = clue[j];
          final e = i + len;
          if (e <= n && noEmpty(i, e)) {
            if (e == n) {
              ok = j == k - 1;
            } else {
              ok = cells[e] != kFilled && suf[e + 1][j + 1];
            }
          }
        }
        suf[i][j] = ok;
      }
    }
    if (!pre[n][k]) return null;
    final canEmpty = List<bool>.filled(n, false);
    final fillDiff = List<int>.filled(n + 1, 0);
    for (var c = 0; c < n; c++) {
      if (cells[c] == kFilled) continue;
      for (var j = 0; j <= k; j++) {
        if (pre[c][j] && suf[c + 1][j]) {
          canEmpty[c] = true;
          break;
        }
      }
    }
    for (var j = 0; j < k; j++) {
      final len = clue[j];
      for (var s = 0; s + len <= n; s++) {
        final e = s + len;
        if (!noEmpty(s, e)) continue;
        final left = s == 0 ? j == 0 : (cells[s - 1] != kFilled && pre[s - 1][j]);
        if (!left) continue;
        final right = e == n ? j == k - 1 : (cells[e] != kFilled && suf[e + 1][j + 1]);
        if (!right) continue;
        fillDiff[s]++;
        fillDiff[e]--;
      }
    }
    final out = List<int>.from(cells);
    var run = 0;
    for (var c = 0; c < n; c++) {
      run += fillDiff[c];
      final canFill = run > 0;
      if (!canFill && !canEmpty[c]) return null;
      if (canFill && !canEmpty[c]) out[c] = kFilled;
      if (!canFill && canEmpty[c]) out[c] = kEmpty;
    }
    return out;
  }
}

/// Result of running the line solver on a whole puzzle.
final class NonogramSolveResult {
  const NonogramSolveResult(this.cells, this.contradiction, this.sweeps);
  final List<int> cells;
  final bool contradiction;

  /// Number of full row+column sweeps that made progress.
  final int sweeps;

  bool get solved => !contradiction && !cells.contains(kUnknown);
}

/// Propagates [NonogramLineSolver] over rows and columns to a fixpoint.
NonogramSolveResult solveNonogram(List<List<int>> rows, List<List<int>> cols, {List<int>? start}) {
  final h = rows.length, w = cols.length;
  final cells = start == null ? List<int>.filled(w * h, kUnknown) : List<int>.from(start);
  var sweeps = 0;
  final rowDirty = List<bool>.filled(h, true);
  final colDirty = List<bool>.filled(w, true);
  var progress = true;
  while (progress) {
    progress = false;
    for (var y = 0; y < h; y++) {
      if (!rowDirty[y]) continue;
      rowDirty[y] = false;
      final line = [for (var x = 0; x < w; x++) cells[y * w + x]];
      final r = NonogramLineSolver.solveLine(rows[y], line);
      if (r == null) return NonogramSolveResult(cells, true, sweeps);
      for (var x = 0; x < w; x++) {
        if (r[x] != line[x]) {
          cells[y * w + x] = r[x];
          colDirty[x] = true;
          progress = true;
        }
      }
    }
    for (var x = 0; x < w; x++) {
      if (!colDirty[x]) continue;
      colDirty[x] = false;
      final line = [for (var y = 0; y < h; y++) cells[y * w + x]];
      final r = NonogramLineSolver.solveLine(cols[x], line);
      if (r == null) return NonogramSolveResult(cells, true, sweeps);
      for (var y = 0; y < h; y++) {
        if (r[y] != line[y]) {
          cells[y * w + x] = r[y];
          rowDirty[y] = true;
          progress = true;
        }
      }
    }
    if (progress) sweeps++;
  }
  return NonogramSolveResult(cells, false, sweeps);
}

/// A generated nonogram.
final class NonogramPuzzle {
  NonogramPuzzle({required this.width, required this.height, required this.solution, required this.seed})
    : rowClues = List.unmodifiable([
        for (var y = 0; y < height; y++) List<int>.unmodifiable(cluesOf(solution.sublist(y * width, (y + 1) * width))),
      ]),
      colClues = List.unmodifiable([
        for (var x = 0; x < width; x++)
          List<int>.unmodifiable(cluesOf([for (var y = 0; y < height; y++) solution[y * width + x]])),
      ]);

  final int width;
  final int height;
  final List<bool> solution;
  final List<List<int>> rowClues;
  final List<List<int>> colClues;
  final int seed;

  Map<String, Object?> toJson() => {
    'w': width,
    'h': height,
    'seed': seed,
    'solution': [for (final f in solution) f ? 1 : 0],
  };

  factory NonogramPuzzle.fromJson(Map<String, Object?> j) => NonogramPuzzle(
    width: jsonInt(j, 'w'),
    height: jsonInt(j, 'h'),
    seed: jsonInt(j, 'seed'),
    solution: List.unmodifiable([for (final v in jsonInts(j['solution'])) v == 1]),
  );
}

/// Seeded generator of line-solvable nonograms.
abstract final class NonogramGenerator {
  static const int minSize = 5;
  static const int maxSize = 15;

  /// Default size and fill density per difficulty (lower density needs more
  /// line reasoning).
  static ({int size, double density}) preset(PuzzleDifficulty d) => switch (d) {
    PuzzleDifficulty.easy => (size: 5, density: 0.62),
    PuzzleDifficulty.medium => (size: 10, density: 0.58),
    PuzzleDifficulty.hard => (size: 12, density: 0.55),
    PuzzleDifficulty.expert => (size: 15, density: 0.52),
  };

  /// A puzzle that the line solver solves completely (unique solution).
  static NonogramPuzzle generate(PuzzleDifficulty difficulty, int seed, {int? width, int? height}) {
    final p = preset(difficulty);
    final w = (width ?? p.size).clamp(minSize, maxSize);
    final h = (height ?? p.size).clamp(minSize, maxSize);
    final rng = SeededRng(seed);
    while (true) {
      final grid = [for (var i = 0; i < w * h; i++) rng.nextDouble() < p.density];
      // Repair: fill undetermined cells until the line solver succeeds.
      for (var round = 0; round < w * h; round++) {
        final puzzle = NonogramPuzzle(width: w, height: h, solution: grid, seed: seed);
        final r = solveNonogram(puzzle.rowClues, puzzle.colClues);
        if (r.solved) {
          final filled = grid.where((f) => f).length;
          if (filled == 0 || filled == w * h) break;
          return NonogramPuzzle(width: w, height: h, solution: List.unmodifiable(grid), seed: seed);
        }
        final open = [
          for (var i = 0; i < w * h; i++)
            if (r.cells[i] == kUnknown) i,
        ];
        if (open.isEmpty) break;
        final c = rng.pick(open);
        grid[c] = !grid[c];
      }
    }
  }
}

final class NonogramState extends PuzzleState {
  const NonogramState({required this.cells, this.moves = 0});

  /// Player marks: 0 unknown, 1 filled, 2 crossed.
  final List<int> cells;
  final int moves;

  @override
  Map<String, Object?> toJson() => {'cells': cells, 'moves': moves};

  factory NonogramState.fromJson(Map<String, Object?> j) =>
      NonogramState(cells: List.unmodifiable(jsonInts(j['cells'])), moves: jsonInt(j, 'moves'));
}

final class NonogramAction extends PuzzleAction {
  /// Sets [cell] to [mark] (0 clears, 1 fills, 2 crosses).
  const NonogramAction(this.cell, this.mark);

  const NonogramAction.fill(this.cell) : mark = kFilled;
  const NonogramAction.cross(this.cell) : mark = kEmpty;
  const NonogramAction.clear(this.cell) : mark = kUnknown;

  final int cell;
  final int mark;

  @override
  Map<String, Object?> toJson() => {'c': cell, 'm': mark};

  factory NonogramAction.fromJson(Map<String, Object?> j) => NonogramAction(jsonInt(j, 'c'), jsonInt(j, 'm'));

  @override
  bool operator ==(Object other) => other is NonogramAction && other.cell == cell && other.mark == mark;

  @override
  int get hashCode => Object.hash(cell, mark);

  @override
  String toString() => 'NonogramAction($cell, $mark)';
}

/// A nonogram game.
final class NonogramGame extends PuzzleBase<NonogramState, NonogramAction> {
  NonogramGame(this.puzzle, {NonogramState? state, super.history})
    : super(state ?? NonogramState(cells: List.unmodifiable(List<int>.filled(puzzle.width * puzzle.height, 0))));

  factory NonogramGame.generate(PuzzleDifficulty d, int seed, {int? width, int? height}) =>
      NonogramGame(NonogramGenerator.generate(d, seed, width: width, height: height));

  factory NonogramGame.fromJson(Map<String, Object?> json) {
    checkKind(json, PuzzleKind.nonogram);
    return NonogramGame(
      NonogramPuzzle.fromJson(jsonObject(json['config'])),
      state: NonogramState.fromJson(jsonObject(json['state'])),
      history: jsonHistory(json, NonogramState.fromJson),
    );
  }

  final NonogramPuzzle puzzle;

  @override
  PuzzleKind get kind => PuzzleKind.nonogram;

  @override
  NonogramState? transition(NonogramState s, NonogramAction a) {
    if (a.cell < 0 || a.cell >= s.cells.length || a.mark < 0 || a.mark > 2) return null;
    if (s.cells[a.cell] == a.mark || isSolved) return null;
    return NonogramState(cells: List.unmodifiable(List<int>.from(s.cells)..[a.cell] = a.mark), moves: s.moves + 1);
  }

  @override
  bool get isSolved {
    final c = state.cells;
    for (var i = 0; i < c.length; i++) {
      if ((c[i] == kFilled) != puzzle.solution[i]) return false;
    }
    return true;
  }

  @override
  bool get isOver => isSolved;

  /// Whether the filled cells of row [y] already match its clue.
  bool rowSatisfied(int y) {
    final w = puzzle.width;
    return sameList(cluesOf([for (var x = 0; x < w; x++) state.cells[y * w + x] == kFilled]), puzzle.rowClues[y]);
  }

  /// Whether the filled cells of column [x] already match its clue.
  bool colSatisfied(int x) {
    final w = puzzle.width;
    return sameList(
      cluesOf([for (var y = 0; y < puzzle.height; y++) state.cells[y * w + x] == kFilled]),
      puzzle.colClues[x],
    );
  }

  /// A wrong mark first (`mistake`), else the first cell the line solver
  /// deduces from the player's correct marks (`lineLogic`; focus = the
  /// line's cells).
  @override
  PuzzleHint<NonogramAction>? hint() {
    if (isSolved) return null;
    final w = puzzle.width, h = puzzle.height;
    final cells = state.cells;
    for (var i = 0; i < cells.length; i++) {
      final m = cells[i];
      if (m == kFilled && !puzzle.solution[i]) return PuzzleHint(NonogramAction.cross(i), technique: 'mistake', focus: [i]);
      if (m == kEmpty && puzzle.solution[i]) return PuzzleHint(NonogramAction.fill(i), technique: 'mistake', focus: [i]);
    }
    // One sweep of the line solver over the player's (correct) marks;
    // prefer a deduced fill over a deduced cross.
    PuzzleHint<NonogramAction>? cross;
    for (var line = 0; line < h + w; line++) {
      final isRow = line < h;
      final idx = isRow ? [for (var x = 0; x < w; x++) line * w + x] : [for (var y = 0; y < h; y++) y * w + (line - h)];
      final before = [for (final i in idx) cells[i]];
      final r = NonogramLineSolver.solveLine(isRow ? puzzle.rowClues[line] : puzzle.colClues[line - h], before);
      if (r == null) continue;
      for (var k = 0; k < idx.length; k++) {
        if (r[k] == before[k]) continue;
        if (r[k] == kFilled) return PuzzleHint(NonogramAction.fill(idx[k]), technique: 'lineLogic', focus: idx);
        cross ??= PuzzleHint(NonogramAction.cross(idx[k]), technique: 'lineLogic', focus: idx);
      }
    }
    if (cross != null) return cross;
    // Fallback (not reached for line-solvable puzzles): reveal a filled cell.
    for (var i = 0; i < cells.length; i++) {
      if (puzzle.solution[i] && cells[i] != kFilled) {
        return PuzzleHint(NonogramAction.fill(i), technique: 'reveal', focus: [i]);
      }
    }
    return null;
  }

  @override
  Map<String, Object?> configJson() => puzzle.toJson();
}

/// Seeded Sudoku generation with a unique solution and a target difficulty.
///
/// 1. A random complete grid is built by randomised backtracking.
/// 2. Clues are removed (in 180°-symmetric pairs by default) while the puzzle
///    keeps a unique solution, giving a minimal puzzle.
/// 3. The puzzle is graded by [SudokuLogic]. A puzzle harder than the target
///    receives clues (taken from the solution at the cells where the
///    target-tier solver gets stuck) until it is exactly as hard as the
///    target; an easier one is discarded. Expert puzzles additionally run a
///    short clue-swap hill climb that keeps uniqueness and increases the
///    difficulty until the hard-tier solver gets stuck.
library;

import '../core/puzzle_game.dart';
import '../core/seeded_rng.dart';
import 'sudoku_core.dart';
import 'sudoku_logic.dart';

/// A generated puzzle.
final class SudokuPuzzle {
  const SudokuPuzzle({
    required this.givens,
    required this.solution,
    required this.difficulty,
    required this.hardest,
    required this.seed,
  });

  final List<int> givens;
  final List<int> solution;
  final PuzzleDifficulty difficulty;

  /// Hardest technique needed ([SudokuTechnique.beyondLogic] for expert).
  final SudokuTechnique hardest;
  final int seed;

  int get clueCount => givens.where((v) => v != 0).length;

  Map<String, Object?> toJson() => {
    'givens': givens,
    'solution': solution,
    'difficulty': difficulty.name,
    'hardest': hardest.name,
    'seed': seed,
  };

  factory SudokuPuzzle.fromJson(Map<String, Object?> j) => SudokuPuzzle(
    givens: List.unmodifiable(jsonInts(j['givens'])),
    solution: List.unmodifiable(jsonInts(j['solution'])),
    difficulty: PuzzleDifficulty.values.byName(j['difficulty']! as String),
    hardest: SudokuTechnique.values.byName(j['hardest']! as String),
    seed: jsonInt(j, 'seed'),
  );
}

/// Seeded Sudoku generator.
abstract final class SudokuGenerator {
  /// Minimum clue count of easy puzzles (friendlier openings).
  static const int easyMinClues = 32;

  /// Generates a puzzle of exactly [difficulty] from [seed].
  static SudokuPuzzle generate(PuzzleDifficulty difficulty, int seed, {bool symmetric = true}) {
    final rng = SeededRng(seed);
    while (true) {
      final solution = SudokuSolver.randomSolution(rng);
      var puzzle = minimize(solution, rng, symmetric: symmetric);
      var grade = SudokuLogic.grade(puzzle);
      if (difficulty == PuzzleDifficulty.expert && grade.difficulty != PuzzleDifficulty.expert) {
        final hardened = _harden(puzzle, solution, rng, symmetric: symmetric);
        if (hardened == null) continue;
        puzzle = hardened;
        grade = SudokuLogic.grade(puzzle);
      }
      if (grade.difficulty.index < difficulty.index) continue;
      if (grade.difficulty.index > difficulty.index) {
        final eased = _ease(puzzle, solution, difficulty, rng, symmetric: symmetric);
        if (eased == null) continue;
        puzzle = eased;
        grade = SudokuLogic.grade(puzzle);
        if (grade.difficulty != difficulty) continue;
      }
      if (difficulty == PuzzleDifficulty.easy) {
        puzzle = _fillTo(puzzle, solution, easyMinClues, rng);
        grade = SudokuLogic.grade(puzzle);
      }
      return SudokuPuzzle(
        givens: List.unmodifiable(puzzle),
        solution: List.unmodifiable(solution),
        difficulty: difficulty,
        hardest: grade.hardest,
        seed: seed,
      );
    }
  }

  static int _mirror(int c) => 80 - c;

  /// Removes clues from [solution] while the solution stays unique.
  static List<int> minimize(List<int> solution, SeededRng rng, {bool symmetric = true}) {
    final grid = List<int>.from(solution);
    final order = [
      for (var c = 0; c < 81; c++)
        if (!symmetric || c <= _mirror(c)) c,
    ];
    rng.shuffle(order);
    for (final c in order) {
      final m = _mirror(c);
      final a = grid[c], b = grid[m];
      grid[c] = 0;
      if (symmetric) grid[m] = 0;
      if (!SudokuSolver.hasUniqueSolution(grid)) {
        grid[c] = a;
        grid[m] = b;
      }
    }
    return grid;
  }

  /// Adds solution clues until the puzzle is at most [target] hard.
  static List<int>? _ease(
    List<int> puzzle,
    List<int> solution,
    PuzzleDifficulty target,
    SeededRng rng, {
    required bool symmetric,
  }) {
    final grid = List<int>.from(puzzle);
    for (var guard = 0; guard < 81; guard++) {
      final logic = SudokuLogic(grid);
      final g = logic.solve(maxTier: target == PuzzleDifficulty.expert ? PuzzleDifficulty.hard : target);
      if (g.solved) return grid;
      // Reveal a stuck cell with the most candidates (the most informative).
      var bestPop = -1;
      final best = <int>[];
      for (var c = 0; c < 81; c++) {
        if (logic.values[c] != 0) continue;
        final p = kPop9[logic.cand[c]];
        if (p > bestPop) {
          bestPop = p;
          best
            ..clear()
            ..add(c);
        } else if (p == bestPop) {
          best.add(c);
        }
      }
      if (best.isEmpty) return null;
      final c = rng.pick(best);
      grid[c] = solution[c];
      if (symmetric) grid[_mirror(c)] = solution[_mirror(c)];
    }
    return null;
  }

  /// Adds random clues until [minClues] are given (keeps the grade <= easy).
  static List<int> _fillTo(List<int> puzzle, List<int> solution, int minClues, SeededRng rng) {
    final grid = List<int>.from(puzzle);
    final empty = [
      for (var c = 0; c < 81; c++)
        if (grid[c] == 0) c,
    ];
    rng.shuffle(empty);
    var clues = 81 - empty.length;
    for (final c in empty) {
      if (clues >= minClues) break;
      if (grid[c] != 0) continue;
      grid[c] = solution[c];
      clues++;
    }
    return grid;
  }

  /// A difficulty score used by the hill climb.
  static int _score(SudokuGrade g, List<int> grid) {
    if (!g.solved) return 1 << 20;
    return g.hardest.tier.index * 10000 + g.hardSteps * 100 + g.hardest.index * 10 + grid.where((v) => v == 0).length;
  }

  /// Clue-swap hill climb towards a puzzle the hard tier cannot solve.
  static List<int>? _harden(List<int> puzzle, List<int> solution, SeededRng rng, {required bool symmetric}) {
    var grid = List<int>.from(puzzle);
    var score = _score(SudokuLogic.grade(grid), grid);
    for (var iter = 0; iter < 60; iter++) {
      if (score >= 1 << 20) return grid;
      final clues = [
        for (var c = 0; c < 81; c++)
          if (grid[c] != 0 && (!symmetric || c <= _mirror(c))) c,
      ];
      final holes = [
        for (var c = 0; c < 81; c++)
          if (grid[c] == 0 && (!symmetric || c <= _mirror(c))) c,
      ];
      if (clues.isEmpty || holes.isEmpty) return null;
      final out = rng.pick(clues);
      final into = rng.pick(holes);
      final next = List<int>.from(grid);
      next[out] = 0;
      if (symmetric) next[_mirror(out)] = 0;
      next[into] = solution[into];
      if (symmetric) next[_mirror(into)] = solution[_mirror(into)];
      if (!SudokuSolver.hasUniqueSolution(next)) continue;
      final reduced = _reduce(next, rng, symmetric: symmetric);
      final s = _score(SudokuLogic.grade(reduced), reduced);
      if (s >= score) {
        grid = reduced;
        score = s;
      }
    }
    return score >= 1 << 20 ? grid : null;
  }

  /// Removes any clue whose removal keeps the solution unique.
  static List<int> _reduce(List<int> puzzle, SeededRng rng, {required bool symmetric}) {
    final grid = List<int>.from(puzzle);
    final order = [
      for (var c = 0; c < 81; c++)
        if (grid[c] != 0 && (!symmetric || c <= _mirror(c))) c,
    ];
    rng.shuffle(order);
    for (final c in order) {
      final m = _mirror(c);
      final a = grid[c], b = grid[m];
      grid[c] = 0;
      if (symmetric) grid[m] = 0;
      if (!SudokuSolver.hasUniqueSolution(grid)) {
        grid[c] = a;
        grid[m] = b;
      }
    }
    return grid;
  }
}

import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/cinema/rules/puzzles/puzzles.dart';

import 'support.dart';

/// Counts solutions by brute force (rows enumerated from their clues).
int bruteForceCount(NonogramPuzzle p, {int limit = 2}) {
  List<List<bool>> rowsFor(List<int> clue, int w) {
    final out = <List<bool>>[];
    void rec(int block, int pos, List<bool> cur) {
      if (block == clue.length) {
        out.add(List<bool>.from(cur));
        return;
      }
      final len = clue[block];
      for (var s = pos; s + len <= w; s++) {
        for (var k = s; k < s + len; k++) {
          cur[k] = true;
        }
        rec(block + 1, s + len + 1, cur);
        for (var k = s; k < s + len; k++) {
          cur[k] = false;
        }
      }
    }

    rec(0, 0, List<bool>.filled(w, false));
    return out;
  }

  final options = [for (final c in p.rowClues) rowsFor(c, p.width)];
  var count = 0;
  final grid = <List<bool>>[];
  void search(int y) {
    if (count >= limit) return;
    if (y == p.height) {
      for (var x = 0; x < p.width; x++) {
        if (!sameList(cluesOf([for (final r in grid) r[x]]), p.colClues[x])) return;
      }
      count++;
      return;
    }
    for (final r in options[y]) {
      grid.add(r);
      search(y + 1);
      grid.removeLast();
    }
  }

  search(0);
  return count;
}

void main() {
  group('line solver', () {
    test('overlap and edge cases', () {
      expect(NonogramLineSolver.solveLine([3], [0, 0, 0, 0, 0]), [0, 0, 1, 0, 0]);
      expect(NonogramLineSolver.solveLine([5], [0, 0, 0, 0, 0]), [1, 1, 1, 1, 1]);
      expect(NonogramLineSolver.solveLine([], [0, 0, 0]), [2, 2, 2]);
      expect(NonogramLineSolver.solveLine([1, 1], [0, 0, 0]), [1, 2, 1]);
      expect(NonogramLineSolver.solveLine([2], [0, 1, 0, 0, 0]), [0, 1, 0, 2, 2]);
      expect(NonogramLineSolver.solveLine([1], [1, 0, 1]), isNull, reason: 'contradiction');
      expect(NonogramLineSolver.solveLine([2, 1], [0, 0, 0, 2, 0]), [0, 1, 0, 2, 1]);
      expect(NonogramLineSolver.solveLine([4], [2, 0, 0, 0, 0]), [2, 1, 1, 1, 1]);
    });

    test('agrees with brute force on random lines', () {
      final rng = SeededRng(8);
      for (var i = 0; i < 300; i++) {
        final n = rng.nextRange(3, 9);
        final truth = [for (var k = 0; k < n; k++) rng.nextBool()];
        final clue = cluesOf(truth);
        final cells = [for (var k = 0; k < n; k++) rng.nextInt(4) == 0 ? (truth[k] ? 1 : 2) : 0];
        final r = NonogramLineSolver.solveLine(clue, cells)!;
        // Every line consistent with clue and cells.
        final all = <List<bool>>[];
        for (var m = 0; m < (1 << n); m++) {
          final line = [for (var k = 0; k < n; k++) (m >> k) & 1 == 1];
          var ok = sameList(cluesOf(line), clue);
          for (var k = 0; k < n && ok; k++) {
            if (cells[k] == 1 && !line[k]) ok = false;
            if (cells[k] == 2 && line[k]) ok = false;
          }
          if (ok) all.add(line);
        }
        for (var k = 0; k < n; k++) {
          final allFilled = all.every((l) => l[k]);
          final allEmpty = all.every((l) => !l[k]);
          expect(r[k], allFilled ? 1 : (allEmpty ? 2 : 0), reason: 'clue $clue cells $cells');
        }
      }
    });
  });

  group('generator', () {
    test('puzzles are line-solvable, hence unique (5×5 … 15×15)', () {
      for (var seed = 0; seed < 40; seed++) {
        final w = 5 + seed % 11, h = 5 + (seed * 7) % 11;
        final p = NonogramGenerator.generate(PuzzleDifficulty.values[seed % 4], seed, width: w, height: h);
        expect(p.width, w);
        expect(p.height, h);
        final r = solveNonogram(p.rowClues, p.colClues);
        expect(r.solved, isTrue);
        for (var i = 0; i < w * h; i++) {
          expect(r.cells[i] == kFilled, p.solution[i]);
        }
      }
    });

    test('brute force confirms uniqueness on small puzzles', () {
      for (var seed = 0; seed < 25; seed++) {
        final p = NonogramGenerator.generate(PuzzleDifficulty.easy, seed);
        expect(bruteForceCount(p), 1, reason: 'seed $seed');
      }
    });

    test('performance budget: 15×15 in < 200 ms', () {
      // Measured ≈ 6 ms worst case on the development container.
      final times = [for (var s = 0; s < 10; s++) timeMs(() => NonogramGenerator.generate(PuzzleDifficulty.expert, s))];
      expect(median(times), lessThan(200), reason: '$times');
    });
  });

  group('game', () {
    test('hints solve the puzzle and point out mistakes', () {
      for (final d in PuzzleDifficulty.values) {
        final g = NonogramGame.generate(d, 3);
        followHints(g);
        expect(g.isSolved, isTrue, reason: d.name);
        for (var y = 0; y < g.puzzle.height; y++) {
          expect(g.rowSatisfied(y), isTrue);
        }
      }
      final g = NonogramGame.generate(PuzzleDifficulty.medium, 4);
      final empty = g.puzzle.solution.indexOf(false);
      g.apply(NonogramAction.fill(empty));
      final h = g.hint()!;
      expect(h.technique, 'mistake');
      expect(h.action, NonogramAction.cross(empty));
    });

    test('marks, undo, JSON and random play', () {
      final g = NonogramGame.generate(PuzzleDifficulty.hard, 9);
      expect(g.apply(const NonogramAction.fill(0)), isTrue);
      expect(g.apply(const NonogramAction.fill(0)), isFalse);
      expect(g.apply(const NonogramAction(0, 7)), isFalse);
      expect(g.apply(const NonogramAction.clear(0)), isTrue);
      expect(g.undo(), isTrue);
      expect(g.state.cells[0], kFilled);
      final rng = SeededRng(2);
      for (var i = 0; i < 2000; i++) {
        g.apply(NonogramAction(rng.nextInt(g.state.cells.length), rng.nextInt(3)));
      }
      expectJsonRoundTrip(g);
      expect(g.hint(), isNotNull);
    });
  });
}

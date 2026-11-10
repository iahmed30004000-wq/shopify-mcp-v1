import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/cinema/rules/puzzles/puzzles.dart';

import 'support.dart';

List<int> parse(String s) => [for (final ch in s.split('')) ch == '.' ? 0 : int.parse(ch)];

// A well-known, uniquely solvable newspaper-style puzzle and its solution.
final classic = parse('53..7....6..195....98....6.8...6...34..8.3..17...2...6.6....28....419..5....8..79');
final classicSolution = parse(
  '534678912672195348198342567859761423426853791713924856961537284287419635345286179',
);

void main() {
  group('solver', () {
    test('solves a known puzzle and proves uniqueness', () {
      expect(SudokuSolver.solve(classic), classicSolution);
      expect(SudokuSolver.countSolutions(classic), 1);
      expect(isConsistentGrid(classicSolution), isTrue);
    });

    test('counts multiple and zero solutions', () {
      expect(SudokuSolver.countSolutions(List<int>.filled(81, 0), limit: 5), 5);
      final broken = List<int>.from(classic)..[2] = 5; // duplicate 5 in row 0
      expect(SudokuSolver.countSolutions(broken), 0);
      expect(SudokuSolver.solve(broken), isNull);
    });

    test('random complete grids are valid', () {
      final rng = SeededRng(3);
      for (var i = 0; i < 20; i++) {
        final g = SudokuSolver.randomSolution(rng);
        expect(g.contains(0), isFalse);
        expect(isConsistentGrid(g), isTrue);
      }
    });
  });

  group('logical techniques', () {
    test('the classic puzzle needs singles only', () {
      final g = SudokuLogic.grade(classic);
      expect(g.solved, isTrue);
      expect(g.difficulty, PuzzleDifficulty.easy);
    });

    test('deductions are sound on many minimal puzzles', () {
      final rng = SeededRng(99);
      for (var i = 0; i < 40; i++) {
        final solution = SudokuSolver.randomSolution(rng);
        final puzzle = SudokuGenerator.minimize(solution, rng, symmetric: i.isEven);
        final logic = SudokuLogic(puzzle);
        logic.solve();
        for (var c = 0; c < 81; c++) {
          if (logic.values[c] != 0) {
            expect(logic.values[c], solution[c]);
          } else {
            expect(logic.cand[c] & (1 << (solution[c] - 1)), isNot(0), reason: 'true digit eliminated');
          }
        }
      }
    });

    test('an X-wing is found and eliminates', () {
      // Every cell may hold anything, except that in rows 0 and 8 the digit
      // 1 is only possible in columns 0 and 8: an X-wing on 1.
      final cand = List<int>.filled(81, kAllDigits);
      for (final r in [0, 8]) {
        for (var c = 1; c < 8; c++) {
          cand[r * 9 + c] = kAllDigits & ~1;
        }
      }
      final logic = SudokuLogic.withCandidates(List<int>.filled(81, 0), cand);
      final step = logic.next();
      expect(step?.technique, SudokuTechnique.xWing);
      for (var r = 1; r < 8; r++) {
        expect(logic.cand[r * 9] & 1, 0);
        expect(logic.cand[r * 9 + 8] & 1, 0);
        expect(logic.cand[r * 9 + 4] & 1, 1);
      }
    });
  });

  group('generator', () {
    for (final d in PuzzleDifficulty.values) {
      test('${d.name}: unique solution graded exactly ${d.name}', () {
        for (var seed = 0; seed < 12; seed++) {
          final p = SudokuGenerator.generate(d, seed);
          expect(SudokuSolver.countSolutions(p.givens), 1, reason: 'seed $seed');
          expect(SudokuSolver.solve(p.givens), p.solution);
          for (var c = 0; c < 81; c++) {
            if (p.givens[c] != 0) expect(p.givens[c], p.solution[c]);
          }
          final grade = SudokuLogic.grade(p.givens);
          expect(grade.difficulty, d, reason: 'seed $seed');
          if (d == PuzzleDifficulty.easy) expect(p.clueCount, greaterThanOrEqualTo(SudokuGenerator.easyMinClues));
          if (d == PuzzleDifficulty.expert) expect(grade.solved, isFalse);
        }
      });
    }

    test('generation is deterministic per seed', () {
      final a = SudokuGenerator.generate(PuzzleDifficulty.hard, 5);
      final b = SudokuGenerator.generate(PuzzleDifficulty.hard, 5);
      expect(a.givens, b.givens);
    });

    test('performance budget: median < 200 ms for the hardest levels', () {
      // Measured on the development container: hard ≈ 25 ms and expert ≈
      // 10 ms on average (worst seen ≈ 110 ms) in JIT test mode.
      for (final d in [PuzzleDifficulty.hard, PuzzleDifficulty.expert]) {
        final times = [for (var s = 100; s < 111; s++) timeMs(() => SudokuGenerator.generate(d, s))];
        expect(median(times), lessThan(200), reason: '$d $times');
      }
    });
  });

  group('game', () {
    SudokuGame game() => SudokuGame(SudokuPuzzle(
      givens: classic,
      solution: classicSolution,
      difficulty: PuzzleDifficulty.easy,
      hardest: SudokuTechnique.hiddenSingle,
      seed: 0,
    ));

    test('givens are locked; placements, notes and conflicts', () {
      final g = game();
      expect(g.apply(const SudokuAction.place(0, 1)), isFalse, reason: 'given');
      expect(g.apply(const SudokuAction.place(2, 5)), isTrue);
      expect(g.conflicts(), containsAll([0, 2]));
      expect(g.mistakes(), {2});
      expect(g.state.mistakes, 1);
      expect(g.apply(const SudokuAction.erase(2)), isTrue);
      expect(g.conflicts(), isEmpty);
      expect(g.apply(const SudokuAction.toggleNote(2, 4)), isTrue);
      expect(g.state.notes[2], 1 << 3);
      // Placing a 4 in the same row clears the peer's note.
      expect(g.apply(const SudokuAction.place(3, 4)), isTrue);
      expect(g.state.notes[2] & (1 << 3), 0);
      expect(g.apply(const SudokuAction.toggleNote(3, 1)), isFalse, reason: 'no notes on filled cells');
    });

    test('auto notes are the candidates; placing clears peer notes', () {
      final g = game();
      expect(g.apply(const SudokuAction.autoNotes()), isTrue);
      expect(g.state.notes[2], SudokuGame.candidatesOf(classic, 2));
      expect(g.apply(const SudokuAction.autoNotes()), isFalse, reason: 'nothing changes');
      final digit = classicSolution[2];
      g.apply(SudokuAction.place(2, digit));
      for (final p in kPeers[2]) {
        expect(g.state.notes[p] & (1 << (digit - 1)), 0);
      }
    });

    test('hints point out mistakes first, then logical placements', () {
      final g = game();
      g.apply(const SudokuAction.place(2, 9));
      final h = g.hint()!;
      expect(h.technique, 'mistake');
      expect(h.action, const SudokuAction.erase(2));
      g.apply(h.action);
      final next = g.hint()!;
      expect(next.action.type, SudokuActionType.place);
      expect(next.action.digit, classicSolution[next.action.cell]);
    });

    test('following hints solves every difficulty', () {
      for (final d in PuzzleDifficulty.values) {
        final g = SudokuGame.generate(d, 21);
        followHints(g);
        expect(g.isSolved, isTrue, reason: d.name);
        expectJsonRoundTrip(g);
      }
    });

    test('undo and JSON', () {
      final g = game();
      g.apply(const SudokuAction.place(2, 4));
      g.apply(const SudokuAction.toggleNote(3, 2));
      expectJsonRoundTrip(g);
      expect(g.undo(), isTrue);
      expect(g.undo(), isTrue);
      expect(g.state.values, classic);
      expect(g.undo(), isFalse);
    });

    test('random play never throws', () {
      final g = SudokuGame.generate(PuzzleDifficulty.medium, 4);
      final rng = SeededRng(4);
      for (var i = 0; i < 3000; i++) {
        final c = rng.nextInt(81), d = rng.nextRange(1, 9);
        switch (rng.nextInt(4)) {
          case 0:
            g.apply(SudokuAction.place(c, d));
          case 1:
            g.apply(SudokuAction.erase(c));
          case 2:
            g.apply(SudokuAction.toggleNote(c, d));
          default:
            if (rng.nextInt(20) == 0) g.undo();
        }
      }
      expect(g.hint(), isNotNull);
    });
  });
}

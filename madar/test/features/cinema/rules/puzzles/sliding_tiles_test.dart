import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/cinema/rules/puzzles/puzzles.dart';

import 'support.dart';

List<int> play(List<int> tiles, List<int> moves) {
  final t = List<int>.from(tiles);
  final n = SlidingSolverTestHelper.sqrt(t.length);
  for (final m in moves) {
    final b = t.indexOf(0);
    expect(SlidingSolver.neighbours(b, n), contains(m), reason: 'moves must be adjacent');
    t[b] = t[m];
    t[m] = 0;
  }
  return t;
}

abstract final class SlidingSolverTestHelper {
  static int sqrt(int len) => len == 9 ? 3 : (len == 16 ? 4 : 5);
}

void main() {
  test('solvability parity', () {
    expect(SlidingSolver.isSolvable(SlidingSolver.goal(3), 3), isTrue);
    expect(SlidingSolver.isSolvable(SlidingSolver.goal(4), 4), isTrue);
    expect(SlidingSolver.isSolvable([2, 1, 3, 4, 5, 6, 7, 8, 0], 3), isFalse);
    expect(SlidingSolver.isSolvable([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 15, 14, 0], 4), isFalse, reason: 'the 14-15 swap');
    // Moving the blank up one row on 4×4 keeps it solvable.
    expect(SlidingSolver.isSolvable([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 0, 13, 14, 15, 12], 4), isTrue);
    expect(() => SlidingGame.fromTiles([2, 1, 3, 4, 5, 6, 7, 8, 0]), throwsArgumentError);
  });

  test('deals are solvable and unsolved for every size and difficulty', () {
    for (final n in [3, 4, 5]) {
      for (final d in PuzzleDifficulty.values) {
        for (var seed = 0; seed < 10; seed++) {
          final g = SlidingGame(SlidingConfig(size: n, difficulty: d, seed: seed));
          expect(SlidingSolver.isSolvable(g.state.tiles, n), isTrue);
          expect(g.isSolved, isFalse);
          expect(g.state.tiles.toSet().length, n * n);
        }
      }
    }
  });

  test('IDA* is optimal on the hardest 8-puzzles (31 moves)', () {
    for (final t in [
      [8, 6, 7, 2, 5, 4, 3, 0, 1],
      [6, 4, 7, 8, 5, 0, 3, 2, 1],
    ]) {
      final sol = SlidingSolver.optimal(t, 3)!;
      expect(sol.length, 31);
      expect(play(t, sol), SlidingSolver.goal(3));
    }
    expect(SlidingSolver.optimal(SlidingSolver.goal(3), 3), isEmpty);
    final one = [1, 2, 3, 4, 5, 6, 7, 0, 8];
    expect(SlidingSolver.optimal(one, 3), [8]);
  });

  test('staged solver solves random 4×4 and 5×5 boards', () {
    for (final n in [4, 5]) {
      for (var seed = 0; seed < 10; seed++) {
        final g = SlidingGame(SlidingConfig(size: n, difficulty: PuzzleDifficulty.expert, seed: seed));
        final sol = SlidingSolver.staged(g.state.tiles, n);
        expect(play(g.state.tiles, sol), SlidingSolver.goal(n));
      }
    }
  });

  test('following hints solves the puzzle; hint budget', () {
    final times = <int>[];
    for (final n in [3, 4, 5]) {
      final g = SlidingGame(SlidingConfig(size: n, difficulty: PuzzleDifficulty.expert, seed: 4));
      times.add(timeMs(g.hint));
      followHints(g);
      expect(g.isSolved, isTrue);
    }
    // Measured ≈ 14 ms median, ≤ 170 ms worst for a first 5×5 hint on the
    // development container.
    expect(times.every((t) => t < 1000), isTrue, reason: '$times');
  });

  test('tapping slides whole lines; illegal taps are rejected', () {
    final g = SlidingGame.fromTiles([1, 2, 3, 4, 5, 6, 7, 8, 0]);
    expect(g.apply(const SlidingAction(4)), isFalse, reason: 'not in line with the blank');
    expect(g.apply(const SlidingAction(8)), isFalse, reason: 'the blank itself');
    expect(g.apply(const SlidingAction(6)), isTrue);
    expect(g.state.tiles, [1, 2, 3, 4, 5, 6, 0, 7, 8]);
    expect(g.state.moves, 2);
    expect(g.apply(const SlidingAction(0)), isTrue);
    expect(g.state.tiles, [0, 2, 3, 1, 5, 6, 4, 7, 8]);
    expect(g.undo(), isTrue);
    expect(g.undo(), isTrue);
    expect(g.isSolved, isTrue);
  });

  test('random play never throws; replay and JSON', () {
    final g = SlidingGame(const SlidingConfig(size: 4, difficulty: PuzzleDifficulty.hard, seed: 12));
    final rng = SeededRng(12);
    final log = <Map<String, Object?>>[];
    for (var i = 0; i < 3000; i++) {
      final a = SlidingAction(rng.nextInt(16));
      if (g.apply(a)) log.add(roundTripJson(a.toJson()));
    }
    expect(SlidingSolver.isSolvable(g.state.tiles, 4), isTrue);
    expect(replay(SlidingGame(const SlidingConfig(size: 4, difficulty: PuzzleDifficulty.hard, seed: 12)), log),
        replay(g, const []));
    expectJsonRoundTrip(g);
  });
}

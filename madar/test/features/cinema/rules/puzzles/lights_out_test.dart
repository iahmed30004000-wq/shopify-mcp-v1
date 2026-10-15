import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/cinema/rules/puzzles/puzzles.dart';

import 'support.dart';

/// Independent solver: try every first-row pattern and chase the lights.
List<List<int>> chaseSolutions(List<bool> board, int rows, int cols) {
  final out = <List<int>>[];
  for (var mask = 0; mask < (1 << cols); mask++) {
    final l = List<bool>.from(board);
    final presses = <int>[];
    void press(int i) {
      presses.add(i);
      final x = i % cols, y = i ~/ cols;
      for (final (dx, dy) in const [(0, 0), (1, 0), (-1, 0), (0, 1), (0, -1)]) {
        final nx = x + dx, ny = y + dy;
        if (nx >= 0 && ny >= 0 && nx < cols && ny < rows) l[ny * cols + nx] = !l[ny * cols + nx];
      }
    }

    for (var x = 0; x < cols; x++) {
      if (mask & (1 << x) != 0) press(x);
    }
    for (var y = 1; y < rows; y++) {
      for (var x = 0; x < cols; x++) {
        if (l[(y - 1) * cols + x]) press(y * cols + x);
      }
    }
    if (!l.contains(true)) out.add(presses);
  }
  return out;
}

void main() {
  test('press-matrix algebra: rank and null space', () {
    expect(LightsOutAlgebra.of(5, 5).nullSpace.length, 2);
    expect(LightsOutAlgebra.of(4, 4).nullSpace.length, 4);
    expect(LightsOutAlgebra.of(3, 3).nullSpace.length, 0);
    for (final z in LightsOutAlgebra.of(5, 5).nullSpace) {
      expect(LightsOutAlgebra.of(5, 5).apply(z).isZero, isTrue, reason: 'quiet pattern');
    }
  });

  test('solver agrees with light chasing; unsolvable boards are detected', () {
    final alg = LightsOutAlgebra.of(5, 5);
    for (var i = 0; i < 25; i++) {
      final b = Gf2Vector(25)..set(i);
      final x = alg.solve(b);
      final chase = chaseSolutions(b.toBools(), 5, 5);
      expect(x != null, chase.isNotEmpty);
      expect(alg.isSolvable(b), chase.isNotEmpty);
      if (x != null) {
        expect(alg.apply(x).toBools(), b.toBools());
        expect(x.weight, chase.map((c) => c.length).reduce((a, b) => a < b ? a : b));
      }
    }
  });

  test('generated boards are solvable with the minimal par', () {
    for (final d in PuzzleDifficulty.values) {
      for (var seed = 0; seed < 25; seed++) {
        final g = LightsOutGame(LightsOutConfig(difficulty: d, seed: seed));
        expect(g.state.lit, greaterThan(0));
        final chase = chaseSolutions(g.state.lights, 5, 5);
        expect(chase, isNotEmpty);
        expect(g.par, chase.map((c) => c.length).reduce((a, b) => a < b ? a : b));
        if (d != PuzzleDifficulty.expert) expect(g.par, lessThanOrEqualTo(g.config.presses!));
      }
    }
  });

  test('hints solve in exactly par presses; other sizes work', () {
    for (var seed = 0; seed < 10; seed++) {
      final g = LightsOutGame(LightsOutConfig(difficulty: PuzzleDifficulty.expert, seed: seed));
      expect(followHints(g), g.par);
      expect(g.isSolved, isTrue);
    }
    for (final (r, c) in [(3, 3), (4, 4), (6, 7), (9, 9)]) {
      final g = LightsOutGame(LightsOutConfig(rows: r, cols: c, difficulty: PuzzleDifficulty.hard, seed: 2));
      followHints(g);
      expect(g.isSolved, isTrue, reason: '$r×$c');
    }
  });

  test('press toggles the plus shape; undo, replay, JSON', () {
    final g = LightsOutGame(const LightsOutConfig(seed: 1));
    final before = g.state.lights;
    g.apply(const LightsOutAction(12));
    for (var i = 0; i < 25; i++) {
      final toggled = [12, 7, 17, 11, 13].contains(i);
      expect(g.state.lights[i], toggled ? !before[i] : before[i]);
    }
    expect(g.apply(const LightsOutAction(25)), isFalse);
    expect(g.undo(), isTrue);
    expect(g.state.lights, before);
    final rng = SeededRng(3);
    final log = <Map<String, Object?>>[];
    for (var i = 0; i < 500 && !g.isOver; i++) {
      final a = LightsOutAction(rng.nextInt(25));
      if (g.apply(a)) log.add(roundTripJson(a.toJson()));
    }
    expect(replay(LightsOutGame(const LightsOutConfig(seed: 1)), log), replay(g, const []));
    final restored = expectJsonRoundTrip(g) as LightsOutGame;
    expect(restored.par, g.par);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/cinema/rules/puzzles/puzzles.dart';

import 'support.dart';

void main() {
  test('mask rotation', () {
    expect(rotateMask(Dir4.up.bit, 1), Dir4.right.bit);
    expect(rotateMask(Dir4.left.bit, 1), Dir4.up.bit);
    expect(rotateMask(Dir4.up.bit | Dir4.right.bit, 2), Dir4.down.bit | Dir4.left.bit);
    expect(rotateMask(0xF, 3), 0xF);
    expect(rotateMask(5, 4), 5);
  });

  test('generated networks are spanning trees and start unsolved', () {
    for (final d in PuzzleDifficulty.values) {
      for (var seed = 0; seed < 20; seed++) {
        final c = PipeConfig.forDifficulty(d, seed: seed);
        final net = PipeNetwork.generate(c);
        final n = c.width * c.height;
        var halfEdges = 0;
        for (var i = 0; i < n; i++) {
          final m = net.solution[i];
          expect(m, isNot(0), reason: 'every tile has a pipe');
          halfEdges += bitCount(m);
          expect(
            [0, 1, 2, 3].any((t) => rotateMask(net.scrambled[i], t) == m),
            isTrue,
            reason: 'scrambled tiles are rotations',
          );
        }
        expect(halfEdges, 2 * (n - 1), reason: 'a tree has n-1 edges');
        expect(PipeNetwork.isSolvedLayout(c, net.solution), isTrue);
        expect(PipeNetwork.isSolvedLayout(c, net.scrambled), isFalse);
      }
    }
  });

  test('wrap-around boards connect across the edges', () {
    final c = PipeConfig.forDifficulty(PuzzleDifficulty.expert, seed: 3);
    expect(c.wrap, isTrue);
    expect(PipeNetwork.neighbour(c, 0, Dir4.left), c.width - 1);
    expect(PipeNetwork.neighbour(c, 0, Dir4.up), (c.height - 1) * c.width);
    final flat = PipeConfig.forDifficulty(PuzzleDifficulty.easy);
    expect(PipeNetwork.neighbour(flat, 0, Dir4.left), -1);
  });

  test('rotating every tile into place wins; locks block rotation', () {
    final g = PipeGame(const PipeConfig(width: 6, height: 5, seed: 7));
    final wrong = [
      for (var i = 0; i < 30; i++)
        if (g.masks[i] != g.network.solution[i]) i,
    ];
    expect(g.apply(PipeAction.lock(wrong.first)), isTrue);
    expect(g.apply(PipeAction.rotate(wrong.first)), isFalse);
    expect(g.apply(PipeAction.lock(wrong.first)), isTrue);
    expect(g.apply(PipeAction.rotate(wrong.first, 4)), isFalse, reason: 'a full turn is a no-op');
    for (final i in wrong) {
      var t = 0;
      while (g.masks[i] != g.network.solution[i]) {
        g.apply(PipeAction.rotate(i));
        t++;
        expect(t, lessThan(4));
      }
    }
    expect(g.isSolved, isTrue);
    expect(g.powered().every((p) => p), isTrue);
    expect(g.apply(PipeAction.rotate(0)), isFalse, reason: 'finished');
  });

  test('hints solve every difficulty (including a wrongly locked tile)', () {
    for (final d in PuzzleDifficulty.values) {
      final g = PipeGame(PipeConfig.forDifficulty(d, seed: 5));
      final bad = [for (var i = 0; i < g.masks.length; i++) if (g.masks[i] != g.network.solution[i]) i].first;
      g.apply(PipeAction.lock(bad));
      followHints(g);
      expect(g.isSolved, isTrue, reason: d.name);
    }
  });

  test('random play never throws; undo, replay and JSON', () {
    final g = PipeGame(PipeConfig.forDifficulty(PuzzleDifficulty.hard, seed: 2));
    final rng = SeededRng(2);
    final log = <Map<String, Object?>>[];
    for (var i = 0; i < 2000 && !g.isOver; i++) {
      final cell = rng.nextInt(81);
      final a = rng.nextInt(8) == 0 ? PipeAction.lock(cell) : PipeAction.rotate(cell, rng.nextRange(1, 3));
      if (g.apply(a)) log.add(roundTripJson(a.toJson()));
    }
    expect(replay(PipeGame(PipeConfig.forDifficulty(PuzzleDifficulty.hard, seed: 2)), log), replay(g, const []));
    expectJsonRoundTrip(g);
    while (g.undo()) {}
    expect(g.state.rotations.every((r) => r == 0), isTrue);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/cinema/rules/puzzles/puzzles.dart';

import 'support.dart';

void main() {
  group('line rules', () {
    test('merges resolve from the leading edge, once per tile', () {
      expect(slideLine([2, 2, 2, 2]).line, [4, 4, 0, 0]);
      expect(slideLine([2, 2, 2, 2]).gain, 8);
      expect(slideLine([2, 2, 4, 0]).line, [4, 4, 0, 0]);
      expect(slideLine([4, 4, 8, 0]).line, [8, 8, 0, 0]);
      expect(slideLine([8, 8, 8, 0]).line, [16, 8, 0, 0]);
      expect(slideLine([0, 0, 0, 2]).line, [2, 0, 0, 0]);
      expect(slideLine([2, 0, 2, 4]).line, [4, 4, 0, 0]);
      expect(slideLine([2, 4, 8, 16]).line, [2, 4, 8, 16]);
      expect(slideLine([2, 4, 8, 16]).gain, 0);
      expect(slideLine([4, 0, 0, 4, 8]).line, [8, 8, 0, 0, 0]);
    });

    test('board slides in all four directions', () {
      final cells = [
        2, 0, 0, 2, //
        0, 4, 4, 0,
        0, 0, 0, 0,
        2, 0, 0, 0,
      ];
      expect(slideBoard(cells, 4, Dir4.left).cells.sublist(0, 8), [4, 0, 0, 0, 8, 0, 0, 0]);
      expect(slideBoard(cells, 4, Dir4.right).cells.sublist(0, 8), [0, 0, 0, 4, 0, 0, 0, 8]);
      final up = slideBoard(cells, 4, Dir4.up).cells;
      expect(up.sublist(0, 4), [4, 4, 4, 2]);
      final down = slideBoard(cells, 4, Dir4.down).cells;
      expect(down.sublist(12), [4, 4, 4, 2]);
      expect(slideBoard(cells, 4, Dir4.left).merged, containsAll([0, 4]));
    });
  });

  group('game', () {
    test('starts with two tiles; a legal move spawns exactly one tile', () {
      final g = Merge2048Game(const Merge2048Config(seed: 3));
      expect(g.state.cells.where((v) => v != 0).length, 2);
      final before = g.state.cells.where((v) => v != 0).length;
      final d = g.legalDirections().first;
      final merges = slideBoard(g.state.cells, 4, d).merged.length;
      expect(g.apply(Merge2048Action.slide(d)), isTrue);
      expect(g.state.cells.where((v) => v != 0).length, before - merges + 1);
      expect(g.state.moves, 1);
      expect(g.state.lastSpawn, greaterThanOrEqualTo(0));
    });

    test('a move that changes nothing is illegal', () {
      final g = Merge2048Game.fromCells([
        2, 0, 0, 0, //
        4, 0, 0, 0,
        0, 0, 0, 0,
        0, 0, 0, 0,
      ]);
      expect(g.apply(const Merge2048Action.slide(Dir4.left)), isFalse);
      expect(g.apply(const Merge2048Action.slide(Dir4.up)), isFalse);
      expect(g.state.moves, 0);
      expect(g.apply(const Merge2048Action.slide(Dir4.right)), isTrue);
    });

    test('scores merges and detects a win, then keeps playing on request', () {
      final g = Merge2048Game.fromCells([
        1024, 1024, 0, 0, //
        0, 0, 0, 0,
        0, 0, 0, 0,
        0, 0, 0, 2,
      ]);
      expect(g.isSolved, isFalse);
      expect(g.apply(const Merge2048Action.slide(Dir4.left)), isTrue);
      expect(g.state.score, 2048);
      expect(g.isSolved, isTrue);
      expect(g.isOver, isTrue, reason: 'paused on the win');
      expect(g.apply(const Merge2048Action.slide(Dir4.right)), isFalse);
      expect(g.hint()!.action, const Merge2048Action.keepPlaying());
      expect(g.apply(const Merge2048Action.keepPlaying()), isTrue);
      expect(g.isOver, isFalse);
      expect(g.apply(const Merge2048Action.keepPlaying()), isFalse);
    });

    test('a full board without merges is lost', () {
      final g = Merge2048Game.fromCells([
        2, 4, 2, 4, //
        4, 2, 4, 2,
        2, 4, 2, 4,
        4, 2, 4, 2,
      ]);
      expect(g.isLost, isTrue);
      expect(g.isOver, isTrue);
      expect(g.hint(), isNull);
      for (final d in Dir4.values) {
        expect(g.apply(Merge2048Action.slide(d)), isFalse);
      }
    });

    test('undo restores tiles, score and the spawn RNG', () {
      final g = Merge2048Game(const Merge2048Config(seed: 9));
      final d = g.legalDirections().first;
      g.apply(Merge2048Action.slide(d));
      final after = g.state.toJson().toString();
      expect(g.undo(), isTrue);
      g.apply(Merge2048Action.slide(d));
      expect(g.state.toJson().toString(), after, reason: 'same spawn after redo');
    });

    test('5×5 and 6×6 boards', () {
      for (final size in [5, 6]) {
        final g = Merge2048Game(Merge2048Config(size: size, seed: 1));
        expect(g.state.cells.length, size * size);
        followHints(g, maxSteps: 50);
        expect(g.state.moves, greaterThan(0));
      }
    });
  });

  test('long random play never throws and stays consistent', () {
    for (var seed = 0; seed < 40; seed++) {
      final g = Merge2048Game(Merge2048Config(seed: seed, size: 4 + seed % 3));
      final rng = SeededRng(seed);
      var steps = 0;
      while (!g.isOver && steps < 3000) {
        g.apply(Merge2048Action.slide(rng.pick(Dir4.values)));
        steps++;
      }
      final s = g.state;
      expect(s.cells.every((v) => v == 0 || (v & (v - 1)) == 0), isTrue, reason: 'powers of two');
      expect(s.score, greaterThanOrEqualTo(0));
    }
  });

  test('expectimax hint reaches 512 on easy', () {
    final g = Merge2048Game(Merge2048Config.forDifficulty(PuzzleDifficulty.easy, seed: 2));
    followHints(g, maxSteps: 2000);
    expect(g.state.maxTile, greaterThanOrEqualTo(512));
  });

  test('deterministic replay and JSON round trip', () {
    final a = Merge2048Game(const Merge2048Config(seed: 77));
    final rng = SeededRng(1);
    final log = <Map<String, Object?>>[];
    for (var i = 0; i < 200 && !a.isOver; i++) {
      final action = Merge2048Action.slide(rng.pick(Dir4.values));
      if (a.apply(action)) log.add(roundTripJson(action.toJson()));
    }
    expect(replay(Merge2048Game(const Merge2048Config(seed: 77)), log), replay(a, const []));
    expectJsonRoundTrip(a);
  });
}

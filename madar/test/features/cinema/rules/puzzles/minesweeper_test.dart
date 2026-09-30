import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/cinema/rules/puzzles/puzzles.dart';

import 'support.dart';

void main() {
  test('first click is always safe and opens an area, on every board size', () {
    for (final d in PuzzleDifficulty.values) {
      for (var seed = 0; seed < 15; seed++) {
        final g = MinesweeperGame(MinesweeperConfig.forDifficulty(d, seed: seed));
        final rng = SeededRng(seed);
        final first = rng.nextInt(g.config.cells);
        expect(g.apply(MinesweeperAction.reveal(first)), isTrue);
        final s = g.state;
        expect(s.mines.where((m) => m).length, g.config.mines);
        expect(s.mines[first], isFalse);
        expect(s.numbers[first], 0, reason: 'opening');
        for (final n in g.grid.neighbours8(first)) {
          expect(s.mines[n], isFalse);
          expect(s.revealed[n], isTrue, reason: 'flood fill');
        }
        expect(g.isLost, isFalse);
      }
    }
  });

  test('crowded boards still keep the first cell safe', () {
    final g = MinesweeperGame(const MinesweeperConfig(width: 4, height: 4, mines: 12, seed: 1));
    g.apply(const MinesweeperAction.reveal(5));
    expect(g.state.mines[5], isFalse);
    expect(g.isLost, isFalse);
  });

  group('rules', () {
    late MinesweeperGame g;
    setUp(() {
      g = MinesweeperGame(const MinesweeperConfig(width: 9, height: 9, mines: 10, seed: 4));
      g.apply(const MinesweeperAction.reveal(40));
    });

    test('flags toggle and protect cells; revealed cells cannot be flagged', () {
      final hidden = g.state.revealed.indexWhere((r) => !r);
      expect(g.apply(MinesweeperAction.flag(hidden)), isTrue);
      expect(g.apply(MinesweeperAction.reveal(hidden)), isFalse);
      expect(g.minesLeft, 9);
      expect(g.apply(MinesweeperAction.flag(hidden)), isTrue);
      expect(g.apply(const MinesweeperAction.flag(40)), isFalse);
    });

    test('chording reveals the neighbours when flags match, loses on a wrong flag', () {
      final s = g.state;
      // A revealed number with at least one hidden mine next to it.
      final cell = [
        for (var i = 0; i < 81; i++)
          if (s.revealed[i] && s.numbers[i] > 0 && g.grid.neighbours8(i).any((n) => !s.revealed[n] && !s.mines[n])) i,
      ].first;
      expect(g.apply(MinesweeperAction.chord(cell)), isFalse, reason: 'no flags yet');
      final ok = MinesweeperGame.fromJson(g.toJson());
      for (final n in ok.grid.neighbours8(cell)) {
        if (ok.state.mines[n]) ok.apply(MinesweeperAction.flag(n));
      }
      expect(ok.apply(MinesweeperAction.chord(cell)), isTrue);
      expect(ok.isLost, isFalse);
      for (final n in ok.grid.neighbours8(cell)) {
        expect(ok.state.revealed[n] || ok.state.flags[n], isTrue);
      }
      // Wrong flags: flag safe cells instead of the mines.
      final bad = MinesweeperGame.fromJson(g.toJson());
      final safeHidden = bad.grid.neighbours8(cell).where((n) => !bad.state.revealed[n] && !bad.state.mines[n]).toList();
      final mines = bad.grid.neighbours8(cell).where((n) => bad.state.mines[n]).length;
      if (safeHidden.length >= mines) {
        for (final n in safeHidden.take(bad.state.numbers[cell])) {
          bad.apply(MinesweeperAction.flag(n));
        }
        expect(bad.apply(MinesweeperAction.chord(cell)), isTrue);
        expect(bad.isLost, isTrue);
      }
    });

    test('revealing a mine loses; winning flags every mine', () {
      final lose = MinesweeperGame.fromJson(g.toJson());
      final mine = lose.state.mines.indexOf(true);
      lose.apply(MinesweeperAction.reveal(mine));
      expect(lose.isLost, isTrue);
      expect(lose.state.exploded, mine);
      expect(lose.isOver, isTrue);
      expect(lose.apply(MinesweeperAction.reveal(lose.state.revealed.indexOf(false))), isFalse);
      expect(lose.undo(), isTrue, reason: 'a loss can be taken back');
      expect(lose.isLost, isFalse);

      final win = MinesweeperGame.fromJson(g.toJson());
      for (var i = 0; i < 81; i++) {
        if (!win.state.mines[i] && !win.state.revealed[i]) win.apply(MinesweeperAction.reveal(i));
      }
      expect(win.isSolved, isTrue);
      expect(win.state.flags, win.state.mines);
    });
  });

  test('the deducer is sound on random positions', () {
    for (var seed = 0; seed < 60; seed++) {
      final d = PuzzleDifficulty.values[seed % 3];
      final g = MinesweeperGame(MinesweeperConfig.forDifficulty(d, seed: seed));
      final rng = SeededRng(seed);
      g.apply(MinesweeperAction.reveal(rng.nextInt(g.config.cells)));
      for (var k = 0; k < 6 && !g.isOver; k++) {
        final ded = g.deduce();
        for (final c in ded.safe) {
          expect(g.state.mines[c], isFalse, reason: 'seed $seed');
        }
        for (final c in ded.mines) {
          expect(g.state.mines[c], isTrue, reason: 'seed $seed');
        }
        final safe = ded.safe.where((c) => !g.state.revealed[c]).toList();
        if (safe.isEmpty) break;
        g.apply(MinesweeperAction.reveal(safe.first));
      }
    }
  });

  test('no-guess boards are cleared by hints alone', () {
    for (final d in [PuzzleDifficulty.easy, PuzzleDifficulty.medium]) {
      for (var seed = 0; seed < 8; seed++) {
        final g = MinesweeperGame(MinesweeperConfig.forDifficulty(d, seed: seed, noGuess: true));
        while (!g.isOver) {
          final h = g.hint()!;
          expect(h.technique, isNot('guess'), reason: '$d seed $seed');
          expect(g.apply(h.action), isTrue);
        }
        expect(g.isSolved, isTrue);
      }
    }
  });

  test('hints on ordinary boards never reveal a mine unless guessing', () {
    for (var seed = 0; seed < 20; seed++) {
      final g = MinesweeperGame(MinesweeperConfig.forDifficulty(PuzzleDifficulty.easy, seed: seed));
      var guard = 0;
      while (!g.isOver && guard++ < 500) {
        final h = g.hint()!;
        g.apply(h.action);
        if (g.isLost) expect(h.technique, 'guess');
      }
      expect(g.isOver, isTrue);
    }
  });

  test('long random play never throws; replay and JSON', () {
    for (var seed = 0; seed < 30; seed++) {
      final g = MinesweeperGame(MinesweeperConfig.forDifficulty(PuzzleDifficulty.values[seed % 4], seed: seed));
      final rng = SeededRng(seed);
      final log = <Map<String, Object?>>[];
      for (var i = 0; i < 400 && !g.isOver; i++) {
        final c = rng.nextInt(g.config.cells);
        final a = switch (rng.nextInt(5)) {
          0 => MinesweeperAction.flag(c),
          1 => MinesweeperAction.chord(c),
          _ => MinesweeperAction.reveal(c),
        };
        if (g.apply(a)) log.add(roundTripJson(a.toJson()));
      }
      expectJsonRoundTrip(g);
      final again = MinesweeperGame(MinesweeperConfig.forDifficulty(PuzzleDifficulty.values[seed % 4], seed: seed));
      expect(replay(again, log), replay(g, const []));
    }
  });
}

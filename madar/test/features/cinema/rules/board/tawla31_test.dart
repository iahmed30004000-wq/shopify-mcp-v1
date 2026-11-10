// ٣١ (Tawla 31) – rules T1–T10 of RULES.md §3.
//
// Contrary layout (default): player 0's pip n is index n − 1, player 1's pip
// n is index 24 − n. Parallel layout (option): player 1's pip n is index
// (n + 11) mod 24.
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/cinema/rules/board/backgammon/backgammon_board.dart';
import 'package:madar/features/cinema/rules/board/backgammon/backgammon_rules.dart';
import 'package:madar/features/cinema/rules/board/board_games.dart';

import 'backgammon_test_helpers.dart';

void main() {
  const rules = backgammonRules;
  const parallel = BackgammonConfig(variant: TawlaVariant.tawla31, layout31: Tawla31Layout.parallel, matchTarget: 0);

  test('T1 start (contrary, default): 15 on the own 24-point, stacks facing each other', () {
    final s = BackgammonState.initial(seed: 3, config: BackgammonConfig.tawla31);
    expect(s.points[23], 15);
    expect(s.points[0], -15);
    expect(s.pipCount(0), 360);
    expect(s.pipCount(1), 360);
    expect(s.phase, BackgammonPhase.awaitingRoll);
    expect(BackgammonConfig.tawla31.mode.runnerTarget, 6);
    checkTawla(s);
  });

  test('T1 option parallel: player 1 starts on index 11 and runs 11 → 0 → 23 → 12', () {
    final s = BackgammonState.initial(seed: 3, config: parallel);
    expect(s.points[23], 15);
    expect(s.points[11], -15);
    expect(s.pipCount(1), 360);
    expect(parallel.indexOf(1, 24), 11);
    expect(parallel.indexOf(1, 13), 0);
    expect(parallel.indexOf(1, 12), 23);
    expect(parallel.indexOf(1, 1), 12);
    expect(parallel.indexOf(1, 6), 17);
    for (var pip = 1; pip <= 24; pip++) {
      expect(parallel.pipOf(1, parallel.indexOf(1, pip)), pip);
    }
    final mode = parallel.mode;
    expect(mode.parallel, isTrue);
    expect(mode.runnerTarget, 12);
    for (var m = 1; m <= 24; m++) {
      expect(mode.mirror(m), m <= 12 ? m + 12 : m - 12);
      expect(mode.mirror(mode.mirror(m)), m);
    }
    // Player 1's runner (pip 15, index 2) wraps from index 0 to 23 → 21.
    final wrap = bg({23: 15, 11: -14, 2: -1}, player: 1, dice: const [5, 1], config: parallel);
    expect(rules.nextSteps(wrap, const []), contains(step(2, 21, 5)));
    // Home is indices 12..17: bearing off from index 12 (pip 1).
    final home = bg({23: 15, 12: -1, 17: -1}, off: const [0, 13], player: 1, dice: const [1, 6], config: parallel);
    expect(rules.legalMoves(home), [
      BackgammonMove.play([step(17, off, 6), step(12, off, 1)]),
      BackgammonMove.play([step(17, 16, 1), step(16, off, 6)]),
    ]);
  });

  test('T2 any opposing checker closes a point; nothing is hit or pinned', () {
    final s = bg({23: 13, 12: 1, 2: 1, 9: -1, 0: -14}, dice: const [3, 1], config: tawla31Single);
    expect(rules.nextSteps(s, const []), isNot(contains(step(12, 9, 3))));
    for (final m in rules.legalMoves(s)) {
      final after = rules.apply(s, m);
      expect(after.bar, [0, 0]);
      expect(after.points[9], -1);
      checkTawla(after);
    }
  });

  test('T3 first turn: only one checker leaves the start', () {
    final s0 = BackgammonState.initial(seed: 1, config: tawla31Single);
    for (final dice in const [
      [5, 3],
      [6, 1],
      [2, 2],
      [5, 5],
    ]) {
      final s = s0.copyWith(phase: BackgammonPhase.moving, dice: dice, currentPlayer: 0);
      final plays = rules.legalMoves(s);
      expect(plays, isNotEmpty);
      for (final m in plays) {
        expect(rules.apply(s, m).points[23], 14, reason: '$dice $m');
      }
    }
    // 6-6 is the exception: the runner is home after three sixes (24 → 6)
    // and the fourth six may take a second checker off the start.
    final sixes = s0.copyWith(phase: BackgammonPhase.moving, dice: const [6, 6], currentPlayer: 0);
    expect(
      rules.isLegal(sixes, BackgammonMove.play([step(23, 17, 6), step(17, 11, 6), step(11, 5, 6), step(23, 17, 6)])),
      isTrue,
    );
  });

  test('T3/D13 the runner reaches the target with the first die of a double; the rest are free', () {
    final s = bg({23: 14, 8: 1, 0: -15}, dice: const [3, 3], config: tawla31Single);
    final spread = BackgammonMove.play([step(8, 5, 3), step(23, 20, 3), step(23, 20, 3), step(23, 20, 3)]);
    expect(rules.isLegal(s, spread), isTrue);
    expect(rules.legalMoves(s).any((m) => rules.apply(s, m).points[23] == 11), isTrue);
    expect(rules.isLegal(s, BackgammonMove.play([step(23, 20, 3), step(8, 5, 3), step(23, 20, 3), step(23, 20, 3)])), isFalse);
    expect(rules.nextSteps(s, const []), [step(8, 5, 3)]);
    expect(rules.nextSteps(s, [step(8, 5, 3)]), containsAll([step(23, 20, 3), step(5, 2, 3)]));
  });

  test('T3 the restriction lifts mid-roll for a non-double as well', () {
    final s = bg({23: 14, 8: 1, 0: -15}, dice: const [3, 5], config: tawla31Single);
    expect(rules.isLegal(s, BackgammonMove.play([step(8, 5, 3), step(23, 18, 5)])), isTrue);
    expect(rules.isLegal(s, BackgammonMove.play([step(23, 18, 5), step(8, 5, 3)])), isFalse);
  });

  test('T3 a runner blocked by single checkers: the turn passes', () {
    final s = bg(
      {23: 14, 11: 1, 10: -1, 9: -1, 8: -1, 7: -1, 6: -1, 5: -1, 0: -9},
      dice: const [3, 2],
      config: tawla31Single,
    );
    expect(rules.legalMoves(s), [BackgammonMove.play(const [])]);
    final after = rules.apply(s, BackgammonMove.play(const []));
    expect(after.isOver, isFalse);
    expect(after.currentPlayer, 1);
  });

  test('T3 option runnerTarget opponentHalf: the restriction lifts at own pip 12', () {
    final base = bg({23: 14, 12: 1, 0: -15}, dice: const [1, 2], config: tawla31Single);
    final play = BackgammonMove.play([step(12, 11, 1), step(23, 21, 2)]);
    expect(rules.isLegal(base, play), isFalse);
    const half = BackgammonConfig(
      variant: TawlaVariant.tawla31,
      matchTarget: 0,
      runnerTarget: Tawla31RunnerTarget.opponentHalf,
    );
    expect(rules.isLegal(bg({23: 14, 12: 1, 0: -15}, dice: const [1, 2], config: half), play), isTrue);
  });

  test('T4 maximum dice use with the runner rule; the higher die when only one fits', () {
    final s = bg({23: 14, 11: 1, 3: -1, 0: -14}, dice: const [5, 3], config: tawla31Single);
    expect(rules.legalMoves(s), [
      BackgammonMove.play([step(11, 6, 5)]),
    ]);
  });

  test('T5 bearing off with all 15 home; the opponent stack keeps own point 1 closed', () {
    final s = bg({2: 5, 4: 10, 0: -15}, dice: const [2, 1], config: tawla31Single);
    expect(rules.nextSteps(s, const []), isNot(contains(step(2, 0, 2))));
    final bear = bg({2: 5, 4: 10, 0: -15}, dice: const [5, 3], config: tawla31Single);
    expect(rules.isLegal(bear, BackgammonMove.play([step(4, off, 5), step(2, off, 3)])), isTrue);
  });

  test('T6 round score = the loser\'s checkers left (1, 7, 15), no multiplier', () {
    for (final (loserOff, points) in const [(14, 1), (8, 7), (0, 15)]) {
      final s = bg({1: 1, 18: -(15 - loserOff)}, off: [14, loserOff], dice: const [2, 1], config: tawla31Single);
      final end = rules.apply(s, BackgammonMove.play([step(1, off, 2)]));
      expect(
        end.result,
        GameResult(winners: const [0], reason: tawlaEndReason(TawlaGameEnd.bearOffCount), scores: [points, 0]),
      );
      expect(end.lastGame?.end, TawlaGameEnd.bearOffCount);
    }
  });

  test('T7 match to 31 with overshoot (25 → 40); T8 the next round starts with its winner', () {
    final s = bg({1: 1, 18: -15}, off: const [14, 0], dice: const [2, 1], config: BackgammonConfig.tawla31, matchScores: const [25, 30]);
    final end = rules.apply(s, BackgammonMove.play([step(1, off, 2)]));
    expect(end.result, GameResult(winners: const [0], reason: GameEndReason.targetScoreReached, scores: const [40, 30]));
    final mid = rules.apply(s.copyWith(matchScores: const [0, 0]), BackgammonMove.play([step(1, off, 2)]));
    expect(mid.result, isNull);
    final next = rules.apply(mid, BackgammonMove.nextGame);
    expect(next.currentPlayer, 0);
    expect(next.openingRolls, isEmpty);
    expect(next.points[23], 15);
    expect(next.points[0], -15);
  });

  test('T10 option noFullPrime: no six-point block in front of every opposing checker', () {
    const noPrime = BackgammonConfig(variant: TawlaVariant.tawla31, matchTarget: 0, noFullPrime: true);
    final pos = {2: 1, 6: 1, 7: 1, 8: 1, 9: 1, 10: 1, 13: 1, 23: 8, 0: -15};
    final prime = BackgammonMove.play([step(13, 11, 2), step(23, 22, 1)]);
    expect(rules.isLegal(bg(pos, dice: const [2, 1], config: tawla31Single), prime), isTrue);
    final s = bg(pos, dice: const [2, 1], config: noPrime);
    expect(rules.isLegal(s, prime), isFalse);
    for (final m in rules.legalMoves(s)) {
      final after = rules.apply(s, m);
      expect([for (var i = 6; i <= 11; i++) after.points[i] > 0].every((x) => x), isFalse);
    }
    // Waived when every maximal play would build the block.
    final forced = bg({1: 1, 2: 1, 3: 1, 4: 1, 5: 1, 12: 1, 0: -15}, off: const [9, 0], dice: const [6, 6], config: noPrime);
    expect(rules.legalMoves(forced), [
      BackgammonMove.play([step(12, 6, 6)]),
    ]);
  });

  test('T9 random ٣١ games (both layouts, both runner targets, noFullPrime) end with a winner', () {
    const configs = [
      tawla31Single,
      parallel,
      BackgammonConfig(variant: TawlaVariant.tawla31, matchTarget: 0, runnerTarget: Tawla31RunnerTarget.opponentHalf),
      BackgammonConfig(variant: TawlaVariant.tawla31, matchTarget: 0, noFullPrime: true),
    ];
    for (final c in configs) {
      for (var seed = 0; seed < 4; seed++) {
        final e = playTawla(BackgammonState.initial(seed: seed, config: c), seed: seed);
        final r = e.result!;
        expect(r.winners.length, 1, reason: '${c.toJson()} seed $seed: ${e.state.lastGame}');
        expect(r.scores[r.winners.single], inInclusiveRange(1, 15));
      }
    }
  });

  test('E1 frozen test: one stuck side is not a frozen position', () {
    final s = bg(
      {23: 14, 11: 1, 10: -1, 9: -1, 8: -1, 7: -1, 6: -1, 5: -1, 0: -9},
      dice: const [3, 2],
      config: tawla31Single,
    );
    // Every roll is blocked for player 0's runner and his start waits…
    expect(hasAnyPlay(boardFor(s, 0)), isFalse);
    // …but player 1 can move, so the pass does not void the game.
    expect(hasAnyPlay(boardFor(s, 1)), isTrue);
    expect(rules.apply(s, BackgammonMove.play(const [])).isOver, isFalse);
  });
}

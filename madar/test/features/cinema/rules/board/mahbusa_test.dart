// محبوسة (Mahbusa) – rules M1–M15 and E5 of RULES.md §3.
//
// Coordinates: player 0's pip n is index n − 1 (moves 23 → 0, home 0..5);
// player 1's pip n is index 24 − n (moves 0 → 23, home 18..23).
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/cinema/rules/board/backgammon/backgammon_board.dart';
import 'package:madar/features/cinema/rules/board/backgammon/backgammon_rules.dart';
import 'package:madar/features/cinema/rules/board/board_games.dart';

import 'backgammon_test_helpers.dart';

void main() {
  const rules = backgammonRules;
  const motherOn = BackgammonConfig(variant: TawlaVariant.mahbusa, matchTarget: 0, motherRule: true);

  test('M1 start: all 15 on the own 24-point, the stacks facing each other', () {
    for (var seed = 0; seed < 5; seed++) {
      final s = BackgammonState.initial(seed: seed, config: BackgammonConfig.mahbusa);
      expect(s.points[23], 15);
      expect(s.points[0], -15);
      expect(s.points.where((v) => v != 0).length, 2);
      expect(s.pinned.every((o) => o == -1), isTrue);
      expect(s.pipCount(0), 360);
      expect(s.pipCount(1), 360);
      checkTawla(s);
    }
  });

  test('M2 opening as G4: the winner rolls both dice afresh', () {
    final s = BackgammonState.initial(seed: 8, config: BackgammonConfig.mahbusa);
    expect(s.phase, BackgammonPhase.awaitingRoll);
    expect(rules.legalMoves(s), [BackgammonMove.roll]);
  });

  test('M3/M5 no hitting, no bar: landing on a lone checker pins it', () {
    final s = bg({23: 14, 12: 1, 0: -14, 9: -1}, config: mahbusaSingle);
    final after = rules.apply(s, BackgammonMove.play([step(12, 9, 3), step(23, 22, 1)]));
    expect(after.pinned[9], 1);
    expect(after.points[9], 1);
    expect(after.bar, [0, 0]);
    expect(after.pinnedCount(1), 1);
    expect(after.pipCount(1), s.pipCount(1)); // the pinned checker still counts where it is
    checkTawla(after);
  });

  test('M4 a point with two or more opposing checkers is closed', () {
    final s = bg({23: 14, 12: 1, 0: -13, 9: -2}, config: mahbusaSingle);
    expect(rules.nextSteps(s, const []), isNot(contains(step(12, 9, 3))));
    expect(rules.isLegal(s, BackgammonMove.play([step(12, 9, 3), step(23, 22, 1)])), isFalse);
  });

  test('M4/M5 a point the opponent controls is closed to the pinned side', () {
    // Player 1's checker is pinned on index 9 under player 0's checker.
    final s = bg({23: 14, 9: 1, 0: -13, 5: -1}, pinned: {9: 1}, player: 1, dice: const [4, 1], config: mahbusaSingle);
    checkTawla(s);
    expect(rules.nextSteps(s, const []), isNot(contains(step(5, 9, 4))));
    expect(rules.nextSteps(s, const []), contains(step(0, 4, 4)));
    for (final m in rules.legalMoves(s)) {
      expect(m.steps.any((x) => x.to == 9), isFalse);
    }
  });

  test('M5 the pinner may stack more checkers on its pin', () {
    final s = bg({23: 13, 12: 1, 9: 1, 0: -14}, pinned: {9: 1}, config: mahbusaSingle);
    final after = rules.apply(s, BackgammonMove.play([step(12, 9, 3), step(23, 22, 1)]));
    expect(after.points[9], 2);
    expect(after.pinned[9], 1);
    checkTawla(after);
  });

  test('M6 moving the pinner away with the second die releases the checker', () {
    final s = bg({23: 14, 12: 1, 0: -14, 9: -1}, dice: const [3, 2], config: mahbusaSingle);
    final after = rules.apply(s, BackgammonMove.play([step(12, 9, 3), step(9, 7, 2)]));
    expect(after.pinned[9], -1);
    expect(after.points[9], -1); // a free lone checker again (it can be pinned again)
    expect(after.points[7], 1);
    checkTawla(after);
    // Released, it is an ordinary blot: landing there pins it again.
    final again = bg({23: 14, 12: 1, 0: -14, 9: -1}, dice: const [3, 1], config: mahbusaSingle);
    expect(rules.apply(again, BackgammonMove.play([step(12, 9, 3), step(23, 22, 1)])).pinned[9], 1);
  });

  test('M6 bearing off the pinner releases the checker', () {
    final s = bg({2: 1, 4: 2, 20: -14}, pinned: {2: 1}, off: const [12, 0], dice: const [3, 5], config: mahbusaSingle);
    checkTawla(s);
    final after = rules.apply(s, BackgammonMove.play([step(2, off, 3), step(4, off, 5)]));
    expect(after.pinned[2], -1);
    expect(after.points[2], -1);
    expect(after.off, [14, 0]);
    checkTawla(after);
  });

  test('M7 a pinned checker cannot move; with nothing movable the turn passes', () {
    // Player 1: one checker pinned on index 9, the other 14 on its 2-point
    // facing player 0's closed start; bearing off is not allowed.
    final s = bg({9: 1, 23: 14, 22: -14}, pinned: {9: 1}, player: 1, dice: const [1, 2], config: mahbusaSingle);
    checkTawla(s);
    expect(rules.legalMoves(s), [BackgammonMove.play(const [])]);
    expect(hasAnyPlay(boardFor(s, 1)), isFalse);
    expect(hasAnyPlay(boardFor(s, 0)), isTrue);
    final after = rules.apply(s, BackgammonMove.play(const []));
    expect(after.isOver, isFalse, reason: 'E1 only fires when neither side can ever move');
    expect(after.phase, BackgammonPhase.awaitingRoll);
    expect(after.currentPlayer, 0);
  });

  test('M8 no bearing off while one of the mover\'s checkers is pinned, even after bear-off began', () {
    final pinned = bg(
      {5: 6, 3: 7, 1: -1, 20: -14},
      pinned: {1: 0},
      off: const [1, 0],
      dice: const [4, 1],
      config: mahbusaSingle,
    );
    checkTawla(pinned);
    final plays = rules.legalMoves(pinned);
    expect(plays, isNotEmpty);
    for (final m in plays) {
      expect(m.steps.any((x) => x.to == off), isFalse);
    }
    expect(rules.isLegal(pinned, BackgammonMove.play([step(3, off, 4), step(5, 4, 1)])), isFalse);
    // The same position with that checker free: bearing off is allowed.
    final free = bg({5: 6, 3: 7, 1: 1, 20: -15}, off: const [1, 0], dice: const [4, 1], config: mahbusaSingle);
    expect(rules.isLegal(free, BackgammonMove.play([step(3, off, 4), step(5, 4, 1)])), isTrue);
  });

  test('M9 score: 1, or «مارس» 2 when the loser has borne off nothing; never a triple', () {
    const withTriple = BackgammonConfig(variant: TawlaVariant.mahbusa, matchTarget: 0, triple: TawlaTriple.standard);
    final mars = rules.apply(
      bg({0: 1, 3: -1, 20: -14}, off: const [14, 0], dice: const [1, 2], config: withTriple),
      BackgammonMove.play([step(0, off, 2)]),
    );
    expect(mars.result, GameResult(winners: const [0], reason: GameEndReason.bearOffGammon, scores: const [2, 0]));
    final singleWin = rules.apply(
      bg({0: 1, 20: -12}, off: const [14, 3], dice: const [1, 2], config: mahbusaSingle),
      BackgammonMove.play([step(0, off, 2)]),
    );
    expect(singleWin.result, GameResult(winners: const [0], reason: GameEndReason.bearOffSingle, scores: const [1, 0]));
  });

  test('M9 option checkersTo31: the loser gives up the checkers left; match to 31', () {
    const count = BackgammonConfig(variant: TawlaVariant.mahbusa, mahbusaScoring: MahbusaScoring.checkersTo31);
    expect(count.target, 31);
    final end = rules.apply(
      bg({0: 1, 20: -12}, off: const [14, 3], dice: const [1, 2], config: count),
      BackgammonMove.play([step(0, off, 2)]),
    );
    expect(end.matchScores, [12, 0]);
    expect(end.lastGame?.end, TawlaGameEnd.bearOffCount);
  });

  // Player 0 pins player 1's last checker on its start point (index 0) with
  // the 6 from index 6; player 0 has nothing left on its own start.
  BackgammonState motherPosition(BackgammonConfig c) =>
      bg({6: 12, 3: 3, 0: -1, 12: -14}, dice: const [6, 1], config: c);
  final pinMother = BackgammonMove.play([step(6, 0, 6), step(6, 5, 1)]);

  test('M10 motherRule off (default): a pinned mother does not end the game', () {
    final after = rules.apply(motherPosition(mahbusaSingle), pinMother);
    expect(after.pinned[0], 1);
    expect(after.isOver, isFalse);
    expect(after.phase, BackgammonPhase.awaitingRoll);
  });

  test('M10 motherRule on: mother pinned and the pinner\'s start empty → «مارس» at once', () {
    final after = rules.apply(motherPosition(motherOn), pinMother);
    expect(
      after.result,
      GameResult(winners: const [0], reason: tawlaEndReason(TawlaGameEnd.motherPinned), scores: const [2, 0]),
    );
    expect(after.lastGame?.end, TawlaGameEnd.motherPinned);
  });

  test('M10 motherRule on: the game goes on while the pinner has a checker on his start, then wins 2', () {
    final s = bg({0: 1, 23: 1, 6: 13, 12: -14}, pinned: {0: 1}, dice: const [6, 5], config: motherOn);
    checkTawla(s);
    final stays = rules.apply(s, BackgammonMove.play([step(6, 1, 5), step(6, 0, 6)]));
    expect(stays.isOver, isFalse);
    final leaves = rules.apply(s, BackgammonMove.play([step(23, 17, 6), step(6, 1, 5)]));
    expect(leaves.result?.winners, [0]);
    expect(leaves.result?.scores, [2, 0]);
    expect(leaves.lastGame?.end, TawlaGameEnd.motherPinned);
  });

  test('M10 motherRule with checkersTo31: a pinned mother gives up all 15', () {
    const c = BackgammonConfig(
      variant: TawlaVariant.mahbusa,
      motherRule: true,
      mahbusaScoring: MahbusaScoring.checkersTo31,
    );
    final after = rules.apply(motherPosition(c), pinMother);
    expect(after.matchScores, [15, 0]);
  });

  test('M11/E5 both mothers pinned → a void game 0–0, whatever motherRule says', () {
    for (final c in [mahbusaSingle, motherOn]) {
      final s = bg({6: 14, 23: -1, 0: -1, 12: -13}, pinned: {23: 0}, dice: const [6, 1], config: c);
      checkTawla(s);
      final after = rules.apply(s, pinMother);
      expect(after.result, GameResult.draw(tawlaEndReason(TawlaGameEnd.bothMothersPinned), scores: const [0, 0]));
      expect(after.lastGame, const TawlaGameSummary(number: 1, winner: null, points: 0, end: TawlaGameEnd.bothMothersPinned));
    }
    // In a match the void game is replayed from an opening roll.
    final s = bg({6: 14, 23: -1, 0: -1, 12: -13}, pinned: {23: 0}, dice: const [6, 1], config: BackgammonConfig.mahbusa);
    final over = rules.apply(s, pinMother);
    expect(over.phase, BackgammonPhase.gameOver);
    expect(over.matchScores, [0, 0]);
    final next = rules.apply(over, BackgammonMove.nextGame);
    expect(next.openingRolls, isNotEmpty);
    expect(next.points[23], 15);
    expect(next.pinned.every((o) => o == -1), isTrue);
  });

  test('M13 a start point with two or more checkers is closed; the last one can be pinned', () {
    final two = bg({6: 12, 3: 3, 0: -2, 12: -13}, dice: const [6, 1], config: mahbusaSingle);
    expect(rules.nextSteps(two, const []), isNot(contains(step(6, 0, 6))));
    final one = motherPosition(mahbusaSingle);
    expect(rules.nextSteps(one, const []), contains(step(6, 0, 6)));
  });

  test('M14 random محبوسة games end with a winner or a void E5/E1/E2 game, invariants hold', () {
    for (final c in [mahbusaSingle, motherOn]) {
      for (var seed = 0; seed < 5; seed++) {
        final e = playTawla(BackgammonState.initial(seed: seed, config: c), seed: seed);
        final r = e.result!;
        final end = e.state.lastGame!.end;
        if (r.isDraw) {
          expect(end.isVoid, isTrue);
        } else {
          expect(r.scores[r.winners.single], inInclusiveRange(1, 2));
        }
      }
    }
  });
}

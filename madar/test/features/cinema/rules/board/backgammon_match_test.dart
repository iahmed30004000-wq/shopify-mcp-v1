// طاولة الزهر – the match layer (X1–X5) and the engine guards (E2, E3),
// named after the rules in RULES.md §3.
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/cinema/rules/board/backgammon/backgammon_rules.dart';
import 'package:madar/features/cinema/rules/board/board_games.dart';

import 'backgammon_test_helpers.dart';
import 'board_test_utils.dart';

void main() {
  const rules = backgammonRules;
  const match5 = BackgammonConfig(); // the Jordanian default: a match to 5

  /// Player 0 is about to bear off his last checker (on the 6-point) with
  /// 6-5; the loser has [loserOff] checkers off.
  BackgammonState lastChecker({
    BackgammonConfig config = match5,
    List<int> scores = const [0, 0],
    int loserOff = 0,
    int cube = 1,
  }) => bg(
    {5: 1, 12: -(15 - loserOff)},
    off: [14, loserOff],
    dice: const [6, 5],
    config: config,
    matchScores: scores,
    cubeValue: cube,
    cubeOwner: cube > 1 ? 1 : -1,
  );

  final bearOff = BackgammonMove.play([step(5, off, 6)]);

  test('X1 a game below the target ends in gameOver; the only move is nextGame', () {
    final s = rules.apply(lastChecker(loserOff: 1), bearOff);
    expect(s.result, isNull);
    expect(s.isOver, isFalse);
    expect(s.phase, BackgammonPhase.gameOver);
    expect(s.matchScores, [1, 0]);
    expect(s.lastGame, const TawlaGameSummary(number: 1, winner: 0, points: 1, end: TawlaGameEnd.bearOffSingle));
    expect(s.currentPlayer, 0);
    expect(rules.legalMoves(s), [BackgammonMove.nextGame]);
    expect(rules.isLegal(s, BackgammonMove.roll), isFalse);
    checkTawla(s);
  });

  test('X1/X2 the first to reach the target wins the match; overshoot allowed (5 → 6)', () {
    final s = rules.apply(lastChecker(scores: const [4, 3]), bearOff);
    expect(
      s.result,
      GameResult(winners: const [0], reason: GameEndReason.targetScoreReached, scores: const [6, 3]),
    );
    expect(s.lastGame?.points, 2);
    expect(s.phase, BackgammonPhase.gameOver);
    expect(rules.legalMoves(s), isEmpty);
  });

  test('X1 matchTarget 0 = a single game: the game result is final', () {
    final s = rules.apply(lastChecker(config: single, loserOff: 2), bearOff);
    expect(s.result, GameResult(winners: const [0], reason: GameEndReason.bearOffSingle, scores: const [1, 0]));
  });

  test('X3 the previous winner starts the next game and rolls at once (default)', () {
    final over = rules.apply(lastChecker(loserOff: 1, scores: const [0, 2]), bearOff);
    final next = rules.apply(over, BackgammonMove.nextGame);
    expect(next.gameNumber, 2);
    expect(next.currentPlayer, 0);
    expect(next.phase, BackgammonPhase.awaitingRoll);
    expect(next.openingRolls, isEmpty);
    expect(next.dice, isEmpty);
    expect(next.matchScores, [1, 2]);
    expect(next.points, BackgammonState.startingPoints(match5));
    expect(next.bar, [0, 0]);
    expect(next.off, [0, 0]);
    expect(next.turns, 0);
    expect(next.lastGame, over.lastGame);
    expect(rules.legalMoves(next), [BackgammonMove.roll]);
    checkTawla(next);
  });

  test('X3 option openingRoll: every game opens with an opening roll', () {
    const cfg = BackgammonConfig(nextGameStarter: TawlaNextStarter.openingRoll);
    final next = rules.apply(rules.apply(lastChecker(config: cfg, loserOff: 1), bearOff), BackgammonMove.nextGame);
    final o = next.openingRolls;
    expect(o, isNotEmpty);
    expect(next.currentPlayer, o[o.length - 2] > o.last ? 0 : 1);
    expect(next.phase, BackgammonPhase.awaitingRoll);
    // …and with the international opening the starter plays those dice.
    const intl = BackgammonConfig(nextGameStarter: TawlaNextStarter.openingRoll, openingRollIsFirstMove: true);
    final next2 = rules.apply(rules.apply(lastChecker(config: intl, loserOff: 1), bearOff), BackgammonMove.nextGame);
    expect(next2.phase, BackgammonPhase.moving);
    expect(next2.dice, next2.openingRolls.sublist(next2.openingRolls.length - 2));
  });

  test('X4 a dropped double scores the cube value toward the match', () {
    const cube = BackgammonConfig(doublingCube: true);
    final offered = bg(
      const {23: 2, 12: 5, 7: 3, 5: 5, 0: -2, 11: -5, 16: -3, 18: -5},
      phase: BackgammonPhase.doubleOffered,
      player: 1,
      config: cube,
      cubeValue: 2,
      cubeOwner: 0,
      matchScores: const [1, 0],
    );
    final dropped = rules.apply(offered, BackgammonMove.drop);
    expect(dropped.matchScores, [3, 0]);
    expect(dropped.lastGame, const TawlaGameSummary(number: 1, winner: 0, points: 2, end: TawlaGameEnd.doubleDeclined));
    expect(dropped.result, isNull);
    final won = rules.apply(offered.copyWith(matchScores: const [3, 0]), BackgammonMove.drop);
    expect(won.result, GameResult(winners: const [0], reason: GameEndReason.targetScoreReached, scores: const [5, 0]));
  });

  test('X4 the cube resets to 1, centred, for the next game', () {
    const cube = BackgammonConfig(doublingCube: true);
    final over = rules.apply(lastChecker(config: cube, loserOff: 1, cube: 4), bearOff);
    expect(over.matchScores, [4, 0]);
    final next = rules.apply(over, BackgammonMove.nextGame);
    expect(next.cubeValue, 1);
    expect(next.cubeOwner, -1);
  });

  test('X5/E2 a void game (turn cap) scores nothing; the next game opens with an opening roll', () {
    const capped = BackgammonConfig(maxTurns: 1);
    final s = bg(const {23: 2, 12: 5, 7: 3, 5: 5, 0: -2, 11: -5, 16: -3, 18: -5}, config: capped);
    final over = rules.apply(s, rules.legalMoves(s).first);
    expect(over.phase, BackgammonPhase.gameOver);
    expect(over.result, isNull);
    expect(over.matchScores, [0, 0]);
    expect(over.lastGame, const TawlaGameSummary(number: 1, winner: null, points: 0, end: TawlaGameEnd.moveLimit));
    expect(over.lastGame!.isVoid, isTrue);
    final next = rules.apply(over, BackgammonMove.nextGame);
    expect(next.openingRolls, isNotEmpty);
    expect(next.gameNumber, 2);
  });

  test('E2 the turn cap counts plays, passes included; single game → a draw', () {
    const capped = BackgammonConfig(matchTarget: 0, maxTurns: 3);
    final e = playTawla(BackgammonState.initial(seed: 2, config: capped), seed: 2);
    expect(e.result, GameResult.draw(GameEndReason.moveLimit, scores: const [0, 0]));
    expect(e.state.turns, 3);
    expect(e.history.where((m) => m.kind == BackgammonMoveKind.play).length, 3);
  });

  test('E3/X5 seed + moves replay a whole match of every variant; no tie at the target', () {
    const configs = [
      BackgammonConfig.jordan,
      BackgammonConfig.mahbusa,
      BackgammonConfig.tawla31,
      BackgammonConfig(variant: TawlaVariant.tawla31, layout31: Tawla31Layout.parallel),
    ];
    for (final c in configs) {
      final e = playTawla(BackgammonState.initial(seed: 5, config: c), seed: 5, check: false);
      final r = e.result!;
      expect(r.reason, GameEndReason.targetScoreReached);
      expect(r.winners.length, 1);
      final w = r.winners.single;
      expect(r.scores[w], greaterThanOrEqualTo(c.target));
      expect(r.scores[1 - w], lessThan(c.target));
      expect(e.state.gameNumber, greaterThanOrEqualTo(3), reason: 'at least three games to reach ${c.target}');
      final restored = BoardGameEngine<BackgammonState, BackgammonMove>.fromJson(rules, roundTrip(e.toJson()));
      expect(canonical(restored.state), canonical(e.state));
    }
  });

  test('undo crosses a game boundary and restores the finished game', () {
    final e = BoardGameEngine<BackgammonState, BackgammonMove>(rules, lastChecker(loserOff: 1));
    e.apply(bearOff);
    final over = canonical(e.state);
    e.apply(BackgammonMove.nextGame);
    expect(e.undo(), BackgammonMove.nextGame);
    expect(canonical(e.state), over);
  });

  test('state JSON round trip keeps pins, match scores, turns and the last game', () {
    final s = bg(
      const {0: 1, 23: -1, 12: 13, 11: -13},
      pinned: const {0: 1, 23: 0},
      config: BackgammonConfig.mahbusa,
      matchScores: const [3, 1],
    ).copyWith(turns: 17, lastGame: const TawlaGameSummary(number: 4, winner: 1, points: 2, end: TawlaGameEnd.bearOffGammon));
    final copy = BackgammonState.fromJson(roundTrip(s.toJson()));
    expect(canonical(copy), canonical(s));
    expect(copy.pinned[0], 1);
    expect(copy.pinned[23], 0);
    expect(copy.pinnedCount(0), 1);
    expect(copy.turns, 17);
    expect(copy.lastGame?.number, 4);
    checkTawla(copy);
  });

  test('moves round-trip through JSON, including nextGame', () {
    for (final m in [
      BackgammonMove.roll,
      BackgammonMove.nextGame,
      BackgammonMove.drop,
      BackgammonMove.play([step(bar, 21, 3), step(5, off, 6)]),
    ]) {
      expect(BackgammonMove.fromJson(roundTrip(m.toJson())), m);
    }
  });
}

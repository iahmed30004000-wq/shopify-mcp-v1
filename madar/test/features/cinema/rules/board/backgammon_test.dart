import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/cinema/rules/board/board_games.dart';

import 'board_test_utils.dart';

BackgammonState bg(
  Map<int, int> points, {
  List<int> bar = const [0, 0],
  List<int> off = const [0, 0],
  int player = 0,
  List<int> dice = const [3, 1],
  BackgammonPhase phase = BackgammonPhase.moving,
  BackgammonConfig config = const BackgammonConfig(),
  List<int> rng = const [1, 2, 3, 4],
}) {
  final p = List<int>.filled(24, 0);
  points.forEach((k, v) => p[k] = v);
  return BackgammonState(
    config: config,
    points: p,
    bar: bar,
    off: off,
    currentPlayer: player,
    phase: phase,
    dice: phase == BackgammonPhase.moving ? dice : const [],
    rng: rng,
  );
}

const step = BackgammonStep.new;
const bar = BackgammonStep.bar, off = BackgammonStep.off;

/// The standard start from player 0's view.
const Map<int, int> start = {23: 2, 12: 5, 7: 3, 5: 5, 0: -2, 11: -5, 16: -3, 18: -5};

void main() {
  const rules = backgammonRules;

  test('initial position and opening roll', () {
    for (var seed = 0; seed < 20; seed++) {
      final s = BackgammonState.initial(seed: seed);
      checkInvariants(s);
      expect(s.pipCount(0), 167);
      expect(s.pipCount(1), 167);
      expect(s.phase, BackgammonPhase.moving);
      expect(s.dice[0], isNot(s.dice[1]));
      expect(s.currentPlayer, s.dice[0] > s.dice[1] ? 0 : 1);
      expect(s.openingRolls.length.isEven, isTrue);
      expect(canonical(BackgammonState.initial(seed: seed)), canonical(s));
    }
  });

  test('house rule: the opening winner rolls afresh', () {
    const cfg = BackgammonConfig(openingRollIsFirstMove: false);
    final s = BackgammonState.initial(seed: 4, config: cfg);
    expect(s.phase, BackgammonPhase.awaitingRoll);
    expect(s.dice, isEmpty);
    expect(s.currentPlayer, s.openingRolls[s.openingRolls.length - 2] > s.openingRolls.last ? 0 : 1);
    expect(rules.legalMoves(s), [BackgammonMove.roll]);
  });

  test('the next roll survives a JSON round trip (deterministic dice)', () {
    final s = bg(start, phase: BackgammonPhase.awaitingRoll, rng: const [9, 8, 7, 6]);
    final a = rules.apply(s, BackgammonMove.roll);
    final b = rules.apply(BackgammonState.fromJson(roundTrip(s.toJson())), BackgammonMove.roll);
    expect(b.dice, a.dice);
    expect(a.dice.every((d) => d >= 1 && d <= 6), isTrue);
  });

  test('a checker on the bar must enter first', () {
    final s = bg({5: 5, 7: 3, 12: 5, 23: 1, 0: -2, 11: -5, 16: -3, 18: -5}, bar: const [1, 0]);
    final plays = rules.legalMoves(s);
    expect(plays, isNotEmpty);
    for (final m in plays) {
      expect(m.steps.first.from, bar);
    }
    expect(plays.map((m) => m.steps.first.to).toSet(), {21, 23});
  });

  test('a closed board forces a pass', () {
    final s = bg({5: 14, 18: -2, 19: -2, 20: -2, 21: -2, 22: -2, 23: -2, 0: -3}, bar: const [1, 0], dice: const [4, 2]);
    expect(rules.legalMoves(s), [BackgammonMove.play(const [])]);
    final next = rules.apply(s, BackgammonMove.play(const []));
    expect(next.currentPlayer, 1);
    expect(next.phase, BackgammonPhase.awaitingRoll);
  });

  test('both dice must be used when possible', () {
    final s = bg({5: 1, 12: -15}, off: const [14, 0], dice: const [6, 5]);
    expect(rules.legalMoves(s), [
      BackgammonMove.play([step(5, 0, 5), step(0, off, 6)]),
    ]);
    final end = rules.apply(s, rules.legalMoves(s).single);
    expect(end.result, const GameResult(winners: [0], reason: GameEndReason.bearOffGammon, scores: [2, 0]));
  });

  test('if only one die can be played, it must be the higher', () {
    final s = bg({19: 1, 10: -2}, off: const [14, 13], dice: const [3, 6]);
    expect(rules.legalMoves(s), [
      BackgammonMove.play([step(19, 13, 6)]),
    ]);
    final bearOff = bg({0: 1, 3: -1, 12: -14}, off: const [14, 0], dice: const [1, 2]);
    expect(rules.legalMoves(bearOff), [
      BackgammonMove.play([step(0, off, 2)]),
    ]);
    final end = rules.apply(bearOff, rules.legalMoves(bearOff).single);
    expect(end.result?.reason, GameEndReason.bearOffBackgammon);
    expect(end.result?.scores, [3, 0]);
  });

  test('bearing off with a higher die from the highest point; single game', () {
    final s = bg({2: 2, 12: -14}, off: const [13, 1], dice: const [6, 5]);
    expect(rules.legalMoves(s), [
      BackgammonMove.play([step(2, off, 6), step(2, off, 5)]),
    ]);
    final end = rules.apply(s, rules.legalMoves(s).single);
    expect(end.result, const GameResult(winners: [0], reason: GameEndReason.bearOffSingle, scores: [1, 0]));
  });

  test('no bearing off while a checker is outside the home board', () {
    final s = bg({6: 1, 0: 14, 12: -15}, dice: const [6, 6]);
    for (final m in rules.legalMoves(s)) {
      expect(m.steps.first, step(6, 0, 6));
      expect(m.steps.skip(1).every((x) => x.to == off), isTrue);
    }
  });

  test('hitting a blot sends it to the bar; any step order is accepted', () {
    final s = bg({5: 14, 7: 1, 4: -1, 20: -14});
    final play = BackgammonMove.play([step(7, 4, 3), step(5, 4, 1)]);
    final reversed = BackgammonMove.play([step(5, 4, 1), step(7, 4, 3)]);
    expect(rules.isLegal(s, play), isTrue);
    expect(rules.isLegal(s, reversed), isTrue);
    expect(rules.isLegal(s, BackgammonMove.play([step(7, 4, 3)])), isFalse); // must use both dice
    expect(rules.isLegal(s, BackgammonMove.play([step(7, 3, 3), step(5, 4, 1)])), isFalse);
    final after = rules.apply(s, reversed);
    expect(after.bar, [0, 1]);
    expect(after.points[4], 2);
    checkInvariants(after);
  });

  test('player 1 moves the other way and enters on the low points', () {
    final s = bg({0: -1, 23: 15}, bar: const [0, 1], off: const [0, 13], player: 1, dice: const [2, 5]);
    final plays = rules.legalMoves(s);
    expect(plays.every((m) => m.steps.first.from == bar), isTrue);
    expect(plays.map((m) => m.steps.first.to).toSet(), {1, 4});
  });

  test('nextSteps guides a one-checker-at-a-time UI', () {
    final s = bg(start);
    final first = rules.nextSteps(s, const []);
    expect(first, containsAll([step(7, 4, 3), step(5, 4, 1)]));
    expect(rules.nextSteps(s, [step(7, 4, 3)]), contains(step(5, 4, 1)));
    expect(rules.nextSteps(s, [step(7, 4, 3), step(5, 4, 1)]), isEmpty);
  });

  group('doubling cube', () {
    const cube = BackgammonConfig(doublingCube: true);

    test('offer, take, and ownership', () {
      final s = bg(start, phase: BackgammonPhase.awaitingRoll, config: cube);
      expect(rules.legalMoves(s), [BackgammonMove.roll, BackgammonMove.offerDouble]);
      final offered = rules.apply(s, BackgammonMove.offerDouble);
      expect(offered.currentPlayer, 1);
      expect(rules.legalMoves(offered), [BackgammonMove.take, BackgammonMove.drop]);
      final taken = rules.apply(offered, BackgammonMove.take);
      expect(taken.cubeValue, 2);
      expect(taken.cubeOwner, 1);
      expect(taken.currentPlayer, 0);
      expect(rules.legalMoves(taken), [BackgammonMove.roll]); // no redouble without the cube
    });

    test('drop concedes the current cube value', () {
      final s = rules.apply(bg(start, phase: BackgammonPhase.awaitingRoll, config: cube), BackgammonMove.offerDouble);
      final end = rules.apply(s, BackgammonMove.drop);
      expect(end.result, const GameResult(winners: [0], reason: GameEndReason.doubleDeclined, scores: [1, 0]));
    });

    test('no cube unless enabled', () {
      expect(rules.legalMoves(bg(start, phase: BackgammonPhase.awaitingRoll)), [BackgammonMove.roll]);
    });
  });

  group('ai', () {
    test('never reads the dice RNG', () {
      final a = bg(start, dice: const [6, 4], rng: const [1, 1, 1, 1]);
      final b = bg(start, dice: const [6, 4], rng: const [99, 98, 97, 96]);
      for (final level in AiLevel.values) {
        expect(
          const BackgammonAi().chooseMove(a, level, BoardRng(3), const AiBudget.nodes(3000)),
          const BackgammonAi().chooseMove(b, level, BoardRng(3), const AiBudget.nodes(3000)),
        );
      }
    });

    test('hard hits a blot and makes a point with 3-1', () {
      final m = const BackgammonAi().chooseMove(bg(start), AiLevel.hard, BoardRng(1), const AiBudget.nodes(20000));
      // The classic 3-1 opening: 8/5 6/5.
      expect(rules.apply(bg(start), m).points[4], 2);
    });

    test('cube decisions', () {
      // Far ahead in a race: double; the opponent should drop.
      final ahead = bg(
        {1: 15, 0: -15},
        phase: BackgammonPhase.awaitingRoll,
        config: const BackgammonConfig(doublingCube: true),
      );
      expect(const BackgammonAi().chooseMove(ahead, AiLevel.hard, BoardRng(1)), BackgammonMove.offerDouble);
      final offered = rules.apply(ahead, BackgammonMove.offerDouble);
      expect(const BackgammonAi().chooseMove(offered, AiLevel.hard, BoardRng(1)), BackgammonMove.drop);
      // Even start: just roll.
      final even = bg(start, phase: BackgammonPhase.awaitingRoll, config: const BackgammonConfig(doublingCube: true));
      expect(const BackgammonAi().chooseMove(even, AiLevel.hard, BoardRng(1)), BackgammonMove.roll);
    });
  });
}

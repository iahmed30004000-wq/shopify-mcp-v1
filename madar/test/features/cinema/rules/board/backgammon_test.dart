// طاولة الزهر – the shared rules (G*) and شيش بيش (S*), named after the rules
// in RULES.md §3. Match layer: backgammon_match_test.dart; محبوسة:
// mahbusa_test.dart; ٣١: tawla31_test.dart; AI: backgammon_ai_test.dart.
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/cinema/rules/board/backgammon/backgammon_rules.dart';
import 'package:madar/features/cinema/rules/board/board_games.dart';

import 'backgammon_test_helpers.dart';
import 'board_test_utils.dart';

/// The شيش بيش start from player 0's view.
const Map<int, int> start = {23: 2, 12: 5, 7: 3, 5: 5, 0: -2, 11: -5, 16: -3, 18: -5};

void main() {
  const rules = backgammonRules;

  group('§2 configuration', () {
    test('D1 BackgammonConfig() is the Jordanian default (jordan)', () {
      const c = BackgammonConfig();
      expect(c, BackgammonConfig.jordan);
      expect(c.variant, TawlaVariant.sheshBesh);
      expect(c.openingRollIsFirstMove, isFalse);
      expect(c.nextGameStarter, TawlaNextStarter.previousWinner);
      expect(c.matchTarget, isNull);
      expect(c.target, 5);
      expect(c.gammons, isTrue);
      expect(c.triple, TawlaTriple.none);
      expect(c.doublingCube, isFalse);
      expect(c.maxCube, 64);
      expect(c.motherRule, isFalse);
      expect(c.mahbusaScoring, MahbusaScoring.points);
      expect(c.layout31, Tawla31Layout.contrary);
      expect(c.runnerTarget, Tawla31RunnerTarget.opponentStartQuadrant);
      expect(c.noFullPrime, isFalse);
      expect(c.maxTurns, 2000);
      final kitGame = boardGameKits[BoardGameId.backgammon]!.newGame(players: 2, seed: 3) as BackgammonState;
      expect(kitGame.config, BackgammonConfig.jordan);
    });

    test('X2 match targets: 5 (شيش بيش, محبوسة), 31 (٣١ and count-scored محبوسة), 0 = one game', () {
      expect(BackgammonConfig.jordan.target, 5);
      expect(BackgammonConfig.mahbusa.target, 5);
      expect(BackgammonConfig.tawla31.target, 31);
      expect(
        const BackgammonConfig(variant: TawlaVariant.mahbusa, mahbusaScoring: MahbusaScoring.checkersTo31).target,
        31,
      );
      expect(const BackgammonConfig(matchTarget: 7).target, 7);
      expect(single.target, 0);
    });

    test('config JSON round trip for every named config and option', () {
      const configs = [
        BackgammonConfig.jordan,
        BackgammonConfig.mahbusa,
        BackgammonConfig.tawla31,
        BackgammonConfig.international,
        BackgammonConfig(doublingCube: true, maxCube: 16, triple: TawlaTriple.barOnly, gammons: false),
        BackgammonConfig(variant: TawlaVariant.mahbusa, motherRule: true, mahbusaScoring: MahbusaScoring.checkersTo31),
        BackgammonConfig(
          variant: TawlaVariant.tawla31,
          layout31: Tawla31Layout.parallel,
          runnerTarget: Tawla31RunnerTarget.opponentHalf,
          noFullPrime: true,
          nextGameStarter: TawlaNextStarter.openingRoll,
          matchTarget: 0,
          maxTurns: 99,
          openingRollIsFirstMove: true,
        ),
      ];
      for (final c in configs) {
        expect(BackgammonConfig.fromJson(roundTrip(c.toJson())), c);
      }
    });

    test('config fromJson rejects impossible numbers (a turn cap of 0 would void every game of a match)', () {
      for (final (key, value) in const [('maxTurns', 0), ('target', -1), ('maxCube', 0)]) {
        final json = BackgammonConfig.jordan.toJson()..[key] = value;
        expect(() => BackgammonConfig.fromJson(json), throwsFormatException, reason: '$key: $value');
      }
    });

    test('D6 the doubling cube is a شيش بيش option only', () {
      final json = BackgammonConfig.mahbusa.toJson()..['cube'] = true;
      expect(() => BackgammonConfig.fromJson(json), throwsFormatException);
      expect(() => BackgammonConfig(variant: TawlaVariant.tawla31, doublingCube: true), throwsA(isA<AssertionError>()));
    });

    test('international config keeps the earlier engine behaviour reachable', () {
      const c = BackgammonConfig.international;
      final s = BackgammonState.initial(seed: 4, config: c);
      expect(s.phase, BackgammonPhase.moving);
      expect(s.dice[0], isNot(s.dice[1]));
      final end = rules.apply(
        bg({0: 1, 3: -1, 12: -14}, off: const [14, 0], dice: const [1, 2], config: c),
        BackgammonMove.play([step(0, off, 2)]),
      );
      expect(end.result, GameResult(winners: const [0], reason: GameEndReason.bearOffBackgammon, scores: const [3, 0]));
    });
  });

  group('§3 shared rules', () {
    test('G3/G4 opening roll: ties re-rolled, the higher die starts and rolls both dice afresh', () {
      for (var seed = 0; seed < 20; seed++) {
        final s = BackgammonState.initial(seed: seed);
        checkInvariants(s);
        checkTawla(s);
        expect(s.pipCount(0), 167);
        expect(s.pipCount(1), 167);
        expect(s.phase, BackgammonPhase.awaitingRoll);
        expect(s.dice, isEmpty);
        final o = s.openingRolls;
        expect(o.length.isEven, isTrue);
        for (var i = 0; i + 2 < o.length; i += 2) {
          expect(o[i], o[i + 1], reason: 'only a tie is re-rolled');
        }
        expect(o[o.length - 2], isNot(o.last));
        expect(s.currentPlayer, o[o.length - 2] > o.last ? 0 : 1);
        expect(rules.legalMoves(s), [BackgammonMove.roll]);
        expect(canonical(BackgammonState.initial(seed: seed)), canonical(s));
      }
    });

    test('G4 option openingRollIsFirstMove: the starter plays the two opening dice', () {
      const cfg = BackgammonConfig(openingRollIsFirstMove: true);
      for (var seed = 0; seed < 10; seed++) {
        final s = BackgammonState.initial(seed: seed, config: cfg);
        expect(s.phase, BackgammonPhase.moving);
        expect(s.dice, s.openingRolls.sublist(s.openingRolls.length - 2));
        expect(s.currentPlayer, s.dice[0] > s.dice[1] ? 0 : 1);
      }
    });

    test('E3 the next roll survives a JSON round trip (deterministic dice)', () {
      final s = bg(start, phase: BackgammonPhase.awaitingRoll, rng: const [9, 8, 7, 6]);
      final a = rules.apply(s, BackgammonMove.roll);
      final b = rules.apply(BackgammonState.fromJson(roundTrip(s.toJson())), BackgammonMove.roll);
      expect(b.dice, a.dice);
      expect(a.dice.every((d) => d >= 1 && d <= 6), isTrue);
    });

    test('G5 one checker using both dice needs an open intermediate point', () {
      // Player 0's last checker outside home on pip 13; pips 7 and 8 closed.
      final blocked = bg({12: 1, 6: -2, 7: -2, 20: -11}, off: const [14, 0], dice: const [6, 5]);
      expect(rules.legalMoves(blocked), [BackgammonMove.play(const [])]);
      expect(rules.isLegal(blocked, BackgammonMove.play([step(12, 6, 6), step(6, 1, 5)])), isFalse);
      // Only pip 7 closed: 13 → 8 → 2 is fine, 13 → 7 → 2 is not.
      final half = bg({12: 1, 6: -2, 20: -13}, off: const [14, 0], dice: const [6, 5]);
      expect(rules.isLegal(half, BackgammonMove.play([step(12, 7, 5), step(7, 1, 6)])), isTrue);
      expect(rules.isLegal(half, BackgammonMove.play([step(12, 6, 6), step(6, 1, 5)])), isFalse);
    });

    test('G6 doubles are played four times', () {
      final plays = rules.legalMoves(bg(start, dice: const [2, 2]));
      expect(plays, isNotEmpty);
      for (final m in plays) {
        expect(m.steps.length, 4);
        expect(m.steps.every((x) => x.die == 2), isTrue);
      }
    });

    test('G7 both dice must be used when possible; any step order is accepted', () {
      final s = bg({5: 14, 7: 1, 4: -1, 20: -14});
      expect(rules.isLegal(s, BackgammonMove.play([step(7, 4, 3), step(5, 4, 1)])), isTrue);
      expect(rules.isLegal(s, BackgammonMove.play([step(5, 4, 1), step(7, 4, 3)])), isTrue);
      expect(rules.isLegal(s, BackgammonMove.play([step(7, 4, 3)])), isFalse);
      expect(rules.isLegal(s, BackgammonMove.play([step(7, 3, 3), step(5, 4, 1)])), isFalse);
    });

    test('G7 if only one die can be played, it must be the higher', () {
      final s = bg({19: 1, 10: -2}, off: const [14, 13], dice: const [3, 6]);
      expect(rules.legalMoves(s), [
        BackgammonMove.play([step(19, 13, 6)]),
      ]);
    });

    test('G7 the higher-die rule also picks a bear-off as the single move', () {
      // 5/off with the 5 and 5→3 with the 2 are each possible, never both.
      final s = bg({5: 1, 4: 1, 0: -2, 3: -2, 12: -11}, off: const [13, 0], dice: const [5, 2]);
      expect(rules.legalMoves(s), [
        BackgammonMove.play([step(4, off, 5)]),
      ]);
      expect(rules.isLegal(s, BackgammonMove.play([step(4, 2, 2)])), isFalse);
    });

    test('G7 no legal move: the turn passes as an empty play', () {
      final s = bg({5: 14, 18: -2, 19: -2, 20: -2, 21: -2, 22: -2, 23: -2, 0: -3}, bar: const [1, 0], dice: const [4, 2]);
      expect(rules.legalMoves(s), [BackgammonMove.play(const [])]);
      final next = rules.apply(s, BackgammonMove.play(const []));
      expect(next.currentPlayer, 1);
      expect(next.phase, BackgammonPhase.awaitingRoll);
      expect(next.isOver, isFalse);
    });

    test('G8 bearing off: the exact point', () {
      final s = bg({5: 1, 4: 1, 2: 1, 12: -15}, off: const [12, 0], dice: const [5, 3]);
      expect(rules.isLegal(s, BackgammonMove.play([step(4, off, 5), step(2, off, 3)])), isTrue);
    });

    test('G8 bearing off: a higher die takes the highest checker', () {
      final s = bg({2: 2, 12: -14}, off: const [13, 1], dice: const [6, 5]);
      expect(rules.legalMoves(s), [
        BackgammonMove.play([step(2, off, 6), step(2, off, 5)]),
      ]);
    });

    test('G8 bearing off: otherwise the die is played inside the home board', () {
      final s = bg({5: 1, 1: 1, 12: -15}, off: const [13, 0], dice: const [4, 3]);
      final first = rules.nextSteps(s, const []);
      expect(first, isNot(contains(step(1, off, 4))));
      expect(first, isNot(contains(step(1, off, 3))));
      expect(first, containsAll([step(5, 1, 4), step(5, 2, 3)]));
    });

    test('G8 no bearing off while a checker is outside the home board', () {
      final s = bg({6: 1, 0: 14, 12: -15}, dice: const [6, 6]);
      for (final m in rules.legalMoves(s)) {
        expect(m.steps.first, step(6, 0, 6));
        expect(m.steps.skip(1).every((x) => x.to == off), isTrue);
      }
    });

    test('G9 bearing off is never compulsory', () {
      final s = bg({1: 2, 4: 1, 12: -15}, off: const [12, 0], dice: const [2, 1]);
      expect(rules.isLegal(s, BackgammonMove.play([step(4, 2, 2), step(2, 1, 1)])), isTrue);
      expect(rules.isLegal(s, BackgammonMove.play([step(1, off, 2), step(1, 0, 1)])), isTrue);
    });

    test('G10/E4 bearing off the 15th checker ends the play even with a die left', () {
      final s = bg({5: 1, 12: -15}, off: const [14, 0], dice: const [6, 5]);
      final direct = BackgammonMove.play([step(5, off, 6)]);
      final indirect = BackgammonMove.play([step(5, 0, 5), step(0, off, 6)]);
      expect(rules.legalMoves(s), [direct]);
      expect(rules.isLegal(s, direct), isTrue);
      expect(rules.isLegal(s, indirect), isTrue);
      expect(rules.isLegal(s, BackgammonMove.play([step(5, 0, 5)])), isFalse);
      expect(rules.nextSteps(s, const []), containsAll([step(5, off, 6), step(5, 0, 5)]));
      expect(rules.nextSteps(s, [step(5, 0, 5)]), [step(0, off, 6)]);
      expect(rules.nextSteps(s, [step(5, off, 6)]), isEmpty);
      for (final m in [direct, indirect]) {
        final end = rules.apply(s, m);
        expect(end.result, GameResult(winners: const [0], reason: GameEndReason.bearOffGammon, scores: const [2, 0]));
        expect(end.lastGame, const TawlaGameSummary(number: 1, winner: 0, points: 2, end: TawlaGameEnd.bearOffGammon));
      }
    });

    test('G10/E4 with a double: two checkers off and the game ends', () {
      final s = bg({0: 2, 12: -14}, off: const [13, 1], dice: const [6, 6]);
      expect(rules.legalMoves(s), [
        BackgammonMove.play([step(0, off, 6), step(0, off, 6)]),
      ]);
    });

    test('nextSteps guides a one-checker-at-a-time UI', () {
      final s = bg(start);
      final first = rules.nextSteps(s, const []);
      expect(first, containsAll([step(7, 4, 3), step(5, 4, 1)]));
      expect(rules.nextSteps(s, [step(7, 4, 3)]), contains(step(5, 4, 1)));
      expect(rules.nextSteps(s, [step(7, 4, 3), step(5, 4, 1)]), isEmpty);
    });
  });

  group('§4 شيش بيش', () {
    test('S1 start: 2 on 24, 5 on 13, 3 on 8, 5 on 6 for each side', () {
      final s = BackgammonState.initial(seed: 1);
      for (final e in start.entries) {
        expect(s.points[e.key], e.value);
      }
      expect(s.points.where((v) => v != 0).length, 8);
    });

    test('S2/S3 two opposing checkers close a point; a blot is hit to the bar', () {
      final s = bg({5: 14, 7: 1, 4: -1, 6: -2, 20: -12});
      expect(rules.nextSteps(s, const []), isNot(contains(step(7, 6, 1))));
      expect(rules.isLegal(s, BackgammonMove.play([step(7, 6, 1), step(5, 2, 3)])), isFalse);
      final after = rules.apply(s, BackgammonMove.play([step(5, 4, 1), step(7, 4, 3)]));
      expect(after.bar, [0, 1]);
      expect(after.points[4], 2);
      checkTawla(after);
    });

    test('S3 one checker can hit on each step, including the last step of the play', () {
      final s = bg({9: 1, 5: 14, 6: -1, 4: -1, 20: -13}, dice: const [3, 2]);
      final after = rules.apply(s, BackgammonMove.play([step(9, 6, 3), step(6, 4, 2)]));
      expect(after.bar, [0, 2]);
      expect(after.points[4], 1);
      expect(after.points[6], 0);
      checkTawla(after);
    });

    test('S4 a checker on the bar must enter first (own point 25 − die)', () {
      final s = bg({5: 5, 7: 3, 12: 5, 23: 1, 0: -2, 11: -5, 16: -3, 18: -5}, bar: const [1, 0]);
      final plays = rules.legalMoves(s);
      expect(plays, isNotEmpty);
      for (final m in plays) {
        expect(m.steps.first.from, bar);
      }
      expect(plays.map((m) => m.steps.first.to).toSet(), {21, 23});
    });

    test('S4 entering with a double: up to four checkers', () {
      final s = bg({5: 11, 11: -15}, bar: const [4, 0], dice: const [3, 3]);
      expect(rules.legalMoves(s), [
        BackgammonMove.play([step(bar, 21, 3), step(bar, 21, 3), step(bar, 21, 3), step(bar, 21, 3)]),
      ]);
    });

    test('S4 enter, then move the same checker with the other die', () {
      final s = bg({0: 14, 11: -15}, bar: const [1, 0], dice: const [4, 2]);
      expect(rules.legalMoves(s).single.steps.last.to, 18);
      expect(rules.isLegal(s, BackgammonMove.play([step(bar, 20, 4), step(20, 18, 2)])), isTrue);
      expect(rules.isLegal(s, BackgammonMove.play([step(bar, 22, 2), step(22, 18, 4)])), isTrue);
    });

    test('S4 one checker enters, the other die is lost', () {
      final s = bg({0: 13, 20: -2, 11: -13}, bar: const [2, 0], dice: const [4, 2]);
      expect(rules.legalMoves(s), [
        BackgammonMove.play([step(bar, 22, 2)]),
      ]);
    });

    test('S4 player 1 moves the other way and enters on the low points', () {
      final s = bg({0: -1, 23: 15}, bar: const [0, 1], off: const [0, 13], player: 1, dice: const [2, 5]);
      final plays = rules.legalMoves(s);
      expect(plays.every((m) => m.steps.first.from == bar), isTrue);
      expect(plays.map((m) => m.steps.first.to).toSet(), {1, 4});
    });

    test('S5 a checker hit while bearing off must come home before bear-off resumes', () {
      final s = bg({5: 6, 3: 5, 12: -15}, bar: const [1, 0], off: const [3, 0], dice: const [6, 5]);
      final plays = rules.legalMoves(s);
      expect(plays, isNotEmpty);
      for (final m in plays) {
        expect(m.steps.first.from, bar);
        expect(m.steps.any((x) => x.to == off), isFalse);
      }
    });

    group('S6/S7 scoring', () {
      GameResult? finish(BackgammonConfig c, {List<int> loserBar = const [0, 0], Map<int, int>? pts}) => rules
          .apply(
            bg(pts ?? {0: 1, 3: -1, 12: -14}, bar: loserBar, off: const [14, 0], dice: const [1, 2], config: c),
            BackgammonMove.play([step(0, off, 2)]),
          )
          .result;

      test('S6 single win = 1', () {
        final s = bg({2: 2, 12: -14}, off: const [13, 1], dice: const [6, 5]);
        final end = rules.apply(s, rules.legalMoves(s).single);
        expect(end.result, GameResult(winners: const [0], reason: GameEndReason.bearOffSingle, scores: const [1, 0]));
      });

      test('S6/S7 «مارس» = 2; triple none (default) even with a checker in the winner home', () {
        expect(finish(single)?.scores, [2, 0]);
        expect(finish(single)?.reason, GameEndReason.bearOffGammon);
      });

      test('S7 triple barOnly: 3 only with a loser checker on the bar', () {
        const c = BackgammonConfig(matchTarget: 0, triple: TawlaTriple.barOnly);
        expect(finish(c)?.scores, [2, 0]);
        final barred = finish(c, loserBar: const [0, 1], pts: {0: 1, 12: -14});
        expect(barred, GameResult(winners: const [0], reason: GameEndReason.bearOffBackgammon, scores: const [3, 0]));
      });

      test('S7 triple standard: 3 with a loser checker on the bar or in the winner home', () {
        const c = BackgammonConfig(matchTarget: 0, triple: TawlaTriple.standard);
        expect(finish(c)?.scores, [3, 0]);
        expect(finish(c, pts: {0: 1, 12: -15})?.scores, [2, 0]);
      });

      test('S6 option gammons: false → every win is single', () {
        expect(finish(const BackgammonConfig(matchTarget: 0, gammons: false))?.scores, [1, 0]);
      });

      test('S6 points are multiplied by the cube', () {
        const c = BackgammonConfig(matchTarget: 0, doublingCube: true);
        final end = rules.apply(
          bg({0: 1, 12: -15}, off: const [14, 0], dice: const [1, 2], config: c, cubeValue: 2, cubeOwner: 0),
          BackgammonMove.play([step(0, off, 2)]),
        );
        expect(end.result?.scores, [4, 0]);
      });
    });

    group('S8 doubling cube (option)', () {
      const cube = BackgammonConfig(doublingCube: true, matchTarget: 0);

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
        expect(end.result, GameResult(winners: const [0], reason: GameEndReason.doubleDeclined, scores: const [1, 0]));
        expect(end.lastGame?.end, TawlaGameEnd.doubleDeclined);
      });

      test('maxCube caps the cube, even when it is not a power of two', () {
        const capped = BackgammonConfig(doublingCube: true, matchTarget: 0, maxCube: 3);
        final at2 = bg(start, phase: BackgammonPhase.awaitingRoll, config: capped, cubeValue: 2, cubeOwner: 0);
        expect(rules.legalMoves(at2), [BackgammonMove.roll], reason: 'doubling 2 would give 4 > maxCube 3');
        // The default cap 64: a 32 cube can still be doubled, a 64 cube cannot.
        final at32 = bg(start, phase: BackgammonPhase.awaitingRoll, config: cube, cubeValue: 32, cubeOwner: 0);
        expect(rules.legalMoves(at32), [BackgammonMove.roll, BackgammonMove.offerDouble]);
        expect(rules.legalMoves(at32.copyWith(cubeValue: 64)), [BackgammonMove.roll]);
      });

      test('no cube unless enabled (off by default)', () {
        expect(rules.legalMoves(bg(start, phase: BackgammonPhase.awaitingRoll)), [BackgammonMove.roll]);
      });
    });

    test('S10 no ties: random شيش بيش games always end with a winner', () {
      for (var seed = 0; seed < 4; seed++) {
        final e = playTawla(BackgammonState.initial(seed: seed, config: single), seed: seed);
        expect(e.result?.winners.length, 1);
        expect(e.state.lastGame?.isVoid, isFalse);
      }
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
      const cube = BackgammonConfig(doublingCube: true, matchTarget: 0);
      // Far ahead in a race: double; the opponent should drop.
      final ahead = bg({1: 15, 0: -15}, phase: BackgammonPhase.awaitingRoll, config: cube);
      expect(const BackgammonAi().chooseMove(ahead, AiLevel.hard, BoardRng(1)), BackgammonMove.offerDouble);
      final offered = rules.apply(ahead, BackgammonMove.offerDouble);
      expect(const BackgammonAi().chooseMove(offered, AiLevel.hard, BoardRng(1)), BackgammonMove.drop);
      // Even start: just roll.
      final even = bg(start, phase: BackgammonPhase.awaitingRoll, config: cube);
      expect(const BackgammonAi().chooseMove(even, AiLevel.hard, BoardRng(1)), BackgammonMove.roll);
    });
  });
}

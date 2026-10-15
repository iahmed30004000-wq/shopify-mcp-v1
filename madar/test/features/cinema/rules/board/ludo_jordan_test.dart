// Ludo «لودو» as commonly played in Jordan – one test per rule of the final
// spec (rule ids L-…, E-L… as in RULES.md §5).
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/cinema/rules/board/board_games.dart' show BoardGameId, boardGameKits;
import 'package:madar/features/cinema/rules/board/core/engine.dart';
import 'package:madar/features/cinema/rules/board/core/game_types.dart';
import 'package:madar/features/cinema/rules/board/core/rng.dart';
import 'package:madar/features/cinema/rules/board/ludo/ludo_rules.dart';

import 'board_test_utils.dart' show canonical, roundTrip;

const y = kLudoYard;
const h = kLudoHome;
const rules = ludoRules;

LudoState ludo(
  List<List<int>> tokens, {
  int player = 0,
  int dice = 0,
  int sixes = 0,
  LudoConfig? config,
  List<int> ranking = const [],
  int tries = 0,
  List<bool>? captured,
}) => LudoState(
  config: config ?? LudoConfig(players: tokens.length),
  tokens: tokens,
  currentPlayer: player,
  phase: dice == 0 ? LudoPhase.awaitingRoll : LudoPhase.awaitingMove,
  rng: const [1, 2, 3, 4],
  dice: dice,
  consecutiveSixes: sixes,
  ranking: ranking,
  yardTries: tries,
  captured: captured,
);

/// The same state with die [d] showing (as if just rolled).
LudoState rolled(LudoState s, int d) =>
    s.copyWith(phase: LudoPhase.awaitingMove, dice: d, consecutiveSixes: d == 6 ? s.consecutiveSixes + 1 : 0);

/// Structural invariants, including the lapping square of `mustCapture`.
void ludoInvariants(LudoState s) {
  for (final t in s.tokens) {
    expect(t.length, s.config.tokensPerPlayer);
    for (final x in t) {
      expect(x, inInclusiveRange(y, s.config.captureToEnterHome ? kLudoBeforeStart : h));
    }
  }
  expect(s.captured, hasLength(s.config.players));
  expect(s.yardTries, lessThan(s.config.yardRollAttempts));
  // Two colours never share a non-safe square (captures would have happened),
  // except safe pairs and allies.
  final owners = <int, Set<int>>{};
  for (var p = 0; p < s.config.players; p++) {
    for (final t in s.tokens[p]) {
      final sq = s.absoluteSquare(p, t);
      if (sq >= 0 && !s.config.isSafe(sq)) (owners[sq] ??= {}).add(p);
    }
  }
  if (!s.config.pairsAreSafe) {
    owners.forEach((sq, ps) {
      final list = ps.toList();
      for (var i = 0; i < list.length; i++) {
        for (var j = i + 1; j < list.length; j++) {
          expect(s.config.allies(list[i], list[j]), isTrue, reason: 'square $sq shared by ${list[i]} and ${list[j]}');
        }
      }
    });
  }
}

void main() {
  group('configuration', () {
    test('LudoConfig() and the kit are the Jordanian game', () {
      const c = LudoConfig();
      expect(c, const LudoConfig.jordan(players: 4));
      expect(c.exitRolls, [6]);
      expect(c.extraTurnOnSix && c.extraTurnOnCapture && c.extraTurnOnHome, isTrue);
      expect(c.maxConsecutiveSixes, 3);
      expect(c.exactRollToFinish, isTrue);
      expect(c.safeSquares, LudoSafeSquares.startAndStars);
      expect(c.blockades || c.safePairs || c.playUntilLast || c.teams || c.captureToEnterHome, isFalse);
      expect(c.firstPlayer, LudoFirstPlayer.random);
      expect(c.yardRollAttempts, 1);
      expect(c.bonusRollOnUnusableSix, isFalse);
      for (final n in [2, 3, 4]) {
        final s = boardGameKits[BoardGameId.ludo]!.newGame(players: n, seed: 5) as LudoState;
        expect(s.config, LudoConfig.jordan(players: n));
      }
    });

    test('L-C4: an old save without the new keys starts with seat 0 and no new options', () {
      final old = const LudoConfig(players: 2).toJson()
        ..remove('safePairs')
        ..remove('first')
        ..remove('yardTries')
        ..remove('unusableSixAgain')
        ..remove('mustCapture')
        ..remove('teams');
      final c = LudoConfig.fromJson(old);
      expect(c, const LudoConfig(players: 2, firstPlayer: LudoFirstPlayer.seat0));
      // Old states lack `tries` and `captured`.
      final state = LudoState.fromJson({
        'config': old,
        'tokens': [
          [y, y, y, y],
          [y, y, y, y],
        ],
        'player': 0,
        'phase': 'awaitingRoll',
        'rng': [1, 2, 3, 4],
        'dice': 0,
        'sixes': 0,
        'ranking': <int>[],
      });
      expect(state.yardTries, 0);
      expect(state.captured, [false, false]);
    });

    test('every option survives a JSON round-trip', () {
      const c = LudoConfig(
        players: 4,
        tokensPerPlayer: 3,
        exitRolls: [1, 6],
        extraTurnOnSix: false,
        maxConsecutiveSixes: 0,
        extraTurnOnCapture: false,
        extraTurnOnHome: false,
        exactRollToFinish: false,
        safeSquares: LudoSafeSquares.startOnly,
        blockades: true,
        playUntilLast: true,
        safePairs: true,
        firstPlayer: LudoFirstPlayer.seat0,
        yardRollAttempts: 3,
        bonusRollOnUnusableSix: true,
        captureToEnterHome: true,
        teams: true,
      );
      expect(LudoConfig.fromJson(roundTrip(c.toJson())), c);
    });
  });

  group('setup and turns', () {
    test('L-1, L-2: 2–4 players, 4 tokens in the yard; two players sit opposite', () {
      for (final n in [2, 3, 4]) {
        final s = LudoState.initial(seed: 1, config: LudoConfig(players: n));
        expect(s.tokens, hasLength(n));
        expect(s.tokens.every((t) => t.length == 4 && t.every((x) => x == y)), isTrue);
      }
      const two = LudoConfig(players: 2);
      expect([two.seatOf(0), two.seatOf(1)], [0, 2]);
      const three = LudoConfig(players: 3);
      expect([three.seatOf(0), three.seatOf(1), three.seatOf(2)], [0, 1, 2]);
    });

    test('L-3: the first player is a seeded random draw that leaves the dice untouched', () {
      for (final n in [2, 3, 4]) {
        final counts = List.filled(n, 0);
        for (var seed = 0; seed < 1200; seed++) {
          final s = LudoState.initial(
            seed: seed,
            config: LudoConfig(players: n),
          );
          counts[s.currentPlayer]++;
          final fixed = LudoState.initial(
            seed: seed,
            config: LudoConfig(players: n, firstPlayer: LudoFirstPlayer.seat0),
          );
          expect(fixed.currentPlayer, 0);
          expect(s.rng, fixed.rng, reason: 'the dice stream is not consumed');
          expect(
            LudoState.initial(
              seed: seed,
              config: LudoConfig(players: n),
            ).currentPlayer,
            s.currentPlayer,
          );
        }
        final expected = 1200 / n;
        for (final c in counts) {
          expect(c, inInclusiveRange(expected * 0.8, expected * 1.2), reason: '$n players: $counts');
        }
      }
      // Stored in the saved state, so a replay starts with the same player.
      final s = LudoState.initial(seed: 7, config: const LudoConfig(players: 4));
      expect(LudoState.fromJson(roundTrip(s.toJson())).currentPlayer, s.currentPlayer);
    });

    test('L-4, L-5: one die; a player who can move must move', () {
      final s = ludo([
        [10, y, y, y],
        [y, y, y, y],
      ], dice: 3);
      expect(rules.legalMoves(s), [const LudoMove.move(0)]);
      final r = rules.apply(
        ludo([
          [10, y, y, y],
          [y, y, y, y],
        ]),
        LudoMove.roll,
      );
      expect(r.dice, inInclusiveRange(1, 6));
      expect(r.phase, LudoPhase.awaitingMove);
    });

    test('L-6: only a 6 leaves the yard, onto the start square, using the whole roll', () {
      final five = ludo([
        [y, y, y, y],
        [y, y, y, y],
      ], dice: 5);
      expect(rules.legalMoves(five), [LudoMove.pass]);
      final six = ludo(
        [
          [y, y, y, y],
          [y, y, y, y],
        ],
        dice: 6,
        sixes: 1,
      );
      expect(rules.legalMoves(six), hasLength(4));
      final out = rules.apply(six, const LudoMove.move(2));
      expect(out.tokens[0], [y, y, 0, y]);
      expect(out.absoluteSquare(0, 0), 0);
      // L-25 option: a 1 also leaves the yard.
      final one = ludo(
        [
          [y, y, y, y],
          [y, y, y, y],
        ],
        dice: 1,
        config: const LudoConfig(players: 2, exitRolls: [1, 6]),
      );
      expect(rules.apply(one, const LudoMove.move(0)).tokens[0][0], 0);
    });

    test('L-7: a 6 may move a token that is already out instead', () {
      final s = ludo(
        [
          [10, y, y, y],
          [y, y, y, y],
        ],
        dice: 6,
        sixes: 1,
      );
      expect(rules.legalMoves(s).toSet(), {for (var t = 0; t < 4; t++) LudoMove.move(t)});
      expect(rules.apply(s, const LudoMove.move(0)).tokens[0][0], 16);
    });

    test('L-8: all tokens in the yard – one roll by default', () {
      final s = rules.apply(
        ludo([
          [y, y, y, y],
          [y, y, y, y],
        ], dice: 3),
        LudoMove.pass,
      );
      expect(s.currentPlayer, 1);
      expect(s.yardTries, 0);
    });

    test('L-8 option, E-L12: three tries while no token is out; a 6 exits with the normal bonus', () {
      const cfg = LudoConfig(players: 2, yardRollAttempts: 3);
      var s = ludo(
        [
          [y, y, y, h],
          [y, y, y, y],
        ],
        dice: 3,
        config: cfg,
      );
      s = rules.apply(s, LudoMove.pass);
      expect((s.currentPlayer, s.yardTries, s.phase), (0, 1, LudoPhase.awaitingRoll));
      expect(LudoState.fromJson(roundTrip(s.toJson())).yardTries, 1);
      s = rules.apply(rolled(s, 2), LudoMove.pass);
      expect((s.currentPlayer, s.yardTries), (0, 2));
      s = rules.apply(rolled(s, 4), LudoMove.pass);
      expect((s.currentPlayer, s.yardTries), (1, 0));
      // A 6 on the first try: exit, then the six's bonus roll.
      final six = rules.apply(
        rolled(
          ludo([
            [y, y, y, y],
            [y, y, y, y],
          ], config: cfg),
          6,
        ),
        const LudoMove.move(0),
      );
      expect((six.currentPlayer, six.yardTries, six.tokens[0][0]), (0, 0, 0));
      // With a token out the tries do not apply.
      final out = rules.apply(
        ludo(
          [
            [53, y, y, y],
            [y, y, y, y],
          ],
          dice: 5,
          config: cfg,
        ),
        LudoMove.pass,
      );
      expect(out.currentPlayer, 1);
    });

    test('L-9: a 6 gives another roll (and the run of sixes is counted)', () {
      final s = rules.apply(
        ludo(
          [
            [10, y, y, y],
            [y, y, y, y],
          ],
          dice: 6,
          sixes: 1,
        ),
        const LudoMove.move(0),
      );
      expect((s.currentPlayer, s.phase, s.consecutiveSixes), (0, LudoPhase.awaitingRoll, 1));
    });

    test('L-10: a capture gives another roll', () {
      final s = rules.apply(
        ludo([
          [1, y, y, y],
          [30, y, y, y],
        ], dice: 3),
        const LudoMove.move(0),
      );
      expect(s.tokens[1][0], y);
      expect(s.currentPlayer, 0);
    });

    test('L-11: a token reaching home gives another roll', () {
      final s = rules.apply(
        ludo([
          [53, 20, y, y],
          [y, y, y, y],
        ], dice: 3),
        const LudoMove.move(0),
      );
      expect(s.tokens[0][0], h);
      expect(s.currentPlayer, 0);
    });

    test('L-12: at most one extra roll per move (a 6 that captures earns one roll, not two)', () {
      var s = rules.apply(
        ludo(
          [
            [1, 20, y, y],
            [33, y, y, y],
          ],
          dice: 6,
          sixes: 1,
        ),
        const LudoMove.move(0),
      );
      expect(s.tokens[1][0], y, reason: 'captured on absolute 7');
      expect((s.currentPlayer, s.phase), (0, LudoPhase.awaitingRoll));
      s = rules.apply(rolled(s, 2), const LudoMove.move(1));
      expect(s.currentPlayer, 1, reason: 'no second bonus is left over');
    });

    test('L-13: the third 6 ends the turn, earlier moves stand; a non-6 bonus roll breaks the run', () {
      final third = ludo(
        [
          [22, y, y, y],
          [y, y, y, y],
        ],
        dice: 6,
        sixes: 3,
      );
      expect(rules.legalMoves(third), [LudoMove.pass]);
      final next = rules.apply(third, LudoMove.pass);
      expect(next.currentPlayer, 1);
      expect(next.consecutiveSixes, 0);
      expect(next.tokens[0][0], 22, reason: 'the moves of the first two sixes stand');
      // Six, six, then a capture with a 4: the bonus roll starts a new run.
      final s = rules.apply(
        ludo([
          [1, y, y, y],
          [31, y, y, y],
        ], dice: 4).copyWith(consecutiveSixes: 0),
        const LudoMove.move(0),
      );
      expect(s.currentPlayer, 0);
      expect(s.consecutiveSixes, 0);
      final after = rules.apply(rolled(s, 6), const LudoMove.move(0));
      expect(after.consecutiveSixes, 1);
    });

    test('L-14, E-L2′: an unusable 6 passes the turn with no bonus; option `bonusRollOnUnusableSix`', () {
      List<List<int>> stuck() => [
        [53, h, h, h],
        [y, y, y, y],
      ];
      final s = rules.apply(ludo(stuck(), dice: 6, sixes: 1), LudoMove.pass);
      expect((s.currentPlayer, s.consecutiveSixes), (1, 0));
      final bonus = rules.apply(
        ludo(stuck(), dice: 6, sixes: 2, config: const LudoConfig(players: 2, bonusRollOnUnusableSix: true)),
        LudoMove.pass,
      );
      expect((bonus.currentPlayer, bonus.phase, bonus.consecutiveSixes), (0, LudoPhase.awaitingRoll, 2));
      final third = rules.apply(rolled(bonus, 6), LudoMove.pass);
      expect(third.currentPlayer, 1, reason: 'the third six still ends the turn');
    });
  });

  group('the board', () {
    test('L-15: one lap, then into the own column', () {
      final s = rules.apply(
        ludo([
          [48, y, y, y],
          [y, y, y, y],
        ], dice: 4),
        const LudoMove.move(0),
      );
      expect(s.tokens[0][0], 52);
      expect(s.absoluteSquare(0, 52), -1);
    });

    test('L-16: capture only by landing – passing over an opponent does nothing', () {
      final s = rules.apply(
        ludo([
          [1, y, y, y],
          [29, y, y, y],
        ], dice: 4),
        const LudoMove.move(0),
      );
      expect(s.tokens[1][0], 29);
      expect(s.tokens[0][0], 5);
      expect(s.currentPlayer, 1);
    });

    test('L-17: safe squares are the four start squares and the four stars (start + 8)', () {
      const c = LudoConfig();
      expect(
        [
          for (var sq = 0; sq < 52; sq++)
            if (c.isSafe(sq)) sq,
        ],
        [0, 8, 13, 21, 26, 34, 39, 47],
      );
      final s = rules.apply(
        ludo([
          [5, y, y, y],
          [34, y, y, y],
        ], dice: 3),
        const LudoMove.move(0),
      );
      expect(s.tokens[1][0], 34, reason: 'absolute 8 is a star');
      expect(
        [
          for (var sq = 0; sq < 52; sq++)
            if (const LudoConfig(safeSquares: LudoSafeSquares.startOnly).isSafe(sq)) sq,
        ],
        [0, 13, 26, 39],
      );
    });

    List<List<int>> pairOnFour() => [
      [1, y, y, y],
      [30, 30, y, y],
    ];

    test('L-18, E-L6′: landing on an opponent pair captures both (default)', () {
      final s = rules.apply(ludo(pairOnFour(), dice: 3), const LudoMove.move(0));
      expect(s.tokens[1], [y, y, y, y]);
      expect(s.tokens[0][0], 4);
    });

    test('L-18 option `safePairs`: a pair cannot be captured but can be shared and passed', () {
      const cfg = LudoConfig(players: 2, safePairs: true);
      final land = rules.apply(ludo(pairOnFour(), dice: 3, config: cfg), const LudoMove.move(0));
      expect(land.tokens[1], [30, 30, y, y]);
      expect(land.tokens[0][0], 4);
      expect(land.currentPlayer, 1, reason: 'no capture, no bonus');
      final pass = rules.apply(ludo(pairOnFour(), dice: 5, config: cfg), const LudoMove.move(0));
      expect(pass.tokens[0][0], 6);
      // A single token of the same colour elsewhere is still capturable.
      final single = rules.apply(
        ludo(
          [
            [1, y, y, y],
            [30, 31, y, y],
          ],
          dice: 3,
          config: cfg,
        ),
        const LudoMove.move(0),
      );
      expect(single.tokens[1], [y, 31, y, y]);
    });

    test('L-19, E-L6′ option `blockades`: a pair can be neither landed on nor passed', () {
      const cfg = LudoConfig(players: 2, blockades: true);
      expect(rules.legalMoves(ludo(pairOnFour(), dice: 3, config: cfg)), [LudoMove.pass]);
      expect(rules.legalMoves(ludo(pairOnFour(), dice: 5, config: cfg)), [LudoMove.pass]);
      expect(rules.legalMoves(ludo(pairOnFour(), dice: 2, config: cfg)), [const LudoMove.move(0)]);
    });

    test('E-L11: with blockades, an opponent pair on the start square stops the exit', () {
      final s = ludo(
        [
          [y, y, y, y],
          [26, 26, y, y],
        ],
        dice: 6,
        sixes: 1,
        config: const LudoConfig(players: 2, blockades: true),
      );
      expect(s.absoluteSquare(1, 26), 0);
      expect(rules.legalMoves(s), [LudoMove.pass]);
    });

    test('L-20: the home column is private – nothing lands on or captures a token there', () {
      final s = rules.apply(
        ludo(
          [
            [51, y, y, y],
            [20, y, y, y],
          ],
          player: 1,
          dice: 5,
        ),
        const LudoMove.move(0),
      );
      expect(s.absoluteSquare(1, 25), 51);
      expect(s.tokens[0][0], 51);
    });

    test('L-21: entering onto a safe start square shares it; without safe squares it captures', () {
      List<List<int>> t() => [
        [y, y, y, y],
        [26, y, y, y],
      ];
      final shared = rules.apply(ludo(t(), dice: 6, sixes: 1), const LudoMove.move(0));
      expect(shared.tokens[1][0], 26);
      expect(shared.tokens[0][0], 0);
      final hit = rules.apply(
        ludo(t(), dice: 6, sixes: 1, config: const LudoConfig(players: 2, safeSquares: LudoSafeSquares.none)),
        const LudoMove.move(0),
      );
      expect(hit.tokens[1][0], y);
    });

    test('L-22: the exact roll is needed to finish; option `exactRollToFinish: false`', () {
      final s = ludo([
        [48, 53, y, y],
        [y, y, y, y],
      ], dice: 4);
      expect(rules.legalMoves(s), [const LudoMove.move(0)]);
      final loose = rules.apply(
        ludo(
          [
            [53, y, y, y],
            [y, y, y, y],
          ],
          dice: 5,
          config: const LudoConfig(players: 2, exactRollToFinish: false),
        ),
        const LudoMove.move(0),
      );
      expect(loose.tokens[0][0], h);
    });

    test('L-23, L-24: the first player home wins; option `playUntilLast` ranks everyone', () {
      final end = rules.apply(
        ludo([
          [53, h, h, h],
          [y, y, y, y],
        ], dice: 3),
        const LudoMove.move(0),
      );
      expect(
        end.result,
        const GameResult(winners: [0], reason: GameEndReason.allTokensHome, scores: [4, 0], ranking: [0]),
      );
      final three = rules.apply(
        ludo(
          [
            [53, h, h, h],
            [y, y, y, y],
            [10, y, y, y],
          ],
          dice: 3,
          config: const LudoConfig(players: 3, playUntilLast: true),
        ),
        const LudoMove.move(0),
      );
      expect(three.isOver, isFalse);
      expect(three.ranking, [0]);
      expect(three.currentPlayer, 1);
    });
  });

  group('option `captureToEnterHome` (L-28)', () {
    const cfg = LudoConfig(players: 2, captureToEnterHome: true);

    test('E-L13: without a capture a token at 50 keeps lapping – 1 → the square before its start, 2 → its start', () {
      final one = rules.apply(
        ludo(
          [
            [50, y, y, y],
            [y, y, y, y],
          ],
          dice: 1,
          config: cfg,
        ),
        const LudoMove.move(0),
      );
      expect(one.tokens[0][0], kLudoBeforeStart);
      expect(one.absoluteSquare(0, kLudoBeforeStart), 51);
      expect(one.absoluteSquare(1, kLudoBeforeStart), 25);
      final two = rules.apply(
        ludo(
          [
            [50, y, y, y],
            [y, y, y, y],
          ],
          dice: 2,
          config: cfg,
        ),
        const LudoMove.move(0),
      );
      expect(two.tokens[0][0], 0);
      final lap = rules.apply(
        ludo(
          [
            [kLudoBeforeStart, y, y, y],
            [y, y, y, y],
          ],
          dice: 3,
          config: cfg,
        ),
        const LudoMove.move(0),
      );
      expect(lap.tokens[0][0], 2);
      expect(const LudoConfig(players: 3, captureToEnterHome: true).seatOf(1), 1);
      expect(LudoState.initial(config: const LudoConfig(players: 3)).absoluteSquare(1, kLudoBeforeStart), 12);
    });

    test('the lapping square is not safe: an opponent landing there captures', () {
      final s = rules.apply(
        ludo(
          [
            [kLudoBeforeStart, y, y, y],
            [24, y, y, y],
          ],
          player: 1,
          dice: 1,
          config: cfg,
        ),
        const LudoMove.move(0),
      );
      expect(s.tokens[0][0], y);
      expect(s.captured, [false, true]);
    });

    test('a capture opens the home column', () {
      var s = rules.apply(
        ludo(
          [
            [1, 48, y, y],
            [30, y, y, y],
          ],
          dice: 3,
          config: cfg,
        ),
        const LudoMove.move(0),
      );
      expect(s.captured, [true, false]);
      expect(LudoState.fromJson(roundTrip(s.toJson())).captured, [true, false]);
      s = rules.apply(rolled(s, 4), const LudoMove.move(1));
      expect(s.tokens[0][1], 52);
      // A token already past its entrance (at 57) laps once more.
      final past = rules.apply(
        ludo(
          [
            [kLudoBeforeStart, y, y, y],
            [y, y, y, y],
          ],
          dice: 2,
          config: cfg,
          captured: [true, false],
        ),
        const LudoMove.move(0),
      );
      expect(past.tokens[0][0], 1);
    });

    test('the rule is off by default', () {
      final s = rules.apply(
        ludo([
          [50, y, y, y],
          [y, y, y, y],
        ], dice: 1),
        const LudoMove.move(0),
      );
      expect(s.tokens[0][0], 51);
    });
  });

  group('option `teams` (L-29)', () {
    const cfg = LudoConfig(teams: true);

    test('partners never capture or block each other', () {
      final s = rules.apply(
        ludo(
          [
            [1, y, y, y],
            [y, y, y, y],
            [30, y, y, y],
            [y, y, y, y],
          ],
          dice: 3,
          config: cfg,
        ),
        const LudoMove.move(0),
      );
      expect(s.absoluteSquare(2, 30), 4);
      expect(s.tokens[2][0], 30);
      expect(s.tokens[0][0], 4);
      final opp = rules.apply(
        ludo(
          [
            [1, y, y, y],
            [43, y, y, y],
            [y, y, y, y],
            [y, y, y, y],
          ],
          dice: 3,
          config: cfg,
        ),
        const LudoMove.move(0),
      );
      expect(opp.absoluteSquare(1, 43), 4);
      expect(opp.tokens[1][0], y);
      final blocked = ludo(
        [
          [1, y, y, y],
          [y, y, y, y],
          [30, 30, y, y],
          [y, y, y, y],
        ],
        dice: 5,
        config: cfg.copyWith(blockades: true),
      );
      expect(rules.legalMoves(blocked), [const LudoMove.move(0)]);
    });

    test('a player whose tokens are home moves the partner\'s; the team wins with all eight', () {
      var s = rules.apply(
        ludo(
          [
            [53, h, h, h],
            [y, y, y, y],
            [52, h, h, h],
            [y, y, y, y],
          ],
          dice: 3,
          config: cfg,
        ),
        const LudoMove.move(0),
      );
      expect(s.isOver, isFalse);
      expect(s.currentPlayer, 0, reason: 'home bonus');
      expect(s.movingPlayer, 2);
      s = rolled(s, 4);
      expect(rules.legalMoves(s), [const LudoMove.move(0)]);
      s = rules.apply(s, const LudoMove.move(0));
      expect(s.tokens[2][0], h);
      expect(
        s.result,
        const GameResult(winners: [0, 2], reason: GameEndReason.allTokensHome, scores: [4, 0, 4, 0], ranking: [0, 2]),
      );
    });
  });

  group('whole games', () {
    const variants = <String, LudoConfig>{
      'jordan ×2': LudoConfig.jordan(players: 2),
      'jordan ×3': LudoConfig.jordan(players: 3),
      'jordan ×4': LudoConfig.jordan(players: 4),
      'safe pairs': LudoConfig(players: 2, safePairs: true),
      'blockades': LudoConfig(players: 4, blockades: true),
      'capture to enter home': LudoConfig(players: 2, captureToEnterHome: true),
      'yard tries, unusable six, 1 exits': LudoConfig(
        players: 3,
        yardRollAttempts: 3,
        bonusRollOnUnusableSix: true,
        exitRolls: [1, 6],
      ),
      'teams': LudoConfig(players: 4, teams: true),
      'until last, overshoot, start-only safety': LudoConfig(
        players: 4,
        playUntilLast: true,
        exactRollToFinish: false,
        safeSquares: LudoSafeSquares.startOnly,
      ),
    };

    test('seeded random games end, keep the invariants and replay from JSON', () {
      variants.forEach((name, cfg) {
        for (var seed = 0; seed < 3; seed++) {
          final e = BoardGameEngine<LudoState, LudoMove>(rules, LudoState.initial(seed: seed, config: cfg));
          final rng = BoardRng(seed * 13 + 1);
          while (!e.isOver) {
            ludoInvariants(e.state);
            e.apply(rng.pick(e.legalMoves()));
            expect(e.history.length, lessThan(20000), reason: '$name does not end');
          }
          ludoInvariants(e.state);
          final r = e.result!;
          expect(r.reason, GameEndReason.allTokensHome);
          if (cfg.teams) {
            expect(r.winners, hasLength(2));
            expect(r.winners.every((w) => e.state.finished(w)), isTrue);
          } else {
            expect(e.state.finished(r.winners.single), isTrue);
          }
          if (cfg.playUntilLast) expect(r.ranking.toSet(), {0, 1, 2, 3});
          final restored = BoardGameEngine<LudoState, LudoMove>.fromJson(rules, roundTrip(e.toJson()));
          expect(canonical(restored.state), canonical(e.state), reason: name);
          expect(canonical(LudoState.fromJson(roundTrip(e.state.toJson()))), canonical(e.state));
        }
      });
    });

    test('same seed, same game (deterministic dice and first player)', () {
      List<String> line(int seed) {
        final e = BoardGameEngine<LudoState, LudoMove>(
          rules,
          LudoState.initial(seed: seed, config: const LudoConfig.jordan(players: 4)),
        );
        final rng = BoardRng(3);
        for (var i = 0; i < 200 && !e.isOver; i++) {
          e.apply(rng.pick(e.legalMoves()));
        }
        return [for (final m in e.history) m.toString()];
      }

      expect(line(12), line(12));
    });
  });
}

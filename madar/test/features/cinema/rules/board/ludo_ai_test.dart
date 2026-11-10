// Ludo AI at every level, for every variant of RULES.md §5.
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/cinema/rules/board/core/engine.dart';
import 'package:madar/features/cinema/rules/board/core/game_types.dart';
import 'package:madar/features/cinema/rules/board/core/rng.dart';
import 'package:madar/features/cinema/rules/board/ludo/ludo_ai.dart';
import 'package:madar/features/cinema/rules/board/ludo/ludo_rules.dart';

const y = kLudoYard;
const h = kLudoHome;
const ai = LudoAi();
const rules = ludoRules;

LudoState ludo(List<List<int>> tokens, {int player = 0, int dice = 0, LudoConfig? config, List<bool>? captured}) =>
    LudoState(
      config: config ?? LudoConfig(players: tokens.length),
      tokens: tokens,
      currentPlayer: player,
      phase: dice == 0 ? LudoPhase.awaitingRoll : LudoPhase.awaitingMove,
      rng: const [1, 2, 3, 4],
      dice: dice,
      captured: captured,
    );

const variants = <String, LudoConfig>{
  'jordan': LudoConfig.jordan(players: 2),
  'safe pairs': LudoConfig(players: 2, safePairs: true),
  'blockades': LudoConfig(players: 2, blockades: true),
  'capture to enter home': LudoConfig(players: 2, captureToEnterHome: true),
  'three yard tries, unusable six': LudoConfig(players: 2, yardRollAttempts: 3, bonusRollOnUnusableSix: true),
  '1 and 6 exit': LudoConfig(players: 2, exitRolls: [1, 6]),
  'teams': LudoConfig(players: 4, teams: true),
};

/// One game; the side with parity [strong] (seat, or team with 4 players)
/// plays [strongLevel]. Returns 1 when that side wins, else 0.
double duel(LudoConfig cfg, int seed, int strong, AiLevel strongLevel, AiLevel weakLevel) {
  final e = BoardGameEngine<LudoState, LudoMove>(rules, LudoState.initial(seed: seed, config: cfg));
  final rng = BoardRng(seed * 7919 + 17);
  while (!e.isOver) {
    final p = e.currentPlayer;
    final level = p % 2 == strong ? strongLevel : weakLevel;
    final m = ai.chooseMove(e.state, level, rng, const AiBudget.nodes(500));
    expect(e.legalMoves(), contains(m));
    e.apply(m);
    expect(e.history.length, lessThan(20000));
  }
  return e.result!.winners.first % 2 == strong ? 1 : 0;
}

void main() {
  test('every level plays legal moves to the end in every variant (seeded self-play)', () {
    variants.forEach((name, cfg) {
      for (final level in AiLevel.values) {
        final e = BoardGameEngine<LudoState, LudoMove>(rules, LudoState.initial(seed: 50, config: cfg));
        final rng = BoardRng(51);
        while (!e.isOver) {
          final m = ai.chooseMove(e.state, level, rng, const AiBudget.nodes(500));
          expect(rules.isLegal(e.state, m), isTrue, reason: '$name ${level.name}');
          e.apply(m);
        }
        expect(e.result!.reason, GameEndReason.allTokensHome);
      }
    });
  });

  test('hard beats easy clearly in every variant (24 seeded games, alternating seats)', () {
    variants.forEach((name, cfg) {
      var score = 0.0;
      for (var g = 0; g < 24; g++) {
        score += duel(cfg, 900 + g, g % 2, AiLevel.hard, AiLevel.easy);
      }
      expect(score, greaterThanOrEqualTo(18), reason: '$name: hard won $score / 24');
    });
  }, timeout: const Timeout(Duration(minutes: 5)));

  test('hard is at least as strong as medium (Jordanian game, 60 seeded games)', () {
    var score = 0.0;
    for (var g = 0; g < 60; g++) {
      score += duel(variants['jordan']!, 300 + g, g % 2, AiLevel.hard, AiLevel.medium);
    }
    expect(score, greaterThanOrEqualTo(30), reason: 'hard won $score / 60 against medium');
  }, timeout: const Timeout(Duration(minutes: 5)));

  test('four-player free-for-all: one hard AI beats three medium ones more than its fair share', () {
    // Seeds 500–619, the hard seat rotates. A fair share is 30 / 120. The
    // one-roll lookahead won exactly 30 here (25.1 % over 700 probe games);
    // looking through every opponent's roll wins 38 (29.9 % over 700).
    var wins = 0;
    for (var g = 0; g < 120; g++) {
      final hardSeat = g % 4;
      final e = BoardGameEngine<LudoState, LudoMove>(
        rules,
        LudoState.initial(seed: 500 + g, config: const LudoConfig(players: 4)),
      );
      final rng = BoardRng((500 + g) * 7919 + 17);
      while (!e.isOver) {
        final level = e.currentPlayer == hardSeat ? AiLevel.hard : AiLevel.medium;
        e.apply(ai.chooseMove(e.state, level, rng, const AiBudget.nodes(500)));
      }
      if (e.result!.winners.first == hardSeat) wins++;
    }
    expect(wins, greaterThanOrEqualTo(34), reason: 'hard won $wins / 120 (fair share 30)');
  }, timeout: const Timeout(Duration(minutes: 5)));

  test('medium and hard capture when they can; easy stays legal', () {
    final s = ludo([
      [1, 20, y, y],
      [30, y, y, y],
    ], dice: 3);
    expect(ai.chooseMove(s, AiLevel.hard, BoardRng(1)), const LudoMove.move(0));
    expect(ai.chooseMove(s, AiLevel.medium, BoardRng(1)), const LudoMove.move(0));
    expect(rules.legalMoves(s), contains(ai.chooseMove(s, AiLevel.easy, BoardRng(1))));
  });

  test('capture to enter home: hard takes the capture that opens its column', () {
    final s = ludo(
      [
        [1, 44, y, y],
        [30, y, y, y],
      ],
      dice: 3,
      config: const LudoConfig(players: 2, captureToEnterHome: true),
    );
    expect(ai.chooseMove(s, AiLevel.hard, BoardRng(1)), const LudoMove.move(0));
  });

  test('safe pairs: hard does not break up a protected pair in front of an opponent', () {
    // Tokens 0 and 1 share absolute 10; an opponent sits 3 behind on 7.
    final s = ludo(
      [
        [10, 10, 30, y],
        [33, y, y, y],
      ],
      dice: 2,
      config: const LudoConfig(players: 2, safePairs: true),
    );
    final m = ai.chooseMove(s, AiLevel.hard, BoardRng(1));
    expect(m, const LudoMove.move(2));
  });

  test('teams: once home, the AI moves the partner\'s tokens', () {
    final s = ludo(
      [
        [h, h, h, h],
        [y, y, y, y],
        [10, 20, y, y],
        [y, y, y, y],
      ],
      dice: 4,
      config: const LudoConfig(teams: true),
    );
    expect(s.movingPlayer, 2);
    for (final level in AiLevel.values) {
      final m = ai.chooseMove(s, level, BoardRng(2));
      expect(rules.legalMoves(s), contains(m));
      expect(LudoRules.stepFor(s, 2, m.token, 4), isNotNull);
    }
  });

  test('the AI never reads the dice stream: changing the RNG state does not change its choice', () {
    final a = ludo([
      [1, 20, 40, y],
      [30, 12, y, y],
    ], dice: 5);
    final b = a.copyWith(rng: const [9, 9, 9, 9]);
    for (final level in [AiLevel.medium, AiLevel.hard]) {
      expect(ai.chooseMove(a, level, BoardRng(3)), ai.chooseMove(b, level, BoardRng(3)));
    }
  });

  test('hard with the phone budget returns a legal move', () {
    final s = ludo([
      [1, 20, 40, y],
      [30, 12, y, y],
    ], dice: 6);
    expect(rules.legalMoves(s), contains(ai.chooseMove(s, AiLevel.hard, BoardRng(3))));
  });
}

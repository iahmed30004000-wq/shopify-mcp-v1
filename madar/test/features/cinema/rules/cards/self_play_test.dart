// Random self-play of whole matches for every game (and main variants) at
// every AI level, checking the invariants after every move (see
// support.dart), JSON save / resume, and deterministic replay from a seed.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/cinema/rules/cards/cards.dart';

import 'support.dart';

Kit kit(String name, CardGameId id, [Object? options]) =>
    Kit(name, (seed) => CardGames.newMatch(id, seed: seed, options: options), CardGames.fromJson, CardGames.ai(id));

final kits = <Kit>[
  kit('tarneeb', CardGameId.tarneeb),
  kit(
    'tarneeb 41 open auction',
    CardGameId.tarneeb,
    const TarneebOptions(
      targetScore: 41,
      passIsFinal: false,
      allPass: TarneebAllPass.dealerTakesMinimum,
      defendersScoreWhenMade: true,
      bidderLeads: false,
    ),
  ),
  kit('trix', CardGameId.trix),
  kit('trix complex partners', CardGameId.trix, const TrixOptions(mode: TrixMode.complex, partnership: true)),
  kit('basra', CardGameId.basra),
  kit(
    'basra 2p normal 7♦',
    CardGameId.basra,
    const BasraOptions(players: 2, sevenDiamonds: BasraSevenDiamonds.normal, basraOnLastCard: true),
  ),
  kit('baloot', CardGameId.baloot),
  kit(
    'baloot relaxed',
    CardGameId.baloot,
    const BalootOptions(mustTrumpWhenPartnerWinning: false, mustOvertrump: false, sunDoubleOnlyWhenBehind: false),
  ),
  kit('hand', CardGameId.hand),
  kit('hand 2p', CardGameId.hand, const RummyOptions.hand(players: 2)),
  kit('konkan', CardGameId.konkan),
  kit('konkan 3p rounds', CardGameId.konkan, const RummyOptions.konkan(players: 3, matchEnd: RummyMatchEnd.rounds)),
];

/// Shorter matches for the (slower) hard AI.
final hardKits = <Kit>[
  kit('tarneeb', CardGameId.tarneeb, const TarneebOptions(targetScore: 21)),
  kit('trix', CardGameId.trix, const TrixOptions(mode: TrixMode.complex)),
  kit('basra', CardGameId.basra, const BasraOptions(targetScore: 41)),
  kit('baloot', CardGameId.baloot, const BalootOptions(targetScore: 80)),
  kit('hand', CardGameId.hand, const RummyOptions.hand(rounds: 2)),
  kit('konkan', CardGameId.konkan, const RummyOptions.konkan(targetScore: 150)),
];

void main() {
  group('self-play', () {
    for (final k in kits) {
      for (final level in [AiLevel.easy, AiLevel.medium]) {
        test('${k.name}: ${level.name}', () {
          for (var seed = 1; seed <= 5; seed++) {
            playMatch(k, seed, List.filled(4, level), jsonEvery: seed == 1 ? 11 : 0);
          }
        });
      }
    }
    for (final k in hardKits) {
      test('${k.name}: hard (tiny budget), mixed tables', () {
        playMatch(k, 1, List.filled(4, AiLevel.hard), budget: const AiBudget.simulations(12), jsonEvery: 13);
        playMatch(k, 2, [AiLevel.hard, AiLevel.easy, AiLevel.medium, AiLevel.easy], budget: const AiBudget.simulations(12));
      });
    }
  });

  group('deterministic replay', () {
    for (final k in hardKits) {
      test('${k.name}: same seed and levels → same match; the move log replays it', () {
        const levels = [AiLevel.hard, AiLevel.easy, AiLevel.medium, AiLevel.hard];
        const budget = AiBudget.simulations(8);
        final a = playMatch(k, 42, levels, budget: budget);
        final b = playMatch(k, 42, levels, budget: budget);
        expect(b.finalJson, a.finalJson);
        expect(b.moveLog, a.moveLog);
        final replay = k.create(42);
        for (final mj in a.moveLog) {
          replay.apply(replay.moveFromJson(jsonDecode(mj) as Map<String, Object?>));
        }
        expect(jsonEncode(replay.toJson()), a.finalJson);
        expect(playMatch(k, 43, levels, budget: budget).finalJson, isNot(a.finalJson));
      });
    }
  });

  test('a saved match resumes and finishes identically', () {
    for (final k in hardKits) {
      final e = k.create(7);
      final rng = CardRng(99);
      for (var i = 0; i < 40 && !e.isOver; i++) {
        final p = e.currentPlayer!;
        e.apply(k.ai.chooseMove(e.state, p, AiLevel.medium, rng, AiBudget.phone));
      }
      final saved = jsonEncode(e.toJson());
      final restored = k.restore(jsonDecode(saved) as Map<String, Object?>);
      final r1 = CardRng(5);
      final r2 = CardRng(5);
      while (!e.isOver) {
        final p = e.currentPlayer!;
        e.apply(k.ai.chooseMove(e.state, p, AiLevel.medium, r1, AiBudget.phone));
        final q = restored.currentPlayer!;
        restored.apply(k.ai.chooseMove(restored.state, q, AiLevel.medium, r2, AiBudget.phone));
      }
      expect(restored.isOver, isTrue, reason: k.name);
      expect(jsonEncode(restored.toJson()), jsonEncode(e.toJson()), reason: k.name);
    }
  });
}

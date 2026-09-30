// Random self-play of whole matches for every game (and main variants) at
// every AI level, checking the invariants after every move (see
// support.dart), JSON save / resume, and deterministic replay from a seed.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/cinema/rules/cards/cards.dart';

import 'support.dart';

Kit kit(String name, CardGameId id, [Object? options]) =>
    Kit(name, (seed) => CardGames.newMatch(id, seed: seed, options: options), CardGames.fromJson, CardGames.ai(id));

/// Every game of the registry with its Jordanian default (null options), every
/// named preset and a few house-rule mixes. Solitaire is not a
/// `CardGameEngine`; its self-play is in `solitaire_ai_test.dart`.
final kits = <Kit>[
  // Tarneeb and 41.
  kit('tarneeb', CardGameId.tarneeb),
  kit(
    'tarneeb to 41, open auction',
    CardGameId.tarneeb,
    TarneebOptions.openAuction(targetScore: 41).copyWith(defendersScoreWhenMade: true, bidderLeads: false),
  ),
  kit('tarneeb syrian trump', CardGameId.tarneeb, const TarneebOptions.syrianTrump()),
  kit(
    'tarneeb lebanese auction, worthless hand, trump lead, loss at -31',
    CardGameId.tarneeb,
    const TarneebOptions(
      oneRoundAuction: true,
      worthlessHandRedeal: true,
      firstLeadMustBeTrump: true,
      loseAtNegativeTarget: true,
    ),
  ),
  kit('forty-one', CardGameId.fortyOne),
  kit('400 (lebanese)', CardGameId.fortyOne, const FortyOneOptions.lebanese400()),
  kit('syrian 41', CardGameId.fortyOne, const FortyOneOptions.syrian()),
  // Trix: the four menu entries and the earlier open-doubling rules.
  for (final preset in TrixPreset.values) kit('trix ${preset.name}', CardGameId.trix, preset.options),
  kit('trix open doubling', CardGameId.trix, const TrixOptions.openDoubling()),
  // Basra.
  kit('basra', CardGameId.basra),
  kit(
    'basra 2p normal 7♦',
    CardGameId.basra,
    const BasraOptions(players: 2, sevenDiamonds: BasraSevenDiamonds.normal, basraOnLastCard: true),
  ),
  kit('basra palestinian 44', CardGameId.basra, const BasraOptions.palestinian44()),
  kit('basra egyptian 3p', CardGameId.basra, const BasraOptions.egyptian(players: 3)),
  // Baloot.
  kit('baloot', CardGameId.baloot),
  kit(
    'baloot relaxed',
    CardGameId.baloot,
    const BalootOptions(
      partnerWinningVoid: BalootPartnerWinningVoid.free,
      mustOvertrump: false,
      sunDoubleRule: BalootSunDoubleRule.always,
    ),
  ),
  kit(
    'baloot every option',
    CardGameId.baloot,
    const BalootOptions(
      kawesh: true,
      aceThirdRound: true,
      declareProjects: BalootDeclareProjects.manual,
      firstLead: BalootFirstLead.taker,
    ),
  ),
  // Hand and Konkan (the shared rummy engine).
  kit('hand', CardGameId.hand),
  kit('hand 2p', CardGameId.hand, const RummyOptions.hand(players: 2)),
  kit('hand partnership', CardGameId.hand, const RummyOptions.handPartnership()),
  kit('hand indicator', CardGameId.hand, const RummyOptions.handIndicator(rounds: 3)),
  kit('konkan', CardGameId.konkan),
  kit('konkan 3p rounds', CardGameId.konkan, const RummyOptions.konkan(players: 3, matchEnd: RummyMatchEnd.rounds)),
  // Blackjack 21 (1–3 seats; only the first `seats` levels are read).
  kit('blackjack', CardGameId.blackjack),
  kit('blackjack european 3 seats', CardGameId.blackjack, const BlackjackOptions.european(seats: 3)),
  kit(
    'blackjack 1 pack late surrender',
    CardGameId.blackjack,
    const BlackjackOptions(decks: 1, penetration: 0.85, seats: 3, surrender: BlackjackSurrender.late),
  ),
];

/// Shorter matches for the (slower) hard AI.
final hardKits = <Kit>[
  kit('tarneeb', CardGameId.tarneeb, const TarneebOptions(targetScore: 21)),
  kit('forty-one', CardGameId.fortyOne, const FortyOneOptions(target: 31)),
  kit('trix', CardGameId.trix, const TrixOptions(mode: TrixMode.complex)),
  kit('basra', CardGameId.basra, const BasraOptions(targetScore: 41)),
  kit('baloot', CardGameId.baloot, const BalootOptions(targetScore: 80)),
  kit('hand', CardGameId.hand, const RummyOptions.hand(rounds: 2)),
  kit('konkan', CardGameId.konkan, const RummyOptions.konkan(eliminationScore: 101)),
  kit('blackjack', CardGameId.blackjack, const BlackjackOptions(seats: 2, sessionRounds: 10)),
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
        playMatch(k, 2, [
          AiLevel.hard,
          AiLevel.easy,
          AiLevel.medium,
          AiLevel.easy,
        ], budget: const AiBudget.simulations(12));
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

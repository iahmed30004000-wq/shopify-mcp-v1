// Hand (هاند): seeded self-play of whole matches for the Jordanian default
// and every preset / main option set, at every AI level, with the shared
// invariants (a legal move always exists, the AI's choice validates, cards
// are conserved), JSON save / resume, deterministic replay, the no-peeking
// check and hard-beats-easy.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/cinema/rules/cards/cards.dart';
import 'package:madar/features/cinema/rules/cards/core/determinize.dart';

import 'support.dart';

Kit handKit(String name, RummyOptions options) => Kit(
  name,
  (seed) => HandEngine.newMatch(seed: seed, options: options),
  HandEngine.fromJson,
  const HandAi() as CardAi<CardGameState, CardMove>,
);

final variants = <Kit>[
  handKit('hand (Jordan default)', const RummyOptions.hand()),
  handKit('hand 2 players', const RummyOptions.hand(players: 2)),
  handKit('hand 3 players', const RummyOptions.hand(players: 3)),
  handKit('hand partnership', const RummyOptions.handPartnership()),
  handKit('hand indicator (ورقة الكشف)', const RummyOptions.handIndicator(rounds: 3)),
  handKit(
    'hand escalating openings, discard any, either-suit set swap, freed wild used, rotate, flip',
    const RummyOptions(
      openingMustBeatPrevious: true,
      discardUse: RummyDiscardUse.any,
      setWildSwap: RummySetWildSwap.anyMissingSuit,
      swappedWildMustBeUsed: true,
      dealerRule: RummyDealerRule.rotate,
      stockEnd: RummyStockEnd.flipNoShuffle,
      rounds: 3,
    ),
  ),
  handKit(
    'hand Gulf bonuses, ace low 1, target score, partner pays',
    const RummyOptions(
      bonusWildLastDiscard: true,
      bonusOneColour: true,
      bonusOneSuit: true,
      aceLowOpeningValue: 1,
      aceHighOpeningValue: 10,
      acePenalty: 10,
      partnership: true,
      partnerOfWinnerPays: true,
      matchEnd: RummyMatchEnd.targetScore,
      targetScore: 300,
    ),
  ),
  handKit(
    'hand 7 rounds, run required, no first-turn rules, shared ties, void rounds count',
    const RummyOptions(
      rounds: 7,
      openingRequiresRun: true,
      starterFirstTurnDiscardOnly: false,
      noGoOutOnFirstTurn: false,
      tieBreak: RummyTieBreak.shared,
      voidRoundsCount: true,
      pairsRedeal: false,
      jokerPenalty: 25,
    ),
  ),
];

/// Shorter matches for the hard AI.
final hardVariants = <Kit>[
  handKit('hand', const RummyOptions.hand(rounds: 1)),
  handKit('hand partnership', const RummyOptions.handPartnership(rounds: 1)),
  handKit('hand indicator', const RummyOptions.handIndicator(rounds: 1)),
];

void main() {
  group('self-play', () {
    for (final k in variants) {
      for (final level in [AiLevel.easy, AiLevel.medium]) {
        test('${k.name}: ${level.name}', () {
          for (var seed = 1; seed <= 3; seed++) {
            final r = playMatch(k, seed, List.filled(4, level), jsonEvery: seed == 1 ? 7 : 0);
            expect(r.winners, isNotEmpty);
          }
        });
      }
    }
    for (final k in hardVariants) {
      test('${k.name}: hard (tiny budget), mixed tables', () {
        playMatch(k, 1, List.filled(4, AiLevel.hard), budget: const AiBudget.simulations(8), jsonEvery: 13);
        playMatch(k, 2, [
          AiLevel.hard,
          AiLevel.easy,
          AiLevel.medium,
          AiLevel.easy,
        ], budget: const AiBudget.simulations(8));
      });
    }
  });

  test('whole matches: 5 scored rounds plus tie-break rounds; the totals are the sum of the rounds', () {
    for (var seed = 1; seed <= 6; seed++) {
      final r = playMatch(variants[0], seed, List.filled(4, AiLevel.medium));
      final s = HandEngine.fromJson(jsonDecode(r.finalJson) as Map<String, Object?>).state;
      expect(s.roundsPlayed, 5 + s.tieBreakRounds);
      expect(s.tieBreakRounds, lessThanOrEqualTo(3));
      for (var seat = 0; seat < 4; seat++) {
        expect(s.results.fold<int>(0, (a, x) => a + x.points[seat]), s.seatScores[seat]);
      }
      for (final x in s.results.where((x) => x.winner != null)) {
        expect(x.points[x.winner!], x.handFinish ? -60 : -30);
      }
    }
  });

  group('deterministic replay and resume', () {
    for (final k in hardVariants) {
      test('${k.name}: same seed and levels → same match; the move log replays it', () {
        const levels = [AiLevel.hard, AiLevel.easy, AiLevel.medium, AiLevel.hard];
        const budget = AiBudget.simulations(6);
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

    test('a saved match resumes and finishes identically', () {
      for (final k in [variants[0], variants[3], variants[4]]) {
        final e = k.create(7);
        final rng = CardRng(99);
        for (var i = 0; i < 120 && !e.isOver; i++) {
          e.apply(k.ai.chooseMove(e.state, e.currentPlayer!, AiLevel.medium, rng, AiBudget.phone));
        }
        final restored = k.restore(jsonDecode(jsonEncode(e.toJson())) as Map<String, Object?>);
        final r1 = CardRng(5);
        final r2 = CardRng(5);
        while (!e.isOver) {
          e.apply(k.ai.chooseMove(e.state, e.currentPlayer!, AiLevel.medium, r1, AiBudget.phone));
          restored.apply(k.ai.chooseMove(restored.state, restored.currentPlayer!, AiLevel.medium, r2, AiBudget.phone));
        }
        expect(restored.isOver, isTrue, reason: k.name);
        expect(jsonEncode(restored.toJson()), jsonEncode(e.toJson()), reason: k.name);
      }
    });
  });

  group('no peeking', () {
    for (final k in [variants[0], variants[3], variants[4]]) {
      test('${k.name}: decisions depend only on what the seat can see', () {
        const ai = HandAi();
        final e = k.create(5);
        final rng = CardRng(1);
        var checked = 0;
        for (var move = 0; move < 400 && !e.isOver; move++) {
          final seat = e.currentPlayer!;
          if (move % 7 == 3) {
            final real = e.state as RummyState;
            final other = ai.determinize(real, seat, CardRng(move));
            expect(
              jsonEncode(cardsToJson(sortedCards(other.cardsInPlay()))),
              jsonEncode(cardsToJson(sortedCards(real.cardsInPlay()))),
            );
            expect(other.hands[seat], real.hands[seat]);
            for (final level in [AiLevel.medium, AiLevel.hard]) {
              final a = ai.chooseMove(real, seat, level, CardRng(9), const AiBudget.simulations(10));
              final b = ai.chooseMove(other, seat, level, CardRng(9), const AiBudget.simulations(10));
              expect(b, a, reason: '${k.name} move $move ${level.name}');
            }
            checked++;
          }
          e.apply(k.ai.chooseMove(e.state, seat, AiLevel.medium, rng, AiBudget.phone));
        }
        expect(checked, greaterThan(10));
      });
    }

    test('determinised worlds keep publicly known cards (a taken discard, a swapped wild) and the indicator', () {
      final hands = [c('2C 3C'), c('KD KH 5S X0'), c('4D'), c('9S')];
      final s = RummyState.custom(
        options: const RummyOptions.handIndicator(),
        hands: hands,
        indicator: PlayingCard.parse('7H'),
        stock: cardsMinus(buildDeck(copies: 2, jokers: 2), [...hands.expand((h) => h), PlayingCard.parse('7H')]),
      )..known[1] = c('KD X0');
      for (var i = 0; i < 10; i++) {
        final w = const HandAi().determinize(s, 0, CardRng(i));
        expect(w.hands[1], containsAll(c('KD X0')));
        expect(w.hands.map((h) => h.length), [2, 4, 1, 1]);
        expect(w.hands[0], s.hands[0]);
        expect(w.stock.length, s.stock.length);
        expect(w.cardsInPlay().length, 106);
      }
    });
  });

  test('hard beats easy (one hard seat against three easy, rotating)', () {
    final kit = handKit('hand', const RummyOptions.hand(rounds: 3));
    var wins = 0;
    var edge = 0.0;
    const matches = 8;
    for (var m = 0; m < matches; m++) {
      final hardSeat = m % 4;
      final levels = [for (var s = 0; s < 4; s++) s == hardSeat ? AiLevel.hard : AiLevel.easy];
      final r = playMatch(kit, 1000 + m, levels, budget: const AiBudget.simulations(24));
      final others = [
        for (var s = 0; s < 4; s++)
          if (s != hardSeat) r.scores[s],
      ];
      edge += others.reduce((a, b) => a + b) / 3 - r.scores[hardSeat];
      if (r.winners.contains(hardSeat)) wins++;
    }
    // ignore: avoid_print
    print('hand: hard won $wins/$matches, average edge ${(edge / matches).toStringAsFixed(1)} points');
    expect(edge / matches, greaterThan(10));
    expect(wins, greaterThanOrEqualTo(4), reason: 'chance is 2 in 8');
  });
}

List<PlayingCard> c(String ids) => PlayingCard.list(ids);

// Konkan (كونكان): seeded self-play of whole matches (elimination over 301
// by default, and the other match ends and options) at every AI level, with
// the shared invariants, JSON save / resume, deterministic replay, the
// no-peeking check and hard-beats-easy.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/cinema/rules/cards/cards.dart';

import 'support.dart';

Kit konkanKit(String name, RummyOptions options) => Kit(
  name,
  (seed) => KonkanEngine.newMatch(seed: seed, options: options),
  KonkanEngine.fromJson,
  const KonkanAi() as CardAi<CardGameState, CardMove>,
);

final variants = <Kit>[
  konkanKit('konkan (default, over 301 out)', const RummyOptions.konkan()),
  konkanKit('konkan 2 players', const RummyOptions.konkan(players: 2)),
  konkanKit('konkan 3 players, 101', const RummyOptions.konkan(players: 3, eliminationScore: 101)),
  konkanKit('konkan to 500', const RummyOptions.konkan(matchEnd: RummyMatchEnd.targetScore)),
  konkanKit('konkan 3 rounds', const RummyOptions.konkan(players: 3, matchEnd: RummyMatchEnd.rounds, rounds: 3)),
  konkanKit(
    'konkan open with the discard, escalating openings, joker 50',
    const RummyOptions(
      variant: RummyVariant.konkan,
      winnerScore: 0,
      handWinnerScore: 0,
      jokerPenalty: 50,
      matchEnd: RummyMatchEnd.elimination,
      eliminationScore: 151,
      openingMustUseDiscard: true,
      openingMustBeatPrevious: true,
    ),
  ),
];

final hardVariants = <Kit>[
  konkanKit('konkan 101', const RummyOptions.konkan(eliminationScore: 101)),
  konkanKit('konkan 2 players 101', const RummyOptions.konkan(players: 2, eliminationScore: 101)),
];

void main() {
  group('self-play', () {
    for (final k in variants) {
      for (final level in [AiLevel.easy, AiLevel.medium]) {
        test('${k.name}: ${level.name}', () {
          for (var seed = 1; seed <= 3; seed++) {
            playMatch(k, seed, List.filled(4, level), jsonEvery: seed == 1 ? 9 : 0);
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

  test('elimination matches end with one player left (or the lowest of those who crossed together)', () {
    for (var seed = 1; seed <= 6; seed++) {
      final r = playMatch(variants[0], seed, List.filled(4, AiLevel.medium));
      final s = KonkanEngine.fromJson(jsonDecode(r.finalJson) as Map<String, Object?>).state;
      final left = s.activeSeats;
      expect(left.length, lessThanOrEqualTo(1));
      if (left.isNotEmpty) expect(r.winners, left);
      for (var seat = 0; seat < 4; seat++) {
        if (s.eliminated[seat]) expect(s.seatScores[seat], greaterThan(301));
        if (!s.eliminated[seat]) expect(s.seatScores[seat], lessThanOrEqualTo(301));
      }
      // Nobody's total ever goes down in Konkan.
      for (final x in s.results) {
        expect(x.points.every((v) => v >= 0), isTrue);
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
      });
    }

    test('a saved match resumes and finishes identically', () {
      final k = variants[0];
      final e = k.create(7);
      final rng = CardRng(99);
      for (var i = 0; i < 400 && !e.isOver; i++) {
        e.apply(k.ai.chooseMove(e.state, e.currentPlayer!, AiLevel.medium, rng, AiBudget.phone));
      }
      final restored = k.restore(jsonDecode(jsonEncode(e.toJson())) as Map<String, Object?>);
      final r1 = CardRng(5);
      final r2 = CardRng(5);
      while (!e.isOver) {
        e.apply(k.ai.chooseMove(e.state, e.currentPlayer!, AiLevel.medium, r1, AiBudget.phone));
        restored.apply(k.ai.chooseMove(restored.state, restored.currentPlayer!, AiLevel.medium, r2, AiBudget.phone));
      }
      expect(jsonEncode(restored.toJson()), jsonEncode(e.toJson()));
    });
  });

  test('no peeking: decisions depend only on what the seat can see', () {
    const ai = KonkanAi();
    final e = variants[0].create(5);
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
        for (final level in [AiLevel.medium, AiLevel.hard]) {
          final a = ai.chooseMove(real, seat, level, CardRng(9), const AiBudget.simulations(10));
          final b = ai.chooseMove(other, seat, level, CardRng(9), const AiBudget.simulations(10));
          expect(b, a, reason: 'move $move ${level.name}');
        }
        checked++;
      }
      e.apply(ai.chooseMove(e.state as RummyState, seat, AiLevel.medium, rng, AiBudget.phone));
    }
    expect(checked, greaterThan(10));
  });

  test('hard beats easy (one hard seat against three easy, rotating)', () {
    final kit = konkanKit('konkan', const RummyOptions.konkan(matchEnd: RummyMatchEnd.rounds, rounds: 3));
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
    print('konkan: hard won $wins/$matches, average edge ${(edge / matches).toStringAsFixed(1)} points');
    expect(edge / matches, greaterThan(10));
    expect(wins, greaterThanOrEqualTo(4), reason: 'chance is 2 in 8');
  });

  test('hard outlasts easy in the elimination game', () {
    final kit = konkanKit('konkan 101', const RummyOptions.konkan(eliminationScore: 101));
    var wins = 0;
    const matches = 8;
    for (var m = 0; m < matches; m++) {
      final hardSeat = m % 4;
      final levels = [for (var s = 0; s < 4; s++) s == hardSeat ? AiLevel.hard : AiLevel.easy];
      final r = playMatch(kit, 2000 + m, levels, budget: const AiBudget.simulations(16));
      if (r.winners.contains(hardSeat)) wins++;
    }
    // ignore: avoid_print
    print('konkan elimination: hard won $wins/$matches');
    expect(wins, greaterThanOrEqualTo(3), reason: 'chance is 2 in 8');
  });
}

// Basra self-play for every rule set and table size: all AI levels, legal
// moves only, card conservation, JSON save / resume, deterministic replay,
// no peeking at hidden cards, and the hard AI beating the easy one.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/cinema/rules/cards/cards.dart';

import 'support.dart';

Kit basraKit(String name, BasraOptions o) => Kit(
  name,
  (seed) => BasraEngine.newMatch(seed: seed, options: o),
  BasraEngine.fromJson,
  const BasraAi(),
);

final variants = <String, BasraOptions>{
  'jordan 4p': const BasraOptions(),
  'jordan 2p': const BasraOptions(players: 2),
  'jordan 3p': const BasraOptions(players: 3),
  'jordan 4 individuals': const BasraOptions(partnership: false),
  'jordan 6 cards': const BasraOptions(handSize: 6, basraOnLastCard: true),
  'palestinian 44 4p': const BasraOptions.palestinian44(),
  'palestinian 44 2p': const BasraOptions.palestinian44(players: 2),
  'egyptian 4p': const BasraOptions.egyptian(),
  'egyptian 2p': const BasraOptions.egyptian(players: 2),
};

List<AiLevel> levelsFor(int n, AiLevel level) => List.filled(n, level);

void main() {
  group('self-play, every variant', () {
    for (final v in variants.entries) {
      final k = basraKit(v.key, v.value);
      test('${v.key}: easy and medium, whole matches, JSON every 11 moves', () {
        for (var seed = 1; seed <= 3; seed++) {
          for (final level in [AiLevel.easy, AiLevel.medium]) {
            final r = playMatch(k, seed, levelsFor(v.value.players, level), jsonEvery: seed == 1 ? 11 : 0);
            final best = r.scores.reduce((a, b) => a > b ? a : b);
            expect(best, greaterThanOrEqualTo(v.value.targetScore));
            expect(r.winners.every((s) => r.scores[s] == best), isTrue);
          }
        }
      });
    }

    for (final v in variants.entries) {
      final o = v.value;
      final short = BasraOptions(
        players: o.players,
        partnership: o.partnership,
        deck: o.deck,
        handSize: o.handSize,
        targetScore: 41,
        basraValue: o.basraValue,
        jackBasraPoints: o.jackBasraPoints,
        sevenDiamonds: o.sevenDiamonds,
        basraOnLastCard: o.basraOnLastCard,
        majorityPoints: o.majorityPoints,
        majorityTie: o.majorityTie,
      );
      final k = basraKit(v.key, short);
      test('${v.key}: hard (tiny budget) and a mixed table', () {
        playMatch(k, 1, levelsFor(o.players, AiLevel.hard), budget: const AiBudget.simulations(8), jsonEvery: 13);
        final mixed = [AiLevel.hard, AiLevel.easy, AiLevel.medium, AiLevel.easy].sublist(0, o.players);
        playMatch(k, 2, mixed, budget: const AiBudget.simulations(8));
      });
    }
  });

  test('deterministic replay: same seed and levels → same match; the move log replays it', () {
    for (final o in [const BasraOptions(players: 3, targetScore: 41), const BasraOptions.egyptian(targetScore: 61)]) {
      final k = basraKit('replay', o);
      final levels = [AiLevel.hard, AiLevel.easy, AiLevel.medium, AiLevel.hard].sublist(0, o.players);
      const budget = AiBudget.simulations(6);
      final a = playMatch(k, 42, levels, budget: budget);
      final b = playMatch(k, 42, levels, budget: budget);
      expect(b.finalJson, a.finalJson);
      final replay = k.create(42);
      for (final mj in a.moveLog) {
        replay.apply(replay.moveFromJson(jsonDecode(mj) as Map<String, Object?>));
      }
      expect(jsonEncode(replay.toJson()), a.finalJson);
    }
  });

  group('the AI never peeks', () {
    for (final v in variants.entries) {
      test('${v.key}: decisions depend only on what the seat can see', () {
        const ai = BasraAi();
        final e = BasraEngine.newMatch(seed: 5, options: v.value);
        final rng = CardRng(1);
        var checked = 0;
        for (var move = 0; move < 160 && !e.isOver; move++) {
          final seat = e.currentPlayer!;
          if (move % 9 == 4) {
            final real = e.state;
            final other = ai.determinize(real, seat, CardRng(move));
            expect(other.hands[seat], real.hands[seat]);
            expect(other.table, real.table);
            expect(sortedCards(other.cardsInPlay()), sortedCards(real.cardsInPlay()));
            for (final level in [AiLevel.medium, AiLevel.hard]) {
              final a = ai.chooseMove(real, seat, level, CardRng(9), const AiBudget.simulations(8));
              final b = ai.chooseMove(other, seat, level, CardRng(9), const AiBudget.simulations(8));
              expect(b, a, reason: '${v.key} move $move ${level.name}');
            }
            checked++;
          }
          e.apply(ai.chooseMove(e.state, seat, AiLevel.medium, rng, AiBudget.phone));
        }
        expect(checked, greaterThan(8));
      });
    }
  });

  group('the hard AI beats the easy AI', () {
    const matches = 10;
    for (final v in {
      'jordan 4p': const BasraOptions(targetScore: 61),
      'jordan 3p': const BasraOptions(players: 3, targetScore: 61),
      'jordan 2p': const BasraOptions(players: 2, targetScore: 61),
      'palestinian 44': const BasraOptions.palestinian44(targetScore: 61),
      'egyptian': const BasraOptions.egyptian(),
    }.entries) {
      test(v.key, () {
        var wins = 0;
        var edge = 0.0;
        final k = basraKit(v.key, v.value);
        final n = v.value.players;
        for (var m = 0; m < matches; m++) {
          final hardSeats = v.value.teams
              ? [
                  for (var s = 0; s < n; s++)
                    if (s % 2 == m % 2) s,
                ]
              : [m % n];
          final levels = [for (var s = 0; s < n; s++) hardSeats.contains(s) ? AiLevel.hard : AiLevel.easy];
          final r = playMatch(k, 1000 + m, levels, budget: const AiBudget.simulations(24));
          final hard = r.scores[hardSeats.first].toDouble();
          final others = [
            for (var s = 0; s < n; s++)
              if (!hardSeats.contains(s)) r.scores[s],
          ];
          edge += hard - others.reduce((a, b) => a + b) / others.length;
          if (hardSeats.any(r.winners.contains)) wins++;
        }
        final sides = v.value.sides;
        // ignore: avoid_print
        print('basra ${v.key}: hard won $wins/$matches, average edge ${(edge / matches).toStringAsFixed(1)}');
        expect(edge / matches, greaterThan(3));
        expect(wins, greaterThan(matches / sides));
      });
    }
  });
}

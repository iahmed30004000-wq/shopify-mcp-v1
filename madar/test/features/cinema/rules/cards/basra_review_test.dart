// Basra: problems found in the adversarial rules review, each proved by a
// test that failed before its fix (final spec §3, §4, §6.1), plus the
// capture search checked against brute force and the AI levels in order.
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/cinema/rules/cards/cards.dart';

import 'support.dart';

List<PlayingCard> c(String ids) => PlayingCard.list(ids);
PlayingCard p(String id) => PlayingCard.parse(id);

/// Brute force over every family of disjoint groups of [table] numerals
/// adding up to [v]: the best (cards, scoring cards, card points).
(int, int, int) bruteBest(List<PlayingCard> table, int v) {
  final nums = [
    for (final x in table)
      if (BasraRules.numeral(x) != null) x,
  ];
  (int, int, int) key(Iterable<PlayingCard> taken) => (
    taken.length,
    taken.where((x) => BasraRules.cardPoints(x) > 0).length,
    taken.fold<int>(0, (a, x) => a + BasraRules.cardPoints(x)),
  );
  bool better((int, int, int) a, (int, int, int) b) =>
      a.$1 > b.$1 || (a.$1 == b.$1 && (a.$2 > b.$2 || (a.$2 == b.$2 && a.$3 > b.$3)));
  var best = (0, 0, 0);
  void go(Set<int> used, int from) {
    final k = key([for (final i in used) nums[i]]);
    if (better(k, best)) best = k;
    final free = [
      for (var i = 0; i < nums.length; i++)
        if (!used.contains(i)) i,
    ];
    for (var mask = 1; mask < 1 << free.length; mask++) {
      final g = [
        for (var k = 0; k < free.length; k++)
          if (mask & (1 << k) != 0) free[k],
      ];
      // Canonical order: each new group starts after the previous one.
      if (g.reduce(math.min) < from) continue;
      if (g.fold<int>(0, (a, i) => a + BasraRules.numeral(nums[i])!) != v) continue;
      go({...used, ...g}, g.reduce(math.min) + 1);
    }
  }

  go({}, 0);
  return best;
}

void main() {
  group('R1 hand sizes: only 4, 5 or 6 cards a round (spec §3, §6.1)', () {
    test('sizes that are not Basra deals are refused, even when the pack divides', () {
      // All of these split the pack into whole rounds, and all were accepted
      // before the fix (one round of 12, a 24-card hand, 1–3 cards a round…).
      for (final o in [
        const BasraOptions(handSize: 12),
        const BasraOptions(handSize: 2),
        const BasraOptions(handSize: 3),
        const BasraOptions(handSize: 1),
        const BasraOptions(players: 2, handSize: 8),
        const BasraOptions(players: 2, handSize: 24),
        const BasraOptions(players: 3, handSize: 8),
        const BasraOptions(players: 2, deck: BasraDeck.short44, handSize: 10),
      ]) {
        expect(o.configError, 'handSize', reason: 'players ${o.players} hand ${o.handSize} ${o.deck.name}');
        expect(() => BasraState.newMatch(options: o, seed: 1), throwsArgumentError);
      }
    });

    test('the sizes of the spec stay allowed', () {
      for (final o in [
        const BasraOptions(),
        const BasraOptions(handSize: 4),
        const BasraOptions(handSize: 6),
        const BasraOptions(players: 2, handSize: 6),
        const BasraOptions(players: 3),
        const BasraOptions.palestinian44(),
        const BasraOptions(deck: BasraDeck.short44, sevenDiamonds: BasraSevenDiamonds.normal, handSize: 5),
        const BasraOptions.palestinian44(players: 2),
        const BasraOptions(players: 2, deck: BasraDeck.short44, handSize: 5),
      ]) {
        expect(o.configError, isNull, reason: 'players ${o.players} hand ${o.handSize} ${o.deck.name}');
      }
    });
  });

  group('R2 an explicit hand size equal to the automatic one is the same rule set', () {
    test('handSize 4 is the Jordanian preset; 5 with 44 cards is the Palestinian one', () {
      // Before the fix both were `custom` and unequal to the preset.
      expect(const BasraOptions(handSize: 4), const BasraOptions());
      expect(const BasraOptions(handSize: 4).hashCode, const BasraOptions().hashCode);
      expect(const BasraOptions(handSize: 4).preset, BasraPreset.jordan);
      expect(
        const BasraOptions(deck: BasraDeck.short44, sevenDiamonds: BasraSevenDiamonds.normal, handSize: 5).preset,
        BasraPreset.palestinian44,
      );
      expect(const BasraOptions(handSize: 6).preset, BasraPreset.custom);
      expect(const BasraOptions(handSize: 6), isNot(const BasraOptions()));
    });
  });

  group('R3 AI: the next opponent gets a new hand after the last card of a round', () {
    // Seat 3 (the dealer) plays the last card of a round: every other hand is
    // empty, and a new round of four is dealt as soon as the card is down.
    // In a dealt game that last card is forced; the positions below are built
    // by hand (`BasraState.custom`), where the helpers must still be right.
    final stock = c('2H 3H 4H 5H 6H 7H 8H 9H TH 2D 4D 5D 6D 7D 8D 9D');
    BasraState roundEnd(String hand) =>
        BasraState.custom(hands: [c(''), c(''), c(''), c(hand)], table: c('4C'), stock: stock)..turn = 3;

    test('a card left on the table is at risk (it was counted as safe)', () {
      final s = roundEnd('9S');
      expect(BasraAi.risk(s, 3, c('4C'), BasraAi.unseen(s, 3)), greaterThan(0));
    });

    test('the medium AI does not leave 4 + 3 (a basra of 14 for any seven) when a queen is safer', () {
      for (final hand in ['3D QS', 'QS 3D']) {
        // Before the fix the choice followed the hand order: 3D was played
        // from '3D QS'.
        final m = const BasraAi().chooseMove(roundEnd(hand), 3, AiLevel.medium, math.Random(1), AiBudget.phone);
        expect(m, BasraMove(p('QS')), reason: hand);
      }
    });
  });

  group('R4 AI: only the very last card of the deal loses its basra (§4.3, E16)', () {
    test('every hand holds one card: the first of them still scores its basra', () {
      // 5S on a lone 5H is a basra of 10. `BasraAi.gain` valued it as a plain
      // capture whenever every hand held at most one card (then the move is
      // forced in a dealt game, but the helper is public).
      final s = BasraState.custom(hands: [c('5S'), c('9H'), c('8D'), c('3C')], table: c('5H'));
      expect(BasraAi.gain(s, 0, p('5S')), greaterThanOrEqualTo(10));
      final last = BasraState.custom(hands: [c('5S'), c(''), c(''), c('')], table: c('5H'));
      expect(BasraAi.gain(last, 0, p('5S')), lessThan(10));
      final counted = BasraState.custom(
        hands: [c('5S'), c(''), c(''), c('')],
        table: c('5H'),
        options: const BasraOptions(basraOnLastCard: true),
      );
      expect(BasraAi.gain(counted, 0, p('5S')), greaterThanOrEqualTo(10));
    });
  });

  group('captures against brute force (A4.1, A4.3, A10.1)', () {
    test('the family taken is the most cards, then the most scoring cards, then the most card points', () {
      final rng = CardRng(7);
      var checked = 0;
      for (var i = 0; i < 1500; i++) {
        final d = buildDeck();
        rng.shuffle(d);
        final n = 1 + rng.nextInt(7);
        final table = d.sublist(0, n);
        final v = BasraRules.numeral(d[n]);
        if (v == null) continue;
        final got = BasraRules.bestSumCapture([
          for (final x in table)
            if (BasraRules.numeral(x) != null) x,
        ], v);
        final key = (
          got.length,
          got.where((x) => BasraRules.cardPoints(x) > 0).length,
          got.fold<int>(0, (a, x) => a + BasraRules.cardPoints(x)),
        );
        expect(key, bruteBest(table, v), reason: '$table <- ${d[n]} took $got');
        // Every card taken is a numeral of at most the value, and the taken
        // cards add up to a multiple of it.
        expect(got.every((x) => BasraRules.numeral(x)! <= v), isTrue);
        expect(got.fold<int>(0, (a, x) => a + BasraRules.numeral(x)!) % v, 0);
        checked++;
      }
      expect(checked, greaterThan(500));
    });
  });

  group('AI levels in order', () {
    test('medium beats easy (Jordanian 4 players, 2 players)', () {
      for (final o in [const BasraOptions(targetScore: 61), const BasraOptions(players: 2, targetScore: 61)]) {
        final k = Kit(
          'basra',
          (seed) => BasraEngine.newMatch(seed: seed, options: o),
          BasraEngine.fromJson,
          const BasraAi(),
        );
        var wins = 0;
        var edge = 0.0;
        const matches = 12;
        for (var m = 0; m < matches; m++) {
          final levels = [for (var s = 0; s < o.players; s++) s % 2 == m % 2 ? AiLevel.medium : AiLevel.easy];
          final r = playMatch(k, 700 + m, levels);
          edge += r.scores[m % 2] - r.scores[1 - m % 2];
          if (r.winners.contains(m % 2)) wins++;
        }
        expect(edge / matches, greaterThan(3), reason: '${o.players} players');
        expect(wins, greaterThan(matches / 2), reason: '${o.players} players');
      }
    });
  });
}

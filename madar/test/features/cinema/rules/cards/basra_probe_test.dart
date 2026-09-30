// TEMPORARY probe (review), deleted after the review.
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/cinema/rules/cards/cards.dart';
import 'package:madar/features/cinema/rules/cards/core/deck.dart';

import 'support.dart';

List<PlayingCard> c(String ids) => PlayingCard.list(ids);
PlayingCard p(String id) => PlayingCard.parse(id);

/// Brute force: every family of disjoint groups adding up to [v]; the most
/// cards, then the most scoring cards, then the most card points.
(int, int, int) brute(List<PlayingCard> table, int v) {
  final nums = table.where((x) => BasraRules.numeral(x) != null).toList();
  var best = (0, 0, 0);
  void go(int i, List<List<PlayingCard>> groups, Set<PlayingCard> used) {
    final taken = groups.expand((g) => g).toList();
    final key = (
      taken.length,
      taken.where((x) => BasraRules.cardPoints(x) > 0).length,
      taken.fold<int>(0, (a, x) => a + BasraRules.cardPoints(x)),
    );
    if (key.$1 > best.$1 ||
        (key.$1 == best.$1 && (key.$2 > best.$2 || (key.$2 == best.$2 && key.$3 > best.$3)))) {
      best = key;
    }
    // Enumerate subsets of unused numerals that sum to v (containing the first unused at index >= i).
    final free = [for (final x in nums) if (!used.contains(x)) x];
    final n = free.length;
    for (var mask = 1; mask < 1 << n; mask++) {
      var sum = 0;
      final g = <PlayingCard>[];
      for (var k = 0; k < n; k++) {
        if (mask & (1 << k) != 0) {
          sum += BasraRules.numeral(free[k])!;
          g.add(free[k]);
        }
      }
      if (sum != v) continue;
      // canonical: the group's smallest index must be >= i in nums order
      final minIdx = g.map(nums.indexOf).reduce(math.min);
      if (minIdx < i) continue;
      go(minIdx + 1, [...groups, g], {...used, ...g});
    }
  }

  go(0, [], {});
  return best;
}

void main() {
  test('probe: capture family vs brute force', () {
    final rng = CardRng(7);
    final deck = buildDeck();
    var checked = 0;
    for (var i = 0; i < 1500; i++) {
      final d = List.of(deck);
      rng.shuffle(d);
      final n = 1 + rng.nextInt(7);
      final table = d.sublist(0, n);
      final card = d[n];
      final v = BasraRules.numeral(card);
      if (v == null) continue;
      final got = BasraRules.bestSumCapture(table.where((x) => BasraRules.numeral(x) != null).toList(), v);
      final key = (
        got.length,
        got.where((x) => BasraRules.cardPoints(x) > 0).length,
        got.fold<int>(0, (a, x) => a + BasraRules.cardPoints(x)),
      );
      expect(key, brute(table, v), reason: '$table <- $card got $got');
      checked++;
    }
    expect(checked, greaterThan(500));
  });

  test('probe: handSize values', () {
    for (final h in [1, 2, 3, 4, 5, 6, 8, 12, 24]) {
      for (final pl in [2, 3, 4]) {
        for (final d in BasraDeck.values) {
          final o = BasraOptions(players: pl, handSize: h, deck: d);
          // ignore: avoid_print
          if (o.configError == null) print('accepted: players $pl hand $h deck ${d.name} rounds ${o.roundsPerDeal}');
        }
      }
    }
    // ignore: avoid_print
    print('preset of handSize 4: ${const BasraOptions(handSize: 4).preset}');
  });

  test('probe: medium vs easy (Basra 4p)', () {
    final k = Kit(
      'b',
      (seed) => BasraEngine.newMatch(seed: seed, options: const BasraOptions(targetScore: 61)),
      BasraEngine.fromJson,
      const BasraAi(),
    );
    var edge = 0.0;
    var wins = 0;
    for (var m = 0; m < 10; m++) {
      final med = m % 2;
      final levels = [for (var s = 0; s < 4; s++) s % 2 == med ? AiLevel.medium : AiLevel.easy];
      final r = playMatch(k, 500 + m, levels);
      edge += r.scores[med] - r.scores[1 - med];
      if (r.winners.contains(med)) wins++;
    }
    // ignore: avoid_print
    print('basra medium vs easy: wins $wins/10 edge ${edge / 10}');
  });
}

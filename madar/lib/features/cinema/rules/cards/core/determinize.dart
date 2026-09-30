/// Sampling the hidden cards consistently with what a player has seen, for
/// the hard AI's information-set Monte Carlo search.
library;

import 'dart:math' as math;

import 'card_rng.dart';
import 'playing_card.dart';

/// Deals [pool] to `counts.length` holders (`counts` must add up to
/// `pool.length`) at random, so that holder `h` only receives cards with
/// `canHold(h, card)`. Constraints are kept whenever a consistent deal is
/// found within a few attempts; otherwise they are relaxed for the cards that
/// cannot be placed (the search is still sound, just less informed).
List<List<PlayingCard>> dealConstrained(
  List<PlayingCard> pool,
  List<int> counts,
  bool Function(int holder, PlayingCard card) canHold,
  math.Random rng,
) {
  final holders = counts.length;
  final total = counts.fold<int>(0, (a, b) => a + b);
  if (total != pool.length) {
    throw ArgumentError('counts ($total) must add up to the pool (${pool.length})');
  }
  final eligible = <PlayingCard, List<int>>{};
  for (final c in pool) {
    eligible.putIfAbsent(c, () => [for (var h = 0; h < holders; h++) if (counts[h] > 0 && canHold(h, c)) h]);
  }
  for (var attempt = 0; attempt < 24; attempt++) {
    final cards = List.of(pool);
    shuffleWith(cards, rng);
    // Most constrained cards first.
    cards.sort((a, b) => eligible[a]!.length - eligible[b]!.length);
    final left = List.of(counts);
    final out = [for (var h = 0; h < holders; h++) <PlayingCard>[]];
    var ok = true;
    for (final c in cards) {
      final options = eligible[c]!.where((h) => left[h] > 0).toList();
      if (options.isEmpty) {
        ok = false;
        break;
      }
      // Weighted by remaining capacity.
      final weight = options.fold<int>(0, (a, h) => a + left[h]);
      var r = rng.nextInt(weight);
      var pick = options.last;
      for (final h in options) {
        r -= left[h];
        if (r < 0) {
          pick = h;
          break;
        }
      }
      out[pick].add(c);
      left[pick]--;
    }
    if (ok) return out;
  }
  // Relaxed fallback: honour constraints greedily, then fill anything.
  final cards = List.of(pool);
  shuffleWith(cards, rng);
  final left = List.of(counts);
  final out = [for (var h = 0; h < holders; h++) <PlayingCard>[]];
  final rest = <PlayingCard>[];
  for (final c in cards) {
    final options = eligible[c]!.where((h) => left[h] > 0).toList();
    if (options.isEmpty) {
      rest.add(c);
      continue;
    }
    final h = options[rng.nextInt(options.length)];
    out[h].add(c);
    left[h]--;
  }
  for (final c in rest) {
    final h = [for (var i = 0; i < holders; i++) if (left[i] > 0) i].first;
    out[h].add(c);
    left[h]--;
  }
  return out;
}

/// `all` minus every card of `remove` (multiset difference).
List<PlayingCard> cardsMinus(Iterable<PlayingCard> all, Iterable<PlayingCard> remove) {
  final counts = <PlayingCard, int>{};
  for (final c in remove) {
    counts[c] = (counts[c] ?? 0) + 1;
  }
  final out = <PlayingCard>[];
  for (final c in all) {
    final n = counts[c] ?? 0;
    if (n > 0) {
      counts[c] = n - 1;
    } else {
      out.add(c);
    }
  }
  return out;
}

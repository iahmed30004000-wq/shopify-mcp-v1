/// Basra AI: greedy captures (easy), capture value minus the risk left to
/// the next opponent from counted cards (medium), determinised Monte Carlo
/// (hard). Works for every rule set (2–4 players, 52 or 44 cards, either
/// basra value): all values come from [BasraRules.captureFor].
library;

import 'dart:math' as math;

import '../core/ai_base.dart';
import '../core/card_rng.dart';
import '../core/determinize.dart';
import '../core/playing_card.dart';
import 'basra_rules.dart';
import 'basra_state.dart';

class BasraAi extends HeuristicAi<BasraState, BasraMove> {
  const BasraAi() : super(const BasraRules());

  @override
  double get matchWinBonus => 40;

  /// What one more captured card is worth towards the most-cards points
  /// (0.25 with the Jordanian 3; more with the Egyptian 30).
  static double cardWeight(BasraOptions o) => 0.25 + math.max(0, o.majorityPoints - 3) / 40;

  /// Immediate value of playing [card] for its side.
  static double gain(BasraState s, int seat, PlayingCard card) {
    final cap = BasraRules.captureFor(s.table, card, s.options);
    if (!cap.isCapture) {
      // A dropped card may be picked up by the opponents.
      return -BasraRules.cardPoints(card) * 1.0 - (card.rank == Rank.jack ? 3 : 0);
    }
    final lastCard = s.stock.isEmpty && s.hands.every((h) => h.length <= 1);
    var v = 0.0;
    for (final c in [...cap.cards, card]) {
      v += BasraRules.cardPoints(c) + cardWeight(s.options);
    }
    if (cap.basraPoints > 0 && (!lastCard || s.options.basraOnLastCard)) v += cap.basraPoints;
    // Using a jack or the sweeping 7♦ on a poor table wastes it.
    if (card.rank == Rank.jack || (card == sevenOfDiamonds && s.options.sevenDiamonds == BasraSevenDiamonds.sweep)) {
      v -= 1.5;
    }
    return v;
  }

  /// Cards [seat] has not seen (hidden in hands or the stock).
  static List<PlayingCard> unseen(BasraState s, int seat) {
    final seen = <PlayingCard>{...s.hands[seat], ...s.table, for (final p in s.piles) ...p};
    return [
      for (final c in s.fullDeck())
        if (!seen.contains(c)) c,
    ];
  }

  /// Expected loss from what the next opponent can do with [table].
  static double risk(BasraState s, int seat, List<PlayingCard> table, List<PlayingCard> unseenCards) {
    if (table.isEmpty || unseenCards.isEmpty) return 0;
    final next = (seat + 1) % s.playerCount;
    final handSize = s.hands[next].length;
    if (handSize == 0) return 0;
    final total = unseenCards.length;
    double chance(int k) => k <= 0 ? 0 : 1 - math.pow(1 - k / total, handSize).toDouble();
    final w = cardWeight(s.options);
    final tableValue = table.fold<double>(0, (a, c) => a + BasraRules.cardPoints(c) + w);
    var loss = 0.0;
    // A jack sweeps everything (a basra on a lone jack).
    final jacks = unseenCards.where((c) => c.rank == Rank.jack).length;
    final loneJack = table.length == 1 && table.first.rank == Rank.jack;
    loss += chance(jacks) * (tableValue + 1 + (loneJack ? s.options.jackBasraPoints : 0));
    // Basra threats: a card (the 7♦ included) that clears the table. Each
    // is weighted by what that basra would be worth to the opponent (twice
    // the card in Jordan, a flat value in Egypt).
    var basraCards = 0;
    var basraValue = 0;
    for (final c in unseenCards.toSet()) {
      if (c.rank == Rank.jack) continue;
      final cap = BasraRules.captureFor(table, c, s.options);
      if (cap.basraPoints > 0) {
        basraCards++;
        basraValue += cap.basraPoints;
      }
    }
    if (basraCards > 0) loss += chance(basraCards) * (basraValue / basraCards + tableValue);
    return loss;
  }

  /// Rollouts use the plain greedy capture value (much cheaper than the
  /// risk model).
  @override
  BasraMove rolloutMove(BasraState s, int seat, math.Random rng) {
    final legal = rules.legalMoves(s, seat);
    return legal.length == 1 ? legal.first : bestBy(legal, (m) => gain(s, seat, m.card));
  }

  @override
  BasraMove easyMove(BasraState s, int seat, List<BasraMove> legal, math.Random rng) => bestBy(legal, (m) {
    final cap = BasraRules.captureFor(s.table, m.card, s.options);
    return cap.cards.length * 2 + cap.basraPoints - (m.card.rank == Rank.jack && cap.cards.length < 2 ? 3 : 0);
  });

  @override
  BasraMove mediumMove(BasraState s, int seat, List<BasraMove> legal, math.Random rng) {
    final unseenCards = unseen(s, seat);
    return bestBy(legal, (m) {
      final cap = BasraRules.captureFor(s.table, m.card, s.options);
      final after = cap.isCapture
          ? [
              for (final c in s.table)
                if (!cap.cards.contains(c)) c,
            ]
          : [...s.table, m.card];
      return gain(s, seat, m.card) - risk(s, seat, after, unseenCards) * 0.8;
    });
  }

  @override
  BasraState determinize(BasraState s, int observer, math.Random rng) {
    final w = s.copy()
      // Future shuffles must not leak into the search.
      ..rng = CardRng(rng.nextInt(0x7fffffff));
    final pool = unseen(s, observer);
    final others = [
      for (var i = 0; i < s.playerCount; i++)
        if (i != observer) i,
    ];
    final counts = [for (final o in others) s.hands[o].length, s.stock.length];
    final dealt = dealConstrained(pool, counts, (h, c) => true, rng);
    for (var i = 0; i < others.length; i++) {
      w.hands[others[i]] = dealt[i]..sort();
    }
    w.stock = dealt.last;
    return w;
  }
}

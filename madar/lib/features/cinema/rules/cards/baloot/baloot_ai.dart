/// Baloot AI: hand evaluation for Sun / Hokom, doubling, card counting and
/// partner feeding in play; determinised Monte Carlo for hard.
library;

import 'dart:math' as math;

import '../core/ai_base.dart';
import '../core/card_rng.dart';
import '../core/determinize.dart';
import '../core/playing_card.dart';
import '../core/trick.dart';
import 'baloot_rules.dart';
import 'baloot_state.dart';

/// Strength of [cards] for Sun (roughly: expected winners).
double balootSunStrength(List<PlayingCard> cards) {
  var v = 0.0;
  for (final suit in Suit.values) {
    final ranks = ofSuit(cards, suit).map((c) => c.rank).toSet();
    final len = ofSuit(cards, suit).length;
    if (ranks.contains(Rank.ace)) v += 1;
    if (ranks.contains(Rank.ten)) v += ranks.contains(Rank.ace) ? 0.8 : (len >= 2 ? 0.35 : 0.1);
    if (ranks.contains(Rank.king) && ranks.contains(Rank.ace) && ranks.contains(Rank.ten)) v += 0.5;
    if (len >= 4 && ranks.contains(Rank.ace)) v += 0.3;
  }
  return v;
}

/// Strength of [cards] for Hokom with [trump].
double balootHokomStrength(List<PlayingCard> cards, Suit trump) {
  var v = 0.0;
  final trumps = ofSuit(cards, trump).map((c) => c.rank).toSet();
  if (trumps.contains(Rank.jack)) v += 1.6;
  if (trumps.contains(Rank.nine)) v += trumps.contains(Rank.jack) ? 1.3 : 0.9;
  if (trumps.contains(Rank.ace)) v += 0.7;
  if (trumps.contains(Rank.ten)) v += 0.4;
  v += (trumps.length - trumps.intersection({Rank.jack, Rank.nine, Rank.ace, Rank.ten}).length) * 0.3;
  for (final suit in Suit.values) {
    if (suit == trump) continue;
    final side = ofSuit(cards, suit).map((c) => c.rank).toSet();
    if (side.contains(Rank.ace)) v += 0.7;
    if (side.isEmpty && trumps.length >= 3) v += 0.3;
  }
  return v;
}

class BalootAi extends HeuristicAi<BalootState, BalootMove> {
  const BalootAi() : super(const BalootRules());

  @override
  double get matchWinBonus => 60;

  // ---------------------------------------------------------------- bidding

  BalootMove _bid(BalootState s, int seat, List<BalootMove> legal, {required bool careful, math.Random? rng}) {
    final hand = s.hands[seat];
    final up = s.upCard!;
    final withUp = [...hand, up];
    final noise = careful || rng == null ? 0.0 : rng.nextDouble() * 1.0 - 0.4;
    final sun = balootSunStrength(withUp) + noise;
    final partnerBought = s.buyer >= 0 && s.buyer % 2 == seat % 2;
    final sunThreshold = careful ? (partnerBought ? 3.6 : 2.7) : 2.6;
    if (legal.contains(const BalootMove.sun()) && sun >= sunThreshold) return const BalootMove.sun();
    final hokoms = legal.where((m) => m.kind == BalootMoveKind.hokom).toList();
    if (hokoms.isNotEmpty) {
      final best = bestBy(hokoms, (m) => balootHokomStrength(withUp, m.suit!));
      final strength = balootHokomStrength(withUp, best.suit!) + noise;
      final trumps = ofSuit(withUp, best.suit!).length;
      if (strength >= (careful ? 3.1 : 2.8) && trumps >= 3) return best;
    }
    return const BalootMove.pass();
  }

  BalootMove _doubleDecision(BalootState s, int seat) {
    final hand = s.hands[seat];
    if (s.mode == BalootMode.sun) {
      return balootSunStrength(hand) >= 4.2 ? const BalootMove.raise() : const BalootMove.pass();
    }
    final trump = s.trump!;
    final t = ofSuit(hand, trump).map((c) => c.rank).toSet();
    final strong = t.contains(Rank.jack) && t.contains(Rank.nine) && t.length >= 3;
    if (seat == s.buyer) {
      return s.level < 4 && strong && t.length >= 5 ? const BalootMove.raise() : const BalootMove.pass();
    }
    if (s.level == 1) return strong ? const BalootMove.raise() : const BalootMove.pass();
    return strong && t.length >= 4 && s.level < 4 ? const BalootMove.raise() : const BalootMove.pass();
  }

  // ------------------------------------------------------------------ play

  PlayingCard _playMedium(BalootState s, int seat) {
    final legal = BalootRules.playable(s, seat);
    if (legal.length == 1) return legal.first;
    final hand = s.hands[seat];
    final mode = s.mode!;
    final trump = s.trump;
    final played = s.playedCards.toSet();
    int rankOf(PlayingCard c) =>
        BalootRules.isTrump(c, mode, trump) ? BalootRules.trumpRank(c.rank) : BalootRules.sunRank(c.rank);
    int pts(PlayingCard c) => BalootRules.cardPoints(c, mode, trump);
    bool isMaster(PlayingCard c) {
      for (final x in s.fullDeck()) {
        if (x.suit != c.suit || played.contains(x) || hand.contains(x)) continue;
        if (rankOf(x) > rankOf(c)) return false;
      }
      return true;
    }

    final voids = voidsFromTricks([...s.tricks, if (s.trick != null) s.trick!], 4);
    bool opponentsMayRuff(Suit suit) {
      if (mode == BalootMode.sun || suit == trump) return false;
      final trumpsOut = s.fullDeck().any((x) => x.suit == trump && !played.contains(x) && !hand.contains(x));
      if (!trumpsOut) return false;
      return [(seat + 1) % 4, (seat + 3) % 4].any((o) => voids[o].contains(suit) && !voids[o].contains(trump));
    }

    final trick = s.trick!;
    final buyers = s.buyer % 2 == seat % 2;
    if (trick.isEmpty) {
      if (mode == BalootMode.hokom && buyers) {
        final masters = legal.where((c) => c.suit == trump && isMaster(c)).toList();
        final trumpsOut = s.fullDeck().any((x) => x.suit == trump && !played.contains(x) && !hand.contains(x));
        if (masters.isNotEmpty && trumpsOut) return bestBy(masters, rankOf);
      }
      final sideMasters = legal.where((c) => c.suit != trump && isMaster(c) && !opponentsMayRuff(c.suit)).toList();
      if (sideMasters.isNotEmpty) return bestBy(sideMasters, (c) => pts(c) * 10 + rankOf(c));
      final safe = legal.where((c) => c.suit != trump && !opponentsMayRuff(c.suit)).toList();
      final pool = safe.isNotEmpty ? safe : legal;
      return bestBy(pool, (c) => -pts(c) * 10 - rankOf(c) + ofSuit(hand, c.suit).length);
    }
    final led = trick.ledSuit!;
    int pw(PlayingCard c) => BalootRules.power(c, led, mode, trump);
    final winIdx = trick.winningIndex((c, l) => BalootRules.power(c, l, mode, trump));
    final winCard = trick.cards[winIdx];
    final partnerWinning = trick.seats[winIdx] % 2 == seat % 2;
    final last = trick.length == 3;
    final partnerSafe =
        partnerWinning && (last || (isMaster(winCard) && (winCard.suit == trump || !opponentsMayRuff(led))));
    if (partnerSafe) {
      // Feed the partner points without wasting masters.
      final feed = legal.where((c) => !isMaster(c) || pts(c) >= 10).toList();
      final pool = feed.isNotEmpty ? feed : legal;
      return bestBy(pool, (c) => pts(c) * 10 - rankOf(c) - (BalootRules.isTrump(c, mode, trump) ? 200 : 0));
    }
    final beaters = legal.where((c) => pw(c) > pw(winCard)).toList();
    if (beaters.isNotEmpty) {
      final trickPts = trick.cards.fold<int>(0, (a, c) => a + pts(c));
      if (last) return bestBy(beaters, (c) => -pw(c) - pts(c) * 2);
      final masters = beaters.where((c) => isMaster(c) && (c.suit == trump || !opponentsMayRuff(led))).toList();
      if (masters.isNotEmpty) return bestBy(masters, (c) => -pw(c));
      if (trickPts >= 10 || BalootRules.isTrump(beaters.first, mode, trump)) {
        return bestBy(beaters, (c) => -pw(c));
      }
    }
    // Losing: throw the cheapest card.
    return bestBy(legal, (c) => -pts(c) * 10 - rankOf(c) - (BalootRules.isTrump(c, mode, trump) ? 100 : 0));
  }

  PlayingCard _playEasy(BalootState s, int seat) {
    final legal = BalootRules.playable(s, seat);
    final trick = s.trick!;
    if (trick.isEmpty) return bestBy(legal, (c) => BalootRules.cardPoints(c, s.mode, s.trump));
    final led = trick.ledSuit!;
    final winIdx = trick.winningIndex((c, l) => BalootRules.power(c, l, s.mode, s.trump));
    final best = BalootRules.power(trick.cards[winIdx], led, s.mode, s.trump);
    final beaters = legal.where((c) => BalootRules.power(c, led, s.mode, s.trump) > best).toList();
    if (trick.seats[winIdx] % 2 != seat % 2 && beaters.isNotEmpty) {
      return bestBy(beaters, (c) => BalootRules.power(c, led, s.mode, s.trump));
    }
    return bestBy(legal, (c) => -BalootRules.cardPoints(c, s.mode, s.trump));
  }

  // ------------------------------------------------------------ AI levels

  @override
  BalootMove easyMove(BalootState s, int seat, List<BalootMove> legal, math.Random rng) => switch (s.phase) {
    BalootPhase.bidding => _bid(s, seat, legal, careful: false, rng: rng),
    BalootPhase.doubling => const BalootMove.pass(),
    _ => BalootMove.play(_playEasy(s, seat)),
  };

  @override
  BalootMove mediumMove(BalootState s, int seat, List<BalootMove> legal, math.Random rng) => switch (s.phase) {
    BalootPhase.bidding => _bid(s, seat, legal, careful: true),
    BalootPhase.doubling => _doubleDecision(s, seat),
    _ => BalootMove.play(_playMedium(s, seat)),
  };

  @override
  BalootState determinize(BalootState s, int observer, math.Random rng) {
    final w = s.copy()
      // Future shuffles must not leak into the search.
      ..rng = CardRng(rng.nextInt(0x7fffffff));
    final others = [
      for (var i = 0; i < 4; i++)
        if (i != observer) i,
    ];
    final seen = <PlayingCard>{...s.hands[observer], ...s.playedCards, ?s.upCard};
    // Publicly known cards in other hands: the taken up-card and revealed
    // projects.
    final fixed = [for (var i = 0; i < 4; i++) <PlayingCard>{}];
    final up = s.turnedUp;
    if (s.upCard == null && up != null && s.buyer >= 0 && s.buyer != observer && !seen.contains(up)) {
      fixed[s.buyer].add(up);
    }
    if (s.projectsRevealed) {
      for (final p in s.projects) {
        if (p.seat == observer) continue;
        for (final c in p.cards) {
          if (!seen.contains(c)) fixed[p.seat].add(c);
        }
      }
    }
    final fixedAll = {for (final f in fixed) ...f};
    final pool = [
      for (final c in s.fullDeck())
        if (!seen.contains(c) && !fixedAll.contains(c)) c,
    ];
    final voids = voidsFromTricks([...s.tricks, if (s.trick != null) s.trick!], 4);
    final counts = [for (final o in others) s.hands[o].length - fixed[o].length, s.stock.length];
    final dealt = dealConstrained(
      pool,
      counts,
      (h, c) => h == others.length || !voids[others[h]].contains(c.suit),
      rng,
    );
    for (var i = 0; i < others.length; i++) {
      w.hands[others[i]] = [...fixed[others[i]], ...dealt[i]]..sort();
    }
    w.stock = dealt.last;
    return w;
  }
}

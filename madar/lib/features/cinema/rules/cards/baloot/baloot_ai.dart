/// Baloot AI: hand evaluation for Sun / Hokom / Ashkal, the Sun priority and
/// Hokom confirmation steps, doubling with the lock choice, card counting and
/// partner feeding in play (legality, including the Saudi trumping rules, comes
/// from [BalootRules.playable]); determinised Monte Carlo for hard.
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

  /// Best Hokom among [hokoms] for [cards], with its strength.
  static (BalootMove, double) _bestHokom(List<BalootMove> hokoms, List<PlayingCard> cards) {
    final best = bestBy(hokoms, (m) => balootHokomStrength(cards, m.suit!));
    return (best, balootHokomStrength(cards, best.suit!));
  }

  BalootMove _bid(BalootState s, int seat, List<BalootMove> legal, {required bool careful, math.Random? rng}) {
    // A hand of 7s, 8s and 9s only is not worth playing.
    if (legal.contains(const BalootMove.kawesh())) return const BalootMove.kawesh();
    final hand = s.hands[seat];
    final up = s.upCard!;
    final withUp = [...hand, up];
    final noise = careful || rng == null ? 0.0 : rng.nextDouble() * 1.0 - 0.4;
    final sun = balootSunStrength(withUp) + noise;
    final ourContract = s.bidder >= 0 && s.buyer % 2 == seat % 2;
    final sunThreshold = careful ? (ourContract ? 3.6 : 2.7) : 2.6;
    final hokomThreshold = careful ? 3.1 : 2.8;
    switch (s.bidStage) {
      case BalootBidStage.confirm:
        // Keep the Hokom unless the hand (with the up card) is a clear Sun.
        final (_, hokom) = _bestHokom([BalootMove.hokom(s.trump!)], withUp);
        return sun >= sunThreshold + 0.4 && sun >= hokom - 0.3 ? const BalootMove.sun() : const BalootMove.confirm();
      case BalootBidStage.priority:
        // Overcalling the partner only moves the up card: rarely worth it.
        final need = ourContract ? sunThreshold + (s.mode == BalootMode.sun ? 1.5 : 0.3) : sunThreshold;
        return sun >= need ? const BalootMove.sun() : const BalootMove.pass();
      case BalootBidStage.open:
        break;
    }
    if (legal.contains(const BalootMove.sun()) && sun >= sunThreshold) return const BalootMove.sun();
    if (legal.contains(const BalootMove.ashkal())) {
      // Sun for the partner, who takes the up card: a good Sun hand that
      // does not need the up card itself.
      final own = balootSunStrength(hand) + noise;
      if (own >= sunThreshold - 0.2 && (up.rank == Rank.ten || up.rank == Rank.king || up.rank == Rank.queen)) {
        return const BalootMove.ashkal();
      }
    }
    final hokoms = legal.where((m) => m.kind == BalootMoveKind.hokom).toList();
    if (hokoms.isNotEmpty) {
      final (best, strength) = _bestHokom(hokoms, withUp);
      final trumps = ofSuit(withUp, best.suit!).length;
      // The third round (up-turned Ace) is the last chance to play the deal.
      final need = s.bidRound == 3 ? hokomThreshold - 0.6 : hokomThreshold;
      if (strength + noise >= need && trumps >= 3) return best;
    }
    return const BalootMove.pass();
  }

  BalootMove _doubleDecision(BalootState s, int seat, List<BalootMove> legal) {
    final hand = s.hands[seat];
    if (s.mode == BalootMode.sun) {
      return balootSunStrength(hand) >= 4.2 ? const BalootMove.raise() : const BalootMove.pass();
    }
    final trump = s.trump!;
    final t = ofSuit(hand, trump).map((c) => c.rank).toSet();
    final strong = t.contains(Rank.jack) && t.contains(Rank.nine) && t.length >= 3;
    // A defender holding the top trumps locks the play so they cannot be
    // drawn by trump leads.
    BalootMove raise() {
      final lock = t.contains(Rank.jack) && t.length >= 3;
      final m = BalootMove.raise(locked: lock);
      return legal.contains(m) ? m : const BalootMove.raise();
    }

    if (seat == s.buyer) {
      return s.level < 4 && strong && t.length >= 5 ? const BalootMove.raise() : const BalootMove.pass();
    }
    if (s.level == 1) return strong ? raise() : const BalootMove.pass();
    return strong && t.length >= 4 && s.level < 4 ? raise() : const BalootMove.pass();
  }

  /// Manual declaration: declare unless an opponent has already declared a
  /// better project (then ours would score nothing and only show cards).
  BalootMove _declareDecision(BalootState s, int seat) {
    final mine = BalootRules.projectsOf(s, seat);
    for (final p in s.projects) {
      if (p.seat % 2 == seat % 2) continue;
      final beaten = mine.every(
        (q) => BalootRules.compareProjects(p, q, s.firstPlayer, s.mode!, trump: s.trump, options: s.options) > 0,
      );
      if (beaten) return const BalootMove.skipProjects();
    }
    return const BalootMove.declareProjects();
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
    _ =>
      legal.contains(const BalootMove.declareProjects())
          ? const BalootMove.declareProjects()
          : BalootMove.play(_playEasy(s, seat)),
  };

  @override
  BalootMove mediumMove(BalootState s, int seat, List<BalootMove> legal, math.Random rng) => switch (s.phase) {
    BalootPhase.bidding => _bid(s, seat, legal, careful: true),
    BalootPhase.doubling => _doubleDecision(s, seat, legal),
    _ =>
      legal.contains(const BalootMove.declareProjects())
          ? _declareDecision(s, seat)
          : BalootMove.play(_playMedium(s, seat)),
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
    // Who holds the belote is hidden until it is announced: take it from
    // the sampled hands, not from the real deal.
    if (w.phase != BalootPhase.bidding && w.phase != BalootPhase.over) w.belote = BalootRules.beloteHolder(w);
    return w;
  }
}

/// Tarneeb AI: easy / medium (card counting, voids, partner signals) / hard
/// (determinised Monte Carlo).
library;

import 'dart:math' as math;

import '../core/ai_base.dart';
import '../core/determinize.dart';
import '../core/playing_card.dart';
import '../core/trick.dart';
import 'tarneeb_rules.dart';
import 'tarneeb_state.dart';

/// Estimated tricks of [hand] with [trump] as trumps (no partner help).
double tarneebHandTricks(List<PlayingCard> hand, Suit trump) {
  var tricks = 0.0;
  final trumpLen = ofSuit(hand, trump).length;
  var spareTrumps = trumpLen - 3;
  for (final suit in Suit.values) {
    final cards = ofSuit(hand, suit).map((c) => c.rank).toSet();
    final len = ofSuit(hand, suit).length;
    if (suit == trump) {
      if (cards.contains(Rank.ace)) tricks += 1;
      if (cards.contains(Rank.king)) tricks += len >= 2 ? 0.9 : 0.4;
      if (cards.contains(Rank.queen)) tricks += len >= 3 ? 0.7 : 0.2;
      if (cards.contains(Rank.jack) && len >= 4) tricks += 0.4;
      if (len > 3) tricks += (len - 3) * 0.85;
    } else {
      if (cards.contains(Rank.ace)) tricks += len >= 7 ? 0.7 : 1;
      if (cards.contains(Rank.king)) tricks += len >= 2 ? (len >= 6 ? 0.5 : 0.75) : 0.2;
      if (cards.contains(Rank.queen) && len >= 3 && len <= 5) tricks += 0.35;
      if (len <= 1 && spareTrumps > 0) {
        final ruffs = len == 0 ? 1.0 : 0.5;
        tricks += ruffs;
        spareTrumps--;
      }
    }
  }
  return tricks;
}

/// What a seat can deduce from the public history of the current deal.
class _Memory {
  _Memory(TarneebState s, this.seat) : hand = s.hands[seat], trump = s.trump {
    for (final c in s.playedCards) {
      played.add(c);
    }
    final all = [...s.tricks, if (s.trick != null) s.trick!];
    voids = voidsFromTricks(all, 4);
    // Partner's encouraging discards (a high card thrown while not following).
    final partner = (seat + 2) % 4;
    for (final t in s.tricks) {
      final led = t.cards.first.suit;
      for (var i = 1; i < t.cards.length; i++) {
        final c = t.cards[i];
        if (t.seats[i] == partner && c.suit != led && c.suit != trump && c.rank.value >= 8) wanted = c.suit;
      }
    }
  }

  final int seat;
  final List<PlayingCard> hand;
  final Suit? trump;
  final Set<PlayingCard> played = {};
  late final List<Set<Suit>> voids;
  Suit? wanted;

  /// No unseen card of the same suit outranks [card].
  bool isMaster(PlayingCard card) {
    for (var v = card.rank.value + 1; v <= 14; v++) {
      final c = PlayingCard(card.suit, Rank.fromValue(v));
      if (!played.contains(c) && !hand.contains(c)) return false;
    }
    return true;
  }

  int unseenIn(Suit suit) {
    var n = 0;
    for (final r in Rank.values) {
      final c = PlayingCard(suit, r);
      if (!played.contains(c) && !hand.contains(c)) n++;
    }
    return n;
  }

  bool opponentsMayRuff(Suit suit) {
    if (trump == null || suit == trump) return false;
    if (unseenIn(trump!) == 0) return false;
    for (final o in [(seat + 1) % 4, (seat + 3) % 4]) {
      if (voids[o].contains(suit) && !voids[o].contains(trump)) return true;
    }
    return false;
  }
}

class TarneebAi extends HeuristicAi<TarneebState, TarneebMove> {
  const TarneebAi() : super(const TarneebRules());

  @override
  double get matchWinBonus => 20;

  // ---------------------------------------------------------------- bidding

  TarneebMove _bid(TarneebState s, int seat, List<TarneebMove> legal, {required bool careful, math.Random? rng}) {
    final hand = s.hands[seat];
    var mine = Suit.values.map((t) => tarneebHandTricks(hand, t)).reduce(math.max);
    if (!careful && rng != null) mine += rng.nextDouble() * 1.6 - 0.6;
    var team = mine + 2.6;
    if (careful) {
      final partner = (seat + 2) % 4;
      final partnerBids = s.bids.where((b) => b.seat == partner && !b.isPass).map((b) => b.amount);
      if (partnerBids.isNotEmpty) {
        final pb = partnerBids.reduce(math.max);
        team = math.max(team, pb + (mine - 2.8) * 0.8);
      }
      // Outbidding the opponents costs: be a little more conservative.
      if (s.highBidder >= 0 && s.highBidder % 2 != seat % 2) team -= 0.3;
    }
    final target = team.floor();
    final bids = legal.where((m) => m.kind == TarneebMoveKind.bid).toList();
    final canPass = legal.contains(const TarneebMove.pass());
    if (bids.isEmpty) return legal.first;
    final lowest = bids.first;
    // Never overbid a partner who holds the contract unless much stronger.
    if (careful && s.highBidder >= 0 && s.highBidder % 2 == seat % 2 && canPass) {
      if (target < lowest.amount! + 1) return const TarneebMove.pass();
    }
    if (lowest.amount! <= target || !canPass) return lowest;
    return const TarneebMove.pass();
  }

  Suit _bestTrump(List<PlayingCard> hand) =>
      bestBy(Suit.values, (t) => tarneebHandTricks(hand, t) + ofSuit(hand, t).length * 0.01);

  // ------------------------------------------------------------------ play

  PlayingCard _lowest(Iterable<PlayingCard> cards, Suit? trump) => bestBy(
    cards,
    (c) => -(c.rank.value + (c.suit == trump ? 20 : 0)),
  );

  PlayingCard _playMedium(TarneebState s, int seat) {
    final mem = _Memory(s, seat);
    final trick = s.trick!;
    final trump = s.trump!;
    final legal = TarneebRules.playableCards(s.hands[seat], trick);
    final bidTeam = s.highBidder % 2 == seat % 2;
    if (trick.isEmpty) return _lead(s, mem, legal, bidTeam);
    final led = trick.ledSuit!;
    int pw(PlayingCard c) => TarneebRules.power(c, led, trump);
    final winIdx = trick.winningIndex((c, l) => TarneebRules.power(c, l, trump));
    final winCard = trick.cards[winIdx];
    final winSeat = trick.seats[winIdx];
    final partnerWinning = winSeat % 2 == seat % 2;
    final last = trick.length == 3;
    final beaters = legal.where((c) => pw(c) > pw(winCard)).toList();
    final following = legal.first.suit == led;
    bool partnerSafe() {
      if (last) return true;
      if (winCard.suit == trump) return mem.isMaster(winCard);
      return mem.isMaster(winCard) && !mem.opponentsMayRuff(led);
    }

    if (following) {
      if (partnerWinning && partnerSafe()) return _lowest(legal, trump);
      if (beaters.isEmpty) return _lowest(legal, trump);
      if (last) return _lowest(beaters, trump);
      final masters = beaters.where(mem.isMaster).toList();
      if (masters.isNotEmpty && !mem.opponentsMayRuff(led)) return _lowest(masters, trump);
      // Second hand low, third hand high.
      if (trick.length == 1) return _lowest(legal, trump);
      return bestBy(beaters, (c) => c.rank.value);
    }
    // Void in the led suit.
    final trumps = legal.where((c) => c.suit == trump).toList();
    final side = legal.where((c) => c.suit != trump).toList();
    if (partnerWinning && partnerSafe()) {
      if (side.isNotEmpty) return _discard(mem, side, trump, signal: true);
      return _lowest(trumps, trump);
    }
    if (beaters.isNotEmpty) {
      return _lowest(beaters, trump);
    }
    if (side.isNotEmpty) return _discard(mem, side, trump, signal: false);
    return _lowest(trumps, trump);
  }

  PlayingCard _discard(_Memory mem, List<PlayingCard> side, Suit trump, {required bool signal}) {
    if (signal) {
      // Encourage: a high-ish (≥ 8) non-master card of a suit where we hold
      // the master.
      for (final suit in Suit.values) {
        if (suit == trump) continue;
        final cards = side.where((c) => c.suit == suit).toList();
        if (cards.length < 2 || !cards.any(mem.isMaster)) continue;
        final spare = cards.where((c) => !mem.isMaster(c) && c.rank.value >= 8).toList();
        if (spare.isNotEmpty) return bestBy(spare, (c) => -c.rank.value);
      }
    }
    // Throw the lowest card that is not a master, preferring short suits.
    final nonMasters = side.where((c) => !mem.isMaster(c) && c.rank.value < 8).toList();
    final pool = nonMasters.isNotEmpty ? nonMasters : side;
    return bestBy(pool, (c) => -(c.rank.value * 4 + side.where((x) => x.suit == c.suit).length));
  }

  PlayingCard _lead(TarneebState s, _Memory mem, List<PlayingCard> legal, bool bidTeam) {
    final trump = s.trump!;
    final trumps = legal.where((c) => c.suit == trump).toList();
    final trumpsOut = mem.unseenIn(trump);
    // Declarers draw trumps with a master trump.
    if (bidTeam && trumps.isNotEmpty && trumpsOut > 0) {
      final masters = trumps.where(mem.isMaster).toList();
      if (masters.isNotEmpty) return bestBy(masters, (c) => c.rank.value);
      if (trumps.length >= 4 && trumps.length > trumpsOut) return _lowest(trumps, trump);
    }
    // Cash side masters the opponents cannot ruff.
    final sideMasters = legal.where((c) => c.suit != trump && mem.isMaster(c) && !mem.opponentsMayRuff(c.suit));
    if (sideMasters.isNotEmpty && mem.unseenIn(sideMasters.first.suit) > 0) {
      return bestBy(sideMasters, (c) => c.rank.value);
    }
    // Partner asked for a suit.
    final wanted = mem.wanted;
    if (wanted != null) {
      final cards = legal.where((c) => c.suit == wanted).toList();
      if (cards.isNotEmpty) return _lowest(cards, trump);
    }
    // Lead low from the longest side suit the opponents cannot ruff.
    final side = legal.where((c) => c.suit != trump && !mem.opponentsMayRuff(c.suit)).toList();
    final pool = side.isNotEmpty ? side : legal.where((c) => c.suit != trump).toList();
    if (pool.isNotEmpty) {
      final longest = bestBy(Suit.values.where((x) => pool.any((c) => c.suit == x)), (x) {
        return pool.where((c) => c.suit == x).length;
      });
      return _lowest(pool.where((c) => c.suit == longest), trump);
    }
    return _lowest(legal, trump);
  }

  PlayingCard _playEasy(TarneebState s, int seat) {
    final trick = s.trick!;
    final legal = TarneebRules.playableCards(s.hands[seat], trick);
    if (trick.isEmpty) return bestBy(legal, (c) => c.rank.value - (c.suit == s.trump ? 5 : 0));
    final led = trick.ledSuit!;
    final winIdx = trick.winningIndex((c, l) => TarneebRules.power(c, l, s.trump));
    if (trick.seats[winIdx] % 2 == seat % 2) return _lowest(legal, s.trump);
    final best = TarneebRules.power(trick.cards[winIdx], led, s.trump);
    final beaters = legal.where((c) => TarneebRules.power(c, led, s.trump) > best);
    if (beaters.isNotEmpty) return bestBy(beaters, (c) => c.rank.value);
    return _lowest(legal, s.trump);
  }

  // ------------------------------------------------------------ AI levels

  @override
  TarneebMove easyMove(TarneebState s, int seat, List<TarneebMove> legal, math.Random rng) => switch (s.phase) {
    TarneebPhase.bidding => _bid(s, seat, legal, careful: false, rng: rng),
    TarneebPhase.trump => TarneebMove.trump(_bestTrump(s.hands[seat])),
    _ => TarneebMove.play(_playEasy(s, seat)),
  };

  @override
  TarneebMove mediumMove(TarneebState s, int seat, List<TarneebMove> legal, math.Random rng) => switch (s.phase) {
    TarneebPhase.bidding => _bid(s, seat, legal, careful: true),
    TarneebPhase.trump => TarneebMove.trump(_bestTrump(s.hands[seat])),
    _ => TarneebMove.play(_playMedium(s, seat)),
  };

  @override
  TarneebState determinize(TarneebState s, int observer, math.Random rng) {
    final w = s.copy();
    final seen = <PlayingCard>{...s.hands[observer], ...s.playedCards};
    final pool = [
      for (final c in s.fullDeck())
        if (!seen.contains(c)) c,
    ];
    final others = [for (var i = 0; i < 4; i++) if (i != observer) i];
    final voids = voidsFromTricks([...s.tricks, if (s.trick != null) s.trick!], 4);
    final dealt = dealConstrained(
      pool,
      [for (final o in others) s.hands[o].length],
      (h, c) => !voids[others[h]].contains(c.suit),
      rng,
    );
    for (var i = 0; i < others.length; i++) {
      w.hands[others[i]] = dealt[i]..sort();
    }
    return w;
  }
}

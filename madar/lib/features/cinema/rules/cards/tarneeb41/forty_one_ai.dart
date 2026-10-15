/// "41" AI: easy (noisy bid, grab tricks while short) / medium (bid by
/// expected value with the match situation in mind, play for its own bid,
/// its partner's and against the opponents') / hard (determinised Monte
/// Carlo over the medium policy).
library;

import 'dart:math' as math;

import '../core/ai_base.dart';
import '../core/card_game.dart';
import '../core/card_rng.dart';
import '../core/determinize.dart';
import '../core/playing_card.dart';
import '../core/trick.dart';
import '../tarneeb/tarneeb_ai.dart' show tarneebHandTricks;
import 'forty_one_rules.dart';
import 'forty_one_state.dart';

/// Own tricks a hand is expected to take in the individual game, where
/// nobody plays to help the bidder.
double fortyOneHandTricks(List<PlayingCard> hand, Suit trump) => tarneebHandTricks(hand, trump) + 0.2;

/// Chance of taking at least [bid] tricks when [estimate] are expected.
double fortyOneMakeChance(double estimate, int bid, {double spread = 1.1}) {
  final z = (bid - 0.5 - estimate) / spread;
  return 1 - _phi(z);
}

// Standard normal CDF (Abramowitz–Stegun 7.1.26 through erf).
double _phi(double z) {
  final x = z.abs() / math.sqrt2;
  final t = 1 / (1 + 0.3275911 * x);
  final y =
      1 -
      (((((1.061405429 * t - 1.453152027) * t) + 1.421413741) * t - 0.284496736) * t + 0.254829592) *
          t *
          math.exp(-x * x);
  return z >= 0 ? 0.5 * (1 + y) : 0.5 * (1 - y);
}

/// What a seat can deduce from the public history of the deal.
class _Memory {
  _Memory(FortyOneState s, this.seat) : hand = s.hands[seat], trump = s.trump {
    played.addAll(s.playedCards);
    voids = voidsFromTricks([...s.tricks, if (s.trick != null) s.trick!], 4);
  }

  final int seat;
  final List<PlayingCard> hand;
  final Suit trump;
  final Set<PlayingCard> played = {};
  late final List<Set<Suit>> voids;

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

  /// One of [seats] may trump a lead of [suit].
  bool mayRuff(Suit suit, Iterable<int> seats) {
    if (suit == trump || unseenIn(trump) == 0) return false;
    return seats.any((o) => voids[o].contains(suit) && !voids[o].contains(trump));
  }
}

class FortyOneAi extends HeuristicAi<FortyOneState, FortyOneMove> {
  const FortyOneAi() : super(const FortyOneRules());

  @override
  double get matchWinBonus => 30;

  // ---------------------------------------------------------------- bidding

  /// Expected own tricks, trimmed when the bids already made claim most of
  /// the 13 tricks.
  double _estimate(FortyOneState s, int seat) {
    var est = fortyOneHandTricks(s.hands[seat], s.trump);
    var claimed = 0;
    for (var i = 0; i < 4; i++) {
      if (i != seat) claimed += s.bids[i] ?? 0;
    }
    final excess = claimed + est - 13;
    if (claimed > 0 && excess > 0) est -= excess * 0.3;
    return est;
  }

  /// Value of bidding [bid] for [seat]: expected points, plus the match
  /// situation (a made bid that wins the match, a failure that drops a
  /// player at the target below it).
  double bidUtility(FortyOneState s, int seat, int bid, double estimate) {
    final o = s.options;
    final p = fortyOneMakeChance(estimate, bid);
    final mine = s.playerScores[seat];
    final v = o.value(bid, mine).toDouble();
    var u = p * v - (1 - p) * v;
    final after = List.of(s.playerScores)..[seat] = mine + v.toInt();
    final team = seat % 2;
    if (!FortyOneRules.qualifies(o, s.playerScores, team) && FortyOneRules.qualifies(o, after, team)) {
      u += p * matchWinBonus;
    }
    if (mine >= o.target && mine - v < o.target) u -= (1 - p) * 10;
    return u;
  }

  FortyOneMove _bidMedium(FortyOneState s, int seat, List<FortyOneMove> legal) {
    final est = _estimate(s, seat);
    final bids = [for (final m in legal) m.amount!];
    var needed = 0;
    if (seat == s.dealer) needed = s.minTotalNow - s.bidTotal;
    // A dealer bid below [needed] throws the deal in: worth 0 to everybody,
    // counted a little lower because players usually make the total up
    // when it is close (and endless throw-ins are no fun).
    double utility(int b) => b < needed ? -2.5 : bidUtility(s, seat, b, est);
    final best = bestBy(bids, utility);
    return FortyOneMove.bid(best);
  }

  /// Easy: the estimate with some noise, rounded down; as dealer it makes
  /// the total up when that is within reach.
  FortyOneMove _bidEasy(FortyOneState s, int seat, List<FortyOneMove> legal, math.Random rng) {
    final est = fortyOneHandTricks(s.hands[seat], s.trump) + rng.nextDouble() * 1.2 - 0.7;
    var b = est.floor();
    if (seat == s.dealer) {
      final needed = s.minTotalNow - s.bidTotal;
      if (needed > b && needed <= est + 1.5) b = needed;
    }
    final lo = legal.first.amount!;
    return FortyOneMove.bid(b.clamp(lo, 13));
  }

  // ------------------------------------------------------------------ play

  static int _need(FortyOneState s, int seat) => (s.bids[seat] ?? 0) - s.tricksWon[seat];

  PlayingCard _lowest(Iterable<PlayingCard> cards, Suit trump) =>
      bestBy(cards, (c) => -(c.rank.value + (c.suit == trump ? 20 : 0)));

  PlayingCard _playMedium(FortyOneState s, int seat) {
    final mem = _Memory(s, seat);
    final trick = s.trick!;
    final trump = s.trump;
    final legal = FortyOneRules.playableCards(s.hands[seat], trick);
    final partner = (seat + 2) % 4;
    final iNeed = _need(s, seat) > 0;
    final partnerNeeds = _need(s, partner) > 0;
    if (trick.isEmpty) return _lead(s, mem, legal, iNeed: iNeed, partnerNeeds: partnerNeeds);
    final led = trick.ledSuit!;
    int pw(PlayingCard c) => FortyOneRules.power(c, led, trump);
    final winIdx = trick.winningIndex((c, l) => FortyOneRules.power(c, l, trump));
    final winCard = trick.cards[winIdx];
    final winSeat = trick.seats[winIdx];
    final after = [for (var i = trick.length + 1; i < 4; i++) (trick.leader + i) % 4];
    final oppsAfter = after.where((x) => x % 2 != seat % 2).toList();
    final beaters = legal.where((c) => pw(c) > pw(winCard)).toList();
    // A card that would win now and keep the trick.
    bool holds(PlayingCard c) {
      if (oppsAfter.isEmpty) return true;
      if (c.suit == trump) return mem.isMaster(c);
      return mem.isMaster(c) && !mem.mayRuff(led, oppsAfter);
    }

    final safeBeaters = beaters.where(holds).toList();
    final oppNeeds = [(seat + 1) % 4, (seat + 3) % 4].any((o) => _need(s, o) > 0);
    if (winSeat == partner) {
      final partnerHolds = oppsAfter.isEmpty || (winCard.suit == trump ? mem.isMaster(winCard) : holds(winCard));
      if (partnerNeeds && (partnerHolds || !(iNeed || oppNeeds) || safeBeaters.isEmpty)) {
        return _discard(mem, legal, trump);
      }
      if (iNeed && beaters.isNotEmpty) {
        return _lowest(safeBeaters.isNotEmpty ? safeBeaters : beaters, trump);
      }
      if (!partnerHolds && safeBeaters.isNotEmpty && oppNeeds) return _lowest(safeBeaters, trump);
      return _discard(mem, legal, trump);
    }
    // An opponent (or nobody on my side) is winning.
    final worthTaking = iNeed || _need(s, winSeat) > 0 || oppsAfter.any((o) => _need(s, o) > 0);
    if (beaters.isEmpty || !worthTaking) return _discard(mem, legal, trump);
    if (safeBeaters.isNotEmpty) return _lowest(safeBeaters, trump);
    // No sure winner: partner still to play may do better; else try high.
    final partnerAfter = after.contains(partner);
    if (partnerAfter && !iNeed) return _discard(mem, legal, trump);
    if (legal.first.suit != led) return _lowest(beaters, trump); // ruff low
    return bestBy(beaters, (c) => c.rank.value);
  }

  PlayingCard _discard(_Memory mem, List<PlayingCard> legal, Suit trump) {
    final side = legal.where((c) => c.suit != trump).toList();
    final pool = side.isNotEmpty ? side : legal;
    final nonMasters = pool.where((c) => !mem.isMaster(c)).toList();
    final from = nonMasters.isNotEmpty ? nonMasters : pool;
    // Lowest card, from the shortest suit on ties (to make voids).
    return bestBy(from, (c) => -(c.rank.value * 4 + from.where((x) => x.suit == c.suit).length));
  }

  PlayingCard _lead(
    FortyOneState s,
    _Memory mem,
    List<PlayingCard> legal, {
    required bool iNeed,
    required bool partnerNeeds,
  }) {
    final trump = s.trump;
    final seat = mem.seat;
    final opps = [(seat + 1) % 4, (seat + 3) % 4];
    final oppNeeds = opps.any((o) => _need(s, o) > 0);
    final trumps = legal.where((c) => c.suit == trump).toList();
    final sideMasters = legal
        .where((c) => c.suit != trump && mem.isMaster(c) && !mem.mayRuff(c.suit, opps) && mem.unseenIn(c.suit) > 0)
        .toList();
    if (iNeed || (oppNeeds && !partnerNeeds)) {
      final trumpMasters = trumps.where(mem.isMaster).toList();
      if (trumpMasters.isNotEmpty && mem.unseenIn(trump) > 0) return bestBy(trumpMasters, (c) => c.rank.value);
      if (sideMasters.isNotEmpty) return bestBy(sideMasters, (c) => c.rank.value);
      if (trumps.length >= 5 && trumps.length > mem.unseenIn(trump)) return _lowest(trumps, trump);
    }
    // Lead low from the longest side suit (a partner who needs tricks may
    // win it).
    final side = legal.where((c) => c.suit != trump).toList();
    if (side.isNotEmpty) {
      final longest = bestBy(Suit.values.where((x) => side.any((c) => c.suit == x)), (x) {
        return side.where((c) => c.suit == x).length;
      });
      return _lowest(side.where((c) => c.suit == longest), trump);
    }
    return _lowest(legal, trump);
  }

  PlayingCard _playEasy(FortyOneState s, int seat) {
    final trick = s.trick!;
    final trump = s.trump;
    final legal = FortyOneRules.playableCards(s.hands[seat], trick);
    final iNeed = _need(s, seat) > 0;
    if (trick.isEmpty) {
      return iNeed ? bestBy(legal, (c) => c.rank.value - (c.suit == trump ? 5 : 0)) : _lowest(legal, trump);
    }
    final led = trick.ledSuit!;
    final winIdx = trick.winningIndex((c, l) => FortyOneRules.power(c, l, trump));
    final best = FortyOneRules.power(trick.cards[winIdx], led, trump);
    final beaters = legal.where((c) => FortyOneRules.power(c, led, trump) > best);
    if (iNeed && beaters.isNotEmpty) return bestBy(beaters, (c) => c.rank.value);
    return _lowest(legal, trump);
  }

  // ------------------------------------------------------------ AI levels

  /// An easy player's random slips (see [easyMistakeRate]) are kept to the
  /// card play: a random bid of 2–13 would sink its own score for good and
  /// the match might never end.
  @override
  FortyOneMove chooseMove(FortyOneState state, int player, AiLevel level, math.Random rng, AiBudget budget) {
    if (level == AiLevel.easy && state.phase == FortyOnePhase.bidding && state.currentPlayer == player) {
      return _bidEasy(state, player, rules.legalMoves(state, player), rng);
    }
    return super.chooseMove(state, player, level, rng, budget);
  }

  @override
  FortyOneMove easyMove(FortyOneState s, int seat, List<FortyOneMove> legal, math.Random rng) =>
      s.phase == FortyOnePhase.bidding ? _bidEasy(s, seat, legal, rng) : FortyOneMove.play(_playEasy(s, seat));

  @override
  FortyOneMove mediumMove(FortyOneState s, int seat, List<FortyOneMove> legal, math.Random rng) =>
      s.phase == FortyOnePhase.bidding ? _bidMedium(s, seat, legal) : FortyOneMove.play(_playMedium(s, seat));

  /// In the auction only the heuristic bid and its neighbours (and, for the
  /// dealer, the bid that makes up the total) are compared.
  @override
  List<FortyOneMove> hardCandidates(FortyOneState s, int seat, List<FortyOneMove> legal, FortyOneMove prior) {
    if (s.phase != FortyOnePhase.bidding) return legal;
    final b = prior.amount!;
    final wanted = {b, b - 1, b + 1, if (seat == s.dealer) s.minTotalNow - s.bidTotal};
    return [
      prior,
      for (final m in legal)
        if (m != prior && wanted.contains(m.amount)) m,
    ];
  }

  /// Points of the observer's team minus the opponents' since [root], plus
  /// the match bonus.
  @override
  double evaluate(FortyOneState root, FortyOneState s, int observer) {
    double d(int seat) => (s.playerScores[seat] - root.playerScores[seat]).toDouble();
    final team = observer % 2;
    var v = d(team) + d(team + 2) - d(1 - team) - d(3 - team);
    if (s.isOver && !root.isOver) v += s.winners.contains(observer) ? matchWinBonus : -matchWinBonus;
    return v;
  }

  @override
  FortyOneState determinize(FortyOneState s, int observer, math.Random rng) {
    final w = s.copy()..rng = CardRng(rng.nextInt(0x7fffffff));
    final exposed = s.exposedCard;
    // (Whether it is still in the dealer's hand is public: it is unless played.)
    final pinned = exposed != null && observer != s.dealer && !s.playedCards.contains(exposed) ? exposed : null;
    final seen = <PlayingCard>{...s.hands[observer], ...s.playedCards, ?pinned};
    final pool = [
      for (final c in s.fullDeck())
        if (!seen.contains(c)) c,
    ];
    final others = [
      for (var i = 0; i < 4; i++)
        if (i != observer) i,
    ];
    final voids = voidsFromTricks([...s.tricks, if (s.trick != null) s.trick!], 4);
    final dealt = dealConstrained(
      pool,
      [for (final o in others) s.hands[o].length - (o == s.dealer && pinned != null ? 1 : 0)],
      (h, c) => !voids[others[h]].contains(c.suit),
      rng,
    );
    for (var i = 0; i < others.length; i++) {
      if (others[i] == s.dealer && pinned != null) dealt[i].add(pinned);
      w.hands[others[i]] = dealt[i]..sort();
    }
    return w;
  }
}

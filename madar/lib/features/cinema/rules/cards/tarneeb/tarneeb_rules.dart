/// Tarneeb (طرنيب) rules as commonly played in Jordan: auction 7–13, trump
/// chosen by the winning bidder, tricks, scoring to 31 (41, 61). See
/// RULES.md for every rule and option.
library;

import '../core/card_game.dart';
import '../core/playing_card.dart';
import '../core/trick.dart';
import 'tarneeb_state.dart';

class TarneebRules extends CardRules<TarneebState, TarneebMove> {
  const TarneebRules();

  static int power(PlayingCard card, Suit led, Suit? trump) => standardPower(card, led, trump);

  /// Cards of [hand] that may be played to [trick] (follow suit).
  static List<PlayingCard> playableCards(List<PlayingCard> hand, Trick? trick) {
    final led = trick?.ledSuit;
    if (led == null) return List.of(hand);
    final follow = hand.where((c) => c.suit == led).toList();
    return follow.isEmpty ? List.of(hand) : follow;
  }

  /// Cards [seat] may play now: follow suit, and with
  /// `firstLeadMustBeTrump` the opening lead of the deal is a trump when
  /// the leader holds one.
  static List<PlayingCard> playable(TarneebState s, int seat) {
    final hand = s.hands[seat];
    if (mustLeadTrump(s)) {
      final trumps = hand.where((c) => c.suit == s.trump).toList();
      if (trumps.isNotEmpty) return trumps;
    }
    return playableCards(hand, s.trick);
  }

  /// The opening lead of the deal, under `firstLeadMustBeTrump`.
  static bool mustLeadTrump(TarneebState s) =>
      s.options.firstLeadMustBeTrump &&
      s.phase == TarneebPhase.playing &&
      s.tricks.isEmpty &&
      (s.trick?.isEmpty ?? false);

  static bool dealerMustBid(TarneebState s) =>
      s.options.allPass == TarneebAllPass.dealerTakesMinimum && s.highBid == 0 && s.consecutivePasses == 3;

  /// A hand with no ace, no king in a suit of 2+ cards, no queen in a suit
  /// of 3+ and no jack in a suit of 4+ (option `worthlessHandRedeal`).
  static bool isWorthlessHand(List<PlayingCard> hand) {
    for (final suit in Suit.values) {
      final cards = ofSuit(hand, suit).toList();
      final len = cards.length;
      for (final c in cards) {
        if (c.rank == Rank.ace) return false;
        if (c.rank == Rank.king && len >= 2) return false;
        if (c.rank == Rank.queen && len >= 3) return false;
        if (c.rank == Rank.jack && len >= 4) return false;
      }
    }
    return true;
  }

  /// [seat] may throw its hand in now: a worthless hand, claimed before the
  /// first bid of the auction (earlier passes do not matter) and before the
  /// seat has spoken. A bid shows strength, so a claim after it would let a
  /// player cancel a deal the opponents are about to win.
  static bool canThrowIn(TarneebState s, int seat) =>
      s.options.worthlessHandRedeal &&
      s.phase == TarneebPhase.bidding &&
      s.highBidder < 0 &&
      !s.hasSpoken(seat) &&
      isWorthlessHand(s.hands[seat]);

  /// The lowest bid [seat] may make now. In the Lebanese one-round auction
  /// the dealer may equal the standing bid.
  static int lowestBid(TarneebState s, int seat) {
    final o = s.options;
    if (s.highBid == 0) return o.minBid;
    final equal = o.oneRoundAuction && seat == s.dealer;
    final lo = equal ? s.highBid : s.highBid + 1;
    return lo < o.minBid ? o.minBid : lo;
  }

  @override
  List<TarneebMove> legalMoves(TarneebState s, int seat) {
    if (s.isOver || s.turn != seat) return const [];
    switch (s.phase) {
      case TarneebPhase.bidding:
        return [
          if (!dealerMustBid(s)) const TarneebMove.pass(),
          for (var b = lowestBid(s, seat); b <= 13; b++) TarneebMove.bid(b),
          if (canThrowIn(s, seat)) const TarneebMove.throwIn(),
        ];
      case TarneebPhase.trump:
        return [for (final suit in Suit.values) TarneebMove.trump(suit)];
      case TarneebPhase.playing:
        return [for (final c in playable(s, seat)) TarneebMove.play(c)];
      case TarneebPhase.over:
        return const [];
    }
  }

  @override
  String? validate(TarneebState s, int seat, TarneebMove m) {
    final base = super.validate(s, seat, m);
    if (base == null || base != 'illegalMove') return base;
    if (m.kind == TarneebMoveKind.play && s.phase == TarneebPhase.playing) {
      if (!s.hands[seat].contains(m.card)) return 'cardNotInHand';
      if (mustLeadTrump(s)) return 'mustLeadTrump';
      return 'mustFollowSuit';
    }
    if (m.kind == TarneebMoveKind.bid && s.phase == TarneebPhase.bidding) {
      return (m.amount ?? 0) > 13 ? 'bidTooHigh' : 'bidTooLow';
    }
    if (m.kind == TarneebMoveKind.pass && s.phase == TarneebPhase.bidding) return 'dealerMustBid';
    if (m.kind == TarneebMoveKind.throwIn && s.phase == TarneebPhase.bidding) return 'cannotThrowIn';
    return 'wrongPhase';
  }

  @override
  TarneebMove moveFromJson(Map<String, Object?> json) => TarneebMove.fromJson(json);

  @override
  void apply(TarneebState s, TarneebMove m, [List<CardEvent>? ev]) {
    final seat = s.turn;
    switch (m.kind) {
      case TarneebMoveKind.bid:
        s.bids.add(TarneebBid(seat, m.amount!));
        s.highBid = m.amount!;
        s.highBidder = seat;
        s.consecutivePasses = 0;
        ev?.add(CardEvent(CardEventType.bid, seat: seat, value: m.amount));
        _advanceAuction(s, seat, ev);
      case TarneebMoveKind.pass:
        s.bids.add(TarneebBid(seat, 0));
        s.passed[seat] = true;
        s.consecutivePasses++;
        ev?.add(CardEvent(CardEventType.pass, seat: seat));
        _advanceAuction(s, seat, ev);
      case TarneebMoveKind.throwIn:
        // A worthless hand: nobody scores and the next dealer deals.
        ev?.add(CardEvent(CardEventType.redeal, seat: seat, cards: List.of(s.hands[seat]), detail: 'worthlessHand'));
        s.dealer = (s.dealer + 1) % 4;
        s.dealFromRng();
        ev?.add(CardEvent(CardEventType.dealt, seat: s.dealer));
      case TarneebMoveKind.trump:
        s.trump = m.suit;
        ev?.add(CardEvent(CardEventType.trumpChosen, seat: seat, suit: m.suit));
        _startPlay(s);
      case TarneebMoveKind.play:
        _play(s, seat, m.card!, ev);
    }
  }

  void _advanceAuction(TarneebState s, int speaker, List<CardEvent>? ev) {
    if (s.highBid == 13) return _endAuction(s, ev);
    if (s.options.oneRoundAuction) {
      // Everybody speaks once; the dealer speaks last.
      if (speaker != s.dealer) {
        s.turn = (speaker + 1) % 4;
        return;
      }
      return s.highBidder < 0 ? _allPassed(s, ev) : _endAuction(s, ev);
    }
    if (s.options.passIsFinal) {
      final active = [
        for (var i = 0; i < 4; i++)
          if (!s.passed[i]) i,
      ];
      if (s.highBidder >= 0 && active.length == 1) return _endAuction(s, ev);
      if (active.isEmpty) return _allPassed(s, ev);
      var next = (speaker + 1) % 4;
      while (s.passed[next]) {
        next = (next + 1) % 4;
      }
      s.turn = next;
    } else {
      if (s.highBidder >= 0 && s.consecutivePasses >= 3) return _endAuction(s, ev);
      if (s.highBidder < 0 && s.consecutivePasses >= 4) return _allPassed(s, ev);
      s.turn = (speaker + 1) % 4;
    }
  }

  void _endAuction(TarneebState s, List<CardEvent>? ev) {
    if (s.trump != null) {
      // Syrian trumps: already known from the exposed card.
      ev?.add(CardEvent(CardEventType.trumpChosen, seat: s.highBidder, suit: s.trump, detail: 'exposedCard'));
      _startPlay(s);
      return;
    }
    s.phase = TarneebPhase.trump;
    s.turn = s.highBidder;
  }

  void _startPlay(TarneebState s) {
    s.phase = TarneebPhase.playing;
    final leader = s.options.bidderLeads ? s.highBidder : (s.dealer + 1) % 4;
    s.trick = Trick(leader);
    s.turn = leader;
  }

  void _allPassed(TarneebState s, List<CardEvent>? ev) {
    ev?.add(const CardEvent(CardEventType.redeal, detail: 'allPassed'));
    // Jordan: the same dealer shuffles and deals again.
    if (s.options.allPass == TarneebAllPass.redealNextDealer) s.dealer = (s.dealer + 1) % 4;
    s.dealFromRng();
    ev?.add(CardEvent(CardEventType.dealt, seat: s.dealer));
  }

  void _play(TarneebState s, int seat, PlayingCard card, List<CardEvent>? ev) {
    s.hands[seat].remove(card);
    final trick = s.trick!..add(seat, card);
    ev?.add(CardEvent(CardEventType.cardPlayed, seat: seat, cards: [card]));
    if (trick.length < 4) {
      s.turn = (seat + 1) % 4;
      return;
    }
    final winner = trick.winner((c, led) => power(c, led, s.trump));
    s.tricksWon[winner % 2]++;
    s.tricks.add(trick);
    ev?.add(CardEvent(CardEventType.trickWon, seat: winner, cards: List.of(trick.cards)));
    if (s.tricks.length == 13) {
      s.trick = null;
      _scoreDeal(s, ev);
    } else {
      s.trick = Trick(winner);
      s.turn = winner;
    }
  }

  /// Points per team for a finished deal: `b` = [bid], `T` = the bidding
  /// team's tricks, `D = 13 − T`.
  ///
  /// | Case | Bidders | Defenders |
  /// |---|---|---|
  /// | b ≤ 12, made, T < 13 | +T (`madeScore`) | 0 (`defendersScoreWhenMade`: D) |
  /// | b ≤ 12, T = 13 | +`kabootScore` (16) | as above |
  /// | b ≤ 12, failed | −b | D (`failScore`) |
  /// | b = 13, made | +`kabootBidMadeScore` (26) | as above |
  /// | b = 13, failed | −`kabootBidFailPenalty` (16) | 2·D (`kabootFailDefenders`) |
  static List<int> dealPoints(TarneebOptions o, int bidder, int bid, List<int> tricks) {
    final bt = bidder % 2;
    final dt = 1 - bt;
    final taken = tricks[bt];
    final defenders = tricks[dt];
    final pts = [0, 0];
    final whenMade = o.defendersScoreWhenMade ? defenders : 0;
    if (bid == 13) {
      if (taken == 13) {
        pts[bt] = o.kabootBidMadeScore;
        pts[dt] = whenMade;
      } else {
        pts[bt] = -o.kabootBidFailPenalty;
        pts[dt] = switch (o.kabootFailDefenders) {
          TarneebKabootFail.doubled => 2 * defenders,
          TarneebKabootFail.single => defenders,
        };
      }
      return pts;
    }
    if (taken >= bid) {
      pts[bt] = taken == 13
          ? o.kabootScore
          : switch (o.madeScore) {
              TarneebMadeScore.tricksTaken => taken,
              TarneebMadeScore.bid => bid,
            };
      pts[dt] = whenMade;
    } else {
      pts[bt] = -bid;
      pts[dt] = switch (o.failScore) {
        TarneebFailScore.defendersTricks => defenders,
        TarneebFailScore.bid => bid,
        TarneebFailScore.nothing => 0,
      };
    }
    return pts;
  }

  /// The winning team after a scored deal, or null to play on: a team at the
  /// target wins (both → the higher total, an exact tie → [bidderTeam]); with
  /// `loseAtNegativeTarget` a team at or below minus the target loses.
  static int? matchWinner(TarneebOptions o, List<int> scores, int bidderTeam) {
    final target = o.targetScore;
    final a = scores[0];
    final b = scores[1];
    if (a >= target || b >= target) return a > b ? 0 : (b > a ? 1 : bidderTeam);
    if (o.loseAtNegativeTarget && (a <= -target || b <= -target)) {
      if (a <= -target && b <= -target) return a > b ? 0 : (b > a ? 1 : 1 - bidderTeam);
      return a <= -target ? 1 : 0;
    }
    return null;
  }

  void _scoreDeal(TarneebState s, List<CardEvent>? ev) {
    final pts = dealPoints(s.options, s.highBidder, s.highBid, s.tricksWon);
    final result = TarneebRoundResult(
      bidder: s.highBidder,
      bid: s.highBid,
      trump: s.trump!,
      tricks: List.of(s.tricksWon),
      points: pts,
    );
    s.results.add(result);
    s.roundNumber++;
    for (var t = 0; t < 2; t++) {
      s.teamScores[t] += pts[t];
    }
    ev?.add(CardEvent(CardEventType.roundScored, seat: s.highBidder, value: pts[s.highBidder % 2]));
    final winner = matchWinner(s.options, s.teamScores, s.highBidder % 2);
    if (winner != null) {
      s.winnerTeam = winner;
      s.phase = TarneebPhase.over;
      final reached = s.teamScores[winner] >= s.options.targetScore;
      ev?.add(CardEvent(CardEventType.matchOver, seat: winner, detail: reached ? 'target' : 'negativeTarget'));
      return;
    }
    s.dealer = (s.dealer + 1) % 4;
    s.dealFromRng();
    ev?.add(CardEvent(CardEventType.dealt, seat: s.dealer));
  }
}

class TarneebEngine extends RulesEngine<TarneebState, TarneebMove> {
  TarneebEngine(TarneebState state) : super(const TarneebRules(), state);

  factory TarneebEngine.newMatch({TarneebOptions options = const TarneebOptions(), required int seed}) =>
      TarneebEngine(TarneebState.newMatch(options: options, seed: seed));

  factory TarneebEngine.fromJson(Map<String, Object?> json) => TarneebEngine(TarneebState.fromJson(json));
}

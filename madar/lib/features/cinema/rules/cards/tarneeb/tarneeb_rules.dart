/// Tarneeb (طرنيب) rules: auction 7–13, trump chosen by the winning
/// bidder, tricks, scoring to 31 (or 41). See RULES.md.
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

  static bool dealerMustBid(TarneebState s) =>
      s.options.allPass == TarneebAllPass.dealerTakesMinimum && s.highBid == 0 && s.consecutivePasses == 3;

  @override
  List<TarneebMove> legalMoves(TarneebState s, int seat) {
    if (s.isOver || s.turn != seat) return const [];
    switch (s.phase) {
      case TarneebPhase.bidding:
        final lo = s.highBid + 1 > s.options.minBid ? s.highBid + 1 : s.options.minBid;
        return [if (!dealerMustBid(s)) const TarneebMove.pass(), for (var b = lo; b <= 13; b++) TarneebMove.bid(b)];
      case TarneebPhase.trump:
        return [for (final suit in Suit.values) TarneebMove.trump(suit)];
      case TarneebPhase.playing:
        return [for (final c in playableCards(s.hands[seat], s.trick)) TarneebMove.play(c)];
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
      return 'mustFollowSuit';
    }
    if (m.kind == TarneebMoveKind.bid && s.phase == TarneebPhase.bidding) return 'bidTooLow';
    if (m.kind == TarneebMoveKind.pass && s.phase == TarneebPhase.bidding) return 'dealerMustBid';
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
        _advanceAuction(s, ev);
      case TarneebMoveKind.pass:
        s.bids.add(TarneebBid(seat, 0));
        s.passed[seat] = true;
        s.consecutivePasses++;
        ev?.add(CardEvent(CardEventType.pass, seat: seat));
        _advanceAuction(s, ev);
      case TarneebMoveKind.trump:
        s.trump = m.suit;
        s.phase = TarneebPhase.playing;
        final leader = s.options.bidderLeads ? s.highBidder : (s.dealer + 1) % 4;
        s.trick = Trick(leader);
        s.turn = leader;
        ev?.add(CardEvent(CardEventType.trumpChosen, seat: seat, suit: m.suit));
      case TarneebMoveKind.play:
        _play(s, seat, m.card!, ev);
    }
  }

  void _advanceAuction(TarneebState s, List<CardEvent>? ev) {
    if (s.highBid == 13) return _endAuction(s);
    if (s.options.passIsFinal) {
      final active = [
        for (var i = 0; i < 4; i++)
          if (!s.passed[i]) i,
      ];
      if (s.highBidder >= 0 && active.length == 1) return _endAuction(s);
      if (active.isEmpty) return _allPassed(s, ev);
      var next = (s.turn + 1) % 4;
      while (s.passed[next]) {
        next = (next + 1) % 4;
      }
      s.turn = next;
    } else {
      if (s.highBidder >= 0 && s.consecutivePasses >= 3) return _endAuction(s);
      if (s.highBidder < 0 && s.consecutivePasses >= 4) return _allPassed(s, ev);
      s.turn = (s.turn + 1) % 4;
    }
  }

  void _endAuction(TarneebState s) {
    s.phase = TarneebPhase.trump;
    s.turn = s.highBidder;
  }

  void _allPassed(TarneebState s, List<CardEvent>? ev) {
    ev?.add(const CardEvent(CardEventType.redeal));
    s.dealer = (s.dealer + 1) % 4;
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

  /// Points per team for a finished deal.
  static List<int> dealPoints(TarneebOptions o, int bidder, int bid, List<int> tricks) {
    final bt = bidder % 2;
    final dt = 1 - bt;
    final pts = [0, 0];
    if (tricks[bt] >= bid) {
      pts[bt] = tricks[bt] == 13
          ? o.allTricksScore
          : switch (o.madeScore) {
              TarneebMadeScore.tricksTaken => tricks[bt],
              TarneebMadeScore.bid => bid,
            };
      if (o.defendersScoreWhenMade) pts[dt] = tricks[dt];
    } else {
      pts[bt] = -bid;
      pts[dt] = switch (o.failScore) {
        TarneebFailScore.defendersTricks => tricks[dt],
        TarneebFailScore.bid => bid,
        TarneebFailScore.nothing => 0,
      };
    }
    return pts;
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
    final target = s.options.targetScore;
    if (s.teamScores[0] >= target || s.teamScores[1] >= target) {
      final a = s.teamScores[0];
      final b = s.teamScores[1];
      s.winnerTeam = a > b ? 0 : (b > a ? 1 : s.highBidder % 2);
      s.phase = TarneebPhase.over;
      ev?.add(CardEvent(CardEventType.matchOver, seat: s.winnerTeam));
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

/// "41" (طلب فردي) rules: one bid each (no pass), follow suit, tricks per
/// player, bid values won or lost, a team wins when one partner reaches 41
/// while the other is above zero. See RULES.md.
library;

import '../core/card_game.dart';
import '../core/playing_card.dart';
import '../core/trick.dart';
import 'forty_one_state.dart';

class FortyOneRules extends CardRules<FortyOneState, FortyOneMove> {
  const FortyOneRules();

  static int power(PlayingCard card, Suit led, Suit trump) => standardPower(card, led, trump);

  /// Cards of [hand] that may be played to [trick] (follow suit).
  static List<PlayingCard> playableCards(List<PlayingCard> hand, Trick? trick) {
    final led = trick?.ledSuit;
    if (led == null) return List.of(hand);
    final follow = hand.where((c) => c.suit == led).toList();
    return follow.isEmpty ? List.of(hand) : follow;
  }

  @override
  List<FortyOneMove> legalMoves(FortyOneState s, int seat) {
    if (s.isOver || s.turn != seat) return const [];
    return switch (s.phase) {
      FortyOnePhase.bidding => [for (var b = s.minBidFor(seat); b <= 13; b++) FortyOneMove.bid(b)],
      FortyOnePhase.playing => [for (final c in playableCards(s.hands[seat], s.trick)) FortyOneMove.play(c)],
      FortyOnePhase.over => const [],
    };
  }

  @override
  String? validate(FortyOneState s, int seat, FortyOneMove m) {
    final base = super.validate(s, seat, m);
    if (base == null || base != 'illegalMove') return base;
    if (m.kind == FortyOneMoveKind.play && s.phase == FortyOnePhase.playing) {
      if (!s.hands[seat].contains(m.card)) return 'cardNotInHand';
      return 'mustFollowSuit';
    }
    if (m.kind == FortyOneMoveKind.bid && s.phase == FortyOnePhase.bidding) {
      // (A move decoded from a damaged save may have no amount.)
      return (m.amount ?? 0) > 13 ? 'bidTooHigh' : 'bidTooLow';
    }
    return 'wrongPhase';
  }

  @override
  FortyOneMove moveFromJson(Map<String, Object?> json) => FortyOneMove.fromJson(json);

  @override
  void apply(FortyOneState s, FortyOneMove m, [List<CardEvent>? ev]) {
    final seat = s.turn;
    switch (m.kind) {
      case FortyOneMoveKind.bid:
        s.bids[seat] = m.amount;
        ev?.add(CardEvent(CardEventType.bid, seat: seat, value: m.amount));
        if (seat != s.dealer) {
          s.turn = (seat + 1) % 4;
          return;
        }
        // The dealer spoke last: play, or throw in a low total.
        if (s.bidTotal < s.minTotalNow) return _throwIn(s, ev);
        _startPlay(s);
      case FortyOneMoveKind.play:
        _play(s, seat, m.card!, ev);
    }
  }

  void _throwIn(FortyOneState s, List<CardEvent>? ev) {
    ev?.add(CardEvent(CardEventType.redeal, value: s.bidTotal, detail: 'lowTotal'));
    if (s.options.throwInRedeal == FortyOneThrowIn.nextDealer) s.dealer = (s.dealer + 1) % 4;
    s.dealFromRng();
    ev?.add(CardEvent(CardEventType.dealt, seat: s.dealer));
  }

  /// The first leader of the deal.
  static int firstLeader(FortyOneState s) {
    if (s.options.firstLead == FortyOneFirstLead.dealerRight) return (s.dealer + 1) % 4;
    var best = (s.dealer + 1) % 4;
    for (var i = 1; i < 4; i++) {
      final seat = (s.dealer + 1 + i) % 4;
      if (s.bids[seat]! > s.bids[best]!) best = seat;
    }
    return best;
  }

  void _startPlay(FortyOneState s) {
    s.phase = FortyOnePhase.playing;
    final leader = firstLeader(s);
    s.trick = Trick(leader);
    s.turn = leader;
  }

  void _play(FortyOneState s, int seat, PlayingCard card, List<CardEvent>? ev) {
    s.hands[seat].remove(card);
    final trick = s.trick!..add(seat, card);
    ev?.add(CardEvent(CardEventType.cardPlayed, seat: seat, cards: [card]));
    if (trick.length < 4) {
      s.turn = (seat + 1) % 4;
      return;
    }
    final winner = trick.winner((c, led) => power(c, led, s.trump));
    s.tricksWon[winner]++;
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

  /// Points per seat: +value(bid) when a seat took at least its bid
  /// (overtricks are worth nothing), else −value(bid). Values are read with
  /// each seat's score at the start of the deal ([scoresBefore]).
  static List<int> dealPoints(FortyOneOptions o, List<int> bids, List<int> tricks, List<int> scoresBefore) => [
    for (var seat = 0; seat < 4; seat++)
      (tricks[seat] >= bids[seat] ? 1 : -1) * o.value(bids[seat], scoresBefore[seat]),
  ];

  /// [team] qualifies: one partner at the target, the other positive (or,
  /// with `nonNegative`, at least zero).
  static bool qualifies(FortyOneOptions o, List<int> scores, int team) {
    bool partnerOk(int v) => o.partnerRule == FortyOnePartnerRule.positive ? v > 0 : v >= 0;
    final a = scores[team];
    final b = scores[team + 2];
    return (a >= o.target && partnerOk(b)) || (b >= o.target && partnerOk(a));
  }

  /// The winning team after a scored deal, or null to play on.
  static int? matchWinner(FortyOneOptions o, List<int> scores) {
    final q0 = qualifies(o, scores, 0);
    final q1 = qualifies(o, scores, 1);
    if (q0 != q1) return q0 ? 0 : 1;
    if (!q0) return null;
    // Both teams qualify after the same deal.
    final total = [scores[0] + scores[2], scores[1] + scores[3]];
    final best = [scores[0] > scores[2] ? scores[0] : scores[2], scores[1] > scores[3] ? scores[1] : scores[3]];
    final order = o.bothQualify == FortyOneBothQualify.higherTeamTotal ? [total, best] : [best, total];
    for (final k in order) {
      if (k[0] != k[1]) return k[0] > k[1] ? 0 : 1;
    }
    return null; // Still level: another deal.
  }

  void _scoreDeal(FortyOneState s, List<CardEvent>? ev) {
    final bids = [for (final b in s.bids) b!];
    final pts = dealPoints(s.options, bids, s.tricksWon, s.playerScores);
    s.results.add(
      FortyOneRoundResult(dealer: s.dealer, trump: s.trump, bids: bids, tricks: List.of(s.tricksWon), points: pts),
    );
    s.roundNumber++;
    for (var seat = 0; seat < 4; seat++) {
      s.playerScores[seat] += pts[seat];
      ev?.add(CardEvent(CardEventType.roundScored, seat: seat, value: pts[seat]));
    }
    int? winner;
    var reason = 'target';
    if (s.options.bid13WinsMatch) {
      for (var seat = 0; seat < 4; seat++) {
        if (bids[seat] == 13 && s.tricksWon[seat] == 13) {
          winner = seat % 2;
          reason = 'bid13';
        }
      }
    }
    winner ??= matchWinner(s.options, s.playerScores);
    if (winner != null) {
      s.winnerTeam = winner;
      s.phase = FortyOnePhase.over;
      ev?.add(CardEvent(CardEventType.matchOver, seat: winner, detail: reason));
      return;
    }
    s.dealer = (s.dealer + 1) % 4;
    s.dealFromRng();
    ev?.add(CardEvent(CardEventType.dealt, seat: s.dealer));
  }
}

class FortyOneEngine extends RulesEngine<FortyOneState, FortyOneMove> {
  FortyOneEngine(FortyOneState state) : super(const FortyOneRules(), state);

  factory FortyOneEngine.newMatch({FortyOneOptions options = const FortyOneOptions(), required int seed}) =>
      FortyOneEngine(FortyOneState.newMatch(options: options, seed: seed));

  factory FortyOneEngine.fromJson(Map<String, Object?> json) => FortyOneEngine(FortyOneState.fromJson(json));
}

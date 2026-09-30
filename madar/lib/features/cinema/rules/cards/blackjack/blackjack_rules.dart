/// Blackjack 21 (بلاك جاك ٢١) rules: the shoe, the deal and peek, the
/// player actions, the dealer's fixed play and the points tally. See
/// RULES.md.
library;

import 'dart:math' as math;

import '../core/card_game.dart';
import '../core/playing_card.dart';
import 'blackjack_state.dart';
import 'blackjack_strategy.dart';

/// Everything the table can animate. Each one is sent as a [BlackjackEvent].
enum BlackjackEventKind {
  /// Every card went back into the shoe; [BlackjackEvent.reason] is
  /// `cutCard`, `continuous` or `emergency` (B-2, B-4, B-5).
  shoeShuffled,

  /// One card went face down to the discards (B-3).
  cardBurned,

  /// A round was dealt (B-21).
  dealt,

  /// The dealer checked the hole card; `value` is 1 when it made a natural.
  dealerPeeked,

  /// The hole card was turned up.
  holeRevealed,

  /// The dealer took a card.
  dealerDrew,

  /// A split hand received its second card (B-37).
  cardToHand,
  hit,
  stood,
  handDoubled,
  split,
  surrendered,
  bust,

  /// A natural (B-12), shown as soon as it is dealt.
  blackjack,

  /// A hand's result: [BlackjackEvent.outcome], `value` = its points.
  handSettled,

  /// European table with `originalOnly`: a dealer natural takes one base
  /// result (−2) from the seat in all (B-25, B-61g). `value` = the points
  /// given back to the seat after its `handSettled` events (always > 0), so
  /// the seat's events add up to its round points.
  lossCapped,

  /// The round is over; the summary is `state.lastRound`.
  roundScored,
  sessionOver,

  /// Coach mode: the last decision differed from the chart;
  /// [BlackjackEvent.action] is the chart's choice (B-75).
  adviceGiven,
}

/// The shared event type used for [kind]: the value of the same name once
/// `CardEventType` has one, else the nearest generic type.
CardEventType blackjackEventType(BlackjackEventKind kind) {
  for (final t in CardEventType.values) {
    if (t.name == kind.name) return t;
  }
  return switch (kind) {
    BlackjackEventKind.dealt => CardEventType.dealt,
    BlackjackEventKind.shoeShuffled => CardEventType.redeal,
    BlackjackEventKind.cardBurned => CardEventType.discarded,
    BlackjackEventKind.hit ||
    BlackjackEventKind.dealerDrew ||
    BlackjackEventKind.cardToHand ||
    BlackjackEventKind.handDoubled => CardEventType.drewStock,
    BlackjackEventKind.roundScored => CardEventType.roundScored,
    BlackjackEventKind.sessionOver => CardEventType.matchOver,
    _ => CardEventType.cardPlayed,
  };
}

/// A [CardEvent] with the Blackjack details. [detail] is always the name of
/// [kind].
class BlackjackEvent extends CardEvent {
  BlackjackEvent(this.kind, {super.seat, this.hand, super.cards, super.value, this.outcome, this.action, this.reason})
    : super(blackjackEventType(kind), detail: kind.name);

  final BlackjackEventKind kind;

  /// Index of the seat's hand (after splits), when it concerns one hand.
  final int? hand;
  final BlackjackOutcome? outcome;
  final BlackjackAction? action;
  final String? reason;

  @override
  String toString() =>
      'BlackjackEvent(${kind.name}, seat: $seat, hand: $hand, cards: $cards, value: $value'
      '${outcome == null ? '' : ', ${outcome!.name}'}${action == null ? '' : ', ${action!.name}'}'
      '${reason == null ? '' : ', $reason'})';
}

class BlackjackRules extends CardRules<BlackjackState, BlackjackMove> {
  const BlackjackRules();

  @override
  List<BlackjackMove> legalMoves(BlackjackState s, int seat) {
    switch (s.phase) {
      case BlackjackPhase.over:
        return const [];
      case BlackjackPhase.betweenRounds:
        if (seat != 0) return const [];
        return [BlackjackMove.deal, if (s.options.sessionRounds == null) BlackjackMove.endSession];
      case BlackjackPhase.playerTurn:
        if (seat != s.turn) return const [];
        return [
          if (s.canHit) BlackjackMove.hit,
          BlackjackMove.stand,
          if (s.canDouble) BlackjackMove.doubleHand,
          if (s.canSplit) BlackjackMove.split,
          if (s.canSurrender) BlackjackMove.surrender,
        ];
    }
  }

  @override
  String? validate(BlackjackState s, int seat, BlackjackMove m) {
    final base = super.validate(s, seat, m);
    if (base != 'illegalMove') return base;
    final inRound = s.phase == BlackjackPhase.playerTurn;
    return switch (m.action) {
      BlackjackAction.deal => 'roundInProgress',
      BlackjackAction.endSession => inRound ? 'roundInProgress' : 'sessionHasRounds',
      _ when !inRound => 'noRoundInProgress',
      BlackjackAction.hit => 'cannotHit',
      BlackjackAction.double => 'cannotDouble',
      BlackjackAction.split => 'cannotSplit',
      BlackjackAction.surrender => 'cannotSurrender',
      BlackjackAction.stand => 'illegalMove',
    };
  }

  @override
  BlackjackMove moveFromJson(Map<String, Object?> json) => BlackjackMove.fromJson(json);

  @override
  void apply(BlackjackState s, BlackjackMove m, [List<CardEvent>? ev]) {
    switch (m.action) {
      case BlackjackAction.deal:
        _deal(s, ev);
      case BlackjackAction.endSession:
        s.phase = BlackjackPhase.over;
        ev?.add(BlackjackEvent(BlackjackEventKind.sessionOver));
      case BlackjackAction.hit:
      case BlackjackAction.stand:
      case BlackjackAction.double:
      case BlackjackAction.split:
      case BlackjackAction.surrender:
        _decide(s, m.action, ev);
    }
  }

  // ---------------------------------------------------------------------------
  // The shoe.

  static void _shuffleAll(BlackjackState s, String reason, List<CardEvent>? ev) {
    s.shoe = [...s.shoe, ...s.discards];
    s.discards = [];
    s.rng.shuffle(s.shoe);
    ev?.add(BlackjackEvent(BlackjackEventKind.shoeShuffled, reason: reason));
  }

  /// The next card; an empty shoe is refilled from the discards (never the
  /// cards on the table) without a burn. Null when no card exists (B-5).
  static PlayingCard? _draw(BlackjackState s, List<CardEvent>? ev) {
    if (s.shoe.isEmpty) {
      if (s.discards.isEmpty) return null;
      s.shoe = s.discards;
      s.discards = [];
      s.rng.shuffle(s.shoe);
      ev?.add(BlackjackEvent(BlackjackEventKind.shoeShuffled, reason: 'emergency'));
    }
    return s.shoe.removeLast();
  }

  // ---------------------------------------------------------------------------
  // The deal (B-20…B-24).

  void _deal(BlackjackState s, List<CardEvent>? ev) {
    final o = s.options;
    for (final seat in s.seats) {
      for (final h in seat.hands) {
        s.discards.addAll(h.cards);
      }
      seat.hands = [BlackjackHand()];
    }
    s.discards.addAll(s.dealer);
    s.dealer = [];
    s.holeHidden = false;
    if (o.continuousShuffle) {
      _shuffleAll(s, 'continuous', ev);
    } else if (s.shoe.length < o.reshuffleBelow) {
      _shuffleAll(s, 'cutCard', ev);
      if (o.burnCard && s.shoe.isNotEmpty) {
        s.discards.add(s.shoe.removeLast());
        ev?.add(BlackjackEvent(BlackjackEventKind.cardBurned));
      }
    }
    for (var round = 0; round < 2; round++) {
      for (final seat in s.seats) {
        final c = _draw(s, ev);
        if (c != null) seat.hands.first.cards.add(c);
      }
      if (round == 0 || !o.european) {
        final c = _draw(s, ev);
        if (c != null) s.dealer.add(c);
      }
    }
    s.holeHidden = !o.european && s.dealer.length == 2;
    s.dealNumber++;
    s.phase = BlackjackPhase.playerTurn;
    s.turn = 0;
    s.handIndex = 0;
    ev?.add(BlackjackEvent(BlackjackEventKind.dealt, cards: s.dealerVisible));

    final upValue = s.dealer.isEmpty ? 0 : blackjackCardValue(s.dealer.first);
    final tenOrAce = upValue == 1 || upValue == 10;
    if (!o.european && tenOrAce) {
      final dealerNatural = isTwoCardTwentyOne(s.dealer);
      ev?.add(BlackjackEvent(BlackjackEventKind.dealerPeeked, value: dealerNatural ? 1 : 0));
      if (dealerNatural) {
        _reveal(s, ev);
        for (var i = 0; i < s.seats.length; i++) {
          final h = s.seats[i].hands.first;
          h.done = true;
          if (h.natural) ev?.add(BlackjackEvent(BlackjackEventKind.blackjack, seat: i, hand: 0));
          _settle(s, i, 0, h.natural ? BlackjackOutcome.push : BlackjackOutcome.loss, ev);
        }
        _finishRound(s, dealerNatural: true, ev: ev);
        return;
      }
    }
    for (var i = 0; i < s.seats.length; i++) {
      final h = s.seats[i].hands.first;
      if (!h.natural) continue;
      h.done = true;
      ev?.add(BlackjackEvent(BlackjackEventKind.blackjack, seat: i, hand: 0));
      // On the European table a natural against an ace or a 10 waits for
      // the dealer's second card (B-24).
      if (!(o.european && tenOrAce)) _settle(s, i, 0, BlackjackOutcome.blackjack, ev);
    }
    _advance(s, ev);
  }

  // ---------------------------------------------------------------------------
  // Player decisions (B-30…B-40).

  void _decide(BlackjackState s, BlackjackAction action, List<CardEvent>? ev) {
    final o = s.options;
    final seatIndex = s.turn;
    final seat = s.seats[seatIndex];
    final h = seat.hands[s.handIndex];
    final advice = BlackjackStrategy.advise(s);
    if (advice != null) {
      seat.decisions++;
      if (advice.action == action) {
        seat.decisionsMatched++;
      } else if (o.advisor == BlackjackAdvisor.coach) {
        ev?.add(BlackjackEvent(BlackjackEventKind.adviceGiven, seat: seatIndex, hand: s.handIndex, action: advice.action));
      }
    }
    switch (action) {
      case BlackjackAction.hit:
        final c = _draw(s, ev);
        if (c == null) {
          h.done = true;
          ev?.add(BlackjackEvent(BlackjackEventKind.stood, seat: seatIndex, hand: s.handIndex, reason: 'noCards'));
          break;
        }
        h.cards.add(c);
        ev?.add(BlackjackEvent(BlackjackEventKind.hit, seat: seatIndex, hand: s.handIndex, cards: [c]));
        if (h.bust) {
          _bust(s, ev);
        } else if (h.total == 21 && o.autoStandOn21) {
          h.done = true;
          ev?.add(BlackjackEvent(BlackjackEventKind.stood, seat: seatIndex, hand: s.handIndex, reason: 'twentyOne'));
        }
      case BlackjackAction.stand:
        h.done = true;
        ev?.add(BlackjackEvent(BlackjackEventKind.stood, seat: seatIndex, hand: s.handIndex));
      case BlackjackAction.double:
        h.doubled = true;
        h.done = true;
        final c = _draw(s, ev);
        if (c != null) h.cards.add(c);
        ev?.add(
          BlackjackEvent(
            BlackjackEventKind.handDoubled,
            seat: seatIndex,
            hand: s.handIndex,
            cards: [?c],
            reason: c == null ? 'noCards' : null,
          ),
        );
        if (h.bust) _bust(s, ev);
      case BlackjackAction.split:
        final a = h.cards[0];
        final b = h.cards[1];
        final aces = blackjackCardValue(a) == 1;
        h
          ..cards = [a]
          ..fromSplit = true
          ..splitAces = aces;
        seat.hands.insert(s.handIndex + 1, BlackjackHand(cards: [b], fromSplit: true, splitAces: aces));
        seat.splits++;
        ev?.add(BlackjackEvent(BlackjackEventKind.split, seat: seatIndex, hand: s.handIndex, cards: [a, b]));
        _prepare(s, ev);
      case BlackjackAction.surrender:
        h
          ..surrendered = true
          ..done = true;
        ev?.add(BlackjackEvent(BlackjackEventKind.surrendered, seat: seatIndex, hand: s.handIndex));
        _settle(s, seatIndex, s.handIndex, BlackjackOutcome.surrendered, ev);
      case BlackjackAction.deal:
      case BlackjackAction.endSession:
        throw StateError('not a hand decision');
    }
    if (h.done) _advance(s, ev);
  }

  void _bust(BlackjackState s, List<CardEvent>? ev) {
    final h = s.seats[s.turn].hands[s.handIndex];
    h.done = true;
    ev?.add(BlackjackEvent(BlackjackEventKind.bust, seat: s.turn, hand: s.handIndex, value: h.total));
    // A busted hand loses at once, even if the dealer busts later (B-13).
    _settle(s, s.turn, s.handIndex, BlackjackOutcome.loss, ev);
  }

  /// Gives the active hand its second card after a split and applies the
  /// automatic stands (split aces, 21).
  void _prepare(BlackjackState s, List<CardEvent>? ev) {
    final o = s.options;
    final h = s.seats[s.turn].hands[s.handIndex];
    if (h.done) return;
    if (h.fromSplit && h.cards.length == 1) {
      final c = _draw(s, ev);
      if (c == null) {
        h.done = true;
        ev?.add(BlackjackEvent(BlackjackEventKind.stood, seat: s.turn, hand: s.handIndex, reason: 'noCards'));
        return;
      }
      h.cards.add(c);
      ev?.add(BlackjackEvent(BlackjackEventKind.cardToHand, seat: s.turn, hand: s.handIndex, cards: [c]));
      if (h.splitAces && !o.hitSplitAces && !s.canSplit) {
        // One card each on split aces (B-38).
        h.done = true;
        ev?.add(BlackjackEvent(BlackjackEventKind.stood, seat: s.turn, hand: s.handIndex, reason: 'splitAces'));
        return;
      }
    }
    if (h.total == 21 && o.autoStandOn21) {
      h.done = true;
      ev?.add(BlackjackEvent(BlackjackEventKind.stood, seat: s.turn, hand: s.handIndex, reason: 'twentyOne'));
    }
  }

  /// Moves to the next hand that needs a decision, or plays the dealer.
  void _advance(BlackjackState s, List<CardEvent>? ev) {
    while (true) {
      if (s.turn >= s.seats.length) {
        _dealerAndSettle(s, ev);
        return;
      }
      final seat = s.seats[s.turn];
      if (s.handIndex >= seat.hands.length) {
        s.turn++;
        s.handIndex = 0;
        continue;
      }
      if (!seat.hands[s.handIndex].done) {
        _prepare(s, ev);
        if (!seat.hands[s.handIndex].done) return;
      }
      s.handIndex++;
    }
  }

  // ---------------------------------------------------------------------------
  // The dealer and the settlement (B-50…B-61).

  void _reveal(BlackjackState s, List<CardEvent>? ev) {
    if (!s.holeHidden) return;
    s.holeHidden = false;
    ev?.add(BlackjackEvent(BlackjackEventKind.holeRevealed, cards: [s.dealer[1]]));
  }

  /// Whether the dealer must take another card (B-51, B-52).
  static bool dealerHits(List<PlayingCard> cards, BlackjackOptions o) {
    final t = blackjackTotal(cards);
    return t.total < 17 || (t.total == 17 && t.soft && o.dealerHitsSoft17);
  }

  void _dealerAndSettle(BlackjackState s, List<CardEvent>? ev) {
    final o = s.options;
    final open = [
      for (final seat in s.seats)
        for (final h in seat.hands)
          if (!h.settled) h,
    ];
    final live = open.any((h) => !h.natural);
    final waitingNatural = open.any((h) => h.natural);
    _reveal(s, ev);
    if (o.european && (live || waitingNatural)) {
      final c = _draw(s, ev);
      if (c != null) {
        s.dealer.add(c);
        ev?.add(BlackjackEvent(BlackjackEventKind.dealerDrew, cards: [c]));
      }
    }
    final dealerNatural = isTwoCardTwentyOne(s.dealer);
    if (live && !dealerNatural) {
      while (dealerHits(s.dealer, o)) {
        final c = _draw(s, ev);
        if (c == null) break;
        s.dealer.add(c);
        ev?.add(BlackjackEvent(BlackjackEventKind.dealerDrew, cards: [c]));
      }
    }
    final dealerTotal = blackjackTotal(s.dealer).total;
    for (var i = 0; i < s.seats.length; i++) {
      final hands = s.seats[i].hands;
      for (var j = 0; j < hands.length; j++) {
        final h = hands[j];
        if (h.settled) continue;
        final BlackjackOutcome outcome;
        if (h.natural) {
          outcome = dealerNatural ? BlackjackOutcome.push : BlackjackOutcome.blackjack;
        } else if (dealerNatural || h.bust) {
          outcome = BlackjackOutcome.loss;
        } else if (dealerTotal > 21 || h.total > dealerTotal) {
          outcome = BlackjackOutcome.win;
        } else {
          outcome = h.total == dealerTotal ? BlackjackOutcome.push : BlackjackOutcome.loss;
        }
        _settle(s, i, j, outcome, ev);
      }
    }
    _finishRound(s, dealerNatural: dealerNatural, ev: ev);
  }

  /// Net points of a settled hand (B-60, B-61), before the tally rule.
  static int netPoints(BlackjackHand h, BlackjackOptions o) => switch (h.outcome!) {
    BlackjackOutcome.blackjack => o.blackjackBonus,
    BlackjackOutcome.win => h.doubled ? 4 : 2,
    BlackjackOutcome.push => 0,
    BlackjackOutcome.loss => h.doubled ? -4 : -2,
    BlackjackOutcome.surrendered => -1,
  };

  static int _tallied(int net, BlackjackOptions o) => o.tally == BlackjackTally.winsOnly ? math.max(0, net) : net;

  void _settle(BlackjackState s, int seat, int hand, BlackjackOutcome outcome, List<CardEvent>? ev) {
    final h = s.seats[seat].hands[hand];
    h.outcome = outcome;
    h.done = true;
    h.points = _tallied(netPoints(h, s.options), s.options);
    ev?.add(BlackjackEvent(BlackjackEventKind.handSettled, seat: seat, hand: hand, outcome: outcome, value: h.points));
  }

  void _finishRound(BlackjackState s, {required bool dealerNatural, List<CardEvent>? ev}) {
    final o = s.options;
    final seatPoints = <int>[];
    for (var i = 0; i < s.seats.length; i++) {
      final seat = s.seats[i];
      final nets = [for (final h in seat.hands) netPoints(h, o)];
      if (dealerNatural && o.originalOnlyApplies) {
        // The seat loses one base result in all, whatever it split or
        // doubled; a natural pushes (B-25, B-61g). The first hand carries
        // the seat's result; `lossCapped` gives back what the hands'
        // `handSettled` events took beyond it.
        final shown = seat.hands.fold<int>(0, (n, h) => n + h.points);
        final seatNet = seat.hands.any((h) => h.natural) ? 0 : -2;
        for (var j = 0; j < nets.length; j++) {
          nets[j] = j == 0 ? seatNet : 0;
          seat.hands[j].points = _tallied(nets[j], o);
        }
        final givenBack = seat.hands.fold<int>(0, (n, h) => n + h.points) - shown;
        if (givenBack != 0) ev?.add(BlackjackEvent(BlackjackEventKind.lossCapped, seat: i, value: givenBack));
      }
      var net = 0;
      var tallied = 0;
      for (var j = 0; j < seat.hands.length; j++) {
        final h = seat.hands[j];
        net += nets[j];
        tallied += h.points;
        switch (h.outcome!) {
          case BlackjackOutcome.blackjack:
          case BlackjackOutcome.win:
            seat.handsWon++;
            if (h.doubled) seat.doublesWon++;
          case BlackjackOutcome.push:
            seat.handsPushed++;
          case BlackjackOutcome.loss:
          case BlackjackOutcome.surrendered:
            seat.handsLost++;
        }
        if (h.natural) seat.blackjacks++;
        if (h.bust) seat.busts++;
      }
      seat.points += tallied;
      seatPoints.add(tallied);
      // Streaks follow the net result, so they mean the same under both
      // tallies (B-63).
      if (net > 0) {
        seat.streak++;
        seat.bestStreak = math.max(seat.bestStreak, seat.streak);
      } else if (net < 0) {
        seat.streak = 0;
      }
    }
    s.roundsPlayed++;
    final dealerTotal = blackjackTotal(s.dealer).total;
    s.lastRound = BlackjackRoundSummary(
      round: s.roundsPlayed,
      seatPoints: seatPoints,
      dealerTotal: dealerTotal,
      dealerBlackjack: dealerNatural,
      dealerBust: dealerTotal > 21,
    );
    s.turn = 0;
    s.handIndex = 0;
    ev?.add(BlackjackEvent(BlackjackEventKind.roundScored, value: s.roundsPlayed));
    final limit = o.sessionRounds;
    if (limit != null && s.roundsPlayed >= limit) {
      s.phase = BlackjackPhase.over;
      ev?.add(BlackjackEvent(BlackjackEventKind.sessionOver));
    } else {
      s.phase = BlackjackPhase.betweenRounds;
    }
  }
}

class BlackjackEngine extends RulesEngine<BlackjackState, BlackjackMove> {
  BlackjackEngine(BlackjackState state) : super(const BlackjackRules(), state);

  factory BlackjackEngine.newMatch({BlackjackOptions options = const BlackjackOptions(), required int seed}) =>
      BlackjackEngine(BlackjackState.newMatch(options: options, seed: seed));

  factory BlackjackEngine.fromJson(Map<String, Object?> json) => BlackjackEngine(BlackjackState.fromJson(json));

  /// The hint button (B-75): the chart's action for the hand being played,
  /// or null between rounds.
  BlackjackAdvice? advice() => BlackjackStrategy.advise(state);
}

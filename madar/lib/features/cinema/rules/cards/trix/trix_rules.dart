/// Trix (تركس) rules: four kingdoms, the owner of each choosing the order of
/// its contracts (king of hearts, queens, diamonds, ltoush, trix – or complex
/// and trix). See RULES.md.
library;

import '../core/card_game.dart';
import '../core/playing_card.dart';
import '../core/trick.dart';
import 'trix_state.dart';

final PlayingCard kingOfHearts = PlayingCard(Suit.hearts, Rank.king);

class TrixRules extends CardRules<TrixState, TrixMove> {
  const TrixRules();

  static bool hasKing(TrixContract? c) => c == TrixContract.king || c == TrixContract.complex;
  static bool hasQueens(TrixContract? c) => c == TrixContract.queens || c == TrixContract.complex;
  static bool hasDiamonds(TrixContract? c) => c == TrixContract.diamonds || c == TrixContract.complex;
  static bool hasTricks(TrixContract? c) => c == TrixContract.ltoush || c == TrixContract.complex;

  /// Cards [seat] could double in the current contract.
  static List<PlayingCard> doublable(TrixState s, int seat) => [
    for (final c in s.hands[seat])
      if ((hasKing(s.contract) && c == kingOfHearts) || (hasQueens(s.contract) && c.rank == Rank.queen)) c,
  ];

  static List<List<PlayingCard>> _subsets(List<PlayingCard> cards) {
    final out = <List<PlayingCard>>[];
    for (var mask = 0; mask < 1 << cards.length; mask++) {
      out.add([
        for (var i = 0; i < cards.length; i++)
          if (mask & (1 << i) != 0) cards[i],
      ]);
    }
    return out;
  }

  /// Cards of [hand] playable to the current trick.
  static List<PlayingCard> trickPlayable(TrixState s, List<PlayingCard> hand) {
    final led = s.trick!.ledSuit;
    if (led == null) {
      if (hasKing(s.contract) && s.options.noHeartLeadInKing) {
        final other = hand.where((c) => c.suit != Suit.hearts).toList();
        if (other.isNotEmpty) return other;
      }
      return List.of(hand);
    }
    final follow = hand.where((c) => c.suit == led).toList();
    if (follow.isNotEmpty) return follow;
    if (hasKing(s.contract) && s.options.kingMustBeDiscarded && hand.contains(kingOfHearts)) return [kingOfHearts];
    return List.of(hand);
  }

  /// The cards that may go on the trix layout right now.
  static List<PlayingCard> layoutOpenings(TrixState s) {
    final out = <PlayingCard>[];
    for (final suit in Suit.values) {
      final lo = s.layoutLow[suit.index];
      final hi = s.layoutHigh[suit.index];
      if (lo == 0) {
        out.add(PlayingCard(suit, Rank.jack));
        continue;
      }
      if (lo > 2) out.add(PlayingCard(suit, Rank.fromValue(lo - 1)));
      if (hi < 14) out.add(PlayingCard(suit, Rank.fromValue(hi + 1)));
    }
    return out;
  }

  static List<PlayingCard> layoutPlayable(TrixState s, List<PlayingCard> hand) {
    final open = layoutOpenings(s).toSet();
    return hand.where(open.contains).toList();
  }

  @override
  List<TrixMove> legalMoves(TrixState s, int seat) {
    if (s.isOver || s.turn != seat) return const [];
    switch (s.phase) {
      case TrixPhase.contract:
        return [
          for (final c in s.options.contracts)
            if (!s.used.contains(c)) TrixMove.contract(c),
        ];
      case TrixPhase.doubling:
        return [for (final sub in _subsets(doublable(s, seat))) TrixMove.double(sub)];
      case TrixPhase.tricks:
        return [for (final c in trickPlayable(s, s.hands[seat])) TrixMove.play(c)];
      case TrixPhase.layout:
        final cards = layoutPlayable(s, s.hands[seat]);
        return cards.isEmpty ? const [TrixMove.pass()] : [for (final c in cards) TrixMove.play(c)];
      case TrixPhase.over:
        return const [];
    }
  }

  @override
  String? validate(TrixState s, int seat, TrixMove m) {
    final base = super.validate(s, seat, m);
    if (base != 'illegalMove') return base;
    if (m.kind == TrixMoveKind.play && (s.phase == TrixPhase.tricks || s.phase == TrixPhase.layout)) {
      if (!s.hands[seat].contains(m.card)) return 'cardNotInHand';
      if (s.phase == TrixPhase.layout) return 'notPlayableOnLayout';
      final led = s.trick!.ledSuit;
      if (led == null) return 'noHeartLead';
      if (s.hands[seat].any((c) => c.suit == led)) return 'mustFollowSuit';
      return 'mustDiscardKing';
    }
    if (m.kind == TrixMoveKind.pass && s.phase == TrixPhase.layout) return 'mustPlayWhenAble';
    if (m.kind == TrixMoveKind.contract && s.phase == TrixPhase.contract) return 'contractAlreadyPlayed';
    return 'wrongPhase';
  }

  @override
  TrixMove moveFromJson(Map<String, Object?> json) => TrixMove.fromJson(json);

  @override
  void apply(TrixState s, TrixMove m, [List<CardEvent>? ev]) {
    final seat = s.turn;
    switch (m.kind) {
      case TrixMoveKind.contract:
        final c = m.contract!;
        s.contract = c;
        s.used.add(c);
        ev?.add(CardEvent(CardEventType.contractChosen, seat: seat, detail: c.name));
        if (s.options.doubling && (hasKing(c) || hasQueens(c))) {
          s.phase = TrixPhase.doubling;
          s.doublingAnswers = 0;
        } else if (c == TrixContract.trix) {
          s.phase = TrixPhase.layout;
        } else {
          s.phase = TrixPhase.tricks;
          s.trick = Trick(s.owner);
        }
        s.turn = s.owner;
      case TrixMoveKind.double:
        for (final c in m.cards) {
          s.doubled[c] = seat;
        }
        ev?.add(
          m.cards.isEmpty
              ? CardEvent(CardEventType.pass, seat: seat)
              : CardEvent(CardEventType.doubled, seat: seat, cards: m.cards),
        );
        s.doublingAnswers++;
        if (s.doublingAnswers == 4) {
          s.phase = TrixPhase.tricks;
          s.trick = Trick(s.owner);
          s.turn = s.owner;
        } else {
          s.turn = (seat + 1) % 4;
        }
      case TrixMoveKind.play:
        if (s.phase == TrixPhase.layout) {
          _layoutPlay(s, seat, m.card!, ev);
        } else {
          _trickPlay(s, seat, m.card!, ev);
        }
      case TrixMoveKind.pass:
        s.cannotHold[seat].addAll(layoutOpenings(s));
        ev?.add(CardEvent(CardEventType.pass, seat: seat));
        s.turn = _nextActive(s, seat);
    }
  }

  int _nextActive(TrixState s, int seat) {
    var next = (seat + 1) % 4;
    while (s.finished.contains(next)) {
      next = (next + 1) % 4;
    }
    return next;
  }

  void _layoutPlay(TrixState s, int seat, PlayingCard card, List<CardEvent>? ev) {
    s.hands[seat].remove(card);
    s.layoutCards.add(card);
    final i = card.suit.index;
    final v = card.rank.value;
    if (s.layoutLow[i] == 0) {
      s.layoutLow[i] = v;
      s.layoutHigh[i] = v;
    } else if (v < s.layoutLow[i]) {
      s.layoutLow[i] = v;
    } else {
      s.layoutHigh[i] = v;
    }
    ev?.add(CardEvent(CardEventType.cardPlayed, seat: seat, cards: [card]));
    if (s.hands[seat].isEmpty) {
      s.finished.add(seat);
      ev?.add(CardEvent(CardEventType.playerFinished, seat: seat, value: s.finished.length));
      if (s.finished.length == 3) {
        final lastSeat = [0, 1, 2, 3].firstWhere((x) => !s.finished.contains(x));
        // The last player's cards go down too (the layout completes).
        s.layoutCards.addAll(s.hands[lastSeat]);
        s.hands[lastSeat].clear();
        s.finished.add(lastSeat);
        return _scoreDeal(s, ev);
      }
    }
    s.turn = _nextActive(s, seat);
  }

  void _trickPlay(TrixState s, int seat, PlayingCard card, List<CardEvent>? ev) {
    s.hands[seat].remove(card);
    final trick = s.trick!..add(seat, card);
    ev?.add(CardEvent(CardEventType.cardPlayed, seat: seat, cards: [card]));
    if (trick.length < 4) {
      s.turn = (seat + 1) % 4;
      return;
    }
    final winner = trick.winner((c, led) => standardPower(c, led, null));
    s.taken[winner].addAll(trick.cards);
    s.tricksTaken[winner]++;
    s.tricks.add(trick);
    s.trick = null;
    ev?.add(CardEvent(CardEventType.trickWon, seat: winner, cards: List.of(trick.cards)));
    if (_trickDealOver(s)) return _scoreDeal(s, ev);
    s.trick = Trick(winner);
    s.turn = winner;
  }

  bool _trickDealOver(TrixState s) {
    if (s.tricks.length == 13) return true;
    final taken = [for (final t in s.taken) ...t];
    return switch (s.contract!) {
      TrixContract.king => taken.contains(kingOfHearts),
      TrixContract.queens => taken.where((c) => c.rank == Rank.queen).length == 4,
      TrixContract.diamonds => taken.where((c) => c.suit == Suit.diamonds).length == 13,
      _ => false,
    };
  }

  /// Points per seat of the finished deal.
  static List<int> dealPoints(TrixState s) {
    final o = s.options;
    final pts = List.filled(4, 0);
    final c = s.contract!;
    if (c == TrixContract.trix) {
      for (var i = 0; i < s.finished.length; i++) {
        pts[s.finished[i]] += o.trixScores[i];
      }
      return pts;
    }
    int team(int seat) => o.partnership ? seat % 2 : seat;
    void penalise(int taker, PlayingCard card, int penalty) {
      final doubler = s.doubled[card];
      if (doubler == null) {
        pts[taker] -= penalty;
        return;
      }
      pts[taker] -= 2 * penalty;
      if (team(doubler) != team(taker)) pts[doubler] += penalty;
    }

    for (var seat = 0; seat < 4; seat++) {
      for (final card in s.taken[seat]) {
        if (hasKing(c) && card == kingOfHearts) penalise(seat, card, o.kingPenalty);
        if (hasQueens(c) && card.rank == Rank.queen) penalise(seat, card, o.queenPenalty);
        if (hasDiamonds(c) && card.suit == Suit.diamonds) pts[seat] -= o.diamondPenalty;
      }
      if (hasTricks(c)) pts[seat] -= o.trickPenalty * s.tricksTaken[seat];
    }
    return pts;
  }

  void _scoreDeal(TrixState s, List<CardEvent>? ev) {
    final pts = dealPoints(s);
    for (var i = 0; i < 4; i++) {
      s.seatScores[i] += pts[i];
    }
    s.results.add(TrixDealResult(s.owner, s.contract!, pts));
    ev?.add(CardEvent(CardEventType.roundScored, seat: s.owner, detail: s.contract!.name));
    if (s.used.length == s.options.contracts.length) {
      s.kingdom++;
      s.used = [];
      s.owner = (s.owner + 1) % 4;
      if (s.kingdom == 4) {
        s.phase = TrixPhase.over;
        ev?.add(const CardEvent(CardEventType.matchOver));
        return;
      }
    }
    s.dealFromRng();
    ev?.add(CardEvent(CardEventType.dealt, seat: s.owner));
  }
}

class TrixEngine extends RulesEngine<TrixState, TrixMove> {
  TrixEngine(TrixState state) : super(const TrixRules(), state);

  factory TrixEngine.newMatch({TrixOptions options = const TrixOptions(), required int seed}) =>
      TrixEngine(TrixState.newMatch(options: options, seed: seed));

  factory TrixEngine.fromJson(Map<String, Object?> json) => TrixEngine(TrixState.fromJson(json));
}

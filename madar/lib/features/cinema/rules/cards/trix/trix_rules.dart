/// Trix (تركس) rules as commonly played in Jordan: four kingdoms, the owner
/// of each choosing the order of its contracts (شيخ الكبة, البنات, الديناري,
/// اللطوش, التركس – or الكومبلكس and التركس). See RULES.md §2.
library;

import '../core/card_game.dart';
import '../core/playing_card.dart';
import '../core/trick.dart';
import 'trix_state.dart';

final PlayingCard kingOfHearts = PlayingCard(Suit.hearts, Rank.king);
final PlayingCard aceOfHearts = PlayingCard(Suit.hearts, Rank.ace);

class TrixRules extends CardRules<TrixState, TrixMove> {
  const TrixRules();

  static bool hasKing(TrixContract? c) => c == TrixContract.king || c == TrixContract.complex;
  static bool hasQueens(TrixContract? c) => c == TrixContract.queens || c == TrixContract.complex;
  static bool hasDiamonds(TrixContract? c) => c == TrixContract.diamonds || c == TrixContract.complex;
  static bool hasTricks(TrixContract? c) => c == TrixContract.ltoush || c == TrixContract.complex;

  /// Whether the king rules (`noHeartLeadInKing`, `kingMustBeDiscarded`,
  /// `kingOnAceOfHearts`) apply to the current contract.
  static bool kingRulesApply(TrixState s) =>
      s.contract == TrixContract.king || (s.contract == TrixContract.complex && s.options.kingRulesInComplex);

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
    final o = s.options;
    final kingRules = kingRulesApply(s);
    final led = s.trick!.ledSuit;
    if (led == null) {
      if (kingRules && o.noHeartLeadInKing) {
        final other = hand.where((c) => c.suit != Suit.hearts).toList();
        if (other.isNotEmpty) return other;
      }
      return List.of(hand);
    }
    final follow = hand.where((c) => c.suit == led).toList();
    if (follow.isNotEmpty) {
      if (kingRules &&
          o.kingOnAceOfHearts &&
          led == Suit.hearts &&
          s.trick!.cards.contains(aceOfHearts) &&
          hand.contains(kingOfHearts)) {
        return [kingOfHearts];
      }
      return follow;
    }
    if (kingRules && o.kingMustBeDiscarded && hand.contains(kingOfHearts)) return [kingOfHearts];
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
      if (s.hands[seat].any((c) => c.suit == led)) {
        return m.card!.suit == led ? 'mustPlayKingOnAce' : 'mustFollowSuit';
      }
      return 'mustDiscardKing';
    }
    if (m.kind == TrixMoveKind.double && s.phase == TrixPhase.doubling) {
      // A card the seat does not hold, or one that cannot be doubled in this
      // contract (only K♥ in King / Complex, queens in Queens / Complex).
      return m.cards.every(s.hands[seat].contains) ? 'notDoublable' : 'cardNotInHand';
    }
    if (m.kind == TrixMoveKind.pass && s.phase == TrixPhase.layout) return 'mustPlayWhenAble';
    if (m.kind == TrixMoveKind.contract && s.phase == TrixPhase.contract) {
      return s.options.contracts.contains(m.contract) ? 'contractAlreadyPlayed' : 'contractNotAvailable';
    }
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
        if (s.options.doublingReveal == TrixDoublingReveal.sequential) {
          for (final c in m.cards) {
            s.doubled[c] = seat;
          }
          ev?.add(
            m.cards.isEmpty
                ? CardEvent(CardEventType.pass, seat: seat)
                : CardEvent(CardEventType.doubled, seat: seat, cards: m.cards),
          );
        } else {
          // Hidden until everyone has answered: the event only says that
          // this seat answered.
          for (final c in m.cards) {
            s.pendingDoubles[c] = seat;
          }
          ev?.add(CardEvent(CardEventType.doubled, seat: seat, detail: TrixEventDetail.doublingAnswered));
        }
        s.doublingAnswers++;
        if (s.doublingAnswers == 4) {
          _revealDoubles(s, ev);
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

  /// Simultaneous doubling: every hidden double becomes public at once, one
  /// event per doubling seat in seat order from the owner.
  void _revealDoubles(TrixState s, List<CardEvent>? ev) {
    if (s.pendingDoubles.isEmpty) return;
    for (var i = 0; i < 4; i++) {
      final seat = (s.owner + i) % 4;
      final cards = sortedCards([
        for (final e in s.pendingDoubles.entries)
          if (e.value == seat) e.key,
      ]);
      if (cards.isEmpty) continue;
      for (final c in cards) {
        s.doubled[c] = seat;
      }
      ev?.add(CardEvent(CardEventType.doubled, seat: seat, cards: cards, detail: TrixEventDetail.doublingRevealed));
    }
    s.pendingDoubles = {};
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
        // The last player's cards go down too (the layout completes); his
        // event carries them so the table can move them.
        final rest = List.of(s.hands[lastSeat]);
        s.layoutCards.addAll(rest);
        s.hands[lastSeat].clear();
        s.finished.add(lastSeat);
        ev?.add(CardEvent(CardEventType.playerFinished, seat: lastSeat, cards: rest, value: 4));
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

  /// Points per seat of the finished deal (RULES.md §2, "Scoring").
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
    for (var seat = 0; seat < 4; seat++) {
      for (final card in s.taken[seat]) {
        if (hasKing(c) && card == kingOfHearts) _scoreCard(s, pts, seat, card, o.kingPenalty);
        if (hasQueens(c) && card.rank == Rank.queen) _scoreCard(s, pts, seat, card, o.queenPenalty);
        if (hasDiamonds(c) && card.suit == Suit.diamonds) pts[seat] -= o.diamondPenalty;
      }
      if (hasTricks(c)) pts[seat] -= o.trickPenalty * s.tricksTaken[seat];
    }
    return pts;
  }

  /// The completed trick holding [card], if any.
  static Trick? trickHolding(TrixState s, PlayingCard card) {
    for (final t in s.tricks) {
      if (t.cards.contains(card)) return t;
    }
    return null;
  }

  /// Scores K♥ or a queen of value [v] taken by seat [t] (the doubling
  /// table of RULES.md §2).
  static void _scoreCard(TrixState s, List<int> pts, int t, PlayingCard card, int v) {
    final o = s.options;
    final d = s.doubled[card];
    if (d == null) {
      pts[t] -= v;
      return;
    }
    int team(int seat) => o.partnership ? seat % 2 : seat;
    if (team(t) != team(d)) {
      // An opponent took it: he pays double, the doubler gains the value.
      pts[t] -= 2 * v;
      pts[d] += v;
      return;
    }
    // The doubler (or his partner) took it. The trick's leader decides
    // between "forced" and "self-led"; a hand-built state without the trick
    // counts as self-led.
    final leader = trickHolding(s, card)?.leader ?? t;
    final selfLed = t == d && leader == d;
    if (!o.partnership) {
      switch (o.selfCaptureRule) {
        case TrixSelfCapture.leaderGains:
          if (selfLed) {
            pts[t] -= v;
          } else {
            pts[t] -= 2 * v;
            pts[leader] += v;
          }
        case TrixSelfCapture.leaderGainsStrict:
          pts[t] -= 2 * v;
          if (!selfLed) pts[leader] += v;
        case TrixSelfCapture.normalValue:
          pts[t] -= v;
        case TrixSelfCapture.doubleNoBonus:
          pts[t] -= 2 * v;
      }
      return;
    }
    switch (o.partnerCaptureRule) {
      case TrixPartnerCapture.noBonus:
        pts[t] -= 2 * v;
      case TrixPartnerCapture.opponentsGain:
        if (selfLed) {
          pts[t] -= v;
        } else {
          pts[t] -= 2 * v;
          pts[team(leader) != team(d) ? leader : (leader + 1) % 4] += v;
        }
      case TrixPartnerCapture.normalValue:
        pts[t] -= v;
    }
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

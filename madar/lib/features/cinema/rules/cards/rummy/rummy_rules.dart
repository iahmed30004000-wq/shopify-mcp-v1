/// Rules shared by Hand (هاند) and Konkan (كونكان). A turn is a sequence of
/// atomic moves: draw (stock or the top discard), then any lay-downs, and a
/// discard that ends the turn. See RULES.md.
library;

import '../core/card_game.dart';
import '../core/determinize.dart';
import '../core/playing_card.dart';
import 'rummy_meld.dart';
import 'rummy_state.dart';

class RummyRules extends CardRules<RummyState, RummyMove> {
  const RummyRules();

  static bool _openingOk(RummyOptions o, MeldPlan p, PlayingCard? must) =>
      p.value >= o.openingThreshold && (!o.openingRequiresRun || p.hasRun) && (must == null || p.uses(must));

  /// Opening lay-downs available from [hand] (most cards first), leaving at
  /// least [keep] cards for the discard.
  static List<MeldPlan> openingPlans(
    RummyOptions o,
    List<PlayingCard> hand, {
    PlayingCard? must,
    int keep = 1,
    int cap = 12,
  }) {
    final found = <MeldPlan>[];
    final keys = <String>{};
    searchPlans(hand, candidateMelds(hand), (p) {
      if (_openingOk(o, p, must)) {
        final key = (p.melds.map((m) => m.key).toList()..sort()).join('|');
        if (keys.add(key)) found.add(p);
      }
      return true;
    }, maxCards: hand.length - keep);
    found.sort((a, b) => b.cardCount != a.cardCount ? b.cardCount - a.cardCount : b.value - a.value);
    return found.take(cap).toList();
  }

  static bool canOpen(RummyOptions o, List<PlayingCard> hand, {PlayingCard? must, int keep = 1}) {
    var ok = false;
    searchPlans(hand, candidateMelds(hand), (p) {
      ok = _openingOk(o, p, must);
      return !ok;
    }, maxCards: hand.length - keep);
    return ok;
  }

  /// Whether [seat] could meld [card] at once if it took it.
  static bool canUseCard(RummyState s, int seat, PlayingCard card) {
    final hand = [...s.hands[seat], card];
    if (!s.opened[seat]) return canOpen(s.options, hand, must: card);
    if (hand.length < 2) return false;
    for (final m in s.table) {
      if (m.withCard(card) != null) return true;
      if (s.options.jokerSwap && m.swapJoker(card) != null) return true;
    }
    return candidateMelds(hand).any((m) => m.cards.contains(card) && m.cards.length <= hand.length - 1);
  }

  @override
  List<RummyMove> legalMoves(RummyState s, int seat) {
    if (s.isOver || s.turn != seat) return const [];
    final o = s.options;
    if (s.phase == RummyPhase.draw) {
      final top = s.topDiscard;
      return [
        const RummyMove.drawStock(),
        if (top != null && (!o.discardMustBeUsed || canUseCard(s, seat, top))) const RummyMove.takeDiscard(),
      ];
    }
    final hand = s.hands[seat];
    final must = s.mustUse;
    final distinct = hand.toSet().toList()..sort();
    final moves = <RummyMove>[];
    if (!s.opened[seat]) {
      for (final p in openingPlans(o, hand, must: must)) {
        moves.add(RummyMove.open([for (final m in p.melds) m.cards]));
      }
    } else {
      for (final m in candidateMelds(hand)) {
        if (m.cards.length <= hand.length - 1 && (must == null || m.cards.contains(must))) {
          moves.add(RummyMove.meld(m.cards));
        }
      }
      if (hand.length >= 2) {
        for (final c in distinct) {
          if (must != null && c != must) continue;
          for (var i = 0; i < s.table.length; i++) {
            if (s.table[i].withCard(c) != null) moves.add(RummyMove.layoff(c, i));
            if (o.jokerSwap && s.table[i].swapJoker(c) != null) moves.add(RummyMove.swapJoker(c, i));
          }
        }
      }
    }
    // Safety net: a taken discard that can no longer be used is released.
    if (must == null || moves.isEmpty) {
      for (final c in distinct) {
        moves.add(RummyMove.discard(c));
      }
    }
    return moves;
  }

  @override
  String? validate(RummyState s, int seat, RummyMove m) {
    if (s.isOver) return 'matchOver';
    if (s.turn != seat) return 'notYourTurn';
    final o = s.options;
    final isDraw = m.kind == RummyMoveKind.drawStock || m.kind == RummyMoveKind.takeDiscard;
    if (isDraw != (s.phase == RummyPhase.draw)) return 'wrongPhase';
    final hand = s.hands[seat];
    switch (m.kind) {
      case RummyMoveKind.drawStock:
        return null;
      case RummyMoveKind.takeDiscard:
        if (s.topDiscard == null) return 'discardPileEmpty';
        return legalMoves(s, seat).contains(m) ? null : 'cannotUseDiscard';
      case RummyMoveKind.open:
      case RummyMoveKind.meld:
        if (m.kind == RummyMoveKind.open && s.opened[seat]) return 'alreadyOpened';
        if (m.kind == RummyMoveKind.meld && !s.opened[seat]) return 'notOpened';
        if (m.kind == RummyMoveKind.meld && m.melds.length != 1) return 'invalidMeld';
        if (m.melds.isEmpty) return 'invalidMeld';
        final cards = m.meldCards;
        if (cardsMinus(hand, cards).length != hand.length - cards.length) return 'cardNotInHand';
        final melds = [for (final cs in m.melds) Meld.arrange(cs)];
        if (melds.any((x) => x == null)) return 'invalidMeld';
        if (hand.length - cards.length < 1) return 'mustKeepOneCard';
        final plan = MeldPlan([for (final x in melds) x!]);
        if (s.mustUse != null && !plan.uses(s.mustUse!)) return 'mustUseTakenDiscard';
        if (m.kind == RummyMoveKind.open) {
          if (plan.value < o.openingThreshold) return 'openingBelowThreshold';
          if (o.openingRequiresRun && !plan.hasRun) return 'openingNeedsRun';
        }
        return null;
      case RummyMoveKind.layoff:
      case RummyMoveKind.swapJoker:
      case RummyMoveKind.discard:
        if (!hand.contains(m.card)) return 'cardNotInHand';
        if (legalMoves(s, seat).contains(m)) return null;
        if (m.kind == RummyMoveKind.discard) return 'mustUseTakenDiscard';
        if (!s.opened[seat]) return 'notOpened';
        if (hand.length < 2) return 'mustKeepOneCard';
        if (s.mustUse != null && m.card != s.mustUse) return 'mustUseTakenDiscard';
        return m.kind == RummyMoveKind.layoff ? 'doesNotFit' : 'noJokerForCard';
    }
  }

  @override
  RummyMove moveFromJson(Map<String, Object?> json) => RummyMove.fromJson(json);

  void _used(RummyState s, int seat, Iterable<PlayingCard> cards) {
    for (final c in cards) {
      s.hands[seat].remove(c);
      s.known[seat].remove(c);
      if (c == s.mustUse) s.mustUse = null;
    }
  }

  @override
  void apply(RummyState s, RummyMove m, [List<CardEvent>? ev]) {
    final seat = s.turn;
    final hand = s.hands[seat];
    switch (m.kind) {
      case RummyMoveKind.drawStock:
        if (s.stock.isEmpty) {
          if (s.discardPile.length > 1 && s.recycles < s.options.maxStockRecycles) {
            final top = s.discardPile.removeLast();
            s.stock = s.discardPile;
            s.rng.shuffle(s.stock);
            s.discardPile = [top];
            s.recycles++;
          } else {
            return _endRound(s, null, ev);
          }
        }
        final card = s.stock.removeLast();
        hand
          ..add(card)
          ..sort();
        s.phase = RummyPhase.play;
        ev?.add(CardEvent(CardEventType.drewStock, seat: seat, cards: [card]));
      case RummyMoveKind.takeDiscard:
        final card = s.discardPile.removeLast();
        hand
          ..add(card)
          ..sort();
        s.known[seat].add(card);
        if (s.options.discardMustBeUsed) s.mustUse = card;
        s.phase = RummyPhase.play;
        ev?.add(CardEvent(CardEventType.tookDiscard, seat: seat, cards: [card]));
      case RummyMoveKind.open:
      case RummyMoveKind.meld:
        for (final cs in m.melds) {
          final meld = Meld.arrange(cs, owner: seat)!;
          _used(s, seat, cs);
          s.table.add(meld);
        }
        final opening = m.kind == RummyMoveKind.open;
        s.opened[seat] = true;
        ev?.add(CardEvent(opening ? CardEventType.opened : CardEventType.melded, seat: seat, cards: m.meldCards));
      case RummyMoveKind.layoff:
        s.table[m.target!] = s.table[m.target!].withCard(m.card!)!;
        _used(s, seat, [m.card!]);
        ev?.add(CardEvent(CardEventType.laidOff, seat: seat, cards: [m.card!], value: m.target));
      case RummyMoveKind.swapJoker:
        final (meld, joker) = s.table[m.target!].swapJoker(m.card!)!;
        s.table[m.target!] = meld;
        _used(s, seat, [m.card!]);
        hand
          ..add(joker)
          ..sort();
        ev?.add(CardEvent(CardEventType.jokerSwapped, seat: seat, cards: [m.card!, joker], value: m.target));
      case RummyMoveKind.discard:
        _used(s, seat, [m.card!]);
        s.mustUse = null;
        s.discardPile.add(m.card!);
        ev?.add(CardEvent(CardEventType.discarded, seat: seat, cards: [m.card!]));
        if (hand.isEmpty) return _endRound(s, seat, ev);
        s.turn = (seat + 1) % s.playerCount;
        s.phase = RummyPhase.draw;
        s.openAtTurnStart = s.opened[s.turn];
    }
  }

  /// Points of a finished round per seat ([winner] null: abandoned).
  static List<int> roundPoints(RummyState s, int? winner, {required bool handFinish}) {
    final o = s.options;
    final pts = List.filled(s.playerCount, 0);
    if (winner == null) return pts;
    final mult = handFinish ? o.handMultiplier : 1;
    for (var p = 0; p < s.playerCount; p++) {
      if (p == winner) continue;
      pts[p] = (s.opened[p] ? s.handPenalty(p) : o.notOpenedPenalty) * mult;
    }
    pts[winner] = handFinish ? o.handWinnerScore : o.winnerScore;
    return pts;
  }

  void _endRound(RummyState s, int? winner, List<CardEvent>? ev) {
    final handFinish = winner != null && !s.openAtTurnStart;
    final pts = roundPoints(s, winner, handFinish: handFinish);
    for (var i = 0; i < pts.length; i++) {
      s.seatScores[i] += pts[i];
    }
    s.results.add(RummyRoundResult(winner: winner, handFinish: handFinish, points: pts));
    ev?.add(CardEvent(CardEventType.roundScored, seat: winner, detail: handFinish ? 'hand' : null));
    final o = s.options;
    final done = o.matchEnd == RummyMatchEnd.rounds
        ? s.results.length >= o.rounds
        : s.seatScores.any((x) => x >= o.targetScore);
    if (done) {
      s.over = true;
      s.phase = RummyPhase.over;
      ev?.add(const CardEvent(CardEventType.matchOver));
      return;
    }
    s.dealer = (s.dealer + 1) % s.playerCount;
    s.dealFromRng();
    ev?.add(CardEvent(CardEventType.dealt, seat: s.dealer));
  }
}

class RummyEngine extends RulesEngine<RummyState, RummyMove> {
  RummyEngine(RummyState state) : super(const RummyRules(), state);

  factory RummyEngine.newMatch({required RummyOptions options, required int seed}) =>
      RummyEngine(RummyState.newMatch(options: options, seed: seed));

  factory RummyEngine.fromJson(Map<String, Object?> json) => RummyEngine(RummyState.fromJson(json));
}

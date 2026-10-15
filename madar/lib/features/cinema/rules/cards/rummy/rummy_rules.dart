/// Rules shared by Hand (هاند) and Konkan (كونكان). A turn is a sequence of
/// atomic moves: draw (stock or the top discard), then any lay-downs, and a
/// discard that ends the turn; a closed player may also go out in one
/// `finish` move. See RULES.md.
library;

import 'dart:math' as math;

import '../core/card_game.dart';
import '../core/determinize.dart';
import '../core/playing_card.dart';
import 'rummy_meld.dart';
import 'rummy_state.dart';

class RummyRules extends CardRules<RummyState, RummyMove> {
  const RummyRules();

  // ------------------------------------------------------------ queries

  /// Cards [seat] must keep after a lay-down this turn: two on its first
  /// turn when nobody may go out on their first turn, else one (for the
  /// discard).
  static int keepFor(RummyState s, int seat) => s.options.noGoOutOnFirstTurn && s.turnsTaken[seat] == 0 ? 2 : 1;

  /// The starter's first turn: a discard only.
  static bool discardOnlyTurn(RummyState s, int seat) =>
      s.options.starterFirstTurnDiscardOnly && seat == s.starter && s.turnsTaken[seat] == 0;

  /// Minimum total of an opening made now.
  static int openingMinimum(RummyState s) {
    final o = s.options;
    if (!o.openingMustBeatPrevious || s.highestOpening == 0) return o.openingThreshold;
    return math.max(o.openingThreshold, s.highestOpening + 1);
  }

  /// Whether [m] contains the taken discard [must] in an allowed way (with
  /// the indicator option a wild taken from the pile may only be an ace).
  static bool mustFits(RummyState s, Meld m, PlayingCard must) {
    if (!m.cards.contains(must)) return false;
    final r = s.meldRules;
    if (!s.options.wildIndicator || !r.isWild(must)) return true;
    return r.wildUsedAsAce(m, must);
  }

  static bool planUsesMust(RummyState s, MeldPlan p, PlayingCard? must) =>
      must == null || p.melds.any((m) => mustFits(s, m, must));

  /// Why [p] cannot be an opening now (null: it can).
  static String? openingError(RummyState s, MeldPlan p, PlayingCard? must) {
    final o = s.options;
    if (!planUsesMust(s, p, must)) return 'mustUseTakenDiscard';
    if (o.openingMustUseDiscard && must == null) return 'openingNeedsDiscard';
    if (p.value < o.openingThreshold) return 'openingBelowThreshold';
    if (p.value < openingMinimum(s)) return 'openingMustBeatPrevious';
    if (o.openingRequiresRun && !p.hasRun) return 'openingNeedsRun';
    return null;
  }

  /// Opening lay-downs from [hand] (most cards first), leaving at least
  /// [keep] cards.
  static List<MeldPlan> openingPlans(
    RummyState s,
    List<PlayingCard> hand, {
    PlayingCard? must,
    int keep = 1,
    int cap = 12,
    bool stopAtFirst = false,
    List<Meld>? candidates,
  }) {
    final cands = candidates ?? s.meldRules.candidates(hand);
    final found = <MeldPlan>[];
    final keys = <String>{};
    bool visit(MeldPlan p) {
      if (openingError(s, p, must) == null && keys.add(p.key)) {
        found.add(p);
        if (stopAtFirst) return false;
      }
      return true;
    }

    final maxCards = hand.length - keep;
    if (must == null) {
      searchPlans(hand, cands, visit, maxCards: maxCards);
    } else {
      // Every such opening holds a meld with the taken card: start from each
      // of them and search the rest of the hand, so that the node limit of
      // the search is never spent on plans without it.
      for (final (first, rest, restCands) in _withFirst(s, hand, cands, must)) {
        if (first.cards.length > maxCards) continue;
        var go = visit(MeldPlan([first]));
        if (go) {
          searchPlans(rest, restCands, (p) {
            go = visit(MeldPlan([first, ...p.melds]));
            return go;
          }, maxCards: maxCards - first.cards.length);
        }
        if (!go) break;
      }
    }
    found.sort((a, b) => b.cardCount != a.cardCount ? b.cardCount - a.cardCount : b.value - a.value);
    return found.take(cap).toList();
  }

  /// For each candidate of [cands] that holds the taken card [must] in an
  /// allowed way: that meld, the rest of [hand] and the candidates that still
  /// fit in it.
  static Iterable<(Meld, List<PlayingCard>, List<Meld>)> _withFirst(
    RummyState s,
    List<PlayingCard> hand,
    List<Meld> cands,
    PlayingCard must,
  ) sync* {
    for (final first in cands) {
      if (!mustFits(s, first, must)) continue;
      final rest = cardsMinus(hand, first.cards);
      final counts = cardCounts(rest);
      final restCands = [
        for (final m in cands)
          if (_fits(m, counts)) m,
      ];
      yield (first, rest, restCands);
    }
  }

  static bool _fits(Meld m, List<int> counts) {
    final need = cardCounts(m.cards);
    for (final c in m.cards) {
      if (need[c.code] > counts[c.code]) return false;
    }
    return true;
  }

  /// Lays [cards] off on the table one by one (greedily), or null when some
  /// card does not fit. Used for the lay-offs of a one-turn finish.
  static List<RummyLayoff>? layAll(RummyState s, List<PlayingCard> cards) {
    final r = s.meldRules;
    final table = List.of(s.table);
    final rest = List.of(cards);
    final out = <RummyLayoff>[];
    var progress = true;
    while (rest.isNotEmpty && progress) {
      progress = false;
      for (var k = 0; k < rest.length && !progress; k++) {
        for (var i = 0; i < table.length; i++) {
          final m = r.withCard(table[i], rest[k]);
          if (m == null) continue;
          table[i] = m;
          out.add(RummyLayoff(rest[k], i));
          rest.removeAt(k);
          progress = true;
          break;
        }
      }
    }
    return rest.isEmpty ? out : null;
  }

  /// Ways for a closed [seat] holding [hand] to go out in one move (new
  /// melds, lay-offs on table melds, the last card discarded), pure
  /// finishes first.
  static List<RummyMove> finishMoves(
    RummyState s,
    int seat,
    List<PlayingCard> hand, {
    PlayingCard? must,
    int cap = 6,
    bool stopAtFirst = false,
    List<Meld>? candidates,
  }) {
    if (!s.options.oneTurnFinishWaivesThreshold || s.opened[seat] || keepFor(s, seat) > 1) return const [];
    final cands = candidates ?? s.meldRules.candidates(hand);
    final out = <RummyMove>[];
    final seen = <RummyMove>{};
    void add(RummyMove m) {
      if (seen.add(m)) out.add(m);
    }

    bool visit(MeldPlan plan, List<PlayingCard> left) {
      if (!planUsesMust(s, plan, must)) return true;
      final melds = [for (final m in plan.melds) m.cards];
      final lows = [for (final m in plan.melds) m.wildPlacedLow];
      if (left.length == 1) {
        add(RummyMove.finish(melds: melds, wildLow: lows, discard: left.single));
      } else {
        for (final d in left.toSet()) {
          final lay = layAll(s, List.of(left)..remove(d));
          if (lay != null) {
            add(RummyMove.finish(melds: melds, wildLow: lows, layoffs: lay, discard: d));
            break;
          }
        }
      }
      return out.length < cap && !(stopAtFirst && out.isNotEmpty);
    }

    final maxLeft = s.table.isEmpty ? 1 : 4;
    if (must == null) {
      coverPlans(hand, cands, maxLeft, visit);
    } else {
      // As for openings: start from each meld that holds the taken card.
      for (final (first, rest, restCands) in _withFirst(s, hand, cands, must)) {
        if (rest.isEmpty) continue;
        var go = rest.length > maxLeft || visit(MeldPlan([first]), rest);
        if (go) {
          coverPlans(rest, restCands, maxLeft, (plan, left) {
            go = visit(MeldPlan([first, ...plan.melds]), left);
            return go;
          });
        }
        if (!go) break;
      }
    }
    out.sort((a, b) => a.layoffs.length - b.layoffs.length);
    return out;
  }

  /// Whether [seat] may take [top] from the discard pile now: it must go
  /// at once into a new meld with at least two cards of the hand (before
  /// opening, inside an opening or a one-turn finish).
  static bool canTakeDiscard(RummyState s, int seat, PlayingCard top) {
    final hand = [...s.hands[seat], top]..sort();
    final keep = keepFor(s, seat);
    final r = s.meldRules;
    final cands = r.candidates(hand);
    if (!s.opened[seat]) {
      return openingPlans(s, hand, must: top, keep: keep, stopAtFirst: true, candidates: cands).isNotEmpty ||
          finishMoves(s, seat, hand, must: top, stopAtFirst: true, candidates: cands).isNotEmpty;
    }
    if (cands.any((m) => mustFits(s, m, top) && m.cards.length <= hand.length - keep)) return true;
    if (s.options.discardUse != RummyDiscardUse.any || hand.length - 1 < keep) return false;
    for (var i = 0; i < s.table.length; i++) {
      if (layoffError(s, seat, top, i, handAfter: hand.length - 1) == null) return true;
      if (!s.options.jokerSwap) continue;
      if (r.swap(s.table[i], [top]) != null) return true;
      // Both missing suits of a set of two naturals and a wild.
      for (final other in s.hands[seat]) {
        if (r.swap(s.table[i], [top, other]) != null) return true;
      }
    }
    return false;
  }

  /// Why [card] cannot be laid off on table meld [target] (null: it can).
  /// [handAfter] is the hand size after the lay-off.
  static String? layoffError(
    RummyState s,
    int seat,
    PlayingCard card,
    int target, {
    bool atLow = false,
    int? handAfter,
  }) {
    if (target < 0 || target >= s.table.length) return 'noSuchMeld';
    final r = s.meldRules;
    final t = s.table[target];
    if (r.withCard(t, card, atLow: atLow) == null) return 'doesNotFit';
    // A set of two naturals and a wild takes a single natural only from a
    // player about to go out, or when another player holds one card.
    if (s.options.setWildSwap == RummySetWildSwap.bothMissing &&
        t.kind == MeldKind.set &&
        t.cards.length == 3 &&
        t.wilds == 1 &&
        !r.isWild(card)) {
      final after = handAfter ?? s.hands[seat].length - 1;
      final lastCard = s.activeSeats.any((p) => p != seat && s.hands[p].length == 1);
      if (after > 2 && !lastCard) return 'setNeedsBothSuits';
    }
    return null;
  }

  /// Lay-downs available to [seat] in the play phase (no discards).
  static List<RummyMove> layDownMoves(RummyState s, int seat) {
    final o = s.options;
    final r = s.meldRules;
    final hand = s.hands[seat];
    final must = s.mustUse;
    final keep = keepFor(s, seat);
    final cands = r.candidates(hand);
    final moves = <RummyMove>[];
    if (!s.opened[seat]) {
      moves.addAll(finishMoves(s, seat, hand, must: must, candidates: cands));
      for (final p in openingPlans(s, hand, must: must, keep: keep, candidates: cands)) {
        moves.add(
          RummyMove.open([for (final m in p.melds) m.cards], wildLow: [for (final m in p.melds) m.wildPlacedLow]),
        );
      }
      return moves;
    }
    for (final m in cands) {
      if (m.cards.length <= hand.length - keep && (must == null || mustFits(s, m, must))) {
        moves.add(RummyMove.meld(m.cards, wildLow: m.wildPlacedLow));
      }
    }
    final anyUse = o.discardUse == RummyDiscardUse.any;
    if (must != null && !anyUse) return moves;
    final distinct = hand.toSet().toList()..sort();
    if (hand.length - 1 >= keep) {
      for (final c in distinct) {
        if (must != null && c != must) continue;
        for (var i = 0; i < s.table.length; i++) {
          if (layoffError(s, seat, c, i) != null) continue;
          moves.add(RummyMove.layoff(c, i));
          final t = s.table[i];
          if (r.isWild(c) && t.kind == MeldKind.run && t.low > 1 && t.high < 14) {
            moves.add(RummyMove.layoff(c, i, atLow: true));
          }
        }
      }
    }
    if (o.jokerSwap) {
      for (var i = 0; i < s.table.length; i++) {
        final t = s.table[i];
        if (t.wilds == 0) continue;
        if (t.kind == MeldKind.run) {
          for (final c in distinct) {
            if ((must == null || c == must) && r.swap(t, [c]) != null) moves.add(RummyMove.swapJoker(c, i));
          }
          continue;
        }
        final have = <PlayingCard>[];
        for (final su in r.missingSuits(t)) {
          for (final c in distinct) {
            if (!r.isWild(c) && r.rankOf(c) == t.rank && r.suitOf(c) == su) {
              have.add(c);
              break;
            }
          }
        }
        for (final c in have) {
          if ((must == null || c == must) && r.swap(t, [c]) != null) moves.add(RummyMove.swapJoker(c, i));
        }
        if (have.length == 2 && hand.length - 1 >= keep && (must == null || have.contains(must))) {
          if (r.swap(t, have) != null) moves.add(RummyMove.swapJoker(have[0], i, card2: have[1]));
        }
      }
    }
    return moves;
  }

  /// Whether a discard is held back (a taken discard or a freed wild still to
  /// be laid down).
  static bool discardBlocked(RummyState s) =>
      s.mustUse != null || (s.options.swappedWildMustBeUsed && s.pendingWilds.isNotEmpty);

  /// Whether lay-down [m] puts down a card that holds the discard back (the
  /// taken discard or a freed wild still to be laid down).
  static bool usesBlockedCard(RummyState s, RummyMove m) {
    final must = s.mustUse;
    final pending = s.options.swappedWildMustBeUsed ? s.pendingWilds : const <PlayingCard>[];
    bool blocked(PlayingCard? c) => c != null && (c == must || pending.contains(c));
    return blocked(m.card) || blocked(m.card2) || m.meldCards.any(blocked);
  }

  @override
  List<RummyMove> legalMoves(RummyState s, int seat) {
    if (s.isOver || s.turn != seat) return const [];
    switch (s.phase) {
      case RummyPhase.over:
        return const [];
      case RummyPhase.redealOffer:
        return const [RummyMove.callRedeal(), RummyMove.keepHand()];
      case RummyPhase.draw:
        final top = s.topDiscard;
        return [
          const RummyMove.drawStock(),
          if (top != null && canTakeDiscard(s, seat, top)) const RummyMove.takeDiscard(),
        ];
      case RummyPhase.play:
        break;
    }
    final distinct = s.hands[seat].toSet().toList()..sort();
    final discards = [for (final c in distinct) RummyMove.discard(c)];
    if (discardOnlyTurn(s, seat)) return discards;
    final moves = layDownMoves(s, seat);
    // The discard waits while a lay-down can still put the taken discard (or
    // a freed wild) on the table; one that no lay-down can use is released,
    // whatever else could still be laid down.
    if (!discardBlocked(s) || !moves.any((m) => usesBlockedCard(s, m))) moves.addAll(discards);
    return moves;
  }

  @override
  String? validate(RummyState s, int seat, RummyMove m) {
    if (s.isOver) return 'matchOver';
    if (s.turn != seat) return 'notYourTurn';
    final o = s.options;
    final phaseOk = switch (m.kind) {
      RummyMoveKind.drawStock || RummyMoveKind.takeDiscard => s.phase == RummyPhase.draw,
      RummyMoveKind.callRedeal || RummyMoveKind.keepHand => s.phase == RummyPhase.redealOffer,
      _ => s.phase == RummyPhase.play,
    };
    if (!phaseOk) return 'wrongPhase';
    final hand = s.hands[seat];
    final r = s.meldRules;
    final keep = keepFor(s, seat);
    final must = s.mustUse;
    String? keepError(int left) => left < 1 ? 'mustKeepOneCard' : (left < keep ? 'noGoOutOnFirstTurn' : null);
    switch (m.kind) {
      case RummyMoveKind.callRedeal:
        return s.canCallRedeal(seat) ? null : 'cannotRedeal';
      case RummyMoveKind.keepHand:
      case RummyMoveKind.drawStock:
        return null;
      case RummyMoveKind.takeDiscard:
        final top = s.topDiscard;
        if (top == null) return 'discardPileEmpty';
        return canTakeDiscard(s, seat, top) ? null : 'cannotUseDiscard';
      default:
        break;
    }
    if (m.kind != RummyMoveKind.discard && discardOnlyTurn(s, seat)) return 'firstTurnDiscardOnly';
    switch (m.kind) {
      case RummyMoveKind.open:
      case RummyMoveKind.meld:
        if (m.kind == RummyMoveKind.open && s.opened[seat]) return 'alreadyOpened';
        if (m.kind == RummyMoveKind.meld && !s.opened[seat]) return 'notOpened';
        if (m.melds.isEmpty || (m.kind == RummyMoveKind.meld && m.melds.length != 1)) return 'invalidMeld';
        final cards = m.meldCards;
        if (cardsMinus(hand, cards).length != hand.length - cards.length) return 'cardNotInHand';
        final melds = [for (var i = 0; i < m.melds.length; i++) r.arrange(m.melds[i], wildLow: m.lowAt(i))];
        if (melds.any((x) => x == null)) return 'invalidMeld';
        final kept = keepError(hand.length - cards.length);
        if (kept != null) return kept;
        final plan = MeldPlan([for (final x in melds) x!]);
        if (!planUsesMust(s, plan, must)) return 'mustUseTakenDiscard';
        if (m.kind == RummyMoveKind.open) return openingError(s, plan, must);
        return null;
      case RummyMoveKind.finish:
        if (s.opened[seat]) return 'alreadyOpened';
        if (!o.oneTurnFinishWaivesThreshold) return 'finishNotAllowed';
        if (keep > 1) return 'noGoOutOnFirstTurn';
        if (m.melds.isEmpty || m.card == null) return 'invalidMeld';
        final used = [...m.meldCards, for (final l in m.layoffs) l.card, m.card!];
        final rest = cardsMinus(hand, used);
        if (rest.length != hand.length - used.length) return 'cardNotInHand';
        if (rest.isNotEmpty) return 'notAFinish';
        final melds = [for (var i = 0; i < m.melds.length; i++) r.arrange(m.melds[i], wildLow: m.lowAt(i))];
        if (melds.any((x) => x == null)) return 'invalidMeld';
        if (!planUsesMust(s, MeldPlan([for (final x in melds) x!]), must)) return 'mustUseTakenDiscard';
        final table = List.of(s.table);
        for (final l in m.layoffs) {
          if (l.target < 0 || l.target >= table.length) return 'noSuchMeld';
          final next = r.withCard(table[l.target], l.card, atLow: l.atLow);
          if (next == null) return 'doesNotFit';
          table[l.target] = next;
        }
        return null;
      case RummyMoveKind.layoff:
        if (!s.opened[seat]) return 'notOpened';
        if (!hand.contains(m.card)) return 'cardNotInHand';
        final kept = keepError(hand.length - 1);
        if (kept != null) return kept;
        if (must != null && (o.discardUse != RummyDiscardUse.any || m.card != must)) return 'mustUseTakenDiscard';
        return layoffError(s, seat, m.card!, m.target ?? -1, atLow: m.atLow);
      case RummyMoveKind.swapJoker:
        if (!o.jokerSwap) return 'jokerSwapOff';
        if (!s.opened[seat]) return 'notOpened';
        final nats = [m.card!, ?m.card2];
        if (cardsMinus(hand, nats).length != hand.length - nats.length) return 'cardNotInHand';
        if (must != null && (o.discardUse != RummyDiscardUse.any || !nats.contains(must))) {
          return 'mustUseTakenDiscard';
        }
        final t = m.target;
        if (t == null || t < 0 || t >= s.table.length) return 'noSuchMeld';
        final meld = s.table[t];
        if (r.swap(meld, nats) == null) {
          // A single natural of a missing suit on a set of two naturals and
          // a wild: both missing suits are needed.
          final single = nats.length == 1 && !r.isWild(nats.single) ? nats.single : null;
          final needsBoth =
              single != null &&
              meld.kind == MeldKind.set &&
              meld.cards.length == 3 &&
              meld.wilds == 1 &&
              r.rankOf(single) == meld.rank &&
              r.missingSuits(meld).contains(r.suitOf(single));
          return needsBoth ? 'setNeedsBothSuits' : 'noJokerForCard';
        }
        return keepError(hand.length - nats.length + 1);
      case RummyMoveKind.discard:
        if (!hand.contains(m.card)) return 'cardNotInHand';
        if (discardBlocked(s) && !legalMoves(s, seat).contains(m)) {
          return must != null ? 'mustUseTakenDiscard' : 'mustUseFreedWild';
        }
        return null;
      case RummyMoveKind.drawStock:
      case RummyMoveKind.takeDiscard:
      case RummyMoveKind.callRedeal:
      case RummyMoveKind.keepHand:
        return null;
    }
  }

  @override
  RummyMove moveFromJson(Map<String, Object?> json) => RummyMove.fromJson(json);

  // ------------------------------------------------------------ applying

  void _used(RummyState s, int seat, Iterable<PlayingCard> cards) {
    for (final c in cards) {
      s.hands[seat].remove(c);
      s.known[seat].remove(c);
      s.pendingWilds.remove(c);
      if (c == s.mustUse) s.mustUse = null;
    }
  }

  @override
  void apply(RummyState s, RummyMove m, [List<CardEvent>? ev]) {
    final seat = s.turn;
    final hand = s.hands[seat];
    final r = s.meldRules;
    switch (m.kind) {
      case RummyMoveKind.callRedeal:
        ev?.add(CardEvent(CardEventType.redeal, seat: seat, detail: 'pairs'));
        s.dealFromRng();
        ev?.add(CardEvent(CardEventType.dealt, seat: s.dealer, cards: [?s.indicator]));
      case RummyMoveKind.keepHand:
        ev?.add(CardEvent(CardEventType.pass, seat: seat, detail: 'keepHand'));
        final next = s.redealCandidate(after: seat);
        s.turn = next ?? s.starter;
        s.phase = next == null ? RummyPhase.play : RummyPhase.redealOffer;
      case RummyMoveKind.drawStock:
        var restocked = false;
        if (s.stock.isEmpty) {
          if (!_restock(s)) return _endRound(s, null, ev);
          restocked = true;
        }
        final card = s.stock.removeLast();
        hand
          ..add(card)
          ..sort();
        s.phase = RummyPhase.play;
        ev?.add(CardEvent(CardEventType.drewStock, seat: seat, cards: [card], detail: restocked ? 'restocked' : null));
      case RummyMoveKind.takeDiscard:
        final card = s.discardPile.removeLast();
        hand
          ..add(card)
          ..sort();
        s.known[seat].add(card);
        s.mustUse = card;
        s.phase = RummyPhase.play;
        ev?.add(CardEvent(CardEventType.tookDiscard, seat: seat, cards: [card]));
      case RummyMoveKind.open:
      case RummyMoveKind.meld:
        final plan = _layMelds(s, seat, m);
        final opening = m.kind == RummyMoveKind.open;
        if (opening) s.highestOpening = math.max(s.highestOpening, plan.value);
        s.opened[seat] = true;
        ev?.add(
          CardEvent(
            opening ? CardEventType.opened : CardEventType.melded,
            seat: seat,
            cards: m.meldCards,
            value: plan.value,
          ),
        );
      case RummyMoveKind.layoff:
        _layOff(s, seat, m.card!, m.target!, m.atLow, ev);
      case RummyMoveKind.swapJoker:
        final nats = [m.card!, ?m.card2];
        final t = m.target!;
        final (meld, wild) = r.swap(s.table[t], nats)!;
        s.table[t] = meld;
        _used(s, seat, nats);
        hand
          ..add(wild)
          ..sort();
        s.known[seat].add(wild);
        if (s.options.swappedWildMustBeUsed) s.pendingWilds.add(wild);
        if (t < s.tableAtTurnStart) {
          s.usedOldMelds = true;
          s.oldMeldCards.addAll(nats);
        }
        ev?.add(CardEvent(CardEventType.jokerSwapped, seat: seat, cards: [...nats, wild], value: t));
      case RummyMoveKind.finish:
        final plan = _layMelds(s, seat, m);
        s.opened[seat] = true;
        ev?.add(CardEvent(CardEventType.opened, seat: seat, cards: m.meldCards, value: plan.value));
        for (final l in m.layoffs) {
          _layOff(s, seat, l.card, l.target, l.atLow, ev);
        }
        _discard(s, seat, m.card!, ev);
      case RummyMoveKind.discard:
        _discard(s, seat, m.card!, ev);
    }
  }

  MeldPlan _layMelds(RummyState s, int seat, RummyMove m) {
    final r = s.meldRules;
    final melds = <Meld>[];
    for (var i = 0; i < m.melds.length; i++) {
      final meld = r.arrange(m.melds[i], owner: seat, wildLow: m.lowAt(i))!;
      _used(s, seat, meld.cards);
      s.table.add(meld);
      melds.add(meld);
    }
    return MeldPlan(melds);
  }

  void _layOff(RummyState s, int seat, PlayingCard card, int target, bool atLow, List<CardEvent>? ev) {
    s.table[target] = s.meldRules.withCard(s.table[target], card, atLow: atLow)!;
    _used(s, seat, [card]);
    if (target < s.tableAtTurnStart) {
      s.usedOldMelds = true;
      s.oldMeldCards.add(card);
    }
    ev?.add(CardEvent(CardEventType.laidOff, seat: seat, cards: [card], value: target));
  }

  void _discard(RummyState s, int seat, PlayingCard card, List<CardEvent>? ev) {
    _used(s, seat, [card]);
    s.mustUse = null;
    s.pendingWilds = [];
    s.discardPile.add(card);
    ev?.add(CardEvent(CardEventType.discarded, seat: seat, cards: [card]));
    if (s.hands[seat].isEmpty) return _endRound(s, seat, ev, lastDiscard: card);
    s.turnsTaken[seat]++;
    if (s.options.stockEnd == RummyStockEnd.voidAtPlayers && s.stock.length <= s.activeSeats.length) {
      return _endRound(s, null, ev);
    }
    _startTurn(s, s.nextActive(seat));
  }

  static void _startTurn(RummyState s, int seat) {
    s.turn = seat;
    s.phase = RummyPhase.draw;
    s.openAtTurnStart = s.opened[seat];
    s.tableAtTurnStart = s.table.length;
    s.usedOldMelds = false;
    s.oldMeldCards = [];
    s.pendingWilds = [];
    s.mustUse = null;
  }

  /// Refills an empty stock from the discards (all but the top card), or
  /// returns false when the round must be void.
  bool _restock(RummyState s) {
    final o = s.options;
    if (s.discardPile.length <= 1) return false;
    switch (o.stockEnd) {
      case RummyStockEnd.reshuffle:
        if (s.recycles >= o.maxStockRecycles) return false;
        final top = s.discardPile.removeLast();
        s.stock = s.discardPile;
        s.rng.shuffle(s.stock);
        s.discardPile = [top];
      case RummyStockEnd.flipNoShuffle:
        if (s.recycles >= RummyOptions.flipSafetyCap) return false;
        final top = s.discardPile.removeLast();
        // The pile turned face down: its bottom card is drawn first.
        s.stock = s.discardPile.reversed.toList();
        s.discardPile = [top];
      case RummyStockEnd.voidAtPlayers:
        return false;
    }
    s.recycles++;
    return true;
  }

  // ------------------------------------------------------------ scoring

  /// Bonus factor of a full hand (options): ×2 for a wild as the last
  /// discard, ×2 for one colour or ×4 for one suit (wilds excepted). The
  /// full hand is every card the winner put down this turn: its new melds,
  /// what it laid on older melds (when that still counts as a full hand) and
  /// the last discard.
  static int bonusFactor(RummyState s, int winner, PlayingCard? lastDiscard) {
    final o = s.options;
    final r = s.meldRules;
    var b = 1;
    if (o.bonusWildLastDiscard && lastDiscard != null && r.isWild(lastDiscard)) b *= 2;
    if (o.bonusOneColour || o.bonusOneSuit) {
      final cards = [
        for (var i = s.tableAtTurnStart; i < s.table.length; i++)
          if (s.table[i].owner == winner) ...s.table[i].cards,
        ...s.oldMeldCards,
        ?lastDiscard,
      ].where((c) => !r.isWild(c));
      final suits = cards.map(r.suitOf).toSet();
      bool red(Suit x) => x == Suit.hearts || x == Suit.diamonds;
      if (o.bonusOneSuit && suits.length <= 1) {
        b *= 4;
      } else if (o.bonusOneColour && (suits.every(red) || !suits.any(red))) {
        b *= 2;
      }
    }
    return b;
  }

  /// Points of a round: (each seat's own points, what is added to each
  /// seat's total). [winner] null: a void round.
  static (List<int>, List<int>) roundPoints(RummyState s, int? winner, {required bool handFinish, int bonus = 1}) {
    final o = s.options;
    final n = s.playerCount;
    final own = List.filled(n, 0);
    if (winner == null) return (own, List.filled(n, 0));
    final mult = handFinish ? o.handMultiplier * bonus : 1;
    int penalty(int p) => s.opened[p] ? s.handPenalty(p) : o.notOpenedPenalty;
    for (final p in s.activeSeats) {
      if (p != winner) own[p] = penalty(p) * mult;
    }
    own[winner] = handFinish ? o.handWinnerScore * bonus : o.winnerScore;
    if (!o.partnership) return (own, List.of(own));
    final partner = (winner + 2) % n;
    own[partner] = o.partnerOfWinnerPays ? penalty(partner) : 0;
    final team = [0, 0];
    for (var p = 0; p < n; p++) {
      team[p % 2] += own[p];
    }
    return (own, [for (var p = 0; p < n; p++) team[p % 2]]);
  }

  void _endRound(RummyState s, int? winner, List<CardEvent>? ev, {PlayingCard? lastDiscard}) {
    final o = s.options;
    final full = winner != null && !s.openAtTurnStart && (!o.fullHandOwnMeldsOnly || !s.usedOldMelds);
    final bonus = full ? bonusFactor(s, winner, lastDiscard) : 1;
    final (own, pts) = roundPoints(s, winner, handFinish: full, bonus: bonus);
    bool counted;
    if (winner != null) {
      counted = true;
      s.voidStreak = 0;
    } else {
      s.voidStreak++;
      counted = o.voidRoundsCount || s.voidStreak >= RummyOptions.maxVoidRepeats;
      if (counted) s.voidStreak = 0;
    }
    for (var i = 0; i < pts.length; i++) {
      s.seatScores[i] += pts[i];
    }
    final out = <int>[];
    if (winner != null && o.matchEnd == RummyMatchEnd.elimination) {
      final number = s.roundsPlayed + 1;
      for (final p in s.activeSeats) {
        if (s.seatScores[p] > o.eliminationScore) {
          s.eliminated[p] = true;
          s.eliminatedAt[p] = number;
          out.add(p);
        }
      }
    }
    s.results.add(
      RummyRoundResult(
        winner: winner,
        handFinish: full,
        points: pts,
        seatPoints: own,
        counted: counted,
        multiplier: bonus,
        eliminated: out,
      ),
    );
    ev?.add(
      CardEvent(
        CardEventType.roundScored,
        seat: winner,
        value: bonus,
        detail: winner == null ? 'void' : (full ? 'hand' : null),
      ),
    );
    for (final p in out) {
      ev?.add(CardEvent(CardEventType.playerFinished, seat: p, detail: 'eliminated'));
    }
    if (counted && _matchEnds(s)) {
      s.over = true;
      s.phase = RummyPhase.over;
      ev?.add(const CardEvent(CardEventType.matchOver));
      return;
    }
    if (winner != null) s.dealer = nextDealer(s, own);
    s.dealFromRng();
    ev?.add(CardEvent(CardEventType.dealt, seat: s.dealer, cards: [?s.indicator]));
  }

  /// Whether the match is over after a counted round (starting an extra
  /// round when players tie for the lowest total).
  static bool _matchEnds(RummyState s) {
    final o = s.options;
    if (o.matchEnd == RummyMatchEnd.elimination) return s.activeSeats.length <= 1;
    final reached =
        s.tieBreakRounds > 0 ||
        (o.matchEnd == RummyMatchEnd.rounds ? s.roundsPlayed >= o.rounds : s.seatScores.any((x) => x >= o.targetScore));
    if (!reached) return false;
    if (o.tieBreak == RummyTieBreak.shared || s.tieBreakRounds >= o.maxTieBreakRounds) return true;
    final best = s.seatScores.reduce(math.min);
    final teams = {
      for (var i = 0; i < s.playerCount; i++)
        if (s.seatScores[i] == best) s.teamOf(i),
    };
    if (teams.length <= 1) return true;
    s.tieBreakRounds++;
    return false;
  }

  /// Dealer of the next round after a scored round with seat points [own].
  static int nextDealer(RummyState s, List<int> own) {
    if (s.options.dealerRule == RummyDealerRule.rotate) return s.nextActive(s.dealer);
    final active = s.activeSeats;
    final worst = active.map((p) => own[p]).reduce(math.max);
    final tied = active.where((p) => own[p] == worst).toSet();
    if (tied.contains(s.dealer)) return s.dealer;
    for (var i = 1; i <= s.playerCount; i++) {
      final p = (s.dealer + i) % s.playerCount;
      if (tied.contains(p)) return p;
    }
    return s.nextActive(s.dealer);
  }
}

class RummyEngine extends RulesEngine<RummyState, RummyMove> {
  RummyEngine(RummyState state) : super(const RummyRules(), state);

  factory RummyEngine.newMatch({required RummyOptions options, required int seed}) =>
      RummyEngine(RummyState.newMatch(options: options, seed: seed));

  factory RummyEngine.fromJson(Map<String, Object?> json) => RummyEngine(RummyState.fromJson(json));
}

/// AI for the rummy games (Hand, Konkan): opening as soon as possible,
/// melding and laying off, discarding the least useful card while not
/// feeding the next player; hard searches the draw and discard decisions.
library;

import 'dart:math' as math;

import '../core/ai_base.dart';
import '../core/card_rng.dart';
import '../core/determinize.dart';
import '../core/playing_card.dart';
import 'rummy_meld.dart';
import 'rummy_rules.dart';
import 'rummy_state.dart';

/// Distance between two ranks, the ace counting high or low.
int rankDistance(PlayingCard a, PlayingCard b) {
  var d = (a.rank.value - b.rank.value).abs();
  if (a.rank == Rank.ace || b.rank == Rank.ace) {
    final av = a.rank == Rank.ace ? 1 : a.rank.value;
    final bv = b.rank == Rank.ace ? 1 : b.rank.value;
    d = math.min(d, (av - bv).abs());
  }
  return d;
}

class RummyAi extends HeuristicAi<RummyState, RummyMove> {
  const RummyAi() : super(const RummyRules());

  @override
  double get matchWinBonus => 150;

  @override
  int get maxRolloutMoves => 48;

  /// How much [seat] wants to keep [c] (low: discard it).
  double keepValue(RummyState s, int seat, PlayingCard c, {bool careful = true}) {
    if (c.isJoker) return 1000;
    final hand = s.hands[seat];
    var v = 0.0;
    for (final x in hand) {
      if (identical(x, c) || x.isJoker) continue;
      if (x.rank == c.rank && x.suit != c.suit) v += 8;
      if (x.suit == c.suit) {
        final d = rankDistance(x, c);
        if (d == 1) v += 7;
        if (d == 2) v += 3.5;
      }
    }
    v -= s.penaltyOf(c) * 0.45;
    if (careful) {
      final next = (seat + 1) % s.playerCount;
      // Do not feed the next player a card they can lay off or asked for.
      if (s.opened[next] && s.table.any((m) => m.withCard(c) != null)) v += 14;
      for (final k in s.known[next]) {
        if (k.isJoker) continue;
        if (k.rank == c.rank || (k.suit == c.suit && rankDistance(k, c) <= 2)) v += 5;
      }
    }
    return v;
  }

  RummyMove _bestDiscard(RummyState s, int seat, List<RummyMove> legal, {bool careful = true}) {
    final discards = legal.where((m) => m.kind == RummyMoveKind.discard).toList();
    if (discards.isEmpty) return legal.first;
    return bestBy(discards, (m) => -keepValue(s, seat, m.card!, careful: careful));
  }

  RummyMove _play(RummyState s, int seat, List<RummyMove> legal, {required bool careful}) {
    final hand = s.hands[seat];
    RummyMove? pick(RummyMoveKind kind, num Function(RummyMove) score) {
      final ms = legal.where((m) => m.kind == kind).toList();
      return ms.isEmpty ? null : bestBy<RummyMove>(ms, score);
    }

    final open = pick(
      RummyMoveKind.open,
      (m) => m.meldCards.length * 100 + MeldPlan([for (final cs in m.melds) Meld.arrange(cs)!]).value,
    );
    if (open != null) return open;
    final meld = pick(
      RummyMoveKind.meld,
      (m) => m.meldCards.length * 10 - m.meldCards.where((c) => c.isJoker).length * 6,
    );
    if (meld != null) return meld;
    final layoff = pick(
      RummyMoveKind.layoff,
      (m) => m.card!.isJoker ? (hand.length <= 3 ? 1 : -1000) : s.penaltyOf(m.card!).toDouble(),
    );
    if (layoff != null && (!layoff.card!.isJoker || hand.length <= 3)) return layoff;
    if (careful && hand.length >= 3) {
      final swap = pick(RummyMoveKind.swapJoker, (m) => 1);
      if (swap != null) return swap;
    }
    if (s.mustUse != null) {
      final use = legal.where((m) => m.kind != RummyMoveKind.discard).toList();
      if (use.isNotEmpty) return use.first;
    }
    return _bestDiscard(s, seat, legal, careful: careful);
  }

  @override
  RummyMove easyMove(RummyState s, int seat, List<RummyMove> legal, math.Random rng) {
    if (s.phase == RummyPhase.draw) {
      return legal.contains(const RummyMove.takeDiscard()) && rng.nextBool()
          ? const RummyMove.takeDiscard()
          : const RummyMove.drawStock();
    }
    return _play(s, seat, legal, careful: false);
  }

  @override
  RummyMove mediumMove(RummyState s, int seat, List<RummyMove> legal, math.Random rng) {
    if (s.phase == RummyPhase.draw) {
      return legal.contains(const RummyMove.takeDiscard())
          ? const RummyMove.takeDiscard()
          : const RummyMove.drawStock();
    }
    return _play(s, seat, legal, careful: true);
  }

  @override
  List<RummyMove> hardCandidates(RummyState s, int seat, List<RummyMove> legal, RummyMove prior) {
    if (s.phase == RummyPhase.draw) return legal;
    if (prior.kind == RummyMoveKind.discard) {
      final discards = legal.where((m) => m.kind == RummyMoveKind.discard).toList()
        ..sort((a, b) => keepValue(s, seat, a.card!).compareTo(keepValue(s, seat, b.card!)));
      final top = discards.take(4).toList();
      if (!top.contains(prior)) top.insert(0, prior);
      return top;
    }
    if (prior.kind == RummyMoveKind.open && s.mustUse == null) {
      // Open now, or wait for a bigger lay-down (a "hand")?
      return [prior, _bestDiscard(s, seat, legal)];
    }
    return [prior];
  }

  /// Rough penalty [seat] is heading for (used when a rollout is cut short):
  /// the cards left for an opened player; for a closed hand most of the
  /// not-opened penalty, a little less the closer it is to opening.
  double _estimate(RummyState s, int seat) {
    if (s.opened[seat]) return s.handPenalty(seat).toDouble();
    final plan = bestPlan(s.hands[seat], keep: 1, nodeCap: 600);
    final progress = math.min(plan.value, s.options.openingThreshold) / s.options.openingThreshold;
    return math.max(s.handPenalty(seat).toDouble(), s.options.notOpenedPenalty * (1 - 0.25 * progress));
  }

  @override
  double evaluate(RummyState root, RummyState s, int observer) {
    if (s.isOver || s.dealNumber != root.dealNumber) return super.evaluate(root, s, observer);
    var opp = 0.0;
    for (var p = 0; p < s.playerCount; p++) {
      if (p != observer) opp += _estimate(s, p);
    }
    return opp / (s.playerCount - 1) - _estimate(s, observer);
  }

  @override
  RummyState determinize(RummyState s, int observer, math.Random rng) {
    final w = s.copy()
      // Future shuffles must not leak into the search.
      ..rng = CardRng(rng.nextInt(0x7fffffff));
    final others = [
      for (var i = 0; i < s.playerCount; i++)
        if (i != observer) i,
    ];
    final seen = [
      ...s.hands[observer],
      ...s.discardPile,
      for (final m in s.table) ...m.cards,
      for (final o in others) ...s.known[o],
    ];
    final pool = cardsMinus(s.fullDeck(), seen);
    final counts = [for (final o in others) s.hands[o].length - s.known[o].length, s.stock.length];
    final dealt = dealConstrained(pool, counts, (h, c) => true, rng);
    for (var i = 0; i < others.length; i++) {
      w.hands[others[i]] = [...s.known[others[i]], ...dealt[i]]..sort();
    }
    w.stock = dealt.last;
    return w;
  }
}

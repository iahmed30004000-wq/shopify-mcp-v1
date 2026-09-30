/// AI for the rummy games (Hand, Konkan): going out in one move when it
/// can, opening as soon as possible, melding and laying off, discarding the
/// least useful card while not feeding the next player; hard searches the
/// draw, open-or-wait and discard decisions over sampled deals.
library;

import 'dart:math' as math;

import '../core/ai_base.dart';
import '../core/card_rng.dart';
import '../core/determinize.dart';
import '../core/playing_card.dart';
import 'rummy_meld.dart';
import 'rummy_rules.dart';
import 'rummy_state.dart';

int _rankGap(Rank a, Rank b) {
  var d = (a.value - b.value).abs();
  if (a == Rank.ace || b == Rank.ace) {
    final av = a == Rank.ace ? 1 : a.value;
    final bv = b == Rank.ace ? 1 : b.value;
    d = math.min(d, (av - bv).abs());
  }
  return d;
}

/// Distance between the ranks of two natural cards, the ace counting high or
/// low.
int rankDistance(PlayingCard a, PlayingCard b) => _rankGap(a.rank, b.rank);

class RummyAi extends HeuristicAi<RummyState, RummyMove> {
  const RummyAi() : super(const RummyRules());

  @override
  double get matchWinBonus => 150;

  @override
  int get maxRolloutMoves => 48;

  /// Extra weight on card penalties when a high score is dangerous (Konkan
  /// elimination: an unopened hand would knock this seat out).
  double _danger(RummyState s, int seat) {
    final o = s.options;
    if (o.matchEnd != RummyMatchEnd.elimination) return 0;
    return s.seatScores[seat] + o.notOpenedPenalty > o.eliminationScore ? 0.6 : 0;
  }

  /// How much [seat] wants to keep [c] (low: discard it).
  double keepValue(RummyState s, int seat, PlayingCard c, {bool careful = true}) {
    final r = s.meldRules;
    if (r.isWild(c)) return 1000;
    final rank = r.rankOf(c);
    final suit = r.suitOf(c);
    var v = 0.0;
    for (final x in s.hands[seat]) {
      if (x == c || r.isWild(x)) continue;
      final xs = r.suitOf(x);
      if (r.rankOf(x) == rank && xs != suit) v += 8;
      if (xs == suit) {
        final d = _rankGap(r.rankOf(x), rank);
        if (d == 1) v += 7;
        if (d == 2) v += 3.5;
      }
    }
    v -= s.penaltyOf(c) * (0.45 + _danger(s, seat));
    if (careful) {
      final next = s.nextActive(seat);
      // Old rule set: the next player could take it to lay it off.
      if (s.options.discardUse == RummyDiscardUse.any &&
          s.opened[next] &&
          s.table.any((m) => r.withCard(m, c) != null)) {
        v += 14;
      }
      // Do not feed a card that makes a meld with cards the next player is
      // known to hold.
      for (final k in s.known[next]) {
        if (r.isWild(k)) continue;
        if (r.rankOf(k) == rank || (r.suitOf(k) == suit && _rankGap(r.rankOf(k), rank) <= 2)) v += 5;
      }
    }
    return v;
  }

  RummyMove _bestDiscard(RummyState s, int seat, List<RummyMove> legal, {bool careful = true}) {
    final discards = legal.where((m) => m.kind == RummyMoveKind.discard).toList();
    if (discards.isEmpty) return legal.first;
    return bestBy(discards, (m) => -keepValue(s, seat, m.card!, careful: careful));
  }

  /// Copies of the natural card that would free the end wild of a run (the
  /// more of them are visible, the safer the wild is from a swap).
  int _swapSafety(RummyState s, int seat, Meld m) {
    if (m.kind != MeldKind.run || m.wilds == 0) return 0;
    final r = s.meldRules;
    var safe = 0;
    for (var i = 0; i < m.cards.length; i++) {
      if (!m.isWildAt(i)) continue;
      final p = m.low + i;
      final rank = p == 1 || p == 14 ? Rank.ace : Rank.fromValue(p);
      final natural = PlayingCard(m.suit!, rank);
      if (r.isWild(natural)) continue;
      bool isIt(PlayingCard c) => c == natural;
      safe += s.discardPile.where(isIt).length + s.hands[seat].where(isIt).length;
      for (final t in s.table) {
        safe += t.cards.where(isIt).length;
      }
    }
    return safe;
  }

  List<Meld> _melds(RummyState s, RummyMove m) => [
    for (var i = 0; i < m.melds.length; i++) s.meldRules.arrange(m.melds[i], wildLow: m.lowAt(i))!,
  ];

  /// Whether a wild freed by [swap] could be laid down again this turn
  /// (needed with `swappedWildMustBeUsed`).
  bool _swapUsable(RummyState s, int seat, RummyMove swap) {
    if (!s.options.swappedWildMustBeUsed) return true;
    final w = s.copy();
    rules.apply(w, swap);
    final wild = w.hands[seat].where(w.meldRules.isWild).toList();
    return RummyRules.layDownMoves(
      w,
      seat,
    ).any((m) => m.card != null && wild.contains(m.card) || m.meldCards.any(wild.contains));
  }

  RummyMove _play(RummyState s, int seat, List<RummyMove> legal, {required bool careful}) {
    final r = s.meldRules;
    final o = s.options;
    final hand = s.hands[seat];
    RummyMove? pick(RummyMoveKind kind, num Function(RummyMove) score, [bool Function(RummyMove)? where]) {
      final ms = legal.where((m) => m.kind == kind && (where == null || where(m))).toList();
      return ms.isEmpty ? null : bestBy<RummyMove>(ms, score);
    }

    // Going out in one move: a full hand (no lay-offs) first.
    final finish = pick(
      RummyMoveKind.finish,
      (m) => -m.layoffs.length * 10 + (o.bonusWildLastDiscard && r.isWild(m.card!) ? 5 : 0),
    );
    if (finish != null) return finish;
    final open = pick(RummyMoveKind.open, (m) {
      final melds = _melds(s, m);
      final value = MeldPlan(melds).value;
      final safety = melds.fold<int>(0, (a, x) => a + _swapSafety(s, seat, x));
      return m.meldCards.length * 100 + value * 0.1 + safety;
    });
    if (open != null) return open;
    final meld = pick(RummyMoveKind.meld, (m) {
      final x = _melds(s, m).single;
      return m.meldCards.length * 10 - x.wilds * 6 + _swapSafety(s, seat, x) * 0.5;
    });
    if (meld != null) return meld;
    final pendingWild = o.swappedWildMustBeUsed && s.pendingWilds.isNotEmpty;
    final layoff = pick(
      RummyMoveKind.layoff,
      (m) => r.isWild(m.card!) ? (hand.length <= 3 || pendingWild ? 1 : -1000) : s.penaltyOf(m.card!),
    );
    if (layoff != null && (!r.isWild(layoff.card!) || hand.length <= 3 || pendingWild)) return layoff;
    if (careful && hand.length >= 3) {
      final swap = pick(RummyMoveKind.swapJoker, (m) => m.card2 == null ? 1 : 2, (m) => _swapUsable(s, seat, m));
      if (swap != null) return swap;
    }
    if (!legal.any((m) => m.kind == RummyMoveKind.discard)) {
      // A taken discard or a freed wild must be laid down first.
      return legal.first;
    }
    return _bestDiscard(s, seat, legal, careful: careful);
  }

  /// A hand dealt with enough identical pairs is thrown in when it is weak.
  bool _wantsRedeal(RummyState s, int seat) => bestPlan(s.hands[seat], s.meldRules, keep: 1, nodeCap: 600).value < 30;

  @override
  RummyMove easyMove(RummyState s, int seat, List<RummyMove> legal, math.Random rng) {
    switch (s.phase) {
      case RummyPhase.redealOffer:
        return const RummyMove.keepHand();
      case RummyPhase.draw:
        return legal.contains(const RummyMove.takeDiscard()) && rng.nextBool()
            ? const RummyMove.takeDiscard()
            : const RummyMove.drawStock();
      case RummyPhase.play:
      case RummyPhase.over:
        return _play(s, seat, legal, careful: false);
    }
  }

  @override
  RummyMove mediumMove(RummyState s, int seat, List<RummyMove> legal, math.Random rng) {
    switch (s.phase) {
      case RummyPhase.redealOffer:
        return _wantsRedeal(s, seat) ? const RummyMove.callRedeal() : const RummyMove.keepHand();
      case RummyPhase.draw:
        return legal.contains(const RummyMove.takeDiscard())
            ? const RummyMove.takeDiscard()
            : const RummyMove.drawStock();
      case RummyPhase.play:
      case RummyPhase.over:
        return _play(s, seat, legal, careful: true);
    }
  }

  @override
  List<RummyMove> hardCandidates(RummyState s, int seat, List<RummyMove> legal, RummyMove prior) {
    if (s.phase == RummyPhase.draw) return legal;
    if (s.phase != RummyPhase.play) return [prior];
    if (prior.kind == RummyMoveKind.discard) {
      final discards = legal.where((m) => m.kind == RummyMoveKind.discard).toList()
        ..sort((a, b) => keepValue(s, seat, a.card!).compareTo(keepValue(s, seat, b.card!)));
      final top = discards.take(4).toList();
      if (!top.contains(prior)) top.insert(0, prior);
      return top;
    }
    if (prior.kind == RummyMoveKind.open && s.mustUse == null) {
      // Open now, or wait for a bigger lay-down (a full hand)?
      final wait = _bestDiscard(s, seat, legal);
      return wait.kind == RummyMoveKind.discard ? [prior, wait] : [prior];
    }
    return [prior];
  }

  /// Rough penalty [seat] is heading for (used when a rollout is cut short):
  /// the cards left for an opened player; for a closed hand most of the
  /// not-opened penalty, a little less the closer it is to opening.
  double _estimate(RummyState s, int seat) {
    if (s.opened[seat]) return s.handPenalty(seat).toDouble();
    final plan = bestPlan(s.hands[seat], s.meldRules, keep: 1, nodeCap: 600);
    final threshold = s.options.openingThreshold;
    final progress = math.min(plan.value, threshold) / threshold;
    return math.max(s.handPenalty(seat).toDouble(), s.options.notOpenedPenalty * (1 - 0.25 * progress));
  }

  @override
  double evaluate(RummyState root, RummyState s, int observer) {
    if (s.isOver || s.dealNumber != root.dealNumber) return super.evaluate(root, s, observer);
    final team = s.teamOf(observer);
    var own = 0.0;
    var opp = 0.0;
    var nOwn = 0;
    var nOpp = 0;
    for (final p in s.activeSeats) {
      final e = _estimate(s, p);
      if (s.teamOf(p) == team) {
        own += e;
        nOwn++;
      } else {
        opp += e;
        nOpp++;
      }
    }
    return (nOpp == 0 ? 0 : opp / nOpp) - own / math.max(1, nOwn);
  }

  @override
  RummyState determinize(RummyState s, int observer, math.Random rng) {
    final w = s.copy()
      // Future shuffles must not leak into the search.
      ..rng = CardRng(rng.nextInt(0x7fffffff));
    final others = [
      for (final p in s.activeSeats)
        if (p != observer) p,
    ];
    final seen = [
      ...s.hands[observer],
      ...s.discardPile,
      for (final m in s.table) ...m.cards,
      for (final o in others) ...s.known[o],
      ?s.indicator,
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

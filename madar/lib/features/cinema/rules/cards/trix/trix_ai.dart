/// Trix AI: contract choice, doubling, ducking play in the negative
/// contracts and blocking play on the trix layout.
library;

import 'dart:math' as math;

import '../core/ai_base.dart';
import '../core/card_rng.dart';
import '../core/determinize.dart';
import '../core/playing_card.dart';
import '../core/trick.dart';
import 'trix_rules.dart';
import 'trix_state.dart';

/// Rough expected points of [hand] in contract [c] (for choosing contracts).
double trixContractEstimate(TrixContract c, List<PlayingCard> hand) {
  int len(Suit s) => ofSuit(hand, s).length;
  bool has(Suit s, Rank r) => hand.contains(PlayingCard(s, r));
  final aces = hand.where((x) => x.rank == Rank.ace).length;
  final kings = hand.where((x) => x.rank == Rank.king).length;
  final queens = hand.where((x) => x.rank == Rank.queen).length;
  final lows = hand.where((x) => x.rank.value <= 5).length;
  switch (c) {
    case TrixContract.king:
      if (hand.contains(kingOfHearts)) {
        final h = len(Suit.hearts);
        final p = h >= 6 ? 0.2 : (h >= 4 ? 0.4 : (h >= 2 ? 0.65 : 0.85));
        return -75 * p;
      }
      return -75 * 0.25 * (1 + (aces + kings - 2) / 6).clamp(0.4, 1.6);
    case TrixContract.queens:
      var risk = 0.0;
      for (final s in Suit.values) {
        if (has(s, Rank.queen)) {
          risk += (len(s) >= 4 && !has(s, Rank.ace) && !has(s, Rank.king)) ? 0.3 : 0.65;
        } else {
          risk += (has(s, Rank.ace) || has(s, Rank.king)) ? 0.35 : 0.15;
        }
      }
      return -25 * risk;
    case TrixContract.diamonds:
      final d = ofSuit(hand, Suit.diamonds).toList();
      final high = d.where((x) => x.rank.value >= 10).length;
      final est = (3.25 + (high - 1.25) * 1.2 - (d.length >= 5 ? 0.5 : 0) + (aces - 1) * 0.3).clamp(0.0, 13.0);
      return -10 * est;
    case TrixContract.ltoush:
      final est = (3.25 + (aces - 1) * 0.9 + (kings - 1) * 0.6 + (queens - 1) * 0.3 - (lows - 5) * 0.2).clamp(0.0, 13.0);
      return -15 * est;
    case TrixContract.trix:
      final jacks = hand.where((x) => x.rank == Rank.jack).length;
      final spread = hand.fold<int>(0, (a, x) => a + (x.rank.value - 11).abs()) / hand.length;
      return (125 + 30 * (jacks - 1) - (spread - 3.5) * 25).clamp(50, 200).toDouble();
    case TrixContract.complex:
      return trixContractEstimate(TrixContract.king, hand) +
          trixContractEstimate(TrixContract.queens, hand) +
          trixContractEstimate(TrixContract.diamonds, hand) +
          trixContractEstimate(TrixContract.ltoush, hand);
  }
}

const Map<TrixContract, double> _baseline = {
  TrixContract.king: -18.75,
  TrixContract.queens: -25,
  TrixContract.diamonds: -32.5,
  TrixContract.ltoush: -48.75,
  TrixContract.trix: 125,
  TrixContract.complex: -125,
};

class TrixAi extends HeuristicAi<TrixState, TrixMove> {
  const TrixAi() : super(const TrixRules());

  @override
  double get matchWinBonus => 150;

  // --------------------------------------------------------------- choices

  TrixMove _contract(TrixState s, int seat, List<TrixMove> legal, {math.Random? noise}) => bestBy(legal, (m) {
    final c = m.contract!;
    var v = trixContractEstimate(c, s.hands[seat]) - _baseline[c]!;
    if (noise != null) v += noise.nextDouble() * 60 - 30;
    return v;
  });

  TrixMove _double(TrixState s, int seat) {
    final hand = s.hands[seat];
    final pick = <PlayingCard>[];
    for (final c in TrixRules.doublable(s, seat)) {
      final suitLen = ofSuit(hand, c.suit).length;
      if (c == kingOfHearts) {
        if (suitLen >= 5) pick.add(c);
      } else if (suitLen >= 4 &&
          !hand.contains(PlayingCard(c.suit, Rank.ace)) &&
          !hand.contains(PlayingCard(c.suit, Rank.king))) {
        pick.add(c);
      }
    }
    return TrixMove.double(pick);
  }

  // ------------------------------------------------------------ trick play

  int _penalty(TrixState s, PlayingCard c) {
    final o = s.options;
    final mult = s.doubled.containsKey(c) ? 2 : 1;
    var p = 0;
    if (TrixRules.hasKing(s.contract) && c == kingOfHearts) p += o.kingPenalty * mult;
    if (TrixRules.hasQueens(s.contract) && c.rank == Rank.queen) p += o.queenPenalty * mult;
    if (TrixRules.hasDiamonds(s.contract) && c.suit == Suit.diamonds) p += o.diamondPenalty;
    return p;
  }

  PlayingCard _trickMedium(TrixState s, int seat) {
    final hand = s.hands[seat];
    final legal = TrixRules.trickPlayable(s, hand);
    if (legal.length == 1) return legal.first;
    final trick = s.trick!;
    final played = s.playedCards.toSet();
    bool unseen(PlayingCard c) => !played.contains(c) && !hand.contains(c);
    final trickCost = TrixRules.hasTricks(s.contract) ? s.options.trickPenalty : 0;
    if (trick.isEmpty) {
      return bestBy(legal, (c) {
        var higher = 0;
        var lower = 0;
        for (final r in Rank.values) {
          final x = PlayingCard(c.suit, r);
          if (!unseen(x)) continue;
          if (r.value > c.rank.value) {
            higher++;
          } else {
            lower++;
          }
        }
        final winChance = higher == 0 ? 1.0 : (lower + higher == 0 ? 1.0 : 0.6 * lower / (lower + higher));
        // Penalty cards still out in this suit that my lead may flush.
        var flush = 0.0;
        for (final r in Rank.values) {
          final x = PlayingCard(c.suit, r);
          if (unseen(x) && r.value > c.rank.value) flush += _penalty(s, x);
        }
        final cost = winChance * (trickCost + _penalty(s, c) + 12) + _penalty(s, c) * 0.6 - flush * 0.08;
        return -cost;
      });
    }
    final led = trick.ledSuit!;
    final winIdx = trick.winningIndex((c, l) => standardPower(c, l, null));
    final winCard = trick.cards[winIdx];
    final partnerWinning = s.options.partnership && trick.seats[winIdx] % 2 == seat % 2;
    final last = trick.length == 3;
    if (legal.first.suit == led && legal.every((c) => c.suit == led)) {
      final under = legal.where((c) => c.rank.value < winCard.rank.value).toList();
      if (under.isNotEmpty) return bestBy(under, (c) => c.rank.value + _penalty(s, c) * 0.01);
      if (last) {
        final clean = legal.where((c) => _penalty(s, c) == 0).toList();
        return bestBy(clean.isNotEmpty ? clean : legal, (c) => c.rank.value - _penalty(s, c));
      }
      return bestBy(legal, (c) => -c.rank.value - _penalty(s, c));
    }
    // Discarding.
    if (partnerWinning) {
      final clean = legal.where((c) => _penalty(s, c) == 0).toList();
      if (clean.isNotEmpty) return bestBy(clean, (c) => c.rank.value);
    }
    return bestBy(legal, (c) {
      final suitLen = ofSuit(hand, c.suit).length;
      return _penalty(s, c) * 10 + c.rank.value * 2 - suitLen;
    });
  }

  PlayingCard _trickEasy(TrixState s, int seat) {
    final legal = TrixRules.trickPlayable(s, s.hands[seat]);
    final trick = s.trick!;
    if (trick.isEmpty) return bestBy(legal, (c) => -c.rank.value);
    final led = trick.ledSuit!;
    if (legal.every((c) => c.suit == led)) return bestBy(legal, (c) => -c.rank.value);
    return bestBy(legal, (c) => _penalty(s, c) * 10 + c.rank.value);
  }

  // ---------------------------------------------------------------- layout

  PlayingCard _layoutMedium(TrixState s, int seat, List<PlayingCard> playable) {
    final hand = s.hands[seat].toSet();
    final played = s.layoutCards.toSet();
    return bestBy(playable, (c) {
      final v = c.rank.value;
      var score = 0.0;
      // Neighbours this play opens: my own chain is good, others' cards bad.
      final dirs = c.rank == Rank.jack && s.layoutLow[c.suit.index] == 0 ? [-1, 1] : [v < 11 ? -1 : 1];
      for (final d in dirs) {
        var next = v + d;
        var mine = true;
        while (next >= 2 && next <= 14) {
          final x = PlayingCard(c.suit, Rank.fromValue(next));
          if (played.contains(x)) break;
          if (hand.contains(x) && mine) {
            score += 2;
          } else {
            if (mine) score -= 1.5;
            mine = false;
            break;
          }
          next += d;
        }
      }
      // Get rid of cards far from the jack early (they block me later).
      score += (v - 11).abs() * 0.05;
      return score;
    });
  }

  // ------------------------------------------------------------ AI levels

  @override
  TrixMove easyMove(TrixState s, int seat, List<TrixMove> legal, math.Random rng) {
    switch (s.phase) {
      case TrixPhase.contract:
        return _contract(s, seat, legal, noise: rng);
      case TrixPhase.doubling:
        return TrixMove.double(const []);
      case TrixPhase.tricks:
        return TrixMove.play(_trickEasy(s, seat));
      case TrixPhase.layout:
        return legal[rng.nextInt(legal.length)];
      case TrixPhase.over:
        return legal.first;
    }
  }

  @override
  TrixMove mediumMove(TrixState s, int seat, List<TrixMove> legal, math.Random rng) {
    switch (s.phase) {
      case TrixPhase.contract:
        return _contract(s, seat, legal);
      case TrixPhase.doubling:
        return _double(s, seat);
      case TrixPhase.tricks:
        return TrixMove.play(_trickMedium(s, seat));
      case TrixPhase.layout:
        if (legal.first.kind == TrixMoveKind.pass) return legal.first;
        return TrixMove.play(_layoutMedium(s, seat, [for (final m in legal) m.card!]));
      case TrixPhase.over:
        return legal.first;
    }
  }

  @override
  TrixState determinize(TrixState s, int observer, math.Random rng) {
    final w = s.copy()
      // Future shuffles must not leak into the search.
      ..rng = CardRng(rng.nextInt(0x7fffffff));
    final others = [for (var i = 0; i < 4; i++) if (i != observer) i];
    final seen = <PlayingCard>{...s.hands[observer], ...s.playedCards};
    // Publicly doubled cards still in hand stay with their doubler.
    final fixed = [for (var i = 0; i < 4; i++) <PlayingCard>[]];
    for (final e in s.doubled.entries) {
      if (e.value != observer && !seen.contains(e.key)) fixed[e.value].add(e.key);
    }
    final fixedAll = {for (final f in fixed) ...f};
    final pool = [
      for (final c in s.fullDeck())
        if (!seen.contains(c) && !fixedAll.contains(c)) c,
    ];
    final allTricks = [...s.tricks, if (s.trick != null) s.trick!];
    final voids = voidsFromTricks(allTricks, 4);
    final noKing = List.filled(4, false);
    if (TrixRules.hasKing(s.contract)) {
      for (final t in allTricks) {
        if (t.cards.isEmpty) continue;
        final led = t.cards.first.suit;
        if (s.options.noHeartLeadInKing && led == Suit.hearts) {
          voids[t.leader].addAll([Suit.clubs, Suit.diamonds, Suit.spades]);
        }
        for (var i = 1; i < t.cards.length; i++) {
          if (s.options.kingMustBeDiscarded && t.cards[i].suit != led && t.cards[i] != kingOfHearts) {
            noKing[t.seats[i]] = true;
          }
        }
      }
    }
    bool canHold(int h, PlayingCard c) {
      final seat = others[h];
      if (voids[seat].contains(c.suit)) return false;
      if (s.cannotHold[seat].contains(c)) return false;
      if (noKing[seat] && c == kingOfHearts) return false;
      return true;
    }

    final dealt = dealConstrained(pool, [for (final o in others) s.hands[o].length - fixed[o].length], canHold, rng);
    for (var i = 0; i < others.length; i++) {
      w.hands[others[i]] = [...fixed[others[i]], ...dealt[i]]..sort();
    }
    return w;
  }
}

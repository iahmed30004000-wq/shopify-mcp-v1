// Scratch probes (reviewer).
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/cinema/rules/cards/cards.dart';
import 'package:madar/features/cinema/rules/cards/core/trick.dart' show Trick;

PlayingCard p(String id) => PlayingCard.parse(id);
final kh = p('KH');
final ah = p('AH');

int winnerOf(Trick t) {
  final led = t.cards.first.suit;
  var best = 0;
  for (var i = 1; i < t.cards.length; i++) {
    if (t.cards[i].suit == led && t.cards[i].rank.value > t.cards[best].rank.value) best = i;
  }
  return t.seats[best];
}

/// Independent referee: the legal cards of a trick turn, from the spec text.
Set<PlayingCard> refTrickLegal(TrixState s, int seat) {
  final o = s.options;
  final hand = s.hands[seat];
  final kingRules =
      s.contract == TrixContract.king || (s.contract == TrixContract.complex && o.kingRulesInComplex);
  final t = s.trick!;
  if (t.cards.isEmpty) {
    if (kingRules && o.noHeartLeadInKing && hand.any((c) => c.suit != Suit.hearts)) {
      return hand.where((c) => c.suit != Suit.hearts).toSet();
    }
    return hand.toSet();
  }
  final led = t.cards.first.suit;
  final follow = hand.where((c) => c.suit == led).toSet();
  if (follow.isNotEmpty) {
    if (kingRules && o.kingOnAceOfHearts && led == Suit.hearts && t.cards.contains(ah) && hand.contains(kh)) {
      return {kh};
    }
    return follow;
  }
  if (kingRules && o.kingMustBeDiscarded && hand.contains(kh)) return {kh};
  return hand.toSet();
}

Set<PlayingCard> refLayoutLegal(TrixState s, int seat) {
  final down = s.layoutCards.toSet();
  bool isDown(Suit su, int v) => down.contains(PlayingCard(su, Rank.fromValue(v)));
  final out = <PlayingCard>{};
  for (final c in s.hands[seat]) {
    final v = c.rank.value;
    if (c.rank == Rank.jack) {
      out.add(c);
    } else if (v < 11 && isDown(c.suit, v + 1)) {
      out.add(c);
    } else if (v > 11 && isDown(c.suit, v - 1)) {
      out.add(c);
    }
  }
  return out;
}

/// Independent referee: points of a finished trick deal (spec §6.2).
List<int> refPoints(TrixOptions o, TrixContract k, List<Trick> tricks, Map<PlayingCard, int> doubled) {
  final pts = List.filled(4, 0);
  int team(int x) => o.partnership ? x % 2 : x;
  final king = k == TrixContract.king || k == TrixContract.complex;
  final queens = k == TrixContract.queens || k == TrixContract.complex;
  final diamonds = k == TrixContract.diamonds || k == TrixContract.complex;
  final ltoush = k == TrixContract.ltoush || k == TrixContract.complex;
  for (final t in tricks) {
    final w = winnerOf(t);
    if (ltoush) pts[w] -= o.trickPenalty;
    for (final card in t.cards) {
      if (diamonds && card.suit == Suit.diamonds) pts[w] -= o.diamondPenalty;
      int? v;
      if (king && card == kh) v = o.kingPenalty;
      if (queens && card.rank == Rank.queen) v = o.queenPenalty;
      if (v == null) continue;
      final d = doubled[card];
      final l = t.leader;
      if (d == null) {
        pts[w] -= v;
      } else if (team(w) != team(d)) {
        pts[w] -= 2 * v;
        pts[d] += v;
      } else if (!o.partnership) {
        final selfLed = l == d;
        switch (o.selfCaptureRule) {
          case TrixSelfCapture.leaderGains:
            if (selfLed) {
              pts[w] -= v;
            } else {
              pts[w] -= 2 * v;
              pts[l] += v;
            }
          case TrixSelfCapture.leaderGainsStrict:
            pts[w] -= 2 * v;
            if (!selfLed) pts[l] += v;
          case TrixSelfCapture.normalValue:
            pts[w] -= v;
          case TrixSelfCapture.doubleNoBonus:
            pts[w] -= 2 * v;
        }
      } else {
        switch (o.partnerCaptureRule) {
          case TrixPartnerCapture.noBonus:
            pts[w] -= 2 * v;
          case TrixPartnerCapture.normalValue:
            pts[w] -= v;
          case TrixPartnerCapture.opponentsGain:
            if (w == d && l == d) {
              pts[w] -= v;
            } else {
              pts[w] -= 2 * v;
              pts[team(l) != team(d) ? l : (l + 1) % 4] += v;
            }
        }
      }
    }
  }
  return pts;
}

void main() {
  test('referee fuzz', () {
    final rng = CardRng(99);
    var deals = 0;
    var doubledDeals = 0;
    for (var game = 0; game < 60; game++) {
      final o = TrixOptions(
        partnership: rng.nextBool(),
        mode: rng.nextBool() ? TrixMode.classic : TrixMode.complex,
        doubling: rng.nextInt(5) != 0,
        noHeartLeadInKing: rng.nextBool(),
        kingMustBeDiscarded: rng.nextBool(),
        kingOnAceOfHearts: rng.nextBool(),
        kingRulesInComplex: rng.nextBool(),
        firstOwnerRule: rng.nextBool() ? TrixFirstOwner.sevenOfHearts : TrixFirstOwner.fixedSeat,
        firstOwner: rng.nextInt(4),
        doublingReveal: rng.nextBool() ? TrixDoublingReveal.simultaneous : TrixDoublingReveal.sequential,
        selfCaptureRule: TrixSelfCapture.values[rng.nextInt(4)],
        partnerCaptureRule: TrixPartnerCapture.values[rng.nextInt(3)],
      );
      final e = TrixEngine.newMatch(seed: game, options: o);
      if (o.firstOwnerRule == TrixFirstOwner.sevenOfHearts) {
        expect(e.state.hands[e.state.owner], contains(p('7H')));
      } else {
        expect(e.state.owner, o.firstOwner);
      }
      var guard = 0;
      while (!e.isOver) {
        final s = e.state;
        final seat = e.currentPlayer!;
        final legal = e.legalMoves(seat);
        if (s.phase == TrixPhase.tricks) {
          expect(legal.map((m) => m.card).toSet(), refTrickLegal(s, seat));
          for (final c in s.hands[seat]) {
            final ok = legal.contains(TrixMove.play(c));
            expect(e.validate(TrixMove.play(c)) == null, ok);
          }
        } else if (s.phase == TrixPhase.layout) {
          final ref = refLayoutLegal(s, seat);
          if (ref.isEmpty) {
            expect(legal, [const TrixMove.pass()]);
          } else {
            expect(legal.map((m) => m.card).toSet(), ref);
          }
        }
        final m = legal[rng.nextInt(legal.length)];
        final pre = s.copy();
        e.apply(m);
        if (e.state.dealsPlayed > pre.dealsPlayed) {
          deals++;
          final r = e.state.results.last;
          if (pre.contract == TrixContract.trix) {
            final order = [...pre.finished, seat];
            order.add([0, 1, 2, 3].firstWhere((x) => !order.contains(x)));
            final ref = List.filled(4, 0);
            for (var i = 0; i < 4; i++) {
              ref[order[i]] += o.trixScores[i];
            }
            expect(r.points, ref);
          } else {
            final last = pre.trick!.copy()..add(seat, m.card!);
            final tricks = [...pre.tricks, last];
            if (pre.doubled.isNotEmpty) doubledDeals++;
            expect(r.points, refPoints(o, pre.contract!, tricks, pre.doubled), reason: '$o');
          }
        }
        if (++guard > 3000) fail('no end');
      }
    }
    // ignore: avoid_print
    print('deals $deals doubled $doubledDeals');
  });
}

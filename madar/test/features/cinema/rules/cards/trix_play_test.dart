// Trix self-play for every Jordanian preset and house-rule set at every AI
// level, with the scoring invariants of RULES.md §2 ("Invariants") checked
// on every deal; an independent referee (legal moves, turns and every seat's
// points from the RULES.md text) over random house rules; hidden-doubling
// fairness of the AIs; deterministic replay; the AI levels in order.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/cinema/rules/cards/cards.dart';
import 'package:madar/features/cinema/rules/cards/core/trick.dart' show standardPower;

PlayingCard p(String id) => PlayingCard.parse(id);
int sum(Iterable<int> xs) => xs.fold(0, (a, b) => a + b);

final variants = <String, TrixOptions>{
  'تركس (jordan)': const TrixOptions(),
  'تركس شراكة': const TrixOptions.jordan(partnership: true),
  'تركس كومبلكس': const TrixOptions.jordan(mode: TrixMode.complex),
  'كومبلكس شراكة': const TrixOptions.jordan(mode: TrixMode.complex, partnership: true),
  'open doubling': const TrixOptions.openDoubling(),
  'house: K♥ on A♥, heart leads, no forced K♥, strict self-capture': const TrixOptions(
    kingOnAceOfHearts: true,
    noHeartLeadInKing: false,
    kingMustBeDiscarded: false,
    selfCaptureRule: TrixSelfCapture.leaderGainsStrict,
  ),
  'house: complex without king rules, normal value': const TrixOptions(
    mode: TrixMode.complex,
    kingRulesInComplex: false,
    kingOnAceOfHearts: true,
    selfCaptureRule: TrixSelfCapture.normalValue,
  ),
  'house: partnership, opponents gain, sequential': const TrixOptions(
    partnership: true,
    partnerCaptureRule: TrixPartnerCapture.opponentsGain,
    doublingReveal: TrixDoublingReveal.sequential,
  ),
  'house: complex partnership, normal value': const TrixOptions(
    mode: TrixMode.complex,
    partnership: true,
    partnerCaptureRule: TrixPartnerCapture.normalValue,
  ),
  'house: no doubling': const TrixOptions(doubling: false),
};

/// The deal-total adjustment (RULES.md §2, "Invariants"): how far a deal's
/// point sum is from its undoubled total. [pre] is the state before [m], the
/// move that finished a trick deal.
int invariantAdjustment(TrixState pre, TrixMove m) {
  final o = pre.options;
  final contract = pre.contract!;
  if (contract == TrixContract.trix) return 0;
  final last = pre.trick!.copy()..add(pre.turn, m.card!);
  final tricks = [...pre.tricks, last];
  int team(int seat) => o.partnership ? seat % 2 : seat;
  var adj = 0;
  for (final e in pre.doubled.entries) {
    final trick = tricks.firstWhere((t) => t.cards.contains(e.key));
    final taker = trick.winner((x, led) => standardPower(x, led, null));
    final d = e.value;
    final v = e.key == kingOfHearts ? o.kingPenalty : o.queenPenalty;
    if (team(taker) != team(d)) continue;
    final selfLed = taker == d && trick.leader == d;
    if (o.partnership) {
      if (o.partnerCaptureRule == TrixPartnerCapture.noBonus) adj -= v;
    } else if (o.selfCaptureRule == TrixSelfCapture.doubleNoBonus ||
        (o.selfCaptureRule == TrixSelfCapture.leaderGainsStrict && selfLed)) {
      adj -= v;
    }
  }
  return adj;
}

class Played {
  Played(this.state, this.moves, this.log);

  final TrixState state;
  final int moves;
  final List<String> log;
}

/// Plays a whole match; checks after every move that a legal move exists,
/// the AI neither changes the state nor plays an illegal move, every move
/// has an event, every card is somewhere exactly once, and after every deal
/// the RULES.md §2.7 score sums (every deal and every kingdom).
Played selfPlay(
  TrixOptions o,
  int seed,
  List<AiLevel> levels, {
  AiBudget budget = const AiBudget.simulations(12),
  int jsonEvery = 0,
}) {
  const ai = TrixAi();
  var e = TrixEngine.newMatch(seed: seed, options: o);
  final rng = CardRng(seed * 7919 + 17);
  final deck = buildDeck();
  var adjustments = 0;
  var expectedTotal = 0;
  var moves = 0;
  final log = <String>[];
  while (!e.isOver) {
    final seat = e.currentPlayer!;
    expect(e.legalMoves(seat), isNotEmpty);
    final before = jsonEncode(e.toJson());
    final m = ai.chooseMove(e.state, seat, levels[seat], rng, budget);
    expect(jsonEncode(e.toJson()), before, reason: 'the AI changed the state');
    expect(e.validate(m), isNull, reason: 'illegal AI move $m');
    final pre = e.state.copy();
    final events = e.apply(m);
    log.add(jsonEncode(m.toJson()));
    moves++;
    expect(events, isNotEmpty);
    expect(sortedCards(e.state.cardsInPlay()), deck, reason: 'cards not conserved after $m');
    if (e.state.dealsPlayed > pre.dealsPlayed) {
      final r = e.state.results.last;
      final adj = invariantAdjustment(pre, m);
      expect(sum(r.points), o.undoubledTotal(r.contract) + adj, reason: 'deal ${r.contract.name} ${pre.doubled}');
      adjustments += adj;
      expectedTotal += o.undoubledTotal(r.contract) + adj;
      expect(sum(e.state.seatScores), expectedTotal);
      if (r.contract == TrixContract.complex) {
        // Complex: 13 tricks, so all 13 diamonds, the 4 queens and K♥.
        expect(pre.tricks.length, 12);
      }
      if (pre.used.length == o.contracts.length) {
        // A completed kingdom sums to 0 plus the doubling adjustments.
        expect(sum(e.state.seatScores), adjustments, reason: 'kingdom sum');
      }
    }
    if (jsonEvery > 0 && moves % jsonEvery == 0) {
      final json = jsonDecode(jsonEncode(e.toJson())) as Map<String, Object?>;
      final restored = TrixEngine.fromJson(json);
      expect(jsonEncode(restored.toJson()), jsonEncode(json));
      expect(TrixMove.fromJson(jsonDecode(jsonEncode(m.toJson())) as Map<String, Object?>), m);
      e = restored;
    }
    if (moves > 5000) fail('the match did not end');
  }
  expect(e.currentPlayer, isNull);
  expect(e.state.winners, isNotEmpty);
  expect(e.state.results, hasLength(o.mode == TrixMode.classic ? 20 : 8));
  return Played(e.state, moves, log);
}


// ------------------------------------------------------------------------
// An independent referee, written from the RULES.md §2 text and not from
// the engine: who acts, which moves are legal and what every seat scores.

final _kh = p('KH');
final _ah = p('AH');

int _refWinner(Trick t) {
  final led = t.cards.first.suit;
  var best = 0;
  for (var i = 1; i < t.cards.length; i++) {
    if (t.cards[i].suit == led && t.cards[i].rank.value > t.cards[best].rank.value) best = i;
  }
  return t.seats[best];
}

bool _refKingRules(TrixOptions o, TrixContract k) =>
    k == TrixContract.king || (k == TrixContract.complex && o.kingRulesInComplex);

/// P-1, P-K2, P-K3, P-K5.
Set<PlayingCard> _refTrickLegal(TrixOptions o, TrixContract k, Trick t, List<PlayingCard> hand) {
  final kingRules = _refKingRules(o, k);
  if (t.cards.isEmpty) {
    final other = hand.where((c) => c.suit != Suit.hearts).toSet();
    return kingRules && o.noHeartLeadInKing && other.isNotEmpty ? other : hand.toSet();
  }
  final led = t.cards.first.suit;
  final follow = hand.where((c) => c.suit == led).toSet();
  if (follow.isNotEmpty) {
    final aceDown = led == Suit.hearts && t.cards.contains(_ah);
    return kingRules && o.kingOnAceOfHearts && aceDown && hand.contains(_kh) ? {_kh} : follow;
  }
  return kingRules && o.kingMustBeDiscarded && hand.contains(_kh) ? {_kh} : hand.toSet();
}

/// X-1, X-2: a jack, or the card next to a card already on the layout
/// (towards the 2 below the jack, towards the ace above it).
Set<PlayingCard> _refLayoutLegal(List<PlayingCard> layout, List<PlayingCard> hand) {
  final down = layout.toSet();
  bool isDown(Suit s, int v) => down.contains(PlayingCard(s, Rank.fromValue(v)));
  return {
    for (final c in hand)
      if (c.rank == Rank.jack ||
          (c.rank.value < 11 && isDown(c.suit, c.rank.value + 1)) ||
          (c.rank.value > 11 && isDown(c.suit, c.rank.value - 1)))
        c,
  };
}

/// DB-2: K♥ in King / Complex, the queens in Queens / Complex.
Set<PlayingCard> _refDoublable(TrixContract k, List<PlayingCard> hand) => {
  for (final c in hand)
    if ((c == _kh && (k == TrixContract.king || k == TrixContract.complex)) ||
        (c.rank == Rank.queen && (k == TrixContract.queens || k == TrixContract.complex)))
      c,
};

/// §2.7: points of a finished trick deal, straight from the tables.
List<int> _refPoints(TrixOptions o, TrixContract k, List<Trick> tricks, Map<PlayingCard, int> doubled) {
  final pts = List.filled(4, 0);
  int team(int x) => o.partnership ? x % 2 : x;
  final king = k == TrixContract.king || k == TrixContract.complex;
  final queens = k == TrixContract.queens || k == TrixContract.complex;
  final diamonds = k == TrixContract.diamonds || k == TrixContract.complex;
  final ltoush = k == TrixContract.ltoush || k == TrixContract.complex;
  for (final t in tricks) {
    final w = _refWinner(t);
    final l = t.leader;
    if (ltoush) pts[w] -= o.trickPenalty;
    for (final card in t.cards) {
      if (diamonds && card.suit == Suit.diamonds) pts[w] -= o.diamondPenalty;
      final v = king && card == _kh ? o.kingPenalty : (queens && card.rank == Rank.queen ? o.queenPenalty : 0);
      if (v == 0) continue;
      final d = doubled[card];
      if (d == null) {
        pts[w] -= v; // DB-S1
      } else if (team(w) != team(d)) {
        pts[w] -= 2 * v; // DB-S2 / DB-P1
        pts[d] += v;
      } else if (!o.partnership) {
        final selfLed = l == d; // DB-S3 (forced) / DB-S4 (self-led)
        switch (o.selfCaptureRule) {
          case TrixSelfCapture.leaderGains:
            pts[w] -= selfLed ? v : 2 * v;
            if (!selfLed) pts[l] += v;
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
          // DB-P2 / DB-P3
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

/// A random house-rule set (every option, every value).
TrixOptions _randomOptions(CardRng r) => TrixOptions(
  partnership: r.nextBool(),
  mode: r.nextBool() ? TrixMode.classic : TrixMode.complex,
  doubling: r.nextInt(5) != 0,
  noHeartLeadInKing: r.nextBool(),
  kingMustBeDiscarded: r.nextBool(),
  kingOnAceOfHearts: r.nextBool(),
  kingRulesInComplex: r.nextBool(),
  firstOwnerRule: r.nextBool() ? TrixFirstOwner.sevenOfHearts : TrixFirstOwner.fixedSeat,
  firstOwner: r.nextInt(4),
  doublingReveal: r.nextBool() ? TrixDoublingReveal.simultaneous : TrixDoublingReveal.sequential,
  selfCaptureRule: TrixSelfCapture.values[r.nextInt(TrixSelfCapture.values.length)],
  partnerCaptureRule: TrixPartnerCapture.values[r.nextInt(TrixPartnerCapture.values.length)],
);

/// Plays a match with random legal moves (random doubles included) and
/// checks every move and every deal against the referee. Returns the number
/// of deals with a doubled card.
int refereeMatch(TrixOptions o, int seed) {
  final rng = CardRng(seed * 31 + 5);
  final e = TrixEngine.newMatch(seed: seed, options: o);
  // K-2: the 7♥ holder of the first deal, or the fixed seat.
  final firstOwner = o.firstOwnerRule == TrixFirstOwner.sevenOfHearts
      ? e.state.hands.indexWhere((h) => h.contains(p('7H')))
      : o.firstOwner;
  final per = o.contracts.length;
  final chosen = <TrixContract>[];
  var answers = <int, List<PlayingCard>>{};
  var doubledDeals = 0;
  var totals = List.filled(4, 0);
  var guard = 0;
  while (!e.isOver) {
    final s = e.state;
    final deal = s.results.length;
    final owner = (firstOwner + deal ~/ per) % 4; // K-1, K-3
    expect(s.owner, owner, reason: 'deal $deal');
    final seat = e.currentPlayer!;
    final legal = e.legalMoves(seat);
    switch (s.phase) {
      case TrixPhase.contract:
        // K-4: the owner, any contract of the kingdom not played yet.
        expect(seat, owner);
        final used = chosen.sublist(deal - deal % per);
        expect(legal.map((m) => m.contract).toSet(), o.contracts.where((k) => !used.contains(k)).toSet());
      case TrixPhase.doubling:
        // DB-1, DB-5: every seat answers once, from the owner round.
        expect(seat, (owner + answers.length) % 4);
        final can = _refDoublable(s.contract!, s.hands[seat]);
        expect(legal, hasLength(1 << can.length));
        expect(legal.every((m) => m.cards.toSet().difference(can).isEmpty), isTrue);
      case TrixPhase.tricks:
        final t = s.trick!;
        // K-6, P-2: the owner leads first, then the last trick's winner.
        final leader = s.tricks.isEmpty ? owner : _refWinner(s.tricks.last);
        expect(t.leader, leader);
        expect(seat, (leader + t.length) % 4);
        expect(legal.map((m) => m.card).toSet(), _refTrickLegal(o, s.contract!, t, s.hands[seat]));
        for (final c in s.hands[seat]) {
          expect(e.validate(TrixMove.play(c)) == null, legal.contains(TrixMove.play(c)));
        }
      case TrixPhase.layout:
        // X-3: the owner first, then the next seat still holding cards.
        if (s.layoutCards.isEmpty && s.cannotHold.every((x) => x.isEmpty)) expect(seat, owner);
        expect(s.finished, isNot(contains(seat)));
        final ref = _refLayoutLegal(s.layoutCards, s.hands[seat]);
        // X-4: pass only with no playable card.
        expect(legal, ref.isEmpty ? [const TrixMove.pass()] : [for (final c in sortedCards(ref)) TrixMove.play(c)]);
      case TrixPhase.over:
        fail('over');
    }
    final m = legal[rng.nextInt(legal.length)];
    final pre = s.copy();
    final events = e.apply(m);
    final post = e.state;
    if (m.kind == TrixMoveKind.contract) {
      chosen.add(m.contract!);
      answers = {};
    }
    if (m.kind == TrixMoveKind.double) {
      answers[seat] = m.cards;
      final withCards = events.where((x) => x.type == CardEventType.doubled && x.cards.isNotEmpty).toList();
      if (o.doublingReveal == TrixDoublingReveal.simultaneous) {
        // DB-5: nothing shows before the fourth answer, then all at once.
        if (answers.length < 4) {
          expect(withCards, isEmpty);
          expect(post.doubled, isEmpty);
        } else {
          expect({for (final x in withCards) ...x.cards}, {for (final a in answers.values) ...a});
        }
      } else {
        expect([for (final x in withCards) ...x.cards], m.cards);
      }
      if (answers.length == 4) {
        expect(post.doubled, {
          for (final a in answers.entries)
            for (final c in a.value) c: a.key,
        });
        expect(post.phase, TrixPhase.tricks);
        expect(post.currentPlayer, owner);
      }
    }
    if (post.dealsPlayed == pre.dealsPlayed) {
      if (++guard > 3000) fail('the match did not end');
      continue;
    }
    // A deal ended: its points, straight from the tables.
    final r = post.results.last;
    expect(r.owner, owner);
    expect(r.contract, pre.contract);
    List<int> ref;
    if (pre.contract == TrixContract.trix) {
      // X-5, X-6: places in finishing order; the fourth is placed last.
      final order = [...pre.finished, seat];
      order.add([0, 1, 2, 3].firstWhere((x) => !order.contains(x)));
      ref = List.filled(4, 0);
      for (var i = 0; i < 4; i++) {
        ref[order[i]] += o.trixScores[i];
      }
    } else {
      final tricks = [...pre.tricks, pre.trick!.copy()..add(seat, m.card!)];
      final taken = [for (final t in tricks) ...t.cards];
      // P-K4, P-Q3, P-D3: the early ends; P-L1, C-4: all 13 tricks.
      final early = switch (pre.contract!) {
        TrixContract.king => taken.contains(_kh),
        TrixContract.queens => taken.where((c) => c.rank == Rank.queen).length == 4,
        TrixContract.diamonds => taken.where((c) => c.suit == Suit.diamonds).length == 13,
        _ => false,
      };
      expect(early || tricks.length == 13, isTrue);
      final lastBut = tricks.sublist(0, tricks.length - 1).expand((t) => t.cards).toList();
      final endedBefore = switch (pre.contract!) {
        TrixContract.king => lastBut.contains(_kh),
        TrixContract.queens => lastBut.where((c) => c.rank == Rank.queen).length == 4,
        TrixContract.diamonds => lastBut.where((c) => c.suit == Suit.diamonds).length == 13,
        _ => false,
      };
      expect(endedBefore, isFalse, reason: 'the deal should have ended one trick earlier');
      if (pre.doubled.isNotEmpty) doubledDeals++;
      ref = _refPoints(o, pre.contract!, tricks, pre.doubled);
    }
    expect(r.points, ref, reason: 'deal $deal ${pre.contract!.name}');
    totals = [for (var i = 0; i < 4; i++) totals[i] + ref[i]];
    expect(post.seatScores, totals);
  }
  // M-1: a fixed number of deals; M-2, M-4, M-5: the best total wins, ties share.
  expect(e.state.results, hasLength(4 * per));
  final sc = [for (var i = 0; i < 4; i++) o.partnership ? totals[i % 2] + totals[i % 2 + 2] : totals[i]];
  expect(e.state.scores, sc);
  final best = sc.reduce((a, b) => a > b ? a : b);
  expect(e.state.winners, [
    for (var i = 0; i < 4; i++)
      if (sc[i] == best) i,
  ]);
  return doubledDeals;
}

void main() {
  group('self-play, every variant', () {
    for (final v in variants.entries) {
      test('${v.key}: easy and medium, invariants on every deal, save / resume', () {
        for (var seed = 1; seed <= 2; seed++) {
          selfPlay(v.value, seed, List.filled(4, AiLevel.easy), jsonEvery: seed == 1 ? 17 : 0);
          selfPlay(v.value, seed, List.filled(4, AiLevel.medium), jsonEvery: seed == 2 ? 13 : 0);
        }
      });
      test('${v.key}: hard (tiny budget) in a mixed table', () {
        selfPlay(
          v.value,
          3,
          const [AiLevel.hard, AiLevel.easy, AiLevel.medium, AiLevel.hard],
          budget: const AiBudget.simulations(6),
          jsonEvery: 29,
        );
      });
    }
  });

  test('individual Jordanian default: every deal sums to its undoubled total, kingdoms to 0', () {
    for (var seed = 10; seed < 14; seed++) {
      final s = selfPlay(const TrixOptions(), seed, List.filled(4, AiLevel.medium)).state;
      for (final r in s.results) {
        expect(sum(r.points), const TrixOptions().undoubledTotal(r.contract));
      }
      for (var k = 0; k < 4; k++) {
        expect(sum([for (final r in s.results.sublist(k * 5, k * 5 + 5)) ...r.points]), 0);
      }
      expect(sum(s.seatScores), 0);
    }
  });

  test('partnership default (noBonus): deals lose v for each doubled card its own team took', () {
    // Checked inside selfPlay; here we also make sure such a case happened.
    var sawOwnTeamCapture = false;
    for (var seed = 1; seed <= 6 && !sawOwnTeamCapture; seed++) {
      final s = selfPlay(const TrixOptions(partnership: true), seed, List.filled(4, AiLevel.medium)).state;
      sawOwnTeamCapture = s.results.any((r) => sum(r.points) < const TrixOptions().undoubledTotal(r.contract));
    }
    expect(sawOwnTeamCapture, isTrue);
  });

  group('deterministic replay', () {
    for (final o in [const TrixOptions(mode: TrixMode.complex), const TrixOptions.openDoubling(mode: TrixMode.complex)]) {
      test('${o.doublingReveal.name}: same seed and levels → same match; the move log replays it', () {
        const levels = [AiLevel.hard, AiLevel.easy, AiLevel.medium, AiLevel.hard];
        const budget = AiBudget.simulations(6);
        final a = selfPlay(o, 42, levels, budget: budget);
        final b = selfPlay(o, 42, levels, budget: budget);
        expect(jsonEncode(b.state.toJson()), jsonEncode(a.state.toJson()));
        expect(b.log, a.log);
        final replay = TrixEngine.newMatch(seed: 42, options: o);
        for (final mj in a.log) {
          replay.apply(replay.moveFromJson(jsonDecode(mj) as Map<String, Object?>));
        }
        expect(jsonEncode(replay.toJson()), jsonEncode(a.state.toJson()));
        final c = selfPlay(o, 43, levels, budget: budget);
        expect(jsonEncode(c.state.toJson()), isNot(jsonEncode(a.state.toJson())));
      });
    }
  });

  group('the AIs never see hidden cards', () {
    for (final o in [
      const TrixOptions(),
      const TrixOptions(mode: TrixMode.complex, partnership: true),
      const TrixOptions(doublingReveal: TrixDoublingReveal.sequential, kingOnAceOfHearts: true),
    ]) {
      test('${o.mode.name} partnership=${o.partnership} ${o.doublingReveal.name}: '
          're-dealing what a seat cannot see does not change its decision', () {
        const ai = TrixAi();
        final e = TrixEngine.newMatch(seed: 5, options: o);
        final rng = CardRng(1);
        var checked = 0;
        var checkedDoubling = 0;
        for (var move = 0; move < 500 && !e.isOver; move++) {
          final seat = e.currentPlayer!;
          final doubling = e.state.phase == TrixPhase.doubling;
          if (move % 7 == 3 || (doubling && e.state.doublingAnswers > 0)) {
            final real = e.state;
            final other = ai.determinize(real, seat, CardRng(move));
            expect(sortedCards(other.cardsInPlay()), sortedCards(real.cardsInPlay()));
            expect(other.hands[seat], real.hands[seat]);
            expect(other.doublesVisibleTo(seat), real.doublesVisibleTo(seat));
            for (final level in [AiLevel.medium, AiLevel.hard]) {
              final a = ai.chooseMove(real, seat, level, CardRng(9), const AiBudget.simulations(10));
              final b = ai.chooseMove(other, seat, level, CardRng(9), const AiBudget.simulations(10));
              expect(b, a, reason: 'move $move ${level.name}');
            }
            checked++;
            if (doubling) checkedDoubling++;
          }
          e.apply(ai.chooseMove(e.state, seat, AiLevel.medium, rng, AiBudget.phone));
        }
        expect(checked, greaterThan(10));
        expect(checkedDoubling, greaterThan(0));
      });
    }

    test('DB-5 E-3 hidden doubling: an earlier seat\'s secret answer does not change a later seat\'s move', () {
      const ai = TrixAi();
      // Round-robin deal: 7♥ at seat 3 (owner), Q♦ at seat 3, Q♥ at 0, K♥ and Q♠ at 1, Q♣ at 2.
      final deck = buildDeck();
      final hands = [
        for (var seat = 0; seat < 4; seat++)
          [
            for (var i = seat; i < 52; i += 4) deck[i],
          ],
      ];
      TrixEngine after(List<PlayingCard> ownerDouble) {
        final e = TrixEngine(TrixState.withHands(hands, options: const TrixOptions(mode: TrixMode.complex)));
        e.apply(const TrixMove.contract(TrixContract.complex));
        e.apply(TrixMove.double(ownerDouble));
        return e;
      }

      final doubled = after([p('QD')]);
      final quiet = after(const []);
      expect(doubled.state.pendingDoubles, {p('QD'): 3});
      expect(quiet.state.pendingDoubles, isEmpty);
      expect(doubled.currentPlayer, 0);
      for (var i = 0; i < 8; i++) {
        expect(
          jsonEncode(ai.determinize(doubled.state, 0, CardRng(i)).toJson()),
          jsonEncode(ai.determinize(quiet.state, 0, CardRng(i)).toJson()),
        );
      }
      for (final level in AiLevel.values) {
        for (var r = 0; r < 3; r++) {
          final a = ai.chooseMove(doubled.state, 0, level, CardRng(r), const AiBudget.simulations(16));
          final b = ai.chooseMove(quiet.state, 0, level, CardRng(r), const AiBudget.simulations(16));
          expect(b, a, reason: '${level.name} $r');
        }
      }
      // Seat 1 (after two hidden answers) likewise.
      doubled.apply(TrixMove.double(const []));
      quiet.apply(TrixMove.double(const []));
      for (final level in AiLevel.values) {
        final a = ai.chooseMove(doubled.state, 1, level, CardRng(4), const AiBudget.simulations(16));
        final b = ai.chooseMove(quiet.state, 1, level, CardRng(4), const AiBudget.simulations(16));
        expect(b, a, reason: level.name);
      }
    });

    test('E-3 sampled worlds: other seats\' pending doubles are re-drawn, own answer and revealed doubles kept', () {
      const ai = TrixAi();
      // A deal where the owner holds something to double.
      var seed = 12;
      late TrixEngine e;
      while (true) {
        e = TrixEngine.newMatch(seed: seed++, options: const TrixOptions(mode: TrixMode.complex));
        e.apply(const TrixMove.contract(TrixContract.complex));
        if (TrixRules.doublable(e.state, e.state.owner).length >= 2) break;
      }
      final owner = e.state.owner;
      // The owner doubles everything it can; the next seat answers too.
      final ownerCards = TrixRules.doublable(e.state, owner);
      e.apply(TrixMove.double(ownerCards));
      final next = e.currentPlayer!;
      final nextCards = TrixRules.doublable(e.state, next);
      e.apply(TrixMove.double(nextCards));
      final observer = e.currentPlayer!;
      var ownerCardsMoved = false;
      for (var i = 0; i < 30; i++) {
        final w = ai.determinize(e.state, observer, CardRng(i));
        for (final entry in w.pendingDoubles.entries) {
          // Every pending double in the world is a card its seat holds there.
          expect(w.hands[entry.value], contains(entry.key));
          expect(entry.value, isNot(observer));
        }
        if (ownerCards.any((card) => !w.hands[owner].contains(card))) ownerCardsMoved = true;
      }
      expect(ownerCardsMoved, isTrue, reason: 'hidden doubles must not pin cards to their doubler');

      // The observer's own hidden answer is kept.
      final mine = TrixRules.doublable(e.state, observer);
      e.apply(TrixMove.double(mine));
      final last = e.currentPlayer!;
      final w = ai.determinize(e.state, observer, CardRng(3));
      for (final card in mine) {
        expect(w.pendingDoubles[card], observer);
      }
      e.apply(TrixMove.double(const []));
      // After the reveal every doubled card not yet played stays with its doubler.
      expect(e.state.phase, TrixPhase.tricks);
      for (var i = 0; i < 10; i++) {
        final world = ai.determinize(e.state, last, CardRng(i));
        for (final entry in e.state.doubled.entries) {
          expect(world.hands[entry.value], contains(entry.key));
        }
      }
    });

    test('K-2 sampled worlds: in the first deal the owner holds the 7♥ (public), later deals free', () {
      const ai = TrixAi();
      final e = TrixEngine.newMatch(seed: 31);
      final owner = e.state.owner;
      final observer = (owner + 1) % 4;
      for (var i = 0; i < 10; i++) {
        expect(ai.determinize(e.state, observer, CardRng(i)).hands[owner], contains(p('7H')));
      }
      e.apply(e.legalMoves(owner).first);
      while (e.state.dealsPlayed == 0) {
        e.apply(e.legalMoves(e.currentPlayer!).first);
      }
      expect(e.state.owner, owner);
      final other = [0, 1, 2, 3].firstWhere((x) => x != owner && !e.state.hands[x].contains(p('7H')));
      var moved = false;
      for (var i = 0; i < 20; i++) {
        if (!ai.determinize(e.state, other, CardRng(i)).hands[owner].contains(p('7H'))) moved = true;
      }
      expect(moved, isTrue);
    });

    test('P-K5 sampled worlds: a seat that played a heart onto A♥ does not hold K♥', () {
      const ai = TrixAi();
      final hands = [
        PlayingCard.list('AH 2H 2C 3C 4C 5C 6C 7C 8C 9C TC JC QC'),
        PlayingCard.list('3H 4H KC AC 2D 3D 4D 5D 6D 7D 8D 9D TD'),
        PlayingCard.list('KH 5H 6H 7H 8H JD QD KD AD 2S 3S 4S 5S'),
        PlayingCard.list('9H TH JH QH 6S 7S 8S 9S TS JS QS KS AS'),
      ];
      final e = TrixEngine(
        TrixState.withHands(
          hands,
          options: const TrixOptions(
            firstOwnerRule: TrixFirstOwner.fixedSeat,
            doubling: false,
            noHeartLeadInKing: false,
            kingOnAceOfHearts: true,
          ),
        ),
      );
      e.apply(const TrixMove.contract(TrixContract.king));
      e.apply(TrixMove.play(p('AH')));
      e.apply(TrixMove.play(p('3H')));
      // Seat 2 holds K♥ and must play it.
      expect(e.legalMoves(2), [TrixMove.play(kingOfHearts)]);
      // From seat 3's view: seat 1 played 3♥ onto A♥ instead of K♥, so no
      // sampled world gives seat 1 the K♥.
      for (var i = 0; i < 20; i++) {
        final w = ai.determinize(e.state, 3, CardRng(i));
        expect(w.hands[1], isNot(contains(kingOfHearts)));
      }
    });
  });

  test('medium AI: the forced K♥ and the partner-aware discards are legal in every variant', () {
    const ai = TrixAi();
    for (final o in variants.values) {
      final e = TrixEngine.newMatch(seed: 77, options: o);
      final rng = CardRng(3);
      for (var i = 0; i < 300 && !e.isOver; i++) {
        final seat = e.currentPlayer!;
        final m = ai.chooseMove(e.state, seat, AiLevel.medium, rng, AiBudget.phone);
        expect(e.validate(m), isNull);
        e.apply(m);
      }
    }
  });

  test('independent referee: turns, legal moves, doubling, early ends and every seat\'s points, '
      'over random house rules and random play', () {
    final r = CardRng(2026);
    var doubled = 0;
    for (var game = 0; game < 40; game++) {
      doubled += refereeMatch(game < 4 ? TrixPreset.values[game].options : _randomOptions(r), game);
    }
    expect(doubled, greaterThan(100), reason: 'random play must exercise the doubling table');
  });

  /// One [strong] seat (rotating) against three [weak] seats, or a strong
  /// team (alternating) against a weak team. Deterministic budgets.
  void expectStronger(TrixOptions o, int matches, AiLevel strong, AiLevel weak, String label) {
    var wins = 0;
    var edge = 0.0;
    for (var m = 0; m < matches; m++) {
      final strongSeats = o.partnership ? [m % 2, m % 2 + 2] : [m % 4];
      final levels = [for (var s = 0; s < 4; s++) strongSeats.contains(s) ? strong : weak];
      final s = selfPlay(o, 1000 + m, levels, budget: const AiBudget.simulations(24)).state;
      final sc = s.scores;
      final mine = sum(strongSeats.map((x) => sc[x])) / strongSeats.length;
      final others = [
        for (var x = 0; x < 4; x++)
          if (!strongSeats.contains(x)) sc[x],
      ];
      edge += mine - sum(others) / others.length;
      if (strongSeats.any(s.winners.contains)) wins++;
    }
    // ignore: avoid_print
    print('$label: ${strong.name} won $wins/$matches against ${weak.name}, '
        'average edge ${(edge / matches).toStringAsFixed(1)}');
    expect(edge / matches, greaterThan(0));
    expect(wins, greaterThanOrEqualTo(matches / (o.partnership ? 2 : 4)));
  }

  group('hard beats easy', () {
    for (final entry in {
      'تركس كومبلكس': (const TrixOptions(mode: TrixMode.complex), 8),
      'تركس (jordan)': (const TrixOptions(), 4),
      'كومبلكس شراكة': (const TrixOptions(mode: TrixMode.complex, partnership: true), 6),
    }.entries) {
      test(entry.key, () => expectStronger(entry.value.$1, entry.value.$2, AiLevel.hard, AiLevel.easy, entry.key));
    }
  });

  group('the levels are ordered: medium beats easy, hard beats medium', () {
    for (final entry in {
      'تركس (jordan)': const TrixOptions(),
      'تركس شراكة': const TrixOptions(partnership: true),
      'تركس كومبلكس': const TrixOptions(mode: TrixMode.complex),
      'كومبلكس شراكة': const TrixOptions(mode: TrixMode.complex, partnership: true),
    }.entries) {
      test('${entry.key}: medium beats easy', () {
        expectStronger(entry.value, 8, AiLevel.medium, AiLevel.easy, entry.key);
      });
    }
    for (final entry in {
      'تركس كومبلكس': const TrixOptions(mode: TrixMode.complex),
      'كومبلكس شراكة': const TrixOptions(mode: TrixMode.complex, partnership: true),
    }.entries) {
      test('${entry.key}: hard beats medium', () {
        expectStronger(entry.value, 6, AiLevel.hard, AiLevel.medium, entry.key);
      });
    }
  });
}

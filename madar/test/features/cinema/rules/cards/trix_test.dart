// Trix (تركس) as commonly played in Jordan: one test per rule of the spec
// (RULES.md §2). Test names start with the rule id (T-, K-, P-, X-, DB-, C-,
// M-, E- for the edge cases, O- for options and J- for save / load).
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/cinema/rules/cards/cards.dart';
import 'package:madar/features/cinema/rules/cards/core/trick.dart' show standardPower;

List<PlayingCard> c(String ids) => PlayingCard.list(ids);
PlayingCard p(String id) => PlayingCard.parse(id);

/// Seat 0 always owns the first kingdom (for hand-built deals).
const fixed0 = TrixOptions(firstOwnerRule: TrixFirstOwner.fixedSeat);

/// Seat 0 all spades, 1 all hearts (so the 7♥), 2 all diamonds, 3 all clubs.
List<List<PlayingCard>> suitsDeal() => [
  for (final s in [Suit.spades, Suit.hearts, Suit.diamonds, Suit.clubs])
    [for (final r in Rank.values) PlayingCard(s, r)],
];

/// The sorted deck dealt one card at a time: every seat holds every suit.
/// 7♥ and J♥ at seat 3, K♥ at seat 1, A♥ at seat 2.
List<List<PlayingCard>> roundRobinDeal() {
  final deck = buildDeck();
  return [
    for (var seat = 0; seat < 4; seat++)
      [
        for (var i = seat; i < 52; i += 4) deck[i],
      ],
  ];
}

/// Seat 0 all clubs, 1 K♥ + 12 diamonds, 2 twelve hearts (7♥) + 2♦, 3 all
/// spades.
List<List<PlayingCard>> kingDeal() => [
  c('AC KC QC JC TC 9C 8C 7C 6C 5C 4C 3C 2C'),
  c('KH AD KD QD JD TD 9D 8D 7D 6D 5D 4D 3D'),
  c('AH QH JH TH 9H 8H 7H 6H 5H 4H 3H 2H 2D'),
  c('AS KS QS JS TS 9S 8S 7S 6S 5S 4S 3S 2S'),
];

/// Seat 0 A♥ 2♥ + clubs, seat 1 K♥ 3♥ 4♥ K♣ A♣ + diamonds, seat 2 (7♥)
/// hearts, diamonds and spades, seat 3 hearts and spades.
List<List<PlayingCard>> aceDeal() => [
  c('AH 2H 2C 3C 4C 5C 6C 7C 8C 9C TC JC QC'),
  c('KH 3H 4H KC AC 2D 3D 4D 5D 6D 7D 8D 9D'),
  c('5H 6H 7H 8H TD JD QD KD AD 2S 3S 4S 5S'),
  c('9H TH JH QH 6S 7S 8S 9S TS JS QS KS AS'),
];

void expectFullDeal(List<List<PlayingCard>> hands) {
  expect(hands.map((h) => h.length), [13, 13, 13, 13]);
  expect(sortedCards([for (final h in hands) ...h]), buildDeck());
}

/// Plays [ids] in order for whoever is to act.
void play(TrixEngine e, String ids) {
  for (final card in c(ids)) {
    e.apply(TrixMove.play(card));
  }
}

/// Every seat answers "no double".
void noDoubles(TrixEngine e) {
  while (e.state.phase == TrixPhase.doubling) {
    e.apply(TrixMove.double(const []));
  }
}

/// Plays the first legal move until [deals] more deals are scored.
void playOut(TrixEngine e, {int deals = 1}) {
  final target = e.state.dealsPlayed + deals;
  while (!e.isOver && e.state.dealsPlayed < target) {
    e.apply(e.legalMoves(e.currentPlayer!).first);
  }
}

/// A completed trick led by [leader]; [ids] in play order.
Trick tr(int leader, String ids) {
  final cards = c(ids);
  return Trick(leader, seats: [for (var i = 0; i < cards.length; i++) (leader + i) % 4], cards: cards);
}

/// A hand-built finished deal: [tricks] fill `taken` and `tricksTaken`;
/// [doubled] maps card ids to their doubler.
TrixState finishedDeal(
  TrixContract contract,
  List<Trick> tricks, {
  TrixOptions options = fixed0,
  Map<String, int> doubled = const {},
}) {
  final s = TrixState.withHands(suitsDeal(), options: options)
    ..contract = contract
    ..tricks = tricks
    ..doubled = {for (final e in doubled.entries) p(e.key): e.value};
  for (final t in tricks) {
    final w = t.winner((card, led) => standardPower(card, led, null));
    s.taken[w].addAll(t.cards);
    s.tricksTaken[w]++;
  }
  return s;
}

int sum(List<int> xs) => xs.fold(0, (a, b) => a + b);

void main() {
  test('deals used by these tests are full 52-card deals', () {
    for (final d in [suitsDeal(), roundRobinDeal(), kingDeal(), aceDeal()]) {
      expectFullDeal(d);
    }
  });

  group('O: options and presets', () {
    test('O-1 const TrixOptions() is the Jordanian preset', () {
      expect(const TrixOptions(), const TrixOptions.jordan());
      expect(identical(const TrixOptions(), const TrixOptions.jordan()), isTrue);
      const o = TrixOptions();
      expect(o.mode, TrixMode.classic);
      expect(o.partnership, isFalse);
      expect(o.firstOwnerRule, TrixFirstOwner.sevenOfHearts);
      expect(o.doubling, isTrue);
      expect(o.doublingReveal, TrixDoublingReveal.simultaneous);
      expect(o.selfCaptureRule, TrixSelfCapture.leaderGains);
      expect(o.partnerCaptureRule, TrixPartnerCapture.noBonus);
      expect(o.noHeartLeadInKing, isTrue);
      expect(o.kingMustBeDiscarded, isTrue);
      expect(o.kingOnAceOfHearts, isFalse);
      expect(o.kingRulesInComplex, isTrue);
      expect([o.kingPenalty, o.queenPenalty, o.diamondPenalty, o.trickPenalty], [75, 25, 10, 15]);
      expect(o.trixScores, [200, 150, 100, 50]);
    });

    test('O-2 the four menu presets: تركس, تركس شراكة, تركس كومبلكس, كومبلكس شراكة', () {
      expect(const TrixOptions.jordan(partnership: true), const TrixOptions(partnership: true));
      expect(const TrixOptions.jordan(mode: TrixMode.complex), const TrixOptions(mode: TrixMode.complex));
      expect(
        const TrixOptions.jordan(mode: TrixMode.complex, partnership: true),
        const TrixOptions(mode: TrixMode.complex, partnership: true),
      );
      expect(const TrixOptions.jordan(partnership: true), isNot(const TrixOptions()));
    });

    test('O-2 TrixPreset lists the four menu entries', () {
      expect(TrixPreset.values.map((x) => x.options), [
        const TrixOptions(),
        const TrixOptions(partnership: true),
        const TrixOptions(mode: TrixMode.complex),
        const TrixOptions(mode: TrixMode.complex, partnership: true),
      ]);
    });

    test('O-3 openDoubling keeps the earlier engine rules reachable', () {
      const o = TrixOptions.openDoubling();
      expect(o.firstOwnerRule, TrixFirstOwner.fixedSeat);
      expect(o.firstOwner, 0);
      expect(o.doublingReveal, TrixDoublingReveal.sequential);
      expect(o.selfCaptureRule, TrixSelfCapture.doubleNoBonus);
      expect(o.partnerCaptureRule, TrixPartnerCapture.noBonus);
      expect(const TrixOptions.openDoubling(mode: TrixMode.complex, partnership: true).partnership, isTrue);
    });

    test('O-4 undoubled deal totals: −75, −100, −130, −195, +500, −500', () {
      const o = TrixOptions();
      expect([for (final k in TrixContract.values) o.undoubledTotal(k)], [-75, -100, -130, -195, 500, -500]);
    });
  });

  group('T: players, cards, deal', () {
    test('T-1 T-3 four players, 13 cards each from one 52-card deck; a fresh deal for every contract', () {
      final e = TrixEngine.newMatch(seed: 3);
      expectFullDeal(e.state.hands);
      expect(e.state.playerCount, 4);
      final first = [for (final h in e.state.hands) List.of(h)];
      e.apply(TrixMove.contract(TrixContract.ltoush));
      playOut(e);
      expect(e.state.dealNumber, 2);
      expectFullDeal(e.state.hands);
      expect(e.state.hands, isNot(first));
    });

    test('T-2 ace high, no trumps: the highest card of the led suit wins', () {
      final e = TrixEngine(TrixState.withHands(roundRobinDeal(), options: fixed0));
      e.apply(const TrixMove.contract(TrixContract.ltoush));
      // Seat 0 leads 2♣; 3♣, Q♣ and 5♣ follow: Q♣ (seat 2) wins.
      play(e, '2C 3C QC 5C');
      expect(e.state.tricks.single.winner((x, l) => standardPower(x, l, null)), 2);
      expect(e.state.tricksTaken, [0, 0, 1, 0]);
      // A card of another suit never wins, however high.
      final f = TrixEngine(TrixState.withHands(suitsDeal(), options: fixed0));
      f.apply(const TrixMove.contract(TrixContract.ltoush));
      play(f, '2S AH AD AC');
      expect(f.state.tricksTaken, [1, 0, 0, 0]);
    });

    test('T-4 play goes to the next seat (seat + 1)', () {
      final e = TrixEngine(TrixState.withHands(roundRobinDeal(), options: fixed0));
      e.apply(const TrixMove.contract(TrixContract.ltoush));
      final order = <int>[];
      for (final id in ['2C', '3C', 'QC', '5C']) {
        order.add(e.currentPlayer!);
        e.apply(TrixMove.play(p(id)));
      }
      expect(order, [0, 1, 2, 3]);
    });

    test('T-5 no bidding: the first move of a deal is the owner choosing a contract', () {
      final e = TrixEngine.newMatch(seed: 8);
      expect(e.state.phase, TrixPhase.contract);
      expect(e.legalMoves(e.currentPlayer!).every((m) => m.kind == TrixMoveKind.contract), isTrue);
    });
  });

  group('K: kingdoms', () {
    test('K-1 four kingdoms, one per player (classic: five deals each)', () {
      final e = TrixEngine.newMatch(seed: 11);
      playOut(e, deals: 20);
      expect(e.isOver, isTrue);
      final owners = e.state.results.map((r) => r.owner).toList();
      final first = owners.first;
      expect(owners, [
        for (var k = 0; k < 4; k++)
          for (var i = 0; i < 5; i++) (first + k) % 4,
      ]);
    });

    test('K-2 the holder of the 7♥ in the first deal owns the first kingdom', () {
      final e = TrixEngine(TrixState.withHands(roundRobinDeal()));
      expect(e.state.owner, 3);
      expect(e.currentPlayer, 3);
      expect(e.state.phase, TrixPhase.contract);
      for (var seed = 1; seed <= 20; seed++) {
        final s = TrixState.newMatch(seed: seed);
        final holder = s.hands.indexWhere((h) => h.contains(p('7H')));
        expect(s.owner, holder, reason: 'seed $seed');
        expect(s.currentPlayer, holder, reason: 'seed $seed');
      }
    });

    test('K-2 only the first deal of the match decides; later deals keep the kingdom owner', () {
      final e = TrixEngine(TrixState.withHands(suitsDeal()));
      expect(e.state.owner, 1);
      var sevenElsewhere = false;
      for (var i = 0; i < 4; i++) {
        e.apply(e.legalMoves(1).first);
        playOut(e);
        expect(e.state.owner, 1);
        expect(e.currentPlayer, 1);
        if (!e.state.hands[1].contains(p('7H'))) sevenElsewhere = true;
      }
      expect(sevenElsewhere, isTrue);
    });

    test('K-2 fixedSeat uses firstOwner', () {
      final s = TrixState.withHands(suitsDeal(), options: const TrixOptions(firstOwnerRule: TrixFirstOwner.fixedSeat, firstOwner: 2));
      expect(s.owner, 2);
      expect(s.currentPlayer, 2);
    });

    test('K-3 after its contracts the kingdom passes to the next seat', () {
      final e = TrixEngine(TrixState.withHands(suitsDeal()));
      expect(e.state.owner, 1);
      for (var i = 0; i < 5; i++) {
        e.apply(e.legalMoves(1).first);
        playOut(e);
      }
      expect(e.state.kingdom, 1);
      expect(e.state.owner, 2);
      expect(e.currentPlayer, 2);
      final f = TrixEngine(TrixState.withHands(roundRobinDeal()));
      for (var i = 0; i < 5; i++) {
        f.apply(f.legalMoves(3).first);
        playOut(f);
      }
      // 7♥ at seat 3 owns the first kingdom, seat 0 the second.
      expect(f.state.owner, 0);
    });

    test('K-4 the owner picks each contract once, in any order', () {
      final e = TrixEngine(TrixState.withHands(suitsDeal(), options: fixed0));
      expect(e.currentPlayer, 0);
      expect(e.legalMoves(0).map((m) => m.contract), TrixContract.values.take(5));
      e.apply(const TrixMove.contract(TrixContract.ltoush));
      playOut(e);
      expect(e.state.owner, 0);
      expect(e.legalMoves(0).map((m) => m.contract), isNot(contains(TrixContract.ltoush)));
      expect(e.validate(const TrixMove.contract(TrixContract.ltoush)), 'contractAlreadyPlayed');
      expect(e.validate(const TrixMove.contract(TrixContract.complex)), 'contractNotAvailable');
      for (var i = 0; i < 4; i++) {
        e.apply(e.legalMoves(0).last);
        playOut(e);
      }
      expect(e.state.results.map((r) => r.contract), [
        TrixContract.ltoush,
        TrixContract.trix,
        TrixContract.diamonds,
        TrixContract.queens,
        TrixContract.king,
      ]);
      expect(e.state.owner, 1);
    });

    test('K-5 the 7♥ holder chooses the contract on that same first deal', () {
      final hands = roundRobinDeal();
      final e = TrixEngine(TrixState.withHands(hands));
      expect(e.state.hands, hands);
      expect(e.legalMoves(3), hasLength(5));
      e.apply(const TrixMove.contract(TrixContract.ltoush));
      expect(e.state.results, isEmpty);
      expect(e.state.hands, hands);
    });

    test('K-6 the owner leads the first trick and starts the layout', () {
      final e = TrixEngine(TrixState.withHands(roundRobinDeal()));
      e.apply(const TrixMove.contract(TrixContract.diamonds));
      expect(e.state.trick!.leader, 3);
      expect(e.currentPlayer, 3);
      final f = TrixEngine(TrixState.withHands(roundRobinDeal()));
      f.apply(const TrixMove.contract(TrixContract.trix));
      expect(f.state.phase, TrixPhase.layout);
      expect(f.currentPlayer, 3);
    });

    test('K-7 no compulsory order: Trix or King may come first', () {
      final e = TrixEngine(TrixState.withHands(roundRobinDeal()));
      expect(e.validate(const TrixMove.contract(TrixContract.trix)), isNull);
      expect(e.validate(const TrixMove.contract(TrixContract.king)), isNull);
    });
  });

  group('P: trick play', () {
    test('P-1 follow suit if you can', () {
      final e = TrixEngine(TrixState.withHands(roundRobinDeal(), options: fixed0));
      e.apply(const TrixMove.contract(TrixContract.ltoush));
      e.apply(TrixMove.play(p('2C')));
      expect(e.legalMoves(1).map((m) => m.card), c('3C 7C JC'));
      expect(e.validate(TrixMove.play(p('2D'))), 'mustFollowSuit');
      expect(e.validate(TrixMove.play(p('AS'))), 'cardNotInHand');
    });

    test('P-1 a player who cannot follow may play any card (outside the king rules)', () {
      final e = TrixEngine(TrixState.withHands(kingDeal(), options: fixed0));
      e.apply(const TrixMove.contract(TrixContract.ltoush));
      e.apply(TrixMove.play(p('2C')));
      expect(e.legalMoves(1), hasLength(13));
    });

    test('P-2 the winner of a trick leads the next one', () {
      final e = TrixEngine(TrixState.withHands(roundRobinDeal(), options: fixed0));
      e.apply(const TrixMove.contract(TrixContract.ltoush));
      play(e, '2C 3C QC 5C');
      expect(e.currentPlayer, 2);
      expect(e.state.trick!.leader, 2);
    });
  });

  group('P-K: شيخ الكبة (king of hearts)', () {
    test('P-K1 the taker of K♥ loses 75', () {
      // Seat 1's K♥ is the highest heart: seat 1 takes it.
      final s = finishedDeal(TrixContract.king, [tr(0, '2H KH 3H 4H')]);
      expect(TrixRules.dealPoints(s), [0, -75, 0, 0]);
    });

    test('P-K2 a player who cannot follow and holds K♥ must throw it', () {
      final e = TrixEngine(TrixState.withHands(kingDeal(), options: fixed0.copyWith(doubling: false)));
      e.apply(const TrixMove.contract(TrixContract.king));
      e.apply(TrixMove.play(p('2C')));
      expect(e.legalMoves(1), [TrixMove.play(p('KH'))]);
      expect(e.validate(TrixMove.play(p('AD'))), 'mustDiscardKing');
    });

    test('P-K2 a holder of K♥ who can follow suit follows normally', () {
      final e = TrixEngine(TrixState.withHands(aceDeal(), options: fixed0.copyWith(doubling: false)));
      e.apply(const TrixMove.contract(TrixContract.king));
      e.apply(TrixMove.play(p('2C')));
      expect(e.legalMoves(1).map((m) => m.card), c('KC AC'));
    });

    test('P-K2 option off: a void holder of K♥ may keep it', () {
      final e = TrixEngine(
        TrixState.withHands(kingDeal(), options: fixed0.copyWith(doubling: false).copyWith(kingMustBeDiscarded: false)),
      );
      e.apply(const TrixMove.contract(TrixContract.king));
      e.apply(TrixMove.play(p('2C')));
      expect(e.legalMoves(1), hasLength(13));
    });

    test('P-K3 no heart lead while holding another suit', () {
      final hands = kingDeal();
      hands[0] = c('2H AC KC QC JC TC 9C 8C 7C 6C 5C 4C 3C');
      hands[2] = c('AH QH JH TH 9H 8H 7H 6H 5H 4H 3H 2C 2D');
      final opts = fixed0.copyWith(doubling: false);
      final e = TrixEngine(TrixState.withHands(hands, options: opts));
      e.apply(const TrixMove.contract(TrixContract.king));
      expect(e.legalMoves(0).any((m) => m.card!.suit == Suit.hearts), isFalse);
      expect(e.validate(TrixMove.play(p('2H'))), 'noHeartLead');
      // In another contract the same lead is fine.
      final f = TrixEngine(TrixState.withHands(hands, options: opts));
      f.apply(const TrixMove.contract(TrixContract.ltoush));
      expect(f.legalMoves(0), contains(TrixMove.play(p('2H'))));
      // Option off: hearts may be led in King too.
      final g = TrixEngine(TrixState.withHands(hands, options: opts.copyWith(noHeartLeadInKing: false)));
      g.apply(const TrixMove.contract(TrixContract.king));
      expect(g.legalMoves(0), contains(TrixMove.play(p('2H'))));
    });

    test('P-K3 E-7 a leader with only hearts may lead any heart, K♥ included', () {
      final hands = kingDeal();
      // Seat 0: only hearts (K♥ included).
      hands[0] = c('KH QH JH TH 9H 8H 7H 6H 5H 4H 3H 2H AH');
      hands[1] = c('AC AD KD QD JD TD 9D 8D 7D 6D 5D 4D 3D');
      hands[2] = c('KC QC JC TC 9C 8C 7C 6C 5C 4C 3C 2C 2D');
      expectFullDeal(hands);
      final e = TrixEngine(TrixState.withHands(hands, options: fixed0.copyWith(doubling: false)));
      e.apply(const TrixMove.contract(TrixContract.king));
      expect(e.legalMoves(0), hasLength(13));
      expect(e.validate(TrixMove.play(p('KH'))), isNull);
    });

    test('P-K4 the King deal ends as soon as K♥ is taken', () {
      final e = TrixEngine(TrixState.withHands(kingDeal(), options: fixed0.copyWith(doubling: false)));
      e.apply(const TrixMove.contract(TrixContract.king));
      play(e, '2C KH 2D 2S');
      expect(e.state.dealsPlayed, 1);
      expect(e.state.results.single.points, [-75, 0, 0, 0]);
      expect(e.state.phase, TrixPhase.contract);
      expectFullDeal(e.state.hands);
    });

    test('P-K5 kingOnAceOfHearts (off by default): K♥ must go on a heart trick holding A♥', () {
      final base = fixed0.copyWith(doubling: false).copyWith(noHeartLeadInKing: false);
      final off = TrixEngine(TrixState.withHands(aceDeal(), options: base));
      off.apply(const TrixMove.contract(TrixContract.king));
      off.apply(TrixMove.play(p('AH')));
      expect(off.legalMoves(1).map((m) => m.card), unorderedEquals(c('3H 4H KH')));

      final on = TrixEngine(TrixState.withHands(aceDeal(), options: base.copyWith(kingOnAceOfHearts: true)));
      on.apply(const TrixMove.contract(TrixContract.king));
      on.apply(TrixMove.play(p('AH')));
      expect(on.legalMoves(1), [TrixMove.play(p('KH'))]);
      expect(on.validate(TrixMove.play(p('3H'))), 'mustPlayKingOnAce');
      expect(on.validate(TrixMove.play(p('2D'))), 'mustFollowSuit');

      // Without A♥ on the trick K♥ is not forced.
      final low = TrixEngine(TrixState.withHands(aceDeal(), options: base.copyWith(kingOnAceOfHearts: true)));
      low.apply(const TrixMove.contract(TrixContract.king));
      low.apply(TrixMove.play(p('2H')));
      expect(low.legalMoves(1).map((m) => m.card), unorderedEquals(c('3H 4H KH')));
    });
  });

  group('P-Q P-D P-L: البنات، الديناري، اللطوش', () {
    test('P-Q1 P-Q3 each queen −25; the deal ends when the fourth queen is taken', () {
      final e = TrixEngine(TrixState.withHands(suitsDeal(), options: fixed0.copyWith(doubling: false)));
      e.apply(const TrixMove.contract(TrixContract.queens));
      play(e, 'QS QH QD QC');
      expect(e.state.results.single.points, [-100, 0, 0, 0]);
    });

    test('P-Q2 no lead or discard restrictions in Queens', () {
      final e = TrixEngine(TrixState.withHands(aceDeal(), options: fixed0.copyWith(doubling: false)));
      e.apply(const TrixMove.contract(TrixContract.queens));
      expect(e.legalMoves(0), hasLength(13));
      final f = TrixEngine(TrixState.withHands(kingDeal(), options: fixed0.copyWith(doubling: false)));
      f.apply(const TrixMove.contract(TrixContract.queens));
      f.apply(TrixMove.play(p('2C')));
      expect(f.legalMoves(1), hasLength(13));
    });

    test('P-D1 P-D3 each diamond −10; the deal ends when all thirteen are taken', () {
      final hands = [
        c('AD KD QD JD AS KS QS JS TS 9S 8S 7S 6S'),
        c('TD 9D 8D 5S 4S 3S 2S AH KH QH JH TH 9H'),
        c('7D 6D 5D 8H 7H 6H 5H 4H 3H 2H AC KC QC'),
        c('4D 3D 2D JC TC 9C 8C 7C 6C 5C 4C 3C 2C'),
      ];
      expectFullDeal(hands);
      final e = TrixEngine(TrixState.withHands(hands, options: fixed0));
      e.apply(const TrixMove.contract(TrixContract.diamonds));
      play(e, 'AD TD 7D 4D KD 9D 6D 3D QD 8D 5D 2D JD 5S 8H JC');
      expect(e.state.results.single.points, [-130, 0, 0, 0]);
      expect(e.state.results.single.contract, TrixContract.diamonds);
    });

    test('P-D2 P-D4 DB-2 no doubling in Diamonds; diamonds are never doubled', () {
      final e = TrixEngine(TrixState.withHands(suitsDeal(), options: fixed0));
      e.apply(const TrixMove.contract(TrixContract.diamonds));
      expect(e.state.phase, TrixPhase.tricks);
      // In Complex Q♦ doubles as a queen; its −10 as a diamond never doubles.
      final s = finishedDeal(TrixContract.complex, [tr(1, 'AS 2S 3S QD')], doubled: {'QD': 0});
      expect(TrixRules.dealPoints(s), [25, -50 - 10 - 15, 0, 0]);
    });

    test('P-L1 P-L2 each trick −15, all 13 tricks are played, no doubling', () {
      final s = finishedDeal(TrixContract.ltoush, const [])..tricksTaken = [5, 4, 3, 1];
      expect(TrixRules.dealPoints(s), [-75, -60, -45, -15]);
      final e = TrixEngine(TrixState.withHands(suitsDeal(), options: fixed0));
      e.apply(const TrixMove.contract(TrixContract.ltoush));
      expect(e.state.phase, TrixPhase.tricks);
      playOut(e);
      expect(e.state.results.single.points, [-195, 0, 0, 0]);
    });
  });

  group('X: التركس (the layout)', () {
    test('X-1 X-2 X-5 jacks open each row, cards go on one rank at a time; 200/150/100/50', () {
      final e = TrixEngine(TrixState.withHands(suitsDeal(), options: fixed0));
      e.apply(const TrixMove.contract(TrixContract.trix));
      expect(e.legalMoves(0), [TrixMove.play(p('JS'))]);
      e.apply(TrixMove.play(p('JS')));
      expect(e.legalMoves(1), [TrixMove.play(p('JH'))]);
      e.apply(TrixMove.play(p('JH')));
      e.apply(TrixMove.play(p('JD')));
      e.apply(TrixMove.play(p('JC')));
      expect(e.legalMoves(0).map((m) => m.card), unorderedEquals([p('TS'), p('QS')]));
      expect(e.validate(TrixMove.play(p('9S'))), 'notPlayableOnLayout');
      playOut(e);
      expect(e.state.results.single.points, [200, 150, 100, 50]);
    });

    test('X-3 X-4 E-8 must play when able; pass (باص) only with no legal card', () {
      final hands = suitsDeal();
      hands[0] = c('AS KS QS JS TS 9S 8S 7S 6S 5S 4S 3S JH');
      hands[1] = c('2S AH KH QH TH 9H 8H 7H 6H 5H 4H 3H 2H');
      final e = TrixEngine(TrixState.withHands(hands, options: fixed0));
      e.apply(const TrixMove.contract(TrixContract.trix));
      expect(e.validate(const TrixMove.pass()), 'mustPlayWhenAble');
      e.apply(TrixMove.play(p('JS')));
      expect(e.legalMoves(1), [const TrixMove.pass()]);
      e.apply(const TrixMove.pass());
      expect(e.state.cannotHold[1], containsAll([p('TS'), p('QS'), p('JH'), p('JD'), p('JC')]));
      expect(e.currentPlayer, 2);
    });

    test('X-3 finished players are skipped', () {
      final s = TrixState.withHands(suitsDeal(), options: fixed0);
      final e = TrixEngine(s);
      e.apply(const TrixMove.contract(TrixContract.trix));
      // Seat 1 goes out first; afterwards the turn skips it.
      s.hands[1] = [p('JH')];
      play(e, 'JS JH');
      expect(s.finished, [1]);
      expect(e.currentPlayer, 2);
      play(e, 'JD JC');
      expect(e.currentPlayer, 0);
      e.apply(TrixMove.play(p('TS')));
      expect(e.currentPlayer, 2);
    });

    test('X-6 E-9 the third player out ends the deal; the fourth is placed last', () {
      final e = TrixEngine(TrixState.withHands(suitsDeal(), options: fixed0));
      e.apply(const TrixMove.contract(TrixContract.trix));
      final events = <CardEvent>[];
      while (e.state.dealsPlayed == 0) {
        events.addAll(e.apply(e.legalMoves(e.currentPlayer!).first));
      }
      final finished = events.where((x) => x.type == CardEventType.playerFinished).map((x) => x.seat).toList();
      expect(finished, [0, 1, 2]);
      expect(e.state.results.single.points, [200, 150, 100, 50]);
    });

    test('X-7 the layout never deadlocks and X-8 nothing is doubled in Trix', () {
      for (var seed = 1; seed <= 10; seed++) {
        final e = TrixEngine.newMatch(seed: seed);
        e.apply(const TrixMove.contract(TrixContract.trix));
        expect(e.state.phase, TrixPhase.layout);
        playOut(e);
        expect(sum(e.state.results.single.points), 500);
      }
    });

    test('X-5 partnership: places are scored per seat and summed by team', () {
      final s = TrixState.withHands(suitsDeal(), options: const TrixOptions(partnership: true))
        ..contract = TrixContract.trix
        ..finished = [0, 1, 2, 3];
      expect(TrixRules.dealPoints(s), [200, 150, 100, 50]);
      s.seatScores = [200, 150, 100, 50];
      expect(s.scores, [300, 200, 300, 200]);
      s
        ..finished = [0, 2, 1, 3]
        ..seatScores = TrixRules.dealPoints(s);
      expect(s.scores, [350, 150, 350, 150]);
      s
        ..finished = [0, 1, 3, 2]
        ..seatScores = TrixRules.dealPoints(s);
      expect(s.scores, [250, 250, 250, 250]);
    });
  });

  group('DB: doubling (الدبل)', () {
    test('DB-1 DB-4 doubling comes after the contract and before the first lead', () {
      final e = TrixEngine(TrixState.withHands(kingDeal(), options: fixed0));
      e.apply(const TrixMove.contract(TrixContract.king));
      expect(e.state.phase, TrixPhase.doubling);
      expect(e.state.trick, isNull);
      noDoubles(e);
      expect(e.state.phase, TrixPhase.tricks);
      expect(e.currentPlayer, 0);
      for (final k in [TrixContract.queens]) {
        final f = TrixEngine(TrixState.withHands(kingDeal(), options: fixed0));
        f.apply(TrixMove.contract(k));
        expect(f.state.phase, TrixPhase.doubling);
      }
      final g = TrixEngine(TrixState.withHands(kingDeal(), options: fixed0.copyWith(doubling: false)));
      g.apply(const TrixMove.contract(TrixContract.king));
      expect(g.state.phase, TrixPhase.tricks);
    });

    test('DB-2 DB-3 only K♥ (King) and queens (Queens); any subset of them', () {
      final e = TrixEngine(TrixState.withHands(roundRobinDeal()));
      e.apply(const TrixMove.contract(TrixContract.queens));
      // Owner 3 holds Q♦ only.
      expect(e.legalMoves(3), [TrixMove.double(const []), TrixMove.double([p('QD')])]);
      e.apply(TrixMove.double(const []));
      // Seat 0: Q♥; seat 1: Q♠.
      expect(e.legalMoves(0), [TrixMove.double(const []), TrixMove.double([p('QH')])]);
      final s = TrixState.withHands(suitsDeal(), options: fixed0);
      s.hands[0] = c('QS QH QD QC 2S 3S 4S 5S 6S 7S 8S 9S TS');
      final f = TrixEngine(s);
      f.apply(const TrixMove.contract(TrixContract.queens));
      expect(f.legalMoves(0), hasLength(16));
      final k = TrixEngine(TrixState.withHands(roundRobinDeal()));
      k.apply(const TrixMove.contract(TrixContract.king));
      expect(k.legalMoves(3), [TrixMove.double(const [])]);
      k.apply(TrixMove.double(const []));
      k.apply(TrixMove.double(const []));
      expect(k.legalMoves(1), [TrixMove.double(const []), TrixMove.double([p('KH')])]);
      final x = TrixEngine(TrixState.withHands(roundRobinDeal(), options: const TrixOptions(mode: TrixMode.complex)));
      x.apply(const TrixMove.contract(TrixContract.complex));
      x.apply(TrixMove.double(const []));
      x.apply(TrixMove.double(const []));
      // Complex: seat 1 may double K♥ and Q♠ (4 subsets).
      expect(x.legalMoves(1), hasLength(4));
    });

    test('DB-5 E-2 simultaneous: every seat answers, a seat with nothing to double has one move', () {
      final e = TrixEngine(TrixState.withHands(kingDeal(), options: fixed0));
      e.apply(const TrixMove.contract(TrixContract.king));
      final answered = <int>[];
      while (e.state.phase == TrixPhase.doubling) {
        final seat = e.currentPlayer!;
        answered.add(seat);
        if (seat != 1) expect(e.legalMoves(seat), [TrixMove.double(const [])]);
        e.apply(e.legalMoves(seat).first);
      }
      expect(answered, [0, 1, 2, 3]);
    });

    test('DB-5 simultaneous: answers stay hidden until the fourth, then are revealed together', () {
      final e = TrixEngine(TrixState.withHands(roundRobinDeal(), options: const TrixOptions(mode: TrixMode.complex)));
      e.apply(const TrixMove.contract(TrixContract.complex));
      // Owner 3 doubles Q♦; seat 0 nothing; seat 1 K♥; seat 2 Q♣.
      final ev3 = e.apply(TrixMove.double([p('QD')]));
      expect(ev3.single.type, CardEventType.doubled);
      expect(ev3.single.cards, isEmpty);
      expect(ev3.single.detail, TrixEventDetail.doublingAnswered);
      expect(e.state.doubled, isEmpty);
      expect(e.state.pendingDoubles, {p('QD'): 3});
      expect(e.state.doublesVisibleTo(3), {p('QD'): 3});
      expect(e.state.doublesVisibleTo(0), isEmpty);
      final ev0 = e.apply(TrixMove.double(const []));
      expect(ev0.single.detail, TrixEventDetail.doublingAnswered);
      expect(ev0.single.cards, isEmpty);
      e.apply(TrixMove.double([p('KH')]));
      expect(e.state.doubled, isEmpty);
      expect(e.state.doublingAnswered, [3, 0, 1]);
      final last = e.apply(TrixMove.double([p('QC')]));
      expect(e.state.doubled, {p('QD'): 3, p('KH'): 1, p('QC'): 2});
      expect(e.state.pendingDoubles, isEmpty);
      final reveals = last.where((x) => x.detail == TrixEventDetail.doublingRevealed).toList();
      // Seat order from the owner: 3, (0 nothing), 1, 2.
      expect(reveals.map((x) => x.seat), [3, 1, 2]);
      expect(reveals.map((x) => x.cards), [
        [p('QD')],
        [p('KH')],
        [p('QC')],
      ]);
      expect(e.state.phase, TrixPhase.tricks);
      expect(e.currentPlayer, 3);
    });

    test('DB-5 sequential option: each double is public at once', () {
      final e = TrixEngine(
        TrixState.withHands(
          kingDeal(),
          options: fixed0.copyWith(doublingReveal: TrixDoublingReveal.sequential),
        ),
      );
      e.apply(const TrixMove.contract(TrixContract.king));
      expect(e.apply(TrixMove.double(const [])).single.type, CardEventType.pass);
      final ev = e.apply(TrixMove.double([p('KH')]));
      expect(ev.single.type, CardEventType.doubled);
      expect(ev.single.cards, [p('KH')]);
      expect(e.state.doubled, {p('KH'): 1});
      expect(e.state.pendingDoubles, isEmpty);
    });

    test('DB-6 DB-7 a doubled card stays public and may be led', () {
      final hands = kingDeal();
      final e = TrixEngine(TrixState.withHands(hands, options: fixed0));
      e.apply(const TrixMove.contract(TrixContract.queens));
      e.apply(TrixMove.double([p('QC')]));
      noDoubles(e);
      expect(e.state.doubled, {p('QC'): 0});
      expect(e.validate(TrixMove.play(p('QC'))), isNull);
      e.apply(TrixMove.play(p('QC')));
      expect(e.state.doubled, {p('QC'): 0});
    });

    test('DB-S1 an undoubled card costs its taker the normal value', () {
      final s = finishedDeal(TrixContract.queens, [tr(1, '4C 2S QC 3D')]);
      expect(TrixRules.dealPoints(s), [0, 0, 0, -25]);
    });

    test('DB-S2 §6.3-1 doubled card taken by another: taker −2×, doubler +1×', () {
      final e = TrixEngine(TrixState.withHands(kingDeal(), options: fixed0));
      e.apply(const TrixMove.contract(TrixContract.king));
      e.apply(TrixMove.double(const []));
      expect(e.legalMoves(1), [TrixMove.double(const []), TrixMove.double([p('KH')])]);
      e.apply(TrixMove.double([p('KH')]));
      e.apply(TrixMove.double(const []));
      expect(e.state.doubled, isEmpty);
      e.apply(TrixMove.double(const []));
      expect(e.state.doubled, {p('KH'): 1});
      expect(e.currentPlayer, 0);
      play(e, '2C KH 2D 2S');
      expect(e.state.results.single.points, [-150, 75, 0, 0]);
      for (final rule in TrixSelfCapture.values) {
        final s = finishedDeal(
          TrixContract.queens,
          [tr(1, '4C AS QC AC')],
          options: fixed0.copyWith(selfCaptureRule: rule),
          doubled: {'QC': 3},
        );
        expect(TrixRules.dealPoints(s), [-50, 0, 0, 25], reason: rule.name);
      }
    });

    // Individual: seat 3 doubled Q♣. Forced: seat 1 led 4♣ and Q♣ won.
    // Self-led: seat 3 led Q♣ and it won.
    final forced = tr(1, '4C 2S QC 3D');
    final selfLed = tr(3, 'QC 2S 3D 4C');
    const table = {
      TrixSelfCapture.leaderGains: ([0, 25, 0, -50], [0, 0, 0, -25]),
      TrixSelfCapture.leaderGainsStrict: ([0, 25, 0, -50], [0, 0, 0, -50]),
      TrixSelfCapture.normalValue: ([0, 0, 0, -25], [0, 0, 0, -25]),
      TrixSelfCapture.doubleNoBonus: ([0, 0, 0, -50], [0, 0, 0, -50]),
    };
    for (final entry in table.entries) {
      final rule = entry.key;
      test('DB-S3 selfCaptureRule ${rule.name}: doubler forced to take his own card', () {
        final s = finishedDeal(
          TrixContract.queens,
          [forced],
          options: fixed0.copyWith(selfCaptureRule: rule),
          doubled: {'QC': 3},
        );
        expect(TrixRules.dealPoints(s), entry.value.$1);
      });
      test('DB-S4 selfCaptureRule ${rule.name}: doubler led his own card and won it', () {
        final s = finishedDeal(
          TrixContract.queens,
          [selfLed],
          options: fixed0.copyWith(selfCaptureRule: rule),
          doubled: {'QC': 3},
        );
        expect(TrixRules.dealPoints(s), entry.value.$2);
      });
    }

    test('DB-S3 §6.3-2 through play: seat 1 leads ♣4, seat 3 follows with its doubled Q♣', () {
      final hands = [
        c('2S 3S 4S 5S 6S 7S 8S 9S TS JS QS KS AS'),
        c('4C 2H 3H 4H 5H 6H 7H 8H 9H TH JH QH KH'),
        c('AH 2D 3D 4D 5D 6D 7D 8D 9D TD JD QD KD'),
        c('QC AD 2C 3C 5C 6C 7C 8C 9C TC JC KC AC'),
      ];
      expectFullDeal(hands);
      // 7♥ at seat 1: seat 1 owns and leads.
      final e = TrixEngine(TrixState.withHands(hands));
      e.apply(const TrixMove.contract(TrixContract.queens));
      // Answers from the owner: seat 1, 2, 3 (doubles Q♣), 0.
      e.apply(TrixMove.double(const []));
      e.apply(TrixMove.double(const []));
      e.apply(TrixMove.double([p('QC')]));
      e.apply(TrixMove.double(const []));
      play(e, '4C AH QC 2S');
      final pts = TrixRules.dealPoints(e.state);
      expect(pts, [0, 25, 0, -50]);
    });

    test('DB-S4 §6.3-3 E-5 through play: a self-led doubled K♥ costs its doubler 75', () {
      final hands = kingDeal();
      hands[0] = c('KH QH JH TH 9H 8H 7H 6H 5H 4H 3H 2H AH');
      hands[1] = c('AC AD KD QD JD TD 9D 8D 7D 6D 5D 4D 3D');
      hands[2] = c('KC QC JC TC 9C 8C 7C 6C 5C 4C 3C 2C 2D');
      final e = TrixEngine(TrixState.withHands(hands));
      expect(e.state.owner, 0);
      e.apply(const TrixMove.contract(TrixContract.king));
      e.apply(TrixMove.double([p('KH')]));
      noDoubles(e);
      play(e, 'KH 3D 2C 2S');
      expect(e.state.results.single.points, [-75, 0, 0, 0]);
    });

    test('DB-P1 partnership: an opponent takes it: taker −2×, doubler +1×', () {
      for (final rule in TrixPartnerCapture.values) {
        final s = finishedDeal(
          TrixContract.queens,
          [tr(0, 'QS AS 2S 3S')],
          options: fixed0.copyWith(partnership: true, partnerCaptureRule: rule),
          doubled: {'QS': 0},
        );
        expect(TrixRules.dealPoints(s), [25, -50, 0, 0], reason: rule.name);
      }
    });

    // Partnership: seat 0 doubled Q♠.
    final partnerTakes = tr(1, '3S AS 4S QS'); // opponent led, partner 2 won
    final partnerTakesOwnLead = tr(0, 'QS 3S AS 4S'); // doubler led, partner 2 won
    final doublerForcedByOpp = tr(1, '3S 4S 5S QS'); // opponent led, doubler won
    final doublerForcedByPartner = tr(2, '3S 4S QS 5S'); // partner led, doubler won
    final doublerSelfLed = tr(0, 'QS 3S 4S 5S');
    const partnerTable = {
      TrixPartnerCapture.noBonus: [
        [0, 0, -50, 0],
        [0, 0, -50, 0],
        [-50, 0, 0, 0],
        [-50, 0, 0, 0],
        [-50, 0, 0, 0],
      ],
      TrixPartnerCapture.opponentsGain: [
        [0, 25, -50, 0],
        [0, 25, -50, 0],
        [-50, 25, 0, 0],
        [-50, 0, 0, 25],
        [-25, 0, 0, 0],
      ],
      TrixPartnerCapture.normalValue: [
        [0, 0, -25, 0],
        [0, 0, -25, 0],
        [-25, 0, 0, 0],
        [-25, 0, 0, 0],
        [-25, 0, 0, 0],
      ],
    };
    for (final entry in partnerTable.entries) {
      test('DB-P2 DB-P3 partnerCaptureRule ${entry.key.name}: the doubler\'s own team takes it', () {
        final cases = [partnerTakes, partnerTakesOwnLead, doublerForcedByOpp, doublerForcedByPartner, doublerSelfLed];
        for (var i = 0; i < cases.length; i++) {
          final s = finishedDeal(
            TrixContract.queens,
            [cases[i]],
            options: fixed0.copyWith(partnership: true, partnerCaptureRule: entry.key),
            doubled: {'QS': 0},
          );
          expect(TrixRules.dealPoints(s), entry.value[i], reason: 'case $i');
        }
      });
    }

    test('§6.3-4 partnership default: partner takes the doubled Q♠: −50, nobody gains', () {
      final s = finishedDeal(
        TrixContract.queens,
        [partnerTakes],
        options: fixed0.copyWith(partnership: true),
        doubled: {'QS': 0},
      );
      expect(TrixRules.dealPoints(s), [0, 0, -50, 0]);
      s.seatScores = TrixRules.dealPoints(s);
      expect(s.scores, [-50, 0, -50, 0]);
    });

    test('§6.3-5 Complex: seat 1 takes Q♦ doubled by seat 0: −50 −10 −15, doubler +25', () {
      final s = finishedDeal(TrixContract.complex, [tr(1, 'AS 2S 3S QD')], doubled: {'QD': 0});
      expect(TrixRules.dealPoints(s), [25, -75, 0, 0]);
    });

    test('§6.3-6 Complex: seat 2 must throw its doubled K♥ on seat 3\'s lead; seat 0 wins', () {
      final hands = [
        c('AC KC QC JC TC 9C 8C 7C 6C JS QS KS AS'),
        c('5C AD KD QD JD TD 9D 8D 7D 6D 5D 4D 3D'),
        c('KH AH QH JH TH 9H 8H 6H 5H 4H 3H 2H 2D'),
        c('7H 2C 3C 4C 2S 3S 4S 5S 6S 7S 8S 9S TS'),
      ];
      expectFullDeal(hands);
      final e = TrixEngine(TrixState.withHands(hands, options: const TrixOptions(mode: TrixMode.complex)));
      expect(e.currentPlayer, 3);
      e.apply(const TrixMove.contract(TrixContract.complex));
      e.apply(TrixMove.double(const []));
      e.apply(TrixMove.double(const []));
      e.apply(TrixMove.double(const []));
      e.apply(TrixMove.double([p('KH')]));
      e.apply(TrixMove.play(p('2C')));
      e.apply(TrixMove.play(p('AC')));
      e.apply(TrixMove.play(p('5C')));
      expect(e.legalMoves(2), [TrixMove.play(p('KH'))]);
      e.apply(TrixMove.play(p('KH')));
      expect(TrixRules.dealPoints(e.state), [-150 - 15, 0, 75, 0]);
    });

    test('E-4 the King deal scores with the trick that captured the doubled K♥', () {
      final e = TrixEngine(TrixState.withHands(kingDeal(), options: fixed0));
      e.apply(const TrixMove.contract(TrixContract.king));
      e.apply(TrixMove.double(const []));
      e.apply(TrixMove.double([p('KH')]));
      noDoubles(e);
      play(e, '2C KH 2D 2S');
      expect(e.state.results.single.points, [-150, 75, 0, 0]);
      expect(TrixRules.trickHolding(e.state, p('KH')), isNull, reason: 'a new deal started');
    });
  });

  group('C: الكومبلكس (Complex)', () {
    test('C-1 C-6 two contracts per kingdom, eight deals; the match is 4 kingdoms', () {
      final e = TrixEngine.newMatch(seed: 4, options: const TrixOptions(mode: TrixMode.complex));
      expect(e.legalMoves(e.currentPlayer!).map((m) => m.contract), [TrixContract.complex, TrixContract.trix]);
      playOut(e, deals: 100);
      expect(e.isOver, isTrue);
      expect(e.state.results.length, 8);
      expect(e.state.results.where((r) => r.contract == TrixContract.complex), hasLength(4));
    });

    test('C-2 C-3 penalties stack: Q♦ is a queen and a diamond', () {
      final s = finishedDeal(TrixContract.complex, const [])
        ..taken = [c('KH QD 2D'), <PlayingCard>[], c('QS'), <PlayingCard>[]]
        ..tricksTaken = [2, 0, 1, 0];
      expect(TrixRules.dealPoints(s), [-75 - 25 - 20 - 30, 0, -25 - 15, 0]);
    });

    test('C-4 C-5 all 13 tricks are always played; the deal totals −500', () {
      final e = TrixEngine(TrixState.withHands(suitsDeal(), options: fixed0.copyWith(mode: TrixMode.complex)));
      e.apply(const TrixMove.contract(TrixContract.complex));
      noDoubles(e);
      // Seat 0 (spades) leads and wins every trick; K♥ and the queens fall early.
      play(e, 'QS KH QD QC');
      expect(e.state.dealsPlayed, 0);
      playOut(e);
      expect(e.state.results.single.points, [-500, 0, 0, 0]);
    });

    test('C-6 doubling applies in Complex (K♥ and queens)', () {
      final e = TrixEngine(TrixState.withHands(roundRobinDeal(), options: const TrixOptions(mode: TrixMode.complex)));
      e.apply(const TrixMove.contract(TrixContract.complex));
      expect(e.state.phase, TrixPhase.doubling);
    });

    test('C-7 the king rules apply in Complex unless kingRulesInComplex is off', () {
      final base = fixed0.copyWith(doubling: false).copyWith(mode: TrixMode.complex);
      final on = TrixEngine(TrixState.withHands(kingDeal(), options: base));
      on.apply(const TrixMove.contract(TrixContract.complex));
      on.apply(TrixMove.play(p('2C')));
      expect(on.legalMoves(1), [TrixMove.play(p('KH'))]);
      final off = TrixEngine(TrixState.withHands(kingDeal(), options: base.copyWith(kingRulesInComplex: false)));
      off.apply(const TrixMove.contract(TrixContract.complex));
      off.apply(TrixMove.play(p('2C')));
      expect(off.legalMoves(1), hasLength(13));
      // Heart leads: banned with the king rules, allowed without.
      final a = TrixEngine(TrixState.withHands(aceDeal(), options: base));
      a.apply(const TrixMove.contract(TrixContract.complex));
      expect(a.legalMoves(0).any((m) => m.card!.suit == Suit.hearts), isFalse);
      final b = TrixEngine(TrixState.withHands(aceDeal(), options: base.copyWith(kingRulesInComplex: false)));
      b.apply(const TrixMove.contract(TrixContract.complex));
      expect(b.legalMoves(0), hasLength(13));
      // K♥ on A♥ follows the same switch.
      final ace = base.copyWith(noHeartLeadInKing: false, kingOnAceOfHearts: true);
      final c1 = TrixEngine(TrixState.withHands(aceDeal(), options: ace));
      c1.apply(const TrixMove.contract(TrixContract.complex));
      c1.apply(TrixMove.play(p('AH')));
      expect(c1.legalMoves(1), [TrixMove.play(p('KH'))]);
      final c2 = TrixEngine(TrixState.withHands(aceDeal(), options: ace.copyWith(kingRulesInComplex: false)));
      c2.apply(const TrixMove.contract(TrixContract.complex));
      c2.apply(TrixMove.play(p('AH')));
      expect(c2.legalMoves(1), hasLength(3));
    });
  });

  group('M: match end', () {
    test('M-1 classic: 20 deals, then the match is over', () {
      final e = TrixEngine.newMatch(seed: 21);
      playOut(e, deals: 19);
      expect(e.isOver, isFalse);
      final events = <CardEvent>[];
      while (!e.isOver) {
        events.addAll(e.apply(e.legalMoves(e.currentPlayer!).first));
      }
      expect(e.state.results, hasLength(20));
      expect(events.last.type, CardEventType.matchOver);
      expect(e.currentPlayer, isNull);
      expect(e.legalMoves(0), isEmpty);
      expect(e.validate(const TrixMove.pass()), 'matchOver');
    });

    test('M-2 M-3 highest total wins; individual kingdoms sum to 0 without doubles', () {
      final e = TrixEngine.newMatch(seed: 22, options: const TrixOptions(doubling: false));
      playOut(e, deals: 20);
      expect(sum(e.state.seatScores), 0);
      final best = e.scores.reduce((a, b) => a > b ? a : b);
      expect(e.state.winners, [
        for (var i = 0; i < 4; i++)
          if (e.scores[i] == best) i,
      ]);
    });

    test('M-4 a tie for first place is a shared win (draw)', () {
      final s = TrixState.withHands(suitsDeal())
        ..phase = TrixPhase.over
        ..seatScores = [100, 100, -50, -150];
      expect(s.winners, [0, 1]);
      final t = TrixState.withHands(suitsDeal(), options: const TrixOptions(partnership: true))
        ..phase = TrixPhase.over
        ..seatScores = [100, 20, -100, -20];
      expect(t.winners, [0, 1, 2, 3]);
    });

    test('M-5 partnership: partners share the team total; negative totals are allowed', () {
      final s = TrixState.withHands(suitsDeal(), options: const TrixOptions(partnership: true))
        ..seatScores = [10, 20, -130, 40];
      expect(s.scores, [-120, 60, -120, 60]);
      expect(s.teamOf(2), 0);
      expect(s.teamOf(3), 1);
      s.phase = TrixPhase.over;
      expect(s.winners, [1, 3]);
    });
  });

  group('J: save and load', () {
    test('J-1 options JSON round-trip keeps every option', () {
      const all = TrixOptions(
        partnership: true,
        mode: TrixMode.complex,
        doubling: false,
        kingPenalty: 50,
        queenPenalty: 20,
        diamondPenalty: 5,
        trickPenalty: 10,
        trixScores: [250, 150, 75, 25],
        noHeartLeadInKing: false,
        kingMustBeDiscarded: false,
        kingOnAceOfHearts: true,
        kingRulesInComplex: false,
        firstOwnerRule: TrixFirstOwner.fixedSeat,
        firstOwner: 3,
        doublingReveal: TrixDoublingReveal.sequential,
        selfCaptureRule: TrixSelfCapture.leaderGainsStrict,
        partnerCaptureRule: TrixPartnerCapture.opponentsGain,
      );
      for (final o in [const TrixOptions(), const TrixOptions.openDoubling(), all]) {
        expect(TrixOptions.fromJson(o.toJson()), o);
        expect(TrixOptions.fromJson(o.toJson()).hashCode, o.hashCode);
      }
    });

    test('J-2 an older options map without the new keys loads with the Jordanian defaults', () {
      final old = {
        'partnership': false,
        'mode': 'classic',
        'doubling': true,
        'kingPenalty': 75,
        'queenPenalty': 25,
        'diamondPenalty': 10,
        'trickPenalty': 15,
        'trixScores': [200, 150, 100, 50],
        'noHeartLeadInKing': true,
        'kingMustBeDiscarded': true,
        'firstOwner': 0,
      };
      expect(TrixOptions.fromJson(old), const TrixOptions());
      expect(TrixOptions.fromJson(const {}), const TrixOptions());
    });

    test('J-3 a match saved during hidden doubling resumes with the hidden answers', () {
      final e = TrixEngine(TrixState.withHands(roundRobinDeal()));
      e.apply(const TrixMove.contract(TrixContract.queens));
      e.apply(TrixMove.double([p('QD')]));
      final json = e.toJson();
      expect(json['pendingDoubles'], [
        ['QD', 3],
      ]);
      final r = TrixEngine.fromJson(json);
      expect(r.state.pendingDoubles, {p('QD'): 3});
      expect(r.state.doubled, isEmpty);
      expect(r.toJson().toString(), json.toString());
      noDoubles(r);
      expect(r.state.doubled, {p('QD'): 3});
    });

    test('J-4 a state saved before pendingDoubles existed still loads', () {
      final e = TrixEngine.newMatch(seed: 2);
      final json = Map<String, Object?>.of(e.toJson())..remove('pendingDoubles');
      expect(TrixEngine.fromJson(json).state.pendingDoubles, isEmpty);
    });

    test('J-5 moves round-trip through JSON', () {
      final moves = [
        const TrixMove.contract(TrixContract.complex),
        TrixMove.double(const []),
        TrixMove.double([p('QS'), p('KH')]),
        TrixMove.play(p('7H')),
        const TrixMove.pass(),
      ];
      for (final m in moves) {
        expect(TrixMove.fromJson(m.toJson()), m);
      }
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/cinema/rules/cards/cards.dart';

List<PlayingCard> c(String ids) => PlayingCard.list(ids);
PlayingCard p(String id) => PlayingCard.parse(id);

/// Seat 0 all spades, 1 all hearts, 2 all diamonds, 3 all clubs.
List<List<PlayingCard>> suitsDeal() => [
  for (final s in [Suit.spades, Suit.hearts, Suit.diamonds, Suit.clubs])
    [for (final r in Rank.values) PlayingCard(s, r)],
];

void playOut(TrixEngine e, {int deals = 1}) {
  final target = e.state.dealsPlayed + deals;
  while (!e.isOver && e.state.dealsPlayed < target) {
    e.apply(e.legalMoves(e.currentPlayer!).first);
  }
}

void main() {
  group('kingdoms', () {
    test('the owner picks each contract once; after five the next seat owns', () {
      final e = TrixEngine(TrixState.withHands(suitsDeal()));
      expect(e.currentPlayer, 0);
      expect(e.legalMoves(0).map((m) => m.contract), TrixContract.values.take(5));
      e.apply(const TrixMove.contract(TrixContract.ltoush));
      playOut(e);
      expect(e.state.owner, 0);
      expect(e.legalMoves(0).map((m) => m.contract), isNot(contains(TrixContract.ltoush)));
      expect(e.validate(const TrixMove.contract(TrixContract.ltoush)), 'contractAlreadyPlayed');
      for (var i = 0; i < 4; i++) {
        e.apply(e.legalMoves(0).first);
        playOut(e);
      }
      expect(e.state.kingdom, 1);
      expect(e.state.owner, 1);
      expect(e.currentPlayer, 1);
    });

    test('complex mode has two contracts per kingdom; the match is 4 kingdoms', () {
      final e = TrixEngine.newMatch(seed: 4, options: const TrixOptions(mode: TrixMode.complex));
      expect(e.legalMoves(0).map((m) => m.contract), [TrixContract.complex, TrixContract.trix]);
      var guard = 0;
      while (!e.isOver && guard++ < 5000) {
        e.apply(e.legalMoves(e.currentPlayer!).first);
      }
      expect(e.isOver, isTrue);
      expect(e.state.results.length, 8);
    });
  });

  group('king of hearts', () {
    List<List<PlayingCard>> deal() => [
      c('AC KC QC JC TC 9C 8C 7C 6C 5C 4C 3C 2C'),
      c('KH AD KD QD JD TD 9D 8D 7D 6D 5D 4D 3D'),
      c('AH QH JH TH 9H 8H 7H 6H 5H 4H 3H 2H 2D'),
      c('AS KS QS JS TS 9S 8S 7S 6S 5S 4S 3S 2S'),
    ];

    test('doubling, the forced discard of K♥ and the doubled scoring', () {
      final e = TrixEngine(TrixState.withHands(deal()));
      e.apply(const TrixMove.contract(TrixContract.king));
      expect(e.state.phase, TrixPhase.doubling);
      expect(e.legalMoves(0), [TrixMove.double(const [])]);
      e.apply(TrixMove.double(const []));
      expect(e.legalMoves(1), [TrixMove.double(const []), TrixMove.double([p('KH')])]);
      e.apply(TrixMove.double([p('KH')]));
      e.apply(TrixMove.double(const []));
      e.apply(TrixMove.double(const []));
      expect(e.state.doubled, {p('KH'): 1});
      expect(e.currentPlayer, 0);
      e.apply(TrixMove.play(p('2C')));
      // Seat 1 cannot follow clubs and holds K♥: it must throw it.
      expect(e.legalMoves(1), [TrixMove.play(p('KH'))]);
      expect(e.validate(TrixMove.play(p('AD'))), 'mustDiscardKing');
      e.apply(TrixMove.play(p('KH')));
      e.apply(TrixMove.play(p('2D')));
      e.apply(TrixMove.play(p('2S')));
      // Seat 0 took the doubled king: -150, the doubler +75; the deal ends.
      expect(e.state.results.single.points, [-150, 75, 0, 0]);
      expect(e.state.dealsPlayed, 1);
      expect(e.state.phase, TrixPhase.contract);
    });

    test('hearts may not be led while the leader holds another suit', () {
      final hands = deal();
      hands[0] = c('2H AC KC QC JC TC 9C 8C 7C 6C 5C 4C 3C');
      hands[2] = c('AH QH JH TH 9H 8H 7H 6H 5H 4H 3H 2C 2D');
      final e = TrixEngine(TrixState.withHands(hands, options: const TrixOptions(doubling: false)));
      e.apply(const TrixMove.contract(TrixContract.king));
      expect(e.legalMoves(0).any((m) => m.card!.suit == Suit.hearts), isFalse);
      expect(e.validate(TrixMove.play(p('2H'))), 'noHeartLead');
      // In another contract the same lead is fine.
      final f = TrixEngine(TrixState.withHands(hands, options: const TrixOptions(doubling: false)));
      f.apply(const TrixMove.contract(TrixContract.ltoush));
      expect(f.legalMoves(0), contains(TrixMove.play(p('2H'))));
    });
  });

  test('queens: the deal ends when the fourth queen is taken', () {
    final e = TrixEngine(TrixState.withHands(suitsDeal(), options: const TrixOptions(doubling: false)));
    e.apply(const TrixMove.contract(TrixContract.queens));
    e.apply(TrixMove.play(p('QS')));
    e.apply(TrixMove.play(p('QH')));
    e.apply(TrixMove.play(p('QD')));
    e.apply(TrixMove.play(p('QC')));
    expect(e.state.results.single.points, [-100, 0, 0, 0]);
  });

  test('diamonds: the deal ends as soon as all thirteen diamonds are taken', () {
    final hands = [
      c('AD KD QD JD AS KS QS JS TS 9S 8S 7S 6S'),
      c('TD 9D 8D 5S 4S 3S 2S AH KH QH JH TH 9H'),
      c('7D 6D 5D 8H 7H 6H 5H 4H 3H 2H AC KC QC'),
      c('4D 3D 2D JC TC 9C 8C 7C 6C 5C 4C 3C 2C'),
    ];
    final e = TrixEngine(TrixState.withHands(hands));
    e.apply(const TrixMove.contract(TrixContract.diamonds));
    for (final trick in [
      ['AD', 'TD', '7D', '4D'],
      ['KD', '9D', '6D', '3D'],
      ['QD', '8D', '5D', '2D'],
      ['JD', '5S', '8H', 'JC'],
    ]) {
      for (final id in trick) {
        e.apply(TrixMove.play(p(id)));
      }
    }
    expect(e.state.results.single.points, [-130, 0, 0, 0]);
    expect(e.state.results.single.contract, TrixContract.diamonds);
  });

  group('scoring', () {
    TrixState scored(TrixContract contract, {TrixOptions options = const TrixOptions()}) =>
        TrixState.withHands(suitsDeal(), options: options)..contract = contract;

    test('ltoush −15 per trick; queens −25 (doubled −50, doubler +25)', () {
      final s = scored(TrixContract.ltoush)..tricksTaken = [5, 4, 3, 1];
      expect(TrixRules.dealPoints(s), [-75, -60, -45, -15]);
      final q = scored(TrixContract.queens)
        ..taken = [
          c('QS QH'),
          c('QD'),
          <PlayingCard>[],
          c('QC'),
        ]
        ..doubled = {p('QS'): 2, p('QC'): 3};
      // Seat 0: Q♠ doubled by seat 2 (−50, seat 2 +25) and Q♥ (−25).
      // Seat 3 took its own doubled Q♣: −50, no bonus.
      expect(TrixRules.dealPoints(q), [-75, -25, 25, -50]);
    });

    test('complex adds everything: Q♦ counts as a queen and a diamond', () {
      final s = scored(TrixContract.complex)
        ..taken = [
          c('KH QD 2D'),
          <PlayingCard>[],
          c('QS'),
          <PlayingCard>[],
        ]
        ..tricksTaken = [2, 0, 1, 0];
      expect(TrixRules.dealPoints(s), [-75 - 25 - 20 - 30, 0, -25 - 15, 0]);
    });

    test('partnership: team totals, no doubling bonus when the partner takes it', () {
      final s = scored(TrixContract.king, options: const TrixOptions(partnership: true))
        ..taken = [<PlayingCard>[], <PlayingCard>[], c('KH'), <PlayingCard>[]]
        ..doubled = {p('KH'): 0};
      expect(TrixRules.dealPoints(s), [0, 0, -150, 0]);
      s.seatScores = [10, 20, 30, 40];
      expect(s.scores, [40, 60, 40, 60]);
      expect(s.teamOf(2), 0);
    });
  });

  group('trix layout', () {
    test('jacks open each suit, cards go on in sequence; 200/150/100/50', () {
      final e = TrixEngine(TrixState.withHands(suitsDeal()));
      e.apply(const TrixMove.contract(TrixContract.trix));
      expect(e.legalMoves(0), [TrixMove.play(p('JS'))]);
      e.apply(TrixMove.play(p('JS')));
      expect(e.legalMoves(1), [TrixMove.play(p('JH'))]);
      e.apply(TrixMove.play(p('JH')));
      e.apply(TrixMove.play(p('JD')));
      e.apply(TrixMove.play(p('JC')));
      expect(e.legalMoves(0).map((m) => m.card), unorderedEquals([p('TS'), p('QS')]));
      playOut(e);
      expect(e.state.results.single.points, [200, 150, 100, 50]);
    });

    test('a player who cannot play passes (and only then)', () {
      final hands = suitsDeal();
      hands[0] = c('AS KS QS JS TS 9S 8S 7S 6S 5S 4S 3S JH');
      hands[1] = c('2S AH KH QH TH 9H 8H 7H 6H 5H 4H 3H 2H');
      final e = TrixEngine(TrixState.withHands(hands));
      e.apply(const TrixMove.contract(TrixContract.trix));
      expect(e.validate(const TrixMove.pass()), 'mustPlayWhenAble');
      e.apply(TrixMove.play(p('JS')));
      expect(e.legalMoves(1), [const TrixMove.pass()]);
      e.apply(const TrixMove.pass());
      expect(e.state.cannotHold[1], containsAll([p('TS'), p('QS'), p('JH'), p('JD'), p('JC')]));
      expect(e.currentPlayer, 2);
    });
  });
}

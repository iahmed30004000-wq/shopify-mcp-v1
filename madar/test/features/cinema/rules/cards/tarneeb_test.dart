import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/cinema/rules/cards/core/card_game.dart';
import 'package:madar/features/cinema/rules/cards/core/playing_card.dart';
import 'package:madar/features/cinema/rules/cards/tarneeb/tarneeb_ai.dart';
import 'package:madar/features/cinema/rules/cards/tarneeb/tarneeb_rules.dart';
import 'package:madar/features/cinema/rules/cards/tarneeb/tarneeb_state.dart';

List<PlayingCard> c(String ids) => PlayingCard.list(ids);

/// A fixed deal: seat 0 all spades, 1 all hearts, 2 all diamonds, 3 all clubs.
List<List<PlayingCard>> suitsDeal() => [
  for (final s in [Suit.spades, Suit.hearts, Suit.diamonds, Suit.clubs])
    [for (final r in Rank.values) PlayingCard(s, r)],
];

void main() {
  group('auction', () {
    test('first bidder is the dealer\'s right; bids must rise; 7..13', () {
      final e = TarneebEngine(TarneebState.withHands(suitsDeal()));
      expect(e.currentPlayer, 0);
      expect(e.legalMoves(0), [
        const TarneebMove.pass(),
        for (var b = 7; b <= 13; b++) TarneebMove.bid(b),
      ]);
      e.apply(const TarneebMove.bid(8));
      expect(e.currentPlayer, 1);
      expect(e.legalMoves(1).where((m) => m.kind == TarneebMoveKind.bid).first, const TarneebMove.bid(9));
      expect(e.validate(const TarneebMove.bid(8)), 'bidTooLow');
      expect(() => e.apply(const TarneebMove.bid(7)), throwsA(isA<IllegalMoveException>()));
    });

    test('a passed player is skipped and the auction ends when the others passed', () {
      final e = TarneebEngine(TarneebState.withHands(suitsDeal()));
      e.apply(const TarneebMove.bid(7)); // 0
      e.apply(const TarneebMove.pass()); // 1
      e.apply(const TarneebMove.bid(9)); // 2
      e.apply(const TarneebMove.pass()); // 3
      expect(e.currentPlayer, 0); // 1 and 3 skipped from now on
      e.apply(const TarneebMove.bid(10));
      expect(e.currentPlayer, 2);
      e.apply(const TarneebMove.pass());
      expect(e.state.phase, TarneebPhase.trump);
      expect(e.currentPlayer, 0);
      expect(e.state.highBid, 10);
    });

    test('bidding 13 ends the auction at once', () {
      final e = TarneebEngine(TarneebState.withHands(suitsDeal()));
      e.apply(const TarneebMove.bid(13));
      expect(e.state.phase, TarneebPhase.trump);
      expect(e.currentPlayer, 0);
    });

    test('all pass → redeal by the next dealer (option: dealer must bid)', () {
      final e = TarneebEngine(TarneebState.withHands(suitsDeal(), seed: 5));
      for (var i = 0; i < 4; i++) {
        e.apply(const TarneebMove.pass());
      }
      expect(e.state.dealer, 0);
      expect(e.state.dealNumber, 2);
      expect(e.state.roundNumber, 0);
      expect(e.currentPlayer, 1);
      expect(e.state.phase, TarneebPhase.bidding);

      final f = TarneebEngine(
        TarneebState.withHands(suitsDeal(), options: const TarneebOptions(allPass: TarneebAllPass.dealerTakesMinimum)),
      );
      for (var i = 0; i < 3; i++) {
        f.apply(const TarneebMove.pass());
      }
      expect(f.currentPlayer, 3);
      expect(f.legalMoves(3).contains(const TarneebMove.pass()), isFalse);
      expect(f.validate(const TarneebMove.pass()), 'dealerMustBid');
    });

    test('non-final passes: the auction ends after three passes in a row', () {
      final e = TarneebEngine(
        TarneebState.withHands(suitsDeal(), options: const TarneebOptions(passIsFinal: false)),
      );
      e.apply(const TarneebMove.pass()); // 0
      e.apply(const TarneebMove.bid(7)); // 1
      e.apply(const TarneebMove.pass()); // 2
      e.apply(const TarneebMove.pass()); // 3
      expect(e.currentPlayer, 0); // a passed player may come back in
      e.apply(const TarneebMove.bid(8));
      e.apply(const TarneebMove.pass()); // 1
      e.apply(const TarneebMove.pass()); // 2
      e.apply(const TarneebMove.pass()); // 3
      expect(e.state.phase, TarneebPhase.trump);
      expect(e.state.highBidder, 0);
    });
  });

  group('play', () {
    TarneebEngine contract({required int bid, required Suit trump, List<List<PlayingCard>>? hands}) {
      final e = TarneebEngine(TarneebState.withHands(hands ?? suitsDeal()));
      e.apply(TarneebMove.bid(bid));
      for (var i = 0; i < 3; i++) {
        e.apply(const TarneebMove.pass());
      }
      e.apply(TarneebMove.trump(trump));
      return e;
    }

    test('the bidder leads; players must follow suit; trumps win', () {
      final hands = [
        c('AS KS QS JS TS 9S 8S 7S 6S 5S 4S 3S 2H'),
        c('AH KH QH JH TH 9H 8H 7H 6H 5H 4H 3H 2S'),
        c('AD KD QD JD TD 9D 8D 7D 6D 5D 4D 3D 2D'),
        c('AC KC QC JC TC 9C 8C 7C 6C 5C 4C 3C 2C'),
      ];
      final e = contract(bid: 7, trump: Suit.diamonds, hands: hands);
      expect(e.currentPlayer, 0);
      e.apply(TarneebMove.play(PlayingCard.parse('2H')));
      // Seat 1 holds hearts: must follow.
      expect(e.legalMoves(1).every((m) => m.card!.suit == Suit.hearts), isTrue);
      expect(e.validate(TarneebMove.play(PlayingCard.parse('2S'))), 'mustFollowSuit');
      e.apply(TarneebMove.play(PlayingCard.parse('AH')));
      // Seat 2 is void in hearts: anything goes, and a trump wins.
      expect(e.legalMoves(2).length, 13);
      e.apply(TarneebMove.play(PlayingCard.parse('2D')));
      e.apply(TarneebMove.play(PlayingCard.parse('2C')));
      expect(e.state.tricksWon, [1, 0]);
      expect(e.currentPlayer, 2);
    });

    test('scoring: made, failed, kaboot, options', () {
      const o = TarneebOptions();
      expect(TarneebRules.dealPoints(o, 0, 7, [9, 4]), [9, 0]);
      expect(TarneebRules.dealPoints(o, 1, 8, [6, 7]), [6, -8]);
      expect(TarneebRules.dealPoints(o, 2, 7, [13, 0]), [16, 0]);
      expect(TarneebRules.dealPoints(o, 3, 13, [0, 13]), [0, 16]);
      const bidOnly = TarneebOptions(
        madeScore: TarneebMadeScore.bid,
        defendersScoreWhenMade: true,
        failScore: TarneebFailScore.bid,
      );
      expect(TarneebRules.dealPoints(bidOnly, 0, 7, [9, 4]), [7, 4]);
      expect(TarneebRules.dealPoints(bidOnly, 0, 10, [9, 4]), [-10, 10]);
    });

    test('a whole deal: spades trump, seat 0 takes every trick → kaboot 16', () {
      final e = contract(bid: 7, trump: Suit.spades);
      while (e.state.roundNumber == 0) {
        final p = e.currentPlayer!;
        e.apply(e.legalMoves(p).last);
      }
      expect(e.state.lastResult!.tricks, [13, 0]);
      expect(e.state.teamScores, [16, 0]);
      expect(e.state.dealer, 0);
      expect(e.state.hands.every((h) => h.length == 13), isTrue);
    });

    test('the match ends at the target; ties go to the bidding team', () {
      final s = TarneebState.withHands(suitsDeal(), options: const TarneebOptions(targetScore: 41));
      s.teamScores = [30, 38];
      final e = TarneebEngine(s);
      e.apply(const TarneebMove.bid(7));
      for (var i = 0; i < 3; i++) {
        e.apply(const TarneebMove.pass());
      }
      e.apply(const TarneebMove.trump(Suit.spades));
      while (!e.isOver) {
        e.apply(e.legalMoves(e.currentPlayer!).last);
      }
      expect(e.state.teamScores, [46, 38]);
      expect(e.state.winners, [0, 2]);
    });
  });

  test('hand estimate: a long strong trump suit is worth many tricks', () {
    expect(tarneebHandTricks(c('AS KS QS JS TS 9S 8S AH KH AD 2C 3C 4C'), Suit.spades), greaterThan(9));
    expect(tarneebHandTricks(c('2S 3S 4H 5H 6H 7D 8D 9D 2C 3C 4C 5C 6C'), Suit.clubs), lessThan(2.5));
  });
}

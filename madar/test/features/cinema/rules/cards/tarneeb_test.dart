// Tarneeb (طرنيب) as commonly played in Jordan: one test per rule and
// scoring line of the rules document (RULES.md §1, the "A" numbering), the
// options and presets, serialisation, the AI and seeded self-play.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/cinema/rules/cards/core/card_game.dart';
import 'package:madar/features/cinema/rules/cards/core/card_rng.dart';
import 'package:madar/features/cinema/rules/cards/core/deck.dart';
import 'package:madar/features/cinema/rules/cards/core/determinize.dart';
import 'package:madar/features/cinema/rules/cards/core/playing_card.dart';
import 'package:madar/features/cinema/rules/cards/tarneeb/tarneeb_ai.dart';
import 'package:madar/features/cinema/rules/cards/tarneeb/tarneeb_rules.dart';
import 'package:madar/features/cinema/rules/cards/tarneeb/tarneeb_state.dart';

import 'support.dart';

List<PlayingCard> c(String ids) => PlayingCard.list(ids);

/// A fixed deal: seat 0 all spades, 1 all hearts, 2 all diamonds, 3 all clubs.
List<List<PlayingCard>> suitsDeal() => [
  for (final s in [Suit.spades, Suit.hearts, Suit.diamonds, Suit.clubs])
    [for (final r in Rank.values) PlayingCard(s, r)],
];

/// [first] for seat 0 and the rest of the deck, in order, for seats 1–3.
List<List<PlayingCard>> dealWith(List<PlayingCard> first) {
  final rest = cardsMinus(buildDeck(), first);
  return [first, for (var i = 0; i < 3; i++) rest.sublist(i * 13, i * 13 + 13)];
}

/// Plays the highest legal card for everybody until the deal is scored.
void playOut(TarneebEngine e) {
  final round = e.state.roundNumber;
  while (e.state.roundNumber == round && !e.isOver) {
    e.apply(e.legalMoves(e.currentPlayer!).last);
  }
}

/// Seat 0 wins the auction at [bid] (the others pass) and names [trump].
TarneebEngine contract({
  required int bid,
  required Suit trump,
  List<List<PlayingCard>>? hands,
  TarneebOptions options = const TarneebOptions(),
  List<int>? teamScores,
}) {
  final s = TarneebState.withHands(hands ?? suitsDeal(), options: options);
  if (teamScores != null) s.teamScores = List.of(teamScores);
  final e = TarneebEngine(s);
  e.apply(TarneebMove.bid(bid));
  while (e.state.phase == TarneebPhase.bidding) {
    e.apply(const TarneebMove.pass());
  }
  e.apply(TarneebMove.trump(trump));
  return e;
}

Kit tarneebKit(String name, TarneebOptions o) =>
    Kit(name, (seed) => TarneebEngine.newMatch(seed: seed, options: o), TarneebEngine.fromJson, const TarneebAi());

void main() {
  group('A1 players and deal', () {
    test('A1.1–A1.4 four players, 52 cards, 13 each; partners sit opposite (0 & 2, 1 & 3)', () {
      final e = TarneebEngine.newMatch(seed: 3);
      expect(e.state.hands.map((h) => h.length), [13, 13, 13, 13]);
      expect(sortedCards(e.state.cardsInPlay()), sortedCards(buildDeck()));
      expect([for (var i = 0; i < 4; i++) e.state.teamOf(i)], [0, 1, 0, 1]);
      expect(e.state.scores, [0, 0, 0, 0]);
    });

    test('A1.5 the first dealer is seat 3 (`firstDealer`), so seat 0 speaks first', () {
      final e = TarneebEngine.newMatch(seed: 3);
      expect(e.state.dealer, 3);
      expect(e.currentPlayer, 0);
      final f = TarneebEngine.newMatch(seed: 3, options: const TarneebOptions(firstDealer: 1));
      expect(f.currentPlayer, 2);
    });

    test('A1.5 after every scored deal the deal passes to the right (dealer + 1)', () {
      final e = contract(bid: 7, trump: Suit.spades);
      playOut(e);
      expect(e.state.dealer, 0);
      expect(e.currentPlayer, 1);
      expect(e.state.hands.every((h) => h.length == 13), isTrue);
    });
  });

  group('A2 auction', () {
    test('A2.1 the dealer\'s right speaks first; A2.2 bids 7–13, each higher than the last', () {
      final e = TarneebEngine(TarneebState.withHands(suitsDeal()));
      expect(e.currentPlayer, 0);
      expect(e.legalMoves(0), [const TarneebMove.pass(), for (var b = 7; b <= 13; b++) TarneebMove.bid(b)]);
      e.apply(const TarneebMove.bid(8));
      expect(e.currentPlayer, 1);
      expect(e.legalMoves(1).where((m) => m.kind == TarneebMoveKind.bid).first, const TarneebMove.bid(9));
      expect(e.validate(const TarneebMove.bid(8)), 'bidTooLow');
      expect(e.validate(const TarneebMove.bid(6)), 'bidTooLow');
      expect(() => e.apply(const TarneebMove.bid(7)), throwsA(isA<IllegalMoveException>()));
    });

    test('A2.2 a bid above 13 is `bidTooHigh`; a move decoded without its amount gets an error id', () {
      final e = TarneebEngine(TarneebState.withHands(suitsDeal()));
      expect(e.validate(const TarneebMove.bid(14)), 'bidTooHigh');
      expect(e.validate(const TarneebMove.bid(0)), 'bidTooLow');
      expect(e.validate(TarneebMove.fromJson(const {'k': 'bid'})), 'bidTooLow');
      expect(() => e.apply(const TarneebMove.bid(14)), throwsA(isA<IllegalMoveException>()));
    });

    test('A2.2 overbidding one\'s own partner is legal; A2.3 a player who passed may not bid again', () {
      final e = TarneebEngine(TarneebState.withHands(suitsDeal()));
      e.apply(const TarneebMove.bid(7)); // 0
      e.apply(const TarneebMove.pass()); // 1
      expect(e.validate(const TarneebMove.bid(8)), isNull); // 2 over partner 0
      e.apply(const TarneebMove.bid(8)); // 2
      e.apply(const TarneebMove.pass()); // 3
      expect(e.currentPlayer, 0); // 1 and 3 are skipped from now on
      e.apply(const TarneebMove.bid(10));
      expect(e.currentPlayer, 2);
      e.apply(const TarneebMove.pass());
      expect(e.state.phase, TarneebPhase.trump);
      expect(e.currentPlayer, 0);
      expect(e.state.highBid, 10);
    });

    test('A2.3 the auction ends when every other player has passed after a bid (7, pass, pass, pass)', () {
      final e = TarneebEngine(TarneebState.withHands(suitsDeal()));
      e.apply(const TarneebMove.bid(7));
      for (var i = 0; i < 3; i++) {
        e.apply(const TarneebMove.pass());
      }
      expect(e.state.phase, TarneebPhase.trump);
      expect(e.currentPlayer, 0);
      expect(e.legalMoves(0), [for (final s in Suit.values) TarneebMove.trump(s)]);
    });

    test('A2.5 a bid of 13 ends the auction at once, even before the others have spoken', () {
      final e = TarneebEngine(TarneebState.withHands(suitsDeal()));
      e.apply(const TarneebMove.bid(13));
      expect(e.state.phase, TarneebPhase.trump);
      expect(e.currentPlayer, 0);
      expect(e.state.bids.length, 1);
    });

    test('A2.6 all four pass → nobody scores and the SAME dealer deals again (Jordan default)', () {
      final e = TarneebEngine(TarneebState.withHands(suitsDeal(), seed: 5));
      final events = <CardEvent>[];
      for (var i = 0; i < 4; i++) {
        events.addAll(e.apply(const TarneebMove.pass()));
      }
      expect(events.where((x) => x.type == CardEventType.redeal).single.detail, 'allPassed');
      expect(e.state.dealer, 3);
      expect(e.currentPlayer, 0);
      expect(e.state.dealNumber, 2);
      expect(e.state.roundNumber, 0);
      expect(e.state.phase, TarneebPhase.bidding);
      expect(e.state.teamScores, [0, 0]);
      expect(e.state.bids, isEmpty);
      expect(e.state.hands, isNot(suitsDeal())); // a fresh shuffle
      expect(sortedCards(e.state.cardsInPlay()), sortedCards(buildDeck()));
    });

    test('allPass: redealNextDealer → the next dealer deals (dealer 0, seat 1 speaks first)', () {
      final e = TarneebEngine(
        TarneebState.withHands(
          suitsDeal(),
          seed: 5,
          options: const TarneebOptions(allPass: TarneebAllPass.redealNextDealer),
        ),
      );
      for (var i = 0; i < 4; i++) {
        e.apply(const TarneebMove.pass());
      }
      expect(e.state.dealer, 0);
      expect(e.currentPlayer, 1);
      expect(e.state.dealNumber, 2);
      expect(e.state.roundNumber, 0);
    });

    test('allPass: dealerTakesMinimum → after three passes the dealer has no pass (`dealerMustBid`)', () {
      final f = TarneebEngine(
        TarneebState.withHands(suitsDeal(), options: const TarneebOptions(allPass: TarneebAllPass.dealerTakesMinimum)),
      );
      for (var i = 0; i < 3; i++) {
        f.apply(const TarneebMove.pass());
      }
      expect(f.currentPlayer, 3);
      expect(f.legalMoves(3).contains(const TarneebMove.pass()), isFalse);
      expect(f.legalMoves(3).first, const TarneebMove.bid(7));
      expect(f.validate(const TarneebMove.pass()), 'dealerMustBid');
    });

    test('open auction (`passIsFinal: false`): a passed player may come back; three passes end it', () {
      final e = TarneebEngine(TarneebState.withHands(suitsDeal(), options: const TarneebOptions.openAuction()));
      e.apply(const TarneebMove.pass()); // 0
      e.apply(const TarneebMove.bid(7)); // 1
      e.apply(const TarneebMove.pass()); // 2
      e.apply(const TarneebMove.pass()); // 3
      expect(e.currentPlayer, 0);
      e.apply(const TarneebMove.bid(8));
      e.apply(const TarneebMove.pass()); // 1
      e.apply(const TarneebMove.pass()); // 2
      e.apply(const TarneebMove.pass()); // 3
      expect(e.state.phase, TarneebPhase.trump);
      expect(e.state.highBidder, 0);
    });

    test('Lebanese auction (`oneRoundAuction`): one call each; only the dealer may equal the bid', () {
      const o = TarneebOptions.lebaneseAuction();
      final e = TarneebEngine(TarneebState.withHands(suitsDeal(), options: o));
      e.apply(const TarneebMove.bid(8)); // 0
      expect(e.legalMoves(1)[1], const TarneebMove.bid(9)); // no equalling for 1
      e.apply(const TarneebMove.pass()); // 1
      e.apply(const TarneebMove.bid(9)); // 2
      expect(e.currentPlayer, 3);
      expect(e.legalMoves(3)[1], const TarneebMove.bid(9)); // the dealer may equal
      e.apply(const TarneebMove.bid(9));
      expect(e.state.phase, TarneebPhase.trump);
      expect(e.state.highBidder, 3);
      expect(e.currentPlayer, 3);

      // Nobody speaks twice: 0 passes, 1 bids 7, 2 bids 8, the dealer passes.
      final f = TarneebEngine(TarneebState.withHands(suitsDeal(), options: o));
      f.apply(const TarneebMove.pass());
      f.apply(const TarneebMove.bid(7));
      f.apply(const TarneebMove.bid(8));
      f.apply(const TarneebMove.pass());
      expect(f.state.phase, TarneebPhase.trump);
      expect(f.state.highBidder, 2);

      // All four pass: the same dealer again.
      final g = TarneebEngine(TarneebState.withHands(suitsDeal(), options: o, seed: 2));
      for (var i = 0; i < 4; i++) {
        g.apply(const TarneebMove.pass());
      }
      expect(g.state.dealer, 3);
      expect(g.state.dealNumber, 2);
    });
  });

  group('A3 trump and first lead', () {
    test('A3.1 the winning bidder names any of the four suits; there is no no-trump', () {
      final e = TarneebEngine(TarneebState.withHands(suitsDeal()));
      e.apply(const TarneebMove.bid(13));
      expect(e.legalMoves(0).map((m) => m.suit), Suit.values);
      expect(e.legalMoves(0).every((m) => m.kind == TarneebMoveKind.trump), isTrue);
    });

    test('A3.2 the winning bidder leads the first trick (`bidderLeads: false` → the dealer\'s right)', () {
      final s = TarneebState.withHands(suitsDeal());
      final e = TarneebEngine(s);
      e.apply(const TarneebMove.pass()); // 0
      e.apply(const TarneebMove.bid(7)); // 1
      e.apply(const TarneebMove.pass()); // 2
      e.apply(const TarneebMove.pass()); // 3
      e.apply(const TarneebMove.trump(Suit.hearts));
      expect(e.state.phase, TarneebPhase.playing);
      expect(e.currentPlayer, 1);

      final f = TarneebEngine(TarneebState.withHands(suitsDeal(), options: const TarneebOptions(bidderLeads: false)));
      f.apply(const TarneebMove.pass());
      f.apply(const TarneebMove.bid(7));
      f.apply(const TarneebMove.pass());
      f.apply(const TarneebMove.pass());
      f.apply(const TarneebMove.trump(Suit.hearts));
      expect(f.currentPlayer, 0);
    });

    test('A-opt-1 Syrian trump: the dealer\'s exposed 7♠ makes clubs trumps; it stays in the dealer\'s hand', () {
      final s = TarneebState.withHands(
        suitsDeal(),
        dealer: 0,
        options: const TarneebOptions.syrianTrump(),
        exposedCard: PlayingCard.parse('7S'),
      );
      expect(s.exposedCard, PlayingCard.parse('7S'));
      expect(s.trump, Suit.clubs);
      expect(s.hands[0], contains(PlayingCard.parse('7S')));
      final e = TarneebEngine(s);
      expect(e.currentPlayer, 1);
      e.apply(const TarneebMove.bid(7)); // 1
      final events = <CardEvent>[];
      for (var i = 0; i < 3; i++) {
        events.addAll(e.apply(const TarneebMove.pass()));
      }
      // No trump phase: play starts at once, the bidder leads.
      expect(e.state.phase, TarneebPhase.playing);
      expect(e.currentPlayer, 1);
      expect(e.state.trump, Suit.clubs);
      expect(events.any((x) => x.type == CardEventType.trumpChosen && x.suit == Suit.clubs), isTrue);
      expect(
        () => TarneebState.withHands(
          suitsDeal(),
          dealer: 0,
          options: const TarneebOptions.syrianTrump(),
          exposedCard: PlayingCard.parse('7H'),
        ),
        throwsArgumentError,
      );
    });

    test('A-opt-1 Syrian trump from a shuffled deal: the exposed card is the dealer\'s and fixes the sister suit', () {
      for (var seed = 1; seed <= 20; seed++) {
        final s = TarneebState.newMatch(seed: seed, options: const TarneebOptions.syrianTrump());
        expect(s.hands[s.dealer], contains(s.exposedCard));
        expect(s.trump, sisterSuit(s.exposedCard!.suit));
      }
      expect([for (final x in Suit.values) sisterSuit(x)], [Suit.spades, Suit.hearts, Suit.diamonds, Suit.clubs]);
      // The default game has no exposed card and no trump before the auction.
      final d = TarneebState.newMatch(seed: 1);
      expect(d.exposedCard, isNull);
      expect(d.trump, isNull);
    });
  });

  group('A4 play', () {
    final mixed = [
      c('AS KS QS JS TS 9S 8S 7S 6S 5S 4S 3S 2H'),
      c('AH KH QH JH TH 9H 8H 7H 6H 5H 4H 3H 2S'),
      c('AD KD QD JD TD 9D 8D 7D 6D 5D 4D 3D 2D'),
      c('AC KC QC JC TC 9C 8C 7C 6C 5C 4C 3C 2C'),
    ];

    test('A4.1 follow suit; A4.2 a void player may play any card, trumping is never forced; A4.3 trumps win', () {
      final e = contract(bid: 7, trump: Suit.diamonds, hands: mixed);
      expect(e.currentPlayer, 0);
      e.apply(TarneebMove.play(PlayingCard.parse('2H')));
      expect(e.legalMoves(1).every((m) => m.card!.suit == Suit.hearts), isTrue);
      expect(e.validate(TarneebMove.play(PlayingCard.parse('2S'))), 'mustFollowSuit');
      expect(e.validate(TarneebMove.play(PlayingCard.parse('AS'))), 'cardNotInHand');
      e.apply(TarneebMove.play(PlayingCard.parse('AH')));
      expect(e.legalMoves(2).length, 13); // void in hearts: anything, trumps too
      e.apply(TarneebMove.play(PlayingCard.parse('2D')));
      expect(e.legalMoves(3).length, 13); // void: need not trump
      e.apply(TarneebMove.play(PlayingCard.parse('2C')));
      expect(e.state.tricksWon, [1, 0]); // the lowest trump beats the ace
      expect(e.currentPlayer, 2); // A4.4 the winner leads
    });

    test('A4.5 all 13 tricks are played even when the contract is already decided', () {
      final e = contract(bid: 7, trump: Suit.spades);
      var tricks = 0;
      while (e.state.roundNumber == 0) {
        final ev = e.apply(e.legalMoves(e.currentPlayer!).last);
        tricks += ev.where((x) => x.type == CardEventType.trickWon).length;
      }
      expect(tricks, 13);
    });

    test('A-opt-4 `firstLeadMustBeTrump`: the opening lead is a trump when the leader holds one', () {
      const o = TarneebOptions(firstLeadMustBeTrump: true);
      final e = contract(bid: 7, trump: Suit.hearts, hands: mixed, options: o);
      expect(e.legalMoves(0), [TarneebMove.play(PlayingCard.parse('2H'))]);
      expect(e.validate(TarneebMove.play(PlayingCard.parse('AS'))), 'mustLeadTrump');
      e.apply(TarneebMove.play(PlayingCard.parse('2H')));
      for (var i = 0; i < 3; i++) {
        e.apply(e.legalMoves(e.currentPlayer!).last);
      }
      // Later leads are free.
      final leader = e.currentPlayer!;
      expect(e.legalMoves(leader).length, e.state.hands[leader].length);
      // A leader without trumps leads anything.
      final f = contract(bid: 7, trump: Suit.clubs, hands: mixed, options: o);
      expect(f.legalMoves(0).length, 13);
    });
  });

  group('A5 scoring (b = bid, T = bidders\' tricks, D = 13 − T)', () {
    const o = TarneebOptions();
    test('made, b ≤ T ≤ 12 → bidders +T, defenders 0 (bid 8, took 10 → +10 / 0)', () {
      expect(TarneebRules.dealPoints(o, 0, 8, [10, 3]), [10, 0]);
      expect(TarneebRules.dealPoints(o, 1, 7, [6, 7]), [0, 7]);
    });

    test('failed, T < b → bidders −b, defenders +D (bid 9, took 7 → −9 / +6)', () {
      expect(TarneebRules.dealPoints(o, 0, 9, [7, 6]), [-9, 6]);
      expect(TarneebRules.dealPoints(o, 1, 8, [6, 7]), [6, -8]);
    });

    test('kaboot (كبوت) on a bid of 7–12: all 13 tricks → 16 (bid 7 and bid 12)', () {
      expect(TarneebRules.dealPoints(o, 2, 7, [13, 0]), [16, 0]);
      expect(TarneebRules.dealPoints(o, 0, 12, [13, 0]), [16, 0]);
    });

    test('bid 13 and made → 26', () {
      expect(TarneebRules.dealPoints(o, 3, 13, [0, 13]), [0, 26]);
      expect(TarneebRules.dealPoints(o, 0, 13, [13, 0]), [26, 0]);
    });

    test('bid 13 and failed → bidders −16, defenders double their tricks (T = 12: −16 / +2; T = 0: −16 / +26)', () {
      expect(TarneebRules.dealPoints(o, 0, 13, [12, 1]), [-16, 2]);
      expect(TarneebRules.dealPoints(o, 0, 13, [0, 13]), [-16, 26]);
    });

    test('`kabootFailDefenders: single` → a failed 13 gives the defenders their tricks once (−16 / +1)', () {
      const single = TarneebOptions(kabootFailDefenders: TarneebKabootFail.single);
      expect(TarneebRules.dealPoints(single, 0, 13, [12, 1]), [-16, 1]);
    });

    test('kaboot values are options (`kabootScore`, `kabootBidMadeScore`, `kabootBidFailPenalty`)', () {
      const flat = TarneebOptions(kabootScore: 13, kabootBidMadeScore: 16, kabootBidFailPenalty: 13);
      expect(TarneebRules.dealPoints(flat, 0, 9, [13, 0]), [13, 0]);
      expect(TarneebRules.dealPoints(flat, 0, 13, [13, 0]), [16, 0]);
      expect(TarneebRules.dealPoints(flat, 0, 13, [11, 2]), [-13, 4]);
    });

    test('options `madeScore: bid`, `defendersScoreWhenMade`, `failScore: bid / nothing`', () {
      const bidOnly = TarneebOptions(
        madeScore: TarneebMadeScore.bid,
        defendersScoreWhenMade: true,
        failScore: TarneebFailScore.bid,
      );
      expect(TarneebRules.dealPoints(bidOnly, 0, 7, [9, 4]), [7, 4]);
      expect(TarneebRules.dealPoints(bidOnly, 0, 10, [9, 4]), [-10, 10]);
      expect(TarneebRules.dealPoints(bidOnly, 0, 13, [13, 0]), [26, 0]);
      const nothing = TarneebOptions(failScore: TarneebFailScore.nothing);
      expect(TarneebRules.dealPoints(nothing, 0, 10, [9, 4]), [-10, 0]);
      // The 13 row is its own rule, whatever `failScore` says.
      expect(TarneebRules.dealPoints(nothing, 0, 13, [12, 1]), [-16, 2]);
    });

    test('a whole deal: seat 0 bids 7 with spades and takes all 13 → 16; a bid of 13 made → 26', () {
      final e = contract(bid: 7, trump: Suit.spades);
      playOut(e);
      expect(e.state.lastResult!.tricks, [13, 0]);
      expect(e.state.lastResult!.kaboot, isTrue);
      expect(e.state.teamScores, [16, 0]);
      final f = contract(bid: 13, trump: Suit.spades);
      playOut(f);
      expect(f.state.teamScores, [26, 0]);
    });

    test('a whole deal: a bid of 13 in clubs by seat 0 fails with 0 tricks → −16 / +26', () {
      final e = contract(bid: 13, trump: Suit.clubs);
      playOut(e);
      expect(e.state.lastResult!.tricks, [0, 13]);
      expect(e.state.lastResult!.made, isFalse);
      expect(e.state.teamScores, [-16, 26]);
    });
  });

  group('A6 match', () {
    const o = TarneebOptions();
    test('A6.2 the target is 31 (41 and 61 offered); reaching it exactly ends the match, 30 does not', () {
      expect(o.targetScore, 31);
      expect(TarneebOptions.targetChoices, [31, 41, 61]);
      expect(TarneebRules.matchWinner(o, [31, 5], 0), 0);
      expect(TarneebRules.matchWinner(o, [30, 5], 0), isNull);
      final e = contract(bid: 7, trump: Suit.spades, teamScores: [15, 0]);
      playOut(e);
      expect(e.isOver, isTrue);
      expect(e.state.teamScores, [31, 0]);
      expect(e.state.winners, [0, 2]);
      expect(e.currentPlayer, isNull);
      final f = contract(bid: 7, trump: Suit.spades, teamScores: [14, 0]);
      playOut(f);
      expect(f.isOver, isFalse);
      expect(f.state.teamScores, [30, 0]);
    });

    test('A6.1 scores may go negative and a team at −40 keeps playing (no loss at −31 by default)', () {
      expect(TarneebRules.matchWinner(o, [-40, 10], 0), isNull);
      final e = contract(bid: 13, trump: Suit.clubs, teamScores: [-20, 0]);
      playOut(e);
      expect(e.state.teamScores, [-36, 26]);
      expect(e.isOver, isFalse);
    });

    test('`loseAtNegativeTarget`: a team at or below −31 after a deal loses', () {
      const neg = TarneebOptions(loseAtNegativeTarget: true);
      expect(TarneebRules.matchWinner(neg, [-31, 10], 0), 1);
      expect(TarneebRules.matchWinner(neg, [5, -31], 1), 0);
      expect(TarneebRules.matchWinner(neg, [-30, 10], 0), isNull);
      final e = contract(bid: 13, trump: Suit.clubs, teamScores: [-20, 0], options: neg);
      final events = <CardEvent>[];
      while (!e.isOver) {
        events.addAll(e.apply(e.legalMoves(e.currentPlayer!).last));
      }
      expect(e.state.winners, [1, 3]);
      expect(events.last.detail, 'negativeTarget');
    });

    test('A6.4 both teams at the target (only with options) → the higher total; an exact tie → the bidding team', () {
      expect(TarneebRules.matchWinner(o, [35, 33], 1), 0);
      expect(TarneebRules.matchWinner(o, [33, 33], 1), 1);
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

    test('A6.6 bidding and making 13 does not win the match by itself', () {
      final e = contract(bid: 13, trump: Suit.spades);
      playOut(e);
      expect(e.state.teamScores, [26, 0]);
      expect(e.isOver, isFalse);
    });
  });

  group('A-opt-3 worthless hand (`worthlessHandRedeal`)', () {
    test('a worthless hand: no ace, no king with another card of its suit, no queen in 3+, no jack in 4+', () {
      bool w(String ids) => TarneebRules.isWorthlessHand(c(ids));
      expect(w('2S 3S 4S 5S 6S 2H 3H 4H 5H 2D 3D 4D KC'), isTrue); // singleton king
      expect(w('2S 3S 4S 5S 6S 7S 2H 3H 4H 5H 2D QD JC'), isTrue); // Q in 2, J singleton
      expect(w('2S 3S 4S 5S 6S 2H 3H 4H 5H 2D 3D QD JC'), isFalse); // Q in 3
      expect(w('2S 3S 4S 5S 6S 2H 3H 4H 5H 2D 3D 2C KC'), isFalse); // K with another club
      expect(w('2S 3S 4S 5S 6S 2H 3H 4H 5H 2D 3D 4D AC'), isFalse); // an ace
      expect(w('2S 3S 4S 5S 6S 2H 3H 4H 5H 2D 3D 4D QD'), isFalse); // Q in 4
      expect(w('2S 3S 4S JS 6S 2H 3H 4H 5H 2D 3D 4D 5C'), isFalse); // J in 5
      expect(w('2S 3S JS 2H 3H 4H 5H 6H 7H 2D 3D 4D 5C'), isTrue); // J in 3
    });

    test('offered on the player\'s first turn to speak only; the next dealer deals, nobody scores', () {
      const o = TarneebOptions(worthlessHandRedeal: true);
      final hands = dealWith(c('2S 3S 4S 5S 6S 2H 3H 4H 5H 2D 3D 4D KC'));
      expect(TarneebRules.isWorthlessHand(hands[0]), isTrue);
      // Without the option there is no throw-in.
      final plain = TarneebEngine(TarneebState.withHands(hands));
      expect(plain.legalMoves(0).contains(const TarneebMove.throwIn()), isFalse);
      expect(plain.validate(const TarneebMove.throwIn()), 'cannotThrowIn');
      final e = TarneebEngine(TarneebState.withHands(hands, options: o, seed: 4));
      expect(e.legalMoves(0).last, const TarneebMove.throwIn());
      final events = e.apply(const TarneebMove.throwIn());
      expect(events.first.type, CardEventType.redeal);
      expect(events.first.detail, 'worthlessHand');
      expect(events.first.cards, hands[0]); // the hand is shown
      expect(e.state.dealer, 0);
      expect(e.currentPlayer, 1);
      expect(e.state.dealNumber, 2);
      expect(e.state.roundNumber, 0);
      expect(e.state.teamScores, [0, 0]);
      // After speaking once the chance is gone.
      final f = TarneebEngine(TarneebState.withHands(hands, options: o.copyWith(passIsFinal: false)));
      f.apply(const TarneebMove.pass()); // 0
      f.apply(const TarneebMove.bid(7)); // 1
      f.apply(const TarneebMove.pass()); // 2
      f.apply(const TarneebMove.pass()); // 3
      expect(f.currentPlayer, 0);
      expect(f.legalMoves(0).contains(const TarneebMove.throwIn()), isFalse);
      // A player with a real hand never gets it.
      final g = TarneebEngine(TarneebState.withHands(hands, options: o));
      g.apply(const TarneebMove.pass());
      expect(TarneebRules.isWorthlessHand(g.state.hands[1]), isFalse);
      expect(g.legalMoves(1).contains(const TarneebMove.throwIn()), isFalse);
    });

    test('claimed before the first bid (spec A-opt-3): after anyone bids, a worthless hand plays on', () {
      const o = TarneebOptions(worthlessHandRedeal: true);
      final hands = dealWith(c('2S 3S 4S 5S 6S 2H 3H 4H 5H 2D 3D 4D KC'));
      // Dealer 1: seat 2 bids 12 before seat 0 first speaks. Seat 0 must not
      // be able to cancel the deal after seeing that bid.
      final e = TarneebEngine(TarneebState.withHands(hands, options: o, dealer: 1));
      e.apply(const TarneebMove.bid(12)); // 2
      e.apply(const TarneebMove.pass()); // 3
      expect(e.currentPlayer, 0);
      expect(e.legalMoves(0), isNot(contains(const TarneebMove.throwIn())));
      expect(e.validate(const TarneebMove.throwIn()), 'cannotThrowIn');
      // Passes before do not take the right away.
      final f = TarneebEngine(TarneebState.withHands(hands, options: o, dealer: 1));
      f.apply(const TarneebMove.pass()); // 2
      f.apply(const TarneebMove.pass()); // 3
      expect(f.legalMoves(0).last, const TarneebMove.throwIn());
      f.apply(const TarneebMove.throwIn());
      expect(f.state.dealer, 2);
      expect(f.currentPlayer, 3);
    });
  });

  group('options, presets and serialisation', () {
    test('const TarneebOptions() is the Jordanian game', () {
      const o = TarneebOptions();
      expect(o, const TarneebOptions.jordan());
      expect(o.targetScore, 31);
      expect(o.minBid, 7);
      expect(o.passIsFinal, isTrue);
      expect(o.oneRoundAuction, isFalse);
      expect(o.allPass, TarneebAllPass.redealSameDealer);
      expect(o.madeScore, TarneebMadeScore.tricksTaken);
      expect(o.defendersScoreWhenMade, isFalse);
      expect(o.failScore, TarneebFailScore.defendersTricks);
      expect(o.kabootScore, 16);
      expect(o.kabootBidMadeScore, 26);
      expect(o.kabootBidFailPenalty, 16);
      expect(o.kabootFailDefenders, TarneebKabootFail.doubled);
      expect(o.trumpMode, TarneebTrumpMode.bidderChooses);
      expect(o.bidderLeads, isTrue);
      expect(o.firstLeadMustBeTrump, isFalse);
      expect(o.worthlessHandRedeal, isFalse);
      expect(o.loseAtNegativeTarget, isFalse);
      expect(o.firstDealer, 3);
      expect(const TarneebOptions.jordan(targetScore: 41), o.copyWith(targetScore: 41));
      expect(const TarneebOptions.syrianTrump().trumpMode, TarneebTrumpMode.exposedCardSisterSuit);
      expect(const TarneebOptions.lebaneseAuction().oneRoundAuction, isTrue);
      expect(
        const TarneebOptions.openAuction(),
        o.copyWith(passIsFinal: false, allPass: TarneebAllPass.dealerTakesMinimum),
      );
    });

    test('options JSON round trip (every field changed)', () {
      const o = TarneebOptions(
        targetScore: 61,
        minBid: 8,
        passIsFinal: false,
        oneRoundAuction: true,
        allPass: TarneebAllPass.redealNextDealer,
        madeScore: TarneebMadeScore.bid,
        failScore: TarneebFailScore.nothing,
        defendersScoreWhenMade: true,
        kabootScore: 20,
        kabootBidMadeScore: 30,
        kabootBidFailPenalty: 13,
        kabootFailDefenders: TarneebKabootFail.single,
        trumpMode: TarneebTrumpMode.exposedCardSisterSuit,
        bidderLeads: false,
        firstLeadMustBeTrump: true,
        worthlessHandRedeal: true,
        loseAtNegativeTarget: true,
        firstDealer: 1,
      );
      final back = TarneebOptions.fromJson(jsonDecode(jsonEncode(o.toJson())) as Map<String, Object?>);
      expect(back, o);
      expect(back.toJson(), o.toJson());
      expect(TarneebOptions.fromJson(const {}), const TarneebOptions());
    });

    test('an old save (`allTricksScore`, `allPass: redeal`, no new keys) loads with its old rules', () {
      final legacy = {
        'targetScore': 41,
        'minBid': 7,
        'passIsFinal': true,
        'allPass': 'redeal',
        'madeScore': 'tricksTaken',
        'failScore': 'defendersTricks',
        'defendersScoreWhenMade': false,
        'allTricksScore': 16,
        'bidderLeads': true,
        'firstDealer': 3,
      };
      final o = TarneebOptions.fromJson(legacy);
      expect(o.targetScore, 41);
      expect(o.allPass, TarneebAllPass.redealNextDealer);
      expect(o.kabootScore, 16);
      expect(o.kabootBidMadeScore, 16);
      expect(o.kabootBidFailPenalty, 13);
      expect(o.kabootFailDefenders, TarneebKabootFail.single);
      expect(o.trumpMode, TarneebTrumpMode.bidderChooses);
      expect(o.worthlessHandRedeal, isFalse);
      // The whole legacy state loads too.
      final state = TarneebState.newMatch(seed: 9).toJson()
        ..['options'] = legacy
        ..remove('exposedCard');
      final restored = TarneebState.fromJson(jsonDecode(jsonEncode(state)) as Map<String, Object?>);
      expect(restored.options.allPass, TarneebAllPass.redealNextDealer);
      expect(restored.exposedCard, isNull);
    });

    test('state and move JSON round trip mid-deal (Syrian trump, worthless-hand option)', () {
      final e = TarneebEngine.newMatch(
        seed: 21,
        options: const TarneebOptions.syrianTrump().copyWith(worthlessHandRedeal: true, firstLeadMustBeTrump: true),
      );
      final rng = CardRng(4);
      for (var i = 0; i < 12 && !e.isOver; i++) {
        final p = e.currentPlayer!;
        final m = const TarneebAi().chooseMove(e.state, p, AiLevel.medium, rng, AiBudget.phone);
        expect(TarneebMove.fromJson(jsonDecode(jsonEncode(m.toJson())) as Map<String, Object?>), m);
        e.apply(m);
      }
      final json = jsonDecode(jsonEncode(e.toJson())) as Map<String, Object?>;
      final back = TarneebEngine.fromJson(json);
      expect(jsonEncode(back.toJson()), jsonEncode(json));
      expect(back.state.exposedCard, e.state.exposedCard);
      expect(const TarneebMove.throwIn().toJson(), {'k': 'throwIn'});
      expect(TarneebMove.fromJson(const {'k': 'throwIn'}), const TarneebMove.throwIn());
    });
  });

  group('AI', () {
    test('hand estimate: a long strong trump suit is worth many tricks', () {
      expect(tarneebHandTricks(c('AS KS QS JS TS 9S 8S AH KH AD 2C 3C 4C'), Suit.spades), greaterThan(9));
      expect(tarneebHandTricks(c('2S 3S 4H 5H 6H 7D 8D 9D 2C 3C 4C 5C 6C'), Suit.clubs), lessThan(2.5));
    });

    /// Dealer 0: seat 1 bids 12, 2 and 3 pass, seat 0 (holding [hand]) must
    /// pass or bid 13.
    TarneebState facing12(List<PlayingCard> hand) {
      final e = TarneebEngine(TarneebState.withHands(dealWith(hand), dealer: 0));
      e.apply(const TarneebMove.bid(12));
      e.apply(const TarneebMove.pass());
      e.apply(const TarneebMove.pass());
      expect(e.currentPlayer, 0);
      return e.state;
    }

    test('medium bids 13 only with a clear margin (+26 against −16 and double to the defenders)', () {
      const ai = TarneebAi();
      final rng = CardRng(1);
      // About 13.15 tricks with the partner: not enough.
      final close = facing12(c('AS KS QS JS TS 9S 8S 7S 6S AH KH 2D 2C'));
      expect(ai.chooseMove(close, 0, AiLevel.medium, rng, AiBudget.phone), const TarneebMove.pass());
      // Thirteen spades: certain.
      final sure = facing12(suitsDeal()[0]);
      expect(ai.chooseMove(sure, 0, AiLevel.medium, rng, AiBudget.phone), const TarneebMove.bid(13));
    });

    test('with a certain كبوت the AI bids 13 at once (+26), not a cheap 7 that scores 16 for the same 13 tricks', () {
      const ai = TarneebAi();
      // Seat 0 speaks first holding all thirteen spades.
      final s = TarneebState.withHands(suitsDeal());
      expect(ai.chooseMove(s, 0, AiLevel.medium, CardRng(1), AiBudget.phone), const TarneebMove.bid(13));
      // The hard AI keeps that bid, and weighs 13 whenever the medium AI
      // would bid at all.
      expect(ai.chooseMove(s, 0, AiLevel.hard, CardRng(1), const AiBudget.simulations(60)), const TarneebMove.bid(13));
      final legal = const TarneebRules().legalMoves(s, 0);
      expect(ai.hardCandidates(s, 0, legal, const TarneebMove.bid(9)), contains(const TarneebMove.bid(13)));
      expect(ai.hardCandidates(s, 0, legal, const TarneebMove.pass()), isNot(contains(const TarneebMove.bid(13))));
      // A merely good hand (about 13.15 tricks with the partner) still bids low.
      final good = TarneebState.withHands(dealWith(c('AS KS QS JS TS 9S 8S 7S 6S AH KH 2D 2C')));
      expect(ai.chooseMove(good, 0, AiLevel.medium, CardRng(1), AiBudget.phone), const TarneebMove.bid(7));
    });

    test('Syrian trump: the AI values its hand with the known trump suit', () {
      const ai = TarneebAi();
      // Seat 1 holds all the hearts; the exposed 7♠ makes clubs trumps.
      final syrian = TarneebState.withHands(
        suitsDeal(),
        dealer: 0,
        options: const TarneebOptions.syrianTrump(),
        exposedCard: PlayingCard.parse('7S'),
      );
      expect(ai.chooseMove(syrian, 1, AiLevel.medium, CardRng(1), AiBudget.phone), const TarneebMove.pass());
      final free = TarneebState.withHands(suitsDeal(), dealer: 0);
      expect(ai.chooseMove(free, 1, AiLevel.medium, CardRng(1), AiBudget.phone).kind, TarneebMoveKind.bid);
    });

    test('medium throws a worthless hand in while it may; the hard AI weighs it against pass and bids', () {
      const ai = TarneebAi();
      final hands = dealWith(c('2S 3S 4S 5S 6S 2H 3H 4H 5H 2D 3D 4D KC'));
      const o = TarneebOptions(worthlessHandRedeal: true);
      final s = TarneebState.withHands(hands, options: o);
      expect(ai.chooseMove(s, 0, AiLevel.medium, CardRng(3), AiBudget.phone), const TarneebMove.throwIn());
      // Dealer 1: seats 2 and 3 pass before seat 0 first speaks.
      final e = TarneebEngine(TarneebState.withHands(hands, options: o, dealer: 1));
      e.apply(const TarneebMove.pass());
      e.apply(const TarneebMove.pass());
      expect(ai.chooseMove(e.state, 0, AiLevel.medium, CardRng(3), AiBudget.phone), const TarneebMove.throwIn());
      // The hard AI compares the throw-in with passing and bidding.
      expect(
        ai.hardCandidates(e.state, 0, e.legalMoves(0), const TarneebMove.pass()),
        containsAll(const [TarneebMove.pass(), TarneebMove.bid(7), TarneebMove.throwIn()]),
      );
      // Once the partner has bid the chance is gone and the AI simply passes.
      final f = TarneebEngine(TarneebState.withHands(hands, options: o, dealer: 1));
      f.apply(const TarneebMove.bid(7));
      f.apply(const TarneebMove.pass());
      expect(ai.chooseMove(f.state, 0, AiLevel.medium, CardRng(3), AiBudget.phone), const TarneebMove.pass());
    });

    test('determinised worlds keep the Syrian exposed card with the dealer until it is played', () {
      final s = TarneebState.withHands(
        suitsDeal(),
        dealer: 0,
        options: const TarneebOptions.syrianTrump(),
        exposedCard: PlayingCard.parse('7S'),
      );
      const ai = TarneebAi();
      for (var i = 0; i < 20; i++) {
        final w = ai.determinize(s, 1, CardRng(i));
        expect(w.hands[0], contains(PlayingCard.parse('7S')));
        expect(w.hands[1], s.hands[1]);
        expect(w.hands.map((h) => h.length), [13, 13, 13, 13]);
        expect(sortedCards(w.cardsInPlay()), sortedCards(buildDeck()));
      }
      // The dealer's own view is its real hand.
      expect(ai.determinize(s, 0, CardRng(1)).hands[0], s.hands[0]);
    });

    for (final (name, options) in [
      ('jordan', const TarneebOptions()),
      (
        'syrian + worthless hand + trump lead',
        TarneebOptions(
          trumpMode: TarneebTrumpMode.exposedCardSisterSuit,
          worthlessHandRedeal: true,
          firstLeadMustBeTrump: true,
        ),
      ),
    ]) {
      test('$name: decisions depend only on what the seat can see (medium and hard)', () {
        const ai = TarneebAi();
        final e = TarneebEngine.newMatch(seed: 5, options: options);
        final rng = CardRng(1);
        var checked = 0;
        for (var move = 0; move < 240 && !e.isOver; move++) {
          final seat = e.currentPlayer!;
          if (move % 7 == 3) {
            final real = e.state;
            final other = ai.determinize(real, seat, CardRng(move));
            expect(sortedCards(other.cardsInPlay()), sortedCards(real.cardsInPlay()));
            // The worlds the hard AI searches are built from public facts and
            // the seat's own hand only (not the other hands, not the saved
            // shuffle generator that fixes the next deals).
            expect(
              jsonEncode(ai.determinize(other, seat, CardRng(77)).toJson()),
              jsonEncode(ai.determinize(real, seat, CardRng(77)).toJson()),
              reason: '$name move $move world',
            );
            for (final level in [AiLevel.medium, AiLevel.hard]) {
              final a = ai.chooseMove(real, seat, level, CardRng(9), const AiBudget.simulations(40));
              final b = ai.chooseMove(other, seat, level, CardRng(9), const AiBudget.simulations(40));
              expect(b, a, reason: '$name move $move ${level.name}');
            }
            checked++;
          }
          e.apply(ai.chooseMove(e.state, seat, AiLevel.medium, rng, AiBudget.phone));
        }
        expect(checked, greaterThan(10));
      });
    }
  });

  group('self-play (every AI level, no illegal move, card conservation, the match ends)', () {
    final variants = <Kit>[
      tarneebKit('jordan', const TarneebOptions()),
      tarneebKit('jordan to 41', const TarneebOptions.jordan(targetScore: 41)),
      tarneebKit('redeal by the next dealer', const TarneebOptions(allPass: TarneebAllPass.redealNextDealer)),
      tarneebKit('syrian trump', const TarneebOptions.syrianTrump()),
      tarneebKit('lebanese auction', const TarneebOptions.lebaneseAuction()),
      tarneebKit('open auction', const TarneebOptions.openAuction()),
      tarneebKit(
        'house rules',
        const TarneebOptions(
          worthlessHandRedeal: true,
          firstLeadMustBeTrump: true,
          loseAtNegativeTarget: true,
          kabootFailDefenders: TarneebKabootFail.single,
        ),
      ),
    ];
    for (final k in variants) {
      test('${k.name}: easy, medium, hard and mixed tables', () {
        playMatch(k, 1, List.filled(4, AiLevel.easy), jsonEvery: 11);
        playMatch(k, 2, List.filled(4, AiLevel.medium));
        playMatch(
          k,
          3,
          [AiLevel.hard, AiLevel.easy, AiLevel.medium, AiLevel.hard],
          budget: const AiBudget.simulations(12),
          jsonEvery: 17,
        );
      });
    }

    test('deterministic replay: the same seed and levels give the same match', () {
      final k = variants[3];
      const levels = [AiLevel.hard, AiLevel.easy, AiLevel.medium, AiLevel.easy];
      final a = playMatch(k, 42, levels, budget: const AiBudget.simulations(8));
      final b = playMatch(k, 42, levels, budget: const AiBudget.simulations(8));
      expect(b.finalJson, a.finalJson);
      final replay = k.create(42);
      for (final mj in a.moveLog) {
        replay.apply(replay.moveFromJson(jsonDecode(mj) as Map<String, Object?>));
      }
      expect(jsonEncode(replay.toJson()), a.finalJson);
    });
  });

  group('AI levels are ordered (two partners of one level against two of another)', () {
    for (final (name, options, strong, weak, matches, sims) in [
      ('jordan', const TarneebOptions(), AiLevel.hard, AiLevel.easy, 8, 24),
      ('syrian trump', const TarneebOptions.syrianTrump(), AiLevel.hard, AiLevel.easy, 6, 24),
      ('jordan', const TarneebOptions(), AiLevel.medium, AiLevel.easy, 8, 0),
      // With a phone-sized search (about 150 rollouts a move); with a tiny
      // budget the hard AI keeps the medium move.
      ('jordan', const TarneebOptions(), AiLevel.hard, AiLevel.medium, 6, 150),
    ]) {
      test('$name: ${strong.name} beats ${weak.name}', () {
        final k = tarneebKit(name, options);
        var wins = 0;
        var edge = 0;
        for (var m = 0; m < matches; m++) {
          final strongTeam = m % 2;
          final levels = [for (var s = 0; s < 4; s++) s % 2 == strongTeam ? strong : weak];
          final r = playMatch(k, 500 + m, levels, budget: AiBudget.simulations(sims));
          if (r.winners.contains(strongTeam)) wins++;
          edge += r.scores[strongTeam] - r.scores[1 - strongTeam];
        }
        // ignore: avoid_print
        print(
          'tarneeb $name: ${strong.name} won $wins/$matches against ${weak.name}, '
          'average edge ${(edge / matches).toStringAsFixed(1)}',
        );
        expect(wins, greaterThan(matches / 2));
        expect(edge, greaterThan(0));
      });
    }
  });
}

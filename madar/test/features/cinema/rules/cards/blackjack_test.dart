// Blackjack 21 (بلاك جاك ٢١): one test per rule and scoring line of the
// Madar spec (§5–§7), named after the rule ids (B-…).
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/cinema/rules/cards/blackjack/blackjack_rules.dart';
import 'package:madar/features/cinema/rules/cards/blackjack/blackjack_state.dart';
import 'package:madar/features/cinema/rules/cards/core/playing_card.dart';

const noBurn = BlackjackOptions(burnCard: false);

/// A table whose shoe gives [draw] first (deal order: one card to each seat,
/// the up card, a second card to each seat, the hole card).
BlackjackEngine table(String draw, {BlackjackOptions options = noBurn}) =>
    BlackjackEngine(BlackjackState.custom(options: options, drawOrder: PlayingCard.list(draw)));

List<BlackjackEvent> play(BlackjackEngine e, BlackjackMove m) => e.apply(m).cast<BlackjackEvent>();

List<BlackjackEventKind> kinds(List<BlackjackEvent> ev) => [for (final e in ev) e.kind];

BlackjackHand hand(BlackjackEngine e, [int seat = 0, int index = 0]) => e.state.seats[seat].hands[index];

List<PlayingCard> cards(String ids) => PlayingCard.list(ids);

void main() {
  group('presets and options (§6)', () {
    test('const BlackjackOptions() is the Jordan preset with every §6.1 value', () {
      const o = BlackjackOptions();
      expect(o, const BlackjackOptions.jordan());
      expect(o.decks, 6);
      expect(o.penetration, 0.75);
      expect(o.burnCard, isTrue);
      expect(o.continuousShuffle, isFalse);
      expect(o.holeCard, BlackjackHoleCard.peek);
      expect(o.originalOnly, isFalse);
      expect(o.dealerHitsSoft17, isFalse);
      expect(o.blackjackBonus, 3);
      expect(o.doubleOn, BlackjackDoubleOn.any);
      expect(o.doubleAfterSplit, isTrue);
      expect(o.maxHands, 4);
      expect(o.splitTensByRankOnly, isFalse);
      expect(o.resplitAces, isFalse);
      expect(o.hitSplitAces, isFalse);
      expect(o.surrender, BlackjackSurrender.off);
      expect(o.autoStandOn21, isTrue);
      expect(o.tally, BlackjackTally.net);
      expect(o.sessionRounds, 20);
      expect(o.seats, 1);
      expect(o.advisor, BlackjackAdvisor.onRequest);
    });

    test('options survive JSON, including an endless session and the European preset', () {
      final all = [
        const BlackjackOptions(),
        const BlackjackOptions.european(seats: 3, originalOnly: true),
        const BlackjackOptions(
          decks: 1,
          penetration: 0.85,
          dealerHitsSoft17: true,
          blackjackBonus: 2,
          doubleOn: BlackjackDoubleOn.nineToEleven,
          doubleAfterSplit: false,
          maxHands: 2,
          splitTensByRankOnly: true,
          resplitAces: true,
          hitSplitAces: true,
          surrender: BlackjackSurrender.late,
          autoStandOn21: false,
          tally: BlackjackTally.winsOnly,
          sessionRounds: null,
          seats: 2,
          advisor: BlackjackAdvisor.coach,
        ),
      ];
      for (final o in all) {
        final back = BlackjackOptions.fromJson(jsonDecode(jsonEncode(o.toJson())) as Map<String, Object?>);
        expect(back, o);
      }
      expect(const BlackjackOptions().copyWith(endless: true).sessionRounds, isNull);
    });
  });

  group('the shoe (B-1…B-5)', () {
    test('B-1 six packs, B-3 one card burned after the first shuffle', () {
      final s = BlackjackState.newMatch(seed: 3);
      expect(s.shoe.length + s.discards.length, 312);
      expect(s.discards.length, 1);
      expect(BlackjackState.newMatch(seed: 3, options: noBurn).discards, isEmpty);
      expect(
        BlackjackState.newMatch(seed: 3, options: const BlackjackOptions(continuousShuffle: true)).discards,
        isEmpty,
      );
      expect(BlackjackState.newMatch(seed: 3, options: const BlackjackOptions(decks: 2)).fullDeck().length, 104);
    });

    test('B-2 reshuffle only before a round and only below the 25 % line; B-3 burn after it', () {
      expect(const BlackjackOptions().reshuffleBelow, 78);
      const one = BlackjackOptions(decks: 1);
      expect(one.reshuffleBelow, 13);
      final deck = cards('2S 3S 4S 5S 6S 7S 8S 9S TS JS QS KS AS');
      final restOf = [
        for (final c in PlayingCard.list('2H 3H 4H 5H 6H 7H 8H 9H TH JH QH KH AH')) c,
        for (final s in [Suit.clubs, Suit.diamonds])
          for (final r in Rank.values) PlayingCard(s, r),
      ];
      // 13 cards left: no shuffle.
      final e = BlackjackEngine(
        BlackjackState.custom(options: one, drawOrder: deck, discards: restOf, fillRest: false),
      );
      var ev = play(e, BlackjackMove.deal);
      expect(kinds(ev), isNot(contains(BlackjackEventKind.shoeShuffled)));
      // 12 cards left: shuffle, then burn, then deal.
      final f = BlackjackEngine(
        BlackjackState.custom(options: one, drawOrder: deck.sublist(1), discards: [deck.first, ...restOf], fillRest: false),
      );
      ev = play(f, BlackjackMove.deal);
      expect(kinds(ev).take(3), [
        BlackjackEventKind.shoeShuffled,
        BlackjackEventKind.cardBurned,
        BlackjackEventKind.dealt,
      ]);
      expect(ev.first.reason, 'cutCard');
      expect(f.state.discards.length, 1);
      expect(f.state.shoe.length, 52 - 1 - 4);
    });

    test('B-4 continuous shuffle: every card back before every round, no burn', () {
      final e = BlackjackEngine.newMatch(seed: 9, options: const BlackjackOptions(continuousShuffle: true));
      for (var round = 0; round < 3; round++) {
        if (e.state.phase == BlackjackPhase.playerTurn) {
          while (e.state.phase == BlackjackPhase.playerTurn) {
            play(e, BlackjackMove.stand);
          }
        }
        final ev = play(e, BlackjackMove.deal);
        expect(ev.first.kind, BlackjackEventKind.shoeShuffled);
        expect(ev.first.reason, 'continuous');
        expect(kinds(ev), isNot(contains(BlackjackEventKind.cardBurned)));
        expect(e.state.discards, isEmpty);
      }
    });

    test('B-5 an empty shoe mid-round is refilled from the discards without a burn', () {
      // 1 pack, 3 seats: 9 cards in the shoe (above the 85 % line of 8).
      const o = BlackjackOptions(decks: 1, penetration: 0.85, seats: 3, burnCard: false);
      final draw = cards('8S TH TD 6C 8H 9H 9D TC 5S');
      final rest = [
        for (final c in [
          for (final s in Suit.values)
            for (final r in Rank.values) PlayingCard(s, r),
        ])
          if (!draw.contains(c)) c,
      ];
      final e = BlackjackEngine(BlackjackState.custom(options: o, drawOrder: draw, discards: rest, fillRest: false));
      play(e, BlackjackMove.deal);
      play(e, BlackjackMove.split); // the last shoe card goes to the first 8
      expect(e.state.shoe, isEmpty);
      final ev = play(e, BlackjackMove.stand); // the second 8 needs a card
      final shuffle = ev.firstWhere((x) => x.kind == BlackjackEventKind.shoeShuffled);
      expect(shuffle.reason, 'emergency');
      expect(kinds(ev), isNot(contains(BlackjackEventKind.cardBurned)));
      expect(hand(e, 0, 1).cards.length, 2);
      expect(sortedCards(e.state.cardsInPlay()), sortedCards(e.state.fullDeck()));
    });

    test('B-5 with no card anywhere the hand that needs one stands, and so does the dealer', () {
      const o = BlackjackOptions(decks: 1, penetration: 0.85, seats: 3, burnCard: false);
      final e = BlackjackEngine(
        BlackjackState.custom(options: o, drawOrder: cards('8S TH TD 6C 8H 9H 9D TC 5S'), fillRest: false),
      );
      play(e, BlackjackMove.deal);
      play(e, BlackjackMove.split);
      final ev = play(e, BlackjackMove.stand);
      expect(ev.where((x) => x.kind == BlackjackEventKind.stood && x.reason == 'noCards').length, 1);
      expect(kinds(ev), isNot(contains(BlackjackEventKind.shoeShuffled)));
      expect(hand(e, 0, 1).cards, cards('8H'));
      play(e, BlackjackMove.stand); // seat 1: 19
      final last = play(e, BlackjackMove.stand); // seat 2: 19; dealer 16 cannot draw
      expect(kinds(last), isNot(contains(BlackjackEventKind.dealerDrew)));
      expect(e.state.dealer, cards('6C TC'));
      expect(e.state.lastRound!.dealerTotal, 16);
      expect(e.state.phase, BlackjackPhase.betweenRounds);
    });
  });

  group('values (B-10…B-13)', () {
    test('B-10/B-11 totals: A-A-9 soft 21, A-A-10 hard 12, A-6 soft 17, A-6-10 hard 17', () {
      expect(blackjackTotal(cards('AS AH 9D')), (total: 21, soft: true));
      expect(blackjackTotal(cards('AS AH TD')), (total: 12, soft: false));
      expect(blackjackTotal(cards('AS 6H')), (total: 17, soft: true));
      expect(blackjackTotal(cards('AS 6H TD')), (total: 17, soft: false));
      expect(blackjackTotal(cards('KS QH')), (total: 20, soft: false));
      expect(blackjackCardValue(PlayingCard.parse('JD')), 10);
      expect(blackjackCardValue(PlayingCard.parse('AD')), 1);
    });

    test('B-11/B-31 a soft 21 (A-A-9) stands by itself', () {
      final e = table('AS 9D AH 7C 9S TC');
      play(e, BlackjackMove.deal);
      final ev = play(e, BlackjackMove.hit);
      expect(ev.any((x) => x.kind == BlackjackEventKind.stood && x.reason == 'twentyOne'), isTrue);
      expect(hand(e).cards, cards('AS AH 9S'));
      expect(hand(e).outcome, BlackjackOutcome.win); // dealer 16 + 10 = bust
      expect(e.scores, [2]);
    });

    test('B-31 autoStandOn21 off: a soft 21 may still take a card', () {
      final e = table('AS 9D AH 7C 9S', options: noBurn.copyWith(autoStandOn21: false));
      play(e, BlackjackMove.deal);
      play(e, BlackjackMove.hit);
      expect(e.legalMoves(0), contains(BlackjackMove.hit));
    });

    test('B-12 a natural is ace + 10-value as the first two cards of an unsplit hand', () {
      expect(BlackjackHand(cards: cards('AS KD')).natural, isTrue);
      expect(BlackjackHand(cards: cards('AS KD'), fromSplit: true).natural, isFalse);
      expect(BlackjackHand(cards: cards('AS 5D 5H')).natural, isFalse);
    });

    test('B-13 a busted hand loses at once, even when the dealer busts later', () {
      final e = table('TS 9H 6D 6S 9C 7C 8S TC', options: noBurn.copyWith(seats: 2));
      // Seat 0: 10 6 (16), seat 1: 9 9 (18), dealer 6 7.
      play(e, BlackjackMove.deal);
      final ev = play(e, BlackjackMove.hit); // seat 0 takes 8: 24
      expect(kinds(ev), containsAllInOrder([BlackjackEventKind.bust, BlackjackEventKind.handSettled]));
      expect(hand(e).outcome, BlackjackOutcome.loss);
      play(e, BlackjackMove.stand); // seat 1; dealer 13 takes 10: 23
      expect(e.state.lastRound!.dealerBust, isTrue);
      expect(e.scores, [-2, 2]);
    });
  });

  group('the round (B-20…B-26)', () {
    test('B-20/B-21 seat 0 deals; one card to each seat, the up card, a second each, the hole card', () {
      final e = table('2S 3S 4S 5S 6S 7S', options: noBurn.copyWith(seats: 2));
      expect(e.currentPlayer, 0);
      expect(e.legalMoves(0), [BlackjackMove.deal]);
      expect(e.legalMoves(1), isEmpty);
      play(e, BlackjackMove.deal);
      expect(hand(e, 0).cards, cards('2S 5S'));
      expect(hand(e, 1).cards, cards('3S 6S'));
      expect(e.state.dealer, cards('4S 7S'));
      expect(e.state.holeHidden, isTrue);
      expect(e.state.dealerVisible, cards('4S'));
      expect(e.currentPlayer, 0);
      expect(e.legalMoves(1), isEmpty);
    });

    test('B-22 up A, hole K: the round ends at once; 10-9 scores −2, A-Q pushes; nobody acts', () {
      final e = table('TS AH AD 9S QH KC', options: noBurn.copyWith(seats: 2));
      final ev = play(e, BlackjackMove.deal);
      final peek = ev.firstWhere((x) => x.kind == BlackjackEventKind.dealerPeeked);
      expect(peek.value, 1);
      expect(kinds(ev), contains(BlackjackEventKind.holeRevealed));
      expect(e.scores, [-2, 0]);
      expect(hand(e, 1).outcome, BlackjackOutcome.push);
      expect(e.state.phase, BlackjackPhase.betweenRounds);
      expect(e.legalMoves(0), [BlackjackMove.deal]);
      expect(e.state.lastRound!.dealerBlackjack, isTrue);
    });

    test('B-22 up 10, hole 9: the peek finds nothing and play goes on', () {
      final e = table('TS TD 8H 9C');
      final ev = play(e, BlackjackMove.deal);
      expect(ev.firstWhere((x) => x.kind == BlackjackEventKind.dealerPeeked).value, 0);
      expect(e.state.phase, BlackjackPhase.playerTurn);
      expect(e.state.holeHidden, isTrue);
      expect(e.legalMoves(0), containsAll([BlackjackMove.hit, BlackjackMove.stand, BlackjackMove.doubleHand]));
    });

    test('B-22 no peek with a 2–9 up card', () {
      final e = table('TS 9D 8H AC');
      final ev = play(e, BlackjackMove.deal);
      expect(kinds(ev), isNot(contains(BlackjackEventKind.dealerPeeked)));
    });

    test('B-23 there is no side offer against a dealer ace: the only moves are the hand decisions', () {
      final e = table('TS AD 8H 6C');
      play(e, BlackjackMove.deal);
      expect(e.legalMoves(0).map((m) => m.action).toSet(), {
        BlackjackAction.hit,
        BlackjackAction.stand,
        BlackjackAction.double,
      });
    });

    test('B-24/B-50 player A-K against a 6: +3 at once and the dealer draws nothing', () {
      final e = table('AS 6D KH TC');
      final ev = play(e, BlackjackMove.deal);
      expect(kinds(ev), containsAllInOrder([BlackjackEventKind.blackjack, BlackjackEventKind.handSettled]));
      expect(kinds(ev), isNot(contains(BlackjackEventKind.dealerDrew)));
      expect(e.state.dealer, cards('6D TC'));
      expect(e.scores, [3]);
      expect(e.state.seats.first.blackjacks, 1);
    });

    test('B-24 with a peek, a natural against an ace is settled at once when the dealer has none', () {
      final e = table('AS AD KH 6C');
      play(e, BlackjackMove.deal);
      expect(hand(e).outcome, BlackjackOutcome.blackjack);
      expect(e.scores, [3]);
    });

    test('B-25 European table: the dealer has only the up card while the seats play', () {
      final e = table('TS 9D 7H', options: noBurn.copyWith(holeCard: BlackjackHoleCard.europeanNoHoleCard));
      final ev = play(e, BlackjackMove.deal);
      expect(e.state.dealer, cards('9D'));
      expect(e.state.holeHidden, isFalse);
      expect(kinds(ev), isNot(contains(BlackjackEventKind.dealerPeeked)));
    });

    test('B-24 European table: A-K against an ace waits for the dealer\'s second card', () {
      const eu = BlackjackOptions.european();
      final e = table('AS AD KH 5C', options: eu.copyWith(burnCard: false));
      final ev = play(e, BlackjackMove.deal);
      final k = kinds(ev);
      expect(k.indexOf(BlackjackEventKind.dealerDrew), lessThan(k.indexOf(BlackjackEventKind.handSettled)));
      expect(e.state.dealer, cards('AD 5C')); // no live hand: no more cards
      expect(e.scores, [3]);
      final f = table('AS AD KH KC', options: eu.copyWith(burnCard: false));
      play(f, BlackjackMove.deal);
      expect(hand(f).outcome, BlackjackOutcome.push);
      expect(f.scores, [0]);
    });

    test('B-25/B-61g European table: a doubled 11 against a dealer natural scores −4, or −2 with originalOnly', () {
      for (final (originalOnly, expected) in [(false, -4), (true, -2)]) {
        final e = table(
          '6S TD 5H 9C AS',
          options: BlackjackOptions.european(originalOnly: originalOnly).copyWith(burnCard: false),
        );
        play(e, BlackjackMove.deal);
        play(e, BlackjackMove.doubleHand); // 6 5 9 = 20
        expect(e.state.lastRound!.dealerBlackjack, isTrue);
        expect(e.scores, [expected], reason: 'originalOnly: $originalOnly');
      }
    });

    test('B-25/B-61g European originalOnly: a seat split into 3 hands loses −2 in all', () {
      for (final (originalOnly, expected) in [(true, -2), (false, -10)]) {
        final e = table(
          '8S TD 8H 8C 3S 9H 2D 5S 7D AS',
          options: BlackjackOptions.european(originalOnly: originalOnly).copyWith(burnCard: false),
        );
        play(e, BlackjackMove.deal);
        play(e, BlackjackMove.split);
        play(e, BlackjackMove.split);
        play(e, BlackjackMove.doubleHand); // 8 3 9
        play(e, BlackjackMove.doubleHand); // 8 2 5
        play(e, BlackjackMove.stand); // 8 7
        final seat = e.state.seats.first;
        expect(seat.hands.length, 3);
        expect(seat.handsLost, 3);
        expect(e.scores, [expected], reason: 'originalOnly: $originalOnly');
      }
    });

    test('B-26 seats act in order, each hand to the end, then the dealer', () {
      final e = table('TS 9H 7D 6S 9C 9D 8S 5C', options: noBurn.copyWith(seats: 2));
      play(e, BlackjackMove.deal);
      expect(e.currentPlayer, 0);
      play(e, BlackjackMove.stand);
      expect(e.currentPlayer, 1);
      expect(e.legalMoves(0), isEmpty);
    });
  });

  group('player actions (B-30…B-41)', () {
    test('B-30/B-32 hit takes one card, stand ends the hand', () {
      final e = table('TS 9D 2H 7C 3S');
      play(e, BlackjackMove.deal);
      final ev = play(e, BlackjackMove.hit);
      expect(ev.first.kind, BlackjackEventKind.hit);
      expect(ev.first.cards, cards('3S'));
      expect(hand(e).cards.length, 3);
      play(e, BlackjackMove.stand);
      expect(e.state.phase, BlackjackPhase.betweenRounds);
    });

    test('B-33 double: one card, then the hand stands; only as the first decision', () {
      final e = table('6S 9D 5H 7C TS');
      play(e, BlackjackMove.deal);
      final ev = play(e, BlackjackMove.doubleHand);
      expect(ev.first.kind, BlackjackEventKind.handDoubled);
      expect(hand(e).doubled, isTrue);
      expect(hand(e).cards.length, 3);
      expect(e.state.phase, BlackjackPhase.betweenRounds); // 21 against 16 + 2 ...
      final f = table('6S 9D 2H 7C 2S');
      play(f, BlackjackMove.deal);
      play(f, BlackjackMove.hit);
      expect(f.legalMoves(0), isNot(contains(BlackjackMove.doubleHand)));
      expect(f.validate(BlackjackMove.doubleHand), 'cannotDouble');
    });

    test('B-33 doubleOn nineToEleven: hard 9–11 only', () {
      const o = BlackjackOptions(burnCard: false, doubleOn: BlackjackDoubleOn.nineToEleven);
      for (final (draw, allowed) in [
        ('6S 9D 4H 7C', true), // 10
        ('6S 9D 2H 7C', false), // 8
        ('AS 9D 7H 7C', false), // soft 18
        ('9S 9D 3H 7C', false), // 12
        ('5S 9D 4H 7C', true), // 9
      ]) {
        final e = table(draw, options: o);
        play(e, BlackjackMove.deal);
        expect(e.state.canDouble, allowed, reason: draw);
      }
    });

    test('B-34 double after split by default; not with doubleAfterSplit off; never on split aces', () {
      final e = table('8S 6D 8H TC 3S');
      play(e, BlackjackMove.deal);
      play(e, BlackjackMove.split);
      expect(e.state.canDouble, isTrue);
      final f = table('8S 6D 8H TC 3S', options: noBurn.copyWith(doubleAfterSplit: false));
      play(f, BlackjackMove.deal);
      play(f, BlackjackMove.split);
      expect(f.state.canDouble, isFalse);
      final g = table('AS 6D AH TC 5S', options: noBurn.copyWith(hitSplitAces: true));
      play(g, BlackjackMove.deal);
      play(g, BlackjackMove.split);
      expect(g.state.canHit, isTrue);
      expect(g.state.canDouble, isFalse);
    });

    test('B-35 K-Q splits by default, not with splitTensByRankOnly (K-K still does)', () {
      final e = table('KS 6D QH TC');
      play(e, BlackjackMove.deal);
      expect(e.state.canSplit, isTrue);
      final f = table('KS 6D QH TC', options: noBurn.copyWith(splitTensByRankOnly: true));
      play(f, BlackjackMove.deal);
      expect(f.state.canSplit, isFalse);
      expect(f.validate(BlackjackMove.split), 'cannotSplit');
      final g = table('KS 6D KH TC', options: noBurn.copyWith(splitTensByRankOnly: true));
      play(g, BlackjackMove.deal);
      expect(g.state.canSplit, isTrue);
      final h = table('9S 6D 8H TC');
      play(h, BlackjackMove.deal);
      expect(h.state.canSplit, isFalse);
    });

    test('B-36 re-split: the 4th eight makes a 4th hand, a 5th eight cannot split', () {
      final e = table('8S 6D 8H TC 8D 8C 8S');
      play(e, BlackjackMove.deal);
      play(e, BlackjackMove.split);
      play(e, BlackjackMove.split);
      play(e, BlackjackMove.split);
      expect(e.state.seats.first.hands.length, 4);
      expect(hand(e).cards, cards('8S 8S'));
      expect(e.state.canSplit, isFalse);
      expect(e.state.seats.first.splits, 3);
      final f = table('8S 6D 8H TC 8D 8C', options: noBurn.copyWith(maxHands: 2));
      play(f, BlackjackMove.deal);
      play(f, BlackjackMove.split);
      expect(f.state.canSplit, isFalse);
    });

    test('B-37/B-57 8-8 vs 6: split, double to 21, stand on 18, dealer busts: +4 +2 = +6', () {
      final e = table('8S 6D 8H TC 3S KD TH 7C');
      play(e, BlackjackMove.deal);
      play(e, BlackjackMove.split);
      // The second hand gets its card only when its turn comes.
      expect(hand(e, 0, 0).cards, cards('8S 3S'));
      expect(hand(e, 0, 1).cards, cards('8H'));
      play(e, BlackjackMove.doubleHand);
      expect(hand(e, 0, 0).cards, cards('8S 3S KD'));
      expect(hand(e, 0, 1).cards, cards('8H TH'));
      final ev = play(e, BlackjackMove.stand);
      expect(kinds(ev), contains(BlackjackEventKind.dealerDrew));
      expect(e.state.dealer, cards('6D TC 7C'));
      expect(e.scores, [6]);
      final seat = e.state.seats.first;
      expect(seat.handsWon, 2);
      expect(seat.doublesWon, 1);
      expect(e.state.lastRound!.seatPoints, [6]);
    });

    test('B-38/B-39 A-A split: A+K is an ordinary 21 (+2), A+A is a soft 12 that stands', () {
      final e = table('AS 9D AH 8C KS AD');
      play(e, BlackjackMove.deal);
      play(e, BlackjackMove.split);
      expect(e.state.phase, BlackjackPhase.betweenRounds);
      expect(hand(e, 0, 0).cards, cards('AS KS'));
      expect(hand(e, 0, 0).outcome, BlackjackOutcome.win);
      expect(hand(e, 0, 0).points, 2);
      expect(hand(e, 0, 1).cards, cards('AH AD'));
      expect(hand(e, 0, 1).outcome, BlackjackOutcome.loss);
      expect(e.scores, [0]);
      expect(e.state.seats.first.blackjacks, 0);
    });

    test('B-38 resplitAces lets A+A split again; hitSplitAces lets a split ace take cards', () {
      final e = table('AS 9D AH 8C AD 5S 5H 5C', options: noBurn.copyWith(resplitAces: true));
      play(e, BlackjackMove.deal);
      play(e, BlackjackMove.split);
      expect(e.state.phase, BlackjackPhase.playerTurn);
      expect(e.legalMoves(0), [BlackjackMove.stand, BlackjackMove.split]);
      play(e, BlackjackMove.split);
      expect(e.state.seats.first.hands.length, 3);
      final f = table('AS 9D AH 8C 5S 2H', options: noBurn.copyWith(hitSplitAces: true));
      play(f, BlackjackMove.deal);
      play(f, BlackjackMove.split);
      expect(f.legalMoves(0), [BlackjackMove.hit, BlackjackMove.stand]);
    });

    test('B-40 late surrender: −1 on the original two cards; refused after hit or split, when off, and in Europe', () {
      const late = BlackjackOptions(burnCard: false, surrender: BlackjackSurrender.late);
      final e = table('TS 9D 6H 8C', options: late);
      play(e, BlackjackMove.deal);
      expect(e.legalMoves(0), contains(BlackjackMove.surrender));
      final ev = play(e, BlackjackMove.surrender);
      expect(kinds(ev), containsAllInOrder([BlackjackEventKind.surrendered, BlackjackEventKind.handSettled]));
      expect(kinds(ev), isNot(contains(BlackjackEventKind.dealerDrew)));
      expect(e.scores, [-1]);
      expect(hand(e).outcome, BlackjackOutcome.surrendered);

      final hit = table('TS 9D 3H 8C 2S', options: late);
      play(hit, BlackjackMove.deal);
      play(hit, BlackjackMove.hit);
      expect(hit.validate(BlackjackMove.surrender), 'cannotSurrender');

      final split = table('8S 9D 8H 8C 3S', options: late);
      play(split, BlackjackMove.deal);
      play(split, BlackjackMove.split);
      expect(split.state.canSurrender, isFalse);

      final off = table('TS 9D 6H 8C');
      play(off, BlackjackMove.deal);
      expect(off.state.canSurrender, isFalse);

      final eu = table(
        'TS 9D 6H',
        options: const BlackjackOptions.european().copyWith(burnCard: false, surrender: BlackjackSurrender.late),
      );
      play(eu, BlackjackMove.deal);
      expect(eu.state.canSurrender, isFalse);
    });

    test('B-40 surrender comes after the peek: a dealer natural ends the round first', () {
      final e = table('TS AD 6H KC', options: noBurn.copyWith(surrender: BlackjackSurrender.late));
      play(e, BlackjackMove.deal);
      expect(e.state.phase, BlackjackPhase.betweenRounds);
      expect(e.scores, [-2]);
    });
  });

  group('the dealer (B-50…B-52)', () {
    test('B-50 all hands bust: hole card shown, no dealer draw; one live seat: the dealer draws', () {
      final e = table('TS 7D 6H 9C 8S');
      play(e, BlackjackMove.deal);
      final ev = play(e, BlackjackMove.hit);
      expect(kinds(ev), contains(BlackjackEventKind.holeRevealed));
      expect(kinds(ev), isNot(contains(BlackjackEventKind.dealerDrew)));
      expect(e.state.dealer, cards('7D 9C'));

      final f = table('TS 9H 7D 6S 9C 9D 8S 5C', options: noBurn.copyWith(seats: 2));
      play(f, BlackjackMove.deal);
      play(f, BlackjackMove.hit); // seat 0 busts
      play(f, BlackjackMove.stand); // seat 1 stands on 18
      expect(f.state.dealer, cards('7D 9D 5C'));
      expect(f.scores, [-2, -2]);
    });

    test('B-51 the dealer hits 16 or less and stands on hard 17', () {
      final e = table('TS 9D 9H 7C 2S');
      play(e, BlackjackMove.deal);
      play(e, BlackjackMove.stand);
      expect(e.state.dealer, cards('9D 7C 2S'));
      expect(e.scores, [2]); // 19 against 18
      expect(BlackjackRules.dealerHits(cards('TS 7C'), const BlackjackOptions()), isFalse);
      expect(BlackjackRules.dealerHits(cards('TS 6C'), const BlackjackOptions()), isTrue);
    });

    test('B-52 soft 17 (A-6, A-A-5): stands by default, hits with dealerHitsSoft17', () {
      const s17 = BlackjackOptions();
      const h17 = BlackjackOptions(dealerHitsSoft17: true);
      for (final soft17 in ['AS 6C', 'AS AH 5C']) {
        expect(BlackjackRules.dealerHits(cards(soft17), s17), isFalse, reason: soft17);
        expect(BlackjackRules.dealerHits(cards(soft17), h17), isTrue, reason: soft17);
      }
      final e = table('TS AD 8H 6C 4D');
      play(e, BlackjackMove.deal);
      play(e, BlackjackMove.stand);
      expect(e.scores, [2]);
      final f = table('TS AD 8H 6C 4D', options: noBurn.copyWith(dealerHitsSoft17: true));
      play(f, BlackjackMove.deal);
      play(f, BlackjackMove.stand);
      expect(f.state.dealer, cards('AD 6C 4D'));
      expect(f.scores, [-2]);
    });
  });

  group('settlement and points (B-55…B-61)', () {
    test('B-60 a natural scores +3, or +2 with blackjackBonus 2', () {
      final e = table('AS 6D KH TC', options: noBurn.copyWith(blackjackBonus: 2));
      play(e, BlackjackMove.deal);
      expect(e.scores, [2]);
      expect(hand(e).outcome, BlackjackOutcome.blackjack);
    });

    test('B-61a win +2, B-61c push 0, B-61d loss −2', () {
      final win = table('TS 9D 9H 8C');
      play(win, BlackjackMove.deal);
      play(win, BlackjackMove.stand);
      expect(win.scores, [2]);
      final push = table('TS 9D 8H 9C');
      play(push, BlackjackMove.deal);
      play(push, BlackjackMove.stand);
      expect(push.scores, [0]);
      expect(push.state.seats.first.handsPushed, 1);
      final loss = table('TS 9D 7H TC');
      play(loss, BlackjackMove.deal);
      play(loss, BlackjackMove.stand);
      expect(loss.scores, [-2]);
      expect(loss.state.seats.first.handsLost, 1);
    });

    test('B-61b doubled win +4, B-61e doubled loss −4', () {
      final win = table('6S 9D 5H 8C TS');
      play(win, BlackjackMove.deal);
      play(win, BlackjackMove.doubleHand);
      expect(win.scores, [4]);
      final loss = table('6S TD 5H TC 2S');
      play(loss, BlackjackMove.deal);
      play(loss, BlackjackMove.doubleHand);
      expect(loss.scores, [-4]);
    });

    test('B-58 a 21 of three cards beats a dealer 20; B-59 split hands settle one by one', () {
      final e = table('8S TD 8H TC 3S KD 2H 9S');
      play(e, BlackjackMove.deal);
      play(e, BlackjackMove.split); // 8 3
      play(e, BlackjackMove.hit); // 8 3 K = 21, stands
      play(e, BlackjackMove.hit); // second hand 8 2 + 9 = 19
      play(e, BlackjackMove.stand);
      expect(hand(e, 0, 0).outcome, BlackjackOutcome.win);
      expect(hand(e, 0, 1).outcome, BlackjackOutcome.loss);
      expect(e.scores, [0]);
    });

    test('B-62 winsOnly tally: losses score 0, wins as usual', () {
      const o = BlackjackOptions(burnCard: false, tally: BlackjackTally.winsOnly);
      final loss = table('6S TD 5H TC 2S', options: o);
      play(loss, BlackjackMove.deal);
      play(loss, BlackjackMove.doubleHand);
      expect(loss.scores, [0]);
      expect(hand(loss).points, 0);
      final win = table('6S 9D 5H 8C TS', options: o);
      play(win, BlackjackMove.deal);
      play(win, BlackjackMove.doubleHand);
      expect(win.scores, [4]);
      final sur = table('TS 9D 6H 8C', options: o.copyWith(surrender: BlackjackSurrender.late));
      play(sur, BlackjackMove.deal);
      play(sur, BlackjackMove.surrender);
      expect(sur.scores, [0]);
    });

    test('B-63 a round above 0 extends the streak, below 0 breaks it, 0 leaves it', () {
      // Rounds: win, win, push, loss.
      final e = table('TS 9D 9H 8C TS 9D 9H 8C TS 9D 8H 9C TS 9D 7H TC');
      int streakAfterRound() {
        play(e, BlackjackMove.deal);
        play(e, BlackjackMove.stand);
        return e.state.seats.first.streak;
      }

      expect(streakAfterRound(), 1);
      expect(streakAfterRound(), 2);
      expect(streakAfterRound(), 2);
      expect(streakAfterRound(), 0);
      expect(e.state.seats.first.bestStreak, 2);
    });

    test('B-64 an endless session ends only with endSession; B-64 a session ends after sessionRounds', () {
      final e = BlackjackEngine.newMatch(seed: 2, options: const BlackjackOptions(sessionRounds: null));
      expect(e.legalMoves(0), [BlackjackMove.deal, BlackjackMove.endSession]);
      final ev = play(e, BlackjackMove.endSession);
      expect(ev.single.kind, BlackjackEventKind.sessionOver);
      expect(e.isOver, isTrue);
      expect(e.currentPlayer, isNull);

      final f = BlackjackEngine.newMatch(seed: 2, options: const BlackjackOptions(sessionRounds: 10));
      expect(f.validate(BlackjackMove.endSession), 'sessionHasRounds');
      var rounds = 0;
      while (!f.isOver) {
        final m = f.legalMoves(f.currentPlayer!).first;
        final events = play(f, m);
        if (events.any((x) => x.kind == BlackjackEventKind.roundScored)) rounds++;
      }
      expect(rounds, 10);
      expect(f.state.roundsPlayed, 10);
    });

    test('B-67 winner: higher points, then hands won, then naturals, then fewer busts, else a draw', () {
      final s = BlackjackState.newMatch(seed: 1, options: const BlackjackOptions(seats: 3))
        ..phase = BlackjackPhase.over;
      void set(int i, int points, int won, int bj, int busts) => s.seats[i]
        ..points = points
        ..handsWon = won
        ..blackjacks = bj
        ..busts = busts;
      set(0, 4, 5, 1, 2);
      set(1, 4, 6, 0, 3);
      set(2, 2, 9, 3, 0);
      expect(s.winners, [1]);
      set(1, 4, 5, 1, 2);
      expect(s.winners, [0, 1]);
      set(1, 4, 5, 2, 9);
      expect(s.winners, [1]);
      set(1, 4, 5, 1, 1);
      expect(s.winners, [1]);
      final solo = BlackjackState.newMatch(seed: 1)..phase = BlackjackPhase.over;
      expect(solo.winners, [0]);
      expect(solo.soloSessionWon, isFalse);
      solo.seats.first.points = 3;
      expect(solo.soloSessionWon, isTrue);
    });
  });

  group('the advisor (B-75)', () {
    test('coach: a hard 16 vs 10 hit matches the chart; a stand is a deviation with advice', () {
      const coach = BlackjackOptions(burnCard: false, advisor: BlackjackAdvisor.coach);
      final e = table('TS TD 6H 9C 2S', options: coach);
      play(e, BlackjackMove.deal);
      expect(e.advice()!.action, BlackjackAction.hit);
      final ev = play(e, BlackjackMove.hit);
      expect(kinds(ev), isNot(contains(BlackjackEventKind.adviceGiven)));
      expect(e.state.seats.first.decisions, 1);
      expect(e.state.seats.first.decisionsMatched, 1);

      final f = table('TS TD 6H 9C', options: coach);
      play(f, BlackjackMove.deal);
      final ev2 = play(f, BlackjackMove.stand);
      final advice = ev2.firstWhere((x) => x.kind == BlackjackEventKind.adviceGiven);
      expect(advice.action, BlackjackAction.hit);
      expect(f.state.seats.first.accuracy, 0.0);

      final g = table('TS TD 6H 9C');
      play(g, BlackjackMove.deal);
      expect(kinds(play(g, BlackjackMove.stand)), isNot(contains(BlackjackEventKind.adviceGiven)));
      expect(g.state.seats.first.decisions, 1);
    });
  });

  group('state', () {
    test('validate gives stable error ids', () {
      final e = table('TS 9D 7H 8C');
      expect(e.validate(BlackjackMove.hit), 'noRoundInProgress');
      play(e, BlackjackMove.deal);
      expect(e.validate(BlackjackMove.deal), 'roundInProgress');
      expect(e.validate(BlackjackMove.split), 'cannotSplit');
      expect(e.validate(BlackjackMove.surrender), 'cannotSurrender');
      expect(e.validate(BlackjackMove.endSession), 'roundInProgress');
    });

    test('card conservation: shoe + discards + table = 52 × decks after every action', () {
      final e = BlackjackEngine.newMatch(seed: 4, options: const BlackjackOptions(decks: 2, seats: 3));
      final full = sortedCards(e.state.fullDeck());
      while (!e.isOver) {
        final p = e.currentPlayer!;
        final legal = e.legalMoves(p);
        e.apply(legal.contains(BlackjackMove.split) ? BlackjackMove.split : legal.first);
        expect(sortedCards(e.state.cardsInPlay()), full);
      }
    });

    test('save / resume mid-hand keeps the shoe order, the generator, seat, hand index, tally and streak', () {
      final e = table('TS 9D 9H 8C 8S 6D 8H TC 3S KD TH 7C');
      play(e, BlackjackMove.deal);
      play(e, BlackjackMove.stand); // +2, streak 1
      play(e, BlackjackMove.deal);
      play(e, BlackjackMove.split);
      final json = jsonDecode(jsonEncode(e.toJson())) as Map<String, Object?>;
      expect(json['game'], 'blackjack');
      final back = BlackjackEngine.fromJson(json);
      expect(jsonEncode(back.toJson()), jsonEncode(json));
      expect(back.state.handIndex, 0);
      expect(back.state.seats.first.streak, 1);
      expect(back.state.shoe, e.state.shoe);
      for (final m in [BlackjackMove.doubleHand, BlackjackMove.stand, BlackjackMove.deal]) {
        e.apply(m);
        back.apply(m);
      }
      expect(jsonEncode(back.toJson()), jsonEncode(e.toJson()));
      expect(e.scores, [8]);
    });
  });

  test('§5.7 wording: no wagering words in the Blackjack package, its ids, options or events', () {
    const english = [
      'bet',
      'bets',
      'betting',
      'wager',
      'wagers',
      'wagering',
      'stake',
      'stakes',
      'chip',
      'chips',
      'money',
      'cash',
      'bankroll',
      'payout',
      'payouts',
      'pay',
      'pays',
      'paid',
      'odds',
      'house',
      'casino',
      'insurance',
      'even money',
    ];
    const arabic = [
      'رهان',
      'مراهنة',
      'راهن',
      'فيش',
      'رقائق',
      'مال',
      'فلوس',
      'أموال',
      'رصيد',
      'كازينو',
      'ربح مالي',
      'تأمين',
      'دفعة',
      'التاجر',
    ];
    // camelCase ids become separate words so `betAmount` is caught but
    // `between` is not.
    String words(String text) => text.replaceAllMapped(RegExp('([a-z])([A-Z])'), (m) => '${m[1]} ${m[2]}').toLowerCase();
    bool hasEnglish(String text, String w) => RegExp('\\b${RegExp.escape(w)}\\b').hasMatch(words(text));
    bool hasArabic(String text, String w) =>
        RegExp('(^|[\\s\\p{P}])${RegExp.escape(w)}(\$|[\\s\\p{P}])', unicode: true).hasMatch(text);

    final dir = Directory('lib/features/cinema/rules/cards/blackjack');
    final files = dir.listSync().whereType<File>().where((f) => f.path.endsWith('.dart')).toList();
    expect(files, isNotEmpty);
    final texts = {
      for (final f in files) f.path: f.readAsStringSync(),
      'ids': [
        ...BlackjackEventKind.values.map((v) => v.name),
        ...BlackjackAction.values.map((v) => v.name),
        ...BlackjackOutcome.values.map((v) => v.name),
        ...const BlackjackOptions().toJson().keys,
        ...BlackjackHand(cards: cards('AS')).toJson().keys,
        ...BlackjackSeat().toJson().keys,
      ].join(' '),
    };
    for (final e in texts.entries) {
      for (final w in english) {
        expect(hasEnglish(e.value, w), isFalse, reason: '"$w" in ${e.key}');
      }
      for (final w in arabic) {
        expect(hasArabic(e.value, w), isFalse, reason: '"$w" in ${e.key}');
      }
    }
    expect(hasEnglish('betAmount', 'bet'), isTrue);
    expect(hasEnglish('between rounds', 'bet'), isFalse);
  });
}

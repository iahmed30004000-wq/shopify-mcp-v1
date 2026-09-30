// "41" (طلب فردي), the individual-bid game of the Tarneeb family, with its
// "400 (لبناني)" and "سوري 41" presets: one test per rule and scoring line of
// the rules document (RULES.md, the "B" numbering), edge cases, match end,
// serialisation, the AI and seeded self-play.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/cinema/rules/cards/core/card_game.dart';
import 'package:madar/features/cinema/rules/cards/core/card_rng.dart';
import 'package:madar/features/cinema/rules/cards/core/deck.dart';
import 'package:madar/features/cinema/rules/cards/core/determinize.dart';
import 'package:madar/features/cinema/rules/cards/core/playing_card.dart';
import 'package:madar/features/cinema/rules/cards/tarneeb41/forty_one_ai.dart';
import 'package:madar/features/cinema/rules/cards/tarneeb41/forty_one_rules.dart';
import 'package:madar/features/cinema/rules/cards/tarneeb/tarneeb_state.dart' show sisterSuit;
import 'package:madar/features/cinema/rules/cards/tarneeb41/forty_one_state.dart';

import 'support.dart';

/// Seat 0 all hearts (the trumps), 1 all spades, 2 all diamonds, 3 all clubs.
List<List<PlayingCard>> heartsDeal() => [
  for (final s in [Suit.hearts, Suit.spades, Suit.diamonds, Suit.clubs])
    [for (final r in Rank.values) PlayingCard(s, r)],
];

/// [hand] for [seat] and the rest of the deck, in order, for the others.
List<List<PlayingCard>> dealWith(int seat, List<PlayingCard> hand) {
  final rest = cardsMinus(buildDeck(), hand);
  var k = 0;
  return [
    for (var i = 0; i < 4; i++)
      if (i == seat) hand else rest.sublist(13 * k, 13 * ++k),
  ];
}

FortyOneEngine engine({
  List<List<PlayingCard>>? hands,
  FortyOneOptions options = const FortyOneOptions(),
  List<int>? scores,
  int dealer = 3,
  int seed = 0,
  PlayingCard? exposedCard,
}) => FortyOneEngine(
  FortyOneState.withHands(
    hands ?? heartsDeal(),
    options: options,
    scores: scores,
    dealer: dealer,
    seed: seed,
    exposedCard: exposedCard,
  ),
);

/// Bids [bids] in order from the dealer's right (dealer 3: seats 0, 1, 2, 3).
List<CardEvent> bidAll(FortyOneEngine e, List<int> bids) => [for (final b in bids) ...e.apply(FortyOneMove.bid(b))];

/// Plays the highest legal card for everybody until the deal is scored.
List<CardEvent> playOut(FortyOneEngine e) {
  final round = e.state.roundNumber;
  final events = <CardEvent>[];
  while (e.state.roundNumber == round && !e.isOver) {
    events.addAll(e.apply(e.legalMoves(e.currentPlayer!).last));
  }
  return events;
}

Kit fortyOneKit(String name, FortyOneOptions o) =>
    Kit(name, (seed) => FortyOneEngine.newMatch(seed: seed, options: o), FortyOneEngine.fromJson, const FortyOneAi());

void main() {
  group('B1 players, deal and bidding', () {
    test('B1 four players, 13 cards each, partners opposite; scores are per player', () {
      final e = FortyOneEngine.newMatch(seed: 2);
      expect(e.state.hands.map((h) => h.length), [13, 13, 13, 13]);
      expect(sortedCards(e.state.cardsInPlay()), sortedCards(buildDeck()));
      expect([for (var i = 0; i < 4; i++) e.state.teamOf(i)], [0, 1, 0, 1]);
      expect(e.state.playerCount, 4);
      e.state.playerScores = [5, 6, 7, 8];
      expect(e.scores, [5, 6, 7, 8]);
    });

    test('B1 bidding starts at the dealer\'s right and ends with the dealer; one bid each, 2 to 13, no pass', () {
      final e = engine();
      expect(e.currentPlayer, 0);
      expect(e.legalMoves(0), [for (var b = 2; b <= 13; b++) FortyOneMove.bid(b)]);
      expect(e.validate(const FortyOneMove.bid(1)), 'bidTooLow');
      expect(e.validate(const FortyOneMove.bid(14)), 'bidTooHigh');
      e.apply(const FortyOneMove.bid(5));
      expect(e.currentPlayer, 1);
      // Bids need not rise.
      expect(e.legalMoves(1).first, const FortyOneMove.bid(2));
      e.apply(const FortyOneMove.bid(2));
      e.apply(const FortyOneMove.bid(2));
      expect(e.currentPlayer, 3);
      e.apply(const FortyOneMove.bid(2));
      expect(e.state.phase, FortyOnePhase.playing);
      expect(e.state.bids, [5, 2, 2, 2]);
    });

    test('B4.2 the total may exceed 13 (13 + 2 + 2 + 2 = 19)', () {
      final e = engine();
      bidAll(e, [13, 2, 2, 2]);
      expect(e.state.phase, FortyOnePhase.playing);
      expect(e.state.bidTotal, 19);
    });

    test('B4.1 bids adding up to less than 11 (2 + 2 + 2 + 4 = 10) → thrown in, no score, the next dealer deals', () {
      final e = engine(seed: 3);
      final events = bidAll(e, [2, 2, 2, 4]);
      final redeal = events.firstWhere((x) => x.type == CardEventType.redeal);
      expect(redeal.detail, 'lowTotal');
      expect(redeal.value, 10);
      expect(e.state.dealer, 0);
      expect(e.currentPlayer, 1);
      expect(e.state.dealNumber, 2);
      expect(e.state.roundNumber, 0);
      expect(e.state.playerScores, [0, 0, 0, 0]);
      expect(e.state.bids, [null, null, null, null]);
      expect(e.state.phase, FortyOnePhase.bidding);
      // Exactly 11 is enough.
      final f = engine();
      bidAll(f, [2, 2, 2, 5]);
      expect(f.state.phase, FortyOnePhase.playing);
    });

    test('`throwInRedeal: sameDealer` → the same dealer deals again', () {
      final e = engine(options: const FortyOneOptions(throwInRedeal: FortyOneThrowIn.sameDealer), seed: 3);
      bidAll(e, [2, 2, 2, 2]);
      expect(e.state.dealer, 3);
      expect(e.currentPlayer, 0);
      expect(e.state.dealNumber, 2);
    });

    test('B4.9 the dealer can always make the total up (others at their minimum, the dealer up to 13)', () {
      for (final o in [const FortyOneOptions(), const FortyOneOptions.lebanese400()]) {
        for (final scores in [
          [0, 0, 0, 0],
          [55, 60, 70, 80],
        ]) {
          final e = engine(options: o, scores: scores);
          for (var i = 0; i < 3; i++) {
            e.apply(e.legalMoves(e.currentPlayer!).first);
          }
          expect(e.state.bidTotal + 13, greaterThanOrEqualTo(e.state.minTotalNow));
          e.apply(e.legalMoves(3).last);
          expect(e.state.phase, FortyOnePhase.playing);
        }
      }
    });
  });

  group('B1 play', () {
    test(
      'B1 the first lead comes from the dealer\'s right; hearts are trumps; follow suit; tricks count per player',
      () {
        final e = engine();
        bidAll(e, [13, 2, 2, 2]);
        expect(e.state.trump, Suit.hearts);
        expect(e.currentPlayer, 0);
        e.apply(FortyOneMove.play(PlayingCard.parse('2H')));
        // Seat 1 has no heart: any card, and a spade cannot win.
        expect(e.legalMoves(1).length, 13);
        e.apply(FortyOneMove.play(PlayingCard.parse('AS')));
        e.apply(FortyOneMove.play(PlayingCard.parse('AD')));
        e.apply(FortyOneMove.play(PlayingCard.parse('AC')));
        expect(e.state.tricksWon, [1, 0, 0, 0]);
        expect(e.currentPlayer, 0); // the winner leads
      },
    );

    test('B1 follow suit if able, else any card (trumping never compulsory); the highest trump wins', () {
      final hands = [
        PlayingCard.list('AS KS QS JS TS 9S 8S 7S 6S 5S 4S 3S 2H'),
        PlayingCard.list('AH KH QH JH TH 9H 8H 7H 6H 5H 4H 3H 2S'),
        PlayingCard.list('AD KD QD JD TD 9D 8D 7D 6D 5D 4D 3D 2D'),
        PlayingCard.list('AC KC QC JC TC 9C 8C 7C 6C 5C 4C 3C 2C'),
      ];
      final e = engine(hands: hands);
      bidAll(e, [2, 2, 2, 5]);
      e.apply(FortyOneMove.play(PlayingCard.parse('AS')));
      expect(e.legalMoves(1), [FortyOneMove.play(PlayingCard.parse('2S'))]);
      expect(e.validate(FortyOneMove.play(PlayingCard.parse('AH'))), 'mustFollowSuit');
      e.apply(FortyOneMove.play(PlayingCard.parse('2S')));
      expect(e.legalMoves(2).length, 13);
      e.apply(FortyOneMove.play(PlayingCard.parse('2D')));
      e.apply(FortyOneMove.play(PlayingCard.parse('2C')));
      expect(e.state.tricksWon, [1, 0, 0, 0]);
      // Seat 0 leads its heart: seat 1 must follow with a heart and wins.
      e.apply(FortyOneMove.play(PlayingCard.parse('2H')));
      expect(e.legalMoves(1).every((m) => m.card!.suit == Suit.hearts), isTrue);
      e.apply(FortyOneMove.play(PlayingCard.parse('3H')));
      e.apply(e.legalMoves(2).first);
      e.apply(e.legalMoves(3).first);
      expect(e.state.tricksWon, [1, 1, 0, 0]);
    });

    test('`firstLead: highestBidder` → the highest bidder leads (the earliest on a tie)', () {
      const o = FortyOneOptions(firstLead: FortyOneFirstLead.highestBidder);
      final e = engine(options: o);
      bidAll(e, [3, 5, 5, 2]);
      expect(e.currentPlayer, 1);
      final f = engine(options: o);
      bidAll(f, [3, 2, 2, 6]);
      expect(f.currentPlayer, 3);
    });
  });

  group('B3 values and B1 scoring', () {
    test('`doubleFrom7` (default): 1–6 face value, 7+ doubled', () {
      const o = FortyOneOptions();
      expect([for (var b = 1; b <= 13; b++) o.value(b, 0)], [1, 2, 3, 4, 5, 6, 14, 16, 18, 20, 22, 24, 26]);
      expect(o.value(9, 45), 18); // the score does not matter
    });

    test('`levant400`: below 30 own points 2 3 4 10 12 14 16 27 40…; from 30 on 2 3 4 5 6 14 16 27 40…', () {
      const o = FortyOneOptions.lebanese400();
      expect([for (var b = 2; b <= 13; b++) o.value(b, 29)], [2, 3, 4, 10, 12, 14, 16, 27, 40, 40, 40, 40]);
      expect([for (var b = 2; b <= 13; b++) o.value(b, 30)], [2, 3, 4, 5, 6, 14, 16, 27, 40, 40, 40, 40]);
      expect([for (var b = 2; b <= 13; b++) o.value(b, -12)], [2, 3, 4, 10, 12, 14, 16, 27, 40, 40, 40, 40]);
      const x4 = FortyOneOptions(valueTable: FortyOneValueTable.levant400, levantTenPlus: FortyOneTenPlus.times4);
      expect([for (var b = 10; b <= 13; b++) x4.value(b, 0)], [40, 44, 48, 52]);
    });

    test('`faceValue`: a bid is worth its number', () {
      const o = FortyOneOptions(valueTable: FortyOneValueTable.faceValue);
      expect([for (var b = 1; b <= 13; b++) o.value(b, 0)], [for (var b = 1; b <= 13; b++) b]);
    });

    test(
      'B4.3 made → +value, overtricks worth nothing; failed → −value (bid 2 took 0 → −2; 7 took 9 → +14; 13 → +26)',
      () {
        const o = FortyOneOptions();
        expect(FortyOneRules.dealPoints(o, [2, 7, 13, 3], [0, 9, 0, 4], [0, 0, 0, 0]), [-2, 14, -26, 3]);
        expect(FortyOneRules.dealPoints(o, [13, 2, 2, 2], [13, 0, 0, 0], [0, 0, 0, 0]), [26, -2, -2, -2]);
      },
    );

    test('B4.4 `levant400` below 30: 5 made → +10, 9 made → +27, failed 9 → −27; at 34, 5 made → +5', () {
      const o = FortyOneOptions.lebanese400();
      expect(FortyOneRules.dealPoints(o, [5, 9, 9, 5], [5, 10, 8, 6], [0, 0, 29, 34]), [10, 27, -27, 5]);
    });

    test('a whole deal: seat 0 bids 13 in hearts and takes all 13; the others fail their 2s', () {
      final e = engine();
      bidAll(e, [13, 2, 2, 2]);
      final events = playOut(e);
      expect(e.state.lastResult!.tricks, [13, 0, 0, 0]);
      expect(e.state.lastResult!.made(0), isTrue);
      expect(e.state.playerScores, [26, -2, -2, -2]);
      expect(events.where((x) => x.type == CardEventType.roundScored).map((x) => x.value), [26, -2, -2, -2]);
      // The deal passes right.
      expect(e.state.dealer, 0);
      expect(e.currentPlayer, 1);
      expect(e.state.roundNumber, 1);
    });
  });

  group('B3 rising minimums (400)', () {
    test('B4.7 a player on 34 cannot bid 2; the table maximum 42 → the total must be at least 13', () {
      final s = FortyOneState.withHands(
        heartsDeal(),
        options: const FortyOneOptions.lebanese400(),
        scores: [34, 42, 12, -5],
      );
      expect([for (var i = 0; i < 4; i++) s.minBidFor(i)], [3, 4, 2, 2]);
      expect(s.minTotalNow, 13);
      final e = FortyOneEngine(s);
      expect(e.legalMoves(0).first, const FortyOneMove.bid(3));
      expect(e.validate(const FortyOneMove.bid(2)), 'bidTooLow');
      bidAll(e, [3, 4, 2, 3]);
      expect(e.state.phase, FortyOnePhase.bidding); // 12 < 13: thrown in
      expect(e.state.dealNumber, 2);
    });

    test('steps: own score < 30 → 2, 30–39 → 3, 40–49 → 4, 50+ → 5; total 11 / 12 / 13 / 14 by the highest score', () {
      const o = FortyOneOptions.lebanese400();
      for (final (score, bid, total) in [
        (29, 2, 11),
        (30, 3, 12),
        (39, 3, 12),
        (40, 4, 13),
        (49, 4, 13),
        (50, 5, 14),
        (90, 5, 14),
      ]) {
        final s = FortyOneState.withHands(heartsDeal(), options: o, scores: [score, 0, 0, 0]);
        expect(s.minBidFor(0), bid, reason: 'score $score');
        expect(s.minTotalNow, total, reason: 'score $score');
      }
      // Without the option the scores change nothing.
      final plain = FortyOneState.withHands(heartsDeal(), scores: [45, 0, 0, 0]);
      expect(plain.minBidFor(0), 2);
      expect(plain.minTotalNow, 11);
    });
  });

  group('B1 winning the match', () {
    const o = FortyOneOptions();
    test('B4.5 seat 0 on 45 with seat 2 on −3 → no win; seat 2 at +1 → team 0 wins', () {
      expect(FortyOneRules.matchWinner(o, [45, 10, -3, 12]), isNull);
      expect(FortyOneRules.matchWinner(o, [45, 10, 1, 12]), 0);
      expect(FortyOneRules.matchWinner(o, [10, 41, 12, 1]), 1);
    });

    test('B4.5 a partner on exactly 0: no win by default (`positive`), a win with `nonNegative`', () {
      expect(FortyOneRules.matchWinner(o, [45, 10, 0, 12]), isNull);
      const nn = FortyOneOptions(partnerRule: FortyOnePartnerRule.nonNegative);
      expect(FortyOneRules.matchWinner(nn, [45, 10, 0, 12]), 0);
    });

    test('B4.6 both teams qualify → the higher team total (default) or the higher single score', () {
      // 41 + 5 = 46 against 43 + 10 = 53: team 1 either way.
      expect(FortyOneRules.matchWinner(o, [41, 43, 5, 10]), 1);
      const ind = FortyOneOptions(bothQualify: FortyOneBothQualify.higherIndividual);
      expect(FortyOneRules.matchWinner(ind, [41, 43, 5, 10]), 1);
      // 50 + 1 = 51 against 41 + 20 = 61: the rules differ.
      expect(FortyOneRules.matchWinner(o, [50, 41, 1, 20]), 1);
      expect(FortyOneRules.matchWinner(ind, [50, 41, 1, 20]), 0);
      // Equal totals → the higher single score; everything equal → play on.
      expect(FortyOneRules.matchWinner(o, [50, 45, 1, 6]), 0);
      expect(FortyOneRules.matchWinner(o, [45, 45, 6, 6]), isNull);
    });

    test('a real deal ends the match: seat 0 on 30 makes 13 (+26 → 56) and seat 2 stays positive', () {
      final e = engine(scores: [30, 5, 5, 5]);
      bidAll(e, [13, 2, 2, 2]);
      final events = playOut(e);
      expect(e.isOver, isTrue);
      expect(e.state.playerScores, [56, 3, 3, 3]);
      expect(e.state.winners, [0, 2]);
      expect(e.currentPlayer, isNull);
      expect(events.last.type, CardEventType.matchOver);
      expect(events.last.detail, 'target');
    });

    test('a player at 41+ whose partner does not qualify keeps playing (and can drop back)', () {
      final e = engine(scores: [30, 5, 2, 5]);
      bidAll(e, [13, 2, 2, 2]);
      playOut(e);
      expect(e.state.playerScores, [56, 3, 0, 3]);
      expect(e.isOver, isFalse); // seat 2 is on 0
    });

    test('`bid13WinsMatch`: bidding 13 and making it wins at once (off by default)', () {
      final e = engine();
      bidAll(e, [13, 2, 2, 2]);
      playOut(e);
      expect(e.isOver, isFalse);
      final f = engine(options: const FortyOneOptions(bid13WinsMatch: true));
      bidAll(f, [13, 2, 2, 2]);
      final events = playOut(f);
      expect(f.isOver, isTrue);
      expect(f.state.winners, [0, 2]);
      expect(events.last.detail, 'bid13');
    });
  });

  group('presets', () {
    test('const FortyOneOptions() is the "41" game: hearts, 2–13, total 11, doubled from 7, 41 with partner > 0', () {
      const o = FortyOneOptions();
      expect(o, const FortyOneOptions.jordan());
      expect(o.trumpMode, FortyOneTrumpMode.heartsFixed);
      expect(o.minBid, 2);
      expect(o.minTotal, 11);
      expect(o.risingMinimums, isFalse);
      expect(o.valueTable, FortyOneValueTable.doubleFrom7);
      expect(o.target, 41);
      expect(o.partnerRule, FortyOnePartnerRule.positive);
      expect(o.bothQualify, FortyOneBothQualify.higherTeamTotal);
      expect(o.throwInRedeal, FortyOneThrowIn.nextDealer);
      expect(o.firstLead, FortyOneFirstLead.dealerRight);
      expect(o.bid13WinsMatch, isFalse);
      expect(o.firstDealer, 3);
      expect(
        const FortyOneOptions.lebanese400(),
        o.copyWith(risingMinimums: true, valueTable: FortyOneValueTable.levant400),
      );
      expect(const FortyOneOptions.syrian(), o.copyWith(trumpMode: FortyOneTrumpMode.exposedCardSisterSuit));
    });

    test('B4.8 Syrian 41: the exposed 7♠ makes clubs trumps and the dealer keeps the 7♠', () {
      final e = engine(
        options: const FortyOneOptions.syrian(),
        hands: heartsDeal(),
        dealer: 1,
        exposedCard: PlayingCard.parse('7S'),
      );
      expect(e.state.exposedCard, PlayingCard.parse('7S'));
      expect(e.state.trump, Suit.clubs);
      expect(e.state.hands[1], contains(PlayingCard.parse('7S')));
      for (var seed = 1; seed <= 20; seed++) {
        final s = FortyOneState.newMatch(seed: seed, options: const FortyOneOptions.syrian());
        expect(s.hands[s.dealer], contains(s.exposedCard));
        expect(s.trump, sisterSuit(s.exposedCard!.suit));
      }
      expect(FortyOneState.newMatch(seed: 1).exposedCard, isNull);
      expect(
        () => engine(options: const FortyOneOptions.syrian(), dealer: 1, exposedCard: PlayingCard.parse('7H')),
        throwsArgumentError,
      );
    });
  });

  group('serialisation', () {
    test('options JSON round trip (every field changed); missing keys take the defaults', () {
      const o = FortyOneOptions(
        trumpMode: FortyOneTrumpMode.exposedCardSisterSuit,
        minBid: 1,
        minTotal: 12,
        risingMinimums: true,
        valueTable: FortyOneValueTable.faceValue,
        levantTenPlus: FortyOneTenPlus.times4,
        target: 51,
        partnerRule: FortyOnePartnerRule.nonNegative,
        bothQualify: FortyOneBothQualify.higherIndividual,
        throwInRedeal: FortyOneThrowIn.sameDealer,
        firstLead: FortyOneFirstLead.highestBidder,
        bid13WinsMatch: true,
        firstDealer: 0,
      );
      expect(FortyOneOptions.fromJson(jsonDecode(jsonEncode(o.toJson())) as Map<String, Object?>), o);
      expect(FortyOneOptions.fromJson(const {}), const FortyOneOptions());
    });

    test('state and move JSON round trip mid-deal; the save is tagged `fortyOne`', () {
      final e = FortyOneEngine.newMatch(seed: 8, options: const FortyOneOptions.syrian());
      final rng = CardRng(2);
      for (var i = 0; i < 20; i++) {
        final p = e.currentPlayer!;
        final m = const FortyOneAi().chooseMove(e.state, p, AiLevel.medium, rng, AiBudget.phone);
        expect(FortyOneMove.fromJson(jsonDecode(jsonEncode(m.toJson())) as Map<String, Object?>), m);
        e.apply(m);
      }
      final json = jsonDecode(jsonEncode(e.toJson())) as Map<String, Object?>;
      expect(json['game'], 'fortyOne');
      final back = FortyOneEngine.fromJson(json);
      expect(jsonEncode(back.toJson()), jsonEncode(json));
      expect(back.state.exposedCard, e.state.exposedCard);
      // Until the registry gains `CardGameId.fortyOne` the family id is used.
      expect(e.state.gameId.name, anyOf('fortyOne', 'tarneeb'));
    });
  });

  group('AI', () {
    test('make chance falls as the bid rises and is about one half at the estimate', () {
      expect(fortyOneMakeChance(4, 3), greaterThan(fortyOneMakeChance(4, 4)));
      expect(fortyOneMakeChance(4, 5), lessThan(fortyOneMakeChance(4, 4)));
      expect(fortyOneMakeChance(4.5, 5), closeTo(0.5, 0.01));
      expect(fortyOneMakeChance(8, 2), greaterThan(0.99));
      expect(fortyOneMakeChance(1, 9), lessThan(0.01));
    });

    test('medium bids for the match: on −3 with a partner on 45 it bids enough to get above 0', () {
      const ai = FortyOneAi();
      // About 3.45 tricks: normally a safe 2 or 3.
      final hands = dealWith(0, PlayingCard.list('AH KH 5H 4H 2S 3S 4S 6S 2D 3D 4D 5D 2C'));
      final calm = FortyOneState.withHands(hands);
      expect(ai.chooseMove(calm, 0, AiLevel.medium, CardRng(1), AiBudget.phone).amount, lessThan(4));
      // Only a made 4 (+4 → 1 point) lets the partner's 45 win the match.
      final late = FortyOneState.withHands(hands, scores: [-3, 10, 45, 10]);
      expect(ai.chooseMove(late, 0, AiLevel.medium, CardRng(1), AiBudget.phone), const FortyOneMove.bid(4));
      // With 13 trumps the medium AI bids 13.
      expect(
        ai.chooseMove(FortyOneState.withHands(heartsDeal()), 0, AiLevel.medium, CardRng(1), AiBudget.phone),
        const FortyOneMove.bid(13),
      );
    });

    test('the medium dealer makes a close total up and lets a hopeless one be thrown in', () {
      const ai = FortyOneAi();
      // The dealer (seat 3) expects about 5.4 tricks and needs 5 after 2 + 2 + 2.
      final close = FortyOneEngine(
        FortyOneState.withHands(dealWith(3, PlayingCard.list('AH KH QH 5H AS KS 2S 4D 2D 3D 2C 3C 4C'))),
      );
      bidAll(close, [2, 2, 2]);
      final m = ai.chooseMove(close.state, 3, AiLevel.medium, CardRng(1), AiBudget.phone);
      expect(close.state.bidTotal + m.amount!, greaterThanOrEqualTo(11));
      // A dealer with no trump and no honour needs 5: it lets the deal go.
      final weak = FortyOneEngine(
        FortyOneState.withHands([
          PlayingCard.list('AH KH QH JH TH 9H AS KS QS AD KD QD AC'),
          PlayingCard.list('8H 7H 6H 5H JS TS 9S 8S JD TD 9D KC QC'),
          PlayingCard.list('4H 3H 2H 7S 6S 5S 8D 7D 6D JC TC 9C 8C'),
          PlayingCard.list('4S 3S 2S 5D 4D 3D 2D 7C 6C 5C 4C 3C 2C'),
        ]),
      );
      bidAll(weak, [2, 2, 2]);
      final dm = ai.chooseMove(weak.state, 3, AiLevel.medium, CardRng(1), AiBudget.phone);
      expect(weak.state.bidTotal + dm.amount!, lessThan(11));
    });

    test('determinised worlds keep voids and the Syrian exposed card with the dealer', () {
      const ai = FortyOneAi();
      final e = engine(options: const FortyOneOptions.syrian(), dealer: 1, exposedCard: PlayingCard.parse('7S'));
      // Dealer 1: seats 2, 3, 0, 1 bid.
      bidAll(e, [3, 3, 3, 3]);
      expect(e.currentPlayer, 2);
      // Diamonds are led; seats 3 and 0 show out.
      e.apply(FortyOneMove.play(PlayingCard.parse('2D')));
      e.apply(FortyOneMove.play(PlayingCard.parse('2C')));
      e.apply(FortyOneMove.play(PlayingCard.parse('2H')));
      for (var i = 0; i < 20; i++) {
        final w = ai.determinize(e.state, 1, CardRng(i));
        expect(w.hands[1], e.state.hands[1]);
        expect(w.hands[3].any((x) => x.suit == Suit.diamonds), isFalse);
        expect(w.hands[0].any((x) => x.suit == Suit.diamonds), isFalse);
        expect(sortedCards(w.cardsInPlay()), sortedCards(buildDeck()));
      }
      // Observer 2 does not hold the 7♠: every world leaves it with dealer 1.
      for (var i = 0; i < 20; i++) {
        expect(ai.determinize(e.state, 2, CardRng(i)).hands[1], contains(PlayingCard.parse('7S')));
      }
    });

    for (final (name, options) in [('41', const FortyOneOptions()), ('syrian 41', const FortyOneOptions.syrian())]) {
      test('$name: decisions depend only on what the seat can see (medium and hard)', () {
        const ai = FortyOneAi();
        final e = FortyOneEngine.newMatch(seed: 5, options: options);
        final rng = CardRng(1);
        var checked = 0;
        for (var move = 0; move < 240 && !e.isOver; move++) {
          final seat = e.currentPlayer!;
          if (move % 7 == 3) {
            final real = e.state;
            final other = ai.determinize(real, seat, CardRng(move));
            expect(sortedCards(other.cardsInPlay()), sortedCards(real.cardsInPlay()));
            for (final level in [AiLevel.medium, AiLevel.hard]) {
              final a = ai.chooseMove(real, seat, level, CardRng(9), const AiBudget.simulations(10));
              final b = ai.chooseMove(other, seat, level, CardRng(9), const AiBudget.simulations(10));
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
    final presets = <Kit>[
      fortyOneKit('41', const FortyOneOptions()),
      fortyOneKit('400 (lebanese)', const FortyOneOptions.lebanese400()),
      fortyOneKit('syrian 41', const FortyOneOptions.syrian()),
      fortyOneKit(
        'house rules',
        const FortyOneOptions(
          partnerRule: FortyOnePartnerRule.nonNegative,
          bothQualify: FortyOneBothQualify.higherIndividual,
          throwInRedeal: FortyOneThrowIn.sameDealer,
          firstLead: FortyOneFirstLead.highestBidder,
          bid13WinsMatch: true,
          valueTable: FortyOneValueTable.faceValue,
        ),
      ),
    ];
    for (final k in presets) {
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
      final k = presets[2];
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

  group('hard beats easy (both partners hard against two easy players)', () {
    for (final (name, options, matches) in [
      ('41', const FortyOneOptions(), 8),
      ('400 (lebanese)', const FortyOneOptions.lebanese400(), 6),
    ]) {
      test(name, () {
        final k = fortyOneKit(name, options);
        var wins = 0;
        var edge = 0;
        for (var m = 0; m < matches; m++) {
          final hardTeam = m % 2;
          final levels = [for (var s = 0; s < 4; s++) s % 2 == hardTeam ? AiLevel.hard : AiLevel.easy];
          final r = playMatch(k, 700 + m, levels, budget: const AiBudget.simulations(24));
          if (r.winners.contains(hardTeam)) wins++;
          edge += r.scores[hardTeam] + r.scores[hardTeam + 2] - r.scores[1 - hardTeam] - r.scores[3 - hardTeam];
        }
        // ignore: avoid_print
        print('41 $name: hard won $wins/$matches, average team edge ${(edge / matches).toStringAsFixed(1)}');
        expect(wins, greaterThan(matches / 2));
        expect(edge, greaterThan(0));
      });
    }
  });
}

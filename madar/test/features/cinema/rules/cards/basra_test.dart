// Basra (باصرة) as commonly played in Jordan: one test per rule of the
// final spec (IDs A…, E…), the presets and the options.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/cinema/rules/cards/cards.dart';

List<PlayingCard> c(String ids) => PlayingCard.list(ids);
PlayingCard p(String id) => PlayingCard.parse(id);

BasraCapture cap(String table, String card, [BasraOptions o = const BasraOptions()]) =>
    BasraRules.captureFor(c(table), p(card), o);

const egypt = BasraOptions.egyptian();
const pal = BasraOptions.palestinian44();

/// Plays [ids] in turn from a hand-built position.
BasraEngine playOut(BasraState s, List<String> ids) {
  final e = BasraEngine(s);
  for (final id in ids) {
    e.apply(BasraMove(p(id)));
  }
  return e;
}

void main() {
  group('presets and options (§3)', () {
    test('the default options are the Jordanian preset', () {
      expect(const BasraOptions(), const BasraOptions.jordan());
      const o = BasraOptions();
      expect(o.players, 4);
      expect(o.teams, isTrue);
      expect(o.deck, BasraDeck.full52);
      expect(o.cardsPerRound, 4);
      expect(o.basraValue, BasraValueRule.twiceCard);
      expect(o.faceCardBasraBase, 10);
      expect(o.jackBasraPoints, 0);
      expect(o.sevenDiamonds, BasraSevenDiamonds.sweep);
      expect(o.sevenDiamondsBasraMaxSum, 10);
      expect(o.basraOnLastCard, isFalse);
      expect(o.majorityPoints, 3);
      expect(o.majorityTie, BasraMajorityTie.none);
      expect(o.targetScore, 101);
      expect(o.preset, BasraPreset.jordan);
    });

    test('Palestinian 44: no Q/K, 7♦ ordinary, the rest Jordanian', () {
      expect(pal.deck, BasraDeck.short44);
      expect(pal.sevenDiamonds, BasraSevenDiamonds.normal);
      expect(pal.basraValue, BasraValueRule.twiceCard);
      expect(pal.majorityPoints, 3);
      expect(pal.preset, BasraPreset.palestinian44);
      expect(pal.buildPack().length, 44);
      expect(pal.buildPack().any((x) => x.rank == Rank.queen || x.rank == Rank.king), isFalse);
    });

    test('Egyptian: flat 10, jack on a lone jack 20, most cards 30 carried over', () {
      expect(egypt.basraValue, BasraValueRule.flat);
      expect(egypt.basraPoints, 10);
      expect(egypt.jackBasraPoints, 20);
      expect(egypt.majorityPoints, 30);
      expect(egypt.majorityTie, BasraMajorityTie.carryOver);
      expect(egypt.sevenDiamonds, BasraSevenDiamonds.sweep);
      expect(egypt.preset, BasraPreset.egyptian);
      expect(const BasraOptions(majorityPoints: 5).preset, BasraPreset.custom);
      // Presets keep their identity with another table size or target.
      expect(const BasraOptions.egyptian(players: 2, targetScore: 151).preset, BasraPreset.egyptian);
    });

    test('options and presets survive a JSON round trip', () {
      for (final o in [
        const BasraOptions(),
        pal,
        egypt,
        const BasraOptions(players: 3, targetScore: 121),
        const BasraOptions(players: 2, handSize: 6, basraOnLastCard: true),
      ]) {
        final back = BasraOptions.fromJson(jsonDecode(jsonEncode(o.toJson())) as Map<String, Object?>);
        expect(back, o);
        expect(back.preset, o.preset);
      }
    });

    test('a save from before the Jordanian defaults keeps its flat basra value', () {
      final old = <String, Object?>{
        'players': 4,
        'partnership': true,
        'targetScore': 101,
        'basraPoints': 10,
        'jackBasraPoints': 20,
        'sevenDiamonds': 'sweep',
        'sevenDiamondsBasraMaxSum': 10,
        'basraOnLastCard': false,
        'majorityPoints': 3,
      };
      final o = BasraOptions.fromJson(old);
      expect(o.basraValue, BasraValueRule.flat);
      expect(o.jackBasraPoints, 20);
      expect(o.deck, BasraDeck.full52);
      expect(o.majorityTie, BasraMajorityTie.none);
      final state = BasraState.newMatch(seed: 3).toJson()
        ..['options'] = old
        ..remove('majorityCarry');
      final restored = BasraState.fromJson(state);
      expect(restored.majorityCarry, 0);
      expect(restored.options.basraValue, BasraValueRule.flat);
    });

    test('configurations that cannot be dealt are refused with a stable id', () {
      expect(const BasraOptions(players: 3, deck: BasraDeck.short44).configError, 'shortDeckThreePlayers');
      expect(const BasraOptions(players: 3, handSize: 6).configError, 'handSize');
      expect(const BasraOptions(handSize: 5).configError, 'handSize');
      expect(const BasraOptions(players: 2, deck: BasraDeck.short44, handSize: 3).configError, 'handSize');
      expect(
        () => BasraState.newMatch(seed: 1, options: const BasraOptions.palestinian44(players: 3)),
        throwsArgumentError,
      );
      for (final ok in [
        const BasraOptions(),
        const BasraOptions(players: 2),
        const BasraOptions(players: 3),
        const BasraOptions(handSize: 6),
        const BasraOptions(players: 2, handSize: 6),
        pal,
        const BasraOptions.palestinian44(players: 2),
        const BasraOptions.palestinian44(players: 2).copyHand(5),
      ]) {
        expect(ok.configError, isNull, reason: ok.toJson().toString());
      }
    });
  });

  group('players and deal (A2, A3, §6.1)', () {
    test('A2.1 two, three or four players; four play as two partnerships', () {
      final four = BasraState.newMatch(seed: 1);
      expect(four.teamOf(0), four.teamOf(2));
      expect(four.teamOf(1), four.teamOf(3));
      expect(four.piles.length, 2);
      final individual = BasraState.newMatch(seed: 1, options: const BasraOptions(partnership: false));
      expect(individual.piles.length, 4);
      final three = BasraState.newMatch(seed: 1, options: const BasraOptions(players: 3));
      expect(three.hands.length, 3);
      expect(three.piles.length, 3);
      expect(three.scores.length, 3);
    });

    test('A2.2–A2.3 the dealer\'s right plays first; the deal then passes to the right', () {
      final e = BasraEngine.newMatch(seed: 4);
      expect(e.state.dealer, 3);
      expect(e.currentPlayer, 0);
      final rng = CardRng(1);
      while (e.state.dealNumber == 1) {
        e.apply(const BasraAi().chooseMove(e.state, e.currentPlayer!, AiLevel.easy, rng, AiBudget.phone));
      }
      expect(e.state.dealer, 0);
      expect(e.currentPlayer, 1);
    });

    test('A3.1–A3.2 52 cards: four face up on the table and four to each player', () {
      final e = BasraEngine.newMatch(seed: 8);
      expect(e.state.hands.every((h) => h.length == 4), isTrue);
      expect(e.state.table.length, 4);
      expect(e.state.stock.length, 52 - 4 - 16);
      final two = BasraEngine.newMatch(seed: 8, options: const BasraOptions(players: 2));
      expect(two.state.hands.length, 2);
      expect(two.state.stock.length, 52 - 4 - 8);
      expect(two.state.scores.length, 2);
    });

    test('A3.3–A3.4 no jack (nor the sweeping 7♦) starts on the table', () {
      var sevenSeen = false;
      for (var seed = 0; seed < 200; seed++) {
        final s = BasraState.newMatch(seed: seed);
        expect(s.table.any((x) => x.rank == Rank.jack || x == sevenOfDiamonds), isFalse, reason: 'seed $seed');
        // With an ordinary 7♦ only jacks are reburied.
        final n = BasraState.newMatch(
          seed: seed,
          options: const BasraOptions(sevenDiamonds: BasraSevenDiamonds.normal),
        );
        expect(n.table.any((x) => x.rank == Rank.jack), isFalse);
        sevenSeen |= n.table.contains(sevenOfDiamonds);
      }
      expect(sevenSeen, isTrue);
    });

    int rounds(BasraOptions o) {
      final e = BasraEngine.newMatch(seed: 2, options: o);
      final rng = CardRng(3);
      var deals = 1;
      final sizes = <int>{};
      while (e.state.dealNumber == 1) {
        if (e.state.hands.every((h) => h.length == o.cardsPerRound)) {
          sizes.add(e.state.stock.length);
        }
        e.apply(const BasraAi().chooseMove(e.state, e.currentPlayer!, AiLevel.easy, rng, AiBudget.phone));
      }
      deals += sizes.length - 1;
      return deals;
    }

    test('A3.5 / §6.1 whole rounds: 3 (4 players), 6 (2), 4 (3); no more cards to the table', () {
      expect(const BasraOptions().roundsPerDeal, 3);
      expect(const BasraOptions(players: 2).roundsPerDeal, 6);
      expect(const BasraOptions(players: 3).roundsPerDeal, 4);
      expect(const BasraOptions(handSize: 6).roundsPerDeal, 2);
      expect(const BasraOptions(players: 2, handSize: 6).roundsPerDeal, 4);
      expect(rounds(const BasraOptions()), 3);
      expect(rounds(const BasraOptions(players: 2)), 6);
      expect(rounds(const BasraOptions(players: 3)), 4);
    });

    test('§6.1 44 cards: 2 players get 4 cards × 5 rounds; 4 players 5 cards × 2 rounds; 3 refused', () {
      final two = BasraState.newMatch(seed: 5, options: const BasraOptions.palestinian44(players: 2));
      expect(two.hands.map((h) => h.length), [4, 4]);
      expect(two.stock.length, 44 - 4 - 8);
      expect(const BasraOptions.palestinian44(players: 2).roundsPerDeal, 5);
      expect(rounds(const BasraOptions.palestinian44(players: 2)), 5);
      final four = BasraState.newMatch(seed: 5, options: pal);
      expect(four.hands.every((h) => h.length == 5), isTrue);
      expect(four.stock.length, 44 - 4 - 20);
      expect(pal.roundsPerDeal, 2);
      expect(rounds(pal), 2);
      expect(const BasraOptions.palestinian44(players: 3).configError, 'shortDeckThreePlayers');
      expect(four.fullDeck().length, 44);
      expect(sortedCards(four.cardsInPlay()), sortedCards(pal.buildPack()));
    });
  });

  group('captures (A4, E1–E14)', () {
    test('A4.1 E1 a numeral takes equal ranks and groups adding up to it; K stays', () {
      final r = cap('2H 3C 5D KS', '5S');
      expect(sortedCards(r.cards), sortedCards(c('2H 3C 5D')));
      expect(r.basraPoints, 0);
    });

    test('A4.3 E2 groups are disjoint: 2 4 4 ← 6 takes one {2,4}', () {
      final r = cap('2H 4C 4D', '6S');
      expect(r.cards.length, 2);
      expect(r.cards, contains(p('2H')));
      expect(r.basraPoints, 0);
    });

    test('A4.3 E3 the family with the most cards: 4 5 6 3 2 ← 9 takes {4,5} {6,3}', () {
      final nine = cap('4H 5C 6D 3S 2H', '9S');
      expect(sortedCards(nine.cards), sortedCards(c('4H 5C 6D 3S')));
      expect(nine.basraPoints, 0);
      // Aces count 1.
      expect(sortedCards(cap('AH 2C KD', '3S').cards), sortedCards(c('AH 2C')));
    });

    test('A10.1 equal-size families: the one with more scoring cards is taken', () {
      // 5 ← {2♣,3♥} or {2♦,3♥}: the 3 can only be used once.
      for (final table in ['2C 3H 2D', '2D 3H 2C']) {
        final r = cap(table, '5S');
        expect(sortedCards(r.cards), sortedCards(c('2C 3H')), reason: table);
      }
      // 4 ← {A♥,3♣} or {2♦,2♥}… both fit: all four are taken.
      expect(cap('AH 3C 2D 2H', '4S').cards.length, 4);
      // 11 is no numeral: 10 ← {T♦} or {9,A}: both fit; with only one ace,
      // 10 ← {T♣} v {9♣,A♠}: the two-card family wins on size.
      expect(sortedCards(cap('TC 9C AS', 'TS').cards), sortedCards(c('TC 9C AS')));
      expect(sortedCards(cap('9C AS 8H 2H', 'TS').cards), sortedCards(c('9C AS 8H 2H')));
      // 6 ← {A♠,5♥} or {4♦,2♣}… plus a 6 on the table: max size, then points.
      expect(sortedCards(cap('AS 5H 3D 3C', '6S').cards).length, 4);
    });

    test('A4.2 a numeral never takes a Q, K or J', () {
      expect(cap('KD 3C', '3S').cards, c('3C'));
      expect(cap('QD JH', '5S').isCapture, isFalse);
    });

    test('A4.4 E4 queens and kings take only their own rank, every copy', () {
      expect(cap('KD 6H 7C', 'KS').cards, c('KD'));
      final r = cap('QD QH 5C', 'QS');
      expect(r.cards, c('QD QH'));
      expect(r.basraPoints, 0);
    });

    test('A4.5 E7 a jack sweeps the whole table, faces included, without a basra', () {
      final r = cap('JC 4D', 'JS');
      expect(r.cards.length, 2);
      expect(r.basraPoints, 0);
      expect(cap('KD 6H 7C', 'JS').cards.length, 3);
    });

    test('A4.5 E13 a jack or the 7♦ played to an empty table stays', () {
      expect(cap('', 'JS').isCapture, isFalse);
      expect(cap('', '7D').isCapture, isFalse);
    });

    test('A4.6 E8 the 7♦ sweeps; numerals adding up to ≤ 10 make a basra of 14', () {
      final r = cap('AH 2C 3S', '7D');
      expect(r.cards.length, 3);
      expect(r.basraPoints, 14);
      expect(cap('AH 2C 3S', '7D', egypt).basraPoints, 10);
    });

    test('A4.6 E9 the 7♦ on numerals adding up to more than 10: takes them, no basra', () {
      expect(cap('5H 6C', '7D').cards.length, 2);
      expect(cap('5H 6C', '7D').basraPoints, 0);
    });

    test('A4.6 E10 the 7♦ taking a face card: no basra', () {
      expect(cap('KH 2C', '7D').cards.length, 2);
      expect(cap('KH 2C', '7D').basraPoints, 0);
    });

    test('A4.6 E11 an ordinary 7♦ (option normal) captures like any seven: 3 + 4 → basra 14', () {
      const normal = BasraOptions(sevenDiamonds: BasraSevenDiamonds.normal);
      expect(cap('5H 6C', '7D', normal).isCapture, isFalse);
      final r = cap('3H 4C', '7D', normal);
      expect(r.cards.length, 2);
      expect(r.basraPoints, 14);
    });

    test('A4.7 a card that takes nothing stays on the table', () {
      expect(cap('KD QH', '5S').isCapture, isFalse);
      final e = playOut(BasraState.custom(hands: [c('5S 9H'), c('KH 9D'), c('2D 9S'), c('9C TS')], table: c('KD')), [
        '5S',
      ]);
      expect(e.state.table, c('KD 5S'));
    });

    test('A4.8 the captured cards and the capturing card go to the side pile (shared by partners)', () {
      final e = playOut(BasraState.custom(hands: [c('5S 9H'), c('KH 9D'), c('KD 9S'), c('9C TS')], table: c('5H KC')), [
        '5S',
        'KH',
      ]);
      expect(sortedCards(e.state.piles[0]), sortedCards(c('5H 5S')));
      expect(sortedCards(e.state.piles[1]), sortedCards(c('KC KH')));
      e.apply(BasraMove(p('9S'))); // seat 2 (partner of 0): nothing
      expect(e.state.lastCapturer, 1);
    });

    test('E12 a 7♦ left on the table is taken by a 7: basra 14', () {
      final e = playOut(BasraState.custom(hands: [c('7D 9H'), c('7C 9D'), c('KD 8S'), c('8C TS')], table: []), [
        '7D',
        '7C',
      ]);
      expect(e.state.basraScore, [0, 14]);
    });

    test('E14 rank and sum together clear the table: 4 6 10♦ ← 10 is a basra of 20', () {
      final r = cap('4H 6C TD', 'TS');
      expect(r.cards.length, 3);
      expect(r.basraPoints, 20);
    });
  });

  group('basra value (A5, §5.2)', () {
    test('A5.1 twice the capturing card: A 2 … 10 20, Q/K 20, 7♦ 14', () {
      final expected = {
        'A': 2,
        '2': 4,
        '3': 6,
        '4': 8,
        '5': 10,
        '6': 12,
        '7': 14,
        '8': 16,
        '9': 18,
        'T': 20,
        'Q': 20,
        'K': 20,
      };
      for (final e in expected.entries) {
        final card = p('${e.key}S');
        expect(BasraRules.basraValue(card, const BasraOptions()), e.value, reason: e.key);
        final lone = p('${e.key}H');
        expect(BasraRules.captureFor([lone], card, const BasraOptions()).basraPoints, e.value, reason: e.key);
        // Egyptian: a flat 10.
        expect(BasraRules.captureFor([lone], card, egypt).basraPoints, 10, reason: e.key);
      }
      expect(BasraRules.basraValue(sevenOfDiamonds, const BasraOptions()), 14);
      expect(BasraRules.basraValue(p('QS'), const BasraOptions(faceCardBasraBase: 12)), 24);
    });

    test('A5.1 E5 E15 a queen on queens is 20, an ace on a lone ace 2 (Egyptian 10 each)', () {
      expect(cap('QD QH', 'QS').basraPoints, 20);
      expect(cap('QD QH', 'QS', egypt).basraPoints, 10);
      expect(cap('AH', 'AS').basraPoints, 2);
      expect(cap('AH', 'AS', egypt).basraPoints, 10);
      // A numeral clearing a larger table by sums.
      final r = cap('7H 3C 4D 2S 5H', '7S');
      expect(sortedCards(r.cards), sortedCards(c('7H 3C 4D 2S 5H')));
      expect(r.basraPoints, 14);
    });

    test('A5.2–A5.3 E6 a jack on a lone jack: nothing in Jordan, 20 in Egypt; never doubled', () {
      expect(cap('JD', 'JS').isCapture, isTrue);
      expect(cap('JD', 'JS').basraPoints, 0);
      expect(cap('JD', 'JS', egypt).basraPoints, 20);
      expect(cap('JD', 'JS', const BasraOptions(jackBasraPoints: 30)).basraPoints, 30);
      expect(cap('JD 2C', 'JS', egypt).basraPoints, 0);
    });

    test('A5.4 the 7♦ basra follows the value rule: 14, or 10 flat', () {
      expect(cap('3H 4C', '7D').basraPoints, 14);
      expect(cap('3H 4C', '7D', egypt).basraPoints, 10);
    });

    test('A5.6–A5.7 a basra is scored at once, even on the very first play', () {
      final e = BasraEngine(BasraState.custom(hands: [c('5S 9H'), c('KH 9D'), c('2D 8S'), c('9C TS')], table: c('5H')));
      final events = e.apply(BasraMove(p('5S')));
      expect(e.state.basraScore, [10, 0]);
      expect(events.where((x) => x.type == CardEventType.basra).single.value, 10);
    });

    test('A5.5 E16 a basra with the very last card of the deal does not count (option)', () {
      for (final allowed in [false, true]) {
        final e = playOut(
          BasraState.custom(
            hands: [c('2S'), c('KH'), c('KD'), c('6C')],
            table: c('4H'),
            options: BasraOptions(basraOnLastCard: allowed),
          ),
          ['2S', 'KH', 'KD', '6C'], // 6 takes 4 + 2 with the last card
        );
        expect(e.state.results.single.basras, [0, allowed ? 12 : 0]);
      }
      // No basra at all: 5 takes 2 + 3 only.
      final e = playOut(BasraState.custom(hands: [c('2S'), c('KH'), c('3D'), c('5C')], table: c('4H')), [
        '2S',
        'KH',
        '3D',
        '5C',
      ]);
      expect(e.state.results.single.basras, [0, 0]);
    });
  });

  group('end of deal and scoring (A6, A7, §5)', () {
    test('A6.1 leftovers go to the side that captured last, never as a basra', () {
      final e = playOut(BasraState.custom(hands: [c('5S'), c('KH'), c('2D'), c('9C')], table: c('5H')), [
        '5S',
        'KH',
        '2D',
        '9C',
      ]);
      final r = e.state.results.single;
      expect(r.cardCounts, [5, 0]);
      // Basra 10 (a 5 on a lone 5) + most cards 3.
      expect(r.points, [13, 0]);
      expect(r.basras, [10, 0]);
    });

    test('A6.2 nobody captured: the table goes to the dealer\'s side', () {
      final e = playOut(BasraState.custom(hands: [c('5S'), c('KH'), c('2D'), c('9C')], table: c('3H'), dealer: 3), [
        '5S',
        'KH',
        '2D',
        '9C',
      ]);
      expect(e.state.results.single.cardCounts, [0, 5]);
    });

    test('A7 card points: each J and A 1, 2♣ 2, 10♦ 3, most cards 3 (16 a deal)', () {
      expect(BasraRules.cardPoints(p('JS')), 1);
      expect(BasraRules.cardPoints(p('AH')), 1);
      expect(BasraRules.cardPoints(p('2C')), 2);
      expect(BasraRules.cardPoints(p('2D')), 0);
      expect(BasraRules.cardPoints(p('TD')), 3);
      expect(BasraRules.cardPoints(p('TS')), 0);
      expect(buildDeck().fold<int>(0, (a, x) => a + BasraRules.cardPoints(x)) + 3, 16);
      final piles = [
        [...c('JS JH AS 2C TD'), for (var i = 0; i < 25; i++) p('3H')],
        c('AH AD AC JD JC'),
      ];
      expect(BasraRules.dealPoints(const BasraOptions(), piles, [10, 20]), [2 + 1 + 2 + 3 + 3 + 10, 5 + 20]);
    });

    test('A7.1 a tie for most cards: nobody scores the 3 (13 card points)', () {
      final s = BasraRules.scoreDeal(const BasraOptions(), [c('2H 3H'), c('4H 5H')], [0, 0]);
      expect(s.points, [0, 0]);
      expect(s.majoritySide, isNull);
      expect(s.carry, 0);
    });

    test('A7.1 carry-over (Egypt): the 30 adds up over two ties, then goes to a clear winner', () {
      final tie = [c('2H 3H'), c('4H 5H')];
      final first = BasraRules.scoreDeal(egypt, tie, [0, 0]);
      expect(first.points, [0, 0]);
      expect(first.carry, 30);
      final second = BasraRules.scoreDeal(egypt, tie, [0, 0], carry: first.carry);
      expect(second.carry, 60);
      final third = BasraRules.scoreDeal(egypt, [c('2H 3H 6H'), c('4H 5H')], [0, 0], carry: second.carry);
      expect(third.points, [90, 0]);
      expect(third.majoritySide, 0);
      expect(third.majorityAwarded, 90);
      expect(third.carry, 0);
      // Without the carry-over rule a carried amount is ignored.
      expect(BasraRules.scoreDeal(const BasraOptions(), [c('2H 3H 6H'), c('4H')], [0, 0], carry: 30).points, [3, 0]);
    });

    test('A7.1 a tie on cards is carried in the saved state into the next deal (Egypt only)', () {
      // 5S takes 5H, 9D takes 9H, 3S takes 3H, 7C takes 7H with the last
      // card: 4 cards each, no scoring card, no basra.
      BasraState tieDeal(BasraOptions o) =>
          BasraState.custom(hands: [c('5S'), c('9D'), c('3S'), c('7C')], table: c('5H 9H 3H 7H'), options: o);
      final jordan = playOut(tieDeal(const BasraOptions()), ['5S', '9D', '3S', '7C']);
      expect(jordan.state.results.single.cardCounts, [4, 4]);
      expect(jordan.state.results.single.points, [0, 0]);
      expect(jordan.state.majorityCarry, 0);

      final e = playOut(tieDeal(egypt), ['5S', '9D', '3S', '7C']);
      final first = e.state.results.single;
      expect(first.points, [0, 0]);
      expect(first.majoritySide, isNull);
      expect(first.carry, 30);
      expect(e.state.majorityCarry, 30);
      final saved = BasraEngine.fromJson(jsonDecode(jsonEncode(e.toJson())) as Map<String, Object?>);
      expect(saved.state.majorityCarry, 30);
      // Play the next (random) deal out: its most-cards points are 60, or
      // 90 carried on if it ties again.
      final rng = CardRng(4);
      while (saved.state.results.length < 2) {
        saved.apply(const BasraAi().chooseMove(saved.state, saved.currentPlayer!, AiLevel.easy, rng, AiBudget.phone));
      }
      final second = saved.state.results[1];
      if (second.majoritySide == null) {
        expect(second.carry, 60);
      } else {
        expect(second.majorityAwarded, 60);
        expect(saved.state.majorityCarry, 0);
      }
    });

    test('§5.4 a whole Jordanian deal: A 42, B 26 (16 card points)', () {
      // A: 28 cards with 3 jacks, 2 aces, the 2♣; basras 14 + 18.
      // B: 24 cards with 1 jack, 2 aces, the 10♦; basra 20.
      final a = [...c('JS JH JD AS AH 2C'), for (var i = 0; i < 22; i++) p('3H')];
      final b = [...c('JC AD AC TD'), for (var i = 0; i < 20; i++) p('4H')];
      final s = BasraRules.scoreDeal(const BasraOptions(), [a, b], [14 + 18, 20]);
      expect(s.points, [42, 26]);
      expect(s.majoritySide, 0);
    });

    test('three players: most cards is individual', () {
      final s = BasraRules.scoreDeal(const BasraOptions(players: 3), [c('2H 3H 4H'), c('5H'), c('6H 7H')], [0, 0, 0]);
      expect(s.points, [3, 0, 0]);
      expect(
        BasraRules.scoreDeal(const BasraOptions(players: 3), [c('2H 3H'), c('5H'), c('6H 7H')], [0, 0, 0]).points,
        [0, 0, 0],
      );
    });
  });

  group('match (A8)', () {
    test('A8.1–A8.2 the match ends at 101 for a side ahead', () {
      final s = BasraState.custom(hands: [c('5S'), c('KH'), c('2D'), c('9C')], table: c('5H'))..sideScores = [95, 50];
      final e = playOut(s, ['5S', 'KH', '2D', '9C']);
      expect(e.isOver, isTrue);
      expect(e.state.winners, [0, 2]);
      expect(e.currentPlayer, isNull);
    });

    test('A8.3 both over the target: the higher total wins', () {
      final s = BasraState.custom(hands: [c('5S'), c('KH'), c('2D'), c('9C')], table: c('5H'))..sideScores = [99, 110];
      final e = playOut(s, ['5S', 'KH', '2D', '9C']);
      // 99 + 13 = 112 > 110.
      expect(e.isOver, isTrue);
      expect(e.state.winners, [0, 2]);
    });

    test('A8.4 leaders equal at or above the target: another deal', () {
      final s = BasraState.custom(hands: [c('5S'), c('KH'), c('2D'), c('9C')], table: c('5H'))..sideScores = [90, 103];
      final e = playOut(s, ['5S', 'KH', '2D', '9C']);
      expect(e.state.sideScores, [103, 103]);
      expect(e.isOver, isFalse);
      expect(e.state.dealNumber, 2);
    });

    test('a custom target (151) is honoured', () {
      final s = BasraState.custom(
        hands: [c('5S'), c('KH'), c('2D'), c('9C')],
        table: c('5H'),
        options: const BasraOptions(targetScore: 151),
      )..sideScores = [120, 0];
      expect(playOut(s, ['5S', 'KH', '2D', '9C']).isOver, isFalse);
    });
  });

  group('serialisation', () {
    test('a mid-deal state survives JSON for every preset and table size', () {
      for (final o in [const BasraOptions(), pal, egypt, const BasraOptions(players: 3)]) {
        final e = BasraEngine.newMatch(seed: 11, options: o);
        final rng = CardRng(2);
        for (var i = 0; i < 9; i++) {
          e.apply(const BasraAi().chooseMove(e.state, e.currentPlayer!, AiLevel.medium, rng, AiBudget.phone));
        }
        e.state.majorityCarry = 30;
        final json = jsonDecode(jsonEncode(e.toJson())) as Map<String, Object?>;
        final back = BasraEngine.fromJson(json);
        expect(jsonEncode(back.toJson()), jsonEncode(json));
        expect(back.state.majorityCarry, 30);
        expect(back.state.options, o);
      }
    });

    test('deal results keep the most-cards side and the carried amount', () {
      const r = BasraDealResult([33, 0], [30, 22], [0, 0], majoritySide: 0, majorityAwarded: 30, carry: 0);
      final back = BasraDealResult.fromJson(jsonDecode(jsonEncode(r.toJson())) as Map<String, Object?>);
      expect(back.majoritySide, 0);
      expect(back.majorityAwarded, 30);
      final old = BasraDealResult.fromJson({
        'points': [3, 0],
        'cardCounts': [30, 22],
        'basras': [0, 0],
      });
      expect(old.majoritySide, isNull);
      expect(old.carry, 0);
    });
  });
}

extension on BasraOptions {
  /// The same options with an explicit hand size.
  BasraOptions copyHand(int n) => BasraOptions(
    players: players,
    partnership: partnership,
    deck: deck,
    handSize: n,
    targetScore: targetScore,
    basraValue: basraValue,
    faceCardBasraBase: faceCardBasraBase,
    basraPoints: basraPoints,
    jackBasraPoints: jackBasraPoints,
    sevenDiamonds: sevenDiamonds,
    sevenDiamondsBasraMaxSum: sevenDiamondsBasraMaxSum,
    basraOnLastCard: basraOnLastCard,
    majorityPoints: majorityPoints,
    majorityTie: majorityTie,
  );
}

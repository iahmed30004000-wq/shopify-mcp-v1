import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/cinema/rules/cards/cards.dart';

List<PlayingCard> c(String ids) => PlayingCard.list(ids);
PlayingCard p(String id) => PlayingCard.parse(id);

BasraCapture cap(String table, String card, [BasraOptions o = const BasraOptions()]) =>
    BasraRules.captureFor(c(table), p(card), o);

void main() {
  group('captures', () {
    test('numerals take equal ranks and every group adding up to their value', () {
      final r = cap('7H 3C 4D 2S 5H', '7S');
      expect(sortedCards(r.cards), sortedCards(c('7H 3C 4D 2S 5H')));
      expect(r.basraPoints, 10); // the table is cleared: basra
      // 9 on 4 5 6 3 2: {4,5} and {6,3}; the 2 stays.
      final nine = cap('4H 5C 6D 3S 2H', '9S');
      expect(sortedCards(nine.cards), sortedCards(c('4H 5C 6D 3S')));
      expect(nine.basraPoints, 0);
      // Aces count 1.
      expect(sortedCards(cap('AH 2C KD', '3S').cards), sortedCards(c('AH 2C')));
      // Nothing to take: the card stays.
      expect(cap('KD QH', '5S').isCapture, isFalse);
    });

    test('kings and queens only take their own rank', () {
      expect(cap('KD 6H 7C', 'KS').cards, c('KD'));
      expect(cap('QD QH 5C', 'QS').cards, c('QD QH'));
      expect(cap('QD', 'QS').basraPoints, 10);
      expect(cap('KD 3C', '3S').cards, c('3C')); // a numeral never takes a face
    });

    test('a jack sweeps (no basra), except a jack on a lone jack (20)', () {
      final r = cap('KD 6H 7C', 'JS');
      expect(r.cards.length, 3);
      expect(r.basraPoints, 0);
      expect(cap('JD', 'JS').basraPoints, 20);
      expect(cap('JD', 'JS', const BasraOptions(jackBasraPoints: 0)).basraPoints, 0);
      expect(cap('', 'JS').isCapture, isFalse);
    });

    test('the 7♦ sweeps; a basra when the table is numerals adding up to ≤ 10', () {
      expect(cap('AH 2C 3S', '7D').basraPoints, 10);
      expect(cap('5H 6C', '7D').basraPoints, 0);
      expect(cap('5H 6C', '7D').cards.length, 2);
      expect(cap('KH 2C', '7D').basraPoints, 0);
      const normal = BasraOptions(sevenDiamonds: BasraSevenDiamonds.normal);
      expect(cap('5H 6C', '7D', normal).isCapture, isFalse);
      expect(cap('3H 4C', '7D', normal).basraPoints, 10);
    });
  });

  group('play', () {
    test('captures go to the side pile; a basra made with the last card does not count', () {
      final s = BasraState.custom(hands: [c('5S'), c('KH'), c('2D'), c('9C')], table: c('5H'));
      final e = BasraEngine(s);
      e.apply(BasraMove(p('5S'))); // seat 0: basra
      expect(e.state.basraScore, [10, 0]);
      expect(e.state.piles[0], sortedCards(c('5H 5S')));
      e.apply(BasraMove(p('KH'))); // stays on the table
      e.apply(BasraMove(p('2D')));
      expect(e.state.table, c('KH 2D'));
      // Seat 3 plays the last card; nothing to take; the table goes to the
      // last capturer (seat 0) and the deal is scored.
      e.apply(BasraMove(p('9C')));
      final r = e.state.results.single;
      expect(r.cardCounts, [5, 0]);
      // Basra 10 + majority 3.
      expect(r.points, [13, 0]);
    });

    test('last-card basra option', () {
      for (final allowed in [false, true]) {
        final s = BasraState.custom(
          hands: [c('2S'), c('KH'), c('3D'), c('5C')],
          table: c('4H'),
          options: BasraOptions(basraOnLastCard: allowed),
        );
        final e = BasraEngine(s);
        e.apply(BasraMove(p('2S')));
        e.apply(BasraMove(p('KH')));
        e.apply(BasraMove(p('3D')));
        // Table 4H 2S KH 3D? No: 2 on 4 takes nothing, so the table is
        // 4H 2S KH 3D and 5C takes 2+3 only.
        e.apply(BasraMove(p('5C')));
        expect(e.state.results.single.basras, [0, 0]);
      }
      for (final allowed in [false, true]) {
        final s = BasraState.custom(
          hands: [c('2S'), c('KH'), c('KD'), c('6C')],
          table: c('4H'),
          options: BasraOptions(basraOnLastCard: allowed),
        );
        final e = BasraEngine(s);
        e.apply(BasraMove(p('2S')));
        e.apply(BasraMove(p('KH')));
        e.apply(BasraMove(p('KD'))); // takes KH
        e.apply(BasraMove(p('6C'))); // 4+2 = 6: clears the table with the last card
        expect(e.state.results.single.basras, [0, allowed ? 10 : 0]);
      }
    });

    test('four cards each per round; deals continue until the stock is empty', () {
      final e = BasraEngine.newMatch(seed: 8);
      expect(e.state.hands.every((h) => h.length == 4), isTrue);
      expect(e.state.table.length, 4);
      expect(e.state.stock.length, 52 - 4 - 16);
      final two = BasraEngine.newMatch(seed: 8, options: const BasraOptions(players: 2));
      expect(two.state.hands.length, 2);
      expect(two.state.stock.length, 52 - 4 - 8);
      expect(two.state.scores.length, 2);
    });

    test('no jack or 7♦ starts on the table', () {
      for (var seed = 0; seed < 200; seed++) {
        final s = BasraState.newMatch(seed: seed);
        expect(s.table.any((x) => x.rank == Rank.jack || x == sevenOfDiamonds), isFalse, reason: 'seed $seed');
      }
    });
  });

  test('deal points: jacks, aces, 2♣, 10♦, majority (none on a tie), basras', () {
    const o = BasraOptions();
    final piles = [
      [...c('JS JH AS 2C TD'), for (var i = 0; i < 25; i++) p('3H')],
      c('AH AD AC JD JC'),
    ];
    expect(BasraRules.dealPoints(o, piles, [10, 20]), [2 + 1 + 2 + 3 + 3 + 10, 5 + 20]);
    expect(BasraRules.dealPoints(o, [c('2H 3H'), c('4H 5H')], [0, 0]), [0, 0]);
  });

  test('the match ends at 101; a tie at the top plays on', () {
    final s = BasraState.custom(hands: [c('5S'), c('KH'), c('2D'), c('9C')], table: c('5H'));
    s.sideScores = [95, 50];
    final e = BasraEngine(s);
    for (final id in ['5S', 'KH', '2D', '9C']) {
      e.apply(BasraMove(p(id)));
    }
    expect(e.isOver, isTrue);
    expect(e.state.winners, [0, 2]);
  });
}

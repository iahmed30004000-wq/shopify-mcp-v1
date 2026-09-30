import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/cinema/rules/cards/cards.dart';

List<PlayingCard> c(String ids) => PlayingCard.list(ids);
PlayingCard p(String id) => PlayingCard.parse(id);
Meld m(String ids, [int owner = 1]) => Meld.arrange(c(ids), owner: owner)!;

const hand = RummyOptions.hand();

void main() {
  group('melds', () {
    test('runs and sets, ace low or high, never round the corner', () {
      expect((m('5H 6H 7H').kind, m('5H 6H 7H').value), (MeldKind.run, 18));
      expect((m('QS KS AS').low, m('QS KS AS').high, m('QS KS AS').value), (12, 14, 31));
      expect((m('AS 2S 3S').low, m('AS 2S 3S').value), (1, 6));
      expect(Meld.arrange(c('KS AS 2S')), isNull);
      expect((m('7H 7S 7D').kind, m('7H 7S 7D').value), (MeldKind.set, 21));
      expect(m('AH AS AD').value, 33);
      expect(Meld.arrange(c('7H 7H 7S')), isNull, reason: 'two 7♥ from the double pack');
      expect(Meld.arrange(c('7H 7S 7D 7C X0')), isNull);
      expect(Meld.arrange(c('5H 6S 7H')), isNull);
      expect(Meld.arrange(c('5H 6H')), isNull);
    });

    test('jokers fill gaps and ends; fewer jokers than natural cards', () {
      final gap = m('5H X0 7H');
      expect(gap.cards, c('5H X0 7H'));
      expect(gap.value, 18);
      expect(m('QS KS X0').high, 14);
      expect(m('QS KS X0').value, 31);
      expect(Meld.arrange(c('5H X0 X1')), isNull);
      expect(Meld.arrange(c('5H 6H X0 X1')), isNull);
      expect(m('5H 6H 7H X0 X1').cards.length, 5);
      expect(m('7H 7S X0').kind, MeldKind.set);
    });

    test('lay-offs and joker swaps', () {
      final run = m('5H 6H 7H');
      expect(run.withCard(p('8H'))!.high, 8);
      expect(run.withCard(p('4H'))!.low, 4);
      expect(run.withCard(p('9H')), isNull);
      expect(run.withCard(p('8S')), isNull);
      expect(m('QS KS AS').withCard(p('JS'))!.low, 11);
      expect(m('QS KS AS').withCard(p('2S')), isNull);
      expect(m('7H 7S 7D').withCard(p('7C'))!.cards.length, 4);
      expect(m('7H 7S 7D').withCard(p('7H')), isNull);
      expect(m('7H 7S 7D').withCard(PlayingCard.joker())!.jokers, 1);

      final (swapped, joker) = m('5H X0 7H').swapJoker(p('6H'))!;
      expect(swapped.cards, c('5H 6H 7H'));
      expect(joker, PlayingCard.joker());
      expect(m('5H X0 7H').swapJoker(p('6S')), isNull);
      expect(m('7H 7S X0').swapJoker(p('7D')), isNotNull);
      expect(m('7H 7S X0').swapJoker(p('7H')), isNull);
    });

    test('candidate melds and the best plan of a hand', () {
      final h = c('5H 6H 7H 8H 9C 9D 9S X0 2C KD');
      final cands = candidateMelds(h);
      expect(cands.any((x) => x.key == m('5H 6H 7H 8H').key), isTrue);
      expect(cands.any((x) => x.key == m('9C 9D 9S').key), isTrue);
      final plan = bestPlan(h, keep: 1);
      // 5-8♥ (26) + three 9s with the joker (36)... the best uses 8 of 10.
      expect(plan.value, greaterThanOrEqualTo(26 + 27));
      expect(plan.cardCount, lessThanOrEqualTo(h.length - 1));
    });
  });

  group('turn', () {
    RummyState state({
      required List<List<PlayingCard>> hands,
      List<PlayingCard> discardPile = const [],
      List<PlayingCard>? stock,
      List<Meld> table = const [],
      List<bool>? opened,
      RummyPhase phase = RummyPhase.play,
      RummyOptions options = hand,
    }) => RummyState.custom(
      options: options,
      hands: hands,
      stock: stock ?? c('2C 3C 4C 5C 6C 7C'),
      discardPile: discardPile,
      table: table,
      opened: opened,
      phase: phase,
    );

    test('the first player gets 15 cards and starts by discarding', () {
      final e = HandEngine.newMatch(seed: 3);
      expect(e.state.hands.map((h) => h.length), [15, 14, 14, 14]);
      expect(e.state.stock.length, 108 - 57);
      expect(e.state.phase, RummyPhase.play);
      final k = KonkanEngine.newMatch(seed: 3);
      expect(k.state.fullDeck().length, 106);
    });

    test('opening needs 51 and must leave a card to discard', () {
      final e = RummyEngine(state(hands: [c('QS KS AS 5H 6H 7H 8H 2C 3D 9C 4S'), c('2D'), c('3S'), c('4H')]));
      expect(e.validate(RummyMove.open([c('QS KS AS'), c('5H 6H 7H')])), 'openingBelowThreshold');
      expect(e.validate(RummyMove.open([c('QS KS AS'), c('5H 6H 8H')])), 'invalidMeld');
      expect(e.validate(RummyMove.meld(c('QS KS AS'))), 'notOpened');
      expect(e.validate(RummyMove.open([c('QS KS AS'), c('5H 6H 7H 8H')])), isNull);
      e.apply(RummyMove.open([c('QS KS AS'), c('5H 6H 7H 8H')]));
      expect(e.state.opened[0], isTrue);
      expect(e.state.table.length, 2);
      expect(e.state.hands[0], unorderedEquals(c('2C 9C 3D 4S')));
      final all = RummyEngine(state(hands: [c('QS KS AS 5H 6H 7H 8H'), c('2D'), c('3S'), c('4H')]));
      expect(all.validate(RummyMove.open([c('QS KS AS'), c('5H 6H 7H 8H')])), 'mustKeepOneCard');
    });

    test('the top discard can only be taken to be melded at once', () {
      final h0 = c('QS KS 5H 6H 7H 8H 2C 3D 9C 4S JD TD 3C 6C');
      final take = RummyEngine(
        state(hands: [h0, c('2D'), c('3S'), c('4H')], discardPile: c('2H AS'), phase: RummyPhase.draw),
      );
      expect(take.legalMoves(0), contains(const RummyMove.takeDiscard()));
      take.apply(const RummyMove.takeDiscard());
      expect(take.state.mustUse, p('AS'));
      expect(take.validate(RummyMove.discard(p('2C'))), 'mustUseTakenDiscard');
      expect(take.legalMoves(0).every((x) => x.kind == RummyMoveKind.open), isTrue);
      expect(take.validate(RummyMove.open([c('5H 6H 7H 8H'), c('3C 3D X0')])), isNotNull);
      take.apply(RummyMove.open([c('QS KS AS'), c('5H 6H 7H 8H')]));
      expect(take.state.mustUse, isNull);
      expect(take.validate(RummyMove.discard(p('2C'))), isNull);

      final refuse = RummyEngine(
        state(hands: [h0, c('2D'), c('3S'), c('4H')], discardPile: c('AS 2H'), phase: RummyPhase.draw),
      );
      expect(refuse.legalMoves(0), [const RummyMove.drawStock()]);
      expect(refuse.validate(const RummyMove.takeDiscard()), 'cannotUseDiscard');
    });

    test('lay-off and joker swap moves', () {
      final table = [m('5H X0 7H', 1), m('9C 9D 9S', 2)];
      final e = RummyEngine(
        state(hands: [c('6H 8H 9H 2C'), c('2D'), c('3S'), c('4H')], table: table, opened: [true, true, true, false]),
      );
      final legal = e.legalMoves(0);
      expect(legal, contains(RummyMove.swapJoker(p('6H'), 0)));
      expect(legal, contains(RummyMove.layoff(p('8H'), 0)));
      expect(legal, contains(RummyMove.layoff(p('9H'), 1)));
      e.apply(RummyMove.swapJoker(p('6H'), 0));
      expect(e.state.table[0].cards, c('5H 6H 7H'));
      expect(e.state.hands[0], contains(PlayingCard.joker()));
      e.apply(RummyMove.layoff(p('8H'), 0));
      expect(e.state.table[0].high, 8);
      final closed = RummyEngine(
        state(hands: [c('8H 2C'), c('2D'), c('3S'), c('4H')], table: table, opened: [false, true, true, false]),
      );
      expect(closed.validate(RummyMove.layoff(p('8H'), 0)), 'notOpened');
    });

    test('going out: −30 for the winner, cards left for the opened, 100 for the closed', () {
      final e = RummyEngine(
        state(
          hands: [c('9C'), c('KD 5C'), c('2D 3D'), c('X0 AS')],
          opened: [true, true, false, true],
        ),
      );
      e.apply(RummyMove.discard(p('9C')));
      final r = e.state.results.single;
      expect(r.winner, 0);
      expect(r.handFinish, isFalse);
      expect(r.points, [-30, 15, 100, 36]);
      expect(e.state.seatScores, [-30, 15, 100, 36]);
      expect(e.state.dealNumber, 2); // next round dealt
    });

    test('"hand": going out in one turn from a closed hand doubles the others', () {
      final e = RummyEngine(
        state(
          hands: [c('QS KS AS 5H 6H 7H 8H 9C'), c('KD 5C'), c('2D 3D'), c('X0 AS')],
          opened: [false, true, false, true],
        ),
      );
      e.apply(RummyMove.open([c('QS KS AS'), c('5H 6H 7H 8H')]));
      e.apply(RummyMove.discard(p('9C')));
      final r = e.state.results.single;
      expect(r.handFinish, isTrue);
      expect(r.points, [-60, 30, 200, 72]);
    });

    test('Konkan preset: no bonus for going out', () {
      final e = RummyEngine(
        state(
          hands: [c('9C'), c('KD 5C'), c('2D 3D'), c('X0 AS')],
          opened: [true, true, false, true],
          options: const RummyOptions.konkan(),
        ),
      );
      e.apply(RummyMove.discard(p('9C')));
      expect(e.state.results.single.points, [0, 15, 100, 36]);
    });

    test('an empty stock is refilled from the discards; then the round is abandoned', () {
      final e = RummyEngine(
        state(hands: [c('9C 8D'), c('2D'), c('3S'), c('4H')], stock: [], discardPile: c('2C 3D 4S'), phase: RummyPhase.draw),
      );
      e.apply(const RummyMove.drawStock());
      expect(e.state.recycles, 1);
      expect(e.state.discardPile, c('4S'));
      expect(e.state.stock.length, 1);
      expect(e.state.hands[0].length, 3);

      final s = state(hands: [c('9C 8D'), c('2D'), c('3S'), c('4H')], stock: [], discardPile: c('2C 3D 4S'), phase: RummyPhase.draw)
        ..recycles = 2;
      final f = RummyEngine(s);
      f.apply(const RummyMove.drawStock());
      expect(f.state.results.single.winner, isNull);
      expect(f.state.results.single.points, [0, 0, 0, 0]);
    });

    test('the match ends after the set number of rounds (Hand) or at the target (Konkan)', () {
      final s = state(hands: [c('9C'), c('KD 5C'), c('2D 3D'), c('X0 AS')], opened: [true, true, false, true]);
      s.results.addAll([
        for (var i = 0; i < 4; i++) const RummyRoundResult(winner: 1, handFinish: false, points: [0, 0, 0, 0]),
      ]);
      final e = RummyEngine(s);
      e.apply(RummyMove.discard(p('9C')));
      expect(e.isOver, isTrue);
      expect(e.state.winners, [0]);

      final k = state(
        hands: [c('9C'), c('KD 5C'), c('2D 3D'), c('X0 AS')],
        opened: [true, true, false, true],
        options: const RummyOptions.konkan(),
      )..seatScores = [0, 0, 450, 0];
      final ke = RummyEngine(k);
      ke.apply(RummyMove.discard(p('9C')));
      expect(ke.isOver, isTrue);
      expect(ke.state.winners, [0]);
    });
  });
}

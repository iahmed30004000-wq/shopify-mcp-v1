// Hand (هاند) as commonly played in Jordan: one test per rule and scoring
// line of the rules document (RULES.md, Hand), named after the rule, plus
// every option.
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/cinema/rules/cards/cards.dart';

List<PlayingCard> c(String ids) => PlayingCard.list(ids);
PlayingCard p(String id) => PlayingCard.parse(id);
const hand = RummyOptions.hand();
const rules = MeldRules();
Meld m(String ids, [int owner = 1]) => rules.arrange(c(ids), owner: owner)!;

RummyState st({
  RummyOptions options = hand,
  required List<String> hands,
  String stock = '2C 3C 4C 5C 6C 7C 8C 9C',
  String discard = '',
  List<Meld> table = const [],
  List<bool>? opened,
  int turn = 0,
  RummyPhase phase = RummyPhase.play,
  List<int>? turnsTaken,
  int dealer = 3,
}) => RummyState.custom(
  options: options,
  hands: [for (final h in hands) c(h)],
  stock: c(stock),
  discardPile: c(discard),
  table: table,
  opened: opened,
  turn: turn,
  phase: phase,
  turnsTaken: turnsTaken,
  dealer: dealer,
);

bool has(List<RummyMove> moves, RummyMoveKind kind) => moves.any((x) => x.kind == kind);

/// A closed 15-card hand that lays down 14 cards in four melds (98) and
/// discards the king of clubs.
const fullHand = 'QS KS AS 5H 6H 7H 8H 9C 9D 9S 2D 3D 4D 5D KC';
final fullMelds = [c('QS KS AS'), c('5H 6H 7H 8H'), c('9C 9D 9S'), c('2D 3D 4D 5D')];

void main() {
  group('deal and turn', () {
    test('C6/C7 deck: two packs and two jokers (106); 14 each, 15 for the starter; stock 77 / 63 / 49', () {
      for (final (n, left) in [(2, 77), (3, 63), (4, 49)]) {
        final s = RummyState.newMatch(options: RummyOptions.hand(players: n), seed: 3);
        expect(s.fullDeck().length, 106);
        expect(s.fullDeck().where((x) => x.isJoker).length, 2);
        expect(s.cardsInPlay().length, 106);
        expect(s.starter, 0, reason: 'the first dealer is the seat before seat 0');
        expect([for (var i = 0; i < n; i++) s.hands[i].length], [15, for (var i = 1; i < n; i++) 14]);
        expect(s.stock.length, left);
        expect(s.discardPile, isEmpty);
      }
    });

    test('C8 the starter\'s first turn is only a discard (no draw, no lay-down)', () {
      final e = RummyEngine(
        st(hands: ['TC JC QC 7H 7S 7D 2D 5S 8H 9C KD 3S 4H 6D QH', '2D', '3S', '4H'], turnsTaken: [0, 0, 0, 0]),
      );
      expect(e.state.starter, 0);
      expect(e.legalMoves(0).every((x) => x.kind == RummyMoveKind.discard), isTrue);
      expect(e.validate(RummyMove.open([c('TC JC QC'), c('7H 7S 7D')])), 'firstTurnDiscardOnly');
      expect(e.validate(const RummyMove.drawStock()), 'wrongPhase');
      e.apply(RummyMove.discard(p('KD')));
      expect((e.state.turn, e.state.phase, e.state.hands[0].length), (1, RummyPhase.draw, 14));
      // In a real deal as well.
      final real = HandEngine.newMatch(seed: 8);
      while (real.state.phase == RummyPhase.redealOffer) {
        real.apply(const RummyMove.keepHand());
      }
      expect(real.legalMoves(real.state.starter).every((x) => x.kind == RummyMoveKind.discard), isTrue);
    });

    test('G3 nobody goes out on their first turn: lay-downs leave two cards; the second turn may go out', () {
      final first = RummyEngine(st(hands: ['2C', fullHand, '3S', '4H'], turn: 1, turnsTaken: [1, 0, 0, 0]));
      expect(first.validate(RummyMove.open(fullMelds)), 'noGoOutOnFirstTurn');
      expect(first.validate(RummyMove.finish(melds: fullMelds, discard: p('KC'))), 'noGoOutOnFirstTurn');
      expect(has(first.legalMoves(1), RummyMoveKind.finish), isFalse);
      expect(first.validate(RummyMove.open(fullMelds.sublist(0, 3))), isNull);
      first.apply(RummyMove.open(fullMelds.sublist(0, 3)));
      expect(first.validate(RummyMove.meld(c('2D 3D 4D 5D'))), 'noGoOutOnFirstTurn');
      first.apply(RummyMove.meld(c('2D 3D 4D')));
      expect(first.validate(RummyMove.layoff(p('5D'), 3)), 'noGoOutOnFirstTurn');
      // Second turn: going out is allowed.
      final second = RummyEngine(st(hands: ['2C', fullHand, '3S', '4H'], turn: 1));
      expect(second.validate(RummyMove.open(fullMelds)), isNull);
      expect(has(second.legalMoves(1), RummyMoveKind.finish), isTrue);
    });

    test('T3 a discard always ends the turn; play goes to the next seat', () {
      final e = RummyEngine(st(hands: ['2C 5D 9S', '2D', '3S', '4H'], opened: [true, true, true, true]));
      e.apply(RummyMove.discard(p('9S')));
      expect((e.state.turn, e.state.phase, e.state.topDiscard), (1, RummyPhase.draw, p('9S')));
    });

    test('T6 any card may be discarded, a joker included', () {
      final e = RummyEngine(st(hands: ['X0 2C 5D', '2D', '3S', '4H'], opened: [true, true, true, true]));
      expect(e.validate(RummyMove.discard(PlayingCard.joker())), isNull);
    });
  });

  group('melds and opening', () {
    test('O1 opening needs 51: 50 is refused, 51 accepted', () {
      final e = RummyEngine(st(hands: ['TC JC QC 7H 7S 7D 5S 5H 5D 5C 2S 9D KH 8C', '2D', '3S', '4H']));
      expect(e.validate(RummyMove.open([c('TC JC QC'), c('5S 5H 5D 5C')])), 'openingBelowThreshold');
      expect(e.validate(RummyMove.open([c('TC JC QC'), c('7H 7S 7D')])), isNull);
      expect(e.validate(RummyMove.open([c('TC JC QC'), c('5S 5H 2S')])), 'invalidMeld');
      expect(e.validate(RummyMove.meld(c('TC JC QC'))), 'notOpened');
    });

    test('O4 opening values: the ace is 11 everywhere (A-2-3 = 16, Q-K-A = 31, A-A-A = 33)', () {
      final r = st(hands: ['2C', '2D', '3S', '4H']).meldRules;
      expect(r.arrange(c('AS 2S 3S'))!.value, 16);
      expect(r.arrange(c('QH KH AH'))!.value, 31);
      expect(r.arrange(c('AC AD AH'))!.value, 33);
      expect(MeldPlan([r.arrange(c('KC KD X0'))!, r.arrange(c('5S 6S 7S'))!]).value, 48);
      expect(MeldPlan([r.arrange(c('KC KD X0'))!, r.arrange(c('5S 6S 7S'))!, r.arrange(c('AS 2S 3S'))!]).value, 64);
    });

    test('O4 option aceLowOpeningValue 1: A-2-3 = 6; aceHighOpeningValue 10: Q-K-A = 30', () {
      final r = st(
        options: const RummyOptions(aceLowOpeningValue: 1, aceHighOpeningValue: 10),
        hands: ['2C', '2D', '3S', '4H'],
      ).meldRules;
      expect(r.arrange(c('AS 2S 3S'))!.value, 6);
      expect(r.arrange(c('QH KH AH'))!.value, 30);
    });

    test('M4 the second copy of a card may sit in another meld', () {
      final e = RummyEngine(st(hands: ['7H 7S 7D 5H 6H 7H 8H QS KS AS 2C', '2D', '3S', '4H']));
      expect(e.validate(RummyMove.open([c('7H 7S 7D'), c('5H 6H 7H 8H'), c('QS KS AS')])), isNull);
      final plan = bestPlan(c('7H 7S 7D 5H 6H 7H 2C'), rules, keep: 1);
      expect(plan.cardCount, 6);
    });

    test('J2 at most one wild per meld (two wilds refused, two naturals and a wild accepted)', () {
      final e = RummyEngine(st(hands: ['5H 7H 9H X0 X1 QS KS 9C 9D 9S 2C', '2D', '3S', '4H']));
      expect(e.validate(RummyMove.open([c('5H X0 7H X1 9H'), c('9C 9D 9S')])), 'invalidMeld');
      expect(e.validate(RummyMove.open([c('QS KS X0'), c('9C 9D 9S')])), isNull, reason: '31 + 27');
    });

    test('J4 the player places an end wild (5♥6♥🃏 = 18 or 15); it is then that card', () {
      final e = RummyEngine(
        st(hands: ['5H 6H X0 2C 9D', '8H 4H 3H 7H 2S', '3S', '4H'], opened: [true, true, false, false]),
      );
      final legal = e.legalMoves(0);
      expect(legal, contains(RummyMove.meld(c('5H 6H X0'))));
      expect(legal, contains(RummyMove.meld(c('5H 6H X0'), wildLow: true)));
      e.apply(RummyMove.meld(c('5H 6H X0')));
      expect((e.state.table.single.low, e.state.table.single.high, e.state.table.single.value), (5, 7, 18));
      e.apply(RummyMove.discard(p('2C')));
      e.apply(const RummyMove.drawStock());
      expect(e.validate(RummyMove.layoff(p('8H'), 0)), isNull);
      expect(e.validate(RummyMove.layoff(p('4H'), 0)), isNull);
      expect(e.validate(RummyMove.layoff(p('3H'), 0)), 'doesNotFit', reason: 'the wild is 7♥, not 4♥');
      expect(e.validate(RummyMove.swapJoker(p('4H'), 0)), 'noJokerForCard');
      expect(e.validate(RummyMove.swapJoker(p('7H'), 0)), isNull);
      // The other placement: 15.
      final low = RummyEngine(st(hands: ['5H 6H X0 2C 9D', '2D', '3S', '4H'], opened: [true, true, false, false]));
      low.apply(RummyMove.meld(c('5H 6H X0'), wildLow: true));
      expect((low.state.table.single.low, low.state.table.single.value), (4, 15));
    });

    test('O3/O6 only new melds count to 51; lay-offs and swaps are allowed right after opening', () {
      final table = [m('9D TD JD'), m('5S X0 7S')];
      final e = RummyEngine(
        st(hands: ['TC JC QC 7H 7C 7D QD 6S 2C', '2D', '3S', '4H'], table: table, opened: [false, true, false, false]),
      );
      expect(e.validate(RummyMove.layoff(p('QD'), 0)), 'notOpened');
      expect(e.validate(RummyMove.swapJoker(p('6S'), 1)), 'notOpened');
      e.apply(RummyMove.open([c('TC JC QC'), c('7H 7C 7D')]));
      expect(e.validate(RummyMove.layoff(p('QD'), 0)), isNull);
      expect(e.validate(RummyMove.swapJoker(p('6S'), 1)), isNull);
      e.apply(RummyMove.layoff(p('QD'), 0));
      e.apply(RummyMove.swapJoker(p('6S'), 1));
      expect(e.state.hands[0], c('2C X0'));
      expect(e.state.table[1].cards, c('5S 6S 7S'));
    });

    test('O7/L4 a card must be kept for the discard (last card, 2 cards + a drawn third)', () {
      final e = RummyEngine(
        st(hands: ['8H', '2D', '3S', '4H'], table: [m('5H 6H 7H')], opened: [true, true, true, true]),
      );
      expect(e.validate(RummyMove.layoff(p('8H'), 0)), 'mustKeepOneCard');
      final d = RummyEngine(
        st(hands: ['5C 6C', '2D', '3S', '4H'], stock: '7C', opened: [true, true, true, true], phase: RummyPhase.draw),
      );
      d.apply(const RummyMove.drawStock());
      expect(d.validate(RummyMove.meld(c('5C 6C 7C'))), 'mustKeepOneCard');
    });

    test('O8 option openingMustBeatPrevious: after 56 a 56 is refused and 57 accepted; a finish ignores it', () {
      const o = RummyOptions(openingMustBeatPrevious: true);
      final e = RummyEngine(
        st(options: o, hands: ['TC JC QC KC AS 2S 3S 9H 9S 9D 5D 8C', '2D', '3S', '4H'])..highestOpening = 56,
      );
      expect(e.validate(RummyMove.open([c('TC JC QC KC'), c('AS 2S 3S')])), 'openingMustBeatPrevious');
      expect(e.validate(RummyMove.open([c('TC JC QC'), c('9H 9S 9D')])), isNull);
      e.apply(RummyMove.open([c('TC JC QC'), c('9H 9S 9D')]));
      expect(e.state.highestOpening, 57);
      final f = RummyEngine(
        st(options: o, hands: ['2D 3D 4D 2H 3H 4H 2S 3S 4S 2C 3C 4C 5C 6C KD', '2D', '3S', '4H'])..highestOpening = 90,
      );
      expect(
        f.validate(
          RummyMove.finish(melds: [c('2D 3D 4D'), c('2H 3H 4H'), c('2S 3S 4S'), c('2C 3C 4C 5C 6C')], discard: p('KD')),
        ),
        isNull,
      );
    });

    test('O9 option openingRequiresRun: an opening of sets only is refused', () {
      final e = RummyEngine(
        st(
          options: const RummyOptions(openingRequiresRun: true),
          hands: ['KC KD KH 9C 9D 9S 7H 7S 7D 2C', '2D', '3S', '4H'],
        ),
      );
      expect(e.validate(RummyMove.open([c('KC KD KH'), c('9C 9D 9S')])), 'openingNeedsRun');
    });

    test('option openingMustUseDiscard (Konkan, Yemen): a closed player opens only with the taken discard', () {
      const o = RummyOptions.konkan(openingMustUseDiscard: true);
      final no = RummyEngine(st(options: o, hands: ['TC JC QC 7H 7S 7D 2C 9D', '2D', '3S', '4H']));
      expect(no.validate(RummyMove.open([c('TC JC QC'), c('7H 7S 7D')])), 'openingNeedsDiscard');
      final yes = RummyEngine(
        st(options: o, hands: ['TC JC 7H 7S 7D 2C 9D 4S', '2D', '3S', '4H'], discard: 'QC', phase: RummyPhase.draw),
      );
      yes.apply(const RummyMove.takeDiscard());
      expect(yes.validate(RummyMove.open([c('TC JC QC'), c('7H 7S 7D')])), isNull);
    });
  });

  group('the top discard', () {
    test('T4 it is offered only for a new meld with two hand cards (never a lay-off or a swap)', () {
      final layOnly = RummyEngine(
        st(
          hands: ['2D 5S 8H KD', '2C', '3S', '4H'],
          table: [m('9C TC JC'), m('5H X0 7H')],
          opened: [true, true, false, false],
          discard: 'QC',
          phase: RummyPhase.draw,
        ),
      );
      expect(layOnly.legalMoves(0), [const RummyMove.drawStock()]);
      expect(layOnly.validate(const RummyMove.takeDiscard()), 'cannotUseDiscard');
      final swapOnly = RummyEngine(
        st(
          hands: ['2D 5S 8S KD', '2C', '3S', '4H'],
          table: [m('5H X0 7H')],
          opened: [true, true, false, false],
          discard: '6H',
          phase: RummyPhase.draw,
        ),
      );
      expect(swapOnly.legalMoves(0), [const RummyMove.drawStock()]);
      final newMeld = RummyEngine(
        st(
          hands: ['QS QD 2C 5S', '2D', '3S', '4H'],
          opened: [true, true, false, false],
          discard: 'QH',
          phase: RummyPhase.draw,
        ),
      );
      expect(newMeld.legalMoves(0), contains(const RummyMove.takeDiscard()));
      newMeld.apply(const RummyMove.takeDiscard());
      expect(newMeld.state.mustUse, p('QH'));
      expect(newMeld.validate(RummyMove.discard(p('2C'))), 'mustUseTakenDiscard');
      expect(newMeld.legalMoves(0), [RummyMove.meld(c('QD QH QS'))]);
      newMeld.apply(RummyMove.meld(c('QD QH QS')));
      expect(newMeld.validate(RummyMove.discard(p('2C'))), isNull);
    });

    test('T4 before opening it must be part of a 51 opening made this turn', () {
      final h0 = 'QS KS 5H 6H 7H 8H 2C 3D 9C 4S JD TD 3C 6C';
      final take = RummyEngine(st(hands: [h0, '2D', '3S', '4H'], discard: '2H AS', phase: RummyPhase.draw));
      expect(take.legalMoves(0), contains(const RummyMove.takeDiscard()));
      take.apply(const RummyMove.takeDiscard());
      expect(take.legalMoves(0).every((x) => x.kind == RummyMoveKind.open), isTrue);
      expect(take.validate(RummyMove.open([c('5H 6H 7H 8H'), c('JD TD 9C')])), isNotNull);
      take.apply(RummyMove.open([c('QS KS AS'), c('5H 6H 7H 8H')]));
      expect(take.state.mustUse, isNull);
      final refuse = RummyEngine(st(hands: [h0, '2D', '3S', '4H'], discard: 'AS 2H', phase: RummyPhase.draw));
      expect(refuse.legalMoves(0), [const RummyMove.drawStock()]);
    });

    test('O10 a closed player may take it below 51 only to go out this turn', () {
      final finish = RummyEngine(
        st(
          hands: ['2D 3D 4D 2H 3H 4H 2S 3S 4S 2C 3C 5C 6C KD', '2D', '3S', '4H'],
          discard: '4C',
          phase: RummyPhase.draw,
        ),
      );
      expect(finish.legalMoves(0), contains(const RummyMove.takeDiscard()));
      finish.apply(const RummyMove.takeDiscard());
      final legal = finish.legalMoves(0);
      expect(legal.every((x) => x.kind == RummyMoveKind.finish), isTrue);
      final go = legal.first;
      expect(go.card, p('KD'));
      finish.apply(go);
      expect(finish.state.results.single.handFinish, isTrue);
      final stuck = RummyEngine(
        st(
          hands: ['2D 3D 4D 2H 3H 4H 2S 3S 4S 2C 3C 9C KD KH', '2D', '3S', '4H'],
          discard: '4C',
          phase: RummyPhase.draw,
        ),
      );
      expect(stuck.legalMoves(0), [const RummyMove.drawStock()]);
    });

    test('T4 option discardUse any: after opening it may be taken to lay off', () {
      final e = RummyEngine(
        st(
          options: const RummyOptions(discardUse: RummyDiscardUse.any),
          hands: ['2D 5S 8H KD', '2C', '3S', '4H'],
          table: [m('9C TC JC')],
          opened: [true, true, false, false],
          discard: 'QC',
          phase: RummyPhase.draw,
        ),
      );
      expect(e.legalMoves(0), contains(const RummyMove.takeDiscard()));
      e.apply(const RummyMove.takeDiscard());
      expect(e.validate(RummyMove.layoff(p('QC'), 0)), isNull);
      expect(e.validate(RummyMove.discard(p('2D'))), 'mustUseTakenDiscard');
    });
  });

  group('lay-offs and wild swaps', () {
    test('S2 set 8♣8♥🃏: one 8 is refused, both missing 8s swap the wild out', () {
      final e = RummyEngine(
        st(
          hands: ['8D 8S 2C 5H KD', '2D 3D', '3S 4S', '4H 5H'],
          table: [m('8C 8H X0')],
          opened: [true, true, true, true],
        ),
      );
      expect(e.validate(RummyMove.layoff(p('8D'), 0)), 'setNeedsBothSuits');
      expect(e.validate(RummyMove.swapJoker(p('8D'), 0)), 'setNeedsBothSuits');
      expect(e.legalMoves(0), isNot(contains(RummyMove.layoff(p('8D'), 0))));
      expect(e.legalMoves(0), contains(RummyMove.swapJoker(p('8D'), 0, card2: p('8S'))));
      e.apply(RummyMove.swapJoker(p('8S'), 0, card2: p('8D')));
      expect(e.state.table.single.cards, c('8C 8D 8H 8S'));
      expect(e.state.hands[0], unorderedEquals(c('2C 5H KD X0')));
      expect(e.state.known[0], [PlayingCard.joker()], reason: 'everyone saw the wild taken');
    });

    test('S2 a single natural on 8♣8♥🃏 only when about to go out or another player holds one card', () {
      final soon = RummyEngine(
        st(hands: ['8D 2C 5H', '2D 3D', '3S 4S', '4H 5H'], table: [m('8C 8H X0')], opened: [true, true, true, true]),
      );
      expect(soon.validate(RummyMove.layoff(p('8D'), 0)), isNull, reason: 'two cards left after it');
      final lastCard = RummyEngine(
        st(hands: ['8D 2C 5H KD', '2D 3D', '3S', '4H 5H'], table: [m('8C 8H X0')], opened: [true, true, true, true]),
      );
      expect(lastCard.validate(RummyMove.layoff(p('8D'), 0)), isNull, reason: 'seat 2 holds one card');
      lastCard.apply(RummyMove.layoff(p('8D'), 0));
      expect(lastCard.state.table.single.cards, c('8C 8D 8H X0'));
    });

    test('S2 … and when the player goes out this turn (a one-turn finish laying one 8 off)', () {
      final e = RummyEngine(
        st(
          hands: ['2D 3D 4D 2H 3H 4H 2S 3S 4S 5C 6C 7C 8D KD', 'KS 7D', '3S 4S', '4H 5H'],
          table: [m('8C 8H X0')],
          opened: [false, true, true, true],
        ),
      );
      final go = RummyMove.finish(
        melds: [c('2D 3D 4D'), c('2H 3H 4H'), c('2S 3S 4S'), c('5C 6C 7C')],
        layoffs: [RummyLayoff(p('8D'), 0)],
        discard: p('KD'),
      );
      expect(e.validate(go), isNull);
      expect(e.legalMoves(0).any((x) => x.kind == RummyMoveKind.finish && x.layoffs.isNotEmpty), isTrue);
      e.apply(go);
      expect(e.state.results.single.winner, 0);
    });

    test('S2 option setWildSwap anyMissingSuit: either missing suit frees the wild', () {
      final e = RummyEngine(
        st(
          options: const RummyOptions(setWildSwap: RummySetWildSwap.anyMissingSuit),
          hands: ['8D 8S 2C 5H KD', '2D 3D', '3S 4S', '4H 5H'],
          table: [m('8C 8H X0')],
          opened: [true, true, true, true],
        ),
      );
      expect(e.validate(RummyMove.layoff(p('8D'), 0)), isNull);
      expect(e.validate(RummyMove.swapJoker(p('8D'), 0)), isNull);
      e.apply(RummyMove.swapJoker(p('8D'), 0));
      expect(e.state.table.single.cards, c('8C 8D 8H'));
    });

    test('S2 set K♠K♥K♦🃏: K♣ frees the wild, a second K♠ does not', () {
      final e = RummyEngine(
        st(hands: ['KC KS 2C 5D', '2D', '3S', '4H'], table: [m('KS KH KD X0')], opened: [true, true, true, true]),
      );
      expect(e.validate(RummyMove.swapJoker(p('KS'), 0)), 'noJokerForCard');
      expect(e.validate(RummyMove.swapJoker(p('KC'), 0)), isNull);
    });

    test('S2 run 5♥🃏7♥: only 6♥ frees the wild', () {
      final e = RummyEngine(
        st(hands: ['6H 4H 8H 6S 2C', '2D', '3S', '4H'], table: [m('5H X0 7H')], opened: [true, true, true, true]),
      );
      expect(e.validate(RummyMove.swapJoker(p('4H'), 0)), 'noJokerForCard');
      expect(e.validate(RummyMove.swapJoker(p('8H'), 0)), 'noJokerForCard');
      expect(e.validate(RummyMove.swapJoker(p('6S'), 0)), 'noJokerForCard');
      expect(e.validate(RummyMove.swapJoker(p('6H'), 0)), isNull);
    });

    test('L3 a wild may be laid off only on a meld without one; the player picks the end', () {
      final e = RummyEngine(
        st(
          hands: ['X1 2C 5D 9S', '2D', '3S', '4H'],
          table: [m('5H 6H 7H'), m('9C X0 JC')],
          opened: [true, true, true, true],
        ),
      );
      expect(e.legalMoves(0), contains(RummyMove.layoff(PlayingCard.joker(1), 0)));
      expect(e.legalMoves(0), contains(RummyMove.layoff(PlayingCard.joker(1), 0, atLow: true)));
      expect(e.validate(RummyMove.layoff(PlayingCard.joker(1), 1)), 'doesNotFit');
      e.apply(RummyMove.layoff(PlayingCard.joker(1), 0, atLow: true));
      expect(e.state.table[0].low, 4);
    });

    test('L1/M5 an opened player may lay off on any meld, the partner\'s and opponents\' too', () {
      final e = RummyEngine(
        st(
          hands: ['8H 4S 2C', '2D', '3S', '4H'],
          table: [m('5H 6H 7H', 1), m('5S 6S 7S', 2)],
          opened: [true, true, true, false],
        ),
      );
      expect(e.validate(RummyMove.layoff(p('8H'), 0)), isNull);
      expect(e.validate(RummyMove.layoff(p('4S'), 1)), isNull);
    });

    test('S3 a freed wild may stay in hand (default)', () {
      final e = RummyEngine(
        st(hands: ['6H 2C 3D', '2D', '3S', '4H'], table: [m('5H X0 7H')], opened: [true, true, true, true]),
      );
      e.apply(RummyMove.swapJoker(p('6H'), 0));
      expect(e.validate(RummyMove.discard(p('2C'))), isNull);
    });

    test('S3 option swappedWildMustBeUsed: the discard waits until the freed wild is laid down', () {
      const o = RummyOptions(swappedWildMustBeUsed: true);
      final e = RummyEngine(
        st(
          options: o,
          hands: ['6H 2C 3D 4D 9S', '2D', '3S', '4H'],
          table: [m('5H X0 7H')],
          opened: [true, true, true, true],
        ),
      );
      e.apply(RummyMove.swapJoker(p('6H'), 0));
      expect(e.validate(RummyMove.discard(p('2C'))), 'mustUseFreedWild');
      e.apply(RummyMove.meld(c('3D 4D X0')));
      expect(e.validate(RummyMove.discard(p('2C'))), isNull);
      // A wild that cannot be laid down again is released (safety net).
      final stuck = RummyEngine(
        st(options: o, hands: ['KC 2C', '2D', '3S', '4H'], table: [m('KS KH KD X0')], opened: [true, true, true, true]),
      );
      stuck.apply(RummyMove.swapJoker(p('KC'), 0));
      expect(stuck.validate(RummyMove.discard(p('2C'))), isNull);
    });

    test('S5 a closed player may not swap; a swap never counts toward 51', () {
      final e = RummyEngine(
        st(hands: ['6H 2C 3D', '2D', '3S', '4H'], table: [m('5H X0 7H')], opened: [false, true, true, true]),
      );
      expect(e.validate(RummyMove.swapJoker(p('6H'), 0)), 'notOpened');
      expect(has(e.legalMoves(0), RummyMoveKind.swapJoker), isFalse);
    });
  });

  group('going out and scoring', () {
    RummyEngine outState({RummyOptions options = hand, String h0 = fullHand, List<Meld> table = const []}) =>
        RummyEngine(
          st(
            options: options,
            hands: [h0, 'KD 5C', '2D 3D', 'X1 AS'],
            table: table,
            opened: [false, true, false, true],
          ),
        );

    test('H3/H5/H6 going out after opening earlier: −30, cards left for the opened, 100 for the closed', () {
      final e = RummyEngine(st(hands: ['9C', 'KD 5C', '2D 3D', 'X0 AS'], opened: [true, true, false, true]));
      e.apply(RummyMove.discard(p('9C')));
      final r = e.state.results.single;
      expect((r.winner, r.handFinish, r.counted), (0, false, true));
      expect(r.points, [-30, 15, 100, 26]);
      expect(e.state.seatScores, [-30, 15, 100, 26]);
      expect(e.state.dealNumber, 2, reason: 'the next round is dealt at once');
    });

    test('H4 full hand (هاند): closed, one turn, own new melds only → −60, others ×2, closed 200', () {
      final e = outState();
      e.apply(RummyMove.open(fullMelds));
      final events = e.apply(RummyMove.discard(p('KC')));
      final r = e.state.results.single;
      expect(r.handFinish, isTrue);
      expect(r.points, [-60, 30, 200, 52]);
      expect(events.firstWhere((x) => x.type == CardEventType.roundScored).detail, 'hand');
      // The same in one finish move.
      final f = outState();
      f.apply(RummyMove.finish(melds: fullMelds, discard: p('KC')));
      expect(f.state.results.single.points, [-60, 30, 200, 52]);
    });

    test('G4 a one-turn finish that lays off on an older meld is a ضمون (−30, nobody doubled)', () {
      final e = outState(h0: 'QS KS AS 5H 6H 7H 8H 9C 9D 9S 2D 3D 4D QH KC', table: [m('9H TH JH')]);
      e.apply(RummyMove.open([c('QS KS AS'), c('5H 6H 7H 8H'), c('9C 9D 9S'), c('2D 3D 4D')]));
      e.apply(RummyMove.layoff(p('QH'), 0));
      e.apply(RummyMove.discard(p('KC')));
      final r = e.state.results.single;
      expect(r.handFinish, isFalse);
      expect(r.points, [-30, 15, 100, 26]);
      // Laying off on one's own new meld keeps it a full hand.
      final own = outState(h0: 'QS KS AS 5H 6H 7H 8H 9C 9D 9S 2D 3D 4D 5D KC');
      own.apply(RummyMove.open([c('QS KS AS'), c('5H 6H 7H 8H'), c('9C 9D 9S'), c('2D 3D 4D')]));
      own.apply(RummyMove.layoff(p('5D'), own.state.table.indexWhere((x) => x.cards.contains(p('2D')))));
      own.apply(RummyMove.discard(p('KC')));
      expect(own.state.results.single.handFinish, isTrue);
    });

    test('G4 … and so is one with a wild swapped from an older meld', () {
      final e = outState(h0: 'QS KS AS 5H 6H 7H 8H 9C 9D 9S 2D 3D 4D TH KC', table: [m('9H X0 JH')]);
      e.apply(RummyMove.open([c('QS KS AS'), c('5H 6H 7H 8H'), c('9C 9D 9S'), c('2D 3D 4D')]));
      e.apply(RummyMove.swapJoker(p('TH'), 0));
      e.apply(RummyMove.layoff(PlayingCard.joker(), 4));
      e.apply(RummyMove.discard(p('KC')));
      expect(e.state.results.single.handFinish, isFalse);
      expect(e.state.results.single.points[0], -30);
    });

    test('G4 option fullHandOwnMeldsOnly off: the lay-off finish is still a full hand', () {
      final e = outState(
        options: const RummyOptions(fullHandOwnMeldsOnly: false),
        h0: 'QS KS AS 5H 6H 7H 8H 9C 9D 9S 2D 3D 4D QH KC',
        table: [m('9H TH JH')],
      );
      e.apply(
        RummyMove.finish(
          melds: [c('QS KS AS'), c('5H 6H 7H 8H'), c('9C 9D 9S'), c('2D 3D 4D')],
          layoffs: [RummyLayoff(p('QH'), 0)],
          discard: p('KC'),
        ),
      );
      expect(e.state.results.single.handFinish, isTrue);
    });

    test('O10 a one-turn finish below 51 (47) is legal and is a full hand; an opening of 47 is not', () {
      final melds = [c('2D 3D 4D'), c('2H 3H 4H'), c('2S 3S 4S'), c('2C 3C 4C 5C 6C')];
      final e = outState(h0: '2D 3D 4D 2H 3H 4H 2S 3S 4S 2C 3C 4C 5C 6C KD');
      expect(e.validate(RummyMove.open(melds)), 'openingBelowThreshold');
      expect(e.legalMoves(0).any((x) => x.kind == RummyMoveKind.finish && x.card == p('KD')), isTrue);
      expect(e.validate(RummyMove.finish(melds: melds, discard: p('KD'))), isNull);
      expect(e.validate(RummyMove.finish(melds: melds.sublist(0, 3), discard: p('KD'))), 'notAFinish');
      e.apply(RummyMove.finish(melds: melds, discard: p('KD')));
      expect(e.state.results.single.handFinish, isTrue);
      expect(e.state.results.single.points[0], -60);
    });

    test('O10 option oneTurnFinishWaivesThreshold off: no finish below 51', () {
      final e = outState(
        options: const RummyOptions(oneTurnFinishWaivesThreshold: false),
        h0: '2D 3D 4D 2H 3H 4H 2S 3S 4S 2C 3C 4C 5C 6C KD',
      );
      expect(has(e.legalMoves(0), RummyMoveKind.finish), isFalse);
      expect(
        e.validate(
          RummyMove.finish(melds: [c('2D 3D 4D'), c('2H 3H 4H'), c('2S 3S 4S'), c('2C 3C 4C 5C 6C')], discard: p('KD')),
        ),
        'finishNotAllowed',
      );
    });

    test('a finish may end with lay-offs on table melds (a ضمون)', () {
      final e = outState(h0: '2D 3D 4D 2H 3H 4H 2S 3S 4S 2C 3C 4C QH KD', table: [m('9H TH JH')]);
      final finishes = e.legalMoves(0).where((x) => x.kind == RummyMoveKind.finish).toList();
      expect(finishes.any((x) => x.layoffs.length == 1 && x.layoffs.single.card == p('QH')), isTrue);
      e.apply(finishes.firstWhere((x) => x.layoffs.isNotEmpty));
      expect(e.state.results.single.handFinish, isFalse);
      expect(e.state.results.single.points[0], -30);
    });

    test('Pen. cards left: K♠ 7♦ 🃏 = 32, A♣ 3♥ = 14, never opened 100 (Konkan joker 25)', () {
      final s = st(hands: ['9C', 'KS 7D X0', 'AC 3H', '2D'], opened: [true, true, true, false]);
      expect((s.handPenalty(1), s.handPenalty(2)), (32, 14));
      final e = RummyEngine(s)..apply(RummyMove.discard(p('9C')));
      expect(e.state.results.single.points, [-30, 32, 14, 100]);
      final k = st(options: const RummyOptions.konkan(), hands: ['9C', 'KS 7D X0', 'AC 3H', '2D']);
      expect(k.handPenalty(1), 42);
      expect(st(options: const RummyOptions(acePenalty: 10), hands: ['AC', '2D', '2D', '2D']).handPenalty(0), 10);
    });

    test('bonus options: a wild as the last discard ×2 (−120, ×4, 400)', () {
      final e = RummyEngine(
        st(
          options: const RummyOptions(bonusWildLastDiscard: true),
          hands: ['QS KS AS 5H 6H 7H 8H 9C 9D 9S 2D 3D 4D 5D X0', 'KD 5C', '2D 3D', 'X1 AS'],
          opened: [false, true, false, true],
        ),
      );
      e.apply(RummyMove.finish(melds: fullMelds, discard: PlayingCard.joker()));
      final r = e.state.results.single;
      expect(r.multiplier, 2);
      expect(r.points, [-120, 60, 400, 104]);
    });

    test('bonus options: one colour ×2, one suit ×4 (−240, ×8, 800)', () {
      const both = RummyOptions(bonusOneColour: true, bonusOneSuit: true);
      final suit = RummyEngine(
        st(
          options: both,
          hands: ['AH 2H 3H 4H 5H 6H 7H 8H 9H TH JH QH KH AH 5H', 'KD 5C', '2D 3D', 'X1 AS'],
          opened: [false, true, false, true],
        ),
      );
      suit.apply(RummyMove.finish(melds: [c('AH 2H 3H 4H 5H 6H 7H'), c('8H 9H TH JH QH KH AH')], discard: p('5H')));
      expect(suit.state.results.single.points, [-240, 120, 800, 208]);
      final colour = RummyEngine(
        st(
          options: both,
          hands: ['AH 2H 3H 4H 5H 6H 7H 8D 9D TD JD QD KD AD 5D', 'KC 5C', '2S 3S', 'X1 AS'],
          opened: [false, true, false, true],
        ),
      );
      colour.apply(RummyMove.finish(melds: [c('AH 2H 3H 4H 5H 6H 7H'), c('8D 9D TD JD QD KD AD')], discard: p('5D')));
      expect(colour.state.results.single.multiplier, 2);
      expect(colour.state.results.single.points[0], -120);
    });
  });

  group('partnership', () {
    RummyState team({
      RummyOptions options = const RummyOptions.handPartnership(),
      String h0 = '9C',
      List<bool>? opened,
    }) => st(options: options, hands: [h0, 'KS 7D X0', 'AC 3H', '2D'], opened: opened ?? [true, true, true, false]);

    test('P6 the winner\'s partner is not counted; the other team pays both hands', () {
      final e = RummyEngine(team())..apply(RummyMove.discard(p('9C')));
      final r = e.state.results.single;
      expect(r.points, [-30, 132, -30, 132]);
      expect(r.seatPoints, [-30, 32, 0, 100]);
      expect(e.state.scores, [-30, 132, -30, 132]);
      expect(e.state.teamOf(2), 0);
    });

    test('P6 after a full hand: −60 and the other team doubled (400 if neither opened)', () {
      final e = RummyEngine(team(h0: fullHand, opened: [false, true, true, false]))
        ..apply(RummyMove.finish(melds: fullMelds, discard: p('KC')));
      expect(e.state.results.single.points, [-60, 264, -60, 264]);
      final none = RummyEngine(team(h0: fullHand, opened: [false, false, true, false]))
        ..apply(RummyMove.finish(melds: fullMelds, discard: p('KC')));
      expect(none.state.results.single.points[1], 400);
    });

    test('P7 option partnerOfWinnerPays: the partner\'s own cards go to the winning team', () {
      final e = RummyEngine(team(options: const RummyOptions(partnership: true, partnerOfWinnerPays: true)))
        ..apply(RummyMove.discard(p('9C')));
      expect(e.state.results.single.points, [-16, 132, -16, 132]);
    });

    test('P3 each partner opens for themselves; both partners win together', () {
      final e = RummyEngine(team(opened: [false, true, true, false])..table = [m('5H 6H 7H', 2)]);
      expect(e.validate(RummyMove.layoff(p('9C'), 0)), 'notOpened');
      final s = team()
        ..results.addAll([
          for (var i = 0; i < 4; i++) const RummyRoundResult(winner: 1, handFinish: false, points: [0, 0, 0, 0]),
        ]);
      final end = RummyEngine(s)..apply(RummyMove.discard(p('9C')));
      expect(end.isOver, isTrue);
      expect(end.state.winners, [0, 2]);
    });
  });

  group('dealer, empty stock and match', () {
    test('C3 loser deals: points [−30, 32, 14, 100] → seat 3 deals, seat 0 starts', () {
      final e = RummyEngine(st(hands: ['9C', 'KS 7D X0', 'AC 3H', '2D'], opened: [true, true, true, false], dealer: 1));
      e.apply(RummyMove.discard(p('9C')));
      expect((e.state.dealer, e.state.starter), (3, 0));
    });

    test('C3 loser deals: a tie for the most points keeps the dealer if tied, else the first tied after it', () {
      RummyEngine tie(int dealer) => RummyEngine(
        st(hands: ['9C', 'KS KD KH QS', 'TS TD TH TC', '2C'], opened: [true, true, true, true], dealer: dealer),
      )..apply(RummyMove.discard(p('9C')));
      expect(tie(2).state.dealer, 2);
      expect(tie(0).state.dealer, 1);
    });

    test('C3 option dealerRule rotate: the next seat deals', () {
      final e = RummyEngine(
        st(
          options: const RummyOptions(dealerRule: RummyDealerRule.rotate),
          hands: ['9C', 'KS 7D X0', 'AC 3H', '2D'],
          opened: [true, true, true, false],
          dealer: 1,
        ),
      )..apply(RummyMove.discard(p('9C')));
      expect(e.state.dealer, 2);
    });

    test('X1 an empty stock is refilled from the discards (the top discard stays)', () {
      final e = RummyEngine(
        st(hands: ['9C 8D', '2D', '3S', '4H'], stock: '', discard: '2C 3D 4S', phase: RummyPhase.draw),
      );
      final ev = e.apply(const RummyMove.drawStock());
      expect(e.state.recycles, 1);
      expect(e.state.discardPile, c('4S'));
      expect(e.state.stock.length, 1);
      expect(e.state.hands[0].length, 3);
      expect(ev.single.detail, 'restocked');
    });

    test('X2 after two reshuffles the round is void: not counted, same dealer, no points', () {
      final s = st(
        hands: ['9C 8D', '2D', '3S', '4H'],
        stock: '',
        discard: '2C 3D 4S',
        phase: RummyPhase.draw,
        dealer: 2,
      )..recycles = 2;
      final e = RummyEngine(s)..apply(const RummyMove.drawStock());
      final r = e.state.results.single;
      expect((r.winner, r.counted), (null, false));
      expect(r.points, [0, 0, 0, 0]);
      expect(e.state.roundsPlayed, 0);
      expect(e.state.dealer, 2);
      expect(e.state.voidStreak, 1);
    });

    test('X2 the third void in a row of a round number is skipped with 0 and counts', () {
      final s = st(hands: ['9C 8D', '2D', '3S', '4H'], stock: '', discard: '2C 3D 4S', phase: RummyPhase.draw)
        ..recycles = 2
        ..voidStreak = 2;
      final e = RummyEngine(s)..apply(const RummyMove.drawStock());
      expect(e.state.results.single.counted, isTrue);
      expect(e.state.roundsPlayed, 1);
      expect(e.state.voidStreak, 0);
    });

    test('X2 option voidRoundsCount: a void round counts', () {
      final s = st(
        options: const RummyOptions(voidRoundsCount: true),
        hands: ['9C 8D', '2D', '3S', '4H'],
        stock: '',
        discard: '2C 3D 4S',
        phase: RummyPhase.draw,
      )..recycles = 2;
      final e = RummyEngine(s)..apply(const RummyMove.drawStock());
      expect(e.state.roundsPlayed, 1);
    });

    test('X1 option stockEnd voidAtPlayers: void once the stock holds no more cards than players', () {
      final e = RummyEngine(
        st(
          options: const RummyOptions(stockEnd: RummyStockEnd.voidAtPlayers),
          hands: ['9C 8D', '2D', '3S', '4H'],
          stock: '2C 3C 4C 5C 6C',
          opened: [true, true, true, true],
          phase: RummyPhase.draw,
        ),
      );
      e.apply(const RummyMove.drawStock());
      expect(e.state.results, isEmpty);
      e.apply(RummyMove.discard(p('9C')));
      expect(e.state.results.single.winner, isNull);
    });

    test('X1 option stockEnd flipNoShuffle: the discards are turned over unshuffled, the top stays', () {
      final e = RummyEngine(
        st(
          options: const RummyOptions(stockEnd: RummyStockEnd.flipNoShuffle),
          hands: ['9C 8D', '2D', '3S', '4H'],
          stock: '',
          discard: '2C 3D 4S 5H',
          phase: RummyPhase.draw,
        )..recycles = 5,
      );
      e.apply(const RummyMove.drawStock());
      expect(e.state.hands[0], contains(p('2C')), reason: 'the bottom discard is drawn first');
      expect(e.state.stock, c('4S 3D'));
      expect(e.state.discardPile, c('5H'));
    });

    test('H7 the match is 5 scored rounds (void rounds do not count); lowest total wins', () {
      final s = st(hands: ['9C', 'KD 5C', '2D 3D', 'X0 AS'], opened: [true, true, false, true]);
      s.results.addAll([
        for (var i = 0; i < 4; i++) const RummyRoundResult(winner: 1, handFinish: false, points: [0, 0, 0, 0]),
        const RummyRoundResult(winner: null, handFinish: false, points: [0, 0, 0, 0], counted: false),
      ]);
      final e = RummyEngine(s)..apply(RummyMove.discard(p('9C')));
      expect(e.isOver, isTrue);
      expect(e.state.roundsPlayed, 5);
      expect(e.state.winners, [0]);
      expect(e.state.currentPlayer, isNull);
    });

    test('H7 option rounds 7', () {
      final s = st(
        options: const RummyOptions(rounds: 7),
        hands: ['9C', 'KD 5C', '2D 3D', 'X0 AS'],
        opened: [true, true, false, true],
      );
      s.results.addAll([
        for (var i = 0; i < 5; i++) const RummyRoundResult(winner: 1, handFinish: false, points: [0, 0, 0, 0]),
      ]);
      final e = RummyEngine(s)..apply(RummyMove.discard(p('9C')));
      expect(e.isOver, isFalse);
    });

    test('H8 a tie for lowest: extra rounds (at most 3), then shared', () {
      // The last round scores [−30, 15, 100, 26].
      RummyState tied() =>
          st(hands: ['9C', 'KD 5C', '2D 3D', 'X0 AS'], opened: [true, true, false, true])
            ..results.addAll([
              for (var i = 0; i < 4; i++) const RummyRoundResult(winner: 1, handFinish: false, points: [0, 0, 0, 0]),
            ]);
      final s = tied()..seatScores = [100, 0, -85, -26];
      final e = RummyEngine(s)..apply(RummyMove.discard(p('9C')));
      // Totals: 70, 15, 15, 0 → seat 3 alone lowest: over.
      expect(e.isOver, isTrue);
      final t = tied()..seatScores = [100, 0, -85, -11];
      final extra = RummyEngine(t)..apply(RummyMove.discard(p('9C')));
      // Totals 70, 15, 15, 15: seats 1, 2, 3 tie → an extra round.
      expect(extra.isOver, isFalse);
      expect(extra.state.tieBreakRounds, 1);
      final last = tied()
        ..seatScores = [100, 0, -85, -11]
        ..tieBreakRounds = 3;
      final shared = RummyEngine(last)..apply(RummyMove.discard(p('9C')));
      expect(shared.isOver, isTrue);
      expect(shared.state.winners, [1, 2, 3]);
    });

    test('H8 option tieBreak shared', () {
      final t =
          st(
              options: const RummyOptions(tieBreak: RummyTieBreak.shared),
              hands: ['9C', 'KD 5C', '2D 3D', 'X0 AS'],
              opened: [true, true, false, true],
            )
            ..seatScores = [100, 0, -85, -11]
            ..results.addAll([
              for (var i = 0; i < 4; i++) const RummyRoundResult(winner: 1, handFinish: false, points: [0, 0, 0, 0]),
            ]);
      final e = RummyEngine(t)..apply(RummyMove.discard(p('9C')));
      expect(e.isOver, isTrue);
      expect(e.state.winners, [1, 2, 3]);
    });

    test('H9 option matchEnd targetScore: over in the round someone reaches it; negative totals are fine', () {
      final s = st(
        options: const RummyOptions(matchEnd: RummyMatchEnd.targetScore, targetScore: 200),
        hands: ['9C', 'KD 5C', '2D 3D', 'X0 AS'],
        opened: [true, true, false, true],
      )..seatScores = [-50, 0, 120, 0];
      final e = RummyEngine(s)..apply(RummyMove.discard(p('9C')));
      expect(e.isOver, isTrue);
      expect(e.state.seatScores, [-80, 15, 220, 26]);
      expect(e.state.winners, [0]);
    });
  });

  group('pairs redeal', () {
    test('2.10 four identical pairs (or three and a joker, two and both jokers) may cancel the deal', () {
      RummyState s(String h) => st(hands: [h, '2D', '3S', '4H']);
      expect(s('7H 7H KS KS 2C 2C 9D 9D 4S 5S 6S 8C JC').canCallRedeal(0), isTrue);
      expect(s('7H 7H KS KS 2C 2C X0 4S 5S 6S 8C JC TD').canCallRedeal(0), isTrue);
      expect(s('7H 7H KS KS X0 X1 4S 5S 6S 8C JC TD QH').canCallRedeal(0), isTrue);
      expect(s('7H 7H KS KS 2C 2C 9D 4S 5S 6S 8C JC TD').canCallRedeal(0), isFalse);
      expect(
        st(
          options: const RummyOptions(pairsRedeal: false),
          hands: ['7H 7H KS KS 2C 2C 9D 9D', '2D', '3S', '4H'],
        ).redealCandidate(after: null),
        isNull,
      );
    });

    test('2.10 the offer comes before the starter\'s discard; redealing does not count, same dealer', () {
      RummyEngine? found;
      for (var seed = 1; seed < 400 && found == null; seed++) {
        final e = HandEngine.newMatch(seed: seed);
        if (e.state.phase == RummyPhase.redealOffer) found = e;
      }
      expect(found, isNotNull);
      final e = found!;
      final seat = e.currentPlayer!;
      expect(e.state.canCallRedeal(seat), isTrue);
      expect(e.legalMoves(seat), [const RummyMove.callRedeal(), const RummyMove.keepHand()]);
      final keep = RummyEngine(e.state.copy())..apply(const RummyMove.keepHand());
      expect(keep.state.phase == RummyPhase.play || keep.state.phase == RummyPhase.redealOffer, isTrue);
      final deal = e.state.dealNumber;
      final dealer = e.state.dealer;
      final ev = e.apply(const RummyMove.callRedeal());
      expect(ev.first.type, CardEventType.redeal);
      expect(e.state.dealNumber, deal + 1);
      expect((e.state.dealer, e.state.results.length), (dealer, 0));
    });
  });

  group('indicator card (ورقة الكشف), option wildIndicator', () {
    test('§6 a face-up indicator (never a joker) beside the stock; stock one card smaller', () {
      for (var seed = 1; seed <= 20; seed++) {
        final s = RummyState.newMatch(options: const RummyOptions.handIndicator(), seed: seed);
        expect(s.indicator, isNotNull);
        expect(s.indicator!.isJoker, isFalse);
        expect(s.stock.length, 48);
        expect(s.cardsInPlay().length, 106);
      }
    });

    test('§6 a non-ace indicator makes its suit\'s aces wild and the jokers natural aces; values', () {
      final s = st(options: const RummyOptions.handIndicator(), hands: ['AH X0 5S', '2D', '3S', '4H'])
        ..indicator = p('7H');
      final r = s.meldRules;
      expect((r.isWild(p('AH')), r.isWild(PlayingCard.joker()), r.isWild(p('AS'))), (true, false, false));
      expect(s.handPenalty(0), 15 + 11 + 5);
      final ace = st(options: const RummyOptions.handIndicator(), hands: ['AH X0', '2D', '3S', '4H'])
        ..indicator = p('AC');
      expect((ace.meldRules.isWild(p('AH')), ace.meldRules.isWild(PlayingCard.joker())), (false, true));
    });

    test('§6 a wild ace taken from the discard pile may only be the ace of its own suit', () {
      final s = st(
        options: const RummyOptions.handIndicator(),
        hands: ['5S 6S 2H 3H 9C', '2D', '3S', '4H'],
        opened: [true, true, true, true],
        discard: 'AH',
        phase: RummyPhase.draw,
      )..indicator = p('7H');
      final e = RummyEngine(s)..apply(const RummyMove.takeDiscard());
      expect(e.validate(RummyMove.meld(c('5S 6S AH'))), 'mustUseTakenDiscard');
      expect(e.validate(RummyMove.meld(c('AH 2H 3H'))), 'mustUseTakenDiscard', reason: 'there A♥ would be 4♥');
      expect(e.validate(RummyMove.meld(c('AH 2H 3H'), wildLow: true)), isNull);
    });
  });
}

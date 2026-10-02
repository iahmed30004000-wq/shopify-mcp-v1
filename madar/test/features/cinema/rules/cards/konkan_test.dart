// Konkan (كونكان): one test per rule and scoring line of the rules
// document (RULES.md, Konkan): the shared Hand core, scoring (nothing for
// going out, a one-turn finish doubles the others, joker 25), and the match
// by elimination over 301, with its options.
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/cinema/rules/cards/cards.dart';

List<PlayingCard> c(String ids) => PlayingCard.list(ids);
PlayingCard p(String id) => PlayingCard.parse(id);
const konkan = RummyOptions.konkan();

RummyState st({
  RummyOptions options = konkan,
  required List<String> hands,
  List<bool>? opened,
  List<int>? scores,
  List<bool>? eliminated,
  int turn = 0,
  int dealer = 3,
}) {
  final s = RummyState.custom(
    options: options,
    hands: [for (final h in hands) c(h)],
    stock: c('2C 3C 4C 5C 6C 7C 8C 9C'),
    opened: opened,
    turn: turn,
    phase: RummyPhase.play,
    dealer: dealer,
    eliminated: eliminated,
  );
  if (scores != null) s.seatScores = List.of(scores);
  return s;
}

void main() {
  group('the Hand core', () {
    test('K1 106 cards (two jokers), 14 each and 15 for the starter', () {
      final s = RummyState.newMatch(options: konkan, seed: 2);
      expect(s.fullDeck().length, 106);
      expect(s.fullDeck().where((x) => x.isJoker).length, 2);
      expect(s.hands.map((h) => h.length), [15, 14, 14, 14]);
      expect(s.stock.length, 49);
      expect(s.gameId, CardGameId.konkan);
    });

    test('K2 the corrected core: starter only discards first, one wild per meld, ace 11, discard into a new meld', () {
      const k = konkan;
      expect((k.starterFirstTurnDiscardOnly, k.noGoOutOnFirstTurn, k.maxWildsPerMeld), (true, true, 1));
      expect((k.aceLowOpeningValue, k.openingThreshold, k.discardUse), (11, 51, RummyDiscardUse.newMeldOnly));
      final e = RummyEngine(
        RummyState.custom(
          options: k,
          hands: [c('TC JC QC 7H 7S 7D 2D 5S 8H 9C KD 3S 4H 6D QH'), c('2D'), c('3S'), c('4H')],
          turnsTaken: [0, 0, 0, 0],
          phase: RummyPhase.play,
        ),
      );
      expect(e.validate(RummyMove.open([c('TC JC QC'), c('7H 7S 7D')])), 'firstTurnDiscardOnly');
      expect(e.state.meldRules.arrange(c('AS 2S 3S'))!.value, 16);
      expect(e.state.meldRules.arrange(c('5H X0 7H X1 9H')), isNull);
    });
  });

  group('scoring', () {
    test('K3 going out scores 0; the others their cards (joker 25), 100 if never opened', () {
      final e = RummyEngine(st(hands: ['9C', 'KS 7D X0', 'AC 3H', '2D'], opened: [true, true, true, false]))
        ..apply(RummyMove.discard(p('9C')));
      expect(e.state.results.single.points, [0, 42, 14, 100]);
    });

    test('K4 a one-turn finish from a closed hand (كونكان): 0, everyone else doubled (200 unopened)', () {
      final e = RummyEngine(
        st(
          hands: ['QS KS AS 5H 6H 7H 8H 9C 9D 9S 2D 3D 4D 5D KC', 'KD 5C', '2D 3D', 'X1 AS'],
          opened: [false, true, false, true],
        ),
      );
      e.apply(
        RummyMove.finish(melds: [c('QS KS AS'), c('5H 6H 7H 8H'), c('9C 9D 9S'), c('2D 3D 4D 5D')], discard: p('KC')),
      );
      final r = e.state.results.single;
      expect(r.handFinish, isTrue);
      expect(r.points, [0, 30, 200, 72]);
    });
  });

  group('match: elimination over 301', () {
    test('K6 example: A 250 + 60 = 310 is out, B 290 + 10 = 300 stays; B and C play on', () {
      final e = RummyEngine(
        st(
          options: const RummyOptions.konkan(players: 3),
          hands: ['KS KD KH KC QS QD', '7C 3D', '9C'],
          opened: [true, true, true],
          scores: [250, 290, 120],
          turn: 2,
          dealer: 1,
        ),
      );
      final ev = e.apply(RummyMove.discard(p('9C')));
      expect(e.state.seatScores, [310, 300, 120]);
      expect(e.state.eliminated, [true, false, false]);
      expect(e.state.results.single.eliminated, [0]);
      expect(ev.any((x) => x.type == CardEventType.playerFinished && x.seat == 0), isTrue);
      expect(e.isOver, isFalse);
      // Only the players still in are dealt; the deal falls to the highest
      // scorer of the round among them (B).
      expect(e.state.hands[0], isEmpty);
      expect((e.state.dealer, e.state.starter), (1, 2));
      expect(e.state.stock.length, 106 - 29);
      expect(e.state.cardsInPlay().length, 106);
      while (e.state.phase == RummyPhase.redealOffer) {
        e.apply(const RummyMove.keepHand());
      }
      e.apply(RummyMove.discard(e.state.hands[2].last));
      expect(e.state.turn, 1, reason: 'turns skip the eliminated seat');
    });

    test('K6 301 stays, 302 is out', () {
      final e = RummyEngine(
        st(hands: ['9C', '2D', '3D', '2S 3S'], opened: [true, true, true, true], scores: [0, 299, 300, 296])
          ..eliminated = [false, false, false, false],
      )..apply(RummyMove.discard(p('9C')));
      expect(e.state.seatScores, [0, 301, 303, 301]);
      expect(e.state.eliminated, [false, false, true, false]);
    });

    test('K6 the last player left wins', () {
      final e = RummyEngine(
        st(
          options: const RummyOptions.konkan(players: 3),
          hands: ['', '7C 3D', '9C'],
          opened: [true, true, true],
          scores: [310, 295, 120],
          eliminated: [true, false, false],
          turn: 2,
        ),
      )..apply(RummyMove.discard(p('9C')));
      expect(e.isOver, isTrue);
      expect(e.state.winners, [2]);
      expect(e.state.eliminated, [true, true, false]);
    });

    test('K6 with two players it is "first over 301 loses"', () {
      final e = RummyEngine(
        st(
          options: const RummyOptions.konkan(players: 2),
          hands: ['KS KD', '9C'],
          opened: [true, true],
          scores: [295, 100],
          turn: 1,
          dealer: 0,
        ),
      )..apply(RummyMove.discard(p('9C')));
      expect(e.isOver, isTrue);
      expect(e.state.winners, [1]);
    });

    test('K9 if everyone still in crosses in the same round, the lowest wins (an exact tie is shared)', () {
      const o = RummyOptions(
        variant: RummyVariant.konkan,
        winnerScore: 10,
        matchEnd: RummyMatchEnd.elimination,
        players: 3,
      );
      final e = RummyEngine(
        st(options: o, hands: ['9C', 'KS', '5D'], opened: [true, true, true], scores: [295, 298, 300]),
      )..apply(RummyMove.discard(p('9C')));
      expect(e.state.seatScores, [305, 308, 305]);
      expect(e.isOver, isTrue);
      expect(e.state.winners, [0, 2]);
    });

    test('K7 option eliminationScore 101', () {
      final e = RummyEngine(
        st(
          options: const RummyOptions.konkan(eliminationScore: 101),
          hands: ['9C', '2D', '3D', '2S'],
          opened: [true, true, true, true],
          scores: [0, 99, 100, 90],
        ),
      )..apply(RummyMove.discard(p('9C')));
      expect(e.state.eliminated, [false, false, true, false]);
      expect(RummyOptions.eliminationChoices, [301, 101]);
    });

    test('K8 options matchEnd targetScore (500, lowest wins) and rounds', () {
      final t = RummyEngine(
        st(
          options: const RummyOptions.konkan(matchEnd: RummyMatchEnd.targetScore),
          hands: ['9C', 'KD 5C', '2D 3D', 'X0 AS'],
          opened: [true, true, false, true],
          scores: [0, 0, 450, 0],
        ),
      )..apply(RummyMove.discard(p('9C')));
      expect(t.isOver, isTrue);
      expect(t.state.winners, [0]);
      final s =
          st(
              options: const RummyOptions.konkan(matchEnd: RummyMatchEnd.rounds, rounds: 3),
              hands: ['9C', 'KD 5C', '2D 3D', 'X0 AS'],
              opened: [true, true, false, true],
            )
            ..results.addAll([
              for (var i = 0; i < 2; i++) const RummyRoundResult(winner: 1, handFinish: false, points: [0, 0, 0, 0]),
            ]);
      final r = RummyEngine(s)..apply(RummyMove.discard(p('9C')));
      expect(r.isOver, isTrue);
      expect(r.state.eliminated, [false, false, false, false]);
    });

    test('partnership Konkan with elimination is refused', () {
      expect(
        const RummyOptions(
          variant: RummyVariant.konkan,
          partnership: true,
          matchEnd: RummyMatchEnd.elimination,
        ).invalidReason,
        'partnershipWithElimination',
      );
    });

    test('a void round eliminates nobody and does not count', () {
      final s =
          RummyState.custom(
              options: konkan,
              hands: [c('9C 8D'), c('2D'), c('3S'), c('4H')],
              discardPile: c('2C 3D 4S'),
              phase: RummyPhase.draw,
            )
            ..recycles = 2
            ..seatScores = [400, 0, 0, 0];
      final e = RummyEngine(s)..apply(const RummyMove.drawStock());
      expect(e.state.eliminated, [false, false, false, false]);
      expect(e.state.roundsPlayed, 0);
    });
  });

  group('AI', () {
    test('near the elimination score the AI sheds high cards first', () {
      final calm = st(hands: ['KS 2C 7H 9D', '2D', '3S', '4H'], opened: [true, true, true, true]);
      final danger = st(
        hands: ['KS 2C 7H 9D', '2D', '3S', '4H'],
        opened: [true, true, true, true],
        scores: [250, 0, 0, 0],
      );
      const ai = KonkanAi();
      final a = ai.keepValue(calm, 0, p('KS')) - ai.keepValue(calm, 0, p('2C'));
      final b = ai.keepValue(danger, 0, p('KS')) - ai.keepValue(danger, 0, p('2C'));
      expect(b, lessThan(a));
    });
  });
}

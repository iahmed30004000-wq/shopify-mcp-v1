import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/cinema/rules/cards/cards.dart';

PlayingCard p(String id) => PlayingCard.parse(id);
List<PlayingCard> c(String ids) => PlayingCard.list(ids);

List<List<PlayingCard>> roundRobinDeal() {
  final deck = buildDeck();
  return [
    for (var seat = 0; seat < 4; seat++) [for (var i = seat; i < 52; i += 4) deck[i]],
  ];
}

void main() {
  test('probe: invalid double error id', () {
    final e = TrixEngine(TrixState.withHands(roundRobinDeal()));
    e.apply(const TrixMove.contract(TrixContract.queens));
    // owner 3 holds QD only
    print('not held: ${e.validate(TrixMove.double([p('QS')]))}');
    print('not doublable: ${e.validate(TrixMove.double([p('7H')]))}');
    print('play in doubling: ${e.validate(TrixMove.play(p('7H')))}');
  });

  test('probe: fromJson unsorted', () {
    final m = TrixMove.fromJson({'k': 'double', 'cs': ['KH', 'QS']});
    print('fromJson unsorted == double: ${m == TrixMove.double([p('QS'), p('KH')])} cards=${m.cards}');
  });

  test('probe: complex heart lead after K♥ fell', () {
    // seat 0 holds KH + clubs; seat 1.. etc
    final hands = [
      c('KH 2H AC KC QC JC TC 9C 8C 7C 6C 5C 4C'),
      c('3C 3H 4H 5H 6H 7H AD KD QD JD TD 9D 8D'),
      c('2C 8H 9H TH JH QH AH 7D 6D 5D 4D 3D 2D'),
      c('AS KS QS JS TS 9S 8S 7S 6S 5S 4S 3S 2S'),
    ];
    final e = TrixEngine(TrixState.withHands(hands,
        options: const TrixOptions(mode: TrixMode.complex, firstOwnerRule: TrixFirstOwner.fixedSeat, doubling: false)));
    e.apply(const TrixMove.contract(TrixContract.complex));
    e.apply(TrixMove.play(p('AC')));
    e.apply(TrixMove.play(p('3C')));
    e.apply(TrixMove.play(p('2C')));
    // seat 3 void clubs, no KH -> any
    e.apply(TrixMove.play(p('2S')));
    // seat 0 won; leads KC? lead 4C
    e.apply(TrixMove.play(p('4C')));
    // seat 1 void in clubs now -> no KH -> any
    print('seat1 legal count ${e.legalMoves(1).length}');
  });

  test('probe: hard move identical after JSON restore', () {
    const ai = TrixAi();
    for (final o in [const TrixOptions(), const TrixOptions(mode: TrixMode.complex, partnership: true)]) {
      final e = TrixEngine.newMatch(seed: 17, options: o);
      final rng = CardRng(5);
      var diffs = 0;
      for (var i = 0; i < 400 && !e.isOver; i++) {
        final seat = e.currentPlayer!;
        if (i % 5 == 0) {
          final r = TrixState.fromJson(jsonDecode(jsonEncode(e.toJson())) as Map<String, Object?>);
          final a = ai.chooseMove(e.state, seat, AiLevel.hard, CardRng(i), const AiBudget.simulations(12));
          final b = ai.chooseMove(r, seat, AiLevel.hard, CardRng(i), const AiBudget.simulations(12));
          if (a != b) diffs++;
        }
        e.apply(ai.chooseMove(e.state, seat, AiLevel.medium, rng, AiBudget.phone));
      }
      print('diffs ${o.mode.name}: $diffs');
    }
  });
}

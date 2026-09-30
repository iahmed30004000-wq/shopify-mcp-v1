// The AIs must not peek: re-dealing everything a seat cannot see (the other
// hands, the stock) consistently with public information must not change
// that seat's decision, at medium or at hard.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/cinema/rules/cards/cards.dart';

void main() {
  for (final id in CardGameId.values) {
    test('${id.name}: decisions depend only on what the seat can see', () {
      final ai = CardGames.ai(id) as HeuristicAi;
      final e = CardGames.newMatch(id, seed: 5);
      final rng = CardRng(1);
      var checked = 0;
      for (var move = 0; move < 400 && !e.isOver; move++) {
        final seat = e.currentPlayer!;
        if (move % 7 == 3) {
          final real = e.state;
          final other = ai.determinize(real, seat, CardRng(move));
          // Same own hand and public view, different hidden cards.
          expect(jsonEncode(cardsToJson(sortedCards(other.cardsInPlay()))), jsonEncode(cardsToJson(sortedCards(real.cardsInPlay()))));
          for (final level in [AiLevel.medium, AiLevel.hard]) {
            final a = ai.chooseMove(real, seat, level, CardRng(9), const AiBudget.simulations(10));
            final b = ai.chooseMove(other, seat, level, CardRng(9), const AiBudget.simulations(10));
            expect(b, a, reason: '${id.name} move $move ${level.name}');
          }
          checked++;
        }
        e.apply(ai.chooseMove(e.state, seat, AiLevel.medium, rng, AiBudget.phone));
      }
      expect(checked, greaterThan(10));
    });
  }

  test('determinised worlds keep voids and publicly known cards', () {
    // Tarneeb: after a trick where seat 1 showed out of hearts, no world
    // gives seat 1 a heart.
    final hands = [
      PlayingCard.list('2H 3H 4H 5H 6H 7H 8H 9H TH JH QH KH AH'),
      PlayingCard.list('2S 3S 4S 5S 6S 7S 8S 9S TS JS QS KS AS'),
      PlayingCard.list('2D 3D 4D 5D 6D 7D 8D 9D TD JD QD KD AD'),
      PlayingCard.list('2C 3C 4C 5C 6C 7C 8C 9C TC JC QC KC AC'),
    ];
    final e = TarneebEngine(TarneebState.withHands(hands));
    e.apply(const TarneebMove.bid(7));
    for (var i = 0; i < 3; i++) {
      e.apply(const TarneebMove.pass());
    }
    e.apply(const TarneebMove.trump(Suit.clubs));
    for (final id in ['2H', '2S', '2D', '2C']) {
      e.apply(TarneebMove.play(PlayingCard.parse(id)));
    }
    const ai = TarneebAi();
    for (var i = 0; i < 20; i++) {
      final w = ai.determinize(e.state, 3, CardRng(i));
      expect(w.hands[3], e.state.hands[3]);
      for (final seat in [0, 1, 2]) {
        expect(w.hands[seat].length, 12);
      }
      expect(w.hands[1].any((c) => c.suit == Suit.hearts), isFalse);
      expect(w.hands[2].any((c) => c.suit == Suit.hearts), isFalse);
    }
    // Rummy: a card taken from the discard pile stays with its taker.
    final r = RummyState.custom(
      options: const RummyOptions.hand(),
      hands: [
        PlayingCard.list('2C 3C'),
        PlayingCard.list('KD KH 5S'),
        PlayingCard.list('4D'),
        PlayingCard.list('9S'),
      ],
      stock: PlayingCard.list('7H 8H 9H 2D 3D'),
    )..known[1] = PlayingCard.list('KD');
    for (var i = 0; i < 10; i++) {
      final w = const RummyAi().determinize(r, 0, CardRng(i));
      expect(w.hands[1], contains(PlayingCard.parse('KD')));
      expect(w.hands[0], r.hands[0]);
      expect(w.stock.length, 5);
    }
  });
}

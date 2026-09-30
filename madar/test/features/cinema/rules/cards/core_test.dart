import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/cinema/rules/cards/cards.dart';
import 'package:madar/features/cinema/rules/cards/core/determinize.dart';
import 'package:madar/features/cinema/rules/cards/core/search.dart';
import 'package:madar/features/cinema/rules/cards/core/trick.dart';

void main() {
  group('cards', () {
    test('every card round-trips through its id; jokers have no suit', () {
      for (var code = 0; code < 56; code++) {
        final c = PlayingCard.fromCode(code);
        expect(PlayingCard.parse(c.id), same(c));
      }
      expect(PlayingCard.parse('TD'), PlayingCard(Suit.diamonds, Rank.ten));
      expect(PlayingCard.list('AS  KD 7H X1'), [
        PlayingCard(Suit.spades, Rank.ace),
        PlayingCard(Suit.diamonds, Rank.king),
        PlayingCard(Suit.hearts, Rank.seven),
        PlayingCard.joker(1),
      ]);
      expect(() => PlayingCard.joker().suit, throwsStateError);
      expect(() => PlayingCard.parse('1S'), throwsFormatException);
    });

    test('decks', () {
      expect(buildDeck().toSet().length, 52);
      expect(buildDeck(ranks: balootRanks).length, 32);
      expect(buildDeck(copies: 2, jokers: 4).length, 108);
      expect(buildDeck(copies: 2, jokers: 2).length, 106);
    });
  });

  group('CardRng', () {
    test('same seed, same sequence; different seeds differ; JSON resumes exactly', () {
      final a = CardRng(42);
      final b = CardRng(42);
      final seqA = [for (var i = 0; i < 50; i++) a.nextUint32()];
      expect([for (var i = 0; i < 50; i++) b.nextUint32()], seqA);
      final c = CardRng(43);
      expect([for (var i = 0; i < 50; i++) c.nextUint32()], isNot(seqA));
      final saved = CardRng.fromJson(jsonDecode(jsonEncode(a.toJson())));
      expect([for (var i = 0; i < 20; i++) saved.nextInt(1000)], [for (var i = 0; i < 20; i++) a.nextInt(1000)]);
      // Negative and 64-bit seeds are fine.
      expect(CardRng(-7).nextUint32(), isNot(CardRng(7).nextUint32()));
      expect(CardRng(1 << 40).nextUint32(), isNot(CardRng(0).nextUint32()));
    });

    test('nextInt stays in range and is roughly uniform; shuffle permutes', () {
      final r = CardRng(1);
      final counts = List.filled(6, 0);
      for (var i = 0; i < 6000; i++) {
        counts[r.nextInt(6)]++;
      }
      for (final n in counts) {
        expect(n, inInclusiveRange(850, 1150));
      }
      final deck = buildDeck();
      r.shuffle(deck);
      expect(sortedCards(deck), buildDeck());
      expect(deck, isNot(buildDeck()));
      final d = r.nextDouble();
      expect(d, inInclusiveRange(0, 1));
    });

    test('a known seed always deals the same Tarneeb hands (replay stability)', () {
      final s1 = TarneebState.newMatch(seed: 2026);
      final s2 = TarneebState.newMatch(seed: 2026);
      expect(jsonEncode(s1.toJson()), jsonEncode(s2.toJson()));
    });
  });

  group('determinisation', () {
    test('constrained deal respects voids and counts', () {
      final pool = buildDeck().sublist(0, 39);
      final rng = CardRng(9);
      for (var i = 0; i < 30; i++) {
        final hands = dealConstrained(pool, [13, 13, 13], (h, c) => !(h == 0 && c.suit == Suit.diamonds), rng);
        expect(hands.map((h) => h.length), [13, 13, 13]);
        expect(hands[0].any((c) => c.suit == Suit.diamonds), isFalse);
        expect(sortedCards([for (final h in hands) ...h]), sortedCards(pool));
      }
    });

    test('an impossible constraint is relaxed rather than failing', () {
      final pool = PlayingCard.list('2H 3H 4H');
      final hands = dealConstrained(pool, [3], (h, c) => false, CardRng(1));
      expect(sortedCards(hands.single), sortedCards(pool));
    });

    test('multiset difference', () {
      expect(cardsMinus(PlayingCard.list('AS AS KD'), PlayingCard.list('AS')), PlayingCard.list('AS KD'));
    });
  });

  test('trick winner: trumps beat the led suit, other suits never win', () {
    final t = Trick(0)
      ..add(0, PlayingCard.parse('5H'))
      ..add(1, PlayingCard.parse('AS'))
      ..add(2, PlayingCard.parse('KH'))
      ..add(3, PlayingCard.parse('2D'));
    expect(t.winner((c, led) => standardPower(c, led, null)), 2);
    expect(t.winner((c, led) => standardPower(c, led, Suit.diamonds)), 3);
    expect(voidsFromTricks([t], 4)[1], {Suit.hearts});
  });

  test('the hard search keeps the heuristic move when the budget is too small', () {
    final s = TarneebState.newMatch(seed: 3);
    const ai = TarneebAi();
    final legal = const TarneebRules().legalMoves(s, s.turn);
    final prior = legal.last;
    final pick = monteCarloChoose<TarneebState, TarneebMove>(
      candidates: legal,
      hooks: SearchHooks(
        sampleWorld: (r) => ai.determinize(s, s.turn, r),
        apply: (st, m) => const TarneebRules().apply(st, m),
        policy: ai.rolloutMove,
        done: (st) => ai.rolloutDone(s, st),
        score: (st) => ai.evaluate(s, st, s.turn),
      ),
      rng: CardRng(1),
      budget: const AiBudget.simulations(5),
      fallback: prior,
    );
    expect(pick, prior);
  });

  group('registry', () {
    test('every game can be created, saved, restored and asked for an AI move', () {
      for (final id in CardGameId.values) {
        final e = CardGames.newMatch(id, seed: 11);
        expect(e.state.gameId, id);
        final json = jsonDecode(jsonEncode(e.toJson())) as Map<String, Object?>;
        final back = CardGames.fromJson(json);
        expect(jsonEncode(back.toJson()), jsonEncode(json));
        final p = e.currentPlayer!;
        final m = CardGames.ai(id).chooseMove(e.state, p, AiLevel.medium, CardRng(1), AiBudget.phone);
        expect(e.validate(m), isNull);
        expect(e.legalMoves((p + 1) % e.state.playerCount), isEmpty);
        expect(e.validate(m), isNull);
        e.apply(m);
      }
    });

    test('a move for the wrong phase is rejected with an id', () {
      final e = CardGames.newMatch(CardGameId.tarneeb, seed: 1);
      expect(() => e.apply(TarneebMove.play(PlayingCard.parse('AS'))), throwsA(isA<IllegalMoveException>()));
    });
  });
}

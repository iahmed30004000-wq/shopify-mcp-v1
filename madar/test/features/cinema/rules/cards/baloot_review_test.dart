// Baloot: problems found in the adversarial rules review, each proved by a
// test that failed before its fix (final spec §11, RULES.md §5.6), plus the
// AI levels in order.
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/cinema/rules/cards/cards.dart';
import 'package:madar/features/cinema/rules/cards/core/determinize.dart';

import 'support.dart';

List<PlayingCard> c(String ids) => PlayingCard.list(ids);
PlayingCard p(String id) => PlayingCard.parse(id);

/// A deal with [hands] (five cards each) and the up card [up]; the rest of
/// the pack is the stock, dealt from its end.
BalootEngine deal(List<String> hands, String up, {BalootOptions options = const BalootOptions(), List<String>? stock}) {
  final hs = [for (final h in hands) c(h)];
  final upCard = p(up);
  final rest = stock == null
      ? cardsMinus(buildDeck(ranks: balootRanks), [for (final h in hs) ...h, upCard])
      : c(stock.join(' '));
  return BalootEngine(BalootState.withDeal(hands: hs, upCard: upCard, stock: rest, options: options));
}

/// The first trick of a Sun deal bought by seat 0 (who took the up card
/// A♥): seat 0 leads A♠; seat 1, void in spades, declares a hundred in clubs
/// and plays the ♣10; seat 2 holds 9-10-J-Q-K♦ (a hundred topped by the
/// king) and is to act. [seat0], [seat1] and [seat3] are the hidden hands:
/// the two worlds used below differ only there, so seat 2 sees exactly the
/// same thing in both (a hundred announced by seat 1, the ♠A and the ♣10).
BalootState trickOne(String seat0, String seat1, String seat3, BalootDeclareProjects declare) {
  final s = deal(
    ['7S JS KS AS 9H', 'TC JC QC KC AC', '9D TD JD QD KD', '7C 8C 8S TS QS'],
    '9S',
    options: BalootOptions(declareProjects: declare),
  ).state;
  s
    ..phase = BalootPhase.playing
    ..mode = BalootMode.sun
    ..trump = null
    ..buyer = 0
    ..bidder = 0
    ..upCard = null
    ..turnedUp = p('AH')
    ..stock = []
    ..hands = [c(seat0), c(seat1), c('9D TD JD QD KD 7H 9S JH'), c(seat3)]
    ..projectsDecided = List.filled(4, declare == BalootDeclareProjects.auto)
    ..trick = Trick(0)
    ..turn = 0;
  s.projects = declare == BalootDeclareProjects.auto
      ? [for (var seat = 0; seat < 4; seat++) ...BalootRules.projectsOf(s, seat)]
      : [];
  final e = BalootEngine(s)..apply(BalootMove.play(p('AS')));
  if (declare == BalootDeclareProjects.manual) e.apply(const BalootMove.declareProjects());
  e.apply(BalootMove.play(p('TC')));
  return e.state;
}

/// Seat 1's hundred is 10-J-Q-K-A♣ (it beats seat 2's king-high hundred).
BalootState worldA(BalootDeclareProjects d) =>
    trickOne('7S JS KS AS 9H QH AH 9C', 'TC JC QC KC AC 8H TH 7D', '7C 8C 8S TS QS 8D AD KH', d);

/// Seat 1's hundred is 8-9-10-J-Q♣ (seat 2's king-high hundred beats it).
BalootState worldB(BalootDeclareProjects d) =>
    trickOne('7S JS KS AS 9H QH AH AC', '8C 9C TC JC QC 8H TH 7D', '7C KC 8S TS QS 8D AD KH', d);

void main() {
  group('R1 projects: named when play starts, cards shown only after the first trick', () {
    // Seat 0 (P1) bids Sun and gets no double (scores 0-0), so play starts
    // at once. Seat 0 holds four queens, seat 2 a fifty (8-9-10-J ♦).
    BalootEngine sunDeal([BalootOptions o = const BalootOptions()]) =>
        deal(['QS QH QD QC 7D', '7S 8S 9H TH JH', '8D 9D TD JD KD', 'AH 7C 8C 9C TC'], 'KH', options: o);

    test('auto: the play-start announcement carries the project types and points, not the cards', () {
      final e = sunDeal();
      final events = e.apply(const BalootMove.sun());
      expect(e.state.phase, BalootPhase.playing);
      final announced = events.where((x) => x.type == CardEventType.projectsDeclared).toList();
      expect(announced.map((x) => x.seat).toSet(), e.state.projects.map((x) => x.seat).toSet());
      for (final x in announced) {
        // Before the fix every event already held the project cards.
        expect(x.cards, isEmpty, reason: 'seat ${x.seat} showed ${x.cards} before the first trick');
        final mine = e.state.projects.where((q) => q.seat == x.seat);
        expect(x.detail, mine.map((q) => q.type.name).join(','));
        expect(x.value, mine.fold<int>(0, (a, q) => a + q.value(BalootMode.sun)));
      }
      expect(e.state.projectsRevealed, isFalse);
    });

    test('auto: when the first trick is complete every declared project is shown', () {
      final e = sunDeal();
      e.apply(const BalootMove.sun());
      final shown = <CardEvent>[];
      for (var i = 0; i < 4; i++) {
        final seat = e.currentPlayer!;
        final events = e.apply(e.legalMoves(seat).first);
        shown.addAll(events.where((x) => x.type == CardEventType.projectsDeclared));
        if (i < 3) expect(shown, isEmpty);
      }
      expect(e.state.projectsRevealed, isTrue);
      expect(shown.every((x) => x.detail == 'shown'), isTrue);
      final bySeat = {for (final x in shown) x.seat!: x.cards};
      for (final q in e.state.projects) {
        expect(bySeat[q.seat], containsAll(q.cards));
      }
      expect(bySeat.keys.toSet(), e.state.projects.map((x) => x.seat).toSet());
    });

    test('manual: declaring names the projects; the cards follow after the first trick', () {
      final e = sunDeal(const BalootOptions(declareProjects: BalootDeclareProjects.manual));
      e.apply(const BalootMove.sun());
      expect(e.legalMoves(0), const [BalootMove.declareProjects(), BalootMove.skipProjects()]);
      final events = e.apply(const BalootMove.declareProjects());
      final x = events.singleWhere((x) => x.type == CardEventType.projectsDeclared);
      expect(x.cards, isEmpty);
      final mine = e.state.projects.where((q) => q.seat == 0).toList();
      expect(mine.any((q) => q.isCarre), isTrue);
      expect(x.detail, mine.map((q) => q.type.name).join(','));
      expect(x.value, mine.fold<int>(0, (a, q) => a + q.value(BalootMode.sun)));
      // Play the first trick (declaring or skipping as needed): then shown.
      final shown = <CardEvent>[];
      while (e.state.tricks.isEmpty) {
        final seat = e.currentPlayer!;
        final m = e.legalMoves(seat).first;
        shown.addAll(e.apply(m).where((x) => x.type == CardEventType.projectsDeclared && x.detail == 'shown'));
      }
      expect({for (final x in shown) x.seat}, e.state.projects.map((q) => q.seat).toSet());
      expect(shown.firstWhere((x) => x.seat == 0).cards, containsAll(c('QS QH QD QC')));
    });
  });

  group('R2 the declared set follows the comparison options', () {
    // Four queens or 10-J-Q-K-A of spades: both a hundred, sharing the Q♠,
    // and nothing else in the hand. Which one to declare depends on which
    // wins among hundreds.
    final hand = c('QS QH QD QC TS JS KS AS');

    test('default: four of a kind beats a sequence, so the carré is declared', () {
      final best = BalootRules.detectProjects(hand, 0, BalootMode.hokom, trump: Suit.hearts);
      expect(best.single.isCarre, isTrue);
    });

    test('sequenceBeatsCarre: the sequence is declared (it was the carré before the fix)', () {
      final best = BalootRules.detectProjects(
        hand,
        0,
        BalootMode.hokom,
        trump: Suit.hearts,
        options: const BalootOptions(sequenceBeatsCarre: true),
      );
      expect(best.single.isCarre, isFalse);
      expect(best.single.topIndex, naturalIndex(Rank.ace));
    });

    test('in a real deal the declarer\'s team then wins the project comparison', () {
      // Seat 0 gets Q♥ Q♦ Q♣ K♠ A♠ plus Q♠ T♠ J♠ from the stock; seat 1 holds
      // 7-8-9-10-J of hearts (a hundred topped by the jack).
      const o = BalootOptions(sequenceBeatsCarre: true, doubling: false);
      final e = deal(
        ['QH QD QC KS AS', '7H 8H 9H TH JH', '7C 8C 9C TC JC', '7D 8D 9D TD JD'],
        'QS',
        options: o,
        // Drawn from the end: seat 0 (taker) 2, then seats 1, 2, 3 three each.
        stock: ['KD AD KC', 'AC KH AH', '7S 8S 9S', 'TS JS'],
      );
      e.apply(const BalootMove.hokom(Suit.spades));
      for (var i = 0; i < 3; i++) {
        e.apply(const BalootMove.pass());
      }
      e.apply(const BalootMove.confirm());
      expect(e.state.phase, BalootPhase.playing);
      expect(e.state.hands[0], containsAll(c('QS QH QD QC TS JS KS AS')));
      final mine = e.state.projects.where((x) => x.seat == 0).single;
      expect(mine.isCarre, isFalse);
      expect(
        BalootRules.projectTeam(
          e.state.projects,
          e.state.firstPlayer,
          BalootMode.hokom,
          trump: Suit.spades,
          options: o,
        ),
        0,
      );
    });
  });
  group('R3 manual declaration: the AI decides on what has been announced, not on hidden cards', () {
    test('an announced hundred of unknown height does not make seat 2 skip its own hundred', () {
      const manual = BalootDeclareProjects.manual;
      final a = worldA(manual);
      final b = worldB(manual);
      expect(a.turn, 2);
      expect(BalootEngine(a).legalMoves(2), const [BalootMove.declareProjects(), BalootMove.skipProjects()]);
      // Only the type and the points of seat 1's project are public so far.
      expect(a.projects.single.value(BalootMode.sun), b.projects.single.value(BalootMode.sun));
      final ma = const BalootAi().chooseMove(a, 2, AiLevel.medium, math.Random(1), AiBudget.phone);
      final mb = const BalootAi().chooseMove(b, 2, AiLevel.medium, math.Random(1), AiBudget.phone);
      // Before the fix the AI read seat 1's cards: skip in A, declare in B.
      expect(ma, mb);
      expect(ma, const BalootMove.declareProjects());
    });

    test('a project of a higher value announced by an opponent still makes it skip', () {
      final s = worldB(BalootDeclareProjects.manual);
      // Seat 2 now holds only a sira (4) against seat 1's hundred (20).
      s.hands[2] = c('9D TD JD 7H 9S JH AD KH');
      s.hands[3] = c('7C KC 8S TS QS 8D QD KD');
      expect(BalootRules.projectsOf(s, 2).single.type, BalootProjectType.sira);
      final m = const BalootAi().chooseMove(s, 2, AiLevel.medium, math.Random(1), AiBudget.phone);
      expect(m, const BalootMove.skipProjects());
    });
  });

  group('R4 hard AI: before the first trick is complete only the project types are public', () {
    for (final d in BalootDeclareProjects.values) {
      test('${d.name}: the sampled world depends only on what seat 2 has seen', () {
        const ai = BalootAi();
        final a = worldA(d);
        final b = worldB(d);
        expect(a.projectsRevealed, isFalse);
        for (var k = 0; k < 12; k++) {
          final wa = ai.determinize(a, 2, math.Random(k));
          final wb = ai.determinize(b, 2, math.Random(k));
          // Before the fix the worlds kept seat 1's real project cards.
          expect(jsonEncode(wa.toJson()), jsonEncode(wb.toJson()), reason: 'sample $k');
        }
      });

      test('${d.name}: each announced project is placed, at the announced value, in its owner\'s sampled hand', () {
        const ai = BalootAi();
        final real = worldA(d);
        final own = real.projects.where((x) => x.seat == 2).toList();
        final heights = <int>{};
        for (var k = 0; k < 40; k++) {
          final w = ai.determinize(real, 2, math.Random(k));
          expect(sortedCards(w.cardsInPlay()), sortedCards(real.cardsInPlay()));
          expect(w.hands[2], real.hands[2]);
          expect(w.projects.where((x) => x.seat == 2).map((x) => x.cards), own.map((x) => x.cards));
          final theirs = w.projects.where((x) => x.seat == 1).single;
          expect(theirs.type, BalootProjectType.hundred);
          // Seat 1 is void in spades and has played the ♣10.
          final held = {...w.hands[1], p('TC')};
          expect(held.containsAll(theirs.cards), isTrue, reason: '$theirs in ${w.hands[1]}');
          expect(theirs.cards.any((x) => x.suit == Suit.spades), isFalse);
          expect(w.hands[1].any((x) => x.suit == Suit.spades), isFalse);
          heights.add(theirs.topIndex);
          expect(w.projects.where((x) => x.seat == 0 || x.seat == 3), isEmpty);
        }
        // Different heights are sampled (the real one is not favoured).
        expect(heights.length, greaterThan(1));
      });
    }

    test('once the first trick is complete the shown projects are fixed in their owners\' hands', () {
      final e = BalootEngine(worldA(BalootDeclareProjects.auto));
      e.apply(BalootMove.play(p('9S')));
      e.apply(BalootMove.play(p('QS')));
      expect(e.state.projectsRevealed, isTrue);
      final w = const BalootAi().determinize(e.state, 2, math.Random(3));
      expect(
        jsonEncode(w.projects.map((x) => x.toJson()).toList()),
        jsonEncode(e.state.projects.map((x) => x.toJson()).toList()),
      );
      final seat1 = e.state.projects.singleWhere((x) => x.seat == 1);
      expect(w.hands[1], containsAll(seat1.cards.where((x) => x != p('TC'))));
    });
  });

  group('saving and copying', () {
    test('copy() and a JSON round trip reproduce the state after every move (default and every option)', () {
      for (final o in [
        const BalootOptions(targetScore: 60),
        const BalootOptions(
          targetScore: 60,
          kawesh: true,
          aceThirdRound: true,
          ashkalInRound2: true,
          declareProjects: BalootDeclareProjects.manual,
          firstLead: BalootFirstLead.taker,
        ),
      ]) {
        for (var seed = 1; seed <= 3; seed++) {
          final e = BalootEngine.newMatch(seed: seed, options: o);
          final rng = CardRng(seed);
          for (var n = 0; !e.isOver && n < 3000; n++) {
            final j = jsonEncode(e.toJson());
            expect(jsonEncode(BalootState.fromJson(jsonDecode(j) as Map<String, Object?>).toJson()), j);
            expect(jsonEncode(e.state.copy().toJson()), j);
            e.apply(const BalootAi().chooseMove(e.state, e.currentPlayer!, AiLevel.easy, rng, AiBudget.phone));
          }
          expect(e.isOver, isTrue);
        }
      }
    });
  });

  group('AI levels in order', () {
    test('medium beats easy', () {
      final k = Kit('baloot', (seed) => BalootEngine.newMatch(seed: seed), BalootEngine.fromJson, const BalootAi());
      var wins = 0;
      var edge = 0.0;
      const matches = 12;
      for (var m = 0; m < matches; m++) {
        final levels = [for (var s = 0; s < 4; s++) s % 2 == m % 2 ? AiLevel.medium : AiLevel.easy];
        final r = playMatch(k, 700 + m, levels);
        edge += r.scores[m % 2] - r.scores[1 - m % 2];
        if (r.winners.contains(m % 2)) wins++;
      }
      expect(edge / matches, greaterThan(5));
      expect(wins, greaterThan(matches / 2));
    });
  });
}

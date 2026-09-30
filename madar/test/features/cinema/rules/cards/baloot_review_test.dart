// Baloot: problems found in the adversarial rules review, each proved by a
// test that failed before its fix (final spec §11, RULES.md §5.6).
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/cinema/rules/cards/cards.dart';
import 'package:madar/features/cinema/rules/cards/core/determinize.dart';

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
        BalootRules.projectTeam(e.state.projects, e.state.firstPlayer, BalootMode.hokom, trump: Suit.spades, options: o),
        0,
      );
    });
  });
}

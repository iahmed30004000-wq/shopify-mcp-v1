// Hand / Konkan rules review: each test proves a problem found by an
// adversarial read of the rules document against the engine, and keeps it
// fixed (RULES.md, Hand and Konkan).
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/cinema/rules/cards/cards.dart';

List<PlayingCard> c(String ids) => PlayingCard.list(ids);
PlayingCard p(String id) => PlayingCard.parse(id);
const rules = MeldRules();
Meld m(String ids, [int owner = 1]) => rules.arrange(c(ids), owner: owner)!;

RummyState st({
  RummyOptions options = const RummyOptions.hand(),
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

/// Why table meld [m] is not a valid meld of [s]'s round, or null.
String? meldProblem(RummyState s, Meld m) {
  final r = s.meldRules;
  if (m.wilds > s.options.maxWildsPerMeld || m.naturals <= m.wilds) return 'wilds';
  for (var i = 0; i < m.cards.length; i++) {
    if (m.isWildAt(i) != r.isWild(m.cards[i])) return 'wild mask';
  }
  if (m.kind == MeldKind.set) {
    final nats = [
      for (var i = 0; i < m.cards.length; i++)
        if (!m.isWildAt(i)) m.cards[i],
    ];
    if (m.cards.length < 3 || m.cards.length > 4) return 'set size';
    if (nats.any((x) => r.rankOf(x) != m.rank) || nats.map(r.suitOf).toSet().length != nats.length) return 'set';
    return null;
  }
  if (m.cards.length < 3 || m.low < 1 || m.high > 14) return 'run size';
  for (var i = 0; i < m.cards.length; i++) {
    if (!m.isWildAt(i) && !r.isCardAt(m.cards[i], m.suit!, m.low + i)) return 'run card';
  }
  return null;
}

/// The table and [seat]'s hand after a move (to compare two moves).
String outcome(RummyState s, int seat) =>
    '${[for (final m in s.table) '${m.low}:${m.cards}:${m.wildMask}'].join('|')}#${sortedCards(s.hands[seat])}';

/// Every single-card lay-down [seat] could try: lay-offs (both ends), swaps
/// of one or two cards, melds of the hand's candidates (both placements),
/// discards.
List<RummyMove> tries(RummyState s, int seat) {
  final distinct = s.hands[seat].toSet().toList()..sort();
  return [
    for (final x in distinct) ...[
      RummyMove.discard(x),
      for (var i = 0; i < s.table.length; i++) ...[
        RummyMove.layoff(x, i),
        RummyMove.layoff(x, i, atLow: true),
        RummyMove.swapJoker(x, i),
        for (final y in distinct)
          if (y.code > x.code) RummyMove.swapJoker(x, i, card2: y),
      ],
    ],
    for (final m in s.meldRules.candidates(s.hands[seat])) ...[
      RummyMove.meld(m.cards),
      RummyMove.meld(m.cards, wildLow: true),
    ],
  ];
}

void main() {
  group('swappedWildMustBeUsed', () {
    test('a freed wild that cannot be laid down again does not force other lay-downs before the discard', () {
      const o = RummyOptions(swappedWildMustBeUsed: true);
      final e = RummyEngine(
        st(
          options: o,
          hands: ['KC 7D 2C 9S', '2D 3D', '3S 4S', '4H 5H'],
          table: [m('KS KH KD X0'), m('3D 4D 5D X1')],
          opened: [true, true, true, true],
        ),
      );
      e.apply(RummyMove.swapJoker(p('KC'), 0));
      expect(e.state.hands[0], unorderedEquals(c('7D 2C 9S X0')));
      // The wild fits nowhere (the set is full, the run has its wild, no
      // meld in hand), so it is released at once; 7♦ still fits the run but
      // nothing obliges the player to lay it off first.
      expect(e.legalMoves(0), contains(RummyMove.layoff(p('7D'), 1)));
      expect(e.legalMoves(0), contains(RummyMove.discard(p('2C'))));
      expect(e.validate(RummyMove.discard(p('2C'))), isNull);
    });

    test('… while a freed wild that can be laid down still holds the discard back, other lay-downs or not', () {
      const o = RummyOptions(swappedWildMustBeUsed: true);
      final e = RummyEngine(
        st(
          options: o,
          hands: ['KC 7D 2C 3C 9S', '2D 3D', '3S 4S', '4H 5H'],
          table: [m('KS KH KD X0'), m('3D 4D 5D X1')],
          opened: [true, true, true, true],
        ),
      );
      e.apply(RummyMove.swapJoker(p('KC'), 0));
      expect(e.validate(RummyMove.discard(p('9S'))), 'mustUseFreedWild');
      e.apply(RummyMove.layoff(p('7D'), 1));
      expect(e.validate(RummyMove.discard(p('9S'))), 'mustUseFreedWild');
      expect(e.legalMoves(0).any((x) => x.kind == RummyMoveKind.discard), isFalse);
      e.apply(RummyMove.meld(c('2C 3C X0')));
      expect(e.validate(RummyMove.discard(p('9S'))), isNull);
    });
  });

  group('the top discard', () {
    test('T4 a closed player may take it whenever a 51 opening can use it (a search limit hid this one)', () {
      // 6♣ 6♦ 6♥ 6♠ (24) + 7♣ 7♦ 🃏 (21) + 2♣ 2♦ 🃏 (6) = 51, the only opening
      // that holds the 2♦; the capped plan search ran out before reaching it.
      final e = RummyEngine(
        st(
          hands: ['2C 3C 4C 6C 7C 6D 7D 5H 6H 6H 3S 6S X0 X1', '9D', '3H', '4S'],
          discard: '2D',
          phase: RummyPhase.draw,
        ),
      );
      expect(e.legalMoves(0), contains(const RummyMove.takeDiscard()));
      expect(e.validate(const RummyMove.takeDiscard()), isNull);
      e.apply(const RummyMove.takeDiscard());
      final open = RummyMove.open([c('6C 6D 6H 6S'), c('7C 7D X0'), c('2C 2D X1')]);
      expect(e.validate(open), isNull);
      final opens = e.legalMoves(0).where((x) => x.kind == RummyMoveKind.open).toList();
      expect(opens, isNotEmpty);
      expect(opens.every((x) => x.meldCards.contains(p('2D'))), isTrue);
      e.apply(opens.first);
      expect(e.state.opened[0], isTrue);
      expect(e.state.mustUse, isNull);
    });
  });

  group('documented behaviour', () {
    test('openingMustBeatPrevious: the bar is the open move itself, not melds added later that turn', () {
      const o = RummyOptions(openingMustBeatPrevious: true);
      final e = RummyEngine(
        st(options: o, hands: ['TC JC QC 9H 9S 9D 5D 6D 7D 2S', '2D', '3S', '4H'])..highestOpening = 56,
      );
      e.apply(RummyMove.open([c('TC JC QC'), c('9H 9S 9D')]));
      expect(e.state.highestOpening, 57);
      e.apply(RummyMove.meld(c('5D 6D 7D')));
      expect(e.state.highestOpening, 57);
    });
  });

  group('bonus options', () {
    test('one suit / one colour looks at every card of the full hand, lay-offs on older melds included', () {
      // fullHandOwnMeldsOnly off: a one-turn finish with a lay-off on an
      // older meld is still a full hand, but the 8♠ laid off means the hand
      // was not all hearts (nor all red): no bonus.
      const o = RummyOptions(fullHandOwnMeldsOnly: false, bonusOneSuit: true, bonusOneColour: true);
      final e = RummyEngine(
        st(
          options: o,
          hands: ['2H 3H 4H 5H 6H 7H 8H 9H TH JH QH KH AH 8S 5H', 'KD 5C', '2D 3D', 'X1 AS'],
          table: [m('5S 6S 7S', 1)],
          opened: [false, true, false, true],
        ),
      );
      e.apply(
        RummyMove.finish(
          melds: [c('2H 3H 4H 5H 6H 7H'), c('8H 9H TH JH QH KH AH')],
          layoffs: [RummyLayoff(p('8S'), 0)],
          discard: p('5H'),
        ),
      );
      final r = e.state.results.single;
      expect(r.handFinish, isTrue);
      expect(r.multiplier, 1);
      expect(r.points, [-60, 30, 200, 52]);
    });

    test('… and a heart laid off on an older heart meld keeps the one-suit bonus', () {
      const o = RummyOptions(fullHandOwnMeldsOnly: false, bonusOneSuit: true);
      final e = RummyEngine(
        st(
          options: o,
          hands: ['2H 3H 4H 5H 6H 7H 8H 9H TH JH QH KH AH 8C 5H', 'KD 5C', '2D 3D', 'X1 AS'],
          table: [m('8S 8H 8D', 1)],
          opened: [false, true, false, true],
        ),
      );
      e.apply(
        RummyMove.finish(
          melds: [c('2H 3H 4H 5H 6H 7H'), c('8H 9H TH JH QH KH AH')],
          layoffs: [RummyLayoff(p('8C'), 0)],
          discard: p('5H'),
        ),
      );
      expect(e.state.results.single.multiplier, 1, reason: '8♣ is not a heart');
      final hearts = RummyEngine(
        st(
          options: o,
          hands: ['2H 3H 4H 5H 6H 7H 8H 9H TH JH QH KH AH 9H 5H', 'KD 5C', '2D 3D', 'X1 AS'],
          table: [m('TH JH QH', 1)],
          opened: [false, true, false, true],
        ),
      );
      hearts.apply(
        RummyMove.finish(
          melds: [c('2H 3H 4H 5H 6H 7H'), c('8H 9H TH JH QH KH AH')],
          layoffs: [RummyLayoff(p('9H'), 0)],
          discard: p('5H'),
        ),
      );
      expect(hearts.state.results.single.multiplier, 4);
    });

    test('the cards laid on older melds this turn survive a save in the middle of the turn', () {
      const o = RummyOptions(fullHandOwnMeldsOnly: false, bonusOneSuit: true);
      final e = RummyEngine(
        st(
          options: o,
          hands: ['2H 3H 4H 5H 6H 7H 8H 9H TH JH QH KH AH 8S 5H', 'KD 5C', '2D 3D', 'X1 AS'],
          table: [m('5S 6S 7S', 1)],
          opened: [false, true, false, true],
        ),
      );
      e.apply(RummyMove.open([c('2H 3H 4H 5H 6H 7H'), c('8H 9H TH JH QH KH AH')]));
      e.apply(RummyMove.layoff(p('8S'), 0));
      final json = jsonDecode(jsonEncode(e.toJson())) as Map<String, Object?>;
      expect(json['oldMeldCards'], ['8S']);
      final back = RummyEngine.fromJson(json)..apply(RummyMove.discard(p('5H')));
      expect(back.state.results.single.handFinish, isTrue);
      expect(back.state.results.single.multiplier, 1);
      // A save from before this field loads with none.
      final old = Map.of(json)..remove('oldMeldCards');
      expect(RummyEngine.fromJson(old).state.oldMeldCards, isEmpty);
    });
  });

  group('engine consistency (seeded self-play)', () {
    const kits = {
      'hand': RummyOptions.hand(),
      'konkan': RummyOptions.konkan(),
      'options': RummyOptions(
        discardUse: RummyDiscardUse.any,
        setWildSwap: RummySetWildSwap.anyMissingSuit,
        swappedWildMustBeUsed: true,
        wildIndicator: true,
      ),
    };
    for (final k in kits.entries) {
      test('${k.key}: every listed move validates; every lay-down that validates is listed and leaves valid melds', () {
        for (var seed = 1; seed <= 2; seed++) {
          final e = RummyEngine.newMatch(options: k.value, seed: seed);
          final rng = CardRng(seed);
          final deck = e.state.fullDeck().length;
          for (var n = 0; n < 900 && !e.isOver; n++) {
            final s = e.state;
            final seat = e.currentPlayer!;
            final legal = e.legalMoves(seat);
            final listed = <String>{};
            for (final mv in legal) {
              expect(e.validate(mv), isNull, reason: '$mv');
              final w = s.copy();
              const RummyRules().apply(w, mv);
              expect(w.cardsInPlay().length, deck);
              if (w.dealNumber == s.dealNumber) {
                for (final t in w.table) {
                  expect(meldProblem(w, t), isNull, reason: '$mv → $t');
                }
              }
              listed.add(outcome(w, seat));
            }
            if (s.phase == RummyPhase.play) {
              for (final mv in tries(s, seat)) {
                if (e.validate(mv) != null) continue;
                final w = s.copy();
                const RummyRules().apply(w, mv);
                if (mv.kind == RummyMoveKind.discard) {
                  expect(legal, contains(mv));
                } else {
                  expect(s.opened[seat] || mv.kind == RummyMoveKind.meld, isTrue);
                  expect(listed, contains(outcome(w, seat)), reason: 'validated but not listed: $mv');
                  for (final t in w.table) {
                    expect(meldProblem(w, t), isNull, reason: '$mv → $t');
                  }
                }
              }
            }
            final level = seat.isEven ? AiLevel.medium : AiLevel.easy;
            e.apply(const RummyAi().chooseMove(s, seat, level, rng, AiBudget.phone));
          }
        }
      });
    }

    test('the top discard is offered exactly when an opening or a one-turn finish can use it', () {
      bool exhaustive(RummyState s, List<PlayingCard> hand, PlayingCard must) {
        final cands = s.meldRules.candidates(hand);
        var found = false;
        searchPlans(
          hand,
          cands,
          (p) {
            found = RummyRules.openingError(s, p, must) == null;
            return !found;
          },
          maxCards: hand.length - 1,
          nodeCap: 1 << 30,
        );
        if (!found) {
          coverPlans(hand, cands, 1, (plan, left) {
            found = RummyRules.planUsesMust(s, plan, must);
            return !found;
          }, nodeCap: 1 << 30);
        }
        return found;
      }

      var offered = 0;
      for (var seed = 1; seed <= 600; seed++) {
        // Dense hands (six ranks), where the plan search has the most to do.
        final lo = 2 + seed % 7;
        final deck = buildDeck(
          copies: 2,
          jokers: 2,
        ).where((x) => x.isJoker || (x.rank.value >= lo && x.rank.value < lo + 6)).toList();
        CardRng(seed).shuffle(deck);
        final hand = deck.sublist(0, 14)..sort();
        final s = st(hands: ['', '9D', '3H', '4S'], discard: deck[14].id, phase: RummyPhase.draw)..hands[0] = hand;
        final can = RummyRules.canTakeDiscard(s, 0, deck[14]);
        if (can) offered++;
        expect(can, exhaustive(s, [...hand, deck[14]]..sort(), deck[14]), reason: 'seed $seed $hand + ${deck[14]}');
      }
      expect(offered, greaterThan(100));
    });
  });
}

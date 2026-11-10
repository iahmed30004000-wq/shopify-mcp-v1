// The shared rummy core of Hand and Konkan: melds with wild cards (one wild
// per meld, the wild's place in a run, lay-offs, swaps), candidate search,
// moves, options and state JSON (including saves from before the Jordanian
// defaults).
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/cinema/rules/cards/cards.dart';

List<PlayingCard> c(String ids) => PlayingCard.list(ids);
PlayingCard p(String id) => PlayingCard.parse(id);
const rules = MeldRules();
Meld m(String ids, {int owner = 1, bool low = false}) => rules.arrange(c(ids), owner: owner, wildLow: low)!;

void main() {
  group('melds', () {
    test('runs and sets; the ace is low or high, never round the corner', () {
      expect((m('5H 6H 7H').kind, m('5H 6H 7H').value), (MeldKind.run, 18));
      expect((m('QS KS AS').low, m('QS KS AS').high, m('QS KS AS').value), (12, 14, 31));
      expect(rules.arrange(c('KS AS 2S')), isNull);
      expect((m('7H 7S 7D').kind, m('7H 7S 7D').value), (MeldKind.set, 21));
      expect(m('AH AS AD').value, 33);
      expect(rules.arrange(c('7H 7H 7S')), isNull, reason: 'two 7♥ from the double pack');
      expect(rules.arrange(c('7H 7S 7D 7C X0')), isNull, reason: 'a set has at most four cards');
      expect(rules.arrange(c('5H 6S 7H')), isNull);
      expect(rules.arrange(c('5H 6H')), isNull);
      expect(m('2C 3C 4C 5C 6C 7C 8C 9C TC JC QC KC AC').cards.length, 13);
    });

    test('the ace counts 11 in the opening wherever it is (A-2-3 = 16)', () {
      expect((m('AS 2S 3S').low, m('AS 2S 3S').value), (1, 16));
      expect(m('X0 2D 3D', low: true).value, 16, reason: 'wild as A♦');
      expect(m('2D 3D X0').value, 9, reason: 'wild as 4♦');
      const low1 = MeldRules(aceLowValue: 1);
      expect(low1.arrange(c('AS 2S 3S'))!.value, 6);
      const high10 = MeldRules(aceHighValue: 10);
      expect(high10.arrange(c('QS KS AS'))!.value, 30);
      expect(high10.arrange(c('AH AS AD'))!.value, 33, reason: 'an ace in a set is 11');
    });

    test('at most one wild per meld, always at least two naturals', () {
      expect(rules.arrange(c('5H X0 7H X1 9H')), isNull);
      expect(rules.arrange(c('5H 6H 7H X0 X1')), isNull);
      expect(rules.arrange(c('5H X0 X1')), isNull);
      expect(rules.arrange(c('7H X0 X1')), isNull);
      expect(m('5H X0 7H').cards, c('5H X0 7H'));
      expect(m('7H 7S X0').kind, MeldKind.set);
      expect(m('7H 7S X0').wilds, 1);
      // The old rule (fewer wilds than naturals) is still available.
      const legacy = MeldRules(maxWilds: 4, setSwapNeedsBoth: false);
      expect(legacy.arrange(c('5H 6H 7H X0 X1'))!.cards.length, 5);
      expect(legacy.arrange(c('5H 6H X0 X1')), isNull);
    });

    test('an end wild goes where the player puts it and stays that card', () {
      final high = m('5H 6H X0');
      final low = m('5H 6H X0', low: true);
      expect((high.low, high.high, high.value), (5, 7, 18));
      expect((low.low, low.high, low.value), (4, 6, 15));
      expect(high.wildPlacedLow, isFalse);
      expect(low.wildPlacedLow, isTrue);
      // The high end closed: the wild can only go low.
      expect(m('KS AS X0').low, 12);
      expect(m('KS AS X0').wildPlacedLow, isFalse);
      // After placement the wild is 7♥.
      expect(rules.withCard(high, p('8H'))!.high, 8);
      expect(rules.withCard(high, p('4H'))!.low, 4);
      expect(rules.withCard(high, p('3H')), isNull, reason: 'the wild cannot be re-read as 4♥');
      expect(rules.swap(high, [p('4H')]), isNull);
      expect(rules.swap(high, [p('7H')])!.$1.cards, c('5H 6H 7H'));
      // Candidates offer both places.
      final both = rules.candidates(c('5H 6H X0')).where((x) => x.kind == MeldKind.run).map((x) => x.low).toSet();
      expect(both, {4, 5});
    });

    test('lay-offs on runs and sets, a wild at either end', () {
      final run = m('5H 6H 7H');
      expect(rules.withCard(run, p('8H'))!.high, 8);
      expect(rules.withCard(run, p('4H'))!.low, 4);
      expect(rules.withCard(run, p('9H')), isNull);
      expect(rules.withCard(run, p('8S')), isNull);
      expect(rules.withCard(m('QS KS AS'), p('JS'))!.low, 11);
      expect(rules.withCard(m('QS KS AS'), p('2S')), isNull);
      expect(rules.withCard(m('7H 7S 7D'), p('7C'))!.cards.length, 4);
      expect(rules.withCard(m('7H 7S 7D'), p('7H')), isNull);
      expect(rules.withCard(m('7H 7S 7D'), PlayingCard.joker())!.wilds, 1);
      expect(rules.withCard(run, PlayingCard.joker())!.high, 8);
      expect(rules.withCard(run, PlayingCard.joker(), atLow: true)!.low, 4);
      expect(rules.withCard(m('5H X0 7H'), PlayingCard.joker(1)), isNull, reason: 'one wild per meld');
      expect(rules.withCard(m('7H 7S X0'), p('7D'))!.cards, c('7D 7H 7S X0'));
    });

    test('wild swaps: exact card in a run; the missing suit(s) in a set', () {
      final (swapped, joker) = rules.swap(m('5H X0 7H'), [p('6H')])!;
      expect(swapped.cards, c('5H 6H 7H'));
      expect(swapped.wilds, 0);
      expect(joker, PlayingCard.joker());
      expect(rules.swap(m('5H X0 7H'), [p('6S')]), isNull);
      // Three naturals and a wild: the missing suit frees it.
      expect(rules.swap(m('KS KH KD X0'), [p('KC')])!.$1.cards, c('KC KD KH KS'));
      expect(rules.swap(m('KS KH KD X0'), [p('KS')]), isNull);
      // Two naturals and a wild: both missing suits at once.
      expect(rules.swap(m('7H 7S X0'), [p('7D')]), isNull);
      final (four, freed) = rules.swap(m('7H 7S X0'), [p('7D'), p('7C')])!;
      expect(four.cards, c('7C 7D 7H 7S'));
      expect(freed, PlayingCard.joker());
      const either = MeldRules(setSwapNeedsBoth: false);
      expect(either.swap(m('7H 7S X0'), [p('7D')])!.$1.cards, c('7D 7H 7S'));
      expect(rules.swap(m('7H 7S X0'), [p('7H')]), isNull);
    });

    test('candidates keep each joker apart so two wild melds can be planned', () {
      final hand = c('5H 6H X0 9C 9D X1 2S');
      final cands = rules.candidates(hand);
      expect(cands.any((x) => x.cards.contains(PlayingCard.joker(1))), isTrue);
      final plan = bestPlan(hand, rules, keep: 1);
      expect(plan.melds.length, 2);
      expect(plan.cardCount, 6);
    });

    test('candidate melds and the best plan of a hand', () {
      final h = c('5H 6H 7H 8H 9C 9D 9S X0 2C KD');
      final cands = rules.candidates(h);
      expect(cands.any((x) => x.key == m('5H 6H 7H 8H').key), isTrue);
      expect(cands.any((x) => x.key == m('9C 9D 9S').key), isTrue);
      final plan = bestPlan(h, rules, keep: 1);
      expect(plan.value, greaterThanOrEqualTo(26 + 27));
      expect(plan.cardCount, lessThanOrEqualTo(h.length - 1));
    });

    test('cover search finds every way to go out (one card left over)', () {
      final hand = c('2C 3C 4C 7H 7S 7D KD');
      final found = <String>[];
      coverPlans(hand, rules.candidates(hand), 1, (plan, left) {
        found.add('${plan.key}/${left.single}');
        return true;
      });
      expect(found, contains('${MeldPlan([m('2C 3C 4C'), m('7D 7H 7S')]).key}/KD'));
    });

    test('indicator: the aces of its suit are wild, the jokers natural aces of that suit', () {
      const ind = MeldRules(wildAceSuit: Suit.hearts);
      expect(ind.isWild(p('AH')), isTrue);
      expect(ind.isWild(p('AS')), isFalse);
      expect(ind.isWild(PlayingCard.joker()), isFalse);
      expect(ind.arrange(c('5S AH 7S'))!.wilds, 1, reason: 'A♥ stands for 6♠');
      final aces = ind.arrange(c('AS AD X0'))!;
      expect((aces.kind, aces.wilds), (MeldKind.set, 0), reason: 'the joker is the natural A♥');
      expect(ind.arrange(c('X0 2H 3H'))!.low, 1);
      expect(ind.arrange(c('QH KH X0'))!.high, 14);
      expect(ind.wildUsedAsAce(ind.arrange(c('AH 2H 3H'), wildLow: true)!, p('AH')), isTrue);
      expect(ind.wildUsedAsAce(ind.arrange(c('AH 2H 3H'))!, p('AH')), isFalse, reason: 'there it is 4♥');
      expect(ind.wildUsedAsAce(ind.arrange(c('AS AD AH'))!, p('AH')), isTrue);
      expect(ind.wildUsedAsAce(ind.arrange(c('AS AD X0 AH'))!, p('AH')), isFalse, reason: 'A♥ is taken by the joker');
    });
  });

  group('moves', () {
    test('lay-downs are canonical (order of melds and cards), the wild place counts', () {
      expect(RummyMove.open([c('7H 5H 6H'), c('KS QS AS')]), RummyMove.open([c('AS KS QS'), c('5H 6H 7H')]));
      expect(RummyMove.meld(c('5H 6H X0')), isNot(RummyMove.meld(c('5H 6H X0'), wildLow: true)));
      expect(
        RummyMove.open([c('5H 6H X0'), c('QS KS AS')], wildLow: [true, false]),
        RummyMove.open([c('QS KS AS'), c('5H 6H X0')], wildLow: [false, true]),
      );
      expect(RummyMove.swapJoker(p('7D'), 2, card2: p('7C')), RummyMove.swapJoker(p('7C'), 2, card2: p('7D')));
    });

    test('every kind of move round-trips through JSON', () {
      final moves = [
        const RummyMove.drawStock(),
        const RummyMove.takeDiscard(),
        RummyMove.open([c('QS KS AS'), c('5H 6H X0')], wildLow: [false, true]),
        RummyMove.meld(c('9C 9D 9S')),
        RummyMove.layoff(PlayingCard.joker(1), 3, atLow: true),
        RummyMove.swapJoker(p('7D'), 1, card2: p('7C')),
        RummyMove.discard(p('KD')),
        RummyMove.finish(
          melds: [c('2C 3C 4C'), c('7H 7S 7D')],
          layoffs: [RummyLayoff(p('8H'), 0), RummyLayoff(PlayingCard.joker(), 1, atLow: true)],
          discard: p('KD'),
        ),
        const RummyMove.callRedeal(),
        const RummyMove.keepHand(),
      ];
      for (final mv in moves) {
        final back = RummyMove.fromJson(jsonDecode(jsonEncode(mv.toJson())) as Map<String, Object?>);
        expect(back, mv);
        expect(back.hashCode, mv.hashCode);
      }
    });
  });

  group('options', () {
    test('the defaults are Hand as played in Jordan; presets', () {
      const d = RummyOptions();
      expect(d, const RummyOptions.hand());
      expect((d.decks, d.jokers, d.handSize, d.openingThreshold), (2, 2, 14, 51));
      expect((d.jokerPenalty, d.acePenalty, d.notOpenedPenalty), (15, 11, 100));
      expect((d.winnerScore, d.handWinnerScore, d.handMultiplier), (-30, -60, 2));
      expect((d.aceLowOpeningValue, d.aceHighOpeningValue, d.maxWildsPerMeld), (11, 11, 1));
      expect(
        (d.discardUse, d.setWildSwap, d.dealerRule),
        (RummyDiscardUse.newMeldOnly, RummySetWildSwap.bothMissing, RummyDealerRule.loserDeals),
      );
      expect((d.starterFirstTurnDiscardOnly, d.noGoOutOnFirstTurn, d.oneTurnFinishWaivesThreshold), (true, true, true));
      expect((d.fullHandOwnMeldsOnly, d.voidRoundsCount, d.tieBreak), (true, false, RummyTieBreak.extraRounds));
      expect(
        (d.matchEnd, d.rounds, d.stockEnd, d.maxStockRecycles),
        (RummyMatchEnd.rounds, 5, RummyStockEnd.reshuffle, 2),
      );
      expect((d.partnership, d.partnerOfWinnerPays, d.wildIndicator, d.pairsRedeal), (false, false, false, true));
      const k = RummyOptions.konkan();
      expect((k.variant, k.winnerScore, k.handWinnerScore, k.jokerPenalty), (RummyVariant.konkan, 0, 0, 25));
      expect((k.matchEnd, k.eliminationScore), (RummyMatchEnd.elimination, 301));
      expect(const RummyOptions.handPartnership().partnership, isTrue);
      const ind = RummyOptions.handIndicator();
      expect((ind.wildIndicator, ind.rounds, ind.stockEnd), (true, 7, RummyStockEnd.voidAtPlayers));
    });

    test('unsupported combinations are refused', () {
      expect(const RummyOptions().invalidReason, isNull);
      expect(const RummyOptions.konkan().invalidReason, isNull);
      expect(const RummyOptions(players: 3, partnership: true).invalidReason, 'partnershipNeedsFourPlayers');
      expect(
        const RummyOptions(partnership: true, matchEnd: RummyMatchEnd.elimination).invalidReason,
        'partnershipWithElimination',
      );
      expect(const RummyOptions(maxWildsPerMeld: 2).invalidReason, 'bothMissingNeedsOneWild');
      expect(const RummyOptions(wildIndicator: true, jokers: 4).invalidReason, 'indicatorNeedsTwoJokers');
      expect(
        () => RummyEngine.newMatch(options: const RummyOptions(players: 3, partnership: true), seed: 1),
        throwsArgumentError,
      );
    });

    test('options round-trip through JSON; copyWith', () {
      const o = RummyOptions(
        players: 3,
        wildIndicator: true,
        openingMustBeatPrevious: true,
        discardUse: RummyDiscardUse.any,
        setWildSwap: RummySetWildSwap.anyMissingSuit,
        stockEnd: RummyStockEnd.flipNoShuffle,
        tieBreak: RummyTieBreak.shared,
        dealerRule: RummyDealerRule.rotate,
        bonusOneSuit: true,
      );
      expect(RummyOptions.fromJson(jsonDecode(jsonEncode(o.toJson())) as Map<String, Object?>), o);
      expect(o.copyWith(players: 4).players, 4);
      expect(o.copyWith(players: 4).wildIndicator, isTrue);
    });

    test('a save from before the Jordanian defaults keeps its old rules', () {
      final old = {
        'variant': 'hand',
        'players': 4,
        'decks': 2,
        'jokers': 4,
        'handSize': 14,
        'openingThreshold': 51,
        'openingRequiresRun': false,
        'discardMustBeUsed': true,
        'winnerScore': -30,
        'handWinnerScore': -60,
        'handMultiplier': 2,
        'notOpenedPenalty': 100,
        'jokerPenalty': 25,
        'acePenalty': 11,
        'jokerSwap': true,
        'matchEnd': 'rounds',
        'rounds': 5,
        'targetScore': 500,
        'maxStockRecycles': 2,
      };
      final o = RummyOptions.fromJson(old);
      expect((o.jokers, o.jokerPenalty, o.maxWildsPerMeld, o.aceLowOpeningValue), (4, 25, 4, 1));
      expect(
        (o.discardUse, o.setWildSwap, o.dealerRule, o.tieBreak),
        (RummyDiscardUse.any, RummySetWildSwap.anyMissingSuit, RummyDealerRule.rotate, RummyTieBreak.shared),
      );
      expect((o.starterFirstTurnDiscardOnly, o.noGoOutOnFirstTurn, o.fullHandOwnMeldsOnly), (false, false, false));
      expect((o.voidRoundsCount, o.pairsRedeal, o.oneTurnFinishWaivesThreshold), (true, false, false));
      expect(o.invalidReason, isNull);
    });
  });

  group('state', () {
    test('an old saved match (4 jokers, old keys, no new state) loads and plays to the end', () {
      final e = RummyEngine.newMatch(options: const RummyOptions.hand(), seed: 11);
      final json = jsonDecode(jsonEncode(e.toJson())) as Map<String, Object?>;
      // Rewrite it as the old engine saved it.
      final opts = (json['options']! as Map).cast<String, Object?>();
      for (final k in opts.keys.toList()) {
        if (!{
          'variant',
          'players',
          'decks',
          'jokers',
          'handSize',
          'openingThreshold',
          'openingRequiresRun',
          'winnerScore',
          'handWinnerScore',
          'handMultiplier',
          'notOpenedPenalty',
          'jokerPenalty',
          'acePenalty',
          'jokerSwap',
          'matchEnd',
          'rounds',
          'targetScore',
          'maxStockRecycles',
        }.contains(k)) {
          opts.remove(k);
        }
      }
      opts['discardMustBeUsed'] = true;
      opts['jokers'] = 4;
      opts['jokerPenalty'] = 25;
      json['options'] = opts;
      // Two more jokers in the stock, as in a 108-card deal.
      json['stock'] = [...(json['stock']! as List), 'X2', 'X3'];
      for (final k in [
        'starter',
        'tableAtTurnStart',
        'usedOldMelds',
        'turnsTaken',
        'pendingWilds',
        'highestOpening',
        'indicator',
        'eliminated',
        'eliminatedAt',
        'voidStreak',
        'tieBreakRounds',
      ]) {
        json.remove(k);
      }
      json['phase'] = 'play';
      final restored = RummyEngine.fromJson(json);
      expect(restored.state.options.jokers, 4);
      expect(restored.state.fullDeck().length, 108);
      expect(restored.state.cardsInPlay().length, 108);
      expect(restored.state.turnsTaken, [1, 1, 1, 1]);
      final rng = CardRng(3);
      var moves = 0;
      while (!restored.isOver && moves < 20000) {
        final seat = restored.currentPlayer!;
        final mv = const RummyAi().chooseMove(restored.state, seat, AiLevel.medium, rng, AiBudget.phone);
        expect(restored.validate(mv), isNull);
        restored.apply(mv);
        moves++;
      }
      expect(restored.isOver, isTrue);
    });

    test('the state round-trips through JSON mid-round', () {
      final e = RummyEngine.newMatch(options: const RummyOptions.handIndicator(), seed: 4);
      final rng = CardRng(1);
      for (var i = 0; i < 60; i++) {
        e.apply(const RummyAi().chooseMove(e.state, e.currentPlayer!, AiLevel.medium, rng, AiBudget.phone));
      }
      final json = jsonEncode(e.toJson());
      final back = RummyEngine.fromJson(jsonDecode(json) as Map<String, Object?>);
      expect(jsonEncode(back.toJson()), json);
      expect(back.state.indicator, e.state.indicator);
      expect(back.state.meldRules.wildAceSuit, e.state.meldRules.wildAceSuit);
    });
  });
}

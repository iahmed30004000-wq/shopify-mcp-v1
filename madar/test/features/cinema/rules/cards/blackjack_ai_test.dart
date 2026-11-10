// Blackjack 21: the basic-strategy chart (§5.8) cell by cell, the advisor,
// the three AI seats (B-70), their fairness (B-76), seeded self-play of
// every rule set at every level, and the strength test (B-77).
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/cinema/rules/cards/blackjack/blackjack_ai.dart';
import 'package:madar/features/cinema/rules/cards/blackjack/blackjack_rules.dart';
import 'package:madar/features/cinema/rules/cards/blackjack/blackjack_state.dart';
import 'package:madar/features/cinema/rules/cards/blackjack/blackjack_strategy.dart';
import 'package:madar/features/cinema/rules/cards/core/card_game.dart';
import 'package:madar/features/cinema/rules/cards/core/card_rng.dart';
import 'package:madar/features/cinema/rules/cards/core/playing_card.dart';

import 'support.dart';

const ups = [2, 3, 4, 5, 6, 7, 8, 9, 10, 11];

const codeOf = {
  'H': BlackjackChartCode.hit,
  'S': BlackjackChartCode.stand,
  'D': BlackjackChartCode.doubleOrHit,
  'Ds': BlackjackChartCode.doubleOrStand,
  'P': BlackjackChartCode.split,
  'Rh': BlackjackChartCode.surrenderOrHit,
  'Rs': BlackjackChartCode.surrenderOrStand,
  'Rp': BlackjackChartCode.surrenderOrSplit,
};

/// A card of blackjack value [v] (11 = ace) for building hands.
PlayingCard card(int v, [Suit suit = Suit.spades]) => PlayingCard(
  suit,
  switch (v) {
    1 || 11 => Rank.ace,
    10 => Rank.king,
    _ => Rank.fromValue(v),
  },
);

/// The chart row [row] (ten cells, dealer 2…A) checked against [code].
void expectRow(String name, String row, BlackjackChartCode Function(int up) code) {
  final cells = row.split(' ');
  expect(cells.length, 10, reason: name);
  for (var i = 0; i < 10; i++) {
    expect(code(ups[i]), codeOf[cells[i]], reason: '$name vs ${ups[i] == 11 ? 'A' : ups[i]}');
  }
}

BlackjackEngine table(String draw, {BlackjackOptions options = const BlackjackOptions(burnCard: false)}) =>
    BlackjackEngine(BlackjackState.custom(options: options, drawOrder: PlayingCard.list(draw)));

Kit blackjackKit(String name, BlackjackOptions options) => Kit(
  name,
  (seed) => BlackjackEngine.newMatch(seed: seed, options: options),
  BlackjackEngine.fromJson,
  const BlackjackAi(),
);

void main() {
  const s17 = BlackjackOptions();
  const h17 = BlackjackOptions(dealerHitsSoft17: true);

  group('§5.8 chart: 4–8 packs, S17, double after split, peek (B9 tables)', () {
    test('hard totals', () {
      const hard = {
        5: 'H H H H H H H H H H',
        6: 'H H H H H H H H H H',
        7: 'H H H H H H H H H H',
        8: 'H H H H H H H H H H',
        9: 'H D D D D H H H H H',
        10: 'D D D D D D D D H H',
        11: 'D D D D D D D D D H',
        12: 'H H S S S H H H H H',
        13: 'S S S S S H H H H H',
        14: 'S S S S S H H H H H',
        15: 'S S S S S H H H Rh H',
        16: 'S S S S S H H Rh Rh Rh',
        17: 'S S S S S S S S S S',
        18: 'S S S S S S S S S S',
        20: 'S S S S S S S S S S',
      };
      for (final e in hard.entries) {
        expectRow('hard ${e.key}', e.value, (u) => BlackjackStrategy.hardCode(e.key, u, s17));
      }
    });

    test('soft totals', () {
      const soft = {
        13: 'H H H D D H H H H H',
        14: 'H H H D D H H H H H',
        15: 'H H D D D H H H H H',
        16: 'H H D D D H H H H H',
        17: 'H D D D D H H H H H',
        18: 'S Ds Ds Ds Ds S S H H H',
        19: 'S S S S S S S S S S',
        20: 'S S S S S S S S S S',
      };
      for (final e in soft.entries) {
        expectRow('soft ${e.key}', e.value, (u) => BlackjackStrategy.softCode(e.key, u, s17));
      }
    });

    test('pairs (a pair the chart does not split is played as its total)', () {
      const pairs = {
        2: 'P P P P P P H H H H',
        3: 'P P P P P P H H H H',
        4: 'H H H P P H H H H H',
        5: 'D D D D D D D D H H',
        6: 'P P P P P H H H H H',
        7: 'P P P P P P H H H H',
        8: 'P P P P P P P P P P',
        9: 'P P P P P S P P S S',
        10: 'S S S S S S S S S S',
        1: 'P P P P P P P P P P',
      };
      for (final e in pairs.entries) {
        final h = BlackjackHand(cards: [card(e.key), card(e.key, Suit.hearts)]);
        expectRow(
          'pair ${e.key}',
          e.value,
          (u) => BlackjackStrategy.chartCode(h, card(u, Suit.clubs), s17, canSplit: true),
        );
      }
    });

    test('H17 changes: 11 vs A D, A7 vs 2 Ds, A8 vs 6 Ds, 15 vs A Rh, 17 vs A Rs, 8-8 vs A Rp', () {
      expect(BlackjackStrategy.hardCode(11, 11, h17), BlackjackChartCode.doubleOrHit);
      expect(BlackjackStrategy.softCode(18, 2, h17), BlackjackChartCode.doubleOrStand);
      expect(BlackjackStrategy.softCode(19, 6, h17), BlackjackChartCode.doubleOrStand);
      expect(BlackjackStrategy.hardCode(15, 11, h17), BlackjackChartCode.surrenderOrHit);
      expect(BlackjackStrategy.hardCode(17, 11, h17), BlackjackChartCode.surrenderOrStand);
      expect(BlackjackStrategy.pairCode(8, 11, h17), BlackjackChartCode.surrenderOrSplit);
      // Unchanged under S17.
      expect(BlackjackStrategy.hardCode(15, 11, s17), BlackjackChartCode.hit);
      expect(BlackjackStrategy.hardCode(17, 11, s17), BlackjackChartCode.stand);
      expect(BlackjackStrategy.pairCode(8, 11, s17), BlackjackChartCode.split);
    });

    test('no double after split: 2-2/3-3 vs 4–7, 4-4 never, 6-6 vs 3–6', () {
      const noDas = BlackjackOptions(doubleAfterSplit: false);
      String row(int pair) => [
        for (final u in ups) BlackjackStrategy.pairCode(pair, u, noDas) == BlackjackChartCode.split ? 'P' : '-',
      ].join();
      expect(row(2), '--PPPP----');
      expect(row(3), '--PPPP----');
      expect(row(4), '----------');
      expect(row(6), '-PPPP-----');
      expect(row(7), 'PPPPPP----');
    });

    test('European table, all hands lost: 11 vs 10/A hit, 8-8 vs 10/A hit, A-A vs A hit; originalOnly keeps the peek chart', () {
      const eu = BlackjackOptions.european();
      const euOriginal = BlackjackOptions.european(originalOnly: true);
      expect(BlackjackStrategy.hardCode(11, 10, eu), BlackjackChartCode.hit);
      expect(BlackjackStrategy.hardCode(11, 11, eu), BlackjackChartCode.hit);
      expect(BlackjackStrategy.hardCode(11, 9, eu), BlackjackChartCode.doubleOrHit);
      expect(BlackjackStrategy.pairCode(8, 10, eu), isNull);
      expect(BlackjackStrategy.pairCode(8, 11, eu), isNull);
      expect(BlackjackStrategy.pairCode(8, 9, eu), BlackjackChartCode.split);
      expect(BlackjackStrategy.pairCode(1, 11, eu), isNull);
      expect(BlackjackStrategy.hardCode(11, 10, euOriginal), BlackjackChartCode.doubleOrHit);
      expect(BlackjackStrategy.pairCode(8, 10, euOriginal), BlackjackChartCode.split);
      // 8-8 vs 10 on the European table: hard 16, no surrender there → hit.
      final e = table('8S TD 8H', options: eu.copyWith(burnCard: false));
      e.apply(BlackjackMove.deal);
      expect(e.advice()!.action, BlackjackAction.hit);
    });
  });

  group('the advisor (B-75) resolves each cell to a legal action', () {
    test('after a hit D → H, Ds → S, Rh → H', () {
      final e = table('5S 6D 3H 7C 3S'); // 5 3 = 8, hit 3 = 11 in three cards
      e.apply(BlackjackMove.deal);
      e.apply(BlackjackMove.hit);
      final a = e.advice()!;
      expect(a.code, BlackjackChartCode.doubleOrHit);
      expect(a.action, BlackjackAction.hit);

      final soft = table('AS 4D 2H 7C 5S'); // A 2 + 5 = soft 18 vs 4
      soft.apply(BlackjackMove.deal);
      soft.apply(BlackjackMove.hit);
      expect(soft.advice()!.code, BlackjackChartCode.doubleOrStand);
      expect(soft.advice()!.action, BlackjackAction.stand);

      const late = BlackjackOptions(burnCard: false, surrender: BlackjackSurrender.late);
      final sur = table('TS TD 6H 9C', options: late);
      sur.apply(BlackjackMove.deal);
      expect(sur.advice()!.action, BlackjackAction.surrender);
      final noSur = table('8S TD 3H 9C 5S', options: late); // 11 + 5 = 16 in three cards
      noSur.apply(BlackjackMove.deal);
      noSur.apply(BlackjackMove.hit);
      expect(noSur.advice()!.code, BlackjackChartCode.surrenderOrHit);
      expect(noSur.advice()!.action, BlackjackAction.hit);
    });

    test('a pair that may not split is played as its total; nineToEleven turns a soft double into a hit', () {
      final e = table('8S 6D 8H TC 8D 8C 8S 2H');
      e.apply(BlackjackMove.deal);
      for (var i = 0; i < 3; i++) {
        expect(e.advice()!.action, BlackjackAction.split);
        e.apply(BlackjackMove.split);
      }
      // Four hands: 8-8 vs 6 is hard 16, stand.
      expect(e.advice()!.action, BlackjackAction.stand);
      final soft = table('AS 5D 4H 9C', options: const BlackjackOptions(doubleOn: BlackjackDoubleOn.nineToEleven));
      soft.apply(BlackjackMove.deal); // soft 15 vs 5: D, not allowed → H
      expect(soft.advice()!.action, BlackjackAction.hit);
    });

    test('1–2 packs: the same chart, marked approximate', () {
      final e = table('TS 9D 6H 7C', options: const BlackjackOptions(decks: 2, burnCard: false));
      e.apply(BlackjackMove.deal);
      expect(e.advice()!.approximate, isTrue);
      final f = table('TS 9D 6H 7C');
      f.apply(BlackjackMove.deal);
      expect(f.advice()!.approximate, isFalse);
      expect(BlackjackEngine.newMatch(seed: 1).advice(), isNull);
    });
  });

  group('AI seats (B-70)', () {
    const ai = BlackjackAi();
    BlackjackMove pick(BlackjackEngine e, AiLevel level, [int seed = 1]) =>
        ai.chooseMove(e.state, e.currentPlayer!, level, CardRng(seed), AiBudget.phone);

    test('every level deals between rounds', () {
      final e = BlackjackEngine.newMatch(seed: 1, options: const BlackjackOptions(sessionRounds: null));
      for (final level in AiLevel.values) {
        expect(pick(e, level), BlackjackMove.deal);
      }
    });

    test('easy plays like the dealer: hit to 16, stand on 17, never double, split or surrender', () {
      final hit16 = table('TS TD 6H 9C');
      hit16.apply(BlackjackMove.deal);
      expect(pick(hit16, AiLevel.easy), BlackjackMove.hit);
      final eleven = table('6S 6D 5H 9C');
      eleven.apply(BlackjackMove.deal);
      expect(pick(eleven, AiLevel.easy), BlackjackMove.hit);
      final eights = table('8S 6D 8H 9C');
      eights.apply(BlackjackMove.deal);
      expect(pick(eights, AiLevel.easy), BlackjackMove.hit);
      final seventeen = table('TS 6D 7H 9C');
      seventeen.apply(BlackjackMove.deal);
      expect(pick(seventeen, AiLevel.easy), BlackjackMove.stand);
      for (final (options, expected) in [
        (const BlackjackOptions(burnCard: false), BlackjackMove.stand),
        (const BlackjackOptions(burnCard: false, dealerHitsSoft17: true), BlackjackMove.hit),
      ]) {
        final soft17 = table('AS 9D 6H 9C', options: options);
        soft17.apply(BlackjackMove.deal);
        expect(pick(soft17, AiLevel.easy), expected);
      }
    });

    test('hard follows the chart exactly for the table options', () {
      final eleven = table('6S 6D 5H 9C');
      eleven.apply(BlackjackMove.deal);
      expect(pick(eleven, AiLevel.hard), BlackjackMove.doubleHand);
      final eights = table('8S TD 8H 9C');
      eights.apply(BlackjackMove.deal);
      expect(pick(eights, AiLevel.hard), BlackjackMove.split);
      final sur = table('TS TD 6H 9C', options: const BlackjackOptions(burnCard: false, surrender: BlackjackSurrender.late));
      sur.apply(BlackjackMove.deal);
      expect(pick(sur, AiLevel.hard), BlackjackMove.surrender);
    });

    test('medium plays like the dealer on about 15 % of its decisions', () {
      var differ = 0;
      var slipped = 0;
      for (var seed = 1; seed <= 400 && differ < 600; seed++) {
        final e = BlackjackEngine.newMatch(seed: seed, options: const BlackjackOptions(sessionRounds: 10));
        final rng = CardRng(seed + 1000);
        final probe = CardRng(seed + 1000);
        while (!e.isOver) {
          final p = e.currentPlayer!;
          final hard = ai.chooseMove(e.state, p, AiLevel.hard, CardRng(0), AiBudget.phone);
          final easy = ai.chooseMove(e.state, p, AiLevel.easy, CardRng(0), AiBudget.phone);
          final medium = ai.chooseMove(e.state, p, AiLevel.medium, rng, AiBudget.phone);
          if (e.state.phase == BlackjackPhase.playerTurn) {
            final slip = probe.nextDouble() < BlackjackAi.mediumSlipRate;
            expect(medium, slip ? easy : hard);
            if (hard != easy) {
              differ++;
              if (medium == easy) slipped++;
            }
          }
          e.apply(hard);
        }
      }
      final rate = slipped / differ;
      expect(rate, inInclusiveRange(0.08, 0.22));
    });

    test('B-76 fairness: re-dealing the hole card and the shoe never changes a decision', () {
      for (final options in [
        const BlackjackOptions(seats: 2),
        const BlackjackOptions.european(seats: 2),
        const BlackjackOptions(seats: 3, surrender: BlackjackSurrender.late, dealerHitsSoft17: true),
      ]) {
        final e = BlackjackEngine.newMatch(seed: 8, options: options);
        final rng = CardRng(2);
        var checked = 0;
        while (!e.isOver) {
          final seat = e.currentPlayer!;
          if (e.state.phase == BlackjackPhase.playerTurn) {
            for (var w = 0; w < 3; w++) {
              final world = ai.determinize(e.state, seat, CardRng(w * 13 + checked));
              expect(sortedCards(world.cardsInPlay()), sortedCards(e.state.cardsInPlay()));
              if (e.state.holeHidden) expect(world.dealerVisible, e.state.dealerVisible);
              for (final level in AiLevel.values) {
                final a = ai.chooseMove(e.state, seat, level, CardRng(9), AiBudget.phone);
                final b = ai.chooseMove(world, seat, level, CardRng(9), AiBudget.phone);
                expect(b, a);
              }
              expect(BlackjackStrategy.advise(world)?.action, BlackjackStrategy.advise(e.state)?.action);
            }
            checked++;
          }
          e.apply(ai.chooseMove(e.state, seat, AiLevel.medium, rng, AiBudget.phone));
        }
        expect(checked, greaterThan(20));
      }
    });
  });

  group('self-play: every rule set, every level, no illegal move, sessions end', () {
    final kits = {
      'jordan solo': (blackjackKit('jordan solo', const BlackjackOptions()), 1),
      'jordan 3 seats': (blackjackKit('jordan 3 seats', const BlackjackOptions(seats: 3)), 3),
      'european 3 seats': (blackjackKit('european 3 seats', const BlackjackOptions.european(seats: 3)), 3),
      'european originalOnly h17': (
        blackjackKit(
          'european originalOnly h17',
          const BlackjackOptions.european(seats: 2, originalOnly: true).copyWith(dealerHitsSoft17: true),
        ),
        2,
      ),
      'one pack, 3 seats, every split option': (
        blackjackKit(
          'one pack',
          const BlackjackOptions(
            decks: 1,
            penetration: 0.85,
            burnCard: false,
            seats: 3,
            resplitAces: true,
            hitSplitAces: true,
            surrender: BlackjackSurrender.late,
            doubleOn: BlackjackDoubleOn.nineToEleven,
            doubleAfterSplit: false,
            tally: BlackjackTally.winsOnly,
            blackjackBonus: 2,
            sessionRounds: 50,
          ),
        ),
        3,
      ),
      'continuous shuffle, 2 packs, coach': (
        blackjackKit(
          'continuous',
          const BlackjackOptions(
            decks: 2,
            continuousShuffle: true,
            seats: 2,
            advisor: BlackjackAdvisor.coach,
            autoStandOn21: false,
            splitTensByRankOnly: true,
            maxHands: 3,
            sessionRounds: 10,
          ),
        ),
        2,
      ),
    };
    for (final e in kits.entries) {
      final (kit, seats) = e.value;
      for (final level in AiLevel.values) {
        test('${e.key}: ${level.name}', () {
          for (var seed = 1; seed <= 3; seed++) {
            final r = playMatch(kit, seed, List.filled(seats, level), jsonEvery: seed == 1 ? 7 : 0);
            expect(r.winners, isNotEmpty);
          }
        });
      }
      test('${e.key}: mixed levels', () {
        playMatch(kit, 9, [for (var i = 0; i < seats; i++) AiLevel.values[i % 3]], jsonEvery: 5);
      });
    }

    test('deterministic replay: same seed and levels give the same session; the move log replays it', () {
      final kit = kits['jordan 3 seats']!.$1;
      const levels = [AiLevel.hard, AiLevel.medium, AiLevel.easy];
      final a = playMatch(kit, 42, levels);
      final b = playMatch(kit, 42, levels);
      expect(b.finalJson, a.finalJson);
      expect(b.moveLog, a.moveLog);
      final replay = kit.create(42);
      for (final mj in a.moveLog) {
        replay.apply(replay.moveFromJson(jsonDecode(mj) as Map<String, Object?>));
      }
      expect(jsonEncode(replay.toJson()), a.finalJson);
      expect(playMatch(kit, 43, levels).finalJson, isNot(a.finalJson));
    });
  });

  test('B-77 strength: over 20 000 hands on the same seeds hard beats easy by more than 0.05 points a hand', () {
    const ai = BlackjackAi();
    (double, int) run(AiLevel level) {
      var points = 0;
      var hands = 0;
      var seed = 1;
      while (hands < 20000) {
        final e = BlackjackEngine.newMatch(seed: seed, options: const BlackjackOptions(sessionRounds: 50));
        final rng = CardRng(seed * 31 + 7);
        seed++;
        while (!e.isOver) {
          e.apply(ai.chooseMove(e.state, e.currentPlayer!, level, rng, AiBudget.phone));
        }
        points += e.state.seats.first.points;
        hands += e.state.seats.first.handsPlayed;
      }
      return (points / hands, hands);
    }

    final (easy, easyHands) = run(AiLevel.easy);
    final (medium, _) = run(AiLevel.medium);
    final (hard, hardHands) = run(AiLevel.hard);
    // ignore: avoid_print
    print(
      'blackjack points per hand: easy ${easy.toStringAsFixed(4)} ($easyHands hands), '
      'medium ${medium.toStringAsFixed(4)}, hard ${hard.toStringAsFixed(4)} ($hardHands hands)',
    );
    expect(hard - easy, greaterThan(0.05));
    expect(hard, greaterThan(medium - 0.02));
  });

  test('the registry id falls back until CardGameId.blackjack exists; the JSON always says blackjack', () {
    final s = BlackjackState.newMatch(seed: 1);
    expect(s.toJson()['game'], 'blackjack');
    expect(CardGameId.values.contains(s.gameId), isTrue);
  });
}

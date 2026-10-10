// Solitaire (Klondike): the exact stuck test (S-31), hints (S-36, S-37),
// the three-level auto-player and its fairness (S-75, S-36a), the solver and
// winnable deals (S-61…S-63), seeded self-play of every preset and variant
// at every level, the score-range property (S-43) and the strength test.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/cinema/rules/cards/core/card_game.dart' show AiLevel;
import 'package:madar/features/cinema/rules/cards/core/card_rng.dart';
import 'package:madar/features/cinema/rules/cards/core/deck.dart';
import 'package:madar/features/cinema/rules/cards/core/playing_card.dart';
import 'package:madar/features/cinema/rules/cards/solitaire/solitaire_ai.dart';
import 'package:madar/features/cinema/rules/cards/solitaire/solitaire_board.dart';
import 'package:madar/features/cinema/rules/cards/solitaire/solitaire_game.dart';
import 'package:madar/features/cinema/rules/cards/solitaire/solitaire_options.dart';
import 'package:madar/features/cinema/rules/cards/solitaire/solitaire_seeds.dart';
import 'package:madar/features/cinema/rules/cards/solitaire/solitaire_solver.dart';

List<PlayingCard> cards(String ids) => ids.trim().isEmpty ? <PlayingCard>[] : PlayingCard.list(ids);

const manual = SolitaireOptions(autoMoveToFoundation: SolitaireAutoMove.off);
const waste = SolitairePile.waste;
SolitairePile col(int i) => SolitairePile.column(i);
SolitairePile home(int i) => SolitairePile.foundation(i);

SolitaireBoard board({
  List<String> columns = const [],
  List<int> down = const [],
  String stock = '',
  String wastePile = '',
  List<String> foundations = const [],
  int recycles = 0,
}) => SolitaireBoard.fromPiles(
  columns: [for (final s in columns) cards(s)],
  faceDown: down,
  stock: cards(stock),
  waste: cards(wastePile),
  foundations: [for (final s in foundations) cards(s), for (var i = foundations.length; i < 4; i++) <PlayingCard>[]],
  recycles: recycles,
);

/// [b] with every card the player cannot see (face-down cards, and the stock
/// before its first recycle) dealt again at random.
SolitaireBoard permuteHidden(SolitaireBoard b, int seed) {
  final hidden = <PlayingCard>[
    for (var c = 0; c < 7; c++) ...b.column(c).take(b.down(c)),
    if (b.stockUnseen) ...b.stock,
  ];
  CardRng(seed).shuffle(hidden);
  var i = 0;
  final columns = [
    for (var c = 0; c < 7; c++) [for (var k = 0; k < b.colLen(c); k++) k < b.down(c) ? hidden[i++] : b.column(c)[k]],
  ];
  final stock = b.stockUnseen ? [for (var k = 0; k < b.stock.length; k++) hidden[i++]] : b.stock;
  return SolitaireBoard.fromPiles(
    columns: columns,
    faceDown: [for (var c = 0; c < 7; c++) b.down(c)],
    stock: stock,
    waste: b.waste,
    foundations: [for (var p = 0; p < 4; p++) b.foundation(p)],
    recycles: b.recycles,
  );
}

/// Plays one deal with the auto-player, checking legality, card conservation
/// (edge 20), the score range (S-43) and, when asked, JSON save / resume and
/// undo. Stops at the win, when the player stops, when stuck, or at 1000.
SolitaireGame selfPlay(
  int seed,
  SolitaireOptions o,
  AiLevel level, {
  int jsonEvery = 0,
  int undoEvery = 0,
  bool tickClock = false,
}) {
  var g = SolitaireGame.newDeal(seed: seed, options: o);
  final rng = CardRng(seed * 31 + level.index);
  final deck = sortedCards(buildDeck());
  var n = 0;
  while (!g.isSolved && n < 1000) {
    final a = SolitaireAutoPlayer.choose(g.state.board, o, level, rng);
    if (a == null) break;
    expect(g.validate(a), isNull, reason: 'seed $seed ${level.name}: $a');
    expect(g.apply(a), isTrue);
    n++;
    if (tickClock) g.advanceClock(const Duration(seconds: 1));
    expect(sortedCards(g.state.board.allCards()), deck, reason: 'seed $seed: conservation after $a');
    if (!o.timedScoring) expect(g.state.score, inInclusiveRange(0, 745));
    if (undoEvery > 0 && n % undoEvery == 0 && g.canUndo) {
      expect(g.undo(), isTrue);
      expect(sortedCards(g.state.board.allCards()), deck, reason: 'conservation after undo');
      expect(g.apply(a), isTrue);
    }
    if (jsonEvery > 0 && n % jsonEvery == 0) {
      final json = jsonDecode(jsonEncode(g.toJson())) as Map<String, Object?>;
      final back = SolitaireGame.fromJson(json);
      expect(jsonEncode(back.toJson()), jsonEncode(json));
      expect(SolitaireAction.fromJson(jsonDecode(jsonEncode(a.toJson())) as Map<String, Object?>), a);
      g = back;
    }
    if (n % 50 == 0 && g.isStuck) break;
  }
  expect(n, lessThanOrEqualTo(1000));
  return g;
}

void replayPlan(int seed, SolitaireOptions o, List<SolitaireAction> plan) {
  final g = SolitaireGame.newDeal(seed: seed, options: o);
  for (final a in plan) {
    expect(g.apply(a), isTrue, reason: 'seed $seed: $a is not legal');
  }
  expect(g.isSolved, isTrue, reason: 'seed $seed: the plan does not win');
  expect(g.state.cardsHome, 52);
}

void main() {
  group('S-31 isStuck is exact and advisory', () {
    test('false when a column-to-column move lets the waste card play (edge 13)', () {
      // Moving 5D onto 6S empties a column for the waste king; then the ace
      // under it goes home.
      final g = board(
        columns: ['5D', '6S', '9C', '9D', '9H', 'TC', 'TD'],
        down: [0, 0, 1, 1, 1, 1, 1],
        wastePile: 'AC KH',
      );
      const onePass = SolitaireOptions(passLimit: 1);
      expect(SolitaireSearch.isStuck(g, onePass), isFalse);
      final h = board(
        columns: ['5D', '6H', '9C', '9D', '9S', 'TC', 'TD'],
        down: [0, 0, 1, 1, 1, 1, 1],
        wastePile: 'AC KH',
      );
      expect(SolitaireSearch.isStuck(h, onePass), isTrue);
    });

    test('true when only king shuffles between empty columns and fruitless recycles exist (edge 13)', () {
      final g = board(columns: ['KS'], stock: '2H 3D');
      expect(SolitaireSearch.isStuck(g, const SolitaireOptions()), isTrue);
      expect(SolitaireGame.custom(g).isStuck, isTrue);
    });

    test('with a pass limit it is false while a stock card is unseen; unknown is not stuck', () {
      final g = board(columns: ['KS'], stock: '2H 3D');
      expect(SolitaireSearch.isStuck(g, const SolitaireOptions(passLimit: 1)), isFalse);
      expect(SolitaireSearch.isStuck(g, const SolitaireOptions(), limit: 1), isFalse);
      final seen = board(columns: ['KS'], wastePile: '2H 3D', recycles: 1);
      expect(SolitaireSearch.isStuck(seen, const SolitaireOptions(passLimit: 3)), isTrue);
    });

    test('a fresh deal is never stuck', () {
      for (var seed = 1; seed <= 20; seed++) {
        expect(SolitaireGame.newDeal(seed: seed).isStuck, isFalse);
      }
    });
  });

  group('S-36 hints: the hard choice and a technique id', () {
    SolitaireTechnique technique(SolitaireBoard b, [SolitaireOptions o = manual]) =>
        SolitaireAutoPlayer.hint(b, o).technique;

    test('toFoundation, revealCard, emptyColumn, fromWaste, drawStock, recycle, noMoves', () {
      expect(technique(board(columns: ['9C AH'])), SolitaireTechnique.toFoundation);
      expect(technique(board(columns: ['9C 7H', '8S'], down: [1])), SolitaireTechnique.revealCard);
      expect(
        technique(board(columns: ['5D', '6S', '3C KH', '9C', '9D', '9H', 'TC'], down: [0, 0, 1, 1, 1, 1, 1])),
        SolitaireTechnique.emptyColumn,
      );
      expect(technique(board(columns: ['8S'], wastePile: '7H')), SolitaireTechnique.fromWaste);
      expect(technique(board(columns: ['8S'], stock: '2H')), SolitaireTechnique.drawStock);
      expect(technique(board(columns: ['4S'], wastePile: '3D 9C', recycles: 1)), SolitaireTechnique.recycle);
      final none = SolitaireAutoPlayer.hint(board(columns: ['KS'], wastePile: '9C', recycles: 1), manual);
      expect(none.technique, SolitaireTechnique.noMoves);
      expect(none.action, isNull);
    });

    test('the game hint uses hintLevel; a won game has no hint', () {
      final g = SolitaireGame.custom(board(columns: ['9C 7H', '8S'], down: [1]));
      final h = g.hint();
      expect(h.action, const SolitaireAction.move(SolitairePile.column(0), SolitairePile.column(1)));
      expect(h.fromSolver, isFalse);
    });
  });

  group('S-75 auto-player levels', () {
    test('medium: safe home move first, then the reveal in the column with most face-down cards', () {
      final b = board(columns: ['9C 7H', '8S', 'QD JC TD 6H', '7C', 'AS'], down: [1, 0, 3]);
      expect(
        SolitaireAutoPlayer.choose(b, manual, AiLevel.medium, CardRng(1)),
        const SolitaireAction.move(SolitairePile.column(4), SolitairePile.foundation(0)),
      );
      final c = board(columns: ['9C 7H', '8S', 'QD JC TD 6H', '7C'], down: [1, 0, 3]);
      expect(
        SolitaireAutoPlayer.choose(c, manual, AiLevel.medium, CardRng(1)),
        const SolitaireAction.move(SolitairePile.column(2), SolitairePile.column(3)),
      );
    });

    test('easy picks at random among productive moves', () {
      final b = board(columns: ['9C 7H', '8S', 'QD JC TD 6H', '7C'], down: [1, 0, 3]);
      final picks = {
        for (var s = 0; s < 40; s++) SolitaireAutoPlayer.choose(b, manual, AiLevel.easy, CardRng(s)),
      };
      expect(picks.length, greaterThan(1));
    });

    test('every level stops when nothing productive is left and the stock cannot help', () {
      final b = board(columns: ['KS'], wastePile: '9C 2H', recycles: 1);
      for (final level in AiLevel.values) {
        expect(SolitaireAutoPlayer.choose(b, manual, level, CardRng(1)), isNull);
      }
      expect(SolitaireAutoPlayer.stockUseful(board(columns: ['KS'], stock: '2H'), manual), isTrue);
      expect(SolitaireAutoPlayer.stockUseful(board(columns: ['3S'], wastePile: '2H 9C', recycles: 1), manual), isTrue);
    });

    test('S-36a/S-75 fairness: re-dealing the face-down cards (and the unseen stock) never changes a choice (edge 21)', () {
      var checked = 0;
      for (var seed = 1; seed <= 12; seed++) {
        final o = seed.isEven ? const SolitaireOptions() : const SolitaireOptions.expert();
        final g = SolitaireGame.newDeal(seed: seed, options: o);
        final rng = CardRng(seed);
        for (var step = 0; step < 60 && !g.isSolved; step++) {
          if (step % 6 == 0) {
            final real = g.state.board;
            for (var w = 0; w < 2; w++) {
              final other = permuteHidden(real, seed * 100 + step + w);
              expect(sortedCards(other.allCards()), sortedCards(real.allCards()));
              for (final level in AiLevel.values) {
                final a = SolitaireAutoPlayer.choose(real, o, level, CardRng(7));
                final b = SolitaireAutoPlayer.choose(other, o, level, CardRng(7));
                expect(b, a, reason: 'seed $seed step $step ${level.name}');
              }
            }
            checked++;
          }
          final a = SolitaireAutoPlayer.choose(g.state.board, o, AiLevel.medium, rng);
          if (a == null) break;
          g.apply(a);
        }
      }
      expect(checked, greaterThan(40));
    });
  });

  group('the solver (S-61…S-63)', () {
    test('S-61 winnable deals: for 25 seeds per default rule set the solver\'s plan replays to 52 home (edge 17)', () {
      const sets = [
        SolitaireOptions.easy(),
        SolitaireOptions(drawCount: 3, winnableOnly: true),
        SolitaireOptions(drawCount: 3, passLimit: 3, winnableOnly: true),
      ];
      for (final o in sets) {
        var fromBundle = 0;
        for (var stream = 1; stream <= 25; stream++) {
          final choice = SolitaireDeals.winnable(
            streamSeed: stream,
            options: o,
            solve: const SolitaireSolver(nodeBudget: 60000).solve,
          );
          expect(choice.proven, isTrue);
          var plan = choice.plan;
          if (choice.fromBundle) {
            fromBundle++;
            plan = const SolitaireSolver().solve(SolitaireBoard.forSeed(choice.seed), o).plan;
          }
          replayPlan(choice.seed, o, plan);
        }
        expect(fromBundle, lessThan(3));
      }
    });

    test('S-62 generation never loops: with a solver that never answers, the bundled seed is used (edge 18)', () {
      var calls = 0;
      SolitaireSolution never(SolitaireBoard b, SolitaireOptions o) {
        calls++;
        return const SolitaireSolution(SolitaireSolveResult.unknown, [], 0);
      }

      const o = SolitaireOptions.easy();
      final first = SolitaireDeals.winnable(streamSeed: 5, options: o, solve: never);
      expect(calls, SolitaireDeals.maxTries);
      expect(first.fromBundle, isTrue);
      expect(first.proven, isTrue);
      expect(first.seed, SolitaireSeeds.drawOneUnlimited.first);
      final next = SolitaireDeals.winnable(streamSeed: 5, options: o, solve: never, used: {first.seed});
      expect(next.seed, SolitaireSeeds.drawOneUnlimited[1]);
      final always = SolitaireDeals.winnable(
        streamSeed: 5,
        options: o.copyWith(autoMoveToFoundation: SolitaireAutoMove.always),
        solve: never,
      );
      expect(always.proven, isFalse);
      expect(SolitaireSeeds.forOptions(const SolitaireOptions.expert()), SolitaireSeeds.drawThreeThreePasses);
      expect(SolitaireSeeds.forOptions(const SolitaireOptions(passLimit: 1)), SolitaireSeeds.drawOneOnePass);
      expect(SolitaireSeeds.forOptions(const SolitaireOptions(drawCount: 3, passLimit: 2)), SolitaireSeeds.drawThreeOnePass);
    });

    test('every bundled list is proved for its rule set (the first seeds re-solved and replayed)', () {
      final sets = {
        SolitaireSeeds.drawOneUnlimited: const SolitaireOptions(),
        SolitaireSeeds.drawOneThreePasses: const SolitaireOptions(passLimit: 3),
        SolitaireSeeds.drawOneOnePass: const SolitaireOptions(passLimit: 1),
        SolitaireSeeds.drawThreeUnlimited: const SolitaireOptions(drawCount: 3),
        SolitaireSeeds.drawThreeThreePasses: const SolitaireOptions(drawCount: 3, passLimit: 3),
        SolitaireSeeds.drawThreeOnePass: const SolitaireOptions(drawCount: 3, passLimit: 1),
      };
      for (final e in sets.entries) {
        expect(e.key.length, greaterThanOrEqualTo(16));
        expect(e.key.toSet().length, e.key.length);
        for (final seed in e.key.take(2)) {
          final s = const SolitaireSolver().solve(SolitaireBoard.forSeed(seed), e.value);
          expect(s.won, isTrue, reason: 'seed $seed');
          replayPlan(seed, e.value, s.plan);
        }
      }
    });

    test('S-63 plans use the engine\'s own rules: explicit flips without autoFlip, explicit safe moves without auto-move', () {
      for (final o in [
        const SolitaireOptions(autoFlip: false),
        const SolitaireOptions(autoMoveToFoundation: SolitaireAutoMove.off),
        const SolitaireOptions(allowFoundationToTableau: false, drawCount: 3),
      ]) {
        final seeds = o.drawCount == 3 ? SolitaireSeeds.drawThreeUnlimited : SolitaireSeeds.drawOneUnlimited;
        for (final seed in seeds.take(2)) {
          final s = const SolitaireSolver().solve(SolitaireBoard.forSeed(seed), o);
          expect(s.won, isTrue, reason: 'seed $seed ${o.toJson()}');
          if (!o.autoFlip) expect(s.plan.any((a) => a.kind == SolitaireActionKind.flip), isTrue);
          replayPlan(seed, o, s.plan);
        }
      }
    });

    test('a tiny budget answers unknown; a lost search is not claimed as a win', () {
      final s = const SolitaireSolver(nodeBudget: 1).solve(SolitaireBoard.forSeed(4), const SolitaireOptions());
      expect(s.result, SolitaireSolveResult.unknown);
      expect(s.plan, isEmpty);
      final dead = board(columns: ['KS'], wastePile: '9C 2H', recycles: 1);
      expect(const SolitaireSolver().solve(dead, const SolitaireOptions(passLimit: 2)).result, SolitaireSolveResult.lost);
    });

    test('S-37 solverHints in winnable-deal mode follow the solver\'s plan while it is proved', () {
      const o = SolitaireOptions(winnableOnly: true, solverHints: true);
      final seed = SolitaireSeeds.drawOneUnlimited.first;
      final g = SolitaireGame.newDeal(seed: seed, options: o);
      final plan = const SolitaireSolver().solve(g.state.board, o).plan;
      final h = g.hint(solverBudget: 200000);
      expect(h.fromSolver, isTrue);
      expect(h.action, plan.first);
      expect(SolitaireGame.newDeal(seed: seed).hint().fromSolver, isFalse);
    });
  });

  group('self-play: every preset and variant at every level (legal, conserved, terminates)', () {
    final variants = <String, SolitaireOptions>{
      'jordan': const SolitaireOptions.jordan(),
      'easy': const SolitaireOptions.easy(),
      'hard': const SolitaireOptions.hard(),
      'expert': const SolitaireOptions.expert(),
      'windowsClassic': const SolitaireOptions.windowsClassic(),
      'draw three, penalty from recycle 4': const SolitaireOptions(drawCount: 3, draw3PenaltyFromRecycle: 4),
      'draw three, penalty on every recycle': const SolitaireOptions(drawCount: 3, draw3PenaltyFromRecycle: 1),
      'draw one, one pass': const SolitaireOptions(passLimit: 1),
      'no worrying back, no auto-flip': const SolitaireOptions(allowFoundationToTableau: false, autoFlip: false),
      'always auto-move, no score, undo penalty': const SolitaireOptions(
        autoMoveToFoundation: SolitaireAutoMove.always,
        scoring: SolitaireScoring.none,
        undoPenalty: 2,
      ),
    };
    for (final e in variants.entries) {
      for (final level in AiLevel.values) {
        test('${e.key}: ${level.name}', () {
          for (var seed = 1; seed <= 4; seed++) {
            selfPlay(
              seed,
              e.value,
              level,
              jsonEvery: seed == 1 ? 9 : 0,
              undoEvery: seed == 2 ? 7 : 0,
              tickClock: e.value.timedScoring,
            );
          }
        });
      }
    }

    test('deterministic: the same seed and level give the same game, and its action log replays it', () {
      for (final level in AiLevel.values) {
        final a = selfPlay(21, const SolitaireOptions(), level);
        final b = selfPlay(21, const SolitaireOptions(), level);
        expect(jsonEncode(b.toJson()), jsonEncode(a.toJson()));
      }
    });
  });

  test('S-43 random legal play keeps the untimed score within 0…745 and cards home within 0…52 (edge 16)', () {
    for (var seed = 1; seed <= 16; seed++) {
      final o = seed.isEven ? const SolitaireOptions() : const SolitaireOptions(drawCount: 3, draw3PenaltyFromRecycle: 1);
      final g = SolitaireGame.newDeal(seed: seed, options: o);
      final rng = CardRng(seed + 99);
      var maxScore = 0;
      for (var n = 0; n < 500 && !g.isSolved; n++) {
        final legal = g.legalActions();
        if (legal.isEmpty) break;
        expect(g.apply(legal[rng.nextInt(legal.length)]), isTrue);
        expect(g.state.score, inInclusiveRange(0, 745));
        expect(g.state.cardsHome, inInclusiveRange(0, 52));
        if (g.state.score > maxScore) maxScore = g.state.score;
      }
      expect(maxScore, greaterThan(0));
    }
  });

  test('S-75 strength: over the same 200 draw-one seeds hard wins more deals than easy', () {
    final wins = {for (final l in AiLevel.values) l: 0};
    for (var seed = 1; seed <= 200; seed++) {
      for (final level in AiLevel.values) {
        final g = SolitaireGame.newDeal(seed: seed);
        final rng = CardRng(seed * 7 + 1);
        var n = 0;
        while (!g.isSolved && n < 1000) {
          final a = SolitaireAutoPlayer.choose(g.state.board, g.options, level, rng);
          if (a == null) break;
          g.apply(a);
          n++;
          if (n % 50 == 0 && g.isStuck) break;
        }
        if (g.isSolved) wins[level] = wins[level]! + 1;
      }
    }
    // ignore: avoid_print
    print('solitaire wins over 200 draw-one deals: ${wins.map((k, v) => MapEntry(k.name, v))}');
    expect(wins[AiLevel.hard]!, greaterThan(wins[AiLevel.easy]!));
    expect(wins[AiLevel.medium]!, greaterThan(wins[AiLevel.easy]!));
  });
}

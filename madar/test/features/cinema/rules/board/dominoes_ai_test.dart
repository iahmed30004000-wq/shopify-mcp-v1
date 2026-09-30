// Dominoes AI at every level, for every variant of RULES.md §4.
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/cinema/rules/board/core/engine.dart';
import 'package:madar/features/cinema/rules/board/core/game_types.dart';
import 'package:madar/features/cinema/rules/board/core/rng.dart';
import 'package:madar/features/cinema/rules/board/dominoes/dominoes_ai.dart';
import 'package:madar/features/cinema/rules/board/dominoes/dominoes_rules.dart';

import 'board_test_utils.dart';

Domino d(int a, int b) => Domino.of(a, b);

List<PlacedDomino> chain(List<(int, int)> tiles) => [for (final (a, b) in tiles) PlacedDomino(d(a, b), a, b)];

DominoState dom(
  List<List<Domino>> hands, {
  List<PlacedDomino> line = const [],
  List<Domino>? boneyard,
  int player = 0,
  DominoConfig? config,
}) {
  final cfg = config ?? DominoConfig(players: hands.length, targetScore: 0);
  final used = {for (final h in hands) ...h, for (final p in line) p.tile};
  return DominoState(
    config: cfg,
    hands: hands,
    boneyard:
        boneyard ??
        [
          for (final t in Domino.doubleSix)
            if (!used.contains(t)) t,
        ],
    line: line,
    currentPlayer: player,
    phase: DominoPhase.playing,
    scores: List.filled(cfg.sides, 0),
    voids: List.filled(cfg.players, 0),
    rng: const [5, 6, 7, 8],
  );
}

/// Nine tiles, ends 5 / 6, six of the seven 5-tiles: [5|6] on the right locks.
final List<PlacedDomino> almostLocked = chain([(5, 0), (0, 1), (1, 5), (5, 5), (5, 2), (2, 3), (3, 5), (5, 4), (4, 6)]);

const ai = DominoAi();
const rules = dominoRules;

const variants = <String, DominoConfig>{
  'jordan': DominoConfig.jordan(players: 2),
  'fives': DominoConfig.allFives(players: 2),
  'block': DominoConfig.block(players: 2),
  'played-out lock': DominoConfig.playOutLock(players: 2),
  'jordan partners': DominoConfig.jordan(players: 4),
  'fives partners': DominoConfig.allFives(players: 4),
};

/// Plays a match; seat parity [strong] (team parity with 4 players) uses
/// [strongLevel], the rest [weakLevel]. Returns 1 / 0.5 / 0 for the strong side.
double duel(DominoConfig cfg, int seed, int strong, AiLevel strongLevel, AiLevel weakLevel, AiBudget budget) {
  final e = BoardGameEngine<DominoState, DominoMove>(rules, DominoState.initial(seed: seed, config: cfg));
  final rng = BoardRng(seed * 7919 + 17);
  while (!e.isOver) {
    final p = e.currentPlayer;
    final level = cfg.sideOf(p) % 2 == strong ? strongLevel : weakLevel;
    final m = ai.chooseMove(e.state, level, rng, budget);
    expect(e.legalMoves(), contains(m));
    e.apply(m);
    expect(e.history.length, lessThan(3000));
  }
  final r = e.result!;
  if (r.isDraw) return 0.5;
  return cfg.sideOf(r.winners.first) % 2 == strong ? 1 : 0;
}

void main() {
  test('every level plays legal moves to the end of a match in every variant (seeded self-play)', () {
    variants.forEach((name, cfg) {
      for (final level in AiLevel.values) {
        final e = BoardGameEngine<DominoState, DominoMove>(rules, DominoState.initial(seed: 40, config: cfg));
        final rng = BoardRng(41);
        while (!e.isOver) {
          checkInvariants(e.state);
          final m = ai.chooseMove(e.state, level, rng, const AiBudget.nodes(800));
          expect(rules.isLegal(e.state, m), isTrue, reason: '$name ${level.name}');
          e.apply(m);
        }
        expect(e.result!.reason, GameEndReason.targetScoreReached);
      }
    });
  });

  test('hard beats easy clearly in every variant (8 seeded matches, alternating seats)', () {
    variants.forEach((name, cfg) {
      var score = 0.0;
      for (var g = 0; g < 8; g++) {
        score += duel(cfg, 900 + g, g % 2, AiLevel.hard, AiLevel.easy, const AiBudget.nodes(3000));
      }
      expect(score, greaterThanOrEqualTo(6.5), reason: '$name: hard scored $score / 8');
    });
  }, timeout: const Timeout(Duration(minutes: 5)));

  test('hard is at least as strong as medium (Jordanian game, 12 seeded matches)', () {
    var score = 0.0;
    for (var g = 0; g < 12; g++) {
      score += duel(variants['jordan']!, 700 + g, g % 2, AiLevel.hard, AiLevel.medium, const AiBudget.nodes(3000));
    }
    expect(score, greaterThanOrEqualTo(6), reason: 'hard scored $score / 12 against medium');
  }, timeout: const Timeout(Duration(minutes: 5)));

  group('medium and the locked line (D-C3)', () {
    // P0 can lock with [5|6] on the right, or play [5|6] on the left / [0|6].
    DominoState lockChoice({required int opponentTiles, DominoConfig? config}) {
      final mine = [d(5, 6), d(0, 6), d(2, 2)];
      final others = [
        for (final t in Domino.doubleSix)
          if (!mine.contains(t) && !almostLocked.any((p) => p.tile == t)) t,
      ];
      return dom(
        [mine, others.sublist(0, opponentTiles)],
        line: almostLocked,
        boneyard: others.sublist(opponentTiles),
        config: config ?? const DominoConfig(targetScore: 0),
      );
    }

    const lock = DominoMove.play(Domino(5, 6), DominoEnd.right);

    test('locks when its hand is likely the lighter one', () {
      expect(ai.chooseMove(lockChoice(opponentTiles: 8), AiLevel.medium, BoardRng(1)), lock);
    });

    test('does not lock when the opponent is likely lighter', () {
      expect(ai.chooseMove(lockChoice(opponentTiles: 1), AiLevel.medium, BoardRng(1)), isNot(lock));
    });

    test('played-out lock: locks to make the next player draw the stock', () {
      final s = lockChoice(opponentTiles: 1, config: const DominoConfig.playOutLock(players: 2, targetScore: 0));
      expect(ai.chooseMove(s, AiLevel.medium, BoardRng(1)), lock);
    });

    test('hard also locks when it is clearly lighter', () {
      expect(ai.chooseMove(lockChoice(opponentTiles: 8), AiLevel.hard, BoardRng(1), const AiBudget.nodes(4000)), lock);
    });
  });

  test('medium takes an All Fives end count (and ignores it in count scoring)', () {
    DominoState s(DominoConfig c) => dom(
      [
        [d(0, 5), d(5, 6)],
        [d(1, 1), d(2, 2)],
      ],
      line: chain([(5, 5)]),
      config: c,
    );
    expect(ai.chooseMove(s(const DominoConfig.allFives(players: 2)), AiLevel.medium, BoardRng(1)).tile, d(0, 5));
    expect(ai.chooseMove(s(const DominoConfig(targetScore: 0)), AiLevel.medium, BoardRng(1)).tile, d(5, 6));
    final hard = ai.chooseMove(s(const DominoConfig.allFives(players: 2)), AiLevel.hard, BoardRng(1));
    expect(hard.tile, d(0, 5));
  });

  test('the AI only uses public information in every variant', () {
    final mine = [d(6, 6), d(6, 1), d(2, 3), d(0, 4)];
    final line = chain([(1, 1)]);
    final others = [
      for (final t in Domino.doubleSix)
        if (!mine.contains(t) && t != d(1, 1)) t,
    ];
    variants.forEach((name, cfg) {
      if (cfg.players != 2) return;
      final a = dom([mine, others.sublist(0, 5)], line: line, boneyard: others.sublist(5), config: cfg);
      final b = dom([mine, others.sublist(18)], line: line, boneyard: others.sublist(0, 18), config: cfg);
      for (final level in AiLevel.values) {
        expect(
          ai.chooseMove(a, level, BoardRng(4), const AiBudget.nodes(3000)),
          ai.chooseMove(b, level, BoardRng(4), const AiBudget.nodes(3000)),
          reason: '$name ${level.name}',
        );
      }
    });
  });

  test('hard with the phone budget returns a legal move', () {
    final s = DominoState.initial(seed: 3, config: const DominoConfig(players: 3));
    var st = rules.apply(s, rules.legalMoves(s).single);
    while (rules.legalMoves(st).length < 2 && st.phase == DominoPhase.playing) {
      st = rules.apply(st, rules.legalMoves(st).first);
    }
    final m = ai.chooseMove(st, AiLevel.hard, BoardRng(9));
    expect(rules.isLegal(st, m), isTrue);
  });
}

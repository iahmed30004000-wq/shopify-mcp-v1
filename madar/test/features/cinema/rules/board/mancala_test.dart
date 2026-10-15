import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/cinema/rules/board/board_games.dart';

import 'board_test_utils.dart';

MancalaState man(List<int> pits, List<int> stores, {int player = 0, MancalaConfig config = MancalaConfig.kalah}) =>
    MancalaState(config: config, pits: pits, stores: stores, currentPlayer: player);

void main() {
  const rules = mancalaRules;

  group('Kalah', () {
    test('initial and the extra turn', () {
      final s = MancalaState.initial();
      expect(rules.legalMoves(s).map((m) => m.pit), [0, 1, 2, 3, 4, 5]);
      final again = rules.apply(s, const MancalaMove(2)); // 4 seeds: 3,4,5,store
      expect(again.currentPlayer, 0);
      expect(again.stores, [1, 0]);
      final other = rules.apply(s, const MancalaMove(0));
      expect(other.currentPlayer, 1);
      checkInvariants(again);
    });

    test('capture from the opposite pit', () {
      final s = man([1, 0, 2, 2, 2, 2, 2, 2, 2, 2, 5, 2], [0, 0]);
      final after = rules.apply(s, const MancalaMove(0));
      expect(after.stores[0], 6);
      expect(after.pits[1], 0);
      expect(after.pits[10], 0);
      // Opposite empty: no capture by default.
      final empty = man([1, 0, 2, 2, 2, 2, 2, 2, 2, 2, 0, 7], [0, 0]);
      expect(rules.apply(empty, const MancalaMove(0)).pits[1], 1);
      final variant = man(
        [1, 0, 2, 2, 2, 2, 2, 2, 2, 2, 0, 7],
        [0, 0],
        config: const MancalaConfig(captureEmptyOpposite: true),
      );
      expect(rules.apply(variant, const MancalaMove(0)).stores[0], 1);
    });

    test("sowing skips the opponent's store", () {
      final s = man([0, 0, 0, 0, 0, 14, 0, 0, 0, 0, 0, 0], [0, 0], config: const MancalaConfig(seedsPerPit: 1));
      final after = rules.apply(s, const MancalaMove(5));
      // 14 seeds: store, six opponent pits, (skip store 1), pits 0..5, store.
      expect(after.stores, [2, 0]);
      expect(after.pits, List.filled(12, 1));
      expect(after.currentPlayer, 0);
    });

    test('game ends when a side is empty; the rest goes to its owner', () {
      final s = man([0, 0, 0, 0, 0, 1, 3, 0, 0, 0, 0, 2], [20, 22]);
      final end = rules.apply(s, const MancalaMove(5));
      expect(end.stores, [21, 27]);
      expect(end.result, const GameResult(winners: [1], reason: GameEndReason.sideEmpty, scores: [21, 27]));
    });

    test('AI takes the capture (and an extra turn first when it helps)', () {
      var s = man([1, 0, 2, 2, 2, 2, 2, 2, 2, 2, 9, 2], [0, 0]);
      while (s.currentPlayer == 0 && !s.isOver) {
        s = rules.apply(s, const MancalaAi().chooseMove(s, AiLevel.hard, BoardRng(1), const AiBudget.nodes(20000)));
      }
      expect(s.stores[0], greaterThanOrEqualTo(10));
    });
  });

  group('Oware', () {
    const o = MancalaConfig.oware;

    test('captures 2s and 3s backwards on the opponent side', () {
      final s = man([0, 0, 0, 0, 0, 3, 1, 2, 1, 5, 5, 5], [0, 0], config: o);
      final after = rules.apply(s, const MancalaMove(5)); // sow 6,7,8 → 2,3,2
      expect(after.stores[0], 7);
      expect(after.pits.sublist(6, 9), [0, 0, 0]);
    });

    test('a grand slam captures nothing', () {
      final s = man([3, 0, 0, 0, 0, 2, 1, 1, 0, 0, 0, 0], [10, 10], config: o);
      final after = rules.apply(s, const MancalaMove(5));
      expect(after.stores, [10, 10]);
      expect(after.pits.sublist(6, 8), [2, 2]);
    });

    test('the opponent must be fed', () {
      final s = man([3, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0], [20, 24], config: o);
      expect(rules.legalMoves(s).map((m) => m.pit), [5]);
      // No feeding move possible: the game ends and the player keeps their seeds.
      final prev = man([1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1], [23, 23], player: 1, config: o);
      final end = rules.apply(prev, const MancalaMove(11));
      expect(end.result?.reason, GameEndReason.cannotFeed);
      expect(end.stores[0] + end.stores[1], 48);
    });

    test('12+ seeds skip the starting pit', () {
      final pits = List.filled(12, 0)..[0] = 12;
      final after = rules.apply(man(pits, [18, 18], config: o), const MancalaMove(0));
      expect(after.pits[0], 0);
      expect(after.pits[1], 2);
    });

    test('more than half the seeds wins', () {
      final s = man([0, 0, 0, 0, 0, 1, 2, 1, 1, 1, 1, 1], [24, 16], config: o);
      final end = rules.apply(s, const MancalaMove(5));
      expect(end.result?.reason, GameEndReason.majorityCaptured);
      expect(end.result?.winners, [0]);
    });
  });
}

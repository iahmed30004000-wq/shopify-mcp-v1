// طاولة الزهر AI: every level in every variant, determinism, and hard
// beating easy clearly (seeded, deterministic node budgets).
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/cinema/rules/board/board_games.dart';

import 'backgammon_test_helpers.dart';
import 'board_test_utils.dart';

const Map<String, BackgammonConfig> variants = {
  'sheshBesh': single,
  'mahbusa': mahbusaSingle,
  'mahbusa motherRule': BackgammonConfig(variant: TawlaVariant.mahbusa, matchTarget: 0, motherRule: true),
  'tawla31': tawla31Single,
  'tawla31 parallel': BackgammonConfig(variant: TawlaVariant.tawla31, matchTarget: 0, layout31: Tawla31Layout.parallel),
  'tawla31 noFullPrime': BackgammonConfig(variant: TawlaVariant.tawla31, matchTarget: 0, noFullPrime: true),
  'international': BackgammonConfig.international,
};

void main() {
  const ai = BackgammonAi();
  const rules = backgammonRules;

  group('every level plays legal moves to the end', () {
    for (final MapEntry(key: name, value: config) in variants.entries) {
      test(name, () {
        for (final level in AiLevel.values) {
          final e = playTawla(
            BackgammonState.initial(seed: 100 + level.index, config: config),
            seed: 100 + level.index,
            levels: [level],
          );
          expect(e.isOver, isTrue, reason: '$name at ${level.name}');
        }
        final mixed = playTawla(
          BackgammonState.initial(seed: 7, config: config),
          seed: 7,
          levels: const [AiLevel.easy, AiLevel.hard],
        );
        expect(mixed.isOver, isTrue);
      });
    }
  });

  test('a whole Jordanian match (to 5) with mixed levels; the AI starts each next game', () {
    final e = playTawla(
      BackgammonState.initial(seed: 21),
      seed: 21,
      levels: const [AiLevel.medium, AiLevel.hard],
      check: false,
    );
    expect(e.result?.reason, GameEndReason.targetScoreReached);
    expect(e.history.where((m) => m.kind == BackgammonMoveKind.nextGame).length, e.state.gameNumber - 1);
  });

  test('the registry kit (default: a Jordanian match to 5) runs under the shared harness', () {
    final kit = boardGameKits[BoardGameId.backgammon]!;
    for (final level in [null, ...AiLevel.values]) {
      final e = playGame(kit, players: 2, seed: 31, levels: [level]);
      final restored = kit.engineFromJson(roundTrip(e.toJson()));
      expect(canonical(restored.state), canonical(e.state));
    }
  });

  test('never reads the dice RNG (every variant)', () {
    for (final config in variants.values) {
      final base = BackgammonState.initial(seed: 3, config: config);
      final a = base.copyWith(phase: BackgammonPhase.moving, dice: const [6, 4], rng: const [1, 1, 1, 1]);
      final b = base.copyWith(phase: BackgammonPhase.moving, dice: const [6, 4], rng: const [99, 98, 97, 96]);
      for (final level in AiLevel.values) {
        expect(
          ai.chooseMove(a, level, BoardRng(3), const AiBudget.nodes(3000)),
          ai.chooseMove(b, level, BoardRng(3), const AiBudget.nodes(3000)),
        );
      }
    }
  });

  test('deterministic replay: same seed and node budget, same game', () {
    for (final config in [mahbusaSingle, tawla31Single]) {
      List<String> line() => [
        for (final m in playTawla(
          BackgammonState.initial(seed: 3, config: config),
          seed: 3,
          levels: const [AiLevel.hard, AiLevel.medium],
          cap: 80,
          check: false,
        ).history)
          m.toJson().toString(),
      ];
      expect(line(), line());
    }
  });

  test('the phone budget returns quickly with a legal move', () {
    for (final config in [single, mahbusaSingle, tawla31Single]) {
      final s = BackgammonState.initial(seed: 9, config: config).copyWith(
        phase: BackgammonPhase.moving,
        dice: const [3, 3],
      );
      final watch = Stopwatch()..start();
      final m = ai.chooseMove(s, AiLevel.hard, BoardRng(1));
      expect(watch.elapsedMilliseconds, lessThan(2000));
      expect(rules.isLegal(s, m), isTrue);
    }
  });

  test('محبوسة: hard pins a lone checker in its home board when it is safe', () {
    // Player 1 has a blot on player 0's 4-point (index 3); player 0 can pin it
    // with 8→4 (4) and cover with 5→4 (1), or play elsewhere.
    final s = bg({7: 3, 4: 3, 23: 9, 3: -1, 0: -14}, dice: const [4, 1], config: mahbusaSingle);
    final m = ai.chooseMove(s, AiLevel.hard, BoardRng(1), const AiBudget.nodes(20000));
    final after = rules.apply(s, m);
    expect(after.pinned[3], 1, reason: '$m');
  });

  test('a game-ending play is chosen for the most points (triple barOnly: hit on the way off)', () {
    const barOnly = BackgammonConfig(matchTarget: 0, triple: TawlaTriple.barOnly);
    // Player 0's last checker is on his 6-point, player 1 has a blot on player
    // 0's 1-point and nothing off: 6/off wins 2, 6/1* 1/off wins 3.
    final s = bg({5: 1, 0: -1, 12: -14}, off: const [14, 0], dice: const [6, 5], config: barOnly);
    for (final level in const [AiLevel.medium, AiLevel.hard]) {
      for (var seed = 1; seed <= 3; seed++) {
        final m = ai.chooseMove(s, level, BoardRng(seed), const AiBudget.nodes(5000));
        expect(rules.apply(s, m).result?.scores, [3, 0], reason: '${level.name} seed $seed: $m');
      }
    }
  });

  test('every way a game ends is seen: a mother-rule win is taken, a lost game is voided (E5)', () {
    const motherOn = BackgammonConfig(variant: TawlaVariant.mahbusa, matchTarget: 0, motherRule: true);
    // Player 0 can pin player 1's last start checker with 6 (index 6 → 0)
    // while his own start is empty: an immediate «مارس».
    final win = bg({6: 12, 3: 3, 0: -1, 12: -14}, dice: const [6, 1], config: motherOn);
    // Player 0's own mother is pinned (a sure «مارس» against him); pinning
    // player 1's mother as well voids the game instead.
    final lost = bg({6: 14, 23: -1, 0: -1, 12: -13}, pinned: {23: 0}, dice: const [6, 1], config: mahbusaSingle);
    for (final level in const [AiLevel.medium, AiLevel.hard]) {
      final w = rules.apply(win, ai.chooseMove(win, level, BoardRng(1), const AiBudget.nodes(5000)));
      expect(w.lastGame?.end, TawlaGameEnd.motherPinned, reason: level.name);
      expect(w.result?.winners, [0]);
      final v = rules.apply(lost, ai.chooseMove(lost, level, BoardRng(1), const AiBudget.nodes(5000)));
      expect(v.lastGame?.end, TawlaGameEnd.bothMothersPinned, reason: level.name);
    }
  });

  test('٣١: every level answers the opening 6-5 with a legal runner move', () {
    final s = BackgammonState.initial(seed: 2, config: tawla31Single).copyWith(
      phase: BackgammonPhase.moving,
      dice: const [6, 5],
      currentPlayer: 0,
    );
    for (final level in AiLevel.values) {
      final m = ai.chooseMove(s, level, BoardRng(1), const AiBudget.nodes(20000));
      expect(rules.isLegal(s, m), isTrue);
      expect(rules.apply(s, m).points[23], 14);
    }
  });

  group('difficulty ordering: hard and medium beat easy clearly', () {
    // (config, stronger level, games, minimum wins of the stronger level)
    const plan = {
      'sheshBesh hard': (single, AiLevel.hard, 16, 12),
      'mahbusa hard': (mahbusaSingle, AiLevel.hard, 16, 12),
      'tawla31 hard': (tawla31Single, AiLevel.hard, 16, 12),
      'sheshBesh medium': (single, AiLevel.medium, 16, 12),
      'mahbusa medium': (mahbusaSingle, AiLevel.medium, 16, 12),
      'tawla31 medium': (tawla31Single, AiLevel.medium, 16, 12),
    };
    for (final MapEntry(key: name, value: (config, strong, games, minimum)) in plan.entries) {
      test(name, () {
        var wins = 0, points = 0;
        for (var g = 0; g < games; g++) {
          final seat = g % 2;
          final e = playTawla(
            BackgammonState.initial(seed: 900 + g, config: config),
            seed: 900 + g,
            levels: seat == 0 ? [strong, AiLevel.easy] : [AiLevel.easy, strong],
            budget: const AiBudget.nodes(2000),
            check: false,
          );
          final r = e.result!;
          if (r.isWinner(seat)) wins++;
          points += r.scores[seat] - r.scores[1 - seat];
        }
        // ignore: avoid_print
        print('$name: won $wins / $games against easy, net points $points');
        expect(wins, greaterThanOrEqualTo(minimum), reason: '${strong.name} won $wins / $games');
        expect(points, greaterThan(0));
      }, timeout: const Timeout(Duration(minutes: 5)));
    }
  });
}

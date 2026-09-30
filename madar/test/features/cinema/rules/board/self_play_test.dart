import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/cinema/rules/board/board_games.dart';

import 'board_test_utils.dart';

void main() {
  for (final kit in boardGameKits.values) {
    final playerCounts = {kit.minPlayers, if (kit.maxPlayers > 2) 3, kit.maxPlayers};
    group(kit.id.name, () {
      test('random legal self-play keeps invariants and round-trips JSON', () {
        for (final players in playerCounts) {
          for (var seed = 0; seed < 6; seed++) {
            final engine = playGame(kit, players: players, seed: seed, levels: const [null]);
            final restored = kit.engineFromJson(roundTrip(engine.toJson()));
            expect(canonical(restored.state), canonical(engine.state));
            final stateCopy = kit.rules.stateFromJson(roundTrip(engine.state.toJson()));
            expect(canonical(stateCopy), canonical(engine.state));
            if (engine.isOver) {
              expect(engine.legalMoves(), isEmpty);
              expect(engine.result, isNotNull);
            }
          }
        }
      });

      for (final level in AiLevel.values) {
        test('AI self-play at ${level.name} without exceptions', () {
          for (final players in playerCounts) {
            for (var seed = 0; seed < 2; seed++) {
              playGame(kit, players: players, seed: 100 + seed, levels: [level]);
            }
          }
        });
      }

      test('mixed levels play legal moves every turn', () {
        for (final players in playerCounts) {
          playGame(kit, players: players, seed: 7, levels: const [AiLevel.easy, AiLevel.hard, AiLevel.medium, null]);
        }
      });

      test('deterministic replay: same seed and node budget, same game', () {
        List<String> line(int seed) {
          final e = playGame(
            kit,
            players: kit.maxPlayers,
            seed: seed,
            levels: const [AiLevel.hard, AiLevel.medium, AiLevel.easy, AiLevel.hard],
            cap: 60,
            invariants: false,
          );
          return [for (final m in e.history) m.toJson().toString()];
        }

        expect(line(3), line(3));
        final a = kit.engine(players: kit.maxPlayers, seed: 11);
        final b = kit.engine(players: kit.maxPlayers, seed: 11);
        expect(canonical(a.state), canonical(b.state));
      });

      test('undo restores the previous state (dice and shuffles included)', () {
        final e = playGame(kit, players: kit.minPlayers, seed: 5, levels: const [null], cap: 8);
        if (!e.canUndo) return;
        final before = canonical(e.states[e.states.length - 2]);
        final last = e.undo();
        expect(canonical(e.state), before);
        e.apply(last);
      });
    });
  }
}

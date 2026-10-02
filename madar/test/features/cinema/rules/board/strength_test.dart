import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/cinema/rules/board/board_games.dart';

import 'board_test_utils.dart';

/// Hard should beat easy in every lobby mode – loosely, with fixed seeds
/// (deterministic node budgets), alternating seats. With four players (Ludo
/// in partnerships) the two seat parities are the two teams.
void main() {
  const budgets = {
    BoardGameId.chess: AiBudget.nodes(6000),
    BoardGameId.checkers: AiBudget.nodes(4000),
    BoardGameId.backgammon: AiBudget.nodes(2000),
    BoardGameId.dominoes: AiBudget.nodes(3000),
    BoardGameId.ludo: AiBudget.nodes(500),
    BoardGameId.mancala: AiBudget.nodes(4000),
    BoardGameId.connectFour: AiBudget.nodes(4000),
    BoardGameId.ticTacToe: AiBudget.nodes(500),
  };
  // (games, minimum hard score with win = 1, draw = 0.5). The defaults (as
  // commonly played in Jordan) get the most games; the other presets fewer,
  // since each game's own tests measure them in more depth.
  const plan = {
    BoardVariantId.chess: (4, 3.0),
    BoardVariantId.damaJordan: (6, 4.5),
    BoardVariantId.damaTurkish: (4, 3.0),
    BoardVariantId.draughtsAmerican: (4, 3.0),
    BoardVariantId.draughtsAmericanFlyingKings: (4, 3.0),
    // Tawla modes play single games here (see singleGame).
    BoardVariantId.tawlaSheshBesh: (16, 10.0),
    BoardVariantId.tawlaMahbusa: (8, 6.0),
    BoardVariantId.tawla31: (8, 6.0),
    BoardVariantId.backgammonInternational: (8, 5.0),
    BoardVariantId.dominoesJordan: (8, 6.0),
    BoardVariantId.dominoesAllFives: (8, 6.0),
    BoardVariantId.dominoesBlock: (8, 6.0),
    BoardVariantId.dominoesPlayOutLock: (8, 6.0),
    BoardVariantId.ludoJordan: (24, 14.0),
    BoardVariantId.ludoTeams: (12, 8.0),
    BoardVariantId.mancalaKalah: (8, 6.5),
    BoardVariantId.mancalaOware: (8, 6.0),
    BoardVariantId.connectFour: (8, 7.0),
    BoardVariantId.ticTacToe: (10, 7.0),
  };

  test('every mode has a strength plan', () {
    expect(plan.keys.toSet(), BoardVariantId.values.toSet());
  });

  for (final kit in boardVariantKits.values) {
    test('${kit.id.name}/${kit.variant.name}: hard beats easy', () {
      final (games, minimum) = plan[kit.variant]!;
      final players = kit.minPlayers;
      var score = 0.0;
      var hardLosses = 0;
      for (var g = 0; g < games; g++) {
        final hardSeat = g % 2;
        final e = playGame(
          kit,
          players: players,
          seed: 900 + g,
          levels: hardSeat == 0 ? const [AiLevel.hard, AiLevel.easy] : const [AiLevel.easy, AiLevel.hard],
          budget: budgets[kit.id],
          invariants: false,
          cap: 3000,
          initial: singleGame(kit, players: players, seed: 900 + g),
        );
        final r = e.result;
        if (r == null || r.isDraw) {
          score += 0.5;
        } else if (r.winners.contains(hardSeat)) {
          score += 1;
        } else {
          hardLosses++;
        }
      }
      expect(score, greaterThanOrEqualTo(minimum), reason: 'hard scored $score / $games (lost $hardLosses)');
      if (kit.id == BoardGameId.ticTacToe) expect(hardLosses, 0);
    }, timeout: const Timeout(Duration(minutes: 5)));
  }
}

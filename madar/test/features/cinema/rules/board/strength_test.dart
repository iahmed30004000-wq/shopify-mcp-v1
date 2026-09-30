import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/cinema/rules/board/board_games.dart';

import 'board_test_utils.dart';

/// Hard should beat easy – loosely, with fixed seeds (deterministic node
/// budgets), alternating seats.
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
  // (games, minimum hard score with win = 1, draw = 0.5)
  const plan = {
    BoardGameId.chess: (4, 3.0),
    BoardGameId.checkers: (6, 4.5),
    BoardGameId.backgammon: (16, 10.0),
    BoardGameId.dominoes: (8, 6.0),
    BoardGameId.ludo: (24, 14.0),
    BoardGameId.mancala: (8, 6.5),
    BoardGameId.connectFour: (8, 7.0),
    BoardGameId.ticTacToe: (10, 7.0),
  };

  for (final kit in boardGameKits.values) {
    test('${kit.id.name}: hard beats easy', () {
      final (games, minimum) = plan[kit.id]!;
      var score = 0.0;
      var hardLosses = 0;
      for (var g = 0; g < games; g++) {
        final hardSeat = g % 2;
        final e = playGame(
          kit,
          players: 2,
          seed: 900 + g,
          levels: hardSeat == 0 ? const [AiLevel.hard, AiLevel.easy] : const [AiLevel.easy, AiLevel.hard],
          budget: budgets[kit.id],
          invariants: false,
          cap: 3000,
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

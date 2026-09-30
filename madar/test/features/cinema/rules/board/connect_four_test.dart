import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/cinema/rules/board/board_games.dart';

import 'board_test_utils.dart';

ConnectFourState playCols(List<int> cols) {
  var s = ConnectFourState.initial();
  for (final c in cols) {
    s = connectFourRules.apply(s, ConnectFourMove(c));
  }
  return s;
}

void main() {
  const rules = connectFourRules;

  test('gravity and full columns', () {
    final s = playCols([3, 3, 3, 3, 3, 3]);
    expect(s.height(3), 6);
    expect(s.cell(0, 3), 1);
    expect(s.cell(1, 3), 2);
    expect(rules.legalMoves(s).map((m) => m.column), [0, 1, 2, 4, 5, 6]);
    checkInvariants(s);
  });

  test('wins in all four directions', () {
    final horizontal = playCols([0, 0, 1, 1, 2, 2, 3]);
    expect(horizontal.result, const GameResult(winners: [0], reason: GameEndReason.lineCompleted));
    expect(horizontal.winningLine, [0, 1, 2, 3]);
    final vertical = playCols([0, 1, 0, 1, 0, 1, 0]);
    expect(vertical.result?.winners, [0]);
    final diagonal = playCols([0, 1, 1, 2, 2, 3, 2, 3, 3, 6, 3]);
    expect(diagonal.result?.winners, [0]);
    expect(diagonal.winningLine, [0, 8, 16, 24]);
    final anti = playCols([6, 5, 5, 4, 4, 3, 4, 3, 3, 0, 3]);
    expect(anti.result?.winners, [0]);
    expect(rules.legalMoves(anti), isEmpty);
  });

  test('a full board without four is a draw', () {
    // (row ~/ 2 + col) parity never lines up four.
    final cells = [
      for (var r = 0; r < kC4Rows; r++)
        for (var c = 0; c < kC4Cols; c++) ((r ~/ 2 + c) % 2) + 1,
    ];
    final last = cells[41];
    cells[41] = 0;
    final s = ConnectFourState(cells: cells, currentPlayer: last - 1);
    final end = rules.apply(s, const ConnectFourMove(6));
    expect(end.result, const GameResult.draw(GameEndReason.boardFull));
  });

  group('ai', () {
    const ai = ConnectFourAi();

    test('takes a win and blocks a threat at every level above easy', () {
      final win = playCols([0, 6, 1, 6, 2]); // player 1 to move must block col 3
      for (final level in [AiLevel.medium, AiLevel.hard]) {
        expect(ai.chooseMove(win, level, BoardRng(1), const AiBudget.nodes(20000)).column, 3);
      }
      final own = playCols([0, 6, 1, 6, 2, 6]); // player 0 wins at col 3
      for (final level in [AiLevel.medium, AiLevel.hard]) {
        expect(ai.chooseMove(own, level, BoardRng(1), const AiBudget.nodes(20000)).column, 3);
      }
    });

    test('hard leaves the opponent no immediate win', () {
      // Player 0 has row 0 at columns 1, 2, 4, 5, 6: player 1 must block 3.
      final s = playCols([1, 1, 2, 2, 4, 4, 6, 0, 5]);
      final m = ai.chooseMove(s, AiLevel.hard, BoardRng(1), const AiBudget.nodes(50000));
      final after = rules.apply(s, m);
      final reply = rules.legalMoves(after).where((r) => rules.apply(after, r).result?.winners.contains(0) ?? false);
      expect(reply, isEmpty, reason: 'played ${m.column}');
    });

    test('hard opens in the centre', () {
      expect(
        ai.chooseMove(ConnectFourState.initial(), AiLevel.hard, BoardRng(1), const AiBudget.nodes(30000)).column,
        3,
      );
    });
  });
}

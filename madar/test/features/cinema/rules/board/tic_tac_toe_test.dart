import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/cinema/rules/board/board_games.dart';

TicTacToeState playCells(List<int> cells) {
  var s = TicTacToeState.initial();
  for (final c in cells) {
    s = ticTacToeRules.apply(s, TicTacToeMove(c));
  }
  return s;
}

void main() {
  const rules = ticTacToeRules;
  const ai = TicTacToeAi();

  test('wins, draws and occupied cells', () {
    final x = playCells([0, 3, 1, 4, 2]);
    expect(x.result, const GameResult(winners: [0], reason: GameEndReason.lineCompleted));
    expect(x.winningLine, [0, 1, 2]);
    final o = playCells([0, 2, 1, 4, 3, 6]);
    expect(o.result?.winners, [1]);
    final draw = playCells([0, 1, 2, 4, 3, 5, 7, 6, 8]);
    expect(draw.result, const GameResult.draw(GameEndReason.boardFull));
    expect(() => rules.apply(TicTacToeState.initial(), const TicTacToeMove(9)), throwsA(isA<IllegalMoveException>()));
    expect(rules.legalMoves(playCells([4])).map((m) => m.cell), isNot(contains(4)));
  });

  test('hard never loses against any opponent strategy', () {
    var games = 0;
    void explore(TicTacToeState s, int aiPlayer, int seed) {
      if (s.isOver) {
        games++;
        expect(s.result!.winners, isNot(contains(1 - aiPlayer)));
        return;
      }
      if (s.currentPlayer == aiPlayer) {
        explore(rules.apply(s, ai.chooseMove(s, AiLevel.hard, BoardRng(seed))), aiPlayer, seed);
      } else {
        for (final m in rules.legalMoves(s)) {
          explore(rules.apply(s, m), aiPlayer, seed + m.cell);
        }
      }
    }

    explore(TicTacToeState.initial(), 0, 1);
    explore(TicTacToeState.initial(), 1, 2);
    expect(games, greaterThan(100));
  });

  test('hard wins when it can and prefers the quickest win', () {
    // X: 0,1 ; O: 3,4 ; X to move → 2 wins now (5 would lose time).
    final s = playCells([0, 3, 1, 4]);
    expect(ai.chooseMove(s, AiLevel.hard, BoardRng(1)).cell, 2);
  });

  test('medium always blocks an immediate threat', () {
    final s = playCells([0, 4, 1]); // O must block 2
    for (var seed = 0; seed < 20; seed++) {
      expect(ai.chooseMove(s, AiLevel.medium, BoardRng(seed)).cell, 2);
    }
  });

  test('perfect play from both sides is a draw', () {
    var s = TicTacToeState.initial();
    final rng = BoardRng(5);
    while (!s.isOver) {
      s = rules.apply(s, ai.chooseMove(s, AiLevel.hard, rng));
    }
    expect(s.result?.isDraw, isTrue);
  });
}

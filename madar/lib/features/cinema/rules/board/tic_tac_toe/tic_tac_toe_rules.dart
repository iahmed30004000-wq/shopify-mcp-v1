/// Tic-tac-toe (إكس أو) on 3×3. Cells 0..8 row-major; values 0 empty,
/// 1 = player 0 (X, moves first), 2 = player 1 (O).
library;

import '../core/engine.dart';
import '../core/game_types.dart';

const List<List<int>> kTicTacToeLines = [
  [0, 1, 2], [3, 4, 5], [6, 7, 8], // rows
  [0, 3, 6], [1, 4, 7], [2, 5, 8], // columns
  [0, 4, 8], [2, 4, 6], // diagonals
];

final class TicTacToeMove extends GameMove {
  const TicTacToeMove(this.cell);
  factory TicTacToeMove.fromJson(Map<String, Object?> json) => TicTacToeMove((json['cell']! as num).toInt());

  final int cell;

  @override
  Map<String, Object?> toJson() => {'cell': cell};

  @override
  bool operator ==(Object other) => other is TicTacToeMove && other.cell == cell;

  @override
  int get hashCode => cell.hashCode;

  @override
  String toString() => 'cell$cell';
}

final class TicTacToeState extends GameState {
  TicTacToeState({required List<int> cells, required this.currentPlayer, List<int> winningLine = const [], this.result})
    : cells = List.unmodifiable(cells),
      winningLine = List.unmodifiable(winningLine);

  factory TicTacToeState.initial() => TicTacToeState(cells: List.filled(9, 0), currentPlayer: 0);

  factory TicTacToeState.fromJson(Map<String, Object?> json) {
    final r = json['result'];
    return TicTacToeState(
      cells: intList(json['cells']),
      currentPlayer: (json['player']! as num).toInt(),
      winningLine: intList(json['line']),
      result: r == null ? null : GameResult.fromJson(jsonMap(r)),
    );
  }

  final List<int> cells;
  @override
  final int currentPlayer;
  final List<int> winningLine;
  @override
  final GameResult? result;

  @override
  int get playerCount => 2;

  @override
  Map<String, Object?> toJson() => {
    'cells': cells,
    'player': currentPlayer,
    'line': winningLine,
    if (result != null) 'result': result!.toJson(),
  };
}

/// The completed line containing value [v], or empty.
List<int> ticTacToeLine(List<int> cells, int v) {
  for (final l in kTicTacToeLines) {
    if (cells[l[0]] == v && cells[l[1]] == v && cells[l[2]] == v) return l;
  }
  return const [];
}

final class TicTacToeRules extends GameRules<TicTacToeState, TicTacToeMove> {
  const TicTacToeRules();

  @override
  BoardGameId get id => BoardGameId.ticTacToe;

  @override
  List<TicTacToeMove> legalMoves(TicTacToeState state) {
    if (state.isOver) return const [];
    return [
      for (var i = 0; i < 9; i++)
        if (state.cells[i] == 0) TicTacToeMove(i),
    ];
  }

  @override
  TicTacToeState apply(TicTacToeState state, TicTacToeMove move) {
    if (move.cell < 0 || move.cell > 8 || state.cells[move.cell] != 0) throw IllegalMoveException(move);
    final p = state.currentPlayer;
    final cells = [...state.cells]..[move.cell] = p + 1;
    final line = ticTacToeLine(cells, p + 1);
    GameResult? result;
    if (line.isNotEmpty) {
      result = GameResult(winners: [p], reason: GameEndReason.lineCompleted);
    } else if (!cells.contains(0)) {
      result = const GameResult.draw(GameEndReason.boardFull);
    }
    return TicTacToeState(cells: cells, currentPlayer: result == null ? 1 - p : p, winningLine: line, result: result);
  }

  @override
  TicTacToeState stateFromJson(Map<String, Object?> json) => TicTacToeState.fromJson(json);

  @override
  TicTacToeMove moveFromJson(Map<String, Object?> json) => TicTacToeMove.fromJson(json);
}

const ticTacToeRules = TicTacToeRules();

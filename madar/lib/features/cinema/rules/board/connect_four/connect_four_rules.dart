/// Four in a Row (أربعة في صف) – 7 columns × 6 rows, gravity drop.
///
/// Cells are `row * 7 + col` with row 0 at the bottom; values 0 empty,
/// 1 = player 0, 2 = player 1. Player 0 moves first.
///
/// Bitboards use the classic layout (bit `col * 7 + row`, one sentinel bit
/// per column = 49 bits), so this file needs 64-bit integers (Dart VM/AOT).
library;

import '../core/engine.dart';
import '../core/game_types.dart';

const int kC4Cols = 7;
const int kC4Rows = 6;

/// Bitboard helpers (Pascal Pons' layout).
abstract final class C4Bits {
  static const int height = kC4Rows + 1;
  static final int bottomMask = () {
    var m = 0;
    for (var c = 0; c < kC4Cols; c++) {
      m |= 1 << (c * height);
    }
    return m;
  }();
  static final int boardMask = bottomMask * ((1 << kC4Rows) - 1);

  static int bottom(int col) => 1 << (col * height);
  static int top(int col) => 1 << (kC4Rows - 1 + col * height);
  static int column(int col) => ((1 << kC4Rows) - 1) << (col * height);

  static bool aligned(int pos) {
    var m = pos & (pos >> height);
    if (m & (m >> (2 * height)) != 0) return true; // horizontal
    m = pos & (pos >> (height - 1));
    if (m & (m >> (2 * (height - 1))) != 0) return true; // diagonal \
    m = pos & (pos >> (height + 1));
    if (m & (m >> (2 * (height + 1))) != 0) return true; // diagonal /
    m = pos & (pos >> 1);
    return m & (m >> 2) != 0; // vertical
  }

  /// Empty cells that would complete four for the owner of [position].
  static int winningCells(int position, int mask) {
    var r = (position << 1) & (position << 2) & (position << 3);
    for (final s in const [height, height - 1, height + 1]) {
      var p = (position << s) & (position << (2 * s));
      r |= p & (position << (3 * s));
      r |= p & (position >> s);
      p = (position >> s) & (position >> (2 * s));
      r |= p & (position << s);
      r |= p & (position >> (3 * s));
    }
    return r & (boardMask ^ mask);
  }

  static int popcount(int x) {
    var c = 0;
    while (x != 0) {
      x &= x - 1;
      c++;
    }
    return c;
  }
}

final class ConnectFourMove extends GameMove {
  const ConnectFourMove(this.column);
  factory ConnectFourMove.fromJson(Map<String, Object?> json) => ConnectFourMove((json['col']! as num).toInt());

  final int column;

  @override
  Map<String, Object?> toJson() => {'col': column};

  @override
  bool operator ==(Object other) => other is ConnectFourMove && other.column == column;

  @override
  int get hashCode => column.hashCode;

  @override
  String toString() => 'col$column';
}

final class ConnectFourState extends GameState {
  ConnectFourState({
    required List<int> cells,
    required this.currentPlayer,
    this.lastMove,
    List<int> winningLine = const [],
    this.result,
  }) : cells = List.unmodifiable(cells),
       winningLine = List.unmodifiable(winningLine);

  factory ConnectFourState.initial() => ConnectFourState(cells: List.filled(kC4Cols * kC4Rows, 0), currentPlayer: 0);

  factory ConnectFourState.fromJson(Map<String, Object?> json) {
    final r = json['result'];
    return ConnectFourState(
      cells: intList(json['cells']),
      currentPlayer: (json['player']! as num).toInt(),
      lastMove: (json['last'] as num?)?.toInt(),
      winningLine: intList(json['line']),
      result: r == null ? null : GameResult.fromJson(jsonMap(r)),
    );
  }

  final List<int> cells;
  @override
  final int currentPlayer;

  /// Column of the last drop.
  final int? lastMove;

  /// The four (or more) winning cells, for highlighting.
  final List<int> winningLine;
  @override
  final GameResult? result;

  @override
  int get playerCount => 2;

  int cell(int row, int col) => cells[row * kC4Cols + col];

  int height(int col) {
    var h = 0;
    while (h < kC4Rows && cells[h * kC4Cols + col] != 0) {
      h++;
    }
    return h;
  }

  int get moveCount => cells.where((c) => c != 0).length;

  /// Bitboard of [player]'s stones.
  int bitsOf(int player) {
    var b = 0;
    for (var i = 0; i < cells.length; i++) {
      if (cells[i] == player + 1) b |= 1 << ((i % kC4Cols) * C4Bits.height + i ~/ kC4Cols);
    }
    return b;
  }

  @override
  Map<String, Object?> toJson() => {
    'cells': cells,
    'player': currentPlayer,
    'last': lastMove,
    'line': winningLine,
    if (result != null) 'result': result!.toJson(),
  };
}

final class ConnectFourRules extends GameRules<ConnectFourState, ConnectFourMove> {
  const ConnectFourRules();

  @override
  BoardGameId get id => BoardGameId.connectFour;

  @override
  List<ConnectFourMove> legalMoves(ConnectFourState state) {
    if (state.isOver) return const [];
    return [
      for (var c = 0; c < kC4Cols; c++)
        if (state.cells[(kC4Rows - 1) * kC4Cols + c] == 0) ConnectFourMove(c),
    ];
  }

  @override
  ConnectFourState apply(ConnectFourState state, ConnectFourMove move) {
    final col = move.column;
    final row = state.height(col);
    if (col < 0 || col >= kC4Cols || row >= kC4Rows) throw IllegalMoveException(move);
    final p = state.currentPlayer;
    final cells = [...state.cells];
    cells[row * kC4Cols + col] = p + 1;
    final line = _line(cells, row, col, p + 1);
    GameResult? result;
    if (line.isNotEmpty) {
      result = GameResult(winners: [p], reason: GameEndReason.lineCompleted);
    } else if (!cells.contains(0)) {
      result = const GameResult.draw(GameEndReason.boardFull);
    }
    return ConnectFourState(
      cells: cells,
      currentPlayer: result == null ? 1 - p : p,
      lastMove: col,
      winningLine: line,
      result: result,
    );
  }

  static List<int> _line(List<int> cells, int row, int col, int v) {
    final out = <int>{};
    for (final (dr, dc) in const [(0, 1), (1, 0), (1, 1), (1, -1)]) {
      final run = <int>[row * kC4Cols + col];
      for (final sign in const [1, -1]) {
        var r = row + dr * sign, c = col + dc * sign;
        while (r >= 0 && r < kC4Rows && c >= 0 && c < kC4Cols && cells[r * kC4Cols + c] == v) {
          run.add(r * kC4Cols + c);
          r += dr * sign;
          c += dc * sign;
        }
      }
      if (run.length >= 4) out.addAll(run);
    }
    return out.toList()..sort();
  }

  @override
  ConnectFourState stateFromJson(Map<String, Object?> json) => ConnectFourState.fromJson(json);

  @override
  ConnectFourMove moveFromJson(Map<String, Object?> json) => ConnectFourMove.fromJson(json);
}

const connectFourRules = ConnectFourRules();

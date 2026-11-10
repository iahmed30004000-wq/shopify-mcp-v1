/// Grid coordinates shared by Word Search and the Crossword.
///
/// RTL convention: a grid is stored in LOGICAL order. Column 0 is the start
/// of a line – the RIGHT edge when drawn right-to-left. Laying a row out with
/// a Flutter `Row` under `Directionality.rtl` therefore draws column 0 on the
/// right automatically; a canvas painter that draws left-to-right should use
/// [visualColumn]. "Forward" (reading direction) means increasing column,
/// i.e. right-to-left on screen, and "down" means increasing row.
library;

/// A cell position (row, column) in logical order.
final class GridPos {
  /// Creates a position.
  const GridPos(this.row, this.col);

  /// Parses `[row, col]`.
  factory GridPos.fromJson(Object? json) {
    final l = json! as List<Object?>;
    return GridPos(l[0]! as int, l[1]! as int);
  }

  /// Row (0 = top).
  final int row;

  /// Logical column (0 = start of the line = right edge in RTL).
  final int col;

  /// The position [steps] cells away in [dir].
  GridPos step(GridDirection dir, [int steps = 1]) => GridPos(row + dir.dRow * steps, col + dir.dCol * steps);

  /// `[row, col]`.
  List<int> toJson() => [row, col];

  @override
  bool operator ==(Object other) => other is GridPos && other.row == row && other.col == col;

  @override
  int get hashCode => row * 7919 + col;

  @override
  String toString() => '($row,$col)';
}

/// The eight straight directions in logical grid space.
enum GridDirection {
  /// Along the line in reading order (right-to-left on screen).
  forward(0, 1),

  /// Against reading order (left-to-right on screen).
  backward(0, -1),

  /// Top to bottom.
  down(1, 0),

  /// Bottom to top.
  up(-1, 0),

  /// Down and forward (down-left on screen).
  downForward(1, 1),

  /// Down and backward (down-right on screen).
  downBackward(1, -1),

  /// Up and forward (up-left on screen).
  upForward(-1, 1),

  /// Up and backward (up-right on screen).
  upBackward(-1, -1);

  const GridDirection(this.dRow, this.dCol);

  /// Row step.
  final int dRow;

  /// Logical column step.
  final int dCol;

  /// The two natural reading directions of Arabic text in a grid.
  bool get isReading => this == forward || this == down;

  /// True for the four diagonals.
  bool get isDiagonal => dRow != 0 && dCol != 0;

  /// The opposite direction.
  GridDirection get reversed => GridDirection.values.firstWhere((d) => d.dRow == -dRow && d.dCol == -dCol);

  /// The direction from [a] to [b] when they lie on one straight line
  /// (horizontal, vertical or 45° diagonal), else null.
  static GridDirection? between(GridPos a, GridPos b) {
    final dr = b.row - a.row, dc = b.col - a.col;
    if (dr == 0 && dc == 0) return null;
    if (dr != 0 && dc != 0 && dr.abs() != dc.abs()) return null;
    final sr = dr.sign, sc = dc.sign;
    return GridDirection.values.firstWhere((d) => d.dRow == sr && d.dCol == sc);
  }
}

/// The on-screen column (0 = left edge) of logical column [col] in a grid
/// of [cols] columns drawn right-to-left (or unchanged when [rtl] is false).
int visualColumn(int col, int cols, {bool rtl = true}) => rtl ? cols - 1 - col : col;

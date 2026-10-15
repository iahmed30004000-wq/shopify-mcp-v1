/// Small grid helpers shared by the puzzles (row-major cell indices).
library;

/// The four orthogonal directions; `dy` grows downwards (row index).
enum Dir4 {
  up(0, -1),
  right(1, 0),
  down(0, 1),
  left(-1, 0);

  const Dir4(this.dx, this.dy);

  final int dx;
  final int dy;

  Dir4 get opposite => Dir4.values[(index + 2) % 4];

  /// Rotated a quarter turn clockwise.
  Dir4 get clockwise => Dir4.values[(index + 1) % 4];

  /// Bit used by pipe masks (up = 1, right = 2, down = 4, left = 8).
  int get bit => 1 << index;
}

/// A rectangular grid geometry.
final class GridShape {
  const GridShape(this.width, this.height);

  final int width;
  final int height;

  int get length => width * height;

  int index(int x, int y) => y * width + x;
  int xOf(int i) => i % width;
  int yOf(int i) => i ~/ width;

  bool contains(int x, int y) => x >= 0 && y >= 0 && x < width && y < height;

  /// The neighbour of [i] in [d], or -1 when off the grid.
  int step(int i, Dir4 d) {
    final x = xOf(i) + d.dx, y = yOf(i) + d.dy;
    return contains(x, y) ? index(x, y) : -1;
  }

  /// Orthogonal neighbours of [i].
  List<int> neighbours4(int i) {
    final out = <int>[];
    for (final d in Dir4.values) {
      final n = step(i, d);
      if (n >= 0) out.add(n);
    }
    return out;
  }

  /// The up to eight surrounding cells of [i].
  List<int> neighbours8(int i) {
    final x0 = xOf(i), y0 = yOf(i);
    final out = <int>[];
    for (var dy = -1; dy <= 1; dy++) {
      for (var dx = -1; dx <= 1; dx++) {
        if (dx == 0 && dy == 0) continue;
        final x = x0 + dx, y = y0 + dy;
        if (contains(x, y)) out.add(index(x, y));
      }
    }
    return out;
  }
}

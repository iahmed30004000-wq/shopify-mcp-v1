/// Sudoku geometry tables and a fast bitmask backtracking solver.
///
/// Cells are 0..80 row-major; values are 1..9 (0 = empty); candidate masks
/// use bit `d - 1` for digit `d`.
library;

import '../core/seeded_rng.dart';

const int kSudokuCells = 81;
const int kAllDigits = 0x1FF;

int rowOf(int c) => c ~/ 9;
int colOf(int c) => c % 9;
int boxOf(int c) => (c ~/ 27) * 3 + (c % 9) ~/ 3;

/// The 27 houses: rows 0..8, columns 9..17, boxes 18..26.
final List<List<int>> kHouses = List<List<int>>.unmodifiable([
  for (var r = 0; r < 9; r++) List<int>.unmodifiable([for (var c = 0; c < 9; c++) r * 9 + c]),
  for (var c = 0; c < 9; c++) List<int>.unmodifiable([for (var r = 0; r < 9; r++) r * 9 + c]),
  for (var b = 0; b < 9; b++)
    List<int>.unmodifiable([
      for (var i = 0; i < 9; i++) ((b ~/ 3) * 3 + i ~/ 3) * 9 + (b % 3) * 3 + i % 3,
    ]),
]);

/// The 20 peers of every cell.
final List<List<int>> kPeers = List<List<int>>.unmodifiable([
  for (var c = 0; c < 81; c++)
    List<int>.unmodifiable([
      for (var p = 0; p < 81; p++)
        if (p != c && (rowOf(p) == rowOf(c) || colOf(p) == colOf(c) || boxOf(p) == boxOf(c))) p,
    ]),
]);

/// Whether two distinct cells see each other.
bool sees(int a, int b) => a != b && (rowOf(a) == rowOf(b) || colOf(a) == colOf(b) || boxOf(a) == boxOf(b));

/// Popcount for 9-bit masks.
final List<int> kPop9 = List<int>.unmodifiable([
  for (var m = 0; m < 512; m++) _pop(m),
]);

int _pop(int m) {
  var n = 0;
  while (m != 0) {
    m &= m - 1;
    n++;
  }
  return n;
}

/// The single digit of a one-bit mask (1..9).
int digitOfMask(int mask) {
  var d = 1;
  while ((mask & 1) == 0) {
    mask >>= 1;
    d++;
  }
  return d;
}

/// Digits (1..9) contained in [mask].
List<int> digitsOf(int mask) => [
  for (var d = 1; d <= 9; d++)
    if (mask & (1 << (d - 1)) != 0) d,
];

/// Whether [grid] contains no duplicate within any house (zeros ignored).
bool isConsistentGrid(List<int> grid) {
  for (final h in kHouses) {
    var seen = 0;
    for (final c in h) {
      final v = grid[c];
      if (v == 0) continue;
      final b = 1 << (v - 1);
      if (seen & b != 0) return false;
      seen |= b;
    }
  }
  return true;
}

/// Bitmask backtracking with the minimum-remaining-values heuristic.
final class SudokuSolver {
  SudokuSolver._(List<int> grid) : _grid = List<int>.from(grid) {
    for (var c = 0; c < 81; c++) {
      final v = _grid[c];
      if (v == 0) {
        _empties.add(c);
      } else {
        final b = 1 << (v - 1);
        if ((_rows[rowOf(c)] | _cols[colOf(c)] | _boxes[boxOf(c)]) & b != 0) _invalid = true;
        _rows[rowOf(c)] |= b;
        _cols[colOf(c)] |= b;
        _boxes[boxOf(c)] |= b;
      }
    }
  }

  final List<int> _grid;
  final List<int> _rows = List<int>.filled(9, 0);
  final List<int> _cols = List<int>.filled(9, 0);
  final List<int> _boxes = List<int>.filled(9, 0);
  final List<int> _empties = [];
  bool _invalid = false;

  int _count = 0;
  int _limit = 2;
  List<int>? _first;
  SeededRng? _rng;
  int _nodes = 0;

  /// Counts solutions of [grid] up to [limit].
  static int countSolutions(List<int> grid, {int limit = 2}) {
    final s = SudokuSolver._(grid);
    if (s._invalid) return 0;
    s._limit = limit;
    s._search(0);
    return s._count;
  }

  /// The first solution of [grid] (null when there is none).
  static List<int>? solve(List<int> grid) {
    final s = SudokuSolver._(grid);
    if (s._invalid) return null;
    s._limit = 1;
    s._search(0);
    return s._first;
  }

  /// Whether [grid] has exactly one solution.
  static bool hasUniqueSolution(List<int> grid) => countSolutions(grid, limit: 2) == 1;

  /// A uniformly shuffled complete valid grid.
  static List<int> randomSolution(SeededRng rng) {
    final s = SudokuSolver._(List<int>.filled(81, 0));
    s._limit = 1;
    s._rng = rng;
    s._search(0);
    return s._first!;
  }

  /// Search nodes visited by the last call through [countSolutionsWithNodes].
  static ({int solutions, int nodes}) countSolutionsWithNodes(List<int> grid, {int limit = 2}) {
    final s = SudokuSolver._(grid);
    if (s._invalid) return (solutions: 0, nodes: 0);
    s._limit = limit;
    s._search(0);
    return (solutions: s._count, nodes: s._nodes);
  }

  bool _search(int depth) {
    _nodes++;
    final n = _empties.length;
    if (depth == n) {
      _count++;
      _first ??= List<int>.from(_grid);
      return _count >= _limit;
    }
    var best = -1, bestCount = 10, bestMask = 0;
    for (var i = depth; i < n; i++) {
      final c = _empties[i];
      final m = ~(_rows[c ~/ 9] | _cols[c % 9] | _boxes[(c ~/ 27) * 3 + (c % 9) ~/ 3]) & kAllDigits;
      final pc = kPop9[m];
      if (pc < bestCount) {
        best = i;
        bestCount = pc;
        bestMask = m;
        if (pc <= 1) break;
      }
    }
    if (bestCount == 0) return false;
    final c = _empties[best];
    _empties[best] = _empties[depth];
    _empties[depth] = c;
    final r = c ~/ 9, col = c % 9, b = (c ~/ 27) * 3 + (c % 9) ~/ 3;
    final digits = <int>[];
    for (var d = 0; d < 9; d++) {
      if (bestMask & (1 << d) != 0) digits.add(d);
    }
    _rng?.shuffle(digits);
    for (final d in digits) {
      final bit = 1 << d;
      _grid[c] = d + 1;
      _rows[r] |= bit;
      _cols[col] |= bit;
      _boxes[b] |= bit;
      final stop = _search(depth + 1);
      _rows[r] &= ~bit;
      _cols[col] &= ~bit;
      _boxes[b] &= ~bit;
      _grid[c] = 0;
      if (stop) {
        _empties[depth] = _empties[best];
        _empties[best] = c;
        return true;
      }
    }
    _empties[depth] = _empties[best];
    _empties[best] = c;
    return false;
  }
}

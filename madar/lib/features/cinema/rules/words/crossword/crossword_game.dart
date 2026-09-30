/// Crossword play state: entering letters, check and reveal.
///
/// Letters are compared after folding (ا/أ/إ/آ, ى/ي, ة/ه), so a player who
/// types ا in a cell whose answer is أ is right. Revealed cells show the
/// solution letter and are locked; [CrosswordGame.revealedCount] lets the UI
/// adjust scores.
library;

import '../core/arabic_text.dart';
import '../core/letter_grid.dart';
import 'crossword_generator.dart';

/// A crossword in progress.
final class CrosswordGame {
  /// Starts a game.
  CrosswordGame(this.puzzle);

  /// Restores a saved game.
  factory CrosswordGame.fromJson(Map<String, Object?> j) {
    final g = CrosswordGame(CrosswordPuzzle.fromJson(j['puzzle']! as Map<String, Object?>));
    for (final e in (j['letters']! as Map<String, Object?>).entries) {
      g._letters[_parseKey(e.key)] = e.value! as String;
    }
    for (final k in j['revealed']! as List<Object?>) {
      g._revealed.add(_parseKey(k! as String));
    }
    return g;
  }

  static GridPos _parseKey(String k) {
    final parts = k.split(',');
    return GridPos(int.parse(parts[0]), int.parse(parts[1]));
  }

  static String _key(GridPos p) => '${p.row},${p.col}';

  /// The puzzle.
  final CrosswordPuzzle puzzle;
  final Map<GridPos, String> _letters = {};
  final Set<GridPos> _revealed = {};

  /// Letter entered in [p] (null when empty).
  String? letterAt(GridPos p) => _letters[p];

  /// Whether [p] was revealed.
  bool isRevealed(GridPos p) => _revealed.contains(p);

  /// Number of revealed cells.
  int get revealedCount => _revealed.length;

  /// Enters [letter] (one Arabic letter; null or empty clears). Returns
  /// false for block cells, revealed cells or invalid input.
  bool setLetter(GridPos p, String? letter) {
    if (!puzzle.isCell(p) || _revealed.contains(p)) return false;
    if (letter == null || letter.isEmpty) {
      _letters.remove(p);
      return true;
    }
    final plain = ArabicText.plain(letter);
    if (plain.length != 1 || !ArabicText.isGameWord(plain)) return false;
    _letters[p] = plain;
    return true;
  }

  bool _isRight(GridPos p) {
    final l = _letters[p];
    return l != null && ArabicText.foldLetter(l) == ArabicText.foldLetter(puzzle.solutionAt(p)!);
  }

  /// Filled cells among [cells] whose letter is wrong.
  Set<GridPos> _wrongIn(Iterable<GridPos> cells) => {
    for (final p in cells)
      if (_letters.containsKey(p) && !_isRight(p)) p,
  };

  /// Whether the cell's letter is wrong (false when empty).
  bool checkCell(GridPos p) => _wrongIn([p]).isNotEmpty;

  /// Wrong cells of [entry].
  Set<GridPos> checkEntry(CrosswordEntry entry) => _wrongIn(entry.cells);

  /// Wrong cells of the whole grid.
  Set<GridPos> checkAll() => _wrongIn(puzzle.cells);

  /// Reveals one cell.
  void revealCell(GridPos p) {
    if (!puzzle.isCell(p)) return;
    _letters[p] = puzzle.solutionAt(p)!;
    _revealed.add(p);
  }

  /// Reveals an entry.
  void revealEntry(CrosswordEntry entry) => entry.cells.forEach(revealCell);

  /// Reveals everything.
  void revealAll() => puzzle.cells.forEach(revealCell);

  /// Whether [entry] is completely and correctly filled.
  bool isEntrySolved(CrosswordEntry entry) => entry.cells.every(_isRight);

  /// Whether the grid is solved.
  bool get isSolved => puzzle.cells.every(_isRight);

  /// Fraction of letter cells filled.
  double get progress => _letters.length / puzzle.cells.length;

  /// Serialises.
  Map<String, Object?> toJson() => {
    'puzzle': puzzle.toJson(),
    'letters': {for (final e in _letters.entries) _key(e.key): e.value},
    'revealed': [for (final p in _revealed) _key(p)],
  };
}

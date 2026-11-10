/// Word Search play state: straight-line selections and found words.
library;

import '../core/letter_grid.dart';
import 'word_search_generator.dart';

/// Result of a selection.
enum SelectionOutcome {
  /// Not a straight line (or outside the grid).
  invalidLine,

  /// A straight line that is not a hidden word.
  miss,

  /// A hidden word found for the first time.
  found,

  /// A hidden word that was already found.
  alreadyFound,
}

/// A game in progress.
final class WordSearchGame {
  /// Starts a game.
  WordSearchGame(this.puzzle, {Set<String>? found}) : _found = {...?found};

  /// Restores a saved game.
  factory WordSearchGame.fromJson(Map<String, Object?> j) => WordSearchGame(
    WordSearchPuzzle.fromJson(j['puzzle']! as Map<String, Object?>),
    found: {for (final w in j['found']! as List<Object?>) w! as String},
  );

  /// The puzzle.
  final WordSearchPuzzle puzzle;
  final Set<String> _found;

  /// Words found so far.
  Set<String> get found => Set.unmodifiable(_found);

  /// Placements of the found words (for highlighting).
  List<WordPlacement> get foundPlacements => [for (final p in puzzle.placements) if (_found.contains(p.word)) p];

  /// Whether every word was found.
  bool get isComplete => _found.length == puzzle.placements.length;

  /// Cells from [a] to [b] when they form a straight line, else null.
  List<GridPos>? line(GridPos a, GridPos b) {
    if (!puzzle.contains(a) || !puzzle.contains(b)) return null;
    if (a == b) return [a];
    final d = GridDirection.between(a, b);
    if (d == null) return null;
    final n = (b.row - a.row).abs() > (b.col - a.col).abs() ? (b.row - a.row).abs() : (b.col - a.col).abs();
    return [for (var i = 0; i <= n; i++) a.step(d, i)];
  }

  /// Checks a drag from [a] to [b]; a word may be selected from either end.
  (SelectionOutcome, WordPlacement?) select(GridPos a, GridPos b) {
    final cells = line(a, b);
    if (cells == null || cells.length < 2) return (SelectionOutcome.invalidLine, null);
    for (final p in puzzle.placements) {
      final matches = (p.start == a && p.end == b) || (p.start == b && p.end == a);
      if (!matches) continue;
      if (_found.contains(p.word)) return (SelectionOutcome.alreadyFound, p);
      _found.add(p.word);
      return (SelectionOutcome.found, p);
    }
    return (SelectionOutcome.miss, null);
  }

  /// Serialises.
  Map<String, Object?> toJson() => {'puzzle': puzzle.toJson(), 'found': _found.toList()};
}

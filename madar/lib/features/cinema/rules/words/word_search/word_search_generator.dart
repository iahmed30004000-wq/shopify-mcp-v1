/// Word Search grid generator (RTL-aware, eight directions, seeded).
///
/// Difficulty grows with grid size, allowed directions and overlap:
///
/// | level  | grid  | words | directions                                   |
/// |--------|-------|-------|----------------------------------------------|
/// | easy   | 8×8   | 6     | reading only: forward (right→left) and down  |
/// | medium | 10×10 | 8     | + the two downward diagonals                 |
/// | hard   | 12×12 | 11    | all eight, overlaps preferred                |
/// | expert | 14×14 | 15    | all eight, overlaps preferred                |
///
/// Guarantees (checked by [WordSearchGenerator.validate]): every placed word
/// appears exactly once in the grid (in any of the eight directions), no
/// blocked or sensitive word of three or more letters appears by accident,
/// and the same seed always gives the same puzzle.
library;

import '../core/arabic_text.dart';
import '../core/letter_grid.dart';
import '../core/words_rng.dart';
import '../lexicon/word_filter.dart';
import 'word_search_themes.dart';

/// Difficulty presets.
enum WordSearchDifficulty {
  /// 8×8, reading directions only.
  easy,

  /// 10×10, + downward diagonals.
  medium,

  /// 12×12, all directions.
  hard,

  /// 14×14, all directions.
  expert,
}

/// Generator options.
final class WordSearchConfig {
  /// Creates options.
  const WordSearchConfig({
    required this.rows,
    required this.cols,
    required this.wordCount,
    required this.directions,
    this.preferOverlap = false,
  });

  /// The preset for [difficulty].
  factory WordSearchConfig.forDifficulty(WordSearchDifficulty difficulty) => switch (difficulty) {
    WordSearchDifficulty.easy => const WordSearchConfig(
      rows: 8,
      cols: 8,
      wordCount: 6,
      directions: {GridDirection.forward, GridDirection.down},
    ),
    WordSearchDifficulty.medium => const WordSearchConfig(
      rows: 10,
      cols: 10,
      wordCount: 8,
      directions: {GridDirection.forward, GridDirection.down, GridDirection.downForward, GridDirection.downBackward},
    ),
    WordSearchDifficulty.hard => WordSearchConfig(
      rows: 12,
      cols: 12,
      wordCount: 11,
      directions: GridDirection.values.toSet(),
      preferOverlap: true,
    ),
    WordSearchDifficulty.expert => WordSearchConfig(
      rows: 14,
      cols: 14,
      wordCount: 15,
      directions: GridDirection.values.toSet(),
      preferOverlap: true,
    ),
  };

  /// Grid rows.
  final int rows;

  /// Grid columns.
  final int cols;

  /// Words to place (fewer when the theme is short).
  final int wordCount;

  /// Allowed placement directions.
  final Set<GridDirection> directions;

  /// Favour placements that share letters with placed words.
  final bool preferOverlap;
}

/// A placed word.
final class WordPlacement {
  /// Creates a placement.
  const WordPlacement({required this.word, required this.display, required this.start, required this.direction});

  /// Restores from JSON.
  factory WordPlacement.fromJson(Map<String, Object?> j) => WordPlacement(
    word: j['word']! as String,
    display: j['display']! as String,
    start: GridPos.fromJson(j['start']),
    direction: GridDirection.values.byName(j['dir']! as String),
  );

  /// Plain letters.
  final String word;

  /// Vowelled form for the word list.
  final String display;

  /// First letter's cell.
  final GridPos start;

  /// Direction of the letters.
  final GridDirection direction;

  /// Last letter's cell.
  GridPos get end => start.step(direction, word.length - 1);

  /// The cells, first letter first.
  List<GridPos> get cells => [for (var i = 0; i < word.length; i++) start.step(direction, i)];

  /// Serialises.
  Map<String, Object?> toJson() => {'word': word, 'display': display, 'start': start.toJson(), 'dir': direction.name};
}

/// A generated puzzle.
final class WordSearchPuzzle {
  /// Creates a puzzle.
  WordSearchPuzzle({required this.grid, required this.placements, required this.seed})
    : rows = grid.length,
      cols = grid.isEmpty ? 0 : grid.first.length;

  /// Restores from JSON.
  factory WordSearchPuzzle.fromJson(Map<String, Object?> j) => WordSearchPuzzle(
    grid: [
      for (final row in j['grid']! as List<Object?>) [for (final c in row! as List<Object?>) c! as String],
    ],
    placements: [for (final p in j['placements']! as List<Object?>) WordPlacement.fromJson(p! as Map<String, Object?>)],
    seed: j['seed']! as int,
  );

  /// Letters by [row][logical column] (column 0 = right edge in RTL).
  final List<List<String>> grid;

  /// Hidden words.
  final List<WordPlacement> placements;

  /// Seed that produced the puzzle.
  final int seed;

  /// Rows.
  final int rows;

  /// Columns.
  final int cols;

  /// Letter at [p].
  String at(GridPos p) => grid[p.row][p.col];

  /// Whether [p] is inside the grid.
  bool contains(GridPos p) => p.row >= 0 && p.row < rows && p.col >= 0 && p.col < cols;

  /// Serialises.
  Map<String, Object?> toJson() => {
    'grid': grid,
    'placements': [for (final p in placements) p.toJson()],
    'seed': seed,
  };
}

/// Builds puzzles.
final class WordSearchGenerator {
  /// Creates a generator; [letterWeights] (letter → weight) shapes the
  /// filler letters (defaults to typical Arabic letter frequencies).
  WordSearchGenerator({WordFilter? filter, Map<String, double>? letterWeights})
    : filter = filter ?? WordFilter.none(),
      _fillLetters = (letterWeights ?? defaultLetterWeights).keys.toList(),
      _fillWeights = (letterWeights ?? defaultLetterWeights).values.toList();

  /// Filter for accidental words.
  final WordFilter filter;

  final List<String> _fillLetters;
  final List<double> _fillWeights;

  /// Approximate letter frequencies of written Arabic (per mille); ة and ى
  /// are kept rare because they only end words.
  static const Map<String, double> defaultLetterWeights = {
    'ا': 120, 'ل': 110, 'ي': 75, 'م': 62, 'و': 60, 'ن': 58, 'ر': 45, 'ت': 45, 'ب': 40, 'ع': 36, 'د': 30, //
    'س': 28, 'ه': 26, 'ف': 25, 'ق': 22, 'ك': 22, 'ح': 20, 'ج': 14, 'أ': 14, 'ش': 12, 'ط': 10, 'ص': 10, 'خ': 9,
    'ة': 8, 'إ': 6, 'ز': 6, 'ث': 5, 'ض': 5, 'غ': 5, 'ذ': 5, 'ى': 4, 'ظ': 2, 'ء': 2, 'ئ': 2, 'ؤ': 1, 'آ': 1,
  };

  /// Generates a puzzle from [words] (a theme's list) with [config].
  WordSearchPuzzle generate(List<ThemeWord> words, WordSearchConfig config, int seed) {
    final maxLen = config.rows > config.cols ? config.rows : config.cols;
    final pool = <ThemeWord>[];
    final seen = <String>{};
    for (final w in words) {
      final p = ArabicText.plain(w.word);
      final key = ArabicText.fold(p);
      if (p.length < 3 || p.length > maxLen || !ArabicText.isGameWord(p) || filter.isUnsuitable(p)) continue;
      if (!seen.add(key)) continue;
      pool.add(ThemeWord(p, w.vowelled));
    }
    if (pool.isEmpty) throw ArgumentError('no usable words');
    final rng = WordsRng(WordsRng.mix([seed, config.rows, config.cols, config.wordCount]));
    WordSearchPuzzle? best;
    for (var attempt = 0; attempt < 60; attempt++) {
      final order = rng.shuffle([...pool]);
      final chosen = <ThemeWord>[];
      for (final w in order) {
        if (chosen.length >= config.wordCount) break;
        // Avoid words that contain another chosen word (it would be found twice).
        final f = ArabicText.fold(w.word);
        if (chosen.any((c) => f.contains(ArabicText.fold(c.word)) || ArabicText.fold(c.word).contains(f))) continue;
        chosen.add(w);
      }
      chosen.sort((a, b) => b.length.compareTo(a.length));
      final result = _tryBuild(chosen, config, rng, seed);
      if (result == null) continue;
      if (best == null || result.placements.length > best.placements.length) best = result;
      if (best.placements.length >= chosen.length) break;
    }
    if (best == null) throw StateError('could not build a word search grid');
    return best;
  }

  WordSearchPuzzle? _tryBuild(List<ThemeWord> words, WordSearchConfig config, WordsRng rng, int seed) {
    final grid = List.generate(config.rows, (_) => List<String?>.filled(config.cols, null));
    final placements = <WordPlacement>[];
    final dirs = GridDirection.values.where(config.directions.contains).toList();
    for (final w in words) {
      final options = <(GridPos, GridDirection, int)>[];
      for (final d in dirs) {
        for (var r = 0; r < config.rows; r++) {
          for (var c = 0; c < config.cols; c++) {
            final endR = r + d.dRow * (w.length - 1), endC = c + d.dCol * (w.length - 1);
            if (endR < 0 || endR >= config.rows || endC < 0 || endC >= config.cols) continue;
            var overlap = 0;
            var ok = true;
            for (var i = 0; i < w.length; i++) {
              final cell = grid[r + d.dRow * i][c + d.dCol * i];
              if (cell == null) continue;
              if (cell != w.word[i]) {
                ok = false;
                break;
              }
              overlap++;
            }
            if (ok && overlap < w.length) options.add((GridPos(r, c), d, overlap));
          }
        }
      }
      if (options.isEmpty) continue; // skip this word; the puzzle keeps the others
      final weights = [
        for (final o in options) config.preferOverlap ? 1.0 + 6.0 * o.$3 : (o.$3 == 0 ? 3.0 : 1.0),
      ];
      final pick = options[rng.weightedIndex(weights)];
      final placement = WordPlacement(word: w.word, display: w.vowelled, start: pick.$1, direction: pick.$2);
      for (final (i, p) in placement.cells.indexed) {
        grid[p.row][p.col] = w.word[i];
      }
      placements.add(placement);
    }
    if (placements.isEmpty) return null;
    final fixed = {for (final p in placements) ...p.cells};
    final letters = [
      for (var r = 0; r < config.rows; r++) [for (var c = 0; c < config.cols; c++) grid[r][c] ?? _fillLetter(rng)],
    ];
    for (var round = 0; round < 40; round++) {
      final bad = _problemCells(letters, placements, fixed);
      if (bad == null) return null; // a clash inside fixed cells: rebuild
      if (bad.isEmpty) return WordSearchPuzzle(grid: letters, placements: placements, seed: seed);
      for (final p in bad) {
        letters[p.row][p.col] = _fillLetter(rng);
      }
    }
    return null;
  }

  String _fillLetter(WordsRng rng) => _fillLetters[rng.weightedIndex(_fillWeights)];

  /// Filler cells that take part in an accidental occurrence (a second copy
  /// of a hidden word or an unsuitable sequence); `null` when an accidental
  /// occurrence uses fixed cells only.
  Set<GridPos>? _problemCells(List<List<String>> letters, List<WordPlacement> placements, Set<GridPos> fixed) {
    final bad = <GridPos>{};
    for (final occ in _occurrences(letters, [
      for (final p in placements) ArabicText.fold(p.word),
      ...filter.unsuitableSequences,
    ])) {
      final cells = occ.$2;
      final key = occ.$1;
      final isPlacement = placements.any((p) => ArabicText.fold(p.word) == key && _sameCells(p.cells, cells));
      if (isPlacement) continue;
      final free = cells.where((c) => !fixed.contains(c)).toList();
      if (free.isEmpty) return null;
      bad.addAll(free);
    }
    return bad;
  }

  static bool _sameCells(List<GridPos> a, List<GridPos> b) =>
      a.length == b.length && (a.first == b.first && a.last == b.last || a.first == b.last && a.last == b.first);

  /// Every occurrence (folded key, cells) of the [keys] in all directions.
  static List<(String, List<GridPos>)> _occurrences(List<List<String>> letters, List<String> keys) {
    final rows = letters.length, cols = rows == 0 ? 0 : letters.first.length;
    final folded = [for (final row in letters) [for (final l in row) ArabicText.foldLetter(l)]];
    final byFirst = <String, List<String>>{};
    for (final k in keys.toSet()) {
      byFirst.putIfAbsent(k[0], () => []).add(k);
    }
    final out = <(String, List<GridPos>)>[];
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final cand = byFirst[folded[r][c]];
        if (cand == null) continue;
        for (final d in GridDirection.values) {
          for (final k in cand) {
            final endR = r + d.dRow * (k.length - 1), endC = c + d.dCol * (k.length - 1);
            if (endR < 0 || endR >= rows || endC < 0 || endC >= cols) continue;
            var ok = true;
            for (var i = 1; i < k.length; i++) {
              if (folded[r + d.dRow * i][c + d.dCol * i] != k[i]) {
                ok = false;
                break;
              }
            }
            if (ok) out.add((k, [for (var i = 0; i < k.length; i++) GridPos(r + d.dRow * i, c + d.dCol * i)]));
          }
        }
      }
    }
    return out;
  }

  /// Problems with [puzzle] (empty when valid): each hidden word must occur
  /// exactly once (a palindrome's reverse reading counts as the same
  /// occurrence) and no unsuitable sequence may appear.
  static List<String> validate(WordSearchPuzzle puzzle, WordFilter filter) {
    final problems = <String>[];
    for (final p in puzzle.placements) {
      final cells = p.cells;
      if (!cells.every(puzzle.contains)) {
        problems.add('${p.word} leaves the grid');
        continue;
      }
      final text = cells.map(puzzle.at).join();
      if (text != p.word) problems.add('${p.word} reads "$text"');
    }
    final occ = _occurrences(puzzle.grid, [for (final p in puzzle.placements) ArabicText.fold(p.word)]);
    for (final p in puzzle.placements) {
      final key = ArabicText.fold(p.word);
      final distinct = <String>{};
      for (final o in occ.where((o) => o.$1 == key)) {
        final ends = [o.$2.first, o.$2.last]..sort((a, b) => a.row != b.row ? a.row - b.row : a.col - b.col);
        distinct.add('$ends');
      }
      if (distinct.length != 1) problems.add('${p.word} occurs ${distinct.length} times');
    }
    for (final o in _occurrences(puzzle.grid, filter.unsuitableSequences)) {
      problems.add('unsuitable sequence ${o.$1} at ${o.$2.first}');
    }
    return problems;
  }
}

/// Arabic crossword generator: dense, connected free-form grids from the
/// clue bank, deterministic for a seed.
///
/// Grid convention: logical columns (column 0 = right edge in RTL, see
/// letter_grid.dart). "Across" entries run in reading order (increasing
/// column = right-to-left on screen); "down" entries run top to bottom.
/// Numbering follows the usual scan – rows top to bottom, cells in reading
/// order – so 1-across starts at the top right.
///
/// Placement rules (every generated grid obeys them, see
/// [CrosswordPuzzle.validate]):
/// * every entry crosses at least one other entry and the grid is connected;
/// * the cells just before and after an entry are empty;
/// * letters that do not cross never touch a parallel neighbour, so every
///   maximal run of two or more letters is exactly one clued entry (no
///   unclued "accidental" words);
/// * each answer appears once (answers are unique by folded spelling);
/// * crossing letters are the same letter after folding (ا/أ/إ/آ, ى/ي, ة/ه).
///
/// Many seeded attempts are scored (entries, crossings, density) within a
/// small budget and the best one is cropped to its bounding box.
library;

import 'dart:typed_data';

import '../core/arabic_text.dart';
import '../core/letter_grid.dart';
import '../core/words_rng.dart';
import 'clue_bank.dart';

/// Entry orientation.
enum CrosswordAxis {
  /// Along the line (right-to-left on screen).
  across,

  /// Top to bottom.
  down;

  /// Grid step.
  GridDirection get direction => this == across ? GridDirection.forward : GridDirection.down;
}

/// Difficulty presets.
enum CrosswordDifficulty {
  /// Up to 9×9, easy clues only.
  easy,

  /// Up to 11×11, easy and medium clues.
  medium,

  /// Up to 13×13, all clues, favouring harder ones.
  hard,
}

/// Generator options.
final class CrosswordConfig {
  /// Creates options.
  const CrosswordConfig({
    required this.size,
    required this.targetWords,
    required this.maxLevel,
    this.minLevel = 1,
    this.attempts = 24,
  });

  /// The preset for [difficulty].
  factory CrosswordConfig.forDifficulty(CrosswordDifficulty difficulty) => switch (difficulty) {
    CrosswordDifficulty.easy => const CrosswordConfig(size: 9, targetWords: 9, maxLevel: 1),
    CrosswordDifficulty.medium => const CrosswordConfig(size: 11, targetWords: 13, maxLevel: 2, attempts: 16),
    CrosswordDifficulty.hard => const CrosswordConfig(size: 13, targetWords: 17, maxLevel: 3, minLevel: 2, attempts: 10),
  };

  /// Maximum rows and columns.
  final int size;

  /// Entries to aim for.
  final int targetWords;

  /// Hardest clue level used.
  final int maxLevel;

  /// Easiest clue level used (easier clues are added only when the pool is
  /// too small).
  final int minLevel;

  /// Seeded attempts compared.
  final int attempts;
}

/// One clued entry.
final class CrosswordEntry {
  /// Creates an entry.
  const CrosswordEntry({
    required this.number,
    required this.axis,
    required this.start,
    required this.answer,
    required this.display,
    required this.clue,
    required this.level,
  });

  /// Restores from JSON.
  factory CrosswordEntry.fromJson(Map<String, Object?> j) => CrosswordEntry(
    number: j['n']! as int,
    axis: CrosswordAxis.values.byName(j['axis']! as String),
    start: GridPos.fromJson(j['start']),
    answer: j['answer']! as String,
    display: j['display']! as String,
    clue: j['clue']! as String,
    level: j['level']! as int,
  );

  /// Clue number.
  final int number;

  /// Across or down.
  final CrosswordAxis axis;

  /// First cell.
  final GridPos start;

  /// Plain letters.
  final String answer;

  /// Vowelled form (shown after solving / reveal).
  final String display;

  /// Arabic clue.
  final String clue;

  /// Clue level.
  final int level;

  /// Letter count.
  int get length => answer.length;

  /// The cells in order.
  List<GridPos> get cells => [for (var i = 0; i < answer.length; i++) start.step(axis.direction, i)];

  /// Serialises.
  Map<String, Object?> toJson() => {
    'n': number,
    'axis': axis.name,
    'start': start.toJson(),
    'answer': answer,
    'display': display,
    'clue': clue,
    'level': level,
  };
}

/// A finished crossword.
final class CrosswordPuzzle {
  /// Creates a puzzle.
  CrosswordPuzzle({required this.rows, required this.cols, required this.entries, required this.seed}) {
    _solution = List.generate(rows, (_) => List<String?>.filled(cols, null));
    for (final e in entries) {
      for (final (i, p) in e.cells.indexed) {
        _solution[p.row][p.col] ??= e.answer[i];
      }
    }
  }

  /// Restores from JSON.
  factory CrosswordPuzzle.fromJson(Map<String, Object?> j) => CrosswordPuzzle(
    rows: j['rows']! as int,
    cols: j['cols']! as int,
    entries: [for (final e in j['entries']! as List<Object?>) CrosswordEntry.fromJson(e! as Map<String, Object?>)],
    seed: j['seed']! as int,
  );

  /// Rows.
  final int rows;

  /// Columns.
  final int cols;

  /// Entries sorted by number, across before down.
  final List<CrosswordEntry> entries;

  /// Seed that produced the grid.
  final int seed;

  late final List<List<String?>> _solution;

  /// Solution letter of a cell (null = block).
  String? solutionAt(GridPos p) => _solution[p.row][p.col];

  /// Whether [p] is a letter cell.
  bool isCell(GridPos p) => p.row >= 0 && p.row < rows && p.col >= 0 && p.col < cols && _solution[p.row][p.col] != null;

  /// Letter cells.
  List<GridPos> get cells => [
    for (var r = 0; r < rows; r++)
      for (var c = 0; c < cols; c++)
        if (_solution[r][c] != null) GridPos(r, c),
  ];

  /// Entries through [p].
  List<CrosswordEntry> entriesAt(GridPos p) => [for (final e in entries) if (e.cells.contains(p)) e];

  /// Letter cells / grid area.
  double get density => cells.length / (rows * cols);

  /// Cells shared by an across and a down entry.
  int get crossings => cells.where((p) => entriesAt(p).length > 1).length;

  /// Structural problems (empty when the grid obeys every placement rule).
  List<String> validate() {
    final problems = <String>[];
    final keys = <String>{};
    for (final e in entries) {
      if (!keys.add(ArabicText.fold(e.answer))) problems.add('duplicate answer ${e.answer}');
      for (final (i, p) in e.cells.indexed) {
        final s = isCell(p) ? solutionAt(p)! : null;
        if (s == null || ArabicText.foldLetter(s) != ArabicText.foldLetter(e.answer[i])) {
          problems.add('${e.answer} does not fit at $p');
        }
      }
      final before = e.start.step(e.axis.direction, -1), after = e.start.step(e.axis.direction, e.length);
      if (isCell(before) || isCell(after)) problems.add('${e.answer} touches another word end to end');
    }
    // Every maximal run of 2+ letters must be exactly one entry.
    for (final axis in CrosswordAxis.values) {
      final d = axis.direction;
      for (final p in cells) {
        if (isCell(p.step(d, -1))) continue;
        var n = 0;
        while (isCell(p.step(d, n))) {
          n++;
        }
        if (n < 2) continue;
        final match = entries.where((e) => e.axis == axis && e.start == p && e.length == n);
        if (match.isEmpty) problems.add('unclued run of $n at $p ($axis)');
      }
    }
    // Connectivity.
    final all = cells.toSet();
    if (all.isNotEmpty) {
      final seen = <GridPos>{all.first};
      final queue = [all.first];
      while (queue.isNotEmpty) {
        final p = queue.removeLast();
        for (final d in const [GridDirection.forward, GridDirection.backward, GridDirection.down, GridDirection.up]) {
          final q = p.step(d);
          if (all.contains(q) && seen.add(q)) queue.add(q);
        }
      }
      if (seen.length != all.length) problems.add('grid is not connected');
    }
    return problems;
  }

  /// Serialises.
  Map<String, Object?> toJson() => {
    'rows': rows,
    'cols': cols,
    'entries': [for (final e in entries) e.toJson()],
    'seed': seed,
  };
}

final class _Placed {
  _Placed(this.clue, this.axis, this.row, this.col);
  final ClueEntry clue;
  final CrosswordAxis axis;
  final int row, col;
}

/// A clue with its folded letters as code units (fast comparisons).
final class _Cand {
  _Cand(this.clue) : codes = Int32List.fromList(ArabicText.fold(clue.answer).codeUnits);
  final ClueEntry clue;
  final Int32List codes;
}

final class _Board {
  _Board(this.size)
    : folded = Int32List(size * size),
      letters = List<String?>.filled(size * size, null),
      acrossOwner = Uint8List(size * size),
      downOwner = Uint8List(size * size);

  final int size;

  /// Folded code unit per cell (0 = empty), row-major.
  final Int32List folded;

  /// Plain solution letter per cell.
  final List<String?> letters;
  final Uint8List acrossOwner, downOwner;
  final List<_Placed> placed = [];
  int crossings = 0;

  bool _empty(int r, int c) => r < 0 || c < 0 || r >= size || c >= size || folded[r * size + c] == 0;

  /// Number of crossings if [codes] fit at (r, c) on [axis], else -1.
  int fit(Int32List codes, CrosswordAxis axis, int r, int c) {
    final across = axis == CrosswordAxis.across;
    final dr = across ? 0 : 1, dc = across ? 1 : 0;
    final n = codes.length;
    if (r < 0 || c < 0 || r + dr * (n - 1) >= size || c + dc * (n - 1) >= size) return -1;
    if (!_empty(r - dr, c - dc) || !_empty(r + dr * n, c + dc * n)) return -1;
    var cross = 0;
    for (var i = 0; i < n; i++) {
      final rr = r + dr * i, cc = c + dc * i;
      final idx = rr * size + cc;
      final cell = folded[idx];
      if (cell != 0) {
        if (cell != codes[i]) return -1;
        if ((across ? acrossOwner[idx] : downOwner[idx]) != 0) return -1;
        cross++;
      } else if (across) {
        // A new letter must not touch parallel neighbours.
        if (!_empty(rr - 1, cc) || !_empty(rr + 1, cc)) return -1;
      } else {
        if (!_empty(rr, cc - 1) || !_empty(rr, cc + 1)) return -1;
      }
    }
    return cross;
  }

  void place(_Cand cand, CrosswordAxis axis, int r, int c, int cross) {
    final across = axis == CrosswordAxis.across;
    final dr = across ? 0 : 1, dc = across ? 1 : 0;
    final answer = cand.clue.answer;
    for (var i = 0; i < answer.length; i++) {
      final idx = (r + dr * i) * size + (c + dc * i);
      if (folded[idx] == 0) {
        folded[idx] = cand.codes[i];
        letters[idx] = answer[i];
      }
      (across ? acrossOwner : downOwner)[idx] = 1;
    }
    placed.add(_Placed(cand.clue, axis, r, c));
    crossings += cross;
  }

  double score() {
    if (placed.isEmpty) return 0;
    var minR = size, maxR = -1, minC = size, maxC = -1, filled = 0;
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        if (folded[r * size + c] == 0) continue;
        filled++;
        if (r < minR) minR = r;
        if (r > maxR) maxR = r;
        if (c < minC) minC = c;
        if (c > maxC) maxC = c;
      }
    }
    final area = (maxR - minR + 1) * (maxC - minC + 1);
    return placed.length * 100 + crossings * 25 + 200 * filled / area;
  }
}

/// Builds crosswords.
final class CrosswordGenerator {
  /// Creates a generator over [bank].
  CrosswordGenerator(List<ClueEntry> bank) : bank = List.unmodifiable(bank);

  /// The clue bank.
  final List<ClueEntry> bank;

  /// Generates a crossword with [config] from [seed].
  CrosswordPuzzle generate(CrosswordConfig config, int seed) {
    final rng = WordsRng(WordsRng.mix([seed, config.size, config.targetWords, config.maxLevel]));
    var pool = [
      for (final c in bank)
        if (c.level <= config.maxLevel && c.level >= config.minLevel && c.length >= 3 && c.length <= config.size) c,
    ];
    if (pool.length < config.targetWords * 8) {
      pool = [for (final c in bank) if (c.level <= config.maxLevel && c.length >= 3 && c.length <= config.size) c];
    }
    // Unique by folded answer.
    final seen = <String>{};
    final cands = [for (final c in pool) if (seen.add(ArabicText.fold(c.answer))) _Cand(c)];
    _Board? best;
    var bestScore = -1.0;
    for (var attempt = 0; attempt < config.attempts; attempt++) {
      final board = _attempt(cands, config, rng);
      final s = board.score();
      if (s > bestScore) {
        best = board;
        bestScore = s;
      }
    }
    return _finish(best!, seed);
  }

  _Board _attempt(List<_Cand> pool, CrosswordConfig config, WordsRng rng) {
    final board = _Board(config.size);
    final order = rng.shuffle([...pool]);
    // Seed word: a long one across the middle.
    final firstIdx = order.indexWhere((c) => c.codes.length >= (config.size >= 11 ? 6 : 5));
    final first = order[firstIdx < 0 ? 0 : firstIdx];
    board.place(first, CrosswordAxis.across, config.size ~/ 2, (config.size - first.codes.length) ~/ 2, 0);
    final used = <_Cand>{first};
    // Folded letter -> (candidate, index of the letter), in shuffled order.
    final byLetter = <int, List<(_Cand, int)>>{};
    for (final c in order) {
      for (var j = 0; j < c.codes.length; j++) {
        byLetter.putIfAbsent(c.codes[j], () => []).add((c, j));
      }
    }
    final size = config.size;
    final centre = (size - 1) / 2;
    while (board.placed.length < config.targetWords) {
      _Cand? pickCand;
      var pickAxis = CrosswordAxis.across;
      var pickR = 0, pickC = 0, pickCross = 0;
      var pickScore = double.negativeInfinity;
      for (var idx = 0; idx < size * size; idx++) {
        final code = board.folded[idx];
        if (code == 0) continue;
        final across = board.acrossOwner[idx] != 0, down = board.downOwner[idx] != 0;
        if (across && down) continue;
        final axis = across ? CrosswordAxis.down : CrosswordAxis.across;
        final r = idx ~/ size, c = idx % size;
        final list = byLetter[code];
        if (list == null) continue;
        for (final (cand, j) in list) {
          if (used.contains(cand)) continue;
          final sr = axis == CrosswordAxis.down ? r - j : r;
          final sc = axis == CrosswordAxis.across ? c - j : c;
          final cross = board.fit(cand.codes, axis, sr, sc);
          if (cross < 1) continue;
          final n = cand.codes.length;
          final midR = sr + (axis == CrosswordAxis.down ? (n - 1) / 2 : 0);
          final midC = sc + (axis == CrosswordAxis.across ? (n - 1) / 2 : 0);
          final dist = (midR - centre).abs() + (midC - centre).abs();
          final score = cross * 10.0 + n * 1.5 - dist * 0.8 + rng.nextDouble() * 3;
          if (score > pickScore) {
            pickScore = score;
            pickCand = cand;
            pickAxis = axis;
            pickR = sr;
            pickC = sc;
            pickCross = cross;
          }
        }
      }
      if (pickCand == null) break;
      board.place(pickCand, pickAxis, pickR, pickC, pickCross);
      used.add(pickCand);
    }
    return board;
  }

  CrosswordPuzzle _finish(_Board board, int seed) {
    var minR = board.size, maxR = -1, minC = board.size, maxC = -1;
    for (final p in board.placed) {
      final endR = p.row + (p.axis == CrosswordAxis.down ? p.clue.length - 1 : 0);
      final endC = p.col + (p.axis == CrosswordAxis.across ? p.clue.length - 1 : 0);
      if (p.row < minR) minR = p.row;
      if (endR > maxR) maxR = endR;
      if (p.col < minC) minC = p.col;
      if (endC > maxC) maxC = endC;
    }
    final starts = <GridPos, Map<CrosswordAxis, _Placed>>{};
    for (final p in board.placed) {
      starts.putIfAbsent(GridPos(p.row - minR, p.col - minC), () => {})[p.axis] = p;
    }
    final ordered = starts.keys.toList()..sort((a, b) => a.row != b.row ? a.row - b.row : a.col - b.col);
    final entries = <CrosswordEntry>[];
    for (final (i, pos) in ordered.indexed) {
      for (final axis in CrosswordAxis.values) {
        final p = starts[pos]![axis];
        if (p == null) continue;
        entries.add(
          CrosswordEntry(
            number: i + 1,
            axis: axis,
            start: pos,
            answer: p.clue.answer,
            display: p.clue.display,
            clue: p.clue.clue,
            level: p.clue.level,
          ),
        );
      }
    }
    return CrosswordPuzzle(rows: maxR - minR + 1, cols: maxC - minC + 1, entries: entries, seed: seed);
  }
}

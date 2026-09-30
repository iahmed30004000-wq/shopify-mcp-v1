/// Human-style Sudoku solving techniques: used to grade generated puzzles
/// and to explain hints.
///
/// Tiers (the difficulty of a puzzle is the tier of the hardest technique a
/// technique-ordered solver needs):
/// * easy – naked single, hidden single;
/// * medium – pointing, claiming (locked candidates), naked/hidden pairs and
///   triples;
/// * hard – X-wing, XY-wing, swordfish, XYZ-wing, naked/hidden quads;
/// * expert – not solvable with the above: needs chains / forcing (the hint
///   falls back to revealing a cell).
library;

import '../core/puzzle_game.dart';
import 'sudoku_core.dart';

enum SudokuTechnique {
  nakedSingle(PuzzleDifficulty.easy),
  hiddenSingle(PuzzleDifficulty.easy),
  pointing(PuzzleDifficulty.medium),
  claiming(PuzzleDifficulty.medium),
  nakedPair(PuzzleDifficulty.medium),
  hiddenPair(PuzzleDifficulty.medium),
  nakedTriple(PuzzleDifficulty.medium),
  hiddenTriple(PuzzleDifficulty.medium),
  xWing(PuzzleDifficulty.hard),
  xyWing(PuzzleDifficulty.hard),
  swordfish(PuzzleDifficulty.hard),
  xyzWing(PuzzleDifficulty.hard),
  nakedQuad(PuzzleDifficulty.hard),
  hiddenQuad(PuzzleDifficulty.hard),

  /// Not a technique: the logical solver is stuck (expert tier).
  beyondLogic(PuzzleDifficulty.expert);

  const SudokuTechnique(this.tier);
  final PuzzleDifficulty tier;
}

/// One deduction: at most one placement plus eliminations.
final class SudokuStep {
  const SudokuStep(this.technique, {this.cell = -1, this.digit = 0, this.eliminated = 0, this.focus = const []});

  final SudokuTechnique technique;

  /// Placed cell (-1 for a pure elimination step).
  final int cell;
  final int digit;

  /// Number of candidates removed.
  final int eliminated;

  /// Cells that justify the deduction.
  final List<int> focus;

  bool get isPlacement => cell >= 0;

  @override
  String toString() => 'SudokuStep(${technique.name}, cell: $cell, digit: $digit, elim: $eliminated)';
}

/// The result of grading a puzzle.
final class SudokuGrade {
  const SudokuGrade(this.solved, this.hardest, this.counts);

  /// Whether the technique set solved the puzzle.
  final bool solved;

  /// Hardest technique used, or [SudokuTechnique.beyondLogic] when stuck.
  final SudokuTechnique hardest;

  /// How many times each technique fired.
  final Map<SudokuTechnique, int> counts;

  PuzzleDifficulty get difficulty => solved ? hardest.tier : PuzzleDifficulty.expert;

  /// Number of steps at the hard tier (a finer measure inside a tier).
  int get hardSteps => counts.entries.where((e) => e.key.tier == PuzzleDifficulty.hard).fold(0, (a, e) => a + e.value);
}

/// A candidate-tracking board that applies techniques one step at a time.
final class SudokuLogic {
  /// Starts from [grid] (0 = empty); candidates are computed from the values.
  SudokuLogic(List<int> grid) : values = List<int>.from(grid), cand = List<int>.filled(81, 0) {
    for (var c = 0; c < 81; c++) {
      if (values[c] != 0) continue;
      var m = kAllDigits;
      for (final p in kPeers[c]) {
        final v = values[p];
        if (v != 0) m &= ~(1 << (v - 1));
      }
      cand[c] = m;
    }
  }

  /// Starts from [grid] with explicit candidate masks (e.g. the player's
  /// pencil marks intersected with the true candidates).
  SudokuLogic.withCandidates(List<int> grid, List<int> candidates)
    : values = List<int>.from(grid),
      cand = List<int>.from(candidates);

  final List<int> values;
  final List<int> cand;

  bool get isSolved => !values.contains(0);

  /// True when an empty cell has no candidate left.
  bool get hasContradiction {
    for (var c = 0; c < 81; c++) {
      if (values[c] == 0 && cand[c] == 0) return true;
    }
    return false;
  }

  void place(int c, int d) {
    values[c] = d;
    cand[c] = 0;
    final b = ~(1 << (d - 1));
    for (final p in kPeers[c]) {
      cand[p] &= b;
    }
  }

  /// Finds and applies the easiest available step up to [maxTier].
  SudokuStep? next({PuzzleDifficulty maxTier = PuzzleDifficulty.hard}) {
    final s = _nakedSingle() ?? _hiddenSingle();
    if (s != null || maxTier == PuzzleDifficulty.easy) return s;
    final m =
        _lockedCandidates() ??
        _nakedSubset(2) ??
        _hiddenSubset(2) ??
        _nakedSubset(3) ??
        _hiddenSubset(3);
    if (m != null || maxTier == PuzzleDifficulty.medium) return m;
    return _fish(2) ?? _xyWing() ?? _fish(3) ?? _xyzWing() ?? _nakedSubset(4) ?? _hiddenSubset(4);
  }

  /// Runs [next] until solved or stuck.
  SudokuGrade solve({PuzzleDifficulty maxTier = PuzzleDifficulty.hard}) {
    final counts = <SudokuTechnique, int>{};
    var hardest = SudokuTechnique.nakedSingle;
    while (!isSolved) {
      final s = next(maxTier: maxTier);
      if (s == null || hasContradiction) {
        return SudokuGrade(false, SudokuTechnique.beyondLogic, counts);
      }
      counts[s.technique] = (counts[s.technique] ?? 0) + 1;
      if (s.technique.index > hardest.index) hardest = s.technique;
    }
    return SudokuGrade(true, hardest, counts);
  }

  /// Grades [puzzle] with the full technique set.
  static SudokuGrade grade(List<int> puzzle) => SudokuLogic(puzzle).solve();

  // ---------------------------------------------------------------------------

  SudokuStep? _nakedSingle() {
    for (var c = 0; c < 81; c++) {
      if (values[c] == 0 && kPop9[cand[c]] == 1) {
        final d = digitOfMask(cand[c]);
        place(c, d);
        return SudokuStep(SudokuTechnique.nakedSingle, cell: c, digit: d, focus: [c]);
      }
    }
    return null;
  }

  SudokuStep? _hiddenSingle() {
    for (var h = 0; h < 27; h++) {
      final house = kHouses[h];
      var once = 0, twice = 0;
      for (final c in house) {
        final m = cand[c];
        twice |= once & m;
        once |= m;
      }
      final only = once & ~twice;
      if (only == 0) continue;
      final bit = only & -only;
      for (final c in house) {
        if (cand[c] & bit != 0) {
          final d = digitOfMask(bit);
          place(c, d);
          return SudokuStep(SudokuTechnique.hiddenSingle, cell: c, digit: d, focus: house);
        }
      }
    }
    return null;
  }

  int _eliminate(int c, int mask) {
    final before = cand[c];
    final after = before & ~mask;
    if (after == before) return 0;
    cand[c] = after;
    return kPop9[before] - kPop9[after];
  }

  SudokuStep? _lockedCandidates() {
    // Pointing: inside a box a digit is confined to one row / column.
    for (var b = 0; b < 9; b++) {
      final box = kHouses[18 + b];
      for (var d = 0; d < 9; d++) {
        final bit = 1 << d;
        var rows = 0, cols = 0, n = 0;
        for (final c in box) {
          if (cand[c] & bit != 0) {
            rows |= 1 << rowOf(c);
            cols |= 1 << colOf(c);
            n++;
          }
        }
        if (n < 2) continue;
        for (final (lines, offset) in [(rows, 0), (cols, 9)]) {
          if (kPop9[lines] != 1) continue;
          final line = kHouses[offset + digitOfMask(lines) - 1];
          var elim = 0;
          for (final c in line) {
            if (boxOf(c) != b) elim += _eliminate(c, bit);
          }
          if (elim > 0) {
            return SudokuStep(SudokuTechnique.pointing, eliminated: elim, focus: [
              for (final c in box)
                if (cand[c] & bit != 0) c,
            ]);
          }
        }
      }
    }
    // Claiming: inside a row / column a digit is confined to one box.
    for (var h = 0; h < 18; h++) {
      final line = kHouses[h];
      for (var d = 0; d < 9; d++) {
        final bit = 1 << d;
        var boxes = 0, n = 0;
        for (final c in line) {
          if (cand[c] & bit != 0) {
            boxes |= 1 << boxOf(c);
            n++;
          }
        }
        if (n < 2 || kPop9[boxes] != 1) continue;
        final b = digitOfMask(boxes) - 1;
        var elim = 0;
        for (final c in kHouses[18 + b]) {
          final inLine = h < 9 ? rowOf(c) == h : colOf(c) == h - 9;
          if (!inLine) elim += _eliminate(c, bit);
        }
        if (elim > 0) {
          return SudokuStep(SudokuTechnique.claiming, eliminated: elim, focus: [
            for (final c in line)
              if (cand[c] & bit != 0) c,
          ]);
        }
      }
    }
    return null;
  }

  static const _nakedTech = {2: SudokuTechnique.nakedPair, 3: SudokuTechnique.nakedTriple, 4: SudokuTechnique.nakedQuad};
  static const _hiddenTech = {
    2: SudokuTechnique.hiddenPair,
    3: SudokuTechnique.hiddenTriple,
    4: SudokuTechnique.hiddenQuad,
  };

  /// Visits every [k]-combination of [items]; stops when [visit] is true.
  static bool _combos(List<int> items, int k, bool Function(List<int>) visit) {
    final n = items.length;
    if (k > n) return false;
    final idx = List<int>.generate(k, (i) => i);
    final pick = List<int>.filled(k, 0);
    while (true) {
      for (var i = 0; i < k; i++) {
        pick[i] = items[idx[i]];
      }
      if (visit(pick)) return true;
      var i = k - 1;
      while (i >= 0 && idx[i] == n - k + i) {
        i--;
      }
      if (i < 0) return false;
      idx[i]++;
      for (var j = i + 1; j < k; j++) {
        idx[j] = idx[j - 1] + 1;
      }
    }
  }

  SudokuStep? _nakedSubset(int k) {
    for (var h = 0; h < 27; h++) {
      final house = kHouses[h];
      final open = [
        for (final c in house)
          if (values[c] == 0) c,
      ];
      if (open.length <= k) continue;
      final small = [
        for (final c in open)
          if (kPop9[cand[c]] >= 2 && kPop9[cand[c]] <= k) c,
      ];
      SudokuStep? found;
      _combos(small, k, (cells) {
        var union = 0;
        for (final c in cells) {
          union |= cand[c];
        }
        if (kPop9[union] != k) return false;
        var elim = 0;
        for (final c in open) {
          if (!cells.contains(c)) elim += _eliminate(c, union);
        }
        if (elim == 0) return false;
        found = SudokuStep(_nakedTech[k]!, eliminated: elim, focus: List<int>.from(cells));
        return true;
      });
      if (found != null) return found;
    }
    return null;
  }

  SudokuStep? _hiddenSubset(int k) {
    for (var h = 0; h < 27; h++) {
      final house = kHouses[h];
      final pos = List<int>.filled(9, 0);
      for (var i = 0; i < 9; i++) {
        final m = cand[house[i]];
        for (var d = 0; d < 9; d++) {
          if (m & (1 << d) != 0) pos[d] |= 1 << i;
        }
      }
      final digits = [
        for (var d = 0; d < 9; d++)
          if (kPop9[pos[d]] >= 2 && kPop9[pos[d]] <= k) d,
      ];
      final openCount = house.where((c) => values[c] == 0).length;
      if (openCount <= k) continue;
      SudokuStep? found;
      _combos(digits, k, (ds) {
        var cells = 0, keep = 0;
        for (final d in ds) {
          cells |= pos[d];
          keep |= 1 << d;
        }
        if (kPop9[cells] != k) return false;
        var elim = 0;
        final focus = <int>[];
        for (var i = 0; i < 9; i++) {
          if (cells & (1 << i) != 0) {
            focus.add(house[i]);
            elim += _eliminate(house[i], ~keep & kAllDigits);
          }
        }
        if (elim == 0) return false;
        found = SudokuStep(_hiddenTech[k]!, eliminated: elim, focus: focus);
        return true;
      });
      if (found != null) return found;
    }
    return null;
  }

  SudokuStep? _fish(int n) {
    final tech = n == 2 ? SudokuTechnique.xWing : SudokuTechnique.swordfish;
    for (var d = 0; d < 9; d++) {
      final bit = 1 << d;
      for (final byRow in const [true, false]) {
        // For each base line, the cover positions holding the digit.
        final lines = <int>[];
        final masks = List<int>.filled(9, 0);
        for (var a = 0; a < 9; a++) {
          var m = 0;
          for (var b = 0; b < 9; b++) {
            final c = byRow ? a * 9 + b : b * 9 + a;
            if (cand[c] & bit != 0) m |= 1 << b;
          }
          masks[a] = m;
          if (kPop9[m] >= 2 && kPop9[m] <= n) lines.add(a);
        }
        SudokuStep? found;
        _combos(lines, n, (base) {
          var cover = 0;
          for (final a in base) {
            cover |= masks[a];
          }
          if (kPop9[cover] != n) return false;
          var elim = 0;
          for (var a = 0; a < 9; a++) {
            if (base.contains(a)) continue;
            for (var b = 0; b < 9; b++) {
              if (cover & (1 << b) == 0) continue;
              elim += _eliminate(byRow ? a * 9 + b : b * 9 + a, bit);
            }
          }
          if (elim == 0) return false;
          found = SudokuStep(tech, eliminated: elim, focus: [
            for (final a in base)
              for (var b = 0; b < 9; b++)
                if (masks[a] & (1 << b) != 0) byRow ? a * 9 + b : b * 9 + a,
          ]);
          return true;
        });
        if (found != null) return found;
      }
    }
    return null;
  }

  SudokuStep? _xyWing() {
    for (var p = 0; p < 81; p++) {
      final pm = cand[p];
      if (values[p] != 0 || kPop9[pm] != 2) continue;
      for (final a in kPeers[p]) {
        final am = cand[a];
        if (values[a] != 0 || kPop9[am] != 2 || am == pm || kPop9[am & pm] != 1) continue;
        final z = am & ~pm;
        final bm = (pm & ~am) | z;
        for (final b in kPeers[p]) {
          if (b == a || cand[b] != bm || values[b] != 0) continue;
          var elim = 0;
          for (final c in kPeers[a]) {
            if (c != b && c != p && sees(c, b)) elim += _eliminate(c, z);
          }
          if (elim > 0) return SudokuStep(SudokuTechnique.xyWing, eliminated: elim, focus: [p, a, b]);
        }
      }
    }
    return null;
  }

  SudokuStep? _xyzWing() {
    for (var p = 0; p < 81; p++) {
      final pm = cand[p];
      if (values[p] != 0 || kPop9[pm] != 3) continue;
      final peers = kPeers[p];
      for (var i = 0; i < peers.length; i++) {
        final a = peers[i];
        final am = cand[a];
        if (values[a] != 0 || kPop9[am] != 2 || am & ~pm != 0) continue;
        for (var j = i + 1; j < peers.length; j++) {
          final b = peers[j];
          final bm = cand[b];
          if (values[b] != 0 || kPop9[bm] != 2 || bm & ~pm != 0 || bm == am) continue;
          if ((am | bm) != pm) continue;
          final z = am & bm;
          if (kPop9[z] != 1) continue;
          var elim = 0;
          for (final c in peers) {
            if (c != a && c != b && sees(c, a) && sees(c, b)) elim += _eliminate(c, z);
          }
          if (elim > 0) return SudokuStep(SudokuTechnique.xyzWing, eliminated: elim, focus: [p, a, b]);
        }
      }
    }
    return null;
  }
}

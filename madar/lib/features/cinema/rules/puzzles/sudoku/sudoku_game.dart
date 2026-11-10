/// Playable Sudoku: placements, candidate notes, conflicts, hints and undo.
library;

import '../core/puzzle_game.dart';
import 'sudoku_core.dart';
import 'sudoku_generator.dart';
import 'sudoku_logic.dart';

/// Snapshot of the player's grid.
final class SudokuState extends PuzzleState {
  const SudokuState({required this.values, required this.notes, this.moves = 0, this.mistakes = 0, this.hints = 0});

  /// Givens and player entries (0 = empty).
  final List<int> values;

  /// Pencil marks per cell (bit `d - 1` for digit `d`).
  final List<int> notes;
  final int moves;

  /// Placements that disagreed with the solution (a statistic).
  final int mistakes;

  /// Hints requested.
  final int hints;

  SudokuState copyWith({List<int>? values, List<int>? notes, int? moves, int? mistakes, int? hints}) => SudokuState(
    values: values ?? this.values,
    notes: notes ?? this.notes,
    moves: moves ?? this.moves,
    mistakes: mistakes ?? this.mistakes,
    hints: hints ?? this.hints,
  );

  @override
  Map<String, Object?> toJson() => {'values': values, 'notes': notes, 'moves': moves, 'mistakes': mistakes, 'hints': hints};

  factory SudokuState.fromJson(Map<String, Object?> j) => SudokuState(
    values: List.unmodifiable(jsonInts(j['values'])),
    notes: List.unmodifiable(jsonInts(j['notes'])),
    moves: jsonInt(j, 'moves'),
    mistakes: jsonInt(j, 'mistakes'),
    hints: jsonInt(j, 'hints'),
  );
}

enum SudokuActionType { place, erase, toggleNote, autoNotes }

final class SudokuAction extends PuzzleAction {
  const SudokuAction.place(this.cell, this.digit) : type = SudokuActionType.place;
  const SudokuAction.erase(this.cell) : type = SudokuActionType.erase, digit = 0;
  const SudokuAction.toggleNote(this.cell, this.digit) : type = SudokuActionType.toggleNote;

  /// Fills every empty cell's notes with its current candidates.
  const SudokuAction.autoNotes() : type = SudokuActionType.autoNotes, cell = -1, digit = 0;

  final SudokuActionType type;
  final int cell;
  final int digit;

  @override
  Map<String, Object?> toJson() => {'t': type.name, 'c': cell, 'd': digit};

  factory SudokuAction.fromJson(Map<String, Object?> j) {
    final c = jsonInt(j, 'c', -1), d = jsonInt(j, 'd');
    return switch (SudokuActionType.values.byName(j['t']! as String)) {
      SudokuActionType.place => SudokuAction.place(c, d),
      SudokuActionType.erase => SudokuAction.erase(c),
      SudokuActionType.toggleNote => SudokuAction.toggleNote(c, d),
      SudokuActionType.autoNotes => const SudokuAction.autoNotes(),
    };
  }

  @override
  bool operator ==(Object other) => other is SudokuAction && other.type == type && other.cell == cell && other.digit == digit;

  @override
  int get hashCode => Object.hash(type, cell, digit);

  @override
  String toString() => 'SudokuAction(${type.name}, $cell, $digit)';
}

/// A Sudoku game over a [SudokuPuzzle].
final class SudokuGame extends PuzzleBase<SudokuState, SudokuAction> {
  SudokuGame(this.puzzle, {SudokuState? state, super.history})
    : super(state ?? SudokuState(values: puzzle.givens, notes: List.unmodifiable(List<int>.filled(81, 0))));

  /// Generates a new puzzle of [difficulty] from [seed].
  factory SudokuGame.generate(PuzzleDifficulty difficulty, int seed) =>
      SudokuGame(SudokuGenerator.generate(difficulty, seed));

  factory SudokuGame.fromJson(Map<String, Object?> json) {
    checkKind(json, PuzzleKind.sudoku);
    return SudokuGame(
      SudokuPuzzle.fromJson(jsonObject(json['config'])),
      state: SudokuState.fromJson(jsonObject(json['state'])),
      history: jsonHistory(json, SudokuState.fromJson),
    );
  }

  final SudokuPuzzle puzzle;

  @override
  PuzzleKind get kind => PuzzleKind.sudoku;

  bool isGiven(int cell) => puzzle.givens[cell] != 0;

  @override
  SudokuState? transition(SudokuState s, SudokuAction a) {
    if (a.type != SudokuActionType.autoNotes && (a.cell < 0 || a.cell >= 81)) return null;
    if (a.type != SudokuActionType.autoNotes && isGiven(a.cell)) return null;
    switch (a.type) {
      case SudokuActionType.place:
        if (a.digit < 1 || a.digit > 9 || s.values[a.cell] == a.digit || isSolved) return null;
        final values = List<int>.from(s.values)..[a.cell] = a.digit;
        final notes = List<int>.from(s.notes)..[a.cell] = 0;
        final clear = ~(1 << (a.digit - 1));
        for (final p in kPeers[a.cell]) {
          notes[p] &= clear;
        }
        return s.copyWith(
          values: List.unmodifiable(values),
          notes: List.unmodifiable(notes),
          moves: s.moves + 1,
          mistakes: s.mistakes + (puzzle.solution[a.cell] == a.digit ? 0 : 1),
        );
      case SudokuActionType.erase:
        if (s.values[a.cell] == 0 && s.notes[a.cell] == 0) return null;
        return s.copyWith(
          values: List.unmodifiable(List<int>.from(s.values)..[a.cell] = 0),
          notes: List.unmodifiable(List<int>.from(s.notes)..[a.cell] = 0),
          moves: s.moves + 1,
        );
      case SudokuActionType.toggleNote:
        if (a.digit < 1 || a.digit > 9 || s.values[a.cell] != 0) return null;
        return s.copyWith(
          notes: List.unmodifiable(List<int>.from(s.notes)..[a.cell] ^= 1 << (a.digit - 1)),
          moves: s.moves + 1,
        );
      case SudokuActionType.autoNotes:
        final notes = List<int>.filled(81, 0);
        for (var c = 0; c < 81; c++) {
          if (s.values[c] == 0) notes[c] = candidatesOf(s.values, c);
        }
        if (sameList(notes, s.notes)) return null;
        return s.copyWith(notes: List.unmodifiable(notes), moves: s.moves + 1);
    }
  }

  /// Candidates of [cell] given the digits in [values] (bit mask).
  static int candidatesOf(List<int> values, int cell) {
    var m = kAllDigits;
    for (final p in kPeers[cell]) {
      final v = values[p];
      if (v != 0) m &= ~(1 << (v - 1));
    }
    return m;
  }

  /// Cells whose digit repeats inside one of their houses.
  Set<int> conflicts() {
    final out = <int>{};
    final v = state.values;
    for (final h in kHouses) {
      for (var i = 0; i < 9; i++) {
        final a = h[i];
        if (v[a] == 0) continue;
        for (var j = i + 1; j < 9; j++) {
          if (v[h[j]] == v[a]) out.addAll([a, h[j]]);
        }
      }
    }
    return out;
  }

  /// Cells whose entry differs from the (unique) solution.
  Set<int> mistakes() => {
    for (var c = 0; c < 81; c++)
      if (state.values[c] != 0 && state.values[c] != puzzle.solution[c]) c,
  };

  @override
  bool get isSolved => sameList(state.values, puzzle.solution);

  @override
  bool get isOver => isSolved;

  /// Explains the next logical placement.
  ///
  /// A wrong entry is pointed out first (`mistake`); otherwise the logical
  /// solver runs from the correct entries and reports the hardest technique
  /// needed for the next placement; when logic is stuck (expert) the most
  /// constrained cell is revealed (`reveal`).
  @override
  PuzzleHint<SudokuAction>? hint() {
    if (isSolved) return null;
    final wrong = mistakes();
    if (wrong.isNotEmpty) {
      final c = wrong.reduce((a, b) => a < b ? a : b);
      return PuzzleHint(SudokuAction.erase(c), technique: 'mistake', focus: [c]);
    }
    final logic = SudokuLogic(state.values);
    var hardest = SudokuTechnique.nakedSingle;
    final focus = <int>{};
    while (true) {
      final step = logic.next();
      if (step == null) break;
      if (step.technique.index > hardest.index) hardest = step.technique;
      if (step.technique.tier != PuzzleDifficulty.easy) focus.addAll(step.focus);
      if (step.isPlacement) {
        return PuzzleHint(
          SudokuAction.place(step.cell, step.digit),
          technique: hardest.name,
          focus: [step.cell, ...focus.where((c) => c != step.cell)],
        );
      }
    }
    var best = -1, bestPop = 10;
    for (var c = 0; c < 81; c++) {
      if (logic.values[c] == 0 && kPop9[logic.cand[c]] < bestPop) {
        best = c;
        bestPop = kPop9[logic.cand[c]];
      }
    }
    if (best < 0) return null;
    return PuzzleHint(
      SudokuAction.place(best, puzzle.solution[best]),
      technique: SudokuTechnique.beyondLogic.name,
      focus: [best],
    );
  }

  /// Records that a hint was used (a non-undoable statistic).
  void countHint() => replaceState(state.copyWith(hints: state.hints + 1));

  @override
  Map<String, Object?> configJson() => puzzle.toJson();
}

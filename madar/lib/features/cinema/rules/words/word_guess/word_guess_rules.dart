/// Letter-feedback rules of Word Guess ("Mufrada"), adapted to Arabic.
///
/// A word is a sequence of plain letters (tashkeel and tatweel ignored; a
/// word of five letters is five cells whatever its vowels). Feedback compares
/// FOLDED letters (see [ArabicText.fold]):
///
/// * alef family – ا أ إ آ are one letter: guessing ا where the answer has أ
///   is "correct"; the reveal shows the answer's true spelling;
/// * alef maqsura – ى and ي are one letter (ى only ends words);
/// * taa marbuta – ة and ه are one letter (ة only ends words, and everyday
///   spelling often writes it as ه);
/// * hamza seats – ء ؤ ئ are three DIFFERENT letters (they are separate keys
///   and change the word); both spellings of words such as مسؤول / مسئول are
///   still accepted as guesses by the dictionary (see WordGuessBank);
/// * repeated letters follow the usual two-pass rule: exact matches first,
///   then each remaining answer letter can mark at most one guess letter as
///   "present".
library;

import '../core/arabic_text.dart';

/// Feedback for one guessed letter.
enum LetterMark {
  /// Right letter, right cell.
  correct,

  /// The letter is in the word, in another cell.
  present,

  /// Not in the word (or all its occurrences are already accounted for).
  absent;

  /// Keyboard colouring keeps the best mark seen for a letter.
  LetterMark best(LetterMark? other) => other == null || index <= other.index ? this : other;
}

/// Scoring helpers.
abstract final class WordGuessRules {
  /// The folded letters of [word].
  static List<String> foldedLetters(String word) {
    final f = ArabicText.fold(word);
    return [for (var i = 0; i < f.length; i++) f[i]];
  }

  /// Marks [guess] against [answer] (both any spelling; equal letter counts).
  static List<LetterMark> score(String guess, String answer) {
    final g = foldedLetters(guess), a = foldedLetters(answer);
    if (g.length != a.length) {
      throw ArgumentError('guess has ${g.length} letters, answer ${a.length}');
    }
    final marks = List<LetterMark>.filled(g.length, LetterMark.absent);
    final remaining = <String, int>{};
    for (var i = 0; i < g.length; i++) {
      if (g[i] == a[i]) {
        marks[i] = LetterMark.correct;
      } else {
        remaining.update(a[i], (v) => v + 1, ifAbsent: () => 1);
      }
    }
    for (var i = 0; i < g.length; i++) {
      if (marks[i] == LetterMark.correct) continue;
      final left = remaining[g[i]] ?? 0;
      if (left > 0) {
        marks[i] = LetterMark.present;
        remaining[g[i]] = left - 1;
      }
    }
    return marks;
  }

  /// Hard mode: every revealed hint must be reused. Returns null when
  /// [guess] honours all [previous] rows, else the first violated hint as
  /// `(letter, position)` – position null for a "present" letter.
  static ({String letter, int? position})? hardModeViolation(
    String guess,
    List<({String guess, List<LetterMark> marks})> previous,
  ) {
    final g = foldedLetters(guess);
    for (final row in previous) {
      final p = foldedLetters(row.guess);
      final needed = <String, int>{};
      for (var i = 0; i < p.length; i++) {
        if (row.marks[i] == LetterMark.correct && g[i] != p[i]) return (letter: p[i], position: i);
        if (row.marks[i] != LetterMark.absent) needed.update(p[i], (v) => v + 1, ifAbsent: () => 1);
      }
      for (final e in needed.entries) {
        if (g.where((l) => l == e.key).length < e.value) return (letter: e.key, position: null);
      }
    }
    return null;
  }
}

/// Word Guess answers, valid-guess dictionary and daily / endless selection.
///
/// Answers are Madar's curated, family-friendly 4 / 5 / 6-letter words
/// (assets/games/word_guess_answers.json, each with a vowelled display
/// form). A guess is valid when it has the right number of letters, is not a
/// blocked word, and its lookup key ([ArabicText.lookupKey]) is in the
/// lexicon or among the answers – so hamza / alef / taa-marbuta spelling
/// variants of real words are accepted.
///
/// Daily word: day N counts calendar days from 2026-01-01 (the player's local
/// date). Days are grouped in cycles of `answers.length`; each cycle is a
/// fresh seeded permutation of the answers, so no answer repeats within a
/// cycle and every player sees the same word on the same date. Changing the
/// answer list re-deals future days (bump [WordGuessBank.dailySalt] when
/// publishing a new list mid-cycle if past days must stay stable).
library;

import 'dart:convert';

import '../core/arabic_text.dart';
import '../core/words_rng.dart';
import '../lexicon/lexicon.dart';
import '../lexicon/word_filter.dart';

/// An answer word.
final class AnswerWord {
  /// Creates an answer.
  const AnswerWord(this.word, this.vowelled);

  /// Plain letters.
  final String word;

  /// Vowelled display form.
  final String vowelled;

  /// Letter count.
  int get length => word.length;

  @override
  String toString() => word;
}

/// Answer lists and the guess dictionary.
final class WordGuessBank {
  /// Creates a bank.
  WordGuessBank({required Map<int, List<AnswerWord>> answers, required this.lexicon, required this.filter})
    : _answers = {for (final e in answers.entries) e.key: List.unmodifiable(e.value)},
      _answerKeys = {
        for (final list in answers.values)
          for (final a in list) ArabicText.lookupKey(a.word),
      };

  /// Parses assets/games/word_guess_answers.json. Answers that the [filter]
  /// marks as unsuitable are dropped defensively.
  factory WordGuessBank.parse(String jsonText, {required ArabicLexicon lexicon, required WordFilter filter}) {
    final j = jsonDecode(jsonText) as Map<String, Object?>;
    final raw = j['answers']! as Map<String, Object?>;
    final answers = <int, List<AnswerWord>>{};
    for (final e in raw.entries) {
      answers[int.parse(e.key)] = [
        for (final pair in e.value! as List<Object?>)
          if (!filter.isUnsuitable((pair! as List<Object?>)[0]! as String))
            AnswerWord(pair[0]! as String, pair[1]! as String),
      ];
    }
    return WordGuessBank(answers: answers, lexicon: lexicon, filter: filter);
  }

  /// First day of the daily puzzle (day number 0).
  static final DateTime epoch = DateTime.utc(2026);

  /// Salt mixed into the daily permutation seeds.
  static const int dailySalt = 0x4D554652; // "MUFR"

  /// Supported word lengths.
  static const List<int> lengths = [4, 5, 6];

  final Map<int, List<AnswerWord>> _answers;
  final Set<String> _answerKeys;

  /// The lexicon used as the valid-guess dictionary.
  final ArabicLexicon lexicon;

  /// The word filter.
  final WordFilter filter;

  /// Answers of [length] letters.
  List<AnswerWord> answers(int length) => _answers[length] ?? const [];

  /// Whether [word] is an acceptable guess of [length] letters.
  bool isValidGuess(String word, int length) {
    final p = ArabicText.plain(word).trim();
    if (!ArabicText.isGameWord(p) || p.length != length) return false;
    if (filter.isBlocked(p)) return false;
    return _answerKeys.contains(ArabicText.lookupKey(p)) || lexicon.contains(p);
  }

  /// Day number of [date]'s calendar day (local Y-M-D), 0 on 2026-01-01.
  static int dayNumberOf(DateTime date) =>
      DateTime.utc(date.year, date.month, date.day).difference(epoch).inDays;

  /// The daily answer of [length] letters for [day].
  AnswerWord dailyAnswer(int length, int day) {
    final list = answers(length);
    if (list.isEmpty) throw StateError('no $length-letter answers');
    final n = list.length;
    final cycle = (day / n).floor();
    final idx = day - cycle * n;
    final order = WordsRng(WordsRng.mix([dailySalt, length, cycle])).shuffle(List<int>.generate(n, (i) => i));
    return list[order[idx]];
  }

  /// A random answer for endless play avoiding [recent] words (when
  /// possible).
  AnswerWord endlessAnswer(int length, WordsRng rng, {Set<String> recent = const {}}) {
    final list = answers(length);
    if (list.isEmpty) throw StateError('no $length-letter answers');
    final fresh = [for (final a in list) if (!recent.contains(a.word)) a];
    return rng.pick(fresh.isEmpty ? list : fresh);
  }
}

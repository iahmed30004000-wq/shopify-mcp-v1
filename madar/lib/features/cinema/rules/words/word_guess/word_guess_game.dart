/// Word Guess game state ("Mufrada" – Madar's Arabic Wordle-style game).
///
/// Pure rules: a hidden answer of 4, 5 or 6 letters, a fixed number of
/// attempts, per-letter feedback ([WordGuessRules]), optional hard mode and
/// keyboard colouring. The UI owns input editing; it submits whole guesses.
library;

import '../core/arabic_text.dart';
import 'arabic_keyboard.dart';
import 'word_guess_rules.dart';

/// Daily (one shared word per day) or endless (random words).
enum WordGuessMode {
  /// One seeded word per calendar day.
  daily,

  /// Unlimited random words.
  endless,
}

/// Game options.
final class WordGuessConfig {
  /// Creates options.
  const WordGuessConfig({this.length = 5, this.maxAttempts = 6, this.hardMode = false, this.mode = WordGuessMode.daily})
    : assert(length >= 4 && length <= 6, 'Word Guess supports 4-6 letters'),
      assert(maxAttempts >= 1, 'at least one attempt');

  /// Restores from JSON.
  factory WordGuessConfig.fromJson(Map<String, Object?> j) => WordGuessConfig(
    length: j['length']! as int,
    maxAttempts: j['maxAttempts']! as int,
    hardMode: j['hardMode']! as bool,
    mode: WordGuessMode.values.byName(j['mode']! as String),
  );

  /// Letters per word.
  final int length;

  /// Allowed attempts.
  final int maxAttempts;

  /// Revealed hints must be reused.
  final bool hardMode;

  /// Daily or endless.
  final WordGuessMode mode;

  /// Serialises.
  Map<String, Object?> toJson() => {'length': length, 'maxAttempts': maxAttempts, 'hardMode': hardMode, 'mode': mode.name};
}

/// Why a guess was refused (no attempt is consumed).
enum GuessRejection {
  /// The game is already won or lost.
  gameOver,

  /// Not made of Arabic letters.
  invalidLetters,

  /// Wrong number of letters.
  wrongLength,

  /// Not in the dictionary (or a blocked word).
  notAWord,

  /// Hard mode: a revealed hint was not reused.
  hardModeViolation,
}

/// Outcome of [WordGuessGame.submit].
final class GuessResult {
  const GuessResult._(this.rejection, this.marks, this.hint);

  /// Refused guess.
  final GuessRejection? rejection;

  /// Marks of an accepted guess.
  final List<LetterMark>? marks;

  /// For [GuessRejection.hardModeViolation]: the letter that must be used
  /// and, for a "correct" hint, its cell.
  final ({String letter, int? position})? hint;

  /// Whether the guess was accepted.
  bool get accepted => rejection == null;
}

/// Progress of a game.
enum WordGuessStatus {
  /// Still guessing.
  playing,

  /// Solved.
  won,

  /// Out of attempts.
  lost,
}

/// One submitted row.
final class GuessRow {
  /// Creates a row.
  const GuessRow(this.guess, this.marks);

  /// The guess as typed (plain letters).
  final String guess;

  /// Its marks.
  final List<LetterMark> marks;

  /// Serialises.
  Map<String, Object?> toJson() => {'guess': guess, 'marks': [for (final m in marks) m.name]};
}

/// A game in progress.
final class WordGuessGame {
  /// Starts a game for [answer] (plain letters of [config.length]).
  WordGuessGame({required this.answer, this.config = const WordGuessConfig(), this.isValidWord})
    : assert(ArabicText.plain(answer).length == config.length, 'answer length must match the config');

  /// Restores a saved game; [isValidWord] is not serialised.
  factory WordGuessGame.fromJson(Map<String, Object?> j, {bool Function(String word)? isValidWord}) {
    final g = WordGuessGame(
      answer: j['answer']! as String,
      config: WordGuessConfig.fromJson(j['config']! as Map<String, Object?>),
      isValidWord: isValidWord,
    );
    for (final r in j['rows']! as List<Object?>) {
      final m = r! as Map<String, Object?>;
      g._apply(m['guess']! as String, [for (final x in m['marks']! as List<Object?>) LetterMark.values.byName(x! as String)]);
    }
    return g;
  }

  /// The hidden answer (plain letters).
  final String answer;

  /// Options.
  final WordGuessConfig config;

  /// Dictionary check (null accepts any word of Arabic letters).
  final bool Function(String word)? isValidWord;

  final List<GuessRow> _rows = [];
  final KeyboardMarks keyboard = KeyboardMarks();

  /// Submitted rows.
  List<GuessRow> get rows => List.unmodifiable(_rows);

  /// Attempts left.
  int get attemptsLeft => config.maxAttempts - _rows.length;

  /// Current status.
  WordGuessStatus get status {
    if (_rows.isNotEmpty && _rows.last.marks.every((m) => m == LetterMark.correct)) return WordGuessStatus.won;
    return _rows.length >= config.maxAttempts ? WordGuessStatus.lost : WordGuessStatus.playing;
  }

  /// Whether the game has ended.
  bool get isOver => status != WordGuessStatus.playing;

  /// Submits a guess.
  GuessResult submit(String input) {
    if (isOver) return const GuessResult._(GuessRejection.gameOver, null, null);
    final guess = ArabicText.plain(input).replaceAll(' ', '');
    if (!ArabicText.isGameWord(guess)) return const GuessResult._(GuessRejection.invalidLetters, null, null);
    if (guess.length != config.length) return const GuessResult._(GuessRejection.wrongLength, null, null);
    final valid = isValidWord;
    final isAnswer = ArabicText.fold(guess) == ArabicText.fold(answer);
    if (!isAnswer && valid != null && !valid(guess)) return const GuessResult._(GuessRejection.notAWord, null, null);
    if (config.hardMode) {
      final v = WordGuessRules.hardModeViolation(guess, [for (final r in _rows) (guess: r.guess, marks: r.marks)]);
      if (v != null) return GuessResult._(GuessRejection.hardModeViolation, null, v);
    }
    final marks = WordGuessRules.score(guess, answer);
    _apply(guess, marks);
    return GuessResult._(null, marks, null);
  }

  void _apply(String guess, List<LetterMark> marks) {
    _rows.add(GuessRow(guess, List.unmodifiable(marks)));
    keyboard.record(guess, marks);
  }

  /// A shareable emoji-free result grid ("C" correct, "P" present, "A"
  /// absent per cell, one line per row) – the UI maps it to its own tiles.
  List<String> get resultPattern => [
    for (final r in _rows) r.marks.map((m) => switch (m) { LetterMark.correct => 'C', LetterMark.present => 'P', LetterMark.absent => 'A' }).join(),
  ];

  /// Serialises (answer included – keep saves private).
  Map<String, Object?> toJson() => {
    'answer': answer,
    'config': config.toJson(),
    'rows': [for (final r in _rows) r.toJson()],
  };
}

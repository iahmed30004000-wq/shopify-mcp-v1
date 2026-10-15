/// Typing Race metrics: progress, accuracy and speed for Arabic text.
///
/// Feed the whole content of the input field to [TypingSession.update]
/// after every change (works with IME composition and autocorrect). Units
/// are those of [TypingTarget] (letters / clusters, spaces, punctuation).
///
/// * keystrokes – units added; an added unit that does not match the target
///   at its position is an error (corrected or not);
/// * accuracy = (keystrokes − errors) / keystrokes;
/// * gross WPM = typed units / 5 per minute;
/// * net WPM = correctly typed prefix / 5 per minute (the race speed);
/// * words per minute (real words) = completed target words per minute – a
///   useful Arabic-specific figure, since Arabic words are shorter than the
///   five-character convention.
library;

import 'typing_text.dart';

/// Final or intermediate figures.
final class TypingStats {
  const TypingStats({
    required this.elapsedMs,
    required this.correctUnits,
    required this.typedUnits,
    required this.keystrokes,
    required this.errors,
    required this.completedWords,
    required this.finished,
  });

  /// Time since the first keystroke.
  final int elapsedMs;

  /// Length of the correctly typed prefix.
  final int correctUnits;

  /// Units currently in the field.
  final int typedUnits;

  /// Units added over the session.
  final int keystrokes;

  /// Added units that were wrong.
  final int errors;

  /// Target words completed correctly.
  final int completedWords;

  /// Whether the whole passage is typed correctly.
  final bool finished;

  double get _minutes => elapsedMs <= 0 ? 0 : elapsedMs / 60000.0;

  /// Accuracy 0–1 (1 before any keystroke).
  double get accuracy => keystrokes == 0 ? 1 : (keystrokes - errors) / keystrokes;

  /// Gross WPM.
  double get grossWpm => _minutes == 0 ? 0 : typedUnits / 5 / _minutes;

  /// Net WPM.
  double get netWpm => _minutes == 0 ? 0 : correctUnits / 5 / _minutes;

  /// Real words per minute.
  double get wordsPerMinute => _minutes == 0 ? 0 : completedWords / _minutes;
}

/// A typing session.
final class TypingSession {
  /// Starts a session for [target].
  TypingSession(this.target);

  /// The target.
  final TypingTarget target;

  List<String> _typed = const [];
  int? _startMs;
  int _lastMs = 0;
  int _keystrokes = 0;
  int _errors = 0;
  int? _finishMs;

  /// Updates with the full field [text] at time [atMs] (any monotonic clock).
  void update(String text, int atMs) {
    if (_finishMs != null) return;
    final next = TypingTarget.unitsOf(text, target.mode, trimEnd: false);
    var common = 0;
    while (common < next.length && common < _typed.length && next[common] == _typed[common]) {
      common++;
    }
    for (var i = common; i < next.length; i++) {
      _startMs ??= atMs;
      _keystrokes++;
      if (!target.matches(i, next[i])) _errors++;
    }
    _typed = next;
    _lastMs = atMs;
    if (correctUnits == target.length && _typed.length == target.length) _finishMs = atMs;
  }

  /// Correct prefix length.
  int get correctUnits {
    var n = 0;
    while (n < _typed.length && target.matches(n, _typed[n])) {
      n++;
    }
    return n;
  }

  /// Whether the passage is complete.
  bool get finished => _finishMs != null;

  /// Progress 0–1 by correct prefix.
  double get progress => target.length == 0 ? 1 : correctUnits / target.length;

  /// Index of the first wrong unit in the field, or null.
  int? get firstError {
    final c = correctUnits;
    return c < _typed.length ? c : null;
  }

  /// Figures at [atMs] (defaults to the last update / the finish).
  TypingStats stats([int? atMs]) {
    final correct = correctUnits;
    var words = 0;
    for (var i = 0; i < correct; i++) {
      if (target.units[i] == ' ') words++;
    }
    if (correct == target.length && target.length > 0) words = target.wordCount;
    final end = _finishMs ?? atMs ?? _lastMs;
    return TypingStats(
      elapsedMs: _startMs == null ? 0 : end - _startMs!,
      correctUnits: correct,
      typedUnits: _typed.length,
      keystrokes: _keystrokes,
      errors: _errors,
      completedWords: words,
      finished: finished,
    );
  }
}

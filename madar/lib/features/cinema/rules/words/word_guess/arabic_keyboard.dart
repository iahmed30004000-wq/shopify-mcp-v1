/// On-screen Arabic keyboard model for Word Guess.
///
/// Rows follow the standard Arabic (101) PC / phone layout and are listed in
/// VISUAL left-to-right order (ض is the leftmost key of the top row, as on a
/// physical keyboard) – lay them out with `TextDirection.ltr` even inside an
/// RTL screen. The alef key offers أ إ آ as long-press variants; the لا key
/// types two letters. Key colouring is per folded letter class, so ا / أ /
/// إ / آ share one colour, as do ى / ي and ة / ه (see WordGuessRules).
library;

import '../core/arabic_text.dart';
import 'word_guess_rules.dart';

/// What a key does.
enum ArabicKeyKind {
  /// Types [ArabicKey.letters].
  letter,

  /// Submits the row.
  enter,

  /// Deletes the last letter.
  backspace,
}

/// One key.
final class ArabicKey {
  /// Creates a key.
  const ArabicKey(this.label, {this.kind = ArabicKeyKind.letter, this.variants = const [], String? letters})
    : _letters = letters; // ignore: prefer_initializing_formals

  /// The printed label.
  final String label;

  /// Kind of key.
  final ArabicKeyKind kind;

  /// Long-press alternatives (each types itself).
  final List<String> variants;

  final String? _letters;

  /// The letters typed (two for لا).
  String get letters => _letters ?? (kind == ArabicKeyKind.letter ? label : '');

  /// Folded letter classes this key belongs to (for colouring).
  List<String> get foldClasses => [for (var i = 0; i < letters.length; i++) ArabicText.foldLetter(letters[i])];
}

/// A keyboard layout.
final class ArabicKeyboardLayout {
  /// Creates a layout.
  const ArabicKeyboardLayout(this.rows);

  /// Keyboard rows, top to bottom, keys in visual left-to-right order.
  final List<List<ArabicKey>> rows;

  /// The standard layout.
  static const ArabicKeyboardLayout standard = ArabicKeyboardLayout([
    [
      ArabicKey('ض'), ArabicKey('ص'), ArabicKey('ث'), ArabicKey('ق'), ArabicKey('ف'), ArabicKey('غ'), //
      ArabicKey('ع'), ArabicKey('ه'), ArabicKey('خ'), ArabicKey('ح'), ArabicKey('ج'), ArabicKey('د'),
    ],
    [
      ArabicKey('ش'), ArabicKey('س'), ArabicKey('ي'), ArabicKey('ب'), ArabicKey('ل'), //
      ArabicKey('ا', variants: ['أ', 'إ', 'آ']), ArabicKey('ت'), ArabicKey('ن'), ArabicKey('م'), ArabicKey('ك'),
      ArabicKey('ط'), ArabicKey('ذ'),
    ],
    [
      ArabicKey('↵', kind: ArabicKeyKind.enter), ArabicKey('ئ'), ArabicKey('ء'), ArabicKey('ؤ'), ArabicKey('ر'), //
      ArabicKey('لا', letters: 'لا'), ArabicKey('ى'), ArabicKey('ة'), ArabicKey('و'), ArabicKey('ز'), ArabicKey('ظ'),
      ArabicKey('⌫', kind: ArabicKeyKind.backspace),
    ],
  ]);

  /// Every letter that can be typed (keys and variants).
  Set<String> get typeableLetters => {
    for (final row in rows)
      for (final k in row) ...[
        for (var i = 0; i < k.letters.length; i++) k.letters[i],
        ...k.variants,
      ],
  };
}

/// Best known mark per folded letter class (keyboard colouring).
final class KeyboardMarks {
  /// Creates an empty board.
  KeyboardMarks() : _marks = {};

  KeyboardMarks._(this._marks);

  /// Restores from JSON.
  factory KeyboardMarks.fromJson(Map<String, Object?> json) =>
      KeyboardMarks._({for (final e in json.entries) e.key: LetterMark.values.byName(e.value! as String)});

  final Map<String, LetterMark> _marks;

  /// Records a scored guess.
  void record(String guess, List<LetterMark> marks) {
    final letters = WordGuessRules.foldedLetters(guess);
    for (var i = 0; i < letters.length; i++) {
      _marks[letters[i]] = marks[i].best(_marks[letters[i]]);
    }
  }

  /// Mark of a letter (any spelling), or null when never guessed.
  LetterMark? markOf(String letter) => _marks[ArabicText.foldLetter(ArabicText.plain(letter))];

  /// Mark of a key: the best mark among its letter classes (null = unused).
  LetterMark? markOfKey(ArabicKey key) {
    LetterMark? best;
    for (final c in key.foldClasses) {
      final m = _marks[c];
      if (m != null) best = m.best(best);
    }
    return best;
  }

  /// Serialises.
  Map<String, Object?> toJson() => {for (final e in _marks.entries) e.key: e.value.name};
}

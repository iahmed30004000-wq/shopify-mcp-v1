/// The crossword clue bank (assets/games/crossword_clues.json): original
/// Arabic clues written for Madar.
library;

import 'dart:convert';

/// One clue / answer pair.
final class ClueEntry {
  /// Creates an entry.
  const ClueEntry({required this.answer, required this.display, required this.clue, required this.level});

  /// Plain letters of the answer.
  final String answer;

  /// Vowelled display form of the answer.
  final String display;

  /// The Arabic clue.
  final String clue;

  /// 1 easy, 2 medium, 3 hard.
  final int level;

  /// Letter count.
  int get length => answer.length;
}

/// Parsed clue bank.
abstract final class ClueBank {
  /// Parses the asset file.
  static List<ClueEntry> parse(String jsonText) {
    final j = jsonDecode(jsonText) as Map<String, Object?>;
    return List.unmodifiable([
      for (final c in j['clues']! as List<Object?>)
        () {
          final m = c! as Map<String, Object?>;
          return ClueEntry(
            answer: m['a']! as String,
            display: m['d']! as String,
            clue: m['c']! as String,
            level: m['l']! as int,
          );
        }(),
    ]);
  }
}

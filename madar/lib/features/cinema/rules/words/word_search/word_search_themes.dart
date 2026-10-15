/// Themed word lists for Word Search (assets/games/word_search_themes.json).
library;

import 'dart:convert';

/// A word with its vowelled display form.
final class ThemeWord {
  /// Creates a word.
  const ThemeWord(this.word, this.vowelled);

  /// Plain letters (what the grid shows).
  final String word;

  /// Vowelled display form (for the word list).
  final String vowelled;

  /// Letter count.
  int get length => word.length;
}

/// A theme.
final class WordSearchTheme {
  /// Creates a theme.
  const WordSearchTheme({required this.id, required this.titleAr, required this.titleEn, required this.words});

  /// Stable id (e.g. `fruits`).
  final String id;

  /// Arabic title (content).
  final String titleAr;

  /// English title (content).
  final String titleEn;

  /// The words.
  final List<ThemeWord> words;

  /// Parses all themes from the asset file.
  static List<WordSearchTheme> parseAll(String jsonText) {
    final j = jsonDecode(jsonText) as Map<String, Object?>;
    return [
      for (final t in j['themes']! as List<Object?>)
        () {
          final m = t! as Map<String, Object?>;
          final title = m['title']! as Map<String, Object?>;
          return WordSearchTheme(
            id: m['id']! as String,
            titleAr: title['ar']! as String,
            titleEn: title['en']! as String,
            words: List.unmodifiable([
              for (final w in m['words']! as List<Object?>)
                if (w case [final String word, final String vowelled]) ThemeWord(word, vowelled),
            ]),
          );
        }(),
    ];
  }
}

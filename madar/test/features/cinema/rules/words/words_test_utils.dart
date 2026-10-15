import 'dart:io';

import 'package:madar/features/cinema/rules/words/words.dart';

/// Reads a bundled asset from the repository (tests run from the root).
String readAsset(String path) => File(path).readAsStringSync();

/// Asset loader for [WordsContent].
Future<String> loadAsset(String path) async => readAsset(path);

/// Cached banks (parsing the 1 MB lexicon once keeps the suite fast).
final ArabicLexicon lexicon = ArabicLexicon.parse(readAsset(WordsAssets.lexicon));
final WordFilter wordFilter = WordFilter.parse(readAsset(WordsAssets.wordFilter));
final WordGuessBank guessBank = WordGuessBank.parse(
  readAsset(WordsAssets.wordGuessAnswers),
  lexicon: lexicon,
  filter: wordFilter,
);
final List<WordSearchTheme> themes = WordSearchTheme.parseAll(readAsset(WordsAssets.wordSearchThemes));
final List<ClueEntry> clues = ClueBank.parse(readAsset(WordsAssets.crosswordClues));
final IslamicQuizBank quizBank = IslamicQuizBank.parse(readAsset(WordsAssets.islamicQuiz));
final List<Country> countries = Country.parseAll(readAsset(WordsAssets.countries));
final TypingPassageBank passageBank = TypingPassageBank.parse(readAsset(WordsAssets.typingPassages));
final QuranTextIndex quranIndex = QuranTextIndex.parse(readAsset(WordsAssets.quranText));

/// Runs [body] once to warm up the JIT, then returns the slowest of [runs]
/// timed runs in milliseconds.
int slowestMs(void Function(int run) body, {int runs = 5}) {
  body(-1);
  var worst = 0;
  for (var i = 0; i < runs; i++) {
    final sw = Stopwatch()..start();
    body(i);
    sw.stop();
    if (sw.elapsedMilliseconds > worst) worst = sw.elapsedMilliseconds;
  }
  return worst;
}

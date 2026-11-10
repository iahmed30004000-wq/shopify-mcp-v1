/// Asset paths of the word / quiz game content and a loader that parses
/// each bank once.
///
/// The rules stay free of Flutter: pass any `Future<String> Function(path)`
/// (in the app `rootBundle.loadString`, in tests `File(path).readAsString`).
library;

import '../crossword/clue_bank.dart';
import '../geo/countries.dart';
import '../lexicon/lexicon.dart';
import '../lexicon/word_filter.dart';
import '../quiz/islamic_quiz.dart';
import '../typing/passage_bank.dart';
import '../word_guess/word_guess_bank.dart';
import '../word_search/word_search_themes.dart';

/// Loads the text of an asset.
typedef AssetTextLoader = Future<String> Function(String path);

/// Asset paths.
abstract final class WordsAssets {
  /// Arabic game lexicon.
  static const lexicon = 'assets/games/arabic_lexicon.txt';

  /// Word filter.
  static const wordFilter = 'assets/games/arabic_word_filter.json';

  /// Word Guess answers.
  static const wordGuessAnswers = 'assets/games/word_guess_answers.json';

  /// Word Search themes.
  static const wordSearchThemes = 'assets/games/word_search_themes.json';

  /// Crossword clue bank.
  static const crosswordClues = 'assets/games/crossword_clues.json';

  /// Islamic quiz.
  static const islamicQuiz = 'assets/games/islamic_quiz.json';

  /// Countries, capitals and flags.
  static const countries = 'assets/games/countries.json';

  /// Typing Race passages.
  static const typingPassages = 'assets/games/typing_passages.json';

  /// The bundled Tanzil Quran text (read-only; owned by the Quran feature).
  static const quranText = 'assets/quran/quran-uthmani.txt';
}

/// Lazily loads and caches every bank.
final class WordsContent {
  /// Creates a loader.
  WordsContent(this._load);

  final AssetTextLoader _load;

  Future<ArabicLexicon>? _lexicon;
  Future<WordFilter>? _filter;
  Future<WordGuessBank>? _guess;
  Future<List<WordSearchTheme>>? _themes;
  Future<List<ClueEntry>>? _clues;
  Future<IslamicQuizBank>? _quiz;
  Future<List<Country>>? _countries;
  Future<TypingPassageBank>? _passages;
  Future<QuranTextIndex>? _quran;

  /// The lexicon.
  Future<ArabicLexicon> lexicon() => _lexicon ??= _load(WordsAssets.lexicon).then(ArabicLexicon.parse);

  /// The word filter.
  Future<WordFilter> filter() => _filter ??= _load(WordsAssets.wordFilter).then(WordFilter.parse);

  /// Word Guess answers + dictionary.
  Future<WordGuessBank> wordGuess() => _guess ??= () async {
    final lex = await lexicon();
    final f = await filter();
    return WordGuessBank.parse(await _load(WordsAssets.wordGuessAnswers), lexicon: lex, filter: f);
  }();

  /// Word Search themes.
  Future<List<WordSearchTheme>> themes() =>
      _themes ??= _load(WordsAssets.wordSearchThemes).then(WordSearchTheme.parseAll);

  /// Crossword clue bank.
  Future<List<ClueEntry>> clues() => _clues ??= _load(WordsAssets.crosswordClues).then(ClueBank.parse);

  /// Islamic quiz.
  Future<IslamicQuizBank> islamicQuiz() => _quiz ??= _load(WordsAssets.islamicQuiz).then(IslamicQuizBank.parse);

  /// Countries.
  Future<List<Country>> countries() => _countries ??= _load(WordsAssets.countries).then(Country.parseAll);

  /// Typing passages.
  Future<TypingPassageBank> passages() =>
      _passages ??= _load(WordsAssets.typingPassages).then(TypingPassageBank.parse);

  /// The Quran text index (for Quran typing passages).
  Future<QuranTextIndex> quran() => _quran ??= _load(WordsAssets.quranText).then(QuranTextIndex.parse);
}

/// Madar Cinema Tier 2 word and knowledge games – pure-Dart rules,
/// generators and content models:
///
/// * Word Guess ("Mufrada", Arabic Wordle-style): word_guess/
/// * Word Search: word_search/
/// * Crossword: crossword/
/// * Islamic Quiz: quiz/
/// * Capitals & Flags (code-drawn flags): geo/
/// * Typing Race: typing/
///
/// Content lives in assets/games/ (see CONTENT.md in this folder for
/// sources, licences and review notes); load it with `WordsContent`.
library;

export 'core/arabic_text.dart';
export 'core/letter_grid.dart';
export 'core/words_assets.dart';
export 'core/words_rng.dart';
export 'crossword/clue_bank.dart';
export 'crossword/crossword_game.dart';
export 'crossword/crossword_generator.dart';
export 'geo/capitals_quiz.dart';
export 'geo/countries.dart';
export 'geo/flag_spec.dart';
export 'lexicon/lexicon.dart';
export 'lexicon/word_filter.dart';
export 'quiz/islamic_quiz.dart';
export 'quiz/quiz_engine.dart';
export 'typing/ghost.dart';
export 'typing/passage_bank.dart';
export 'typing/typing_session.dart';
export 'typing/typing_text.dart';
export 'word_guess/arabic_keyboard.dart';
export 'word_guess/word_guess_bank.dart';
export 'word_guess/word_guess_game.dart';
export 'word_guess/word_guess_rules.dart';
export 'word_guess/word_guess_stats.dart';
export 'word_search/word_search_game.dart';
export 'word_search/word_search_generator.dart';
export 'word_search/word_search_themes.dart';

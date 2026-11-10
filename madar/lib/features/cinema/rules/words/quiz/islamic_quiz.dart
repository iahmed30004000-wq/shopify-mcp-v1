/// The Islamic Quiz bank (assets/games/islamic_quiz.json).
///
/// Original questions written for Madar, Arabic first with English
/// translations. Every question cites at least one source – a Quran ayah of
/// the bundled Tanzil text, a hadith (collection + number) or a fact of the
/// mushaf's structure – and each citation carries a verification key that
/// the content build (and the tests, for the Quran) checked against the
/// cited text. Categories: quran, prophets, seerah, pillars, companions,
/// manners. Levels 1–3. Contested fiqh questions are deliberately absent.
library;

import 'dart:convert';

import '../core/words_rng.dart';
import 'quiz_engine.dart';

/// Parsed quiz bank.
final class IslamicQuizBank {
  IslamicQuizBank._(this.questions, this.categories);

  /// Parses the asset file.
  factory IslamicQuizBank.parse(String jsonText) {
    final j = jsonDecode(jsonText) as Map<String, Object?>;
    final questions = <QuizQuestion>[];
    for (final raw in j['questions']! as List<Object?>) {
      final m = raw! as Map<String, Object?>;
      final o = m['o']! as Map<String, Object?>;
      final ar = o['ar']! as List<Object?>, en = o['en']! as List<Object?>;
      questions.add(
        QuizQuestion(
          id: m['id']! as String,
          category: m['cat']! as String,
          level: m['lvl']! as int,
          prompt: LocalizedText.fromJson(m['q']),
          options: [for (var i = 0; i < ar.length; i++) LocalizedText(ar[i]! as String, en[i]! as String)],
          answerIndex: m['a']! as int,
          sources: [for (final s in m['src']! as List<Object?>) QuizSource.fromJson(s! as Map<String, Object?>)],
        ),
      );
    }
    return IslamicQuizBank._(
      List.unmodifiable(questions),
      List.unmodifiable([for (final c in j['categories']! as List<Object?>) c! as String]),
    );
  }

  /// All questions.
  final List<QuizQuestion> questions;

  /// Category ids.
  final List<String> categories;

  /// Questions filtered by [category] and / or [levels].
  List<QuizQuestion> filter({String? category, Set<int>? levels}) => [
    for (final q in questions)
      if ((category == null || q.category == category) && (levels == null || levels.contains(q.level))) q,
  ];

  /// Starts a session: draws unseen questions from the filtered pool via
  /// [deck] (so repeats only happen after the pool is exhausted).
  QuizSession startSession({
    required QuizDeck deck,
    required int seed,
    QuizConfig config = const QuizConfig(),
    String? category,
    Set<int>? levels,
  }) {
    final rng = WordsRng(seed);
    final drawn = deck.draw(filter(category: category, levels: levels), config.questionCount + config.reserve, rng);
    return QuizSession(drawn, config: config, seed: rng.nextUint32());
  }
}

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/cinema/rules/words/words.dart';

import 'words_test_utils.dart';

QuizQuestion _q(String id, {int level = 1}) => QuizQuestion(
  id: id,
  category: 'test',
  level: level,
  prompt: LocalizedText('س $id', 'Q $id'),
  options: const [LocalizedText('أ', 'A'), LocalizedText('ب', 'B'), LocalizedText('ج', 'C'), LocalizedText('د', 'D')],
  answerIndex: 2,
);

void main() {
  group('deck', () {
    test('draws without repeats until the pool is exhausted, then starts a new cycle', () {
      final pool = [for (var i = 0; i < 25; i++) _q('q$i')];
      final deck = QuizDeck();
      final rng = WordsRng(1);
      final seen = <String>{};
      for (var round = 0; round < 2; round++) {
        for (final q in deck.draw(pool, 10, rng).take(10)) {
          expect(seen.add(q.id), isTrue);
        }
      }
      final third = deck.draw(pool, 10, rng);
      expect(third.map((q) => q.id).toSet().length, 10);
      expect(third.where((q) => !seen.contains(q.id)).length, 5); // the 5 never shown come first
      expect(deck.cycle, 1);
      final back = QuizDeck.fromJson(jsonDecode(jsonEncode(deck.toJson())) as Map<String, Object?>);
      expect(back.seen, deck.seen);
    });

    test('islamic quiz sessions never repeat a question before the pool is used up', () {
      final deck = QuizDeck();
      final asked = <String>{};
      final pool = quizBank.filter(category: 'prophets');
      var total = 0;
      for (var s = 0; total + 13 <= pool.length; s++) {
        final session = quizBank.startSession(deck: deck, seed: s, category: 'prophets');
        while (!session.finished) {
          expect(asked.add(session.current.id), isTrue, reason: session.current.id);
          session.answer(session.correctOption);
          total++;
        }
        total += 3; // reserves drawn with the session
      }
      expect(asked.length, greaterThan(50));
    });
  });

  group('session', () {
    test('scoring: level points, streak bonus, 50/50 halving, time bonus', () {
      final qs = [_q('a'), _q('b', level: 2), _q('c', level: 3), _q('d')];
      final s = QuizSession(qs, config: const QuizConfig(questionCount: 4, timeLimitMs: 10000, reserve: 0), seed: 5);
      expect(s.options.length, 4);
      expect(s.options[s.correctOption].en, 'C');
      final o1 = s.answer(s.correctOption, elapsedMs: 10000);
      expect(o1.points, 100);
      final o2 = s.answer(s.correctOption, elapsedMs: 10000);
      expect(o2.points, 220); // 200 * 1.1
      expect(s.useFiftyFifty(), isTrue);
      expect(s.hiddenOptions.length, 2);
      expect(s.hiddenOptions, isNot(contains(s.correctOption)));
      expect(s.useFiftyFifty(), isFalse);
      final o3 = s.answer(s.correctOption, elapsedMs: 0);
      expect(o3.points, (300 * 1.2 * 0.5 * 1.5).round());
      final o4 = s.answer((s.correctOption + 1) % 4);
      expect(o4.correct, isFalse);
      expect(o4.points, 0);
      expect(s.finished, isTrue);
      expect(s.streak, 0);
      expect(s.bestStreak, 3);
      expect(s.correctCount, 3);
      expect(s.score, o1.points + o2.points + o3.points);
    });

    test('skip replaces the question from the reserve and keeps the streak', () {
      final qs = [for (var i = 0; i < 6; i++) _q('q$i')];
      final s = QuizSession(qs, config: const QuizConfig(questionCount: 3, reserve: 2, skips: 1), seed: 1);
      s.answer(s.correctOption);
      final before = s.current.id;
      expect(s.skip(), isTrue);
      expect(s.current.id, isNot(before));
      expect(s.skip(), isFalse);
      s.answer(s.correctOption);
      expect(s.streak, 2);
      s.answer(null); // timeout
      expect(s.finished, isTrue);
      expect(s.answeredCount, 3);
    });

    test('option order is seeded and deterministic', () {
      List<String> order(int seed) => QuizSession([_q('x')], seed: seed).options.map((o) => o.en).toList();
      expect(order(3), order(3));
      final orders = {for (var s = 0; s < 20; s++) order(s).join()};
      expect(orders.length, greaterThan(3));
    });
  });

  group('islamic quiz bank', () {
    test('filters and answers are consistent', () {
      expect(quizBank.filter(levels: {3}).every((q) => q.level == 3), isTrue);
      expect(quizBank.filter(category: 'quran').length, greaterThan(50));
      final q = quizBank.questions.firstWhere((q) => q.prompt.ar.contains('كم عدد سور القرآن'));
      expect(q.answer.en, '114');
      expect(q.sources.first.type, 'meta');
      final hira = quizBank.questions.firstWhere((q) => q.sources.any((s) => s.book == 'bukhari' && s.number == 3));
      expect(hira.sources.first.cite.en, startsWith('Sahih al-Bukhari'));
    });
  });
}

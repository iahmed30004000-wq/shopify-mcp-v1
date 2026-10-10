import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/cinema/rules/words/words.dart';

import 'words_test_utils.dart';

const c = LetterMark.correct, p = LetterMark.present, a = LetterMark.absent;

void main() {
  group('feedback rules', () {
    test('correct, present and absent', () {
      expect(WordGuessRules.score('مدرسة', 'مدرسة'), [c, c, c, c, c]);
      expect(WordGuessRules.score('سمكة', 'كمال'), [a, c, p, a]);
    });

    test('repeated letters: exact matches first, each answer letter used once', () {
      // Answer has one ل; the guess has two – only one can be marked.
      expect(WordGuessRules.score('للبن', 'قلبي'), [a, c, c, a]);
      // Two ب in the answer, two in the guess in the wrong cells -> both present.
      expect(WordGuessRules.score('بسبت', 'تبرب'), [p, a, p, p]);
    });

    test('alef forms, alef maqsura and taa marbuta fold; hamza seats do not', () {
      expect(WordGuessRules.score('اسرة', 'أسرة'), [c, c, c, c]);
      expect(WordGuessRules.score('مدرسه', 'مدرسة'), [c, c, c, c, c]);
      expect(WordGuessRules.score('مشي', 'مشى'), [c, c, c]);
      expect(WordGuessRules.score('سئال', 'سؤال'), [c, a, c, c]);
    });

    test('hard mode requires reusing hints', () {
      final prev = [(guess: 'قلمي', marks: WordGuessRules.score('قلمي', 'قمري'))];
      expect(WordGuessRules.hardModeViolation('قمري', prev), isNull);
      expect(WordGuessRules.hardModeViolation('بيتي', prev)?.letter, 'ق');
    });
  });

  group('game', () {
    test('win flow, rejections, keyboard marks and JSON round trip', () {
      final g = WordGuessGame(answer: 'مدرسة', isValidWord: (w) => guessBank.isValidGuess(w, 5));
      expect(g.submit('مدرس').rejection, GuessRejection.wrongLength);
      expect(g.submit('abcde').rejection, GuessRejection.invalidLetters);
      expect(g.submit('ضضضضض').rejection, GuessRejection.notAWord);
      final r1 = g.submit('مكتبة');
      expect(r1.accepted, isTrue);
      expect(r1.marks, [c, a, a, a, c]);
      expect(g.keyboard.markOf('م'), c);
      expect(g.keyboard.markOf('ه'), c); // ة and ه share a class
      expect(g.keyboard.markOfKey(const ArabicKey('ك')), a);
      final saved = WordGuessGame.fromJson(jsonDecode(jsonEncode(g.toJson())) as Map<String, Object?>);
      expect(saved.rows.length, 1);
      expect(saved.keyboard.markOf('م'), c);
      final r2 = g.submit('مَدْرَسَة');
      expect(r2.marks, everyElement(c));
      expect(g.status, WordGuessStatus.won);
      expect(g.submit('مكتبة').rejection, GuessRejection.gameOver);
      expect(g.resultPattern, ['CAAAC', 'CCCCC']);
    });

    test('loses after the last attempt; hard mode is enforced', () {
      final g = WordGuessGame(answer: 'قمري', config: const WordGuessConfig(length: 4, maxAttempts: 2, hardMode: true));
      expect(g.submit('قلمي').accepted, isTrue);
      final bad = g.submit('بيتي');
      expect(bad.rejection, GuessRejection.hardModeViolation);
      expect(bad.hint?.letter, 'ق');
      expect(g.submit('قمحي').accepted, isTrue);
      expect(g.status, WordGuessStatus.lost);
    });
  });

  group('bank', () {
    test('dictionary accepts spelling variants and rejects blocked words', () {
      expect(guessBank.isValidGuess('مدرسة', 5), isTrue);
      expect(guessBank.isValidGuess('مدرسه', 5), isTrue);
      expect(guessBank.isValidGuess('مسئول', 5) || guessBank.isValidGuess('مسؤول', 5), isTrue);
      expect(guessBank.isValidGuess('مدرسة', 4), isFalse);
      expect(guessBank.isValidGuess('قحبة', 4), isFalse);
      expect(guessBank.isValidGuess('ثثثثث', 5), isFalse);
    });

    test('daily word is deterministic and never repeats within a cycle', () {
      final n = guessBank.answers(5).length;
      final seen = <String>{};
      for (var d = 0; d < n; d++) {
        expect(seen.add(guessBank.dailyAnswer(5, d).word), isTrue, reason: 'day $d');
      }
      expect(guessBank.dailyAnswer(5, 10).word, guessBank.dailyAnswer(5, 10).word);
      expect(guessBank.dailyAnswer(5, -3).length, 5); // before the epoch still works
      expect(WordGuessBank.dayNumberOf(DateTime(2026)), 0);
      expect(WordGuessBank.dayNumberOf(DateTime(2026, 9, 30, 23, 59)), 272);
      for (final len in WordGuessBank.lengths) {
        expect(guessBank.dailyAnswer(len, 100).length, len);
      }
    });

    test('endless mode avoids recent words', () {
      final rng = WordsRng(3);
      final recent = <String>{};
      for (var i = 0; i < 50; i++) {
        final w = guessBank.endlessAnswer(4, rng, recent: recent);
        expect(recent.add(w.word), isTrue);
      }
    });
  });

  group('stats', () {
    test('daily streaks continue on consecutive wins and reset on gaps or losses', () {
      var s = const WordGuessStats();
      s = s.recordDaily(10, won: true, attempts: 3);
      s = s.recordDaily(11, won: true, attempts: 4);
      expect(s.currentStreak, 2);
      expect(s.recordDaily(11, won: false, attempts: 6), same(s)); // same day ignored
      s = s.recordDaily(13, won: true, attempts: 2); // gap
      expect(s.currentStreak, 1);
      s = s.recordDaily(14, won: false, attempts: 6);
      expect(s.currentStreak, 0);
      expect(s.maxStreak, 2);
      expect(s.played, 4);
      expect(s.won, 3);
      expect(s.distribution, [0, 1, 1, 1, 0, 0]);
      expect(s.winRate, 75);
      final back = WordGuessStats.fromJson(jsonDecode(jsonEncode(s.toJson())) as Map<String, Object?>);
      expect(back.toJson(), s.toJson());
      final e = const WordGuessStats().recordEndless(won: true, attempts: 7);
      expect(e.distribution.length, 7);
    });
  });

  group('keyboard', () {
    test('the layout can type every game letter; alef variants share a colour', () {
      final typeable = ArabicKeyboardLayout.standard.typeableLetters;
      for (var i = 0; i < ArabicText.letters.length; i++) {
        expect(typeable, contains(ArabicText.letters[i]));
      }
      final alef = ArabicKeyboardLayout.standard.rows[1].firstWhere((k) => k.label == 'ا');
      expect(alef.variants, ['أ', 'إ', 'آ']);
      final la = ArabicKeyboardLayout.standard.rows[2].firstWhere((k) => k.letters == 'لا');
      expect(la.foldClasses, ['ل', 'ا']);
    });
  });
}

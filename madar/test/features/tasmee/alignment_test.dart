// «التسميع»: what the engine says about a real recitation, driven by the
// scripted stub – a clean recitation, a dropped word, an inserted word, a
// wrong word, a restart mid-verse, a long pause, a verse recited twice and
// a basmala before a surah. Every assertion is about the verdict **and its
// position in the original text**.
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/quran/ayah.dart';
import 'package:madar/features/tasmee/tasmee.dart';

import 'tasmee_fixtures.dart';

void main() {
  // «ٱلْحَمْدُ لِلَّهِ رَبِّ ٱلْعَـٰلَمِينَ» – four words, short enough to read
  // every assertion by eye.
  const fatiha2 = AyahRef(1, 2);
  const ikhlas1 = AyahRef(112, 1);

  late RecitationTarget target;
  late List<String> said;

  setUp(() {
    target = targetOfAyah(fatiha2);
    said = verifiedWords(target);
  });

  RecitationCheck check(RecitationScript script, {RecitationTarget? on, AlignmentOptions? options}) =>
      TasmeeAligner.align(on ?? target, script.heardWords(), options: options ?? const AlignmentOptions());

  group('the words of the verified text', () {
    test('an ayah is cut into its real words, each with its own range in the original', () {
      expect(target.wordCount, 4);
      final text = ayahText(fatiha2);
      for (final w in target.words) {
        expect(text.substring(w.start, w.end), w.text, reason: 'the range must point at the word itself');
        expect(w.ref, fatiha2);
      }
      expect(target.words.map((w) => w.indexInAyah), [0, 1, 2, 3]);
      expect(target.words.first.start, 0);
      expect(target.words.last.end, text.length);
    });

    test('the Uthmani pause and hizb signs are not words, and the real words keep their places', () {
      // 2:2 writes «ۛ» twice as a token of its own; 2:26 opens with «۞».
      final t = targetOfAyah(const AyahRef(2, 2));
      final text = ayahText(const AyahRef(2, 2));
      expect(text.split(' '), hasLength(9), reason: 'nine tokens in the original');
      expect(t.wordCount, 7, reason: 'two of them are the small «sakta» signs, not words');
      expect(t.words.any((w) => w.text.trim() == '\u06DB'), isFalse);
      for (final w in t.words) {
        expect(text.substring(w.start, w.end), w.text);
      }
      final hizb = targetOfAyah(const AyahRef(2, 26));
      expect(hizb.words.first.text, 'إِنَّ');
      expect(hizb.words.first.start, greaterThan(0), reason: 'the hizb sign is still in the original text');
    });
  });

  group('a clean recitation', () {
    test('every word is right, nothing extra, no pause, and the score is full', () {
      final result = check(cleanScript(target));
      expect(verdicts(result), List.filled(4, WordVerdict.right));
      expect(result.extras, isEmpty);
      expect(result.pauses, isEmpty);
      expect(result.counts.mistakes, 0);
      expect(result.counts.accuracy, 1.0);
      expect(result.isClean, isTrue);
      expect(result.cursor, isNull);
    });

    test('the everyday spelling is the same recitation as the Uthmani one', () {
      final result = check(RecitationScript.of(['الحمد', 'لله', 'رب', 'العالمين']));
      expect(verdicts(result), List.filled(4, WordVerdict.right));
      expect(result.isClean, isTrue);
      // What was heard is kept as "heard", never as the verse.
      expect(result.words.first.heard, 'الحمد');
      expect(result.words.first.word.text, 'ٱلْحَمْدُ');
    });

    test('a word the Uthmani script joins still matches two heard words', () {
      // 2:21 «يَـٰٓأَيُّهَا ٱلنَّاسُ ٱعْبُدُوا۟ رَبَّكُمُ …» – the first word is
      // «يا أيها» written joined.
      final t = targetOfAyah(const AyahRef(2, 21));
      final heard = ['يا', 'أيها', ...verifiedWords(t).skip(1)];
      final result = check(RecitationScript.of(heard), on: t);
      expect(result.words.first.verdict, WordVerdict.right);
      expect(result.counts.mistakes, 0);
    });
  });

  group('a dropped word', () {
    test('the word he went past is skipped, in its own place, and nothing else moves', () {
      final result = check(cleanScript(target).drop(1)); // «لِلَّهِ»
      expect(verdicts(result), [WordVerdict.right, WordVerdict.skipped, WordVerdict.right, WordVerdict.right]);
      final missed = result.wrongOrSkipped.single;
      expect(missed.word.text, said[1]);
      expect(missed.word.indexInAyah, 1);
      expect(ayahText(fatiha2).substring(missed.word.start, missed.word.end), said[1]);
      expect(missed.heard, isNull);
      expect(result.counts.skipped, 1);
      expect(result.counts.extras, 0);
    });
  });

  group('an inserted word', () {
    test('a word that is not in the text is an extra, placed before the word it came before', () {
      final result = check(cleanScript(target).insert(2, 'الكريم'));
      expect(verdicts(result), List.filled(4, WordVerdict.right));
      final extra = result.inserted.single;
      expect(extra.heard, 'الكريم');
      expect(extra.reason, ExtraReason.inserted);
      expect(extra.beforeWord, 2);
      expect(extra.beforeWordInAyah, 2);
      expect(extra.ref, fatiha2);
      expect(extra.atCodeUnit, target.words[2].start, reason: 'positioned in the original text');
      expect(result.counts.extras, 1);
      expect(result.counts.mistakes, 1);
      expect(result.isClean, isFalse);
    });

    test('a word the recogniser was unsure about is never a mistake', () {
      final script = cleanScript(target).insert(2, 'خشخشة').unsure(2, confidence: 0.1);
      final result = check(script);
      expect(result.extras.single.reason, ExtraReason.unsure);
      expect(result.counts.extras, 0);
      expect(result.counts.mistakes, 0);
      expect(result.isClean, isTrue);
    });
  });

  group('a wrong word', () {
    test('it is one wrong word, not a skip plus an extra, and what was heard is kept apart', () {
      final result = check(cleanScript(target).replace(2, 'ملك')); // «رَبِّ» → «ملك»
      expect(verdicts(result), [WordVerdict.right, WordVerdict.right, WordVerdict.wrong, WordVerdict.right]);
      final wrong = result.wrongOrSkipped.single;
      expect(wrong.word.text, said[2]);
      expect(wrong.word.indexInAyah, 2);
      expect(wrong.heard, 'ملك');
      expect(ayahText(fatiha2).substring(wrong.word.start, wrong.word.end), said[2]);
      expect(result.counts.wrong, 1);
      expect(result.counts.extras, 0);
      expect(result.counts.skipped, 0);
    });

    test('a word heard with too little confidence is «not sure», not wrong', () {
      final result = check(cleanScript(target).replace(2, 'رد', confidence: 0.15));
      expect(result.words[2].verdict, WordVerdict.unsure);
      expect(result.counts.wrong, 0);
      expect(result.counts.unsure, 1);
      expect(result.counts.mistakes, 0);
      expect(result.words[2].heard, 'رد');
    });
  });

  group('a restart mid-verse', () {
    test('the words he said again are words of the text, not mistakes', () {
      final result = check(cleanScript(target).restartAfter(2));
      expect(verdicts(result), List.filled(4, WordVerdict.right));
      expect(result.extras, hasLength(2));
      for (final e in result.extras) {
        expect(e.reason, ExtraReason.repetition);
        expect(e.ref, fatiha2);
      }
      expect(result.counts.extras, 0);
      expect(result.isClean, isTrue);
    });

    test('and a verse recited twice is the same honest answer', () {
      final result = check(cleanScript(target).again());
      expect(verdicts(result), List.filled(4, WordVerdict.right));
      expect(result.extras, hasLength(4));
      expect(result.extras.map((e) => e.reason).toSet(), {ExtraReason.repetition});
      expect(result.counts.mistakes, 0);
    });
  });

  group('a long pause', () {
    test('it is recorded where he came back, and it is not a mistake', () {
      final result = check(cleanScript(target).pauseBefore(2, const Duration(seconds: 9)));
      expect(verdicts(result), List.filled(4, WordVerdict.right));
      expect(result.pauses, hasLength(1));
      expect(result.pauses.single.beforeWord, 2);
      expect(result.pauses.single.length, greaterThanOrEqualTo(const Duration(seconds: 9)));
      expect(result.counts.mistakes, 0);
      expect(result.isClean, isTrue);
    });

    test('an ordinary breath between words is not a pause', () {
      expect(check(cleanScript(target)).pauses, isEmpty);
    });
  });

  group('stopping mid-verse', () {
    test('what he never reached is pending, not skipped, and the cursor says where he is', () {
      final result = check(RecitationScript.of(said.take(2).toList()));
      expect(verdicts(result), [
        WordVerdict.right,
        WordVerdict.right,
        WordVerdict.pending,
        WordVerdict.pending,
      ]);
      expect(result.counts.pending, 2);
      expect(result.counts.mistakes, 0);
      expect(result.cursor, 2);
      expect(result.counts.accuracy, 1.0, reason: 'right out of what he reached');
    });

    test('and the caller can ask for them to count as skipped instead', () {
      final result = check(
        RecitationScript.of(said.take(2).toList()),
        options: const AlignmentOptions(countUnreachedAsSkipped: true),
      );
      expect(result.counts.skipped, 2);
      expect(result.counts.pending, 0);
    });
  });

  group('a basmala before a surah', () {
    test('it is forgiven, labelled as a prelude, and the surah itself still reads clean', () {
      final t = targetOfAyah(ikhlas1); // «قُلْ هُوَ ٱللَّهُ أَحَدٌ»
      expect(t.wordCount, 4, reason: 'the header basmala is not part of the ayah');
      final result = check(RecitationScript.of([...basmalaWords(), ...verifiedWords(t)]), on: t);
      expect(verdicts(result), List.filled(4, WordVerdict.right));
      expect(result.extras, hasLength(4));
      expect(result.extras.map((e) => e.reason).toSet(), {ExtraReason.prelude});
      expect(result.extras.every((e) => e.beforeWord == 0), isTrue);
      expect(result.counts.mistakes, 0);
      expect(result.isClean, isTrue);
    });

    test('a target that does not allow it counts the basmala as extra words', () {
      final t = targetOfAyah(ikhlas1, allowBasmala: false);
      final result = check(RecitationScript.of([...basmalaWords(), ...verifiedWords(t)]), on: t);
      expect(result.counts.extras, 4);
      expect(result.counts.mistakes, 4);
    });
  });

  group('a range of ayat', () {
    test('every verdict carries its own ayah, and the result slices per ayah', () {
      final t = targetOf(const AyahRange(AyahRef(1, 1), AyahRef(1, 3)));
      final words = verifiedWords(t);
      // A word of the MIDDLE ayah, so it is a real skip and not a tail he
      // simply never reached.
      final at = t.ayat[1].firstWord + 1;
      final result = check(RecitationScript.of([...words]..removeAt(at)), on: t);
      expect(result.ayat.map((a) => a.ref), [const AyahRef(1, 1), const AyahRef(1, 2), const AyahRef(1, 3)]);
      expect(result.ayat[0].counts.isClean, isTrue);
      expect(result.ayat[1].counts.skipped, 1);
      expect(result.ayat[2].counts.isClean, isTrue);
      final missed = result.wrongOrSkipped.single;
      expect(missed.ref, const AyahRef(1, 2));
      expect(missed.word.indexInAyah, 1);
      expect(
        ayahText(const AyahRef(1, 2)).substring(missed.word.start, missed.word.end),
        missed.word.text,
        reason: 'offsets are in that ayah own text, not in the whole range',
      );
    });
  });

  group('a very long verse', () {
    test('al-Baqarah 282 aligns, and a dropped word in the middle is found in its place', () {
      final t = targetOfAyah(const AyahRef(2, 282));
      expect(t.wordCount, greaterThan(100));
      final words = verifiedWords(t);
      final at = words.length ~/ 2;
      final result = check(RecitationScript.of([...words]..removeAt(at)), on: t);
      expect(result.counts.skipped, 1);
      expect(result.wrongOrSkipped.single.word.indexInAyah, at);
      expect(result.counts.right, t.wordCount - 1);
    });
  });

  group('the experimental tashkeel check', () {
    test('it is off by default and says nothing', () {
      final result = check(RecitationScript.of(['الحمد', 'لله', 'رب', 'العالمين']));
      expect(result.tashkeelChecked, isFalse);
      expect(result.words.map((w) => w.tashkeel).toSet(), {TashkeelCheck.notChecked});
      expect(result.counts.tashkeelDifferent, 0);
    });

    test('with no diacritics in what was heard it still says nothing, rather than inventing a mistake', () {
      final result = check(
        RecitationScript.of(['الحمد', 'لله', 'رب', 'العالمين']),
        options: const AlignmentOptions(checkTashkeel: true),
      );
      expect(result.words.map((w) => w.tashkeel).toSet(), {TashkeelCheck.notChecked});
      expect(result.counts.tashkeelDifferent, 0);
      expect(result.isClean, isTrue);
    });

    test('with diacritics it notices a difference, and never changes the verdict', () {
      final wrongMarks = said[0].replaceAll('ُ', 'ِ'); // damma → kasra
      final result = check(
        RecitationScript.of([wrongMarks, ...said.skip(1)]),
        options: const AlignmentOptions(checkTashkeel: true),
      );
      expect(result.words[0].verdict, WordVerdict.right);
      expect(result.words[0].tashkeel, TashkeelCheck.different);
      expect(result.words[1].tashkeel, TashkeelCheck.same);
      expect(result.counts.tashkeelDifferent, 1);
      expect(result.counts.mistakes, 0, reason: 'a tashkeel difference is never a mistake');
    });
  });

  group('what the engine will not do', () {
    test('a hypothesis the model may still revise never scores', () {
      final result = check(cleanScript(target).partialAt(2, 'ملك'));
      expect(verdicts(result), List.filled(4, WordVerdict.right));
      expect(result.extras, isEmpty);
      expect(result.heardWords, 4, reason: 'the partial word is not even counted as heard');
    });

    test('nothing heard at all is no result, not a zero', () {
      final result = check(const RecitationScript([]));
      expect(verdicts(result), List.filled(4, WordVerdict.pending));
      expect(result.counts.accuracy, isNull);
      expect(result.counts.isClean, isFalse);
      expect(result.cursor, 0);
    });
  });
}

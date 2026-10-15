import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/cinema/rules/words/words.dart';

void main() {
  group('ArabicText', () {
    test('plain strips tashkeel, tatweel and Quranic signs but keeps letters', () {
      expect(ArabicText.plain('مَدْرَسَةٌ'), 'مدرسة');
      expect(ArabicText.plain('ٱلرَّحْمَـٰنِ'), 'الرحمن');
      expect(ArabicText.plain('أَحْمَد'), 'أحمد');
      expect(ArabicText.plain('ی ک'), 'ي ك');
      expect(ArabicText.plain('آ'), 'آ'); // decomposed madda
      expect(ArabicText.plain('ؤ'), 'ؤ');
    });

    test('fold merges alef forms, alef maqsura and taa marbuta only', () {
      expect(ArabicText.fold('أإآا'), 'اااا');
      expect(ArabicText.fold('على'), 'علي');
      expect(ArabicText.fold('مدرسة'), 'مدرسه');
      expect(ArabicText.fold('سؤال'), 'سؤال'); // hamza seats stay distinct
      expect(ArabicText.fold('شاطئ'), 'شاطئ');
    });

    test('lookupKey accepts both spellings of hamza-seat words', () {
      expect(ArabicText.lookupKey('مسؤول'), ArabicText.lookupKey('مسئول'));
      expect(ArabicText.lookupKey('أسرة'), ArabicText.lookupKey('اسره'));
    });

    test('skeleton matches Uthmani spellings used in citations', () {
      expect(ArabicText.skeleton('إِبْرَٰهِيمَ'), 'ابرهيم');
      expect(ArabicText.skeleton('يَـُٔودُهُۥ'), 'يوده');
      expect(ArabicText.skeleton('ٱلصَّلَوٰةَ'), 'الصلوه');
    });

    test('letter counting ignores marks; clusters keep marks with their letter', () {
      expect(ArabicText.letterCount('سَيَّارَة'), 5);
      expect(ArabicText.clusters('بَيْتٌ'), ['بَ', 'يْ', 'تٌ']);
      expect(ArabicText.clusters('مَـٰ'), ['مَـٰ']);
      expect(ArabicText.isGameWord('كتاب'), isTrue);
      expect(ArabicText.isGameWord('كتاب1'), isFalse);
      expect(ArabicText.arabicDigits(2026), '٢٠٢٦');
    });
  });

  group('WordsRng', () {
    test('is deterministic, resumable and seedable from text', () {
      final a = WordsRng(42), b = WordsRng(42);
      final seq = [for (var i = 0; i < 40; i++) a.nextUint32()];
      expect([for (var i = 0; i < 40; i++) b.nextUint32()], seq);
      final c = WordsRng(42);
      for (var i = 0; i < 10; i++) {
        c.nextUint32();
      }
      final resumed = WordsRng.fromState(c.state);
      expect([for (var i = 0; i < 30; i++) resumed.nextUint32()], seq.sublist(10));
      expect(WordsRng.fromString('mufrada').nextUint32(), WordsRng.fromString('mufrada').nextUint32());
      expect(WordsRng(1).nextUint32(), isNot(WordsRng(2).nextUint32()));
      expect(WordsRng.mix([1, 2]), isNot(WordsRng.mix([2, 1])));
    });

    test('ranges, shuffles and weights behave', () {
      final r = WordsRng(7);
      final counts = List.filled(4, 0);
      for (var i = 0; i < 8000; i++) {
        counts[r.nextInt(4)]++;
      }
      for (final c in counts) {
        expect(c, inInclusiveRange(1800, 2200));
      }
      final list = List.generate(20, (i) => i);
      expect(r.shuffle([...list])..sort(), list);
      expect(r.weightedIndex([0, 0, 1]), 2);
      expect(() => r.nextInt(0), throwsRangeError);
    });
  });

  group('GridDirection', () {
    test('between finds straight lines only; RTL visual mapping', () {
      expect(GridDirection.between(const GridPos(0, 0), const GridPos(0, 4)), GridDirection.forward);
      expect(GridDirection.between(const GridPos(3, 3), const GridPos(0, 0)), GridDirection.upBackward);
      expect(GridDirection.between(const GridPos(0, 0), const GridPos(1, 2)), isNull);
      expect(GridDirection.forward.isReading && GridDirection.down.isReading, isTrue);
      expect(GridDirection.downForward.reversed, GridDirection.upBackward);
      expect(visualColumn(0, 8), 7);
      expect(visualColumn(0, 8, rtl: false), 0);
    });
  });
}

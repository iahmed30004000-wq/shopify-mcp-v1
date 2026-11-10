import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/quran/ayah.dart';
import 'package:madar/features/recitation/domain/recitation_queue.dart';
import 'package:madar/features/recitation/domain/reciters.dart';
import 'package:madar/features/recitation/domain/surah_ayah_counts.dart';

AyahRange r(int s1, int a1, int s2, int a2) => AyahRange(AyahRef(s1, a1), AyahRef(s2, a2));

List<String> describe(RecitationQueue q, {int? limit}) => [
  for (var i = 0; i < (limit ?? q.length!); i++) q.itemAt(i).toString(),
];

void main() {
  group('SurahMath', () {
    test('6236 ayat in 114 surahs', () {
      expect(kSurahAyahCounts, hasLength(114));
      expect(kSurahAyahCounts.fold<int>(0, (a, b) => a + b), SurahMath.totalAyat);
      expect(SurahMath.ayahCount(2), 286);
      expect(SurahMath.ayahCount(114), 6);
    });

    test('next / previous across surahs and ordinals', () {
      expect(SurahMath.next(const AyahRef(1, 7)), const AyahRef(2, 1));
      expect(SurahMath.next(const AyahRef(114, 6)), isNull);
      expect(SurahMath.previous(const AyahRef(2, 1)), const AyahRef(1, 7));
      expect(SurahMath.previous(const AyahRef(1, 1)), isNull);
      expect(SurahMath.ordinal(const AyahRef(1, 1)), 0);
      expect(SurahMath.ordinal(const AyahRef(2, 1)), 7);
      expect(SurahMath.ordinal(const AyahRef(114, 6)), 6235);
      expect(SurahMath.countIn(r(1, 6, 2, 2)), 4);
      expect(SurahMath.clamp(const AyahRef(1, 99)), const AyahRef(1, 7));
    });
  });

  group('basmala (everyayah convention)', () {
    test('al-Fatihah: the basmala is its first ayah, nothing is added', () {
      final q = RecitationQueue.build(r(1, 1, 1, 7));
      expect(q.length, 7);
      expect(q.itemAt(0).isAyah, isTrue);
      expect(q.itemAt(0).audioAyah, const AyahRef(1, 1));
    });

    test('at-Tawbah has none', () {
      final q = RecitationQueue.build(r(9, 1, 9, 2));
      expect(describe(q), ['ayah(9:1 #1/r1)', 'ayah(9:2 #1/r1)']);
    });

    test('other surahs open with 001001, only from ayah 1', () {
      final q = RecitationQueue.build(r(112, 1, 112, 4));
      expect(q.itemAt(0).isBasmala, isTrue);
      expect(q.itemAt(0).audioAyah, EveryAyah.basmala);
      expect(q.itemAt(0).ayah, const AyahRef(112, 1));
      expect(q.length, 5);
      final mid = RecitationQueue.build(r(2, 255, 2, 257));
      expect(mid.itemAt(0).isAyah, isTrue);
      expect(mid.length, 3);
    });

    test('a range across surahs gets a basmala at each surah start except 9', () {
      final q = RecitationQueue.build(r(8, 75, 10, 1));
      expect(describe(q), [
        'ayah(8:75 #1/r1)',
        for (var a = 1; a <= 129; a++) 'ayah(9:$a #1/r1)',
        'basmala(10:1/r1)',
        'ayah(10:1 #1/r1)',
      ]);
    });

    test('can be switched off', () {
      final q = RecitationQueue.build(r(36, 1, 36, 2), basmala: false);
      expect(q.length, 2);
    });
  });

  group('repeats and gaps', () {
    test('each ayah N times, the basmala once', () {
      final q = RecitationQueue.build(r(112, 1, 112, 2), repeatAyah: 3);
      expect(describe(q), [
        'basmala(112:1/r1)',
        'ayah(112:1 #1/r1)',
        'ayah(112:1 #2/r1)',
        'ayah(112:1 #3/r1)',
        'ayah(112:2 #1/r1)',
        'ayah(112:2 #2/r1)',
        'ayah(112:2 #3/r1)',
      ]);
    });

    test('the range N times, the basmala again in every pass', () {
      final q = RecitationQueue.build(r(112, 1, 112, 2), repeatRange: 2);
      expect(describe(q), [
        'basmala(112:1/r1)',
        'ayah(112:1 #1/r1)',
        'ayah(112:2 #1/r1)',
        'basmala(112:1/r2)',
        'ayah(112:1 #1/r2)',
        'ayah(112:2 #1/r2)',
      ]);
      expect(q.itemAt(3).group, 2);
      expect(q.itemAt(5).group, 3);
    });

    test('a silence after every recitation but the last', () {
      final q = RecitationQueue.build(r(2, 1, 2, 2), repeatAyah: 2, gap: const Duration(seconds: 3));
      expect(describe(q), [
        'basmala(2:1/r1)',
        'ayah(2:1 #1/r1)',
        'gap(3000ms after 2:1/r1)',
        'ayah(2:1 #2/r1)',
        'gap(3000ms after 2:1/r1)',
        'ayah(2:2 #1/r1)',
        'gap(3000ms after 2:2/r1)',
        'ayah(2:2 #2/r1)',
      ]);
      expect(q.itemAt(2).audioAyah, isNull);
    });

    test('repeatRange 0 loops without end; entries are derived per pass', () {
      final q = RecitationQueue.build(r(114, 1, 114, 6), repeatRange: 0);
      expect(q.loops, isTrue);
      expect(q.length, isNull);
      expect(q.contains(1000000), isTrue);
      final far = q.itemAt(7 * 1000 + 3);
      expect(far.rangePass, 1001);
      expect(far.ayah, const AyahRef(114, 3));
    });

    test('the whole mushaf with repeats stays one materialised pass', () {
      final q = RecitationQueue.build(r(1, 1, 114, 6), repeatAyah: 3, repeatRange: 5);
      expect(q.passLength, 6236 * 3 + 112);
      expect(q.length, q.passLength * 5);
      expect(q.itemAt(q.length! - 1).toString(), 'ayah(114:6 #3/r5)');
    });

    test('ranges beyond a surah are clamped; a reversed range is one ayah', () {
      expect(RecitationQueue.build(r(1, 5, 1, 99)).length, 3);
      expect(RecitationQueue.build(r(1, 5, 1, 2)).length, 1);
    });
  });

  group('navigation', () {
    final q = RecitationQueue.build(r(112, 1, 112, 3), repeatAyah: 2, repeatRange: 2);
    // 0 basmala, 1-2 ayah1, 3-4 ayah2, 5-6 ayah3, 7 basmala r2, 8-9 ayah1 …

    test('next ayah skips the remaining repetitions', () {
      expect(q.nextAyahStart(0), 3);
      expect(q.nextAyahStart(2), 3);
      expect(q.nextAyahStart(5), 7);
      expect(q.nextAyahStart(q.length! - 1), isNull);
    });

    test('previous ayah and the start of this one', () {
      expect(q.groupStartOf(2), 0);
      expect(q.previousAyahStart(4), 0);
      expect(q.previousAyahStart(8), 5);
      expect(q.previousAyahStart(1), isNull);
    });

    test('index of an ayah in a pass', () {
      expect(q.indexOfAyah(const AyahRef(112, 2)), 3);
      expect(q.indexOfAyah(const AyahRef(112, 1), rangePass: 2), 7);
      expect(q.indexOfAyah(const AyahRef(112, 4)), isNull);
      expect(q.indexOfAyah(const AyahRef(112, 1), rangePass: 3), isNull);
    });

    test('pass progress', () {
      expect(q.passProgress(0), 0);
      expect(q.passProgress(2, within: 0.5), closeTo((0 + 1.5 / 2) / 3, 1e-9));
      expect(q.passProgress(6, within: 1), 1);
    });
  });
}

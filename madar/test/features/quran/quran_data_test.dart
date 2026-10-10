import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/quran/ayah.dart';
import 'package:madar/core/quran/quran_catalog.dart';
import 'package:madar/features/quran/data/quran_store.dart';
import 'package:madar/features/quran/domain/arabic_search.dart';
import 'package:madar/features/quran/domain/quran_meta.dart';
import 'package:madar/features/quran/domain/quran_text.dart';
import 'package:madar/features/quran/domain/tajweed.dart';

import 'quran_test_data.dart';

/// Letters only (typed Arabic may order its marks differently from Tanzil).
String _letters(String s) => ArabicSearch.normalize(s).text;

void main() {
  final meta = QuranTestData.meta;
  final text = QuranTestData.text;
  final tajweed = QuranTestData.tajweed;

  group('bundled data integrity', () {
    test('114 suras, 6236 ayat, 604 pages, 30 juz, 60 hizb, 240 quarters, 15 sajdat', () {
      expect(meta.surahs, hasLength(114));
      expect(meta.ayahCount, 6236);
      expect(meta.surahs.fold<int>(0, (a, s) => a + s.ayahCount), 6236);
      expect(meta.pageStarts, hasLength(604));
      expect(meta.juzStarts, hasLength(30));
      expect(meta.quarterStarts, hasLength(240));
      expect(meta.sajdat, hasLength(15));
      expect(text.length, 6236);
    });

    test('famous sura sizes and Makki / Madani', () {
      expect(meta.surah(1).ayahCount, 7);
      expect(meta.surah(2).ayahCount, 286);
      expect(meta.surah(9).ayahCount, 129);
      expect(meta.surah(36).ayahCount, 83);
      expect(meta.surah(108).ayahCount, 3);
      expect(meta.surah(114).ayahCount, 6);
      expect(meta.surah(1).makki, isTrue);
      expect(meta.surah(2).makki, isFalse);
      expect(meta.surah(55).makki, isFalse, reason: 'ar-Rahman is Madani in the Madani mushaf');
      expect(meta.surah(96).revelationOrder, 1);
      expect(meta.surah(2).nameArabic, 'البقرة');
      expect(meta.surah(14).nameArabic, 'إبراهيم');
      expect(meta.surah(2).nameEnglish, 'Al-Baqarah');
      expect(meta.surah(2).meaningEnglish, 'The Cow');
    });

    test('the text is Tanzil Uthmani 1.1, with its copyright block', () {
      expect(text.copyrightNotice, contains('Tanzil Quran Text (Uthmani, Version 1.1)'));
      expect(text.copyrightNotice, contains('PLEASE DO NOT REMOVE OR CHANGE THIS COPYRIGHT BLOCK'));
      expect(_letters(text.ayahText(0)), _letters('بِسْمِ ٱللَّهِ ٱلرَّحْمَـٰنِ ٱلرَّحِيمِ'));
      expect(text.ayahText(0).codeUnits.take(6), [0x628, 0x650, 0x633, 0x652, 0x645, 0x650]);
      // The verification log of the build records the shipped file's size and hash.
      final bytes = File('assets/quran/quran-uthmani.txt').lengthSync();
      expect(File('assets/quran/source/verification_log.txt').readAsStringSync(), contains('quran-uthmani.txt: $bytes bytes'));
      expect(File('assets/quran/source/verification_log.txt').readAsStringSync(), contains('RESULT PASS'));
    });

    test('well-known ayat read as expected (letters checked against KFGQPC at build time)', () {
      String at(int s, int a) => _letters(text.ayahText(meta.indexOf(AyahRef(s, a))));
      expect(at(112, 1), _letters('قُلْ هُوَ ٱللَّهُ أَحَدٌ'));
      expect(at(2, 1), _letters('الٓمٓ'));
      expect(at(2, 255), startsWith(_letters('ٱللَّهُ لَآ إِلَـٰهَ إِلَّا هُوَ ٱلْحَىُّ ٱلْقَيُّومُ')));
      expect(at(108, 1), _letters('إِنَّآ أَعْطَيْنَـٰكَ ٱلْكَوْثَرَ'));
      expect(at(114, 6), _letters('مِنَ ٱلْجِنَّةِ وَٱلنَّاسِ'));
    });

    test('the previews\' basmala is exactly 1:1 of the bundled text', () {
      expect(QuranText.openingBasmala, text.ayahText(0));
    });

    test('the basmala leads ayah 1 of every sura but 1 and 9, and splits off cleanly', () {
      for (final s in meta.surahs) {
        final i = s.firstIndex;
        final basmala = text.basmalaOf(s);
        if (s.number == 1 || s.number == 9) {
          expect(basmala, isNull);
          expect(text.basmalaLength(i), 0);
          continue;
        }
        expect(basmala, isNotNull, reason: 'sura ${s.number}');
        expect(basmala!.split(' '), hasLength(4));
        expect(text.line(i), startsWith('$basmala '));
        expect(text.ayahText(i), isNot(startsWith('بِ')), reason: 'sura ${s.number}');
      }
      expect(_letters(text.ayahText(meta.indexOf(const AyahRef(9, 1)))), startsWith(_letters('بَرَآءَةٌ')));
    });

    test('ayah text never contains a surrogate pair (code points == UTF-16 offsets)', () {
      for (var i = 0; i < text.length; i++) {
        expect(text.line(i).runes.length, text.line(i).length);
      }
    });

    test('sajdah signs ۩ sit exactly on the 15 sajdat', () {
      final withSign = [
        for (var i = 0; i < text.length; i++)
          if (text.line(i).contains('۩')) meta.refAt(i),
      ];
      expect(withSign, [for (final s in meta.sajdat) s.ref]);
      expect(meta.sajdat.first.ref, const AyahRef(7, 206));
      expect(meta.sajdat.last.ref, const AyahRef(96, 19));
      expect(meta.sajdahAt(const AyahRef(32, 15))?.obligatory, isTrue);
      expect(meta.sajdahAt(const AyahRef(7, 206))?.obligatory, isFalse);
    });

    test('rub el hizb ۞ opens every quarter that starts inside a sura (incl. 15:49)', () {
      for (final q in meta.quarterStarts) {
        if (q.ayah == 1) continue;
        expect(text.line(meta.indexOf(q)), startsWith('۞'), reason: '$q');
      }
      expect(meta.quarterStartingAt(const AyahRef(15, 49)), isNotNull);
    });

    test('tajweed annotations cover every ayah and stay inside their line', () {
      var total = 0;
      for (var i = 0; i < text.length; i++) {
        for (final m in tajweed.lineMarks(i)) {
          expect(m.start, greaterThanOrEqualTo(0));
          expect(m.end, lessThanOrEqualTo(text.line(i).length), reason: '${meta.refAt(i)} $m');
          total++;
        }
      }
      expect(total, 60057);
    });

    test('tajweed marks land on their letters', () {
      const letters = {
        TajweedRule.qalqalah: 'قطبجد',
        TajweedRule.hamzatWasl: 'ٱ',
        TajweedRule.lamShamsiyyah: 'ل',
        TajweedRule.ghunnah: 'نم',
      };
      for (var i = 0; i < text.length; i++) {
        final line = text.line(i);
        for (final m in tajweed.lineMarks(i)) {
          final want = letters[m.rule];
          if (want == null) continue;
          final covered = line.substring(m.start, m.end);
          expect(covered.split('').any(want.contains), isTrue, reason: '${meta.refAt(i)} $m «$covered»');
        }
      }
    });

    test('1:1 carries the classic tajweed of the basmala', () {
      final marks = tajweed.lineMarks(0);
      final line = text.line(0);
      final wasl = marks.where((m) => m.rule == TajweedRule.hamzatWasl).map((m) => line.substring(m.start, m.end));
      expect(wasl, everyElement('ٱ'));
      expect(marks.where((m) => m.rule == TajweedRule.lamShamsiyyah), hasLength(2));
      expect(marks.any((m) => m.rule == TajweedRule.maddNatural), isTrue);
    });
  });

  group('structure lookups', () {
    test('page / juz / hizb of known ayat', () {
      expect(meta.pageOf(const AyahRef(1, 1)), 1);
      expect(meta.pageOf(const AyahRef(2, 1)), 2);
      expect(meta.pageOf(const AyahRef(2, 255)), 42);
      expect(meta.juzOf(const AyahRef(2, 255)), 3);
      expect(meta.hizbOf(const AyahRef(2, 255)), 5);
      expect(meta.pageOf(const AyahRef(2, 142)), 22);
      expect(meta.juzOf(const AyahRef(2, 142)), 2);
      expect(meta.hizbOf(const AyahRef(2, 142)), 3);
      expect(meta.pageOf(const AyahRef(18, 1)), 293);
      expect(meta.juzOf(const AyahRef(18, 1)), 15);
      expect(meta.pageOf(const AyahRef(36, 1)), 440);
      expect(meta.juzOf(const AyahRef(36, 1)), 22);
      expect(meta.pageOf(const AyahRef(67, 1)), 562);
      expect(meta.juzOf(const AyahRef(67, 1)), 29);
      expect(meta.hizbOf(const AyahRef(67, 1)), 57);
      expect(meta.pageOf(const AyahRef(78, 1)), 582);
      expect(meta.juzOf(const AyahRef(78, 1)), 30);
      expect(meta.hizbOf(const AyahRef(78, 1)), 59);
      expect(meta.pageOf(const AyahRef(114, 6)), 604);
      expect(meta.hizbOf(const AyahRef(114, 6)), 60);
    });

    test('starts and ends', () {
      expect(meta.juzStart(2), const AyahRef(2, 142));
      expect(meta.juzEnd(1), const AyahRef(2, 141));
      expect(meta.juzStart(30), const AyahRef(78, 1));
      expect(meta.hizbStart(2), const AyahRef(2, 75));
      expect(meta.pageStart(604), const AyahRef(112, 1));
      expect(meta.pageEnd(1), const AyahRef(1, 7));
      expect(meta.pageEnd(604), const AyahRef(114, 6));
      expect(meta.ayatOnPage(1), hasLength(7));
      expect(meta.surahsOnPage(604), [112, 113, 114]);
      expect(meta.quarterPosition(9), const QuarterPosition(index: 9, juz: 2, hizb: 3, quarter: 1));
      expect(meta.quarterPosition(10).quarter, 2);
    });

    test('index round trip and neighbours across suras', () {
      for (var i = 0; i < meta.ayahCount; i += 37) {
        expect(meta.indexOf(meta.refAt(i)), i);
      }
      expect(meta.refAt(6235), const AyahRef(114, 6));
      expect(meta.next(const AyahRef(1, 7)), const AyahRef(2, 1));
      expect(meta.previous(const AyahRef(2, 1)), const AyahRef(1, 7));
      expect(meta.next(const AyahRef(114, 6)), isNull);
      expect(meta.previous(const AyahRef(1, 1)), isNull);
      expect(meta.countInRange(const AyahRange(AyahRef(1, 1), AyahRef(2, 5))), 12);
      expect(() => meta.indexOf(const AyahRef(1, 8)), throwsRangeError);
    });
  });

  group('QuranCatalog (bundled)', () {
    test('loads lazily and answers the shared contract', () async {
      final catalog = BundledQuranCatalog(QuranStore(const FileQuranAssetSource()));
      expect(() => catalog.ayahCount(1), throwsStateError);
      await catalog.ensureLoaded();
      final QuranCatalog c = catalog;
      expect(c.surahCount, 114);
      expect(c.ayahCount(2), 286);
      expect(c.surahName(1, arabic: true), 'الفاتحة');
      expect(c.surahName(1, arabic: false), 'Al-Fatihah');
      expect(c.isMakki(96), isTrue);
      expect(c.pageOf(const AyahRef(2, 255)), 42);
      expect(c.juzOf(const AyahRef(2, 255)), 3);
      expect(c.hizbOf(const AyahRef(2, 255)), 5);
      expect(c.pageStart(3), const AyahRef(2, 6));
      expect(c.juzStart(30), const AyahRef(78, 1));
      expect(c.hizbStart(60), const AyahRef(87, 1));
      expect(c.next(const AyahRef(2, 286)), const AyahRef(3, 1));
      expect(c.previous(const AyahRef(3, 1)), const AyahRef(2, 286));
      expect(c.countInRange(const AyahRange(AyahRef(78, 1), AyahRef(114, 6))), 564);
      expect(_letters(await c.ayahText(const AyahRef(112, 1))), _letters('قُلْ هُوَ ٱللَّهُ أَحَدٌ'));
      expect(await c.ayahText(const AyahRef(2, 2)), QuranTestData.text.ayahText(8));
    });

    test('the meta JSON parses to the same structure the app uses', () {
      final json = jsonDecode(QuranTestData.read(QuranAssets.meta)) as Map;
      expect(json['version'], 1);
      expect(QuranMeta.fromJson(json.cast()).pageStarts.last, const AyahRef(112, 1));
    });

    test('a truncated text is rejected', () {
      final lines = QuranTestData.read(QuranAssets.text).split('\n');
      expect(() => QuranText.parse(lines.take(100).join('\n'), meta), throwsFormatException);
    });
  });
}

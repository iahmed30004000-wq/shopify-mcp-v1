import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/quran/ayah.dart';
import 'package:madar/features/quran/data/quran_com_client.dart';
import 'package:madar/features/quran/domain/arabic_search.dart';
import 'package:madar/features/quran/domain/mushaf_layout.dart';
import 'package:madar/features/quran/domain/quran_goto.dart';
import 'package:madar/features/quran/domain/quran_prefs.dart';
import 'package:madar/features/quran/domain/reading_tracker.dart';
import 'package:madar/features/quran/domain/tajweed.dart';

import 'quran_test_data.dart';

String _fixture(String name) => File('test/features/quran/fixtures/$name').readAsStringSync();

class _FixtureHttp implements QuranHttp {
  _FixtureHttp(this.routes);

  final Map<String, String> routes;
  final List<Uri> requests = [];
  bool offline = false;

  @override
  Future<(int, String)> get(Uri uri) async {
    requests.add(uri);
    if (offline) throw const QuranComException(QuranComProblem.offline);
    for (final e in routes.entries) {
      if (uri.toString().contains(e.key)) return (200, e.value);
    }
    return (404, '{"status":404}');
  }
}

void main() {
  final meta = QuranTestData.meta;
  final text = QuranTestData.text;

  group('tajweed', () {
    test('decodes the bundled one-letter format', () {
      expect(Tajweed.decode('w7.8 l16.17 a24.26'), const [
        TajweedMark(TajweedRule.hamzatWasl, 7, 8),
        TajweedMark(TajweedRule.lamShamsiyyah, 16, 17),
        TajweedMark(TajweedRule.maddNatural, 24, 26),
      ]);
      expect(Tajweed.decode(''), isEmpty);
      expect(Tajweed.decode('x1.2 w5.3 q'), isEmpty, reason: 'unknown codes and bad ranges are skipped');
    });

    test('every rule has a unique code and Quran.com class', () {
      expect(TajweedRule.values.map((r) => r.code).toSet(), hasLength(TajweedRule.values.length));
      expect(TajweedRule.fromClass('ham_wasl'), TajweedRule.hamzatWasl);
      expect(TajweedRule.fromClass('laam_shamsiyah'), TajweedRule.lamShamsiyyah);
      expect(TajweedRule.fromClass('madda_obligatory'), TajweedRule.maddConnected);
      expect(TajweedRule.fromClass('madda_necessary'), TajweedRule.maddNecessary);
      expect(TajweedRule.fromClass('qalaqah'), TajweedRule.qalqalah);
      expect(TajweedRule.fromClass('idgham_wo_ghunnah'), TajweedRule.idghamNoGhunnah);
      expect(TajweedRule.fromClass('ikhafa_shafawi'), TajweedRule.ikhfaShafawi);
      expect(TajweedRule.fromClass('slnt'), TajweedRule.silent);
      expect(TajweedRule.fromClass('end'), isNull);
    });

    test('runs cover the text exactly, the shorter mark winning an overlap', () {
      final runs = Tajweed.runs(10, const [
        TajweedMark(TajweedRule.idghamGhunnah, 2, 8),
        TajweedMark(TajweedRule.ghunnah, 4, 6),
      ]);
      expect(runs, const [
        TajweedRun(0, 2, null),
        TajweedRun(2, 4, TajweedRule.idghamGhunnah),
        TajweedRun(4, 6, TajweedRule.ghunnah),
        TajweedRun(6, 8, TajweedRule.idghamGhunnah),
        TajweedRun(8, 10, null),
      ]);
      expect(Tajweed.runs(3, const []), const [TajweedRun(0, 3, null)]);
      expect(Tajweed.runs(3, const [TajweedMark(TajweedRule.silent, 1, 9)]), const [
        TajweedRun(0, 1, null),
        TajweedRun(1, 3, TajweedRule.silent),
      ]);
    });

    test('runs over every bundled ayah are contiguous and complete', () {
      for (var i = 0; i < text.length; i += 7) {
        final line = text.line(i);
        final runs = Tajweed.runs(line.length, QuranTestData.tajweed.lineMarks(i));
        expect(runs.first.start, 0);
        expect(runs.last.end, line.length);
        for (var k = 1; k < runs.length; k++) {
          expect(runs[k].start, runs[k - 1].end);
          expect(runs[k].rule, isNot(runs[k - 1].rule));
        }
      }
    });

    test('slice splits the basmala marks off ayah 1', () {
      final i = meta.surah(2).firstIndex;
      final line = text.line(i);
      final cut = text.basmalaLength(i);
      final body = Tajweed.slice(QuranTestData.tajweed.lineMarks(i), cut, line.length);
      final ayah = line.substring(cut);
      expect(body, isNotEmpty);
      for (final m in body) {
        expect(m.end, lessThanOrEqualTo(ayah.length));
      }
      // الٓمٓ: the two necessary madds.
      expect(body.where((m) => m.rule == TajweedRule.maddNecessary), hasLength(2));
    });

    test('parses Quran.com markup into text + marks (end number dropped)', () {
      const markup =
          'بِسْمِ <tajweed class=ham_wasl>ٱ</tajweed>للَّهِ <tajweed class="laam_shamsiyah">ل</tajweed>رَّحْمَ'
          "<tajweed class='madda_normal'>ـٰ</tajweed>نِ &amp; <span class=end>١</span>";
      final parsed = Tajweed.parseQuranCom(markup);
      expect(parsed.text, 'بِسْمِ ٱللَّهِ لرَّحْمَـٰنِ &');
      expect(parsed.marks, [
        const TajweedMark(TajweedRule.hamzatWasl, 7, 8),
        TajweedMark(TajweedRule.lamShamsiyyah, parsed.text.indexOf('ل', 14), parsed.text.indexOf('ل', 14) + 1),
        TajweedMark(TajweedRule.maddNatural, parsed.text.indexOf('ـ'), parsed.text.indexOf('ـ') + 2),
      ]);
      expect(Tajweed.parseQuranCom('<tajweed class=unknown>ب</tajweed>').marks, isEmpty);
      expect(Tajweed.parseQuranCom('a<tajweed class=ghunnah>b<tajweed class=ikhafa>c</tajweed></tajweed>').marks, [
        const TajweedMark(TajweedRule.ghunnah, 1, 3),
        const TajweedMark(TajweedRule.ikhfa, 2, 3),
      ]);
      expect(Tajweed.stripMarkup('Lord<sup foot_note="1">1</sup> of the worlds'), 'Lord of the worlds');
    });
  });

  group('search', () {
    final index = QuranSearchIndexBuilder.build();

    Set<AyahRef> refs(String q) => {for (final h in index.search(q, limit: 10000).hits) h.ref};

    test('folds diacritics, hamza and alef forms, Uthmani spellings', () {
      expect(refs('الرحمن'), containsAll(const [AyahRef(1, 1), AyahRef(1, 3), AyahRef(55, 1)]));
      expect(refs('العالمين'), contains(const AyahRef(1, 2)));
      expect(refs('الصلاة'), contains(const AyahRef(2, 3)));
      expect(refs('الزكاة'), contains(const AyahRef(2, 43)));
      expect(refs('إبراهيم'), contains(const AyahRef(2, 124)));
      expect(refs('ابراهيم'), refs('إبراهيم'));
      expect(refs('داود'), contains(const AyahRef(2, 251)));
      expect(refs('السماوات'), contains(const AyahRef(2, 255)));
      expect(refs('الحي القيوم'), containsAll(const [AyahRef(2, 255), AyahRef(3, 2), AyahRef(20, 111)]));
      expect(refs('قل هو الله أحد'), {const AyahRef(112, 1)});
      expect(refs('يا أيها الذين آمنوا'), contains(const AyahRef(2, 104)));
      expect(refs('على'), contains(const AyahRef(2, 5)));
      expect(refs('التوراة'), contains(const AyahRef(3, 3)));
      expect(refs('الْحَمْدُ لِلَّهِ'), contains(const AyahRef(1, 2)));
      expect(refs('٢٥٥'), isEmpty, reason: 'digits are not text');
    });

    test('normalises the query like the text', () {
      expect(ArabicSearch.normalizeQuery('  إِبْرَاهِيمَ  '), ArabicSearch.normalizeQuery('ابراهيم'));
      expect(ArabicSearch.normalizeQuery('مدرسة'), 'مدرسه');
      expect(ArabicSearch.normalizeQuery('مسؤول'), 'مسوول');
      expect(ArabicSearch.normalizeQuery('آمنوا'), 'منو');
    });

    test('highlight ranges cover the matched letters with their marks', () {
      final result = index.search('الحي القيوم');
      final hit = result.hits.firstWhere((h) => h.ref == const AyahRef(2, 255));
      final ayah = text.ayahText(hit.index);
      expect(hit.ranges, hasLength(1));
      final (s, e) = hit.ranges.single;
      expect(ArabicSearch.normalize(ayah.substring(s, e)).text, ArabicSearch.normalizeQuery('الحي القيوم'));
      expect(ayah.substring(s, e), endsWith('مُ'), reason: 'the last letter keeps its damma');
    });

    // Review finding: with word breaks folded away, «الرحمن» also matched
    // «ٱلْأَرْحَامَ ۚ إِنَّ» (4:1) and «الله» matched «قِيلَ لَهُمْ» (2:11).
    test('a one-word query never matches across a word break', () {
      final rahman = index.search('الرحمن', limit: 1000);
      expect(rahman.hits.map((h) => h.ref), isNot(contains(const AyahRef(4, 1))));
      expect(rahman.occurrences, 57, reason: 'ar-Rahman occurs 57 times in the Quran');
      // The whole word lights up, its leading hamzat al-wasl included.
      final fatihah = rahman.hits.first;
      final (s, e) = fatihah.ranges.single;
      expect(text.ayahText(fatihah.index).substring(s, e), startsWith('ٱلرَّحْمَـٰنِ'.substring(0, 1)));
      expect(ArabicSearch.normalize(text.ayahText(fatihah.index).substring(s, e)).text, 'لرحمن');
      final allah = index.search('الله', limit: 10000);
      expect(allah.hits.map((h) => h.ref), isNot(contains(const AyahRef(2, 11))));
      for (final h in index.search('نور', limit: 1000).hits) {
        final ayah = text.ayahText(h.index);
        for (final (s, e) in h.ranges) {
          expect(ayah.substring(s, e).trim(), isNot(contains(' ')), reason: '${h.ref}');
        }
      }
      // A query with a break may still match the Uthmani joined spelling.
      expect(index.search('يا أيها الناس').hits.map((h) => h.ref), contains(const AyahRef(2, 21)));
      expect(index.search('قل هو الله أحد').hits.single.ref, const AyahRef(112, 1));
    });

    test('counts, limits and short queries', () {
      final r = index.search('الله', limit: 5);
      expect(r.hits, hasLength(5));
      expect(r.total, greaterThan(1500));
      expect(r.occurrences, greaterThanOrEqualTo(r.total));
      expect(index.search('ا').hits, isEmpty);
      expect(index.search('  ').total, 0);
    });
  });

  group('go to', () {
    test('sura:ayah in either digit script', () {
      expect(QuranGoTo.parse('2:255', meta).single, const GoToTarget(GoToKind.ayah, AyahRef(2, 255), number: 2));
      expect(QuranGoTo.parse('٢:٢٥٥', meta).single.ref, const AyahRef(2, 255));
      expect(QuranGoTo.parse('2 255', meta).single.ref, const AyahRef(2, 255));
      expect(QuranGoTo.parse('2:287', meta), isEmpty);
      expect(QuranGoTo.parse('115:1', meta), isEmpty);
    });

    test('pages, juz and hizb by keyword', () {
      expect(QuranGoTo.parse('page 50', meta).single, GoToTarget(GoToKind.page, meta.pageStart(50), number: 50, page: 50));
      expect(QuranGoTo.parse('صفحة ٥٠', meta).single.page, 50);
      expect(QuranGoTo.parse('ص 604', meta).single.page, 604);
      expect(QuranGoTo.parse('page 605', meta), isEmpty);
      expect(QuranGoTo.parse('جزء ٣٠', meta).single.ref, const AyahRef(78, 1));
      expect(QuranGoTo.parse('juz 2', meta).single.ref, const AyahRef(2, 142));
      expect(QuranGoTo.parse('حزب ٦٠', meta).single.ref, const AyahRef(87, 1));
    });

    test('a bare number offers a sura, a page and a juz', () {
      final t = QuranGoTo.parse('18', meta);
      expect(t.map((e) => e.kind), [GoToKind.surah, GoToKind.page, GoToKind.juz]);
      expect(QuranGoTo.parse('200', meta).map((e) => e.kind), [GoToKind.page]);
    });

    test('sura names in Arabic and English, with an ayah', () {
      expect(QuranGoTo.parse('البقرة', meta).first.ref, const AyahRef(2, 1));
      expect(QuranGoTo.parse('سورة الكهف', meta).first.number, 18);
      expect(QuranGoTo.parse('الكهف ١٠', meta).first.ref, const AyahRef(18, 10));
      expect(QuranGoTo.parse('يس', meta).first.number, 36);
      expect(QuranGoTo.parse('Baqarah 255', meta).first.ref, const AyahRef(2, 255));
      expect(QuranGoTo.parse('al-kahf', meta).first.number, 18);
      expect(QuranGoTo.parse('Surah Yasin', meta).first.number, 36);
      expect(QuranGoTo.parse('Fatiha', meta).first.number, 1);
      expect(QuranGoTo.parse('the cow', meta).first.number, 2);
      expect(QuranGoTo.matchSurahs('ابراهيم', meta).first.number, 14);
      expect(QuranGoTo.matchSurahs('نس', meta).map((s) => s.number), containsAll([4, 114]));
    });
  });

  group('mushaf layout', () {
    test('page 1: al-Fatihah title, no separate basmala, seven ayat', () {
      final blocks = MushafLayout.page(meta, 1);
      expect(blocks, [SurahHeaderBlock(meta.surah(1)), AyatBlock(meta.surah(1), [0, 1, 2, 3, 4, 5, 6])]);
    });

    test('page 604: three suras, each with its title and basmala', () {
      final blocks = MushafLayout.page(meta, 604);
      expect(blocks.whereType<SurahHeaderBlock>().map((b) => b.surah.number), [112, 113, 114]);
      expect(blocks.whereType<BasmalaBlock>(), hasLength(3));
      expect(blocks.whereType<AyatBlock>().fold<int>(0, (a, b) => a + b.indices.length), 4 + 5 + 6);
    });

    test('at-Tawbah has a title but no basmala', () {
      final page = meta.pageOf(const AyahRef(9, 1));
      final blocks = MushafLayout.page(meta, page);
      expect(blocks.whereType<SurahHeaderBlock>().map((b) => b.surah.number), contains(9));
      expect(blocks.whereType<BasmalaBlock>().map((b) => b.surah.number), isNot(contains(9)));
    });

    test('every page lays out exactly its ayat', () {
      var total = 0;
      for (var p = 1; p <= 604; p++) {
        total += MushafLayout.page(meta, p).whereType<AyatBlock>().fold<int>(0, (a, b) => a + b.indices.length);
      }
      expect(total, 6236);
    });
  });

  group('reading tracker', () {
    final t0 = DateTime(2026, 9, 28, 20);

    test('counts active time and ayat that stayed on screen', () {
      final tracker = ReadingTracker();
      tracker.show([10, 11, 12], t0);
      tracker.activity(t0.add(const Duration(seconds: 40)));
      tracker.show([13, 14], t0.add(const Duration(seconds: 70)));
      final s = tracker.flush(t0.add(const Duration(seconds: 100)))!;
      expect(s.seconds, 100);
      expect(s.seen, {10, 11, 12, 13, 14});
      expect(s.firstIndex, 10);
      expect(s.lastIndex, 14);
    });

    test('ignores idle stretches and flipping through pages', () {
      final tracker = ReadingTracker(idleTimeout: const Duration(minutes: 2));
      tracker.show([1], t0);
      tracker.show([2], t0.add(const Duration(seconds: 2))); // flipped past 1
      tracker.show([3], t0.add(const Duration(seconds: 60)));
      // Phone put down for 10 minutes.
      tracker.activity(t0.add(const Duration(minutes: 11)));
      final s = tracker.flush(t0.add(const Duration(minutes: 11, seconds: 30)))!;
      expect(s.seen, {2, 3});
      expect(s.seconds, 90);
    });

    test('background time does not count; short sessions are dropped', () {
      final tracker = ReadingTracker();
      tracker.show([1], t0);
      tracker.pause(t0.add(const Duration(seconds: 20)));
      tracker.resume(t0.add(const Duration(minutes: 30)));
      expect(tracker.flush(t0.add(const Duration(minutes: 30, seconds: 5))), isNull, reason: '25 s is too short');
      final again = ReadingTracker();
      again.show([5], t0);
      again.pause(t0.add(const Duration(seconds: 40)));
      again.resume(t0.add(const Duration(hours: 1)));
      final s = again.flush(t0.add(const Duration(hours: 1)))!;
      expect(s.seconds, 40);
    });
  });

  group('prefs', () {
    test('round trip and tolerant parsing', () {
      const p = QuranReaderPrefs(mode: QuranReaderMode.list, fontSize: 30, tajweed: false, translation: true);
      expect(QuranReaderPrefs.fromJson(p.toJson()), p);
      expect(QuranReaderPrefs.fromJson({'fontSize': 99, 'mode': 'nope'}).fontSize, QuranReaderPrefs.maxFontSize);
      expect(QuranReaderPrefs.fromJson(null), const QuranReaderPrefs());
      final last = QuranLastRead(
        ref: const AyahRef(2, 255),
        page: 42,
        at: DateTime(2026, 9, 28),
        mode: QuranReaderMode.mushaf,
      );
      expect(QuranLastRead.fromJson(last.toJson()), last);
      expect(QuranLastRead.fromJson({'surah': 200, 'ayah': 1, 'page': 1}), isNull);
    });
  });

  group('Quran.com client (recorded fixtures)', () {
    final fatiha = [for (var a = 1; a <= 7; a++) AyahRef(1, a)];

    QuranComClient client(_FixtureHttp http, MemoryQuranCacheStore cache) =>
        QuranComClient(http: http, cache: cache);

    _FixtureHttp http() => _FixtureHttp({
      'uthmani_tajweed?chapter_number=1': _fixture('qurancom_tajweed_chapter_1.json'),
      'uthmani_tajweed?page_number=1': _fixture('qurancom_tajweed_page_1.json'),
      'translations/20?chapter_number=1': _fixture('qurancom_translation_20_chapter_1.json'),
      'translations/20?page_number=1': _fixture('qurancom_translation_20_page_1.json'),
    });

    test('builds the documented URLs', () {
      final c = client(http(), MemoryQuranCacheStore());
      expect(c.tajweedUri(surah: 2).toString(), 'https://api.quran.com/api/v4/quran/verses/uthmani_tajweed?chapter_number=2');
      expect(c.tajweedUri(page: 3).toString(), 'https://api.quran.com/api/v4/quran/verses/uthmani_tajweed?page_number=3');
      expect(
        c.translationUri(20, surah: 1).toString(),
        'https://api.quran.com/api/v4/quran/translations/20?chapter_number=1&fields=verse_key',
      );
    });

    test('downloads tajweed, caches it, reads it back offline', () async {
      final h = http();
      final cache = MemoryQuranCacheStore();
      final c = client(h, cache);
      expect(await c.cachedTajweed(1, expectedAyat: fatiha), isNull);
      expect(h.requests, isEmpty, reason: 'reading the cache never touches the network');
      final t = await c.downloadTajweed(1, expectedAyat: fatiha);
      expect(t, hasLength(7));
      expect(t[const AyahRef(1, 1)]!.text, isNot(contains('١')));
      expect(t[const AyahRef(1, 1)]!.marks.first.rule, TajweedRule.hamzatWasl);
      expect(t[const AyahRef(1, 7)]!.marks.map((m) => m.rule), contains(TajweedRule.maddNecessary));
      expect(cache.entries.keys, [QuranComClient.tajweedKey(1)]);
      h.offline = true;
      final again = await c.cachedTajweed(1, expectedAyat: fatiha);
      expect(again![const AyahRef(1, 2)]!.text, t[const AyahRef(1, 2)]!.text);
      expect(await c.cachedTajweedSurahs(), {1});
    });

    test('translations: footnotes stripped, order used when verse_key is absent', () async {
      final c = client(http(), MemoryQuranCacheStore());
      final t = await c.downloadTranslation(1, id: 20, expectedAyat: fatiha);
      expect(t.name, 'Saheeh International');
      expect(t.verses[const AyahRef(1, 2)], '[All] praise is [due] to Allah, Lord of the worlds -');
      final page = await c.downloadTranslationPage(1, id: 20, expectedAyat: fatiha);
      expect(page.verses[const AyahRef(1, 5)], 'It is You we worship and You we ask for help.');
      expect(await c.cachedTranslationSurahs(20), {1});
      final tp = await c.downloadTajweedPage(1, expectedAyat: fatiha);
      expect(tp.keys, fatiha);
    });

    test('offline, server errors and malformed answers', () async {
      final h = http()..offline = true;
      final c = client(h, MemoryQuranCacheStore());
      await expectLater(
        c.downloadTranslation(1, id: 20, expectedAyat: fatiha),
        throwsA(isA<QuranComException>().having((e) => e.problem, 'problem', QuranComProblem.offline)),
      );
      h.offline = false;
      await expectLater(
        c.downloadTranslation(2, id: 20, expectedAyat: const [AyahRef(2, 1)]),
        throwsA(isA<QuranComException>().having((e) => e.problem, 'problem', QuranComProblem.server)),
      );
      await expectLater(
        c.downloadTajweed(1, expectedAyat: fatiha.take(3).toList()),
        throwsA(isA<QuranComException>().having((e) => e.problem, 'problem', QuranComProblem.format)),
      );
      expect(() => QuranComClient.parseTajweed('[]', fatiha), throwsA(isA<QuranComException>()));
      expect(() => QuranComClient.parseTranslation('not json', 20, fatiha), throwsA(isA<QuranComException>()));
    });
  });
}

/// The search index over the bundled text (built once per test run).
abstract final class QuranSearchIndexBuilder {
  static QuranSearchIndex? _index;

  static QuranSearchIndex build() {
    final meta = QuranTestData.meta;
    final text = QuranTestData.text;
    return _index ??= QuranSearchIndex(
      [for (var i = 0; i < meta.ayahCount; i++) text.ayahText(i)],
      [for (var i = 0; i < meta.ayahCount; i++) meta.refAt(i)],
    );
  }
}

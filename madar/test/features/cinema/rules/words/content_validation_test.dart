import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/cinema/rules/words/words.dart';

import 'words_test_utils.dart';

void main() {
  group('lexicon', () {
    test('entries are unique plain words of 3-8 letters with frequency ranks', () {
      expect(lexicon.length, greaterThan(50000));
      final seen = <String>{};
      for (final e in lexicon.entries) {
        expect(seen.add(e.word), isTrue, reason: 'duplicate ${e.word}');
        expect(ArabicText.isGameWord(e.word), isTrue, reason: e.word);
        expect(e.length, inInclusiveRange(3, 8), reason: e.word);
        expect(ArabicText.plain(e.word), e.word);
      }
      expect(lexicon.entries.first.rank, 1);
      expect(lexicon.rankOf('مدينة')! < lexicon.rankOf('ملعقة')!, isTrue);
      expect(lexicon.exact('سيارة')!.vowelled, 'سَيَّارَة');
      expect([for (final e in lexicon.entries) if (e.vowelled != null) e].length, greaterThan(1500));
    });

    test('the filter is applied: no blocked word is in the lexicon', () {
      final hits = [for (final e in lexicon.entries) if (wordFilter.isBlocked(e.word)) e.word];
      expect(hits, isEmpty);
    });

    test('filter: blocked, sensitive, clitics, allowed look-alikes', () {
      expect(wordFilter.blockedCount, greaterThan(50));
      expect(wordFilter.isBlocked('عاهرة'), isTrue);
      expect(wordFilter.isBlocked('والعاهرة'), isTrue); // clitics stripped
      expect(wordFilter.isBlocked('جماعة'), isFalse); // ة is not the clitic ـه
      expect(wordFilter.isBlocked('كسكس'), isFalse); // couscous
      expect(wordFilter.isBlocked('فرج'), isFalse); // relief
      expect(wordFilter.isSensitive('المخدرات'), isTrue);
      expect(wordFilter.isSensitive('سكر'), isFalse); // sugar
      expect(wordFilter.isUnsuitable('مدرسة'), isFalse);
      expect(wordFilter.unsuitableSequences.every((s) => s.length >= 3), isTrue);
    });
  });

  group('word guess answers', () {
    test('curated, unique, valid guesses, suitable, with vowelled forms', () {
      for (final n in WordGuessBank.lengths) {
        final list = guessBank.answers(n);
        expect(list.length, greaterThanOrEqualTo(n == 5 ? 366 : 150), reason: '$n letters');
        final keys = <String>{};
        for (final a in list) {
          expect(a.length, n);
          expect(keys.add(ArabicText.fold(a.word)), isTrue, reason: 'duplicate ${a.word}');
          expect(wordFilter.isUnsuitable(a.word), isFalse, reason: a.word);
          expect(guessBank.isValidGuess(a.word, n), isTrue, reason: a.word);
          expect(ArabicText.plain(a.vowelled), a.word);
        }
      }
    });
  });

  group('word search themes', () {
    test('themes have unique, suitable words of 3-8 letters', () {
      expect(themes.length, greaterThanOrEqualTo(20));
      final ids = <String>{};
      for (final t in themes) {
        expect(ids.add(t.id), isTrue);
        expect(t.titleAr, isNotEmpty);
        expect(t.titleEn, isNotEmpty);
        expect(t.words.length, greaterThanOrEqualTo(8), reason: t.id);
        final keys = <String>{};
        for (final w in t.words) {
          expect(keys.add(ArabicText.fold(w.word)), isTrue, reason: '${t.id}: ${w.word}');
          expect(w.length, inInclusiveRange(3, 8), reason: w.word);
          expect(ArabicText.isGameWord(w.word), isTrue, reason: w.word);
          expect(wordFilter.isUnsuitable(w.word), isFalse, reason: w.word);
        }
      }
      expect(themes.map((t) => t.id), containsAll(['fruits', 'arab_capitals', 'prophets', 'colours']));
    });
  });

  group('crossword clue bank', () {
    test('at least 300 unique pairs; clues never contain their answer', () {
      expect(clues.length, greaterThanOrEqualTo(300));
      final keys = <String>{};
      for (final c in clues) {
        expect(keys.add(ArabicText.fold(c.answer)), isTrue, reason: c.answer);
        expect(c.length, inInclusiveRange(3, 8));
        expect(c.level, inInclusiveRange(1, 3));
        expect(c.clue.trim(), isNotEmpty);
        expect(ArabicText.plain(c.display), c.answer);
        expect(ArabicText.fold(c.clue).replaceAll(' ', '').contains(ArabicText.fold(c.answer)), isFalse, reason: c.answer);
        expect(wordFilter.isBlocked(c.answer), isFalse);
      }
      for (final level in [1, 2, 3]) {
        expect(clues.where((c) => c.level == level).length, greaterThan(80), reason: 'level $level');
      }
    });
  });

  group('islamic quiz', () {
    final meta = jsonDecode(readAsset('assets/quran/quran-meta.json')) as Map<String, Object?>;
    final suras = meta['suras']! as List<Object?>;
    final skeletons = <int, String>{};
    for (var s = 1; s <= 114; s++) {
      final count = (suras[s - 1]! as List<Object?>)[0]! as int;
      for (var a = 1; a <= count; a++) {
        skeletons[s * 1000 + a] = ArabicText.skeleton(quranIndex.ayah(s, a)!);
      }
    }

    test('at least 300 well-formed questions in every category and level', () {
      final qs = quizBank.questions;
      expect(qs.length, greaterThanOrEqualTo(300));
      final ids = <String>{}, prompts = <String>{};
      for (final q in qs) {
        expect(ids.add(q.id), isTrue, reason: q.id);
        expect(prompts.add(q.prompt.ar), isTrue, reason: 'duplicate ${q.prompt.ar}');
        expect(q.prompt.en, isNotEmpty);
        expect(q.options.length, 4);
        expect(q.options.map((o) => o.ar).toSet().length, 4, reason: q.id);
        expect(q.options.map((o) => o.en).toSet().length, 4, reason: q.id);
        expect(q.answerIndex, inInclusiveRange(0, 3));
        expect(q.level, inInclusiveRange(1, 3));
        expect(quizBank.categories, contains(q.category));
      }
      for (final c in quizBank.categories) {
        expect(qs.where((q) => q.category == c).length, greaterThanOrEqualTo(20), reason: c);
      }
      for (final l in [1, 2, 3]) {
        expect(qs.where((q) => q.level == l), isNotEmpty);
      }
    });

    test('every question cites a source; Quran citations are verified against the bundled text', () {
      var quran = 0, hadith = 0, facts = 0;
      for (final q in quizBank.questions) {
        expect(q.sources, isNotEmpty, reason: q.id);
        for (final s in q.sources) {
          expect(s.cite.ar, isNotEmpty);
          expect(s.cite.en, isNotEmpty);
          switch (s.type) {
            case 'quran':
              quran++;
              final text = skeletons[s.sura! * 1000 + s.ayah!];
              expect(text, isNotNull, reason: '${q.id}: ${s.sura}:${s.ayah} does not exist');
              expect(text!.contains(ArabicText.skeleton(s.key!)), isTrue, reason: '${q.id}: ${s.sura}:${s.ayah} lacks "${s.key}"');
            case 'hadith':
              hadith++;
              expect(['bukhari', 'muslim', 'tirmidhi', 'abudawud'], contains(s.book));
              expect(s.number, greaterThan(0));
              expect(s.key, isNotEmpty);
            case 'meta':
              facts++;
              expect(s.key, isNotEmpty);
            default:
              fail('unknown source type ${s.type}');
          }
        }
      }
      expect(quran, greaterThan(150));
      expect(hadith, greaterThan(80));
      expect(facts, greaterThan(20));
    });

    test('mushaf-structure facts used by the quiz hold in the bundled metadata', () {
      List<Object?> sura(int n) => suras[n - 1]! as List<Object?>;
      final raw = (jsonDecode(readAsset(WordsAssets.islamicQuiz)) as Map<String, Object?>)['questions']! as List<Object?>;
      var checked = 0;
      for (final q in raw) {
        for (final s in (q! as Map<String, Object?>)['src']! as List<Object?>) {
          final m = s! as Map<String, Object?>;
          if (m['t'] != 'meta') continue;
          checked++;
          final ok = switch (m['k']) {
            'sura_count' => suras.length == m['v'],
            'sura_at' => sura(m['n']! as int)[3] == m['name'],
            'ayah_count' => sura(m['n']! as int)[0] == m['v'],
            'place' => sura(m['n']! as int)[2] == m['v'],
            'revealed_first' => sura(m['n']! as int)[1] == 1,
            'juz_count' => (meta['juz']! as List).length == m['v'],
            'page_count' => (meta['pages']! as List).length == m['v'],
            'juz_start' => jsonEncode((meta['juz']! as List)[(m['n']! as int) - 1]) == jsonEncode([m['sura'], m['ayah']]),
            'longest_sura' => () {
              final counts = [for (var i = 1; i <= 114; i++) sura(i)[0]! as int];
              return counts.indexOf(counts.reduce((a, b) => a > b ? a : b)) + 1 == m['n'];
            }(),
            'no_basmala' =>
              !skeletons[(m['n']! as int) * 1000 + 1]!.startsWith('بسماللهالرحمنالرحيم') &&
                  skeletons[2001]!.startsWith('بسماللهالرحمنالرحيم'),
            'ayat_containing' => skeletons.values.where((t) => t.contains(ArabicText.skeleton(m['key']! as String))).length == m['v'],
            'most_named' => () {
              final names = [for (final n in m['names']! as List<Object?>) n! as String];
              final counts = {for (final n in names) n: skeletons.values.where((t) => t.contains(n)).length};
              return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key == m['v'];
            }(),
            'longest_ayah' => () {
              final longest = skeletons.entries.reduce((a, b) => a.value.length >= b.value.length ? a : b).key;
              return longest == (m['s']! as int) * 1000 + (m['a']! as int);
            }(),
            _ => false,
          };
          expect(ok, isTrue, reason: 'meta fact $m');
        }
      }
      expect(checked, greaterThan(20));
    });
  });

  group('countries', () {
    test('all 193 UN members and 2 observers with complete schema', () {
      expect(countries.where((c) => !c.isObserver).length, 193);
      expect(countries.where((c) => c.isObserver).map((c) => c.iso).toSet(), {'VA', 'PS'});
      final isos = <String>{}, namesAr = <String>{}, namesEn = <String>{};
      final capsAr = <String>{}, capsEn = <String>{};
      for (final c in countries) {
        expect(RegExp(r'^[A-Z]{2}$').hasMatch(c.iso), isTrue);
        expect(isos.add(c.iso), isTrue, reason: c.iso);
        expect(namesAr.add(c.name.ar) && namesEn.add(c.name.en), isTrue, reason: c.iso);
        expect(c.capital.ar, isNotEmpty);
        expect(c.capital.en, isNotEmpty);
        if (!c.capitalDisputed) {
          expect(capsAr.add(c.capital.ar) && capsEn.add(c.capital.en), isTrue, reason: 'capital of ${c.iso}');
        }
        expect(c.flag.elements, isNotEmpty, reason: c.iso);
        expect(c.flag.aspectRatio, inInclusiveRange(0.5, 3.0));
      }
      for (final continent in Continent.values) {
        expect(countries.where((c) => c.continent == continent), isNotEmpty);
      }
      expect(countries.firstWhere((c) => c.iso == 'SY').flag.elements.where((e) => e['t'] == 'star').length, 3);
      expect(countries.firstWhere((c) => c.iso == 'KZ').capital.en, 'Astana');
      expect(countries.where((c) => c.capitalDisputed).map((c) => c.iso).toSet(), {'IL', 'PS'});
    });
  });

  group('typing passages', () {
    test('passages are unique; Quran references resolve to the exact bundled text', () {
      final ps = passageBank.passages;
      expect(ps.length, greaterThanOrEqualTo(150));
      expect(ps.map((p) => p.id).toSet().length, ps.length);
      final lines = {
        for (final l in readAsset(WordsAssets.quranText).split('\n'))
          if (l.contains('|') && !l.startsWith('#')) l.substring(0, l.indexOf('|', l.indexOf('|') + 1)): l,
      };
      for (final p in ps) {
        final text = p.resolve(quranIndex);
        expect(text, isNotNull, reason: p.id);
        expect(text!.trim(), isNotEmpty);
        if (p.kind == PassageKind.quran) {
          expect(p.cite, isNotNull);
          expect(p.fromAyah! > 1 || p.sura == 1, isTrue, reason: 'basmala-prefixed ayah ${p.id}');
          final parts = <String>[];
          for (var a = p.fromAyah!; a <= p.toAyah!; a++) {
            final line = lines['${p.sura}|$a']!;
            parts.add(line.substring(line.indexOf('|', line.indexOf('|') + 1) + 1));
          }
          expect(text, parts.join(' '), reason: 'Quran text must be verbatim (${p.id})');
        } else {
          for (final w in ArabicText.plain(text).split(RegExp(r'[^ء-ي]+'))) {
            if (w.isNotEmpty) expect(wordFilter.isBlocked(w), isFalse, reason: w);
          }
        }
        if (p.kind == PassageKind.saying) expect(p.attribution, isNotNull);
      }
      for (final k in PassageKind.values) {
        expect(ps.where((p) => p.kind == k), isNotEmpty, reason: k.name);
      }
    });
  });
}

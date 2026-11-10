// Validates the bundled Hisn al-Muslim content, entry by entry.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/features/adhkar/adhkar.dart';

import 'adhkar_harness.dart';

/// Letters only: no marks, unified alef / hamza seats / ya / ta marbuta.
String skeleton(String s) {
  final b = StringBuffer();
  for (final r in s.runes) {
    if (_marks.contains(r) || r == 0x0640) continue;
    final c = switch (r) {
      0x0623 || 0x0625 || 0x0622 || 0x0671 => 0x0627,
      0x0649 => 0x064A,
      0x0624 || 0x0626 => 0x0621,
      0x0629 => 0x0647,
      _ => r,
    };
    b.writeCharCode(c >= 0x0621 && c <= 0x064A ? c : 0x20);
  }
  return b.toString().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).join(' ');
}

const _marks = {0x064B, 0x064C, 0x064D, 0x064E, 0x064F, 0x0650, 0x0651, 0x0652, 0x0653, 0x0654, 0x0655, 0x0670};

/// Canonical combining classes of the Arabic marks used.
const _ccc = {
  0x064B: 27,
  0x064C: 28,
  0x064D: 29,
  0x064E: 30,
  0x064F: 31,
  0x0650: 32,
  0x0651: 33,
  0x0652: 34,
  0x0653: 230,
  0x0654: 230,
  0x0655: 220,
  0x0670: 35,
};

/// Pairs NFC composes (base + mark → precomposed letter).
const _composable = {
  (0x0627, 0x0653),
  (0x0627, 0x0654),
  (0x0627, 0x0655),
  (0x0648, 0x0654),
  (0x064A, 0x0654),
  (0x06C1, 0x0654),
  (0x06D2, 0x0654),
  (0x06D5, 0x0654),
};

/// Why [s] is not in NFC (null when it is): marks out of canonical order
/// or a base + mark pair that has a precomposed form.
String? nfcProblem(String s) {
  final r = s.runes.toList();
  for (var i = 1; i < r.length; i++) {
    final a = _ccc[r[i - 1]], b = _ccc[r[i]];
    if (a != null && b != null && b < a) return 'marks out of order at $i';
    if (_composable.contains((r[i - 1], r[i]))) return 'decomposed letter at $i';
  }
  return null;
}

/// Share of consonants carrying a mark (madd letters excluded).
double vowelCoverage(String s) {
  final r = s.runes.toList();
  var letters = 0, marked = 0;
  for (var i = 0; i < r.length; i++) {
    final c = r[i];
    if (c < 0x0621 || c > 0x064A || c == 0x0627 || c == 0x0649 || c == 0x0648 || c == 0x064A) continue;
    letters++;
    if (i + 1 < r.length && _marks.contains(r[i + 1])) marked++;
  }
  return letters == 0 ? 1 : marked / letters;
}

/// Code points a TrueType font maps to a glyph (cmap formats 4 and 12).
Set<int> ttfCodepoints(Uint8List bytes) {
  final d = ByteData.sublistView(bytes);
  final numTables = d.getUint16(4);
  var cmap = -1;
  for (var i = 0; i < numTables; i++) {
    final rec = 12 + i * 16;
    if (String.fromCharCodes(bytes.sublist(rec, rec + 4)) == 'cmap') cmap = d.getUint32(rec + 8);
  }
  expect(cmap, greaterThan(0), reason: 'font has a cmap');
  final out = <int>{};
  final n = d.getUint16(cmap + 2);
  for (var i = 0; i < n; i++) {
    final sub = cmap + d.getUint32(cmap + 4 + i * 8 + 4);
    final format = d.getUint16(sub);
    if (format == 4) {
      final segX2 = d.getUint16(sub + 6);
      final ends = sub + 14, starts = ends + segX2 + 2, deltas = starts + segX2, ranges = deltas + segX2;
      for (var s = 0; s < segX2 ~/ 2; s++) {
        final end = d.getUint16(ends + 2 * s), start = d.getUint16(starts + 2 * s);
        final delta = d.getInt16(deltas + 2 * s), rangeOffset = d.getUint16(ranges + 2 * s);
        for (var c = start; c <= end && c != 0xFFFF; c++) {
          var glyph = rangeOffset == 0
              ? (c + delta) & 0xFFFF
              : d.getUint16(ranges + 2 * s + rangeOffset + 2 * (c - start));
          if (rangeOffset != 0 && glyph != 0) glyph = (glyph + delta) & 0xFFFF;
          if (glyph != 0) out.add(c);
        }
      }
    } else if (format == 12) {
      final groups = d.getUint32(sub + 12);
      for (var g = 0; g < groups; g++) {
        final base = sub + 16 + g * 12;
        final s = d.getUint32(base), e = d.getUint32(base + 4), first = d.getUint32(base + 8);
        for (var c = s; c <= e; c++) {
          if (first + (c - s) != 0) out.add(c);
        }
      }
    }
  }
  return out;
}

void main() {
  late AdhkarLibrary lib;
  late Map<String, dynamic> quran;
  late Set<int> amiri;

  setUpAll(() {
    lib = loadBundledLibrary();
    quran = jsonDecode(
      File('test/features/adhkar/fixtures/quran_reference.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    amiri = ttfCodepoints(File('assets/fonts/Amiri-Regular.ttf').readAsBytesSync());
  });

  Iterable<(String, String)> arabicTexts(Dhikr d) sync* {
    for (final (i, s) in d.segments.indexed) {
      switch (s) {
        case DhikrTextSegment(:final text):
          yield ('segment $i', text);
        case DhikrQuranSegment(:final verses):
          for (final (v, verse) in verses.indexed) {
            yield ('segment $i verse $v', verse);
          }
      }
    }
    if (d.note != null) yield ('note', d.note!.ar);
    if (d.virtue != null) yield ('virtue', d.virtue!.ar);
    yield ('reference', d.reference.ar);
  }

  test('the five sets with the expected number of adhkar', () {
    expect(lib.categories.map((c) => c.id), AdhkarCategoryId.values);
    expect(
      {for (final c in lib.categories) c.id: c.items.length},
      {
        AdhkarCategoryId.morning: 25,
        AdhkarCategoryId.evening: 23,
        AdhkarCategoryId.afterPrayer: 12,
        AdhkarCategoryId.sleep: 15,
        AdhkarCategoryId.waking: 4,
      },
    );
    expect(lib.sources.map((s) => s.license), containsAll(['MIT', 'Unlicense']));
    expect(lib.sources.every((s) => s.commit.length == 40), isTrue, reason: 'every source pinned to a commit');
  });

  test('every entry: id, non-empty text, count ≥ 1, reference', () {
    final ids = <String>{};
    for (final c in lib.categories) {
      for (final d in c.items) {
        expect(ids.add(d.id), isTrue, reason: 'unique id ${d.id}');
        expect(d.id, startsWith('${c.id.name}.'));
        expect(d.count, greaterThanOrEqualTo(1), reason: d.id);
        expect(d.plainText.trim(), isNotEmpty, reason: d.id);
        expect(d.reference.ar.trim(), isNotEmpty, reason: d.id);
        expect(d.reference.en?.trim(), isNotEmpty, reason: '${d.id} English reference');
        for (final s in d.segments) {
          if (s is DhikrTextSegment) expect(s.text.trim(), isNotEmpty, reason: d.id);
          if (s is DhikrQuranSegment) expect(s.verses, hasLength(s.lastAyah - s.firstAyah + 1), reason: d.id);
        }
        for (final v in d.countAfter.values) {
          expect(v, greaterThanOrEqualTo(1), reason: d.id);
        }
        expect(d.origin, isNotNull, reason: 'every entry records its source dataset');
      }
    }
  });

  test('clean Unicode: NFC, no tatweel, no stray brackets or markers, trimmed', () {
    for (final d in lib.allDhikr) {
      for (final (where, s) in arabicTexts(d)) {
        final at = '${d.id} $where';
        expect(nfcProblem(s), isNull, reason: at);
        expect(s.contains('ـ'), isFalse, reason: '$at tatweel');
        expect(s, equals(s.trim()), reason: '$at untrimmed');
        expect(s.contains('  '), isFalse, reason: '$at double space');
        expect(s.contains('‘'), isFalse, reason: '$at symbol-font glyph');
        if (where.startsWith('segment')) {
          expect(RegExp(r'[()\[\]{}*«»"A-Za-z0-9]').hasMatch(s), isFalse, reason: '$at stray characters: $s');
          // A vowel on a bare alif belongs to the letter before it.
          expect(RegExp('ا[َّ]').hasMatch(s), isFalse, reason: '$at vowel on a bare alif');
          // Tanween fath is written before the alif.
          expect(RegExp('[اى]ً').hasMatch(s), isFalse, reason: '$at tanween after alif');
        }
      }
      for (final en in [d.translationEn, d.virtue?.en, d.note?.en, d.reference.en].nonNulls) {
        expect(en.contains('(shirk'), isFalse, reason: d.id);
        expect(en, equals(en.trim()), reason: d.id);
      }
    }
  });

  test('every character renders with Amiri (no broken glyphs)', () {
    for (final d in lib.allDhikr) {
      for (final (where, s) in arabicTexts(d)) {
        for (final r in s.runes) {
          if (r == 0x20 || r == 0x0A) continue;
          expect(amiri.contains(r), isTrue, reason: '${d.id} $where: U+${r.toRadixString(16).toUpperCase()} missing');
        }
      }
    }
    // The reader's own marks: the ayah ornament with Arabic-Indic digits and
    // the ornate brackets.
    for (final r in [0x06DD, 0xFD3E, 0xFD3F, for (var i = 0x0660; i <= 0x0669; i++) i]) {
      expect(amiri.contains(r), isTrue, reason: 'U+${r.toRadixString(16)}');
    }
  });

  test('fully vowelled: at least 80 % of consonants carry a mark in every dhikr text', () {
    for (final d in lib.allDhikr) {
      for (final s in d.segments) {
        if (s is DhikrTextSegment) {
          expect(vowelCoverage(s.text), greaterThanOrEqualTo(0.8), reason: '${d.id}: ${s.text}');
        }
      }
    }
  });

  test('Quran verses are exactly the reference text', () {
    final spelled = (quran['spelled'] as Map).cast<String, String>();
    final simple = (quran['simple'] as Map).cast<String, String>();
    var verses = 0;
    for (final d in lib.allDhikr) {
      for (final q in d.quranSegments) {
        for (final (i, verse) in q.verses.indexed) {
          final key = '${q.surah}:${q.ayahAt(i)}';
          expect(spelled[key], isNotNull, reason: '$key in the fixture');
          expect(verse, spelled[key], reason: '${d.id} $key');
          // Cross-check against an independent edition (word for word; the
          // alquran.cloud text prefixes the basmala to ayah 1).
          var other = skeleton(simple[key]!).split(' ');
          if (q.ayahAt(i) == 1 && q.surah != 1 && q.surah != 9) other = other.skip(4).toList();
          final mine = skeleton(verse).split(' ');
          expect(mine.length, other.length, reason: '${d.id} $key word count');
          verses++;
        }
      }
    }
    expect(verses, greaterThan(60));
  });

  test('the key Quran passages are complete wherever they are quoted', () {
    DhikrQuranSegment? find(String id, int surah) =>
        lib.dhikrById(id)!.quranSegments.where((q) => q.surah == surah).firstOrNull;
    void complete(String id, int surah, int first, int last) {
      final q = find(id, surah);
      expect(q, isNotNull, reason: '$id quotes surah $surah');
      expect((q!.firstAyah, q.lastAyah), (first, last), reason: id);
    }

    for (final id in ['morning.01', 'evening.01', 'afterPrayer.10', 'sleep.02']) {
      complete(id, 2, 255, 255); // Ayat al-Kursi
    }
    for (final id in ['evening.02', 'sleep.03']) {
      complete(id, 2, 285, 286); // the end of al-Baqarah
    }
    complete('morning.02', 112, 1, 4);
    complete('morning.03', 113, 1, 5);
    complete('morning.04', 114, 1, 6);
    complete('evening.03', 112, 1, 4);
    complete('evening.04', 113, 1, 5);
    complete('evening.05', 114, 1, 6);
    for (final id in ['afterPrayer.09', 'sleep.01']) {
      complete(id, 112, 1, 4);
      complete(id, 113, 1, 5);
      complete(id, 114, 1, 6);
    }
    complete('waking.04', 3, 190, 200);
    // Ayat al-Kursi, word by word.
    expect(
      skeleton(find('morning.01', 2)!.plainText),
      'الله لا اله الا هو الحي القيوم لا تاخذه سنه ولا نوم له ما في السماوات وما في الارض من ذا الذي يشفع عنده '
      'الا باذنه يعلم ما بين ايديهم وما خلفهم ولا يحيطون بشيء من علمه الا بما شاء وسع كرسيه السماوات والارض ولا '
      'يءوده حفظهما وهو العلي العظيم',
    );
  });

  test('spot-check of 24 well-known adhkar (letters) and their counts', () {
    const expected = {
      'morning.07':
          'اللهم انت ربي لا اله الا انت خلقتني وانا عبدك وانا علي عهدك ووعدك ما استطعت اعوذ بك من شر ما صنعت ابوء لك '
          'بنعمتك علي وابوء بذنبي فاغفر لي فانه لا يغفر الذنوب الا انت',
      'morning.14': 'بسم الله الذي لا يضر مع اسمه شيء في الارض ولا في السماء وهو السميع العليم',
      'morning.15': 'رضيت بالله ربا وبالاسلام دينا وبمحمد نبيا',
      'morning.16': 'يا حي يا قيوم برحمتك استغيث اصلح لي شاني كله ولا تكلني الي نفسي طرفه عين',
      'morning.11': 'حسبي الله لا اله الا هو عليه توكلت وهو رب العرش العظيم',
      'morning.22': 'سبحان الله وبحمده عدد خلقه ورضا نفسه وزنه عرشه ومداد كلماته',
      'morning.25': 'سبحان الله وبحمده',
      'morning.24': 'استغفر الله واتوب اليه',
      'morning.20': 'لا اله الا الله وحده لا شريك له له الملك وله الحمد وهو علي كل شيء قدير',
      'evening.22': 'اعوذ بكلمات الله التامات من شر ما خلق',
      'morning.10':
          'اللهم عافني في بدني اللهم عافني في سمعي اللهم عافني في بصري لا اله الا انت اللهم اني اعوذ بك من الكفر '
          'والفقر واعوذ بك من عذاب القبر لا اله الا انت',
      'morning.09': 'اللهم ما اصبح بي من نعمه او باحد من خلقك فمنك وحدك لا شريك لك فلك الحمد ولك الشكر',
      'morning.06': 'اللهم بك اصبحنا وبك امسينا وبك نحيا وبك نموت واليك النشور',
      'evening.07': 'اللهم بك امسينا وبك اصبحنا وبك نحيا وبك نموت واليك المصير',
      'afterPrayer.02': 'اللهم انت السلام ومنك السلام تباركت يا ذا الجلال والاكرام',
      'afterPrayer.03':
          'لا اله الا الله وحده لا شريك له له الملك وله الحمد وهو علي كل شيء قدير اللهم لا مانع لما اعطيت ولا معطي '
          'لما منعت ولا ينفع ذا الجد منك الجد',
      'sleep.07': 'باسمك اللهم اموت واحيا',
      'sleep.04': 'باسمك ربي وضعت جنبي وبك ارفعه فان امسكت نفسي فارحمها وان ارسلتها فاحفظها بما تحفظ به عبادك الصالحين',
      'waking.01': 'الحمد لله الذي احيانا بعد ما اماتنا واليه النشور',
      'waking.03': 'الحمد لله الذي عافاني في جسدي ورد علي روحي واذن لي بذكره',
      'sleep.06': 'اللهم قني عذابك يوم تبعث عبادك',
      'sleep.12': 'الحمد لله الذي اطعمنا وسقانا وكفانا واوانا فكم ممن لا كافي له ولا مءوي',
      'morning.21': 'اللهم صل وسلم علي نبينا محمد',
      'afterPrayer.12': 'اللهم اني اسالك علما نافعا ورزقا طيبا وعملا متقبلا',
    };
    for (final e in expected.entries) {
      expect(skeleton(lib.dhikrById(e.key)!.plainText), e.value, reason: e.key);
    }
    const counts = {
      'morning.02': 3,
      'morning.08': 4,
      'morning.11': 7,
      'morning.14': 3,
      'morning.15': 3,
      'morning.20': 10,
      'morning.21': 10,
      'morning.23': 100,
      'morning.24': 100,
      'morning.25': 100,
      'evening.22': 3,
      'afterPrayer.01': 3,
      'afterPrayer.05': 33,
      'afterPrayer.06': 33,
      'afterPrayer.07': 33,
      'afterPrayer.11': 10,
      'sleep.01': 3,
      'sleep.06': 3,
      'sleep.08': 33,
      'sleep.09': 33,
      'sleep.10': 34,
    };
    for (final e in counts.entries) {
      expect(lib.dhikrById(e.key)!.count, e.value, reason: e.key);
    }
  });

  test('morning wordings stay in the morning set, evening wordings in the evening set', () {
    final morning = lib.category(AdhkarCategoryId.morning).items.map((d) => skeleton(d.plainText)).join(' | ');
    final evening = lib.category(AdhkarCategoryId.evening).items.map((d) => skeleton(d.plainText)).join(' | ');
    for (final w in ['امسينا وامسي الملك', 'اني امسيت', 'ما امسي بي', 'امسينا علي فطره']) {
      expect(morning.contains(w), isFalse, reason: w);
      expect(evening.contains(w), isTrue, reason: w);
    }
    for (final w in ['اصبحنا واصبح الملك', 'اني اصبحت', 'ما اصبح بي', 'اصبحنا علي فطره']) {
      expect(evening.contains(w), isFalse, reason: w);
      expect(morning.contains(w), isTrue, reason: w);
    }
  });

  test('after-prayer set: per-prayer items and counts', () {
    final c = lib.category(AdhkarCategoryId.afterPrayer);
    expect(c.itemsFor(Prayer.fajr).map((d) => d.id), contains('afterPrayer.12'));
    expect(c.itemsFor(Prayer.fajr), hasLength(12));
    expect(c.itemsFor(Prayer.maghrib), hasLength(11));
    expect(c.itemsFor(Prayer.dhuhr), hasLength(10));
    final muawwidhat = lib.dhikrById('afterPrayer.09')!;
    expect(muawwidhat.countFor(Prayer.fajr), 3);
    expect(muawwidhat.countFor(Prayer.maghrib), 3);
    expect(muawwidhat.countFor(Prayer.asr), 1);
  });

  test('an English meaning for every dhikr but the Quran-only ones (no Quran translation is bundled)', () {
    // Verses, with the basmala or the isti'adha before them.
    final framing = {skeleton('بِسْمِ اللَّهِ الرَّحْمَنِ الرَّحِيمِ'), skeleton('أَعُوذُ بِاللَّهِ مِنَ الشَّيْطَانِ الرَّجِيمِ')};
    for (final d in lib.allDhikr) {
      final quranOnly = d.segments.every((s) => s is DhikrQuranSegment || framing.contains(skeleton(s.plainText)));
      if (quranOnly && d.hasQuran) {
        expect(d.translationEn, isNull, reason: d.id);
      } else {
        expect(d.translationEn, isNotNull, reason: d.id);
      }
    }
    expect(lib.allDhikr.where((d) => d.translationEn != null).length, 64);
  });

  test('the English is Madar\'s own, not the unlicensed hisnmuslim.com / sunnah.com translation', () {
    // Hallmarks of the "Fortress of the Muslim" English the datasets copied
    // (see assets/licenses/adhkar_credits.txt).
    const copied = [
      'None has the right to be worshipped',
      'over all things omnipotent',
      'How perfect Allah is',
      'I take refuge in You from the evil of which I have committed',
      'Whoever says this when he rises in the morning',
    ];
    for (final d in lib.allDhikr) {
      final english = [d.translationEn, d.virtue?.en, d.note?.en].whereType<String>().join(' ');
      for (final phrase in copied) {
        expect(english.contains(phrase), isFalse, reason: '${d.id}: "$phrase"');
      }
    }
  });
}

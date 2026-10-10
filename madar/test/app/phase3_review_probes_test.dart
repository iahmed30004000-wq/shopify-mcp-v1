// Edge probes from the Phase 3 review pass, kept as regression tests: the
// bundled Quran at every page / juz / hizb / quarter boundary and the
// basmala edges (1:1, 9:1, 27:30), the sajdat, Quran.com's tajweed class
// names, SM-2 due dates across month / year / DST edges (run under several
// TZ values), qibla bearings against an independent formula, heading
// smoothing through north, and the recitation queue's basmala rules.
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/quran/ayah.dart';
import 'package:madar/features/hifz/domain/sm2.dart';
import 'package:madar/features/qibla/domain/circular_filter.dart';
import 'package:madar/features/qibla/domain/qibla_fix.dart';
import 'package:madar/features/quran/data/quran_store.dart';
import 'package:madar/features/quran/domain/arabic_search.dart';
import 'package:madar/features/quran/domain/tajweed.dart';
import 'package:madar/features/recitation/domain/recitation_queue.dart';
import 'package:madar/features/wird/domain/calendar_days.dart';

import '../features/quran/quran_test_data.dart';

void main() {
  final meta = QuranTestData.meta;

  group('data boundaries', () {
    test('every page/juz/hizb/quarter start and end maps back to itself', () {
      for (var p = 1; p <= 604; p++) {
        expect(meta.pageOf(meta.pageStart(p)), p, reason: 'start of page $p');
        expect(meta.pageOf(meta.pageEnd(p)), p, reason: 'end of page $p');
        if (p < 604) expect(meta.next(meta.pageEnd(p)), meta.pageStart(p + 1));
      }
      for (var j = 1; j <= 30; j++) {
        expect(meta.juzOf(meta.juzStart(j)), j);
        expect(meta.juzOf(meta.juzEnd(j)), j);
      }
      for (var h = 1; h <= 60; h++) {
        expect(meta.hizbOf(meta.hizbStart(h)), h);
      }
      for (var q = 1; q <= 240; q++) {
        expect(meta.quarterOf(meta.quarterStart(q)), q);
      }
    });

    test('catalog basmala edges', () async {
      final catalog = BundledQuranCatalog(QuranTestData.store());
      await catalog.ensureLoaded();
      final one = await catalog.ayahText(const AyahRef(1, 1));
      expect(one, startsWith('بِسْمِ'));
      final tawbah = await catalog.ayahText(const AyahRef(9, 1));
      expect(tawbah, isNot(contains('بِسْمِ')));
      expect(ArabicSearch.normalize(tawbah).text, startsWith(ArabicSearch.normalize('بَرَآءَةٌ مِّنَ').text));
      final baqarah = await catalog.ayahText(const AyahRef(2, 1));
      expect(baqarah, isNot(contains('بِسْمِ')));
      final naml = await catalog.ayahText(const AyahRef(27, 30));
      expect(naml, contains('بِسْمِ'));
      expect(catalog.next(const AyahRef(114, 6)), isNull);
      expect(catalog.previous(const AyahRef(1, 1)), isNull);
      expect(catalog.next(const AyahRef(1, 7)), const AyahRef(2, 1));
      expect(catalog.countInRange(const AyahRange(AyahRef(1, 1), AyahRef(114, 6))), 6236);
      expect(catalog.pageOf(const AyahRef(1, 7)), 1);
      expect(catalog.pageOf(const AyahRef(2, 1)), 2);
      expect(catalog.pageOf(const AyahRef(114, 6)), 604);
      expect(catalog.juzOf(const AyahRef(2, 142)), 2);
      expect(catalog.juzOf(const AyahRef(2, 141)), 1);
      expect(catalog.hizbOf(const AyahRef(2, 75)), 2);
      expect(catalog.hizbOf(const AyahRef(2, 74)), 1);
    });

    test('sajdat', () {
      final refs = meta.sajdat.map((s) => '${s.ref}').toList();
      expect(refs, [
        '7:206', '13:15', '16:50', '17:109', '19:58', '22:18', '22:77', '25:60', //
        '27:26', '32:15', '38:24', '41:38', '53:62', '84:21', '96:19',
      ]);
    });
  });

  group('tajweed markup', () {
    test('documented Quran.com shape', () {
      const markup =
          'بِسْمِ <tajweed class=ham_wasl>ٱ</tajweed>للَّهِ <tajweed class=ham_wasl>ٱ</tajweed><tajweed class=laam_shamsiyah>ل</tajweed>رَّحْمَ<tajweed class=madda_natural>ـٰ</tajweed>نِ <span class=end>١</span>';
      final t = Tajweed.parseQuranCom(markup);
      expect(t.text, 'بِسْمِ ٱللَّهِ ٱلرَّحْمَـٰنِ');
      expect(t.marks.map((m) => m.rule).toList(), contains(TajweedRule.hamzatWasl));
      expect(t.marks.map((m) => m.rule).toList(), contains(TajweedRule.lamShamsiyyah));
    });

    test('Quran.com class names', () {
      for (final c in [
        'ham_wasl',
        'slnt',
        'laam_shamsiyah',
        'madda_normal',
        'madda_permissible',
        'madda_necessary',
        'madda_obligatory',
        'qalaqah',
        'ikhafa_shafawi',
        'ikhafa',
        'idgham_shafawi',
        'iqlab',
        'idgham_ghunnah',
        'idgham_wo_ghunnah',
        'idgham_mutajanisayn',
        'idgham_mutaqaribayn',
        'ghunnah',
      ]) {
        expect(TajweedRule.fromClass(c), isNotNull, reason: c);
      }
    });
  });

  group('SM-2 due dates', () {
    test('month, year and DST edges', () {
      expect(Sm2.dueDate(DateTime(2026, 1, 31, 23, 50), 1), DateTime(2026, 2, 1));
      expect(Sm2.dueDate(DateTime(2026, 12, 31, 10), 6), DateTime(2027, 1, 6));
      expect(Sm2.dueDate(DateTime(2028, 2, 28), 1), DateTime(2028, 2, 29));
      // Europe (last Sunday of March / October), US, Chile.
      for (final d in [
        DateTime(2026, 3, 28),
        DateTime(2026, 10, 24),
        DateTime(2026, 3, 7),
        DateTime(2026, 9, 5),
        DateTime(2026, 9, 6),
        DateTime(2026, 4, 4),
      ]) {
        for (final n in [1, 2, 6, 16]) {
          final due = Sm2.dueDate(d.add(const Duration(hours: 22)), n);
          expect(CalendarDays.between(d, due), n, reason: '$d + $n');
          expect(due.hour == 0 || due.hour == 1, isTrue, reason: '$due');
          expect(CalendarDays.key(due), CalendarDays.key(DateTime(d.year, d.month, d.day + n, 12)), reason: '$d + $n');
        }
      }
    });
  });

  group('qibla bearings', () {
    double ref(double lat, double lon) {
      const kLat = 21.4225241, kLon = 39.8261818;
      final p1 = lat * math.pi / 180, p2 = kLat * math.pi / 180;
      final dl = (kLon - lon) * math.pi / 180;
      final y = math.sin(dl) * math.cos(p2);
      final x = math.cos(p1) * math.sin(p2) - math.sin(p1) * math.cos(p2) * math.cos(dl);
      return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
    }

    test('known cities', () {
      final cities = {
        'Amman': (31.9539, 35.9106, 160.7),
        'Sydney': (-33.8688, 151.2093, 277.5),
        'Tokyo': (35.6762, 139.6503, 293.0),
        'Cape Town': (-33.9249, 18.4241, 23.0),
        'Moscow': (55.7558, 37.6173, 176.0),
        'Riyadh': (24.7136, 46.6753, 243.9),
        'Madinah': (24.4672, 39.6111, 176.0),
      };
      for (final MapEntry(key: name, value: (lat, lon, approx)) in cities.entries) {
        final fix = QiblaFix.at(lat, lon);
        expect(fix.bearing, closeTo(ref(lat, lon), 0.01), reason: name);
        expect(fix.bearing, closeTo(approx, 1.5), reason: '$name ${fix.bearing}');
      }
      expect(QiblaFix.at(21.4225241, 39.8261818).atKaaba, isTrue);
    });
  });

  group('heading filter', () {
    test('359 → 0 → 1 never swings through south', () {
      final f = CircularOneEuroFilter();
      final seq = <double>[355, 357, 359, 0.5, 2, 4, 6, 4, 1, 359, 356];
      for (final a in seq) {
        final out = f.filter(a, 0.02);
        final d = ((out - a + 540) % 360) - 180;
        expect(d.abs(), lessThan(10), reason: 'in $a out $out');
        expect(out, inInclusiveRange(0, 360));
      }
    });
  });

  group('recitation queue', () {
    List<String> items(RecitationQueue q) => [for (var i = 0; i < q.length!; i++) q.itemAt(i).toString()];

    test('basmala edges', () {
      expect(items(RecitationQueue.build(const AyahRange(AyahRef(8, 75), AyahRef(9, 1)))), [
        'ayah(8:75 #1/r1)',
        'ayah(9:1 #1/r1)',
      ]);
      expect(items(RecitationQueue.build(const AyahRange(AyahRef(1, 1), AyahRef(1, 2)))).first, 'ayah(1:1 #1/r1)');
      expect(items(RecitationQueue.build(const AyahRange(AyahRef(113, 5), AyahRef(114, 1)), repeatAyah: 2)), [
        'ayah(113:5 #1/r1)',
        'ayah(113:5 #2/r1)',
        'basmala(114:1/r1)',
        'ayah(114:1 #1/r1)',
        'ayah(114:1 #2/r1)',
      ]);
      final twice = items(RecitationQueue.build(const AyahRange(AyahRef(112, 1), AyahRef(112, 2)), repeatRange: 2));
      expect(twice.where((s) => s.startsWith('basmala')).length, 2);
    });
  });
}

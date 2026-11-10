import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/features/ramadan/domain/khatmah_plan.dart';
import 'package:madar/features/ramadan/domain/ramadan_calendar.dart';
import 'package:madar/features/wird/domain/quran_axis.dart';

import '../wird/fake_quran_catalog.dart';

void main() {
  final start = DateTime(2027, 2, 8);
  DateTime day(int i) => addCivilDays(start, i);

  KhatmahPlan plan({int days = 30, int ceiling = 40, int total = 604}) =>
      KhatmahPlan(startDate: start, totalPages: total, days: days, ceilingPages: ceiling);

  /// Invariants that must hold in every state.
  void checkInvariants(KhatmahPlan p, KhatmahToday t, {String? why}) {
    final all = [t.portion.pages, ...t.upcoming];
    for (final n in all) {
      expect(n, isNonNegative, reason: 'negative portion $why');
      expect(n, lessThanOrEqualTo(p.ceilingPages), reason: 'over the ceiling $why');
    }
    expect(t.portion.fromPage, greaterThanOrEqualTo(1), reason: why);
    if (!t.portion.isEmpty) {
      expect(t.portion.toPage, lessThanOrEqualTo(p.totalPages), reason: 'past the last page $why');
    }
    expect(t.remainingPages, inInclusiveRange(0, p.totalPages), reason: why);
    expect(t.shortfallPages, isNonNegative, reason: why);
    // When everything fits, today's reading plus the re-planned days account
    // for every page that was left when the day began.
    if ((t.status == KhatmahStatus.active || t.status == KhatmahStatus.notStarted) && t.shortfallPages == 0) {
      final leftAtDayStart = t.remainingPages + t.readToday;
      final today = t.portion.pages > t.readToday ? t.portion.pages : t.readToday;
      expect(today + t.upcoming.fold<int>(0, (a, b) => a + b), leftAtDayStart, reason: 'all pages planned $why');
    }
  }

  group('the original even plan', () {
    test('604 pages in 30 days: today is 21 for the first four days then 20', () {
      final p = plan();
      final t = p.today(day(0), KhatmahProgress());
      expect(t.status, KhatmahStatus.active);
      expect(t.portion, const KhatmahPortion(1, 21));
      expect(t.upcoming, hasLength(29));
      expect([t.portion.pages, ...t.upcoming].fold<int>(0, (a, b) => a + b), 604);
      expect(t.shortfallPages, 0);
      expect(t.suggestedExtensionDays, 0);
      expect(t.pagesBehind, 0);
      expect(t.daysLeft, 30);
    });

    test('reading each day exactly as planned finishes on the last day', () {
      final p = plan();
      var progress = KhatmahProgress();
      for (var i = 0; i < 30; i++) {
        final t = p.today(day(i), progress);
        expect(t.pagesBehind, 0, reason: 'day $i');
        expect(t.status, KhatmahStatus.active);
        progress = progress.markPortionRead(i, t.portion, totalPages: 604);
      }
      expect(progress.frontier, 604);
      final done = p.today(day(29), progress);
      expect(done.status, KhatmahStatus.finished);
      expect(done.portion.isEmpty, isTrue);
      expect(done.remainingPages, 0);
    });

    test("today's portion does not shrink while he reads through it", () {
      final p = plan();
      final t0 = p.today(day(3), KhatmahProgress({2: p.plannedBefore(3)}));
      final mid = KhatmahProgress({2: p.plannedBefore(3), 3: p.plannedBefore(3) + 10});
      final t1 = p.today(day(3), mid);
      expect(t1.portion, t0.portion);
      expect(t1.readToday, 10);
      expect(t1.portionLeft, t0.portion.pages - 10);
      expect(t1.todayDone, isFalse);
      final full = p.today(day(3), mid.markPortionRead(3, t0.portion, totalPages: 604));
      expect(full.todayDone, isTrue);
      expect(full.portionLeft, 0);
    });

    test('before the start it previews day 1', () {
      final t = plan().today(day(-3), KhatmahProgress());
      expect(t.status, KhatmahStatus.notStarted);
      expect(t.portion, const KhatmahPortion(1, 21));
      expect(t.dayIndex, 0);
    });
  });

  group('re-plan after missed days', () {
    test('1 missed day: 604 pages over 29 days', () {
      final t = plan().today(day(1), KhatmahProgress());
      expect(t.pagesBehind, 21);
      expect(t.daysLeft, 29);
      expect(t.portion, const KhatmahPortion(1, 21));
      expect(t.upcoming, hasLength(28));
      expect([t.portion.pages, ...t.upcoming].fold<int>(0, (a, b) => a + b), 604);
      expect([t.portion.pages, ...t.upcoming].reduce((a, b) => a > b ? a : b), 21);
      expect(t.shortfallPages, 0);
      checkInvariants(plan(), t, why: '1 missed');
    });

    test('5 missed days: 604 pages over 25 days', () {
      final t = plan().today(day(5), KhatmahProgress());
      expect(t.daysLeft, 25);
      expect(t.portion.pages, 25);
      expect([t.portion.pages, ...t.upcoming].fold<int>(0, (a, b) => a + b), 604);
      expect(t.shortfallPages, 0);
      // Even: no two days differ by more than one page.
      final all = [t.portion.pages, ...t.upcoming];
      expect(all.reduce((a, b) => a > b ? a : b) - all.reduce((a, b) => a < b ? a : b), lessThanOrEqualTo(1));
      expect(t.pagesBehind, 104, reason: '5 x 20 + 4 odd pages');
    });

    test('15 missed days: the default ceiling of 40 is reached, never exceeded', () {
      final p = plan();
      final t = p.today(day(15), KhatmahProgress());
      expect(t.daysLeft, 15);
      expect(t.portion.pages, 40);
      expect(t.upcoming, everyElement(40));
      expect(t.upcoming, hasLength(14));
      // 15 x 40 = 600; four pages cannot fit.
      expect(t.shortfallPages, 4);
      expect(t.suggestedExtensionDays, 1);
      expect(t.remainingPages, 604);
      checkInvariants(p, t, why: '15 missed');
    });

    test('15 missed days with a higher ceiling fits again, evenly', () {
      final p = plan(ceiling: 45);
      final t = p.today(day(15), KhatmahProgress());
      expect(t.portion.pages, 41);
      expect(t.shortfallPages, 0);
      expect(t.suggestedExtensionDays, 0);
      expect([t.portion.pages, ...t.upcoming].fold<int>(0, (a, b) => a + b), 604);
    });

    test('a tight ceiling reports the shortfall and the days to add', () {
      final p = plan(ceiling: 20);
      final t = p.today(day(10), KhatmahProgress());
      // 20 days left x 20 = 400 of 604: 204 do not fit = 11 more days at 20.
      expect(t.portion.pages, 20);
      expect(t.shortfallPages, 204);
      expect(t.suggestedExtensionDays, 11);
      checkInvariants(p, t, why: 'tight');
    });

    test('catching up lowers the shortfall and the later days', () {
      final p = plan();
      final base = p.today(day(15), KhatmahProgress());
      // He reads 55 pages today, 15 more than the 40 allowed.
      final read = KhatmahProgress({15: 55});
      final t = p.today(day(15), read);
      expect(t.portion, base.portion, reason: 'the day\'s portion stays fixed');
      expect(t.readToday, 55);
      expect(t.todayDone, isTrue);
      expect(t.shortfallPages, 0);
      expect(t.remainingPages, 549);
      expect(t.upcoming.fold<int>(0, (a, b) => a + b), 549);
      checkInvariants(p, t, why: 'catching up');
    });

    test('reading ahead of schedule shrinks the rest', () {
      final p = plan();
      final t = p.today(day(4), KhatmahProgress({0: 60, 1: 120, 2: 200, 3: 300}));
      expect(t.pagesBehind, 0);
      expect(t.portion.fromPage, 301);
      expect(t.portion.pages, lessThan(21));
      expect(t.daysLeft, 26);
    });

    test('partial reading on an earlier day is counted', () {
      final p = plan();
      final t = p.today(day(5), KhatmahProgress({0: 21, 1: 42}));
      expect(t.portion.fromPage, 43);
      expect(t.remainingPages, 604 - 42);
      expect([t.portion.pages, ...t.upcoming].fold<int>(0, (a, b) => a + b), 604 - 42);
    });

    test('property sweep: never over the ceiling, never negative, never past the last page', () {
      for (final ceiling in [1, 5, 20, 21, 25, 40, 100, 1000]) {
        for (final days in [1, 7, 29, 30]) {
          for (final total in [604, 30, 1]) {
            final p = plan(days: days, ceiling: ceiling, total: total);
            for (var d = -1; d <= days + 2; d++) {
              for (final read in [0, 1, total ~/ 3, total - 1, total, total + 50]) {
                final progress = KhatmahProgress({if (read > 0 && d > 0) d - 1: read.clamp(0, total)});
                final t = p.today(day(d), progress);
                checkInvariants(p, t, why: 'ceiling=$ceiling days=$days total=$total day=$d read=$read');
              }
            }
          }
        }
      }
    });

    test('exactly fitting: ceiling x days left == remaining reports no shortfall', () {
      final p = plan(days: 10, ceiling: 60, total: 600);
      final t = p.today(day(0), KhatmahProgress());
      expect(t.portion.pages, 60);
      expect(t.shortfallPages, 0);
      final p2 = plan(days: 10, ceiling: 59, total: 600);
      expect(p2.today(day(0), KhatmahProgress()).shortfallPages, 10);
    });
  });

  group('after the last day / finished', () {
    test('overdue: a catch-up portion within the ceiling plus a suggested extension', () {
      final p = plan();
      final t = p.today(day(31), KhatmahProgress({29: 500}));
      expect(t.status, KhatmahStatus.overdue);
      expect(t.remainingPages, 104);
      expect(t.portion, const KhatmahPortion(501, 40));
      expect(t.shortfallPages, 104);
      expect(t.suggestedExtensionDays, 3);
      expect(t.upcoming, isEmpty);
      expect(t.daysLeft, 0);
    });

    test('overdue with few pages left never goes past the last page', () {
      final t = plan().today(day(40), KhatmahProgress({29: 600}));
      expect(t.portion, const KhatmahPortion(601, 4));
      expect(t.portion.toPage, 604);
      expect(t.suggestedExtensionDays, 1);
    });

    test('finished stays finished, even if marked beyond the end', () {
      final p = plan();
      final progress = KhatmahProgress().markReadThrough(3, 9999, totalPages: 604);
      expect(progress.frontier, 604);
      final t = p.today(day(3), progress);
      expect(t.status, KhatmahStatus.finished);
      expect(t.portion.isEmpty, isTrue);
      expect(t.upcoming, isEmpty);
      expect(t.shortfallPages, 0);
    });

    test('a one-day plan and a one-page ceiling are valid', () {
      final p = KhatmahPlan(startDate: start, totalPages: 10, days: 0, ceilingPages: 0);
      expect(p.days, 1);
      expect(p.ceilingPages, 1);
      final t = p.today(start, KhatmahProgress());
      expect(t.portion.pages, 1);
      expect(t.shortfallPages, 9);
    });
  });

  group('progress', () {
    test('mark read is monotonic per day and clamped', () {
      var pr = KhatmahProgress();
      pr = pr.markReadThrough(0, 20, totalPages: 604);
      pr = pr.markReadThrough(1, 10, totalPages: 604); // below day 0's mark
      expect(pr.frontier, 20, reason: 'cannot fall below what was read before');
      pr = pr.markReadThrough(1, 50, totalPages: 604);
      expect(pr.frontierBefore(1), 20);
      expect(pr.frontier, 50);
      pr = pr.markReadThrough(1, 30, totalPages: 604); // a correction downwards
      expect(pr.frontier, 30);
      pr = pr.markReadThrough(1, 0, totalPages: 604);
      expect(pr.frontierByDay, {0: 20});
      pr = pr.markReadThrough(-5, 25, totalPages: 604);
      expect(pr.frontierByDay[0], 25);
    });

    test('the previous state is the undo', () {
      final a = KhatmahProgress({0: 10});
      final b = a.markReadThrough(1, 30, totalPages: 604);
      expect(a.frontier, 10);
      expect(b.frontier, 30);
    });

    test('a hand-changed clock (a later day marked, then an earlier one) stays consistent', () {
      final p = KhatmahProgress({5: 100}).markReadThrough(2, 150, totalPages: 604);
      expect(p.frontierByDay, {2: 150, 5: 150});
      expect(p.frontier, 150);
    });
  });

  group('the span and the mushaf axis', () {
    test('forSpan caps the days at the month length', () {
      const c = RamadanCalendar();
      final s29 = c.spanOfYear(1448); // 29 days
      expect(s29.length, 29);
      final p = KhatmahPlan.forSpan(s29, totalPages: 604);
      expect(p.days, 29);
      expect(p.startDate, s29.first);
      expect(KhatmahPlan.forSpan(s29, totalPages: 604, days: 20).days, 20);
      final s30 = c.spanOfYear(1447);
      expect(s30.length, 30);
      expect(KhatmahPlan.forSpan(s30, totalPages: 604).days, 30);
    });

    test('portions map onto the wird page axis', () {
      final axis = QuranAxis.of(FakeQuranCatalog(), WirdUnit.pages);
      expect(axis.units, 604);
      final p = plan(total: axis.units);
      final t = p.today(day(0), KhatmahProgress());
      final range = t.portion.ayahRange(axis)!;
      // Day 1 starts at Al-Fatihah 1:1 and ends where page 21 ends.
      expect((range.first.surah, range.first.ayah), (1, 1));
      final next = p.today(day(1), KhatmahProgress({0: t.portion.pages}));
      final r2 = next.portion.ayahRange(axis)!;
      expect(axis.index.indexOf(r2.first), axis.index.indexOf(range.last) + 1, reason: 'portions are contiguous');
      // The last portion ends at the last ayah of the mushaf.
      final lastDay = p.today(day(29), KhatmahProgress({28: 604 - 20}));
      final last = lastDay.portion.ayahRange(axis)!;
      expect((last.last.surah, last.last.ayah), (114, 6));
      expect(const KhatmahPortion(5, 0).ayahRange(axis), isNull);
    });
  });

  group('serialisation', () {
    test('plan and progress round-trip through JSON', () {
      final p = KhatmahPlan(startDate: DateTime(2027, 2, 8), totalPages: 604, days: 29, ceilingPages: 33);
      final back = KhatmahPlan.fromJson(jsonDecode(jsonEncode(p.toJson())) as Map<String, dynamic>);
      expect(back, p);
      expect(p.toJson()['startDate'], '2027-02-08');
      final pr = KhatmahProgress({0: 21, 3: 80, 10: 300});
      final prBack = KhatmahProgress.fromJson(jsonDecode(jsonEncode(pr.toJson())) as Map<String, dynamic>);
      expect(prBack, pr);
      expect(prBack.hashCode, pr.hashCode);
    });

    test('bad JSON falls back to safe values', () {
      final p = KhatmahPlan.fromJson({'startDate': 'nope', 'days': -3, 'ceilingPages': 'x'});
      expect(p.days, 1);
      expect(p.ceilingPages, KhatmahPlan.defaultCeilingPages);
      expect(p.totalPages, 604);
      final pr = KhatmahProgress.fromJson({
        'frontierByDay': {'a': 5, '2': 'x', '-1': 4, '3': 7},
      });
      expect(pr.frontierByDay, {3: 7});
      expect(KhatmahProgress.fromJson({}).frontier, 0);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/core/quran/ayah.dart';
import 'package:madar/features/wird/domain/calendar_days.dart';
import 'package:madar/features/wird/domain/quran_axis.dart';
import 'package:madar/features/wird/domain/wird_engine.dart';
import 'package:madar/features/wird/domain/wird_plan.dart';

import 'fake_quran_catalog.dart';

final _catalog = FakeQuranCatalog();
final _index = QuranIndex(_catalog);
QuranAxis _axis(WirdUnit unit) => QuranAxis.of(_catalog, unit, index: _index);

final _start = DateTime(2026, 9, 1);
DateTime _day(int offset) => CalendarDays.add(_start, offset);

/// Last ayah of page [page].
AyahRef _pageEnd(int page) => page == 604 ? const AyahRef(114, 6) : _catalog.previous(_catalog.pageStart(page + 1))!;

AyahRange _pages(int from, int to) => AyahRange(_catalog.pageStart(from), _pageEnd(to));

var _seq = 0;
WirdSession _session(
  int dayOffset,
  AyahRange range, {
  String? plan = 'p',
  QuranSessionMode mode = QuranSessionMode.read,
}) => WirdSession(
  id: 's${_seq++}',
  day: _day(dayOffset),
  range: range,
  planId: plan,
  mode: mode,
  createdAt: _day(dayOffset).add(Duration(hours: 12, seconds: _seq)),
);

WirdPlan _plan({
  WirdUnit unit = WirdUnit.pages,
  double amount = 2,
  AyahRef start = const AyahRef(1, 1),
  int? khatmaDays,
  WirdCatchUp catchUp = WirdCatchUp.spread,
  List<WirdPause> pauses = const [],
  bool active = true,
  DateTime? startDate,
}) {
  final s = startDate ?? _start;
  return WirdPlan(
    id: 'p',
    name: 'Plan',
    unit: unit,
    amountPerDay: amount,
    start: start,
    startDate: s,
    targetDate: khatmaDays == null ? null : CalendarDays.add(s, khatmaDays - 1),
    active: active,
    meta: WirdPlanMeta(catchUp: catchUp, pauses: pauses),
  );
}

WirdPlanState _compute(WirdPlan plan, List<WirdSession> sessions, int todayOffset, {DateTime? today}) =>
    WirdEngine.compute(plan: plan, sessions: sessions, axis: _axis(plan.unit), today: today ?? _day(todayOffset));

void main() {
  group('QuranIndex / QuranAxis', () {
    test('indexes every ayah in reading order', () {
      expect(_index.total, 6236);
      expect(_index.indexOf(const AyahRef(1, 1)), 0);
      expect(_index.indexOf(const AyahRef(2, 1)), 7);
      expect(_index.refAt(7), const AyahRef(2, 1));
      expect(_index.refAt(6235), const AyahRef(114, 6));
      expect(_index.count(const AyahRange(AyahRef(1, 6), AyahRef(2, 2))), 4);
      for (final i in [0, 6, 7, 293, 2000, 5000, 6235]) {
        expect(_index.indexOf(_index.refAt(i)), i);
      }
    });

    test('page, juz and hizb positions', () {
      final pages = _axis(WirdUnit.pages);
      expect(pages.units, 604);
      expect(pages.positionOf(0), 0);
      expect(pages.positionOf(_index.indexOf(const AyahRef(2, 1))), 1);
      expect(pages.positionOf(_index.indexOf(const AyahRef(2, 6))), 2);
      expect(pages.indexAt(2), _index.indexOf(const AyahRef(2, 6)));
      expect(pages.positionOf(6236), 604);
      // Halfway through page 2 (2:1–2:5, five ayat) is between ayat 2 and 3.
      expect(pages.positionOf(_index.indexOf(const AyahRef(2, 3))), closeTo(1.4, 1e-9));
      final juz = _axis(WirdUnit.juz);
      expect(juz.units, 30);
      expect(juz.positionOf(_index.indexOf(const AyahRef(2, 142))), 1);
      final hizb = _axis(WirdUnit.hizb);
      expect(hizb.units, 60);
      expect(hizb.positionOf(_index.indexOf(const AyahRef(2, 75))), 1);
      final ayat = _axis(WirdUnit.ayat);
      expect(ayat.units, 6236);
      expect(ayat.positionOf(10), 10);
    });

    test('cumulative positions continue into the next khatma', () {
      final pages = _axis(WirdUnit.pages);
      expect(pages.positionOfCumulative(6236), 604);
      expect(pages.positionOfCumulative(6236 + 7), 605);
      expect(pages.indexAtCumulative(605), 6236 + 7);
    });
  });

  group('daily targets per unit', () {
    test('khatma in 30 days: ~20 pages ending on a page boundary', () {
      final s = _compute(_plan(khatmaDays: 30), const [], 0);
      expect(s.target.base, closeTo(604 / 30, 1e-9));
      expect(s.target.range, _pages(1, 20));
      expect(s.target.quota, 20);
      expect(s.target.met, isFalse);
      expect(s.days.single.status, WirdDayStatus.pending);
    });

    test('N pages a day advances with the reading', () {
      final plan = _plan(amount: 2);
      final sessions = [_session(0, _pages(1, 2)), _session(1, _pages(3, 4)), _session(2, _pages(5, 6))];
      final s = _compute(plan, sessions, 3);
      expect(s.target.range, _pages(7, 8));
      expect(s.cursor, _catalog.pageStart(7));
      expect(s.streak, 3);
      expect(s.days.map((d) => d.status), [
        WirdDayStatus.met,
        WirdDayStatus.met,
        WirdDayStatus.met,
        WirdDayStatus.pending,
      ]);
    });

    test('a juz a day', () {
      final plan = _plan(unit: WirdUnit.juz, amount: 1);
      expect(_compute(plan, const [], 0).target.range, const AyahRange(AyahRef(1, 1), AyahRef(2, 141)));
      final s = _compute(plan, [_session(0, const AyahRange(AyahRef(1, 1), AyahRef(2, 141)))], 1);
      expect(s.target.range, const AyahRange(AyahRef(2, 142), AyahRef(2, 252)));
      expect(s.days.first.status, WirdDayStatus.met);
    });

    test('a hizb a day', () {
      final s = _compute(_plan(unit: WirdUnit.hizb, amount: 1), const [], 0);
      expect(s.target.range, const AyahRange(AyahRef(1, 1), AyahRef(2, 74)));
    });

    test('N ayat a day, with partial progress today', () {
      final plan = _plan(unit: WirdUnit.ayat, amount: 10, start: const AyahRef(2, 1));
      final s = _compute(plan, [_session(0, const AyahRange(AyahRef(2, 1), AyahRef(2, 5)))], 0);
      expect(s.target.range, const AyahRange(AyahRef(2, 1), AyahRef(2, 10)));
      expect(s.target.remaining, const AyahRange(AyahRef(2, 6), AyahRef(2, 10)));
      expect(s.target.progress, closeTo(0.5, 1e-9));
      expect(s.target.met, isFalse);
      expect(s.target.resumeAt, const AyahRef(2, 6));
    });

    test('half a page a day ends mid-page', () {
      final s = _compute(_plan(amount: 0.5, start: const AyahRef(2, 1)), const [], 0);
      // Page 2 is 2:1–2:5: half of it rounds to 3 ayat.
      expect(s.target.range, const AyahRange(AyahRef(2, 1), AyahRef(2, 3)));
    });
  });

  group('catch-up', () {
    test('behind on an open-ended plan: all at once vs spread over a week', () {
      final all = _compute(_plan(catchUp: WirdCatchUp.allAtOnce), const [], 2);
      expect(all.target.behind, closeTo(4, 1e-9));
      expect(all.target.range, _pages(1, 6));
      expect(all.days.take(2).map((d) => d.status), [WirdDayStatus.missed, WirdDayStatus.missed]);
      final spread = _compute(_plan(catchUp: WirdCatchUp.spread), const [], 2);
      // 2 + 4/7 = 2.57 pages → ends at the end of page 3.
      expect(spread.target.range, _pages(1, 3));
    });

    // Review finding: the daily share of a small debt (1/7 page) used to be
    // rounded away at the page boundary every day, so a plan missed once and
    // then read faithfully stayed "behind" forever.
    for (final (unit, amount) in [
      (WirdUnit.pages, 1.0),
      (WirdUnit.pages, 2.0),
      (WirdUnit.pages, 5.0),
      (WirdUnit.juz, 1.0),
      (WirdUnit.ayat, 10.0),
      (WirdUnit.pages, 0.5),
    ]) {
      test('spread catch-up clears a missed day ($amount $unit a day)', () {
        final plan = _plan(unit: unit, amount: amount);
        final sessions = <WirdSession>[];
        for (var d = 1; d <= 30; d++) {
          final range = _compute(plan, sessions, d).target.remaining;
          if (range != null) sessions.add(_session(d, range));
        }
        final end = _compute(plan, sessions, 31);
        expect(end.target.behind, lessThan(0.05));
        // Never more than one extra unit a day on top of the plan.
        expect(end.days.skip(1).every((d) => d.quota <= amount + 1 + 1e-9 || amount < 1), isTrue);
      });
    }

    test('behind on a khatma: the rest over the days left, or all at once', () {
      final spread = _compute(_plan(khatmaDays: 30), const [], 10);
      // 604 pages over the 20 days left = 30.2 → 30 pages.
      expect(spread.target.range, _pages(1, 30));
      final all = _compute(_plan(khatmaDays: 30, catchUp: WirdCatchUp.allAtOnce), const [], 10);
      // Eleven days' worth: 604 × 11 / 30 = 221.47 → 221 pages.
      expect(all.target.range, _pages(1, 221));
    });

    test('ahead: all at once rests today, spread lightens it', () {
      final sessions = [_session(0, _pages(1, 6))];
      final all = _compute(_plan(catchUp: WirdCatchUp.allAtOnce), sessions, 1);
      expect(all.target.ahead, closeTo(4, 1e-9));
      expect(all.target.range, isNull);
      expect(all.target.met, isTrue);
      expect(all.days.last.status, WirdDayStatus.rest);
      final spread = _compute(_plan(), sessions, 1);
      // 2 − 4/7 = 1.43 → one page.
      expect(spread.target.range, _pages(7, 7));
    });

    test('an overdue khatma owes everything left', () {
      final s = _compute(_plan(khatmaDays: 3), [_session(0, _pages(1, 100))], 5);
      expect(s.target.range, _pages(101, 604));
    });
  });

  group('sessions', () {
    test('untagged reading counts when it continues from the position', () {
      final plan = _plan(amount: 2);
      final s = _compute(plan, [_session(0, _pages(1, 2), plan: null)], 0);
      expect(s.target.met, isTrue);
      // Reading elsewhere does not move the plan.
      final elsewhere = _compute(plan, [_session(0, _pages(100, 101), plan: null)], 0);
      expect(elsewhere.target.met, isFalse);
      expect(elsewhere.target.done, 0);
      // Another plan's session is not ours.
      final other = _compute(plan, [_session(0, _pages(1, 2), plan: 'other')], 0);
      expect(other.target.met, isFalse);
    });

    test('a tagged session may jump ahead; listening counts too', () {
      final plan = _plan(amount: 2);
      final s = _compute(plan, [_session(0, _pages(10, 11), mode: QuranSessionMode.listen)], 0);
      expect(s.cursor, _catalog.pageStart(12));
      expect(s.target.met, isTrue);
    });

    test('sessions before the start date are ignored', () {
      final s = _compute(_plan(amount: 2), [_session(-1, _pages(1, 2))], 0);
      expect(s.target.done, 0);
    });

    test('an open-ended plan goes round the mushaf', () {
      final plan = _plan(unit: WirdUnit.ayat, amount: 10, start: const AyahRef(114, 1));
      final day0 = _compute(plan, const [], 0);
      expect(day0.target.range, const AyahRange(AyahRef(114, 1), AyahRef(114, 6)));
      final s = _compute(plan, [
        _session(0, const AyahRange(AyahRef(114, 1), AyahRef(114, 6))),
        _session(0, const AyahRange(AyahRef(1, 1), AyahRef(1, 4))),
      ], 0);
      expect(s.khatmas, 1);
      expect(s.cursor, const AyahRef(1, 5));
      expect(s.target.met, isTrue);
    });

    test('a finished khatma', () {
      final plan = _plan(khatmaDays: 2, start: const AyahRef(114, 1));
      final s = _compute(plan, [_session(0, const AyahRange(AyahRef(114, 1), AyahRef(114, 6)))], 1);
      expect(s.completedOn, _day(0));
      expect(s.completed, isTrue);
      expect(s.cursor, isNull);
      expect(s.fraction, 1);
      expect(s.target.met, isTrue);
      expect(s.projectedFinish, _day(0));
    });
  });

  group('history', () {
    test('streaks: missed days break, paused and rest days do not', () {
      final plan = _plan(amount: 1, catchUp: WirdCatchUp.allAtOnce, pauses: [WirdPause(_day(4), _day(4))]);
      final sessions = [
        _session(0, _pages(1, 1)),
        _session(1, _pages(2, 2)),
        // day 2 missed
        _session(3, _pages(3, 5)), // catches up (2 owed) and reads one ahead
        // day 4 paused
        _session(5, _pages(6, 6)), // nothing owed (ahead), read anyway: met
        _session(6, _pages(7, 7)),
        // day 7: nothing owed, nothing read (rest); day 8 today, pending
      ];
      final s = _compute(plan, sessions, 8);
      expect(s.days.map((d) => d.status), [
        WirdDayStatus.met,
        WirdDayStatus.met,
        WirdDayStatus.missed,
        WirdDayStatus.met,
        WirdDayStatus.paused,
        WirdDayStatus.met,
        WirdDayStatus.met,
        WirdDayStatus.rest,
        WirdDayStatus.pending,
      ]);
      expect(s.streak, 3);
      expect(s.bestStreak, 3);
    });

    test('paused days owe nothing', () {
      final plan = _plan(amount: 2, catchUp: WirdCatchUp.allAtOnce, pauses: [WirdPause(_day(0), _day(1))]);
      final s = _compute(plan, const [], 2);
      expect(s.target.range, _pages(1, 2));
      expect(s.days.take(2).every((d) => d.status == WirdDayStatus.paused), isTrue);
    });

    test('an inactive plan is paused today', () {
      final s = _compute(_plan(active: false, pauses: [WirdPause(_day(1))]), const [], 3);
      expect(s.paused, isTrue);
      expect(s.projectedFinish, isNull);
      expect(s.target.range, isNull);
    });

    test('days run across month boundaries', () {
      final plan = _plan(amount: 1, startDate: DateTime(2026, 1, 30));
      final s = WirdEngine.compute(
        plan: plan,
        sessions: const [],
        axis: _axis(WirdUnit.pages),
        today: DateTime(2026, 3, 1),
      );
      // 30 Jan … 1 Mar 2026 = 31 days.
      expect(s.days.length, 31);
      expect(s.days.last.day, DateTime(2026, 3, 1));
      expect(s.dayOf(DateTime(2026, 2, 28))!.status, WirdDayStatus.missed);
    });

    test('a plan that has not started previews its first portion', () {
      final s = _compute(_plan(amount: 2), const [], -3);
      expect(s.started, isFalse);
      expect(s.days, isEmpty);
      expect(s.target.range, _pages(1, 2));
    });
  });

  group('projection', () {
    test('a khatma read on schedule finishes on its target date', () {
      final plan = _plan(khatmaDays: 30);
      final sessions = <WirdSession>[];
      var page = 1;
      for (var d = 0; d < 6; d++) {
        final s = _compute(plan, sessions, d);
        sessions.add(_session(d, s.target.range!));
        page = _catalog.pageOf(s.target.range!.last) + 1;
      }
      final s = _compute(plan, sessions, 5);
      expect(s.target.met, isTrue);
      expect(page, greaterThan(115));
      expect(CalendarDays.between(s.projectedFinish!, plan.targetDate!).abs(), lessThanOrEqualTo(1));
    });

    test('an open-ended plan projects the end of the current round', () {
      final s = _compute(_plan(amount: 4), const [], 0);
      // 604 pages at 4 a day = 151 days, today included.
      expect(s.projectedFinish, _day(150));
    });
  });
}

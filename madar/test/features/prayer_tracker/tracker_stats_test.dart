import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/features/prayer_tracker/domain/tracker_days.dart';
import 'package:madar/features/prayer_tracker/domain/tracker_prayers.dart';
import 'package:madar/features/prayer_tracker/domain/tracker_stats.dart';

var _id = 0;

PrayerLogRow row(
  String day,
  Prayer prayer, [
  PrayerStatus status = PrayerStatus.prayed,
  bool jamaah = false,
  bool mosque = false,
]) {
  final at = DateTime(2026, 1, 1);
  return PrayerLogRow(
    id: 'r${_id++}',
    createdAt: at,
    updatedAt: at,
    day: day,
    prayer: prayer,
    status: status,
    inJamaah: jamaah,
    atMosque: mosque,
    loggedAt: at,
  );
}

/// All five obligatory prayers of [day] as [status].
List<PrayerLogRow> fullDay(String day, [PrayerStatus status = PrayerStatus.prayed]) => [
  for (final p in TrackerPrayers.obligatory) row(day, p, status),
];

DateTime d(int y, int m, int day) => DateTime(y, m, day);

void main() {
  group('TrackerDays', () {
    test('keys round-trip and malformed keys are rejected', () {
      expect(TrackerDays.key(d(2026, 3, 7)), '2026-03-07');
      expect(TrackerDays.parse('2026-03-07'), d(2026, 3, 7));
      expect(TrackerDays.parse('2026-02-31'), isNull, reason: 'overflowing date');
      expect(TrackerDays.parse('2026-13-01'), isNull);
      expect(TrackerDays.parse('07/03/2026'), isNull);
    });

    test('day arithmetic crosses months, years and daylight-saving changes', () {
      expect(TrackerDays.add(d(2026, 1, 31), 1), d(2026, 2, 1));
      expect(TrackerDays.add(d(2026, 3, 1), -1), d(2026, 2, 28));
      expect(TrackerDays.add(d(2024, 3, 1), -1), d(2024, 2, 29), reason: 'leap year');
      expect(TrackerDays.add(d(2026, 12, 31), 1), d(2027, 1, 1));
      // Europe's and the US's spring-forward / fall-back weekends.
      expect(TrackerDays.between(d(2026, 3, 28), d(2026, 3, 30)), 2);
      expect(TrackerDays.between(d(2026, 10, 24), d(2026, 10, 26)), 2);
      expect(TrackerDays.fromOrdinal(TrackerDays.ordinal(d(2026, 3, 29))), d(2026, 3, 29));
      expect(TrackerDays.daysInMonth(2026, 2), 28);
      expect(TrackerDays.daysInMonth(2028, 2), 29);
    });
  });

  group('DaySummary', () {
    test('counts prayed, late, made up, missed, jamaah and sunnah', () {
      final s = DaySummary(
        day: d(2026, 9, 27),
        logs: {
          for (final r in [
            row('2026-09-27', Prayer.fajr, PrayerStatus.prayed, true, true),
            row('2026-09-27', Prayer.dhuhr, PrayerStatus.late, true),
            row('2026-09-27', Prayer.asr, PrayerStatus.qada),
            row('2026-09-27', Prayer.maghrib, PrayerStatus.missed, true),
            row('2026-09-27', Prayer.sunnahFajr),
            row('2026-09-27', Prayer.witr),
            row('2026-09-27', Prayer.duha, PrayerStatus.missed),
          ])
            r.prayer: r,
        },
      );
      expect(s.fardPrayed, 3);
      expect((s.onTime, s.late, s.madeUp, s.missed), (1, 1, 1, 1));
      expect(s.jamaah, 2, reason: 'a missed prayer never counts as jamaah');
      expect(s.mosque, 1);
      expect(s.voluntary, {Prayer.sunnahFajr, Prayer.witr});
      expect(s.complete, isFalse);
      expect(s.completion, 0.6);
      expect(s.jamaahShare, closeTo(2 / 3, 1e-9));
    });

    test('a day of five prayed, late or made-up prayers is complete', () {
      final logs = [
        row('2026-09-27', Prayer.fajr, PrayerStatus.qada),
        row('2026-09-27', Prayer.dhuhr, PrayerStatus.late),
        row('2026-09-27', Prayer.asr),
        row('2026-09-27', Prayer.maghrib),
        row('2026-09-27', Prayer.isha),
      ];
      expect(DaySummary(day: d(2026, 9, 27), logs: {for (final r in logs) r.prayer: r}).complete, isTrue);
    });
  });

  group('TrackerStreaks', () {
    test('no complete day means no streak', () {
      expect(TrackerStreaks.of(const [], today: d(2026, 9, 28)), TrackerStreaks.zero);
    });

    test('runs continue across a month boundary', () {
      final days = [d(2026, 1, 29), d(2026, 1, 30), d(2026, 1, 31), d(2026, 2, 1), d(2026, 2, 2)];
      final s = TrackerStreaks.of(days, today: d(2026, 2, 2));
      expect((s.current, s.best, s.todayComplete), (5, 5, true));
    });

    test('runs continue across a year boundary and a leap day', () {
      final days = [d(2027, 12, 30), d(2027, 12, 31), d(2028, 1, 1), d(2028, 2, 28), d(2028, 2, 29), d(2028, 3, 1)];
      expect(TrackerStreaks.of(days, today: d(2028, 1, 1)).current, 3);
      expect(TrackerStreaks.of(days, today: d(2028, 3, 1)).current, 3);
    });

    test('an unfinished today does not break the streak, a missing yesterday does', () {
      final days = [d(2026, 9, 25), d(2026, 9, 26), d(2026, 9, 27)];
      final underWay = TrackerStreaks.of(days, today: d(2026, 9, 28));
      expect((underWay.current, underWay.todayComplete), (3, false));
      // Two days later with nothing on the 28th: the streak is gone, the
      // best one stays.
      final broken = TrackerStreaks.of(days, today: d(2026, 9, 29));
      expect((broken.current, broken.best), (0, 3));
    });

    test('a missing day in the middle splits the runs; best is the longest', () {
      final days = [
        for (var i = 1; i <= 6; i++) d(2026, 8, i), // six in a row
        for (var i = 8; i <= 10; i++) d(2026, 8, i), // gap on the 7th, then three
      ];
      final s = TrackerStreaks.of(days, today: d(2026, 8, 10));
      expect((s.current, s.best), (3, 6));
    });

    test('streaks come from real logs: a missed prayer breaks the day, qada mends it', () {
      final logs = [
        ...fullDay('2026-09-30'),
        ...fullDay('2026-10-01'),
        ...[
          for (final p in TrackerPrayers.obligatory)
            row('2026-10-02', p, p == Prayer.fajr ? PrayerStatus.missed : PrayerStatus.prayed),
        ],
        ...fullDay('2026-10-03'),
      ];
      final h = TrackerHistory.of(logs, today: d(2026, 10, 3));
      expect((h.streaks.current, h.streaks.best), (1, 2));

      // Made up on a later day, the missed Fajr keeps its day and the day
      // becomes complete: the four days form one run.
      final mended = [
        for (final r in logs)
          if (r.day == '2026-10-02' && r.prayer == Prayer.fajr) r.copyWith(status: PrayerStatus.qada) else r,
      ];
      final h2 = TrackerHistory.of(mended, today: d(2026, 10, 3));
      expect((h2.streaks.current, h2.streaks.best), (4, 4));
    });

    test('voluntary prayers alone never complete a day', () {
      final logs = [
        for (final p in TrackerPrayers.voluntary) row('2026-09-28', p),
        for (final p in TrackerPrayers.obligatory.take(4)) row('2026-09-28', p),
      ];
      expect(TrackerHistory.of(logs, today: d(2026, 9, 28)).streaks.current, 0);
    });
  });

  group('TrackerTotals', () {
    test('shares, per-prayer breakdown and sunnah counts over a span', () {
      final logs = [
        row('2026-09-01', Prayer.fajr, PrayerStatus.prayed, true, true),
        row('2026-09-01', Prayer.dhuhr, PrayerStatus.late, true),
        row('2026-09-01', Prayer.asr, PrayerStatus.missed),
        row('2026-09-02', Prayer.fajr, PrayerStatus.qada),
        row('2026-09-02', Prayer.sunnahFajr),
        row('2026-09-02', Prayer.sunnahIsha),
        row('2026-09-02', Prayer.witr),
        ...fullDay('2026-09-03'),
        row('2026-10-01', Prayer.fajr), // another month
      ];
      final h = TrackerHistory.of(logs, today: d(2026, 10, 1));
      final t = h.month(2026, 9);
      expect(t.days, 30);
      expect((t.loggedDays, t.completeDays), (3, 1));
      expect((t.fardPrayed, t.onTime, t.late, t.madeUp, t.missed), (8, 6, 1, 1, 1));
      expect(t.onTimeShare, closeTo(6 / 8, 1e-9));
      expect(t.jamaahShare, closeTo(2 / 8, 1e-9));
      expect(t.mosqueShare, closeTo(1 / 8, 1e-9));
      expect(t.rawatib, 2);
      expect(t.voluntaryOf(Prayer.witr), 1);
      expect(t.voluntaryOf(Prayer.qiyam), 0);
      final fajr = t.breakdownOf(Prayer.fajr);
      expect((fajr.onTime, fajr.late, fajr.madeUp, fajr.missed), (2, 0, 1, 0));
      expect(t.breakdownOf(Prayer.asr).missed, 1);
      expect(h.month(2026, 8).isEmpty, isTrue);
    });

    test('an empty span has no shares (no division by zero)', () {
      const t = TrackerTotals();
      expect((t.onTimeShare, t.jamaahShare, t.mosqueShare), (0, 0, 0));
    });
  });

  group('QadaLedger', () {
    test('missed obligatory prayers, oldest first and in the order of the day', () {
      final logs = [
        row('2026-09-10', Prayer.isha, PrayerStatus.missed),
        row('2026-09-02', Prayer.maghrib, PrayerStatus.missed),
        row('2026-09-02', Prayer.fajr, PrayerStatus.missed),
        row('2026-09-05', Prayer.asr, PrayerStatus.qada),
        row('2026-09-06', Prayer.dhuhr, PrayerStatus.qada),
        row('2026-09-07', Prayer.witr, PrayerStatus.missed), // voluntary: not owed
        row('2026-09-08', Prayer.dhuhr),
      ];
      final q = QadaLedger.of(logs);
      expect(
        [for (final e in q.outstanding) (TrackerDays.key(e.day), e.prayer)],
        [('2026-09-02', Prayer.fajr), ('2026-09-02', Prayer.maghrib), ('2026-09-10', Prayer.isha)],
      );
      expect(q.madeUp, 2);
      expect(q.filtered(Prayer.isha).single.day, d(2026, 9, 10));
      expect(q.filtered(Prayer.asr), isEmpty);
      expect(q.filtered(null), hasLength(3));
      expect(q.countsByPrayer, {Prayer.fajr: 1, Prayer.dhuhr: 0, Prayer.asr: 0, Prayer.maghrib: 1, Prayer.isha: 1});
    });
  });

  group('TrackerHistory', () {
    test('last seven days end with today, oldest first, empty days included', () {
      final h = TrackerHistory.of([...fullDay('2026-09-26')], today: d(2026, 9, 28));
      final week = h.lastDays(7);
      expect(week.first.day, d(2026, 9, 22));
      expect(week.last.day, d(2026, 9, 28));
      expect(week[4].complete, isTrue);
      expect(week.where((s) => s.isEmpty), hasLength(6));
      expect(h.firstDay, d(2026, 9, 26));
    });

    test('malformed day keys are skipped', () {
      final h = TrackerHistory.of([row('not-a-day', Prayer.fajr), ...fullDay('2026-09-28')], today: d(2026, 9, 28));
      expect(h.days.keys, [d(2026, 9, 28)]);
    });
  });

  group('MonthGrid', () {
    test('September 2026 (starts on a Tuesday) with Saturday or Sunday first', () {
      final sat = MonthGrid.cells(2026, 9, firstDayOfWeek: 6);
      expect(sat.take(3), everyElement(isNull));
      expect(sat[3], d(2026, 9, 1));
      expect(sat.length % 7, 0);
      expect(sat.whereType<DateTime>(), hasLength(30));
      final sun = MonthGrid.cells(2026, 9, firstDayOfWeek: 0);
      expect(sun[2], d(2026, 9, 1));
      expect(MonthGrid.weekdayOrder(6), [6, 0, 1, 2, 3, 4, 5]);
    });

    test('February 2026 starting on a Sunday fills exactly four weeks', () {
      final cells = MonthGrid.cells(2026, 2, firstDayOfWeek: 0);
      expect(cells, hasLength(28));
      expect(cells.first, d(2026, 2, 1));
      expect(cells.last, d(2026, 2, 28));
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/orbit/domain/prayer_schedule.dart';
import 'package:madar/features/prayer/domain/time_zones.dart';
import 'package:madar/features/ramadan/domain/ramadan_calendar.dart';

/// Fixed times: Fajr 05:00, Maghrib 17:00 on every day.
DayTimes _fixed(DateTime d) {
  DateTime at(int h) => DateTime(d.year, d.month, d.day, h);
  return DayTimes(
    day: civilDay(d),
    fajr: at(5),
    sunrise: at(6),
    dhuhr: at(12),
    asr: at(15),
    maghrib: at(17),
    isha: at(19),
  );
}

void main() {
  setUpAll(MadarTimeZones.ensure);

  // 1 Ramadan 1447 = 18 Feb 2026 (Umm al-Qura), as the prayer tests assert.
  final first1447 = DateTime(2026, 2, 18);

  group('month boundary at offset -1 / 0 / +1', () {
    test('offset 0 follows Umm al-Qura exactly', () {
      const c = RamadanCalendar();
      expect(c.dayOfRamadan(DateTime(2026, 2, 17)), isNull);
      expect(c.dayOfRamadan(first1447), 1);
      expect(c.dayOfRamadan(DateTime(2026, 2, 19)), 2);
      expect(c.statusOn(first1447).isFirstDay, isTrue);
    });

    test('offset +1: the local month starts a day earlier', () {
      const c = RamadanCalendar(offsetDays: 1);
      expect(c.dayOfRamadan(DateTime(2026, 2, 16)), isNull);
      expect(c.dayOfRamadan(DateTime(2026, 2, 17)), 1);
      expect(c.isRamadan(DateTime(2026, 2, 17)), isTrue);
    });

    test('offset -1: the local month starts a day later', () {
      const c = RamadanCalendar(offsetDays: -1);
      expect(c.dayOfRamadan(first1447), isNull);
      expect(c.dayOfRamadan(DateTime(2026, 2, 19)), 1);
    });

    test('an offset outside -1..+1 is clamped', () {
      expect(const RamadanCalendar(offsetDays: 2).offsetDays, 1);
      expect(const RamadanCalendar(offsetDays: -5).offsetDays, -1);
    });

    test('the Eid is not Ramadan, at every offset and every year of the table', () {
      for (final off in [-1, 0, 1]) {
        final c = RamadanCalendar(offsetDays: off);
        for (var y = 1447; y <= 1470; y++) {
          final span = c.spanOfYear(y);
          expect(span.hijriYear, y);
          expect(span.length, anyOf(29, 30), reason: 'year $y offset $off');
          // Last day of Ramadan still Ramadan, the next civil day is 1 Shawwal.
          final lastStatus = c.statusOn(span.last);
          expect(lastStatus.isRamadan, isTrue);
          expect(lastStatus.isLastDay, isTrue);
          expect(lastStatus.dayOfRamadan, span.length);
          final eid = c.statusOn(span.eidDay);
          expect(eid.isRamadan, isFalse, reason: '1 Shawwal $y offset $off');
          expect(eid.isEidDay, isTrue);
          expect(eid.atmosphereOn, isFalse);
          expect((eid.hijri.month, eid.hijri.day), (10, 1));
          // The day before the first is Sha'ban, the first is day 1.
          expect(c.dayOfRamadan(addCivilDays(span.first, -1)), isNull);
          expect(c.statusOn(addCivilDays(span.first, -1)).hijri.month, 8);
          expect(c.dayOfRamadan(span.first), 1);
        }
      }
    });
  });

  group('day numbering over whole years', () {
    test('every civil day of 1447-1452 AH agrees with span.dayNumberOf', () {
      for (final off in [-1, 0, 1]) {
        final c = RamadanCalendar(offsetDays: off);
        var d = DateTime(2026, 1, 1);
        final end = DateTime(2031, 12, 31);
        while (!d.isAfter(end)) {
          final n = c.dayOfRamadan(d);
          final span = c.spanContaining(d);
          expect(span?.dayNumberOf(d), n, reason: '$d offset $off');
          expect(span != null, n != null);
          if (n != null) expect(span!.dateOfDay(n), d);
          d = addCivilDays(d, 1);
        }
      }
    });

    test('the span lengths are 29 or 30 and are really that many Ramadan days', () {
      const c = RamadanCalendar();
      for (var y = 1447; y <= 1455; y++) {
        final s = c.spanOfYear(y);
        var count = 0;
        for (var i = -2; i < 33; i++) {
          if (c.isRamadan(addCivilDays(s.first, i))) count++;
        }
        expect(count, s.length, reason: 'year $y');
      }
    });

    test('a leap-day year boundary is not an issue (civil arithmetic)', () {
      expect(civilDaysBetween(DateTime(2028, 2, 28), DateTime(2028, 3, 1)), 2);
      expect(addCivilDays(DateTime(2026, 10, 25), 1), DateTime(2026, 10, 26));
    });
  });

  group('countdown to the next Ramadan', () {
    test('counts the civil days to 1 Ramadan', () {
      const c = RamadanCalendar();
      final next = c.nextSpanAfter(DateTime(2026, 11, 10));
      expect(next.hijriYear, 1448);
      expect(c.daysUntilNextRamadan(DateTime(2026, 11, 10)), civilDaysBetween(DateTime(2026, 11, 10), next.first));
      expect(c.daysUntilNextRamadan(addCivilDays(next.first, -1)), 1);
      expect(c.daysUntilNextRamadan(addCivilDays(next.first, -30)), 30);
    });

    test('on the first day it already counts to the following year', () {
      const c = RamadanCalendar();
      final next = c.nextSpanAfter(DateTime(2026, 11, 10));
      final s = c.statusOn(next.first);
      expect(s.isRamadan, isTrue);
      expect(s.daysUntilNextRamadan, inInclusiveRange(350, 356));
      expect(c.nextSpanOnOrAfter(next.first), next);
    });

    test('the offset shifts the countdown by one day', () {
      final base = const RamadanCalendar().nextSpanAfter(DateTime(2026, 11, 10)).first;
      expect(const RamadanCalendar(offsetDays: 1).nextSpanAfter(DateTime(2026, 11, 10)).first, addCivilDays(base, -1));
      expect(const RamadanCalendar(offsetDays: -1).nextSpanAfter(DateTime(2026, 11, 10)).first, addCivilDays(base, 1));
    });

    test('works from inside Ramadan, from Eid and across a year boundary', () {
      const c = RamadanCalendar();
      final s1447 = c.spanOfYear(1447);
      expect(c.nextSpanAfter(s1447.first).hijriYear, 1448);
      expect(c.nextSpanAfter(s1447.eidDay).hijriYear, 1448);
      expect(c.nextSpanAfter(DateTime(2026, 12, 31)).hijriYear, 1448);
      expect(c.nextSpanOnOrAfter(DateTime(2027, 12, 31)).hijriYear, 1449);
    });

    test('time of day on the input is ignored', () {
      const c = RamadanCalendar();
      expect(c.statusOn(DateTime(2026, 2, 18, 23, 59, 59)).dayOfRamadan, 1);
      expect(c.statusOn(DateTime(2026, 2, 18, 0, 0, 1)).dayOfRamadan, 1);
    });
  });

  group('the app was closed across a boundary', () {
    const c = RamadanCalendar();
    final s = c.spanOfYear(1448);

    test('Ramadan began while closed', () {
      final b = c.boundariesBetween(addCivilDays(s.first, -10), addCivilDays(s.first, 5));
      expect(b.started, isTrue);
      expect(b.eidReached, isFalse);
      // And the state on opening is simply "day 6".
      expect(c.statusOn(addCivilDays(s.first, 5)).dayOfRamadan, 6);
      expect(c.statusOn(addCivilDays(s.first, 5)).atmosphereOn, isTrue);
    });

    test('Eid reached while closed', () {
      final b = c.boundariesBetween(addCivilDays(s.first, 10), addCivilDays(s.eidDay, 2));
      expect(b.started, isFalse);
      expect(b.eidReached, isTrue);
    });

    test('a whole Ramadan passed while closed', () {
      final b = c.boundariesBetween(addCivilDays(s.first, -10), addCivilDays(s.eidDay, 3));
      expect(b.started, isTrue);
      expect(b.eidReached, isTrue);
    });

    test('the edges are inclusive of "now" and exclusive of "lastSeen"', () {
      expect(c.boundariesBetween(addCivilDays(s.first, -1), s.first).started, isTrue);
      expect(c.boundariesBetween(s.first, addCivilDays(s.first, 3)).started, isFalse);
      expect(c.boundariesBetween(s.last, s.eidDay).eidReached, isTrue);
      expect(c.boundariesBetween(s.eidDay, addCivilDays(s.eidDay, 4)).eidReached, isFalse);
    });

    test('nothing crossed on the same day, or when the clock was set backwards', () {
      expect(c.boundariesBetween(s.first, s.first).any, isFalse);
      expect(c.boundariesBetween(addCivilDays(s.first, 5), addCivilDays(s.first, -40)).any, isFalse);
      // After a backwards jump the status is just recomputed from the date.
      expect(c.statusOn(addCivilDays(s.first, -40)).atmosphereOn, isFalse);
    });
  });

  group('the night of Ramadan (night N begins the evening before day N)', () {
    const c = RamadanCalendar();
    final s = c.spanOfYear(1448);

    test('eveningOfNight is the civil date before the day', () {
      expect(s.eveningOfNight(1), addCivilDays(s.first, -1));
      expect(s.eveningOfNight(27), s.dateOfDay(26));
    });

    test('before and after Maghrib, past midnight, and by day', () {
      // Night 1 starts at Maghrib of the last day of Sha'ban.
      final eve = addCivilDays(s.first, -1);
      expect(c.nightAt(DateTime(eve.year, eve.month, eve.day, 16, 59), _fixed), isNull);
      expect(c.nightAt(DateTime(eve.year, eve.month, eve.day, 17), _fixed), 1);
      expect(c.nightAt(DateTime(s.first.year, s.first.month, s.first.day, 1), _fixed), 1);
      expect(c.nightAt(DateTime(s.first.year, s.first.month, s.first.day, 4, 59), _fixed), 1);
      // Fajr of day 1 ends the night; the day is not a night.
      expect(c.nightAt(DateTime(s.first.year, s.first.month, s.first.day, 5), _fixed), isNull);
      expect(c.nightAt(DateTime(s.first.year, s.first.month, s.first.day, 12), _fixed), isNull);
      // Evening of day 26 begins night 27.
      final d26 = s.dateOfDay(26);
      expect(c.nightAt(DateTime(d26.year, d26.month, d26.day, 20), _fixed), 27);
    });

    test('there is no night after the last day (the Eid night)', () {
      final l = s.last;
      expect(c.nightAt(DateTime(l.year, l.month, l.day, 20), _fixed), isNull);
      // The night of the last day began the evening before it.
      final before = addCivilDays(l, -1);
      expect(c.nightAt(DateTime(before.year, before.month, before.day, 20), _fixed), s.length);
    });
  });
}

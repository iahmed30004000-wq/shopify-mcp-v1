// Where Ramadan stands at a given moment: the day, the first evening's night 1,
// the night to log, the countdown's target, the last ten, the 30 days before -
// pure, against fixed prayer times (Fajr 05:30, Maghrib 17:20, Isha 18:45).
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/ramadan/ramadan.dart';

import 'ramadan_test_support.dart';

void main() {
  const calendar = RamadanCalendar();

  RamadanToday at(DateTime now, {RamadanCalendar cal = calendar}) =>
      RamadanToday.compute(now: now, calendar: cal, timesOf: fixedTimes);

  group('inside Ramadan 1448 (8 February to 8 March 2027, 29 days)', () {
    test('by day: the day number, tonight is the next night, the countdown is to iftar', () {
      final t = at(DateTime(2027, 2, 20, 12)); // day 13
      expect(t.inRamadan, isTrue);
      expect(t.dayOfRamadan, 13);
      expect(t.headlineNumber, 13);
      expect(t.hijriYear, 1448);
      expect(t.monthLength, 29);
      expect(t.nightNow, isNull);
      expect(t.tonight, 14);
      expect(t.countdown.phase, FastPhase.fasting);
      expect(t.countdown.target, FastTarget.iftar);
      expect(t.countdown.at, DateTime(2027, 2, 20, 17, 20));
      expect(t.countdown.remaining, const Duration(hours: 5, minutes: 20));
      expect(t.comingSoon, isFalse);
      expect(t.status.atmosphereOn, isTrue);
    });

    test('after Maghrib it is the night: tonight is that night, the countdown is to the end of suhoor', () {
      final t = at(DateTime(2027, 2, 20, 19)); // evening of day 13: night 14 has begun
      expect(t.nightNow, 14);
      expect(t.tonight, 14);
      expect(t.countdown.target, FastTarget.suhoorEnd);
      expect(t.countdown.at, DateTime(2027, 2, 21, 5, 30));
      // After midnight it is still night 14 (the Islamic night runs to Fajr).
      final late = at(DateTime(2027, 2, 21, 2));
      expect(late.nightNow, 14);
      expect(late.dayOfRamadan, 14, reason: 'the calendar day has turned');
      expect(late.tonight, 14);
    });

    test('the first evening: night 1 is Ramadan\'s, though the calendar day is not yet', () {
      final day = at(DateTime(2027, 2, 7, 12));
      expect(day.inRamadan, isFalse);
      expect(day.comingSoon, isTrue);
      expect(day.daysUntilRamadan, 1);
      expect(day.tonight, 1, reason: 'the Taraweeh of tonight is night 1');
      final evening = at(DateTime(2027, 2, 7, 20));
      expect(evening.inRamadan, isTrue);
      expect(evening.dayOfRamadan, isNull);
      expect(evening.nightNow, 1);
      expect(evening.headlineNumber, 1);
      expect(evening.hijriYear, 1448);
      expect(evening.status.atmosphereOn, isFalse, reason: 'the atmosphere starts with the first day');
      expect(evening.countdown.target, FastTarget.suhoorEnd);
      expect(evening.countdown.at, DateTime(2027, 2, 8, 5, 30));
    });

    test('last ten tonight exactly when tonight is night 21 or later', () {
      // Day 19 (26 Feb): tonight is night 20.
      expect(at(DateTime(2027, 2, 26, 12)).tonight, 20);
      expect(at(DateTime(2027, 2, 26, 12)).lastTenTonight, isFalse);
      // Day 20 (27 Feb): tonight is night 21, the first of the last ten.
      expect(at(DateTime(2027, 2, 27, 12)).tonight, 21);
      expect(at(DateTime(2027, 2, 27, 12)).lastTenTonight, isTrue);
      // Day 28 (7 March): tonight is night 29, the last.
      expect(at(DateTime(2027, 3, 7, 12)).tonight, 29);
      expect(at(DateTime(2027, 3, 7, 12)).lastTenTonight, isTrue);
    });

    test('the last day: after the last iftar the countdown is idle, and no night follows in a 29-day month', () {
      final lastDay = at(DateTime(2027, 3, 8, 19)); // 29 Ramadan, after Maghrib
      expect(lastDay.inRamadan, isTrue);
      expect(lastDay.dayOfRamadan, 29);
      expect(lastDay.countdown.phase, FastPhase.idle);
      expect(lastDay.tonight, isNull, reason: 'the evening of 29 Ramadan begins the Eid, no night 30 here');
      expect(lastDay.lastTenTonight, isFalse);
    });

    test('1 Shawwal is the Eid: not Ramadan, no atmosphere, no card', () {
      final eid = at(DateTime(2027, 3, 9, 12));
      expect(eid.inRamadan, isFalse);
      expect(eid.status.isEidDay, isTrue);
      expect(eid.status.atmosphereOn, isFalse);
      expect(eid.comingSoon, isFalse);
      expect(eid.countdown.phase, FastPhase.idle);
    });
  });

  group('before and long after', () {
    test('the countdown to Ramadan shows in the last 30 days and not before', () {
      expect(at(DateTime(2027, 1, 9, 12)).daysUntilRamadan, 30);
      expect(at(DateTime(2027, 1, 9, 12)).comingSoon, isTrue);
      expect(at(DateTime(2027, 1, 8, 12)).daysUntilRamadan, 31);
      expect(at(DateTime(2027, 1, 8, 12)).comingSoon, isFalse);
      expect(at(DateTime(2026, 11, 10, 12)).comingSoon, isFalse);
      expect(at(DateTime(2026, 11, 10, 12)).inRamadan, isFalse);
    });

    test('after the Eid the next Ramadan is a year away: no card until its last 30 days', () {
      final t = at(DateTime(2027, 4, 1, 12));
      expect(t.comingSoon, isFalse);
      expect(t.daysUntilRamadan, greaterThan(300));
    });
  });

  group('the Hijri shift', () {
    test('the same civil day under -1, 0 and +1: 8 February 2027 at noon', () {
      expect(at(DateTime(2027, 2, 8, 12), cal: const RamadanCalendar(offsetDays: -1)).inRamadan, isFalse);
      expect(at(DateTime(2027, 2, 8, 12), cal: const RamadanCalendar(offsetDays: -1)).daysUntilRamadan, 1);
      expect(at(DateTime(2027, 2, 8, 12)).dayOfRamadan, 1);
      expect(at(DateTime(2027, 2, 8, 12), cal: const RamadanCalendar(offsetDays: 1)).dayOfRamadan, 2);
    });

    test('the atmosphere is off on 1 Shawwal under every shift, and on the day before it', () {
      for (final offset in [-1, 0, 1]) {
        final cal = RamadanCalendar(offsetDays: offset);
        final span = cal.spanOfYear(1448);
        expect(cal.statusOn(span.last).atmosphereOn, isTrue, reason: 'offset $offset: the last day');
        expect(cal.statusOn(span.eidDay).atmosphereOn, isFalse, reason: 'offset $offset: 1 Shawwal');
        expect(cal.statusOn(span.first).atmosphereOn, isTrue, reason: 'offset $offset: the first day');
        expect(cal.statusOn(span.dateOfDay(0)).atmosphereOn, isFalse, reason: 'offset $offset: the day before');
      }
    });
  });
}

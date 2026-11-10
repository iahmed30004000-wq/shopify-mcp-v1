import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/orbit/domain/prayer_schedule.dart';
import 'package:madar/features/prayer/domain/time_zones.dart';
import 'package:madar/features/ramadan/domain/fast_countdown.dart';
import 'package:madar/features/ramadan/domain/ramadan_calendar.dart';
import 'package:timezone/timezone.dart' as tz;

void main() {
  late tz.Location amman;
  late PrayerSchedule schedule;
  const calendar = RamadanCalendar();
  late RamadanSpan span;

  setUpAll(() {
    MadarTimeZones.ensure();
    amman = tz.getLocation('Asia/Amman');
    schedule = PrayerSchedule(const PrayerSettings(timeZone: 'Asia/Amman'));
    span = calendar.spanOfYear(1448);
  });

  tz.TZDateTime at(DateTime day, int h, [int m = 0, int s = 0]) =>
      tz.TZDateTime(amman, day.year, day.month, day.day, h, m, s);

  FastCountdown countdown(DateTime now, {RamadanCalendar cal = calendar}) =>
      FastCountdown.compute(now: now, timesOf: schedule.timesFor, calendar: cal);

  group('against the Amman schedule', () {
    test('by day: counts down to the Maghrib of the same day, to the minute', () {
      final day = span.dateOfDay(5);
      final t = schedule.timesFor(day);
      final now = at(day, 11, 30);
      final c = countdown(now);
      expect(c.phase, FastPhase.fasting);
      expect(c.target, FastTarget.iftar);
      expect(c.at, t.maghrib);
      expect(c.remaining, t.maghrib.difference(now));
      expect(c.dayOfRamadan, 5);
      // Maghrib in Amman in February is in the 17:00 hour.
      expect(schedule.wallClock(c.at!).hour, inInclusiveRange(16, 18));
    });

    test('across Fajr: one second before is suhoor, Fajr itself is the fast', () {
      final day = span.dateOfDay(7);
      final t = schedule.timesFor(day);
      final before = countdown(t.fajr.subtract(const Duration(seconds: 1)));
      expect(before.phase, FastPhase.suhoorNight);
      expect(before.target, FastTarget.suhoorEnd);
      expect(before.at, t.fajr);
      expect(before.remaining, const Duration(seconds: 1));
      expect(before.dayOfRamadan, 7);
      final exactly = countdown(t.fajr);
      expect(exactly.phase, FastPhase.fasting);
      expect(exactly.target, FastTarget.iftar);
      expect(exactly.remaining, t.maghrib.difference(t.fajr));
    });

    test('across Maghrib: the iftar moment turns the countdown to the next Fajr', () {
      final day = span.dateOfDay(7);
      final t = schedule.timesFor(day);
      final next = schedule.timesFor(span.dateOfDay(8));
      final justBefore = countdown(t.maghrib.subtract(const Duration(minutes: 1)));
      expect(justBefore.target, FastTarget.iftar);
      expect(justBefore.remaining, const Duration(minutes: 1));
      final exactly = countdown(t.maghrib);
      expect(exactly.phase, FastPhase.suhoorNight);
      expect(exactly.at, next.fajr);
      expect(exactly.remaining, next.fajr.difference(t.maghrib));
      expect(exactly.dayOfRamadan, 8);
    });

    test('across midnight: the same Fajr, one minute apart', () {
      final day = span.dateOfDay(10);
      final nextDay = span.dateOfDay(11);
      final a = countdown(at(day, 23, 59, 30));
      final b = countdown(at(nextDay, 0, 0, 30));
      expect(a.phase, FastPhase.suhoorNight);
      expect(b.phase, FastPhase.suhoorNight);
      expect(a.at, b.at);
      expect(a.at, schedule.timesFor(nextDay).fajr);
      expect(a.remaining - b.remaining, const Duration(minutes: 1));
      expect(b.dayOfRamadan, 11);
    });

    test('the night before the first day counts down to the first suhoor', () {
      final eve = addCivilDays(span.first, -1);
      final firstFajr = schedule.timesFor(span.first).fajr;
      final afterMaghrib = at(eve, 21);
      final c = countdown(afterMaghrib);
      expect(c.phase, FastPhase.suhoorNight);
      expect(c.at, firstFajr);
      expect(c.dayOfRamadan, 1);
      // By day on that same eve nothing is counting yet.
      expect(countdown(at(eve, 10)).phase, FastPhase.idle);
      expect(countdown(at(eve, 10)), FastCountdown.idle);
      // The very Maghrib starts it.
      expect(countdown(schedule.timesFor(eve).maghrib).phase, FastPhase.suhoorNight);
    });

    test('after the last iftar there is nothing to count; Eid day is idle', () {
      final afterLastIftar = at(span.last, 20);
      expect(countdown(afterLastIftar).phase, FastPhase.idle);
      expect(countdown(at(span.eidDay, 6)).phase, FastPhase.idle);
      expect(countdown(at(span.eidDay, 12)).remaining, Duration.zero);
      // But the last day itself still has its iftar.
      expect(countdown(at(span.last, 10)).phase, FastPhase.fasting);
      // And the night leading into the last day counts to its Fajr.
      expect(countdown(at(addCivilDays(span.last, -1), 22)).dayOfRamadan, span.length);
    });

    test('outside Ramadan the countdown is idle', () {
      expect(countdown(DateTime(2026, 11, 10, 12)).phase, FastPhase.idle);
      expect(countdown(DateTime(2027, 6, 1, 3)).phase, FastPhase.idle);
    });

    test('the Hijri offset moves which days count', () {
      // With +1 the first fast starts a day earlier.
      const plus = RamadanCalendar(offsetDays: 1);
      final day = addCivilDays(span.first, -1);
      expect(countdown(at(day, 10), cal: plus).phase, FastPhase.fasting);
      expect(countdown(at(day, 10)).phase, FastPhase.idle);
      const minus = RamadanCalendar(offsetDays: -1);
      expect(countdown(at(span.first, 10), cal: minus).phase, FastPhase.idle);
    });

    test('every minute of a full Ramadan day-night is consistent', () {
      final day = span.dateOfDay(12);
      final t = schedule.timesFor(day);
      for (var m = 0; m < 24 * 60; m += 7) {
        final now = at(day, 0).add(Duration(minutes: m));
        final c = countdown(now);
        expect(c.phase, isNot(FastPhase.idle), reason: '$now');
        expect(c.remaining, greaterThanOrEqualTo(Duration.zero), reason: '$now');
        if (!now.isBefore(t.fajr) && now.isBefore(t.maghrib)) {
          expect(c.target, FastTarget.iftar);
        } else {
          expect(c.target, FastTarget.suhoorEnd);
        }
        expect(c.at!.difference(now), c.remaining);
      }
    });
  });

  group('a traveller: the times are an input, nothing is remembered', () {
    test('new times give a new answer and the old ones the old answer again', () {
      final day = span.dateOfDay(9);
      final home = schedule.timesFor;
      DayTimes shifted(DateTime d) {
        final t = schedule.timesFor(d);
        const by = Duration(hours: 3);
        return DayTimes(
          day: t.day,
          fajr: t.fajr.add(by),
          sunrise: t.sunrise.add(by),
          dhuhr: t.dhuhr.add(by),
          asr: t.asr.add(by),
          maghrib: t.maghrib.add(by),
          isha: t.isha.add(by),
        );
      }

      final now = at(day, 16, 30);
      final a = FastCountdown.compute(now: now, timesOf: home, calendar: calendar);
      final b = FastCountdown.compute(now: now, timesOf: shifted, calendar: calendar);
      final a2 = FastCountdown.compute(now: now, timesOf: home, calendar: calendar);
      expect(b.remaining - a.remaining, const Duration(hours: 3));
      expect(a2, a);
      expect(a.target, FastTarget.iftar);
    });

    test('a move that makes iftar come hours earlier is simply a smaller number', () {
      final day = span.dateOfDay(9);
      DayTimes earlier(DateTime d) {
        final t = schedule.timesFor(d);
        const by = Duration(hours: -4);
        return DayTimes(
          day: t.day,
          fajr: t.fajr.add(by),
          sunrise: t.sunrise.add(by),
          dhuhr: t.dhuhr.add(by),
          asr: t.asr.add(by),
          maghrib: t.maghrib.add(by),
          isha: t.isha.add(by),
        );
      }

      final now = at(day, 14);
      final home = FastCountdown.compute(now: now, timesOf: schedule.timesFor, calendar: calendar);
      final away = FastCountdown.compute(now: now, timesOf: earlier, calendar: calendar);
      expect(home.remaining - away.remaining, const Duration(hours: 4));
    });
  });

  group('daylight-saving change in Amman (Jordan observed it until 2022)', () {
    // The countdown is a difference of instants, so a clock change between
    // now and the target is counted automatically. Jordan has no DST today,
    // so the test feeds the zone's historic change with every day a fast day.
    DayTimes dayTimes(DateTime d) {
      tz.TZDateTime h(int hour) => tz.TZDateTime(amman, d.year, d.month, d.day, hour);
      return DayTimes(
        day: civilDay(d),
        fajr: h(5),
        sunrise: h(6),
        dhuhr: h(12),
        asr: h(15),
        maghrib: h(16),
        isha: h(18),
      );
    }

    int? always(DateTime _) => 1;

    test('autumn: clocks go back overnight, the night is an hour longer', () {
      final before = tz.TZDateTime(amman, 2021, 10, 28, 22);
      final after = tz.TZDateTime(amman, 2021, 10, 29, 12);
      expect(before.timeZoneOffset, isNot(after.timeZoneOffset), reason: 'the tz data must carry the 2021 change');
      final c = FastCountdown.of(now: before, timesOf: dayTimes, fastDayOf: always);
      expect(c.phase, FastPhase.suhoorNight);
      expect(c.at, dayTimes(DateTime(2021, 10, 29)).fajr);
      // 22:00 -> 05:00 on the wall is 7 hours; the real time is 8.
      expect(c.remaining, const Duration(hours: 8));
    });

    test('spring: clocks go forward overnight, the night is an hour shorter', () {
      final before = tz.TZDateTime(amman, 2021, 3, 25, 22);
      final after = tz.TZDateTime(amman, 2021, 3, 26, 12);
      expect(before.timeZoneOffset, isNot(after.timeZoneOffset));
      final c = FastCountdown.of(now: before, timesOf: dayTimes, fastDayOf: always);
      expect(c.remaining, const Duration(hours: 6));
    });

    test('the fasting day itself keeps its own length', () {
      final now = tz.TZDateTime(amman, 2021, 10, 29, 6);
      final c = FastCountdown.of(now: now, timesOf: dayTimes, fastDayOf: always);
      expect(c.phase, FastPhase.fasting);
      expect(c.remaining, const Duration(hours: 10));
    });
  });

  group('ramadanDayTimes', () {
    test('one row per day with the schedule\'s Fajr and Maghrib', () {
      final rows = ramadanDayTimes(span, schedule.timesFor);
      expect(rows, hasLength(span.length));
      expect(rows.first.dayOfRamadan, 1);
      expect(rows.last.dayOfRamadan, span.length);
      expect(rows.first.date, span.first);
      expect(rows[2].suhoorEnd, schedule.timesFor(span.dateOfDay(3)).fajr);
      expect(rows[2].iftar, schedule.timesFor(span.dateOfDay(3)).maghrib);
      for (final r in rows) {
        expect(r.suhoorEnd.isBefore(r.iftar), isTrue);
      }
    });
  });
}

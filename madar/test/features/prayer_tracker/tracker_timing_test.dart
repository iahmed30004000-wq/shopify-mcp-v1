import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/features/orbit/domain/prayer_schedule.dart';
import 'package:madar/features/prayer_tracker/domain/tracker_day.dart';
import 'package:madar/features/prayer_tracker/domain/tracker_days.dart';
import 'package:madar/features/prayer_tracker/domain/tracker_prayers.dart';
import 'package:madar/features/prayer_tracker/domain/tracker_timing.dart';

import 'tracker_fixtures.dart';

DayTimes times(DateTime day, {int fajr = 5 * 60 + 6, int sunrise = 6 * 60 + 28}) {
  DateTime at(int minutes) => DateTime(day.year, day.month, day.day).add(Duration(minutes: minutes));
  return DayTimes(
    day: day,
    fajr: at(fajr),
    sunrise: at(sunrise),
    dhuhr: at(12 * 60 + 27),
    asr: at(15 * 60 + 51),
    maghrib: at(18 * 60 + 31),
    isha: at(19 * 60 + 47),
  );
}

PrayerLogRow log(DateTime day, Prayer prayer, PrayerStatus status, {bool jamaah = false}) => PrayerLogRow(
  id: '${prayer.name}-${status.name}',
  createdAt: day,
  updatedAt: day,
  day: TrackerDays.key(day),
  prayer: prayer,
  status: status,
  inJamaah: jamaah,
  atMosque: false,
  loggedAt: day,
);

void main() {
  final day = DateTime(2026, 9, 28);
  final today = times(day);
  final tomorrow = times(DateTime(2026, 9, 29), fajr: 5 * 60 + 7);

  group('sunnah grouping', () {
    test('each fard has its rawatib (Asr none), twelve rak\'ahs a day', () {
      expect(TrackerPrayers.groups.map((g) => (g.fard, g.sunnah)), [
        (Prayer.fajr, Prayer.sunnahFajr),
        (Prayer.dhuhr, Prayer.sunnahDhuhr),
        (Prayer.asr, null),
        (Prayer.maghrib, Prayer.sunnahMaghrib),
        (Prayer.isha, Prayer.sunnahIsha),
      ]);
      for (final s in TrackerPrayers.rawatib) {
        expect(TrackerPrayers.sunnahOf(TrackerPrayers.fardOf(s)!), s);
      }
      expect(TrackerPrayers.rakahOf(Prayer.sunnahFajr), (before: 2, after: 0));
      expect(TrackerPrayers.rakahOf(Prayer.sunnahDhuhr), (before: 4, after: 2));
      expect(TrackerPrayers.rakahOf(Prayer.sunnahMaghrib), (before: 0, after: 2));
      expect(TrackerPrayers.rakahOf(Prayer.sunnahIsha), (before: 0, after: 2));
      final total = TrackerPrayers.rawatib.fold(0, (sum, p) {
        final r = TrackerPrayers.rakahOf(p)!;
        return sum + r.before + r.after;
      });
      expect(total, 12);
      expect(TrackerPrayers.rakahOf(Prayer.witr), isNull);
      expect(TrackerPrayers.voluntary.toSet().intersection(TrackerPrayers.obligatory.toSet()), isEmpty);
      expect({...TrackerPrayers.obligatory, ...TrackerPrayers.voluntary}, Prayer.values.toSet());
    });

    test('the tap cycle', () {
      expect(StatusCycle.next(null), PrayerStatus.prayed);
      expect(StatusCycle.next(PrayerStatus.prayed), PrayerStatus.late);
      expect(StatusCycle.next(PrayerStatus.late), PrayerStatus.missed);
      expect(StatusCycle.next(PrayerStatus.missed), isNull);
      expect(StatusCycle.next(PrayerStatus.qada), PrayerStatus.missed);
    });
  });

  group('windows', () {
    test('each prayer\'s window within the prayer day', () {
      SlotWindow w(Prayer p) => TrackerTiming.windowOf(p, today, tomorrow);
      expect(w(Prayer.fajr), SlotWindow(today.fajr, today.sunrise));
      expect(w(Prayer.sunnahFajr), SlotWindow(today.fajr, today.sunrise));
      expect(w(Prayer.duha), SlotWindow(today.sunrise.add(const Duration(minutes: 15)), today.dhuhr));
      expect(w(Prayer.dhuhr), SlotWindow(today.dhuhr, today.asr));
      expect(w(Prayer.sunnahDhuhr), SlotWindow(today.dhuhr, today.asr));
      expect(w(Prayer.asr), SlotWindow(today.asr, today.maghrib));
      expect(w(Prayer.maghrib), SlotWindow(today.maghrib, today.isha));
      expect(w(Prayer.sunnahMaghrib), SlotWindow(today.maghrib, today.isha));
      for (final p in [Prayer.isha, Prayer.sunnahIsha, Prayer.witr, Prayer.qiyam]) {
        expect(w(p), SlotWindow(today.isha, tomorrow.fajr), reason: '$p runs until the next Fajr');
      }
    });

    test('"not yet due" flips exactly at the window start and closes at its end', () {
      final w = TrackerTiming.windowOf(Prayer.asr, today, tomorrow);
      const second = Duration(seconds: 1);
      expect(w.at(today.asr.subtract(second)), SlotTiming.upcoming);
      expect(w.at(today.asr), SlotTiming.open);
      expect(w.at(today.maghrib.subtract(second)), SlotTiming.open);
      expect(w.at(today.maghrib), SlotTiming.closed);
      expect(w.untilStart(today.asr.subtract(const Duration(minutes: 10))), const Duration(minutes: 10));
      expect(w.untilStart(today.asr), Duration.zero);
      expect(w.untilEnd(today.maghrib.add(second)), Duration.zero);
    });

    test('Duha is not due at sunrise, only a quarter of an hour later', () {
      final w = TrackerTiming.windowOf(Prayer.duha, today, tomorrow);
      expect(w.at(today.sunrise), SlotTiming.upcoming);
      expect(w.at(today.sunrise.add(const Duration(minutes: 14, seconds: 59))), SlotTiming.upcoming);
      expect(w.at(today.sunrise.add(const Duration(minutes: 15))), SlotTiming.open);
    });

    test('after midnight Isha, Witr and Qiyam are still open until Fajr', () {
      final night = DateTime(2026, 9, 29, 2, 30);
      final view = TrackerDayView.build(day: day, now: night, times: today, nextDay: tomorrow, logs: const []);
      expect(view[Prayer.isha].timing, SlotTiming.open);
      expect(view[Prayer.witr].timing, SlotTiming.open);
      expect(view[Prayer.qiyam].isDue, isFalse, reason: 'voluntary prayers are open, never "due"');
      expect(view[Prayer.qiyam].canLog, isTrue);
      expect(view[Prayer.maghrib].timing, SlotTiming.closed);
      final dawn = TrackerDayView.build(day: day, now: tomorrow.fajr, times: today, nextDay: tomorrow, logs: const []);
      expect(dawn[Prayer.witr].timing, SlotTiming.closed);
    });
  });

  group('TrackerDayView', () {
    test('mid-afternoon: three prayers due or past, two upcoming', () {
      final now = today.asr.add(const Duration(minutes: 20));
      final view = TrackerDayView.build(
        day: day,
        now: now,
        times: today,
        nextDay: tomorrow,
        logs: [
          log(day, Prayer.fajr, PrayerStatus.prayed, jamaah: true),
          log(day, Prayer.dhuhr, PrayerStatus.late),
          log(day, Prayer.sunnahDhuhr, PrayerStatus.prayed),
        ],
      );
      expect(
        [for (final s in view.obligatory) s.timing],
        [SlotTiming.closed, SlotTiming.closed, SlotTiming.open, SlotTiming.upcoming, SlotTiming.upcoming],
      );
      expect([for (final s in view.obligatory) s.canLog], [true, true, true, false, false]);
      expect(view[Prayer.asr].isDue, isTrue);
      expect(view[Prayer.fajr].unloggedPast, isFalse);
      expect(view.prayedCount, 2);
      expect(view.onTimeCount, 1);
      expect(view.jamaahCount, 1);
      expect(view.voluntaryCount, 1);
      expect(view.complete, isFalse);
      expect(view.current?.prayer, Prayer.asr);
      expect(view.nextUpcoming?.prayer, Prayer.maghrib);
      expect(view[Prayer.sunnahMaghrib].canLog, isFalse);
      expect(view[Prayer.duha].timing, SlotTiming.closed);
    });

    test('a closed prayer without a log reads as unlogged, not missed', () {
      final view = TrackerDayView.build(day: day, now: today.maghrib, times: today, nextDay: tomorrow, logs: const []);
      expect(view[Prayer.asr].unloggedPast, isTrue);
      expect(view[Prayer.asr].status, isNull);
      expect(view[Prayer.maghrib].isDue, isTrue);
    });

    test('a past day has every prayer loggable; all five prayed completes it', () {
      final later = DateTime(2026, 10, 3, 9);
      final view = TrackerDayView.build(
        day: day,
        now: later,
        times: today,
        nextDay: tomorrow,
        logs: [
          for (final p in TrackerPrayers.obligatory)
            log(day, p, p == Prayer.isha ? PrayerStatus.qada : PrayerStatus.prayed),
        ],
      );
      expect(view.slots.values.every((s) => s.canLog), isTrue);
      expect(view.complete, isTrue);
      expect(view.nextUpcoming, isNull);
    });

    test('the real schedule: before Fajr the prayer day is still yesterday', () {
      final schedule = hostSchedule();
      final t = schedule.timesFor(day);
      expect(schedule.prayerDayOf(t.fajr.subtract(const Duration(minutes: 1))), DateTime(2026, 9, 27));
      expect(schedule.prayerDayOf(t.fajr), day);
      final view = TrackerDayView.build(
        day: day,
        now: t.dhuhr.subtract(const Duration(seconds: 1)),
        times: t,
        nextDay: schedule.timesFor(DateTime(2026, 9, 29)),
        logs: const [],
      );
      expect(view[Prayer.dhuhr].timing, SlotTiming.upcoming);
      expect(view[Prayer.duha].timing, SlotTiming.open);
    });
  });
}

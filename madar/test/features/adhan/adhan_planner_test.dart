import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/notifications/notification_models.dart';
import 'package:madar/features/adhan/domain/adhan_plan.dart';
import 'package:madar/features/adhan/domain/adhan_settings.dart';
import 'package:madar/features/adhan/domain/adhan_slot.dart';
import 'package:madar/features/adhan/domain/adhan_sound.dart';
import 'package:timezone/timezone.dart' as tz;

import 'adhan_fixtures.dart';

void main() {
  late tz.Location amman;
  const planner = AdhanPlanner();

  setUpAll(() => amman = zone('Asia/Amman'));

  List<AdhanAlarm> plan(
    AdhanSettings settings,
    DateTime now, {
    tz.Location? location,
    tz.Location? device,
    AdhanPlanner p = planner,
  }) => p.plan(
    settings: settings,
    now: now,
    timesFor: wallClockTimes(location ?? amman),
    localDayOf: localDayIn(device ?? location ?? amman),
  );

  group('the next days', () {
    test('every adhan from now on for eight days, soonest first', () {
      final now = wall(amman, 2026, 9, 28, 13, 0); // after Dhuhr
      final alarms = plan(const AdhanSettings(), now);
      expect(alarms.first.slot, AdhanSlot.asr);
      expect(alarms.first.at, wall(amman, 2026, 9, 28, 15, 50));
      expect(alarms.every((a) => a.kind == AdhanKind.adhan), isTrue);
      expect(alarms.every((a) => a.at.isAfter(now)), isTrue);
      expect(alarms.every((a) => !a.at.isAfter(now.add(const Duration(days: 8)))), isTrue);
      // Today's Asr, Maghrib, Isha + 7 whole days + Fajr and Dhuhr of day 8
      // (until 13:00).
      expect(alarms, hasLength(3 + 7 * 5 + 2));
      for (var i = 1; i < alarms.length; i++) {
        expect(alarms[i].at.isAfter(alarms[i - 1].at), isTrue);
      }
      // Covers a whole week without opening the app.
      expect(alarms.last.at.difference(now), greaterThan(const Duration(days: 7)));
    });

    test('each alarm carries its prayer day and sound (Fajr its own)', () {
      final now = wall(amman, 2026, 9, 28, 3, 0);
      final alarms = plan(const AdhanSettings(), now);
      final fajr = alarms.firstWhere((a) => a.slot == AdhanSlot.fajr);
      expect(fajr.day, DateTime.utc(2026, 9, 28));
      expect(fajr.sound, const AdhanSoundRef.tone(TanbihTone.dawn));
      expect(alarms.firstWhere((a) => a.slot == AdhanSlot.isha).sound, const AdhanSoundRef.tone(TanbihTone.brass));
      expect(fajr.prayerAt, fajr.at);
    });

    test('disabled prayers are skipped', () {
      final settings = const AdhanSettings()
          .withAlert(AdhanSlot.asr, const PrayerAlert(adhan: false))
          .withAlert(AdhanSlot.isha, const PrayerAlert(adhan: false));
      final alarms = plan(settings, wall(amman, 2026, 9, 28, 1));
      expect(alarms.where((a) => a.slot == AdhanSlot.asr || a.slot == AdhanSlot.isha), isEmpty);
      expect(alarms.map((a) => a.slot).toSet(), {AdhanSlot.fajr, AdhanSlot.dhuhr, AdhanSlot.maghrib});
    });

    test('nothing enabled → nothing planned', () {
      var s = const AdhanSettings();
      for (final slot in AdhanSlot.prayers) {
        s = s.withAlert(slot, const PrayerAlert(adhan: false));
      }
      expect(s.anyEnabled, isFalse);
      expect(plan(s, wall(amman, 2026, 9, 28, 1)), isEmpty);
    });
  });

  group('reminders and sunrise', () {
    test('a reminder N minutes before, only while still ahead', () {
      final settings = const AdhanSettings().withAlert(AdhanSlot.maghrib, const PrayerAlert(preMinutes: 15));
      final at1810 = wall(amman, 2026, 9, 28, 18, 10);
      final alarms = plan(settings, at1810);
      final pre = alarms.where((a) => a.kind == AdhanKind.preAdhan).toList();
      expect(pre.first.at, wall(amman, 2026, 9, 28, 18, 15));
      expect(pre.first.prayerAt, wall(amman, 2026, 9, 28, 18, 30));
      expect(pre.first.minutesBefore, 15);
      expect(pre.first.sound, isNull);
      // At 18:20 today's reminder has passed, the adhan has not.
      final later = plan(settings, wall(amman, 2026, 9, 28, 18, 20));
      expect(later.first.kind, AdhanKind.adhan);
      expect(later.first.slot, AdhanSlot.maghrib);
      expect(later.where((a) => a.kind == AdhanKind.preAdhan).first.day, DateTime.utc(2026, 9, 29));
    });

    test('a reminder without the adhan is still planned', () {
      final settings = const AdhanSettings().withAlert(
        AdhanSlot.dhuhr,
        const PrayerAlert(adhan: false, preMinutes: 10),
      );
      final alarms = plan(settings, wall(amman, 2026, 9, 28, 1));
      expect(alarms.where((a) => a.slot == AdhanSlot.dhuhr).map((a) => a.kind).toSet(), {AdhanKind.preAdhan});
    });

    test('sunrise alert, optionally before sunrise', () {
      final settings = const AdhanSettings(sunriseAlert: true, sunriseMinutesBefore: 20);
      final alarms = plan(settings, wall(amman, 2026, 9, 28, 1));
      final s = alarms.firstWhere((a) => a.kind == AdhanKind.sunrise);
      expect(s.at, wall(amman, 2026, 9, 28, 5, 50));
      expect(s.prayerAt, wall(amman, 2026, 9, 28, 6, 10));
      expect(s.slot, AdhanSlot.sunrise);
      expect(
        plan(const AdhanSettings(), wall(amman, 2026, 9, 28, 1)).where((a) => a.kind == AdhanKind.sunrise),
        isEmpty,
      );
    });
  });

  group('ids', () {
    test('unique, inside the adhan namespace, stable per day and slot', () {
      final settings = const AdhanSettings(sunriseAlert: true)
          .copyWith(alerts: {for (final s in AdhanSlot.prayers) s: const PrayerAlert(preMinutes: 10)});
      final alarms = plan(settings, wall(amman, 2026, 9, 28, 1));
      final ids = alarms.map((a) => a.id).toList();
      expect(ids.toSet(), hasLength(ids.length));
      expect(ids.every(NotificationNamespaces.adhan.contains), isTrue);
      expect(ids.contains(AdhanIds.test) || ids.contains(AdhanIds.snooze), isFalse);
      expect(
        AdhanIds.of(DateTime.utc(2026, 9, 28), AdhanKind.adhan, AdhanSlot.fajr),
        AdhanIds.of(DateTime.utc(2026, 9, 28), AdhanKind.adhan, AdhanSlot.fajr),
      );
      expect(
        AdhanIds.of(DateTime.utc(2026, 9, 28), AdhanKind.adhan, AdhanSlot.fajr),
        isNot(AdhanIds.of(DateTime.utc(2026, 9, 29), AdhanKind.adhan, AdhanSlot.fajr)),
      );
      // 11 alarms a day × 8 days fits under the cap.
      expect(alarms.length, lessThanOrEqualTo(planner.maxAlarms));
    });

    test('re-planning a day later keeps the ids of the overlapping alarms', () {
      final a = plan(const AdhanSettings(), wall(amman, 2026, 9, 28, 1));
      final b = plan(const AdhanSettings(), wall(amman, 2026, 9, 29, 1));
      final byInstantA = {for (final x in a) x.at: x.id};
      var shared = 0;
      for (final x in b) {
        final id = byInstantA[x.at];
        if (id != null) {
          expect(x.id, id);
          shared++;
        }
      }
      expect(shared, greaterThan(30));
    });

    test('the id cycle never collides inside the horizon', () {
      final seen = <int>{};
      for (var d = 0; d < AdhanIds.cycleDays; d++) {
        final day = DateTime.utc(2026, 1, 1 + d);
        for (final slot in AdhanSlot.prayers) {
          expect(seen.add(AdhanIds.of(day, AdhanKind.adhan, slot)), isTrue);
          expect(seen.add(AdhanIds.of(day, AdhanKind.preAdhan, slot)), isTrue);
        }
        expect(seen.add(AdhanIds.of(day, AdhanKind.sunrise, AdhanSlot.sunrise)), isTrue);
      }
      expect(seen.every((id) => id < AdhanIds.test), isTrue);
    });

    test('the cap keeps the soonest alarms', () {
      final alarms = plan(const AdhanSettings(), wall(amman, 2026, 9, 28, 1), p: const AdhanPlanner(maxAlarms: 7));
      expect(alarms, hasLength(7));
      expect(alarms.first.slot, AdhanSlot.fajr);
    });
  });

  group('daylight saving and time zones', () {
    test('autumn change: the adhan stays at the wall-clock time', () {
      final berlin = zone('Europe/Berlin');
      // DST ends in Europe on 25 Oct 2026 (03:00 → 02:00).
      final alarms = plan(const AdhanSettings(), wall(berlin, 2026, 10, 23, 12, 0), location: berlin);
      final fajrs = alarms.where((a) => a.slot == AdhanSlot.fajr).toList();
      for (final f in fajrs) {
        final local = tz.TZDateTime.from(f.at, berlin);
        expect((local.hour, local.minute), (4, 50));
      }
      final sat = fajrs.firstWhere((a) => a.day == DateTime.utc(2026, 10, 24));
      final sun = fajrs.firstWhere((a) => a.day == DateTime.utc(2026, 10, 25));
      final mon = fajrs.firstWhere((a) => a.day == DateTime.utc(2026, 10, 26));
      // The night of the change is 25 hours long; the next one is ordinary.
      expect(sun.at.difference(sat.at), const Duration(hours: 25));
      expect(mon.at.difference(sun.at), const Duration(hours: 24));
      final ishaSat = alarms.firstWhere((a) => a.slot == AdhanSlot.isha && a.day == DateTime.utc(2026, 10, 24));
      final ishaSun = alarms.firstWhere((a) => a.slot == AdhanSlot.isha && a.day == DateTime.utc(2026, 10, 25));
      expect(ishaSun.at.difference(ishaSat.at), const Duration(hours: 25));
    });

    test('spring change: a 23-hour day, nothing lost or doubled', () {
      final berlin = zone('Europe/Berlin');
      final alarms = plan(const AdhanSettings(), wall(berlin, 2027, 3, 26, 20, 0), location: berlin);
      final sat = alarms.firstWhere((a) => a.slot == AdhanSlot.isha && a.day == DateTime.utc(2027, 3, 27));
      final sun = alarms.firstWhere((a) => a.slot == AdhanSlot.isha && a.day == DateTime.utc(2027, 3, 28));
      expect(sun.at.difference(sat.at), const Duration(hours: 23));
      final perDay = <DateTime, int>{};
      for (final a in alarms) {
        perDay[a.day] = (perDay[a.day] ?? 0) + 1;
      }
      for (final e in perDay.entries) {
        if (e.key.isAfter(DateTime.utc(2027, 3, 26)) && e.key.isBefore(DateTime.utc(2027, 4, 3))) {
          expect(e.value, 5, reason: '${e.key}');
        }
      }
    });

    test('a device in another zone plans the same instants', () {
      final now = wall(amman, 2026, 9, 28, 13, 0);
      final home = plan(const AdhanSettings(), now);
      final travelling = plan(const AdhanSettings(), now, device: zone('America/New_York'));
      final tokyo = plan(const AdhanSettings(), now, device: zone('Asia/Tokyo'));
      final a = home.take(30).map((x) => x.at).toList();
      expect(travelling.take(30).map((x) => x.at).toList(), a);
      expect(tokyo.take(30).map((x) => x.at).toList(), a);
    });

    test('an Isha after midnight (high-latitude summer) still sounds', () {
      final oslo = zone('Europe/Oslo');
      final times = wallClockTimes(
        oslo,
        at: const {
          AdhanSlot.fajr: (2, 40),
          AdhanSlot.sunrise: (4, 0),
          AdhanSlot.dhuhr: (13, 20),
          AdhanSlot.asr: (17, 40),
          AdhanSlot.maghrib: (22, 40),
          AdhanSlot.isha: (23, 59),
        },
      );
      // Isha of 20 June pushed past midnight.
      AdhanDayTimes shifted(DateTime day) {
        final t = times(day);
        return AdhanDayTimes(day, {...t.times, AdhanSlot.isha: t[AdhanSlot.isha]!.add(const Duration(minutes: 41))});
      }

      final now = wall(oslo, 2026, 6, 21, 0, 10);
      final alarms = const AdhanPlanner().plan(
        settings: const AdhanSettings(),
        now: now,
        timesFor: shifted,
        localDayOf: localDayIn(oslo),
      );
      expect(alarms.first.slot, AdhanSlot.isha);
      expect(alarms.first.day, DateTime.utc(2026, 6, 20));
      expect(alarms.first.at, wall(oslo, 2026, 6, 21, 0, 40));
    });
  });

  group('quiet window', () {
    test('covers the adhan and the quiet minutes after it', () {
      final t = DateTime.utc(2026, 9, 28, 15, 50);
      final w = QuietWindow.covering(
        [t],
        t.add(const Duration(minutes: 5)),
        quiet: const Duration(minutes: 20),
        adhanLength: const Duration(minutes: 3),
      );
      expect(w, QuietWindow(t, t.add(const Duration(minutes: 20))));
      expect(
        QuietWindow.covering(
          [t],
          t.add(const Duration(minutes: 25)),
          quiet: const Duration(minutes: 20),
          adhanLength: const Duration(minutes: 3),
        ),
        isNull,
      );
      expect(
        QuietWindow.covering(
          [t],
          t.subtract(const Duration(seconds: 1)),
          quiet: const Duration(minutes: 20),
          adhanLength: const Duration(minutes: 3),
        ),
        isNull,
      );
      // Quiet 0 → only while it sounds.
      expect(
        QuietWindow.covering(
          [t],
          t.add(const Duration(minutes: 2)),
          quiet: Duration.zero,
          adhanLength: const Duration(minutes: 3),
        )?.end,
        t.add(const Duration(minutes: 3)),
      );
    });
  });

  test('nextCall skips reminders', () {
    final settings = const AdhanSettings().withAlert(AdhanSlot.asr, const PrayerAlert(preMinutes: 10));
    final now = wall(amman, 2026, 9, 28, 15, 0);
    final alarms = plan(settings, now);
    expect(alarms.first.kind, AdhanKind.preAdhan);
    expect(AdhanPlanner.nextCall(alarms, now)?.slot, AdhanSlot.asr);
    expect(AdhanPlanner.nextCall(alarms, now)?.kind, AdhanKind.adhan);
  });
}

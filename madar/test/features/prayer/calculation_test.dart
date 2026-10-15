import 'dart:io';

import 'package:adhan_dart/adhan_dart.dart' as adhan;
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/features/orbit/domain/prayer_schedule.dart';
import 'package:madar/features/prayer/domain/cities.dart';
import 'package:madar/features/prayer/domain/location.dart';
import 'package:madar/features/prayer/domain/prayer_day.dart';
import 'package:madar/features/prayer/domain/qibla.dart';
import 'package:madar/features/prayer/domain/time_zones.dart';
import 'package:timezone/timezone.dart' as tz;

import 'fixtures/reference_times.dart';

int _minutes(String hhmm) {
  final p = hhmm.split(':');
  return int.parse(p[0]) * 60 + int.parse(p[1]);
}

int _wallMinutes(PrayerSchedule s, DateTime instant) {
  final w = s.wallClock(instant);
  return w.hour * 60 + w.minute;
}

PrayerSettings _settingsFor(ReferenceSet r) => PrayerSettings(
  latitude: r.latitude,
  longitude: r.longitude,
  method: PrayerMethod.fromId(r.method),
  hanafiAsr: r.hanafi,
  timeZone: r.timeZone,
);

void _expectDay(PrayerSchedule s, ReferenceDay d, int tolerance, String label) {
  final parts = d.date.split('-').map(int.parse).toList();
  final t = s.timesFor(DateTime(parts[0], parts[1], parts[2]));
  final pairs = {
    'fajr': (t.fajr, d.fajr),
    'sunrise': (t.sunrise, d.sunrise),
    'dhuhr': (t.dhuhr, d.dhuhr),
    'asr': (t.asr, d.asr),
    'maghrib': (t.maghrib, d.maghrib),
    'isha': (t.isha, d.isha),
  };
  for (final e in pairs.entries) {
    final got = _wallMinutes(s, e.value.$1);
    final want = _minutes(e.value.$2);
    expect(
      (got - want).abs(),
      lessThanOrEqualTo(tolerance),
      reason:
          '$label ${d.date} ${e.key}: got ${got ~/ 60}:${(got % 60).toString().padLeft(2, '0')}, want ${e.value.$2}',
    );
  }
}

void main() {
  setUpAll(MadarTimeZones.ensure);

  group('published reference times', () {
    test('Amman: the Ministry of Awqaf timetable (99 days) within ±1 min', () {
      final s = PrayerSchedule(_settingsFor(ammanAwqaf));
      for (final d in ammanAwqaf.days) {
        _expectDay(s, d, 1, 'Amman');
      }
    });

    test('the default settings (Amman, Jordan preset, Shafiʿi) reproduce the Ministry\'s times', () {
      // Only the zone is pinned to Asia/Amman, so the check does not depend
      // on the zone of the machine running the test.
      final s = PrayerSchedule(const PrayerSettings().copyWith(timeZone: 'Asia/Amman'));
      expect(s.settings.method, PrayerMethod.jordan);
      expect(s.settings.hanafiAsr, isFalse);
      final day28 = ammanAwqaf.days.firstWhere((d) => d.date == '2026-09-28');
      _expectDay(s, day28, 1, 'Amman default');
      for (final d in ammanAwqaf.days) {
        _expectDay(s, d, 1, 'Amman default');
      }
    });

    for (final r in referenceSets) {
      test('${r.name} (${r.method}) within ±${r.toleranceMinutes} min', () {
        final s = PrayerSchedule(_settingsFor(r));
        for (final d in r.days) {
          _expectDay(s, d, r.toleranceMinutes, r.name);
        }
      });
    }
  });

  group('presets come from adhan_dart', () {
    test('every preset uses adhan\'s own parameters', () {
      // Jordan keeps adhan's angles and method; only its sunrise / Maghrib
      // offsets follow the Ministry's published timetable.
      final expected = <PrayerMethod, adhan.CalculationParameters Function()>{
        PrayerMethod.jordan: adhan.CalculationMethodParameters.jordan,
        PrayerMethod.muslimWorldLeague: adhan.CalculationMethodParameters.muslimWorldLeague,
        PrayerMethod.ummAlQura: adhan.CalculationMethodParameters.ummAlQura,
        PrayerMethod.egyptian: adhan.CalculationMethodParameters.egyptian,
        PrayerMethod.karachi: adhan.CalculationMethodParameters.karachi,
        PrayerMethod.northAmerica: adhan.CalculationMethodParameters.northAmerica,
        PrayerMethod.dubai: adhan.CalculationMethodParameters.dubai,
        PrayerMethod.kuwait: adhan.CalculationMethodParameters.kuwait,
        PrayerMethod.qatar: adhan.CalculationMethodParameters.qatar,
        PrayerMethod.turkiye: adhan.CalculationMethodParameters.turkiye,
        PrayerMethod.singapore: adhan.CalculationMethodParameters.singapore,
        PrayerMethod.tehran: adhan.CalculationMethodParameters.tehran,
        PrayerMethod.gulfRegion: adhan.CalculationMethodParameters.gulfRegion,
        PrayerMethod.moonsightingCommittee: adhan.CalculationMethodParameters.moonsightingCommittee,
        PrayerMethod.algerian: adhan.CalculationMethodParameters.algerian,
        PrayerMethod.morocco: adhan.CalculationMethodParameters.morocco,
        PrayerMethod.tunisia: adhan.CalculationMethodParameters.tunisia,
        PrayerMethod.france: adhan.CalculationMethodParameters.france,
        PrayerMethod.russia: adhan.CalculationMethodParameters.russia,
        PrayerMethod.indonesian: adhan.CalculationMethodParameters.indonesian,
        PrayerMethod.jafari: adhan.CalculationMethodParameters.jafari,
        PrayerMethod.custom: adhan.CalculationMethodParameters.other,
      };
      expect(expected.keys.toSet(), PrayerMethod.values.toSet());
      for (final e in expected.entries) {
        final ours = e.key.parameters();
        final theirs = e.value();
        expect(ours.method, theirs.method, reason: '${e.key}');
        expect(ours.fajrAngle, theirs.fajrAngle, reason: '${e.key}');
        expect(ours.ishaAngle, theirs.ishaAngle, reason: '${e.key}');
        expect(ours.ishaInterval, theirs.ishaInterval, reason: '${e.key}');
        expect(ours.maghribAngle, theirs.maghribAngle, reason: '${e.key}');
        if (e.key == PrayerMethod.jordan) {
          expect(ours.methodAdjustments, {adhan.Prayer.sunrise: -7, adhan.Prayer.maghrib: 7});
        } else {
          expect(ours.methodAdjustments, theirs.methodAdjustments, reason: '${e.key}');
        }
        expect(ours.rounding, theirs.rounding, reason: '${e.key}');
      }
    });

    test('a preset schedule equals adhan computed directly', () {
      const lat = 24.7136, lon = 46.6753; // Riyadh
      for (final m in PrayerMethod.values.where((m) => m != PrayerMethod.custom)) {
        final s = PrayerSchedule(PrayerSettings(latitude: lat, longitude: lon, method: m, timeZone: 'Asia/Riyadh'));
        final ours = s.timesFor(DateTime(2026, 5, 15)); // outside Ramadan
        final p = m.parameters()
          ..madhab = adhan.Madhab.shafi
          ..highLatitudeRule = adhan.HighLatitudeRule.middleOfTheNight;
        final direct = adhan.PrayerTimes(
          date: DateTime(2026, 5, 15, 12),
          coordinates: const adhan.Coordinates(lat, lon),
          calculationParameters: p,
        );
        expect(ours.fajr, direct.fajr.toLocal(), reason: '$m fajr');
        expect(ours.dhuhr, direct.dhuhr.toLocal(), reason: '$m dhuhr');
        expect(ours.asr, direct.asr.toLocal(), reason: '$m asr');
        expect(ours.maghrib, direct.maghrib.toLocal(), reason: '$m maghrib');
        expect(ours.isha, direct.isha.toLocal(), reason: '$m isha');
      }
    });

    test('Jordan: Fajr and Isha at 18°, Shafiʿi Asr by default, Maghrib 7 min after sunset', () {
      const s = PrayerSettings();
      expect(s.method, PrayerMethod.jordan);
      final p = PrayerSchedule(s).parametersFor(2026, 9, 28);
      expect(p.fajrAngle, 18);
      expect(p.ishaAngle, 18);
      expect(p.methodAdjustments[adhan.Prayer.maghrib], 7);
      expect(p.methodAdjustments[adhan.Prayer.sunrise], -7);
      expect(p.madhab, adhan.Madhab.shafi);
    });

    test('Hanafi Asr is later than Shafiʿi', () {
      final shafi = PrayerSchedule(const PrayerSettings(timeZone: 'Asia/Amman')).timesFor(DateTime(2026, 9, 28));
      final hanafi = PrayerSchedule(const PrayerSettings(timeZone: 'Asia/Amman', hanafiAsr: true))
          .timesFor(DateTime(2026, 9, 28));
      final diff = hanafi.asr.difference(shafi.asr).inMinutes;
      expect(diff, inInclusiveRange(40, 80));
      expect(hanafi.dhuhr, shafi.dhuhr);
    });

    test('custom angles and a fixed Isha interval', () {
      const base = PrayerSettings(timeZone: 'Asia/Amman', method: PrayerMethod.custom, fajrAngle: 15, ishaAngle: 15);
      final t15 = PrayerSchedule(base).timesFor(DateTime(2026, 6, 1));
      final t18 = PrayerSchedule(base.copyWith(fajrAngle: 18, ishaAngle: 18)).timesFor(DateTime(2026, 6, 1));
      expect(t15.fajr.isAfter(t18.fajr), isTrue, reason: 'a smaller angle means a later Fajr');
      expect(t15.isha.isBefore(t18.isha), isTrue, reason: 'a smaller angle means an earlier Isha');
      final interval = PrayerSchedule(base.copyWith(ishaIntervalMin: 90)).timesFor(DateTime(2026, 6, 1));
      expect(interval.isha.difference(interval.maghrib), const Duration(minutes: 90));
    });

    test('Umm al-Qura: Isha 90 min after Maghrib, 120 min in Ramadan', () {
      const s = PrayerSettings(
        latitude: 21.4225,
        longitude: 39.8262,
        method: PrayerMethod.ummAlQura,
        timeZone: 'Asia/Riyadh',
      );
      final schedule = PrayerSchedule(s);
      final shaban = schedule.timesFor(DateTime(2026, 1, 25)); // 6 Shaʿban 1447
      expect(shaban.isha.difference(shaban.maghrib), const Duration(minutes: 90));
      final ramadan = schedule.timesFor(DateTime(2026, 3, 1)); // 12 Ramadan 1447
      expect(ramadan.isha.difference(ramadan.maghrib), const Duration(minutes: 120));
    });
  });

  group('adjustments and high latitudes', () {
    test('per-prayer minute adjustments shift exactly that time', () {
      const base = PrayerSettings(timeZone: 'Asia/Amman');
      final plain = PrayerSchedule(base).timesFor(DateTime(2026, 9, 28));
      final adjusted = PrayerSchedule(
        base.copyWith(adjustmentsMin: {'fajr': 2, 'sunrise': -1, 'dhuhr': 3, 'asr': 0, 'maghrib': -2, 'isha': 10}),
      ).timesFor(DateTime(2026, 9, 28));
      expect(adjusted.fajr.difference(plain.fajr), const Duration(minutes: 2));
      expect(adjusted.sunrise.difference(plain.sunrise), const Duration(minutes: -1));
      expect(adjusted.dhuhr.difference(plain.dhuhr), const Duration(minutes: 3));
      expect(adjusted.asr, plain.asr);
      expect(adjusted.maghrib.difference(plain.maghrib), const Duration(minutes: -2));
      expect(adjusted.isha.difference(plain.isha), const Duration(minutes: 10));
    });

    test('times are whole minutes (as published)', () {
      final t = PrayerSchedule(const PrayerSettings()).timesFor(DateTime(2026, 9, 28));
      for (final (_, at) in t.obligatory) {
        expect(at.second, 0);
        expect(at.millisecond, 0);
      }
    });

    test('automatic rule: middle of the night in Amman, one seventh in Oslo', () {
      expect(HighLatitudeMode.auto.ruleFor(31.95), adhan.HighLatitudeRule.middleOfTheNight);
      expect(HighLatitudeMode.auto.ruleFor(59.91), adhan.HighLatitudeRule.seventhOfTheNight);
      final oslo = PrayerSchedule(const PrayerSettings(latitude: 59.9139, longitude: 10.7522, timeZone: 'Europe/Oslo'))
          .timesFor(DateTime(2026, 6, 21));
      // Twilight never ends at midsummer in Oslo: the seventh-of-the-night
      // rule still gives an ordered day.
      expect(oslo.fajr.isBefore(oslo.sunrise), isTrue);
      expect(oslo.maghrib.isBefore(oslo.isha), isTrue);
      final night = oslo.sunrise.add(const Duration(days: 1)).difference(oslo.maghrib);
      expect(oslo.isha.difference(oslo.maghrib), lessThanOrEqualTo(night ~/ 7 + const Duration(minutes: 6)));
    });

    test('inside the polar circle (no sunset) the times stay valid', () {
      final tromso = PrayerSchedule(
        const PrayerSettings(latitude: 69.6492, longitude: 18.9553, timeZone: 'Europe/Oslo'),
      ).timesFor(DateTime(2026, 6, 21));
      for (final at in [tromso.fajr, tromso.sunrise, tromso.dhuhr, tromso.asr, tromso.maghrib, tromso.isha]) {
        expect(at.year, inInclusiveRange(2025, 2027));
      }
      expect(tromso.fajr.isBefore(tromso.dhuhr), isTrue);
      expect(tromso.dhuhr.isBefore(tromso.maghrib), isTrue);
    });
  });

  group('time zones', () {
    test('Makkah is computed in Makkah time whatever the device zone', () {
      // The device zone of the machine running this test is irrelevant: the
      // location carries Asia/Riyadh.
      final ref = referenceSets.firstWhere((r) => r.name == 'Makkah-UmmAlQura');
      final s = PrayerSchedule(_settingsFor(ref));
      expect(s.zone?.name, 'Asia/Riyadh');
      for (final d in ref.days) {
        _expectDay(s, d, 1, 'Makkah');
      }
      final t = s.timesFor(DateTime(2016, 1, 5));
      final wall = s.wallClock(t.fajr);
      expect(wall, isA<tz.TZDateTime>());
      expect((wall as tz.TZDateTime).location.name, 'Asia/Riyadh');
      expect(wall.timeZoneOffset, const Duration(hours: 3));
    });

    test('a location twelve hours from the device keeps its own calendar day', () {
      // Auckland (UTC+12/13) – whatever the device zone, "28 Sep" means 28
      // Sep in Auckland and every time falls on that Auckland date.
      final s = PrayerSchedule(
        const PrayerSettings(
          latitude: -36.8485,
          longitude: 174.7633,
          timeZone: 'Pacific/Auckland',
          method: PrayerMethod.muslimWorldLeague,
        ),
      );
      final t = s.timesFor(DateTime(2026, 9, 28));
      for (final at in [t.fajr, t.sunrise, t.dhuhr, t.asr, t.maghrib, t.isha]) {
        final w = s.wallClock(at);
        expect((w.year, w.month, w.day), (2026, 9, 28), reason: '$w');
      }
      final dhuhr = s.wallClock(t.dhuhr);
      expect(dhuhr.hour, anyOf(12, 13)); // NZ daylight time began on 27 Sep 2026
    });

    test('windowAt and prayerDayOf use the location calendar', () {
      final s = PrayerSchedule(const PrayerSettings(timeZone: 'Asia/Amman'));
      final amman = tz.getLocation('Asia/Amman');
      final t = s.timesFor(DateTime(2026, 9, 28));
      // 01:00 in Amman on 29 Sep belongs to the prayer day of 28 Sep.
      final lateNight = tz.TZDateTime(amman, 2026, 9, 29, 1);
      expect(s.windowAt(lateNight).window, PrayerWindow.isha);
      expect(s.prayerDayOf(lateNight), DateTime(2026, 9, 28));
      final afterDhuhr = s.wallClock(t.dhuhr.add(const Duration(minutes: 5)));
      expect(s.windowAt(afterDhuhr).window, PrayerWindow.dhuhr);
      expect(s.windowAt(afterDhuhr).nextPrayer, Prayer.asr);
      expect(s.dateOf(tz.TZDateTime(amman, 2026, 9, 28, 23, 59)), DateTime(2026, 9, 28));
    });

    test('Reykjavik at midsummer: Maghrib after midnight is still ahead at 00:05', () {
      // Sunset in Reykjavik on 20 June falls after 00:00 (UTC+0 runs 1.5 h
      // ahead of solar time there), so for a few minutes after midnight the
      // previous day's Asr window is still running and Maghrib comes next.
      final s = PrayerSchedule(
        const PrayerSettings(latitude: 64.15, longitude: -21.95, timeZone: 'Atlantic/Reykjavik'),
      );
      final june20 = s.timesFor(DateTime(2026, 6, 20));
      expect(s.dateOf(june20.maghrib), DateTime(2026, 6, 21), reason: 'the premise: Maghrib after midnight');
      final now = june20.maghrib.subtract(const Duration(minutes: 5));
      expect(s.dateOf(now), DateTime(2026, 6, 21));
      final w = s.windowAt(now);
      expect(w.window, PrayerWindow.asr);
      expect(w.start, june20.asr);
      expect(w.end, june20.maghrib);
      expect(w.nextPrayer, Prayer.maghrib);
      expect(w.nextPrayerAt, june20.maghrib);
      final between = s.windowAt(june20.maghrib.add(const Duration(minutes: 1)));
      expect(
        (between.window, between.nextPrayer, between.nextPrayerAt),
        (PrayerWindow.maghrib, Prayer.isha, june20.isha),
      );
      expect(s.prayerDayOf(now), DateTime(2026, 6, 20));
    });

    test('every city of the list: ordered days, and windows always contain "now"', () {
      final db = CityDatabase.parse(File('assets/geo/cities.json').readAsStringSync());
      final dates = [DateTime(2026, 3, 29), DateTime(2026, 6, 21), DateTime(2026, 10, 25), DateTime(2026, 12, 21)];
      final problems = <String>[];
      for (final c in db.cities) {
        final s = PrayerSchedule(PrayerLocationChanges.pickCity(const PrayerSettings(), c));
        for (final d in dates) {
          final t = s.timesFor(d);
          final seq = [t.fajr, t.sunrise, t.dhuhr, t.asr, t.maghrib, t.isha];
          for (var i = 1; i < seq.length; i++) {
            if (!seq[i].isAfter(seq[i - 1])) problems.add('${c.id} $d: moment $i out of order');
          }
          if (s.dateOf(t.dhuhr) != d) problems.add('${c.id} $d: Dhuhr on ${s.dateOf(t.dhuhr)}');
          for (var m = 0; m < 24 * 60; m += 20) {
            final now = t.day.add(Duration(minutes: m));
            final w = s.windowAt(now);
            if (w.start.isAfter(now) || !w.end.isAfter(now) || !w.nextPrayerAt.isAfter(now)) {
              problems.add('${c.id} ${s.wallClock(now)}: ${w.window} ${s.wallClock(w.start)}–${s.wallClock(w.end)}');
            }
          }
        }
      }
      expect(problems, isEmpty, reason: problems.take(10).join('\n'));
    });

    test('an unknown zone name falls back to the device zone', () {
      final s = PrayerSchedule(const PrayerSettings(timeZone: 'Mars/Olympus_Mons'));
      expect(s.zone, isNull);
      expect(s.timesFor(DateTime(2026, 9, 28)).fajr.isBefore(s.timesFor(DateTime(2026, 9, 28)).dhuhr), isTrue);
    });

    test('ensure() keeps a local zone set by another feature', () {
      MadarTimeZones.ensure();
      tz.setLocalLocation(tz.getLocation('Asia/Amman'));
      MadarTimeZones.ensure();
      expect(tz.local.name, 'Asia/Amman');
    });
  });

  group('the full prayer day', () {
    final s = PrayerSchedule(const PrayerSettings(timeZone: 'Asia/Amman'));
    final day = PrayerTimesDay.of(s, DateTime(2026, 9, 28));

    test('moments are in order, Duha 15 min after sunrise', () {
      final m = day.moments;
      for (var i = 1; i < m.length; i++) {
        expect(m[i].at.isAfter(m[i - 1].at), isTrue, reason: '${m[i].moment}');
      }
      expect(day.duha.difference(day.times.sunrise), const Duration(minutes: 15));
    });

    test('midnight halves and the last third splits Maghrib → next Fajr', () {
      final night = day.nextFajr.difference(day.times.maghrib);
      expect(day.midnight.difference(day.times.maghrib).inSeconds, closeTo(night.inSeconds / 2, 1));
      expect(day.lastThird.difference(day.times.maghrib).inSeconds, closeTo(night.inSeconds * 2 / 3, 1));
      expect(day.nextFajr, s.timesFor(DateTime(2026, 9, 29)).fajr);
    });

    test('current / next moment', () {
      final afterAsr = day.times.asr.add(const Duration(minutes: 1));
      expect(day.currentAt(afterAsr), PrayerMoment.asr);
      expect(day.statusOf(PrayerMoment.dhuhr, afterAsr), MomentStatus.past);
      expect(day.statusOf(PrayerMoment.asr, afterAsr), MomentStatus.current);
      expect(day.statusOf(PrayerMoment.maghrib, afterAsr), MomentStatus.upcoming);
      expect(day.nextAt(afterAsr)?.moment, PrayerMoment.maghrib);
      final beforeFajr = day.times.fajr.subtract(const Duration(minutes: 1));
      expect(day.currentAt(beforeFajr), isNull);
      final lateNight = day.lastThird.add(const Duration(minutes: 1));
      expect(day.currentAt(lateNight), PrayerMoment.lastThird);
    });
  });

  group('qibla', () {
    test('bearing matches adhan and known values', () {
      // Amman ≈ 161°, London ≈ 119°, Jakarta ≈ 295°, New York ≈ 58°.
      expect(QiblaMath.bearing(31.9539, 35.9106), closeTo(160.7, 0.5));
      expect(QiblaMath.bearing(51.5074, -0.1278), closeTo(118.99, 0.5));
      expect(QiblaMath.bearing(-6.2088, 106.8456), closeTo(295.15, 0.5));
      expect(QiblaMath.bearing(40.7128, -74.0060), closeTo(58.48, 0.5));
      final b = QiblaMath.bearing(35.78056, -78.6389);
      expect(b, closeTo(adhan.Qibla.qibla(const adhan.Coordinates(35.78056, -78.6389)), 1e-9));
      expect(b, inInclusiveRange(0, 360));
    });

    test('distance to the Kaaba and compass sectors', () {
      expect(QiblaMath.distanceKm(31.9539, 35.9106), closeTo(1230, 30));
      expect(QiblaMath.compassSector(0), 0);
      expect(QiblaMath.compassSector(160.7), 7); // SSE
      expect(QiblaMath.compassSector(359), 0);
    });
  });
}

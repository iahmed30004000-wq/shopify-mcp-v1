import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/orbit/domain/prayer_schedule.dart';
import 'package:madar/features/prayer/domain/cities.dart';
import 'package:madar/features/prayer/domain/prayer_day.dart';
import 'package:madar/features/prayer/domain/time_zones.dart';
import 'package:madar/features/travel/domain/destination_prayer.dart';

import '../prayer/fixtures/reference_times.dart';

void main() {
  late CityDatabase cities;

  setUpAll(() {
    MadarTimeZones.ensure();
    cities = CityDatabase.parse(File('assets/geo/cities.json').readAsStringSync());
  });

  int minutesOf(String hm) {
    final p = hm.split(':').map(int.parse).toList();
    return p[0] * 60 + p[1];
  }

  int wallMinutes(DestinationPrayer p, DateTime instant) {
    final w = p.localTime(instant);
    return w.hour * 60 + w.minute;
  }

  ReferenceSet set(String name) => referenceSets.firstWhere((r) => r.name == name);

  group('destination prayer times', () {
    test('Makkah with Umm al-Qura matches the official timetable, in Makkah time', () {
      final ref = set('Makkah-UmmAlQura');
      // The user lives in Amman (their own zone and a Fajr tweak) but has
      // chosen Umm al-Qura.
      const user = PrayerSettings(
        method: PrayerMethod.ummAlQura,
        timeZone: 'Asia/Amman',
        adjustmentsMin: {'fajr': 5, 'isha': -3},
      );
      final place = TripPlace(latitude: ref.latitude, longitude: ref.longitude, timeZone: ref.timeZone);
      final prayer = DestinationPrayer(place, user);
      expect(prayer.settings.adjustmentsMin, isEmpty, reason: 'home-mosque tweaks stay at home');
      expect(prayer.settings.method, PrayerMethod.ummAlQura);
      for (final d in ref.days.take(6)) {
        final parts = d.date.split('-').map(int.parse).toList();
        final day = prayer.day(DateTime(parts[0], parts[1], parts[2]));
        final pairs = {
          'fajr': (day.times.fajr, d.fajr),
          'sunrise': (day.times.sunrise, d.sunrise),
          'dhuhr': (day.times.dhuhr, d.dhuhr),
          'asr': (day.times.asr, d.asr),
          'maghrib': (day.times.maghrib, d.maghrib),
          'isha': (day.times.isha, d.isha),
        };
        for (final e in pairs.entries) {
          expect(
            (wallMinutes(prayer, e.value.$1) - minutesOf(e.value.$2)).abs(),
            lessThanOrEqualTo(ref.toleranceMinutes),
            reason: '${d.date} ${e.key}',
          );
        }
      }
    });

    test('a listed city resolves to its own zone, and the day is its calendar day', () {
      final makkah = cities.byId('sa-makkah')!;
      final place = TripPlace.resolve(latitude: makkah.latitude, longitude: makkah.longitude, cities: cities)!;
      expect(place.city, makkah);
      expect(place.timeZone, 'Asia/Riyadh');
      expect(place.countryCode, 'SA');
      final prayer = DestinationPrayer(place, const PrayerSettings());
      // 22:30 UTC on 9 Oct 2026 is already 01:30 on the 10th in Makkah.
      final now = DateTime.utc(2026, 10, 9, 22, 30);
      expect(prayer.todayThere(now), DateTime(2026, 10, 10));
      expect(prayer.localTime(now).hour, 1);
      expect(prayer.utcOffset(now), const Duration(hours: 3));
    });

    test('Istanbul times read on Istanbul\'s clock with the user\'s method', () {
      final istanbul = cities.byId('tr-istanbul')!;
      final prayer = DestinationPrayer(TripPlace.ofCity(istanbul), const PrayerSettings());
      final day = prayer.day(DateTime(2026, 10, 12));
      // Solar noon in Istanbul (28.98°E, UTC+3) is around 12:55.
      final dhuhr = prayer.localTime(day.times.dhuhr);
      expect(dhuhr.hour * 60 + dhuhr.minute, inInclusiveRange(12 * 60 + 45, 13 * 60 + 10));
      expect(day.times.fajr.isBefore(day.times.sunrise), isTrue);
      expect(day.times.maghrib.isBefore(day.times.isha), isTrue);
      expect(day.moments.length, PrayerMoment.values.length);
    });

    test('same moments as the prayer package\'s own schedule for that place', () {
      final cairo = cities.byId('eg-cairo')!;
      const user = PrayerSettings(method: PrayerMethod.egyptian);
      final prayer = DestinationPrayer(TripPlace.ofCity(cairo), user);
      final direct = PrayerSchedule(
        user.copyWith(latitude: cairo.latitude, longitude: cairo.longitude, timeZone: cairo.timeZone),
      ).timesFor(DateTime(2026, 11, 3));
      final ours = prayer.day(DateTime(2026, 11, 3)).times;
      expect(ours.fajr, direct.fajr);
      expect(ours.isha, direct.isha);
    });

    test('time difference from the device', () {
      final tokyo = cities.byId('jp-tokyo');
      if (tokyo == null) return; // not every list carries Tokyo
      final prayer = DestinationPrayer(TripPlace.ofCity(tokyo), const PrayerSettings());
      final now = DateTime.utc(2026, 10, 1, 12);
      expect(prayer.offsetFromDevice(now), const Duration(hours: 9) - now.toLocal().timeZoneOffset);
    });

    test('a free-typed destination has no place', () {
      expect(TripPlace.resolve(latitude: null, longitude: 31, cities: cities), isNull);
    });

    test('coordinates away from any listed city keep the nearest zone but no city', () {
      final place = TripPlace.resolve(latitude: 31.5, longitude: 35.6, cities: cities)!;
      expect(place.city, isNull);
      expect(place.timeZone, isNotNull);
    });
  });

  group('qibla from the destination', () {
    test('bearing and distance from Istanbul', () {
      final istanbul = cities.byId('tr-istanbul')!;
      final q = DestinationPrayer(TripPlace.ofCity(istanbul), const PrayerSettings()).qibla;
      // Makkah lies south-east of Istanbul, ~2,400 km away.
      expect(q.bearing, inInclusiveRange(145, 160));
      expect(q.distanceKm, inInclusiveRange(2300, 2500));
      expect(q.atKaaba, isFalse);
    });

    test('recognises when the destination is the user\'s prayer location', () {
      final amman = cities.byId('jo-amman')!;
      final place = TripPlace.ofCity(amman);
      expect(place.isPrayerLocationOf(PrayerSettings(latitude: amman.latitude, longitude: amman.longitude)), isTrue);
      expect(place.isPrayerLocationOf(const PrayerSettings(latitude: 21.42, longitude: 39.82)), isFalse);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/astro/astronomy.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/features/orbit/domain/prayer_schedule.dart';
import 'package:madar/features/prayer/domain/time_zones.dart';
import 'package:timezone/timezone.dart' as tz;

void main() {
  final schedule = PrayerSchedule(const PrayerSettings()); // Amman, Jordan preset
  final day = DateTime(2026, 9, 27);

  test('prayers are ordered and Dhuhr follows solar noon', () {
    final t = schedule.timesFor(day);
    expect(t.fajr.isBefore(t.sunrise), isTrue);
    expect(t.sunrise.isBefore(t.dhuhr), isTrue);
    expect(t.dhuhr.isBefore(t.asr), isTrue);
    expect(t.asr.isBefore(t.maghrib), isTrue);
    expect(t.maghrib.isBefore(t.isha), isTrue);
    // Solar noon in Amman on this date is ≈ 09:27 UTC (verified in astronomy tests).
    final noonUtc = DateTime.utc(2026, 9, 27, 9, 27);
    expect(t.dhuhr.toUtc().difference(noonUtc).inMinutes.abs(), lessThanOrEqualTo(5));
  });

  test('Fajr and Isha sit near the 18° depression angle', () {
    final t = schedule.timesFor(day);
    const lat = 31.9539, lon = 35.9106;
    final fajrSun = Astro.sun(t.fajr, latitude: lat, longitude: lon).altitude;
    final ishaSun = Astro.sun(t.isha, latitude: lat, longitude: lon).altitude;
    expect(fajrSun, closeTo(-18, 0.6));
    expect(ishaSun, closeTo(-18, 0.6));
    // Maghrib: sunset + Jordan's +5 minute adjustment → sun a little below the horizon.
    final maghribSun = Astro.sun(t.maghrib, latitude: lat, longitude: lon).altitude;
    expect(maghribSun, lessThan(-0.8));
    expect(maghribSun, greaterThan(-2.6));
  });

  test('windows follow the prayer-anchored day', () {
    final t = schedule.timesFor(day);
    WindowState at(DateTime x) => schedule.windowAt(x);
    expect(at(t.fajr.subtract(const Duration(minutes: 5))).window, PrayerWindow.isha);
    expect(at(t.fajr.add(const Duration(minutes: 5))).window, PrayerWindow.fajr);
    expect(at(t.sunrise.add(const Duration(minutes: 5))).window, PrayerWindow.duha);
    expect(at(t.dhuhr.add(const Duration(minutes: 5))).window, PrayerWindow.dhuhr);
    expect(at(t.asr.add(const Duration(minutes: 5))).window, PrayerWindow.asr);
    final m = at(t.maghrib.add(const Duration(minutes: 5)));
    expect(m.window, PrayerWindow.maghrib);
    expect(m.nextPrayer, Prayer.isha);
    final late = at(t.isha.add(const Duration(hours: 1)));
    expect(late.window, PrayerWindow.isha);
    expect(late.nextPrayer, Prayer.fajr);
    expect(late.nextPrayerAt.isAfter(t.isha), isTrue);
    expect(m.progressAt(t.maghrib), 0);
  });

  test('an Isha after midnight: yesterday\'s Maghrib window runs until it begins', () {
    // Isha pushed to ≈ 00:30 the next (local) day, as in a high-latitude
    // summer.
    final base = schedule.timesFor(day).isha;
    final shift = DateTime(2026, 9, 28, 0, 30).difference(base).inMinutes;
    final late = PrayerSchedule(PrayerSettings(adjustmentsMin: {'isha': shift}));
    final isha = late.timesFor(day).isha;
    expect(isha.day, 28, reason: 'the fixture needs an Isha after midnight');
    final before = late.windowAt(isha.subtract(const Duration(minutes: 10)));
    expect(before.window, PrayerWindow.maghrib);
    expect(before.nextPrayer, Prayer.isha);
    expect(before.nextPrayerAt, isha);
    expect(before.start, late.timesFor(day).maghrib);
    final after = late.windowAt(isha.add(const Duration(minutes: 10)));
    expect(after.window, PrayerWindow.isha);
    expect(after.nextPrayer, Prayer.fajr);
  });

  test('obligatory prayers counted over the last 7 days', () {
    final t = schedule.timesFor(day);
    final n = schedule.obligatoryStartedInLast(t.asr.add(const Duration(minutes: 1)));
    // 7 full days × 5 minus the ones not yet due today (maghrib, isha) plus
    // boundary: exactly 35 prayers started in the trailing 7×24h window.
    expect(n, inInclusiveRange(34, 36));
  });

  test('settings round-trip through JSON', () {
    const s = PrayerSettings(
      latitude: 33.5,
      longitude: 36.3,
      cityName: 'Damascus',
      hanafiAsr: true,
      adjustmentsMin: {'fajr': 2},
    );
    final back = PrayerSettings.fromJson(s.toJson());
    expect(back.latitude, 33.5);
    expect(back.hanafiAsr, isTrue);
    expect(back.adjustmentsMin['fajr'], 2);
    expect(back.cityName, 'Damascus');
  });

  group('Phase 2 settings', () {
    setUpAll(MadarTimeZones.ensure);

    test('with the location zone stored, windows follow Amman whatever the device zone', () {
      final amman = tz.getLocation('Asia/Amman');
      final zoned = PrayerSchedule(const PrayerSettings(timeZone: 'Asia/Amman'));
      final t = zoned.timesFor(DateTime(2026, 9, 27));
      WindowState at(DateTime x) => zoned.windowAt(x);
      expect(at(t.fajr.subtract(const Duration(minutes: 5))).window, PrayerWindow.isha);
      expect(at(t.fajr.add(const Duration(minutes: 5))).window, PrayerWindow.fajr);
      expect(at(t.sunrise.add(const Duration(minutes: 5))).window, PrayerWindow.duha);
      expect(at(t.maghrib.add(const Duration(minutes: 5))).nextPrayer, Prayer.isha);
      expect(zoned.prayerDayOf(tz.TZDateTime(amman, 2026, 9, 28, 2)), DateTime(2026, 9, 27));
      final dhuhr = zoned.wallClock(t.dhuhr);
      expect((dhuhr.hour, dhuhr.day), (12, 27));
    });

    test('Phase 1 JSON decodes into the same schedule parameters', () {
      final phase1 = PrayerSettings.fromJson(const {
        'latitude': 31.9539,
        'longitude': 35.9106,
        'fajrAngle': 18,
        'ishaAngle': 18,
        'hanafiAsr': false,
        'adjustmentsMin': <String, Object?>{},
        'useJordanPreset': true,
      });
      expect(phase1, const PrayerSettings());
      expect(PrayerSchedule(phase1).timesFor(day).maghrib, schedule.timesFor(day).maghrib);
    });
  });
}

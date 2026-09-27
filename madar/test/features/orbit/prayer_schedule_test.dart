import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/astro/astronomy.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/features/orbit/domain/prayer_schedule.dart';

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

  test('obligatory prayers counted over the last 7 days', () {
    final t = schedule.timesFor(day);
    final n = schedule.obligatoryStartedInLast(t.asr.add(const Duration(minutes: 1)));
    // 7 full days × 5 minus the ones not yet due today (maghrib, isha) plus
    // boundary: exactly 35 prayers started in the trailing 7×24h window.
    expect(n, inInclusiveRange(34, 36));
  });

  test('settings round-trip through JSON', () {
    const s = PrayerSettings(latitude: 33.5, longitude: 36.3, cityName: 'Damascus', hanafiAsr: true, adjustmentsMin: {'fajr': 2});
    final back = PrayerSettings.fromJson(s.toJson());
    expect(back.latitude, 33.5);
    expect(back.hanafiAsr, isTrue);
    expect(back.adjustmentsMin['fajr'], 2);
    expect(back.cityName, 'Damascus');
  });
}

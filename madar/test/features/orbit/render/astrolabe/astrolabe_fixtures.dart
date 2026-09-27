import 'package:flutter/widgets.dart';
import 'package:madar/core/astro/astronomy.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/core/i18n/formatters.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/core/settings/app_settings.dart';
import 'package:madar/features/orbit/domain/prayer_schedule.dart';
import 'package:madar/features/orbit/render/astrolabe/astrolabe.dart';

/// Deterministic Amman fixtures (27 Sep 2026, Jordanian Awqaf preset) that
/// read the same in any test time zone: the dial shows Amman clock times
/// (UTC+3) as local DateTimes, while the sun is computed at the real instant.
abstract final class AmmanDay {
  static const lat = 31.9539;
  static const lng = 35.9106;

  /// Amman clock time on the fixture day (as a local DateTime).
  static DateTime at(int h, int m, [int s = 0]) => DateTime(2026, 9, 27, h, m, s);

  static DateTime _instant(DateTime clock) =>
      DateTime.utc(clock.year, clock.month, clock.day, clock.hour, clock.minute, clock.second).subtract(const Duration(hours: 3));

  static final DayTimes times = DayTimes(
    day: DateTime(2026, 9, 27),
    fajr: at(5, 6, 15),
    sunrise: at(6, 27, 32),
    dhuhr: at(12, 27, 22),
    asr: at(15, 51, 50),
    maghrib: at(18, 31, 42),
    isha: at(19, 47, 49),
  );

  static WindowState windowAt(DateTime now) {
    final t = times;
    final nextFajr = t.fajr.add(const Duration(days: 1));
    if (now.isBefore(t.fajr)) {
      return WindowState(window: PrayerWindow.isha, start: t.isha.subtract(const Duration(days: 1)), end: t.fajr, nextPrayer: Prayer.fajr, nextPrayerAt: t.fajr);
    }
    if (now.isBefore(t.sunrise)) {
      return WindowState(window: PrayerWindow.fajr, start: t.fajr, end: t.sunrise, nextPrayer: Prayer.dhuhr, nextPrayerAt: t.dhuhr);
    }
    if (now.isBefore(t.dhuhr)) {
      return WindowState(window: PrayerWindow.duha, start: t.sunrise, end: t.dhuhr, nextPrayer: Prayer.dhuhr, nextPrayerAt: t.dhuhr);
    }
    if (now.isBefore(t.asr)) {
      return WindowState(window: PrayerWindow.dhuhr, start: t.dhuhr, end: t.asr, nextPrayer: Prayer.asr, nextPrayerAt: t.asr);
    }
    if (now.isBefore(t.maghrib)) {
      return WindowState(window: PrayerWindow.asr, start: t.asr, end: t.maghrib, nextPrayer: Prayer.maghrib, nextPrayerAt: t.maghrib);
    }
    if (now.isBefore(t.isha)) {
      return WindowState(window: PrayerWindow.maghrib, start: t.maghrib, end: t.isha, nextPrayer: Prayer.isha, nextPrayerAt: t.isha);
    }
    return WindowState(window: PrayerWindow.isha, start: t.isha, end: nextFajr, nextPrayer: Prayer.fajr, nextPrayerAt: nextFajr);
  }

  static AstrolabeSky skyAt(DateTime clock) {
    final sun = Astro.sun(_instant(clock), latitude: lat, longitude: lng);
    return AstrolabeSky(
      sunFraction: PrayerSchedule.dialFraction(clock),
      solarFraction: sun.solarDayFraction,
      sunRaDeg: sun.rightAscension,
      sunDecDeg: sun.declination,
      latitude: lat,
    );
  }

  static AstrolabeLabels labels(String lang, {DigitStyle digits = DigitStyle.auto}) =>
      AstrolabeLabels(lookupL10n(Locale(lang)), MadarFormatter(languageCode: lang, digits: digits));

  static AstrolabeState state(
    DateTime now, {
    String lang = 'ar',
    Set<Prayer> prayed = const {},
    Set<Prayer>? missed,
    double balance = 0.85,
    DigitStyle digits = DigitStyle.auto,
  }) => AstrolabeState(
    times: times,
    window: windowAt(now),
    now: now,
    sky: skyAt(now),
    labels: labels(lang, digits: digits),
    prayed: prayed,
    missed: missed,
    balance: balance,
  );
}

import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../orbit/data/orbit_providers.dart' show orbitClockProvider;
import '../../orbit/domain/prayer_schedule.dart';
import '../data/device_location.dart';
import '../domain/cities.dart';
import '../domain/hijri.dart';
import '../domain/location.dart';
import '../domain/prayer_day.dart';
import 'prayer_settings_controller.dart';

/// The offline city list (assets/geo/cities.json). Loaded once; tests may
/// override it with `CityDatabase.parse(File(...).readAsStringSync())`.
final cityDatabaseProvider = FutureProvider<CityDatabase>((ref) async {
  // Decoded here rather than with loadString: the asset is larger than the
  // bundle's 50 KB threshold, above which loadString decodes on another
  // isolate (slow to start for an 85 KB file).
  final data = await rootBundle.load(CityDatabase.assetPath);
  final text = utf8.decode(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
  return CityDatabase.parse(text);
});

/// The device location (geolocator in the app; a fake in tests).
final locationSourceProvider = Provider<LocationSource>((ref) => const GeolocatorLocationSource());

/// The device's IANA time zone (flutter_timezone in the app).
final deviceTimeZoneProvider = Provider<DeviceTimeZoneSource>((ref) => const FlutterDeviceTimeZone());

/// The wall clock of the prayer screens (follows the orbit's / home's, so
/// tests freeze them all at once).
final prayerClockProvider = Provider<DateTime Function()>((ref) => ref.watch(orbitClockProvider));

/// The schedule of the settings being edited – updates the instant a
/// setting changes (before the encrypted write has landed).
final prayerLiveScheduleProvider = Provider<PrayerSchedule>(
  (ref) => PrayerSchedule(ref.watch(prayerSettingsControllerProvider)),
);

/// The full prayer day (with Duha, midnight and the last third) of a
/// location date. Auto-disposed: callers key it by date, so entries of days
/// no longer shown must not pile up.
final prayerTimesDayProvider = Provider.autoDispose.family<PrayerTimesDay, DateTime>(
  (ref, date) => PrayerTimesDay.of(ref.watch(prayerLiveScheduleProvider), date),
);

/// The Hijri date at an instant, with the user's offset and the Maghrib
/// rollover option. Auto-disposed: it is keyed by the (ticking) clock, so a
/// kept-alive family would gain an entry on every rebuild.
final hijriDateProvider = Provider.autoDispose.family<HijriDate, DateTime>((ref, instant) {
  final settings = ref.watch(prayerSettingsControllerProvider);
  final schedule = ref.watch(prayerLiveScheduleProvider);
  return hijriAt(schedule, settings, instant);
});

/// The Hijri date of [instant] for [settings] (pure helper behind
/// [hijriDateProvider]).
HijriDate hijriAt(PrayerSchedule schedule, PrayerSettings settings, DateTime instant) {
  final wall = schedule.wallClock(instant);
  DateTime? maghrib;
  if (settings.hijriAtMaghrib) {
    maghrib = schedule.wallClock(schedule.timesFor(schedule.dateOf(instant)).maghrib);
  }
  return HijriCalendarMath.at(
    wall,
    offsetDays: settings.hijriOffsetDays,
    rollAtMaghrib: settings.hijriAtMaghrib,
    maghrib: maghrib,
  );
}

/// The Hijri date of a civil (location) date – for tables and date headers,
/// where the Maghrib rollover does not apply.
HijriDate hijriOfDate(PrayerSettings settings, DateTime date) =>
    HijriCalendarMath.fromGregorian(date, offsetDays: settings.hijriOffsetDays);

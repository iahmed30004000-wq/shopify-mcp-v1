import 'package:flutter/foundation.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../core/domain/enums.dart';
import '../../orbit/domain/prayer_schedule.dart';
import '../../prayer/domain/cities.dart';
import '../../prayer/domain/prayer_day.dart';
import '../../prayer/domain/time_zones.dart';
import '../../qibla/domain/qibla_fix.dart';

/// A trip's destination as a place on the globe: its coordinates, its IANA
/// zone and – when it was picked from the offline list – its city.
@immutable
class TripPlace {
  const TripPlace({required this.latitude, required this.longitude, this.timeZone, this.city, this.countryCode});

  /// A destination picked from the offline city list.
  factory TripPlace.ofCity(City city) => TripPlace(
    latitude: city.latitude,
    longitude: city.longitude,
    timeZone: MadarTimeZones.isValid(city.timeZone) ? city.timeZone : null,
    city: city,
    countryCode: city.countryCode,
  );

  /// Within this distance a trip's stored coordinates are "that city".
  static const cityMatchKm = 2.0;

  /// Beyond this distance the nearest city's zone is not trusted.
  static const zoneMatchKm = 400.0;

  /// The place of a trip stored with [latitude] / [longitude] (null when it
  /// has none – a destination typed freely). The trip table keeps no zone,
  /// so the zone is the nearest listed city's: exact for a destination
  /// picked from the list (its coordinates are that city's).
  static TripPlace? resolve({double? latitude, double? longitude, String? country, CityDatabase? cities}) {
    if (latitude == null || longitude == null) return null;
    final nearest = cities?.nearest(latitude, longitude);
    final city = nearest != null && nearest.distanceKm <= cityMatchKm ? nearest.city : null;
    final zone = nearest != null && nearest.distanceKm <= zoneMatchKm && MadarTimeZones.isValid(nearest.city.timeZone)
        ? nearest.city.timeZone
        : null;
    return TripPlace(
      latitude: latitude,
      longitude: longitude,
      timeZone: zone,
      city: city,
      countryCode: city?.countryCode ?? (country != null && country.length == 2 ? country.toUpperCase() : null),
    );
  }

  final double latitude;
  final double longitude;

  /// IANA zone (null: unknown – the device's zone is used).
  final String? timeZone;
  final City? city;

  /// ISO 3166-1 alpha-2, when known.
  final String? countryCode;

  tz.Location? get zone => MadarTimeZones.find(timeZone);

  /// Whether [settings] already pray at this place (same point ±~1 km).
  bool isPrayerLocationOf(PrayerSettings settings) =>
      (settings.latitude - latitude).abs() < 0.01 && (settings.longitude - longitude).abs() < 0.01;

  @override
  bool operator ==(Object other) =>
      other is TripPlace &&
      other.latitude == latitude &&
      other.longitude == longitude &&
      other.timeZone == timeZone &&
      other.city == city;

  @override
  int get hashCode => Object.hash(latitude, longitude, timeZone, city);

  @override
  String toString() => 'TripPlace($latitude, $longitude, $timeZone, ${city?.id})';
}

/// Prayer times and the qibla at a trip's destination, with the user's own
/// calculation choices (method, angles, Asr school, high-latitude rule,
/// clock) moved to the destination's coordinates and zone.
///
/// The per-prayer minute adjustments are *not* carried over: they tune the
/// times to a home mosque's timetable, not to another city's.
class DestinationPrayer {
  DestinationPrayer(TripPlace place, PrayerSettings user) : this._(place, settingsFor(user, place));

  DestinationPrayer._(this.place, this.settings) : schedule = PrayerSchedule(settings), _zone = place.zone;

  /// [user]'s calculation settings at [place].
  static PrayerSettings settingsFor(PrayerSettings user, TripPlace place) => user.copyWith(
    latitude: place.latitude,
    longitude: place.longitude,
    timeZone: place.timeZone,
    cityName: null,
    cityId: place.city?.id,
    cityNameAr: place.city?.nameAr,
    cityNameEn: place.city?.nameEn,
    countryCode: place.countryCode,
    locationSource: place.city != null ? PrayerLocationSource.city : PrayerLocationSource.gps,
    adjustmentsMin: const {},
  );

  final TripPlace place;
  final PrayerSettings settings;
  final PrayerSchedule schedule;
  final tz.Location? _zone;

  /// The full prayer day whose date (at the destination) is [date].
  PrayerTimesDay day(DateTime date) => PrayerTimesDay.of(schedule, date);

  /// The destination's wall-clock time at [now].
  DateTime localTime(DateTime now) => schedule.wallClock(now);

  /// The destination's calendar date at [now].
  DateTime todayThere(DateTime now) => schedule.dateOf(now);

  /// Destination offset minus the device's offset at [now] (positive: the
  /// destination is ahead).
  Duration offsetFromDevice(DateTime now) =>
      MadarTimeZones.offsetAt(now, _zone) - MadarTimeZones.offsetAt(now, null);

  /// The destination zone's UTC offset at [now].
  Duration utcOffset(DateTime now) => MadarTimeZones.offsetAt(now, _zone);

  /// The next obligatory prayer at the destination after [now].
  ({Prayer prayer, DateTime at}) nextPrayer(DateTime now) => nextObligatoryPrayer(schedule, now);

  /// Qibla bearing and great-circle distance from the destination.
  QiblaFix get qibla => QiblaFix.of(
    QiblaPlace(
      latitude: place.latitude,
      longitude: place.longitude,
      nameAr: place.city?.nameAr,
      nameEn: place.city?.nameEn,
    ),
  );
}

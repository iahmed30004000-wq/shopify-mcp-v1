import 'package:flutter/foundation.dart';

import '../../orbit/domain/prayer_schedule.dart';
import 'cities.dart';
import 'time_zones.dart';

/// A position fix from the device.
@immutable
class GeoFix {
  const GeoFix({required this.latitude, required this.longitude, this.accuracyMeters, this.at});

  final double latitude;
  final double longitude;
  final double? accuracyMeters;
  final DateTime? at;
}

/// The device's location permission / service state.
enum LocationAccess {
  /// Permission granted (while in use or always) and the service is on.
  granted,

  /// Not granted yet (asking again shows the system dialog).
  denied,

  /// Denied for good: only the app's system settings can grant it.
  deniedForever,

  /// Location services (GPS) are switched off.
  serviceDisabled,

  /// No location support on this platform.
  unsupported,
}

/// Why a fix could not be obtained.
class LocationFailure implements Exception {
  const LocationFailure(this.access, [this.message]);

  final LocationAccess? access;
  final String? message;

  @override
  String toString() => 'LocationFailure($access, $message)';
}

/// The device location, behind a small interface so tests use fakes.
abstract interface class LocationSource {
  /// Current permission / service state, without asking.
  Future<LocationAccess> check();

  /// Shows the system permission dialog when it still can.
  Future<LocationAccess> request();

  /// A coarse current position (prayer times need ±a few km); throws
  /// [LocationFailure] on denial, disabled services or timeout.
  Future<GeoFix> currentFix({Duration timeLimit = const Duration(seconds: 20)});

  /// Opens this app's page in the system settings.
  Future<bool> openAppSettings();

  /// Opens the system location settings.
  Future<bool> openLocationSettings();
}

/// The device's IANA time zone.
abstract interface class DeviceTimeZoneSource {
  Future<String?> currentZone();
}

/// Pure location → settings transforms.
abstract final class PrayerLocationChanges {
  /// Beyond this distance a GPS fix is named "near" its nearest city.
  static const nearKm = 25.0;

  /// The settings for a city picked from the list: its coordinates, names,
  /// country and time zone.
  static PrayerSettings pickCity(PrayerSettings s, City city) => s.copyWith(
    latitude: city.latitude,
    longitude: city.longitude,
    cityName: null,
    cityId: city.id,
    cityNameAr: city.nameAr,
    cityNameEn: city.nameEn,
    countryCode: city.countryCode,
    timeZone: MadarTimeZones.isValid(city.timeZone) ? city.timeZone : null,
    locationSource: PrayerLocationSource.city,
  );

  /// The settings for a GPS [fix]: named after [nearest]; the time zone is
  /// the device's own ([deviceZone], it follows the network where the phone
  /// is) or else the nearest city's.
  static PrayerSettings applyFix(PrayerSettings s, GeoFix fix, {NearestCity? nearest, String? deviceZone}) {
    final zone = MadarTimeZones.isValid(deviceZone)
        ? deviceZone
        : (nearest != null && MadarTimeZones.isValid(nearest.city.timeZone) ? nearest.city.timeZone : null);
    return s.copyWith(
      latitude: _round(fix.latitude.clamp(-90.0, 90.0)),
      longitude: _round(fix.longitude.clamp(-180.0, 180.0)),
      cityName: null,
      cityId: nearest?.city.id,
      cityNameAr: nearest?.city.nameAr,
      cityNameEn: nearest?.city.nameEn,
      countryCode: nearest?.city.countryCode,
      timeZone: zone,
      locationSource: PrayerLocationSource.gps,
    );
  }

  /// Back to the generic default (Amman, device time zone).
  static PrayerSettings resetToDefault(PrayerSettings s) {
    const d = PrayerSettings();
    return s.copyWith(
      latitude: d.latitude,
      longitude: d.longitude,
      cityName: null,
      cityId: null,
      cityNameAr: null,
      cityNameEn: null,
      countryCode: null,
      timeZone: null,
      locationSource: PrayerLocationSource.defaultCity,
    );
  }

  /// ~11 m precision is plenty for prayer times and stores less about where
  /// the user is.
  static double _round(double v) => (v * 10000).roundToDouble() / 10000;
}

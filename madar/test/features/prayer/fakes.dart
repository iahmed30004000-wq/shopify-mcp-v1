// Test doubles for the prayer feature's platform interfaces.
import 'dart:io';

import 'package:madar/features/prayer/domain/cities.dart';
import 'package:madar/features/prayer/domain/location.dart';

/// A scriptable [LocationSource].
class FakeLocationSource implements LocationSource {
  FakeLocationSource({
    this.access = LocationAccess.granted,
    this.afterRequest = LocationAccess.granted,
    this.fix = const GeoFix(latitude: 31.9539, longitude: 35.9106),
    this.failure,
  });

  /// What [check] reports.
  LocationAccess access;

  /// What [request] reports (and what [check] reports afterwards).
  LocationAccess afterRequest;
  GeoFix fix;

  /// Thrown by [currentFix] when set.
  LocationFailure? failure;

  int requests = 0;
  int fixes = 0;
  int openedAppSettings = 0;
  int openedLocationSettings = 0;

  @override
  Future<LocationAccess> check() async => access;

  @override
  Future<LocationAccess> request() async {
    requests++;
    access = afterRequest;
    return afterRequest;
  }

  @override
  Future<GeoFix> currentFix({Duration timeLimit = const Duration(seconds: 20)}) async {
    fixes++;
    final f = failure;
    if (f != null) throw f;
    return fix;
  }

  @override
  Future<bool> openAppSettings() async {
    openedAppSettings++;
    return true;
  }

  @override
  Future<bool> openLocationSettings() async {
    openedLocationSettings++;
    return true;
  }
}

/// A fixed device time zone.
class FakeDeviceTimeZone implements DeviceTimeZoneSource {
  FakeDeviceTimeZone(this.zone);

  final String? zone;

  @override
  Future<String?> currentZone() async => zone;
}

/// The real offline city list, read from the asset file.
CityDatabase loadTestCities() => CityDatabase.parse(File('assets/geo/cities.json').readAsStringSync());

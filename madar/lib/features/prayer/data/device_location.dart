import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:geolocator/geolocator.dart';

import '../domain/location.dart';

/// [LocationSource] over geolocator (coarse accuracy: prayer times need a
/// few kilometres at most, and coarse keeps the battery and privacy cost
/// low). Needs `ACCESS_COARSE_LOCATION` in the Android manifest.
class GeolocatorLocationSource implements LocationSource {
  const GeolocatorLocationSource();

  @override
  Future<LocationAccess> check() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return LocationAccess.serviceDisabled;
      return _map(await Geolocator.checkPermission());
    } on MissingPluginException {
      return LocationAccess.unsupported;
    } on PlatformException {
      return LocationAccess.unsupported;
    }
  }

  @override
  Future<LocationAccess> request() async {
    try {
      final p = await Geolocator.requestPermission();
      final access = _map(p);
      if (access != LocationAccess.granted) return access;
      if (!await Geolocator.isLocationServiceEnabled()) return LocationAccess.serviceDisabled;
      return access;
    } on MissingPluginException {
      return LocationAccess.unsupported;
    } on PermissionDefinitionsNotFoundException {
      return LocationAccess.unsupported;
    } on PlatformException {
      return LocationAccess.unsupported;
    }
  }

  @override
  Future<GeoFix> currentFix({Duration timeLimit = const Duration(seconds: 20)}) async {
    try {
      final p = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(accuracy: LocationAccuracy.low, timeLimit: timeLimit),
      );
      return GeoFix(latitude: p.latitude, longitude: p.longitude, accuracyMeters: p.accuracy, at: p.timestamp);
    } on TimeoutException {
      // Indoors a fresh fix can take long: the last known one is still a
      // good answer for prayer times.
      final last = await _lastKnown();
      if (last != null) return last;
      throw const LocationFailure(null, 'timeout');
    } on LocationServiceDisabledException {
      throw const LocationFailure(LocationAccess.serviceDisabled);
    } on PermissionDeniedException {
      throw const LocationFailure(LocationAccess.denied);
    } on MissingPluginException {
      throw const LocationFailure(LocationAccess.unsupported);
    } on PlatformException catch (e) {
      throw LocationFailure(null, e.message);
    }
  }

  Future<GeoFix?> _lastKnown() async {
    try {
      final p = await Geolocator.getLastKnownPosition();
      if (p == null) return null;
      return GeoFix(latitude: p.latitude, longitude: p.longitude, accuracyMeters: p.accuracy, at: p.timestamp);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<bool> openAppSettings() async {
    try {
      return await Geolocator.openAppSettings();
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> openLocationSettings() async {
    try {
      return await Geolocator.openLocationSettings();
    } catch (_) {
      return false;
    }
  }

  static LocationAccess _map(LocationPermission p) => switch (p) {
    LocationPermission.always || LocationPermission.whileInUse => LocationAccess.granted,
    LocationPermission.denied => LocationAccess.denied,
    LocationPermission.deniedForever => LocationAccess.deniedForever,
    LocationPermission.unableToDetermine => LocationAccess.unsupported,
  };
}

/// [DeviceTimeZoneSource] over flutter_timezone.
class FlutterDeviceTimeZone implements DeviceTimeZoneSource {
  const FlutterDeviceTimeZone();

  @override
  Future<String?> currentZone() async {
    try {
      return (await FlutterTimezone.getLocalTimezone()).identifier;
    } catch (_) {
      return null;
    }
  }
}

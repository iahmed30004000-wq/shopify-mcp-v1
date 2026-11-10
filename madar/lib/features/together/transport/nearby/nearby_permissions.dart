/// The runtime permissions Google Nearby Connections needs, by Android
/// version, and the flow that asks for them (after Madar's own rationale).
///
/// | Android            | runtime permissions asked                                     |
/// |--------------------|---------------------------------------------------------------|
/// | 8 – 11 (API 26–30) | location (fine + coarse); location services must be on         |
/// | 12, 12L (31–32)    | nearby devices (Bluetooth scan / advertise / connect) + location |
/// | 13+ (33+)          | nearby devices (Bluetooth scan / advertise / connect + Wi-Fi)  |
///
/// Madar never reads the location: Android ties Bluetooth and Wi-Fi scans to
/// it on those versions. BLUETOOTH_SCAN and NEARBY_WIFI_DEVICES are declared
/// `neverForLocation`.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart' show Geolocator;
import 'package:permission_handler/permission_handler.dart';

import '../pairing_state.dart';

/// What [NearbyPermissions.check] found.
enum NearbyPermissionStatus {
  granted,

  /// Not granted yet (the rationale, then the system dialog).
  needed,

  /// Refused with "don't ask again": only the app's settings page can grant
  /// it.
  permanentlyDenied,

  /// Granted, but location services are off where Android needs them for
  /// scans (Android 12L and older).
  serviceOff,
}

/// Android's version, from the app's own channel (`madar/together_nearby`,
/// `sdkInt`). Unknown (tests, desktop): the newest rules apply.
class TogetherPlatformInfo {
  const TogetherPlatformInfo([this.channel = const MethodChannel('madar/together_nearby')]);

  final MethodChannel channel;

  static const int unknownSdk = 36;

  Future<int> sdkInt() async {
    try {
      return await channel.invokeMethod<int>('sdkInt') ?? unknownSdk;
    } on MissingPluginException {
      return unknownSdk;
    } on PlatformException {
      return unknownSdk;
    }
  }
}

/// The permissions of one Android version.
@immutable
final class NearbyPermissionPlan {
  const NearbyPermissionPlan(this.sdkInt);

  final int sdkInt;

  /// BLUETOOTH_SCAN / ADVERTISE / CONNECT (Android 12+).
  bool get bluetooth => sdkInt >= 31;

  /// NEARBY_WIFI_DEVICES (Android 13+).
  bool get wifiDevices => sdkInt >= 33;

  /// ACCESS_FINE_LOCATION (+ coarse): Android 12L and older.
  bool get location => sdkInt <= 32;

  NearbyPermissionNeed get need => bluetooth
      ? (location ? NearbyPermissionNeed.nearbyDevicesAndLocation : NearbyPermissionNeed.nearbyDevices)
      : NearbyPermissionNeed.location;

  List<Permission> get permissions => [
    if (bluetooth) ...[Permission.bluetoothScan, Permission.bluetoothAdvertise, Permission.bluetoothConnect],
    if (wifiDevices) Permission.nearbyWifiDevices,
    if (location) Permission.location,
  ];
}

/// Checks and asks for what [NearbyPermissionPlan] lists.
abstract class NearbyPermissions {
  /// The need the rationale explains on this phone.
  Future<NearbyPermissionNeed> need();

  Future<NearbyPermissionStatus> check();

  /// Shows Android's dialog(s); the status afterwards.
  Future<NearbyPermissionStatus> request();

  Future<void> openAppSettings();

  Future<void> openLocationSettings();
}

/// [NearbyPermissions] over permission_handler.
class PermissionHandlerNearbyPermissions implements NearbyPermissions {
  const PermissionHandlerNearbyPermissions({this.platform = const TogetherPlatformInfo()});

  final TogetherPlatformInfo platform;

  Future<NearbyPermissionPlan> _plan() async => NearbyPermissionPlan(await platform.sdkInt());

  @override
  Future<NearbyPermissionNeed> need() async => (await _plan()).need;

  @override
  Future<NearbyPermissionStatus> check() async {
    final plan = await _plan();
    final statuses = [for (final p in plan.permissions) await p.status];
    return _summarise(plan, statuses);
  }

  @override
  Future<NearbyPermissionStatus> request() async {
    final plan = await _plan();
    final result = await plan.permissions.request();
    return _summarise(plan, result.values.toList());
  }

  Future<NearbyPermissionStatus> _summarise(NearbyPermissionPlan plan, List<PermissionStatus> statuses) async {
    if (statuses.any((s) => s.isPermanentlyDenied || s.isRestricted)) return NearbyPermissionStatus.permanentlyDenied;
    if (!statuses.every((s) => s.isGranted || s.isLimited)) return NearbyPermissionStatus.needed;
    if (plan.location && await Permission.location.serviceStatus == ServiceStatus.disabled) {
      return NearbyPermissionStatus.serviceOff;
    }
    return NearbyPermissionStatus.granted;
  }

  @override
  Future<void> openAppSettings() async {
    await _openAppSettingsPage();
  }

  @override
  Future<void> openLocationSettings() async {
    await Geolocator.openLocationSettings();
  }
}

/// permission_handler's top-level `openAppSettings` (named apart from the
/// interface method).
Future<bool> _openAppSettingsPage() => openAppSettings();

/// Runs [NearbyPermissions]' system dialogs and settings pages through a
/// suspend runner – the app lock's `whileSuspended`, so Android's dialog
/// neither shows the privacy cover nor locks the app on return.
class SuspendingNearbyPermissions implements NearbyPermissions {
  SuspendingNearbyPermissions(this.inner, this.suspend);

  final NearbyPermissions inner;
  final Future<T> Function<T>(Future<T> Function() action) suspend;

  @override
  Future<NearbyPermissionNeed> need() => inner.need();

  @override
  Future<NearbyPermissionStatus> check() => inner.check();

  @override
  Future<NearbyPermissionStatus> request() => suspend(inner.request);

  @override
  Future<void> openAppSettings() => suspend(inner.openAppSettings);

  @override
  Future<void> openLocationSettings() => suspend(inner.openLocationSettings);
}

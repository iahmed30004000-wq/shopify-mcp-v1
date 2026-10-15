import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/cities.dart';
import '../domain/location.dart';
import 'prayer_providers.dart';
import 'prayer_settings_controller.dart';

/// Steps of the "use my current location" flow.
enum LocationFlowStage {
  /// Nothing asked yet.
  idle,

  /// Explaining why before the system dialog (permission not granted yet).
  rationale,

  /// The system permission dialog is showing.
  requesting,

  /// Waiting for a position fix.
  locating,

  /// A fix was stored.
  located,

  /// The user declined (asking again is possible).
  denied,

  /// Declined for good – only the system settings can grant it.
  deniedForever,

  /// Location services are off.
  serviceDisabled,

  /// No location support here.
  unsupported,

  /// No fix (timeout, weak signal).
  failed,
}

@immutable
class LocationFlowState {
  const LocationFlowState(this.stage, {this.fix, this.nearest});

  final LocationFlowStage stage;
  final GeoFix? fix;
  final NearestCity? nearest;

  bool get busy => stage == LocationFlowStage.requesting || stage == LocationFlowStage.locating;
}

/// The permission + positioning state machine behind the location sheet:
/// check → rationale → request → locate, with graceful denied,
/// permanently-denied, services-off and failure states (each offers the
/// manual city picker). A successful fix is written through
/// [PrayerSettingsController.setFix] with the nearest city's names and the
/// device's time zone.
class LocationFlowController extends Notifier<LocationFlowState> {
  @override
  LocationFlowState build() => const LocationFlowState(LocationFlowStage.idle);

  LocationSource get _source => ref.read(locationSourceProvider);

  /// "Use my current location": locates at once when permitted, otherwise
  /// explains first (or reports why it cannot).
  Future<void> start() async {
    if (state.busy) return;
    final access = await _source.check();
    if (!ref.mounted) return;
    switch (access) {
      case LocationAccess.granted:
        await _locate();
      case LocationAccess.denied:
        state = const LocationFlowState(LocationFlowStage.rationale);
      case LocationAccess.deniedForever:
        state = const LocationFlowState(LocationFlowStage.deniedForever);
      case LocationAccess.serviceDisabled:
        state = const LocationFlowState(LocationFlowStage.serviceDisabled);
      case LocationAccess.unsupported:
        state = const LocationFlowState(LocationFlowStage.unsupported);
    }
  }

  /// After the rationale: shows the system dialog, then locates.
  Future<void> allow() async {
    if (state.busy) return;
    state = const LocationFlowState(LocationFlowStage.requesting);
    final access = await _source.request();
    if (!ref.mounted) return;
    switch (access) {
      case LocationAccess.granted:
        await _locate();
      case LocationAccess.denied:
        state = const LocationFlowState(LocationFlowStage.denied);
      case LocationAccess.deniedForever:
        state = const LocationFlowState(LocationFlowStage.deniedForever);
      case LocationAccess.serviceDisabled:
        state = const LocationFlowState(LocationFlowStage.serviceDisabled);
      case LocationAccess.unsupported:
        state = const LocationFlowState(LocationFlowStage.unsupported);
    }
  }

  /// Back from the system settings: re-checks quietly and continues when
  /// the problem is gone.
  Future<void> recheck() async {
    if (state.stage != LocationFlowStage.deniedForever && state.stage != LocationFlowStage.serviceDisabled) return;
    final access = await _source.check();
    if (!ref.mounted) return;
    if (access == LocationAccess.granted) {
      await _locate();
    } else if (access == LocationAccess.denied) {
      state = const LocationFlowState(LocationFlowStage.rationale);
    }
  }

  Future<bool> openAppSettings() => _source.openAppSettings();

  Future<bool> openLocationSettings() => _source.openLocationSettings();

  void reset() => state = const LocationFlowState(LocationFlowStage.idle);

  Future<void> _locate() async {
    state = const LocationFlowState(LocationFlowStage.locating);
    try {
      final fix = await _source.currentFix();
      if (!ref.mounted) return;
      NearestCity? nearest;
      try {
        final db = await ref.read(cityDatabaseProvider.future);
        nearest = db.nearest(fix.latitude, fix.longitude);
      } catch (_) {
        nearest = null;
      }
      final zone = await ref.read(deviceTimeZoneProvider).currentZone();
      if (!ref.mounted) return;
      await ref.read(prayerSettingsControllerProvider.notifier).setFix(fix, nearest: nearest, deviceZone: zone);
      if (!ref.mounted) return;
      state = LocationFlowState(LocationFlowStage.located, fix: fix, nearest: nearest);
    } on LocationFailure catch (f) {
      if (!ref.mounted) return;
      state = LocationFlowState(switch (f.access) {
        LocationAccess.denied => LocationFlowStage.denied,
        LocationAccess.deniedForever => LocationFlowStage.deniedForever,
        LocationAccess.serviceDisabled => LocationFlowStage.serviceDisabled,
        LocationAccess.unsupported => LocationFlowStage.unsupported,
        _ => LocationFlowStage.failed,
      });
    } catch (_) {
      if (!ref.mounted) return;
      state = const LocationFlowState(LocationFlowStage.failed);
    }
  }
}

final locationFlowProvider = NotifierProvider.autoDispose<LocationFlowController, LocationFlowState>(
  LocationFlowController.new,
);

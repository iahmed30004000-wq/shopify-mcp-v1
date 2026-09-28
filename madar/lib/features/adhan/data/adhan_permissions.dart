import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/notifications/notification_service.dart';
import 'adhan_system.dart';

/// What the adhan needs from Android, in the order the card asks for it.
enum AdhanPermission {
  /// POST_NOTIFICATIONS (Android 13+) – without it nothing sounds.
  notifications,

  /// Exact alarms – the adhan at the exact minute (not minutes late).
  exactAlarms,

  /// Full-screen intents (Android 14+) – the adhan screen over the lock
  /// screen.
  fullScreen,

  /// Exemption from battery optimisation – OEM task killers.
  battery,
}

/// Live status of every [AdhanPermission] plus the alarm volume.
@immutable
class AdhanPermissionStatus {
  const AdhanPermissionStatus({required this.granted, this.alarmVolume, this.refused = const {}});

  static const unknown = AdhanPermissionStatus(granted: {});

  final Map<AdhanPermission, bool> granted;
  final AlarmVolume? alarmVolume;

  /// Refused by the user in the system dialog (this session): asking again
  /// opens the system settings page instead – the card says so.
  final Set<AdhanPermission> refused;

  bool isRefused(AdhanPermission p) => !isGranted(p) && refused.contains(p);

  bool isGranted(AdhanPermission p) => granted[p] ?? false;

  /// The adhan can sound at all.
  bool get canNotify => isGranted(AdhanPermission.notifications);

  bool get allGranted => AdhanPermission.values.every(isGranted);

  List<AdhanPermission> get missing => [
    for (final p in AdhanPermission.values)
      if (!isGranted(p)) p,
  ];

  bool get alarmMuted => alarmVolume?.muted ?? false;

  @override
  bool operator ==(Object other) =>
      other is AdhanPermissionStatus &&
      mapEquals(other.granted, granted) &&
      setEquals(other.refused, refused) &&
      other.alarmVolume?.current == alarmVolume?.current &&
      other.alarmVolume?.max == alarmVolume?.max;

  @override
  int get hashCode => Object.hash(
    Object.hashAllUnordered(granted.entries.map((e) => '${e.key}${e.value}')),
    Object.hashAllUnordered(refused),
    alarmVolume?.current,
  );
}

/// Battery-optimisation exemption (permission_handler in production).
abstract interface class BatteryOptimizationGate {
  Future<bool> isExempt();

  /// Shows the system dialog; true if exempt afterwards.
  Future<bool> requestExemption();
}

class PermissionHandlerBatteryGate implements BatteryOptimizationGate {
  const PermissionHandlerBatteryGate();

  bool get _android => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  Future<bool> isExempt() async {
    if (!_android) return true;
    try {
      return await Permission.ignoreBatteryOptimizations.isGranted;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> requestExemption() async {
    if (!_android) return true;
    try {
      return (await Permission.ignoreBatteryOptimizations.request()).isGranted;
    } catch (_) {
      return false;
    }
  }
}

/// Test double.
class FakeBatteryGate implements BatteryOptimizationGate {
  FakeBatteryGate({this.exempt = false, this.grantOnRequest = true});

  bool exempt;
  bool grantOnRequest;
  int requests = 0;

  /// Runs while the exemption is being asked (see
  /// `FakeNotificationPlatform.onRequestNotifications`).
  void Function()? onRequest;

  @override
  Future<bool> isExempt() async => exempt;

  @override
  Future<bool> requestExemption() async {
    requests++;
    onRequest?.call();
    if (grantOnRequest) exempt = true;
    return exempt;
  }
}

/// Checks and requests everything the adhan needs, gracefully: a denied
/// permission is reported, never thrown.
///
/// A "Don't allow" in a system dialog is respected: the settings page is
/// not thrown at the user right after it; the card offers it instead, and
/// the next request opens it. Only when Android can no longer show the
/// dialog at all (it answers at once – permanently denied) does a request go
/// straight to the settings page.
class AdhanPermissions {
  AdhanPermissions({
    required this.notifications,
    required this.system,
    required this.battery,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final NotificationService notifications;
  final AdhanSystem system;
  final BatteryOptimizationGate battery;
  final DateTime Function() _clock;

  /// A dialog answered faster than this was never shown (no person reads and
  /// answers a permission dialog in under half a second).
  static const dialogShownAfter = Duration(milliseconds: 500);

  final Set<AdhanPermission> _refused = {};

  Future<AdhanPermissionStatus> check() async {
    Future<bool> safe(Future<bool> Function() f) async {
      try {
        return await f();
      } catch (_) {
        return false;
      }
    }

    final results = await Future.wait([
      safe(notifications.notificationsEnabled),
      safe(notifications.canScheduleExact),
      safe(system.canUseFullScreenIntent),
      safe(battery.isExempt),
    ]);
    AlarmVolume? volume;
    try {
      volume = await system.alarmVolume();
    } catch (_) {}
    final granted = {
      AdhanPermission.notifications: results[0],
      AdhanPermission.exactAlarms: results[1],
      AdhanPermission.fullScreen: results[2],
      AdhanPermission.battery: results[3],
    };
    _refused.removeWhere((p) => granted[p] ?? false);
    return AdhanPermissionStatus(granted: granted, alarmVolume: volume, refused: Set.unmodifiable(_refused));
  }

  /// Asks through the system dialog [ask]; if it is refused, remembers that
  /// (the next request opens [openSettings]) – unless no dialog could be
  /// shown, then [openSettings] right away. Returns [isGranted] afterwards.
  Future<bool> _askOrOpen(
    AdhanPermission p, {
    required Future<bool> Function() ask,
    required Future<bool> Function() openSettings,
    required Future<bool> Function() isGranted,
  }) async {
    if (_refused.contains(p)) {
      await openSettings();
      return isGranted();
    }
    final asked = _clock();
    if (await ask()) {
      _refused.remove(p);
      return true;
    }
    if (_clock().difference(asked) >= dialogShownAfter) {
      _refused.add(p);
      return false;
    }
    await openSettings();
    return isGranted();
  }

  /// Asks for [p] (dialog or system settings page); true if granted now.
  /// Settings pages report back only when the user returns – the card
  /// re-checks on resume.
  Future<bool> request(AdhanPermission p) async {
    try {
      switch (p) {
        case AdhanPermission.notifications:
          return await _askOrOpen(
            p,
            ask: notifications.requestNotifications,
            openSettings: system.openNotificationSettings,
            isGranted: notifications.notificationsEnabled,
          );
        case AdhanPermission.exactAlarms:
          return await notifications.requestExactAlarms();
        case AdhanPermission.fullScreen:
          if (await system.canUseFullScreenIntent()) return true;
          if (await notifications.requestFullScreenIntent()) return true;
          return await system.canUseFullScreenIntent();
        case AdhanPermission.battery:
          return await _askOrOpen(
            p,
            ask: battery.requestExemption,
            openSettings: system.openBatterySettings,
            isGranted: battery.isExempt,
          );
      }
    } catch (e) {
      debugPrint('AdhanPermissions.request($p) failed: $e');
      return false;
    }
  }
}

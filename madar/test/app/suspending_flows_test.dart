// System flows the app opens itself (permission dialogs, system settings,
// pickers) run inside the app lock's `whileSuspended`: no privacy cover over
// the dialog, no time-out lock for the trip.
import 'dart:ui' show AppLifecycleState;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/app/suspending_flows.dart';
import 'package:madar/core/notifications/notifications.dart';
import 'package:madar/core/settings/app_settings.dart';
import 'package:madar/features/adhan/adhan.dart';
import 'package:madar/features/lock/application/lock_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/lock/lock_test_utils.dart';
import '../features/prayer/fakes.dart';

/// Records which calls ran suspended.
class _Recorder {
  final List<String> suspended = [];
  int depth = 0;
  String? current;

  SuspendRunner runner(String Function() name) => <T>(action) async {
    depth++;
    suspended.add(name());
    try {
      return await action();
    } finally {
      depth--;
    }
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('notifications: permission requests suspended, the rest passes through', () async {
    final fake = FakeNotificationPlatform(enabled: false);
    var calls = 0;
    final platform = SuspendingNotificationPlatform(fake, <T>(action) {
      calls++;
      return action();
    });
    await platform.requestNotifications();
    await platform.requestExactAlarms();
    await platform.requestFullScreenIntent();
    expect(calls, 3);
    expect(fake.requestNotificationsCalls, 1);
    await platform.initialize(onTap: (_) {});
    await platform.pending();
    await platform.notificationsEnabled();
    await platform.canScheduleExact();
    expect(calls, 3, reason: 'no dialog, nothing suspended');
    expect(fake.initialized, isTrue);
  });

  test('battery, adhan settings pages, location and the muezzin picker are suspended', () async {
    final r = _Recorder();
    var name = '';
    final run = r.runner(() => name);
    final battery = SuspendingBatteryGate(FakeBatteryGate(), run);
    name = 'battery';
    await battery.requestExemption();
    await battery.isExempt();

    final system = SuspendingAdhanSystem(FakeAdhanSystem(), run);
    name = 'sound';
    await system.openSoundSettings();
    name = 'channel';
    await system.openNotificationSettings(channelId: 'x');
    name = 'fullscreen';
    await system.openFullScreenIntentSettings();
    name = 'battery page';
    await system.openBatterySettings();
    await system.isKeyguardLocked();
    await system.setLockScreenMode(false);

    final location = SuspendingLocationSource(FakeLocationSource(), run);
    name = 'location';
    await location.request();
    name = 'app settings';
    await location.openAppSettings();
    name = 'location settings';
    await location.openLocationSettings();
    await location.check();

    expect(r.suspended, [
      'battery',
      'sound',
      'channel',
      'fullscreen',
      'battery page',
      'location',
      'app settings',
      'location settings',
    ]);
  });

  test('the lock suspender keeps the privacy cover off while a system dialog is up', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final fx = await LockFixture.configured(biometrics: false);
    final c = ProviderContainer(overrides: [sharedPreferencesProvider.overrideWithValue(prefs), ...fx.overrides]);
    addTearDown(c.dispose);
    final lock = c.read(lockControllerProvider.notifier);
    await lock.load();
    await lock.checkPin('2580');
    lock.revealed(); // the lock screen's door has opened
    expect(c.read(lockControllerProvider).covered, isFalse);

    final suspend = c.read(Provider((ref) => lockSuspender(ref)));
    await suspend(() async {
      // Android's dialog takes the focus: inactive.
      lock.onLifecycle(AppLifecycleState.inactive);
      expect(c.read(lockControllerProvider).shielded, isFalse, reason: 'our own dialog: no cover');
      lock.onLifecycle(AppLifecycleState.resumed);
    });
    lock.onLifecycle(AppLifecycleState.inactive);
    expect(c.read(lockControllerProvider).shielded, isTrue, reason: 'the notification shade: covered');
    lock.onLifecycle(AppLifecycleState.resumed);
  });

  test('the production overrides cover every flow', () {
    final overrides = suspendingFlowOverrides();
    expect(overrides, hasLength(7));
  });
}

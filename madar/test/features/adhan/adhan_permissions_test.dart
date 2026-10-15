import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/notifications/notifications.dart';
import 'package:madar/features/adhan/adhan.dart';

void main() {
  late DateTime now;
  late FakeNotificationPlatform platform;
  late FakeAdhanSystem system;
  late FakeBatteryGate battery;
  late AdhanPermissions permissions;

  setUp(() {
    now = DateTime(2026, 9, 28, 10);
    platform = FakeNotificationPlatform(enabled: false);
    system = FakeAdhanSystem();
    battery = FakeBatteryGate(grantOnRequest: false);
    permissions = AdhanPermissions(
      notifications: NotificationService(platform),
      system: system,
      battery: battery,
      clock: () => now,
    );
  });

  // A person reads the system dialog and taps "Don't allow".
  void readsTheDialog() => now = now.add(const Duration(seconds: 3));

  group('notifications', () {
    test('a refusal in the system dialog is respected – no settings page thrown at the user', () async {
      platform.onRequestNotifications = readsTheDialog;
      expect(await permissions.request(AdhanPermission.notifications), isFalse);
      expect(system.opened, isEmpty);
      final status = await permissions.check();
      expect(status.refused, {AdhanPermission.notifications}, reason: 'the card now offers the settings page');

      // Asking again is the user's own choice: now the settings page opens.
      expect(await permissions.request(AdhanPermission.notifications), isFalse);
      expect(system.opened, ['notifications:']);
    });

    test('no dialog possible any more (answered instantly) → the settings page at once', () async {
      expect(await permissions.request(AdhanPermission.notifications), isFalse);
      expect(system.opened, ['notifications:']);
    });

    test('granted in the dialog', () async {
      platform.onRequestNotifications = () {
        readsTheDialog();
        platform.enabled = true;
      };
      expect(await permissions.request(AdhanPermission.notifications), isTrue);
      expect(system.opened, isEmpty);
      expect((await permissions.check()).refused, isEmpty);
    });
  });

  group('battery optimisation', () {
    test('a refusal in the system dialog is respected, the next tap opens the settings', () async {
      battery.onRequest = readsTheDialog;
      expect(await permissions.request(AdhanPermission.battery), isFalse);
      expect(system.opened, isEmpty);
      expect((await permissions.check()).refused, {AdhanPermission.battery});
      expect(await permissions.request(AdhanPermission.battery), isFalse);
      expect(system.opened, ['battery']);
    });

    test('no dialog possible → the settings page at once', () async {
      expect(await permissions.request(AdhanPermission.battery), isFalse);
      expect(system.opened, ['battery']);
    });
  });
}

// Startup warm-up after the first frame: the time-zone database and the
// notifications plugin – each step failing on its own without taking the app
// down.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/app/app_services.dart';
import 'package:madar/core/notifications/notifications.dart';
import 'package:madar/features/adhkar/adhkar.dart' show AdhkarCategoryId;
import 'package:timezone/timezone.dart' as tz;

class _Broken extends FakeNotificationPlatform {
  @override
  Future<void> initialize({required void Function(RawNotificationTap tap) onTap}) async =>
      throw StateError('plugin missing');
}

NotificationTap _tap(String namespace, Map<String, Object?> data) =>
    NotificationTap(id: 1, namespace: namespace, data: data);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('prepares the time zones and the notifications plugin', () async {
    final platform = FakeNotificationPlatform();
    final c = ProviderContainer(overrides: [notificationPlatformProvider.overrideWithValue(platform)]);
    addTearDown(c.dispose);
    await warmUpServices(c);
    expect(platform.initialized, isTrue);
    expect(tz.timeZoneDatabase.locations.containsKey('Asia/Amman'), isTrue);
  });

  test('a broken notifications plugin is survived', () async {
    final c = ProviderContainer(overrides: [notificationPlatformProvider.overrideWithValue(_Broken())]);
    addTearDown(c.dispose);
    await expectLater(warmUpServices(c), completes);
    // The service still answers (nothing launched the app).
    expect(await c.read(notificationServiceProvider).takeLaunchTap(), isNull);
  });

  test('taps the app shell routes: adhkar reminders only', () {
    expect(
      AppNotificationRouter.locationOf(_tap(NotificationNamespaces.adhkar.name, {'set': 'morning'})),
      '/adhkar/${AdhkarCategoryId.morning.name}',
    );
    expect(AppNotificationRouter.locationOf(_tap(NotificationNamespaces.adhkar.name, {'set': 'nonsense'})), isNull);
    expect(AppNotificationRouter.locationOf(_tap(NotificationNamespaces.adhan.name, {'k': 'adhan'})), isNull);
  });

  test('the launch notification goes to the feature that claims it, once', () async {
    final platform = FakeNotificationPlatform(launch: const RawNotificationTap(id: 1, payload: null, fromLaunch: true));
    final service = NotificationService(platform);
    addTearDown(service.dispose);
    // A foreign / empty payload: nobody's.
    expect(await service.takeLaunchTap(where: (t) => t.namespace == 'adhan'), isNull);
    expect(await service.takeLaunchTap(), isNotNull, reason: 'unclaimed taps stay for a claim-all reader');
    expect(await service.takeLaunchTap(), isNull, reason: 'only once');
  });
}

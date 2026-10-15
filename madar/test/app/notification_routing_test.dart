// Notifications into the running app, end to end (router, database gate,
// adhan host, app lock):
// * an adhan that launched the app (cold start) or is tapped (warm) shows the
//   full-screen adhan – above the app lock, with nothing personal behind it;
// * an adhkar reminder opens its set in the reader, moving the router
//   underneath the lock when Madar is locked;
// * without notifications the app still runs.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/core/notifications/notifications.dart';
import 'package:madar/core/routing/router.dart';
import 'package:madar/core/settings/app_settings.dart';
import 'package:madar/features/adhan/adhan.dart';
import 'package:madar/features/adhan/presentation/adhan_settings_screen.dart';
import 'package:madar/features/adhkar/adhkar.dart';
import 'package:madar/features/home/home_screen.dart';
import 'package:madar/features/lock/application/lock_controller.dart';
import 'package:madar/features/lock/domain/lock_session.dart';
import 'package:madar/features/lock/presentation/lock_screen.dart';
import 'package:madar/features/orbit/domain/prayer_schedule.dart';

import '../features/lock/lock_test_utils.dart';
import '../helpers/test_app.dart';

final _en = lookupL10n(const Locale('en'));

/// Today's Maghrib for the default location (as the app computes it).
final DateTime _maghrib = PrayerSchedule(const PrayerSettings()).timesFor(DateTime(2026, 9, 28)).maghrib;

AdhanAlarm _alarm() => AdhanAlarm(
  id: AdhanIds.of(DateTime.utc(2026, 9, 28), AdhanKind.adhan, AdhanSlot.maghrib),
  kind: AdhanKind.adhan,
  slot: AdhanSlot.maghrib,
  at: _maghrib,
  prayerAt: _maghrib,
  day: DateTime.utc(2026, 9, 28),
  sound: const AdhanSoundRef.tone(TanbihTone.brass),
);

RawNotificationTap _adhanTap({bool launch = false}) {
  final a = _alarm();
  return RawNotificationTap(
    id: a.id,
    fromLaunch: launch,
    payload: NotificationEnvelope.encode(
      NotificationRequest(
        namespace: NotificationNamespaces.adhan,
        id: a.id,
        channelId: 'madar.adhan.test',
        title: 'Maghrib',
        body: '',
        at: a.at,
        data: AdhanEvent.fromAlarm(a).toData(),
        fullScreen: true,
      ),
    ),
  );
}

RawNotificationTap _adhkarTap(AdhkarCategoryId set, {bool launch = false}) {
  final id = NotificationNamespaces.adhkar.first;
  return RawNotificationTap(
    id: id,
    fromLaunch: launch,
    payload: NotificationEnvelope.encode(
      NotificationRequest(
        namespace: NotificationNamespaces.adhkar,
        id: id,
        channelId: 'madar.adhkar.reminder.1',
        title: 'Adhkar',
        body: '',
        at: _maghrib,
        data: {'set': set.name},
      ),
    ),
  );
}

/// A few seconds into the adhan.
DateTime get _now => _maghrib.add(const Duration(seconds: 4));

Future<void> _frames(WidgetTester tester, [int n = 10]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _typePin(WidgetTester tester, String digits) async {
  for (final c in digits.split('')) {
    await tester.tap(find.bySemanticsLabel(c).last);
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// No notifications plugin at all (e.g. the platform side failed to load).
class _BrokenNotifications extends FakeNotificationPlatform {
  @override
  Future<void> initialize({required void Function(RawNotificationTap tap) onTap}) async =>
      throw StateError('no notifications here');

  @override
  Future<RawNotificationTap?> launchTap() async => throw StateError('no notifications here');

  @override
  Future<List<PendingNotice>> pending() async => throw StateError('no notifications here');
}

void main() {
  const english = AppSettings(onboarded: true, languageCode: 'en');

  group('the adhan', () {
    testWidgets('cold start from its notification: the adhan screen, then the app', (tester) async {
      final app = await pumpMadarApp(
        tester,
        settings: english,
        now: _now,
        notifications: FakeNotificationPlatform(launch: _adhanTap(launch: true)),
        overrides: LockFixture.empty().overrides,
        settle: false,
      );
      await _frames(tester);
      expect(find.byType(AdhanScreen), findsOneWidget);
      expect(app.container.read(adhanEventProvider)?.source, AdhanEventSource.launch);
      // Launched (maybe over the keyguard): nothing of the app is painted.
      expect(find.byType(HomeScreen), findsNothing);
      expect(find.byType(HomeScreen, skipOffstage: false), findsOneWidget);
      // Not routed: the adhan is an overlay above the router.
      expect(app.location, AppRoutes.home);

      await tester.tap(find.text(_en.adhanClose));
      await _frames(tester);
      expect(find.byType(AdhanScreen), findsNothing);
      expect(find.byType(HomeScreen), findsOneWidget, reason: 'the phone is unlocked: the app shows at once');
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('cold start while Madar is locked: the adhan over the lock, and the lock after it', (tester) async {
      final fx = await LockFixture.configured(biometrics: false);
      final app = await pumpMadarApp(
        tester,
        settings: english,
        now: _now,
        notifications: FakeNotificationPlatform(launch: _adhanTap(launch: true)),
        overrides: fx.overrides,
        settle: false,
      );
      await _frames(tester);
      expect(app.container.read(lockControllerProvider).phase, LockPhase.locked, reason: 'cold start locks');
      // The adhan shows above the app lock …
      expect(find.byType(AdhanScreen), findsOneWidget);
      // … and neither the lock screen nor the app behind it is painted.
      expect(find.byType(LockScreen), findsNothing);
      expect(find.byType(HomeScreen), findsNothing);
      expect(find.byType(LockScreen, skipOffstage: false), findsOneWidget);

      await tester.tap(find.text(_en.adhanClose));
      await _frames(tester);
      // The lock is in front again; the app still hidden.
      expect(find.byType(AdhanScreen), findsNothing);
      expect(find.byType(LockScreen), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);

      await _typePin(tester, '2580');
      await tester.pumpAndSettle();
      expect(find.byType(LockScreen), findsNothing);
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('closing an adhan shown over the keyguard keeps the lock screen hidden until the phone unlocks', (
      tester,
    ) async {
      final fx = await LockFixture.configured(biometrics: false);
      final system = FakeAdhanSystem()
        ..lockScreenMode = true
        ..keyguardLocked = true;
      await pumpMadarApp(
        tester,
        settings: english,
        now: _now,
        notifications: FakeNotificationPlatform(launch: _adhanTap(launch: true)),
        adhanSystem: system,
        overrides: fx.overrides,
        settle: false,
      );
      await _frames(tester);
      await tester.tap(find.text(_en.adhanClose));
      await tester.pump();
      expect(system.lockScreenMode, isFalse);
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        expect(find.byType(LockScreen), findsNothing);
        expect(find.byType(HomeScreen), findsNothing);
      }
      system.keyguardLocked = false;
      await _frames(tester, 12);
      expect(find.byType(LockScreen), findsOneWidget, reason: 'unlocked phone: Madar\'s own lock is next');
      expect(find.byType(HomeScreen), findsNothing);
    });

    testWidgets('a tap while Madar is open presents it (muting the app); back closes it', (tester) async {
      // An hour after Maghrib: past the adhan's quiet time, so any prayer
      // mute now comes from the adhan screen itself.
      final app = await pumpMadarApp(
        tester,
        settings: english,
        now: _maghrib.add(const Duration(hours: 1)),
        overrides: LockFixture.empty().overrides,
      );
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(app.sound.prayerMuted, isFalse);
      app.notifications.tap(_adhanTap());
      await _frames(tester);
      expect(find.byType(AdhanScreen), findsOneWidget);
      // The prayer mute reaches the app's sound engine (game music and the
      // ambient bed fall silent while the adhan shows).
      expect(app.sound.prayerMuted, isTrue);
      expect(find.byType(HomeScreen), findsNothing, reason: 'from a notification: the app is not painted behind it');
      await tester.binding.handlePopRoute();
      await _frames(tester);
      expect(find.byType(AdhanScreen), findsNothing);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(app.location, AppRoutes.home);
      expect(app.sound.prayerMuted, isFalse, reason: 'the screen released its mute');
      await tester.pump(const Duration(seconds: 2));
    });
  });

  group('adhkar reminders', () {
    testWidgets('cold start from a reminder opens its set (the adhan hub leaves it alone)', (tester) async {
      final app = await pumpMadarApp(
        tester,
        settings: english,
        now: _now,
        notifications: FakeNotificationPlatform(launch: _adhkarTap(AdhkarCategoryId.evening, launch: true)),
        overrides: LockFixture.empty().overrides,
      );
      expect(app.location, '/adhkar/evening');
      expect(find.byType(AdhkarReaderScreen), findsOneWidget);
      expect(tester.widget<AdhkarReaderScreen>(find.byType(AdhkarReaderScreen)).category, AdhkarCategoryId.evening);
      expect(find.byType(AdhanScreen), findsNothing);
      // Back returns through the adhkar home to home.
      await tester.binding.handlePopRoute();
      await settleApp(tester);
      expect(app.location, AppRoutes.adhkar);
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('a tap while locked moves the router under the lock; the reader shows after unlocking', (tester) async {
      final fx = await LockFixture.configured(biometrics: false);
      final app = await pumpMadarApp(tester, settings: english, now: _now, overrides: fx.overrides);
      expect(find.byType(LockScreen), findsOneWidget);
      app.notifications.tap(_adhkarTap(AdhkarCategoryId.morning));
      await settleApp(tester);
      expect(app.location, '/adhkar/morning');
      expect(find.byType(LockScreen), findsOneWidget, reason: 'a deep link never lifts the lock');
      expect(find.byType(AdhkarReaderScreen), findsNothing);
      expect(find.byType(AdhkarReaderScreen, skipOffstage: false), findsOneWidget);

      await _typePin(tester, '2580');
      await tester.pumpAndSettle();
      expect(find.byType(LockScreen), findsNothing);
      expect(find.byType(AdhkarReaderScreen), findsOneWidget);
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('a tap before onboarding is ignored', (tester) async {
      final app = await pumpMadarApp(
        tester,
        settings: const AppSettings(languageCode: 'en'),
        now: _now,
        overrides: LockFixture.empty().overrides,
      );
      app.notifications.tap(_adhkarTap(AdhkarCategoryId.morning));
      await settleApp(tester);
      expect(app.location, AppRoutes.onboarding);
    });
  });

  testWidgets('without a notifications plugin Madar still starts and runs', (tester) async {
    final app = await pumpMadarApp(
      tester,
      settings: english,
      notifications: _BrokenNotifications(),
      overrides: LockFixture.empty().overrides,
    );
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
    app.router.go(AppRoutes.adhanSettings);
    await settleApp(tester);
    expect(find.byType(AdhanSettingsScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

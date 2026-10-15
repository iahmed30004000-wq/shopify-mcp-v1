import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/notifications/notifications.dart';
import 'package:madar/features/adhan/adhan.dart';
import 'package:madar/features/orbit/domain/prayer_schedule.dart';

import 'adhan_test_app.dart';

DateTime _maghrib() => PrayerSchedule(ammanPrayerSettings).timesFor(DateTime(2026, 9, 28)).maghrib.toUtc();

String _payload(AdhanAlarm a, {NotificationNamespace ns = NotificationNamespaces.adhan}) => NotificationEnvelope.encode(
  NotificationRequest(
    namespace: ns,
    id: ns.contains(a.id) ? a.id : ns.first,
    channelId: 'c',
    title: 't',
    body: 'b',
    at: a.at,
    data: AdhanEvent.fromAlarm(a).toData(),
    fullScreen: true,
  ),
);

AdhanAlarm _alarm(DateTime at, {AdhanSlot slot = AdhanSlot.maghrib}) => AdhanAlarm(
  id: AdhanIds.of(DateTime.utc(2026, 9, 28), AdhanKind.adhan, slot),
  kind: AdhanKind.adhan,
  slot: slot,
  at: at,
  prayerAt: at,
  day: DateTime.utc(2026, 9, 28),
  sound: const AdhanSoundRef.tone(TanbihTone.brass),
);

Future<void> _frames(WidgetTester tester, [int n = 10]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<AdhanHarness> _host(
  WidgetTester tester, {
  required DateTime Function() clock,
  FakeNotificationPlatform? platform,
  FakeAdhanSystem? system,
  AdhanSettings settings = const AdhanSettings(),
  BackButtonDispatcher? back,
}) async {
  tester.view.physicalSize = const Size(412, 915) * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  final h = await buildAdhanTestApp(
    tester,
    home: AdhanHost(backButtonDispatcher: back, child: const Center(child: Text('home'))),
    now: clock(),
    clock: clock,
    platform: platform,
    system: system,
    settings: settings,
  );
  await tester.pumpWidget(h.app);
  await _frames(tester);
  return h;
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  final at = _maghrib();

  testWidgets('the notification that launched the app opens the adhan screen', (tester) async {
    final alarm = _alarm(at);
    final platform = FakeNotificationPlatform(
      launch: RawNotificationTap(id: alarm.id, payload: _payload(alarm), fromLaunch: true),
    );
    final h = await _host(tester, clock: () => at.add(const Duration(seconds: 4)), platform: platform);
    expect(find.byType(AdhanScreen), findsOneWidget);
    expect(find.text('المغرب'), findsOneWidget);
    expect(h.system.lockScreenCalls, isNot(contains(false)), reason: 'the launch keeps its lock-screen mode');
    await tester.tap(find.text('إغلاق'));
    await _frames(tester, 12);
    expect(find.byType(AdhanScreen), findsNothing);
    expect(find.text('home'), findsOneWidget);
    expect(h.system.lockScreenMode, isFalse);
    await _unmount(tester);
  });

  testWidgets('a tap while running opens it; "Stop" from the shade and foreign taps do not', (tester) async {
    final h = await _host(tester, clock: () => at.add(const Duration(seconds: 4)));
    expect(find.byType(AdhanScreen), findsNothing);
    final alarm = _alarm(at);

    h.platform.tap(RawNotificationTap(id: alarm.id, actionId: AdhanActions.stop, payload: _payload(alarm)));
    await _frames(tester);
    expect(find.byType(AdhanScreen), findsNothing);

    h.platform.tap(RawNotificationTap(id: 1, payload: _payload(alarm, ns: NotificationNamespaces.adhkar)));
    await _frames(tester);
    expect(find.byType(AdhanScreen), findsNothing);

    h.platform.tap(RawNotificationTap(id: alarm.id, payload: _payload(alarm)));
    await _frames(tester);
    expect(find.byType(AdhanScreen), findsOneWidget);
    await _unmount(tester);
  });

  testWidgets('with Madar open, the adhan time itself brings the screen and the quiet', (tester) async {
    var now = at.subtract(const Duration(seconds: 3));
    final h = await _host(tester, clock: () => now);
    // The alarms were planned (the host keeps them in sync).
    expect(h.platform.scheduled.values.any((s) => s.request.at.isAtSameMomentAs(at)), isTrue);
    expect(find.byType(AdhanScreen), findsNothing);
    expect(h.sound.prayerMuted, isFalse);

    now = at.add(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 3));
    await _frames(tester);
    expect(find.byType(AdhanScreen), findsOneWidget);
    expect(h.sound.prayerMuted, isTrue, reason: 'game music and ambience fall silent');
    expect(h.audio.played, isEmpty, reason: 'the notification sounds, not the app');

    // Closing the screen keeps the prayer quiet going (20 minutes).
    await tester.tap(find.text('إغلاق'));
    await _frames(tester, 12);
    expect(find.byType(AdhanScreen), findsNothing);
    expect(h.sound.prayerMuted, isTrue);

    now = at.add(const Duration(minutes: 21));
    await tester.pump(const Duration(minutes: 21));
    await _frames(tester);
    expect(h.sound.prayerMuted, isFalse);
    await _unmount(tester);
  });

  testWidgets('notifications off while open → the adhan plays in the app', (tester) async {
    var now = at.subtract(const Duration(seconds: 2));
    final h = await _host(tester, clock: () => now, platform: FakeNotificationPlatform(enabled: false));
    now = at.add(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 2));
    await _frames(tester);
    expect(find.byType(AdhanScreen), findsOneWidget);
    expect(h.audio.played, [const AdhanSoundRef.tone(TanbihTone.brass)]);
    await _unmount(tester);
  });

  testWidgets('full-screen off: no takeover while open', (tester) async {
    var now = at.subtract(const Duration(seconds: 2));
    await _host(tester, clock: () => now, settings: const AdhanSettings(fullScreen: false));
    now = at.add(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 2));
    await _frames(tester);
    expect(find.byType(AdhanScreen), findsNothing);
    await _unmount(tester);
  });

  group('lock screen', () {
    testWidgets('an app start without an adhan to show releases a lock-screen mode left behind', (tester) async {
      // E.g. Android re-created the activity from recents with the old
      // full-screen intent: the plugin reports no launch, so no adhan screen
      // would ever clear the mode.
      final system = FakeAdhanSystem()..lockScreenMode = true;
      final h = await _host(tester, clock: () => at.add(const Duration(minutes: 30)), system: system);
      expect(find.byType(AdhanScreen), findsNothing);
      expect(find.text('home'), findsOneWidget);
      expect(h.system.lockScreenMode, isFalse);
      await _unmount(tester);
    });

    testWidgets('a new adhan over one still open keeps the lock-screen mode of its launch', (tester) async {
      final dhuhr = PrayerSchedule(ammanPrayerSettings).timesFor(DateTime(2026, 9, 28)).dhuhr.toUtc();
      final asr = PrayerSchedule(ammanPrayerSettings).timesFor(DateTime(2026, 9, 28)).asr.toUtc();
      var now = dhuhr.add(const Duration(seconds: 5));
      final h = await _host(tester, clock: () => now);
      final a = _alarm(dhuhr, slot: AdhanSlot.dhuhr);
      h.platform.tap(RawNotificationTap(id: a.id, payload: _payload(a)));
      await _frames(tester);
      expect(find.text('الظهر'), findsOneWidget);

      // Hours later, still open: the Asr adhan launches full-screen over the
      // lock screen (MainActivity turns the mode on before Dart hears of it).
      now = asr.add(const Duration(seconds: 2));
      h.system.lockScreenMode = true;
      final b = _alarm(asr, slot: AdhanSlot.asr);
      h.platform.tap(RawNotificationTap(id: b.id, payload: _payload(b)));
      await _frames(tester, 20);
      expect(find.text('العصر'), findsOneWidget);
      expect(find.text('الظهر'), findsNothing);
      expect(h.system.lockScreenMode, isTrue, reason: 'the Dhuhr screen leaving must not hide the Asr adhan');
      await _unmount(tester);
    });

    testWidgets('closing an adhan shown over the lock screen never reveals the app there', (tester) async {
      final alarm = _alarm(at);
      final system = FakeAdhanSystem()
        ..lockScreenMode = true
        ..keyguardLocked = true;
      final h = await _host(
        tester,
        clock: () => at.add(const Duration(seconds: 4)),
        system: system,
        platform: FakeNotificationPlatform(
          launch: RawNotificationTap(id: alarm.id, payload: _payload(alarm), fromLaunch: true),
        ),
      );
      expect(find.byType(AdhanScreen), findsOneWidget);
      expect(find.text('home'), findsNothing);

      await tester.tap(find.text('إغلاق'));
      await tester.pump();
      expect(h.system.lockScreenMode, isFalse);
      // Not a single frame of the app while the keyguard is still up.
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        expect(find.text('home'), findsNothing);
      }

      // The window drops behind the keyguard; the owner unlocks and returns.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await _frames(tester, 3);
      h.system.keyguardLocked = false;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await _frames(tester, 5);
      expect(find.text('home'), findsOneWidget);
      await _unmount(tester);
    });

    testWidgets('closing it on an unlocked phone shows the app at once', (tester) async {
      final alarm = _alarm(at);
      final h = await _host(tester, clock: () => at.add(const Duration(seconds: 4)));
      h.platform.tap(RawNotificationTap(id: alarm.id, payload: _payload(alarm)));
      await _frames(tester);
      expect(find.byType(AdhanScreen), findsOneWidget);
      await tester.tap(find.text('إغلاق'));
      await _frames(tester, 12);
      expect(find.byType(AdhanScreen), findsNothing);
      expect(find.text('home'), findsOneWidget);
      await _unmount(tester);
    });
  });

  testWidgets('the back button closes the adhan, never the hidden app page beneath it', (tester) async {
    // The router's dispatcher, with the app's own back handling (pop a page).
    final root = RootBackButtonDispatcher();
    var appPops = 0;
    root.addCallback(() {
      appPops++;
      return SynchronousFuture(true);
    });
    final h = await _host(tester, clock: () => at.add(const Duration(seconds: 4)), back: root);
    final alarm = _alarm(at);
    h.platform.tap(RawNotificationTap(id: alarm.id, payload: _payload(alarm)));
    await _frames(tester);
    expect(find.byType(AdhanScreen), findsOneWidget);

    await tester.binding.handlePopRoute();
    await _frames(tester, 12);
    expect(find.byType(AdhanScreen), findsNothing);
    expect(appPops, 0, reason: 'the page under the adhan stays where it was');
    expect(find.text('home'), findsOneWidget);

    // No adhan: back is the app's again.
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(appPops, 1);
    await _unmount(tester);
  });

  testWidgets('an adhan screen left open is retired when the app returns hours later', (tester) async {
    final alarm = _alarm(at);
    var now = at.add(const Duration(seconds: 4));
    final system = FakeAdhanSystem()..lockScreenMode = true;
    final h = await _host(
      tester,
      clock: () => now,
      system: system,
      platform: FakeNotificationPlatform(
        launch: RawNotificationTap(id: alarm.id, payload: _payload(alarm), fromLaunch: true),
      ),
    );
    expect(find.byType(AdhanScreen), findsOneWidget);

    // Screen off with the adhan still open; back the next morning.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    now = now.add(const Duration(hours: 10));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await _frames(tester, 12);
    expect(find.byType(AdhanScreen), findsNothing);
    expect(h.system.lockScreenMode, isFalse);
    await _unmount(tester);
  });
}

// The in-app full-screen adhan honours the notification centre.
//
// The notification itself is held back by the gate when Prayer is muted or
// that call was skipped; without this seam the app would still throw the
// full-screen adhan up at the exact minute – the owner silenced it and it
// would shout anyway. And the other way round is just as bad: a hold check
// that fails must never swallow the adhan, so it fails open.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/adhan/adhan.dart';
import 'package:madar/features/orbit/domain/prayer_schedule.dart';

import 'adhan_test_app.dart';

DateTime _maghrib() => PrayerSchedule(ammanPrayerSettings).timesFor(DateTime(2026, 9, 28)).maghrib.toUtc();
DateTime _isha() => PrayerSchedule(ammanPrayerSettings).timesFor(DateTime(2026, 9, 28)).isha.toUtc();

Future<void> _frames(WidgetTester tester, [int n = 10]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}

Future<AdhanHarness> _host(
  WidgetTester tester, {
  required DateTime Function() clock,
  bool Function(AdhanAlarm alarm)? hold,
}) async {
  tester.view.physicalSize = const Size(412, 915) * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  final h = await buildAdhanTestApp(
    tester,
    home: AdhanHost(child: const Center(child: Text('home'))),
    now: clock(),
    clock: clock,
    overrides: [if (hold != null) adhanInAppHoldProvider.overrideWithValue(hold)],
  );
  await tester.pumpWidget(h.app);
  await _frames(tester);
  return h;
}

void main() {
  final maghrib = _maghrib();
  final isha = _isha();

  testWidgets('a held call never takes the screen, and the next one is still armed', (tester) async {
    final held = <AdhanSlot>[];
    var now = maghrib.subtract(const Duration(seconds: 3));
    final h = await _host(
      tester,
      clock: () => now,
      hold: (alarm) {
        held.add(alarm.slot);
        // Only Maghrib is muted / skipped in the centre.
        return alarm.slot == AdhanSlot.maghrib;
      },
    );
    expect(h.platform.scheduled.values.any((s) => s.request.at.isAtSameMomentAs(maghrib)), isTrue);

    now = maghrib.add(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 3));
    await _frames(tester);
    expect(held, contains(AdhanSlot.maghrib), reason: 'the hold was consulted at the exact minute');
    expect(find.byType(AdhanScreen), findsNothing, reason: 'a muted prayer must not take over the screen');

    // The hub re-armed itself: Isha, which is not held, still arrives.
    now = isha.add(const Duration(milliseconds: 100));
    await tester.pump(isha.difference(maghrib) + const Duration(seconds: 3));
    await _frames(tester);
    expect(find.byType(AdhanScreen), findsOneWidget, reason: 'the next adhan was dropped with the held one');
    await _unmount(tester);
  });

  testWidgets('a hold check that throws still presents (fails open)', (tester) async {
    var now = maghrib.subtract(const Duration(seconds: 3));
    await _host(
      tester,
      clock: () => now,
      hold: (_) => throw StateError('the gate is unavailable'),
    );
    now = maghrib.add(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 3));
    await _frames(tester);
    expect(find.byType(AdhanScreen), findsOneWidget, reason: 'a broken check must never silence the adhan');
    await _unmount(tester);
  });

  testWidgets('with no hold wired, nothing changes', (tester) async {
    var now = maghrib.subtract(const Duration(seconds: 3));
    await _host(tester, clock: () => now);
    now = maghrib.add(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 3));
    await _frames(tester);
    expect(find.byType(AdhanScreen), findsOneWidget);
    await _unmount(tester);
  });
}

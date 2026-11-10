import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/adhan/adhan.dart';
import 'package:madar/features/orbit/data/orbit_providers.dart';
import 'package:madar/features/orbit/domain/prayer_schedule.dart';

import 'adhan_test_app.dart';

/// Irbid – a real Jordanian city whose times differ from the default
/// (Amman) by a minute or two.
const _irbid = PrayerSettings(
  latitude: 32.5556,
  longitude: 35.85,
  timeZone: 'Asia/Amman',
  cityNameAr: 'إربد',
  cityNameEn: 'Irbid',
);

/// London – far from the default, so a plan on the wrong location is
/// obvious.
const _london = PrayerSettings(
  latitude: 51.5072,
  longitude: -0.1276,
  timeZone: 'Europe/London',
  cityNameAr: 'لندن',
  cityNameEn: 'London',
);

Future<void> _frames(WidgetTester tester, [int n = 10]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  final now = DateTime.utc(2026, 9, 28, 9);

  testWidgets('never plans on the default location while the stored one is still loading', (tester) async {
    final stored = StreamController<PrayerSettings>();
    addTearDown(stored.close);
    final h = await buildAdhanTestApp(
      tester,
      home: const AdhanHost(child: SizedBox()),
      now: now,
      overrides: [prayerSettingsProvider.overrideWith((ref) => stored.stream)],
    );
    await tester.pumpWidget(h.app);
    await _frames(tester, 20);
    expect(
      h.platform.scheduleLog,
      isEmpty,
      reason: 'the default city (Amman) is not where the user lives – wait for their location',
    );

    stored.add(_london);
    await _frames(tester, 20);
    final maghrib = PrayerSchedule(_london).timesFor(DateTime(2026, 9, 28)).maghrib.toUtc();
    expect(h.platform.scheduled.values.map((s) => s.request.at.toUtc()), contains(maghrib));
    final amman = PrayerSchedule(const PrayerSettings()).timesFor(DateTime(2026, 9, 28)).maghrib.toUtc();
    expect(h.platform.scheduleLog.map((s) => s.request.at.toUtc()), isNot(contains(amman)));

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('a location change moves every alarm to the new times', (tester) async {
    final stored = StreamController<PrayerSettings>();
    addTearDown(stored.close);
    final h = await buildAdhanTestApp(
      tester,
      home: const AdhanHost(child: SizedBox()),
      now: now,
      overrides: [prayerSettingsProvider.overrideWith((ref) => stored.stream)],
    );
    await tester.pumpWidget(h.app);
    stored.add(ammanPrayerSettings);
    await _frames(tester, 20);
    final before = {for (final s in h.platform.scheduled.values) s.request.at.toUtc()};
    expect(before, isNotEmpty);

    stored.add(_irbid);
    await _frames(tester, 20);
    final irbid = PrayerSchedule(_irbid).timesFor(DateTime(2026, 9, 28));
    final after = {for (final s in h.platform.scheduled.values) s.request.at.toUtc()};
    expect(after, contains(irbid.isha.toUtc()));
    expect(after.intersection(before), isNot(contains(PrayerSchedule(ammanPrayerSettings).timesFor(DateTime(2026, 9, 28)).isha.toUtc())));

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}

@Tags(['screenshot'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/design/themes.dart';
import 'package:madar/core/notifications/notifications.dart';
import 'package:madar/features/adhan/adhan.dart';
import 'package:madar/features/adhan/presentation/adhan_settings_screen.dart';
import 'package:madar/features/adhan/presentation/muezzin_picker_sheet.dart';

import '../../helpers/screenshot_harness.dart';
import 'adhan_test_app.dart';

const _dir = 'phase2/adhan';
final _now = DateTime.utc(2026, 9, 28, 11, 12); // 14:12 in Amman, before Asr

final _recording = CustomMuezzin(
  id: 'rec00makkah1',
  name: 'Makkah – Fajr',
  fileName: 'rec00makkah1.mp3',
  length: const Duration(minutes: 3, seconds: 48),
  addedAt: DateTime.utc(2026, 9, 1),
);

AdhanSettings _lived() => const AdhanSettings(sunriseAlert: true, sunriseMinutesBefore: 15)
    .withAlert(AdhanSlot.maghrib, const PrayerAlert(preMinutes: 10))
    .withAlert(AdhanSlot.isha, const PrayerAlert(preMinutes: 15))
    .withAlert(AdhanSlot.dhuhr, const PrayerAlert(adhan: false))
    .withMuezzin(_recording)
    .copyWith(fajrSound: AdhanSoundRef.file(_recording.id));

void main() {
  testWidgets('settings ar lapis – permissions missing', (tester) async {
    final h = await buildAdhanTestApp(
      tester,
      home: const AdhanSettingsScreen(),
      now: _now,
      settings: _lived(),
      platform: FakeNotificationPlatform(exactAllowed: true),
      system: FakeAdhanSystem(fullScreen: false, directory: '${Directory.systemTemp.path}/madar_adhan_test_sounds'),
      battery: FakeBatteryGate(exempt: false),
    );
    await captureScreen(tester, h.app, '$_dir/settings_ar_lapis', settle: const Duration(milliseconds: 2400));
  });

  testWidgets('settings en pearl – all set', (tester) async {
    final h = await buildAdhanTestApp(
      tester,
      home: const AdhanSettingsScreen(),
      now: _now,
      settings: _lived(),
      theme: MadarThemeId.pearl,
      language: 'en',
    );
    await captureScreen(tester, h.app, '$_dir/settings_en_pearl', settle: const Duration(milliseconds: 2400));
  });

  testWidgets('settings en pearl – notifications refused in the dialog', (tester) async {
    var now = _now;
    final platform = FakeNotificationPlatform(enabled: false)
      ..onRequestNotifications = () => now = now.add(const Duration(seconds: 4));
    final h = await buildAdhanTestApp(
      tester,
      home: const AdhanSettingsScreen(),
      now: _now,
      clock: () => now,
      settings: _lived(),
      theme: MadarThemeId.pearl,
      language: 'en',
      platform: platform,
      battery: FakeBatteryGate(exempt: false),
    );
    await captureScreen(
      tester,
      h.app,
      '$_dir/settings_en_pearl_refused',
      settle: const Duration(milliseconds: 2400),
      beforeCapture: (tester) async {
        await tester.tap(find.text('Allow').first);
        for (var i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
      },
    );
  });

  testWidgets('settings ar aurora – alert and test sections', (tester) async {
    final h = await buildAdhanTestApp(
      tester,
      home: const AdhanSettingsScreen(),
      now: _now,
      settings: _lived(),
      theme: MadarThemeId.aurora,
      system: FakeAdhanSystem(
        volume: const AlarmVolume(0, 7),
        directory: '${Directory.systemTemp.path}/madar_adhan_test_sounds',
      ),
    );
    await captureScreen(
      tester,
      h.app,
      '$_dir/settings_ar_aurora_bottom',
      settle: const Duration(milliseconds: 2400),
      beforeCapture: (tester) async {
        await tester.drag(find.byType(ListView).first, const Offset(0, -1300));
        await tester.pump(const Duration(milliseconds: 600));
        await tester.tap(find.text('جرّب الأذان الآن'));
        await tester.pump(const Duration(milliseconds: 600));
      },
    );
  });

  for (final (theme, lang) in [(MadarThemeId.emerald, 'ar'), (MadarThemeId.pearl, 'en')]) {
    testWidgets('muezzin picker $lang ${theme.name}', (tester) async {
      final h = await buildAdhanTestApp(
        tester,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(onPressed: () => showMuezzinPicker(context, fajr: true), child: const Text('open')),
            ),
          ),
        ),
        now: _now,
        settings: _lived(),
        theme: theme,
        language: lang,
      );
      await captureScreen(
        tester,
        h.app,
        '$_dir/picker_${lang}_${theme.name}',
        settle: const Duration(milliseconds: 600),
        beforeCapture: (tester) async {
          await tester.tap(find.text('open'));
          for (var i = 0; i < 20; i++) {
            await tester.pump(const Duration(milliseconds: 60));
          }
        },
      );
    });
  }
}

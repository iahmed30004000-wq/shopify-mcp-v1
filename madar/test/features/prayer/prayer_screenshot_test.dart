// Screenshots of the prayer screens. Run with the device zone of the
// default city so no "times in … time" note appears where not intended:
//   TZ=Asia/Amman flutter test --tags screenshot test/features/prayer
@Tags(['screenshot'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/design/themes.dart';
import 'package:madar/features/prayer/prayer.dart';

import '../../helpers/screenshot_harness.dart';
import 'fakes.dart';
import 'prayer_test_app.dart';

const _dir = 'phase2/prayer';

void main() {
  Future<void> shot(
    WidgetTester tester,
    String name,
    Widget home, {
    MadarThemeId theme = MadarThemeId.lapis,
    Locale locale = const Locale('ar'),
    DateTime? now,
    PrayerSettings settings = prayerTestSettings,
    FakeLocationSource? location,
    Future<void> Function(WidgetTester)? before,
    double height = 915,
  }) async {
    final setup = await buildPrayerTestApp(
      tester,
      home: home,
      theme: theme,
      locale: locale,
      now: now,
      settings: settings,
      location: location,
    );
    await captureScreen(tester, setup.app, '$_dir/$name', beforeCapture: before, logicalSize: Size(412, height));
  }

  Future<void> tap(WidgetTester tester, Finder f) async {
    await tester.tap(f);
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets('times – Arabic, Lapis (Dhuhr window)', (tester) async {
    await shot(tester, 'times_ar_lapis', const PrayerTimesScreen(), height: 1180);
  });

  testWidgets('times – English, Pearl', (tester) async {
    await shot(
      tester,
      'times_en_pearl',
      const PrayerTimesScreen(),
      theme: MadarThemeId.pearl,
      locale: const Locale('en'),
      height: 1180,
    );
  });

  testWidgets('times – Arabic, Aurora, the last third of the night', (tester) async {
    await shot(
      tester,
      'times_ar_aurora_night',
      const PrayerTimesScreen(),
      theme: MadarThemeId.aurora,
      now: DateTime.utc(2026, 9, 28, 0, 20).toLocal(), // 03:20 in Amman
      height: 1180,
    );
  });

  testWidgets('times – English, Emerald, London while the phone is on Amman time', (tester) async {
    await shot(
      tester,
      'times_en_emerald_london',
      const PrayerTimesScreen(),
      theme: MadarThemeId.emerald,
      locale: const Locale('en'),
      settings: const PrayerSettings(
        latitude: 51.5072,
        longitude: -0.1275,
        method: PrayerMethod.moonsightingCommittee,
        timeZone: 'Europe/London',
        cityId: 'gb-london',
        cityNameAr: 'لندن',
        cityNameEn: 'London',
        countryCode: 'GB',
        locationSource: PrayerLocationSource.city,
      ),
    );
  });

  testWidgets('month table – Arabic, Desert', (tester) async {
    await shot(
      tester,
      'month_ar_desert',
      const PrayerTimesScreen(initialView: PrayerTimesView.month),
      theme: MadarThemeId.desert,
      height: 1900,
    );
  });

  testWidgets('month table – English, Pearl, 24-hour', (tester) async {
    await shot(
      tester,
      'month_en_pearl_24h',
      const PrayerTimesScreen(initialView: PrayerTimesView.month),
      theme: MadarThemeId.pearl,
      locale: const Locale('en'),
      settings: prayerTestSettings.copyWith(clock24h: true),
      height: 1900,
    );
  });

  testWidgets('settings – Arabic, Lapis', (tester) async {
    await shot(tester, 'settings_ar_lapis', const PrayerSettingsScreen(), height: 2350);
  });

  testWidgets('settings – English, Pearl, custom angles', (tester) async {
    await shot(
      tester,
      'settings_en_pearl_custom',
      const PrayerSettingsScreen(),
      theme: MadarThemeId.pearl,
      locale: const Locale('en'),
      settings: prayerTestSettings.copyWith(
        method: PrayerMethod.custom,
        customBase: PrayerMethod.jordan,
        fajrAngle: 17.5,
        ishaAngle: 17,
        adjustmentsMin: {'fajr': 2, 'maghrib': 2},
        hijriOffsetDays: 1,
      ),
      height: 2500,
    );
  });

  testWidgets('location sheet – Arabic, Lapis', (tester) async {
    await shot(
      tester,
      'location_sheet_ar_lapis',
      const PrayerTimesScreen(),
      before: (t) => tap(t, find.byType(PrayerLocationChip)),
    );
  });

  testWidgets('location rationale – English, Aurora', (tester) async {
    await shot(
      tester,
      'location_rationale_en_aurora',
      const PrayerTimesScreen(),
      theme: MadarThemeId.aurora,
      locale: const Locale('en'),
      location: FakeLocationSource(access: LocationAccess.denied),
      before: (t) async {
        await tap(t, find.byType(PrayerLocationChip));
        await tap(t, find.text('Use my current location'));
      },
    );
  });

  testWidgets('location permanently denied – Arabic, Pearl', (tester) async {
    await shot(
      tester,
      'location_denied_ar_pearl',
      const PrayerTimesScreen(),
      theme: MadarThemeId.pearl,
      location: FakeLocationSource(access: LocationAccess.deniedForever),
      before: (t) async {
        await tap(t, find.byType(PrayerLocationChip));
        await tap(t, find.text('استخدم موقعي الحالي'));
      },
    );
  });

  testWidgets('city picker – Arabic search, Emerald', (tester) async {
    await shot(
      tester,
      'city_picker_ar_emerald',
      const PrayerTimesScreen(),
      theme: MadarThemeId.emerald,
      before: (t) async {
        await tap(t, find.byType(PrayerLocationChip));
        await tap(t, find.text('اختر مدينة'));
        await t.enterText(find.byType(TextField), 'مكه');
        for (var i = 0; i < 10; i++) {
          await t.pump(const Duration(milliseconds: 50));
        }
      },
    );
  });

  testWidgets('adjustment sheet – Arabic, Desert', (tester) async {
    await shot(
      tester,
      'adjust_sheet_ar_desert',
      const PrayerTimesScreen(),
      theme: MadarThemeId.desert,
      settings: prayerTestSettings.copyWith(adjustmentsMin: {'maghrib': 3}),
      before: (t) async {
        await t.longPress(find.text('المغرب'));
        for (var i = 0; i < 30; i++) {
          await t.pump(const Duration(milliseconds: 50));
        }
      },
    );
  });

  testWidgets('method sheet – English, Lapis', (tester) async {
    await shot(
      tester,
      'method_sheet_en_lapis',
      const PrayerSettingsScreen(),
      locale: const Locale('en'),
      before: (t) => tap(t, find.text('Jordan – Ministry of Awqaf')),
    );
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/design/widgets/widgets.dart' show MadarSwitch;
import 'package:madar/core/sound/sound_api.dart';
import 'package:madar/features/orbit/data/orbit_repository.dart';
import 'package:madar/features/prayer/prayer.dart';

import '../../helpers/test_app.dart' show usePhoneSurface;
import 'fakes.dart';
import 'prayer_test_app.dart';

void main() {
  Future<PrayerTestSetup> pump(
    WidgetTester tester,
    Widget home, {
    Locale locale = const Locale('ar'),
    PrayerSettings settings = prayerTestSettings,
    FakeLocationSource? location,
    DateTime? now,
  }) async {
    usePhoneSurface(tester);
    final setup = await buildPrayerTestApp(
      tester,
      home: home,
      locale: locale,
      settings: settings,
      location: location,
      now: now,
    );
    await tester.pumpWidget(setup.app);
    await settlePrayer(tester);
    return setup;
  }

  Future<PrayerSettings> stored(PrayerTestSetup s, WidgetTester tester) async =>
      (await tester.runAsync(() => Repositories(s.db).keyValues.get(OrbitRepository.prayerSettingsKv)))!;

  /// Scrolls [f] to the middle of the screen (clear of the app bar).
  Future<void> reveal(WidgetTester tester, Finder f) async {
    await tester.scrollUntilVisible(f, 300);
    await tester.runAsync(() async {});
    await Scrollable.ensureVisible(tester.element(f), alignment: 0.5);
    await settlePrayer(tester);
  }

  ProviderContainer containerOf(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));

  group('PrayerTimesScreen', () {
    testWidgets('Arabic: dates, times, current window and countdown', (tester) async {
      await pump(tester, const PrayerTimesScreen());
      expect(find.text('مواقيت الصلاة'), findsOneWidget);
      expect(find.text('١٧ ربيع الآخر ١٤٤٨ هـ'), findsOneWidget);
      expect(find.text('عمّان، الأردن'), findsOneWidget);
      // Amman, 28 Sep 2026 (Ministry of Awqaf: Dhuhr 12:27/28, Asr 15:51/53).
      expect(find.text('١٢:٢٧'), findsOneWidget);
      expect(find.text('٣:٥١'), findsWidgets);
      expect(find.text('الآن'), findsOneWidget);
      expect(find.text('يحين وقت العصر بعد'), findsOneWidget);
      // 14:10 → Asr at 15:51: 1 h 41 min.
      expect(find.textContaining('١:٤١:٠٠'), findsOneWidget);
      expect(find.text('منتصف الليل'), findsOneWidget);
      expect(find.text('الثلث الأخير'), findsOneWidget);
      expect(find.text('الضحى'), findsOneWidget);
    });

    testWidgets('English: 12-hour times with AM / PM', (tester) async {
      await pump(tester, const PrayerTimesScreen(), locale: const Locale('en'));
      expect(find.text('Prayer times'), findsOneWidget);
      expect(find.text('Asr in'), findsOneWidget);
      expect(find.text('3:51'), findsWidgets);
      expect(find.text('PM'), findsWidgets);
      expect(find.text('Now'), findsOneWidget);
      expect(find.text('17 Rabi’ al-Akhir 1448 AH'), findsOneWidget);
      expect(find.text('Amman, Jordan'), findsOneWidget);
    });

    testWidgets('24-hour clock', (tester) async {
      await pump(
        tester,
        const PrayerTimesScreen(),
        locale: const Locale('en'),
        settings: prayerTestSettings.copyWith(clock24h: true),
      );
      expect(find.text('15:51'), findsWidgets);
      expect(find.text('PM'), findsNothing);
    });

    testWidgets('next day with the arrow, back to today; each step sounds', (tester) async {
      final s = await pump(tester, const PrayerTimesScreen(), locale: const Locale('en'));
      expect(find.text('Today'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Next day'));
      await settlePrayer(tester);
      expect(find.text('Tomorrow'), findsOneWidget);
      expect(s.sound.played, contains(Sfx.swipe));
      expect(find.text('Now'), findsNothing, reason: 'no current moment on another day');
      await tester.tap(find.bySemanticsLabel('Back to today'));
      await settlePrayer(tester);
      expect(find.text('Now'), findsOneWidget);
    });

    testWidgets('one arrow step sounds once (the pager stays quiet)', (tester) async {
      final s = await pump(tester, const PrayerTimesScreen(), locale: const Locale('en'));
      s.sound.played.clear();
      await tester.tap(find.bySemanticsLabel('Next day'));
      await settlePrayer(tester);
      expect(s.sound.played.where((x) => x == Sfx.swipe).length, 1);
      s.sound.played.clear();
      await tester.tap(find.bySemanticsLabel('Next day'));
      await settlePrayer(tester);
      await tester.tap(find.bySemanticsLabel('Back to today'));
      await settlePrayer(tester);
      // Two pages back in one animation: only the button's own sound.
      expect(s.sound.played.where((x) => x == Sfx.swipe).length, 1);
      expect(s.sound.played.where((x) => x == Sfx.navigate).length, 1);
    });

    testWidgets('after midnight, before Fajr: «الليلة», and the calendar date is «اليوم»', (tester) async {
      // 03:20 on Monday 28 Sep in Amman: the night of the 27th still runs
      // (last third), Fajr of the 28th is next.
      await pump(tester, const PrayerTimesScreen(), now: DateTime.utc(2026, 9, 28, 0, 20).toLocal());
      expect(find.text('الاثنين، ٢٨ سبتمبر ٢٠٢٦'), findsOneWidget);
      expect(find.text('الليلة'), findsOneWidget);
      expect(find.text('اليوم'), findsNWidgets(1), reason: 'only the Day tab, no "today" title on the 27th');
      expect(find.text('غدًا'), findsNothing);
      await tester.tap(find.bySemanticsLabel('اليوم التالي'));
      await settlePrayer(tester);
      // The next page is the 28th – today, not «tomorrow».
      expect(find.text('اليوم'), findsNWidgets(3), reason: 'Day tab, title, back-to-today pill');
      expect(find.text('غدًا'), findsNothing);
    });

    testWidgets('after midnight the month table marks the calendar date', (tester) async {
      await pump(
        tester,
        const PrayerTimesScreen(initialView: PrayerTimesView.month),
        locale: const Locale('en'),
        now: DateTime.utc(2026, 9, 30, 22, 30).toLocal(), // 01:30 on 1 Oct in Amman
      );
      expect(find.text('October 2026'), findsOneWidget);
    });

    testWidgets('the day view says how to adjust a time', (tester) async {
      await pump(tester, const PrayerTimesScreen(), locale: const Locale('en'));
      await tester.scrollUntilVisible(
        find.text('Long-press any time to adjust it by minutes'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Long-press any time to adjust it by minutes'), findsOneWidget);
      await tester.tap(find.text('Month'));
      await settlePrayer(tester);
      expect(find.text('Long-press any time to adjust it by minutes'), findsNothing);
    });

    testWidgets('swiping moves day by day (RTL: towards the left is the next day)', (tester) async {
      await pump(tester, const PrayerTimesScreen());
      final g = await tester.startGesture(tester.getCenter(find.byType(PageView)));
      for (var i = 0; i < 10; i++) {
        await g.moveBy(const Offset(30, 0));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await g.up();
      await settlePrayer(tester);
      expect(find.text('غدًا'), findsOneWidget);
    });

    testWidgets('Friday Dhuhr is called Jumuʿah', (tester) async {
      await pump(tester, const PrayerTimesScreen(), now: DateTime.utc(2026, 10, 2, 11).toLocal());
      expect(find.text('الجمعة'), findsWidgets);
    });

    testWidgets('long-press a time to nudge it by minutes, with undo', (tester) async {
      final s = await pump(tester, const PrayerTimesScreen(), locale: const Locale('en'));
      await tester.longPress(find.text('Maghrib'));
      await settlePrayer(tester);
      expect(find.text('Adjust Maghrib'), findsOneWidget);
      expect(s.sound.played, contains(Sfx.pickUp));
      final add = find.byIcon(Icons.add_rounded).last;
      await tester.tap(add);
      await settlePrayer(tester);
      await tester.tap(add);
      await settlePrayer(tester);
      expect((await stored(s, tester)).adjustmentsMin, {'maghrib': 2});
      expect(find.text('Calculated: 6:32\u00A0PM'), findsOneWidget);
      await tester.tap(find.text('Done'));
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.text('Maghrib adjusted'), findsOneWidget);
      await tester.tap(find.text('Undo'));
      await settlePrayer(tester);
      expect((await stored(s, tester)).adjustmentsMin, isEmpty);
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('month table lists every day of the month', (tester) async {
      await pump(tester, const PrayerTimesScreen(), locale: const Locale('en'));
      await tester.tap(find.text('Month'));
      await settlePrayer(tester);
      expect(find.text('September 2026'), findsOneWidget);
      expect(find.text('30'), findsWidgets);
      await tester.tap(find.bySemanticsLabel('Next month'));
      await settlePrayer(tester);
      expect(find.text('October 2026'), findsOneWidget);
    });

    testWidgets('location chip → choose a city → times of Makkah, with undo', (tester) async {
      final s = await pump(tester, const PrayerTimesScreen(), locale: const Locale('en'));
      await tester.tap(find.byType(PrayerLocationChip));
      await settlePrayer(tester);
      expect(find.text('Your location'), findsOneWidget);
      await tester.tap(find.text('Choose a city'));
      await settlePrayer(tester);
      await tester.enterText(find.byType(TextField), 'mecca');
      await settlePrayer(tester);
      expect(find.text('Makkah'), findsWidgets);
      await tester.tap(find.text('Makkah').first);
      // Not settled: the undo toast counts down for 5 s.
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      final after = await stored(s, tester);
      expect(after.cityId, 'sa-makkah');
      expect(after.timeZone, 'Asia/Riyadh');
      expect(s.sound.played.where((x) => x == Sfx.complete).length, 1, reason: 'one confirmation per pick');
      expect(find.text('Makkah, Saudi Arabia'), findsOneWidget);
      expect(find.textContaining('Location set to'), findsOneWidget);
      await tester.tap(find.text('Undo'));
      await settlePrayer(tester);
      expect((await stored(s, tester)).cityId, 'jo-amman');
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('use my current location: rationale → allow → located', (tester) async {
      final loc = FakeLocationSource(
        access: LocationAccess.denied,
        fix: const GeoFix(latitude: 32.55, longitude: 35.85),
      );
      final s = await pump(tester, const PrayerTimesScreen(), location: loc);
      await tester.tap(find.byType(PrayerLocationChip));
      await settlePrayer(tester);
      await tester.tap(find.text('استخدم موقعي الحالي'));
      await settlePrayer(tester);
      expect(find.text('نحتاج موقعك التقريبي'), findsOneWidget);
      await tester.tap(find.text('السماح بالموقع'));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      // The sheet shows the result, then closes itself and offers undo.
      await tester.pump(const Duration(seconds: 1));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.textContaining('صار الموقع'), findsOneWidget);
      expect(loc.requests, 1);
      final after = await stored(s, tester);
      expect(after.locationSource, PrayerLocationSource.gps);
      expect(after.cityId, 'jo-irbid');
      expect(find.text('إربد، الأردن'), findsOneWidget);
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('permanently denied offers the app settings and the city list', (tester) async {
      final loc = FakeLocationSource(access: LocationAccess.deniedForever);
      await pump(tester, const PrayerTimesScreen(), location: loc, locale: const Locale('en'));
      await tester.tap(find.byType(PrayerLocationChip));
      await settlePrayer(tester);
      await tester.tap(find.text('Use my current location'));
      await settlePrayer(tester);
      expect(find.text('Location permission is off'), findsOneWidget);
      await tester.tap(find.text('Open app settings'));
      await settlePrayer(tester);
      expect(loc.openedAppSettings, 1);
      expect(find.text('Choose a city'), findsOneWidget);
    });

    testWidgets('the location zone is shown when it differs from the device', (tester) async {
      await pump(
        tester,
        const PrayerTimesScreen(),
        locale: const Locale('en'),
        settings: const PrayerSettings(
          latitude: -36.8485,
          longitude: 174.7633,
          timeZone: 'Pacific/Auckland',
          cityNameEn: 'Auckland',
          cityNameAr: 'أوكلاند',
          countryCode: 'NZ',
          locationSource: PrayerLocationSource.city,
          method: PrayerMethod.muslimWorldLeague,
        ),
      );
      expect(find.text('Times in Auckland time'), findsOneWidget);
    });
  });

  group('PrayerSettingsScreen', () {
    testWidgets('Arabic: every section, the Jordanian method and its summary', (tester) async {
      await pump(tester, const PrayerSettingsScreen());
      expect(find.text('إعدادات المواقيت'), findsOneWidget);
      expect(find.text('وزارة الأوقاف الأردنية'), findsOneWidget);
      expect(find.textContaining('الفجر\u00A0١٨°'), findsOneWidget);
      // Parts never split inside ("المغرب +٧ د" stays together).
      expect(find.textContaining('المغرب\u00A0\u2066+٧\u2069\u00A0د'), findsOneWidget);
      expect(find.text('مواقيت اليوم'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('العرض'), 300);
      expect(find.text('التاريخ الهجري'), findsOneWidget);
    });

    testWidgets('English: pick a method in the sheet', (tester) async {
      final s = await pump(tester, const PrayerSettingsScreen(), locale: const Locale('en'));
      await tester.tap(find.text('Jordan – Ministry of Awqaf'));
      await settlePrayer(tester);
      expect(find.text('Suggested for your location'), findsOneWidget);
      await tester.tap(find.text('Muslim World League'));
      await settlePrayer(tester);
      final after = await stored(s, tester);
      expect(after.method, PrayerMethod.muslimWorldLeague);
      expect(find.text('Muslim World League'), findsOneWidget);
    });

    testWidgets('a new method offers undo', (tester) async {
      final s = await pump(tester, const PrayerSettingsScreen(), locale: const Locale('en'));
      await tester.tap(find.text('Jordan – Ministry of Awqaf'));
      await settlePrayer(tester);
      await tester.tap(find.text('Umm al-Qura – Makkah'));
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect((await stored(s, tester)).method, PrayerMethod.ummAlQura);
      expect(find.text('Method set to Umm al-Qura – Makkah'), findsOneWidget);
      await tester.tap(find.text('Undo'));
      await settlePrayer(tester);
      expect((await stored(s, tester)).method, PrayerMethod.jordan);
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('adjustment steppers tick and persist', (tester) async {
      final s = await pump(tester, const PrayerSettingsScreen(), locale: const Locale('en'));
      final fajrStepper = find.ancestor(of: find.text('Fajr').first, matching: find.byType(Row)).first;
      await reveal(tester, find.text('Manual adjustments'));
      final increase = find.descendant(
        of: find.ancestor(of: find.text('Fajr').last, matching: find.byType(Row)).first,
        matching: find.byIcon(Icons.add_rounded),
      );
      expect(fajrStepper, findsOneWidget);
      await tester.tap(increase);
      await settlePrayer(tester);
      await tester.tap(increase);
      await settlePrayer(tester);
      expect((await stored(s, tester)).adjustmentsMin, {'fajr': 2});
      expect(s.sound.played.where((x) => x == Sfx.countTick).length, 2);
      expect(s.haptics.fired, contains(Haptic.tick));
    });

    testWidgets('Asr madhab, Hijri offset and the clock', (tester) async {
      final s = await pump(tester, const PrayerSettingsScreen(), locale: const Locale('en'));
      await reveal(tester, find.text('Hanafi'));
      await tester.tap(find.text('Hanafi'));
      await settlePrayer(tester);
      expect((await stored(s, tester)).hanafiAsr, isTrue);

      await reveal(tester, find.text('Hijri day adjustment'));
      final hijriRow = find.ancestor(of: find.text('Hijri day adjustment'), matching: find.byType(Row)).first;
      await tester.tap(find.descendant(of: hijriRow, matching: find.byIcon(Icons.add_rounded)));
      await settlePrayer(tester);
      expect((await stored(s, tester)).hijriOffsetDays, 1);
      expect(find.text('18 Rabi’ al-Akhir 1448 AH'), findsWidgets);

      await reveal(tester, find.text('24-hour'));
      await tester.tap(find.text('24-hour'));
      await settlePrayer(tester);
      expect((await stored(s, tester)).clock24h, isTrue);
      expect(containerOf(tester).read(prayerSettingsControllerProvider).clock24h, isTrue);
    });

    testWidgets('custom angles appear for the custom method', (tester) async {
      final s = await pump(
        tester,
        const PrayerSettingsScreen(),
        locale: const Locale('en'),
        settings: prayerTestSettings.copyWith(method: PrayerMethod.custom, fajrAngle: 18, ishaAngle: 18),
      );
      expect(find.text('Fajr angle'), findsOneWidget);
      final row = find.ancestor(of: find.text('Fajr angle'), matching: find.byType(Row)).first;
      await tester.tap(find.descendant(of: row, matching: find.byIcon(Icons.remove_rounded)));
      await settlePrayer(tester);
      expect((await stored(s, tester)).fajrAngle, 17.5);
      await tester.tap(find.byType(MadarSwitch).first);
      await settlePrayer(tester);
      expect((await stored(s, tester)).ishaIntervalMin, 90);
      expect(find.text('Time after Maghrib'), findsOneWidget);
    });
  });

  group('large text', () {
    for (final home in [const PrayerTimesScreen(), const PrayerSettingsScreen()]) {
      testWidgets('${home.runtimeType} lays out at 1.6× text', (tester) async {
        usePhoneSurface(tester);
        final setup = await buildPrayerTestApp(tester, home: home, locale: const Locale('en'));
        tester.platformDispatcher.textScaleFactorTestValue = 1.6;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await tester.pumpWidget(setup.app);
        await settlePrayer(tester);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('HijriDateText', () {
    testWidgets('follows the offset and the Maghrib rollover', (tester) async {
      await pump(
        tester,
        const Scaffold(body: Center(child: HijriDateText())),
        settings: prayerTestSettings.copyWith(hijriOffsetDays: -1),
      );
      expect(find.text('١٦ ربيع الآخر ١٤٤٨ هـ'), findsOneWidget);
    });

    testWidgets('after Maghrib with rollover on, the next Hijri day', (tester) async {
      await pump(
        tester,
        const Scaffold(body: Center(child: HijriDateText())),
        settings: prayerTestSettings.copyWith(hijriAtMaghrib: true),
        now: DateTime.utc(2026, 9, 28, 16, 0).toLocal(), // 19:00 in Amman, after Maghrib
      );
      expect(find.text('١٨ ربيع الآخر ١٤٤٨ هـ'), findsOneWidget);
    });
  });
}

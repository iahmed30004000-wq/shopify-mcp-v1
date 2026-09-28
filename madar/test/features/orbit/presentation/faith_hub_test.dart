// The Faith world's page is a hub of the day: the next prayer with its live
// countdown under today's Hijri date, the tracker's card, the adhkar card
// and links to every faith page – in both languages and every theme.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/design/themes.dart';
import 'package:madar/core/i18n/formatters.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/core/routing/routes.dart';
import 'package:madar/core/settings/app_settings.dart';
import 'package:madar/core/sound/sound_api.dart';
import 'package:madar/features/adhkar/adhkar.dart';
import 'package:madar/features/orbit/data/orbit_providers.dart';
import 'package:madar/features/orbit/data/orbit_repository.dart';
import 'package:madar/features/orbit/presentation/planet/faith_hub.dart';
import 'package:madar/features/orbit/presentation/planet/planet_page.dart';
import 'package:madar/features/prayer/prayer.dart';
import 'package:madar/features/prayer_tracker/prayer_tracker.dart';

import '../../../helpers/test_app.dart';
import '../../lock/lock_test_utils.dart';
import 'orbit_scene_fixtures.dart';

Future<void> _location(MadarDatabase db) => OrbitRepository(Repositories(db)).setPrayerSettings(hostPrayerSettings());

Future<void> _frames(WidgetTester tester, int n) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Future<TestApp> _faithPage(WidgetTester tester, {String lang = 'ar', MadarThemeId theme = MadarThemeId.lapis}) async {
  final app = await pumpMadarApp(
    tester,
    settings: AppSettings(onboarded: true, languageCode: lang, themeId: theme),
    initialLocation: AppRoutes.planetOf('faith'),
    beforePump: _location,
    overrides: LockFixture.empty().overrides,
    settle: false,
  );
  await _frames(tester, 60);
  await settleApp(tester);
  return app;
}

/// Scrolls the planet page's sheet until [finder] is built and visible.
Future<void> _reveal(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    250,
    scrollable: find.descendant(of: find.byType(PlanetModulePage), matching: find.byType(Scrollable)).first,
  );
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

/// The seconds field of an `h:mm:ss` countdown [s] minus [n] seconds.
String _secondsBefore(String s, int n) {
  final secs = int.parse(s.split(':').last);
  return ((secs - n) % 60).toString().padLeft(2, '0');
}

void main() {
  for (final lang in ['ar', 'en']) {
    testWidgets('$lang: next prayer, countdown and Hijri date; the tracker and adhkar cards; links', (tester) async {
      final app = await _faithPage(tester, lang: lang);
      final l = lookupL10n(Locale(lang));
      expect(find.byType(FaithHub), findsOneWidget);
      expect(find.byType(NextPrayerCard), findsOneWidget);

      // The next prayer and its countdown, from the app's own schedule.
      final schedule = app.container.read(prayerScheduleProvider);
      final now = testNow;
      final next = nextObligatoryPrayer(schedule, now);
      final fmt = MadarFormatter(languageCode: lang);
      final clock = PrayerClockFormat(fmt, h24: schedule.settings.clock24h, am: l.ptAm, pm: l.ptPm);
      final card = find.byType(NextPrayerCard);
      expect(find.descendant(of: card, matching: find.text(l.prayerName(next.prayer))), findsOneWidget);
      expect(find.descendant(of: card, matching: find.text(clock.countdown(next.at.difference(now)))), findsOneWidget);
      expect(
        find.descendant(of: card, matching: find.text(l.faithHubAt(clock.format(schedule.wallClock(next.at)).joined))),
        findsOneWidget,
      );
      final hijri = l.hijriDate(hijriAt(schedule, schedule.settings, now), fmt);
      expect(find.descendant(of: card, matching: find.text(hijri)), findsOneWidget);
      expect(Directionality.of(tester.element(card)), lang == 'ar' ? TextDirection.rtl : TextDirection.ltr);

      await _reveal(tester, find.byType(PrayerTodayCard));
      expect(find.byType(PrayerTodayCard), findsOneWidget);
      await _reveal(tester, find.byType(AdhkarTodayCard));
      expect(find.byType(AdhkarTodayCard), findsOneWidget);
      await _reveal(tester, find.text(l.faithHubLinksTitle));
      for (final title in [l.ptTitle, l.faithHubHistory, l.adhkarTitle, l.adhkarTasbeehTitle, l.adhanSettingsTitle]) {
        await _reveal(tester, find.bySemanticsLabel(RegExp('^${RegExp.escape(title)}\\. ')));
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('every link opens its page with a navigation sound; back returns to the Faith page', (tester) async {
    final app = await _faithPage(tester, lang: 'en');
    final l = lookupL10n(const Locale('en'));
    final pages = <String, (String, Type)>{
      l.ptTitle: (AppRoutes.prayerTimes, PrayerTimesScreen),
      l.faithHubHistory: (AppRoutes.prayerTrackerHistory, PrayerTrackerScreen),
      l.adhkarTitle: (AppRoutes.adhkar, AdhkarHomeScreen),
      l.adhkarTasbeehTitle: (AppRoutes.tasbeeh, TasbeehScreen),
    };
    for (final MapEntry(key: title, value: (location, type)) in pages.entries) {
      final link = find.bySemanticsLabel(RegExp('^${RegExp.escape(title)}\\. '));
      await _reveal(tester, link);
      app.sound.played.clear();
      await tester.tap(link);
      await settleApp(tester);
      expect(find.byType(type), findsOneWidget, reason: title);
      expect(app.router.state.uri.toString(), location);
      expect(app.sound.played, contains(Sfx.navigate));
      await tester.binding.handlePopRoute();
      await settleApp(tester);
      expect(find.byType(FaithHub), findsOneWidget);
      expect(app.location, startsWith('/planet/faith'));
      await tester.pump(const Duration(seconds: 6));
    }
  });

  testWidgets('the next-prayer card opens the prayer times; the tracker card its tracker', (tester) async {
    final app = await _faithPage(tester, lang: 'en');
    await tester.tap(find.byType(NextPrayerCard));
    await settleApp(tester);
    expect(find.byType(PrayerTimesScreen), findsOneWidget);
    await tester.binding.handlePopRoute();
    await settleApp(tester);

    await _reveal(tester, find.byType(PrayerTodayCard));
    await tester.tap(
      find.descendant(of: find.byType(PrayerTodayCard), matching: find.byIcon(Icons.chevron_right_rounded)),
    );
    await settleApp(tester);
    expect(find.byType(PrayerTrackerScreen), findsOneWidget);
    expect(app.router.state.uri.toString(), AppRoutes.prayerTracker);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('the countdown ticks every second while the page shows', (tester) async {
    var now = testNow;
    await pumpMadarApp(
      tester,
      initialLocation: AppRoutes.planetOf('faith'),
      beforePump: _location,
      overrides: LockFixture.empty().overrides,
      clock: () => now,
      settle: false,
    );
    await _frames(tester, 60);
    await settleApp(tester);
    String countdown() => tester
        .widgetList<Text>(find.descendant(of: find.byType(NextPrayerCard), matching: find.byType(Text)))
        .last
        .data!;
    final before = countdown();
    now = now.add(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 1));
    final after = countdown();
    expect(after, isNot(before));
    expect(
      Digits.toWestern(BidiIsolate.strip(after)),
      endsWith(_secondsBefore(Digits.toWestern(BidiIsolate.strip(before)), 3)),
    );
  });

  for (final theme in MadarThemeId.values) {
    for (final lang in ['ar', 'en']) {
      testWidgets('renders in ${theme.name} / $lang without layout errors', (tester) async {
        await _faithPage(tester, lang: lang, theme: theme);
        expect(find.byType(FaithHub), findsOneWidget);
        await _reveal(tester, find.byType(AdhkarTodayCard));
        expect(tester.takeException(), isNull);
      });
    }
  }
}

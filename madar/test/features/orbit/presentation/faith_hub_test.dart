// The Faith world's page is a hub of the day: the next prayer with its live
// countdown under today's Hijri date; "your day" (the tracker's and the
// adhkar cards); "with the Quran" (continue reading, today's wird, Hifz once
// it holds something); "tools" (the qibla card over a grid of six) – in both
// languages and every theme, every part opening its page as a route.
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/domain/enums.dart' show HifzKind;
import 'package:madar/core/design/themes.dart';
import 'package:madar/core/i18n/formatters.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/core/routing/routes.dart';
import 'package:madar/core/settings/app_settings.dart';
import 'package:madar/core/sound/sound_api.dart';
import 'package:madar/features/adhan/presentation/adhan_settings_screen.dart';
import 'package:madar/features/adhkar/adhkar.dart';
import 'package:madar/features/hifz/hifz.dart';
import 'package:madar/features/orbit/data/orbit_providers.dart';
import 'package:madar/features/orbit/data/orbit_repository.dart';
import 'package:madar/features/orbit/presentation/planet/faith_hub.dart';
import 'package:madar/features/orbit/presentation/planet/planet_page.dart';
import 'package:madar/features/prayer/prayer.dart';
import 'package:madar/features/prayer_tracker/prayer_tracker.dart';
import 'package:madar/features/qibla/qibla.dart';
import 'package:madar/features/quran/quran.dart';
import 'package:madar/features/recitation/recitation.dart';
import 'package:madar/features/wird/wird.dart';

import '../../../helpers/test_app.dart';
import '../../lock/lock_test_utils.dart';
import 'orbit_scene_fixtures.dart';

Future<void> _location(MadarDatabase db) => OrbitRepository(Repositories(db)).setPrayerSettings(hostPrayerSettings());

/// The location, and one new item to memorise.
Future<void> _withHifz(MadarDatabase db) async {
  await _location(db);
  await Repositories(db).hifzItems.insert(
    HifzItemsCompanion.insert(
      kind: const Value(HifzKind.custom),
      title: const Value('Dua'),
      body: const Value('Rabbi zidni ilma'),
    ),
  );
}

/// A tool tile of the grid, by its semantics ("title. hint").
Finder _tool(String title) => find.bySemanticsLabel(RegExp('^${RegExp.escape(title)}\\. '));

Future<void> _frames(WidgetTester tester, int n) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Future<TestApp> _faithPage(
  WidgetTester tester, {
  String lang = 'ar',
  MadarThemeId theme = MadarThemeId.lapis,
  Future<void> Function(MadarDatabase db) seed = _location,
}) async {
  final app = await pumpMadarApp(
    tester,
    settings: AppSettings(onboarded: true, languageCode: lang, themeId: theme),
    initialLocation: AppRoutes.planetOf('faith'),
    beforePump: seed,
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

      // The three movements, in order down the page, each under its title.
      final order = <Finder>[
        card,
        find.text(l.faithHubTodayTitle),
        find.byType(PrayerTodayCard),
        find.byType(AdhkarTodayCard),
        find.text(l.faithHubQuranTitle),
        find.byType(QuranContinueCard),
        find.byType(WirdTodayCard),
        find.text(l.faithHubToolsTitle),
        find.byType(QiblaCard),
        find.byType(FaithTools),
      ];
      double? previous;
      for (final f in order) {
        await _reveal(tester, f);
        expect(f, findsOneWidget);
        final top = tester.getTopLeft(f).dy + (tester.state<ScrollableState>(
          find.descendant(of: find.byType(PlanetModulePage), matching: find.byType(Scrollable)).first,
        ).position.pixels);
        if (previous != null) expect(top, greaterThan(previous), reason: '$f');
        previous = top;
      }
      // Nothing to memorise yet: no Hifz card (the grid's Hifz tool invites).
      expect(find.byType(HifzTodayCard), findsNothing);
      for (final title in [
        l.quranModeMushaf,
        l.hifzTitle,
        l.recitationTitle,
        l.adhkarTasbeehTitle,
        l.faithHubHistory,
        l.faithHubAdhanTool,
      ]) {
        await _reveal(tester, _tool(title));
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('every tool opens its page with a navigation sound; back returns to the Faith page', (tester) async {
    final app = await _faithPage(tester, lang: 'en');
    final l = lookupL10n(const Locale('en'));
    final pages = <String, (String, Type)>{
      l.quranModeMushaf: (AppRoutes.quran, QuranHomeScreen),
      l.hifzTitle: (AppRoutes.hifz, HifzScreen),
      l.recitationTitle: (AppRoutes.recitationSettings, RecitationSettingsScreen),
      l.adhkarTasbeehTitle: (AppRoutes.tasbeeh, TasbeehScreen),
      l.faithHubHistory: (AppRoutes.prayerTrackerHistory, PrayerTrackerScreen),
      l.faithHubAdhanTool: (AppRoutes.adhanSettings, AdhanSettingsScreen),
    };
    for (final MapEntry(key: title, value: (location, type)) in pages.entries) {
      final link = _tool(title);
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

  testWidgets('every text of the hub has a real style (no fallback underline)', (tester) async {
    await _faithPage(tester, lang: 'ar', seed: _withHifz);
    await _reveal(tester, find.byType(FaithTools));
    final texts = tester.widgetList<RichText>(
      find.descendant(of: find.byType(FaithHub), matching: find.byType(RichText), skipOffstage: false),
    );
    // The Quran card's page seal among them (a bare numeral style).
    expect(
      find.descendant(of: find.byType(QuranContinueCard), matching: find.text('١'), skipOffstage: false),
      findsOneWidget,
    );
    expect(texts.length, greaterThan(20));
    for (final t in texts) {
      expect(t.text.style?.decoration, isNot(TextDecoration.underline), reason: t.text.toPlainText());
    }
  });

  for (final lang in ['ar', 'en']) {
    testWidgets('$lang: the tools are a grid of three by two, flush with the cards', (tester) async {
      await _faithPage(tester, lang: lang);
      final l = lookupL10n(Locale(lang));
      await _reveal(tester, _tool(l.faithHubAdhanTool));
      final rects = [
        for (final t in [
          l.quranModeMushaf,
          l.hifzTitle,
          l.recitationTitle,
          l.adhkarTasbeehTitle,
          l.faithHubHistory,
          l.faithHubAdhanTool,
        ])
          tester.getRect(_tool(t)),
      ];
      // Rows: same tops and heights; columns: same edges and widths.
      for (final row in [rects.sublist(0, 3), rects.sublist(3)]) {
        for (final r in row) {
          expect(r.top, moreOrLessEquals(row.first.top, epsilon: 0.5));
          expect(r.height, moreOrLessEquals(row.first.height, epsilon: 0.5));
          expect(r.width, moreOrLessEquals(rects.first.width, epsilon: 0.5));
        }
      }
      for (var c = 0; c < 3; c++) {
        expect(rects[c + 3].left, moreOrLessEquals(rects[c].left, epsilon: 0.5));
      }
      expect(rects[3].top, greaterThan(rects[0].bottom));
      // Reading order: the mushaf first – on the right in Arabic.
      expect(rects[0].left > rects[2].left, lang == 'ar');
      // Flush with the qibla card above.
      final qibla = tester.getRect(find.byType(QiblaCard));
      final left = rects.map((r) => r.left).reduce((a, b) => a < b ? a : b);
      final right = rects.map((r) => r.right).reduce((a, b) => a > b ? a : b);
      expect(left, moreOrLessEquals(qibla.left, epsilon: 0.5));
      expect(right, moreOrLessEquals(qibla.right, epsilon: 0.5));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Hifz joins the Quran once it holds something; its review opens as a route', (tester) async {
    final app = await _faithPage(tester, lang: 'en', seed: _withHifz);
    final l = lookupL10n(const Locale('en'));
    await _reveal(tester, find.byType(HifzTodayCard));
    // Between the wird and the tools.
    expect(tester.getTopLeft(find.byType(HifzTodayCard)).dy, greaterThan(tester.getTopLeft(find.byType(WirdTodayCard)).dy));
    app.sound.played.clear();
    await tester.tap(find.text(l.hifzStartReview));
    await settleApp(tester);
    expect(find.byType(HifzReviewScreen), findsOneWidget);
    expect(app.location, AppRoutes.hifzReview);
    expect(app.sound.played, contains(Sfx.navigate));
    await tester.binding.handlePopRoute();
    await settleApp(tester);
    expect(find.byType(FaithHub), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('the Quran cards and the qibla open their routes', (tester) async {
    final app = await _faithPage(tester, lang: 'en');
    final l = lookupL10n(const Locale('en'));
    Future<void> back() async {
      await tester.binding.handlePopRoute();
      await settleApp(tester);
      expect(find.byType(FaithHub), findsOneWidget);
    }

    // "Index" in the Quran's header: the Quran's front page.
    await _reveal(tester, find.text(l.faithHubQuranIndex));
    await tester.tap(find.text(l.faithHubQuranIndex));
    await settleApp(tester);
    expect(find.byType(QuranHomeScreen), findsOneWidget);
    expect(app.location, AppRoutes.quran);
    await back();

    // Continue reading: the reader (al-Fatihah on a fresh install).
    await _reveal(tester, find.byType(QuranContinueCard));
    await tester.tap(find.byType(QuranContinueCard));
    await settleApp(tester);
    expect(find.byType(QuranReaderScreen), findsOneWidget);
    expect(app.location, AppRoutes.quranReader);
    await back();

    // A fresh install's wird card invites to start a plan (its routes are
    // covered with a plan in test/app/faith_hooks_test.dart).
    await _reveal(tester, find.byType(WirdTodayCard));
    expect(find.text(l.wirdStartPlanCta), findsOneWidget);

    // The qibla card: the compass (a still fake one).
    await _reveal(tester, find.byType(QiblaCard));
    await tester.tap(find.byType(QiblaCard));
    await settleApp(tester);
    expect(find.byType(QiblaScreen), findsOneWidget);
    expect(app.location, AppRoutes.qibla);
    await back();
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('a fresh day shows no "0" pills: no streak flame, the tasbeeh chip is just its name', (tester) async {
    await _faithPage(tester, lang: 'ar');
    final l = lookupL10n(const Locale('ar'));
    await _reveal(tester, find.byType(AdhkarTodayCard));
    expect(
      find.descendant(of: find.byType(PrayerTodayCard), matching: find.byIcon(Icons.local_fire_department_rounded)),
      findsNothing,
    );
    final card = find.byType(AdhkarTodayCard);
    expect(find.descendant(of: card, matching: find.text(l.adhkarTasbeehTitle)), findsOneWidget);
    expect(find.descendant(of: card, matching: find.textContaining('٠')), findsNothing);
  });

  for (final theme in MadarThemeId.values) {
    for (final lang in ['ar', 'en']) {
      testWidgets('renders in ${theme.name} / $lang without layout errors', (tester) async {
        await _faithPage(tester, lang: lang, theme: theme, seed: _withHifz);
        expect(find.byType(FaithHub), findsOneWidget);
        for (final f in [
          find.byType(AdhkarTodayCard),
          find.byType(WirdTodayCard),
          find.byType(HifzTodayCard),
          find.byType(QiblaCard),
          find.byType(FaithTools),
        ]) {
          await _reveal(tester, f);
          expect(tester.takeException(), isNull, reason: '$f');
        }
      });
    }
  }
}

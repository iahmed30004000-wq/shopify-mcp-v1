// Every Phase 3 route builds its screen in Arabic and English inside the
// full app (router, gates, adhan host, app lock), with the app's shared-axis
// transition; the parameters reach the screens; the Quran, wird and Hifz
// pages dock the mini player; the full player is a routed sheet.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/core/motion/transitions.dart';
import 'package:madar/core/quran/ayah.dart';
import 'package:madar/core/quran/quran_audio.dart';
import 'package:madar/core/routing/now_playing_dock.dart';
import 'package:madar/core/routing/router.dart';
import 'package:madar/core/settings/app_settings.dart';
import 'package:madar/features/hifz/hifz.dart';
import 'package:madar/features/qibla/qibla.dart';
import 'package:madar/features/quran/quran.dart';
import 'package:madar/features/recitation/recitation.dart';
import 'package:madar/features/settings/quran_settings_screen.dart';
import 'package:madar/features/settings/reminders_settings_screen.dart';
import 'package:madar/features/wird/wird.dart';

import '../../features/lock/lock_test_utils.dart';
import '../../helpers/test_app.dart';

Future<void> _frames(WidgetTester tester, [int n = 12]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Starts a recitation of al-Fatihah through the app's QuranAudio (the
/// harness's scripted engine plays it).
Future<void> _recite(WidgetTester tester, TestApp app) async {
  unawaited(app.container.read(quranAudioProvider).play(const AyahRange(AyahRef(1, 1), AyahRef(1, 7))));
  await _frames(tester);
  expect(app.container.read(recitationStateProvider).active, isTrue);
}

void main() {
  final routes = <(String, Type)>[
    (AppRoutes.quran, QuranHomeScreen),
    (AppRoutes.quranReaderOf(ayah: const AyahRef(2, 255)), QuranReaderScreen),
    (AppRoutes.quranReaderOf(page: 42), QuranReaderScreen),
    (AppRoutes.quranReader, QuranReaderScreen),
    (AppRoutes.quranSearch, QuranSearchScreen),
    (AppRoutes.wird, WirdScreen),
    (AppRoutes.hifz, HifzScreen),
    (AppRoutes.hifzReview, HifzReviewScreen),
    (AppRoutes.qibla, QiblaScreen),
    (AppRoutes.quranSettings, QuranSettingsScreen),
    (AppRoutes.recitationSettings, RecitationSettingsScreen),
    (AppRoutes.recitationDownloadsOf('minshawi.murattal'), RecitationDownloadsScreen),
    (AppRoutes.reminders, RemindersSettingsScreen),
  ];

  for (final lang in ['ar', 'en']) {
    group(lang, () {
      for (final (location, type) in routes) {
        testWidgets('$location builds $type', (tester) async {
          final app = await pumpMadarApp(
            tester,
            settings: AppSettings(onboarded: true, languageCode: lang),
            initialLocation: location,
            overrides: LockFixture.empty().overrides,
          );
          expect(find.byType(type), findsOneWidget);
          expect(tester.takeException(), isNull);
          expect(app.router.state.uri.toString(), location);
          expect(
            Directionality.of(tester.element(find.byType(type))),
            lang == 'ar' ? TextDirection.rtl : TextDirection.ltr,
          );
          // The app's own page transition, like every Phase 2 page.
          expect(ModalRoute.of(tester.element(find.byType(type)))!.settings, isA<MadarTransitionPage<void>>());
          // Nested below home: back leaves the page.
          await tester.binding.handlePopRoute();
          await settleApp(tester);
          expect(find.byType(type), findsNothing);
          await tester.pump(const Duration(seconds: 6));
        });
      }
    });
  }

  testWidgets('the parameters reach the screens', (tester) async {
    final app = await pumpMadarApp(
      tester,
      initialLocation: AppRoutes.quranReaderOf(ayah: const AyahRef(2, 255)),
      overrides: LockFixture.empty().overrides,
    );
    var reader = tester.widget<QuranReaderScreen>(find.byType(QuranReaderScreen));
    expect(reader.start, const AyahRef(2, 255));
    expect(reader.page, isNull);

    app.router.go(AppRoutes.quranReaderOf(page: 42));
    await settleApp(tester);
    reader = tester.widget<QuranReaderScreen>(find.byType(QuranReaderScreen));
    expect(reader.start, isNull);
    expect(reader.page, 42);

    // Out of range or malformed: the reader opens where it last stopped.
    app.router.go('${AppRoutes.quranReader}?page=900');
    await settleApp(tester);
    expect(tester.widget<QuranReaderScreen>(find.byType(QuranReaderScreen)).page, isNull);
    app.router.go('${AppRoutes.quranReader}?ayah=x');
    await settleApp(tester);
    expect(tester.widget<QuranReaderScreen>(find.byType(QuranReaderScreen)).start, isNull);

    app.router.go('${AppRoutes.quranSearch}?q=${Uri.encodeQueryComponent('الرحمن')}');
    await settleApp(tester);
    expect(tester.widget<QuranSearchScreen>(find.byType(QuranSearchScreen)).initialQuery, 'الرحمن');

    app.router.go(AppRoutes.wirdOf('plan-7'));
    await settleApp(tester);
    expect(tester.widget<WirdScreen>(find.byType(WirdScreen)).initialPlanId, 'plan-7');

    app.router.go(AppRoutes.recitationDownloadsOf('husary.mujawwad'));
    await settleApp(tester);
    expect(tester.widget<RecitationDownloadsScreen>(find.byType(RecitationDownloadsScreen)).reciter.id, 'husary.mujawwad');

    // A review of one card that is not there: today's queue instead.
    app.router.go(AppRoutes.hifzReviewOf('missing'));
    await settleApp(tester);
    expect(tester.widget<HifzReviewScreen>(find.byType(HifzReviewScreen)).only, isNull);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('an unknown reciter falls back to the recitation settings', (tester) async {
    final app = await pumpMadarApp(
      tester,
      initialLocation: AppRoutes.recitationDownloadsOf('nobody'),
      overrides: LockFixture.empty().overrides,
    );
    expect(find.byType(RecitationSettingsScreen), findsOneWidget);
    expect(app.location, AppRoutes.recitationSettings);
  });

  testWidgets('the Quran home opens the reader and the search as routes; back returns', (tester) async {
    final app = await pumpMadarApp(
      tester,
      settings: const AppSettings(onboarded: true, languageCode: 'en'),
      initialLocation: AppRoutes.quran,
      overrides: LockFixture.empty().overrides,
    );
    final l = lookupL10n(const Locale('en'));
    await tester.tap(find.text(l.quranSearchHint));
    await settleApp(tester);
    expect(find.byType(QuranSearchScreen), findsOneWidget);
    expect(app.location, AppRoutes.quranSearch);
    await tester.binding.handlePopRoute();
    await settleApp(tester);
    expect(app.location, AppRoutes.quran);

    // A sura of the index: the reader at its first ayah.
    await tester.tap(find.text('Al-Baqarah').first);
    await settleApp(tester);
    expect(find.byType(QuranReaderScreen), findsOneWidget);
    expect(app.location, AppRoutes.quranReader);
    await tester.binding.handlePopRoute();
    await settleApp(tester);
    expect(find.byType(QuranHomeScreen), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('the Quran, wird and Hifz pages dock the mini player only while a recitation plays', (tester) async {
    final app = await pumpMadarApp(tester, initialLocation: AppRoutes.hifz, overrides: LockFixture.empty().overrides);
    expect(find.byType(NowPlayingDock), findsOneWidget);
    Rect? bar() {
      final f = find.byKey(const ValueKey('now-playing-bar'));
      return f.evaluate().isEmpty ? null : tester.getRect(f);
    }

    expect(bar(), isNull);
    final before = tester.getRect(find.byType(HifzScreen));
    await _recite(tester, app);
    final docked = bar()!;
    // At the bottom, as wide as the page (less its margins) …
    expect(docked.bottom, lessThanOrEqualTo(915));
    expect(docked.bottom, greaterThan(915 - 24));
    // … and the page's own inset grew by at least its height: nothing on
    // the page is covered.
    final media = MediaQuery.of(tester.element(find.byType(HifzScreen)));
    expect(media.padding.bottom, greaterThanOrEqualTo(915 - docked.top - 0.5));
    expect(tester.getRect(find.byType(HifzScreen)), before);

    // The same player follows on the other pages.
    app.router.go(AppRoutes.quran);
    await settleApp(tester);
    expect(bar(), isNotNull);

    await app.container.read(quranAudioProvider).stop();
    await _frames(tester);
    expect(bar(), isNull);
    expect(MediaQuery.of(tester.element(find.byType(QuranHomeScreen))).padding.bottom, 0);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('/now-playing: the full player as a sheet while reciting; nothing playing, it closes', (tester) async {
    final app = await pumpMadarApp(tester, initialLocation: AppRoutes.quran, overrides: LockFixture.empty().overrides);
    unawaited(app.router.push(AppRoutes.nowPlaying));
    await settleApp(tester);
    expect(find.byType(NowPlayingSheet), findsNothing);
    expect(app.location, AppRoutes.quran);

    await _recite(tester, app);
    unawaited(app.router.push(AppRoutes.nowPlaying));
    // The dial turns while reciting: frames, not a settle.
    await _frames(tester);
    expect(find.byType(NowPlayingSheet), findsOneWidget);
    expect(app.location, AppRoutes.nowPlaying);
    // The page underneath stays.
    expect(find.byType(QuranHomeScreen), findsOneWidget);
    // The recitation ends: the sheet closes itself.
    await app.container.read(quranAudioProvider).stop();
    await _frames(tester, 20);
    expect(find.byType(NowPlayingSheet), findsNothing);
    expect(app.location, AppRoutes.quran);
    await tester.pump(const Duration(seconds: 6));
  });
}

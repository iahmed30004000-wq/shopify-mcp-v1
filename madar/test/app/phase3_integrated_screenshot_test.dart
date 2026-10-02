// Art-direction pass over the integrated Phase 3 experience inside the real
// app (router, AppGate, adhan host, app lock) with the real fonts and
// shaders: the Faith page's three movements, the Faith settings, and the
// mini player docked on Home and under the reader – Arabic/English across
// the Lapis, Pearl, Aurora and Desert themes. Writes PNGs to
// madar/screenshots/phase3/integrated/.
//
//   TZ=Asia/Amman flutter test --tags screenshot test/app/phase3_integrated_screenshot_test.dart
@Tags(['screenshot'])
library;

import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/app/app.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/design/themes.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/core/quran/ayah.dart';
import 'package:madar/core/quran/quran_audio.dart';
import 'package:madar/core/routing/router.dart';
import 'package:madar/core/settings/app_settings.dart';
import 'package:madar/features/hifz/hifz.dart';
import 'package:madar/features/orbit/data/orbit_repository.dart';
import 'package:madar/features/orbit/presentation/planet/faith_hub.dart';
import 'package:madar/features/orbit/presentation/planet/planet_page.dart';
import 'package:madar/features/qibla/qibla.dart' show QiblaCard;
import 'package:madar/features/quran/quran.dart';
import 'package:madar/features/wird/wird.dart';

import '../features/lock/lock_test_utils.dart';
import '../features/orbit/presentation/orbit_scene_fixtures.dart';
import '../features/qibla/qibla_test_app.dart' show readingAt;
import '../helpers/screenshot_harness.dart';
import '../helpers/test_app.dart';

const _dir = 'phase3/integrated';

const _all = [MadarThemeId.lapis, MadarThemeId.pearl, MadarThemeId.aurora, MadarThemeId.desert];

const _spread = [
  ('ar', MadarThemeId.lapis),
  ('en', MadarThemeId.pearl),
  ('ar', MadarThemeId.aurora),
  ('en', MadarThemeId.desert),
];

Future<void> _frames(WidgetTester tester, [int n = 16]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// A day with things to show: the location, a wird plan a few pages in, the
/// reader's last position, and three items to memorise.
Future<void> _lived(MadarDatabase db) async {
  final repos = Repositories(db);
  await OrbitRepository(repos).setPrayerSettings(hostPrayerSettings());
  await WirdService(repos, clock: () => testNow).create(
    WirdDraft(
      name: 'ختمة شهرية',
      template: WirdTemplate.khatma,
      khatmaDays: 30,
      start: const AyahRef(1, 1),
      startDate: DateTime(2026, 9, 20),
      window: PrayerWindow.fajr,
    ),
  );
  await QuranPrefsStore(repos.keyValues).saveLastRead(
    QuranLastRead(ref: const AyahRef(18, 10), page: 294, at: testNow, mode: QuranReaderMode.mushaf),
  );
  for (final (s, a, b) in [(67, 1, 5), (67, 6, 10), (112, 1, 4)]) {
    await repos.hifzItems.insert(
      HifzItemsCompanion.insert(
        kind: const Value(HifzKind.ayat),
        surah: Value(s),
        ayahFrom: Value(a),
        ayahTo: Value(b),
      ),
    );
  }
}

Future<void> _shot(
  WidgetTester tester,
  String name, {
  required String lang,
  required MadarThemeId theme,
  String location = AppRoutes.home,
  Future<void> Function(WidgetTester tester)? beforeCapture,
  int trailingFrames = 12,
  Future<void> Function(MadarDatabase db)? seed,
  void Function(TestAppSetup setup)? configure,
  double textScale = 1,
}) async {
  await preloadOrbitShaders(tester);
  if (textScale != 1) {
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }
  final setup = await buildMadarTestApp(
    tester,
    settings: AppSettings(onboarded: true, languageCode: lang, themeId: theme),
    initialLocation: location,
    beforePump: (db) async {
      await _lived(db);
      await seed?.call(db);
    },
    overrides: LockFixture.empty().overrides,
  );
  configure?.call(setup);
  final scale = textScale == 1 ? '' : '_x${(textScale * 10).round()}';
  await captureScreen(
    tester,
    setup.app,
    '$_dir/${name}_${lang}_${theme.name}$scale',
    beforeCapture: beforeCapture,
    trailingFrames: trailingFrames,
  );
}

ProviderContainer _container(WidgetTester tester) => ProviderScope.containerOf(tester.element(find.byType(MadarApp)));

/// Scrolls the planet sheet so [target] sits near the top.
Future<void> _sheetTo(WidgetTester tester, Finder target) async {
  final scrollable = find.descendant(of: find.byType(PlanetModulePage), matching: find.byType(Scrollable)).first;
  await tester.scrollUntilVisible(target, 200, scrollable: scrollable);
  await _frames(tester, 4);
  // Just under the sheet's top edge.
  final dy = tester.getTopLeft(target).dy - tester.getTopLeft(scrollable).dy - 60;
  await tester.drag(scrollable, Offset(0, -dy));
  await _frames(tester, 24);
}

Future<void> _recite(WidgetTester tester) async {
  unawaited(_container(tester).read(quranAudioProvider).play(const AyahRange(AyahRef(67, 1), AyahRef(67, 30))));
  await _frames(tester, 30);
}

/// The reader's settings (layout, size, tajweed, translation).
Future<void> Function(MadarDatabase db) _prefs(QuranReaderPrefs prefs) =>
    (db) => QuranPrefsStore(Repositories(db).keyValues).savePrefs(prefs);

/// Saheeh International for al-Fatihah, as a user download would leave it.
Future<void> _translation(WidgetTester tester) async {
  final body = File('test/features/quran/fixtures/qurancom_translation_20_chapter_1.json').readAsStringSync();
  final container = _container(tester);
  await tester.runAsync(
    () => container.read(quranCacheStoreProvider).write(QuranComClient.translationKey(20, 1), body),
  );
  container.invalidate(quranTranslationProvider);
  await _frames(tester, 20);
}

/// Hifz review: first letters, then three words.
Future<void> _midReveal(WidgetTester tester) async {
  final l = L10n.of(tester.element(find.byType(HifzReviewScreen)));
  await tester.tap(find.text(l.hifzRevealFirstLetters));
  await _frames(tester, 8);
  for (var i = 0; i < 3; i++) {
    await tester.tap(find.text(l.hifzRevealNextWord));
    await _frames(tester, 6);
  }
}

void main() {
  for (final lang in ['ar', 'en']) {
    for (final theme in _all) {
      testWidgets('hub quran $lang ${theme.name}', (tester) async {
        await _shot(
          tester,
          'hub_quran',
          lang: lang,
          theme: theme,
          location: AppRoutes.planetOf('faith'),
          beforeCapture: (tester) => _sheetTo(tester, find.byType(QuranContinueCard)),
        );
      });

      testWidgets('hub tools $lang ${theme.name}', (tester) async {
        await _shot(
          tester,
          'hub_tools',
          lang: lang,
          theme: theme,
          location: AppRoutes.planetOf('faith'),
          beforeCapture: (tester) => _sheetTo(tester, find.byType(QiblaCard)),
        );
      });
    }
  }

  for (final lang in ['ar', 'en']) {
    for (final theme in _all) {
      testWidgets('hub day $lang ${theme.name}', (tester) async {
        await _shot(
          tester,
          'hub_day',
          lang: lang,
          theme: theme,
          location: AppRoutes.planetOf('faith'),
          beforeCapture: (tester) => _sheetTo(tester, find.byType(NextPrayerCard)),
        );
      });
    }
  }

  // ------------------------------------------------ Phase 3 screens, routed

  for (final (lang, theme) in _spread) {
    testWidgets('quran index $lang ${theme.name}', (tester) async {
      await _shot(tester, 'quran_index', lang: lang, theme: theme, location: AppRoutes.quran);
    });

    testWidgets('mushaf tajweed $lang ${theme.name}', (tester) async {
      await _shot(
        tester,
        'mushaf_tajweed',
        lang: lang,
        theme: theme,
        location: AppRoutes.quranReaderOf(page: 440),
        seed: _prefs(const QuranReaderPrefs()),
        trailingFrames: 60,
        beforeCapture: (tester) => _frames(tester, 10),
      );
    });

    testWidgets('mushaf tajweed large $lang ${theme.name}', (tester) async {
      await _shot(
        tester,
        'mushaf_tajweed_large',
        lang: lang,
        theme: theme,
        location: AppRoutes.quranReaderOf(page: 582),
        seed: _prefs(const QuranReaderPrefs(fontSize: 40)),
        trailingFrames: 60,
        beforeCapture: (tester) => _frames(tester, 10),
      );
    });

    testWidgets('verses translation $lang ${theme.name}', (tester) async {
      await _shot(
        tester,
        'verses_translation',
        lang: lang,
        theme: theme,
        location: AppRoutes.quranReaderOf(ayah: const AyahRef(1, 1)),
        seed: _prefs(const QuranReaderPrefs(mode: QuranReaderMode.list, translation: true)),
        beforeCapture: _translation,
        trailingFrames: 70,
      );
    });

    testWidgets('search $lang ${theme.name}', (tester) async {
      await _shot(
        tester,
        'search',
        lang: lang,
        theme: theme,
        location: Uri(path: AppRoutes.quranSearch, queryParameters: {'q': 'الرحمن'}).toString(),
        trailingFrames: 30,
        beforeCapture: (tester) => _frames(tester, 20),
      );
    });

    testWidgets('now playing $lang ${theme.name}', (tester) async {
      await _shot(
        tester,
        'now_playing',
        lang: lang,
        theme: theme,
        location: AppRoutes.quran,
        beforeCapture: (tester) async {
          await _recite(tester);
          _container(tester).read(routerProvider).push(AppRoutes.nowPlaying);
          await _frames(tester, 30);
        },
        trailingFrames: 4,
      );
    });

    testWidgets('wird $lang ${theme.name}', (tester) async {
      await _shot(tester, 'wird', lang: lang, theme: theme, location: AppRoutes.wird, trailingFrames: 30);
    });

    testWidgets('hifz review $lang ${theme.name}', (tester) async {
      await _shot(
        tester,
        'hifz_review',
        lang: lang,
        theme: theme,
        location: AppRoutes.hifzReview,
        beforeCapture: _midReveal,
      );
    });

    testWidgets('qibla aligned $lang ${theme.name}', (tester) async {
      await _shot(
        tester,
        'qibla_aligned',
        lang: lang,
        theme: theme,
        location: AppRoutes.qibla,
        configure: (setup) => setup.faith.heading.initial = readingAt(160.7),
        trailingFrames: 40,
      );
    });

    testWidgets('qibla off $lang ${theme.name}', (tester) async {
      await _shot(
        tester,
        'qibla_off',
        lang: lang,
        theme: theme,
        location: AppRoutes.qibla,
        configure: (setup) => setup.faith.heading.initial = readingAt(262),
        trailingFrames: 40,
      );
    });

    testWidgets('settings faith $lang ${theme.name}', (tester) async {
      await _shot(
        tester,
        'settings_faith',
        lang: lang,
        theme: theme,
        location: AppRoutes.settings,
        beforeCapture: (tester) async {
          await tester.drag(find.byType(Scrollable).first, const Offset(0, -380));
          await _frames(tester, 24);
        },
      );
    });

    testWidgets('quran settings $lang ${theme.name}', (tester) async {
      await _shot(tester, 'quran_settings', lang: lang, theme: theme, location: AppRoutes.quranSettings);
    });

    testWidgets('reminders $lang ${theme.name}', (tester) async {
      await _shot(tester, 'reminders', lang: lang, theme: theme, location: AppRoutes.reminders);
    });

    testWidgets('home playing $lang ${theme.name}', (tester) async {
      await _shot(tester, 'home_playing', lang: lang, theme: theme, beforeCapture: _recite, trailingFrames: 4);
    });

    testWidgets('reader playing $lang ${theme.name}', (tester) async {
      await _shot(
        tester,
        'reader_playing',
        lang: lang,
        theme: theme,
        location: AppRoutes.quranReaderOf(ayah: const AyahRef(67, 1)),
        beforeCapture: _recite,
        trailingFrames: 4,
      );
    });
  }

  // ------------------------------------------------ text scale 1.3 (overflow)

  for (final (name, lang, theme, location, before) in <(String, String, MadarThemeId, String, Future<void> Function(WidgetTester)?)>[
    ('hub_quran', 'ar', MadarThemeId.lapis, AppRoutes.planetOf('faith'), (t) => _sheetTo(t, find.byType(QuranContinueCard))),
    ('hub_tools', 'en', MadarThemeId.pearl, AppRoutes.planetOf('faith'), (t) => _sheetTo(t, find.byType(QiblaCard))),
    ('quran_index', 'en', MadarThemeId.desert, AppRoutes.quran, null),
    ('wird', 'ar', MadarThemeId.aurora, AppRoutes.wird, null),
    ('hifz_review', 'en', MadarThemeId.lapis, AppRoutes.hifzReview, _midReveal),
    ('qibla_off', 'ar', MadarThemeId.pearl, AppRoutes.qibla, null),
    ('now_playing', 'ar', MadarThemeId.desert, AppRoutes.quran, (t) async {
      await _recite(t);
      _container(t).read(routerProvider).push(AppRoutes.nowPlaying);
      await _frames(t, 30);
    }),
    ('reader_playing', 'en', MadarThemeId.lapis, AppRoutes.quranReaderOf(ayah: const AyahRef(67, 1)), _recite),
  ]) {
    testWidgets('x1.3 $name $lang ${theme.name}', (tester) async {
      await _shot(
        tester,
        name,
        lang: lang,
        theme: theme,
        location: location,
        textScale: 1.3,
        beforeCapture: before,
        trailingFrames: name == 'qibla_off' ? 40 : 12,
        configure: name == 'qibla_off' ? (setup) => setup.faith.heading.initial = readingAt(262) : null,
      );
    });
  }
}

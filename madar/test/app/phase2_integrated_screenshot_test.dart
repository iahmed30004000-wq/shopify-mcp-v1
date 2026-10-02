// Art-direction pass over the integrated Phase 2 experience: every new page
// rendered inside the real app (router, AppGate, adhan host, app lock) with
// the real fonts and shaders, across Arabic/English and the Lapis, Pearl,
// Aurora and Desert themes. Writes PNGs to
// madar/screenshots/phase2/integrated/.
//
//   TZ=Asia/Amman flutter test --tags screenshot test/app/phase2_integrated_screenshot_test.dart
//
// Narrow with `--plain-name '<scene>'` (e.g. 'hub', 'times', 'lock').
@Tags(['screenshot'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/app/app.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/design/themes.dart';
import 'package:madar/core/domain/enums.dart';
import 'package:madar/core/i18n/formatters.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/core/notifications/notifications.dart';
import 'package:madar/core/routing/routes.dart';
import 'package:madar/core/settings/app_settings.dart';
import 'package:madar/features/adhan/adhan.dart';
import 'package:madar/features/adhkar/adhkar.dart';
import 'package:madar/features/lock/presentation/lock_screen.dart';
import 'package:madar/features/orbit/data/orbit_repository.dart';
import 'package:madar/features/orbit/presentation/planet/planet_page.dart';
import 'package:madar/features/prayer/prayer.dart';
import 'package:madar/features/prayer_tracker/prayer_tracker.dart';

import '../features/lock/lock_test_utils.dart';
import '../features/orbit/presentation/orbit_scene_fixtures.dart';
import '../helpers/screenshot_harness.dart';
import '../helpers/test_app.dart';

const _dir = 'phase2/integrated';

/// Sunday 27 Sep 2026 (the test app's day).
final DateTime _day = DateTime(2026, 9, 27);

const _all = [MadarThemeId.lapis, MadarThemeId.pearl, MadarThemeId.aurora, MadarThemeId.desert];

/// Every language × theme pair of the matrix.
Iterable<(String, MadarThemeId)> get _matrix sync* {
  for (final lang in ['ar', 'en']) {
    for (final t in _all) {
      yield (lang, t);
    }
  }
}

/// A spread of four pairs (each theme once, both languages).
const _spread = [
  ('ar', MadarThemeId.lapis),
  ('en', MadarThemeId.pearl),
  ('ar', MadarThemeId.aurora),
  ('en', MadarThemeId.desert),
];

DayTimes get _times => PrayerSchedule(hostPrayerSettings()).timesFor(_day);

Future<void> _frames(WidgetTester tester, [int n = 16]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _location(MadarDatabase db) => OrbitRepository(Repositories(db)).setPrayerSettings(hostPrayerSettings());

/// Today: Fajr on time with its sunnah, Dhuhr in jamaah at the mosque. The
/// three weeks before: mostly complete days, a few late, two missed (one
/// made up), so the streaks, heatmap and qada ledger all have content.
Future<void> _trackerLogs(MadarDatabase db) async {
  await _location(db);
  final repo = PrayerTrackerRepository(Repositories(db), clock: () => testNow);
  await repo.setStatus(_day, Prayer.fajr, PrayerStatus.prayed);
  await repo.toggleVoluntary(_day, Prayer.sunnahFajr);
  await repo.setStatus(_day, Prayer.dhuhr, PrayerStatus.prayed);
  await repo.setJamaah(_day, Prayer.dhuhr, true);
  await repo.setMosque(_day, Prayer.dhuhr, true);
  for (var back = 1; back <= 22; back++) {
    final d = DateTime(_day.year, _day.month, _day.day - back);
    for (final p in kObligatoryPrayers) {
      final code = (back * 7 + p.index * 3) % 23;
      final status = switch (code) {
        0 => PrayerStatus.missed,
        1 || 2 => PrayerStatus.late,
        _ => PrayerStatus.prayed,
      };
      if (back > 17 && p == Prayer.isha) continue; // a gap before tracking began
      await repo.setStatus(d, p, status);
      if (status == PrayerStatus.prayed && (back + p.index).isEven) await repo.setJamaah(d, p, true);
    }
    if (back.isEven) await repo.toggleVoluntary(d, Prayer.witr);
  }
}

Future<void> _adhkarProgress(MadarDatabase db, Map<AdhkarSetKey, AdhkarProgress> sets) async {
  await _location(db);
  final store = AdhkarProgressStore(Repositories(db).keyValues);
  for (final e in sets.entries) {
    await store.save(_day, e.key, e.value);
  }
}

Future<void> _midCount(MadarDatabase db) => _adhkarProgress(db, {
  const AdhkarSetKey(AdhkarCategoryId.morning): const AdhkarProgress(
    index: 7,
    counts: {
      'morning.01': 1,
      'morning.02': 3,
      'morning.03': 3,
      'morning.04': 3,
      'morning.05': 1,
      'morning.06': 1,
      'morning.07': 1,
      'morning.08': 2,
    },
  ),
});

AppSettings _settings(String lang, MadarThemeId theme, {bool onboarded = true}) =>
    AppSettings(onboarded: onboarded, languageCode: lang, themeId: theme);

L10n _l(String lang) => lookupL10n(Locale(lang));

String _digit(String lang, String d) => lang == 'ar' ? Digits.toArabicIndic(d) : d;

/// Renders the real app at [location] and writes `$_dir/<name>.png`.
Future<void> _shot(
  WidgetTester tester,
  String name, {
  required String lang,
  required MadarThemeId theme,
  String location = AppRoutes.home,
  bool onboarded = true,
  Future<void> Function(MadarDatabase db)? beforePump,
  Future<void> Function(WidgetTester tester)? beforeCapture,
  List<Override>? overrides,
  FakeNotificationPlatform? notifications,
  DateTime? now,
  double? textScale,
  int trailingFrames = 12,
  Duration settle = const Duration(milliseconds: 1600),
}) async {
  await preloadOrbitShaders(tester);
  if (textScale != null) {
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }
  final setup = await buildMadarTestApp(
    tester,
    settings: _settings(lang, theme, onboarded: onboarded),
    initialLocation: location,
    beforePump: beforePump ?? _location,
    overrides: overrides ?? LockFixture.empty().overrides,
    notifications: notifications,
    now: now,
  );
  final scale = textScale == null ? '' : '_x${(textScale * 10).round()}';
  await captureScreen(
    tester,
    setup.app,
    '$_dir/${name}_$lang${scale}_${theme.name}',
    beforeCapture: beforeCapture,
    trailingFrames: trailingFrames,
    settle: settle,
  );
}

ProviderContainer _container(WidgetTester tester) => ProviderScope.containerOf(tester.element(find.byType(MadarApp)));

AdhanEvent _adhan(AdhanSlot slot, DateTime at) => AdhanEvent(
  kind: AdhanKind.adhan,
  slot: slot,
  prayerAt: at,
  firedAt: at,
  day: DateTime.utc(at.year, at.month, at.day),
  notificationId: 100003,
  sound: AdhanSoundRef.tone(slot == AdhanSlot.fajr ? TanbihTone.dawn : TanbihTone.brass),
  minutesBefore: 0,
);

Future<void> _scrollFirst(WidgetTester tester, double by, {Finder? within}) async {
  final scrollable = within == null
      ? find.byType(Scrollable).first
      : find.descendant(of: within, matching: find.byType(Scrollable)).first;
  await tester.drag(scrollable, Offset(0, -by));
  await _frames(tester);
}

void main() {
  // ------------------------------------------------------------ full matrix
  for (final (lang, theme) in _matrix) {
    testWidgets('hub $lang ${theme.name}', (tester) async {
      await _shot(tester, 'hub', lang: lang, theme: theme, location: AppRoutes.planetOf('faith'));
    });

    testWidgets('times day $lang ${theme.name}', (tester) async {
      await _shot(tester, 'times_day', lang: lang, theme: theme, location: AppRoutes.prayerTimes);
    });

    testWidgets('reader mid-count $lang ${theme.name}', (tester) async {
      await _shot(tester, 'reader_count', lang: lang, theme: theme, location: '/adhkar/morning', beforePump: _midCount);
    });

    testWidgets('adhan maghrib $lang ${theme.name}', (tester) async {
      final at = _times.maghrib;
      await _shot(
        tester,
        'adhan_maghrib',
        lang: lang,
        theme: theme,
        now: at.add(const Duration(seconds: 5)),
        settle: const Duration(milliseconds: 800),
        beforeCapture: (tester) async {
          _container(tester).read(adhanEventProvider.notifier).present(_adhan(AdhanSlot.maghrib, at));
          await _frames(tester, 40);
        },
      );
    });

    testWidgets('lock hold $lang ${theme.name}', (tester) async {
      final fx = await LockFixture.configured();
      await _shot(
        tester,
        'lock_hold',
        lang: lang,
        theme: theme,
        overrides: fx.overrides,
        trailingFrames: 0,
        beforeCapture: (tester) async {
          await tester.startGesture(tester.getCenter(find.byType(LockScreen)) - const Offset(0, 40));
          await _frames(tester, 7);
        },
      );
    });
  }

  // ------------------------------------------------------------ the spread
  for (final (lang, theme) in _spread) {
    testWidgets('adhan fajr $lang ${theme.name}', (tester) async {
      final at = _times.fajr;
      await _shot(
        tester,
        'adhan_fajr',
        lang: lang,
        theme: theme,
        now: at.add(const Duration(seconds: 5)),
        settle: const Duration(milliseconds: 800),
        beforeCapture: (tester) async {
          _container(tester).read(adhanEventProvider.notifier).present(_adhan(AdhanSlot.fajr, at));
          await _frames(tester, 40);
        },
      );
    });

    testWidgets('lock pin $lang ${theme.name}', (tester) async {
      final fx = await LockFixture.configured(biometrics: false);
      await _shot(
        tester,
        'lock_pin',
        lang: lang,
        theme: theme,
        overrides: fx.overrides,
        beforeCapture: (tester) async {
          for (final d in ['2', '5']) {
            await tester.tap(find.text(_digit(lang, d)).last);
            await tester.pump(const Duration(milliseconds: 120));
          }
        },
      );
    });

    testWidgets('times month $lang ${theme.name}', (tester) async {
      await _shot(
        tester,
        'times_month',
        lang: lang,
        theme: theme,
        location: AppRoutes.prayerTimes,
        beforeCapture: (tester) async {
          await tester.tap(find.text(_l(lang).ptViewMonth));
          await _frames(tester, 24);
        },
      );
    });

    testWidgets('prayer settings $lang ${theme.name}', (tester) async {
      await _shot(tester, 'prayer_settings', lang: lang, theme: theme, location: AppRoutes.prayerSettings);
    });

    testWidgets('tracker today $lang ${theme.name}', (tester) async {
      await _shot(
        tester,
        'tracker_today',
        lang: lang,
        theme: theme,
        location: AppRoutes.prayerTracker,
        beforePump: _trackerLogs,
      );
    });

    testWidgets('tracker history $lang ${theme.name}', (tester) async {
      await _shot(
        tester,
        'tracker_history',
        lang: lang,
        theme: theme,
        location: AppRoutes.prayerTrackerHistory,
        beforePump: _trackerLogs,
      );
    });

    testWidgets('adhkar home $lang ${theme.name}', (tester) async {
      await _shot(
        tester,
        'adhkar_home',
        lang: lang,
        theme: theme,
        location: AppRoutes.adhkar,
        beforePump: (db) => _adhkarProgress(db, {
          const AdhkarSetKey(AdhkarCategoryId.morning): AdhkarProgress(
            index: 25,
            completedAt: DateTime(2026, 9, 27, 6, 40),
            logged: true,
          ),
        }),
      );
    });

    testWidgets('tasbeeh $lang ${theme.name}', (tester) async {
      await _shot(
        tester,
        'tasbeeh',
        lang: lang,
        theme: theme,
        location: AppRoutes.tasbeeh,
        beforeCapture: (tester) async {
          for (var i = 0; i < 12; i++) {
            await tester.tapAt(tester.getCenter(find.byType(TasbeehBeadRing)));
            await tester.pump(const Duration(milliseconds: 40));
          }
          await _frames(tester, 20);
        },
      );
    });

    testWidgets('adhan settings $lang ${theme.name}', (tester) async {
      await _shot(
        tester,
        'adhan_settings',
        lang: lang,
        theme: theme,
        location: AppRoutes.adhanSettings,
        notifications: FakeNotificationPlatform(exactAllowed: false, enabled: false),
      );
    });

    testWidgets('settings root $lang ${theme.name}', (tester) async {
      await _shot(tester, 'settings_root', lang: lang, theme: theme, location: AppRoutes.settings);
    });

    for (final step in [2, 3, 4]) {
      testWidgets('onboarding step ${step + 1} $lang ${theme.name}', (tester) async {
        await _shot(
          tester,
          'onboarding_step${step + 1}',
          lang: lang,
          theme: theme,
          onboarded: false,
          // A first run: nothing granted yet, so the adhan step lists them.
          notifications: FakeNotificationPlatform(exactAllowed: false, enabled: false),
          beforeCapture: (tester) async {
            final l = _l(lang);
            for (var i = 0; i < step; i++) {
              await tester.tap(find.text(i == 0 ? l.onboardingBegin : l.actionContinue));
              await _frames(tester, 20);
            }
          },
        );
      });
    }
  }

  // ------------------------------------------------------------ further down
  for (final (lang, theme) in [('ar', MadarThemeId.lapis), ('en', MadarThemeId.pearl)]) {
    for (final (scene, location, by, seedLogs) in [
      ('times_day', AppRoutes.prayerTimes, 900.0, false),
      ('prayer_settings', AppRoutes.prayerSettings, 1100.0, false),
      ('prayer_settings', AppRoutes.prayerSettings, 2200.0, false),
      ('adhan_settings', AppRoutes.adhanSettings, 1100.0, false),
      ('adhan_settings', AppRoutes.adhanSettings, 2200.0, false),
      ('adhkar_home', AppRoutes.adhkar, 1000.0, false),
      ('tracker_today', AppRoutes.prayerTracker, 1000.0, true),
      ('tracker_history', AppRoutes.prayerTrackerHistory, 1100.0, true),
      ('tracker_history', AppRoutes.prayerTrackerHistory, 2000.0, true),
      ('hub', AppRoutes.planetOf('faith'), 1400.0, false),
    ]) {
      testWidgets('scrolled $scene @$by $lang ${theme.name}', (tester) async {
        await _shot(
          tester,
          '${scene}_scrolled${by.round()}',
          lang: lang,
          theme: theme,
          location: location,
          beforePump: seedLogs ? _trackerLogs : null,
          notifications: scene == 'adhan_settings'
              ? FakeNotificationPlatform(exactAllowed: false, enabled: false)
              : null,
          beforeCapture: (tester) async {
            final within = scene == 'hub'
                ? find.byType(PlanetModulePage)
                : scene.startsWith('tracker')
                ? find.byType(scene == 'tracker_today' ? TrackerTodayView : TrackerHistoryView)
                : null;
            // Drag in steps (a single long fling would overshoot).
            for (var done = 0.0; done < by; done += 300) {
              await _scrollFirst(tester, by - done < 300 ? by - done : 300, within: within);
            }
          },
        );
      });
    }

    testWidgets('home $lang ${theme.name}', (tester) async {
      await _shot(tester, 'home', lang: lang, theme: theme);
    });

    testWidgets('security $lang ${theme.name}', (tester) async {
      await _shot(tester, 'security', lang: lang, theme: theme, location: AppRoutes.security);
    });
  }

  // ------------------------------------------------------------ single scenes
  for (final (lang, theme) in [('ar', MadarThemeId.lapis), ('en', MadarThemeId.pearl)]) {
    testWidgets('hub links $lang ${theme.name}', (tester) async {
      await _shot(
        tester,
        'hub_links',
        lang: lang,
        theme: theme,
        location: AppRoutes.planetOf('faith'),
        beforeCapture: (tester) => _scrollFirst(tester, 520, within: find.byType(PlanetModulePage)),
      );
    });

    testWidgets('location sheet $lang ${theme.name}', (tester) async {
      await _shot(
        tester,
        'location_sheet',
        lang: lang,
        theme: theme,
        location: AppRoutes.prayerTimes,
        beforeCapture: (tester) async {
          await tester.tap(find.byType(PrayerLocationChip));
          await _frames(tester, 24);
        },
      );
    });

    testWidgets('reader complete $lang ${theme.name}', (tester) async {
      await _shot(
        tester,
        'reader_complete',
        lang: lang,
        theme: theme,
        location: '/adhkar/waking',
        beforePump: (db) => _adhkarProgress(db, {
          const AdhkarSetKey(AdhkarCategoryId.waking): const AdhkarProgress(
            index: 3,
            counts: {'waking.01': 1, 'waking.02': 1, 'waking.03': 1},
          ),
        }),
        beforeCapture: (tester) async {
          await tester.tap(find.byType(AdhkarCounterRing));
          await _frames(tester, 30);
        },
      );
    });

    testWidgets('settings scrolled $lang ${theme.name}', (tester) async {
      await _shot(
        tester,
        'settings_scrolled',
        lang: lang,
        theme: theme,
        location: AppRoutes.settings,
        beforeCapture: (tester) => _scrollFirst(tester, 700),
      );
    });

    testWidgets('tracker empty $lang ${theme.name}', (tester) async {
      await _shot(tester, 'tracker_empty', lang: lang, theme: theme, location: AppRoutes.prayerTrackerHistory);
    });

    testWidgets('hub fresh $lang ${theme.name}', (tester) async {
      await _shot(
        tester,
        'hub_fresh',
        lang: lang,
        theme: theme,
        location: AppRoutes.planetOf('faith'),
        beforePump: (_) async {},
      );
    });
  }

  // ------------------------------------------------------------ text at 1.3×
  for (final (scene, lang, theme, location) in [
    ('hub', 'ar', MadarThemeId.lapis, AppRoutes.planetOf('faith')),
    ('times_day', 'ar', MadarThemeId.desert, AppRoutes.prayerTimes),
    ('times_day', 'en', MadarThemeId.pearl, AppRoutes.prayerTimes),
    ('tracker_today', 'en', MadarThemeId.aurora, AppRoutes.prayerTracker),
    ('tracker_history', 'ar', MadarThemeId.pearl, AppRoutes.prayerTrackerHistory),
    ('reader_count', 'ar', MadarThemeId.lapis, '/adhkar/morning'),
    ('adhkar_home', 'en', MadarThemeId.lapis, AppRoutes.adhkar),
    ('tasbeeh', 'ar', MadarThemeId.aurora, AppRoutes.tasbeeh),
    ('adhan_settings', 'en', MadarThemeId.desert, AppRoutes.adhanSettings),
    ('prayer_settings', 'ar', MadarThemeId.pearl, AppRoutes.prayerSettings),
    ('settings_root', 'ar', MadarThemeId.aurora, AppRoutes.settings),
  ]) {
    testWidgets('large text $scene $lang ${theme.name}', (tester) async {
      await _shot(
        tester,
        scene,
        lang: lang,
        theme: theme,
        location: location,
        textScale: 1.3,
        beforePump: scene.startsWith('tracker')
            ? _trackerLogs
            : scene == 'reader_count'
            ? _midCount
            : null,
        notifications: scene == 'adhan_settings' ? FakeNotificationPlatform(exactAllowed: false, enabled: false) : null,
      );
    });
  }

  for (final (lang, theme) in [('ar', MadarThemeId.lapis), ('en', MadarThemeId.aurora)]) {
    testWidgets('large text adhan $lang ${theme.name}', (tester) async {
      final at = _times.maghrib;
      await _shot(
        tester,
        'adhan_maghrib',
        lang: lang,
        theme: theme,
        textScale: 1.3,
        now: at.add(const Duration(seconds: 5)),
        settle: const Duration(milliseconds: 800),
        beforeCapture: (tester) async {
          _container(tester).read(adhanEventProvider.notifier).present(_adhan(AdhanSlot.maghrib, at));
          await _frames(tester, 40);
        },
      );
    });

    testWidgets('large text lock pin $lang ${theme.name}', (tester) async {
      final fx = await LockFixture.configured(biometrics: false);
      await _shot(tester, 'lock_pin', lang: lang, theme: theme, textScale: 1.3, overrides: fx.overrides);
    });

    testWidgets('large text onboarding step 3 $lang ${theme.name}', (tester) async {
      await _shot(
        tester,
        'onboarding_step3',
        lang: lang,
        theme: theme,
        onboarded: false,
        textScale: 1.3,
        beforeCapture: (tester) async {
          final l = _l(lang);
          for (var i = 0; i < 2; i++) {
            await tester.tap(find.text(i == 0 ? l.onboardingBegin : l.actionContinue));
            await _frames(tester, 20);
          }
        },
      );
    });
  }
}

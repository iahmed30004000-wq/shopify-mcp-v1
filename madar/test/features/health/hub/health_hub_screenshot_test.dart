// Art-direction pass over the integrated Health world inside the real app
// (router, AppGate, adhan host, app lock) with the real fonts and shaders:
// the Health planet's hub – standing alerts, today's care, the doctor's
// side, the tools – lived-in, on a fresh install and with the support note;
// and Settings › Health. Arabic/English across Lapis, Pearl and Aurora
// (Desert for a few). Writes PNGs to madar/screenshots/phase4/hub/.
//
//   TZ=Asia/Amman flutter test --tags screenshot test/features/health/hub/health_hub_screenshot_test.dart
@Tags(['screenshot'])
// The whole app renders in software here: a scene of glass cards costs about
// a second a frame on a busy host.
@Timeout(Duration(minutes: 40))
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/design/themes.dart';
import 'package:madar/core/routing/router.dart';
import 'package:madar/core/settings/app_settings.dart';
import 'package:madar/features/health/hub/health_hub.dart';
import 'package:madar/features/health/meds/meds.dart' show TodayDosesCard;
import 'package:madar/features/health/record/record.dart' show HealthAlertsBanner, NextAppointmentCard;
import 'package:madar/features/health/wellbeing/wellbeing.dart' show WellbeingTodayCard;
import 'package:madar/features/orbit/presentation/planet/planet_page.dart';
import 'package:madar/features/settings/health_settings_screen.dart';
import 'package:madar/features/settings/settings_screen.dart';

import '../../../helpers/screenshot_harness.dart';
import '../../../helpers/test_app.dart';
import '../../lock/lock_test_utils.dart';
import '../../orbit/presentation/orbit_scene_fixtures.dart';
import 'hub_seed.dart';

const _dir = 'phase4/hub';

const _themes = [MadarThemeId.lapis, MadarThemeId.pearl, MadarThemeId.aurora];

Future<void> _frames(WidgetTester tester, [int n = 16]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _shot(
  WidgetTester tester,
  String name, {
  required String lang,
  required MadarThemeId theme,
  String location = '/planet/health',
  HubSeed? seed = HubSeed.lived,
  Future<void> Function(WidgetTester tester)? beforeCapture,
  int trailingFrames = 8,
}) async {
  await preloadOrbitShaders(tester);
  final setup = await buildMadarTestApp(
    tester,
    settings: AppSettings(onboarded: true, languageCode: lang, themeId: theme),
    initialLocation: location,
    now: hubTestNow,
    beforePump: (MadarDatabase db) async {
      if (seed != null) {
        await seedHealthHub(db, lang: lang, seed: seed);
      } else {
        await seedHealthHub(db, lang: lang, seed: const HubSeed(meds: false, record: false, wellbeing: null));
      }
    },
    overrides: LockFixture.empty().overrides,
  );
  await captureScreen(
    tester,
    setup.app,
    '$_dir/${name}_${lang}_${theme.name}',
    beforeCapture: beforeCapture,
    trailingFrames: trailingFrames,
  );
}

/// Scrolls the planet sheet so [target] sits [below] its top edge. Jumps the
/// sheet's own scroll position (a drag loses its slop, and cards above that
/// finish loading grow the page), then aligns again once they have settled.
Future<void> _sheetTo(WidgetTester tester, Finder target, {double below = 60}) async {
  final scrollable = find
      .descendant(
        of: find.byType(PlanetModulePage),
        matching: find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down),
      )
      .first;
  final position = tester.state<ScrollableState>(scrollable).position;
  for (var pass = 0; pass < 3; pass++) {
    await _frames(tester, 4);
    final dy = tester.getTopLeft(target).dy - tester.getTopLeft(scrollable).dy - below;
    if (dy.abs() < 2) break;
    position.jumpTo((position.pixels + dy).clamp(position.minScrollExtent, position.maxScrollExtent));
  }
  await _frames(tester, 12);
}

/// Scrolls a settings page by [dy].
Future<void> _scroll(WidgetTester tester, Type page, double dy) async {
  final scrollable = find.descendant(of: find.byType(page), matching: find.byType(Scrollable)).first;
  await tester.drag(scrollable, Offset(0, -dy));
  await _frames(tester, 24);
}

void main() {
  for (final lang in ['ar', 'en']) {
    for (final theme in _themes) {
      testWidgets('hub top $lang ${theme.name}', (tester) async {
        await _shot(
          tester,
          'hub_top',
          lang: lang,
          theme: theme,
          beforeCapture: (tester) => _sheetTo(tester, find.byType(HealthAlertsBanner), below: 150),
        );
      });

      testWidgets('hub care $lang ${theme.name}', (tester) async {
        await _shot(
          tester,
          'hub_care',
          lang: lang,
          theme: theme,
          beforeCapture: (tester) => _sheetTo(tester, find.byType(TodayDosesCard), below: 70),
        );
      });

      testWidgets('hub pain $lang ${theme.name}', (tester) async {
        await _shot(
          tester,
          'hub_pain',
          lang: lang,
          theme: theme,
          beforeCapture: (tester) => _sheetTo(tester, find.byType(HealthPainCard), below: 300),
        );
      });

      testWidgets('hub doctor $lang ${theme.name}', (tester) async {
        await _shot(
          tester,
          'hub_doctor',
          lang: lang,
          theme: theme,
          beforeCapture: (tester) => _sheetTo(tester, find.byType(NextAppointmentCard), below: 70),
        );
      });

      testWidgets('hub tools $lang ${theme.name}', (tester) async {
        await _shot(
          tester,
          'hub_tools',
          lang: lang,
          theme: theme,
          beforeCapture: (tester) => _sheetTo(tester, find.byType(HealthTools), below: 200),
        );
      });

      testWidgets('settings health $lang ${theme.name}', (tester) async {
        await _shot(tester, 'settings_health', lang: lang, theme: theme, location: AppRoutes.healthSettings);
      });

      testWidgets('settings health scrolled $lang ${theme.name}', (tester) async {
        await _shot(
          tester,
          'settings_health_scrolled',
          lang: lang,
          theme: theme,
          location: AppRoutes.healthSettings,
          beforeCapture: (tester) => _scroll(tester, HealthSettingsScreen, 900),
        );
      });
    }

    testWidgets('hub fresh $lang', (tester) async {
      await _shot(
        tester,
        'hub_fresh',
        lang: lang,
        theme: lang == 'ar' ? MadarThemeId.lapis : MadarThemeId.pearl,
        seed: null,
        beforeCapture: (tester) => _sheetTo(tester, find.byType(TodayDosesCard), below: 120),
      );
    });

    testWidgets('hub support $lang', (tester) async {
      await _shot(
        tester,
        'hub_support',
        lang: lang,
        theme: lang == 'ar' ? MadarThemeId.desert : MadarThemeId.pearl,
        seed: HubSeed.lowMood,
        beforeCapture: (tester) => _sheetTo(tester, find.byType(WellbeingTodayCard), below: 40),
      );
    });

    testWidgets('settings root $lang', (tester) async {
      await _shot(
        tester,
        'settings_root',
        lang: lang,
        theme: lang == 'ar' ? MadarThemeId.lapis : MadarThemeId.pearl,
        location: AppRoutes.settings,
        beforeCapture: (tester) => _scroll(tester, SettingsScreen, 520),
      );
    });
  }
}

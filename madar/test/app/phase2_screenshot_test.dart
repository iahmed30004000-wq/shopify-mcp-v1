// Visual pass over the Phase 2 integration inside the real app: the Faith
// planet's hub, the settings hub's new sections, the new onboarding steps,
// the home header with the Hijri date and the "All times" chip, and the
// adhan shown above the app lock. Writes PNGs to madar/screenshots/phase2/app/.
//
//   TZ=Asia/Amman flutter test --tags screenshot test/app/phase2_screenshot_test.dart
@Tags(['screenshot'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/db/repositories/repositories.dart';
import 'package:madar/core/design/themes.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/core/routing/routes.dart';
import 'package:madar/core/settings/app_settings.dart';
import 'package:madar/features/orbit/data/orbit_repository.dart';
import 'package:madar/features/orbit/presentation/planet/planet_page.dart';

import '../features/lock/lock_test_utils.dart';
import '../features/orbit/presentation/orbit_scene_fixtures.dart';
import '../helpers/screenshot_harness.dart';
import '../helpers/test_app.dart';

Future<void> _location(MadarDatabase db) => OrbitRepository(Repositories(db)).setPrayerSettings(hostPrayerSettings());

Future<void> _frames(WidgetTester tester, [int n = 16]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _scrollSheet(WidgetTester tester, double by) async {
  final scrollable = find.descendant(of: find.byType(PlanetModulePage), matching: find.byType(Scrollable)).first;
  await tester.drag(scrollable, Offset(0, -by));
  await _frames(tester);
}

void main() {
  for (final (lang, theme) in [('ar', MadarThemeId.lapis), ('en', MadarThemeId.pearl), ('ar', MadarThemeId.desert)]) {
    testWidgets('faith hub – $lang ${theme.name}', (tester) async {
      final setup = await buildMadarTestApp(
        tester,
        settings: AppSettings(onboarded: true, languageCode: lang, themeId: theme),
        initialLocation: AppRoutes.planetOf('faith'),
        beforePump: _location,
        overrides: LockFixture.empty().overrides,
      );
      await captureScreen(tester, setup.app, 'phase2/app/faith_hub_${lang}_${theme.name}');
    });
  }

  for (final (lang, theme) in [('ar', MadarThemeId.emerald), ('en', MadarThemeId.aurora)]) {
    testWidgets('faith hub links – $lang ${theme.name}', (tester) async {
      final setup = await buildMadarTestApp(
        tester,
        settings: AppSettings(onboarded: true, languageCode: lang, themeId: theme),
        initialLocation: AppRoutes.planetOf('faith'),
        beforePump: _location,
        overrides: LockFixture.empty().overrides,
      );
      await captureScreen(
        tester,
        setup.app,
        'phase2/app/faith_hub_links_${lang}_${theme.name}',
        beforeCapture: (tester) => _scrollSheet(tester, 520),
      );
    });
  }

  for (final (lang, theme, scroll) in [
    ('ar', MadarThemeId.lapis, 300.0),
    ('en', MadarThemeId.pearl, 300.0),
    ('ar', MadarThemeId.aurora, 800.0),
  ]) {
    testWidgets('settings hub – $lang ${theme.name} @$scroll', (tester) async {
      final setup = await buildMadarTestApp(
        tester,
        settings: AppSettings(onboarded: true, languageCode: lang, themeId: theme),
        initialLocation: AppRoutes.settings,
        beforePump: _location,
        overrides: LockFixture.empty().overrides,
      );
      await captureScreen(
        tester,
        setup.app,
        'phase2/app/settings_${lang}_${theme.name}_${scroll.round()}',
        beforeCapture: (tester) async {
          await tester.drag(find.byType(Scrollable).first, Offset(0, -scroll));
          await _frames(tester);
        },
      );
    });
  }

  testWidgets('security page – ar lapis', (tester) async {
    final setup = await buildMadarTestApp(
      tester,
      initialLocation: AppRoutes.security,
      overrides: LockFixture.empty().overrides,
    );
    await captureScreen(tester, setup.app, 'phase2/app/security_ar_lapis');
  });

  for (final (step, lang, theme) in [
    (2, 'ar', MadarThemeId.lapis),
    (3, 'ar', MadarThemeId.emerald),
    (4, 'en', MadarThemeId.aurora),
    (2, 'en', MadarThemeId.pearl),
  ]) {
    testWidgets('onboarding step ${step + 1} – $lang ${theme.name}', (tester) async {
      final setup = await buildMadarTestApp(
        tester,
        settings: AppSettings(languageCode: lang, themeId: theme),
        overrides: LockFixture.empty().overrides,
      );
      await captureScreen(
        tester,
        setup.app,
        'phase2/app/onboarding_step${step + 1}_${lang}_${theme.name}',
        beforeCapture: (tester) async {
          for (var i = 0; i < step; i++) {
            final l = lookupL10n(Locale(lang));
            await tester.tap(find.text(i == 0 ? l.onboardingBegin : l.actionContinue));
            await _frames(tester, 20);
          }
        },
      );
    });
  }

  testWidgets('home header and chips – ar lapis', (tester) async {
    final setup = await buildMadarTestApp(tester, beforePump: _location, overrides: LockFixture.empty().overrides);
    await captureScreen(
      tester,
      setup.app,
      'phase2/app/home_ar_lapis',
      beforeCapture: (tester) async {
        final chips = find.byType(SingleChildScrollView).first;
        await tester.drag(chips, const Offset(600, 0));
        await _frames(tester);
      },
    );
  });
}

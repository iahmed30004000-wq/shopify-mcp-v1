@Tags(['screenshot'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/design/themes.dart';
import 'package:madar/features/orbit/domain/scene_math.dart';
import 'package:madar/features/orbit/render/sky/sky.dart';

import '../../../../helpers/screenshot_harness.dart';
import 'sky_fixtures.dart';

/// The living sky at real times for Amman (UTC+3) – look at every PNG in
/// screenshots/sky_*.png.
void main() {
  setUpAll(() async {
    await loadMadarFonts();
  });

  Future<void> shoot(
    WidgetTester tester,
    SkyShot shot, {
    MadarThemeId theme = MadarThemeId.lapis,
    bool context = false,
    Locale locale = const Locale('ar'),
    OrbitCamera camera = const OrbitCamera(),
    String tag = '',
  }) async {
    await tester.runAsync(SkyPrograms.load);
    final suffix = theme == MadarThemeId.lapis ? '' : '_${theme.name}';
    final name = 'sky_${shot.name}${context ? '_scene' : ''}$suffix${locale.languageCode == 'en' ? '_en' : ''}$tag';
    await captureScreen(
      tester,
      madarScreenshotApp(
        theme: theme,
        locale: locale,
        home: SkyPreviewScene(time: shot.time, withScene: context, camera: camera),
      ),
      name,
      dpr: 2,
      settle: const Duration(milliseconds: 700),
    );
  }

  for (final shot in SkyShot.all) {
    testWidgets('sky ${shot.name}', (tester) async {
      await shoot(tester, shot);
    });
  }

  // Every theme at four moments (the palette harmonises with each theme).
  for (final theme in MadarThemeId.values) {
    if (theme == MadarThemeId.lapis) continue;
    for (final shot in [SkyShot.fajr, SkyShot.noon, SkyShot.maghrib, SkyShot.night]) {
      testWidgets('sky ${shot.name} ${theme.name}', (tester) async {
        await shoot(tester, shot, theme: theme, context: true);
      });
    }
  }

  // The orbit camera swung round, raised and rolled: the sky turns 0.12×
  // and the horizon (with its ground veil) tilts with the roll.
  testWidgets('sky maghrib orbit rolled', (tester) async {
    await shoot(
      tester,
      SkyShot.maghrib,
      camera: const OrbitCamera(azimuth: 1.4, elevation: 0.55, roll: 0.12),
      tag: '_rolled',
      context: true,
    );
  });

  // English star names; Pearl nights (luminous, with stars and the moon).
  testWidgets('sky milky way en', (tester) async {
    await shoot(tester, SkyShot.milkyWay, locale: const Locale('en'));
  });
  for (final shot in [SkyShot.newMoon, SkyShot.crescent, SkyShot.golden]) {
    testWidgets('sky ${shot.name} pearl', (tester) async {
      await shoot(tester, shot, theme: MadarThemeId.pearl);
    });
  }

  // In context: astrolabe stand-in, glass panel and lens flares.
  for (final shot in SkyShot.all) {
    testWidgets('sky scene ${shot.name}', (tester) async {
      await shoot(tester, shot, context: true);
    });
  }
}

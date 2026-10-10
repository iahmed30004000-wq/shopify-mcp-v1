@Tags(['screenshot'])
library;

import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/cinema/engine/cinema_engine.dart';
import 'package:madar/features/cinema/engine/fx/fx.dart';
import 'package:madar/features/cinema/games/demo/demo_game.dart';

import '../../../helpers/screenshot_harness.dart';

// The intermission (projector booth) and the results marquee over a live
// demo scene, through the whole engine – screenshots/cinema/stage/. Arabic
// for every era shown; English (`_en`) for one booth and one marquee to
// check the cards in both reading directions.
void main() {
  setUpAll(() async {
    await loadMadarFonts();
    await CinemaShaders.preload();
    await FxShaders.preload();
  });

  for (final (era, locale) in const [
    (Era.rubberHose, Locale('ar')),
    (Era.technicolor, Locale('ar')),
    (Era.noir, Locale('ar')),
    (Era.vhs, Locale('ar')),
    (Era.rubberHose, Locale('en')),
  ]) {
    final suffix = locale.languageCode == 'ar' ? '' : '_${locale.languageCode}';
    testWidgets('pause booth – ${era.name}$suffix', (tester) async {
      DemoGame? game;
      await captureScreen(
        tester,
        ProviderScope(
          child: madarScreenshotApp(
            locale: locale,
            home: CinemaGameView(
              builder: (ctx) => game = DemoGame(context: ctx, era: era, autoplay: true),
              skipOpening: true,
            ),
          ),
        ),
        'cinema/stage/pause_${era.name}$suffix',
        settle: const Duration(milliseconds: 1200),
        beforeCapture: (tester) async {
          game!.addScore(420);
          game!.pauseGame();
        },
        trailingFrames: 22,
      );
    });
  }

  for (final (era, locale) in const [
    (Era.silent, Locale('ar')),
    (Era.technicolor, Locale('ar')),
    (Era.grindhouse, Locale('ar')),
    (Era.vhs, Locale('ar')),
    (Era.technicolor, Locale('en')),
  ]) {
    final suffix = locale.languageCode == 'ar' ? '' : '_${locale.languageCode}';
    testWidgets('results marquee – ${era.name}$suffix', (tester) async {
      DemoGame? game;
      await captureScreen(
        tester,
        ProviderScope(
          child: madarScreenshotApp(
            locale: locale,
            home: CinemaGameView(
              builder: (ctx) => game = DemoGame(context: ctx, era: era, autoplay: true),
              skipOpening: true,
            ),
          ),
        ),
        'cinema/stage/results_${era.name}$suffix',
        settle: const Duration(milliseconds: 800),
        beforeCapture: (tester) async {
          final g = game!;
          g.hud.best = 900;
          g.addScore(1350);
          g.endScene(won: era != Era.grindhouse);
          for (var i = 0; i < 200 && g.state != SceneState.ended; i++) {
            await tester.pump(const Duration(milliseconds: 50));
          }
        },
        trailingFrames: 44,
      );
    });
  }
}

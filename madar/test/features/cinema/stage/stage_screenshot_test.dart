@Tags(['screenshot'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/cinema/engine/cinema_engine.dart';
import 'package:madar/features/cinema/engine/fx/fx.dart';
import 'package:madar/features/cinema/engine/stage/stage_kit.dart';

import '../../../helpers/screenshot_harness.dart';
import 'stage_harness.dart';

// The stage agent's visual checks (screenshots/cinema/stage/*.png): the
// theatre of every era with the curtains open and the HUD kit in play, the
// curtains mid-haul, and the transitions. LOOK at them after every change.
void main() {
  setUpAll(() async {
    await loadMadarFonts();
    await CinemaShaders.preload();
    await FxShaders.preload();
  });

  for (final era in Era.values) {
    testWidgets('stage frame – ${era.name}', (tester) async {
      final ar = await arabic();
      final scene = StageScene(era)..layout(const Size(412, 915));
      (scene.stage as ReelStage).motion.jumpTo(1);
      scene.model
        ..score = 980
        ..best = 1200
        ..lives = 3
        ..maxLives = 3
        ..bossHealth = 1
        ..bossName = ar.cinemaRigZunbruk;
      scene
        ..place(HudSlot.topStart, scene.hudKit.score())
        ..place(HudSlot.topCenter, scene.hudKit.lives())
        ..place(HudSlot.topEnd, scene.hudKit.pauseButton(() {}))
        ..place(HudSlot.bottomCenter, scene.hudKit.bossBar());
      scene.run(0.5);
      // A hit: a life lost, the boss burnt back, points rolling in.
      scene.model
        ..lives = 2
        ..bossHealth = 0.58
        ..score = 1250;
      scene.run(0.42);
      await shootScene(tester, scene, 'stage_${era.name}');
      scene.dispose();
    });
  }

  testWidgets('curtains mid-haul (opening) – technicolor', (tester) async {
    final scene = StageScene(Era.technicolor)..layout(const Size(412, 915));
    scene.stage.openCurtains();
    scene.run(0.62);
    await shootScene(tester, scene, 'curtains_opening_technicolor');
    scene.dispose();
  });

  testWidgets('curtains closed – rubberHose', (tester) async {
    final scene = StageScene(Era.rubberHose)..layout(const Size(412, 915));
    scene.run(0.5);
    await shootScene(tester, scene, 'curtains_closed_rubberHose');
    scene.dispose();
  });
}

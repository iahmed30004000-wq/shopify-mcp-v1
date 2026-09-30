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
// theatre of every era with the curtains open, the curtains mid-haul, the
// HUD kit and the transitions. LOOK at them after every stage change.
void main() {
  setUpAll(() async {
    await loadMadarFonts();
    await CinemaShaders.preload();
    await FxShaders.preload();
  });

  for (final era in Era.values) {
    testWidgets('stage frame – ${era.name}', (tester) async {
      final scene = StageScene(era)..layout(const Size(412, 915));
      (scene.stage as ReelStage).motion.jumpTo(1);
      scene.run(1.3);
      await shootScene(tester, scene, 'stage_${era.name}');
      scene.dispose();
    });
  }
}

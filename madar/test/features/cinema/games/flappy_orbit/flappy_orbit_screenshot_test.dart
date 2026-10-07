@Tags(['screenshot'])
library;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/cinema/engine/cinema_engine.dart';
import 'package:madar/features/cinema/games/flappy_orbit/flappy_orbit_game.dart';
import 'package:madar/features/cinema/games/flappy_orbit/flappy_orbit_logic.dart';

import '../../../../helpers/screenshot_harness.dart';
import 'flappy_orbit_support.dart';

// Renders Flappy Orbit through the real kit and shaders (SkSL in
// flutter_tester) at chosen moments into screenshots/cinema/games/flappy_orbit/*.png:
// the title card, the launch pad, mid-flight (Arabic and English), the
// three Maestro phases, him blowing away, the pie crash, the loop-the-loop,
// the intermission and the results (Arabic and English). Look at them after
// every change.
void main() {
  setUpAll(() async {
    await loadMadarFonts();
    await CinemaShaders.preload();
  });

  Future<void> shoot(
    WidgetTester tester,
    String moment,
    Future<void> Function(FlappyOrbitGame g) drive, {
    Locale locale = const Locale('ar'),
    bool opening = false,
    bool autoplay = true,
    int gatesPerBoss = 2,
    int bossCount = 3,
    int trailingFrames = 2,
  }) async {
    final suffix = locale.languageCode == 'ar' ? '' : '_${locale.languageCode}';
    await captureScreen(
      tester,
      ProviderScope(
        child: madarScreenshotApp(
          locale: locale,
          home: OrbitTestScreen(autoplay: autoplay, skipOpening: !opening, gatesPerBoss: gatesPerBoss, bossCount: bossCount),
        ),
      ),
      'cinema/games/flappy_orbit/flappy_orbit_$moment$suffix',
      settle: const Duration(milliseconds: 250),
      trailingFrames: trailingFrames,
      beforeCapture: (t) async {
        final g = mountedOrbit(t);
        await runUntil(g, () => g.state != SceneState.loading, maxSeconds: 3, what: 'load');
        await drive(g);
      },
    );
  }

  Future<void> toPlay(FlappyOrbitGame g) => runUntil(g, () => g.isPlaying, maxSeconds: 10, what: 'play');

  Future<void> toBoss(FlappyOrbitGame g) async {
    await toPlay(g);
    await runUntil(g, () => g.act == FlappyAct.boss, maxSeconds: 60, what: 'the fight');
  }

  testWidgets('title card', (tester) async {
    await shoot(tester, 'card', (g) => runFor(g, 1.0), opening: true, autoplay: false);
  });

  testWidgets('iris-in onto the launch pad', (tester) async {
    await shoot(
      tester,
      'iris',
      (g) => runUntil(g, () => g.state == SceneState.opening && g.transitions.coverage < 0.5 && g.transitions.coverage > 0.2, maxSeconds: 10, what: 'iris'),
      opening: true,
      autoplay: false,
    );
  });

  testWidgets('winding the key on the pad', (tester) async {
    await shoot(tester, 'pad', (g) async {
      await toPlay(g);
      await runFor(g, 1.4);
    }, autoplay: false);
  });

  testWidgets('lift-off', (tester) async {
    await shoot(tester, 'liftoff', (g) async {
      await toPlay(g);
      await runFor(g, 0.4);
      g.onScreenTapDown(Vector2.zero(), Offset.zero);
      await runFor(g, 0.55);
    }, autoplay: false);
  });

  for (final locale in const [Locale('ar'), Locale('en')]) {
    testWidgets('mid-flight – ${locale.languageCode}', (tester) async {
      await shoot(tester, 'play', (g) async {
        await toPlay(g);
        await runUntil(g, () => g.gatesPassed >= 3 && g.pilot.action == RigAction.jump && g.pilot.actionTime < 0.2, maxSeconds: 30, what: 'a boost between gates');
      }, locale: locale, gatesPerBoss: 8);
    });
  }

  testWidgets('a near miss callout', (tester) async {
    await shoot(tester, 'nearmiss', (g) async {
      await toPlay(g);
      await runUntil(g, () => g.style.nearMisses > 0 || g.style.rhythmBonuses > 0, maxSeconds: 60, what: 'a style bonus');
      await runFor(g, 0.1);
    }, gatesPerBoss: 50);
  });

  testWidgets('a hit', (tester) async {
    await shoot(tester, 'hit', (g) async {
      await toPlay(g);
      await runFor(g, 1.5);
      g.autoplay = false;
      await runUntil(g, () => g.hud.lives == 2, maxSeconds: 8, what: 'hit');
      await runFor(g, 0.1);
    }, gatesPerBoss: 8);
  });

  testWidgets('chapter card', (tester) async {
    await shoot(tester, 'chapter', (g) async {
      await toPlay(g);
      await runUntil(g, () => g.act == FlappyAct.bossIntro, maxSeconds: 30, what: 'intro');
      await runFor(g, 0.9);
    });
  });

  testWidgets('the Maestro floats in', (tester) async {
    await shoot(tester, 'bossenters', (g) async {
      await toPlay(g);
      await runUntil(g, () => g.act == FlappyAct.bossIntro && g.bossCardDone, maxSeconds: 30, what: 'card done');
      await runFor(g, 0.3);
    });
  });

  testWidgets('phase one: a gust', (tester) async {
    await shoot(tester, 'boss1', (g) async {
      await toBoss(g);
      await runUntil(g, () => g.attacks.activeGusts > 0 && g.maestro.actionTime > 0.15 && g.maestro.actionTime < 0.5, maxSeconds: 15, what: 'a gust');
    });
  });

  testWidgets('phase one: cheeks puffed (the tell)', (tester) async {
    await shoot(tester, 'boss1tell', (g) async {
      await toBoss(g);
      await runUntil(g, () => g.brain!.step == BossStep.windUp && g.brain!.timer > 0.5, maxSeconds: 15, what: 'wind-up');
    });
  });

  testWidgets('phase two: thunder-notes', (tester) async {
    await shoot(tester, 'boss2', (g) async {
      await toBoss(g);
      await runUntil(g, () => g.brain!.phase == BossPhase.thunder, maxSeconds: 60, what: 'phase two');
      await runUntil(g, () => g.attacks.activeNotes > 0 && g.attacks.noteX(0) < 260, maxSeconds: 20, what: 'notes in the air');
    });
  });

  testWidgets('phase three: the stage spins', (tester) async {
    await shoot(tester, 'boss3', (g) async {
      await toBoss(g);
      await runUntil(g, () => g.brain!.phase == BossPhase.spin, maxSeconds: 90, what: 'phase three');
      await runUntil(g, () => g.stageAngle.abs() > 0.12, maxSeconds: 10, what: 'a tilt');
    });
  });

  testWidgets('the Maestro takes a hit', (tester) async {
    await shoot(tester, 'bosshurt', (g) async {
      await toBoss(g);
      await runUntil(g, () => g.maestro.action == RigAction.hurt && g.maestro.actionTime > 0.08, maxSeconds: 30, what: 'a dodge');
    });
  });

  testWidgets('the Maestro blows away', (tester) async {
    await shoot(tester, 'bossdown', (g) async {
      await toBoss(g);
      await runUntil(g, () => g.act == FlappyAct.bossOutro, maxSeconds: 120, what: 'defeat');
      await runFor(g, 0.5);
    });
  });

  testWidgets('crash into the pie', (tester) async {
    await shoot(tester, 'pie', (g) async {
      await toPlay(g);
      await runFor(g, 1.5);
      g.autoplay = false;
      await runUntil(g, () => g.act == FlappyAct.crash && g.pie.splat > 0, maxSeconds: 30, what: 'splat');
      await runFor(g, 0.35);
    }, gatesPerBoss: 8);
  });

  testWidgets('the loop-the-loop', (tester) async {
    await shoot(tester, 'loop', (g) async {
      await toPlay(g);
      await runUntil(g, () => g.act == FlappyAct.finale, maxSeconds: 150, what: 'the finale');
      await runFor(g, 0.9);
    }, bossCount: 1);
  });

  for (final locale in const [Locale('ar'), Locale('en')]) {
    testWidgets('intermission – ${locale.languageCode}', (tester) async {
      await shoot(tester, 'pause', (g) async {
        await toPlay(g);
        await runFor(g, 2.5);
        g.pauseGame();
      }, locale: locale, gatesPerBoss: 8, trailingFrames: 14);
    });

    testWidgets('results – ${locale.languageCode}', (tester) async {
      await shoot(tester, 'results', (g) async {
        await toPlay(g);
        await runFor(g, 4);
        g.autoplay = false;
        await runUntil(g, () => g.state == SceneState.ended, maxSeconds: 60, what: 'results');
      }, locale: locale, gatesPerBoss: 8, trailingFrames: 26);
    });
  }
}

@Tags(['screenshot'])
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/cinema/engine/cinema_engine.dart';
import 'package:madar/features/cinema/engine/rig/rig_kit.dart';
import 'package:madar/features/cinema/games/demo/demo_game.dart';
import 'package:madar/features/cinema/games/demo/demo_screen.dart';

import '../../../helpers/screenshot_harness.dart';
import 'demo_support.dart';

// Renders the vignette through the real kit and shaders (SkSL in
// flutter_tester) at chosen moments into screenshots/cinema/demo/*.png.
// Every era: act one mid-jump and the Baron's slam. The 1930s reel also
// gets the whole arc: opening card, iris-in, a hit, the chapter card, the
// Baron's blast, him taking a hit, the curtain call, the iris-out, the end
// card and the results marquee. Look at them after every engine change.
void main() {
  setUpAll(() async {
    await loadMadarFonts();
    await CinemaShaders.preload();
  });

  Future<void> shoot(
    WidgetTester tester,
    Era era,
    String moment,
    Future<void> Function(DemoGame g) drive, {
    bool opening = false,
    int trailingFrames = 2,
  }) async {
    await captureScreen(
      tester,
      ProviderScope(
        child: madarScreenshotApp(home: CinemaDemoScreen(initialEra: era, autoplay: !opening, showEraPicker: false)),
      ),
      'cinema/demo/demo_${era.name}_$moment',
      settle: const Duration(milliseconds: 250),
      trailingFrames: trailingFrames,
      beforeCapture: (t) async {
        final g = mountedDemo(t);
        await runUntil(g, () => g.state != SceneState.loading, maxSeconds: 3, what: 'load');
        await drive(g);
      },
    );
  }

  bool midAir(DemoGame g) => g.heroY < DemoGame.groundY - 70;

  Future<void> toPlay(DemoGame g) => runUntil(g, () => g.isPlaying, maxSeconds: 10, what: 'play');

  Future<void> toSlam(DemoGame g) async {
    await runUntil(g, () => g.act == DemoAct.boss, maxSeconds: 40, what: 'the fight');
    await runUntil(
      g,
      () => g.boss.action == RigAction.attack && g.boss.attack == BossAttack.slam && g.boss.actionTime > 0.5 && g.boss.actionTime < 0.6,
      maxSeconds: 20,
      what: 'slam',
    );
  }

  for (final era in Era.values) {
    testWidgets('act one, mid-jump – ${era.name}', (tester) async {
      await shoot(tester, era, 'play', (g) async {
        await toPlay(g);
        await runUntil(g, () => g.cleared >= 2 && midAir(g), maxSeconds: 20, what: 'a jump');
      });
    });

    testWidgets('the Baron slams – ${era.name}', (tester) async {
      await shoot(tester, era, 'boss', (g) async {
        await toPlay(g);
        await toSlam(g);
      });
    });
  }

  const reel = Era.rubberHose;

  testWidgets('opening card', (tester) async {
    await shoot(tester, reel, 'card', (g) => runFor(g, 1.0), opening: true);
  });

  testWidgets('iris-in', (tester) async {
    await shoot(
      tester,
      reel,
      'iris',
      (g) => runUntil(g, () => g.state == SceneState.opening && g.transitions.coverage < 0.55 && g.transitions.coverage > 0.2, maxSeconds: 10, what: 'iris'),
      opening: true,
    );
  });

  testWidgets('a hit', (tester) async {
    await shoot(tester, reel, 'hit', (g) async {
      await toPlay(g);
      g.autoplay = false;
      await runUntil(g, () => g.hud.lives == 2, maxSeconds: 10, what: 'hit');
      await runFor(g, 0.12);
    });
  });

  testWidgets('chapter card', (tester) async {
    await shoot(tester, reel, 'chapter', (g) async {
      await toPlay(g);
      await runUntil(g, () => g.act == DemoAct.bossIntro, maxSeconds: 30, what: 'intro');
      await runFor(g, 0.9);
    });
  });

  testWidgets('the Baron taunts', (tester) async {
    await shoot(tester, reel, 'taunt', (g) async {
      await toPlay(g);
      await runUntil(g, () => g.act == DemoAct.boss, maxSeconds: 40, what: 'the fight');
      await runFor(g, 0.4);
    });
  });

  testWidgets('the Baron blasts', (tester) async {
    await shoot(tester, reel, 'blast', (g) async {
      await toPlay(g);
      await runUntil(g, () => g.act == DemoAct.boss, maxSeconds: 40, what: 'the fight');
      await runUntil(
        g,
        () => g.boss.action == RigAction.attack && g.boss.attack == BossAttack.blast && g.boss.actionTime > 0.38,
        maxSeconds: 20,
        what: 'blast',
      );
    });
  });

  testWidgets('the Baron takes a hit', (tester) async {
    await shoot(tester, reel, 'bosshurt', (g) async {
      await toPlay(g);
      await runUntil(g, () => g.bossHits == 2, maxSeconds: 50, what: 'second hit');
      await runFor(g, 0.15);
    });
  });

  testWidgets('curtain call', (tester) async {
    await shoot(tester, reel, 'finale', (g) async {
      await toPlay(g);
      await runUntil(g, () => g.act == DemoAct.finale, maxSeconds: 60, what: 'finale');
      await runFor(g, 1.1);
    });
  });

  testWidgets('iris-out', (tester) async {
    await shoot(tester, reel, 'irisout', (g) async {
      await toPlay(g);
      await runUntil(g, () => g.state == SceneState.ending && g.transitions.coverage > 0.45 && g.transitions.coverage < 0.8, maxSeconds: 70, what: 'iris out');
    });
  });

  testWidgets('end card', (tester) async {
    await shoot(tester, reel, 'end', (g) async {
      await toPlay(g);
      await runUntil(g, () => g.state == SceneState.ending && g.transitions.coverage >= 0.999, maxSeconds: 70, what: 'black');
      await runFor(g, 1.0);
    });
  });

  testWidgets('results marquee', (tester) async {
    await shoot(tester, reel, 'results', (g) async {
      await toPlay(g);
      await runUntil(g, () => g.state == SceneState.ended, maxSeconds: 80, what: 'results');
    }, trailingFrames: 26);
  });
}

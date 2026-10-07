@Tags(['screenshot'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/cinema/engine/cinema_engine.dart';
import 'package:madar/features/cinema/games/metropolis_machine/metropolis_game.dart';
import 'package:madar/features/cinema/games/metropolis_machine/metropolis_rules.dart';

import '../../../../helpers/screenshot_harness.dart';
import 'metropolis_support.dart';

// Renders the show through the real kit and shaders (SkSL in
// flutter_tester) at chosen moments into screenshots/cinema/games/
// metropolis_machine/*.png: the title card and the opening (ar + en), each
// machine in each of its phases mid-attack, a hit, a parry, a machine
// falling, the Baron's card, the conveyor, the pause booth and the results
// marquee (ar + en), the finale and the end card. Look at every one.
void main() {
  setUpAll(() async {
    await loadMadarFonts();
    await CinemaShaders.preload();
  });

  Future<void> shoot(
    WidgetTester tester,
    String moment,
    Future<void> Function(MetropolisGame g) drive, {
    bool opening = false,
    Locale locale = const Locale('ar'),
    int trailingFrames = 2,
    bool autoplay = true,
    double textScale = 1,
    bool reducedMotion = false,
  }) async {
    await captureScreen(
      tester,
      ProviderScope(
        child: madarScreenshotApp(
          locale: locale,
          home: Scaffold(
            backgroundColor: Colors.black,
            body: Builder(
              builder: (ctx) => MediaQuery(
                data: MediaQuery.of(ctx).copyWith(textScaler: TextScaler.linear(textScale), disableAnimations: reducedMotion),
                child: CinemaGameView(skipOpening: !opening, builder: (ctx) => MetropolisGame(context: ctx, autoplay: autoplay && !opening)),
              ),
            ),
          ),
        ),
      ),
      'cinema/games/metropolis_machine/metropolis_${locale.languageCode}_$moment',
      settle: const Duration(milliseconds: 250),
      trailingFrames: trailingFrames,
      beforeCapture: (t) async {
        final g = mountedMetro(t);
        await runUntil(g, () => g.state != SceneState.loading, maxSeconds: 3, what: 'load');
        await drive(g);
      },
    );
  }

  Future<void> toFight(MetropolisGame g) async {
    await runUntil(g, () => g.isPlaying, maxSeconds: 10, what: 'play');
    await runUntil(g, () => g.brain != null && !g.entering, maxSeconds: 10, what: 'the fight');
  }

  /// Runs until the machine is mid-[attack] (its strike landing).
  Future<void> midAttack(MetropolisGame g, AttackKind attack, {double at = 0.15}) async {
    g.debugForceAttack(attack);
    await runUntil(g, () => g.brain!.mode == BossMode.attack && g.brain!.attack == attack && g.brain!.timer >= at, maxSeconds: 12, what: '$attack');
  }

  for (final locale in const [Locale('ar'), Locale('en')]) {
    testWidgets('title card – ${locale.languageCode}', (tester) async {
      await shoot(tester, 'title', (g) => runFor(g, 1.2), opening: true, locale: locale);
    });

    testWidgets('results marquee – ${locale.languageCode}', (tester) async {
      await shoot(tester, 'results', (g) async {
        await toFight(g);
        g.debugJumpToBoss(4, phase: 2);
        g.addScore(730);
        g.debugDefeatBoss();
        await runUntil(g, () => g.state == SceneState.ended, maxSeconds: 60, what: 'results');
      }, locale: locale, trailingFrames: 26);
    });

    testWidgets('intermission booth – ${locale.languageCode}', (tester) async {
      await shoot(tester, 'pause', (g) async {
        await toFight(g);
        g.debugJumpToBoss(1, phase: 1);
        await midAttack(g, AttackKind.blast, at: 0.3);
        g.pauseGame();
        await runFor(g, 0.6);
      }, locale: locale, trailingFrames: 14);
    });
  }

  testWidgets('the shift change walks in', (tester) async {
    await shoot(tester, 'opening', (g) async {
      await runUntil(g, () => g.isPlaying, maxSeconds: 10, what: 'opening');
      await runFor(g, 1.6);
    }, opening: true);
  });

  testWidgets('the first dialogue card', (tester) async {
    await shoot(tester, 'dialogue', (g) async {
      await runUntil(g, () => g.isPlaying, maxSeconds: 10, what: 'opening');
      await runUntil(g, () => g.transitions.isActive && g.transitions.coverage > 0.95, maxSeconds: 10, what: 'card');
      await runFor(g, 0.9);
    }, opening: true);
  });

  testWidgets('the chapter card of the first machine', (tester) async {
    await shoot(tester, 'chapter', (g) async {
      await toFight(g);
      g.debugDefeatBoss();
      await runUntil(g, () => g.bossIndex == 1 && g.transitions.coverage > 0.95, maxSeconds: 30, what: 'card');
      await runFor(g, 0.9);
    });
  });

  // Every machine in every phase, mid-attack.
  const moments = <(int, int, AttackKind, double)>[
    (0, 0, AttackKind.stamp, 0.16),
    (0, 1, AttackKind.stamp, 0.2),
    (0, 2, AttackKind.stampSweep, 0.6),
    (1, 0, AttackKind.jets, 0.4),
    (1, 1, AttackKind.blast, 0.12),
    (1, 2, AttackKind.rivets, 0.5),
    (2, 0, AttackKind.stab, 0.15),
    (2, 1, AttackKind.drop, 0.3),
    (2, 2, AttackKind.sparks, 0.5),
    (3, 0, AttackKind.grab, 0.35),
    (3, 1, AttackKind.boltRain, 0.9),
    (3, 2, AttackKind.punch, 0.15),
    (4, 0, AttackKind.pistons, 0.2),
    (4, 1, AttackKind.sparks, 0.5),
    (4, 2, AttackKind.overload, 0.9),
  ];
  for (final (boss, phase, attack, at) in moments) {
    testWidgets('${MetroBoss.values[boss].name} phase ${phase + 1} – ${attack.name}', (tester) async {
      await shoot(tester, '${MetroBoss.values[boss].name}_p${phase + 1}', (g) async {
        await toFight(g);
        g.debugJumpToBoss(boss, phase: phase);
        await runFor(g, 1.2);
        await midAttack(g, attack, at: at);
      });
    });
  }

  testWidgets('the Clock-Press stunned, the wrench landing', (tester) async {
    await shoot(tester, 'strike', (g) async {
      await toFight(g);
      g.debugJumpToBoss(0);
      await runUntil(g, () => g.brain!.vulnerable, maxSeconds: 15, what: 'open');
      g.heroBody
        ..x = (g.brain!.weakX - 50).clamp(MetroStage.heroMinX, MetroStage.heroMaxX)
        ..facing = 1;
      g.input.strike = true;
      await runFor(g, 0.09);
    }, autoplay: false);
  });

  testWidgets('a hit', (tester) async {
    await shoot(tester, 'hit', (g) async {
      await toFight(g);
      g.debugJumpToBoss(1);
      g.debugHurtHero();
      await runFor(g, 0.14);
    }, autoplay: false);
  });

  testWidgets('the Boiler-Heart falls', (tester) async {
    await shoot(tester, 'bossfall', (g) async {
      await toFight(g);
      g.debugJumpToBoss(1, phase: 2);
      await runFor(g, 0.5);
      g.debugDefeatBoss();
      await runFor(g, 0.55);
    });
  });

  testWidgets('the Baron taunts', (tester) async {
    await shoot(tester, 'taunt', (g) async {
      await toFight(g);
      g.debugDefeatBoss();
      await runUntil(g, () => g.transitions.coverage > 0.95, maxSeconds: 10, what: 'card');
      await runFor(g, 0.9);
    });
  });

  testWidgets('the conveyor to the next hall', (tester) async {
    await shoot(tester, 'transit', (g) async {
      await toFight(g);
      g.debugDefeatBoss();
      await runUntil(g, () => g.act == MetroAct.transit && g.hallSlide > 0.3 && g.hallSlide < 0.6, maxSeconds: 20, what: 'transit');
    });
  });

  testWidgets('the finale: the Baron flies, the lights come back', (tester) async {
    await shoot(tester, 'finale', (g) async {
      await toFight(g);
      g.debugJumpToBoss(4, phase: 2);
      await runFor(g, 0.4);
      g.debugDefeatBoss();
      await runUntil(g, () => g.act == MetroAct.finale, maxSeconds: 10, what: 'finale');
      await runUntil(g, () => !g.transitions.isActive && g.actTime > 3.2, maxSeconds: 12, what: 'the lights');
    });
  });

  testWidgets('the end card', (tester) async {
    await shoot(tester, 'end', (g) async {
      await toFight(g);
      g.debugJumpToBoss(4, phase: 2);
      g.debugDefeatBoss();
      await runUntil(g, () => g.state == SceneState.ending && g.transitions.coverage >= 0.999, maxSeconds: 40, what: 'black');
      await runFor(g, 1.0);
    });
  });

  // --- The critic's pass: the states the first reel did not show. ---

  for (final locale in const [Locale('ar'), Locale('en')]) {
    testWidgets('a long show: four-digit score on the HUD, the Dynamo with its pilot – ${locale.languageCode}', (tester) async {
      await shoot(tester, 'hud_long_show', (g) async {
        await toFight(g);
        g.debugJumpToBoss(4, phase: 1);
        g.addScore(1460);
        await runFor(g, 1.6);
        await midAttack(g, AttackKind.pistons, at: 0.1);
      }, locale: locale);
    });
  }

  testWidgets('the machine rages: the phase-change flash', (tester) async {
    await shoot(tester, 'phase_up', (g) async {
      await toFight(g);
      g.debugJumpToBoss(2);
      g.debugPeaceful = true;
      final b = g.brain!;
      while (b.phase == 0) {
        b.damage(force: true);
      }
      g.debugPeaceful = false;
      await runFor(g, 0.12);
    }, autoplay: false);
  });

  testWidgets('show over: the hero is down', (tester) async {
    await shoot(tester, 'defeat', (g) async {
      await toFight(g);
      g.debugJumpToBoss(1, phase: 1);
      g.debugPeaceful = true;
      g.debugHurtHero();
      await runFor(g, 1.6);
      g.debugHurtHero();
      await runFor(g, 1.6);
      g.debugHurtHero();
      await runFor(g, 0.9);
    }, autoplay: false);
  });

  testWidgets('show over: the losing end card', (tester) async {
    await shoot(tester, 'lost_card', (g) async {
      await toFight(g);
      g.debugPeaceful = true;
      for (var i = 0; i < 3; i++) {
        g.debugHurtHero();
        await runFor(g, 1.6);
      }
      await runUntil(g, () => g.state == SceneState.ending && g.transitions.coverage >= 0.999, maxSeconds: 20, what: 'black');
      await runFor(g, 1.0);
    }, autoplay: false);
  });

  testWidgets('reduced motion: a hit (no flicker, soft flash and shake)', (tester) async {
    await shoot(tester, 'reduced_motion_hit', (g) async {
      await toFight(g);
      expect(g.film.reduceFlicker, isTrue);
      g.debugJumpToBoss(0, phase: 1);
      await runFor(g, 0.6);
      g.debugHurtHero();
      await runFor(g, 0.1);
    }, autoplay: false, reducedMotion: true);
  });

  testWidgets('large text (1.3): the intermission booth', (tester) async {
    await shoot(tester, 'pause_text130', (g) async {
      await toFight(g);
      g.pauseGame();
      await runFor(g, 0.6);
    }, trailingFrames: 14, textScale: 1.3);
  });

  testWidgets('large text (1.3): the results marquee', (tester) async {
    await shoot(tester, 'results_text130', (g) async {
      await toFight(g);
      g.debugJumpToBoss(4, phase: 2);
      g.addScore(730);
      g.debugDefeatBoss();
      await runUntil(g, () => g.state == SceneState.ended, maxSeconds: 60, what: 'results');
    }, trailingFrames: 40, textScale: 1.3);
  });
}

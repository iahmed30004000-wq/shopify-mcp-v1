import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/sound/sound_api.dart';
import 'package:madar/features/cinema/engine/cinema_engine.dart';
import 'package:madar/features/cinema/games/flappy_orbit/flappy_orbit_entry.dart';
import 'package:madar/features/cinema/games/flappy_orbit/flappy_orbit_game.dart';
import 'package:madar/features/cinema/games/flappy_orbit/flappy_orbit_gates.dart';
import 'package:madar/features/cinema/games/flappy_orbit/flappy_orbit_logic.dart';

import '../../cinema_fakes.dart';
import 'flappy_orbit_support.dart';

// The show, headless: the opening and the launch pad, the autopilot flying
// gates for 30 s and meeting the Maestro, a crash into the pie with the
// result reported, input routing, the three boss phases with their
// stingers, the RTL / LTR HUD, reduced motion, and the frame budget with an
// allocation count.
void main() {
  late TestKit kit;
  late RecordingHaptics haptics;
  GameResult? reported;

  setUpAll(() async => CinemaShaders.preload());

  setUp(() {
    kit = TestKit();
    haptics = RecordingHaptics();
    reported = null;
  });

  test('the catalog entry is playable', () {
    expect(flappyOrbitEntry.id, 'flappy_orbit');
    expect(flappyOrbitEntry.isPlayable, isTrue);
    expect(flappyOrbitEntry.era, Era.rubberHose);
  });

  testWidgets('opening card, launch pad, a tap launches, then the first gate', (tester) async {
    final g = await mountOrbit(tester, kit: kit, haptics: haptics, skipOpening: false);
    expect(g.state, SceneState.opening);
    await runUntil(g, () => g.isPlaying, maxSeconds: 12, what: 'opening');
    expect(g.clock.time, lessThan(9));
    expect(g.act, FlappyAct.launch);
    expect(kit.music.last.log, contains('cue title'));
    expect(kit.music.last.log, contains('cue adventure'));
    await runFor(g, 0.5);
    expect(g.heroY, FlappyOrbitGame.padHeroY, reason: 'still on the pad until a tap');
    g.onScreenTapDown(Vector2.zero(), Offset.zero);
    expect(g.act, FlappyAct.liftoff);
    expect(kit.sfx.last.played, contains(CinemaSound.slideUp));
    await runUntil(g, () => g.act == FlappyAct.flight, maxSeconds: 3, what: 'flight');
    expect(g.heroY, lessThan(FlappyOrbitGame.padHeroY - 150));
    expect(g.spawner.activeCount, greaterThan(0), reason: 'gates roll in once airborne');
    await settleTaps(tester);
  });

  testWidgets('a real tap on the screen reaches the game (input routing)', (tester) async {
    final g = await mountOrbit(tester, kit: kit, haptics: haptics);
    await runUntil(g, () => g.isPlaying, maxSeconds: 3, what: 'play');
    expect(g.act, FlappyAct.launch);
    await tester.tapAt(tester.getCenter(find.byType(OrbitTestScreen)));
    await tester.pump(const Duration(milliseconds: 20));
    expect(g.act, FlappyAct.liftoff);
    await settleTaps(tester);
  });

  testWidgets('the autopilot flies 30 s: gates, style, the Maestro; then it crashes into the pie', (tester) async {
    final sink = MemoryScoreSink();
    final g = await mountOrbit(tester, kit: kit, haptics: haptics, autoplay: true, scoreSink: sink, onResult: (r) => reported = r);
    await runUntil(g, () => g.isPlaying, maxSeconds: 3, what: 'play');
    expect(g.act, FlappyAct.flight);
    final allocations = OrbitAllocations.count;
    await runFor(g, 30);
    expect(g.gatesPassed, greaterThanOrEqualTo(g.gatesPerBoss), reason: 'the ramp reaches the first boss inside 30 s');
    expect(g.hud.score, greaterThan(0));
    expect(g.act, isNot(FlappyAct.launch));
    expect(kit.music.last.log, contains('stinger bossIntro'));
    expect(kit.music.last.log, contains('cue boss'));
    expect(kit.sfx.last.played, contains(CinemaSound.coin));
    expect(g.spawner.pool.length, 6, reason: 'gates are pooled');
    expect(OrbitAllocations.count, allocations, reason: 'nothing is built during play');
    // Hands off: the rocket drops onto the roofs until the lives run out.
    g.autoplay = false;
    await runUntil(g, () => g.act == FlappyAct.crash, maxSeconds: 25, what: 'crash');
    expect(g.hud.lives, 0);
    expect(kit.sfx.last.played, contains(CinemaSound.hurt));
    expect(haptics.fired, contains(Haptic.heavy));
    await runUntil(g, () => g.state == SceneState.ended, maxSeconds: 20, what: 'results');
    expect(kit.sfx.last.played, contains(CinemaSound.splat));
    expect(g.pie.splat, 1);
    expect(reported, isNotNull);
    expect(reported!.won, isFalse);
    expect(reported!.gameId, 'flappy_orbit');
    expect(reported!.score, g.hud.score);
    expect(reported!.stats['gates'], g.gatesPassed);
    expect(sink.results.single.score, g.hud.score);
    expect(g.overlays.isActive(CinemaOverlays.results), isTrue);
    await settleTaps(tester);
  });

  testWidgets('a gate costs a life, the rocket keeps flying', (tester) async {
    final g = await mountOrbit(tester, kit: kit, haptics: haptics, autoplay: true);
    await runUntil(g, () => g.isPlaying, maxSeconds: 3, what: 'play');
    await runFor(g, 1.5);
    g.autoplay = false;
    // Fall onto the roofs.
    await runUntil(g, () => g.hud.lives == 2, maxSeconds: 6, what: 'hit');
    expect(g.film.flash, greaterThan(0));
    expect(g.film.shake, greaterThan(0));
    expect(kit.music.last.log, contains('stinger hit'));
    expect(g.pilot.action, RigAction.hurt);
    expect(g.heroY, lessThan(FlightTuning.floor), reason: 'bounced back up');
    await settleTaps(tester);
  });

  testWidgets('pause freezes the world and ducks the music; resume continues', (tester) async {
    final g = await mountOrbit(tester, kit: kit, haptics: haptics, autoplay: true);
    await runUntil(g, () => g.isPlaying, maxSeconds: 3, what: 'play');
    await runFor(g, 1);
    final score = g.scroll;
    g.pauseGame();
    expect(g.state, SceneState.paused);
    expect(kit.music.last.ducked, isTrue);
    expect(g.overlays.isActive(CinemaOverlays.pause), isTrue);
    await runFor(g, 1);
    expect(g.scroll, score, reason: 'the world is frozen');
    g.resumeGame();
    await runFor(g, 0.5);
    expect(g.scroll, greaterThan(score));
    expect(kit.music.last.ducked, isFalse);
    await settleTaps(tester);
  });

  testWidgets('the Maestro: gusts, thunder-notes, the spinning stage, then he blows away', (tester) async {
    final g = await mountOrbit(tester, kit: kit, haptics: haptics, autoplay: true, gatesPerBoss: 2);
    await runUntil(g, () => g.isPlaying, maxSeconds: 3, what: 'play');
    await runUntil(g, () => g.act == FlappyAct.bossIntro, maxSeconds: 30, what: 'the chapter card');
    expect(g.hud.progress, isNull);
    expect(kit.music.last.log, contains('stinger bossIntro'));
    await runUntil(g, () => g.act == FlappyAct.boss, maxSeconds: 10, what: 'the fight');
    expect(g.hud.bossHealth, 1);
    expect(g.hud.bossName, isNotEmpty);
    expect(g.brain!.phase, BossPhase.gusts);
    await runUntil(g, () => g.attacks.activeGusts > 0, maxSeconds: 10, what: 'a gust');
    expect(g.maestro.action, RigAction.attack);
    await runUntil(g, () => g.brain!.phase == BossPhase.thunder, maxSeconds: 60, what: 'phase two');
    expect(kit.music.last.log, contains('stinger drumroll'));
    expect(g.maestro.phase, 1);
    expect(g.hud.bossHealth, lessThan(1));
    await runUntil(g, () => g.attacks.activeNotes > 0, maxSeconds: 15, what: 'a thunder-note');
    expect(kit.sfx.last.played, contains(CinemaSound.zap));
    await runUntil(g, () => g.brain!.phase == BossPhase.spin, maxSeconds: 60, what: 'phase three');
    expect(kit.music.last.log, contains('stinger rimshot'));
    expect(g.maestro.phase, 2);
    await runFor(g, 1.2);
    expect(g.stageAngle.abs(), greaterThan(0.02), reason: 'the whole stage spins');
    await runUntil(g, () => g.act == FlappyAct.bossOutro, maxSeconds: 60, what: 'defeat');
    expect(kit.music.last.log, contains('stinger bossDefeat'));
    expect(g.bossesDefeated, 1);
    await runUntil(g, () => g.act == FlappyAct.flight, maxSeconds: 5, what: 'back to the gates');
    expect(g.difficulty.tier, 1);
    expect(g.hud.bossHealth, isNull);
    expect(g.hud.progress, 0);
    await runFor(g, 1);
    expect(g.stageAngle.abs(), lessThan(0.02), reason: 'the stage settles');
    await settleTaps(tester);
  });

  testWidgets('the chapter card hides the sky, so it never costs a life (no tap needed)', (tester) async {
    final g = await mountOrbit(tester, kit: kit, haptics: haptics, autoplay: true, gatesPerBoss: 2);
    await runUntil(g, () => g.isPlaying, maxSeconds: 3, what: 'play');
    await runUntil(g, () => g.act == FlappyAct.bossIntro, maxSeconds: 30, what: 'the chapter card');
    // The player reads the card and does not tap.
    g.autoplay = false;
    final lives = g.hud.lives;
    await runUntil(g, () => g.transitions.isActive, maxSeconds: 2, what: 'the card');
    await runFor(g, 0.1);
    g.onScreenTapDown(Vector2.zero(), Offset.zero);
    expect(g.flight.vy, 0, reason: 'a tap behind the card is ignored: the rocket hovers');
    var hiddenTime = 0.0;
    await runUntil(
      g,
      () {
        if (g.transitions.isActive) hiddenTime += 1 / 60;
        return g.bossCardDone && !g.transitions.isActive;
      },
      maxSeconds: 8,
      what: 'the card to lift',
    );
    expect(hiddenTime, greaterThan(1), reason: 'the card really covered the sky');
    expect(g.hud.lives, lives, reason: 'no life lost behind the card');
    expect(g.heroY, lessThan(FlightTuning.floor - 120), reason: 'the rocket is left at a fair height');
    await settleTaps(tester);
  });

  testWidgets('one Maestro and the loop-the-loop ending', (tester) async {
    final g = await mountOrbit(tester, kit: kit, haptics: haptics, autoplay: true, gatesPerBoss: 2, bossCount: 1, onResult: (r) => reported = r);
    await runUntil(g, () => g.isPlaying, maxSeconds: 3, what: 'play');
    await runUntil(g, () => g.act == FlappyAct.finale, maxSeconds: 150, what: 'the finale');
    expect(g.pilot.action, RigAction.cheer);
    await runFor(g, 1);
    expect(g.hero.position.x, isNot(closeTo(FlappyOrbitGame.heroX, 5)), reason: 'mid-loop');
    await runUntil(g, () => g.state == SceneState.ended, maxSeconds: 20, what: 'results');
    expect(reported!.won, isTrue);
    expect(reported!.stats['bosses'], 1);
    expect(kit.music.last.log, contains('stinger victory'));
    await settleTaps(tester);
  });

  testWidgets('the HUD mirrors: score at the right in Arabic, at the left in English', (tester) async {
    Future<Map<HudSlot, Rect>> placements(Locale locale) async {
      final g = await mountOrbit(tester, kit: kit, haptics: haptics, locale: locale);
      await runUntil(g, () => g.isPlaying, maxSeconds: 3, what: 'play');
      await tester.pump(const Duration(milliseconds: 16));
      final layer = g.children.whereType<HudLayer>().single;
      final map = <HudSlot, Rect>{};
      for (final (slot, rect) in layer.placements) {
        map.putIfAbsent(slot, () => rect);
      }
      await settleTaps(tester);
      return map;
    }

    final ar = await placements(const Locale('ar'));
    expect(ar[HudSlot.topStart]!.center.dx, greaterThan(ar[HudSlot.topEnd]!.center.dx));
    expect(ar[HudSlot.topStart]!.center.dx, greaterThan(ar[HudSlot.topCenter]!.center.dx));
    final en = await placements(const Locale('en'));
    expect(en[HudSlot.topStart]!.center.dx, lessThan(en[HudSlot.topEnd]!.center.dx));
    expect(en[HudSlot.topStart]!.center.dx, lessThan(en[HudSlot.topCenter]!.center.dx));
  });

  testWidgets('reduced motion: the stage barely tilts in the spin phase', (tester) async {
    final g = await mountOrbit(tester, kit: kit, haptics: haptics, autoplay: true, gatesPerBoss: 2, reducedMotion: true);
    expect(g.film.reduceFlicker, isTrue);
    await runUntil(g, () => g.isPlaying, maxSeconds: 3, what: 'play');
    await runUntil(g, () => g.act == FlappyAct.boss && g.brain!.phase == BossPhase.spin, maxSeconds: 150, what: 'phase three');
    var maxAngle = 0.0;
    for (var i = 0; i < 180; i++) {
      g.update(1 / 60);
      if (g.stageAngle.abs() > maxAngle) maxAngle = g.stageAngle.abs();
      if (i % 4 == 0) await null;
    }
    expect(maxAngle, lessThan(0.07));
    expect(maxAngle, greaterThan(0.005), reason: 'a gentle sway remains');
    await settleTaps(tester);
  });

  testWidgets('frame cost: update and scene recording stay within budget, nothing is allocated in play', (tester) async {
    final g = await mountOrbit(tester, kit: kit, haptics: haptics, autoplay: true);
    await runUntil(g, () => g.isPlaying, maxSeconds: 3, what: 'play');
    g.filmEnabled = false; // record the scene only (the film pass is GPU work)
    await runFor(g, 2);
    final allocations = OrbitAllocations.count;
    final pilotDrawings = g.pilot.drawings;
    final sw = Stopwatch();
    var updateUs = 0, recordUs = 0;
    const frames = 300;
    for (var i = 0; i < frames; i++) {
      sw
        ..reset()
        ..start();
      g.update(1 / 60);
      sw.stop();
      updateUs += sw.elapsedMicroseconds;
      final rec = ui.PictureRecorder();
      final canvas = Canvas(rec);
      sw
        ..reset()
        ..start();
      g.render(canvas);
      sw.stop();
      recordUs += sw.elapsedMicroseconds;
      rec.endRecording().dispose();
      if (i % 4 == 0) await null;
    }
    final update = updateUs / frames / 1000, record = recordUs / frames / 1000;
    // ignore: avoid_print
    print('flappy orbit frame cost (host, act ${g.act.name}): update ${update.toStringAsFixed(2)} ms, record ${record.toStringAsFixed(2)} ms');
    expect(update, lessThan(6), reason: 'update budget is 2 ms on a phone; the host is not faster');
    expect(record, lessThan(9), reason: 'recording budget is 3 ms on a phone');
    expect(OrbitAllocations.count, allocations, reason: 'no drawings, pools or paints are created per frame');
    final drawn = g.pilot.drawings - pilotDrawings;
    expect(drawn, lessThanOrEqualTo(frames / 60 * 24 + 16), reason: 'the hero is re-inked at most on ones (24/s) plus a few pose changes, replayed otherwise');
    await settleTaps(tester);
  });
}

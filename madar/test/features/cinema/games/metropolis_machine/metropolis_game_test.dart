import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/providers.dart';
import 'package:madar/core/sound/prayer_mute.dart';
import 'package:madar/core/sound/sound_api.dart';
import 'package:madar/features/cinema/engine/cinema_engine.dart';
import 'package:madar/features/cinema/games/metropolis_machine/metropolis_game.dart';
import 'package:madar/features/cinema/games/metropolis_machine/metropolis_machine_entry.dart';
import 'package:madar/features/cinema/games/metropolis_machine/metropolis_rules.dart';

import '../../cinema_fakes.dart';
import 'metropolis_support.dart';

// The scene, headless: the whole show under a fake clock (opening, five
// machines, cards, transit, finale, results), the lives, the touch input
// routing, the RTL / LTR HUD, reduced motion and the frame cost.
void main() {
  late TestKit kit;
  late RecordingHaptics haptics;
  late PrayerMuteController mute;
  GameResult? reported;

  setUpAll(() async => CinemaShaders.preload());

  setUp(() {
    kit = TestKit();
    haptics = RecordingHaptics();
    mute = PrayerMuteController(SilentSoundService());
    reported = null;
  });

  Future<MetropolisGame> mount(WidgetTester tester, {bool skipOpening = true, bool autoplay = false, Locale locale = const Locale('ar')}) async {
    await tester.pumpWidget(
      metroHost(
        kit: kit.kit,
        skipOpening: skipOpening,
        locale: locale,
        onResult: (r) => reported = r,
        overrides: [hapticsServiceProvider.overrideWithValue(haptics), prayerMuteProvider.overrideWithValue(mute)],
        builder: (ctx) => MetropolisGame(context: ctx, autoplay: autoplay),
      ),
    );
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    final g = mountedMetro(tester);
    await runUntil(g, () => g.state != SceneState.loading, maxSeconds: 2, what: 'load');
    return g;
  }

  Future<void> toFight(MetropolisGame g) async {
    await runUntil(g, () => g.isPlaying, maxSeconds: 12, what: 'play');
    await runUntil(g, () => g.brain != null && !g.entering && !g.transitions.isActive, maxSeconds: 20, what: 'the fight');
  }

  test('the catalog entry is playable', () {
    expect(metropolisMachineEntry.isPlayable, isTrue);
    expect(metropolisMachineEntry.era, Era.silent);
    expect(metropolisMachineEntry.genre, GameGenre.bossRush);
  });

  testWidgets('the opening: card, crowd, walk-in, two dialogue cards, the first machine', (tester) async {
    final g = await mount(tester, skipOpening: false);
    await runUntil(g, () => g.isPlaying, maxSeconds: 12, what: 'opening');
    expect(g.act, MetroAct.opening);
    expect(g.crowdVisible, isTrue);
    expect(kit.music.last.log, contains('cue title'));
    await runUntil(g, () => g.heroBody.x > MetroStage.heroStartX - 1, maxSeconds: 5, what: 'walk-in');
    await runUntil(g, () => g.brain != null, maxSeconds: 20, what: 'the chapter card and the machine');
    expect(g.act, MetroAct.fight);
    expect(g.bossIndex, 0);
    expect(g.hud.bossName, isNotEmpty);
    expect(kit.music.last.log, contains('stinger bossIntro'));
    await runUntil(g, () => !g.entering, maxSeconds: 4, what: 'entrance');
    expect(g.brain!.mode, isNot(BossMode.entering));
    expect(g.crowdVisible, isFalse);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('30 seconds of the attract bot against the Clock-Press, then the whole rush to the results', (tester) async {
    final g = await mount(tester, autoplay: true);
    await toFight(g);
    expect(g.bossIndex, 0);
    final pool = g.hazards.items.length;
    var spawned = 0;
    var maxActive = 0;
    await runUntil(g, () {
      final n = g.hazards.activeCount;
      if (n > maxActive) maxActive = n;
      if (n > 0) spawned++;
      return g.clock.time > 30;
    }, maxSeconds: 40, what: '30 s');
    expect(spawned, greaterThan(10), reason: 'the machine attacks');
    expect(maxActive, lessThanOrEqualTo(pool));
    expect(g.hazards.items.length, pool, reason: 'hazards are pooled');
    expect(g.strikesLanded + g.livesLost, greaterThan(0), reason: 'the bot engages');
    expect(g.state, SceneState.playing, reason: 'the attract bot never runs out of reels');
    expect(g.hud.lives, greaterThanOrEqualTo(1));
    expect(kit.music.last.log, contains('cue boss'));
    // Now beat every machine through the cheat and watch the arc; the world
    // holds the same components in every hall (one machine at a time, plus
    // the Baron in the last one): nothing leaks between machines.
    // (The bot may already have beaten the first machine in its 30 s, so
    // the count is taken at the first fight of the loop.)
    int? perHall;
    for (var i = g.bossIndex; i < MetroStage.bossCount; i++) {
      await runUntil(g, () => g.brain != null && !g.entering && !g.transitions.isActive && g.act == MetroAct.fight && g.bossIndex == i, maxSeconds: 40, what: 'fight $i');
      final components = g.world.children.length - (i == MetroStage.bossCount - 1 ? 1 : 0);
      perHall ??= components;
      expect(components, perHall, reason: 'components in hall $i');
      g.debugDefeatBoss();
      expect(g.act, MetroAct.bossFall);
      expect(kit.music.last.log, contains('stinger bossDefeat'));
      if (i < MetroStage.bossCount - 1) {
        await runUntil(g, () => g.act == MetroAct.transit, maxSeconds: 20, what: 'taunt card and transit $i');
        expect(g.hallSlide, lessThan(1));
        await runUntil(g, () => g.bossIndex == i + 1, maxSeconds: 10, what: 'next hall');
      }
    }
    await runUntil(g, () => g.act == MetroAct.finale, maxSeconds: 10, what: 'finale');
    await runUntil(g, () => g.cityLights >= 1, maxSeconds: 10, what: 'the lights');
    await runUntil(g, () => g.state == SceneState.ended, maxSeconds: 30, what: 'results');
    expect(reported, isNotNull);
    expect(reported!.won, isTrue);
    expect(reported!.stats['bosses'], MetroStage.bossCount);
    expect(g.hud.score, greaterThan(MetroScore.bossBonus(0)));
    expect(g.bossesBeaten, MetroStage.bossCount);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('standing still costs the reels, then the show is over', (tester) async {
    final g = await mount(tester);
    await toFight(g);
    expect(g.hud.lives, MetroLives.start);
    await runUntil(g, () => g.hud.lives < MetroLives.start, maxSeconds: 30, what: 'first hit');
    expect(g.film.flash, greaterThan(0));
    expect(kit.sfx.last.played, contains(CinemaSound.hurt));
    expect(haptics.fired, contains(Haptic.heavy));
    expect(g.heroBody.invulnerable, isTrue);
    expect(g.assist, 1);
    await runUntil(g, () => g.state == SceneState.ended, maxSeconds: 120, what: 'show over');
    expect(reported!.won, isFalse);
    expect(g.hud.lives, 0);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('a beaten machine gives a reel back and a phase change flashes', (tester) async {
    final g = await mount(tester);
    await toFight(g);
    g.debugHurtHero();
    expect(g.hud.lives, MetroLives.start - 1);
    expect(g.flawless, isFalse);
    // Phase up by cheating damage through the brain, then let the game read it.
    final brain = g.brain!;
    while (brain.phase == 0) {
      brain.damage(force: true);
    }
    await runFor(g, 0.1);
    expect(g.flash.showing, isTrue);
    expect(kit.sfx.last.played, contains(CinemaSound.honk));
    final score = g.hud.score;
    g.debugDefeatBoss();
    expect(g.hud.lives, MetroLives.start, reason: 'a reel comes back');
    expect(g.hud.score - score, greaterThanOrEqualTo(MetroScore.bossBonus(0)));
    expect(g.bossesBeaten, 1);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('touch: the pad runs, a tap swings, swipes jump and dash, the button jumps', (tester) async {
    final g = await mount(tester);
    await toFight(g);
    g.debugPeaceful = true;
    final pad = g.padZone, jump = g.jumpZone;
    final play = g.playRect;
    final action = Offset(play.center.dx, play.center.dy - 60);
    // Hold the right half of the pad: he runs right.
    final padRight = Offset(pad.left + pad.width * 0.8, pad.bottom - 30);
    g.onScreenTapDown(Vector2.zero(), padRight);
    await runFor(g, 0.4);
    expect(g.heroBody.vx, greaterThan(100));
    expect(g.moveHeld, 1);
    g.onScreenTapUp(Vector2.zero(), padRight);
    await runFor(g, 0.3);
    expect(g.heroBody.vx, 0);
    // Left half: runs left.
    final padLeft = Offset(pad.left + pad.width * 0.2, pad.bottom - 30);
    g.onScreenTapDown(Vector2.zero(), padLeft);
    await runFor(g, 0.4);
    expect(g.heroBody.vx, lessThan(-100));
    g.onScreenTapUp(Vector2.zero(), padLeft);
    await runFor(g, 0.4);
    // A clean tap in the action area swings the wrench.
    g.onScreenTapDown(Vector2.zero(), action);
    g.onScreenTapUp(Vector2.zero(), action);
    await runFor(g, 0.05);
    expect(g.heroBody.swinging, isTrue);
    expect(g.heroRig.action, RigAction.attack);
    await runFor(g, 0.5);
    // A swipe up jumps (and never swings).
    g.onScreenTapDown(Vector2.zero(), action);
    g.onScreenDrag(Vector2.zero(), action - const Offset(0, 60));
    await runFor(g, 0.1);
    expect(g.heroBody.onGround, isFalse);
    expect(g.heroBody.vy, lessThan(0));
    g.onScreenDragEnd();
    await runUntil(g, () => g.heroBody.onGround, maxSeconds: 3, what: 'landing');
    expect(g.heroBody.swinging, isFalse);
    // A sideways swipe dashes.
    g.onScreenTapDown(Vector2.zero(), action);
    g.onScreenDrag(Vector2.zero(), action + const Offset(70, 4));
    await runFor(g, 0.05);
    expect(g.heroBody.dashing, isTrue);
    expect(g.heroBody.facing, 1);
    expect(kit.sfx.last.played, contains(CinemaSound.whoosh));
    g.onScreenDragEnd();
    await runFor(g, 0.8);
    // The jump button.
    final btn = Offset(jump.right - 30, jump.bottom - 40);
    g.onScreenTapDown(Vector2.zero(), btn);
    await runFor(g, 0.1);
    expect(g.heroBody.onGround, isFalse);
    expect(g.jumpHeld, isTrue);
    g.onScreenTapUp(Vector2.zero(), btn);
    expect(g.heroBody.swinging, isFalse, reason: 'the jump button never swings');
    await runUntil(g, () => g.heroBody.onGround, maxSeconds: 3, what: 'landing');
    // A flick on the pad dashes left.
    g.onScreenTapDown(Vector2.zero(), padLeft);
    g.onScreenDrag(Vector2.zero(), padLeft - const Offset(70, 0));
    await runFor(g, 0.05);
    expect(g.heroBody.dashing, isTrue);
    expect(g.heroBody.facing, -1);
    g.onScreenDragEnd();
    await runFor(g, 0.3);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('real gestures reach the game through the view', (tester) async {
    final g = await mount(tester);
    await toFight(g);
    final play = g.playRect;
    await tester.tapAt(Offset(play.center.dx, play.center.dy - 40));
    await tester.pump(const Duration(milliseconds: 20));
    await runFor(g, 0.05);
    expect(g.heroBody.swinging, isTrue);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('input is ignored during the entrance and the cards', (tester) async {
    final g = await mount(tester, skipOpening: false);
    await runUntil(g, () => g.isPlaying, maxSeconds: 12, what: 'opening');
    expect(g.cinematic, isTrue);
    final play = g.playRect;
    g.onScreenTapDown(Vector2.zero(), play.center);
    g.onScreenTapUp(Vector2.zero(), play.center);
    await runFor(g, 0.1);
    expect(g.heroBody.swinging, isFalse);
    await tester.pump(const Duration(seconds: 1));
  });

  for (final (locale, rtl) in [(const Locale('ar'), true), (const Locale('en'), false)]) {
    testWidgets('HUD: run pad bottom-left, buttons bottom-right, boss bar centred – ${locale.languageCode}', (tester) async {
      final g = await mount(tester, locale: locale);
      await toFight(g);
      g.debugPeaceful = true;
      final layer = g.children.whereType<HudLayer>().single;
      var placements = layer.placements;
      expect(placements.length, 4);
      // The items are private to the layer: identify them by slot and order.
      Rect ofSlot(HudSlot s, int n) => placements.where((p) => p.$1 == s).elementAt(n).$2;
      final pad = g.padHintRect;
      final jump = g.jumpHintRect;
      final wrench = g.wrenchHintRect;
      final bossBar = ofSlot(HudSlot.bottomCenter, 0);
      final score = ofSlot(HudSlot.topStart, 0);
      final pause = ofSlot(HudSlot.topEnd, 0);
      final screenMid = g.canvasSize.x / 2;
      expect(pad.center.dx, lessThan(screenMid), reason: 'the pad is under the left thumb in $locale');
      expect(jump.center.dx, greaterThan(screenMid), reason: 'jump under the right thumb');
      expect(wrench.center.dx, greaterThan(screenMid));
      expect(jump.left, greaterThan(wrench.left), reason: 'jump is the outer button');
      expect(bossBar.center.dx, closeTo(screenMid, 2));
      expect(pad.bottom, lessThanOrEqualTo(bossBar.top), reason: 'the hints sit above the boss bar, never over it');
      expect(jump.bottom, lessThanOrEqualTo(bossBar.top));
      expect(pad.overlaps(bossBar), isFalse);
      expect(wrench.overlaps(bossBar), isFalse);
      expect(g.playRect.contains(pad.center), isTrue);
      expect(g.padZone.contains(pad.center), isTrue);
      expect(g.jumpZone.contains(jump.center), isTrue);
      expect(g.jumpZone.contains(wrench.center), isFalse, reason: 'tapping the wrench button swings');
      if (rtl) {
        expect(score.left, greaterThan(pause.left), reason: 'score at the start (right) in Arabic');
      } else {
        expect(score.left, lessThan(pause.left));
      }
      // The machine's number rides on the boss bar's plate.
      expect(g.hud.bossName, g.bossPlate(0));
      expect(g.hud.bossName, contains(g.bossName(0)));
      expect(g.hud.bossName, contains(g.digits(MetroStage.bossCount)));
      // The top row never collides, from the first point to a long show.
      for (final points in const [0, 7, 120, 1000, 9000, 50000]) {
        g.addScore(points);
        await runFor(g, 1.2);
        placements = layer.placements;
        final top = placements.where((p) => p.$1 == HudSlot.topStart || p.$1 == HudSlot.topCenter || p.$1 == HudSlot.topEnd).map((p) => p.$2).toList();
        expect(top.length, 3);
        for (var i = 0; i < top.length; i++) {
          for (var j = i + 1; j < top.length; j++) {
            expect(top[i].overlaps(top[j]), isFalse, reason: 'top row items overlap at score ${g.hud.score} in $locale: ${top[i]} vs ${top[j]}');
          }
        }
      }
      await tester.pump(const Duration(seconds: 1));
    });
  }

  testWidgets('a beaten machine: one taunt card, one rimshot; the conveyor waits for the card', (tester) async {
    final g = await mount(tester);
    await toFight(g);
    g.debugDefeatBoss();
    await runUntil(g, () => g.transitions.isActive && g.transitions.coverage > 0.95, maxSeconds: 10, what: 'the taunt card');
    await runFor(g, 0.5);
    expect(g.act, MetroAct.bossFall, reason: 'the conveyor waits for the card');
    expect(g.bossRig, isNotNull, reason: 'the beaten machine stays on stage under the card');
    await runUntil(g, () => g.act == MetroAct.transit, maxSeconds: 10, what: 'transit');
    expect(g.transitions.isActive, isFalse);
    expect(kit.music.last.log.where((l) => l == 'stinger rimshot').length, 1, reason: 'one card, one rimshot');
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('leaving during a card never resumes the show on the disposed game', (tester) async {
    final g = await mount(tester);
    await toFight(g);
    g.debugDefeatBoss();
    await runUntil(g, () => g.transitions.isActive && g.transitions.coverage > 0.95, maxSeconds: 10, what: 'the taunt card');
    expect(g.act, MetroAct.bossFall);
    // Leave the hall: the view is torn down, the transitions are cleared and
    // the pending card completes.
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    await null;
    expect(g.act, MetroAct.bossFall, reason: 'the conveyor must not start on a disposed game');
    expect(tester.takeException(), isNull);
  });

  testWidgets('a cut flow is not resumed by its stale card (debug jumps mid-card)', (tester) async {
    final g = await mount(tester);
    await toFight(g);
    g.debugDefeatBoss();
    await runUntil(g, () => g.transitions.isActive && g.transitions.coverage > 0.95, maxSeconds: 10, what: 'the taunt card');
    g.debugJumpToBoss(2);
    await runFor(g, 0.5);
    expect(g.act, MetroAct.fight, reason: 'the stale taunt card does not start the conveyor');
    expect(g.bossIndex, 2);
    expect(g.brain!.kind, MetroBoss.switchboardSpider);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('the intermission and backgrounding let go of a held control; input is ignored while paused', (tester) async {
    final g = await mount(tester);
    await toFight(g);
    g.debugPeaceful = true;
    final pad = g.padZone;
    final padRight = Offset(pad.left + pad.width * 0.8, pad.bottom - 30);
    // Hold the pad, then pause (the finger is still down when the booth opens).
    g.onScreenTapDown(Vector2.zero(), padRight);
    await runFor(g, 0.3);
    expect(g.heroBody.vx, greaterThan(100));
    g.pauseGame();
    expect(g.state, SceneState.paused);
    expect(g.moveHeld, 0);
    // Taps on the paused stage do nothing.
    final play = g.playRect;
    g.onScreenTapDown(Vector2.zero(), play.center);
    g.onScreenTapUp(Vector2.zero(), play.center);
    g.resumeGame();
    await runFor(g, 0.4);
    expect(g.heroBody.vx, 0, reason: 'no phantom run after the intermission');
    expect(g.heroBody.swinging, isFalse, reason: 'the tap on the booth never swings');
    // The same with the app sent to the background mid-hold.
    g.onScreenTapDown(Vector2.zero(), padRight);
    await runFor(g, 0.2);
    g.lifecycleStateChange(ui.AppLifecycleState.paused);
    expect(g.state, SceneState.paused);
    g.lifecycleStateChange(ui.AppLifecycleState.resumed);
    g.resumeGame();
    await runFor(g, 0.4);
    expect(g.heroBody.vx, 0, reason: 'no phantom run after coming back');
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('pausing during a chapter card: the machine waits for the resume, then the fight goes on', (tester) async {
    final g = await mount(tester);
    await toFight(g);
    g.debugDefeatBoss();
    await runUntil(g, () => g.act == MetroAct.transit, maxSeconds: 20, what: 'transit');
    await runUntil(g, () => g.transitions.isActive && g.transitions.coverage > 0.95, maxSeconds: 10, what: 'the chapter card');
    g.pauseGame();
    final at = g.clock.time;
    await runFor(g, 6);
    expect(g.state, SceneState.paused);
    expect(g.entering, isTrue, reason: 'the machine waits for the show to resume');
    expect(g.clock.time - at, greaterThan(5.9));
    g.resumeGame();
    await runUntil(g, () => g.brain != null && !g.entering && g.brain!.fighting, maxSeconds: 10, what: 'the second machine');
    expect(g.bossIndex, 1);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('the same seed plays the same show', (tester) async {
    Future<List<Object>> play(int seed) async {
      await tester.pumpWidget(
        metroHost(
          kit: TestKit().kit,
          skipOpening: true,
          builder: (ctx) => MetropolisGame(
            autoplay: true,
            context: CinemaContext(kit: ctx.kit, l10n: ctx.l10n, sound: ctx.sound, direction: ctx.direction, skipOpening: true, seed: seed),
          ),
        ),
      );
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      final g = mountedMetro(tester);
      await runUntil(g, () => g.state != SceneState.loading, maxSeconds: 2, what: 'load');
      await toFight(g);
      await runFor(g, 25);
      final out = <Object>[
        g.hud.score,
        g.hud.lives,
        g.bossIndex,
        g.act.name,
        g.brain?.attackNo ?? -1,
        g.brain?.hp ?? -1,
        g.heroBody.x.toStringAsFixed(3),
        g.strikesLanded,
        g.livesLost,
        g.parries,
      ];
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      return out;
    }

    final a = await play(42);
    final b = await play(42);
    expect(b, a, reason: 'deterministic with the seed');
  });

  testWidgets('restart: a fresh show, nothing carried over from the old one', (tester) async {
    final g = await mount(tester, autoplay: true);
    await toFight(g);
    g.debugJumpToBoss(3, phase: 1);
    g.addScore(400);
    g.debugHurtHero();
    await runFor(g, 0.5);
    g.requestRestart();
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    final fresh = mountedMetro(tester);
    expect(identical(fresh, g), isFalse);
    await runUntil(fresh, () => fresh.state != SceneState.loading, maxSeconds: 2, what: 'load');
    await toFight(fresh);
    expect(fresh.bossIndex, 0);
    expect(fresh.hud.score, 0);
    expect(fresh.hud.lives, MetroLives.start);
    expect(fresh.brain!.kind, MetroBoss.clockPress);
    expect(fresh.platforms.where((p) => p.active), isEmpty);
    expect(fresh.livesLost, 0);
    expect(fresh.strikesLanded, 0);
    expect(fresh.flawless, isTrue);
    expect(fresh.assist, 0);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('every machine comes on stage with its phases and its platforms', (tester) async {
    final g = await mount(tester);
    await toFight(g);
    for (var i = 0; i < MetroStage.bossCount; i++) {
      for (var phase = 0; phase < 3; phase++) {
        g.debugJumpToBoss(i, phase: phase);
        expect(g.brain!.kind, MetroBoss.values[i]);
        expect(g.brain!.phase, phase);
        expect(g.hall, i);
        await runFor(g, 2.5);
        expect(g.state, SceneState.playing);
        expect(g.bossRig!.drawings, greaterThanOrEqualTo(0));
      }
    }
    g.debugJumpToBoss(3);
    expect(g.platforms.where((p) => p.active).length, 2, reason: 'the Lift-Titan brings its cars');
    g.debugJumpToBoss(4, phase: 2);
    expect(g.platforms.where((p) => p.active).length, 1, reason: 'the Dynamo raises one car in its last phase');
    expect(g.baron, isNotNull);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('a parried rivet flies back and damages the boiler', (tester) async {
    final g = await mount(tester);
    await toFight(g);
    g.debugJumpToBoss(1);
    final b = g.brain!;
    g.debugForceAttack(AttackKind.rivets);
    await runUntil(g, () => g.hazards.items.any((h) => h.active && h.kind == HazardKind.rivet && h.armed), maxSeconds: 6, what: 'a rivet');
    // Put the hero right in its path and swing as it arrives.
    final hp = b.hp;
    var parried = false;
    for (var i = 0; i < 60 * 4 && !parried; i++) {
      final rivet = g.hazards.items.where((h) => h.active && h.kind == HazardKind.rivet && h.armed && !h.parried).firstOrNull;
      if (rivet == null) break;
      g.heroBody
        ..x = (rivet.x - 40).clamp(MetroStage.heroMinX, MetroStage.heroMaxX)
        ..facing = 1;
      if ((rivet.x - g.heroBody.x).abs() < 55 && rivet.y > MetroStage.groundY - 110) g.input.strike = true;
      g.update(1 / 60);
      if (g.parries > 0) parried = true;
    }
    expect(parried, isTrue);
    expect(kit.music.last.log, contains('stinger pickup'));
    await runFor(g, 2);
    expect(b.hp, lessThan(hp), reason: 'the rivet hit the machine on its way back');
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('reduced motion: longer tells, softer shakes', (tester) async {
    await tester.pumpWidget(
      metroHost(
        kit: kit.kit,
        skipOpening: true,
        overrides: [hapticsServiceProvider.overrideWithValue(haptics), prayerMuteProvider.overrideWithValue(mute)],
        builder: (ctx) => MetropolisGame(context: CinemaContext(kit: ctx.kit, l10n: ctx.l10n, sound: ctx.sound, scoreSink: ctx.scoreSink, direction: ctx.direction, reducedMotion: true, skipOpening: true)),
      ),
    );
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    final g = mountedMetro(tester);
    await runUntil(g, () => g.state != SceneState.loading, maxSeconds: 2, what: 'load');
    await toFight(g);
    expect(g.film.reduceFlicker, isTrue);
    expect(g.brain!.reducedMotion, isTrue);
    g.debugHurtHero();
    expect(g.film.shake, lessThan(0.3));
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('frame cost: update and scene recording stay within budget, pools never grow', (tester) async {
    final g = await mount(tester, autoplay: true);
    await toFight(g);
    g.debugJumpToBoss(4, phase: 2);
    g.filmEnabled = false;
    await runFor(g, 10);
    final heroPaths = g.heroRig.ink.list.pathPool;
    final bossPaths = g.bossRig!.ink.list.pathPool;
    final sparks = g.sparks.capacity, puffs = g.puffs.capacity, hazards = g.hazards.items.length;
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
    print('metropolis frame cost (host, dynamo phase 3): update ${update.toStringAsFixed(2)} ms, record ${record.toStringAsFixed(2)} ms');
    expect(update, lessThan(6), reason: 'update budget is 2 ms on a phone; the host is not faster');
    expect(record, lessThan(9), reason: 'recording budget is 3 ms on a phone');
    expect(g.heroRig.ink.list.pathPool, lessThanOrEqualTo(heroPaths + 6), reason: 'the path pool of the hero is warm');
    // The machine's pool grows only until its biggest drawing has been seen.
    expect(g.bossRig!.ink.list.pathPool, lessThan(420), reason: 'the path pool of the machine is bounded (was $bossPaths)');
    expect(g.bossRig!.ink.list.opCount, lessThan(500), reason: 'one drawing stays within the op budget');
    expect(g.sparks.capacity, sparks);
    expect(g.puffs.capacity, puffs);
    expect(g.hazards.items.length, hazards);
    // Drawings are made on ones at most (24/s per rig), never per tick.
    final before = g.heroRig.drawings;
    await runFor(g, 1);
    expect(g.heroRig.drawings - before, lessThanOrEqualTo(26));
    await tester.pump(const Duration(seconds: 1));
  });
}

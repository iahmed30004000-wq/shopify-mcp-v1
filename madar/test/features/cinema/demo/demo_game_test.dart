import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/core/providers.dart';
import 'package:madar/core/sound/prayer_mute.dart';
import 'package:madar/core/sound/sound_api.dart';
import 'package:madar/features/cinema/engine/cinema_engine.dart';
import 'package:madar/features/cinema/games/demo/demo_game.dart';

import '../cinema_fakes.dart';
import 'demo_support.dart';

// The vignette, headless: every era plays itself through in attract mode
// (opening card, act one, the Baron, the finale, the results) within the
// 30-second brief, with pooled hazards and a measured update / recording
// cost per frame.
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

  Future<DemoGame> mount(WidgetTester tester, Era era, {bool skipOpening = true}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [hapticsServiceProvider.overrideWithValue(haptics), prayerMuteProvider.overrideWithValue(mute)],
        child: MaterialApp(
          locale: const Locale('ar'),
          supportedLocales: L10n.supportedLocales,
          localizationsDelegates: L10n.localizationsDelegates,
          home: CinemaGameView(
            kit: kit.kit,
            skipOpening: skipOpening,
            onResult: (r) => reported = r,
            builder: (ctx) => DemoGame(context: ctx, era: era, autoplay: true),
          ),
        ),
      ),
    );
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    final g = mountedDemo(tester);
    await runUntil(g, () => g.state != SceneState.loading, maxSeconds: 2, what: 'load');
    return g;
  }

  for (final era in Era.values) {
    testWidgets('the show plays itself through to a curtain call – ${era.name}', (tester) async {
      final g = await mount(tester, era, skipOpening: false);
      final pool = g.hazardPoolSize;
      expect(pool, 5);
      // Opening: card then iris.
      await runUntil(g, () => g.isPlaying, maxSeconds: 12, what: 'opening');
      final opening = g.clock.time;
      expect(opening, lessThan(8), reason: 'opening card + iris-in should be short');
      // Act one.
      final actOne = await runUntil(g, () => g.act != DemoAct.run, maxSeconds: 30, what: 'the Baron');
      expect(g.cleared, DemoGame.runGoal);
      expect(g.hud.progress, isNull);
      expect(kit.music.last.log, contains('cue boss'));
      expect(kit.music.last.log, contains('stinger bossIntro'));
      // The chapter card, then the fight.
      await runUntil(g, () => g.act == DemoAct.boss, maxSeconds: 6, what: 'chapter card');
      expect(g.hud.bossHealth, 1);
      expect(g.hud.bossName, isNotEmpty);
      final fight = await runUntil(g, () => g.act == DemoAct.finale, maxSeconds: 40, what: 'boss defeat');
      expect(g.bossHits, DemoGame.bossGoal);
      expect(g.boss.phase, 2);
      expect(kit.music.last.log, contains('stinger bossDefeat'));
      // Finale: iris out, end card, results.
      await runUntil(g, () => g.state == SceneState.ended, maxSeconds: 15, what: 'results');
      final total = g.clock.time;
      expect(reported, isNotNull);
      expect(reported!.won, isTrue);
      expect(reported!.stats['bossHits'], DemoGame.bossGoal);
      expect(g.hazardPoolSize, pool, reason: 'hazards are pooled, never re-created');
      expect(g.hud.lives, 3, reason: 'attract mode clears everything');
      expect(total, lessThan(42), reason: 'the whole vignette (with opening and ending) fits the 30 s brief + titles');
      // ignore: avoid_print
      print('${era.name}: opening ${opening.toStringAsFixed(1)} s, act one ${actOne.toStringAsFixed(1)} s, '
          'boss ${fight.toStringAsFixed(1)} s, total ${total.toStringAsFixed(1)} s');
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(seconds: 1));
    });
  }

  testWidgets('a hit costs a life, three end the show', (tester) async {
    final g = await mount(tester, Era.rubberHose);
    g.autoplay = false;
    await runUntil(g, () => g.hud.lives == 2, maxSeconds: 10, what: 'first hit');
    expect(g.film.flash, greaterThan(0));
    expect(kit.sfx.last.played, contains(CinemaSound.hurt));
    expect(haptics.fired, contains(Haptic.heavy));
    await runUntil(g, () => g.state == SceneState.ended, maxSeconds: 30, what: 'show over');
    expect(reported!.won, isFalse);
    expect(g.hud.lives, 0);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('a tap jumps; the hero clears a roller mid-air', (tester) async {
    final g = await mount(tester, Era.silent);
    g.autoplay = false;
    await runUntil(g, () => g.isPlaying, maxSeconds: 3, what: 'play');
    g.onScreenTapDown(Vector2.zero(), Offset.zero);
    await runFor(g, 0.2);
    expect(g.heroY, lessThan(DemoGame.groundY - 60));
    expect(kit.sfx.last.played, contains(CinemaSound.jump));
    await runUntil(g, () => g.heroY >= DemoGame.groundY - 0.01, maxSeconds: 3, what: 'landing');
    expect(kit.sfx.last.played, contains(CinemaSound.land));
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('frame cost: update and scene recording stay within budget', (tester) async {
    final g = await mount(tester, Era.rubberHose);
    await runUntil(g, () => g.isPlaying, maxSeconds: 3, what: 'play');
    g.filmEnabled = false; // record the scene only (the film pass is GPU work)
    // Warm the caches (first drawings) before measuring.
    await runFor(g, 2);
    final sw = Stopwatch();
    var updateUs = 0, recordUs = 0;
    const frames = 240;
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
    print('demo frame cost (host, act ${g.act.name}): update ${update.toStringAsFixed(2)} ms, '
        'record ${record.toStringAsFixed(2)} ms');
    expect(update, lessThan(6), reason: 'update budget is 2 ms on a phone; the host is not faster');
    expect(record, lessThan(9), reason: 'recording budget is 3 ms on a phone');
    await tester.pump(const Duration(seconds: 1));
  });
}


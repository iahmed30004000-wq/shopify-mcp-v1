// Shared helpers for the Flappy Orbit tests: mounting the game through the
// engine's host view and driving it headlessly through game time.
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/core/motion/motion.dart' show MotionScope;
import 'package:madar/core/providers.dart';
import 'package:madar/core/sound/prayer_mute.dart';
import 'package:madar/core/sound/sound_api.dart';
import 'package:madar/features/cinema/engine/cinema_engine.dart';
import 'package:madar/features/cinema/games/flappy_orbit/flappy_orbit_game.dart';

import '../../cinema_fakes.dart';

/// The game the mounted [CinemaGameView] is running.
FlappyOrbitGame mountedOrbit(WidgetTester tester) =>
    tester.widget<GameWidget<CinemaGame>>(find.byType(GameWidget<CinemaGame>)).game! as FlappyOrbitGame;

/// Steps [game] at 60 Hz until [done] (or [maxSeconds] of game time),
/// yielding to the microtask queue every few ticks so game-time futures
/// (iris, cards, endScene) resume. Returns the seconds advanced.
Future<double> runUntil(FlappyOrbitGame game, bool Function() done, {double maxSeconds = 90, String? what}) async {
  const dt = 1 / 60;
  var t = 0.0;
  var i = 0;
  while (!done() && t < maxSeconds) {
    game.update(dt);
    t += dt;
    if (++i % 4 == 0) await null;
  }
  await null;
  expect(done(), isTrue, reason: 'timed out after ${t.toStringAsFixed(1)} s waiting for ${what ?? 'condition'}');
  return t;
}

/// Steps [game] for [seconds] of game time.
Future<void> runFor(FlappyOrbitGame game, double seconds) async {
  const dt = 1 / 60;
  var t = 0.0;
  var i = 0;
  while (t < seconds - 1e-9) {
    game.update(dt);
    t += dt;
    if (++i % 4 == 0) await null;
  }
  await null;
}

/// A full-screen host of the game, like the hall's screen but without the
/// records store (tests and screenshots).
class OrbitTestScreen extends StatelessWidget {
  const OrbitTestScreen({
    super.key,
    this.kit,
    this.autoplay = false,
    this.skipOpening = false,
    this.gatesPerBoss = 8,
    this.bossCount = 3,
    this.scoreSink,
    this.onResult,
    this.seed = 0,
  });

  final CinemaKit? kit;
  final bool autoplay;
  final bool skipOpening;
  final int gatesPerBoss;
  final int bossCount;
  final ScoreSink? scoreSink;
  final ValueChanged<GameResult>? onResult;
  final int seed;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    body: CinemaGameView(
      kit: kit,
      skipOpening: skipOpening,
      scoreSink: scoreSink,
      onResult: onResult,
      seed: seed,
      builder: (ctx) => FlappyOrbitGame(context: ctx, autoplay: autoplay, gatesPerBoss: gatesPerBoss, bossCount: bossCount),
    ),
  );
}

/// Mounts the game with the test kit (recording audio, counting FilmFx) in
/// [locale], waits for it to load and returns it.
Future<FlappyOrbitGame> mountOrbit(
  WidgetTester tester, {
  required TestKit kit,
  RecordingHaptics? haptics,
  Locale locale = const Locale('ar'),
  bool autoplay = false,
  bool skipOpening = true,
  bool reducedMotion = false,
  int gatesPerBoss = 8,
  int bossCount = 3,
  ScoreSink? scoreSink,
  ValueChanged<GameResult>? onResult,
}) async {
  final mute = PrayerMuteController(SilentSoundService());
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        hapticsServiceProvider.overrideWithValue(haptics ?? RecordingHaptics()),
        prayerMuteProvider.overrideWithValue(mute),
      ],
      child: MaterialApp(
        key: ValueKey('orbit-${locale.languageCode}-$reducedMotion-$autoplay-$gatesPerBoss-$bossCount'),
        locale: locale,
        supportedLocales: L10n.supportedLocales,
        localizationsDelegates: L10n.localizationsDelegates,
        home: MotionScope(
          reduced: reducedMotion,
          child: OrbitTestScreen(
            kit: kit.kit,
            autoplay: autoplay,
            skipOpening: skipOpening,
            gatesPerBoss: gatesPerBoss,
            bossCount: bossCount,
            scoreSink: scoreSink,
            onResult: onResult,
          ),
        ),
      ),
    ),
  );
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
  final g = mountedOrbit(tester);
  await runUntil(g, () => g.state != SceneState.loading, maxSeconds: 2, what: 'load');
  return g;
}

/// Pumps a second so Flame's tap recognizer timers drain before the test
/// ends.
Future<void> settleTaps(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump(const Duration(seconds: 1));
}

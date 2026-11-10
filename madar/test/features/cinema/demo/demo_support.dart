// Shared helpers for the demo tests: finding the mounted game and driving
// it headlessly through game time (no rendering between steps).
import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/cinema/engine/cinema_engine.dart';
import 'package:madar/features/cinema/games/demo/demo_game.dart';

/// The game the mounted [CinemaGameView] is running.
DemoGame mountedDemo(WidgetTester tester) =>
    tester.widget<GameWidget<CinemaGame>>(find.byType(GameWidget<CinemaGame>)).game! as DemoGame;

/// Steps [game] at 60 Hz until [done] (or [maxSeconds] of game time). Yields
/// to the microtask queue every few ticks so game-time futures (iris,
/// cards, endScene) resume. Returns the seconds advanced.
Future<double> runUntil(DemoGame game, bool Function() done, {double maxSeconds = 90, String? what}) async {
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
Future<void> runFor(DemoGame game, double seconds) async {
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

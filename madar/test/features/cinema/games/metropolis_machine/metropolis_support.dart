// Shared helpers for the Metropolis Machine tests: the host widget, the
// mounted game and driving it headlessly through game time.
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/features/cinema/engine/cinema_engine.dart';
import 'package:madar/features/cinema/games/metropolis_machine/metropolis_game.dart';

/// The game the mounted [CinemaGameView] is running.
MetropolisGame mountedMetro(WidgetTester tester) =>
    tester.widget<GameWidget<CinemaGame>>(find.byType(GameWidget<CinemaGame>)).game! as MetropolisGame;

/// A full-screen host of the game (black backdrop, like the hall's screen).
Widget metroHost({
  required CinemaGameBuilder builder,
  CinemaKit? kit,
  bool skipOpening = false,
  ValueChanged<GameResult>? onResult,
  Locale locale = const Locale('ar'),
  List<Override> overrides = const [],
}) => ProviderScope(
  overrides: overrides,
  child: MaterialApp(
    locale: locale,
    supportedLocales: L10n.supportedLocales,
    localizationsDelegates: L10n.localizationsDelegates,
    home: Scaffold(
      backgroundColor: Colors.black,
      body: CinemaGameView(kit: kit, skipOpening: skipOpening, onResult: onResult, builder: builder),
    ),
  ),
);

/// Steps [game] at 60 Hz until [done] (or [maxSeconds] of game time),
/// yielding to the microtask queue every few ticks so game-time futures
/// (cards, iris, endScene) resume. Returns the seconds advanced.
Future<double> runUntil(CinemaGame game, bool Function() done, {double maxSeconds = 90, String? what}) async {
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
Future<void> runFor(CinemaGame game, double seconds) async {
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

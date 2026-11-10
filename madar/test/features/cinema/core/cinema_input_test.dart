import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/core/sound/prayer_mute.dart';
import 'package:madar/core/sound/sound_api.dart';
import 'package:madar/features/cinema/engine/cinema_engine.dart';

import '../cinema_fakes.dart';

class _Game extends CinemaGame {
  _Game({required super.context}) : super(skin: EraSkins.of(Era.rubberHose));

  final List<String> input = [];
  int releases = 0;

  @override
  String get gameId => 'input_test';

  @override
  Future<void> onSceneLoad() async {}

  @override
  void onScreenTapDown(Vector2 worldPoint, Offset screenPoint) => input.add('tapDown');
  @override
  void onScreenTapUp(Vector2 worldPoint, Offset screenPoint) => input.add('tapUp');
  @override
  void onScreenTapCancel() => input.add('tapCancel');
  @override
  void onScreenDrag(Vector2 worldDelta, Offset screenPoint) => input.add('drag');
  @override
  void onScreenDragEnd() => input.add('dragEnd');
  @override
  void onScreenDragCancel() => input.add('dragCancel');

  @override
  void releaseInput() {
    releases++;
    super.releaseInput();
  }
}

/// A game that overrides none of the new hooks (their defaults are no-ops).
class _PlainGame extends CinemaGame {
  _PlainGame({required super.context}) : super(skin: EraSkins.of(Era.rubberHose));

  int ends = 0;

  @override
  String get gameId => 'input_plain_test';

  @override
  Future<void> onSceneLoad() async {}

  @override
  void onScreenDragEnd() => ends++;
}

// The input routing forwards every way a gesture can stop: a tap that is
// cancelled (it turned into a drag, the system took the pointer) and a drag
// that is cancelled. The Intermission lets go of whatever the player is
// holding, and the rest of that gesture never reaches the game.
void main() {
  setUpAll(() async => CinemaShaders.preload());

  Future<T> pumpGame<T extends CinemaGame>(WidgetTester tester, T Function(CinemaContext) build) async {
    late T game;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [prayerMuteProvider.overrideWithValue(PrayerMuteController(SilentSoundService()))],
        child: MaterialApp(
          locale: const Locale('ar'),
          supportedLocales: L10n.supportedLocales,
          localizationsDelegates: L10n.localizationsDelegates,
          home: CinemaGameView(
            kit: TestKit().kit,
            skipOpening: true,
            scoreSink: MemoryScoreSink(),
            builder: (ctx) => game = build(ctx),
          ),
        ),
      ),
    );
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(game.state, SceneState.playing);
    return game;
  }

  int count(List<String> log, String e) => log.where((x) => x == e).length;

  Future<void> slide(WidgetTester tester, TestGesture g, {int steps = 5, Offset by = const Offset(0, 14)}) async {
    for (var i = 0; i < steps; i++) {
      await g.moveBy(by);
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  testWidgets('a tap that turns into a drag is cancelled for the game (no tap-up follows)', (tester) async {
    final g = await pumpGame(tester, (ctx) => _Game(context: ctx));
    final finger = await tester.startGesture(g.playRect.center);
    await tester.pump(const Duration(milliseconds: 16));
    await slide(tester, finger);
    await finger.up();
    await tester.pump(const Duration(seconds: 1));
    expect(g.input.first, 'tapDown');
    expect(count(g.input, 'tapCancel'), 1);
    expect(count(g.input, 'tapUp'), 0);
    expect(g.input.indexOf('tapCancel'), lessThan(g.input.indexOf('drag')));
    expect(g.input.last, 'dragEnd');
    expect(count(g.input, 'dragEnd'), 1);
    expect(count(g.input, 'dragCancel'), 0);
  });

  testWidgets('a tap the system takes away is cancelled', (tester) async {
    final g = await pumpGame(tester, (ctx) => _Game(context: ctx));
    final finger = await tester.startGesture(g.playRect.center);
    await tester.pump(const Duration(milliseconds: 16));
    await finger.cancel();
    await tester.pump(const Duration(seconds: 1));
    expect(g.input, ['tapDown', 'tapCancel']);
  });

  testWidgets('a cancelled drag is cancelled, then ended, exactly once', (tester) async {
    final g = await pumpGame(tester, (ctx) => _Game(context: ctx));
    final finger = await tester.startGesture(g.playRect.center);
    await tester.pump(const Duration(milliseconds: 16));
    await slide(tester, finger);
    await finger.cancel();
    await tester.pump(const Duration(seconds: 1));
    expect(count(g.input, 'dragCancel'), 1);
    expect(count(g.input, 'dragEnd'), 1);
    expect(g.input.indexOf('dragCancel'), lessThan(g.input.indexOf('dragEnd')));
    expect(g.input.last, 'dragEnd');
  });

  testWidgets('the Intermission lets go of held fingers; the rest of those gestures never reaches the game', (
    tester,
  ) async {
    final g = await pumpGame(tester, (ctx) => _Game(context: ctx));
    final c = g.playRect.center;
    // One finger steering (a drag), another resting on the screen (a tap).
    final steer = await tester.startGesture(c, pointer: 11);
    await tester.pump(const Duration(milliseconds: 16));
    await slide(tester, steer);
    final rest = await tester.startGesture(c + const Offset(60, 120), pointer: 12);
    await tester.pump(const Duration(milliseconds: 16));
    expect(g.input, containsAllInOrder(['tapDown', 'tapCancel', 'drag', 'tapDown']));
    g.input.clear();

    g.pauseGame();
    expect(g.state, SceneState.paused);
    expect(g.releases, 1, reason: 'pauseGame calls releaseInput once');
    expect(g.input, ['tapCancel', 'dragCancel', 'dragEnd'], reason: 'taps first, then drags');

    // The fingers keep moving and lift behind the Intermission card.
    await slide(tester, steer);
    await steer.up();
    await rest.up();
    await tester.pump(const Duration(seconds: 1));
    expect(g.input, ['tapCancel', 'dragCancel', 'dragEnd'], reason: 'no drag, drag-end or tap-up after the release');

    // Releasing again with nothing held tells the game nothing.
    g.releaseInput();
    expect(g.input, hasLength(3));

    // After the Intermission new gestures reach the game as usual.
    g.resumeGame();
    await tester.pump(const Duration(milliseconds: 16));
    g.input.clear();
    await tester.tapAt(c);
    await tester.pump(const Duration(seconds: 1));
    expect(g.input, ['tapDown', 'tapUp']);
  });

  testWidgets('games that ignore the new hooks still get their drag end', (tester) async {
    final g = await pumpGame(tester, (ctx) => _PlainGame(context: ctx));
    final finger = await tester.startGesture(g.playRect.center);
    await tester.pump(const Duration(milliseconds: 16));
    await slide(tester, finger);
    await finger.cancel();
    await tester.pump(const Duration(seconds: 1));
    expect(g.ends, 1, reason: 'a cancelled drag still ends (as before)');

    final again = await tester.startGesture(g.playRect.center);
    await tester.pump(const Duration(milliseconds: 16));
    await slide(tester, again);
    g.pauseGame();
    expect(g.ends, 2, reason: 'the Intermission ends the held drag');
    await again.up();
    await tester.pump(const Duration(seconds: 1));
    expect(g.ends, 2, reason: 'and the lift does not end it twice');
  });
}

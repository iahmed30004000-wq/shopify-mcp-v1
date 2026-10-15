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
  _Game({required super.context}) : super(skin: EraSkins.of(Era.silent));

  @override
  String get gameId => 'pause_freeze_test';

  @override
  IntertitleCard? openingCard() => const IntertitleCard(text: 'Opening');

  @override
  Future<void> onSceneLoad() async {}

  @override
  void onScreenTapDown(Vector2 worldPoint, Offset screenPoint) {}
}

// Transitions run on game time, and game time stops for them during the
// Intermission and while the app is in the background: a chapter card
// opened right before the pause must still be there, with its full reading
// time left, when the player comes back.
void main() {
  setUpAll(() async => CinemaShaders.preload());

  Future<_Game> pumpGame(WidgetTester tester, {bool skipOpening = true}) async {
    late _Game game;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [prayerMuteProvider.overrideWithValue(PrayerMuteController(SilentSoundService()))],
        child: MaterialApp(
          locale: const Locale('ar'),
          supportedLocales: L10n.supportedLocales,
          localizationsDelegates: L10n.localizationsDelegates,
          home: CinemaGameView(
            kit: TestKit().kit,
            skipOpening: skipOpening,
            scoreSink: MemoryScoreSink(),
            builder: (ctx) => game = _Game(context: ctx),
          ),
        ),
      ),
    );
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    return game;
  }

  Future<void> pumpSeconds(WidgetTester tester, double seconds) async {
    for (var t = 0.0; t < seconds; t += 0.05) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets('a card opened right before the Intermission waits behind it, then reads on', (tester) async {
    final g = await pumpGame(tester);
    expect(g.state, SceneState.playing);
    var done = false;
    g.transitions
        .intertitle(
          const IntertitleCard(text: 'Chapter', kind: IntertitleKind.chapter),
          hold: const Duration(seconds: 1),
        )
        .then((_) => done = true);
    await pumpSeconds(tester, 0.4);
    expect(g.transitions.coverage, greaterThan(0.95), reason: 'the card is up');
    g.pauseGame();
    await pumpSeconds(tester, 4);
    expect(done, isFalse, reason: 'the reading time must not run out behind the Intermission');
    expect(g.transitions.coverage, greaterThan(0.95), reason: 'the card is still there after the pause');
    expect(g.transitions.isActive, isTrue);
    g.resumeGame();
    await pumpSeconds(tester, 0.3);
    expect(done, isFalse, reason: 'the hold picks up where it stopped (about 0.9 s left)');
    expect(g.transitions.coverage, greaterThan(0.95));
    await pumpSeconds(tester, 1.6);
    expect(done, isTrue);
    expect(g.transitions.coverage, lessThan(0.01));
  });

  testWidgets('an iris started right before the pause stands still until resume', (tester) async {
    final g = await pumpGame(tester);
    var closed = false;
    g.transitions.irisOut(duration: const Duration(seconds: 1)).then((_) => closed = true);
    await pumpSeconds(tester, 0.3);
    g.pauseGame();
    final at = g.transitions.coverage;
    expect(at, inExclusiveRange(0.0, 1.0));
    await pumpSeconds(tester, 2);
    expect(g.transitions.coverage, closeTo(at, 1e-9));
    expect(closed, isFalse);
    g.resumeGame();
    await pumpSeconds(tester, 1.2);
    expect(closed, isTrue);
    expect(g.transitions.coverage, closeTo(1, 1e-6));
  });

  testWidgets('backgrounding holds the opening card until the app is back', (tester) async {
    final g = await pumpGame(tester, skipOpening: false);
    await pumpSeconds(tester, 0.4);
    expect(g.state, SceneState.opening);
    g.lifecycleStateChange(AppLifecycleState.paused);
    expect(g.state, SceneState.opening, reason: 'the opening has no Intermission');
    // Even if a host kept ticking the loop in the background, the card and
    // the iris behind it wait.
    for (var i = 0; i < 600; i++) {
      g.update(1 / 60);
      if (i % 4 == 0) await null;
    }
    await tester.pump();
    expect(g.state, SceneState.opening, reason: 'the opening card is still showing');
    expect(g.transitions.coverage, greaterThan(0.95));
    g.lifecycleStateChange(AppLifecycleState.resumed);
    for (var i = 0; i < 200 && g.state != SceneState.playing; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(g.state, SceneState.playing);
  });

  testWidgets('backgrounding mid-play freezes a card too (the show pauses)', (tester) async {
    final g = await pumpGame(tester);
    var done = false;
    g.transitions
        .intertitle(const IntertitleCard(text: 'Chapter'), hold: const Duration(seconds: 1))
        .then((_) => done = true);
    await pumpSeconds(tester, 0.4);
    g.lifecycleStateChange(AppLifecycleState.hidden);
    g.lifecycleStateChange(AppLifecycleState.paused);
    expect(g.state, SceneState.paused);
    for (var i = 0; i < 600; i++) {
      g.update(1 / 60);
      if (i % 4 == 0) await null;
    }
    await tester.pump();
    expect(done, isFalse);
    g.lifecycleStateChange(AppLifecycleState.hidden);
    g.lifecycleStateChange(AppLifecycleState.inactive);
    g.lifecycleStateChange(AppLifecycleState.resumed);
    expect(g.state, SceneState.paused, reason: 'coming back shows the Intermission; the player resumes');
    g.resumeGame();
    await pumpSeconds(tester, 2);
    expect(done, isTrue);
  });
}

import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/core/providers.dart';
import 'package:madar/core/sound/prayer_mute.dart';
import 'package:madar/core/sound/sound_api.dart';
import 'package:madar/features/cinema/engine/cinema_engine.dart';

import '../cinema_fakes.dart';

class _Counter extends Component {
  int updates = 0;
  @override
  void update(double dt) => updates++;
}

class _TestGame extends CinemaGame {
  _TestGame({required super.context}) : super(skin: EraSkins.of(Era.rubberHose));

  final _Counter counter = _Counter();
  int starts = 0;
  final List<Vector2> taps = [];

  @override
  String get gameId => 'test_game';

  @override
  IntertitleCard? openingCard() => const IntertitleCard(text: 'Test');

  @override
  Future<void> onSceneLoad() async => world.add(counter);

  @override
  void onSceneStart() => starts++;

  @override
  void onScreenTapDown(Vector2 worldPoint, Offset screenPoint) => taps.add(worldPoint);
}

void main() {
  late TestKit kit;
  late MemoryScoreSink sink;
  late RecordingHaptics haptics;
  late PrayerMuteController mute;
  final built = <_TestGame>[];
  GameResult? reported;

  setUpAll(() async => CinemaShaders.preload());

  setUp(() {
    kit = TestKit();
    sink = MemoryScoreSink();
    haptics = RecordingHaptics();
    mute = PrayerMuteController(SilentSoundService());
    built.clear();
    reported = null;
  });

  Future<_TestGame> pumpGame(
    WidgetTester tester, {
    bool skipOpening = true,
    VoidCallback? onExit,
    Future<bool> Function()? confirmLeave,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          hapticsServiceProvider.overrideWithValue(haptics),
          prayerMuteProvider.overrideWithValue(mute),
          cinemaScoreSinkProvider.overrideWithValue(sink),
        ],
        child: MaterialApp(
          locale: const Locale('ar'),
          supportedLocales: L10n.supportedLocales,
          localizationsDelegates: L10n.localizationsDelegates,
          home: CinemaGameView(
            kit: kit.kit,
            skipOpening: skipOpening,
            onResult: (r) => reported = r,
            onExit: onExit,
            confirmLeave: confirmLeave,
            builder: (ctx) {
              final g = _TestGame(context: ctx);
              built.add(g);
              return g;
            },
          ),
        ),
      ),
    );
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    return built.last;
  }

  Future<void> pumpSeconds(WidgetTester tester, double seconds) async {
    for (var t = 0.0; t < seconds; t += 0.05) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets('opening: intertitle → iris-in → playing, music cued', (tester) async {
    final g = await pumpGame(tester, skipOpening: false);
    expect(g.state, SceneState.opening);
    expect(g.transitions.coverage, greaterThan(0.9));
    for (var i = 0; i < 400 && g.state != SceneState.playing; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(g.state, SceneState.playing);
    expect(g.starts, 1);
    expect(g.transitions.coverage, lessThan(0.01));
    final music = kit.music.single;
    expect(music.log.first, 'cue adventure');
    expect(music.log, contains('stinger sceneStart'));
  });

  testWidgets('frames are graded through FilmFx; world updates while playing', (tester) async {
    final g = await pumpGame(tester);
    expect(g.state, SceneState.playing);
    await pumpSeconds(tester, 0.3);
    expect(kit.fx.single.applies, greaterThan(3));
    expect(g.counter.updates, greaterThan(3));
    g.filmEnabled = false;
    final before = kit.fx.single.applies;
    await pumpSeconds(tester, 0.2);
    expect(kit.fx.single.applies, before);
  });

  testWidgets('pause freezes the world but not the projector; resume', (tester) async {
    final g = await pumpGame(tester);
    g.pauseGame();
    await tester.pump();
    expect(g.state, SceneState.paused);
    expect(g.overlays.isActive(CinemaOverlays.pause), isTrue);
    expect(kit.music.single.ducked, isTrue);
    final updates = g.counter.updates;
    final boil = g.clock.time;
    await pumpSeconds(tester, 0.5);
    expect(g.counter.updates, updates, reason: 'world frozen');
    expect(g.clock.time, greaterThan(boil), reason: 'film clock keeps rolling');
    g.resumeGame();
    await pumpSeconds(tester, 0.1);
    expect(g.state, SceneState.playing);
    expect(g.overlays.isActive(CinemaOverlays.pause), isFalse);
    expect(kit.music.single.ducked, isFalse);
    expect(g.counter.updates, greaterThan(updates));
  });

  testWidgets('HUD pause button (top-end = left in RTL) pauses', (tester) async {
    final g = await pumpGame(tester);
    final hudLayer = g.children.whereType<HudLayer>().single;
    final pause = hudLayer.placements.firstWhere((p) => p.$1 == HudSlot.topEnd).$2;
    final score = hudLayer.placements.firstWhere((p) => p.$1 == HudSlot.topStart).$2;
    expect(pause.center.dx, lessThan(g.canvasSize.x / 2));
    expect(score.center.dx, greaterThan(g.canvasSize.x / 2));
    await tester.tapAt(pause.center);
    await tester.pump(const Duration(seconds: 1)); // gesture timers
    expect(g.state, SceneState.paused);
  });

  testWidgets('unhandled taps reach onScreenTapDown in world units', (tester) async {
    final g = await pumpGame(tester);
    await tester.tapAt(g.playRect.center);
    await tester.pump(const Duration(seconds: 1)); // gesture timers
    expect(g.taps, hasLength(1));
    expect(g.taps.single.x, closeTo(g.worldSize.x / 2, 1));
    expect(g.taps.single.y, closeTo(g.worldSize.y / 2, 1));
  });

  testWidgets('feedback plays the sound and its paired haptic', (tester) async {
    final g = await pumpGame(tester);
    g.feedback(CinemaSound.hurt);
    expect(kit.sfx.single.played, [CinemaSound.hurt]);
    expect(haptics.fired, [Haptic.heavy]);
  });

  testWidgets('endScene reports the result and shows the results card', (tester) async {
    final g = await pumpGame(tester);
    g.addScore(7);
    g.addScore(-10);
    expect(g.hud.score, 0, reason: 'never negative');
    g.addScore(5);
    g.endScene(won: true, stats: {'barrels': 3});
    for (var i = 0; i < 300 && g.state != SceneState.ended; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(g.state, SceneState.ended);
    expect(g.overlays.isActive(CinemaOverlays.results), isTrue);
    expect(reported?.score, 5);
    expect(reported?.won, isTrue);
    expect(reported?.stats, {'barrels': 3});
    expect(await sink.best('test_game'), 5);
    expect(kit.music.single.log, containsAll(['stinger victory', 'cue victory']));
  });

  testWidgets('prayer mute silences music and effects', (tester) async {
    final g = await pumpGame(tester);
    final lease = mute.acquire('adhan');
    await tester.pump();
    expect(kit.music.single.prayerMuted, isTrue);
    expect(kit.sfx.single.prayerMuted, isTrue);
    lease.release();
    await tester.pump();
    expect(kit.music.single.prayerMuted, isFalse);
    expect(g.state, SceneState.playing);
  });

  // APK #15: back used to resume, so back could never get the player out.
  testWidgets('system back pauses; back again leaves instead of resuming', (tester) async {
    var asked = 0;
    var exits = 0;
    final g = await pumpGame(
      tester,
      onExit: () => exits++,
      confirmLeave: () async {
        asked++;
        return true;
      },
    );
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(g.state, SceneState.paused);
    expect(asked, 0, reason: 'the first back only pauses');

    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.pump();
    expect(asked, 1, reason: 'a stray back is confirmed first');
    expect(exits, 1);
    expect(g.state, SceneState.paused, reason: 'back never puts the player back into the show');
  });

  testWidgets('a refused confirm stays in the Intermission', (tester) async {
    var exits = 0;
    final g = await pumpGame(tester, onExit: () => exits++, confirmLeave: () async => false);
    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.pump();
    expect(exits, 0);
    expect(g.state, SceneState.paused);
  });

  testWidgets('a running show carries a pause plate; the Intermission replaces it', (tester) async {
    final g = await pumpGame(tester);
    expect(find.byType(PausePlate), findsOneWidget);
    await tester.tap(find.byType(PausePlate));
    await tester.pump();
    expect(g.state, SceneState.paused);
    expect(find.byType(PausePlate), findsNothing);
  });

  testWidgets('backgrounding pauses the show and the music', (tester) async {
    final g = await pumpGame(tester);
    g.lifecycleStateChange(AppLifecycleState.paused);
    expect(g.state, SceneState.paused);
    expect(kit.music.single.paused, isTrue);
    g.lifecycleStateChange(AppLifecycleState.resumed);
    expect(kit.music.single.paused, isFalse);
  });

  testWidgets('restart builds a fresh game and disposes the old one', (tester) async {
    final g = await pumpGame(tester);
    g.requestRestart();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    expect(built, hasLength(2));
    expect(kit.music.first.disposed, isTrue);
    expect(kit.fx.first.disposed, isTrue);
    expect(built.last.context.seed, 1);
  });
}

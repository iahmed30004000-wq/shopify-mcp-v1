import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/core/sound/prayer_mute.dart';
import 'package:madar/core/sound/sound_api.dart';
import 'package:madar/features/cinema/engine/cinema_engine.dart';
import 'package:madar/features/cinema/engine/stage/stage_kit.dart';

import '../cinema_fakes.dart';

class _Game extends CinemaGame {
  _Game({required super.context, Era era = Era.rubberHose}) : super(skin: EraSkins.of(era));

  @override
  String get gameId => 'overlay_test';

  @override
  Future<void> onSceneLoad() async {}
}

void main() {
  late TestKit kit;
  late List<_Game> built;
  final ar = lookupL10n(const Locale('ar'));

  setUpAll(() async => CinemaShaders.preload());

  setUp(() {
    kit = TestKit();
    built = [];
  });

  Future<_Game> pumpGame(WidgetTester tester, {Era era = Era.rubberHose}) async {
    tester.view.physicalSize = const Size(412, 915) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [prayerMuteProvider.overrideWithValue(PrayerMuteController(SilentSoundService()))],
        child: MaterialApp(
          locale: const Locale('ar'),
          supportedLocales: L10n.supportedLocales,
          localizationsDelegates: L10n.localizationsDelegates,
          home: CinemaGameView(
            kit: kit.kit,
            skipOpening: true,
            scoreSink: MemoryScoreSink(),
            builder: (ctx) {
              final g = _Game(context: ctx, era: era);
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

  testWidgets('the standard kit uses the stage agent pieces', (tester) async {
    final g = await pumpGame(tester);
    expect(g.stage, isA<ReelStage>());
    expect(g.transitions, isA<ReelTransitions>());
    expect(g.hudKit, isA<ReelHudKit>());
    expect(CinemaEngine.standardKit.overlays.keys, containsAll(CinemaOverlays.all));
  });

  testWidgets('intermission: the projector booth resumes, restarts and leaves', (tester) async {
    var g = await pumpGame(tester);
    g.pauseGame();
    await pumpSeconds(tester, 0.8);
    expect(find.byType(ProjectorBoothOverlay), findsOneWidget);
    expect(find.text(ar.cinemaIntermission), findsOneWidget);
    expect(find.bySemanticsLabel(ar.cinemaResume), findsOneWidget);
    await tester.tap(find.text(ar.cinemaResume));
    await pumpSeconds(tester, 0.3);
    expect(g.state, SceneState.playing);
    expect(find.byType(ProjectorBoothOverlay), findsNothing);
    expect(kit.sfx.last.played, contains(CinemaSound.tap), reason: 'buttons click through the game bus');

    g.pauseGame();
    await pumpSeconds(tester, 0.8);
    await tester.tap(find.text(ar.cinemaRestart));
    await pumpSeconds(tester, 0.3);
    expect(built, hasLength(2), reason: 'restart builds a fresh show');
    g = built.last;
    g.pauseGame();
    await pumpSeconds(tester, 0.8);
    await tester.tap(find.text(ar.cinemaLeave));
    await pumpSeconds(tester, 1);
  });

  testWidgets('results: the marquee counts the score, stamps a record and closes the curtains', (tester) async {
    final g = await pumpGame(tester, era: Era.technicolor);
    expect(g.stage.curtainOpen, closeTo(1, 0.01));
    g.hud.best = 10;
    g.addScore(40);
    g.endScene(won: true);
    for (var i = 0; i < 300 && g.state != SceneState.ended; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(g.state, SceneState.ended);
    await pumpSeconds(tester, 2.6);
    expect(find.byType(ResultsMarqueeOverlay), findsOneWidget);
    expect(find.text(ar.cinemaTheEnd), findsOneWidget);
    expect(find.text(ar.cinemaStageNewRecord), findsOneWidget);
    expect(find.text('٤٠'), findsWidgets, reason: 'the ticket counted up to the score');
    expect(g.stage.curtainOpen, lessThan(0.1), reason: 'curtain call: the house curtains close behind the card');
    expect(g.transitions.coverage, lessThan(0.05));
    await tester.tap(find.text(ar.cinemaPlayAgain));
    await pumpSeconds(tester, 0.4);
    expect(built, hasLength(2));
  });

  testWidgets('a lost show has no record stamp without a beaten best', (tester) async {
    final g = await pumpGame(tester, era: Era.vhs);
    g.hud.best = 500;
    g.addScore(20);
    g.endScene(won: false);
    for (var i = 0; i < 300 && g.state != SceneState.ended; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await pumpSeconds(tester, 2.4);
    expect(find.text(ar.cinemaGameOver), findsOneWidget);
    expect(find.text(ar.cinemaStageNewRecord), findsNothing);
    expect(find.text(ar.cinemaLeave), findsOneWidget);
  });
}

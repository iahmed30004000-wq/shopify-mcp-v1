import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show JSONMethodCodec, MethodCall;
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/features/cinema/engine/cinema_engine.dart';
import 'package:madar/features/cinema/games/catalog.dart';
import 'package:madar/features/cinema/hall/hall.dart';

import '../../../helpers/screenshot_harness.dart';
import '../cinema_fakes.dart';
import 'hall_fakes.dart';

class _Show extends CinemaGame {
  _Show({required super.context}) : super(skin: EraSkins.of(Era.noir));

  @override
  String get gameId => 'test_show';

  @override
  Future<void> onSceneLoad() async {}
}

void main() {
  final ar = lookupL10n(const Locale('ar'));
  late TestKit kit;
  late List<_Show> built;

  setUpAll(() async => CinemaShaders.preload());

  setUp(() {
    kit = TestKit();
    built = [];
  });

  GameCatalogEntry entry({bool playable = true}) => GameCatalogEntry(
    id: 'test_show',
    title: (l) => l.cinemaNoirTitle,
    tagline: (l) => l.cinemaNoirTagline,
    era: Era.noir,
    tier: GameTier.feature,
    genre: GameGenre.platformer,
    builder: playable
        ? (ctx) {
            final g = _Show(context: ctx);
            built.add(g);
            return g;
          }
        : null,
  );

  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(412, 915) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
  }

  Future<void> frames(WidgetTester tester, [int n = 6]) async {
    for (var i = 0; i < n; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets('an unknown id opens the "not found" stage with a way back', (tester) async {
    phone(tester);
    final env = HallTestEnv();
    await tester.pumpWidget(
      env.app(
        Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () =>
                  Navigator.of(context)
                      .push(MaterialPageRoute<void>(builder: (_) => const CinemaGameScreen(gameId: 'nope'))),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await frames(tester, 12);
    expect(find.byType(NotOpenYetStage), findsOneWidget);
    expect(find.text(ar.cinemaHallNotFound), findsOneWidget);
    await tester.tap(find.text(ar.cinemaHallBackToLobby));
    await frames(tester, 12);
    expect(find.byType(NotOpenYetStage), findsNothing);
    expect(env.session.calls, isEmpty, reason: 'no immersive session for a closed show');
  });

  testWidgets('an announced show that is not playable yet keeps its curtains drawn', (tester) async {
    phone(tester);
    final env = HallTestEnv();
    await tester.pumpWidget(env.app(CinemaGameScreen(gameId: 'test_show', entry: entry(playable: false))));
    await frames(tester);
    expect(find.byType(NotOpenYetStage), findsOneWidget);
    expect(find.text(ar.cinemaNoirTitle), findsOneWidget);
    expect(find.text(ar.cinemaHallComingSoonTitle), findsOneWidget);
    expect(built, isEmpty, reason: 'nothing is built for a show without a builder');
    expect(env.session.calls, isEmpty, reason: 'no immersive session for a closed show');
  });

  testWidgets('every catalog show without a builder, opened by id, keeps its curtains drawn', (tester) async {
    phone(tester);
    final announced = [
      for (final e in CinemaCatalog.all)
        if (!e.isPlayable) e,
    ];
    for (final e in announced) {
      final env = HallTestEnv();
      // A fresh scope per show (keyed), opened by id only: the real lookup.
      await tester.pumpWidget(
        KeyedSubtree(
          key: ValueKey(e.id),
          child: env.app(CinemaGameScreen(gameId: e.id)),
        ),
      );
      await frames(tester);
      expect(find.byType(NotOpenYetStage), findsOneWidget, reason: e.id);
      expect(find.text(e.title(ar)), findsOneWidget, reason: e.id);
      expect(find.text(ar.cinemaHallComingSoonTitle), findsOneWidget, reason: e.id);
      expect(env.session.calls, isEmpty, reason: '${e.id}: no immersive session for a closed show');
    }
    await tester.pumpWidget(const SizedBox());
    await frames(tester, 2);
  });

  testWidgets('a show runs immersive, knows its best, reports its result and restores the chrome', (tester) async {
    phone(tester);
    final env = HallTestEnv(
      records: const CinemaRecords({'test_show': GameRecord(gameId: 'test_show', best: 700, plays: 3)}),
    );
    await tester.pumpWidget(
      env.app(CinemaGameScreen(gameId: 'test_show', entry: entry(), kit: kit.kit, skipOpening: true)),
    );
    await frames(tester);
    final g = built.single;
    expect(env.session.calls, ['enter portrait']);
    expect(g.hud.best, 700);
    g.addScore(900);
    g.endScene(won: true);
    for (var i = 0; i < 300 && g.state != SceneState.ended; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await frames(tester);
    expect(env.store.submitted.single.score, 900);
    expect(env.store.records.best('test_show'), 900);
    expect(env.store.records.of('test_show')?.plays, 4);
    await tester.pumpWidget(const SizedBox());
    await frames(tester, 2);
    expect(env.session.calls.last, 'exit');
  });

  testWidgets('covered by an opaque page or the adhan, the show pauses and sleeps; uncovered it waits', (tester) async {
    phone(tester);
    final env = HallTestEnv();
    final ticking = ValueNotifier(true);
    await tester.pumpWidget(
      env.app(
        ValueListenableBuilder<bool>(
          valueListenable: ticking,
          builder: (context, on, child) => TickerMode(enabled: on, child: child!),
          child: CinemaGameScreen(gameId: 'test_show', entry: entry(), kit: kit.kit, skipOpening: true),
        ),
      ),
    );
    await frames(tester);
    final g = built.single;
    expect(g.state, SceneState.playing);
    ticking.value = false;
    await tester.pump();
    expect(g.state, SceneState.paused);
    expect(g.paused, isTrue, reason: 'the engine sleeps while covered');
    expect(kit.music.single.paused, isTrue);
    ticking.value = true;
    await tester.pump();
    expect(g.paused, isFalse);
    expect(kit.music.single.paused, isFalse);
    expect(g.state, SceneState.paused, reason: 'back in the intermission, not straight into play');
    expect(env.session.calls, contains('reassert'));
    await frames(tester, 20);
  });

  testWidgets('prayer mute shows a quiet badge that folds to a moon', (tester) async {
    phone(tester);
    final env = HallTestEnv();
    await tester.pumpWidget(
      env.app(CinemaGameScreen(gameId: 'test_show', entry: entry(), kit: kit.kit, skipOpening: true)),
    );
    await frames(tester);
    expect(find.text(ar.cinemaHallPrayerMuted), findsNothing);
    final lease = env.mute.acquire('adhan');
    await frames(tester, 2);
    expect(find.text(ar.cinemaHallPrayerMuted), findsOneWidget);
    expect(kit.music.single.prayerMuted, isTrue);
    await tester.pump(const Duration(seconds: 5));
    await frames(tester, 8);
    expect(find.text(ar.cinemaHallPrayerMuted), findsNothing, reason: 'folded to the moon icon');
    expect(find.byIcon(Icons.nightlight_round), findsOneWidget);
    lease.release();
    await frames(tester, 2);
    expect(find.byIcon(Icons.nightlight_round), findsNothing);
  });

  testWidgets('CinemaGameScreen.route opens through an iris', (tester) async {
    phone(tester);
    final env = HallTestEnv();
    await tester.pumpWidget(
      env.app(
        Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () =>
                  Navigator.of(context).push(CinemaGameScreen.route('test_show', entry: entry(playable: false))),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(CinemaGameScreen), findsOneWidget);
    expect(find.byType(IrisRouteTransition), findsOneWidget);
    await frames(tester, 12);
    expect(find.byType(NotOpenYetStage), findsOneWidget);
  });

  // ---------------------------------------------------------------------------
  // B6 (APK #15): "you cannot leave a game".

  /// The Android back button / gesture.
  Future<void> systemBack(WidgetTester tester) async {
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      'flutter/navigation',
      const JSONMethodCodec().encodeMethodCall(const MethodCall('popRoute')),
      (_) {},
    );
    await tester.pump();
  }

  /// A running show on a route of its own, so leaving it can pop.
  Future<void> openShow(WidgetTester tester, HallTestEnv env) async {
    await tester.pumpWidget(
      env.app(
        Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      CinemaGameScreen(gameId: 'test_show', entry: entry(), kit: kit.kit, skipOpening: true),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await frames(tester, 12);
  }

  testWidgets('a running show always shows the pause plate, and the Intermission leads out', (tester) async {
    phone(tester);
    final env = HallTestEnv();
    await openShow(tester, env);
    final g = built.single;
    expect(g.state, SceneState.playing);
    expect(env.session.calls, ['enter portrait']);
    expect(find.byType(PausePlate), findsOneWidget, reason: 'something visible to tap while playing');
    // 48 dp of touch target, as every Madar control has.
    expect(tester.getSize(find.byType(PausePlate)), const Size(48, 48));

    await tester.tap(find.byType(PausePlate));
    await frames(tester, 10);
    expect(g.state, SceneState.paused);
    expect(find.byType(PausePlate), findsNothing, reason: 'the plate steps aside for the Intermission');
    expect(find.text(ar.cinemaExitGame), findsOneWidget, reason: 'the plain way out');

    await tester.tap(find.text(ar.cinemaExitGame));
    await frames(tester, 16);
    expect(find.byType(CinemaGameScreen), findsNothing);
    expect(env.session.calls.last, 'exit', reason: 'orientation, system bars and screen timeout restored');
  });

  testWidgets('back opens the Intermission, back again leaves after a confirm', (tester) async {
    phone(tester);
    final env = HallTestEnv();
    await openShow(tester, env);
    final g = built.single;

    await systemBack(tester);
    await frames(tester, 8);
    expect(g.state, SceneState.paused, reason: 'the first back pauses');
    expect(find.byType(CinemaGameScreen), findsOneWidget);

    // A stray second back asks first, and "keep playing" stays in the show.
    await systemBack(tester);
    await frames(tester, 8);
    expect(find.text(ar.cinemaExitConfirmTitle), findsOneWidget);
    await tester.tap(find.text(ar.cinemaExitStay));
    await frames(tester, 8);
    expect(find.byType(CinemaGameScreen), findsOneWidget, reason: 'a stray back never throws the run away');
    expect(env.session.calls, isNot(contains('exit')));

    await systemBack(tester);
    await frames(tester, 8);
    expect(find.text(ar.cinemaExitConfirmTitle), findsOneWidget);
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text(ar.cinemaExitGame)));
    await frames(tester, 20);
    expect(find.byType(CinemaGameScreen), findsNothing, reason: 'back twice gets the player out');
    expect(env.session.calls.last, 'exit');
  });

  test(
    'madarScreenshotApp is the app shell used here',
    () => expect(madarScreenshotApp(home: const SizedBox()), isA<MaterialApp>()),
  );
}

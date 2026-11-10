// Phase 7 (Madar Cinema) routes inside the full app (router, gates, adhan
// host, app lock), in Arabic and English: the hall (`/cinema`), a show
// (`/cinema/game/<id>` – the demo runs, an unknown id shows the hall's
// "not open yet" stage) and the saved web games (`/saved-games`, `?text=`
// pre-fills the add sheet). Each page has the app's transition; back leaves
// each page for its parent. The location helpers are exact.
//
// The hall's marquee and a running show animate forever, so these tests pump
// frames instead of settling, and take the app down before they end.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/core/motion/transitions.dart';
import 'package:madar/core/routing/cinema_route_pages.dart';
import 'package:madar/core/routing/router.dart';
import 'package:madar/core/settings/app_settings.dart';
import 'package:madar/features/cinema/engine/cinema_engine.dart';
import 'package:madar/features/cinema/hall/hall.dart';
import 'package:madar/features/saved_games/saved_games.dart' show gameSessionPlatformProvider;
import 'package:madar/features/settings/settings_screen.dart';

import '../../features/cinema/cinema_fakes.dart' show TestKit;
import '../../features/cinema/hall/hall_fakes.dart' show FakeSession;
import '../../features/lock/lock_test_utils.dart';
import '../../helpers/test_app.dart';

Future<void> _frames(WidgetTester tester, [int n = 20]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Takes the app down (the marquee and a show never settle).
Future<void> _close(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 6));
}

List<Override> _overrides(FakeSession session) => [
  ...LockFixture.empty().overrides,
  // A running show draws with the engine's kit, minus real audio and film
  // passes; the immersive session is recorded, not sent to Android.
  cinemaKitProvider.overrideWithValue(TestKit().kit),
  gameSessionPlatformProvider.overrideWithValue(session),
];

void main() {
  setUpAll(() async => CinemaShaders.preload());

  group('locations', () {
    test('the cinema, a show and the saved games', () {
      expect(AppRoutes.cinema, '/cinema');
      expect(AppRoutes.cinemaGame, '/cinema/game/:id');
      expect(AppRoutes.cinemaGameOf('demo'), '/cinema/game/demo');
      expect(AppRoutes.cinemaGameOf('a b/c'), '/cinema/game/a%20b%2Fc');
      expect(AppRoutes.savedGames, '/saved-games');
      expect(AppRoutes.savedGamesOf(), '/saved-games');
      expect(AppRoutes.savedGamesOf(sharedText: '  '), '/saved-games');
      final shared = Uri.parse(AppRoutes.savedGamesOf(sharedText: 'play https://x.io/g?a=1&b=2'));
      expect(shared.path, AppRoutes.savedGames);
      expect(shared.queryParameters, {'text': 'play https://x.io/g?a=1&b=2'});
    });

    test('the cinema needs onboarding like every page', () {
      for (final loc in [AppRoutes.cinema, AppRoutes.cinemaGameOf('demo'), AppRoutes.savedGames]) {
        expect(onboardingRedirect(onboarded: false, location: loc), AppRoutes.onboarding);
        expect(onboardingRedirect(onboarded: true, location: loc), isNull);
      }
    });
  });

  for (final lang in ['ar', 'en']) {
    group(lang, () {
      final l = lookupL10n(Locale(lang));
      final direction = lang == 'ar' ? TextDirection.rtl : TextDirection.ltr;

      testWidgets('/cinema opens the hall (fade-through); back returns home', (tester) async {
        final session = FakeSession();
        final app = await pumpMadarApp(
          tester,
          settings: AppSettings(onboarded: true, languageCode: lang),
          initialLocation: AppRoutes.cinema,
          overrides: _overrides(session),
          settle: false,
        );
        await _frames(tester, 30);
        expect(find.byType(CinemaHallScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
        expect(app.router.state.uri.toString(), AppRoutes.cinema);
        expect(Directionality.of(tester.element(find.byType(CinemaHallScreen))), direction);
        expect(find.text(l.cinemaTitle), findsWidgets);
        expect(
          ModalRoute.of(tester.element(find.byType(CinemaHallScreen)))!.settings,
          isA<MadarTransitionPage<void>>(),
        );
        await tester.binding.handlePopRoute();
        await _frames(tester, 20);
        expect(find.byType(CinemaHallScreen), findsNothing);
        expect(app.location, AppRoutes.home);
        await _close(tester);
      });

      testWidgets('/cinema/game/demo runs the demo through the iris', (tester) async {
        final session = FakeSession();
        final app = await pumpMadarApp(
          tester,
          settings: AppSettings(onboarded: true, languageCode: lang),
          initialLocation: AppRoutes.cinemaGameOf('demo'),
          overrides: _overrides(session),
          settle: false,
        );
        await _frames(tester, 40);
        final screen = find.byType(CinemaGameScreen);
        expect(screen, findsOneWidget);
        expect(tester.widget<CinemaGameScreen>(screen).gameId, 'demo');
        expect(find.byType(NotOpenYetStage), findsNothing);
        expect(find.byType(CinemaGameView), findsOneWidget);
        expect(tester.takeException(), isNull);
        expect(app.router.state.uri.toString(), '/cinema/game/demo');
        expect(Directionality.of(tester.element(screen)), direction);
        final page = ModalRoute.of(tester.element(screen))!.settings;
        expect(page, isA<MadarTransitionPage<void>>());
        expect((page as MadarTransitionPage<void>).opaque, isTrue);
        expect(page.transitionDuration, CinemaRoutePages.irisIn);
        expect(session.calls, contains('enter portrait'), reason: 'a show runs immersive');
        await _close(tester);
        expect(session.calls.last, 'exit', reason: 'the chrome comes back');
      });

      testWidgets('/cinema/game/<unknown> shows the "not open yet" stage; its way back leads to the hall', (
        tester,
      ) async {
        final session = FakeSession();
        final app = await pumpMadarApp(
          tester,
          settings: AppSettings(onboarded: true, languageCode: lang),
          initialLocation: AppRoutes.cinemaGameOf('no-such-show'),
          overrides: _overrides(session),
          settle: false,
        );
        await _frames(tester, 30);
        expect(find.byType(NotOpenYetStage), findsOneWidget);
        expect(find.text(l.cinemaHallNotFound), findsOneWidget);
        expect(tester.takeException(), isNull);
        expect(app.router.state.uri.toString(), '/cinema/game/no-such-show');
        expect(session.calls, isEmpty, reason: 'no immersive session for a closed show');
        await tester.tap(find.text(l.cinemaHallBackToLobby));
        await _frames(tester, 30);
        expect(find.byType(NotOpenYetStage), findsNothing);
        expect(find.byType(CinemaHallScreen), findsOneWidget, reason: 'a show is nested under the hall');
        expect(app.location, AppRoutes.cinema);
        await _close(tester);
      });

      testWidgets('/saved-games opens Saved Games; back returns home', (tester) async {
        final app = await pumpMadarApp(
          tester,
          settings: AppSettings(onboarded: true, languageCode: lang),
          initialLocation: AppRoutes.savedGames,
          overrides: LockFixture.empty().overrides,
        );
        final screen = find.byType(SavedGamesScreen);
        expect(screen, findsOneWidget);
        expect(tester.takeException(), isNull);
        expect(tester.widget<SavedGamesScreen>(screen).initialSharedText, isNull);
        expect(Directionality.of(tester.element(screen)), direction);
        expect(ModalRoute.of(tester.element(screen))!.settings, isA<MadarTransitionPage<void>>());
        await tester.binding.handlePopRoute();
        await settleApp(tester);
        expect(find.byType(SavedGamesScreen), findsNothing);
        expect(app.location, AppRoutes.home);
        await tester.pump(const Duration(seconds: 6));
      });
    });
  }

  testWidgets('shared text reaches Saved Games', (tester) async {
    await pumpMadarApp(
      tester,
      initialLocation: AppRoutes.savedGamesOf(sharedText: 'try https://example.com/game'),
      overrides: LockFixture.empty().overrides,
      settle: false,
    );
    await _frames(tester, 30);
    expect(
      tester.widget<SavedGamesScreen>(find.byType(SavedGamesScreen)).initialSharedText,
      'try https://example.com/game',
    );
    await _close(tester);
  });

  testWidgets('CinemaNav pushes the hall, a show and the saved games over the page it was opened from', (tester) async {
    final session = FakeSession();
    final app = await pumpMadarApp(
      tester,
      settings: const AppSettings(onboarded: true, languageCode: 'en'),
      initialLocation: AppRoutes.settings,
      overrides: _overrides(session),
    );
    CinemaNav.hall(tester.element(find.byType(SettingsScreen)));
    await _frames(tester, 30);
    expect(app.router.state.uri.toString(), AppRoutes.cinema);
    CinemaNav.game(tester.element(find.byType(CinemaHallScreen)), 'no-such-show');
    await _frames(tester, 30);
    expect(app.router.state.uri.toString(), '/cinema/game/no-such-show');
    await tester.binding.handlePopRoute();
    await _frames(tester, 20);
    expect(app.router.state.uri.toString(), AppRoutes.cinema);
    CinemaNav.savedGames(tester.element(find.byType(CinemaHallScreen)));
    await _frames(tester, 30);
    expect(find.byType(SavedGamesScreen), findsOneWidget);
    await tester.binding.handlePopRoute();
    await _frames(tester, 20);
    await tester.binding.handlePopRoute();
    await _frames(tester, 20);
    expect(app.location, AppRoutes.settings, reason: 'pushed: back returns to where the hall was opened');
    expect(tester.takeException(), isNull);
    await _close(tester);
  });
}

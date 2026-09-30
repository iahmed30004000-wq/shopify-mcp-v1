import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/features/cinema/hall/cinema_hall_screen.dart';
import 'package:madar/features/cinema/hall/saved_games/saved_game.dart';
import 'package:madar/features/cinema/hall/saved_games/saved_game_launcher.dart';
import 'package:madar/features/cinema/hall/saved_games/saved_games_store.dart';

class _Launcher implements SavedGameLauncher {
  final List<Uri> opened = [];
  bool ok = true;
  @override
  Future<bool> open(SavedGame game) async {
    opened.add(game.url);
    return ok;
  }
}

void main() {
  late MemorySavedGamesStore store;
  late _Launcher launcher;
  final ar = lookupL10n(const Locale('ar'));

  Future<void> pumpHall(WidgetTester tester) async {
    tester.view.physicalSize = const Size(412, 2600) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          savedGamesStoreProvider.overrideWithValue(store),
          savedGameLauncherProvider.overrideWithValue(launcher),
        ],
        child: MaterialApp(
          locale: const Locale('ar'),
          supportedLocales: L10n.supportedLocales,
          localizationsDelegates: L10n.localizationsDelegates,
          home: const CinemaHallScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  setUp(() {
    store = MemorySavedGamesStore();
    launcher = _Launcher();
  });

  testWidgets('lists the programme with coming-soon badges', (tester) async {
    await pumpHall(tester);
    expect(find.text(ar.cinemaTitle), findsOneWidget);
    expect(find.text(ar.cinemaFlappyOrbitTitle), findsOneWidget);
    expect(find.text(ar.cinemaMetropolisTitle), findsOneWidget);
    expect(find.text(ar.cinemaDemoTitle), findsOneWidget);
    expect(find.text(ar.cinemaComingSoon), findsNWidgets(5));
    expect(find.text(ar.cinemaSavedGamesEmpty), findsOneWidget);
  });

  testWidgets('adds a saved game by link, opens it from its origin, removes it', (tester) async {
    await pumpHall(tester);
    await tester.tap(find.text(ar.cinemaAddGame));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('cinema.url')), 'not a link');
    await tester.tap(find.text(ar.cinemaSave));
    await tester.pumpAndSettle();
    expect(find.text(ar.cinemaInvalidUrl), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('cinema.url')), 'play.example.com/tetra');
    await tester.tap(find.text(ar.cinemaSave));
    await tester.pumpAndSettle();
    expect(find.text('play.example.com'), findsNWidgets(2), reason: 'title defaults to the host');
    await tester.tap(find.text('play.example.com').first);
    await tester.pumpAndSettle();
    expect(launcher.opened.single.toString(), 'https://play.example.com/tetra');
    await tester.tap(find.byTooltip(ar.cinemaRemoveGame));
    await tester.pumpAndSettle();
    expect(find.text(ar.cinemaSavedGamesEmpty), findsOneWidget);
  });

  testWidgets('a link that cannot open shows a message', (tester) async {
    await store.add(SavedGame(id: 'x', title: 'X', url: Uri.parse('https://x.example.com'), addedAt: DateTime.utc(2026)));
    launcher.ok = false;
    await pumpHall(tester);
    await tester.tap(find.text('X'));
    await tester.pumpAndSettle();
    expect(find.text(ar.cinemaOpenGameFailed), findsOneWidget);
  });
}

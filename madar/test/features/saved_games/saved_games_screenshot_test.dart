@Tags(['screenshot'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/design/themes.dart';
import 'package:madar/core/design/tokens.dart';
import 'package:madar/core/design/widgets/widgets.dart';
import 'package:madar/core/sound/prayer_mute.dart';
import 'package:madar/features/saved_games/player/game_scripts.dart';
import 'package:madar/features/saved_games/saved_games.dart';
import 'package:webview_flutter/webview_flutter.dart' show WebResourceErrorType;

import '../../helpers/screenshot_harness.dart';
import 'saved_games_fakes.dart';

/// A stand-in for the hall around the shelf.
class _HallPreview extends StatelessWidget {
  const _HallPreview();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return MadarScaffold(
      title: 'Madar Cinema',
      body: ListView(
        padding: const EdgeInsets.only(top: Space.m),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
            child: Text('…', style: text.headlineSmall),
          ),
          const SizedBox(height: Space.l),
          const SavedGamesShelf(),
          const SizedBox(height: Space.xl),
        ],
      ),
    );
  }
}

Future<void> _shot(
  WidgetTester tester,
  String name,
  Widget home, {
  MadarThemeId theme = MadarThemeId.lapis,
  Locale locale = const Locale('ar'),
  List<SavedWebGame> games = const [],
  SavedGamesLayout layout = SavedGamesLayout.grid,
  Future<void> Function(WidgetTester tester, SavedGamesEnv env)? drive,
}) async {
  final (app, env) = buildSavedGamesApp(home: home, theme: theme, locale: locale, games: games, layout: layout);
  await captureScreen(
    tester,
    app,
    'saved_games/${name}_${locale.languageCode}_${theme.name}',
    trailingFrames: 24,
    beforeCapture: drive == null ? null : (t) => drive(t, env),
  );
}

void main() {
  testWidgets('empty state (ar, lapis)', (tester) async {
    await _shot(tester, 'empty', const SavedGamesScreen());
  });

  testWidgets('empty state (en, pearl)', (tester) async {
    await _shot(tester, 'empty', const SavedGamesScreen(), theme: MadarThemeId.pearl, locale: const Locale('en'));
  });

  testWidgets('poster grid (ar, lapis)', (tester) async {
    await _shot(tester, 'grid', const SavedGamesScreen(), games: sampleGames());
  });

  testWidgets('poster grid (en, desert)', (tester) async {
    await _shot(
      tester,
      'grid',
      const SavedGamesScreen(),
      games: sampleGames(),
      theme: MadarThemeId.desert,
      locale: const Locale('en'),
    );
  });

  testWidgets('reorder list (ar, emerald)', (tester) async {
    await _shot(
      tester,
      'list',
      const SavedGamesScreen(),
      games: sampleGames(),
      layout: SavedGamesLayout.list,
      theme: MadarThemeId.emerald,
    );
  });

  testWidgets('add sheet (ar, aurora)', (tester) async {
    await _shot(
      tester,
      'add_sheet',
      const SavedGamesScreen(
        initialSharedText: 'https://claude.ai/public/artifacts/7a6b5c4d-3e2f-1a0b-9c8d-7e6f5a4b3c2d',
      ),
      theme: MadarThemeId.aurora,
      drive: (t, env) async {
        await t.tap(find.text('جلب العنوان'));
        for (var i = 0; i < 10; i++) {
          await t.pump(const Duration(milliseconds: 50));
        }
      },
    );
  });

  testWidgets('add sheet with an http error (en, pearl)', (tester) async {
    await _shot(
      tester,
      'add_sheet_error',
      const SavedGamesScreen(initialSharedText: 'http://games.example.org/tiles'),
      theme: MadarThemeId.pearl,
      locale: const Locale('en'),
    );
  });

  testWidgets('shelf in the hall (ar, lapis)', (tester) async {
    await _shot(tester, 'shelf', const _HallPreview(), games: sampleGames());
  });

  testWidgets('empty shelf in the hall (en, lapis)', (tester) async {
    await _shot(tester, 'shelf_empty', const _HallPreview(), locale: const Locale('en'));
  });

  testWidgets('player loading (ar, lapis)', (tester) async {
    await _shot(tester, 'player_loading', SavedGamePlayerScreen(game: sampleGames()[1]), games: sampleGames());
  });

  testWidgets('player controls open (ar, lapis)', (tester) async {
    await _shot(
      tester,
      'player_controls',
      SavedGamePlayerScreen(game: sampleGames()[0]),
      games: sampleGames(),
      drive: (t, env) async {
        env.web.last.pageFinished(env.web.last.loads.single);
        await t.pump(const Duration(milliseconds: 400));
        await t.tap(find.byKey(const ValueKey('savedGames.control')));
      },
    );
  });

  testWidgets('player prayer pause (ar, lapis)', (tester) async {
    await _shot(
      tester,
      'player_prayer',
      SavedGamePlayerScreen(game: sampleGames()[0]),
      games: sampleGames(),
      drive: (t, env) async {
        final web = env.web.last
          ..result = (s) => s == GameScripts.trackAudio
              ? '"{\\"early\\":true}"'
              : (s.contains('sealed') ? '"{\\"sealed\\":0,\\"blind\\":false}"' : '""');
        web
          ..pageStarted(web.loads.single)
          ..pageFinished(web.loads.single);
        await t.pump(const Duration(milliseconds: 400));
        final container = ProviderScope.containerOf(t.element(find.byType(SavedGamePlayerScreen)));
        container.read(prayerMuteProvider).acquire('screenshot');
      },
    );
  });

  testWidgets('player offline (en, emerald)', (tester) async {
    await _shot(
      tester,
      'player_offline',
      SavedGamePlayerScreen(game: sampleGames()[2]),
      games: sampleGames(),
      theme: MadarThemeId.emerald,
      locale: const Locale('en'),
      drive: (t, env) async => env.web.last.error(WebResourceErrorType.hostLookup),
    );
  });

  testWidgets('player leave confirmation (ar, desert)', (tester) async {
    await _shot(
      tester,
      'player_exit',
      SavedGamePlayerScreen(game: sampleGames()[0]),
      games: sampleGames(),
      theme: MadarThemeId.desert,
      drive: (t, env) async {
        env.web.last.pageFinished(env.web.last.loads.single);
        await t.pump(const Duration(milliseconds: 400));
        await t.binding.handlePopRoute();
      },
    );
  });
}

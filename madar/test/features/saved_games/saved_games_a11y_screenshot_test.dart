// Saved Games at a large font size (text scale 1.3) in Arabic and English,
// in Lapis (dark), Pearl (light) and Aurora – every screen a user meets,
// including the player's floating control and its error / prayer veils.
// Writes screenshots/saved_games/scale130/<screen>_<lang>_<theme>.png.
@Tags(['screenshot'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/design/themes.dart';
import 'package:madar/core/design/tokens.dart';
import 'package:madar/core/design/widgets/widgets.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/core/sound/prayer_mute.dart';
import 'package:madar/features/saved_games/player/android_hardening.dart';
import 'package:madar/features/saved_games/saved_games.dart';

import '../../helpers/screenshot_harness.dart';
import 'saved_games_fakes.dart';

class _Hall extends StatelessWidget {
  const _Hall();

  @override
  Widget build(BuildContext context) => MadarScaffold(
    title: 'Madar Cinema',
    body: ListView(
      padding: const EdgeInsets.only(top: Space.m),
      children: const [SavedGamesShelf(), SizedBox(height: Space.xl), SavedGamesShelf(showHeader: false)],
    ),
  );
}

const _themes = [MadarThemeId.lapis, MadarThemeId.pearl, MadarThemeId.aurora];
const _locales = [Locale('ar'), Locale('en')];

Future<void> _shot(
  WidgetTester tester,
  String name,
  Widget home, {
  required MadarThemeId theme,
  required Locale locale,
  List<SavedWebGame> games = const [],
  Future<void> Function(WidgetTester tester, SavedGamesEnv env)? drive,
}) async {
  final (app, env) = buildSavedGamesApp(home: home, theme: theme, locale: locale, games: games, textScale: 1.3);
  await captureScreen(
    tester,
    app,
    'saved_games/scale130/${name}_${locale.languageCode}_${theme.name}',
    trailingFrames: 24,
    beforeCapture: drive == null ? null : (t) => drive(t, env),
  );
}

L10n _l(WidgetTester tester) => L10n.of(tester.element(find.byType(Scaffold).first));

Future<void> _ready(WidgetTester t, SavedGamesEnv env) async {
  final web = env.web.last;
  web.pageFinished(web.loads.single);
  await t.pump(const Duration(milliseconds: 400));
}

void main() {
  for (final locale in _locales) {
    for (final theme in _themes) {
      final tag = '${locale.languageCode} ${theme.name}';

      testWidgets('empty ($tag)', (tester) async {
        await _shot(tester, 'empty', const SavedGamesScreen(), theme: theme, locale: locale);
      });

      testWidgets('grid ($tag)', (tester) async {
        await _shot(tester, 'grid', const SavedGamesScreen(), theme: theme, locale: locale, games: sampleGames());
      });

      testWidgets('add sheet ($tag)', (tester) async {
        await _shot(
          tester,
          'add_sheet',
          const SavedGamesScreen(initialSharedText: 'https://مثال.السعودية/لعبة'),
          theme: theme,
          locale: locale,
          drive: (t, env) async {
            await t.tap(find.text(_l(t).savedGamesFetchTitle));
            await t.pump(const Duration(milliseconds: 500));
          },
        );
      });

      testWidgets('shelf ($tag)', (tester) async {
        await _shot(tester, 'shelf', const _Hall(), theme: theme, locale: locale, games: sampleGames());
      });

      testWidgets('player controls ($tag)', (tester) async {
        await _shot(
          tester,
          'player_controls',
          SavedGamePlayerScreen(game: sampleGames()[1]),
          theme: theme,
          locale: locale,
          games: sampleGames(),
          drive: (t, env) async {
            await _ready(t, env);
            await t.tap(find.byKey(const ValueKey('savedGames.control')));
          },
        );
      });

      testWidgets('player crashed ($tag)', (tester) async {
        debugNativeWebViewId = (_) => 1;
        addTearDown(() => debugNativeWebViewId = null);
        await _shot(
          tester,
          'player_crashed',
          SavedGamePlayerScreen(game: sampleGames()[2]),
          theme: theme,
          locale: locale,
          games: sampleGames(),
          drive: (t, env) async {
            await _ready(t, env);
            env.session.gone.add(1);
          },
        );
      });

      testWidgets('player prayer ($tag)', (tester) async {
        await _shot(
          tester,
          'player_prayer',
          SavedGamePlayerScreen(game: sampleGames()[0]),
          theme: theme,
          locale: locale,
          games: sampleGames(),
          drive: (t, env) async {
            // A page whose sound Madar cannot vouch for: unloaded.
            env.web.last.result = (s) => s.contains('sealed') ? '"{\\"sealed\\":1,\\"blind\\":true}"' : '""';
            await _ready(t, env);
            final container = ProviderScope.containerOf(t.element(find.byType(SavedGamePlayerScreen)));
            container.read(prayerMuteProvider).acquire('screenshot');
          },
        );
      });
    }
  }
}

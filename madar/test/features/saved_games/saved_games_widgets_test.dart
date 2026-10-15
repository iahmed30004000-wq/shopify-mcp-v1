import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/i18n/formatters.dart' show BidiIsolate;
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/core/sound/prayer_mute.dart';
import 'package:madar/features/saved_games/player/game_scripts.dart';
import 'package:madar/features/saved_games/saved_games.dart';
import 'package:webview_flutter/webview_flutter.dart' show WebResourceErrorType;

import 'saved_games_fakes.dart';

/// A valid 1×1 PNG (stands in for a fetched site icon).
final Uint8List _onePixelPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
);

L10n l10nOf(WidgetTester tester) => L10n.of(tester.element(find.byType(Scaffold).first));

Future<void> settle(WidgetTester tester) => frames(tester, 20);

void main() {
  for (final locale in const [Locale('ar'), Locale('en')]) {
    group('SavedGamesScreen (${locale.languageCode})', () {
      testWidgets('empty state explains how to add a game – nothing pre-filled', (tester) async {
        usePhone(tester);
        final (app, env) = buildSavedGamesApp(home: const SavedGamesScreen(), locale: locale);
        await tester.pumpWidget(app);
        await settle(tester);
        final l = l10nOf(tester);
        expect(find.text(l.savedGamesEmptyTitle), findsOneWidget);
        expect(find.text(l.savedGamesEmptyStep1), findsOneWidget);
        expect(find.text(l.savedGamesEmptyStep2(savedGamesLinkExample)), findsOneWidget);
        expect(find.byKey(const ValueKey('savedGames.emptyAdd')), findsOneWidget);
        expect((await env.store.read()).games, isEmpty);
        // No network, no WebView until the user opens a game.
        expect(env.web.controllers, isEmpty);
        expect(env.fetcher.calls, isEmpty);
        expect(tester.takeException(), isNull);
      });

      testWidgets('add a game: https only, fetch title only on tap, saved to the store', (tester) async {
        usePhone(tester);
        final (app, env) = buildSavedGamesApp(home: const SavedGamesScreen(), locale: locale);
        await tester.pumpWidget(app);
        await settle(tester);
        final l = l10nOf(tester);
        await tester.tap(find.byKey(const ValueKey('savedGames.emptyAdd')));
        await settle(tester);
        expect(find.text(l.savedGamesAddTitle), findsOneWidget);

        // javascript: is refused.
        await tester.enterText(find.byKey(const ValueKey('savedGames.url')), 'javascript:alert(1)');
        await tester.tap(find.byKey(const ValueKey('savedGames.save')));
        await settle(tester);
        expect(find.text(l.savedGamesUrlScheme), findsOneWidget);

        // http is refused with a one-tap fix.
        await tester.enterText(find.byKey(const ValueKey('savedGames.url')), 'http://games.example.org/tiles');
        await tester.tap(find.byKey(const ValueKey('savedGames.save')));
        await settle(tester);
        expect(find.text(l.savedGamesUrlNotHttps), findsOneWidget);
        await tester.ensureVisible(find.text(l.savedGamesUseHttps));
        await tester.tap(find.text(l.savedGamesUseHttps));
        await settle(tester);
        expect(find.text('https://games.example.org/tiles'), findsOneWidget);
        expect(find.text(l.savedGamesSecureBadge), findsOneWidget);

        // Nothing was fetched until now; "Fetch title" asks the fake.
        expect(env.fetcher.calls, isEmpty);
        await tester.ensureVisible(find.text(l.savedGamesFetchTitle));
        await tester.tap(find.text(l.savedGamesFetchTitle));
        await settle(tester);
        expect(env.fetcher.calls, ['title:https://games.example.org/tiles']);
        expect(find.widgetWithText(TextField, 'Starlit Tiles'), findsOneWidget);

        await tester.ensureVisible(find.text(l.savedGamesOrientationLandscape));
        await settle(tester);
        await tester.tap(find.text(l.savedGamesOrientationLandscape));
        await tester.ensureVisible(find.byKey(const ValueKey('savedGames.notes')));
        await tester.enterText(find.byKey(const ValueKey('savedGames.notes')), 'Shared by a friend');
        await tester.tap(find.byKey(const ValueKey('savedGames.save')));
        await settle(tester);

        final games = (await env.store.read()).games;
        expect(games, hasLength(1));
        expect(games.single.url.toString(), 'https://games.example.org/tiles');
        expect(games.single.title, 'Starlit Tiles');
        expect(games.single.orientation, GameOrientation.landscape);
        expect(games.single.notes, 'Shared by a friend');
        expect(games.single.art.favicon, isNull, reason: 'site icon only after an explicit tap');
        await settle(tester);
        expect(find.text('Starlit Tiles'), findsWidgets);
        expect(tester.takeException(), isNull);
      });

      testWidgets('shared text pre-fills the link; a duplicate link is refused', (tester) async {
        usePhone(tester);
        final (app, env) = buildSavedGamesApp(
          home: const SavedGamesScreen(
            initialSharedText: 'Play this! https://claude.ai/public/artifacts/0f1e2d3c-4b5a-6978-8899-aabbccddeeff',
          ),
          locale: locale,
          games: sampleGames(),
        );
        await tester.pumpWidget(app);
        await settle(tester);
        final l = l10nOf(tester);
        expect(find.text('https://claude.ai/public/artifacts/0f1e2d3c-4b5a-6978-8899-aabbccddeeff'), findsOneWidget);
        expect(find.text(l.savedGamesUrlDuplicate(BidiIsolate.isolate('Double Feature'))), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('savedGames.save')));
        await settle(tester);
        expect((await env.store.read()).games, hasLength(3));
      });

      testWidgets('grid shows posters; list view has drag handles; long-press delete has undo', (tester) async {
        usePhone(tester);
        final (app, env) = buildSavedGamesApp(home: const SavedGamesScreen(), locale: locale, games: sampleGames());
        await tester.pumpWidget(app);
        await settle(tester);
        final l = l10nOf(tester);
        expect(find.text('Double Feature'), findsOneWidget);
        expect(find.text('Orbit Puzzle'), findsOneWidget);
        expect(find.text(l.savedGamesNew), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('savedGames.layout')));
        await settle(tester);
        expect((await env.store.read()).layout, SavedGamesLayout.list);
        expect(find.byType(ReorderableListView), findsOneWidget);
        expect(find.text(l.savedGamesReorderHint), findsOneWidget);

        await tester.longPress(find.byKey(const ValueKey('savedGames.row.g2')));
        await settle(tester);
        await tester.tap(find.text(l.actionDelete).last);
        await settle(tester);
        expect((await env.store.read()).games.map((g) => g.id), ['g1', 'g3']);
        await tester.tap(find.text(l.actionUndo).last);
        await settle(tester);
        expect((await env.store.read()).games.map((g) => g.id), ['g1', 'g2', 'g3']);
        await tester.pump(const Duration(seconds: 6));
        await settle(tester);
      });

      testWidgets('edit via long-press; the site icon is fetched only on tap', (tester) async {
        usePhone(tester);
        final (app, env) = buildSavedGamesApp(home: const SavedGamesScreen(), locale: locale, games: sampleGames());
        env.fetcher.icon = _onePixelPng;
        await tester.pumpWidget(app);
        await settle(tester);
        final l = l10nOf(tester);
        await tester.longPress(find.byKey(const ValueKey('savedGames.poster.g2')));
        await settle(tester);
        await tester.tap(find.text(l.actionEdit).last);
        await settle(tester);
        expect(find.text(l.savedGamesEditTitle), findsOneWidget);
        expect(env.fetcher.calls, isEmpty);
        await tester.enterText(find.byKey(const ValueKey('savedGames.title')), 'Orbit Puzzle II');
        await tester.ensureVisible(find.text(l.savedGamesUseSiteIcon));
        await settle(tester);
        await tester.tap(find.text(l.savedGamesUseSiteIcon));
        await settle(tester);
        expect(env.fetcher.calls, ['icon:https://games.example.org/orbit/']);
        await tester.tap(find.byKey(const ValueKey('savedGames.save')));
        await settle(tester);
        final g = (await env.store.read()).byId('g2')!;
        expect(g.title, 'Orbit Puzzle II');
        expect(g.art.favicon, _onePixelPng);
        expect(g.url.toString(), 'https://games.example.org/orbit/');
        expect(env.fetcher.calls, hasLength(1), reason: 'saving goes offline');
      });

      testWidgets('clear site data of one game is asked, then scheduled for its next open', (tester) async {
        usePhone(tester);
        final (app, env) = buildSavedGamesApp(home: const SavedGamesScreen(), locale: locale, games: sampleGames());
        await tester.pumpWidget(app);
        await settle(tester);
        final l = l10nOf(tester);
        await tester.longPress(find.byKey(const ValueKey('savedGames.poster.g1')));
        await settle(tester);
        await tester.tap(find.text(l.savedGamesClearData).last);
        await settle(tester);
        expect(find.text(l.savedGamesClearDataTitle(BidiIsolate.isolate('Double Feature'))), findsOneWidget);
        await tester.tap(find.text(l.savedGamesConfirmClear));
        await settle(tester);
        expect((await env.store.read()).byId('g1')!.clearDataPending, isTrue);
        expect(env.web.controllers, isEmpty, reason: 'nothing is loaded until the game opens');
      });

      testWidgets('clear data of all games asks first', (tester) async {
        usePhone(tester);
        final (app, env) = buildSavedGamesApp(home: const SavedGamesScreen(), locale: locale, games: sampleGames());
        await tester.pumpWidget(app);
        await settle(tester);
        final l = l10nOf(tester);
        await tester.tap(find.byKey(const ValueKey('savedGames.clearAll')));
        await settle(tester);
        expect(find.text(l.savedGamesClearAllTitle), findsOneWidget);
        expect(env.cleaner.calls, 0);
        await tester.tap(find.text(l.savedGamesConfirmClear));
        await settle(tester);
        expect(env.cleaner.calls, 1);
        expect((await env.store.read()).games, hasLength(3), reason: 'the list itself is kept');
      });
    });

    group('SavedGamesShelf (${locale.languageCode})', () {
      testWidgets('empty shelf invites to add; full shelf shows posters and an add card', (tester) async {
        usePhone(tester);
        final (app, _) = buildSavedGamesApp(
          home: const Scaffold(body: SafeArea(child: SavedGamesShelf())),
          locale: locale,
        );
        await tester.pumpWidget(app);
        await settle(tester);
        final l = l10nOf(tester);
        expect(find.byKey(const ValueKey('savedGames.shelfEmpty')), findsOneWidget);
        expect(find.text(l.savedGamesShelfEmpty), findsOneWidget);

        final (app2, _) = buildSavedGamesApp(
          home: const Scaffold(body: SafeArea(child: SavedGamesShelf())),
          locale: locale,
          games: sampleGames(),
        );
        await tester.pumpWidget(app2);
        await settle(tester);
        expect(find.byKey(const ValueKey('savedGames.shelf.g1')), findsOneWidget);
        // The Add card follows the posters (built, scrolled out of view).
        expect(find.byKey(const ValueKey('savedGames.shelfAdd'), skipOffstage: false), findsOneWidget);
        expect(find.text(l.savedGamesSeeAll), findsOneWidget);
      });

      testWidgets('tapping a poster opens the full-screen player', (tester) async {
        usePhone(tester);
        final (app, env) = buildSavedGamesApp(
          home: const Scaffold(body: SafeArea(child: SavedGamesShelf())),
          locale: locale,
          games: sampleGames(),
        );
        await tester.pumpWidget(app);
        await settle(tester);
        await tester.tap(find.byKey(const ValueKey('savedGames.shelf.g1')));
        await settle(tester);
        expect(find.byType(SavedGamePlayerScreen), findsOneWidget);
        expect(env.session.calls.first, 'enter:landscape');
        expect(env.web.last.loads, ['https://claude.ai/public/artifacts/0f1e2d3c-4b5a-6978-8899-aabbccddeeff']);
        expect((await env.store.read()).byId('g1')!.playCount, 8);
      });
    });

    group('SavedGamePlayerScreen (${locale.languageCode})', () {
      Future<SavedGamesEnv> openPlayer(WidgetTester tester, {SavedWebGame? game}) async {
        usePhone(tester);
        final g = game ?? sampleGames()[0];
        final (app, env) = buildSavedGamesApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).push(SavedGamePlayerScreen.route(g)),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
          locale: locale,
          games: sampleGames(),
        );
        await tester.pumpWidget(app);
        await settle(tester);
        await tester.tap(find.text('open'));
        await settle(tester);
        return env;
      }

      testWidgets('loading veil, then the game; controls: mute, reload, open in browser', (tester) async {
        final env = await openPlayer(tester);
        final l = l10nOf(tester);
        expect(find.text(l.savedGamesLoading(BidiIsolate.isolate('Double Feature'))), findsOneWidget);
        final web = env.web.last;
        expect(web.channels, isEmpty);
        web.pageFinished(web.loads.single);
        await settle(tester);
        expect(find.text(l.savedGamesLoading(BidiIsolate.isolate('Double Feature'))), findsNothing);

        await tester.tap(find.byKey(const ValueKey('savedGames.control')));
        await settle(tester);
        await tester.tap(find.bySemanticsLabel(l.savedGamesMute));
        await settle(tester);
        expect(web.scripts, contains(GameScripts.hush(pause: false, hide: false)));

        await tester.tap(find.byKey(const ValueKey('savedGames.control')));
        await settle(tester);
        await tester.tap(find.bySemanticsLabel(l.savedGamesReload));
        await settle(tester);
        expect(web.reloads, 1);

        await tester.tap(find.byKey(const ValueKey('savedGames.control')));
        await settle(tester);
        await tester.tap(find.bySemanticsLabel(l.savedGamesOpenExternal));
        await settle(tester);
        expect(env.opener.opened.single.host, 'claude.ai');
      });

      testWidgets('Android back asks before leaving; leaving restores the system UI', (tester) async {
        final env = await openPlayer(tester);
        final l = l10nOf(tester);
        env.web.last.pageFinished(env.web.last.loads.single);
        await settle(tester);
        await tester.binding.handlePopRoute();
        await settle(tester);
        expect(find.text(l.savedGamesExitTitle), findsOneWidget);
        expect(find.byType(SavedGamePlayerScreen), findsOneWidget);
        await tester.tap(find.text(l.savedGamesExitStay));
        await settle(tester);
        expect(find.byType(SavedGamePlayerScreen), findsOneWidget);

        await tester.binding.handlePopRoute();
        await settle(tester);
        await tester.tap(find.text(l.savedGamesExitLeave));
        await settle(tester);
        expect(find.byType(SavedGamePlayerScreen), findsNothing);
        expect(env.session.calls, containsAllInOrder(['enter:landscape', 'exit']));
      });

      testWidgets('outside links ask, then open in the browser', (tester) async {
        final env = await openPlayer(tester);
        final l = l10nOf(tester);
        final web = env.web.last;
        web.pageFinished(web.loads.single);
        await settle(tester);
        unawaited(Future.value(web.navigate('https://www.anthropic.com/news')));
        await settle(tester);
        expect(find.text(l.savedGamesExternalTitle), findsOneWidget);
        await tester.tap(find.text(l.savedGamesOpenExternal).last);
        await settle(tester);
        expect(env.opener.opened.single.toString(), 'https://www.anthropic.com/news');
      });

      testWidgets('the adhan / prayer mute covers and silences the game, then lifts', (tester) async {
        final env = await openPlayer(tester);
        final l = l10nOf(tester);
        final web = env.web.last
          ..result = (s) => s == GameScripts.trackAudio
              ? '"{\\"early\\":true}"'
              : (s.contains('sealed') ? '"{\\"sealed\\":0,\\"blind\\":false}"' : '""');
        web
          ..pageStarted(web.loads.single)
          ..pageFinished(web.loads.single);
        await settle(tester);
        final container = ProviderScope.containerOf(tester.element(find.byType(SavedGamePlayerScreen)));
        final lease = container.read(prayerMuteProvider).acquire('test adhan');
        await settle(tester);
        expect(find.text(l.savedGamesPrayerTitle), findsOneWidget);
        expect(env.sound.prayerMuted, isTrue);
        expect(web.scripts, contains(GameScripts.hush(pause: true, hide: true)));
        lease.release();
        await settle(tester);
        expect(find.text(l.savedGamesPrayerTitle), findsNothing);
        expect(web.scripts.last, GameScripts.unhush);
      });

      testWidgets('offline shows a retry', (tester) async {
        final env = await openPlayer(tester);
        final l = l10nOf(tester);
        env.web.last.error(WebResourceErrorType.hostLookup);
        await settle(tester);
        expect(find.text(l.savedGamesOfflineTitle), findsOneWidget);
        await tester.tap(find.text(l.savedGamesRetry));
        await settle(tester);
        expect(env.web.last.loads, hasLength(2));
        expect(find.text(l.savedGamesLoading(BidiIsolate.isolate('Double Feature'))), findsOneWidget);
      });
    });
  }

  testWidgets('system chrome: immersive + orientation on enter, portrait edge-to-edge on exit', (tester) async {
    final calls = <MethodCall>[];
    final host = <MethodCall>[];
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      calls.add(call);
      return null;
    });
    messenger.setMockMethodCallHandler(savedGamesHostChannel, (call) async {
      host.add(call);
      return null;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(SystemChannels.platform, null);
      messenger.setMockMethodCallHandler(savedGamesHostChannel, null);
    });
    const platform = SystemGameSessionPlatform();
    await platform.enter(GameOrientation.landscape);
    await platform.exit();
    final methods = calls.map((c) => c.method).toList();
    expect(methods, contains('SystemChrome.setEnabledSystemUIMode'));
    expect(methods, contains('SystemChrome.setPreferredOrientations'));
    final orientations = calls.where((c) => c.method == 'SystemChrome.setPreferredOrientations').toList();
    expect(orientations.first.arguments, ['DeviceOrientation.landscapeLeft', 'DeviceOrientation.landscapeRight']);
    expect(orientations.last.arguments, ['DeviceOrientation.portraitUp']);
    expect(host.map((c) => '${c.method}:${c.arguments}'), ['keepScreenOn:{on: true}', 'keepScreenOn:{on: false}']);
    // The host's optional pause hook: false when not answered.
    expect(await platform.pauseWebView(7), isFalse);
  });
}

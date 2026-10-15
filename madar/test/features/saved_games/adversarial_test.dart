// Adversarial review of Saved Games: each test pins one way a link, a page,
// the system or a hurried user could get around what the feature promises
// (only the saved https origin runs inside Madar, nothing sounds during
// prayer, the phone is always given back as it was, nothing goes online
// before a tap, the controls work with TalkBack).
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/features/saved_games/domain/game_url.dart' show displayHost, punycodeDecode, punycodeEncode;
import 'package:madar/features/saved_games/player/game_player_controller.dart';
import 'package:madar/features/saved_games/player/game_scripts.dart';
import 'package:madar/features/saved_games/saved_games.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'saved_games_fakes.dart';

const String home = 'https://claude.ai/public/artifacts/abc';

/// Android-style results of Madar's scripts.
const String trackedEarly = '"{\\"early\\":true}"';
const String reachAll = '"{\\"sealed\\":0,\\"blind\\":false,\\"media\\":1,\\"ctx\\":1}"';
const String reachBlind = '"{\\"sealed\\":0,\\"blind\\":true,\\"media\\":0,\\"ctx\\":0}"';

class _Dialogs implements GamePageDialogs {
  final List<String> shown = [];

  @override
  Future<void> alert(String host, String message) async => shown.add('alert:$message');

  @override
  Future<bool> confirm(String host, String message) async {
    shown.add('confirm:$message');
    return true;
  }

  @override
  Future<String?> prompt(String host, String message, String? defaultText) async {
    shown.add('prompt:$message');
    return 'x';
  }
}

/// Stands in for the test binding's network block: records every client.
class _RecordingHttp extends HttpOverrides {
  int clients = 0;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    clients++;
    return _OfflineClient();
  }
}

class _OfflineClient implements HttpClient {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #getUrl || invocation.memberName == #openUrl) {
      throw const SocketException('offline (test)');
    }
    return null;
  }
}

L10n _l10n(WidgetTester tester) => L10n.of(tester.element(find.byType(Scaffold).first));

Future<void> _settle(WidgetTester tester) => frames(tester, 20);

void main() {
  group('links', () {
    GameUrlError? err(String s) => validateGameUrl(s).error;
    String? host(String s) => validateGameUrl(s).url?.host;

    test('scheme tricks (case, spaces, invisible and full-width characters) never pass', () {
      for (final s in [
        'JAVASCRIPT:alert(1)',
        ' \tjavascript:alert(1)',
        'java\tscript:alert(1)',
        'java\nscript:alert(1)',
        '​javascript:alert(1)',
        '﻿javascript:alert(1)',
        'ｊａｖａｓｃｒｉｐｔ:alert(1)',
        'INTENT://scan#Intent;scheme=https;package=com.evil;end',
        'intent:#Intent;action=android.intent.action.VIEW;end',
        'Data:text/html,<script>alert(1)</script>',
        'FILE:///sdcard/Download/x.html',
        'CONTENT://com.android.providers.downloads/1',
        'android-app://com.evil/https/claude.ai',
        'https:/\\evil.example',
        'https:\\\\evil.example',
      ]) {
        expect(validateGameUrl(s).isValid, isFalse, reason: s);
      }
    });

    test('userinfo, backslash and encoding tricks cannot hide the real host', () {
      expect(err('https://claude.ai@evil.example/'), GameUrlError.credentials);
      expect(err('HTTPS://CLAUDE.AI@EVIL.EXAMPLE/'), GameUrlError.credentials);
      expect(err('https://claude.ai:443@evil.example/'), GameUrlError.credentials);
      expect(err('https://claude.ai\\@evil.example/'), GameUrlError.credentials);
      expect(err('https://evil.example\\@claude.ai/'), GameUrlError.credentials);
      expect(err('https://claude.ai%40evil.example/'), GameUrlError.malformed);
      // What is stored (and shown) is what loads: a backslash, '#' or '?'
      // ends the host exactly as it does in the browser.
      expect(host('https://evil.example\\.claude.ai/'), 'evil.example');
      expect(host('https://evil.example#@claude.ai'), 'evil.example');
      expect(host('https://evil.example?@claude.ai'), 'evil.example');
      expect(host('https://%63laude.ai/'), 'claude.ai');
      // Shared text after a line break is not part of the link.
      expect(host('https://claude.ai\r\n.evil.example/'), 'claude.ai');
    });

    test('look-alike and invisible characters in a host are refused; punycode stays punycode', () {
      for (final s in [
        'https://сlaude.ai/public/artifacts/x', // Cyrillic "с"
        'https://ｃｌａｕｄｅ.ai/',
        'https://claude。ai/',
        'https://claude.ai​.evil.example/',
        'https://claude­ai.example/',
        'https://claude.ai./x',
        'https://сlaudе.аi/',
      ]) {
        expect(validateGameUrl(s).isValid, isFalse, reason: s);
      }
      final lookAlike = validateGameUrl('https://xn--laude-0ye.ai/public/artifacts/x').url!;
      expect(lookAlike.host, 'xn--laude-0ye.ai');
      expect(isClaudeArtifactUrl(lookAlike), isFalse);
    });

    test('an Arabic domain name is a valid link (stored as punycode)', () {
      expect(host('https://مثال.السعودية/لعبة'), 'xn--mgbh0fb.xn--mgberp4a5d4ar');
      expect(host('موقع.مصر'), 'xn--4gbrim.xn--wgbh1c');
      expect(host('https://ألعاب.example.com/'), 'xn--igbid0esc.example.com');
      // Arabic mixed with Latin letters in one label, tatweel and harakat:
      // not a registrable name.
      for (final s in ['https://claudeمثال.com/', 'https://مـثال.com/', 'https://مَثال.com/']) {
        expect(err(s), GameUrlError.malformed, reason: s);
      }
    });

    test('an Arabic domain is shown in Arabic; any other punycode stays punycode', () {
      expect(punycodeEncode('مثال'), 'mgbh0fb');
      expect(punycodeDecode('mgberp4a5d4ar'), 'السعودية');
      expect(punycodeEncode('bücher'), 'bcher-kva');
      expect(punycodeDecode('bcher-kva'), 'bücher');
      expect(punycodeDecode('bcher-kv!'), isNull);
      expect(displayHost(Uri.parse('https://xn--mgbh0fb.xn--mgberp4a5d4ar/x')), 'مثال.السعودية');
      expect(displayHost(Uri.parse('https://xn--igbid0esc.example.com/')), 'ألعاب.example.com');
      // Look-alikes of Latin names, mixed scripts: never rendered.
      expect(displayHost(Uri.parse('https://xn--laude-0ye.ai/')), 'xn--laude-0ye.ai');
      expect(displayHost(Uri.parse('https://xn--bcher-kva.example/')), 'xn--bcher-kva.example');
      expect(displayHost(Uri.parse('https://xn--mgbh0fb.xn--laude-0ye.ai/')), 'xn--mgbh0fb.xn--laude-0ye.ai');
      final game = SavedWebGame(
        id: 'a',
        title: 't',
        url: validateGameUrl('https://مثال.السعودية/').url!,
        art: const GameArt(glyph: 0, hue: 0),
        addedAt: DateTime(2026),
      );
      expect(game.host, 'مثال.السعودية');
      expect(game.url.toString(), 'https://xn--mgbh0fb.xn--mgberp4a5d4ar/');
    });

    test('the phone itself is not a game host (like localhost)', () {
      for (final s in ['https://127.0.0.1/', 'https://127.8.9.10:8443/x', 'https://0.0.0.0/', 'https://localhost/']) {
        expect(err(s), GameUrlError.malformed, reason: s);
      }
      expect(host('https://192.168.1.20/game'), '192.168.1.20');
    });
  });

  group('navigation from a running page (URLs as the WebView reports them)', () {
    final origins = GameOrigins(Uri.parse(home));
    NavigationVerdict nav(String url) => decideGameNavigation(origins: origins, target: url, isMainFrame: true);

    test('only the saved https origin loads inside; the rest asks or is blocked', () {
      expect(nav('HTTPS://CLAUDE.AI/public/artifacts/other'), NavigationVerdict.allow);
      expect(nav('https://claude.ai@evil.example/'), NavigationVerdict.block);
      expect(nav('https://evil.example/@claude.ai/'), NavigationVerdict.askExternal);
      expect(nav('https://claude.ai.evil.example/'), NavigationVerdict.askExternal);
      expect(nav('https://claude.ai./'), NavigationVerdict.askExternal);
      expect(nav('http://claude.ai/public/artifacts/abc'), NavigationVerdict.askExternal);
      for (final s in [
        'INTENT://x#Intent;scheme=https;package=com.evil;end',
        'intent:#Intent;action=android.intent.action.VIEW;end',
        'android-app://com.evil/https/x',
        'market://details?id=com.evil',
        'chrome://settings',
        'JavaScript:alert(1)',
        'data:text/html,<script>1</script>',
        'blob:https://claude.ai/uuid',
        'file:///sdcard/x',
        'content://x/y',
        'ws://claude.ai/',
      ]) {
        expect(nav(s), NavigationVerdict.block, reason: s);
      }
    });
  });

  group('player controller', () {
    late FakeWebViewPlatform platform;
    late FakeSessionPlatform session;
    late _Dialogs dialogs;
    late List<Uri> external;
    late int cleared;

    GamePlayerController make({DateTime Function()? now}) => GamePlayerController(
      game: SavedWebGame(
        id: 'g1',
        title: 'Double Feature',
        url: Uri.parse(home),
        art: const GameArt(glyph: 0, hue: 0),
        addedAt: DateTime(2026, 9, 1),
      ),
      dialogs: dialogs,
      platform: session,
      // The user says "no" every time.
      onExternalRequest: (u) async => external.add(u),
      onCleared: () async => cleared++,
      now: now,
    );

    setUp(() {
      platform = FakeWebViewPlatform();
      WebViewPlatform.instance = platform;
      session = FakeSessionPlatform();
      dialogs = _Dialogs();
      external = [];
      cleared = 0;
    });

    testWidgets('window.open / target=_blank loops cannot trap the user in "open outside?" questions', (
      tester,
    ) async {
      final c = make(now: () => tester.binding.clock.now());
      await c.start();
      final web = platform.last;
      web.pageFinished(home);
      await tester.pump();
      for (var i = 0; i < 8; i++) {
        expect(await web.navigate('https://ads.example/$i'), NavigationDecision.prevent);
        await tester.pump(const Duration(milliseconds: 300));
      }
      expect(external.length, lessThanOrEqualTo(3));
      // The same guard covers the page's own dialogs.
      await web.onAlert!(const JavaScriptAlertDialogRequest(message: 'still here?', url: home));
      expect(dialogs.shown, isEmpty);
      // After a quiet spell the page may ask again (a real link tap).
      await tester.pump(const Duration(seconds: 40));
      await web.navigate('https://ads.example/later');
      expect(external.last.toString(), 'https://ads.example/later');
      c.dispose();
    });

    testWidgets('nothing from the page pops up over the prayer screen', (tester) async {
      final c = make();
      await c.start();
      final web = platform.last
        ..result = (s) => s == GameScripts.trackAudio ? trackedEarly : (s.contains('sealed') ? reachAll : '""');
      web
        ..pageStarted(home)
        ..pageFinished(home);
      await tester.pump();
      await c.setPrayerMuted(true);
      expect(c.phase, GamePhase.ready, reason: 'hushed in place');
      await web.onAlert!(const JavaScriptAlertDialogRequest(message: 'hi', url: home));
      expect(await web.onConfirm!(const JavaScriptConfirmDialogRequest(message: 'sure?', url: home)), isFalse);
      expect(await web.navigate('https://ads.example/'), NavigationDecision.prevent);
      expect(dialogs.shown, isEmpty);
      expect(external, isEmpty);
      c.dispose();
    });

    testWidgets('prayer: sound Madar cannot account for unloads the page', (tester) async {
      // The tracker only reached the page after its scripts ran (e.g. Web
      // Audio started at load): the hush cannot vouch for silence.
      final c = make();
      await c.start();
      final web = platform.last..result = (s) => s.contains('sealed') ? reachBlind : '""';
      web
        ..pageStarted(home)
        ..pageFinished(home);
      await tester.pump();
      await c.setPrayerMuted(true);
      expect(c.phase, GamePhase.resting);
      expect(web.htmlLoads.last.$1, GameScripts.restPage);
      c.dispose();
    });

    testWidgets('prayer: a page that claims full reach is not trusted unless tracked from its first script', (
      tester,
    ) async {
      final c = make();
      await c.start();
      // The page-start install did not report an early start.
      final web = platform.last..result = (s) => s.contains('sealed') ? reachAll : '""';
      web
        ..pageStarted(home)
        ..pageFinished(home);
      await tester.pump();
      await c.setPrayerMuted(true);
      expect(c.phase, GamePhase.resting);
      c.dispose();
    });

    testWidgets('the audio tracker is installed when a page starts, not only when it has finished', (tester) async {
      final c = make();
      await c.start();
      final web = platform.last..result = (s) => s == GameScripts.trackAudio ? trackedEarly : '""';
      web.pageStarted(home);
      await tester.pump();
      expect(web.scripts, contains(GameScripts.trackAudio));
      c.dispose();
    });

    testWidgets('a clear interrupted by prayer is finished after prayer, not dropped', (tester) async {
      final c = make();
      await c.start();
      final web = platform.last..result = (s) => s == GameScripts.clearedProbe ? '"done"' : '""';
      web.pageFinished(home);
      await tester.pump();
      await c.clearSiteData(); // from the player's menu
      expect(c.phase, GamePhase.clearing);
      await c.setPrayerMuted(true);
      expect(c.phase, GamePhase.resting);
      await c.setPrayerMuted(false);
      expect(c.phase, GamePhase.clearing);
      expect(web.htmlLoads.last.$1, GameScripts.clearSiteDataPage);
      web.pageFinished('https://claude.ai/');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(cleared, 1);
      expect(web.loads.last, home);
      c.dispose();
    });
  });

  test('leaving while entering still ends in Madar\'s own chrome and lets the screen sleep', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final log = <String>[];
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    Future<Object?> slow(MethodCall call) async {
      await Future<void>.delayed(const Duration(milliseconds: 5));
      log.add('${call.method}|${call.arguments}');
      return null;
    }

    messenger
      ..setMockMethodCallHandler(SystemChannels.platform, slow)
      ..setMockMethodCallHandler(savedGamesHostChannel, slow);
    addTearDown(() {
      messenger
        ..setMockMethodCallHandler(SystemChannels.platform, null)
        ..setMockMethodCallHandler(savedGamesHostChannel, null);
    });
    const p = SystemGameSessionPlatform();
    unawaited(p.enter(GameOrientation.landscape));
    await p.exit();
    await Future<void>.delayed(const Duration(milliseconds: 80));
    final last = <String, String>{};
    for (final e in log) {
      last[e.split('|').first] = e;
    }
    expect(last['keepScreenOn'], 'keepScreenOn|{on: false}');
    expect(last['SystemChrome.setPreferredOrientations'], contains('portraitUp'));
    expect(last['SystemChrome.setEnabledSystemUIMode'], contains('edgeToEdge'));
  });

  group('player screen', () {
    Future<SavedGamesEnv> openPlayer(WidgetTester tester, {Widget Function(Widget child)? wrap}) async {
      usePhone(tester);
      final (app, env) = buildSavedGamesApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(SavedGamePlayerScreen.route(sampleGames()[0])),
                child: const Text('open'),
              ),
            ),
          ),
        ),
        games: sampleGames(),
      );
      await tester.pumpWidget(wrap == null ? app : wrap(app));
      await _settle(tester);
      await tester.tap(find.text('open'));
      await _settle(tester);
      env.web.last.pageFinished(env.web.last.loads.single);
      await _settle(tester);
      return env;
    }

    Future<void> lifecycle(WidgetTester tester, List<AppLifecycleState> states) async {
      for (final s in states) {
        tester.binding.handleAppLifecycleStateChanged(s);
        await tester.pump();
      }
    }

    testWidgets('a page pushed over the game gets Madar\'s normal screen; the game\'s comes back after', (
      tester,
    ) async {
      final env = await openPlayer(tester);
      final l = _l10n(tester);
      env.session.calls.clear();
      final nav = Navigator.of(tester.element(find.byType(SavedGamePlayerScreen)));
      unawaited(nav.push(MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('over')))));
      await _settle(tester);
      expect(env.session.calls, ['exit']);
      // Returning to Madar while covered must not hide the bars again.
      await lifecycle(tester, [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]);
      expect(env.session.calls, isNot(contains('reassert')));
      nav.pop();
      await _settle(tester);
      expect(env.session.calls.last, 'enter:landscape');
      // A sheet over the game (the leave question) keeps the game's screen.
      env.session.calls.clear();
      await tester.binding.handlePopRoute();
      await _settle(tester);
      expect(find.text(l.savedGamesExitTitle), findsOneWidget);
      expect(env.session.calls, isEmpty);
    });

    testWidgets('the adhan shown over the app gives the phone back its normal screen while it plays', (
      tester,
    ) async {
      // AdhanHost covers the whole app (above the router) and stops its
      // tickers while the adhan shows.
      final covered = ValueNotifier(false);
      addTearDown(covered.dispose);
      final env = await openPlayer(
        tester,
        wrap: (app) => ValueListenableBuilder<bool>(
          valueListenable: covered,
          builder: (context, on, child) => TickerMode(enabled: !on, child: child!),
          child: app,
        ),
      );
      env.session.calls.clear();
      covered.value = true;
      await _settle(tester);
      expect(env.session.calls, ['exit']);
      covered.value = false;
      await _settle(tester);
      expect(env.session.calls, ['exit', 'enter:landscape']);
    });

    testWidgets('TalkBack: the control tray stays open while it is being explored; one label per button', (
      tester,
    ) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
        accessibleNavigation: true,
      );
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      final semantics = tester.ensureSemantics();
      await openPlayer(tester);
      final l = _l10n(tester);
      await tester.tap(find.byKey(const ValueKey('savedGames.control')));
      await _settle(tester);
      await tester.pump(const Duration(seconds: 10));
      await _settle(tester);
      for (final label in [
        l.savedGamesBackToMadar,
        l.savedGamesReload,
        l.savedGamesMute,
        l.savedGamesOpenExternal,
        l.savedGamesClearData,
      ]) {
        final finder = find.bySemanticsLabel(label);
        expect(finder, findsOneWidget, reason: label);
        final node = tester.getSemantics(finder);
        expect(node.label, label);
        expect(node.tooltip, isEmpty, reason: 'TalkBack would read "$label" twice');
        expect(node.getSemanticsData().flagsCollection.isButton, isTrue);
      }
      final handle = tester.getSemantics(find.bySemanticsLabel(l.savedGamesCloseControls));
      expect(handle.getSemanticsData().flagsCollection.isButton, isTrue);
      semantics.dispose();
    });
  });

  testWidgets('two quick taps on a poster open one player (one WebView, one play counted)', (tester) async {
    usePhone(tester);
    final (app, env) = buildSavedGamesApp(
      home: const Scaffold(body: SafeArea(child: SavedGamesShelf())),
      games: sampleGames(),
    );
    await tester.pumpWidget(app);
    await _settle(tester);
    final poster = find.byKey(const ValueKey('savedGames.shelf.g1'));
    final at = tester.getCenter(poster);
    await tester.tapAt(at);
    await tester.pump(const Duration(milliseconds: 16));
    await tester.tapAt(at);
    await _settle(tester);
    expect(find.byType(SavedGamePlayerScreen), findsOneWidget);
    expect(env.web.controllers, hasLength(1));
    expect((await env.store.read()).byId('g1')!.playCount, 8);
  });

  testWidgets('nothing goes online while games, the shelf and the add sheet are shown – only a tap on Fetch', (
    tester,
  ) async {
    final previous = HttpOverrides.current;
    final http = _RecordingHttp();
    HttpOverrides.global = http;
    addTearDown(() => HttpOverrides.global = previous);
    usePhone(tester);
    final games = [
      for (final g in sampleGames()) g.copyWith(art: g.art.copyWith(favicon: _pixel)),
    ];
    final (app, env) = buildSavedGamesApp(
      home: const SavedGamesScreen(initialSharedText: 'Play https://games.example.org/tiles !'),
      games: games,
      metaFetcher: HttpGameMetaFetcher(),
    );
    await tester.pumpWidget(app);
    await _settle(tester);
    expect(find.byKey(const ValueKey('savedGames.url')), findsOneWidget, reason: 'the add sheet is open');
    expect(http.clients, 0);
    await tester.tap(find.text(_l10n(tester).savedGamesFetchTitle));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await _settle(tester);
    expect(http.clients, greaterThan(0));
    expect(env.fetcher.calls, isEmpty);
  });
}

final Uint8List _pixel = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, //
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
  0x89, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0xDA, 0x63, 0xF8, 0xCF, 0xC0, 0xF0,
  0x1F, 0x00, 0x05, 0x00, 0x01, 0xFF, 0x89, 0x99, 0x3D, 0x1D, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45,
  0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

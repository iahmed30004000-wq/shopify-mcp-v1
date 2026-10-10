// The native side of the player: a WebView whose renderer dies, the host
// channel, and the real Android WebView configuration (through the
// plugin's own pigeon test overrides – no device needed).
//
// ignore_for_file: implementation_imports, depend_on_referenced_packages

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/features/saved_games/player/android_hardening.dart';
import 'package:madar/features/saved_games/player/game_player_controller.dart';
import 'package:madar/features/saved_games/saved_games.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/src/android_webkit.g.dart' as android;
import 'package:webview_flutter_android/webview_flutter_android.dart';

import 'saved_games_fakes.dart';

const String home = 'https://claude.ai/public/artifacts/abc';

class _NoDialogs implements GamePageDialogs {
  @override
  Future<void> alert(String host, String message) async {}

  @override
  Future<bool> confirm(String host, String message) async => false;

  @override
  Future<String?> prompt(String host, String message, String? defaultText) async => null;
}

SavedWebGame _game() => SavedWebGame(
  id: 'g1',
  title: 'Double Feature',
  url: Uri.parse(home),
  art: const GameArt(glyph: 0, hue: 0),
  addedAt: DateTime(2026, 9, 1),
);

/// Gives every (fake) WebView a stable native id: 1, 2, …
void _numberWebViews() {
  final ids = Expando<int>();
  var next = 0;
  debugNativeWebViewId = (c) => ids[c] ??= ++next;
  addTearDown(() => debugNativeWebViewId = null);
}

String _name(Symbol s) => RegExp(r'Symbol\("(.*)"\)').firstMatch(s.toString())?.group(1) ?? '$s';

String _call(Invocation i) => '${_name(i.memberName)}(${i.positionalArguments.join(', ')})';

class _Settings implements android.WebSettings {
  _Settings(this.log);

  final List<String> log;

  @override
  dynamic noSuchMethod(Invocation i) {
    log.add('settings.${_call(i)}');
    return Future<void>.value();
  }
}

class _AndroidWebView implements android.WebView {
  _AndroidWebView(this.log) : settings = _Settings(log);

  final List<String> log;

  @override
  final android.WebSettings settings;

  @override
  Future<String?> evaluateJavascript(String javascriptString) async => null;

  @override
  Future<String?> getUrl() async => null;

  @override
  dynamic noSuchMethod(Invocation i) {
    log.add('webView.${_call(i)}');
    return Future<void>.value();
  }
}

class _Client implements android.WebViewClient {
  @override
  dynamic noSuchMethod(Invocation i) => Future<void>.value();
}

class _Chrome implements android.WebChromeClient {
  @override
  dynamic noSuchMethod(Invocation i) => Future<void>.value();
}

class _Downloads implements android.DownloadListener {
  @override
  dynamic noSuchMethod(Invocation i) => Future<void>.value();
}

class _Storage implements android.WebStorage {
  @override
  dynamic noSuchMethod(Invocation i) => Future<void>.value();
}

void main() {
  group('renderer gone', () {
    late FakeWebViewPlatform platform;
    late FakeSessionPlatform session;

    setUp(() {
      platform = FakeWebViewPlatform();
      WebViewPlatform.instance = platform;
      session = FakeSessionPlatform();
    });

    testWidgets('the crashed game is shown as such and a retry builds a fresh, hardened WebView', (tester) async {
      _numberWebViews();
      final c = GamePlayerController(
        game: _game(),
        dialogs: _NoDialogs(),
        platform: session,
        onExternalRequest: (_) async {},
      );
      await c.start();
      final first = c.web;
      final web1 = platform.last;
      expect(session.calls, contains('harden:1'));
      web1.pageFinished(home);
      await tester.pump();
      // Another WebView's renderer is none of this game's business.
      session.gone.add(99);
      await tester.pump();
      expect(c.phase, GamePhase.ready);
      session.gone.add(1);
      await tester.pump();
      expect(c.phase, GamePhase.crashed);
      expect(await web1.navigate('https://claude.ai/public/artifacts/next'), NavigationDecision.prevent);

      await c.retry();
      expect(c.webGeneration, 1);
      expect(identical(c.web, first), isFalse);
      final web2 = platform.last;
      expect(identical(web2, web1), isFalse);
      expect(web2.delegate, isNotNull, reason: 'configured like the first one');
      expect(web2.channels, isEmpty);
      expect(web2.loads, [home]);
      expect(session.calls, contains('harden:2'));
      expect(c.phase, GamePhase.loading);
      c.dispose();
    });

    testWidgets('player: the crash veil offers a retry, and leaving from it gives the phone back', (tester) async {
      _numberWebViews();
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
      await tester.pumpWidget(app);
      await frames(tester, 20);
      await tester.tap(find.text('open'));
      await frames(tester, 20);
      final l = L10n.of(tester.element(find.byType(SavedGamePlayerScreen)));
      env.web.last.pageFinished(env.web.last.loads.single);
      await frames(tester, 20);

      env.session.gone.add(1);
      await frames(tester, 20);
      expect(find.text(l.savedGamesCrashedTitle), findsOneWidget);
      await tester.tap(find.text(l.savedGamesRetry));
      await frames(tester, 20);
      expect(env.web.controllers, hasLength(2));
      expect(find.byKey(const ValueKey('savedGames.webView.1')), findsOneWidget);
      expect(find.text(l.savedGamesCrashedTitle), findsNothing);

      env.session.gone.add(2);
      await frames(tester, 20);
      await tester.tap(find.text(l.savedGamesBackToMadar));
      await frames(tester, 20);
      expect(find.byType(SavedGamePlayerScreen), findsNothing);
      expect(env.session.calls.last, 'exit');
    });
  });

  test('host channel: renderer-gone reports reach Dart; hardening is requested by id', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final sent = <String>[];
    messenger.setMockMethodCallHandler(savedGamesHostChannel, (call) async {
      sent.add('${call.method}:${call.arguments}');
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(savedGamesHostChannel, null));
    const p = SystemGameSessionPlatform();
    final got = <int>[];
    final sub = p.rendererGone.listen(got.add);
    addTearDown(sub.cancel);
    await messenger.handlePlatformMessage(
      savedGamesHostChannel.name,
      savedGamesHostChannel.codec.encodeMethodCall(const MethodCall('rendererGone', {'id': 7})),
      (_) {},
    );
    await Future<void>.delayed(Duration.zero);
    expect(got, [7]);
    await p.hardenWebView(7);
    expect(sent, ['hardenWebView:{id: 7}']);
  });

  testWidgets('Android: the player\'s WebView has no file, content or mixed-content access and no bridge', (
    tester,
  ) async {
    final log = <String>[];
    final view = _AndroidWebView(log);
    android.PigeonInstanceManager.instance.addHostCreatedInstance(view, 424242);
    android.PigeonOverrides.webView_new = ({dynamic onScrollChanged}) => view;
    android.PigeonOverrides.webViewClient_new =
        ({
          dynamic onPageStarted,
          dynamic onPageFinished,
          dynamic onReceivedHttpError,
          dynamic onReceivedRequestError,
          dynamic onReceivedRequestErrorCompat,
          dynamic requestLoading,
          dynamic urlLoading,
          dynamic doUpdateVisitedHistory,
          dynamic onReceivedHttpAuthRequest,
          dynamic onFormResubmission,
          dynamic onLoadResource,
          dynamic onPageCommitVisible,
          dynamic onReceivedClientCertRequest,
          dynamic onReceivedLoginRequest,
          dynamic onReceivedSslError,
          dynamic onScaleChanged,
        }) => _Client();
    android.PigeonOverrides.webChromeClient_new =
        ({
          dynamic onShowFileChooser,
          dynamic onJsConfirm,
          dynamic onProgressChanged,
          dynamic onPermissionRequest,
          dynamic onShowCustomView,
          dynamic onHideCustomView,
          dynamic onGeolocationPermissionsShowPrompt,
          dynamic onGeolocationPermissionsHidePrompt,
          dynamic onConsoleMessage,
          dynamic onJsAlert,
          dynamic onJsPrompt,
        }) => _Chrome();
    android.PigeonOverrides.downloadListener_new = ({dynamic onDownloadStart}) => _Downloads();
    android.PigeonOverrides.webStorage_instance = _Storage();
    addTearDown(android.PigeonOverrides.pigeon_reset);
    final previous = WebViewPlatform.instance;
    WebViewPlatform.instance = AndroidWebViewPlatform();
    addTearDown(() => WebViewPlatform.instance = previous);

    final session = FakeSessionPlatform();
    final c = GamePlayerController(
      game: _game(),
      dialogs: _NoDialogs(),
      platform: session,
      onExternalRequest: (_) async {},
    );
    await c.start();

    expect(
      log,
      containsAll([
        'settings.setAllowFileAccess(false)',
        'settings.setAllowContentAccess(false)',
        'settings.setGeolocationEnabled(false)',
        'settings.setMediaPlaybackRequiresUserGesture(true)',
        'settings.setMixedContentMode(MixedContentMode.neverAllow)',
        'settings.setJavaScriptEnabled(true)',
      ]),
    );
    expect(log.where((e) => e.startsWith('webView.addJavaScriptChannel')), isEmpty, reason: 'no bridge');
    expect(log, contains(startsWith('webView.loadUrl($home')));
    // The plugin itself turns popup windows on, with no Dart switch to
    // turn them off: the host is asked to (by the WebView's native id).
    expect(log, contains('settings.setSupportMultipleWindows(true)'));
    expect(log, contains('settings.setJavaScriptCanOpenWindowsAutomatically(true)'));
    expect(session.calls, contains('harden:424242'));
    c.dispose();
  });
}

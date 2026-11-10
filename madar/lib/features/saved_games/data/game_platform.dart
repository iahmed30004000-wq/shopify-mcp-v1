import 'dart:async';

import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../domain/saved_web_game.dart';

/// System integration of a playing game: immersive full screen, the game's
/// orientation, keeping the screen on, and (optionally) pausing,
/// hardening and watching the native WebView. Every call is best-effort and
/// never throws.
abstract interface class GameSessionPlatform {
  /// Hides the system bars, locks [orientation], keeps the screen on.
  Future<void> enter(GameOrientation orientation);

  /// Restores Madar's normal chrome (edge-to-edge, portrait, screen may
  /// sleep).
  Future<void> exit();

  /// Re-applies immersive mode (Android shows the bars again after the app
  /// returns from the background).
  Future<void> reassert();

  /// Asks the host to pause the native WebView `webViewId` (Android
  /// `WebView.onPause()` + `pauseTimers()`); true when the host did.
  Future<bool> pauseWebView(int webViewId);

  Future<void> resumeWebView(int webViewId);

  /// Asks the host to lock the native WebView `webViewId` down where the
  /// plugin gives Dart no switch: no popup windows
  /// (`setSupportMultipleWindows(false)`,
  /// `setJavaScriptCanOpenWindowsAutomatically(false)` – the plugin turns
  /// both on, and every `window.open` then creates a native WebView), and
  /// report its renderer's death ([rendererGone]) instead of letting
  /// Android kill the app.
  Future<void> hardenWebView(int webViewId);

  /// Ids of native WebViews whose renderer process is gone (crash, or
  /// killed for memory), as reported by the host.
  Stream<int> get rendererGone;
}

/// Madar's orientations outside a game (see bootstrap).
const List<DeviceOrientation> madarAppOrientations = [DeviceOrientation.portraitUp];

List<DeviceOrientation> orientationsFor(GameOrientation o) => switch (o) {
  GameOrientation.auto => const [
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ],
  GameOrientation.portrait => const [DeviceOrientation.portraitUp],
  GameOrientation.landscape => const [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight],
};

/// Method channel of the Android host (see the lead notes in
/// `saved_games.dart`). Dart → host: `keepScreenOn {on}`,
/// `pauseWebView {id}`, `resumeWebView {id}`, `hardenWebView {id}`; host →
/// Dart: `rendererGone {id}`. Missing handlers are ignored.
const MethodChannel savedGamesHostChannel = MethodChannel('app.madar.orbit/saved_games');

class SystemGameSessionPlatform implements GameSessionPlatform {
  const SystemGameSessionPlatform({this.channel = savedGamesHostChannel});

  final MethodChannel channel;

  // System chrome is global: every enter / exit / reassert runs after the
  // previous one has finished, so a quick exit can never be overtaken by
  // the tail of an enter (leaving the screen on or the bars hidden).
  static Future<void> _chain = Future<void>.value();
  static final Map<String, StreamController<int>> _gone = {};

  static Future<void> _serial(Future<void> Function() op) {
    final run = _chain.then((_) => op());
    _chain = run.then<void>((_) {}, onError: (Object _) {});
    return run;
  }

  @override
  Future<void> enter(GameOrientation orientation) => _serial(() async {
    await _quiet(() => SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky));
    await _quiet(() => SystemChrome.setPreferredOrientations(orientationsFor(orientation)));
    await _invoke('keepScreenOn', {'on': true});
  });

  @override
  Future<void> exit() => _serial(() async {
    await _invoke('keepScreenOn', {'on': false});
    await _quiet(() => SystemChrome.setPreferredOrientations(madarAppOrientations));
    await _quiet(() => SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
  });

  @override
  Future<void> reassert() =>
      _serial(() => _quiet(() => SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky)));

  @override
  Future<bool> pauseWebView(int webViewId) async => await _invoke('pauseWebView', {'id': webViewId}) == true;

  @override
  Future<void> resumeWebView(int webViewId) async => _invoke('resumeWebView', {'id': webViewId});

  @override
  Future<void> hardenWebView(int webViewId) async => _invoke('hardenWebView', {'id': webViewId});

  @override
  Stream<int> get rendererGone {
    final existing = _gone[channel.name];
    if (existing != null) return existing.stream;
    final gone = _gone[channel.name] = StreamController<int>.broadcast();
    try {
      channel.setMethodCallHandler((call) async {
        final args = call.arguments;
        final id = args is Map ? args['id'] : null;
        if (call.method == 'rendererGone' && id is int) gone.add(id);
        return null;
      });
    } on Object {
      // No binding (pure Dart): nothing will report.
    }
    return gone.stream;
  }

  Future<Object?> _invoke(String method, Map<String, Object?> args) async {
    try {
      return await channel.invokeMethod<Object?>(method, args);
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  static Future<void> _quiet(Future<void> Function() call) async {
    try {
      await call();
    } on Object {
      // Not available (tests, desktop): nothing to restore either.
    }
  }
}

/// Opens a link outside Madar, in the user's browser – only after the user
/// confirmed it.
abstract interface class GameLinkOpener {
  Future<bool> openExternally(Uri url);
}

class UrlLauncherGameLinkOpener implements GameLinkOpener {
  const UrlLauncherGameLinkOpener();

  @override
  Future<bool> openExternally(Uri url) async {
    if (url.scheme != 'https' && url.scheme != 'http') return false;
    try {
      return await launchUrl(url, mode: LaunchMode.externalApplication);
    } on Object {
      return false;
    }
  }
}

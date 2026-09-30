import 'dart:async';

import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../domain/saved_web_game.dart';

/// System integration of a playing game: immersive full screen, the game's
/// orientation, keeping the screen on, and (optionally) pausing the native
/// WebView. Every call is best-effort and never throws.
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

/// Method channel the Android host answers (see the lead notes in
/// `saved_games.dart`): `keepScreenOn {on}`, `pauseWebView {id}`,
/// `resumeWebView {id}`. Missing handlers are ignored.
const MethodChannel savedGamesHostChannel = MethodChannel('app.madar/saved_games');

class SystemGameSessionPlatform implements GameSessionPlatform {
  const SystemGameSessionPlatform({this.channel = savedGamesHostChannel});

  final MethodChannel channel;

  @override
  Future<void> enter(GameOrientation orientation) async {
    await _quiet(() => SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky));
    await _quiet(() => SystemChrome.setPreferredOrientations(orientationsFor(orientation)));
    await _invoke('keepScreenOn', {'on': true});
  }

  @override
  Future<void> exit() async {
    await _invoke('keepScreenOn', {'on': false});
    await _quiet(() => SystemChrome.setPreferredOrientations(madarAppOrientations));
    await _quiet(() => SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
  }

  @override
  Future<void> reassert() => _quiet(() => SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky));

  @override
  Future<bool> pauseWebView(int webViewId) async => await _invoke('pauseWebView', {'id': webViewId}) == true;

  @override
  Future<void> resumeWebView(int webViewId) async => _invoke('resumeWebView', {'id': webViewId});

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

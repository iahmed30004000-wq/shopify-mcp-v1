import 'dart:async';
import 'dart:convert';
import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../data/game_platform.dart';
import '../domain/navigation_policy.dart';
import '../domain/saved_web_game.dart';
import 'android_hardening.dart';
import 'game_scripts.dart';

/// What the player shows over (or instead of) the page.
enum GamePhase {
  /// Deleting the site's stored data before the game loads.
  clearing,

  /// First load of the game (full-screen loading veil).
  loading,

  /// The game is running.
  ready,

  /// The main page could not be reached (no connection).
  offline,

  /// The main page failed for another reason.
  failed,

  /// The site's certificate was refused.
  insecure,

  /// Unloaded for prayer (its sound could not be reached); reloads after.
  resting,
}

/// Madar-styled answers to the page's `alert` / `confirm` / `prompt`.
abstract interface class GamePageDialogs {
  Future<void> alert(String host, String message);
  Future<bool> confirm(String host, String message);
  Future<String?> prompt(String host, String message, String? defaultText);
}

/// Drives one game's WebView: locked-down configuration, the origin policy,
/// load / error states, muting (user, prayer, background) and per-site data
/// clearing. UI-free, so tests can run it against a fake WebView platform.
///
/// Never adds a JavaScript channel: pages get no bridge to Madar.
class GamePlayerController extends ChangeNotifier {
  GamePlayerController({
    required this.game,
    required this.onExternalRequest,
    required this.dialogs,
    this.platform = const SystemGameSessionPlatform(),
    this.onCleared,
    WebViewController Function()? createWebView,
    @visibleForTesting this.clearPollInterval = const Duration(milliseconds: 150),
    @visibleForTesting this.rehushInterval = const Duration(seconds: 2),
  }) : origins = GameOrigins(game.url),
       web = (createWebView ?? _defaultWebView)();

  static WebViewController _defaultWebView() => WebViewController(onPermissionRequest: (r) => r.deny());

  final SavedWebGame game;
  final WebViewController web;
  final GameSessionPlatform platform;
  final GamePageDialogs dialogs;

  /// The page wants to open [url] outside the game's origin. The UI asks
  /// the user and opens it externally; it is never loaded in the game view.
  final Future<void> Function(Uri url) onExternalRequest;

  /// The site's data was cleared (the store resets the pending flag).
  final Future<void> Function()? onCleared;

  final Duration clearPollInterval;
  final Duration rehushInterval;

  GameOrigins origins;
  GamePhase _phase = GamePhase.loading;
  int _progress = 0;
  bool _firstPageDone = false;
  bool _mainError = false;
  bool _disposed = false;
  bool _started = false;
  bool _externalPending = false;
  Uri? _resumeUrl;

  bool _userMuted = false;
  bool _prayer = false;
  bool _background = false;
  HushPlan? _prayerPlan;
  bool _nativePaused = false;
  bool _sealedAudio = false;
  Timer? _rehush;
  Future<void> _hushChain = Future<void>.value();

  // Dialog flood guard.
  final List<DateTime> _dialogTimes = [];
  DateTime? _dialogsMutedUntil;

  // Navigation loop guard (e.g. a download URL re-requested forever).
  String? _lastNavUrl;
  int _lastNavCount = 0;
  DateTime _lastNavAt = DateTime.fromMillisecondsSinceEpoch(0);

  GamePhase get phase => _phase;

  /// 0–100 while loading.
  int get progress => _progress;
  bool get userMuted => _userMuted;
  bool get prayerHushed => _prayer;

  /// Some of the game's sound plays in a frame Madar cannot reach from the
  /// page (a cross-origin frame, e.g. a Claude artifact's sandbox).
  bool get sealedAudio => _sealedAudio;
  bool get firstPageDone => _firstPageDone;

  void _set({GamePhase? phase, int? progress}) {
    if (_disposed) return;
    var changed = false;
    if (phase != null && phase != _phase) {
      _phase = phase;
      changed = true;
    }
    if (progress != null && progress != _progress) {
      _progress = progress;
      changed = true;
    }
    if (changed) notifyListeners();
  }

  /// Configures the WebView and loads the game (clearing its data first
  /// when the user asked for it).
  Future<void> start({bool clearFirst = false}) async {
    if (_started) return;
    _started = true;
    await _configure();
    if (clearFirst) {
      await clearSiteData();
    } else {
      await _load(game.url);
    }
  }

  Future<void> _configure() async {
    await _quiet(() => web.setJavaScriptMode(JavaScriptMode.unrestricted));
    await _quiet(() => web.setBackgroundColor(const Color(0xFF000000)));
    await _quiet(
      () => web.setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: _onNavigationRequest,
          onPageStarted: _onPageStarted,
          onPageFinished: _onPageFinished,
          onProgress: (p) => _set(progress: p.clamp(0, 100)),
          onWebResourceError: _onWebResourceError,
          onSslAuthError: (e) {
            unawaited(_quiet(e.cancel));
            if (!_firstPageDone) _fail(GamePhase.insecure);
          },
          // Never answer a site's login prompt from inside a game.
          onHttpAuthRequest: (r) => r.onCancel(),
        ),
      ),
    );
    await _quiet(() => web.setOnJavaScriptAlertDialog(_alert));
    await _quiet(() => web.setOnJavaScriptConfirmDialog(_confirm));
    await _quiet(() => web.setOnJavaScriptTextInputDialog(_prompt));
    // No zoom/overscroll surprises while playing.
    await _quiet(() => web.enableZoom(false));
    await _quiet(() => web.setOverScrollMode(WebViewOverScrollMode.never));
    await hardenGameWebView(web);
  }

  /// The one way a game page is loaded. During prayer nothing is: the
  /// page waits (resting) and loads when the prayer mute lifts.
  Future<void> _load(Uri url) async {
    _mainError = false;
    if (_prayer) {
      _resumeUrl = url;
      _prayerPlan = HushPlan.unload;
      await _rest();
      return;
    }
    _set(phase: GamePhase.loading, progress: 0);
    await _quiet(() => web.loadRequest(url));
  }

  Future<void> _rest() async {
    _set(phase: GamePhase.resting);
    await _quiet(() => web.loadHtmlString(GameScripts.restPage));
  }

  /// Loads the game again (after an error or from the controls).
  Future<void> retry() async {
    if (_prayer || _phase == GamePhase.resting || _phase == GamePhase.clearing) return;
    if (_firstPageDone && _phase == GamePhase.ready) {
      _mainError = false;
      _set(progress: 0);
      await _quiet(web.reload);
      return;
    }
    Uri? current;
    try {
      final u = await web.currentUrl();
      current = u == null ? null : Uri.tryParse(u);
    } on Object {
      current = null;
    }
    await _load(current != null && origins.contains(current) ? current : game.url);
  }

  /// Deletes the game site's storage (see [GameScripts.clearSiteDataPage]),
  /// then loads the game fresh.
  ///
  /// Every origin the game used this session is cleared (the saved link's
  /// and any it was redirected to), one after the other.
  Future<void> clearSiteData() async {
    if (_disposed) return;
    _mainError = false;
    _clearQueue
      ..clear()
      ..addAll([origins.home, ...origins.adopted]);
    _set(phase: GamePhase.clearing, progress: 0);
    await _clearNext();
  }

  final List<String> _clearQueue = [];
  bool _finishingClear = false;
  Timer? _clearTimeout;

  Future<void> _clearNext() async {
    final origin = _clearQueue.removeAt(0);
    await _quiet(() => web.loadHtmlString(GameScripts.clearSiteDataPage, baseUrl: '$origin/'));
    // Completion is detected in onPageFinished; a page that never reports
    // must not strand the player.
    _clearTimeout?.cancel();
    _clearTimeout = Timer(const Duration(seconds: 8), () {
      if (!_disposed && _phase == GamePhase.clearing) unawaited(_finishClear());
    });
  }

  Future<void> _finishClear() async {
    if (_finishingClear) return;
    _finishingClear = true;
    _clearTimeout?.cancel();
    try {
      for (var i = 0; i < 30; i++) {
        // Interrupted (prayer, disposal): the flag stays set for next time.
        if (_disposed || _phase != GamePhase.clearing) return;
        final done = await _evalString(GameScripts.clearedProbe);
        if (done == 'done') break;
        await Future<void>.delayed(clearPollInterval);
      }
      if (_disposed || _phase != GamePhase.clearing) return;
      if (_clearQueue.isNotEmpty) {
        await _clearNext();
        return;
      }
      await onCleared?.call();
      _firstPageDone = false;
      origins = GameOrigins(game.url);
      await _load(game.url);
    } finally {
      _finishingClear = false;
    }
  }

  // ── Navigation ──────────────────────────────────────────────────────────

  FutureOr<NavigationDecision> _onNavigationRequest(NavigationRequest request) {
    if (_phase == GamePhase.resting) return NavigationDecision.prevent;
    final verdict = decideGameNavigation(
      origins: origins,
      target: request.url,
      isMainFrame: request.isMainFrame,
      initialLoad: !_firstPageDone,
    );
    switch (verdict) {
      case NavigationVerdict.allow:
        return _loopGuard(request) ? NavigationDecision.navigate : NavigationDecision.prevent;
      case NavigationVerdict.adopt:
        origins = origins.adopt(Uri.parse(request.url));
        return _loopGuard(request) ? NavigationDecision.navigate : NavigationDecision.prevent;
      case NavigationVerdict.askExternal:
        final uri = Uri.tryParse(request.url);
        if (uri != null && !_externalPending) {
          _externalPending = true;
          unawaited(onExternalRequest(uri).whenComplete(() => _externalPending = false));
        }
        return NavigationDecision.prevent;
      case NavigationVerdict.block:
        return NavigationDecision.prevent;
    }
  }

  bool _loopGuard(NavigationRequest request) {
    if (!request.isMainFrame) return true;
    final now = DateTime.now();
    if (request.url == _lastNavUrl && now.difference(_lastNavAt) < const Duration(seconds: 2)) {
      _lastNavCount++;
    } else {
      _lastNavCount = 1;
    }
    _lastNavUrl = request.url;
    _lastNavAt = now;
    return _lastNavCount <= 4;
  }

  void _onPageStarted(String url) {
    if (_phase == GamePhase.clearing || _phase == GamePhase.resting) return;
    if (!_firstPageDone) _set(phase: GamePhase.loading);
  }

  void _onPageFinished(String url) {
    if (_disposed) return;
    switch (_phase) {
      case GamePhase.clearing:
        unawaited(_finishClear());
        return;
      case GamePhase.resting:
        return;
      case GamePhase.offline || GamePhase.failed || GamePhase.insecure:
        return;
      case GamePhase.loading || GamePhase.ready:
        if (_mainError) return;
        _firstPageDone = true;
        _set(phase: GamePhase.ready, progress: 100);
        unawaited(_afterPageLoad());
    }
  }

  Future<void> _afterPageLoad() async {
    await _quiet(() => web.runJavaScript(GameScripts.trackAudio));
    if (_hushWanted) await _reapplyHush();
  }

  void _onWebResourceError(WebResourceError error) {
    final main = error.isForMainFrame ?? !_firstPageDone;
    if (!main || _phase == GamePhase.clearing || _phase == GamePhase.resting) return;
    if (error.errorType == WebResourceErrorType.unsupportedScheme) return;
    final offline = switch (error.errorType) {
      WebResourceErrorType.hostLookup ||
      WebResourceErrorType.connect ||
      WebResourceErrorType.timeout ||
      WebResourceErrorType.io => true,
      _ => false,
    };
    final insecure = error.errorType == WebResourceErrorType.failedSslHandshake;
    _fail(offline ? GamePhase.offline : (insecure ? GamePhase.insecure : GamePhase.failed));
  }

  void _fail(GamePhase phase) {
    _mainError = true;
    _set(phase: phase);
  }

  // ── Page dialogs (rate-limited: a page cannot trap the user) ────────────

  bool _dialogAllowed() {
    final now = DateTime.now();
    if (_dialogsMutedUntil != null && now.isBefore(_dialogsMutedUntil!)) return false;
    _dialogTimes
      ..add(now)
      ..removeWhere((t) => now.difference(t) > const Duration(seconds: 10));
    if (_dialogTimes.length > 3) {
      _dialogsMutedUntil = now.add(const Duration(seconds: 30));
      _dialogTimes.clear();
      return false;
    }
    return !_disposed && _phase == GamePhase.ready;
  }

  static String _hostOf(String url) => Uri.tryParse(url)?.host ?? '';

  Future<void> _alert(JavaScriptAlertDialogRequest r) async {
    if (!_dialogAllowed()) return;
    await dialogs.alert(_hostOf(r.url), clampText(r.message, 600, singleLine: false));
  }

  Future<bool> _confirm(JavaScriptConfirmDialogRequest r) async {
    if (!_dialogAllowed()) return false;
    return dialogs.confirm(_hostOf(r.url), clampText(r.message, 600, singleLine: false));
  }

  Future<String> _prompt(JavaScriptTextInputDialogRequest r) async {
    if (!_dialogAllowed()) return '';
    final answer = await dialogs.prompt(
      _hostOf(r.url),
      clampText(r.message, 600, singleLine: false),
      r.defaultText == null ? null : clampText(r.defaultText!, 200),
    );
    return answer ?? '';
  }

  // ── Sound ───────────────────────────────────────────────────────────────

  bool get _hushWanted => _userMuted || _prayer || _background;

  /// The Mute button.
  Future<void> setUserMuted(bool muted) {
    if (muted == _userMuted) return Future<void>.value();
    _userMuted = muted;
    notifyListeners();
    return _serial(_reapplyHush);
  }

  /// The app's adhan / prayer mute ([PrayerMuteController.muted]).
  Future<void> setPrayerMuted(bool muted) {
    if (muted == _prayer) return Future<void>.value();
    _prayer = muted;
    if (!_disposed) notifyListeners();
    return _serial(muted ? _enterPrayer : _leavePrayer);
  }

  /// Madar left (true) or returned to (false) the foreground.
  Future<void> setBackground(bool background) {
    if (background == _background) return Future<void>.value();
    _background = background;
    return _serial(_reapplyHush);
  }

  Future<void> _serial(Future<void> Function() op) {
    final run = _hushChain.then((_) => _disposed ? null : op());
    _hushChain = run.then<void>((_) {}, onError: (Object _) {});
    return run;
  }

  Future<void> _enterPrayer() async {
    if (_phase == GamePhase.resting) return;
    int? sealed;
    if (_phase == GamePhase.ready) {
      sealed = await _hush(pause: true, hide: true);
    } else if (_phase != GamePhase.loading && _phase != GamePhase.clearing) {
      // An error page makes no sound.
      sealed = 0;
    }
    final plan = planHush(reason: HushReason.prayer, sealedFrames: sealed);
    _prayerPlan = plan;
    if (plan == HushPlan.unload) {
      Uri? current;
      if (_phase == GamePhase.ready) {
        try {
          final u = await web.currentUrl();
          current = u == null ? null : Uri.tryParse(u);
        } on Object {
          current = null;
        }
      }
      // Loading / clearing / error: start the game afresh afterwards.
      _resumeUrl = current != null && origins.contains(current) ? current : (_resumeUrl ?? game.url);
      await _rest();
    } else {
      await _nativePause();
      _startRehush();
    }
  }

  Future<void> _leavePrayer() async {
    final plan = _prayerPlan;
    _prayerPlan = null;
    if (_phase == GamePhase.resting || plan == HushPlan.unload) {
      final url = _resumeUrl ?? game.url;
      _resumeUrl = null;
      await _load(url);
      return;
    }
    await _reapplyHush();
  }

  /// Brings the page's sound state in line with the current reasons.
  Future<void> _reapplyHush() async {
    if (_disposed || _phase == GamePhase.resting) return;
    final strict = _prayer || _background;
    if (_phase != GamePhase.ready) {
      if (!strict) await _nativeResume();
      _stopRehush();
      return;
    }
    await _eval(GameScripts.unhush);
    if (!_hushWanted) {
      await _nativeResume();
      _stopRehush();
      return;
    }
    final sealed = await _hush(pause: strict, hide: strict);
    if (_userMuted && !strict && (sealed ?? 1) > 0 && !_sealedAudio) {
      _sealedAudio = true;
      notifyListeners();
    }
    if (strict) {
      await _nativePause();
    } else {
      await _nativeResume();
    }
    _startRehush();
  }

  /// Runs the in-page hush; the number of unreachable frames or null.
  Future<int?> _hush({required bool pause, required bool hide}) async {
    final result = decodeJsObject(await _evalRaw(GameScripts.hush(pause: pause, hide: hide)));
    final sealed = result?['sealed'];
    if (sealed is num && sealed > 0 && !_sealedAudio) {
      _sealedAudio = true;
      if (!_disposed) notifyListeners();
    }
    return sealed is num ? sealed.toInt() : null;
  }

  void _startRehush() {
    _rehush ??= Timer.periodic(rehushInterval, (_) {
      if (_disposed || !_hushWanted || _phase != GamePhase.ready) return;
      final strict = _prayer || _background;
      unawaited(_serial(() => _hush(pause: strict, hide: strict)));
    });
  }

  void _stopRehush() {
    _rehush?.cancel();
    _rehush = null;
  }

  Future<void> _nativePause() async {
    final id = nativeWebViewId(web);
    if (id == null || _nativePaused) return;
    _nativePaused = await platform.pauseWebView(id);
  }

  Future<void> _nativeResume() async {
    final id = nativeWebViewId(web);
    if (id == null || !_nativePaused) return;
    _nativePaused = false;
    await platform.resumeWebView(id);
  }

  // ── JavaScript helpers ──────────────────────────────────────────────────

  Future<void> _eval(String script) => _quiet(() => web.runJavaScript(script));

  Future<Object?> _evalRaw(String script) async {
    try {
      return await web.runJavaScriptReturningResult(script);
    } on Object {
      return null;
    }
  }

  Future<String?> _evalString(String script) async {
    final r = await _evalRaw(script);
    return r == null ? null : decodeJsString(r);
  }

  static Future<void> _quiet(Future<void> Function() call) async {
    try {
      await call();
    } on Object {
      // The WebView is gone or the platform lacks the call.
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _stopRehush();
    _clearTimeout?.cancel();
    final id = nativeWebViewId(web);
    if (id != null && _nativePaused) unawaited(platform.resumeWebView(id));
    // Stop anything still sounding before the view is torn down.
    unawaited(_quiet(() => web.loadHtmlString(GameScripts.restPage)));
    super.dispose();
  }
}

/// Android returns a script's string result JSON-quoted (sometimes twice);
/// other platforms return it raw. The plain string either way.
String decodeJsString(Object result) {
  Object? v = result;
  for (var i = 0; i < 2 && v is String; i++) {
    final s = v.trim();
    if (!(s.startsWith('"') && s.endsWith('"'))) break;
    try {
      v = jsonDecode(s);
    } on FormatException {
      break;
    }
  }
  return v is String ? v : '$v';
}

/// A script's JSON-object result as a map (see [decodeJsString]).
Map<String, Object?>? decodeJsObject(Object? result) {
  Object? v = result;
  for (var i = 0; i < 3 && v is String; i++) {
    try {
      v = jsonDecode(v);
    } on FormatException {
      return null;
    }
  }
  return v is Map ? v.cast<String, Object?>() : null;
}

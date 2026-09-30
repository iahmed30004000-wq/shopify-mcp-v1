import 'dart:async';
import 'dart:convert';
import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../data/game_platform.dart';
import '../domain/game_url.dart';
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

  /// The page's renderer process is gone (crashed or killed for memory);
  /// the game needs a fresh WebView.
  crashed,
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
    DateTime Function()? now,
    @visibleForTesting this.clearPollInterval = const Duration(milliseconds: 150),
    @visibleForTesting this.rehushInterval = const Duration(seconds: 2),
  }) : origins = GameOrigins(game.url),
       _createWebView = createWebView ?? _defaultWebView,
       _now = now ?? DateTime.now {
    _web = _createWebView();
  }

  static WebViewController _defaultWebView() => WebViewController(onPermissionRequest: (r) => r.deny());

  final SavedWebGame game;
  final GameSessionPlatform platform;
  final WebViewController Function() _createWebView;
  final DateTime Function() _now;

  late WebViewController _web;
  int _generation = 0;
  bool _webGone = false;
  StreamSubscription<int>? _goneSub;

  /// The game's WebView. Replaced by a fresh one after its renderer died
  /// ([webGeneration] then changes).
  WebViewController get web => _web;

  /// Changes whenever [web] is replaced.
  int get webGeneration => _generation;
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

  // The audio tracker of the current document started before the page's
  // own scripts (reported by the install run at page start; the page
  // cannot fake it, no page script had run yet).
  bool _trackedEarly = false;
  int _pageSeq = 0;

  // A clear of the site's data was cut short by prayer: finish it after.
  bool _resumeClear = false;

  // Flood guard for everything a page can put in front of the user
  // (alert / confirm / prompt and "open outside?" questions).
  final List<DateTime> _modalTimes = [];
  DateTime? _modalsMutedUntil;

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
    _goneSub = platform.rendererGone.listen(_onRendererGone);
    await _configure();
    if (clearFirst) {
      await clearSiteData();
    } else {
      await _load(game.url);
    }
  }

  Future<void> _configure() async {
    final web = _web;
    // Events of a WebView that has since been replaced are ignored.
    bool current() => identical(web, _web);
    await _quiet(() => web.setJavaScriptMode(JavaScriptMode.unrestricted));
    await _quiet(() => web.setBackgroundColor(const Color(0xFF000000)));
    await _quiet(
      () => web.setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (r) => current() ? _onNavigationRequest(r) : NavigationDecision.prevent,
          onPageStarted: (u) => current() ? _onPageStarted(u) : null,
          onPageFinished: (u) => current() ? _onPageFinished(u) : null,
          onProgress: (p) => current() ? _set(progress: p.clamp(0, 100)) : null,
          onWebResourceError: (e) => current() ? _onWebResourceError(e) : null,
          onSslAuthError: (e) {
            unawaited(_quiet(e.cancel));
            if (current() && !_firstPageDone) _fail(GamePhase.insecure);
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
    // What the plugin cannot switch off from Dart (popup windows, which
    // it enables) and the renderer-gone watch are the host's.
    final id = nativeWebViewId(web);
    if (id != null) await platform.hardenWebView(id);
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
    if (_webGone) {
      await _replaceWebView();
      return;
    }
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
    if (_disposed || _webGone) return;
    _resumeClear = false;
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
    // During prayer nothing new may load (a new document could sound).
    if (_phase == GamePhase.resting || _prayer || _webGone) return NavigationDecision.prevent;
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
        if (uri != null && !_externalPending && _modalAllowed(whileLoading: true)) {
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
    if (_disposed || _phase == GamePhase.clearing || _phase == GamePhase.resting) return;
    if (!_firstPageDone) _set(phase: GamePhase.loading);
    // A new document: install the audio tracker before its scripts if we
    // can, and trust in-place hushing only if that worked.
    _trackedEarly = false;
    final seq = ++_pageSeq;
    final web = _web;
    unawaited(() async {
      final r = decodeJsObject(await _evalRaw(GameScripts.trackAudio));
      if (seq == _pageSeq && identical(web, _web) && r?['early'] == true) _trackedEarly = true;
    }());
  }

  void _onPageFinished(String url) {
    if (_disposed) return;
    switch (_phase) {
      case GamePhase.clearing:
        unawaited(_finishClear());
        return;
      case GamePhase.resting:
        return;
      case GamePhase.offline || GamePhase.failed || GamePhase.insecure || GamePhase.crashed:
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
    if (!main || _webGone || _phase == GamePhase.clearing || _phase == GamePhase.resting) return;
    if (error.errorType == WebResourceErrorType.unsupportedScheme) return;
    final offline = switch (error.errorType) {
      WebResourceErrorType.hostLookup ||
      WebResourceErrorType.connect ||
      WebResourceErrorType.timeout ||
      WebResourceErrorType.io => true,
      _ => false,
    };
    final insecure =
        error.errorType == WebResourceErrorType.failedSslHandshake ||
        error.errorType == WebResourceErrorType.unsafeResource;
    _fail(offline ? GamePhase.offline : (insecure ? GamePhase.insecure : GamePhase.failed));
  }

  void _fail(GamePhase phase) {
    _mainError = true;
    _set(phase: phase);
  }

  /// The host reports that WebView [id]'s renderer is gone. Without the
  /// host's handling Android kills the whole app; with it, the player shows
  /// what happened and a retry builds a fresh WebView.
  void _onRendererGone(int id) {
    if (_disposed || _webGone || id != nativeWebViewId(_web)) return;
    _webGone = true;
    _stopRehush();
    _clearTimeout?.cancel();
    _nativePaused = false;
    if (_phase == GamePhase.clearing) _resumeClear = true;
    _set(phase: GamePhase.crashed);
  }

  Future<void> _replaceWebView() async {
    _web = _createWebView();
    _generation++;
    _webGone = false;
    _firstPageDone = false;
    _trackedEarly = false;
    _mainError = false;
    _set(phase: GamePhase.loading, progress: 0);
    notifyListeners();
    await _configure();
    if (_disposed) return;
    if (_resumeClear) {
      await clearSiteData();
    } else {
      await _load(game.url);
    }
  }

  // ── Page dialogs (rate-limited: a page cannot trap the user) ────────────

  /// Whether the page may put a dialog or question in front of the user
  /// now: only while the game is showing ([whileLoading]: or loading – a
  /// saved link that redirects to http asks to open outside), never over
  /// the prayer screen or while Madar is away, and at most 3 in 10 s – then
  /// nothing for 30 s, so a page cannot keep the user from the controls.
  bool _modalAllowed({bool whileLoading = false}) {
    final shown = _phase == GamePhase.ready || (whileLoading && _phase == GamePhase.loading);
    if (_disposed || !shown || _prayer || _background) return false;
    final now = _now();
    if (_modalsMutedUntil != null && now.isBefore(_modalsMutedUntil!)) return false;
    _modalTimes
      ..add(now)
      ..removeWhere((t) => now.difference(t) > const Duration(seconds: 10));
    if (_modalTimes.length > 3) {
      _modalsMutedUntil = now.add(const Duration(seconds: 30));
      _modalTimes.clear();
      return false;
    }
    return true;
  }

  static String _hostOf(String url) {
    final uri = Uri.tryParse(url);
    return uri == null ? '' : displayHost(uri);
  }

  Future<void> _alert(JavaScriptAlertDialogRequest r) async {
    if (!_modalAllowed()) return;
    await dialogs.alert(_hostOf(r.url), clampText(r.message, 600, singleLine: false));
  }

  Future<bool> _confirm(JavaScriptConfirmDialogRequest r) async {
    if (!_modalAllowed()) return false;
    return dialogs.confirm(_hostOf(r.url), clampText(r.message, 600, singleLine: false));
  }

  Future<String> _prompt(JavaScriptTextInputDialogRequest r) async {
    if (!_modalAllowed()) return '';
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
    var blind = true;
    if (_phase == GamePhase.ready) {
      final r = await _hush(pause: true, hide: true);
      sealed = r.sealed;
      blind = r.blind || !_trackedEarly;
    } else if (_phase != GamePhase.loading && _phase != GamePhase.clearing) {
      // An error page (or a dead renderer) makes no sound.
      sealed = 0;
      blind = false;
    }
    final plan = planHush(reason: HushReason.prayer, sealedFrames: sealed, blind: blind);
    _prayerPlan = plan;
    if (plan == HushPlan.unload) {
      await _unloadForPrayer();
    } else {
      if (!_webGone) await _nativePause();
      _startRehush();
    }
  }

  /// Unloads the page (certain silence); it loads again when prayer ends.
  Future<void> _unloadForPrayer() async {
    _prayerPlan = HushPlan.unload;
    _stopRehush();
    if (_phase == GamePhase.clearing) _resumeClear = true;
    Uri? current;
    if (_phase == GamePhase.ready) {
      try {
        final u = await _web.currentUrl();
        current = u == null ? null : Uri.tryParse(u);
      } on Object {
        current = null;
      }
    }
    // Loading / clearing / error: start the game afresh afterwards.
    _resumeUrl = current != null && origins.contains(current) ? current : (_resumeUrl ?? game.url);
    await _rest();
  }

  Future<void> _leavePrayer() async {
    final plan = _prayerPlan;
    _prayerPlan = null;
    if (_phase == GamePhase.resting || plan == HushPlan.unload) {
      final url = _resumeUrl ?? game.url;
      _resumeUrl = null;
      if (_resumeClear) {
        await clearSiteData();
      } else {
        await _load(url);
      }
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
    final r = await _hush(pause: strict, hide: strict);
    if (_userMuted && !strict && (r.sealed ?? 1) > 0 && !_sealedAudio) {
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

  /// Runs the in-page hush: the number of unreachable frames (null when
  /// the hush could not run) and whether some sound may be out of its sight
  /// (an answer without the flag counts as blind).
  Future<({int? sealed, bool blind})> _hush({required bool pause, required bool hide}) async {
    final result = decodeJsObject(await _evalRaw(GameScripts.hush(pause: pause, hide: hide)));
    final sealed = result?['sealed'];
    if (sealed is num && sealed > 0 && !_sealedAudio) {
      _sealedAudio = true;
      if (!_disposed) notifyListeners();
    }
    return (sealed: sealed is num ? sealed.toInt() : null, blind: result?['blind'] != false);
  }

  void _startRehush() {
    _rehush ??= Timer.periodic(rehushInterval, (_) {
      if (_disposed || !_hushWanted || _phase != GamePhase.ready) return;
      final strict = _prayer || _background;
      unawaited(
        _serial(() async {
          final r = await _hush(pause: strict, hide: strict);
          // The page grew sound Madar cannot reach during prayer (a new
          // cross-origin frame, an untracked window): unload it after all.
          final plan = planHush(reason: HushReason.prayer, sealedFrames: r.sealed, blind: r.blind || !_trackedEarly);
          if (_prayer && _prayerPlan == HushPlan.inPlace && plan == HushPlan.unload && _phase == GamePhase.ready) {
            await _nativeResume();
            await _unloadForPrayer();
          }
        }),
      );
    });
  }

  void _stopRehush() {
    _rehush?.cancel();
    _rehush = null;
  }

  Future<void> _nativePause() async {
    final id = nativeWebViewId(_web);
    if (id == null || _nativePaused) return;
    _nativePaused = await platform.pauseWebView(id);
  }

  Future<void> _nativeResume() async {
    final id = nativeWebViewId(_web);
    if (id == null || !_nativePaused) return;
    _nativePaused = false;
    await platform.resumeWebView(id);
  }

  // ── JavaScript helpers ──────────────────────────────────────────────────

  Future<void> _eval(String script) => _quiet(() => _web.runJavaScript(script));

  Future<Object?> _evalRaw(String script) async {
    if (_webGone) return null;
    try {
      return await _web.runJavaScriptReturningResult(script);
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
    unawaited(_goneSub?.cancel());
    final id = nativeWebViewId(_web);
    if (id != null && _nativePaused) unawaited(platform.resumeWebView(id));
    // Stop anything still sounding before the view is torn down.
    if (!_webGone) unawaited(_quiet(() => _web.loadHtmlString(GameScripts.restPage)));
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

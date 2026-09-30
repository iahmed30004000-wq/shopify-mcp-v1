// Fakes and a harness for Saved Games tests: a fake webview_flutter
// platform (no native WebView), a recording session platform / link
// opener / meta fetcher / data cleaner, and a themed app over an in-memory
// store.
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/design/themes.dart';
import 'package:madar/core/i18n/formatters.dart';
import 'package:madar/core/i18n/gen/app_localizations.dart';
import 'package:madar/core/motion/motion_kit.dart';
import 'package:madar/core/providers.dart';
import 'package:madar/core/settings/app_settings.dart' show DigitStyle;
import 'package:madar/core/sound/sound_api.dart';
import 'package:madar/features/saved_games/saved_games.dart';
// The platform interface is resolved through webview_flutter (its fakes
// are the documented way to test without a native WebView).
// ignore: depend_on_referenced_packages
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

// ── Fake webview_flutter platform ─────────────────────────────────────────

class FakeWebViewPlatform extends WebViewPlatform {
  final List<FakeWebController> controllers = [];
  final List<FakeNavigationDelegate> delegates = [];
  int cookieClears = 0;

  FakeWebController get last => controllers.last;

  @override
  PlatformWebViewController createPlatformWebViewController(PlatformWebViewControllerCreationParams params) {
    final c = FakeWebController(params);
    controllers.add(c);
    return c;
  }

  @override
  PlatformNavigationDelegate createPlatformNavigationDelegate(PlatformNavigationDelegateCreationParams params) {
    final d = FakeNavigationDelegate(params);
    delegates.add(d);
    return d;
  }

  @override
  PlatformWebViewWidget createPlatformWebViewWidget(PlatformWebViewWidgetCreationParams params) =>
      FakeWebViewWidget(params);

  @override
  PlatformWebViewCookieManager createPlatformCookieManager(PlatformWebViewCookieManagerCreationParams params) =>
      FakeCookieManager(params, this);
}

class FakePermissionRequest extends PlatformWebViewPermissionRequest {
  FakePermissionRequest() : super(types: {WebViewPermissionResourceType.camera});

  final List<bool> decisions = [];

  bool? get granted => decisions.isEmpty ? null : decisions.last;

  @override
  Future<void> grant() async => decisions.add(true);

  @override
  Future<void> deny() async => decisions.add(false);
}

class FakeWebController extends PlatformWebViewController {
  FakeWebController(super.params) : super.implementation();

  JavaScriptMode? jsMode;
  Color? background;
  bool? zoom;
  WebViewOverScrollMode? overScroll;
  FakeNavigationDelegate? delegate;
  String? current;
  int reloads = 0;
  int cacheClears = 0;
  int storageClears = 0;
  final List<String> loads = [];
  final List<(String, String?)> htmlLoads = [];
  final List<String> scripts = [];
  final List<String> channels = [];
  void Function(PlatformWebViewPermissionRequest)? permissionHandler;
  Future<void> Function(JavaScriptAlertDialogRequest)? onAlert;
  Future<bool> Function(JavaScriptConfirmDialogRequest)? onConfirm;
  Future<String> Function(JavaScriptTextInputDialogRequest)? onPrompt;

  /// Result of `runJavaScriptReturningResult` (Android-style quoted JSON).
  Object Function(String script) result = (_) => '""';

  List<String> get allLoads => [...loads, for (final h in htmlLoads) 'html:${h.$2}'];

  @override
  Future<void> loadRequest(LoadRequestParams params) async {
    loads.add(params.uri.toString());
    current = params.uri.toString();
  }

  @override
  Future<void> loadHtmlString(String html, {String? baseUrl}) async {
    htmlLoads.add((html, baseUrl));
    current = baseUrl ?? 'about:blank';
  }

  @override
  Future<String?> currentUrl() async => current;

  @override
  Future<void> reload() async => reloads++;

  @override
  Future<void> clearCache() async => cacheClears++;

  @override
  Future<void> clearLocalStorage() async => storageClears++;

  @override
  Future<void> setPlatformNavigationDelegate(PlatformNavigationDelegate handler) async =>
      delegate = handler as FakeNavigationDelegate;

  @override
  Future<void> runJavaScript(String javaScript) async => scripts.add(javaScript);

  @override
  Future<Object> runJavaScriptReturningResult(String javaScript) async {
    scripts.add(javaScript);
    return result(javaScript);
  }

  @override
  Future<void> addJavaScriptChannel(JavaScriptChannelParams javaScriptChannelParams) async =>
      channels.add(javaScriptChannelParams.name);

  @override
  Future<void> enableZoom(bool enabled) async => zoom = enabled;

  @override
  Future<void> setBackgroundColor(Color color) async => background = color;

  @override
  Future<void> setJavaScriptMode(JavaScriptMode javaScriptMode) async => jsMode = javaScriptMode;

  @override
  Future<void> setOnPlatformPermissionRequest(
    void Function(PlatformWebViewPermissionRequest request) onPermissionRequest,
  ) async => permissionHandler = onPermissionRequest;

  @override
  Future<void> setOnJavaScriptAlertDialog(
    Future<void> Function(JavaScriptAlertDialogRequest request) onJavaScriptAlertDialog,
  ) async => onAlert = onJavaScriptAlertDialog;

  @override
  Future<void> setOnJavaScriptConfirmDialog(
    Future<bool> Function(JavaScriptConfirmDialogRequest request) onJavaScriptConfirmDialog,
  ) async => onConfirm = onJavaScriptConfirmDialog;

  @override
  Future<void> setOnJavaScriptTextInputDialog(
    Future<String> Function(JavaScriptTextInputDialogRequest request) onJavaScriptTextInputDialog,
  ) async => onPrompt = onJavaScriptTextInputDialog;

  @override
  Future<void> setOverScrollMode(WebViewOverScrollMode mode) async => overScroll = mode;

  // Page events, as the platform would report them.
  void pageStarted(String url) => delegate?.onPageStarted?.call(url);
  void pageFinished(String url) => delegate?.onPageFinished?.call(url);
  void progress(int p) => delegate?.onProgress?.call(p);
  void error(WebResourceErrorType type, {bool main = true}) => delegate?.onError?.call(
    WebResourceError(errorCode: -2, description: 'fake', errorType: type, isForMainFrame: main),
  );

  FutureOr<NavigationDecision> navigate(String url, {bool main = true}) =>
      delegate!.onNavigation!(NavigationRequest(url: url, isMainFrame: main));
}

class FakeNavigationDelegate extends PlatformNavigationDelegate {
  FakeNavigationDelegate(super.params) : super.implementation();

  NavigationRequestCallback? onNavigation;
  PageEventCallback? onPageStarted;
  PageEventCallback? onPageFinished;
  ProgressCallback? onProgress;
  WebResourceErrorCallback? onError;
  HttpAuthRequestCallback? onAuth;
  SslAuthErrorCallback? onSsl;

  @override
  Future<void> setOnNavigationRequest(NavigationRequestCallback onNavigationRequest) async =>
      onNavigation = onNavigationRequest;

  @override
  Future<void> setOnPageStarted(PageEventCallback onPageStarted) async => this.onPageStarted = onPageStarted;

  @override
  Future<void> setOnPageFinished(PageEventCallback onPageFinished) async => this.onPageFinished = onPageFinished;

  @override
  Future<void> setOnProgress(ProgressCallback onProgress) async => this.onProgress = onProgress;

  @override
  Future<void> setOnWebResourceError(WebResourceErrorCallback onWebResourceError) async => onError = onWebResourceError;

  @override
  Future<void> setOnHttpAuthRequest(HttpAuthRequestCallback onHttpAuthRequest) async => onAuth = onHttpAuthRequest;

  @override
  Future<void> setOnSSlAuthError(SslAuthErrorCallback onSslAuthError) async => onSsl = onSslAuthError;

  @override
  Future<void> setOnUrlChange(UrlChangeCallback onUrlChange) async {}

  @override
  Future<void> setOnHttpError(HttpResponseErrorCallback onHttpError) async {}
}

class FakeWebViewWidget extends PlatformWebViewWidget {
  FakeWebViewWidget(super.params) : super.implementation();

  /// Stands in for a web page: a plain board-game-like canvas.
  @override
  Widget build(BuildContext context) => const DecoratedBox(
    key: ValueKey('fakeWebView'),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF1B2A3A), Color(0xFF0E1620)],
      ),
    ),
    child: CustomPaint(painter: _BoardPainter(), size: Size.infinite),
  );
}

class _BoardPainter extends CustomPainter {
  const _BoardPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.shortestSide / 6;
    final origin = Offset((size.width - cell * 5) / 2, (size.height - cell * 5) / 2);
    final paint = Paint();
    for (var r = 0; r < 5; r++) {
      for (var c = 0; c < 5; c++) {
        paint.color = (r + c).isEven ? const Color(0xFF2E4A63) : const Color(0xFF3D6480);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(origin.dx + c * cell + 3, origin.dy + r * cell + 3, cell - 6, cell - 6),
            const Radius.circular(8),
          ),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_BoardPainter oldDelegate) => false;
}

class FakeCookieManager extends PlatformWebViewCookieManager {
  FakeCookieManager(super.params, this.platform) : super.implementation();

  final FakeWebViewPlatform platform;

  @override
  Future<bool> clearCookies() async {
    platform.cookieClears++;
    return true;
  }
}

class FakeSslError extends PlatformSslAuthError {
  FakeSslError() : super(certificate: null, description: 'bad cert');

  bool cancelled = false;
  bool proceeded = false;

  @override
  Future<void> cancel() async => cancelled = true;

  @override
  Future<void> proceed() async => proceeded = true;
}

// ── Recording fakes of Saved Games services ────────────────────────────────

class FakeSessionPlatform implements GameSessionPlatform {
  final List<String> calls = [];

  @override
  Future<void> enter(GameOrientation orientation) async => calls.add('enter:${orientation.name}');

  @override
  Future<void> exit() async => calls.add('exit');

  @override
  Future<void> reassert() async => calls.add('reassert');

  @override
  Future<bool> pauseWebView(int webViewId) async {
    calls.add('pause:$webViewId');
    return true;
  }

  @override
  Future<void> resumeWebView(int webViewId) async => calls.add('resume:$webViewId');
}

class FakeLinkOpener implements GameLinkOpener {
  final List<Uri> opened = [];
  bool succeed = true;

  @override
  Future<bool> openExternally(Uri url) async {
    opened.add(url);
    return succeed;
  }
}

class FakeMetaFetcher implements GameMetaFetcher {
  String? title = 'Starlit Tiles';
  Uint8List? icon;
  final List<String> calls = [];

  @override
  Future<String?> fetchTitle(Uri page) async {
    calls.add('title:$page');
    return title;
  }

  @override
  Future<Uint8List?> fetchIcon(Uri page) async {
    calls.add('icon:$page');
    return icon;
  }
}

class FakeCleaner implements GameWebDataCleaner {
  int calls = 0;

  @override
  Future<bool> clearAll() async {
    calls++;
    return true;
  }
}

class RecordingHaptics implements HapticsService {
  final List<Haptic> fired = [];
  @override
  bool enabled = true;
  @override
  void fire(Haptic haptic) => fired.add(haptic);
}

final DateTime savedGamesTestNow = DateTime(2026, 9, 30, 20, 15);

/// Two sample records (generic test data, never shipped in the app).
List<SavedWebGame> sampleGames({DateTime? now}) {
  final t = now ?? savedGamesTestNow;
  return [
    SavedWebGame(
      id: 'g1',
      title: 'Double Feature',
      url: Uri.parse('https://claude.ai/public/artifacts/0f1e2d3c-4b5a-6978-8899-aabbccddeeff'),
      art: const GameArt(glyph: 5, hue: 0),
      addedAt: t.subtract(const Duration(days: 12)),
      lastPlayedAt: t.subtract(const Duration(days: 3)),
      playCount: 7,
      orientation: GameOrientation.landscape,
    ),
    SavedWebGame(
      id: 'g2',
      title: 'Orbit Puzzle',
      url: Uri.parse('https://games.example.org/orbit/'),
      art: const GameArt(glyph: 1, hue: 5),
      addedAt: t.subtract(const Duration(days: 2)),
    ),
    SavedWebGame(
      id: 'g3',
      title: 'Word Garden',
      url: Uri.parse('https://play.example.net/words'),
      art: const GameArt(glyph: 15, hue: 1),
      addedAt: t.subtract(const Duration(days: 30)),
      lastPlayedAt: t.subtract(const Duration(hours: 2)),
      playCount: 23,
    ),
  ];
}

class SavedGamesEnv {
  SavedGamesEnv({
    required this.store,
    required this.web,
    required this.session,
    required this.opener,
    required this.fetcher,
    required this.cleaner,
    required this.sound,
  });

  final MemorySavedWebGamesStore store;
  final FakeWebViewPlatform web;
  final FakeSessionPlatform session;
  final FakeLinkOpener opener;
  final FakeMetaFetcher fetcher;
  final FakeCleaner cleaner;
  final SilentSoundService sound;
}

/// A themed, localised app over an in-memory store with every platform
/// service faked. The fake WebView platform is installed globally.
(Widget, SavedGamesEnv) buildSavedGamesApp({
  required Widget home,
  MadarThemeId theme = MadarThemeId.lapis,
  Locale locale = const Locale('en'),
  List<SavedWebGame> games = const [],
  SavedGamesLayout layout = SavedGamesLayout.grid,
  List<Override> overrides = const [],
}) {
  final web = FakeWebViewPlatform();
  WebViewPlatform.instance = web;
  final store = MemorySavedWebGamesStore(SavedGamesState(games: games, layout: layout));
  final sound = SilentSoundService();
  final haptics = RecordingHaptics();
  Fx.install(FeedbackService(sound, haptics));
  var ids = 0;
  final env = SavedGamesEnv(
    store: store,
    web: web,
    session: FakeSessionPlatform(),
    opener: FakeLinkOpener(),
    fetcher: FakeMetaFetcher(),
    cleaner: FakeCleaner(),
    sound: sound,
  );
  final arabic = locale.languageCode == 'ar';
  final app = ProviderScope(
    overrides: [
      soundServiceProvider.overrideWithValue(sound),
      hapticsServiceProvider.overrideWithValue(haptics),
      savedWebGamesStoreProvider.overrideWithValue(store),
      gameMetaFetcherProvider.overrideWithValue(env.fetcher),
      gameSessionPlatformProvider.overrideWithValue(env.session),
      gameLinkOpenerProvider.overrideWithValue(env.opener),
      gameWebDataCleanerProvider.overrideWithValue(env.cleaner),
      savedGamesClockProvider.overrideWithValue(() => savedGamesTestNow),
      savedGamesIdProvider.overrideWithValue(() => 'new-${ids++}'),
      ...overrides,
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildMadarTheme(theme, arabic: arabic),
      locale: locale,
      supportedLocales: L10n.supportedLocales,
      localizationsDelegates: L10n.localizationsDelegates,
      builder: (context, child) => MadarFormatScope(
        digits: DigitStyle.auto,
        child: MotionScope(reduced: false, child: CelebrationOverlay(child: child!)),
      ),
      home: home,
    ),
  );
  return (app, env);
}

/// Pumps [n] 50 ms frames.
Future<void> frames(WidgetTester tester, [int n = 16]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Phone-sized surface.
void usePhone(WidgetTester tester) {
  tester.view.physicalSize = const Size(412, 915) * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
}

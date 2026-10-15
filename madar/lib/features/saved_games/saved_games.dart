/// Saved Games: web games the user adds by link and plays full screen in
/// an in-app browser FROM THEIR ORIGINAL LINK. Madar never copies or
/// bundles third-party game code; it stores only a small record per game
/// (bounded JSON in the encrypted key/value table, key `savedGames.v1`).
///
/// * [SavedGamesShelf] – cinema-style shelf for the Madar Cinema hall.
/// * [SavedGamesScreen] – all games (poster grid / reorderable list, empty
///   state explaining how to add e.g. a claude.ai artifact link).
/// * [SavedGamePlayerScreen] – the immersive player
///   (`SavedGamePlayerScreen.route(game)`).
/// * [SavedGamesActions] – add / edit / delete-with-undo / play / clear data.
///
/// Network: only when the user opens a game, or taps "Fetch title" /
/// "Site icon". Sound: the player follows the app's prayer mute
/// (`prayerMuteProvider`); no extra wiring is needed. During prayer a game
/// stays paused in place only when Madar's audio tracker ran before the
/// page's own scripts and reaches every frame; otherwise it is unloaded
/// and reloaded after prayer (certain silence).
///
/// While something opaque covers the player (a pushed page, or the adhan –
/// `AdhanHost` stops the tickers beneath it) the phone gets Madar's normal
/// screen back (portrait, system bars, screen may sleep) and the game is
/// hushed; both return when it is uncovered.
///
/// Host integration (Android, recommended): answer the
/// `app.madar.orbit/saved_games` method channel, finding the view with
/// `WebViewFlutterAndroidExternalApi.getWebView(engine, id)`:
/// * `keepScreenOn {on: bool}` – use `FlutterView.keepScreenOn`, not the
///   window flag (the adhan's lock-screen mode owns that flag);
/// * `pauseWebView {id}` / `resumeWebView {id}` – `onPause()` +
///   `pauseTimers()` / `resumeTimers()` + `onResume()`; answer `true`;
/// * `hardenWebView {id}` – `settings.setSupportMultipleWindows(false)` and
///   `setJavaScriptCanOpenWindowsAutomatically(false)` (the plugin turns
///   both on: every `window.open` would create a native WebView), and wrap
///   its `WebViewClient` (API 26+: `webView.webViewClient`) so that
///   `onRenderProcessGone` returns true and invokes `rendererGone {id}` on
///   this channel – without it Android kills the whole app when a game's
///   renderer crashes or is reclaimed for memory.
/// Without the host the player still works: the screen may dim, in-place
/// muting stays in-page only, and a renderer crash takes the app down.
library;

export 'data/game_meta_fetcher.dart' show GameMetaFetcher, HttpGameMetaFetcher;
export 'data/game_platform.dart'
    show
        GameLinkOpener,
        GameSessionPlatform,
        SystemGameSessionPlatform,
        UrlLauncherGameLinkOpener,
        madarAppOrientations,
        orientationsFor,
        savedGamesHostChannel;
export 'data/saved_games_providers.dart';
export 'data/saved_web_games_store.dart';
export 'domain/game_url.dart' show GameUrlCheck, GameUrlError, isClaudeArtifactUrl, validateGameUrl;
export 'domain/navigation_policy.dart' show GameOrigins, NavigationVerdict, decideGameNavigation, maxAdoptedOrigins;
export 'domain/saved_web_game.dart' show GameArt, GameOrientation, SavedGamesLayout, SavedGamesLimits, SavedWebGame;
export 'presentation/game_editor_sheet.dart' show showGameEditorSheet;
export 'presentation/game_player_screen.dart' show SavedGamePlayerScreen;
export 'presentation/saved_games_screen.dart' show SavedGamesScreen;
export 'presentation/saved_games_shelf.dart' show SavedGamesShelf;
export 'presentation/saved_games_ui.dart' show SavedGamesActions, savedGamesLinkExample;

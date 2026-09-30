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
/// (`prayerMuteProvider`); no extra wiring is needed.
///
/// Host integration (Android, optional but recommended): answer the
/// `app.madar/saved_games` method channel – `keepScreenOn {on: bool}`,
/// `pauseWebView {id: int}` / `resumeWebView {id: int}` (via
/// `WebViewFlutterAndroidExternalApi.getWebView`). Without it the player
/// still works; the screen may dim and in-place muting stays in-page only.
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
export 'domain/game_url.dart';
export 'domain/navigation_policy.dart';
export 'domain/saved_web_game.dart';
export 'presentation/game_editor_sheet.dart' show showGameEditorSheet;
export 'presentation/game_player_screen.dart' show SavedGamePlayerScreen;
export 'presentation/saved_games_screen.dart' show SavedGamesScreen;
export 'presentation/saved_games_shelf.dart' show SavedGamesShelf;
export 'presentation/saved_games_ui.dart' show SavedGamesActions, savedGamesLinkExample;

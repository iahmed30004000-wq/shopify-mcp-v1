import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/db/repositories/repositories.dart';
import 'game_meta_fetcher.dart';
import 'game_platform.dart';
import 'saved_web_games_store.dart';

/// The user's saved web games (encrypted key/value table).
final savedWebGamesStoreProvider = Provider<SavedWebGamesStore>(
  (ref) => KvSavedWebGamesStore(ref.watch(repositoriesProvider).keyValues),
);

/// Live list + layout.
final savedWebGamesProvider = StreamProvider<SavedGamesState>((ref) => ref.watch(savedWebGamesStoreProvider).watch());

/// Title / icon fetch – used only when the user taps "Fetch title" or
/// "Site icon".
final gameMetaFetcherProvider = Provider<GameMetaFetcher>((ref) => HttpGameMetaFetcher());

/// Immersive mode, orientation lock, keep-screen-on, native WebView pause.
final gameSessionPlatformProvider = Provider<GameSessionPlatform>((ref) => const SystemGameSessionPlatform());

/// Opens a confirmed outside link in the user's browser.
final gameLinkOpenerProvider = Provider<GameLinkOpener>((ref) => const UrlLauncherGameLinkOpener());

/// Clears what ALL web games stored (cookies, storage, cache). Only Saved
/// Games uses a WebView in Madar, so nothing else is touched.
final gameWebDataCleanerProvider = Provider<GameWebDataCleaner>((ref) => const WebViewGameDataCleaner());

final savedGamesClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

final savedGamesIdProvider = Provider<String Function()>(
  (ref) =>
      () => const Uuid().v4(),
);

abstract interface class GameWebDataCleaner {
  Future<bool> clearAll();
}

class WebViewGameDataCleaner implements GameWebDataCleaner {
  const WebViewGameDataCleaner();

  @override
  Future<bool> clearAll() async {
    var ok = true;
    try {
      await WebViewCookieManager().clearCookies();
    } on Object {
      ok = false;
    }
    try {
      final web = WebViewController();
      await web.clearLocalStorage();
      await web.clearCache();
    } on Object {
      ok = false;
    }
    return ok;
  }
}

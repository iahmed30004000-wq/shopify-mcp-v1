import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'saved_game.dart';

/// Opens a saved web game from its ORIGINAL link, full screen, in an in-app
/// browser (Android Custom Tabs via url_launcher). Owner: hall – may be
/// upgraded to an embedded full-screen WebView later (that needs a new
/// dependency, coordinated with the app shell).
abstract interface class SavedGameLauncher {
  /// Returns false when nothing could open the link.
  Future<bool> open(SavedGame game);
}

class UrlSavedGameLauncher implements SavedGameLauncher {
  const UrlSavedGameLauncher();

  @override
  Future<bool> open(SavedGame game) async {
    try {
      if (await launchUrl(game.url, mode: LaunchMode.inAppBrowserView)) return true;
      return await launchUrl(game.url, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}

final savedGameLauncherProvider = Provider<SavedGameLauncher>((ref) => const UrlSavedGameLauncher());

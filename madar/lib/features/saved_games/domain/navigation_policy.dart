import 'package:flutter/foundation.dart';

/// What the in-app browser does with a navigation a game page asks for.
enum NavigationVerdict {
  /// Load it inside the game view.
  allow,

  /// Load it and treat its origin as the game's from now on (the saved
  /// link redirected elsewhere while it was first loading, e.g.
  /// `example.com` → `www.example.com`).
  adopt,

  /// Leave the game's origin: ask the user, then open it in the external
  /// browser (never inside Madar).
  askExternal,

  /// Refuse silently (dangerous or meaningless scheme).
  block,
}

/// Why the game's sound is being silenced.
enum HushReason {
  /// The app's adhan / prayer mute (`PrayerMuteController`) is on.
  prayer,

  /// The user tapped Mute in the floating control.
  user,

  /// Madar left the foreground.
  background,
}

/// How the game is silenced.
enum HushPlan {
  /// Pause/mute its media in place and resume the same state afterwards.
  inPlace,

  /// Unload the page (guaranteed silence) and load it again afterwards.
  unload,
}

/// Most origins a game may adopt during its first load (redirect chain).
const int maxAdoptedOrigins = 3;

/// `scheme://host[:port]` of [uri] with the default port dropped, or null
/// when [uri] has no network origin (`data:`, `about:`, …).
String? originOf(Uri uri) {
  final scheme = uri.scheme.toLowerCase();
  if (scheme != 'https' && scheme != 'http') return null;
  if (uri.host.isEmpty) return null;
  final host = uri.host.toLowerCase();
  final port = uri.hasPort && uri.port != (scheme == 'https' ? 443 : 80) ? ':${uri.port}' : '';
  return '$scheme://$host$port';
}

/// The origins a game may navigate within: the saved link's own origin plus
/// any it adopted while it was first loading.
@immutable
class GameOrigins {
  GameOrigins(Uri home) : home = originOf(home) ?? '', adopted = const {};

  const GameOrigins._(this.home, this.adopted);

  final String home;
  final Set<String> adopted;

  bool contains(Uri uri) {
    final o = originOf(uri);
    return o != null && (o == home || adopted.contains(o));
  }

  bool get canAdopt => adopted.length < maxAdoptedOrigins;

  GameOrigins adopt(Uri uri) {
    final o = originOf(uri);
    if (o == null || o == home || adopted.contains(o) || !canAdopt) return this;
    return GameOrigins._(home, {...adopted, o});
  }

  @override
  bool operator ==(Object other) => other is GameOrigins && other.home == home && setEquals(other.adopted, adopted);

  @override
  int get hashCode => Object.hash(home, Object.hashAllUnordered(adopted));
}

/// Decides a navigation request of a game page (pure; see the tests).
///
/// Main frame (what the user sees):
/// * `https` within [origins] → [NavigationVerdict.allow];
/// * `https` elsewhere while the game is still on its [initialLoad] (a
///   redirect of the saved link) → [NavigationVerdict.adopt] (at most
///   [maxAdoptedOrigins]);
/// * any other `https`/`http` link → [NavigationVerdict.askExternal] (http is
///   never loaded inside Madar);
/// * `about:blank` / `about:srcdoc` → allow; everything else (`javascript:`,
///   `data:`, `blob:`, `file:`, `content:`, `intent:`, `market:`, `mailto:`,
///   `tel:`…) → [NavigationVerdict.block].
///
/// Sub-frames (embedded content, e.g. the sandbox frame of a Claude
/// artifact): `https`, `about:blank`/`about:srcdoc`, `data:` and `blob:`
/// are allowed; anything else is blocked.
NavigationVerdict decideGameNavigation({
  required GameOrigins origins,
  required String target,
  required bool isMainFrame,
  bool initialLoad = false,
}) {
  final Uri uri;
  try {
    uri = Uri.parse(target.trim());
  } on FormatException {
    return NavigationVerdict.block;
  }
  final scheme = uri.scheme.toLowerCase();
  final aboutPage = scheme == 'about' && (uri.path == 'blank' || uri.path == 'srcdoc');
  if (!isMainFrame) {
    if (scheme == 'https' && uri.host.isNotEmpty && uri.userInfo.isEmpty) return NavigationVerdict.allow;
    if (aboutPage || scheme == 'data' || scheme == 'blob') return NavigationVerdict.allow;
    return NavigationVerdict.block;
  }
  if (aboutPage) return NavigationVerdict.allow;
  if (scheme != 'https' && scheme != 'http') return NavigationVerdict.block;
  if (uri.host.isEmpty || uri.userInfo.isNotEmpty) return NavigationVerdict.block;
  if (scheme == 'https' && origins.contains(uri)) return NavigationVerdict.allow;
  if (scheme == 'https' && initialLoad && origins.canAdopt) return NavigationVerdict.adopt;
  return NavigationVerdict.askExternal;
}

/// How to silence a game for [reason]. [sealedFrames] is the number of
/// cross-origin frames the in-page hush could not reach (null: the hush
/// could not run at all).
///
/// Prayer requires certain silence: when any sound source is out of reach
/// the page is unloaded (and reloaded after). A user mute or leaving the
/// app never throws the game's state away.
HushPlan planHush({required HushReason reason, required int? sealedFrames}) {
  if (reason != HushReason.prayer) return HushPlan.inPlace;
  return sealedFrames == 0 ? HushPlan.inPlace : HushPlan.unload;
}

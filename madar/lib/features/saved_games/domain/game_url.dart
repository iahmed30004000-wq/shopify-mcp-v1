import 'package:flutter/foundation.dart';

/// Why a typed or shared link cannot be saved as a game.
enum GameUrlError {
  /// Nothing was entered.
  empty,

  /// Longer than `SavedGamesLimits.maxUrl`.
  tooLong,

  /// `http:` – only secure links are accepted (offer the https version).
  notHttps,

  /// Any other scheme: `javascript:`, `data:`, `file:`, `intent:`,
  /// `content:`, `about:`, `blob:`, `mailto:`, `ftp:`…
  unsupportedScheme,

  /// No usable host, spaces, broken syntax.
  malformed,

  /// `https://user:pass@host` – never stored (and a phishing pattern:
  /// `https://claude.ai@evil.example`).
  credentials,
}

/// Result of [validateGameUrl]: exactly one of [url] / [error] is set.
@immutable
class GameUrlCheck {
  const GameUrlCheck.ok(Uri this.url) : error = null;
  const GameUrlCheck.invalid(GameUrlError this.error) : url = null;

  final Uri? url;
  final GameUrlError? error;

  bool get isValid => url != null;

  @override
  bool operator ==(Object other) => other is GameUrlCheck && other.url == url && other.error == error;

  @override
  int get hashCode => Object.hash(url, error);

  @override
  String toString() => isValid ? 'GameUrlCheck.ok($url)' : 'GameUrlCheck.invalid($error)';
}

/// Longest accepted link (mirrors `SavedGamesLimits.maxUrl`).
const int _maxUrl = 2048;

final RegExp _schemePrefix = RegExp(r'^([A-Za-z][A-Za-z0-9+.\-]*):');
final RegExp _whitespace = RegExp(r'\s');
final RegExp _hostLabel = RegExp(r'^(?!-)[a-z0-9-]{1,63}(?<!-)$');
final RegExp _ipv4 = RegExp(r'^\d{1,3}(\.\d{1,3}){3}$');
final RegExp _sharedUrl = RegExp(r'''https?://[^\s<>"'`]+''', caseSensitive: false);
const String _trailingPunctuation = '.,;:!?)]}\'"»”’،؛؟…';

/// Checks a link the user typed, pasted or shared and returns it
/// normalised (lower-case scheme and host, no default port, `/` path), or
/// why it was refused.
///
/// * Only `https` is accepted; `http` is refused as [GameUrlError.notHttps]
///   and every other scheme as [GameUrlError.unsupportedScheme].
/// * A bare host (`claude.ai/public/artifacts/…`) gets `https://`.
/// * Shared text around the link ("Try this: https://…!") is ignored.
GameUrlCheck validateGameUrl(String input) {
  var text = input.trim();
  if (text.isEmpty) return const GameUrlCheck.invalid(GameUrlError.empty);
  text = linkFromText(text);
  if (text.length > _maxUrl) return const GameUrlCheck.invalid(GameUrlError.tooLong);
  if (_whitespace.hasMatch(text)) return const GameUrlCheck.invalid(GameUrlError.malformed);

  if (text.startsWith('//')) {
    text = 'https:$text';
  } else {
    final m = _schemePrefix.firstMatch(text);
    // "example.com:8443/x" is a host with a port, not a scheme.
    final hostWithPort = m != null && RegExp(r'^\d+(?:[/?#]|$)').hasMatch(text.substring(m.end));
    if (m == null || hostWithPort) {
      text = 'https://$text';
    } else {
      final scheme = m.group(1)!.toLowerCase();
      if (scheme == 'http') return const GameUrlCheck.invalid(GameUrlError.notHttps);
      if (scheme != 'https') return const GameUrlCheck.invalid(GameUrlError.unsupportedScheme);
      if (!text.substring(m.end).startsWith('//')) return const GameUrlCheck.invalid(GameUrlError.malformed);
    }
  }

  final Uri uri;
  try {
    uri = Uri.parse(text);
  } on FormatException {
    return const GameUrlCheck.invalid(GameUrlError.malformed);
  }
  if (uri.scheme.toLowerCase() != 'https') return const GameUrlCheck.invalid(GameUrlError.unsupportedScheme);
  if (uri.userInfo.isNotEmpty || text.substring(0, _authorityEnd(text)).contains('@')) {
    return const GameUrlCheck.invalid(GameUrlError.credentials);
  }
  final host = uri.host.toLowerCase();
  if (!isValidGameHost(host)) return const GameUrlCheck.invalid(GameUrlError.malformed);
  if (uri.hasPort && (uri.port <= 0 || uri.port > 65535)) return const GameUrlCheck.invalid(GameUrlError.malformed);

  final normalised = Uri(
    scheme: 'https',
    host: host,
    port: uri.hasPort && uri.port != 443 ? uri.port : null,
    path: uri.path.isEmpty ? '/' : uri.path,
    query: uri.hasQuery ? uri.query : null,
    fragment: uri.hasFragment ? uri.fragment : null,
  );
  final out = normalised.toString();
  if (out.length > _maxUrl) return const GameUrlCheck.invalid(GameUrlError.tooLong);
  return GameUrlCheck.ok(normalised);
}

/// Index just past the authority of an absolute `scheme://authority/…`.
int _authorityEnd(String text) {
  final start = text.indexOf('//');
  if (start < 0) return text.length;
  for (var i = start + 2; i < text.length; i++) {
    final c = text[i];
    if (c == '/' || c == '?' || c == '#') return i;
  }
  return text.length;
}

/// A DNS name with at least two labels (`claude.ai`), or an IPv4 / IPv6
/// literal. Refuses `localhost`, empty labels and odd characters.
bool isValidGameHost(String host) {
  if (host.isEmpty || host.length > 253) return false;
  if (host.startsWith('[') && host.endsWith(']')) return host.length > 2;
  if (_ipv4.hasMatch(host)) return host.split('.').every((p) => int.parse(p) <= 255);
  final labels = host.split('.');
  if (labels.length < 2) return false;
  if (!labels.every(_hostLabel.hasMatch)) return false;
  // The top-level label is never all digits.
  return !RegExp(r'^\d+$').hasMatch(labels.last);
}

/// The first `http(s)://…` link inside shared text, without the sentence
/// punctuation that often follows it; null when there is none.
String? extractSharedUrl(String text) {
  final m = _sharedUrl.firstMatch(text);
  if (m == null) return null;
  var url = m.group(0)!;
  while (url.isNotEmpty && _trailingPunctuation.contains(url[url.length - 1])) {
    // Keep a closing bracket that belongs to the link itself ("a_(b)").
    if (url.endsWith(')') && '('.allMatches(url).length >= ')'.allMatches(url).length) break;
    url = url.substring(0, url.length - 1);
  }
  return url;
}

/// The link inside [text]: [text] itself when it is one token (so
/// `blob:https://…` stays a blob link), else the first http(s) link of a
/// shared sentence.
String linkFromText(String text) {
  final t = text.trim();
  if (!_whitespace.hasMatch(t)) return t;
  return extractSharedUrl(t) ?? t;
}

/// The same link with `https` instead of `http` (the "Use https" fix), or
/// null when [input] is not an http link.
String? httpsVersionOf(String input) {
  final text = linkFromText(input);
  final m = _schemePrefix.firstMatch(text);
  if (m == null || m.group(1)!.toLowerCase() != 'http') return null;
  return 'https${text.substring(m.end - 1)}';
}

/// Whether [url] is a published Claude artifact (for a friendly badge only;
/// every https site is accepted the same way).
bool isClaudeArtifactUrl(Uri url) {
  final host = url.host.toLowerCase();
  if (host == 'claude.site' || host.endsWith('.claude.site')) return true;
  final claude = host == 'claude.ai' || host.endsWith('.claude.ai');
  return claude && url.pathSegments.contains('artifacts');
}

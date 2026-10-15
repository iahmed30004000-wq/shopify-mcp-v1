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

  // An Arabic domain name (مثال.السعودية) becomes its punycode form, the
  // one the browser loads; any other non-ASCII host stays refused below.
  final ascii = _asciiAuthority(text);
  if (ascii == null) return const GameUrlCheck.invalid(GameUrlError.malformed);
  text = ascii;

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
/// literal. Refuses the phone itself (`localhost`, `127.x.x.x`,
/// `0.x.x.x`), empty labels and odd characters.
bool isValidGameHost(String host) {
  if (host.isEmpty || host.length > 253) return false;
  if (host.startsWith('[') && host.endsWith(']')) return host.length > 2;
  if (_ipv4.hasMatch(host)) {
    final parts = host.split('.').map(int.parse).toList();
    if (parts.any((p) => p > 255)) return false;
    return parts.first != 127 && parts.first != 0;
  }
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

// ── Arabic domain names (IDN) ──────────────────────────────────────────────

/// [text] (`https://…`) with a non-ASCII host turned into punycode, [text]
/// itself when the host is ASCII, or null when the host is not a name Madar
/// can show safely: only labels of Arabic letters (with digits and hyphens)
/// are converted, so a Latin look-alike (`сlaude.ai`, full-width letters)
/// is refused rather than loaded.
String? _asciiAuthority(String text) {
  const prefix = 'https://';
  if (!text.startsWith(prefix)) return text;
  final end = _authorityEnd(text);
  final authority = text.substring(prefix.length, end);
  if (!authority.runes.any((c) => c > 0x7F)) return text;
  // Credentials are refused later from the raw text; never convert them.
  if (authority.contains('@')) return text;
  final port = RegExp(r':\d*$').firstMatch(authority);
  final host = port == null ? authority : authority.substring(0, port.start);
  final labels = <String>[];
  for (final label in host.split('.')) {
    if (!label.runes.any((c) => c > 0x7F)) {
      labels.add(label.toLowerCase());
      continue;
    }
    if (!isArabicDomainLabel(label)) return null;
    labels.add('xn--${punycodeEncode(label)}');
  }
  return '$prefix${labels.join('.')}${port?.group(0) ?? ''}${text.substring(end)}';
}

bool _isArabicLetter(int c) =>
    (c >= 0x0621 && c <= 0x063A) ||
    (c >= 0x0641 && c <= 0x064A) ||
    (c >= 0x066E && c <= 0x066F) ||
    (c >= 0x0671 && c <= 0x0673) ||
    (c >= 0x0679 && c <= 0x06D3) ||
    c == 0x06D5 ||
    (c >= 0x06EE && c <= 0x06EF) ||
    (c >= 0x06FA && c <= 0x06FC) ||
    c == 0x06FF;

/// A domain label written in Arabic script: starts with an Arabic letter,
/// then Arabic letters, one kind of digits (0-9, ٠-٩ or ۰-۹) and hyphens.
/// No Latin letters, harakat, tatweel or presentation forms (look-alikes and
/// names no registry issues).
bool isArabicDomainLabel(String label) {
  final cps = label.runes.toList();
  if (cps.isEmpty || cps.length > 63 || !_isArabicLetter(cps.first)) return false;
  if (cps.last == 0x2D) return false;
  var digitKinds = 0;
  for (final c in cps) {
    if (_isArabicLetter(c) || c == 0x2D) continue;
    final kind = c >= 0x30 && c <= 0x39
        ? 1
        : c >= 0x0660 && c <= 0x0669
        ? 2
        : c >= 0x06F0 && c <= 0x06F9
        ? 4
        : 0;
    if (kind == 0) return false;
    digitKinds |= kind;
  }
  return digitKinds == 0 || digitKinds == 1 || digitKinds == 2 || digitKinds == 4;
}

/// The host of [url] as the user should read it: an Arabic domain name in
/// Arabic, every other host as it is (punycode stays punycode, so a
/// look-alike of a Latin name is never rendered as that name).
String displayHost(Uri url) {
  final host = url.host;
  if (!host.contains('xn--')) return host;
  final shown = <String>[];
  for (final label in host.split('.')) {
    if (!label.startsWith('xn--')) {
      shown.add(label);
      continue;
    }
    final decoded = punycodeDecode(label.substring(4));
    if (decoded == null || !isArabicDomainLabel(decoded) || punycodeEncode(decoded) != label.substring(4)) {
      return host;
    }
    shown.add(decoded);
  }
  return shown.join('.');
}

// Punycode (RFC 3492), for single labels.
const int _pBase = 36, _pTMin = 1, _pTMax = 26, _pSkew = 38, _pDamp = 700, _pBias = 72, _pN = 128;

int _pDigit(int d) => d < 26 ? 0x61 + d : 0x16 + d;

int _pValue(int c) => c >= 0x30 && c <= 0x39
    ? c - 0x16
    : c >= 0x41 && c <= 0x5A
    ? c - 0x41
    : c >= 0x61 && c <= 0x7A
    ? c - 0x61
    : -1;

int _pThreshold(int k, int bias) => k <= bias ? _pTMin : (k >= bias + _pTMax ? _pTMax : k - bias);

int _pAdapt(int delta, int points, bool first) {
  var d = first ? delta ~/ _pDamp : delta ~/ 2;
  d += d ~/ points;
  var k = 0;
  while (d > ((_pBase - _pTMin) * _pTMax) ~/ 2) {
    d ~/= _pBase - _pTMin;
    k += _pBase;
  }
  return k + (_pBase - _pTMin + 1) * d ~/ (d + _pSkew);
}

/// The punycode of [label] (without the `xn--` prefix).
String punycodeEncode(String label) {
  final cps = label.runes.toList();
  final out = StringBuffer();
  for (final c in cps) {
    if (c < 0x80) out.writeCharCode(c);
  }
  final basic = out.length;
  var handled = basic;
  if (basic > 0) out.write('-');
  var n = _pN, delta = 0, bias = _pBias;
  while (handled < cps.length) {
    var m = 0x110000;
    for (final c in cps) {
      if (c >= n && c < m) m = c;
    }
    delta += (m - n) * (handled + 1);
    n = m;
    for (final c in cps) {
      if (c < n) delta++;
      if (c != n) continue;
      var q = delta;
      for (var k = _pBase; ; k += _pBase) {
        final t = _pThreshold(k, bias);
        if (q < t) break;
        out.writeCharCode(_pDigit(t + (q - t) % (_pBase - t)));
        q = (q - t) ~/ (_pBase - t);
      }
      out.writeCharCode(_pDigit(q));
      bias = _pAdapt(delta, handled + 1, handled == basic);
      delta = 0;
      handled++;
    }
    delta++;
    n++;
  }
  return out.toString();
}

/// The label a punycode string (without `xn--`) stands for, or null when it
/// is not valid punycode.
String? punycodeDecode(String input) {
  if (input.isEmpty || input.length > 63) return null;
  final out = <int>[];
  final b = input.lastIndexOf('-');
  if (b > 0) {
    for (var j = 0; j < b; j++) {
      final c = input.codeUnitAt(j);
      if (c >= 0x80) return null;
      out.add(c);
    }
  }
  var at = b > 0 ? b + 1 : 0;
  var n = _pN, i = 0, bias = _pBias;
  while (at < input.length) {
    final old = i;
    var w = 1;
    for (var k = _pBase; ; k += _pBase) {
      if (at >= input.length) return null;
      final d = _pValue(input.codeUnitAt(at++));
      if (d < 0) return null;
      i += d * w;
      if (i > 0x7FFFFFFF) return null;
      final t = _pThreshold(k, bias);
      if (d < t) break;
      w *= _pBase - t;
      if (w > 0x7FFFFFFF) return null;
    }
    bias = _pAdapt(i - old, out.length + 1, old == 0);
    n += i ~/ (out.length + 1);
    i %= out.length + 1;
    if (n > 0x10FFFF || (n >= 0xD800 && n <= 0xDFFF)) return null;
    out.insert(i, n);
    i++;
  }
  return String.fromCharCodes(out);
}

import 'package:flutter/foundation.dart';

import 'saved_web_game.dart';

/// What Madar reads from a game's page when the user taps "Fetch title" or
/// "Site icon": a suggested title and icon candidates (best first).
@immutable
class PageMeta {
  const PageMeta({this.title, this.icons = const []});

  final String? title;

  /// Absolute https icon links, best first.
  final List<Uri> icons;
}

final RegExp _titleTag = RegExp(r'<title\b[^>]*>(.*?)</title\s*>', caseSensitive: false, dotAll: true);
final RegExp _metaTag = RegExp(r'<meta\b[^>]*>', caseSensitive: false);
final RegExp _linkTag = RegExp(r'<link\b[^>]*>', caseSensitive: false);
final RegExp _attribute = RegExp(r'''([a-zA-Z_:][-a-zA-Z0-9_:.]*)\s*=\s*("([^"]*)"|'([^']*)'|([^\s"'=<>`]+))''');
final RegExp _entity = RegExp(r'&(#[0-9]{1,7}|#[xX][0-9a-fA-F]{1,6}|[a-zA-Z]{2,8});');
final RegExp _size = RegExp(r'(\d{1,4})[xX](\d{1,4})');

const Map<String, String> _namedEntities = {
  'amp': '&',
  'lt': '<',
  'gt': '>',
  'quot': '"',
  'apos': "'",
  'nbsp': ' ',
  'ndash': '–',
  'mdash': '—',
  'hellip': '…',
  'laquo': '«',
  'raquo': '»',
  'rsquo': '’',
  'lsquo': '‘',
  'rdquo': '”',
  'ldquo': '“',
  'middot': '·',
  'bull': '•',
  'copy': '©',
  'reg': '®',
  'trade': '™',
};

/// Reads the title and icon links of an HTML document fetched from [base].
///
/// Title priority: `og:title`, `twitter:title`, `<title>`,
/// `application-name`; it is cleaned with [cleanPageTitle]. Icons:
/// `apple-touch-icon` first, then `icon` links by declared size (SVG is
/// skipped: it cannot be decoded), then `/favicon.ico`. Only https links.
PageMeta parsePageMeta(String html, Uri base) {
  // Only the head matters (and bounds the work on huge pages).
  final headEnd = html.toLowerCase().indexOf('</head');
  final head = headEnd > 0 ? html.substring(0, headEnd) : (html.length > 262144 ? html.substring(0, 262144) : html);

  final meta = <String, String>{};
  for (final tag in _metaTag.allMatches(head)) {
    final a = _attributes(tag.group(0)!);
    final key = (a['property'] ?? a['name'])?.toLowerCase();
    final content = a['content'];
    if (key != null && content != null && !meta.containsKey(key)) meta[key] = content;
  }
  final titleTag = _titleTag.firstMatch(head)?.group(1);
  final siteName = meta['og:site_name'];
  String? title;
  for (final candidate in [meta['og:title'], meta['twitter:title'], titleTag, meta['application-name']]) {
    final cleaned = candidate == null ? null : cleanPageTitle(candidate, siteName: siteName);
    if (cleaned != null && cleaned.isNotEmpty) {
      title = cleaned;
      break;
    }
  }

  final ranked = <(int, Uri)>[];
  for (final tag in _linkTag.allMatches(head)) {
    final a = _attributes(tag.group(0)!);
    final rel = (a['rel'] ?? '').toLowerCase().split(RegExp(r'\s+'));
    final href = a['href'];
    if (href == null || href.trim().isEmpty) continue;
    final touch = rel.contains('apple-touch-icon') || rel.contains('apple-touch-icon-precomposed');
    if (!touch && !rel.contains('icon')) continue;
    final type = (a['type'] ?? '').toLowerCase();
    final Uri uri;
    try {
      uri = base.resolve(decodeHtmlEntities(href.trim()));
    } on FormatException {
      continue;
    }
    if (uri.scheme != 'https' || uri.host.isEmpty) continue;
    if (type.contains('svg') || uri.path.toLowerCase().endsWith('.svg')) continue;
    var size = 0;
    for (final m in _size.allMatches(a['sizes'] ?? '')) {
      final s = int.parse(m.group(1)!);
      if (s > size) size = s;
    }
    if (touch && size == 0) size = 180;
    // Prefer icons near 96–192 px; huge ones cost bytes for nothing.
    final score = (touch ? 1000 : 0) + (size == 0 ? 16 : (size > 256 ? 256 - (size - 256) ~/ 4 : size));
    ranked.add((score, uri));
  }
  ranked.sort((a, b) => b.$1.compareTo(a.$1));
  final icons = <Uri>[];
  for (final (_, uri) in ranked) {
    if (!icons.contains(uri)) icons.add(uri);
  }
  if (base.scheme == 'https' && base.host.isNotEmpty) {
    final ico = base.replace(path: '/favicon.ico', query: null, fragment: null);
    final plain = Uri(scheme: ico.scheme, host: ico.host, port: ico.hasPort ? ico.port : null, path: '/favicon.ico');
    if (!icons.contains(plain)) icons.add(plain);
  }
  return PageMeta(title: title, icons: icons.take(6).toList(growable: false));
}

/// A page title fit for a game name: entities decoded, whitespace and
/// unsafe characters removed, a trailing " | Site" dropped when it repeats
/// [siteName], cut to `SavedGamesLimits.maxTitle`.
String? cleanPageTitle(String raw, {String? siteName}) {
  var t = clampText(decodeHtmlEntities(raw.replaceAll(RegExp(r'<[^>]*>'), ' ')), 400);
  if (t.isEmpty) return null;
  final site = siteName == null ? null : clampText(decodeHtmlEntities(siteName), 120);
  if (site != null && site.isNotEmpty) {
    for (final sep in const [' | ', ' – ', ' — ', ' - ', ' · ', ' :: ']) {
      final suffix = '$sep$site';
      if (t.length > suffix.length && t.toLowerCase().endsWith(suffix.toLowerCase())) {
        t = t.substring(0, t.length - suffix.length).trim();
        break;
      }
    }
  }
  t = clampText(t, SavedGamesLimits.maxTitle);
  return t.isEmpty ? null : t;
}

/// Decodes numeric and the common named HTML entities.
String decodeHtmlEntities(String s) => s.replaceAllMapped(_entity, (m) {
  final body = m.group(1)!;
  if (body.startsWith('#')) {
    final hex = body.length > 1 && (body[1] == 'x' || body[1] == 'X');
    final code = int.tryParse(hex ? body.substring(2) : body.substring(1), radix: hex ? 16 : 10);
    if (code == null || code <= 0 || code > 0x10FFFF || (code >= 0xD800 && code <= 0xDFFF)) return '';
    return String.fromCharCode(code);
  }
  return _namedEntities[body.toLowerCase()] ?? m.group(0)!;
});

Map<String, String> _attributes(String tag) {
  final out = <String, String>{};
  for (final m in _attribute.allMatches(tag)) {
    final name = m.group(1)!.toLowerCase();
    out.putIfAbsent(name, () => m.group(3) ?? m.group(4) ?? m.group(5) ?? '');
  }
  return out;
}

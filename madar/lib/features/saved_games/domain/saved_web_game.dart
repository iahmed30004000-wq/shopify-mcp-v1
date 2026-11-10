import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show StringCharacters;

import 'game_url.dart';

/// Screen orientation a game prefers while it plays.
enum GameOrientation { auto, portrait, landscape }

/// How the Saved Games screen lays its games out.
enum SavedGamesLayout { grid, list }

/// Hard bounds of what Madar stores for Saved Games. The store's codec
/// enforces every one of them, on write and on read (the stored JSON is one
/// bounded key/value row).
abstract final class SavedGamesLimits {
  static const int maxGames = 40;
  static const int maxTitle = 80;
  static const int maxNotes = 500;
  static const int maxUrl = 2048;

  /// A site icon is kept as a small PNG (resized to [iconPixels] square).
  static const int maxIconBytes = 16 * 1024;
  static const int iconPixels = 96;

  /// Generated icons: glyph and colour indexes (see `GameArtPalette`).
  static const int glyphCount = 16;
  static const int hueCount = 8;

  static const int maxPlayCount = 999999999;
}

/// The icon of a saved game: an original generated glyph on a colour, or –
/// only after the user explicitly asked for it – the site's own favicon.
@immutable
class GameArt {
  const GameArt({required this.glyph, required this.hue, this.favicon});

  /// A deterministic glyph/colour for [seed] (usually the link).
  factory GameArt.seeded(String seed) {
    final h = fnv1a32(seed);
    return GameArt(glyph: h % SavedGamesLimits.glyphCount, hue: (h ~/ 97) % SavedGamesLimits.hueCount);
  }

  /// Index into the glyph set, 0 ≤ glyph < [SavedGamesLimits.glyphCount].
  final int glyph;

  /// Index into the colour set, 0 ≤ hue < [SavedGamesLimits.hueCount].
  final int hue;

  /// PNG bytes of the site's icon (≤ [SavedGamesLimits.maxIconBytes]).
  final Uint8List? favicon;

  bool get hasFavicon => favicon != null;

  GameArt copyWith({int? glyph, int? hue, Uint8List? favicon, bool clearFavicon = false}) => GameArt(
    glyph: glyph ?? this.glyph,
    hue: hue ?? this.hue,
    favicon: clearFavicon ? null : (favicon ?? this.favicon),
  );

  Map<String, Object?> toJson() => {'glyph': glyph, 'hue': hue, if (favicon != null) 'favicon': base64Encode(favicon!)};

  /// Tolerant: out-of-range indexes wrap, an unreadable or oversized icon is
  /// dropped (the glyph stays).
  factory GameArt.fromJson(Object? json, {required String seed}) {
    final fallback = GameArt.seeded(seed);
    if (json is! Map) return fallback;
    int index(Object? v, int count, int or) => v is int ? v % count : or;
    Uint8List? icon;
    final raw = json['favicon'];
    if (raw is String && raw.length <= (SavedGamesLimits.maxIconBytes * 4 ~/ 3) + 4) {
      try {
        final bytes = base64Decode(raw);
        if (bytes.isNotEmpty && bytes.length <= SavedGamesLimits.maxIconBytes) icon = bytes;
      } on FormatException {
        icon = null;
      }
    }
    return GameArt(
      glyph: index(json['glyph'], SavedGamesLimits.glyphCount, fallback.glyph),
      hue: index(json['hue'], SavedGamesLimits.hueCount, fallback.hue),
      favicon: icon,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is GameArt && other.glyph == glyph && other.hue == hue && listEquals(other.favicon, favicon);

  @override
  int get hashCode => Object.hash(glyph, hue, favicon == null ? 0 : Object.hashAll(favicon!));
}

/// A web game the user saved by its link. Madar stores only this record;
/// the game itself always runs from [url] in the in-app browser – no
/// third-party code is ever copied or bundled.
@immutable
class SavedWebGame {
  const SavedWebGame({
    required this.id,
    required this.title,
    required this.url,
    required this.art,
    required this.addedAt,
    this.notes = '',
    this.orientation = GameOrientation.auto,
    this.lastPlayedAt,
    this.playCount = 0,
    this.clearDataPending = false,
  });

  final String id;
  final String title;

  /// Normalised https link (see [validateGameUrl]).
  final Uri url;
  final String notes;
  final GameOrientation orientation;
  final GameArt art;
  final DateTime addedAt;
  final DateTime? lastPlayedAt;
  final int playCount;

  /// The user asked to clear the site's data; done the next time it opens.
  final bool clearDataPending;

  /// The link's host as the user reads it (an Arabic domain in Arabic).
  String get host => displayHost(url);

  SavedWebGame copyWith({
    String? title,
    Uri? url,
    String? notes,
    GameOrientation? orientation,
    GameArt? art,
    DateTime? lastPlayedAt,
    int? playCount,
    bool? clearDataPending,
  }) => SavedWebGame(
    id: id,
    title: title ?? this.title,
    url: url ?? this.url,
    notes: notes ?? this.notes,
    orientation: orientation ?? this.orientation,
    art: art ?? this.art,
    addedAt: addedAt,
    lastPlayedAt: lastPlayedAt ?? this.lastPlayedAt,
    playCount: playCount ?? this.playCount,
    clearDataPending: clearDataPending ?? this.clearDataPending,
  );

  /// This record with every field clamped to [SavedGamesLimits].
  SavedWebGame bounded() => SavedWebGame(
    id: id,
    title: clampText(title, SavedGamesLimits.maxTitle),
    url: url,
    notes: clampText(notes, SavedGamesLimits.maxNotes, singleLine: false),
    orientation: orientation,
    art: art,
    addedAt: addedAt,
    lastPlayedAt: lastPlayedAt,
    playCount: playCount.clamp(0, SavedGamesLimits.maxPlayCount),
    clearDataPending: clearDataPending,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'url': url.toString(),
    if (notes.isNotEmpty) 'notes': notes,
    'orientation': orientation.name,
    'art': art.toJson(),
    'addedAt': addedAt.toUtc().toIso8601String(),
    if (lastPlayedAt != null) 'lastPlayedAt': lastPlayedAt!.toUtc().toIso8601String(),
    if (playCount > 0) 'playCount': playCount,
    if (clearDataPending) 'clearDataPending': true,
  };

  /// Strict about identity (id, https link, date); lenient about the rest.
  /// Throws [FormatException] when the record cannot be trusted.
  factory SavedWebGame.fromJson(Map<Object?, Object?> json) {
    final id = json['id'];
    if (id is! String || id.isEmpty || id.length > 64) throw const FormatException('id');
    final rawUrl = json['url'];
    if (rawUrl is! String) throw const FormatException('url');
    // Only what the validator accepts today (https, no credentials…).
    final check = validateGameUrl(rawUrl);
    final url = check.url;
    if (url == null || url.toString() != rawUrl) throw const FormatException('url');
    final added = DateTime.tryParse('${json['addedAt']}');
    if (added == null) throw const FormatException('addedAt');
    final title = json['title'];
    final notes = json['notes'];
    final count = json['playCount'];
    return SavedWebGame(
      id: id,
      title: title is String && title.trim().isNotEmpty ? title : displayHost(url),
      url: url,
      notes: notes is String ? notes : '',
      orientation: GameOrientation.values.asNameMap()[json['orientation']] ?? GameOrientation.auto,
      art: GameArt.fromJson(json['art'], seed: rawUrl),
      addedAt: added.toLocal(),
      lastPlayedAt: DateTime.tryParse('${json['lastPlayedAt']}')?.toLocal(),
      playCount: count is int && count > 0 ? count : 0,
      clearDataPending: json['clearDataPending'] == true,
    ).bounded();
  }

  @override
  bool operator ==(Object other) =>
      other is SavedWebGame &&
      other.id == id &&
      other.title == title &&
      other.url == url &&
      other.notes == notes &&
      other.orientation == orientation &&
      other.art == art &&
      other.addedAt == addedAt &&
      other.lastPlayedAt == lastPlayedAt &&
      other.playCount == playCount &&
      other.clearDataPending == clearDataPending;

  @override
  int get hashCode =>
      Object.hash(id, title, url, notes, orientation, art, addedAt, lastPlayedAt, playCount, clearDataPending);

  @override
  String toString() => 'SavedWebGame($id, $title, $url)';
}

/// Trims, removes control and bidi-override characters (untrusted page
/// titles), collapses whitespace (unless [singleLine] is false, where line
/// breaks survive) and cuts to [max] user-perceived characters.
String clampText(String text, int max, {bool singleLine = true}) {
  var s = text.replaceAll(_unsafeChars, '');
  s = singleLine ? s.replaceAll(RegExp(r'\s+'), ' ') : s.replaceAll(RegExp(r'[^\S\n]+'), ' ');
  s = s.trim();
  final chars = s.characters;
  return chars.length <= max ? s : chars.take(max).toString().trimRight();
}

// C0/C1 controls except \n and \t, bidi embeddings/overrides/isolates.
final RegExp _unsafeChars = RegExp(
  '[\\u0000-\\u0008\\u000B-\\u001F\\u007F-\\u009F\\u200E\\u200F\\u202A-\\u202E\\u2066-\\u2069]',
);

/// Stable 32-bit FNV-1a hash (seeds generated art).
int fnv1a32(String s) {
  var h = 0x811c9dc5;
  for (final unit in utf8.encode(s)) {
    h ^= unit;
    h = (h * 0x01000193) & 0xFFFFFFFF;
  }
  return h;
}

/// Limits for everything Together Mode keeps on the device, and the text
/// clean-up applied before anything is stored.
///
/// Pure Dart (no Flutter): shared by the domain, the repository and tests.
library;

/// Persistence bounds. Every stored JSON value stays small no matter how many
/// matches are played: history is a sliding window, per-game tallies are
/// capped (the overall tally keeps counting) and so is the trophy shelf.
abstract final class TogetherBounds {
  /// Player name, in characters (runes).
  static const int maxNameLength = 24;

  /// Custom player title, in characters (runes).
  static const int maxTitleLength = 28;

  /// An avatar emoji (one grapheme, possibly a ZWJ sequence), in UTF-16 units.
  static const int maxEmojiLength = 16;

  /// Matches kept in the head-to-head history (oldest dropped first). The
  /// lifetime tallies in the ledger are not affected by the window.
  static const int maxHistory = 300;

  /// Games with their own tally (the least recently played is dropped).
  static const int maxGames = 64;

  /// Trophies on the shelf.
  static const int maxTrophies = 256;

  /// Ids (match ids, game ids).
  static const int maxIdLength = 64;

  /// Absolute value of a stored score.
  static const int maxScore = 999999999;

  /// A match longer than a day is recorded as a day.
  static const int maxDurationSeconds = 24 * 3600;

  /// Upper bound of any single stored JSON value, in UTF-8 bytes (checked by
  /// the persistence tests with the largest possible content).
  static const int maxStoredBytes = 96 * 1024;

  static final RegExp _id = RegExp(r'^[A-Za-z0-9_\-]{1,64}$');

  // C0/C1 controls, bidi embeddings/overrides/isolates and marks, zero-width
  // spaces, the BOM and line/paragraph separators. ZWJ (U+200D) is kept –
  // emoji sequences and Arabic shaping need it.
  static final RegExp _unsafe = RegExp(
    '[\u0000-\u001F\u007F-\u009F؜​‎‏‪-‮  ⁦-⁩﻿]',
  );
  static final RegExp _spaces = RegExp(r'\s+');

  /// Whether [s] is a valid id (letters, digits, `_`, `-`; 1–64 chars).
  static bool isValidId(String s) => _id.hasMatch(s);

  /// [input] without control / bidi characters, whitespace collapsed,
  /// trimmed and cut to [maxRunes] characters. Null becomes ''.
  static String cleanText(Object? input, int maxRunes) {
    if (input is! String) return '';
    final cleaned = input.replaceAll(_unsafe, '').replaceAll(_spaces, ' ').trim();
    final runes = cleaned.runes;
    if (runes.length <= maxRunes) return cleaned;
    return String.fromCharCodes(runes.take(maxRunes)).trim();
  }

  /// A stored score: an integer within ±[maxScore], else null.
  static int? score(Object? v) {
    if (v is! num || !v.isFinite) return null;
    final i = v.round();
    if (i.abs() > maxScore) return i.sign * maxScore;
    return i;
  }

  /// A non-negative count read from storage (corrupt values become 0).
  static int count(Object? v, {int max = 1 << 40}) {
    if (v is! num || !v.isFinite) return 0;
    final i = v.round();
    if (i < 0) return 0;
    return i > max ? max : i;
  }
}

/// Calendar-day arithmetic in the device's local time zone.
abstract final class TogetherDays {
  static const int _msPerDay = 86400000;

  /// Days since 1970-01-01 of [t]'s local calendar date (DST-proof).
  static int indexOf(DateTime t) {
    final local = t.toLocal();
    return DateTime.utc(local.year, local.month, local.day).millisecondsSinceEpoch ~/ _msPerDay;
  }
}

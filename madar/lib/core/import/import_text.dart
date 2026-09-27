/// Text normalisation used to match prototype keys and values against the
/// importer's alias tables (pure Dart).
library;

import '../domain/money.dart' show MoneyText;

abstract final class ImportText {
  static final RegExp _arabicMarks = RegExp('[ً-ٰٟـۖ-ۭ]');
  static final RegExp _nonKey = RegExp('[^a-z0-9ء-ي%]');
  static final RegExp _nonWord = RegExp('[^a-z0-9ء-ي%]+');

  /// Folds Arabic spelling variants: removes diacritics and tatweel and
  /// unifies alef / hamza / yaa / taa-marbuta forms (`أإآٱ→ا`, `ة→ه`,
  /// `ى→ي`, `ؤ→و`, `ئ→ي`).
  static String foldArabic(String input) {
    final s = input.replaceAll(_arabicMarks, '');
    final out = StringBuffer();
    for (final c in s.codeUnits) {
      out.writeCharCode(switch (c) {
        0x0623 || 0x0625 || 0x0622 || 0x0671 => 0x0627, // أ إ آ ٱ → ا
        0x0629 => 0x0647, // ة → ه
        0x0649 => 0x064A, // ى → ي
        0x0624 => 0x0648, // ؤ → و
        0x0626 => 0x064A, // ئ → ي
        _ => c,
      });
    }
    return out.toString();
  }

  /// Canonical form of a JSON key or alias: digits folded, lower-cased,
  /// Arabic folded, every separator removed (`taken_with`, `takenWith` and
  /// `Taken With` all become `takenwith`) and a leading Arabic article `ال`
  /// dropped when at least three letters remain (`الميزانية` ≡ `ميزانية`).
  static String key(String raw) {
    var s = foldArabic(MoneyText.foldDigits(raw).toLowerCase()).replaceAll(_nonKey, '');
    if (s.length >= 5 && s.startsWith('ال')) s = s.substring(2);
    return s;
  }

  /// Canonical form of a free-text value for word matching: like [key] but
  /// words stay separated by single spaces, and the article is dropped from
  /// every word (`مع الفطور` → `مع فطور`).
  static String words(String raw) {
    final s = foldArabic(MoneyText.foldDigits(raw).toLowerCase()).replaceAll(_nonWord, ' ').trim();
    if (s.isEmpty) return s;
    return s.split(' ').map((w) => w.length >= 5 && w.startsWith('ال') ? w.substring(2) : w).join(' ');
  }

  /// A readable label from a key: `readingList` / `reading_list` →
  /// `Reading list`. Arabic keys are returned trimmed, unchanged.
  static String humanize(String key) {
    final trimmed = key.trim();
    if (trimmed.isEmpty) return trimmed;
    if (RegExp('[؀-ۿ]').hasMatch(trimmed)) return trimmed.replaceAll('_', ' ');
    final spaced = trimmed
        .replaceAllMapped(RegExp('([a-z0-9])([A-Z])'), (m) => '${m[1]} ${m[2]}')
        .replaceAll(RegExp(r'[_\-.]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .toLowerCase();
    return spaced.isEmpty ? trimmed : '${spaced[0].toUpperCase()}${spaced.substring(1)}';
  }

  /// A short id-safe slug (`In progress` → `in-progress`); falls back to
  /// [fallback] when nothing usable remains.
  static String slug(String raw, {String fallback = 'x'}) {
    final s = foldArabic(MoneyText.foldDigits(raw).toLowerCase())
        .replaceAll(RegExp('[^a-z0-9ء-ي]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return s.isEmpty ? fallback : s;
  }

  /// Whether [key] looks like `snake_case`, `camelCase` or Arabic.
  static bool isArabic(String key) => RegExp('[؀-ۿ]').hasMatch(key);
  static bool isSnake(String key) => key.contains('_') || key.contains('-');
  static bool isCamel(String key) => RegExp('[a-z][A-Z]').hasMatch(key);
}

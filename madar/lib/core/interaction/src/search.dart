import '../numbers.dart';

/// Forgiving, Arabic-aware text matching for pickers (pure Dart).
///
/// Folds diacritics, tatweel, alef/yeh/teh-marbuta variants, digits of every
/// script and ASCII case, so "مدرسه" finds "مدرسة" and "احمد" finds "أحمد".
abstract final class KitSearch {
  static final RegExp _marks = RegExp('[\\u064B-\\u065F\\u0670\\u0640\\u06D6-\\u06ED]');
  static final RegExp _spaces = RegExp(r'\s+');

  static String fold(String input) {
    final s = LocalizedNumbers.normalizeDigits(input.replaceAll(_marks, '')).toLowerCase();
    final out = StringBuffer();
    for (final c in s.codeUnits) {
      out.writeCharCode(switch (c) {
        0x0622 || 0x0623 || 0x0625 || 0x0671 => 0x0627, // آ أ إ ٱ → ا
        0x0629 => 0x0647, // ة → ه
        0x0649 || 0x06CC => 0x064A, // ى ی → ي
        0x0624 => 0x0648, // ؤ → و
        0x0626 => 0x064A, // ئ → ي
        0x06A9 => 0x0643, // ک → ك
        _ => c,
      });
    }
    return out.toString().replaceAll(_spaces, ' ').trim();
  }

  /// Whether every word of [query] occurs in one of [fields].
  static bool matches(String query, Iterable<String?> fields) {
    final q = fold(query);
    if (q.isEmpty) return true;
    final haystack = fields.nonNulls.map(fold).join(' ');
    return q.split(' ').every(haystack.contains);
  }
}

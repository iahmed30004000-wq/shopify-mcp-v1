/// Search normalisation: folds Arabic and Latin text into comparable terms
/// and remembers where every folded letter came from (for highlighting).
///
/// Pure Dart – runs on the search isolate.
library;

import 'package:meta/meta.dart';

/// One word of a text, folded for search.
@immutable
class SearchToken {
  const SearchToken(this.term, this.start, this.end, this.position, [this.origins]);

  /// The folded word (see [SearchText]).
  final String term;

  /// Code-unit range of the word in the original text, trailing diacritics
  /// included.
  final int start;
  final int end;

  /// Index of the word in its text (0-based).
  final int position;

  /// For each code unit of [term], the code unit of the original it came
  /// from (only when tokenised with `withOrigins`).
  final List<int>? origins;

  /// The original range of the folded stretch [from, to) of [term] (the
  /// whole word when origins were not kept or the stretch is the whole
  /// term).
  (int, int) rangeOf(int from, int to) {
    final o = origins;
    if (o == null || o.isEmpty || (from <= 0 && to >= term.length)) return (start, end);
    final a = o[from.clamp(0, o.length - 1)];
    final lastIndex = (to - 1).clamp(0, o.length - 1);
    // Up to the next letter of the word (takes in the marks after the last
    // matched letter), or the word's end.
    final b = lastIndex + 1 < o.length ? o[lastIndex + 1] : end;
    return (a, b);
  }

  @override
  String toString() => 'SearchToken($term, $start-$end, #$position)';
}

/// Arabic-aware folding for search.
///
/// * Arabic: diacritics (harakat, shadda, sukun, superscript alef), Quranic
///   annotation signs and tatweel are dropped; every alef form (أ إ آ ٱ) →
///   ا; ى / ی → ي; ة → ه; ؤ → و; ئ → ي; a bare hamza ء is dropped; ک → ك.
/// * Digits: Arabic-Indic (٠-٩) and Persian (۰-۹) digits → 0-9, so «١٢»
///   finds «12» and the other way round.
/// * Latin: lower-cased; accented Latin-1 letters lose their accents (é → e);
///   combining accents are dropped.
/// * Invisible characters (bidi isolates and marks, zero-width joiners, soft
///   hyphen) are dropped without breaking a word.
/// * Words are runs of letters and digits; a word also breaks where Arabic
///   letters meet Latin letters or digits («ص10» → «ص», «10»).
abstract final class SearchText {
  /// Longest folded word kept (longer words are cut; they still match by
  /// prefix).
  static const int maxTermLength = 40;

  /// Dropped inside a word (a mark, tatweel, invisible control).
  static const int _drop = -1;

  /// Ends a word.
  static const int _sep = -2;

  // Latin-1 letters (U+00C0–U+00FF) without accents; '\u0000' = separator.
  static const String _latin1 = 'aaaaaaaceeeeiiiidnooooo\u0000ouuuuytsaaaaaaaceeeeiiiidnooooo\u0000ouuuuyty';

  /// The folded form of one code unit: a code unit, [_drop] or [_sep].
  static int _fold(int c) {
    if (c < 0x80) {
      if (c >= 0x61 && c <= 0x7A) return c; // a-z
      if (c >= 0x41 && c <= 0x5A) return c | 0x20; // A-Z
      if (c >= 0x30 && c <= 0x39) return c; // 0-9
      return _sep;
    }
    if (c >= 0x0600 && c <= 0x06FF) return _foldArabic(c);
    if (c >= 0x08A0 && c <= 0x08FF) return c >= 0x08D3 ? _drop : c; // Arabic Extended-A
    if (c == 0x00AD || (c >= 0x200B && c <= 0x200F) || (c >= 0x202A && c <= 0x202E)) return _drop;
    if ((c >= 0x2060 && c <= 0x2069) || c == 0xFEFF) return _drop;
    if (c >= 0x0300 && c <= 0x036F) return _drop; // combining accents
    if (c >= 0xC0 && c <= 0xFF) {
      final f = _latin1.codeUnitAt(c - 0xC0);
      return f == 0 ? _sep : f;
    }
    if ((c >= 0x0100 && c <= 0x024F) || (c >= 0x0370 && c <= 0x03FF) || (c >= 0x0400 && c <= 0x04FF)) {
      final lower = String.fromCharCode(c).toLowerCase();
      return lower.length == 1 ? lower.codeUnitAt(0) : c;
    }
    if (c >= 0x05D0 && c <= 0x05EA) return c; // Hebrew letters
    if ((c >= 0x3040 && c <= 0x9FFF) || (c >= 0xAC00 && c <= 0xD7AF)) return c; // kana, CJK, Hangul
    if (c >= 0xFB50 && c <= 0xFDFF) return c; // Arabic presentation forms A (kept as is)
    if (c >= 0xFE70 && c <= 0xFEFC) return c; // Arabic presentation forms B
    return _sep;
  }

  static int _foldArabic(int c) {
    if (c >= 0x0660 && c <= 0x0669) return 0x30 + c - 0x0660; // ٠-٩
    if (c >= 0x06F0 && c <= 0x06F9) return 0x30 + c - 0x06F0; // ۰-۹
    if ((c >= 0x064B && c <= 0x065F) || c == 0x0670 || (c >= 0x0610 && c <= 0x061A)) return _drop;
    if (c >= 0x06D6 && c <= 0x06ED) return _drop; // Quranic signs, small letters
    switch (c) {
      case 0x0640: // tatweel
      case 0x061C: // Arabic letter mark
      case 0x0621: // hamza on the line
      case 0x0674: // high hamza
        return _drop;
      case 0x0622 || 0x0623 || 0x0625 || 0x0671 || 0x0672 || 0x0673:
        return 0x0627; // alef forms → ا
      case 0x0624:
        return 0x0648; // ؤ → و
      case 0x0626 || 0x0649 || 0x06CC || 0x06D2 || 0x06D3:
        return 0x064A; // ئ ى ی ے → ي
      case 0x0629 || 0x06C0 || 0x06C1 || 0x06C2 || 0x06C3 || 0x06D5:
        return 0x0647; // ة ۀ ہ → ه
      case 0x06A9:
        return 0x0643; // ک → ك
    }
    if ((c >= 0x0620 && c <= 0x064A) || (c >= 0x066E && c <= 0x06D3) || c >= 0x06EE) return c;
    return _sep; // punctuation: ، ؛ ؟ ٪ ٫ ٬ ۔ …
  }

  /// Whether [c] (a folded code unit) is an Arabic letter.
  static bool isArabic(int c) =>
      (c >= 0x0620 && c <= 0x06FF) || (c >= 0x08A0 && c <= 0x08FF) || (c >= 0xFB50 && c <= 0xFEFC);

  /// The words of [text], folded. With [withOrigins] every token also maps
  /// its folded letters back to the original (for highlights). At most
  /// [maxTokens] words are read.
  static List<SearchToken> tokenize(String text, {bool withOrigins = false, int maxTokens = 1 << 30}) {
    final out = <SearchToken>[];
    if (text.isEmpty) return out;
    final buf = StringBuffer();
    var origins = <int>[];
    var inWord = false;
    var arabicWord = false;
    var start = 0;
    var end = 0;
    var length = 0;

    void flush() {
      if (!inWord) return;
      out.add(SearchToken(buf.toString(), start, end, out.length, withOrigins ? List.unmodifiable(origins) : null));
      buf.clear();
      if (withOrigins) origins = <int>[];
      inWord = false;
      length = 0;
    }

    for (var i = 0; i < text.length; i++) {
      final f = _fold(text.codeUnitAt(i));
      if (f == _drop) {
        if (inWord) end = i + 1; // marks after a letter belong to it
        continue;
      }
      if (f == _sep) {
        flush();
        if (out.length >= maxTokens) break;
        continue;
      }
      final arabic = isArabic(f);
      if (inWord && arabic != arabicWord) {
        flush();
        if (out.length >= maxTokens) break;
      }
      if (!inWord) {
        inWord = true;
        arabicWord = arabic;
        start = i;
      }
      end = i + 1;
      if (length < maxTermLength) {
        buf.writeCharCode(f);
        if (withOrigins) origins.add(i);
        length++;
      }
    }
    if (out.length < maxTokens) flush();
    return out;
  }

  /// The folded words of [text] joined by single spaces (e.g. «الصلاة
  /// على الوقت» → «الصلاه علي الوقت»).
  static String fold(String text) => tokenize(text).map((t) => t.term).join(' ');

  /// The folded words of [text] (terms only).
  static List<String> terms(String text) => [for (final t in tokenize(text)) t.term];

  // Leading definite article, alone or after a one-letter conjunction or
  // preposition (و ف ب ك), and «لل» (li + al).
  static const List<String> _articles = ['وال', 'فال', 'بال', 'كال', 'ال', 'لل'];

  /// Shortest word left after taking off an article.
  static const int minStemLength = 3;

  /// [term] without its definite article («الكتاب» / «والكتاب» → «كتاب»),
  /// or null when it has none (or too little would be left).
  static String? stem(String term) {
    if (term.length < minStemLength + 2 || !isArabic(term.codeUnitAt(0))) return null;
    for (final p in _articles) {
      if (term.startsWith(p) && term.length - p.length >= minStemLength) return term.substring(p.length);
    }
    return null;
  }

  /// Whether [a] and [b] differ by at most one edit (insert, delete,
  /// substitute, or swap of two neighbouring letters).
  static bool withinOneEdit(String a, String b) => _oneEdit(a, 0, a.length, b, 0, b.length);

  /// Whether [query] is within one edit of a prefix of [term] (a typo in a
  /// word still being typed: «medicaton» → «medications»).
  static bool prefixWithinOneEdit(String query, String term) {
    final n = query.length;
    for (final len in [n, n + 1, n - 1]) {
      if (len < 1 || len > term.length) continue;
      if (_oneEdit(query, 0, n, term, 0, len)) return true;
    }
    return false;
  }

  static bool _oneEdit(String a, int as, int al, String b, int bs, int bl) {
    final diff = al - bl;
    if (diff > 1 || diff < -1) return false;
    var i = 0;
    while (i < al && i < bl && a.codeUnitAt(as + i) == b.codeUnitAt(bs + i)) {
      i++;
    }
    if (i == al && i == bl) return true; // identical
    if (diff == 0) {
      // Substitution: the rest must match.
      if (_same(a, as + i + 1, b, bs + i + 1, al - i - 1)) return true;
      // Swap of neighbours.
      return i + 1 < al &&
          a.codeUnitAt(as + i) == b.codeUnitAt(bs + i + 1) &&
          a.codeUnitAt(as + i + 1) == b.codeUnitAt(bs + i) &&
          _same(a, as + i + 2, b, bs + i + 2, al - i - 2);
    }
    if (diff == 1) return _same(a, as + i + 1, b, bs + i, bl - i); // a has an extra letter
    return _same(a, as + i, b, bs + i + 1, al - i); // b has an extra letter
  }

  static bool _same(String a, int as, String b, int bs, int len) {
    for (var k = 0; k < len; k++) {
      if (a.codeUnitAt(as + k) != b.codeUnitAt(bs + k)) return false;
    }
    return true;
  }
}

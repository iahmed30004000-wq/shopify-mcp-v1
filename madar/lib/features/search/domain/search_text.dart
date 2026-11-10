/// Search normalisation: folds Arabic and Latin text into comparable terms
/// and remembers where every folded letter came from (for highlighting).
///
/// Pure Dart – runs on the search isolate.
library;

import 'package:meta/meta.dart';

/// One word of a text, folded for search.
@immutable
class SearchToken {
  const SearchToken(this.term, this.start, this.end, this.position, [this.origins, this.hamzaAlefs = 0, this.ending = 0]);

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

  /// Bit k set: letter k of [term] (k < 8) was an alef carrying a hamza or
  /// a madda (أ إ آ) in the original. The definite article's alef never
  /// does, so «إلهام» is not «ال» + «هام».
  final int hamzaAlefs;

  /// How the word's last letter was spelled when it folds to ي or ه:
  /// [SearchText.endingPlain] (ي / ه), [SearchText.endingMarked] (ى / ة),
  /// or 0.
  final int ending;

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
///   ا; ى / ی → ي; ة → ه; ؤ → و; ئ → ي; ک → ك. A hamza on the line ء is
///   kept: «غداء» (lunch) is not «غداً» (tomorrow), «دواء» is not the start
///   of «دوام». A query typed without it still finds it (see
///   [dropHamza]).
/// * Digits: Arabic-Indic (٠-٩) and Persian (۰-۹) digits → 0-9, so «١٢»
///   finds «12» and the other way round. An amount stays one word across
///   its separators: grouping (, ٬) is dropped and the decimal point (. ٫)
///   kept as «.», without trailing zeros – «١٬٢٥٠٫٠٠٠» and «1,250.000» are
///   both «1250», «١٢٫٥٠٠» is «12.5».
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

  /// The hamza on the line, kept by the folding.
  static const int hamza = 0x0621;

  /// [SearchToken.ending]: the last letter was written ي / ه.
  static const int endingPlain = 1;

  /// [SearchToken.ending]: the last letter was written ى / ة.
  static const int endingMarked = 2;

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

  static bool _isDigit(int c) => (c >= 0x30 && c <= 0x39) || (c >= 0x0660 && c <= 0x0669) || (c >= 0x06F0 && c <= 0x06F9);

  static bool _isGroupSep(int c) => c == 0x2C || c == 0x066C; // , ٬

  static bool _isDecimalSep(int c) => c == 0x2E || c == 0x066B; // . ٫

  static bool _isSep(int c) => _isGroupSep(c) || _isDecimalSep(c);

  static bool _digitsAt(String s, int from, int count) {
    if (from + count > s.length) return false;
    for (var k = from; k < from + count; k++) {
      if (!_isDigit(s.codeUnitAt(k))) return false;
    }
    return true;
  }

  /// Where the amount starting at [i] (a digit that starts a word) ends,
  /// when it is written with thousands groups («1,250», «١٬٢٥٠») and / or
  /// decimals («12.5», «١٢٫٥٠٠»); null for a plain run of digits and for
  /// things that only look like numbers (versions and dates «1.2.3», codes
  /// «1.5kg»).
  static int? _amountEnd(String s, int i) {
    final n = s.length;
    // The second part of «1.2.3» or «1,2».
    if (i >= 2 && _isSep(s.codeUnitAt(i - 1)) && _isDigit(s.codeUnitAt(i - 2))) return null;
    var j = i;
    while (j < n && _isDigit(s.codeUnitAt(j))) {
      j++;
    }
    var end = -1;
    if (j - i <= 3) {
      // Thousands groups: exactly three digits after each separator.
      var k = j;
      while (k < n && _isGroupSep(s.codeUnitAt(k)) && _digitsAt(s, k + 1, 3) && !(k + 4 < n && _isDigit(s.codeUnitAt(k + 4)))) {
        k += 4;
      }
      if (k > j) end = j = k;
    }
    if (j + 1 < n && _isDecimalSep(s.codeUnitAt(j)) && _isDigit(s.codeUnitAt(j + 1))) {
      var k = j + 1;
      while (k < n && _isDigit(s.codeUnitAt(k))) {
        k++;
      }
      // «1.2.3», «12.5,7»: not an amount.
      if (k + 1 < n && _isSep(s.codeUnitAt(k)) && _isDigit(s.codeUnitAt(k + 1))) return null;
      end = k;
    }
    if (end < 0) return null;
    if (end < n) {
      final f = _fold(s.codeUnitAt(end));
      if (f >= 0 && !isArabic(f)) return null; // «1.5kg»: a code
    }
    return end;
  }

  /// The words of [text], folded. With [withOrigins] every token also maps
  /// its folded letters back to the original (for highlights). At most
  /// [maxTokens] words are read.
  static List<SearchToken> tokenize(String text, {bool withOrigins = false, int maxTokens = 1 << 30}) {
    final out = <SearchToken>[];
    if (text.isEmpty) return out;
    final units = <int>[];
    var origins = <int>[];
    var inWord = false;
    var arabicWord = false;
    var start = 0;
    var end = 0;
    var hamzaAlefs = 0;
    var lastRaw = 0;
    // An amount being read: its end and whether it has a decimal point.
    var amountEnd = -1;
    var decimal = false;

    void flush() {
      if (!inWord) return;
      var length = units.length;
      if (decimal) {
        // «12.500» → «12.5», «1250.000» → «1250».
        while (length > 0 && units[length - 1] == 0x30) {
          length--;
        }
        if (length > 0 && units[length - 1] == 0x2E) length--;
      }
      var ending = 0;
      if (length > 0 && arabicWord) {
        final last = units[length - 1];
        if (last == 0x064A) {
          ending = lastRaw == 0x064A ? endingPlain : (lastRaw == 0x0649 || lastRaw == 0x06CC ? endingMarked : 0);
        } else if (last == 0x0647) {
          ending = lastRaw == 0x0647 ? endingPlain : (lastRaw == 0x0629 ? endingMarked : 0);
        }
      }
      final term = String.fromCharCodes(length == units.length ? units : units.sublist(0, length));
      out.add(
        SearchToken(
          term,
          start,
          end,
          out.length,
          withOrigins ? List.unmodifiable(length == origins.length ? origins : origins.sublist(0, length)) : null,
          hamzaAlefs,
          ending,
        ),
      );
      units.clear();
      if (withOrigins) origins = <int>[];
      inWord = false;
      hamzaAlefs = 0;
      decimal = false;
      amountEnd = -1;
    }

    for (var i = 0; i < text.length; i++) {
      final c = text.codeUnitAt(i);
      final f = _fold(c);
      if (f == _drop) {
        if (inWord) end = i + 1; // marks after a letter belong to it
        continue;
      }
      if (f == _sep) {
        if (inWord && i < amountEnd) {
          // Inside an amount: grouping is dropped, the decimal point kept.
          end = i + 1;
          if (_isDecimalSep(c) && units.length < maxTermLength) {
            units.add(0x2E);
            if (withOrigins) origins.add(i);
            decimal = true;
          }
          continue;
        }
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
        if (f >= 0x30 && f <= 0x39) amountEnd = _amountEnd(text, i) ?? -1;
      }
      end = i + 1;
      if (units.length < maxTermLength) {
        if (units.length < 8 && (c == 0x0622 || c == 0x0623 || c == 0x0625)) hamzaAlefs |= 1 << units.length;
        units.add(f);
        if (withOrigins) origins.add(i);
        lastRaw = c;
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

  /// Two-letter words after a bare «ال» that are not article + noun
  /// («الله», «الذي», «التي», «الآن», «اللي»).
  static const Set<String> _shortStemStop = {'له', 'ذي', 'تي', 'ان', 'لي'};

  /// [term] without its definite article («الكتاب» / «والكتاب» → «كتاب»),
  /// or null when it has none (or too little would be left). Two-letter
  /// nouns keep their article only after a bare «ال» («الدم» → «دم»).
  /// [hamzaAlefs] (see [SearchToken.hamzaAlefs]) keeps names such as
  /// «إلهام» whole: the article's alef never carries a hamza.
  static String? stem(String term, {int hamzaAlefs = 0}) {
    if (term.length < 4 || !isArabic(term.codeUnitAt(0))) return null;
    for (final p in _articles) {
      if (!term.startsWith(p)) continue;
      final alef = p.indexOf('ا');
      if (alef >= 0 && hamzaAlefs & (1 << alef) != 0) continue;
      final rest = term.length - p.length;
      if (rest >= minStemLength) return term.substring(p.length);
      if (rest == 2 && p == 'ال') {
        final s = term.substring(2);
        if (!_shortStemStop.contains(s)) return s;
      }
    }
    return null;
  }

  static const int _waw = 0x0648, _faa = 0x0641, _baa = 0x0628, _lam = 0x0644, _kaf = 0x0643;

  /// [term] without a leading conjunction or preposition written onto it
  /// (و ب ل, and ف ك before longer words; و / ف + ب / ل): «وحليب» →
  /// «حليب», «بمحمود» → «محمود», «وبسارة» → «ساره» (and «بساره»). Words
  /// with an article are left to [stem].
  static List<String> proclitics(String term) {
    final n = term.length;
    if (n < 4) return const [];
    final c0 = term.codeUnitAt(0);
    if (c0 != _waw && c0 != _faa && c0 != _baa && c0 != _lam && c0 != _kaf) return const [];
    final out = <String>[];
    final minRest = c0 == _faa || c0 == _kaf ? 4 : 3;
    if (n - 1 >= minRest && !term.startsWith('ال', 1)) out.add(term.substring(1));
    if ((c0 == _waw || c0 == _faa) && n - 2 >= 3) {
      final c1 = term.codeUnitAt(1);
      if ((c1 == _baa || c1 == _lam) && !term.startsWith('ال', 2)) out.add(term.substring(2));
    }
    return out;
  }

  /// Every other form [term] is found by, with where it starts in [term]:
  /// without its article ([stem]), without a leading conjunction or
  /// preposition ([proclitics]), and – with [compounds] – the parts of a
  /// compound name written as one word («عبدالرحمن» → «عبد», «الرحمن»,
  /// «رحمن»; «ابوعلي» → «ابو», «علي»).
  static List<(String, int)> variants(String term, {int hamzaAlefs = 0, bool compounds = true}) {
    if (term.length < 4 || !isArabic(term.codeUnitAt(0))) return const [];
    final out = <(String, int)>[];
    final s = stem(term, hamzaAlefs: hamzaAlefs);
    if (s != null) {
      out.add((s, term.length - s.length));
    } else {
      for (final p in proclitics(term)) {
        out.add((p, term.length - p.length));
      }
    }
    if (compounds) {
      if (term.startsWith('عبدال') && term.length >= 6) {
        final rest = term.substring(3);
        out.add(('عبد', 0));
        out.add((rest, 3));
        final rs = stem(rest);
        if (rs != null) out.add((rs, term.length - rs.length));
      } else if (term.startsWith('ابو') && term.length >= 6) {
        out.add(('ابو', 0));
        out.add((term.substring(3), 3));
      }
    }
    return out;
  }

  /// Joined spelling of two neighbouring words of a compound name («عبد» +
  /// «الله» → «عبدالله», «ابو» + «علي» → «ابوعلي»), or null.
  static String? compound(String first, String second) {
    if (second.length < 2 || !isArabic(second.codeUnitAt(0))) return null;
    if (first == 'عبد' && second.startsWith('ال') && second.length >= 3) return '$first$second';
    if (first == 'ابو' && second.length >= 3) return '$first$second';
    return null;
  }

  /// [term] without its hamzas («قراءه» → «قراه»): how it reads when typed
  /// without them.
  static String dropHamza(String term) => term.replaceAll('ء', '');

  /// Whether [term] holds a hamza on the line.
  static bool hasHamza(String term) => term.contains('ء');

  /// Pronoun and dual endings after a taa marbuta turned ت («زوجتي»،
  /// «رحلتنا»، «سنتين»).
  static const Set<String> taaSuffixes = {'ي', 'ك', 'ه', 'نا', 'كم', 'كن', 'ها', 'هم', 'هن', 'كما', 'هما', 'ان', 'ين'};

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

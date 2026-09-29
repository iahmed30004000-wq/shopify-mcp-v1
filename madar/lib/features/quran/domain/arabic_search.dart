import 'package:meta/meta.dart';

import '../../../core/quran/ayah.dart';

/// A search-friendly form of an Arabic text plus the way back to the
/// original's code units (for highlighting).
@immutable
class NormalizedText {
  const NormalizedText(this.text, this.origins, [this.words = const []]);

  /// The folded text.
  final String text;

  /// For each code unit of [text], the code unit of the original it came
  /// from.
  final List<int> origins;

  /// For each code unit of [text], which word of the original it belongs to
  /// (0-based; the folded text itself has no word breaks). Empty for texts
  /// folded before word tracking.
  final List<int> words;

  /// Word breaks of the original that the folded stretch [start, end)
  /// spans.
  int breaksWithin(int start, int end) => words.isEmpty || end <= start ? 0 : words[end - 1] - words[start];
}

/// Folds Arabic (Uthmani and everyday spelling alike) so a search ignores
/// diacritics, Quranic signs, tatweel, hamza seats and alef forms.
///
/// Alef in every form (ا أ إ آ ٱ and the superscript alef ٰ) is dropped
/// altogether: the Uthmani script writes many alefs as a superscript or not
/// at all (ٱلْعَـٰلَمِينَ, ٱلرَّحْمَـٰنِ), so dropping them lets «العالمين» and
/// «الرحمن» both match. Waw or ya carrying a superscript alef (ٱلصَّلَوٰة,
/// عَلَىٰ) read as that alef; the small ya ۦ ۧ reads as ya, the small waw ۥ
/// is dropped; ة → ه, ى/ی → ي, ؤ → و, ئ → ي, ء dropped, ک → ك; digits,
/// punctuation and spaces are dropped (the Uthmani script joins words the
/// everyday spelling writes apart). Latin letters are kept, lower-cased.
abstract final class ArabicSearch {
  static bool _isMark(int c) =>
      (c >= 0x064B && c <= 0x065F) || // harakat, shadda, sukun, hamza above/below …
      (c >= 0x0610 && c <= 0x061A) || // honorifics / small signs
      (c >= 0x06D6 && c <= 0x06DC) || // Quranic pause marks
      (c >= 0x06DF && c <= 0x06E4) || // small high signs
      (c >= 0x06EA && c <= 0x06ED) || // small low signs
      c == 0x06E8 || // small high noon
      c == 0x0640; // tatweel

  static bool _isAlef(int c) => c == 0x0627 || c == 0x0623 || c == 0x0625 || c == 0x0622 || c == 0x0671;

  static bool _isSpace(int c) => c == 0x20 || c == 0x09 || c == 0x0A || c == 0x0D || c == 0xA0 || c == 0x200F;

  static bool _isArabicLetter(int c) => (c >= 0x0620 && c <= 0x064A) || (c >= 0x066E && c <= 0x06D3) || c == 0x06D5;

  static bool _isLatinLetter(int c) => (c >= 0x61 && c <= 0x7A) || (c >= 0x41 && c <= 0x5A);

  /// Folds [text]; see the class comment.
  static NormalizedText normalize(String text) {
    final out = StringBuffer();
    final origins = <int>[];
    final words = <int>[];
    var word = 0;
    var inWord = false;
    void emit(int c, int origin) {
      out.writeCharCode(c);
      origins.add(origin);
      words.add(word);
      inWord = true;
    }

    for (var i = 0; i < text.length; i++) {
      final c = text.codeUnitAt(i);
      // Word breaks are dropped too: the Uthmani script joins words the
      // everyday spelling separates (يَـٰٓأَيُّهَا for «يا أيها», يَبْنَؤُمَّ).
      // They are remembered, though, so a match never runs from the end of
      // one word into the next unless the query does (see [matchRanges]).
      if (_isSpace(c)) {
        if (inWord) word++;
        inWord = false;
        continue;
      }
      if (c == 0x0670 || _isAlef(c) || c == 0x0621 || c == 0x06E5) continue; // alef family, hamza, small waw
      if (_isMark(c)) continue;
      // A bare waw carrying a superscript alef (ٱلصَّلَوٰةَ) stands for an alef
      // in the everyday spelling (a voweled one is a real waw: سَمَـٰوَٰت), and
      // so does an alef maksura carrying one inside a word (ٱلتَّوْرَىٰةَ); at a
      // word's end (عَلَىٰ) it stays a maksura.
      if (c == 0x0648 && _superscriptAlefFollows(text, i + 1) != null) continue;
      if (c == 0x0649) {
        final after = _superscriptAlefFollows(text, i + 1);
        if (after != null && after < text.length && _isArabicLetter(text.codeUnitAt(after))) continue;
      }
      final folded = switch (c) {
        0x0629 => 0x0647, // ة → ه
        0x0649 || 0x06CC || 0x0626 || 0x06E6 || 0x06E7 => 0x064A, // ى ی ئ ۦ ۧ → ي
        0x0624 => 0x0648, // ؤ → و
        0x06A9 => 0x0643, // ک → ك
        _ => c,
      };
      if (_isArabicLetter(folded)) {
        emit(folded, i);
      } else if (_isLatinLetter(folded)) {
        emit(folded | 0x20, i);
      }
    }
    return NormalizedText(out.toString(), List.unmodifiable(origins), List.unmodifiable(words));
  }

  /// When a superscript alef directly follows [from] (the letter before it
  /// carries no vowel of its own): the index of the first non-mark after
  /// that alef; otherwise null.
  static int? _superscriptAlefFollows(String text, int from) {
    if (from >= text.length || text.codeUnitAt(from) != 0x0670) return null;
    var k = from + 1;
    while (k < text.length && (_isMark(text.codeUnitAt(k)) || text.codeUnitAt(k) == 0x0670)) {
      k++;
    }
    return k;
  }

  /// [query] folded the same way (what the user typed).
  static String normalizeQuery(String query) => normalize(query).text.trim();

  /// Word breaks between the letters the user typed (`يا أيها` → 1).
  static int queryBreaks(String query) {
    final words = normalize(query).words;
    return words.isEmpty ? 0 : words.last - words.first;
  }

  /// Every occurrence of [needle] (already folded) in [hay], as ranges of
  /// the ORIGINAL text [original] – extended over the diacritics and signs
  /// that follow the last matched letter so the whole letter lights up.
  ///
  /// An occurrence may span at most [maxBreaks] word breaks of the original
  /// (the query's own): «الرحمن» must not match across «ٱلْأَرْحَامَ إِنَّ»,
  /// while «يا أيها» still finds the joined «يَـٰٓأَيُّهَا».
  static List<(int, int)> matchRanges(String original, NormalizedText hay, String needle, {int? maxBreaks}) {
    if (needle.isEmpty) return const [];
    final out = <(int, int)>[];
    var from = 0;
    while (true) {
      final i = hay.text.indexOf(needle, from);
      if (i < 0) break;
      if (maxBreaks != null && hay.breaksWithin(i, i + needle.length) > maxBreaks) {
        from = i + 1;
        continue;
      }
      var start = hay.origins[i];
      // Folding drops alefs, so a match found from «ل» of «ٱلرَّحْمَـٰنِ»
      // would leave the word's leading alef (and its marks) unlit: take in
      // the alef (with hamza) right before the first letter, in the same word.
      for (var k = start - 1; k >= 0; k--) {
        final c = original.codeUnitAt(k);
        if (_isMark(c) || c == 0x0670) continue;
        if (_isAlef(c) || c == 0x0621) start = k;
        break;
      }
      var end = hay.origins[i + needle.length - 1] + 1;
      while (end < original.length) {
        final c = original.codeUnitAt(end);
        if (_isMark(c) || c == 0x0670 || c == 0x06E5 || c == 0x06E6 || c == 0x06E7) {
          end++;
        } else {
          break;
        }
      }
      if (out.isNotEmpty && out.last.$2 >= start) {
        out[out.length - 1] = (out.last.$1, end);
      } else {
        out.add((start, end));
      }
      from = i + needle.length;
    }
    return out;
  }
}

/// One search hit: the ayah and where the query matched in its text.
@immutable
class QuranSearchHit {
  const QuranSearchHit(this.ref, this.index, this.ranges);

  final AyahRef ref;

  /// Absolute ayah index.
  final int index;

  /// Code-unit ranges of the ayah text to highlight.
  final List<(int, int)> ranges;
}

/// Result of a search: the first [hits] (capped) and the true total.
@immutable
class QuranSearchResult {
  const QuranSearchResult(this.query, this.hits, this.total, this.occurrences);

  final String query;
  final List<QuranSearchHit> hits;

  /// Ayat that match.
  final int total;

  /// Occurrences over all ayat.
  final int occurrences;

  static const empty = QuranSearchResult('', [], 0, 0);
}

/// A folded index of the whole text, built once.
class QuranSearchIndex {
  QuranSearchIndex(List<String> ayat, List<AyahRef> refs)
    : assert(ayat.length == refs.length),
      _ayat = ayat,
      _refs = refs,
      _folded = [for (final a in ayat) ArabicSearch.normalize(a)];

  final List<String> _ayat;
  final List<AyahRef> _refs;
  final List<NormalizedText> _folded;

  /// Minimum folded query length (one letter matches half the Quran).
  static const int minQueryLength = 2;

  /// Ayat containing [query] (folded), in mushaf order.
  QuranSearchResult search(String query, {int limit = 200}) {
    final needle = ArabicSearch.normalizeQuery(query);
    if (needle.length < minQueryLength) return QuranSearchResult(query, const [], 0, 0);
    final breaks = ArabicSearch.queryBreaks(query);
    final hits = <QuranSearchHit>[];
    var total = 0;
    var occurrences = 0;
    for (var i = 0; i < _folded.length; i++) {
      final f = _folded[i];
      if (!f.text.contains(needle)) continue;
      final ranges = ArabicSearch.matchRanges(_ayat[i], f, needle, maxBreaks: breaks);
      if (ranges.isEmpty) continue;
      total++;
      occurrences += ranges.length;
      if (hits.length < limit) hits.add(QuranSearchHit(_refs[i], i, ranges));
    }
    return QuranSearchResult(query, hits, total, occurrences);
  }
}

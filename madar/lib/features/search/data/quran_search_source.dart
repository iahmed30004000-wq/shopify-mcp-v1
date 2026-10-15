import 'dart:math' as math;

import 'package:collection/collection.dart' show mergeSort;

import 'package:flutter/material.dart' show Icons;

import '../../quran/domain/arabic_search.dart';
import '../domain/search_doc.dart';
import 'search_source.dart';

/// The Quran text and its folded search index, once loaded.
typedef QuranSearchData = ({QuranSearchIndex index, String Function(int ayahIndex) ayahText});

/// Loads [QuranSearchData] (null when the Quran is unavailable).
typedef QuranSearchLoader = Future<QuranSearchData?> Function();

/// Ayat of the Quran, searched live by the Quran's own index
/// ([QuranSearchIndex]: Uthmani-aware folding, matches never run across
/// words) instead of being copied into the global index.
///
/// The Quran index matches anywhere inside a word and drops every alef, which
/// suits a reader looking for a phrase but floods an everyday search: «مال»
/// (money) would find «ٱعْمَلُوا۟», the name «أحمد» «ٱلْحَمْدُ», «باسم» «بِسْمِ».
/// So here a match must start a word (after و ف ب ل ك س and the article at
/// most), a leading alef the user typed must be there, and so must a long
/// vowel alef typed inside the word (written ا, ٰ or as a hamza seat in the
/// mushaf). Whole words rank before word starts, then mushaf order.
abstract final class QuranSearchSource {
  static const String id = 'quran';

  /// Open key of an ayah hit (`extra`: `surah`, `ayah`).
  static const String openKey = 'quran.ayah';
  static const String refTable = 'quran_ayat';

  /// Score of an ayah holding the query as a whole word (about a subtitle
  /// match of user data, so the user's own records come first); an ayah
  /// where it only starts a word scores [prefixQuality] of it, and later
  /// ayat in mushaf order a little less.
  static const double baseScore = 1.6;
  static const double prefixQuality = 0.7;

  /// Longest ayah snippet shown.
  static const int snippetLength = 180;

  static LiveSearchSource create(QuranSearchLoader load) => LiveSearchSource(
    id: id,
    planetKey: 'faith',
    icon: Icons.menu_book_rounded,
    labelKey: 'searchSourceQuranAyat',
    weight: 0.95,
    search: (query, ctx, {int limit = 20}) async {
      if (ArabicSearch.normalizeQuery(query).length < QuranSearchIndex.minQueryLength) return LiveSearchResult.empty;
      final data = await load();
      if (data == null) return LiveSearchResult.empty;
      // Every ayah: the filter below decides the total.
      final result = data.index.search(query, limit: 1 << 30);
      if (result.total == 0) return LiveSearchResult.empty;
      final typed = _QuranQuery(query);
      final kept = <(QuranSearchHit, List<(int, int)>, double)>[];
      for (final h in result.hits) {
        final text = data.ayahText(h.index);
        final ranges = <(int, int)>[];
        var best = 0.0;
        for (final r in h.ranges) {
          final q = typed.quality(text, r);
          if (q <= 0) continue;
          ranges.add(r);
          if (q > best) best = q;
        }
        if (ranges.isNotEmpty) kept.add((h, ranges, best));
      }
      if (kept.isEmpty) return LiveSearchResult.empty;
      // Whole words first, then mushaf order (the sort is stable).
      mergeSort(kept, compare: (a, b) => b.$3.compareTo(a.$3));
      final hits = <SearchHit>[];
      for (var i = 0; i < kept.length && i < limit; i++) {
        final (h, ranges, quality) = kept[i];
        final (snippet, lit) = cutAyah(data.ayahText(h.index), ranges);
        hits.add(
          SearchHit(
            doc: SearchDoc(
              id: '${h.ref}',
              refTable: refTable,
              refId: '${h.ref}',
              title: ctx.ayahPlace(h.ref.surah, h.ref.ayah),
              planetKey: 'faith',
              openKey: openKey,
              extra: {'surah': '${h.ref.surah}', 'ayah': '${h.ref.ayah}'},
              sourceId: id,
            ),
            score: baseScore * quality - i * 0.001,
            snippet: snippet,
            snippetRanges: lit,
          ),
        );
      }
      return LiveSearchResult(hits, kept.length);
    },
  );

  /// An ayah's text cut to about [snippetLength] around its first match,
  /// with the match ranges moved along.
  static (String, List<HighlightRange>) cutAyah(String text, List<(int, int)> ranges) {
    var start = 0;
    if (text.length > snippetLength && ranges.isNotEmpty && ranges.first.$1 > 60) {
      final space = text.lastIndexOf(' ', ranges.first.$1 - 40);
      start = space < 0 ? 0 : space + 1;
    }
    var end = math.min(text.length, start + snippetLength);
    if (end < text.length) {
      final space = text.lastIndexOf(' ', end);
      if (space > start) end = space;
    }
    final lead = start > 0 ? '… ' : '';
    final shift = lead.length - start;
    final visibleEnd = lead.length + end - start;
    final out = <HighlightRange>[];
    for (final (a, b) in ranges) {
      final s = math.max(a + shift, lead.length);
      final e = math.min(b + shift, visibleEnd);
      if (e > s) out.add(HighlightRange(s, e));
    }
    return ('$lead${text.substring(start, end)}${end < text.length ? ' …' : ''}', out);
  }
}

/// What the user typed, for [QuranSearchSource]'s word checks: where the
/// alefs were (the Quran index drops them all).
class _QuranQuery {
  _QuranQuery(String query) : _needle = ArabicSearch.normalizeQuery(query) {
    final folded = ArabicSearch.normalize(query);
    final origins = folded.origins;
    final trimmed = query.trim();
    final lead = query.length - query.trimLeft().length;
    for (var i = 0; i < query.length; i++) {
      final c = query.codeUnitAt(i);
      if (!_isAlef(c)) continue;
      // Letters of the needle typed before this alef.
      var k = 0;
      while (k < origins.length && origins[k] < i) {
        k++;
      }
      if (k == 0) {
        // «ال…»: the article, whose alef the mushaf often drops («لِلَّهِ»).
        if (i == lead && (c == 0x0627 || c == 0x0671) && _needle.isNotEmpty && _needle.codeUnitAt(0) == 0x0644) {
          _article = true;
        } else {
          _leadingAlef = true;
        }
      } else {
        _alefsAfter.add(k - 1);
      }
    }
    _endsWithYa = trimmed.isNotEmpty && trimmed.codeUnitAt(trimmed.length - 1) == 0x064A;
  }

  final String _needle;

  /// The query starts with an alef that is not the article's …
  bool _leadingAlef = false;

  /// … or with the article «ال».
  bool _article = false;

  /// Needle letters an alef was typed after (inside or at the end).
  final Set<int> _alefsAfter = {};

  /// Typed with a dotted final ي: «علي» (Ali) is not «عَلَىٰ» (on).
  late final bool _endsWithYa;

  static bool _isAlef(int c) => c == 0x0627 || c == 0x0623 || c == 0x0625 || c == 0x0622 || c == 0x0671;

  /// A letter standing for a typed alef in the mushaf: an alef, a dagger
  /// alef, or a hamza (seat).
  static bool _alefLike(int c) =>
      _isAlef(c) || c == 0x0670 || c == 0x0621 || c == 0x0654 || c == 0x0655 || c == 0x0624 || c == 0x0626;

  static bool _isMark(int c) =>
      (c >= 0x064B && c <= 0x065F) ||
      c == 0x0670 ||
      (c >= 0x0610 && c <= 0x061A) ||
      (c >= 0x06D6 && c <= 0x06ED) ||
      c == 0x0640;

  static bool _isSpace(int c) => c == 0x20 || c == 0x09 || c == 0x0A || c == 0x0D || c == 0xA0 || c == 0x200F;

  /// What may be written onto a word before it: the interrogative «أ», و /
  /// ف, ب ل ك س, the article (after ل without its alef), or «يا».
  static final Set<String> _prefixes = {
    'يا',
    for (final a in ['', 'أ'])
      for (final c in ['', 'و', 'ف'])
        for (final p in ['', 'ب', 'ل', 'ك', 'س'])
          for (final art in ['', 'ال', if (p == 'ل') 'ل']) '$a$c$p$art',
  };

  /// The same before a typed article's «ل» («بِٱللَّهِ»: «ب» + the article's
  /// alef).
  static final Set<String> _beforeArticle = {..._prefixes, for (final p in _prefixes) '$pا'};

  /// How well the match [range] of [text] fits the typed word: 1 for a
  /// whole word, [QuranSearchSource.prefixQuality] for the start of a word,
  /// 0 when it is inside a word or misses a typed alef.
  double quality(String text, (int, int) range) {
    final (start, end) = range;
    if (_leadingAlef && !_isAlef(text.codeUnitAt(start))) return 0;
    // What is written onto the word before the match (an alef the Quran
    // index took in, when the user typed none, belongs to it: «ءَادَمَ» is
    // not «دم»).
    final before = <int>[];
    final first = text.codeUnitAt(start);
    if (!_leadingAlef && _isAlef(first)) before.add(first == 0x0623 ? first : 0x0627);
    var k = start - 1;
    while (k >= 0 && !_isSpace(text.codeUnitAt(k))) {
      final c = text.codeUnitAt(k);
      if (c == 0x0670 || (_isAlef(c) && c != 0x0623)) {
        before.add(0x0627);
      } else if (!_isMark(c)) {
        before.add(c);
      }
      k--;
    }
    final prefix = String.fromCharCodes(before.reversed);
    if (!(_article ? _beforeArticle : _prefixes).contains(prefix)) return 0;
    if (_alefsAfter.isNotEmpty && !_typedAlefsFound(text, start, end)) return 0;
    // The rest of the word: marks and a silent alef («ٱعْمَلُوا۟») don't count.
    var j = end;
    while (j < text.length) {
      final c = text.codeUnitAt(j);
      if (_isMark(c) || _isAlef(c)) {
        j++;
      } else {
        break;
      }
    }
    final whole = j >= text.length || _isSpace(text.codeUnitAt(j));
    if (whole && _endsWithYa && _endsInAlefMaksura(text, end)) return 0;
    return whole ? 1 : QuranSearchSource.prefixQuality;
  }

  /// Whether the word ending at [end] ends in ى read as a long «ā» (with a
  /// dagger alef: «عَلَىٰ», «مُوسَىٰ»).
  static bool _endsInAlefMaksura(String text, int end) {
    var dagger = false;
    var k = end - 1;
    while (k >= 0 && _isMark(text.codeUnitAt(k))) {
      if (text.codeUnitAt(k) == 0x0670) dagger = true;
      k--;
    }
    return dagger && k >= 0 && text.codeUnitAt(k) == 0x0649;
  }

  /// Whether every alef typed inside (or at the end of) the word is in the
  /// matched stretch of the mushaf.
  bool _typedAlefsFound(String text, int start, int end) {
    final hay = ArabicSearch.normalize(text);
    // The needle's first letter at or after the match start.
    var f = 0;
    while (f < hay.origins.length && hay.origins[f] < start) {
      f++;
    }
    if (!hay.text.startsWith(_needle, f)) return false;
    for (final k in _alefsAfter) {
      final from = hay.origins[f + k] + 1;
      final last = k + 1 >= _needle.length;
      final to = last ? text.length : hay.origins[f + k + 1];
      var found = false;
      for (var i = from; i < to; i++) {
        final c = text.codeUnitAt(i);
        if (_alefLike(c)) {
          found = true;
          break;
        }
        // After the last letter only its own marks may come first.
        if (last && !_isMark(c)) break;
      }
      if (!found) return false;
    }
    return true;
  }
}

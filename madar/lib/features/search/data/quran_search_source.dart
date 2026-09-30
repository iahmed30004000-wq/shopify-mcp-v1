import 'dart:math' as math;

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
abstract final class QuranSearchSource {
  static const String id = 'quran';

  /// Open key of an ayah hit (`extra`: `surah`, `ayah`).
  static const String openKey = 'quran.ayah';
  static const String refTable = 'quran_ayat';

  /// Score of the first ayah hit (about a body match of user data; later
  /// ayat in mushaf order score a little less).
  static const double baseScore = 2.0;

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
      final result = data.index.search(query, limit: limit);
      if (result.total == 0) return LiveSearchResult.empty;
      final hits = <SearchHit>[];
      for (var i = 0; i < result.hits.length; i++) {
        final h = result.hits[i];
        final (snippet, ranges) = cutAyah(data.ayahText(h.index), h.ranges);
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
            score: baseScore - i * 0.001,
            snippet: snippet,
            snippetRanges: ranges,
          ),
        );
      }
      return LiveSearchResult(hits, result.total);
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

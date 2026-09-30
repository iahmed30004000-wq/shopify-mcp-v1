/// The in-memory inverted index behind the global search. Pure Dart: it
/// lives on the search isolate (see `search_worker.dart`), or inline in
/// tests.
library;

import 'dart:math' as math;

import 'package:meta/meta.dart';

import 'search_doc.dart';
import 'search_text.dart';

/// How much the index may hold.
@immutable
class SearchIndexLimits {
  const SearchIndexLimits({
    this.maxDocs = 60000,
    this.maxTitleChars = 240,
    this.maxSubtitleChars = 240,
    this.maxBodyChars = 1600,
    this.maxTokensPerDoc = 320,
  });

  /// Most records kept; beyond it the oldest dated records are dropped.
  final int maxDocs;

  /// Longest title / subtitle / body kept (longer text is cut before
  /// indexing).
  final int maxTitleChars;
  final int maxSubtitleChars;
  final int maxBodyChars;

  /// Most words indexed per record.
  final int maxTokensPerDoc;
}

/// Scoring constants (see [SearchIndex.search]).
abstract final class SearchScoring {
  static const double titleWeight = 3.0;
  static const double subtitleWeight = 1.6;
  static const double bodyWeight = 1.0;

  /// A word found only once its article is taken off («كتاب» in «الكتاب»).
  static const double derivedFactor = 0.85;

  static const double exact = 1.0;
  static const double stem = 0.9;

  /// A prefix scores between [prefixMin] and [prefixMin] + [prefixRange]
  /// (closer to a whole word scores more).
  static const double prefixMin = 0.55;
  static const double prefixRange = 0.3;
  static const double typo = 0.5;
  static const double prefixTypo = 0.4;

  /// Words at least this long tolerate one typo.
  static const int typoMinLength = 5;

  /// Rarity bonus per word: `1 + idfWeight · ln(1 + N / df)`.
  static const double idfWeight = 0.12;

  static const double exactTitleBoost = 1.6;
  static const double titleStartBoost = 1.25;
  static const double titlePhraseBoost = 1.4;
  static const double phraseBoost = 1.2;

  /// Recent (or soon due) records: `1 + recencyBoost · e^(−days / recencyDays)`.
  static const double recencyBoost = 0.3;
  static const double recencyDays = 45;

  /// Planet importance: `0.85 + 0.15 · weight` (weight 1 → ×1).
  static double planetFactor(double weight) => (0.85 + 0.15 * weight).clamp(0.5, 1.6);

  static double recencyFactor(int? dateMs, int nowMs) {
    if (dateMs == null) return 1;
    final days = (nowMs - dateMs).abs() / Duration.millisecondsPerDay;
    return 1 + recencyBoost * math.exp(-days / recencyDays);
  }
}

class _Entry {
  _Entry(this.doc, this.terms, this.dateMs, this.bytes);

  final SearchDoc doc;

  /// Every term posted for the record (to take them back out).
  final List<String> terms;
  final int? dateMs;
  final int bytes;
}

/// A query word and the forms it may take in the index.
class _QueryTerm {
  _QueryTerm(this.term) : stem = SearchText.stem(term);

  final String term;
  final String? stem;

  bool get typoTolerant => term.length >= SearchScoring.typoMinLength;

  /// Which stretch of the indexed word [t] this query word matches, in
  /// folded coordinates, with its quality; null when it does not.
  (int, int, double)? match(String t, {bool allowPrefix = true}) {
    if (t == term) return (0, t.length, SearchScoring.exact);
    final s = stem;
    if (s != null && t == s) return (0, t.length, SearchScoring.stem);
    final ts = SearchText.stem(t);
    if (ts != null && (ts == term || ts == s)) return (t.length - ts.length, t.length, SearchScoring.stem);
    if (allowPrefix) {
      if (t.length > term.length && t.startsWith(term)) {
        return (0, term.length, SearchScoring.prefixMin + SearchScoring.prefixRange * term.length / t.length);
      }
      if (ts != null && ts.length > term.length && ts.startsWith(term)) {
        final off = t.length - ts.length;
        return (off, off + term.length, SearchScoring.prefixMin);
      }
    }
    if (typoTolerant) {
      if ((t.length - term.length).abs() <= 1 && SearchText.withinOneEdit(term, t)) {
        return (0, t.length, SearchScoring.typo);
      }
      if (allowPrefix && t.length > term.length + 1 && SearchText.prefixWithinOneEdit(term, t)) {
        return (0, math.min(t.length, term.length), SearchScoring.prefixTypo);
      }
    }
    return null;
  }
}

/// The parsed query: its words in order and the quoted phrases.
class _ParsedQuery {
  _ParsedQuery(this.words, this.phrases, this.folded);

  factory _ParsedQuery.parse(String text) {
    final words = <_QueryTerm>[];
    final phrases = <List<_QueryTerm>>[];
    final parts = text.split(RegExp('["“”]'));
    for (var i = 0; i < parts.length; i++) {
      final terms = [for (final t in SearchText.tokenize(parts[i], maxTokens: 12)) _QueryTerm(t.term)];
      words.addAll(terms);
      if (i.isOdd && terms.length > 1) phrases.add(terms);
    }
    return _ParsedQuery(words.take(12).toList(), phrases, words.map((w) => w.term).join(' '));
  }

  /// Words in the order typed (duplicates kept for phrase checks).
  final List<_QueryTerm> words;

  /// Quoted phrases: every record must hold them word for word.
  final List<List<_QueryTerm>> phrases;

  /// The folded query (`words` joined by spaces).
  final String folded;

  /// Distinct words.
  List<_QueryTerm> get distinct {
    final seen = <String>{};
    return [
      for (final w in words)
        if (seen.add(w.term)) w,
    ];
  }
}

/// In-memory inverted index with Arabic-aware folding, prefix and typo
/// matching, phrase and title boosts, recency and planet weighting, and
/// highlight ranges.
///
/// Every record's title, subtitle and body are folded into terms (see
/// [SearchText]); each term keeps a posting list of `(record, fields)`.
/// Words with an Arabic article are also posted without it («الكتاب» →
/// «كتاب»), marked as derived. Terms are bucketed by their first one and
/// two letters so prefix and typo expansion only scans words that can
/// match.
class SearchIndex {
  SearchIndex({this.limits = const SearchIndexLimits(), DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final SearchIndexLimits limits;
  final DateTime Function() _clock;

  final List<_Entry?> _entries = [];
  final List<int> _free = [];
  final Map<String, int> _byKey = {};
  final Map<String, List<int>> _postings = {};
  final Map<int, Set<String>> _byFirst = {};
  final Map<int, Set<String>> _byFirstTwo = {};
  int _postingCount = 0;
  int _bytes = 0;
  int _evicted = 0;

  // Field flags of a posting: bits 0–2 = the term is a word of the title /
  // subtitle / body; bits 4–6 = only its article-less form is.
  static const int _flagBits = 8;
  static const int _flagMask = (1 << _flagBits) - 1;
  static final List<double> _fieldWeight = List<double>.generate(1 << _flagBits, (f) {
    var w = 0.0;
    if (f & 1 != 0) w = math.max(w, SearchScoring.titleWeight);
    if (f & 2 != 0) w = math.max(w, SearchScoring.subtitleWeight);
    if (f & 4 != 0) w = math.max(w, SearchScoring.bodyWeight);
    if (f & 16 != 0) w = math.max(w, SearchScoring.titleWeight * SearchScoring.derivedFactor);
    if (f & 32 != 0) w = math.max(w, SearchScoring.subtitleWeight * SearchScoring.derivedFactor);
    if (f & 64 != 0) w = math.max(w, SearchScoring.bodyWeight * SearchScoring.derivedFactor);
    return w;
  }, growable: false);

  /// Records in the index.
  int get length => _byKey.length;

  bool contains(String indexKey) => _byKey.containsKey(indexKey);

  /// The stored record for [indexKey] (fields cut to the limits).
  SearchDoc? doc(String indexKey) {
    final id = _byKey[indexKey];
    return id == null ? null : _entries[id]!.doc;
  }

  // ---------------------------------------------------------------- writes

  /// Applies [delta]: clears its sources, removes, then adds / replaces.
  void apply(SearchIndexDelta delta) {
    for (final s in delta.clearSources) {
      clearSource(s);
    }
    for (final key in delta.removals) {
      remove(key);
    }
    for (final doc in delta.upserts) {
      _remove(doc.indexKey);
      _add(doc);
    }
    _enforceLimits();
  }

  /// Adds [doc] or replaces the record with its key.
  void upsert(SearchDoc doc) {
    _remove(doc.indexKey);
    _add(doc);
    _enforceLimits();
  }

  /// Removes the record with [indexKey]; whether it was there.
  bool remove(String indexKey) => _remove(indexKey);

  /// Drops every record of [sourceId].
  void clearSource(String sourceId) {
    final prefix = '$sourceId\u0001';
    final keys = [
      for (final k in _byKey.keys)
        if (k.startsWith(prefix)) k,
    ];
    keys.forEach(_remove);
  }

  /// Empties the index.
  void clear() {
    _entries.clear();
    _free.clear();
    _byKey.clear();
    _postings.clear();
    _byFirst.clear();
    _byFirstTwo.clear();
    _postingCount = 0;
    _bytes = 0;
  }

  static String _cut(String s, int max) => s.length <= max ? s : s.substring(0, max);

  void _add(SearchDoc raw) {
    final doc =
        raw.title.length > limits.maxTitleChars ||
            raw.subtitle.length > limits.maxSubtitleChars ||
            raw.body.length > limits.maxBodyChars
        ? raw.copyWith(
            title: _cut(raw.title, limits.maxTitleChars),
            subtitle: _cut(raw.subtitle, limits.maxSubtitleChars),
            body: _cut(raw.body, limits.maxBodyChars),
          )
        : raw;
    final flags = <String, int>{};
    var budget = limits.maxTokensPerDoc;
    void field(String text, int bit) {
      if (text.isEmpty || budget <= 0) return;
      final tokens = SearchText.tokenize(text, maxTokens: budget);
      budget -= tokens.length;
      for (final t in tokens) {
        flags[t.term] = (flags[t.term] ?? 0) | bit;
        final s = SearchText.stem(t.term);
        if (s != null) flags[s] = (flags[s] ?? 0) | (bit << 4);
      }
    }

    field(doc.title, 1);
    field(doc.subtitle, 2);
    field(doc.body, 4);

    final int id;
    if (_free.isNotEmpty) {
      id = _free.removeLast();
    } else {
      id = _entries.length;
      _entries.add(null);
    }
    for (final MapEntry(key: term, value: f) in flags.entries) {
      var list = _postings[term];
      if (list == null) {
        list = _postings[term] = <int>[];
        _bucketAdd(term);
      }
      list.add(id << _flagBits | f);
    }
    _postingCount += flags.length;
    final bytes = 2 * (doc.title.length + doc.subtitle.length + doc.body.length + doc.id.length + doc.refId.length) + 96;
    _bytes += bytes;
    _entries[id] = _Entry(doc, flags.keys.toList(growable: false), doc.date?.millisecondsSinceEpoch, bytes);
    _byKey[doc.indexKey] = id;
  }

  bool _remove(String key) {
    final id = _byKey.remove(key);
    if (id == null) return false;
    final e = _entries[id]!;
    for (final term in e.terms) {
      final list = _postings[term];
      if (list == null) continue;
      for (var i = 0; i < list.length; i++) {
        if (list[i] >> _flagBits == id) {
          list[i] = list.last;
          list.removeLast();
          _postingCount--;
          break;
        }
      }
      if (list.isEmpty) {
        _postings.remove(term);
        _bucketRemove(term);
      }
    }
    _bytes -= e.bytes;
    _entries[id] = null;
    _free.add(id);
    return true;
  }

  static int _two(String term) => term.codeUnitAt(0) << 16 | term.codeUnitAt(1);

  void _bucketAdd(String term) {
    (_byFirst[term.codeUnitAt(0)] ??= <String>{}).add(term);
    if (term.length >= 2) (_byFirstTwo[_two(term)] ??= <String>{}).add(term);
  }

  void _bucketRemove(String term) {
    final a = _byFirst[term.codeUnitAt(0)];
    if (a != null && a.remove(term) && a.isEmpty) _byFirst.remove(term.codeUnitAt(0));
    if (term.length >= 2) {
      final k = _two(term);
      final b = _byFirstTwo[k];
      if (b != null && b.remove(term) && b.isEmpty) _byFirstTwo.remove(k);
    }
  }

  /// Keeps the index inside [SearchIndexLimits.maxDocs]: drops the oldest
  /// dated records first (then undated ones), down to 95 % of the limit.
  void _enforceLimits() {
    if (_byKey.length <= limits.maxDocs) return;
    final target = (limits.maxDocs * 0.95).floor();
    final live = <int>[
      for (var i = 0; i < _entries.length; i++)
        if (_entries[i] != null) i,
    ];
    live.sort((a, b) {
      final da = _entries[a]!.dateMs;
      final db = _entries[b]!.dateMs;
      if (da == null && db == null) return b.compareTo(a); // newest insertions stay
      if (da == null) return 1;
      if (db == null) return -1;
      return da.compareTo(db);
    });
    var i = 0;
    while (_byKey.length > target && i < live.length) {
      _remove(_entries[live[i++]]!.doc.indexKey);
      _evicted++;
    }
  }

  // ---------------------------------------------------------------- reads

  SearchIndexStats get stats {
    final bySource = <String, int>{};
    for (final e in _entries) {
      if (e == null) continue;
      bySource[e.doc.sourceId] = (bySource[e.doc.sourceId] ?? 0) + 1;
    }
    var termBytes = 0;
    for (final t in _postings.keys) {
      termBytes += 2 * t.length + 64;
    }
    return SearchIndexStats(
      docs: _byKey.length,
      terms: _postings.length,
      postings: _postingCount,
      approxBytes: _bytes + termBytes + 8 * _postingCount + 16 * _entries.length,
      evicted: _evicted,
      docsBySource: bySource,
    );
  }

  /// Every indexed term [q] may stand for, with the match quality.
  Map<String, double> _expand(_QueryTerm q) {
    final out = <String, double>{};
    void put(String t, double w) {
      if ((out[t] ?? 0) < w) out[t] = w;
    }

    final term = q.term;
    if (_postings.containsKey(term)) put(term, SearchScoring.exact);
    final s = q.stem;
    if (s != null && _postings.containsKey(s)) put(s, SearchScoring.stem);
    final Set<String>? bucket;
    if (q.typoTolerant || term.length < 2) {
      bucket = _byFirst[term.codeUnitAt(0)];
    } else {
      bucket = _byFirstTwo[_two(term)];
    }
    if (bucket == null) return out;
    final n = term.length;
    for (final t in bucket) {
      if (t.length > n && t.startsWith(term)) {
        put(t, SearchScoring.prefixMin + SearchScoring.prefixRange * n / t.length);
      } else if (q.typoTolerant) {
        final d = t.length - n;
        if (d >= -1 && d <= 1) {
          if (t != term && SearchText.withinOneEdit(term, t)) put(t, SearchScoring.typo);
        } else if (d > 1 && SearchText.prefixWithinOneEdit(term, t)) {
          put(t, SearchScoring.prefixTypo);
        }
      }
    }
    return out;
  }

  /// Best score of each record for one query word.
  Map<int, double> _scoreWord(_QueryTerm q) {
    final scores = <int, double>{};
    final n = _byKey.length;
    for (final MapEntry(key: term, value: quality) in _expand(q).entries) {
      final list = _postings[term]!;
      final idf = 1 + SearchScoring.idfWeight * math.log(1 + n / list.length);
      final base = quality * idf;
      for (final p in list) {
        final id = p >> _flagBits;
        final s = base * _fieldWeight[p & _flagMask];
        final prev = scores[id];
        if (prev == null || s > prev) scores[id] = s;
      }
    }
    return scores;
  }

  /// Searches the index.
  ///
  /// Every word must match somewhere (exactly, without its article, as the
  /// start of a word, or – for words of 5+ letters – with one typo); when no
  /// record holds them all, the records holding the most words are returned
  /// and [SearchIndexResult.partial] is set. Words in "quotes" must appear
  /// together. A record's score adds up each word's best field (title >
  /// subtitle > body) times its match quality and rarity, is boosted for an
  /// exact title, a title starting with the query and the words appearing
  /// as a phrase, then multiplied by recency, planet weight and source
  /// weight.
  SearchIndexResult search(SearchIndexQuery query) {
    final watch = Stopwatch()..start();
    final parsed = _ParsedQuery.parse(query.text);
    final words = parsed.distinct;
    if (words.isEmpty || _byKey.isEmpty) return SearchIndexResult.empty;

    // 1. Each word's matches, then records holding every word.
    final perWord = [for (final w in words) _scoreWord(w)]..sort((a, b) => a.length.compareTo(b.length));
    var matched = <int, double>{};
    for (final MapEntry(key: id, value: s) in perWord.first.entries) {
      var total = s;
      var ok = true;
      for (var i = 1; i < perWord.length; i++) {
        final v = perWord[i][id];
        if (v == null) {
          ok = false;
          break;
        }
        total += v;
      }
      if (ok) matched[id] = total;
    }
    var partial = false;
    if (matched.isEmpty && perWord.length > 1) {
      final count = <int, int>{};
      final sum = <int, double>{};
      for (final m in perWord) {
        for (final MapEntry(key: id, value: s) in m.entries) {
          count[id] = (count[id] ?? 0) + 1;
          sum[id] = (sum[id] ?? 0) + s;
        }
      }
      final best = count.values.fold(0, math.max);
      if (best > 0) {
        partial = true;
        matched = {
          for (final MapEntry(key: id, value: c) in count.entries)
            if (c == best) id: sum[id]! * c / perWord.length,
        };
      }
    }
    if (parsed.phrases.isNotEmpty) {
      matched.removeWhere((id, _) {
        final d = _entries[id]!.doc;
        return !parsed.phrases.every((p) => _hasPhrase(d.title, p) || _hasPhrase(d.subtitle, p) || _hasPhrase(d.body, p));
      });
    }

    // 2. Counts for the filter chips (before the filters), then filters.
    final counts = <String, Map<String, int>>{};
    final nowMs = (query.now ?? _clock()).millisecondsSinceEpoch;
    final ranked = <(int, double)>[];
    for (final MapEntry(key: id, value: s) in matched.entries) {
      final e = _entries[id]!;
      final d = e.doc;
      final byGroup = counts[d.planetKey] ??= <String, int>{};
      byGroup[d.groupKey] = (byGroup[d.groupKey] ?? 0) + 1;
      if (query.planets.isNotEmpty && !query.planets.contains(d.planetKey)) continue;
      if (query.groups.isNotEmpty && !query.groups.contains(d.groupKey)) continue;
      final score =
          s *
          SearchScoring.recencyFactor(e.dateMs, nowMs) *
          SearchScoring.planetFactor(query.planetWeights[d.planetKey] ?? 1) *
          (query.sourceWeights[d.sourceId] ?? 1);
      ranked.add((id, score));
    }
    int byScore((int, double) a, (int, double) b) {
      final c = b.$2.compareTo(a.$2);
      if (c != 0) return c;
      final da = _entries[a.$1]!.dateMs ?? 0;
      final db = _entries[b.$1]!.dateMs ?? 0;
      return db.compareTo(da);
    }

    ranked.sort(byScore);

    // 3. Title and phrase boosts for the leaders, then the final order.
    final head = math.min(ranked.length, math.max(query.limit * 3, 240));
    for (var i = 0; i < head; i++) {
      final (id, s) = ranked[i];
      ranked[i] = (id, s * _boost(_entries[id]!.doc, parsed));
    }
    final top = ranked.sublist(0, head)..sort(byScore);
    final hits = [
      for (final (id, s) in top.take(query.limit)) _hit(_entries[id]!.doc, s, words),
    ];
    return SearchIndexResult(
      hits: hits,
      total: ranked.length,
      counts: counts,
      partial: partial,
      elapsedMicros: watch.elapsedMicroseconds,
    );
  }

  double _boost(SearchDoc doc, _ParsedQuery q) {
    final title = SearchText.tokenize(doc.title);
    var boost = 1.0;
    if (title.isNotEmpty) {
      final foldedTitle = title.map((t) => t.term).join(' ');
      if (foldedTitle == q.folded) {
        boost *= SearchScoring.exactTitleBoost;
      } else if (_sequenceAt(title, 0, q.words)) {
        boost *= SearchScoring.titleStartBoost;
      }
    }
    if (q.words.length > 1) {
      if (_findSequence(title, q.words)) {
        boost *= SearchScoring.titlePhraseBoost;
      } else if (_hasPhrase(doc.subtitle, q.words) || _hasPhrase(doc.body, q.words)) {
        boost *= SearchScoring.phraseBoost;
      }
    }
    return boost;
  }

  static bool _hasPhrase(String text, List<_QueryTerm> words) =>
      text.isNotEmpty && _findSequence(SearchText.tokenize(text), words);

  static bool _findSequence(List<SearchToken> tokens, List<_QueryTerm> words) {
    for (var i = 0; i + words.length <= tokens.length; i++) {
      if (_sequenceAt(tokens, i, words)) return true;
    }
    return false;
  }

  /// Whether [words] appear in order from token [at] (the last word may be
  /// a prefix).
  static bool _sequenceAt(List<SearchToken> tokens, int at, List<_QueryTerm> words) {
    if (at + words.length > tokens.length) return false;
    for (var j = 0; j < words.length; j++) {
      final last = j == words.length - 1;
      final m = words[j].match(tokens[at + j].term, allowPrefix: last);
      if (m == null || m.$3 < SearchScoring.typo) return false;
    }
    return true;
  }

  SearchHit _hit(SearchDoc doc, double score, List<_QueryTerm> words) {
    final (snippet, snippetRanges) = _snippet(doc.body, words);
    return SearchHit(
      doc: doc.body.isEmpty ? doc : doc.copyWith(body: ''),
      score: score,
      titleRanges: _highlight(doc.title, words),
      subtitleRanges: _highlight(doc.subtitle, words),
      snippet: snippet,
      snippetRanges: snippetRanges,
    );
  }

  /// Longest snippet shown for a body.
  static const int snippetLength = 150;

  /// Line breaks and tabs become spaces (same length, so ranges still fit).
  static String _oneLine(String s) => s.replaceAll(RegExp('[\n\r\t]'), ' ');

  static (String, List<HighlightRange>) _snippet(String body, List<_QueryTerm> words) {
    if (body.isEmpty) return ('', const []);
    final ranges = _highlight(body, words);
    if (body.length <= snippetLength) return (_oneLine(body), ranges);
    final first = ranges.isEmpty ? 0 : ranges.first.start;
    var start = math.max(0, first - 48);
    if (start > 0) {
      // Start at a word boundary when one is close.
      final space = body.indexOf(' ', start);
      if (space >= 0 && space < start + 16 && space < first) start = space + 1;
    }
    var end = math.min(body.length, start + snippetLength);
    if (end < body.length) {
      final space = body.lastIndexOf(' ', end);
      if (space > start + snippetLength ~/ 2) end = space;
    }
    final lead = start > 0 ? '…' : '';
    final cut = _oneLine(body.substring(start, end));
    final text = '$lead$cut${end < body.length ? '…' : ''}';
    final shift = lead.length - start;
    final visibleEnd = lead.length + cut.length;
    final out = <HighlightRange>[];
    for (final r in ranges) {
      final a = math.max(r.start + shift, lead.length);
      final b = math.min(r.end + shift, visibleEnd);
      if (b > a) out.add(HighlightRange(a, b));
    }
    return (text, out);
  }

  /// Stretches of [text] matching the folded query [terms] (merged, in
  /// order) – what a result lights up.
  static List<HighlightRange> highlightTerms(String text, List<String> terms) =>
      _highlight(text, [for (final t in terms) _QueryTerm(t)]);

  /// [highlightTerms] for a query as typed.
  static List<HighlightRange> highlightQuery(String text, String query) =>
      highlightTerms(text, [for (final t in SearchText.tokenize(query)) t.term]);

  static List<HighlightRange> _highlight(String text, List<_QueryTerm> qs) {
    if (text.isEmpty || qs.isEmpty) return const [];
    final out = <HighlightRange>[];
    for (final token in SearchText.tokenize(text, withOrigins: true)) {
      (int, int)? best;
      for (final q in qs) {
        final m = q.match(token.term);
        if (m == null) continue;
        if (best == null || m.$2 - m.$1 > best.$2 - best.$1) best = (m.$1, m.$2);
      }
      if (best == null) continue;
      final (a, b) = token.rangeOf(best.$1, best.$2);
      if (out.isNotEmpty && out.last.end >= a) {
        out[out.length - 1] = HighlightRange(out.last.start, math.max(out.last.end, b));
      } else {
        out.add(HighlightRange(a, b));
      }
    }
    return out;
  }

  @visibleForTesting
  Map<String, double> debugExpand(String word) => _expand(_QueryTerm(word));
}

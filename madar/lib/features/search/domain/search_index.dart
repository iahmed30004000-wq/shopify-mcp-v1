/// The in-memory inverted index behind the global search. Pure Dart: it
/// lives on the search isolate (see `search_worker.dart`), or inline in
/// tests.
library;

import 'dart:math' as math;
import 'dart:typed_data';

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

  /// A word found only in a derived form: without its article («كتاب» in
  /// «الكتاب»), without a conjunction or preposition («حليب» in «وحليب»),
  /// or as part of a compound name.
  static const double derivedFactor = 0.85;

  static const double exact = 1.0;

  /// The query word without its article («الكتاب» → «كتاب»).
  static const double stem = 0.9;

  /// The query word without a conjunction or preposition («وسارة» →
  /// «سارة»): lower, since the letter may belong to the word («بطاقة» is
  /// not «ب» + «طاقة»).
  static const double procliticStem = 0.7;

  /// A prefix scores between [prefixMin] and [prefixMin] + [prefixRange]
  /// (closer to a whole word scores more).
  static const double prefixMin = 0.55;
  static const double prefixRange = 0.3;

  /// A taa marbuta written ت before an ending («زوجة» → «زوجتي»).
  static const double taa = 0.75;

  /// The query leaves out a hamza the word has («قراه» → «قراءه»).
  static const double looseHamza = 0.95;

  /// One typo. Records that need a typo for any word always rank after
  /// records that hold every word exactly or by prefix.
  static const double typo = 0.3;
  static const double prefixTypo = 0.25;

  /// Words at least this long (without their article) tolerate one typo.
  static const int typoMinLength = 5;

  /// Rarity bonus per word: `1 + idfWeight · ln(1 + N / df)`.
  static const double idfWeight = 0.12;

  static const double exactTitleBoost = 1.6;
  static const double titleStartBoost = 1.25;
  static const double titlePhraseBoost = 1.4;
  static const double phraseBoost = 1.2;

  /// The word spelled as typed where the folding merges two spellings (ي /
  /// ى, ه / ة): «علي» (Ali) before «على» (on).
  static const double spellingBonus = 1.15;

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

  static double prefix(int typed, int length) => prefixMin + prefixRange * typed / length;
}

class _Entry {
  _Entry(this.doc, this.terms, this.slots, this.dateMs, this.bytes);

  final SearchDoc doc;

  /// Every term posted for the record (to take them back out) …
  final List<String> terms;

  /// … and where its posting sits in each term's list (kept up to date as
  /// postings move), so a record leaves in time proportional to its own
  /// words, never to the length of the lists it is in.
  final Int32List slots;
  final int? dateMs;
  final int bytes;
}

/// How a query word matched an indexed word: the stretch of the indexed
/// word (folded coordinates), the quality, and whether it took a typo.
typedef _Match = (int, int, double, bool);

/// A query word and the forms it may take in the index.
class _QueryTerm {
  _QueryTerm(this.term, {int hamzaAlefs = 0, this.ending = 0, this.literal = false, this.prefix = true})
    : hamza = SearchText.hasHamza(term),
      articleStem = SearchText.stem(term, hamzaAlefs: hamzaAlefs),
      stems = _stemsOf(term, hamzaAlefs, literal: literal) {
    core = articleStem ?? term;
    typoTolerant = !literal && core.length >= SearchScoring.typoMinLength && !_digits.hasMatch(core);
    taaForms = literal
        ? const []
        : [
            for (final base in [term, for (final (s, _) in stems) s])
              if (base.length >= 3 && base.codeUnitAt(base.length - 1) == 0x0647 && SearchText.isArabic(base.codeUnitAt(0)))
                '${base.substring(0, base.length - 1)}ت',
          ];
  }

  factory _QueryTerm.of(SearchToken t, {bool literal = false, bool prefix = true}) =>
      _QueryTerm(t.term, hamzaAlefs: t.hamzaAlefs, ending: t.ending, literal: literal, prefix: prefix);

  static final RegExp _digits = RegExp('[0-9]');

  static List<(String, double)> _stemsOf(String term, int hamzaAlefs, {required bool literal}) {
    final s = SearchText.stem(term, hamzaAlefs: hamzaAlefs);
    if (s != null) return [(s, SearchScoring.stem)];
    // A quoted word is taken as written: only its article comes off.
    if (literal) return const [];
    return [for (final p in SearchText.proclitics(term)) (p, SearchScoring.procliticStem)];
  }

  final String term;

  /// How the word's last letter was typed (see [SearchToken.ending]).
  final int ending;

  /// Quoted: only the word itself or its article-less form, no typo.
  final bool literal;

  /// Whether it may match the start of a longer word (every word, except
  /// quoted ones – the last word of a quote still being typed may).
  final bool prefix;

  /// Typed with a hamza: only words with it match.
  final bool hamza;

  final String? articleStem;

  /// The word without its article, or without a leading conjunction /
  /// preposition, with the quality of such a match.
  final List<(String, double)> stems;

  /// The word typo tolerance is judged on: without its article («الصوم» is
  /// a three-letter word, so never «اليوم» or «النوم»).
  late final String core;

  /// Long words tolerate a typo; numbers and codes never do («2025» must
  /// not find «2026»).
  late final bool typoTolerant;

  /// Forms with a final ه (from ة) written ت, as before an ending.
  late final List<String> taaForms;

  /// Whether this word can match [t] without a typo at all: every such
  /// match has one of its forms inside [t] (a quick test that spares
  /// working out [t]'s other forms for most words of a text).
  bool _mayOccurIn(String t) {
    if (t.contains(term)) return true;
    for (final (s, _) in stems) {
      if (t.contains(s)) return true;
    }
    for (final a in taaForms) {
      if (t.contains(a)) return true;
    }
    return !hamza && SearchText.hasHamza(t) && SearchText.dropHamza(t).contains(term);
  }

  /// Which stretch of the indexed word [t] (written with [hamzaAlefs], see
  /// [SearchToken.hamzaAlefs]) this query word matches, in folded
  /// coordinates, with its quality and whether it took a typo; null when it
  /// does not.
  _Match? match(String t, {int hamzaAlefs = 0, bool allowPrefix = true}) {
    final n = term.length;
    if (t == term) return (0, t.length, SearchScoring.exact, false);
    for (final (s, q) in stems) {
      if (t == s) return (0, t.length, q, false);
    }
    // Typos: [t] and its other forms are never longer than [t].
    final typoPossible = typoTolerant && t.length + 1 >= core.length;
    if (!typoPossible && !_mayOccurIn(t)) return null;
    final forms = SearchText.variants(t, hamzaAlefs: hamzaAlefs);
    for (final (v, off) in forms) {
      if (v == term) return (off, off + v.length, SearchScoring.stem, false);
      for (final (s, q) in stems) {
        if (v == s) return (off, off + v.length, q, false);
      }
    }
    final loose = !hamza && SearchText.hasHamza(t) ? SearchText.dropHamza(t) : null;
    if (loose == term) return (0, t.length, SearchScoring.looseHamza, false);
    final prefixOk = allowPrefix && prefix;
    if (prefixOk) {
      if (t.length > n && t.startsWith(term)) return (0, n, SearchScoring.prefix(n, t.length), false);
      for (final (v, off) in forms) {
        if (v.length > n && v.startsWith(term)) return (off, off + n, SearchScoring.prefixMin, false);
      }
      for (final (s, q) in stems) {
        if (s.length < SearchText.minStemLength) continue;
        if (t.length > s.length && t.startsWith(s)) return (0, s.length, SearchScoring.prefixMin * q, false);
        for (final (v, off) in forms) {
          if (v.length > s.length && v.startsWith(s)) return (off, off + s.length, SearchScoring.prefixMin * q, false);
        }
      }
      if (loose != null && loose.length > n && loose.startsWith(term)) {
        return (0, _hamzaPrefixEnd(t, n), SearchScoring.prefixMin, false);
      }
    }
    for (final a in taaForms) {
      if (_taaMatch(t, a)) return (0, a.length, SearchScoring.taa, false);
      for (final (v, off) in forms) {
        if (_taaMatch(v, a)) return (off, off + a.length, SearchScoring.taa, false);
      }
    }
    if (typoPossible) {
      final w = core;
      final m = _typo(w, t, 0, prefixOk);
      if (m != null) return m;
      for (final (v, off) in forms) {
        final mv = _typo(w, v, off, prefixOk);
        if (mv != null) return mv;
      }
    }
    return null;
  }

  static _Match? _typo(String w, String x, int off, bool prefixOk) {
    final d = x.length - w.length;
    if (d >= -1 && d <= 1) {
      if (x != w && SearchText.withinOneEdit(w, x)) return (off, off + x.length, SearchScoring.typo, true);
    } else if (prefixOk && d > 1 && SearchText.prefixWithinOneEdit(w, x)) {
      return (off, off + math.min(x.length, w.length), SearchScoring.prefixTypo, true);
    }
    return null;
  }

  /// Where the first [n] hamza-free letters of [t] end.
  static int _hamzaPrefixEnd(String t, int n) {
    var seen = 0;
    for (var i = 0; i < t.length; i++) {
      if (t.codeUnitAt(i) == SearchText.hamza) continue;
      if (++seen == n) return i + 1;
    }
    return t.length;
  }

  static bool _taaMatch(String x, String a) =>
      x.length > a.length && x.startsWith(a) && SearchText.taaSuffixes.contains(x.substring(a.length));
}

/// The parsed query: its words in order and the quoted phrases.
class _ParsedQuery {
  _ParsedQuery(this.words, this.phrases, this.folded);

  /// Quotes: straight, curly, and Arabic guillemets.
  static final RegExp _quotes = RegExp('["“”«»„‟]');

  factory _ParsedQuery.parse(String text) {
    final words = <_QueryTerm>[];
    final phrases = <List<_QueryTerm>>[];
    final parts = text.split(_quotes);
    // An odd number of parts: every quote is closed.
    final unclosed = parts.length.isEven;
    for (var i = 0; i < parts.length; i++) {
      final quoted = i.isOdd;
      final tokens = SearchText.tokenize(parts[i], maxTokens: 12);
      final lastOpen = quoted && unclosed && i == parts.length - 1;
      final terms = [
        for (var k = 0; k < tokens.length; k++)
          _QueryTerm.of(tokens[k], literal: quoted, prefix: !quoted || (lastOpen && k == tokens.length - 1)),
      ];
      words.addAll(terms);
      if (quoted && terms.length > 1) phrases.add(terms);
    }
    final kept = words.take(12).toList();
    return _ParsedQuery(kept, phrases, kept.map((w) => w.term).join(' '));
  }

  /// Words in the order typed (duplicates kept for phrase checks).
  final List<_QueryTerm> words;

  /// Quoted phrases: every record must hold them word for word.
  final List<List<_QueryTerm>> phrases;

  /// The folded query (`words` joined by spaces).
  final String folded;

  /// Distinct words (a word typed both quoted and not counts as quoted).
  List<_QueryTerm> get distinct {
    final byTerm = <String, _QueryTerm>{};
    for (final w in words) {
      final seen = byTerm[w.term];
      if (seen == null || (w.literal && !seen.literal)) byTerm[w.term] = w;
    }
    return byTerm.values.toList();
  }
}

/// One query word's matches: a score per record id (0 = none), whether the
/// record needed a typo for it, and the ids matched.
class _WordHits {
  _WordHits(int size) : score = Float64List(size), typo = Uint8List(size);

  final Float64List score;
  final Uint8List typo;
  final List<int> ids = [];
}

/// In-memory inverted index with Arabic-aware folding, prefix and typo
/// matching, phrase and title boosts, recency and planet weighting, and
/// highlight ranges.
///
/// Every record's title, subtitle and body are folded into terms (see
/// [SearchText]); each term keeps a posting list of `(record, fields)`.
/// Words are also posted in their other forms, marked as derived: without
/// their article («الكتاب» → «كتاب»), without a leading conjunction or
/// preposition («وحليب» → «حليب»), a compound name joined or split («عبد
/// الله» ↔ «عبدالله»). Terms are bucketed by their first one and two
/// letters so prefix and typo expansion only scans words that can match.
class SearchIndex {
  SearchIndex({this.limits = const SearchIndexLimits(), DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final SearchIndexLimits limits;
  final DateTime Function() _clock;

  final List<_Entry?> _entries = [];
  final List<int> _free = [];
  final Map<String, int> _byKey = {};
  final Map<String, List<int>> _postings = {};
  /// Terms (with their posting lists) by their first letter, and by their
  /// first two.
  final Map<int, Map<String, List<int>>> _byFirst = {};
  final Map<int, Map<String, List<int>>> _byFirstTwo = {};
  int _postingCount = 0;
  int _bytes = 0;
  int _evicted = 0;

  /// Records dropped at the cap and not removed since: key → date.
  final Map<String, int?> _dropped = {};

  // Field flags of a posting: bits 0–2 = the term is a word of the title /
  // subtitle / body; bits 4–6 = only a derived form is; bit 3 / bit 7 = the
  // word ends in ي / ه (bit 3) or in ى / ة (bit 7) as written.
  static const int _flagBits = 8;
  static const int _flagMask = (1 << _flagBits) - 1;
  static const int _plainEnding = 8;
  static const int _markedEnding = 128;
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
  bool remove(String indexKey) {
    _dropped.remove(indexKey);
    return _remove(indexKey);
  }

  /// Drops every record of [sourceId].
  void clearSource(String sourceId) {
    final prefix = '$sourceId\u0001';
    final keys = [
      for (final k in _byKey.keys)
        if (k.startsWith(prefix)) k,
    ];
    keys.forEach(_remove);
    _dropped.removeWhere((k, _) => k.startsWith(prefix));
  }

  /// Empties the index.
  void clear() {
    _entries.clear();
    _free.clear();
    _byKey.clear();
    _postings.clear();
    _byFirst.clear();
    _byFirstTwo.clear();
    _dropped.clear();
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
    _dropped.remove(doc.indexKey);
    final flags = <String, int>{};
    var budget = limits.maxTokensPerDoc;
    void field(String text, int bit) {
      if (text.isEmpty || budget <= 0) return;
      final tokens = SearchText.tokenize(text, maxTokens: budget);
      budget -= tokens.length;
      final derived = bit << 4;
      for (var i = 0; i < tokens.length; i++) {
        final t = tokens[i];
        var f = bit;
        if (t.ending == SearchText.endingPlain) f |= _plainEnding;
        if (t.ending == SearchText.endingMarked) f |= _markedEnding;
        flags[t.term] = (flags[t.term] ?? 0) | f;
        for (final (v, _) in SearchText.variants(t.term, hamzaAlefs: t.hamzaAlefs)) {
          flags[v] = (flags[v] ?? 0) | derived;
        }
        if (i + 1 < tokens.length) {
          final joined = SearchText.compound(t.term, tokens[i + 1].term);
          if (joined != null) flags[joined] = (flags[joined] ?? 0) | derived;
        }
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
    final terms = flags.keys.toList(growable: false);
    final slots = Int32List(terms.length);
    for (var k = 0; k < terms.length; k++) {
      final term = terms[k];
      var list = _postings[term];
      if (list == null) {
        list = _postings[term] = <int>[];
        _bucketAdd(term, list);
      }
      slots[k] = list.length;
      list.add(id << _flagBits | flags[term]!);
    }
    _postingCount += terms.length;
    final bytes = 2 * (doc.title.length + doc.subtitle.length + doc.body.length + doc.id.length + doc.refId.length) + 96;
    _bytes += bytes;
    _entries[id] = _Entry(doc, terms, slots, doc.date?.millisecondsSinceEpoch, bytes);
    _byKey[doc.indexKey] = id;
  }

  bool _remove(String key) {
    final id = _byKey.remove(key);
    if (id == null) return false;
    final e = _entries[id]!;
    for (var k = 0; k < e.terms.length; k++) {
      final term = e.terms[k];
      final list = _postings[term];
      if (list == null) continue;
      final at = e.slots[k];
      final last = list.removeLast();
      _postingCount--;
      if (at < list.length) {
        // The last posting fills the hole: tell its record where it went.
        list[at] = last;
        final moved = _entries[last >> _flagBits]!;
        final mt = moved.terms;
        for (var j = 0; j < mt.length; j++) {
          if (identical(mt[j], term) || mt[j] == term) {
            moved.slots[j] = at;
            break;
          }
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

  void _bucketAdd(String term, List<int> list) {
    (_byFirst[term.codeUnitAt(0)] ??= <String, List<int>>{})[term] = list;
    if (term.length >= 2) (_byFirstTwo[_two(term)] ??= <String, List<int>>{})[term] = list;
  }

  void _bucketRemove(String term) {
    final a = _byFirst[term.codeUnitAt(0)];
    if (a != null && a.remove(term) != null && a.isEmpty) _byFirst.remove(term.codeUnitAt(0));
    if (term.length >= 2) {
      final k = _two(term);
      final b = _byFirstTwo[k];
      if (b != null && b.remove(term) != null && b.isEmpty) _byFirstTwo.remove(k);
    }
  }

  /// Keeps the index inside [SearchIndexLimits.maxDocs]: drops the oldest
  /// dated records first (then undated ones), down to 95 % of the limit.
  /// Dropped records are remembered, so they come back (see
  /// [SearchIndexStats.readmit]) once removals make room again.
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
      final e = _entries[live[i++]]!;
      _remove(e.doc.indexKey);
      _dropped[e.doc.indexKey] = e.dateMs;
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
      approxBytes: _bytes + termBytes + 12 * _postingCount + 16 * _entries.length,
      evicted: _evicted,
      docsBySource: bySource,
      readmit: readmit,
    );
  }

  /// Keys of dropped records that fit again, newest first.
  List<String> get readmit {
    // Up to the level eviction leaves (95 %), so a full index doesn't churn.
    final room = (limits.maxDocs * 0.95).floor() - _byKey.length;
    if (_dropped.isEmpty || room <= 0) return const [];
    final keys = _dropped.keys.toList()
      ..sort((a, b) {
        final da = _dropped[a], db = _dropped[b];
        if (da == null && db == null) return 0;
        if (da == null) return -1;
        if (db == null) return 1;
        return db.compareTo(da);
      });
    return keys.length <= room ? keys : keys.sublist(0, room);
  }

  /// Visits every indexed term [q] may stand for, with its posting list
  /// and the match quality: first the exact, article-less, prefix,
  /// hamza-less and taa forms ([strict]), then the typo forms ([typo]). A
  /// term may come more than once (the best quality wins in scoring).
  void _expand(
    _QueryTerm q,
    void Function(String term, List<int> postings, double quality) strict,
    void Function(String term, List<int> postings, double quality) typo,
  ) {
    final term = q.term;
    final n = term.length;
    if (_postings[term] case final list?) strict(term, list, SearchScoring.exact);
    for (final (s, quality) in q.stems) {
      if (_postings[s] case final list?) strict(s, list, quality);
    }
    if (q.prefix) {
      final bucket = n >= 2 ? _byFirstTwo[_two(term)] : _byFirst[term.codeUnitAt(0)];
      if (bucket != null) {
        for (final MapEntry(key: t, value: list) in bucket.entries) {
          if (t.length > n && t.startsWith(term)) {
            strict(t, list, SearchScoring.prefix(n, t.length));
          } else if (!q.hamza && t.length >= n && SearchText.hasHamza(t)) {
            final loose = SearchText.dropHamza(t);
            if (loose == term) {
              strict(t, list, SearchScoring.looseHamza);
            } else if (loose.length > n && loose.startsWith(term)) {
              strict(t, list, SearchScoring.prefix(n, loose.length));
            }
          }
        }
      }
      // Typing a word with its article or a preposition: «المستش» already
      // finds «مستشفى» and «بالمستشفى».
      for (final (s, quality) in q.stems) {
        if (s.length < SearchText.minStemLength) continue;
        final b = _byFirstTwo[_two(s)];
        if (b == null) continue;
        for (final MapEntry(key: t, value: list) in b.entries) {
          if (t.length > s.length && t.startsWith(s)) strict(t, list, SearchScoring.prefix(s.length, t.length) * quality);
        }
      }
    }
    for (final a in q.taaForms) {
      final b = _byFirstTwo[_two(a)];
      if (b == null) continue;
      for (final MapEntry(key: t, value: list) in b.entries) {
        if (_QueryTerm._taaMatch(t, a)) strict(t, list, SearchScoring.taa);
      }
    }
    if (q.typoTolerant) {
      final w = q.core;
      final bucket = _byFirst[w.codeUnitAt(0)];
      if (bucket != null) {
        final wn = w.length;
        for (final MapEntry(key: t, value: list) in bucket.entries) {
          final d = t.length - wn;
          if (d >= -1 && d <= 1) {
            if (t != w && t != term && SearchText.withinOneEdit(w, t)) typo(t, list, SearchScoring.typo);
          } else if (d > 1 && q.prefix && !t.startsWith(w) && !t.startsWith(term) && SearchText.prefixWithinOneEdit(w, t)) {
            typo(t, list, SearchScoring.prefixTypo);
          }
        }
      }
    }
  }

  /// Best score of each record for one query word.
  _WordHits _scoreWord(_QueryTerm q, int size) {
    final out = _WordHits(size);
    final score = out.score;
    final typos = out.typo;
    final ids = out.ids;
    final docs = _byKey.length;
    // The spelling typed, where the folding merges two (ي / ى, ه / ة).
    final spelled = switch (q.ending) {
      SearchText.endingPlain => _plainEnding,
      SearchText.endingMarked => _markedEnding,
      _ => 0,
    };
    _expand(
      q,
      (term, list, quality) {
        final idf = 1 + SearchScoring.idfWeight * math.log(1 + docs / list.length);
        final base = quality * idf;
        final spelling = spelled != 0 && term == q.term;
        for (final p in list) {
          final id = p >> _flagBits;
          var s = base * _fieldWeight[p & _flagMask];
          if (spelling && p & spelled != 0) s *= SearchScoring.spellingBonus;
          final prev = score[id];
          if (prev == 0) ids.add(id);
          if (s > prev) score[id] = s;
        }
      },
      (term, list, quality) {
        final idf = 1 + SearchScoring.idfWeight * math.log(1 + docs / list.length);
        final base = quality * idf;
        for (final p in list) {
          final id = p >> _flagBits;
          final s = base * _fieldWeight[p & _flagMask];
          final prev = score[id];
          if (prev == 0) {
            // Only a typo finds this record (so far: exact forms came first).
            ids.add(id);
            typos[id] = 1;
            score[id] = s;
          } else if (typos[id] == 1 && s > prev) {
            score[id] = s;
          }
        }
      },
    );
    return out;
  }

  /// Searches the index.
  ///
  /// Every word must match somewhere (exactly, without its article or a
  /// leading conjunction / preposition, as the start of a word, or – for
  /// words of 5+ letters without their article – with one typo); when no
  /// record holds them all, the records holding the most words are returned
  /// and [SearchIndexResult.partial] is set. Words in quotes ("…" or «…»)
  /// are taken literally (no typo, no prefix) and must appear together.
  /// Records that need a typo rank after those that don't. A record's
  /// score adds up each word's best field (title > subtitle > body) times
  /// its match quality and rarity, is boosted for an exact title, a title
  /// starting with the query and the words appearing as a phrase, then
  /// multiplied by recency, planet weight and source weight.
  SearchIndexResult search(SearchIndexQuery query) {
    final watch = Stopwatch()..start();
    final parsed = _ParsedQuery.parse(query.text);
    final words = parsed.distinct;
    if (words.isEmpty || _byKey.isEmpty) return SearchIndexResult.empty;

    // 1. Each word's matches, then records holding every word.
    final size = _entries.length;
    final perWord = [for (final w in words) _scoreWord(w, size)]..sort((a, b) => a.ids.length.compareTo(b.ids.length));
    var ids = <int>[];
    var sums = <double>[];
    var typos = <bool>[];
    final first = perWord.first;
    for (final id in first.ids) {
      var total = first.score[id];
      var typo = first.typo[id] != 0;
      var ok = true;
      for (var i = 1; i < perWord.length; i++) {
        final w = perWord[i];
        final v = w.score[id];
        if (v == 0) {
          ok = false;
          break;
        }
        total += v;
        if (w.typo[id] != 0) typo = true;
      }
      if (ok) {
        ids.add(id);
        sums.add(total);
        typos.add(typo);
      }
    }
    var partial = false;
    if (ids.isEmpty && perWord.length > 1) {
      final count = Uint8List(size);
      final sum = Float64List(size);
      final typo = Uint8List(size);
      final touched = <int>[];
      var best = 0;
      for (final w in perWord) {
        for (final id in w.ids) {
          if (count[id] == 0) touched.add(id);
          final c = ++count[id];
          if (c > best) best = c;
          sum[id] += w.score[id];
          if (w.typo[id] != 0) typo[id] = 1;
        }
      }
      if (best > 0) {
        partial = true;
        for (final id in touched) {
          if (count[id] != best) continue;
          ids.add(id);
          sums.add(sum[id] * best / perWord.length);
          typos.add(typo[id] != 0);
        }
      }
    }
    if (parsed.phrases.isNotEmpty) {
      final keptIds = <int>[], keptSums = <double>[], keptTypos = <bool>[];
      for (var i = 0; i < ids.length; i++) {
        final d = _entries[ids[i]]!.doc;
        if (parsed.phrases.every((p) => _hasPhrase(d.title, p) || _hasPhrase(d.subtitle, p) || _hasPhrase(d.body, p))) {
          keptIds.add(ids[i]);
          keptSums.add(sums[i]);
          keptTypos.add(typos[i]);
        }
      }
      ids = keptIds;
      sums = keptSums;
      typos = keptTypos;
    }

    // 2. Counts for the filter chips (before the filters), then filters,
    // then the leaders (a bounded heap: the rest is never sorted).
    final counts = <String, Map<String, int>>{};
    final nowMs = (query.now ?? _clock()).millisecondsSinceEpoch;
    final planetFactors = <String, double>{};
    final top = _TopK(math.max(query.limit * 3, 240));
    var total = 0;
    for (var i = 0; i < ids.length; i++) {
      final id = ids[i];
      final e = _entries[id]!;
      final d = e.doc;
      final byGroup = counts[d.planetKey] ??= <String, int>{};
      byGroup[d.groupKey] = (byGroup[d.groupKey] ?? 0) + 1;
      if (query.planets.isNotEmpty && !query.planets.contains(d.planetKey)) continue;
      if (query.groups.isNotEmpty && !query.groups.contains(d.groupKey)) continue;
      total++;
      final score =
          sums[i] *
          SearchScoring.recencyFactor(e.dateMs, nowMs) *
          (planetFactors[d.planetKey] ??= SearchScoring.planetFactor(query.planetWeights[d.planetKey] ?? 1)) *
          (query.sourceWeights[d.sourceId] ?? 1);
      top.offer(id, score, typos[i], e.dateMs ?? 0);
    }

    // 3. Title and phrase boosts for the leaders, then the final order.
    final head = top.items;
    for (final r in head) {
      r.score *= _boost(_entries[r.id]!.doc, parsed);
    }
    head.sort(_Ranked.compare);
    final hits = [
      for (final r in head.take(query.limit)) _hit(_entries[r.id]!.doc, r.score, words),
    ];
    return SearchIndexResult(
      hits: hits,
      total: total,
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
  /// a prefix; no word may need a typo).
  static bool _sequenceAt(List<SearchToken> tokens, int at, List<_QueryTerm> words) {
    if (at + words.length > tokens.length) return false;
    for (var j = 0; j < words.length; j++) {
      final last = j == words.length - 1;
      final t = tokens[at + j];
      final m = words[j].match(t.term, hamzaAlefs: t.hamzaAlefs, allowPrefix: last);
      if (m == null || m.$4) return false;
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
      _highlight(text, _ParsedQuery.parse(query).distinct);

  static List<HighlightRange> _highlight(String text, List<_QueryTerm> qs) {
    if (text.isEmpty || qs.isEmpty) return const [];
    final out = <HighlightRange>[];
    void light(int a, int b) {
      if (out.isNotEmpty && out.last.end >= a) {
        out[out.length - 1] = HighlightRange(out.last.start, math.max(out.last.end, b));
      } else {
        out.add(HighlightRange(a, b));
      }
    }

    final tokens = SearchText.tokenize(text, withOrigins: true);
    for (var i = 0; i < tokens.length; i++) {
      final token = tokens[i];
      (int, int)? best;
      for (final q in qs) {
        final m = q.match(token.term, hamzaAlefs: token.hamzaAlefs);
        if (m == null) continue;
        if (best == null || m.$2 - m.$1 > best.$2 - best.$1) best = (m.$1, m.$2);
      }
      if (best == null) {
        // A compound name written apart, typed as one word («عبدالله»).
        if (i + 1 < tokens.length) {
          final joined = SearchText.compound(token.term, tokens[i + 1].term);
          if (joined != null && qs.any((q) => q.term == joined || q.stems.any((s) => s.$1 == joined))) {
            light(token.start, token.end);
            light(tokens[i + 1].start, tokens[i + 1].end);
            i++;
          }
        }
        continue;
      }
      final (a, b) = token.rangeOf(best.$1, best.$2);
      light(a, b);
    }
    return out;
  }

  @visibleForTesting
  Map<String, double> debugExpand(String word) {
    final t = SearchText.tokenize(word);
    final out = <String, double>{};
    void put(String term, List<int> _, double quality) {
      if ((out[term] ?? 0) < quality) out[term] = quality;
    }

    _expand(t.isEmpty ? _QueryTerm(word) : _QueryTerm.of(t.first), put, put);
    return out;
  }
}

/// A record in the ranking: records needing a typo come last, then by
/// score, then newest first.
class _Ranked {
  _Ranked(this.id, this.score, this.typo, this.dateMs);

  final int id;
  double score;
  final bool typo;
  final int dateMs;

  static int compare(_Ranked a, _Ranked b) {
    if (a.typo != b.typo) return a.typo ? 1 : -1;
    final c = b.score.compareTo(a.score);
    if (c != 0) return c;
    return b.dateMs.compareTo(a.dateMs);
  }
}

/// The best [k] records offered (in no particular order), kept in a heap
/// whose root is the weakest kept: a record that would not make it costs a
/// comparison and no allocation.
class _TopK {
  _TopK(this.k);

  final int k;
  final List<_Ranked> items = [];

  /// Whether (typo, score, date) ranks strictly before [r].
  static bool _before(bool typo, double score, int dateMs, _Ranked r) {
    if (typo != r.typo) return !typo;
    if (score != r.score) return score > r.score;
    return dateMs > r.dateMs;
  }

  static bool _weaker(_Ranked a, _Ranked b) => _Ranked.compare(a, b) > 0;

  void offer(int id, double score, bool typo, int dateMs) {
    final heap = items;
    if (heap.length < k) {
      heap.add(_Ranked(id, score, typo, dateMs));
      var i = heap.length - 1;
      while (i > 0) {
        final p = (i - 1) >> 1;
        if (!_weaker(heap[i], heap[p])) break;
        final t = heap[i];
        heap[i] = heap[p];
        heap[p] = t;
        i = p;
      }
      return;
    }
    if (k == 0 || !_before(typo, score, dateMs, heap[0])) return;
    heap[0] = _Ranked(id, score, typo, dateMs);
    var i = 0;
    while (true) {
      final l = 2 * i + 1, r = l + 1;
      var m = i;
      if (l < heap.length && _weaker(heap[l], heap[m])) m = l;
      if (r < heap.length && _weaker(heap[r], heap[m])) m = r;
      if (m == i) return;
      final t = heap[i];
      heap[i] = heap[m];
      heap[m] = t;
      i = m;
    }
  }
}

/// What the global search indexes, asks and answers. Pure Dart, sendable
/// between isolates.
library;

import 'package:meta/meta.dart';

/// One searchable record: a task, a note, a person, an ayah …
///
/// [id] is unique within its source; the engine stamps [sourceId]. Opening a
/// result hands [openKey], [refTable], [refId] and [extra] to the app's
/// opener, which maps them to a route.
@immutable
class SearchDoc {
  const SearchDoc({
    required this.id,
    required this.refTable,
    required this.refId,
    required this.title,
    this.subtitle = '',
    this.body = '',
    this.date,
    required this.planetKey,
    this._openKey,
    this.group,
    this.groupLabel,
    this.groupIcon,
    this.groupColor,
    this.extra = const {},
    this.sourceId = '',
  });

  /// Unique within the source (usually the row id).
  final String id;

  /// SQL table of the record (`tasks`, `board_cards` …), or a virtual one
  /// (`quran_ayat`, a lead-registered page).
  final String refTable;

  /// The record's id in [refTable] (`2:255` for an ayah).
  final String refId;

  /// Main line (matches here weigh most).
  final String title;

  /// Second line (e.g. a wallet and amount, a project's name).
  final String subtitle;

  /// Longer text (notes, descriptions); shown as a snippet around the match.
  final String body;

  /// When the record happened / is due (recency ranking, trailing date).
  final DateTime? date;

  /// Planet the record belongs to (`faith`, `health` … `custom_<id>`, or
  /// `custom` for a module with no planet).
  final String planetKey;

  final String? _openKey;

  /// What the opener should open: [refTable] unless the source says
  /// otherwise (`quran.ayah`, `custom.entry` …).
  String get openKey => _openKey ?? refTable;

  /// Optional module this record is grouped under instead of its source
  /// (each custom module is its own group).
  final String? group;

  /// Name, curated icon key and colour (ARGB) of [group].
  final String? groupLabel;
  final String? groupIcon;
  final int? groupColor;

  /// Ids the opener may need (a card's board, an entry's module …).
  final Map<String, String> extra;

  /// Source that produced the record (stamped by the engine).
  final String sourceId;

  /// The group results are listed and filtered under.
  String get groupKey => group ?? sourceId;

  /// Key in the index (source + id).
  String get indexKey => '$sourceId\u0001$id';

  SearchDoc withSource(String source) => source == sourceId ? this : copyWith(sourceId: source);

  SearchDoc copyWith({String? sourceId, String? body, String? subtitle, String? title}) => SearchDoc(
    id: id,
    refTable: refTable,
    refId: refId,
    title: title ?? this.title,
    subtitle: subtitle ?? this.subtitle,
    body: body ?? this.body,
    date: date,
    planetKey: planetKey,
    openKey: _openKey,
    group: group,
    groupLabel: groupLabel,
    groupIcon: groupIcon,
    groupColor: groupColor,
    extra: extra,
    sourceId: sourceId ?? this.sourceId,
  );

  /// Hash of everything that is indexed or shown (detects changed records).
  int get contentHash => Object.hash(
    refTable,
    refId,
    title,
    subtitle,
    body,
    date?.millisecondsSinceEpoch,
    planetKey,
    _openKey,
    group,
    groupLabel,
    groupIcon,
    groupColor,
    Object.hashAllUnordered(extra.entries.map((e) => Object.hash(e.key, e.value))),
  );

  @override
  bool operator ==(Object other) =>
      other is SearchDoc && other.sourceId == sourceId && other.id == id && other.contentHash == contentHash;

  @override
  int get hashCode => Object.hash(sourceId, id);

  @override
  String toString() => 'SearchDoc($sourceId/$id: $title)';
}

/// A highlighted stretch `[start, end)` (code units) of a shown text.
@immutable
class HighlightRange {
  const HighlightRange(this.start, this.end);

  final int start;
  final int end;

  HighlightRange shift(int by) => HighlightRange(start + by, end + by);

  @override
  bool operator ==(Object other) => other is HighlightRange && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => '[$start,$end)';
}

/// One result: the record, its score and what to light up.
@immutable
class SearchHit {
  const SearchHit({
    required this.doc,
    required this.score,
    this.titleRanges = const [],
    this.subtitleRanges = const [],
    this.snippet = '',
    this.snippetRanges = const [],
  });

  /// The record (its body left out; see [snippet]).
  final SearchDoc doc;
  final double score;
  final List<HighlightRange> titleRanges;
  final List<HighlightRange> subtitleRanges;

  /// The part of the body around the first match ('' when the body is
  /// empty), one line, with an ellipsis where it was cut.
  final String snippet;
  final List<HighlightRange> snippetRanges;

  @override
  String toString() => 'SearchHit(${doc.sourceId}/${doc.id} ${score.toStringAsFixed(3)})';
}

/// A query to the index.
@immutable
class SearchIndexQuery {
  const SearchIndexQuery(
    this.text, {
    this.planets = const {},
    this.groups = const {},
    this.limit = 120,
    this.now,
    this.planetWeights = const {},
    this.sourceWeights = const {},
  });

  /// What the user typed. Words in "double quotes" must appear together.
  final String text;

  /// Only these planets (empty = all).
  final Set<String> planets;

  /// Only these groups (sources, or custom modules; empty = all).
  final Set<String> groups;

  /// Most hits returned.
  final int limit;

  /// "Now" for recency (default: the clock).
  final DateTime? now;

  /// Importance of each planet (`Planets.weight`, 1 = normal).
  final Map<String, double> planetWeights;

  /// Weight of each source (1 = normal).
  final Map<String, double> sourceWeights;
}

/// What the index found.
@immutable
class SearchIndexResult {
  const SearchIndexResult({
    required this.hits,
    required this.total,
    required this.counts,
    this.partial = false,
    this.elapsedMicros = 0,
  });

  static const empty = SearchIndexResult(hits: [], total: 0, counts: {});

  /// Ranked hits after the filters (at most `limit`).
  final List<SearchHit> hits;

  /// Matches after the filters.
  final int total;

  /// Matches before the filters: planet → group → count (filter chips).
  final Map<String, Map<String, int>> counts;

  /// Not every word matched anywhere: these are the closest records.
  final bool partial;

  /// Time spent in the index.
  final int elapsedMicros;
}

/// Changes to apply to the index: records added or changed, and keys
/// (see [SearchDoc.indexKey]) removed.
@immutable
class SearchIndexDelta {
  const SearchIndexDelta({this.upserts = const [], this.removals = const [], this.clearSources = const {}});

  final List<SearchDoc> upserts;
  final List<String> removals;

  /// Sources whose records are all dropped first.
  final Set<String> clearSources;

  bool get isEmpty => upserts.isEmpty && removals.isEmpty && clearSources.isEmpty;
}

/// Size of the index.
@immutable
class SearchIndexStats {
  const SearchIndexStats({
    required this.docs,
    required this.terms,
    required this.postings,
    required this.approxBytes,
    required this.evicted,
    this.docsBySource = const {},
    this.readmit = const [],
  });

  final int docs;
  final int terms;
  final int postings;

  /// Rough memory use of the stored text and postings.
  final int approxBytes;

  /// Records dropped to stay inside the limits since the index was made.
  final int evicted;
  final Map<String, int> docsBySource;

  /// Index keys of dropped records that fit again (records were removed
  /// since), newest first: the engine sends them again.
  final List<String> readmit;

  @override
  String toString() => 'SearchIndexStats(docs: $docs, terms: $terms, postings: $postings, ~${approxBytes ~/ 1024} KB)';
}

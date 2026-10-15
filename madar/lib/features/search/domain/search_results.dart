/// A global search request and its answer, grouped for display. Pure Dart.
library;

import 'package:meta/meta.dart';

import 'search_doc.dart';

/// What the screen asks for.
@immutable
class SearchRequest {
  const SearchRequest(this.text, {this.planets = const {}, this.groups = const {}, this.limit = 120});

  final String text;

  /// Only these planets (empty = all).
  final Set<String> planets;

  /// Only these groups: source ids, or `module:<id>` for a custom module
  /// (empty = all).
  final Set<String> groups;
  final int limit;

  bool get isEmpty => text.trim().isEmpty;

  SearchRequest copyWith({String? text, Set<String>? planets, Set<String>? groups, int? limit}) => SearchRequest(
    text ?? this.text,
    planets: planets ?? this.planets,
    groups: groups ?? this.groups,
    limit: limit ?? this.limit,
  );

  @override
  bool operator ==(Object other) =>
      other is SearchRequest &&
      other.text == text &&
      other.limit == limit &&
      _setEq(other.planets, planets) &&
      _setEq(other.groups, groups);

  @override
  int get hashCode => Object.hash(text, limit, Object.hashAllUnordered(planets), Object.hashAllUnordered(groups));
}

bool _setEq(Set<String> a, Set<String> b) => a.length == b.length && a.containsAll(b);

/// Hits of one group (a source or a custom module), best first.
@immutable
class SearchResultGroup {
  const SearchResultGroup({required this.key, required this.hits, required this.count});

  /// Group key ([SearchDoc.groupKey]).
  final String key;
  final List<SearchHit> hits;

  /// Every match of the group (more than [hits] when the list was cut).
  final int count;

  SearchDoc get first => hits.first.doc;

  /// The source of the group's records.
  String get sourceId => first.sourceId;
}

/// The answer to a [SearchRequest].
@immutable
class SearchResults {
  const SearchResults({
    required this.request,
    required this.hits,
    required this.total,
    required this.counts,
    this.partial = false,
    this.elapsed = Duration.zero,
  });

  factory SearchResults.empty(SearchRequest request) =>
      SearchResults(request: request, hits: const [], total: 0, counts: const {});

  final SearchRequest request;

  /// Ranked hits after the filters.
  final List<SearchHit> hits;

  /// Matches after the filters.
  final int total;

  /// Matches before the filters: planet → group → count.
  final Map<String, Map<String, int>> counts;

  /// Not every word matched together (closest records shown).
  final bool partial;
  final Duration elapsed;

  bool get isEmpty => hits.isEmpty;

  /// Matches before the filters.
  int get unfilteredTotal => counts.values.fold(0, (s, m) => s + m.values.fold(0, (a, b) => a + b));

  /// Matches per planet (before the filters).
  Map<String, int> get planetTotals => {
    for (final e in counts.entries) e.key: e.value.values.fold(0, (a, b) => a + b),
  };

  /// Matches per group within [planets] (all planets when empty).
  Map<String, int> groupTotals([Set<String> planets = const {}]) {
    final out = <String, int>{};
    for (final e in counts.entries) {
      if (planets.isNotEmpty && !planets.contains(e.key)) continue;
      for (final g in e.value.entries) {
        out[g.key] = (out[g.key] ?? 0) + g.value;
      }
    }
    return out;
  }

  /// Hits grouped by module, groups in the order of their best hit.
  List<SearchResultGroup> get groups {
    final totals = groupTotals(request.planets);
    final order = <String>[];
    final byKey = <String, List<SearchHit>>{};
    for (final h in hits) {
      final k = h.doc.groupKey;
      (byKey[k] ??= () {
        order.add(k);
        return <SearchHit>[];
      }()).add(h);
    }
    return [
      for (final k in order) SearchResultGroup(key: k, hits: byKey[k]!, count: totals[k] ?? byKey[k]!.length),
    ];
  }
}

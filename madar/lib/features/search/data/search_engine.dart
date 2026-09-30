import 'dart:async';

import 'package:drift/drift.dart' show TableUpdateQuery;
import 'package:flutter/foundation.dart';

import '../../../core/db/database.dart';
import '../domain/search_doc.dart';
import '../domain/search_results.dart';
import 'search_source.dart';
import 'search_worker.dart';

/// Where the engine is.
enum SearchEngineStatus {
  /// Not started (nothing loaded until the search is first used).
  idle,

  /// Reading the sources into the index.
  indexing,

  /// Answering queries; keeps itself up to date.
  ready,

  /// The worker could not start (queries answer empty).
  failed,
}

/// Makes the context records are written up in (language, digits, sura
/// names).
typedef SearchContextFactory = Future<SearchLoadContext> Function();

/// The global search: builds the index lazily on a background worker on
/// first use, keeps it current from the database's table updates
/// (debounced; only changed records are re-indexed) and answers queries,
/// merging the live sources (the Quran) in.
class SearchEngine {
  SearchEngine({
    required this._db,
    required this._registry,
    required SearchContextFactory context,
    SearchWorkerFactory? workerFactory,
    DateTime Function()? clock,
    this.debounce = const Duration(milliseconds: 350),
    this.maxDelay = const Duration(milliseconds: 1500),
    this.applyChunk = 2500,
    this.liveTimeout = const Duration(seconds: 3),
  }) : _contextFactory = context,
       _workerFactory = workerFactory ?? (() => IsolateSearchWorker.spawn()),
       _clock = clock ?? DateTime.now;

  final MadarDatabase _db;
  final SearchRegistry _registry;
  final SearchContextFactory _contextFactory;
  final SearchWorkerFactory _workerFactory;
  final DateTime Function() _clock;

  /// Quiet time after the last change before the index is updated.
  final Duration debounce;

  /// Longest a change waits under a stream of further changes.
  final Duration maxDelay;

  /// Records sent to the worker per message.
  final int applyChunk;

  /// Longest a live source may take before a query answers without it.
  final Duration liveTimeout;

  /// Hits asked of a live source when it is not the only group shown.
  static const int liveLimit = 30;

  /// Current state (the screen shows "preparing" while indexing).
  final ValueNotifier<SearchEngineStatus> status = ValueNotifier(SearchEngineStatus.idle);

  final StreamController<int> _changes = StreamController<int>.broadcast();
  int _revision = 0;

  /// Bumps after every update applied to the index (re-run the query).
  Stream<int> get changes => _changes.stream;
  int get revision => _revision;

  SearchWorker? _worker;
  SearchLoadContext? _ctx;
  Future<void>? _starting;
  bool _disposed = false;
  StreamSubscription<Object?>? _tableSub;
  final Map<String, StreamSubscription<void>> _extraSubs = {};
  final Map<String, SearchSource> _loaded = {};

  /// Per source: record id → content hash of what the index holds.
  final Map<String, Map<String, int>> _hashes = {};
  Map<String, double> _planetWeights = const {};

  final Set<String> _dirty = {};

  /// Sources changed while nobody listened to [changes]: re-read at the
  /// next query instead (no work on the UI isolate while search is closed).
  final Set<String> _deferred = {};
  Timer? _debounceTimer;
  DateTime? _firstDirtyAt;
  Future<void> _updates = Future.value();

  /// Starts the engine (spawns the worker, indexes every source). Safe to
  /// call often; later calls wait for the first.
  Future<void> warmUp() => _starting ??= _start();

  Future<void> _start() async {
    status.value = SearchEngineStatus.indexing;
    try {
      SearchWorker worker;
      try {
        worker = await _workerFactory();
      } on Object catch (e) {
        debugPrint('Search: background worker unavailable ($e); indexing inline');
        worker = InlineSearchWorker();
      }
      if (_disposed) {
        await worker.close();
        return;
      }
      _worker = worker;
      _ctx = await _contextFactory();
      await _loadPlanetWeights();
      _tableSub = _db.tableUpdates(TableUpdateQuery.any()).listen((updates) {
        final tables = {for (final u in updates) u.table};
        if (tables.contains('planets')) unawaited(_loadPlanetWeights());
        for (final s in _loaded.values) {
          if (s.tables.any(tables.contains)) _markDirty(s.id);
        }
      });
      _registry.addListener(_onRegistry);
      for (final s in _registry.indexed.toList()) {
        if (_disposed) return;
        await _load(s);
      }
      if (!_disposed) status.value = SearchEngineStatus.ready;
    } on Object catch (e, st) {
      debugPrint('Search: indexing failed: $e\n$st');
      if (!_disposed) status.value = SearchEngineStatus.failed;
    }
  }

  Future<void> _loadPlanetWeights() async {
    try {
      final planets = await _db.select(_db.planets).get();
      _planetWeights = {for (final p in planets) p.key: p.weight};
    } on Object {
      // Keep the previous weights.
    }
  }

  /// Starts following [s] and indexes it.
  Future<void> _load(SearchSource s) async {
    _loaded[s.id] = s;
    await _extraSubs.remove(s.id)?.cancel();
    final extra = s.changes;
    if (extra != null) _extraSubs[s.id] = extra.listen((_) => _markDirty(s.id));
    await _reload(s);
  }

  /// Re-reads [s] and sends only the records that changed.
  Future<void> _reload(SearchSource s) async {
    final worker = _worker;
    final ctx = _ctx;
    if (worker == null || ctx == null || _disposed) return;
    List<SearchDoc> docs;
    try {
      docs = await s.load(ctx);
    } on Object catch (e, st) {
      debugPrint('Search: source ${s.id} failed to load: $e\n$st');
      return;
    }
    if (_disposed || _loaded[s.id] != s) return;
    final previous = _hashes[s.id] ?? const <String, int>{};
    final next = <String, int>{};
    final upserts = <SearchDoc>[];
    for (final raw in docs) {
      final doc = raw.withSource(s.id);
      final hash = doc.contentHash;
      if (next.containsKey(doc.id)) upserts.removeWhere((d) => d.id == doc.id);
      next[doc.id] = hash;
      if (previous[doc.id] != hash) upserts.add(doc);
    }
    final removals = [
      for (final id in previous.keys)
        if (!next.containsKey(id)) '${s.id}\u0001$id',
    ];
    _hashes[s.id] = next;
    if (upserts.isEmpty && removals.isEmpty) return;
    // Large sources go over in chunks so no single message is huge.
    var i = 0;
    do {
      final end = i + applyChunk < upserts.length ? i + applyChunk : upserts.length;
      await worker.apply(SearchIndexDelta(upserts: upserts.sublist(i, end), removals: i == 0 ? removals : const []));
      if (_disposed) return;
      i = end;
    } while (i < upserts.length);
  }

  void _markDirty(String sourceId) {
    if (_disposed) return;
    if (!_changes.hasListener) {
      _deferred.add(sourceId);
      return;
    }
    _dirty.add(sourceId);
    final now = DateTime.now();
    _firstDirtyAt ??= now;
    _debounceTimer?.cancel();
    final waited = now.difference(_firstDirtyAt!);
    final wait = waited + debounce > maxDelay ? Duration.zero : debounce;
    _debounceTimer = Timer(wait, _flush);
  }

  void _flush() {
    _debounceTimer = null;
    _firstDirtyAt = null;
    final ids = _dirty.toList();
    _dirty.clear();
    if (ids.isEmpty || _disposed) return;
    _updates = _updates.then((_) async {
      for (final id in ids) {
        final s = _loaded[id];
        if (s != null) await _reload(s);
      }
      if (_disposed) return;
      _revision++;
      _changes.add(_revision);
    });
  }

  void _onRegistry() {
    if (_disposed || _worker == null) return;
    _updates = _updates.then((_) async {
      final now = {for (final s in _registry.indexed) s.id: s};
      final removed = [
        for (final id in _loaded.keys)
          if (!now.containsKey(id)) id,
      ];
      for (final id in removed) {
        _loaded.remove(id);
        _hashes.remove(id);
        await _extraSubs.remove(id)?.cancel();
      }
      if (removed.isNotEmpty) await _worker?.apply(SearchIndexDelta(clearSources: removed.toSet()));
      for (final s in now.values) {
        if (!identical(_loaded[s.id], s)) {
          if (_loaded.containsKey(s.id)) {
            _hashes.remove(s.id);
            await _worker?.apply(SearchIndexDelta(clearSources: {s.id}));
          }
          await _load(s);
        }
      }
      if (_disposed) return;
      _revision++;
      _changes.add(_revision);
    });
  }

  /// Applies pending changes now (instead of after the debounce), deferred
  /// ones included.
  Future<void> flushNow() async {
    if (_deferred.isNotEmpty) {
      _dirty.addAll(_deferred);
      _deferred.clear();
    }
    if (_dirty.isNotEmpty) {
      _debounceTimer?.cancel();
      _flush();
    }
    await _updates;
  }

  /// Re-reads [sources] (every source when null).
  Future<void> refresh({Set<String>? sources}) async {
    await warmUp();
    for (final s in _loaded.values) {
      if (sources == null || sources.contains(s.id)) _dirty.add(s.id);
    }
    await flushNow();
  }

  /// Answers [request]: the index and the live sources, merged by score.
  Future<SearchResults> search(SearchRequest request) async {
    final text = request.text.trim();
    if (text.isEmpty) return SearchResults.empty(request);
    await warmUp();
    if (_deferred.isNotEmpty) await flushNow();
    final worker = _worker;
    final ctx = _ctx;
    if (worker == null || ctx == null || _disposed) return SearchResults.empty(request);
    final watch = Stopwatch()..start();
    final query = SearchIndexQuery(
      text,
      planets: request.planets,
      groups: request.groups,
      limit: request.limit,
      now: _clock(),
      planetWeights: _planetWeights,
      sourceWeights: {for (final s in _registry.sources) s.id: s.weight},
    );
    final live = [
      for (final s in _registry.live)
        s
            // The best few, or all of them once filtered to this source.
            .search(text, ctx, limit: request.groups.contains(s.id) ? request.limit : liveLimit)
            .timeout(liveTimeout)
            .then<(LiveSearchSource, LiveSearchResult)>(
              (r) => (s, r),
              onError: (Object e) {
                debugPrint('Search: live source ${s.id} failed: $e');
                return (s, LiveSearchResult.empty);
              },
            ),
    ];
    final SearchIndexResult indexed;
    try {
      indexed = await worker.search(query);
    } on Object catch (e) {
      debugPrint('Search: query failed: $e');
      return SearchResults.empty(request);
    }
    final counts = {
      for (final e in indexed.counts.entries) e.key: Map<String, int>.of(e.value),
    };
    final hits = [...indexed.hits];
    var total = indexed.total;
    for (final (source, result) in await Future.wait(live)) {
      if (result.total == 0) continue;
      final byGroup = counts[source.planetKey] ??= <String, int>{};
      byGroup[source.id] = (byGroup[source.id] ?? 0) + result.total;
      if (request.planets.isNotEmpty && !request.planets.contains(source.planetKey)) continue;
      if (request.groups.isNotEmpty && !request.groups.contains(source.id)) continue;
      total += result.total;
      for (final h in result.hits) {
        hits.add(
          SearchHit(
            doc: h.doc.withSource(source.id),
            score: h.score * source.weight,
            titleRanges: h.titleRanges,
            subtitleRanges: h.subtitleRanges,
            snippet: h.snippet,
            snippetRanges: h.snippetRanges,
          ),
        );
      }
    }
    hits.sort((a, b) => b.score.compareTo(a.score));
    return SearchResults(
      request: request,
      hits: hits.length > request.limit ? hits.sublist(0, request.limit) : hits,
      total: total,
      counts: counts,
      partial: indexed.partial,
      elapsed: watch.elapsed,
    );
  }

  /// Size of the index (starts the engine, applies pending changes).
  Future<SearchIndexStats> stats() async {
    await warmUp();
    await flushNow();
    return _worker?.stats() ?? Future.value(const SearchIndexStats(docs: 0, terms: 0, postings: 0, approxBytes: 0, evicted: 0));
  }

  /// Stops following changes and closes the worker.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _debounceTimer?.cancel();
    _registry.removeListener(_onRegistry);
    await _tableSub?.cancel();
    for (final s in _extraSubs.values) {
      await s.cancel();
    }
    _extraSubs.clear();
    await _changes.close();
    final worker = _worker;
    _worker = null;
    await worker?.close();
    status.dispose();
  }
}

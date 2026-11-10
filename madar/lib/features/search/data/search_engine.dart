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
///
/// It keeps going when things fail: a source whose update the worker
/// rejects is sent again in full (with backoff), the other sources are not
/// held up, a worker that stops answering is replaced, and a query never
/// throws (it answers without the index instead).
class SearchEngine {
  SearchEngine({
    required this._db,
    required this._registry,
    required SearchContextFactory context,
    SearchWorkerFactory? workerFactory,
    DateTime Function()? clock,
    this.debounce = const Duration(milliseconds: 350),
    this.maxDelay = const Duration(milliseconds: 1500),
    this.applyChunk = 500,
    this.liveTimeout = const Duration(seconds: 3),
    this.workerTimeout = const Duration(seconds: 4),
    this.applyTimeout = const Duration(seconds: 30),
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

  /// Records sent to the worker per message (each message is copied on
  /// this isolate, so it stays small).
  final int applyChunk;

  /// Longest a live source may take before a query answers without it.
  final Duration liveTimeout;

  /// Longest the worker may take to answer a query (it answers in
  /// milliseconds; after this it is taken for stuck and replaced).
  final Duration workerTimeout;

  /// Longest the worker may take to apply one update message.
  final Duration applyTimeout;

  /// Hits asked of a live source when it is not the only group shown.
  static const int liveLimit = 30;

  /// Records processed on this isolate between two breaks (so a large
  /// source never holds a frame for long).
  static const int _slice = 1000;

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

  /// The planets changed while nobody listened: re-read at the next query.
  bool _planetsStale = false;

  final Set<String> _dirty = {};

  /// Sources changed while nobody listened to [changes]: re-read at the
  /// next query instead (no work on the UI isolate while search is closed).
  final Set<String> _deferred = {};

  /// Sources the index may hold a partial update of (a failed one): sent
  /// again in full, after clearing them.
  final Set<String> _resync = {};
  int _failures = 0;
  Timer? _retryTimer;

  /// The index dropped records at its cap: after removals, send them again
  /// if they fit (see [SearchIndexStats.readmit]).
  bool _mayHaveDropped = false;

  bool _restarting = false;
  DateTime? _lastRestart;

  Timer? _debounceTimer;
  DateTime? _firstDirtyAt;
  Future<void> _updates = Future.value();

  /// Starts the engine (spawns the worker, indexes every source). Safe to
  /// call often; later calls wait for the first.
  Future<void> warmUp() => _starting ??= _start();

  Future<void> _start() async {
    status.value = SearchEngineStatus.indexing;
    try {
      final worker = await _spawn();
      if (_disposed) {
        await worker.close();
        return;
      }
      _worker = worker;
      // Frames in between: starting the isolate and making the write-up
      // context (language data) each take a moment on this isolate.
      await _breathe();
      _ctx = await _contextFactory();
      await _breathe();
      await _loadPlanetWeights();
      _tableSub = _db.tableUpdates(TableUpdateQuery.any()).listen((updates) {
        final tables = {for (final u in updates) u.table};
        if (tables.contains('planets')) {
          if (_changes.hasListener) {
            unawaited(_loadPlanetWeights());
          } else {
            _planetsStale = true;
          }
        }
        for (final s in _loaded.values) {
          if (s.tables.any(tables.contains)) _markDirty(s.id);
        }
      });
      _registry.addListener(_onRegistry);
      // Through the update queue, so changes arriving meanwhile wait their
      // turn instead of reloading a source at the same time.
      _enqueue(() async {
        for (final s in _registry.indexed.toList()) {
          if (_disposed) return;
          // A source that fails is retried on its own; the others go on.
          await _load(s);
        }
        await _readmit(always: true);
        // One throwaway query readies the query path on the worker, so the
        // user's first keystroke answers as fast as the rest.
        await _worker?.search(const SearchIndexQuery('ا a', limit: 1)).timeout(workerTimeout);
      });
      await _drain();
      if (!_disposed) status.value = SearchEngineStatus.ready;
    } on Object catch (e, st) {
      debugPrint('Search: indexing failed: $e\n$st');
      if (!_disposed) status.value = SearchEngineStatus.failed;
    }
  }

  Future<SearchWorker> _spawn() async {
    try {
      return await _workerFactory();
    } on Object catch (e) {
      debugPrint('Search: background worker unavailable ($e); indexing inline');
      return InlineSearchWorker();
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

  /// A break for this isolate's event loop (frames, input).
  static Future<void> _breathe() => Future<void>.delayed(Duration.zero);

  /// Re-reads [s] and sends only the records that changed. When the worker
  /// fails the update, the source is marked to be cleared and sent again in
  /// full, and a retry is scheduled.
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
    if (_disposed || _loaded[s.id] != s || !identical(worker, _worker)) return;
    final full = _resync.contains(s.id);
    final previous = full ? const <String, int>{} : (_hashes[s.id] ?? const <String, int>{});
    final next = <String, int>{};
    // Changed records go over as they are found, a chunk at a time (a
    // message is copied on this isolate, and a large source never holds
    // them all at once); the removals and a clear (see [_resync]) go with
    // the first and last messages.
    final pending = <SearchDoc>[];
    var sent = false;
    Future<void> send(List<String> removals) async {
      await worker
          .apply(
            SearchIndexDelta(
              clearSources: !sent && full ? {s.id} : const {},
              upserts: List.of(pending),
              removals: removals,
            ),
          )
          .timeout(applyTimeout);
      sent = true;
      pending.clear();
    }

    try {
      for (var i = 0; i < docs.length; i++) {
        if (i > 0 && i % _slice == 0) {
          await _breathe();
          if (_disposed) return;
        }
        final doc = docs[i].withSource(s.id);
        final hash = doc.contentHash;
        // A second record with the same id replaces the first (sent again).
        final twice = next.containsKey(doc.id);
        next[doc.id] = hash;
        if (twice || previous[doc.id] != hash) pending.add(doc);
        if (pending.length >= applyChunk) {
          await send(const []);
          if (_disposed) return;
        }
      }
      final removals = [
        for (final id in previous.keys)
          if (!next.containsKey(id)) '${s.id}\u0001$id',
      ];
      if (pending.isNotEmpty || removals.isNotEmpty || (full && !sent)) await send(removals);
      if (_disposed) return;
      _hashes[s.id] = next;
      _resync.remove(s.id);
      if (sent) _failures = 0;
      if (removals.isNotEmpty) _roomMade = true;
    } on Object catch (e) {
      debugPrint('Search: updating ${s.id} failed ($e); sending it again');
      if (_disposed) return;
      _hashes.remove(s.id);
      _resync.add(s.id);
      _scheduleRetry(s.id);
    }
  }

  /// Records were removed in the last update (dropped ones may fit again).
  bool _roomMade = false;

  /// Retries the sources whose update failed, backing off (the debounce,
  /// doubled per failure in a row, at most half a minute); while nobody
  /// listens, at the next query instead.
  void _scheduleRetry(String sourceId) {
    _failures++;
    if (!_changes.hasListener) {
      _deferred.add(sourceId);
      return;
    }
    _dirty.add(sourceId);
    if (_retryTimer != null) return;
    final ms = debounce.inMilliseconds * (1 << (_failures < 7 ? _failures : 7));
    _retryTimer = Timer(Duration(milliseconds: ms.clamp(1, 30000)), () {
      _retryTimer = null;
      _flush();
    });
  }

  /// Sends records the index dropped at its cap again once removals made
  /// room for them ([always]: ask even if nothing was removed); whether it
  /// sent any.
  Future<bool> _readmit({bool always = false}) async {
    if (!always && !(_mayHaveDropped && _roomMade)) return false;
    _roomMade = false;
    final worker = _worker;
    if (worker == null || _disposed) return false;
    try {
      final stats = await worker.stats().timeout(workerTimeout);
      _mayHaveDropped = stats.evicted > 0;
      if (stats.readmit.isEmpty) return false;
      final sources = <String>{};
      for (final key in stats.readmit) {
        final sep = key.indexOf('\u0001');
        if (sep < 0) continue;
        final source = key.substring(0, sep);
        _hashes[source]?.remove(key.substring(sep + 1));
        sources.add(source);
      }
      for (final id in sources) {
        final s = _loaded[id];
        if (s != null) await _reload(s);
      }
      return true;
    } on Object catch (e) {
      debugPrint('Search: could not check dropped records: $e');
      return false;
    }
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

  /// Runs [job] after the updates before it, whatever happened to them; a
  /// failing job never stops the ones after it.
  void _enqueue(Future<void> Function() job) {
    _updates = _updates.then((_) async {
      if (_disposed) return;
      try {
        await job();
      } on Object catch (e, st) {
        debugPrint('Search: update failed: $e\n$st');
      }
    });
  }

  void _bump() {
    if (_disposed) return;
    _revision++;
    _changes.add(_revision);
  }

  void _flush() {
    _debounceTimer = null;
    _firstDirtyAt = null;
    final ids = _dirty.toList();
    _dirty.clear();
    if (ids.isEmpty || _disposed) return;
    _enqueue(() async {
      for (final id in ids) {
        final s = _loaded[id];
        if (s != null) await _reload(s);
      }
      _bump();
      // Dropped records that fit again follow in a later step, so the
      // results show the change itself first.
      if (_mayHaveDropped && _roomMade) {
        _enqueue(() async {
          if (await _readmit()) _bump();
        });
      }
    });
  }

  void _onRegistry() {
    if (_disposed || _worker == null) return;
    _enqueue(() async {
      final now = {for (final s in _registry.indexed) s.id: s};
      final removed = [
        for (final id in _loaded.keys)
          if (!now.containsKey(id)) id,
      ];
      for (final id in removed) {
        _loaded.remove(id);
        _hashes.remove(id);
        _resync.remove(id);
        await _extraSubs.remove(id)?.cancel();
      }
      if (removed.isNotEmpty) await _worker?.apply(SearchIndexDelta(clearSources: removed.toSet())).timeout(applyTimeout);
      for (final s in now.values) {
        if (!identical(_loaded[s.id], s)) {
          if (_loaded.containsKey(s.id)) {
            _hashes.remove(s.id);
            _resync.add(s.id);
          }
          await _load(s);
        }
      }
      _bump();
    });
  }

  /// The worker stopped answering: replace it and index everything again
  /// (at most once a minute).
  void _replaceWorker() {
    if (_disposed || _restarting) return;
    final now = DateTime.now();
    final last = _lastRestart;
    if (last != null && now.difference(last) < const Duration(minutes: 1)) return;
    _restarting = true;
    _lastRestart = now;
    _enqueue(() async {
      try {
        final old = _worker;
        _worker = null;
        try {
          await old?.close().timeout(const Duration(seconds: 2));
        } on Object {
          // Gone either way.
        }
        final worker = await _spawn();
        if (_disposed) {
          await worker.close();
          return;
        }
        _worker = worker;
        _hashes.clear();
        _resync.clear();
        status.value = SearchEngineStatus.indexing;
        for (final s in _loaded.values.toList()) {
          await _reload(s);
        }
        if (!_disposed) status.value = SearchEngineStatus.ready;
        _bump();
      } finally {
        _restarting = false;
      }
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
      _retryTimer?.cancel();
      _retryTimer = null;
      _flush();
    }
    await _drain();
  }

  /// Waits until the update queue is empty (a step may queue a follow-up).
  Future<void> _drain() async {
    while (true) {
      final pending = _updates;
      await pending;
      if (identical(pending, _updates)) return;
    }
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
  /// Never throws: without a working index it answers with the live
  /// sources alone.
  Future<SearchResults> search(SearchRequest request) async {
    final text = request.text.trim();
    if (text.isEmpty) return SearchResults.empty(request);
    await warmUp();
    if (_deferred.isNotEmpty) await flushNow();
    if (_planetsStale && !_disposed) {
      _planetsStale = false;
      await _loadPlanetWeights();
    }
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
    SearchIndexResult indexed;
    try {
      indexed = await worker.search(query).timeout(workerTimeout);
    } on TimeoutException {
      debugPrint('Search: the index did not answer in $workerTimeout; replacing it');
      indexed = SearchIndexResult.empty;
      _replaceWorker();
    } on Object catch (e) {
      debugPrint('Search: query failed: $e');
      indexed = SearchIndexResult.empty;
    }
    final counts = {
      for (final e in indexed.counts.entries) e.key: Map<String, int>.of(e.value),
    };
    var total = indexed.total;
    final extra = <SearchHit>[];
    for (final (source, result) in await Future.wait(live)) {
      if (result.total == 0) continue;
      final byGroup = counts[source.planetKey] ??= <String, int>{};
      byGroup[source.id] = (byGroup[source.id] ?? 0) + result.total;
      if (request.planets.isNotEmpty && !request.planets.contains(source.planetKey)) continue;
      if (request.groups.isNotEmpty && !request.groups.contains(source.id)) continue;
      total += result.total;
      for (final h in result.hits) {
        extra.add(
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
    // The index's order stands (records needing a typo come after exact
    // ones whatever their score); live hits are merged in by score.
    mergeSort(extra, compare: (a, b) => b.score.compareTo(a.score));
    final hits = <SearchHit>[];
    var i = 0, j = 0;
    while (hits.length < request.limit && (i < indexed.hits.length || j < extra.length)) {
      if (j >= extra.length || (i < indexed.hits.length && indexed.hits[i].score >= extra[j].score)) {
        hits.add(indexed.hits[i++]);
      } else {
        hits.add(extra[j++]);
      }
    }
    return SearchResults(
      request: request,
      hits: hits,
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
    const none = SearchIndexStats(docs: 0, terms: 0, postings: 0, approxBytes: 0, evicted: 0);
    final worker = _worker;
    if (worker == null) return none;
    try {
      return await worker.stats().timeout(workerTimeout);
    } on Object {
      return none;
    }
  }

  /// Stops following changes and closes the worker.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _debounceTimer?.cancel();
    _retryTimer?.cancel();
    _registry.removeListener(_onRegistry);
    status.value = SearchEngineStatus.idle;
    await _tableSub?.cancel();
    for (final s in _extraSubs.values) {
      await s.cancel();
    }
    _extraSubs.clear();
    await _changes.close();
    final worker = _worker;
    _worker = null;
    try {
      await worker?.close();
    } on Object {
      // Closing is best effort.
    }
    status.dispose();
  }
}

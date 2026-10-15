import 'dart:async';

import 'package:drift/drift.dart';

import '../../../core/db/database.dart';
import '../../../core/db/repositories/repositories.dart';
import '../domain/planet_pulse.dart';

/// The orbit's completion hook and its stream of "planet pulse" events.
///
/// * [recordCompletion] logs an `activity_log` entry (so the planet's score
///   and freshness change) and pulses the planet at once.
/// * While [pulses] has listeners, completions logged anywhere else in the
///   app (a task ticked on home, a dose taken in Health …) are picked up from
///   the activity stream and pulse their planet too – one pulse per planet
///   per batch, so an import never floods the scene. Only entries stamped
///   within [recentWindow] of now pulse (an undo that restores an old
///   completion does not).
///
/// The scene answers a pulse with `uPulse`, particles and a chime.
class OrbitPulseHub {
  OrbitPulseHub(this.repos, {DateTime Function()? clock, this.recentWindow = const Duration(minutes: 2)})
    : _clock = clock ?? DateTime.now {
    _controller = StreamController<PlanetPulse>.broadcast(onListen: _start, onCancel: _stop);
  }

  final Repositories repos;
  final DateTime Function() _clock;
  final Duration recentWindow;

  late final StreamController<PlanetPulse> _controller;
  StreamSubscription<Set<TableUpdate>>? _inserts;
  int _watermark = 0;
  bool _started = false;
  int _generation = 0;
  bool _polling = false;
  bool _pollAgain = false;
  bool _disposed = false;

  /// Activity ids already pulsed by [recordCompletion].
  final Set<String> _recorded = {};

  /// Completions being logged right now (`planet|kind|table|id`).
  final Map<String, int> _pending = {};

  MadarDatabase get _db => repos.db;

  /// Planet pulses (broadcast).
  Stream<PlanetPulse> get pulses => _controller.stream;

  /// Logs that [kind] was completed for [planetKey] (optionally pointing at
  /// the source row) and pulses the planet. Undo it with
  /// `repos.activity.removeFor(refTable:, refId:, kind:)`.
  Future<void> recordCompletion(
    String planetKey,
    String kind,
    String? refTable,
    String? refId, {
    DateTime? at,
    double? value,
    Map<String, Object?> payload = const {},
  }) async {
    final signature = '$planetKey|$kind|$refTable|$refId';
    _pending[signature] = (_pending[signature] ?? 0) + 1;
    try {
      final row = await repos.activity.log(
        planetKey: planetKey,
        kind: kind,
        refTable: refTable,
        refId: refId,
        at: at ?? _clock(),
        value: value,
        payload: payload,
      );
      if (_recorded.length > 512) _recorded.clear();
      _recorded.add(row.id);
      if (!_disposed) {
        _controller.add(
          PlanetPulse(
            planetKey: planetKey,
            kind: kind,
            at: row.at,
            refTable: refTable,
            refId: refId,
            activityId: row.id,
          ),
        );
      }
    } finally {
      final left = (_pending[signature] ?? 1) - 1;
      if (left <= 0) {
        _pending.remove(signature);
      } else {
        _pending[signature] = left;
      }
    }
  }

  Future<void> _start() async {
    if (_started || _disposed) return;
    _started = true;
    // A cancel + re-listen while the watermark is read starts a newer
    // generation: only the newest one subscribes (never two).
    final generation = ++_generation;
    final maxId = _db.activityLog.rowId.max();
    final watermark =
        await (_db.selectOnly(_db.activityLog)..addColumns([maxId])).map((r) => r.read(maxId)).getSingleOrNull() ?? 0;
    if (!_started || _disposed || generation != _generation) return;
    _watermark = watermark;
    _inserts = _db
        .tableUpdates(TableUpdateQuery.onTable(_db.activityLog, limitUpdateKind: UpdateKind.insert))
        .listen((_) => unawaited(_poll()));
  }

  Future<void> _stop() async {
    _started = false;
    _generation++;
    await _inserts?.cancel();
    _inserts = null;
  }

  Future<void> _poll() async {
    if (_polling) {
      _pollAgain = true;
      return;
    }
    _polling = true;
    try {
      do {
        _pollAgain = false;
        final a = _db.activityLog;
        final rowId = a.rowId;
        final query = _db.select(a).addColumns([rowId])
          ..where(rowId.isBiggerThanValue(_watermark))
          ..orderBy([OrderingTerm.asc(rowId)]);
        final rows = await query.get();
        if (!_started || _disposed) return;
        final now = _clock();
        final byPlanet = <String, List<ActivityRow>>{};
        for (final r in rows) {
          final id = r.read(rowId);
          if (id != null && id > _watermark) _watermark = id;
          final row = r.readTable(a);
          if (_recorded.remove(row.id)) continue;
          if (_pending.containsKey('${row.planetKey}|${row.kind}|${row.refTable}|${row.refId}')) continue;
          if (row.at.difference(now).abs() > recentWindow) continue;
          (byPlanet[row.planetKey] ??= []).add(row);
        }
        for (final e in byPlanet.entries) {
          final latest = e.value.last;
          _controller.add(
            PlanetPulse(
              planetKey: e.key,
              kind: latest.kind,
              at: latest.at,
              refTable: latest.refTable,
              refId: latest.refId,
              count: e.value.length,
              origin: PulseOrigin.observed,
              activityId: latest.id,
            ),
          );
        }
      } while (_pollAgain && _started && !_disposed);
    } finally {
      _polling = false;
    }
  }

  /// Stops observing and closes [pulses].
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _stop();
    await _controller.close();
  }
}

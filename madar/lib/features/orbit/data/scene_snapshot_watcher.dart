import 'dart:async';

import 'package:drift/drift.dart';

import '../domain/scene_snapshot.dart';

/// Computes a snapshot at a moment in time.
typedef SnapshotCompute = Future<SceneSnapshot> Function(DateTime now);

/// A live stream of [SceneSnapshot]s.
///
/// Recomputes when
/// * any of [tables] is written (drift table updates), debounced by
///   [debounce] – a burst of writes (an import, a cascade delete) costs one
///   recomputation, and a continuous stream of writes still refreshes at
///   least every [maxWait];
/// * the wall clock crosses a minute boundary (time-based reasons: a dose
///   becomes past due, a person becomes overdue …), at most every [tick];
/// * the current prayer window ends (so the countdown target switches on
///   time, not up to a minute late).
///
/// Only one computation runs at a time; changes during a run schedule one
/// more. Snapshots whose [SceneSnapshot.contentHash] equals the previous
/// one are not emitted, so listeners only hear real changes. Cancelling the
/// subscription stops every timer.
class SceneSnapshotWatcher {
  SceneSnapshotWatcher({
    required this.updates,
    required this.compute,
    DateTime Function()? clock,
    this.debounce = const Duration(milliseconds: 250),
    this.maxWait = const Duration(seconds: 1),
    this.tick = const Duration(seconds: 60),
  }) : _clock = clock ?? DateTime.now;

  /// Watches [tables] of [db].
  factory SceneSnapshotWatcher.forTables(
    DatabaseConnectionUser db,
    Iterable<TableInfo<Table, Object?>> tables, {
    required SnapshotCompute compute,
    DateTime Function()? clock,
    Duration debounce = const Duration(milliseconds: 250),
    Duration maxWait = const Duration(seconds: 1),
    Duration? tick = const Duration(seconds: 60),
  }) => SceneSnapshotWatcher(
    updates: db.tableUpdates(TableUpdateQuery.onAllTables(tables)),
    compute: compute,
    clock: clock,
    debounce: debounce,
    maxWait: maxWait,
    tick: tick,
  );

  /// Change notifications (any event triggers a debounced recomputation).
  final Stream<Object?> updates;
  final SnapshotCompute compute;
  final DateTime Function() _clock;
  final Duration debounce;
  final Duration maxWait;

  /// Longest wait between time-based refreshes (null = no ticking).
  final Duration? tick;

  /// The snapshot stream. Each listen starts its own watch.
  Stream<SceneSnapshot> watch() {
    late final StreamController<SceneSnapshot> controller;
    StreamSubscription<Object?>? changes;
    Timer? debounceTimer;
    Timer? tickTimer;
    DateTime? firstPending;
    DateTime? boundary;
    var running = false;
    var dirty = false;
    var closed = false;
    int? lastHash;

    Future<void> run() async {
      if (closed) return;
      if (running) {
        dirty = true;
        return;
      }
      running = true;
      try {
        do {
          dirty = false;
          final snapshot = await compute(_clock());
          if (closed) return;
          boundary = snapshot.prayer.window.end;
          final hash = snapshot.contentHash;
          if (hash != lastHash) {
            lastHash = hash;
            controller.add(snapshot);
          }
        } while (dirty && !closed);
      } on Object catch (e, st) {
        if (!closed) controller.addError(e, st);
      } finally {
        running = false;
      }
    }

    void onChange(Object? _) {
      final now = DateTime.now();
      firstPending ??= now;
      debounceTimer?.cancel();
      final waited = now.difference(firstPending!);
      final wait = waited + debounce > maxWait ? maxWait - waited : debounce;
      debounceTimer = Timer(wait.isNegative ? Duration.zero : wait, () {
        firstPending = null;
        unawaited(run());
      });
    }

    void scheduleTick() {
      final every = tick;
      if (every == null || closed) return;
      tickTimer?.cancel();
      final now = _clock();
      // Just after the next minute boundary …
      var wait = Duration(seconds: 60 - now.second, milliseconds: 20 - now.millisecond);
      // … or the end of the prayer window, whichever comes first.
      final end = boundary;
      if (end != null && end.isAfter(now)) {
        final toEnd = end.difference(now) + const Duration(milliseconds: 20);
        if (toEnd < wait) wait = toEnd;
      }
      if (wait > every) wait = every;
      tickTimer = Timer(wait, () {
        unawaited(run());
        scheduleTick();
      });
    }

    controller = StreamController<SceneSnapshot>(
      onListen: () {
        changes = updates.listen(onChange, onError: (Object e, StackTrace st) {
          if (!closed) controller.addError(e, st);
        });
        unawaited(run().then((_) => scheduleTick()));
      },
      onCancel: () async {
        closed = true;
        debounceTimer?.cancel();
        tickTimer?.cancel();
        await changes?.cancel();
      },
    );
    return controller.stream;
  }
}

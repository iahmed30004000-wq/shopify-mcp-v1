import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

/// What is being counted. Both are seven rounds ("legs" for the sa'i).
enum RoundKind {
  tawaf(7),
  sai(7);

  const RoundKind(this.rounds);

  /// How many rounds finish this kind.
  final int rounds;

  static RoundKind? parse(Object? name) {
    for (final k in values) {
      if (k.name == name) return k;
    }
    return null;
  }
}

/// The two ends of the sa'i.
enum SaiPoint {
  safa,
  marwa;

  SaiPoint get other => this == safa ? marwa : safa;

  static SaiPoint? parse(Object? name) {
    for (final p in values) {
      if (p.name == name) return p;
    }
    return null;
  }
}

/// Where a counting session stands.
enum CounterPhase {
  /// No tap counted yet.
  notStarted,

  /// Counting; the round now being walked is [RoundSession.currentRound].
  inProgress,

  /// Counting is switched off; taps are ignored until resumed.
  paused,

  /// All rounds counted. Taps are ignored until a new session is started.
  complete,
}

/// What a tap did.
enum TapResult {
  /// A round was counted.
  counted,

  /// The last round was counted: the session is complete.
  completed,

  /// Too soon after the previous counted tap (a pocket double-tap).
  debounced,

  /// Counting is paused.
  paused,

  /// The session is already complete (start another to count again).
  ignoredComplete,

  /// There is no session at all.
  noSession;

  bool get counts => this == counted || this == completed;
}

/// One tawaf or sa'i, from the first tap to the last. Immutable.
///
/// [count] is the number of rounds already FINISHED (a tap = "I finished
/// this round"), so the round being walked is `count + 1`.
@immutable
class RoundSession {
  const RoundSession({
    required this.id,
    required this.kind,
    required this.startedAtMs,
    this.saiStart = SaiPoint.safa,
    this.count = 0,
    this.undoable = 0,
    this.paused = false,
    this.abandoned = false,
    this.completedAtMs,
  }) : assert(count >= 0),
       assert(undoable >= 0);

  final String id;
  final RoundKind kind;

  /// Wall-clock UTC milliseconds when the session was created. Only for
  /// showing and ordering history; counting never reads the wall clock.
  final int startedAtMs;

  /// Where the sa'i begins. Everything about the direction is derived from
  /// this and the leg number. Unused for the tawaf.
  final SaiPoint saiStart;

  /// Finished rounds, 0..[total].
  final int count;

  /// Taps that [RoundCounter.undo] may still take back (cleared by a manual
  /// correction).
  final int undoable;

  final bool paused;

  /// Left unfinished because the person started another one.
  final bool abandoned;

  final int? completedAtMs;

  int get total => kind.rounds;

  bool get isComplete => count >= total;

  CounterPhase get phase {
    if (isComplete) return CounterPhase.complete;
    if (paused) return CounterPhase.paused;
    return count == 0 ? CounterPhase.notStarted : CounterPhase.inProgress;
  }

  /// The round being walked now, 1..[total] (the last one once complete).
  int get currentRound => isComplete ? total : count + 1;

  /// Sa'i only: the point he is walking TOWARD now (leg 1 from Safa heads to
  /// Marwa, leg 2 back to Safa, ...). Null for the tawaf and once complete.
  SaiPoint? get headingTo {
    if (kind != RoundKind.sai || isComplete) return null;
    return currentRound.isOdd ? saiStart.other : saiStart;
  }

  /// Sa'i only: where the last leg ends (Marwa for a sa'i begun at Safa).
  SaiPoint? get endPoint {
    if (kind != RoundKind.sai) return null;
    return total.isOdd ? saiStart.other : saiStart;
  }

  RoundSession copyWith({
    int? count,
    int? undoable,
    bool? paused,
    bool? abandoned,
    Object? completedAtMs = _keep,
    RoundKind? kind,
    SaiPoint? saiStart,
  }) => RoundSession(
    id: id,
    kind: kind ?? this.kind,
    startedAtMs: startedAtMs,
    saiStart: saiStart ?? this.saiStart,
    count: count ?? this.count,
    undoable: undoable ?? this.undoable,
    paused: paused ?? this.paused,
    abandoned: abandoned ?? this.abandoned,
    completedAtMs: identical(completedAtMs, _keep) ? this.completedAtMs : completedAtMs as int?,
  );

  static const Object _keep = Object();

  Map<String, Object?> toJson() => {
    'id': id,
    'kind': kind.name,
    'startedAtMs': startedAtMs,
    'saiStart': saiStart.name,
    'count': count,
    'undoable': undoable,
    'paused': paused,
    'abandoned': abandoned,
    'completedAtMs': ?completedAtMs,
  };

  /// Tolerant: a session whose id or kind is unreadable is dropped (null);
  /// numbers are clamped into range so a damaged file can never throw.
  static RoundSession? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final kind = RoundKind.parse(json['kind']);
    if (id is! String || id.isEmpty || kind == null) return null;
    final count = _int(json['count'], 0).clamp(0, kind.rounds);
    return RoundSession(
      id: id,
      kind: kind,
      startedAtMs: _int(json['startedAtMs'], 0),
      saiStart: SaiPoint.parse(json['saiStart']) ?? SaiPoint.safa,
      count: count,
      undoable: _int(json['undoable'], 0).clamp(0, count),
      paused: json['paused'] == true && count < kind.rounds,
      abandoned: json['abandoned'] == true,
      completedAtMs: count >= kind.rounds && json['completedAtMs'] is num ? _int(json['completedAtMs'], 0) : null,
    );
  }

  static int _int(Object? v, int fallback) => v is num ? v.toInt() : fallback;

  @override
  bool operator ==(Object other) =>
      other is RoundSession &&
      other.id == id &&
      other.kind == kind &&
      other.startedAtMs == startedAtMs &&
      other.saiStart == saiStart &&
      other.count == count &&
      other.undoable == undoable &&
      other.paused == paused &&
      other.abandoned == abandoned &&
      other.completedAtMs == completedAtMs;

  @override
  int get hashCode =>
      Object.hash(id, kind, startedAtMs, saiStart, count, undoable, paused, abandoned, completedAtMs);

  @override
  String toString() => 'RoundSession(${kind.name} $count/$total${paused ? ' paused' : ''})';
}

/// The round counter: a list of sessions, the last one being the one in
/// hand. Pure Dart: time comes only from the injected clocks.
///
/// * Debounce is measured on [monotonic] (a stopwatch that only moves
///   forward), so a wall-clock jump, a time-zone change or a daylight-saving
///   step cannot make a tap count twice or be swallowed. The wall clock is
///   only used to stamp sessions for the history.
/// * Every change is synchronous and in memory; persistence is the caller's
///   job (see `RoundCounterPersister`) using [toJson], which is versioned.
class RoundCounter {
  RoundCounter({
    this.debounce = defaultDebounce,
    Duration Function()? monotonic,
    DateTime Function()? wallClock,
    String Function()? newId,
    Iterable<RoundSession> sessions = const [],
  }) : _monotonic = monotonic ?? _stopwatchClock(),
       _wallClock = wallClock ?? DateTime.now,
       _newId = newId ?? (() => const Uuid().v4()),
       _sessions = List.of(sessions);

  /// Long enough to swallow a pocket double-tap, short enough that a
  /// deliberate round (always much slower) is never lost.
  static const Duration defaultDebounce = Duration(milliseconds: 700);

  /// Newest sessions kept in the history.
  static const int maxSessions = 100;

  /// Format version of [toJson].
  static const int version = 1;

  final Duration debounce;
  final Duration Function() _monotonic;
  final DateTime Function() _wallClock;
  final String Function() _newId;
  final List<RoundSession> _sessions;

  /// Monotonic reading of the last COUNTED tap. Never persisted: a monotonic
  /// clock restarts with the process, and a restart is far beyond the
  /// debounce anyway.
  Duration? _lastCounted;

  static Duration Function() _stopwatchClock() {
    final sw = Stopwatch()..start();
    return () => sw.elapsed;
  }

  /// Oldest first.
  List<RoundSession> get sessions => List.unmodifiable(_sessions);

  /// The session in hand (the newest), if any.
  RoundSession? get active => _sessions.isEmpty ? null : _sessions.last;

  CounterPhase get phase => active?.phase ?? CounterPhase.notStarted;

  /// Sessions that reached their last round, oldest first.
  List<RoundSession> completedOf(RoundKind kind) => [
    for (final s in _sessions)
      if (s.kind == kind && s.isComplete) s,
  ];

  bool get canUndo => (active?.undoable ?? 0) > 0;

  /// Starts a new session. Returns false (nothing changes) when a session
  /// has been begun and not finished, unless [abandonCurrent] retires it.
  /// A session with no round counted yet is simply replaced, so choosing
  /// tawaf instead of sa'i leaves no empty entry behind.
  bool start(RoundKind kind, {SaiPoint saiStart = SaiPoint.safa, bool abandonCurrent = false}) {
    final cur = active;
    if (cur != null) {
      final begun = cur.count > 0 && !cur.isComplete;
      if (begun && !abandonCurrent) return false;
      if (cur.count == 0) {
        _sessions.removeLast();
      } else if (begun) {
        _sessions[_sessions.length - 1] = cur.copyWith(abandoned: true, paused: false, undoable: 0);
      }
    }
    _sessions.add(RoundSession(id: _newId(), kind: kind, saiStart: saiStart, startedAtMs: _stamp()));
    if (_sessions.length > maxSessions) _sessions.removeRange(0, _sessions.length - maxSessions);
    _lastCounted = null;
    return true;
  }

  /// One round finished. See [TapResult].
  TapResult tap() {
    final cur = active;
    if (cur == null) return TapResult.noSession;
    if (cur.isComplete) return TapResult.ignoredComplete;
    if (cur.paused) return TapResult.paused;
    final now = _monotonic();
    final last = _lastCounted;
    if (last != null && now - last < debounce) return TapResult.debounced;
    _lastCounted = now;
    final count = cur.count + 1;
    final done = count >= cur.total;
    _replace(cur.copyWith(count: count, undoable: cur.undoable + 1, completedAtMs: done ? _stamp() : null));
    return done ? TapResult.completed : TapResult.counted;
  }

  /// Takes back the last counted tap (also from a complete session). False
  /// when there is none to take back (nothing counted yet, or since a manual
  /// correction).
  bool undo() {
    final cur = active;
    if (cur == null || cur.undoable <= 0 || cur.count <= 0) return false;
    _replace(cur.copyWith(count: cur.count - 1, undoable: cur.undoable - 1, completedAtMs: null));
    // The next tap is a deliberate one: do not let the old window swallow it.
    _lastCounted = null;
    return true;
  }

  /// Manual correction: "I am on round [round] now" (1..total), i.e. the
  /// rounds before it are finished. Works while paused and also reopens a
  /// complete session. Completing needs a tap, never a correction. Returns
  /// false and changes nothing when [round] is out of range.
  bool setRound(int round) {
    final cur = active;
    if (cur == null || round < 1 || round > cur.total) return false;
    _replace(cur.copyWith(count: round - 1, undoable: 0, completedAtMs: null));
    _lastCounted = null;
    return true;
  }

  bool pause() {
    final cur = active;
    if (cur == null || cur.isComplete || cur.paused) return false;
    _replace(cur.copyWith(paused: true));
    return true;
  }

  bool resume() {
    final cur = active;
    if (cur == null || !cur.paused) return false;
    _replace(cur.copyWith(paused: false));
    // Resuming is a deliberate act; the first tap after it must count.
    _lastCounted = null;
    return true;
  }

  /// The guard behind a "done" button: true only when every round has been
  /// counted. A session cannot be finished early (use [start] with
  /// `abandonCurrent` to leave one unfinished).
  bool finish() => active?.isComplete ?? false;

  void _replace(RoundSession s) => _sessions[_sessions.length - 1] = s;

  int _stamp() => _wallClock().toUtc().millisecondsSinceEpoch;

  /// Versioned, ready for `jsonEncode`.
  Map<String, Object?> toJson() => {
    'v': version,
    'sessions': [for (final s in _sessions) s.toJson()],
  };

  /// Restores a counter after the app was killed. Never throws: anything
  /// unreadable gives an empty counter (or drops only the damaged sessions).
  /// A newer format version is read on a best-effort basis rather than
  /// discarded, because losing a count is worse than misreading a field.
  factory RoundCounter.fromJson(
    Object? json, {
    Duration debounce = defaultDebounce,
    Duration Function()? monotonic,
    DateTime Function()? wallClock,
    String Function()? newId,
  }) {
    final raw = json is Map ? json['sessions'] : null;
    final sessions = <RoundSession>[
      if (raw is List)
        for (final s in raw) ?RoundSession.fromJson(s),
    ];
    final tail = sessions.length > maxSessions ? sessions.sublist(sessions.length - maxSessions) : sessions;
    return RoundCounter(
      debounce: debounce,
      monotonic: monotonic,
      wallClock: wallClock,
      newId: newId,
      sessions: tail,
    );
  }
}

/// A game played together: one [TogetherSession] per device, talking over a
/// [TogetherTransport] – or a single session with both players on one device
/// ([TogetherSession.local]).
///
/// * **Start** – the host draws a 32-bit seed and sends it with the config
///   and the seating; both sides build the initial state from it and compare
///   state hashes, so shuffles and dice are identical.
/// * **Turns** – only the participant controlling the seat to move may move
///   (AI seats are driven by the host). Every move carries the turn number
///   and the hash of the resulting state.
/// * **Order** – sequenced messages are numbered and acknowledged; late ones
///   are buffered and reordered, duplicates ignored, gaps trigger a `sync`
///   and the peer retransmits what was not acknowledged.
/// * **Resync** – after a reconnection both sides exchange `sync` (turn +
///   state hash). A mismatch, an illegal or out-of-turn move, or a lost
///   history makes the host send its authoritative snapshot.
/// * **Results** – the end of the game is recorded into the head-to-head
///   history through [recorder] (idempotent by match id).
library;

import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../domain/match_record.dart';
import '../domain/play_modes.dart';
import '../domain/player_profile.dart';
import '../domain/trophies.dart';
import 'envelope.dart';
import 'game_data.dart';
import 'together_game.dart';
import 'transport.dart';

/// Which side of a two-device session this is. A local session (both
/// players on one device) is a host.
enum SessionRole { host, guest }

enum SessionPhase {
  /// Not started yet (guest: waiting for the host's start).
  waiting,
  playing,
  finished,

  /// The peer left before the end.
  abandoned,

  /// The two sides cannot play together (different game or rules version).
  failed,
}

/// Records a finished match (the repository's `recordMatch`).
typedef TogetherResultRecorder = Future<RecordedMatch?> Function(MatchRecord record);

/// A local move or input was refused. [code]: `notStarted`, `finished`,
/// `notYourTurn`, `notYourSeat`, or the game's own illegal-move id.
final class TogetherMoveRefused implements Exception {
  const TogetherMoveRefused(this.code);

  final String code;

  @override
  String toString() => 'TogetherMoveRefused($code)';
}

/// Something that happened in a session.
sealed class SessionEvent {
  const SessionEvent();
}

final class SessionStarted extends SessionEvent {
  const SessionStarted(this.seed);

  final int seed;
}

final class MoveApplied<M> extends SessionEvent {
  const MoveApplied({required this.seat, required this.move, required this.turn, required this.remote});

  final int seat;
  final M move;
  final int turn;

  /// Played on the other device.
  final bool remote;
}

final class InputReceived extends SessionEvent {
  const InputReceived({required this.seat, required this.tick, required this.input});

  final int seat;
  final int tick;
  final GameData input;
}

/// The state was replaced by the host's snapshot.
final class StateResynced extends SessionEvent {
  const StateResynced(this.turn);

  final int turn;
}

final class SessionFinished extends SessionEvent {
  const SessionFinished({required this.outcome, required this.record});

  final SeatOutcome outcome;
  final MatchRecord record;
}

/// An incoming frame failed the whitelist and was dropped.
final class FrameRejected extends SessionEvent {
  const FrameRejected(this.error);

  final TogetherDataRejected error;
}

final class PeerLeft extends SessionEvent {
  const PeerLeft();
}

final class SessionFailed extends SessionEvent {
  const SessionFailed(this.reason);

  final String reason;
}

/// Seatings for games with more seats than players.
abstract final class TogetherSeats {
  /// AI seats are driven by the host.
  static const int ai = -1;

  /// Two players on seats 0 and 1, AIs elsewhere (rivals, each with an AI
  /// partner in 4-seat partnership games: teams 0&2 and 1&3).
  static List<int> rivals(int seatCount) => [for (var s = 0; s < seatCount; s++) s < 2 ? s : ai];

  /// The couple as partners on seats 0 and 2 against AIs on 1 and 3.
  static List<int> partners(int seatCount) => [
    for (var s = 0; s < seatCount; s++)
      switch (s) {
        0 => 0,
        2 => 1,
        _ => ai,
      },
  ];
}

class TogetherSession<S, M> extends ChangeNotifier {
  TogetherSession({
    required this.adapter,
    required this.transport,
    this.role = SessionRole.host,
    List<int>? seats,
    this.seating = const [PlayerSlot.one, PlayerSlot.two],
    this.recorder,
    GameData? config,
    math.Random? random,
    DateTime Function()? clock,
  }) : _random = random ?? math.Random.secure(),
       _clock = clock ?? DateTime.now,
       _codec = TogetherCodec(policy: adapter.policy),
       _config = config ?? GameData.empty,
       _seats = List.unmodifiable(seats ?? TogetherSeats.rivals(adapter.seatCount)) {
    if (_seats.length != adapter.seatCount) throw ArgumentError.value(seats, 'seats', 'one entry per seat');
    if (seating.length != 2 || seating[0] == seating[1]) throw ArgumentError.value(seating, 'seating');
    _sessionId = _randomId();
    _sub = transport.incoming.listen(_onFrame);
    _lastStatus = transport.status.value;
    transport.status.addListener(_onStatus);
    if (role == SessionRole.guest && _lastStatus == TransportStatus.connected) _sendHello();
  }

  /// Both players on this device (pass-and-play, split-screen): nothing is
  /// transmitted, but every move still passes the whitelist codec.
  factory TogetherSession.local({
    required TogetherGameAdapter<S, M> adapter,
    PlayMode mode = PlayMode.passAndPlay,
    List<int>? seats,
    List<PlayerSlot> seating = const [PlayerSlot.one, PlayerSlot.two],
    TogetherResultRecorder? recorder,
    GameData? config,
    math.Random? random,
    DateTime Function()? clock,
  }) => TogetherSession(
    adapter: adapter,
    transport: PassAndPlayTransport(mode: mode),
    seats: seats,
    seating: seating,
    recorder: recorder,
    config: config,
    random: random,
    clock: clock,
  );

  final TogetherGameAdapter<S, M> adapter;
  final TogetherTransport transport;
  final SessionRole role;

  /// Participant → player: `seating[0]` is the host's player.
  final List<PlayerSlot> seating;
  final TogetherResultRecorder? recorder;

  final math.Random _random;
  final DateTime Function() _clock;
  final TogetherCodec _codec;
  GameData _config;
  List<int> _seats;
  late String _sessionId;
  StreamSubscription<String>? _sub;
  late TransportStatus _lastStatus;

  int? _seed;
  S? _state;
  int _turn = 0;
  String? _hash;
  String? _initialHash;
  SessionPhase _phase = SessionPhase.waiting;
  String? _failure;
  SeatOutcome? _outcome;
  MatchRecord? _record;
  DateTime? _startedAt;
  final Completer<RecordedMatch?> _recorded = Completer<RecordedMatch?>();
  final ValueNotifier<int?> _activeParticipant = ValueNotifier(null);
  final StreamController<SessionEvent> _events = StreamController<SessionEvent>.broadcast();

  // Ordering and retransmission.
  static const int _maxOutbox = 256;
  static const int _maxPending = 256;
  int _nextSeq = 1;
  int _lastInOrder = 0;
  int _droppedUpTo = 0;
  final SplayTreeMap<int, TogetherEnvelope> _pending = SplayTreeMap();
  final ListQueue<(int, TogetherBody)> _outbox = ListQueue();
  final Map<int, int> _lastInputTick = {};
  int _rejectedFrames = 0;
  int _unstartedFrames = 0;
  bool _disposed = false;

  // ------------------------------------------------------------ read state

  String get sessionId => _sessionId;

  /// The match id recorded in the history (the host's session id).
  String get matchId => _sessionId;

  int? get seed => _seed;

  bool get started => _state != null;

  /// The current state (throws before the start).
  S get state => _state ?? (throw StateError('the session has not started'));

  S? get stateOrNull => _state;

  /// Moves applied so far (or the snapshot's turn).
  int get turn => _turn;

  /// Hash of the current state.
  String? get stateHash => _hash;

  SessionPhase get phase => _phase;

  /// Why the session failed / ended: `incompatibleGame` (other game or
  /// rules version – on either side), `incompatibleProtocol` (the peer
  /// speaks another wire version), `peerLeft`, `left`.
  String? get failure => _failure;

  SeatOutcome? get outcome => _outcome;

  MatchRecord? get record => _record;

  /// Completes once the result has been recorded (null without a recorder).
  Future<RecordedMatch?> get recorded => _recorded.future;

  /// Seat → participant (0 host, 1 guest, [TogetherSeats.ai]).
  List<int> get seats => _seats;

  GameData get config => _config;

  Stream<SessionEvent> get events => _events.stream;

  /// Frames refused by the whitelist.
  int get rejectedFrames => _rejectedFrames;

  /// The seat that must act next.
  int? get seatToMove => _state == null || _phase != SessionPhase.playing ? null : adapter.seatToMove(_state as S);

  /// The participant whose private view should be on screen (pass-and-play
  /// hand-off): the owner of the seat to move; AI turns keep the previous
  /// one; null before the start and after the end.
  ValueListenable<int?> get activeParticipant => _activeParticipant;

  /// The player of [participant].
  PlayerSlot slotOf(int participant) => seating[participant];

  /// The participant of [slot].
  int participantOf(PlayerSlot slot) => seating.indexOf(slot);

  /// Whether this device controls [seat] (its own players, and AI seats on
  /// the host).
  bool controlsSeat(int seat) {
    if (seat < 0 || seat >= _seats.length) return false;
    final p = _seats[seat];
    if (p == TogetherSeats.ai) return role == SessionRole.host;
    return transport.localParticipants.contains(p);
  }

  /// Whether this device may play now (optionally for [seat]).
  bool canPlay([int? seat]) {
    final s = seatToMove;
    if (s == null || (seat != null && seat != s)) return false;
    return controlsSeat(s);
  }

  // --------------------------------------------------------------- actions

  /// Host: starts the game with a shared [seed] (random when omitted).
  Future<void> start({int? seed}) async {
    if (role != SessionRole.host) throw StateError('only the host starts a session');
    if (_state != null) throw StateError('the session has already started');
    if (_phase == SessionPhase.failed) throw StateError('the session failed: $_failure');
    final s = (seed ?? _random.nextInt(1 << 32)) & 0xFFFFFFFF;
    final initial = adapter.initialState(seed: s, config: _config);
    final hash = _hashOf(initial);
    _seed = s;
    _state = initial;
    _turn = 0;
    _hash = hash;
    _initialHash = hash;
    _phase = SessionPhase.playing;
    _startedAt = _clock();
    _sendStart();
    _emit(SessionStarted(s));
    _afterStateChange();
  }

  /// Plays [move] for [seat] (default: the seat to move). Throws
  /// [TogetherMoveRefused] when it is not this device's turn or the move is
  /// illegal, and [TogetherDataRejected] when the move's data is not pure
  /// game data – nothing is applied or sent then.
  Future<void> play(M move, {int? seat}) async {
    final current = _state;
    if (current == null) throw const TogetherMoveRefused('notStarted');
    if (_phase != SessionPhase.playing) throw const TogetherMoveRefused('finished');
    final toMove = adapter.seatToMove(current);
    final s = seat ?? toMove;
    if (s == null || s != toMove) throw const TogetherMoveRefused('notYourTurn');
    if (!controlsSeat(s)) throw const TogetherMoveRefused('notYourSeat');
    final error = adapter.validateMove(current, s, move);
    if (error != null) throw TogetherMoveRefused(error);
    final data = GameData(adapter.encodeMove(move), policy: adapter.policy);
    final next = adapter.applyMove(current, s, move);
    final hash = _hashOf(next);
    _state = next;
    _turn++;
    _hash = hash;
    _send(MoveBody(turn: _turn, seat: s, move: data, hash: hash));
    _emit(MoveApplied<M>(seat: s, move: move, turn: _turn, remote: false));
    _afterStateChange();
  }

  /// Real-time: sends an input of a local [seat] to the peer (latest wins).
  void sendInput(int seat, Object? input, {required int tick}) {
    if (_state == null) throw const TogetherMoveRefused('notStarted');
    if (!controlsSeat(seat)) throw const TogetherMoveRefused('notYourSeat');
    _send(InputBody(tick: tick, seat: seat, input: GameData(input, policy: adapter.policy)));
  }

  /// Host, real-time: replaces the state with the simulation's [next] and
  /// sends it to the guest as a snapshot ([turn] defaults to the next one).
  void publishState(S next, {int? turn}) {
    if (role != SessionRole.host) throw StateError('only the host publishes the state');
    if (_state == null) throw const TogetherMoveRefused('notStarted');
    final hash = _hashOf(next);
    _state = next;
    _turn = turn ?? _turn + 1;
    _hash = hash;
    _sendSnapshot();
    _afterStateChange();
  }

  /// Host: ends the game with [outcome] (real-time games, resignations,
  /// simultaneous answers) and records it.
  Future<RecordedMatch?> finish(SeatOutcome outcome) async {
    if (role != SessionRole.host) throw StateError('only the host declares a result');
    if (_state == null) throw const TogetherMoveRefused('notStarted');
    if (_phase == SessionPhase.playing) _finish(outcome, announce: true);
    return recorded;
  }

  /// Asks the peer to compare states now (a manual "sync" button).
  void resync() => _sendSync();

  /// Leaves the session (the peer sees [PeerLeft]).
  Future<void> leave() async {
    if (_disposed) return;
    _send(const ByeBody());
    if (_phase == SessionPhase.playing || _phase == SessionPhase.waiting) {
      _phase = SessionPhase.abandoned;
      _failure = 'left';
      _activeParticipant.value = null;
      _notify();
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    unawaited(_sub?.cancel());
    transport.status.removeListener(_onStatus);
    unawaited(transport.close());
    unawaited(_events.close());
    _activeParticipant.dispose();
    if (!_recorded.isCompleted) _recorded.complete(null);
    super.dispose();
  }

  // --------------------------------------------------------------- sending

  void _send(TogetherBody body) {
    if (_disposed) return;
    final seq = body.kind.sequenced ? _nextSeq++ : 0;
    if (seq > 0) {
      // A reset (start, snapshot) supersedes every earlier message: the peer
      // jumps to it on arrival, so they are never retransmitted again (a
      // real-time host publishing snapshots through a disconnection would
      // otherwise resend hundreds of stale states). A snapshot keeps the
      // start – a guest that missed it cannot use a snapshot.
      if (body.kind.resets) {
        _outbox.removeWhere((e) => body.kind == TogetherMessageKind.start || e.$2.kind != TogetherMessageKind.start);
      }
      _outbox.add((seq, body));
      while (_outbox.length > _maxOutbox) {
        _droppedUpTo = _outbox.removeFirst().$1;
      }
    }
    _transmit(seq, body);
  }

  void _transmit(int seq, TogetherBody body) {
    final frame = _codec.encode(
      TogetherEnvelope(sessionId: _sessionId, from: _me, body: body, seq: seq, ack: _lastInOrder),
    );
    unawaited(transport.send(frame));
  }

  /// This device's participant id on the wire (a shared device speaks as the
  /// host).
  int get _me => role == SessionRole.host ? 0 : 1;

  int get _peer => 1 - _me;

  void _sendHello() => _send(HelloBody(gameId: adapter.gameId, gameVersion: adapter.gameVersion));

  void _sendStart() => _send(
    StartBody(
      gameId: adapter.gameId,
      gameVersion: adapter.gameVersion,
      seed: _seed!,
      config: _config,
      seats: _seats,
      hash: _initialHash!,
    ),
  );

  void _sendSnapshot() {
    final s = _state;
    if (s == null || role != SessionRole.host) return;
    _send(
      SnapshotBody(
        turn: _turn,
        state: GameData(adapter.encodeState(s), policy: adapter.policy),
        hash: _hash!,
      ),
    );
    if (_phase == SessionPhase.finished && _outcome != null) _sendResult(_outcome!);
  }

  void _sendSync() => _send(SyncBody(turn: _turn, hash: _hash));

  void _sendResult(SeatOutcome o) => _send(
    ResultBody(
      matchId: matchId,
      outcome: o.isLoss
          ? SeatOutcomeKind.loss
          : o.isDraw
          ? SeatOutcomeKind.draw
          : SeatOutcomeKind.win,
      winners: o.winners,
      scores: o.scores,
    ),
  );

  void _retransmit() {
    for (final (seq, body) in _outbox.toList()) {
      _transmit(seq, body);
    }
  }

  // ------------------------------------------------------------- receiving

  void _onStatus() {
    final status = transport.status.value;
    final was = _lastStatus;
    _lastStatus = status;
    if (status == TransportStatus.connected && was != TransportStatus.connected) {
      if (_state != null) {
        _sendSync();
      } else if (role == SessionRole.guest) {
        _sendHello();
      }
    }
    _notify();
  }

  void _onFrame(String text) {
    if (_disposed) return;
    final TogetherEnvelope env;
    try {
      env = _codec.decode(text);
    } on TogetherDataRejected catch (e) {
      _reject(e);
      // A Together peer speaking another protocol version: stop – never
      // wait forever for frames this build cannot read.
      if (e.reason == TogetherRejection.unsupportedVersion) _fail('incompatibleProtocol');
      return;
    }
    // A peer only ever speaks as itself.
    if (env.from != _peer || transport.localParticipants.contains(env.from)) {
      _reject(const TogetherDataRejected(TogetherRejection.wrongType, 'from'));
      return;
    }
    if (!_acceptsSession(env)) {
      // A guest without the start (lost on the way) hears the host playing:
      // ask again (the host answers with the start and a snapshot).
      if (role == SessionRole.guest && _state == null && _phase == SessionPhase.waiting) {
        if (_unstartedFrames++ % 8 == 0) _sendHello();
      }
      return;
    }
    _prune(env.ack);
    if (!env.kind.sequenced) {
      _control(env);
      return;
    }
    if (env.seq <= _lastInOrder) return; // duplicate or stale
    if (env.kind.resets) {
      _lastInOrder = env.seq;
      _pending.removeWhere((seq, _) => seq <= env.seq);
      _process(env);
      _drain();
      return;
    }
    if (env.seq == _lastInOrder + 1) {
      _lastInOrder = env.seq;
      _process(env);
      _drain();
      return;
    }
    // Early: keep it and ask the peer to retransmit what is missing.
    _pending[env.seq] = env;
    while (_pending.length > _maxPending) {
      _pending.remove(_pending.lastKey());
    }
    if (_pending.length <= 4 || _pending.length % 16 == 0) _sendSync();
  }

  bool _acceptsSession(TogetherEnvelope env) {
    if (_phase == SessionPhase.failed) return false;
    if (role == SessionRole.host) {
      // The guest learns the session id from `start`; its hello may carry its
      // own provisional id. Before the start a guest has nothing else to
      // say: anything sequenced is a stray from another session and must not
      // move this session's ordering.
      if (env.kind == TogetherMessageKind.hello) return true;
      if (_state == null) return env.kind == TogetherMessageKind.bye;
      return env.sessionId == _sessionId;
    }
    if (_state == null) return env.kind == TogetherMessageKind.start || env.kind == TogetherMessageKind.bye;
    return env.sessionId == _sessionId;
  }

  void _reject(TogetherDataRejected e) {
    _rejectedFrames++;
    _emit(FrameRejected(e));
  }

  void _prune(int ack) {
    while (_outbox.isNotEmpty && _outbox.first.$1 <= ack) {
      _outbox.removeFirst();
    }
  }

  void _drain() {
    while (true) {
      final next = _pending.remove(_lastInOrder + 1);
      if (next == null) break;
      _lastInOrder = next.seq;
      _process(next);
    }
  }

  void _control(TogetherEnvelope env) {
    switch (env.body) {
      case HelloBody b:
        _onHello(b);
      case SyncBody b:
        _onSync(env, b);
      case ResyncBody _:
        if (role == SessionRole.host) _sendSnapshot();
      case InputBody b:
        _onInput(env, b);
      case ByeBody b:
        _onBye(b);
      case StartBody() || MoveBody() || SnapshotBody() || ResultBody():
        break; // sequenced kinds never arrive here (the codec checks seq)
    }
  }

  void _process(TogetherEnvelope env) {
    switch (env.body) {
      case StartBody b:
        _onStart(env, b);
      case MoveBody b:
        _onMove(env, b);
      case SnapshotBody b:
        _onSnapshot(b);
      case ResultBody b:
        _onResult(b);
      case HelloBody() || SyncBody() || ResyncBody() || InputBody() || ByeBody():
        break;
    }
  }

  void _onHello(HelloBody b) {
    if (role != SessionRole.host) return;
    if (b.gameId != adapter.gameId || b.gameVersion != adapter.gameVersion) {
      _fail('incompatibleGame');
      return;
    }
    if (_state == null) return;
    // A (re)joining guest: the start, then where the game is now.
    _sendStart();
    if (_turn > 0 || _phase == SessionPhase.finished) _sendSnapshot();
  }

  void _onStart(TogetherEnvelope env, StartBody b) {
    if (role != SessionRole.guest) return;
    // The host re-sends the start when a hello reaches it after the game
    // began (a late or duplicated hello, a reconnection); a snapshot follows
    // whenever the game has moved on. Never rewind an ongoing – or finished –
    // game to its first position.
    if (_state != null) return;
    // From now on speak in the host's session (a bye must reach it).
    _sessionId = env.sessionId;
    if (b.gameId != adapter.gameId || b.gameVersion != adapter.gameVersion || b.seats.length != adapter.seatCount) {
      _fail('incompatibleGame');
      return;
    }
    final S initial;
    final String hash;
    try {
      initial = adapter.initialState(seed: b.seed, config: b.config);
      hash = _hashOf(initial);
    } on Object {
      _fail('incompatibleGame');
      return;
    }
    if (hash != b.hash) {
      // Same game id, different rules: never play on diverging boards.
      _fail('incompatibleGame');
      return;
    }
    _seed = b.seed;
    _config = b.config;
    _seats = b.seats;
    _state = initial;
    _turn = 0;
    _hash = hash;
    _initialHash = hash;
    _phase = SessionPhase.playing;
    _startedAt = _clock();
    _emit(SessionStarted(b.seed));
    _afterStateChange();
  }

  void _onMove(TogetherEnvelope env, MoveBody b) {
    final current = _state;
    if (current == null) return;
    if (b.turn <= _turn) return; // already applied (e.g. via a snapshot)
    if (b.turn > _turn + 1) {
      _outOfSync();
      return;
    }
    // Turn ownership: the sender must control the seat, and it must be that
    // seat's turn.
    final owner = b.seat < _seats.length ? _seats[b.seat] : null;
    final senderOwns = owner == env.from || (owner == TogetherSeats.ai && env.from == 0);
    if (!senderOwns || _phase != SessionPhase.playing || adapter.seatToMove(current) != b.seat) {
      _outOfSync();
      return;
    }
    final M move;
    final S next;
    final String hash;
    try {
      move = adapter.decodeMove(b.move.value);
      if (adapter.validateMove(current, b.seat, move) != null) {
        _outOfSync();
        return;
      }
      next = adapter.applyMove(current, b.seat, move);
      hash = _hashOf(next);
    } on Object {
      _outOfSync();
      return;
    }
    _state = next;
    _turn = b.turn;
    _hash = hash;
    _emit(MoveApplied<M>(seat: b.seat, move: move, turn: _turn, remote: true));
    if (hash != b.hash) _outOfSync();
    _afterStateChange();
  }

  void _onSnapshot(SnapshotBody b) {
    if (role != SessionRole.guest || _state == null) return;
    final S decoded;
    final String hash;
    try {
      decoded = adapter.decodeState(b.state.value);
      hash = _hashOf(decoded);
    } on Object {
      return;
    }
    if (hash != b.hash) return;
    _state = decoded;
    _turn = b.turn;
    _hash = hash;
    if (_phase == SessionPhase.waiting) _phase = SessionPhase.playing;
    _emit(StateResynced(b.turn));
    _afterStateChange();
  }

  void _onResult(ResultBody b) {
    // The host is the referee (the codec already refuses a guest's result).
    if (role != SessionRole.guest || _state == null || _phase == SessionPhase.finished) return;
    final o = switch (b.outcome) {
      SeatOutcomeKind.draw => SeatOutcome.draw(scores: b.scores),
      SeatOutcomeKind.loss => SeatOutcome.loss(scores: b.scores),
      SeatOutcomeKind.win => SeatOutcome(winners: b.winners, scores: b.scores),
    };
    _finish(o, announce: false);
  }

  void _onSync(TogetherEnvelope env, SyncBody b) {
    // env.ack already pruned what the peer has; send it the rest.
    final lostHistory = env.ack < _droppedUpTo;
    _retransmit();
    final current = _state;
    if (role == SessionRole.host) {
      if (current == null) return;
      if (b.hash == null) {
        // The guest never got the start.
        _sendStart();
        if (_turn > 0 || _phase == SessionPhase.finished) _sendSnapshot();
      } else if (lostHistory || (b.turn == _turn && b.hash != _hash)) {
        _sendSnapshot();
      } else if (b.turn > _turn) {
        _sendSync(); // the guest is ahead: tell it what we have, it resends
      }
    } else {
      if (current == null) {
        _sendHello();
      } else if (lostHistory || (b.turn == _turn && b.hash != null && b.hash != _hash)) {
        _send(ResyncBody(turn: _turn, hash: _hash));
      } else if (b.turn > _turn) {
        _sendSync(); // behind: our ack makes the host resend what we lack
      }
    }
  }

  void _onInput(TogetherEnvelope env, InputBody b) {
    if (_state == null) return;
    final owner = b.seat < _seats.length ? _seats[b.seat] : null;
    if (owner != env.from && !(owner == TogetherSeats.ai && env.from == 0)) return;
    final last = _lastInputTick[b.seat];
    if (last != null && b.tick <= last) return;
    _lastInputTick[b.seat] = b.tick;
    _emit(InputReceived(seat: b.seat, tick: b.tick, input: b.input));
  }

  void _onBye(ByeBody b) {
    if (b.reason == ByeReason.incompatible) {
      _fail('incompatibleGame', tellPeer: false);
      return;
    }
    if (_phase == SessionPhase.finished || _phase == SessionPhase.failed) return;
    _phase = SessionPhase.abandoned;
    _failure = 'peerLeft';
    _activeParticipant.value = null;
    _emit(const PeerLeft());
    _notify();
  }

  /// The two states disagree (or the peer sent something impossible): the
  /// host re-asserts its state, a guest asks for it.
  void _outOfSync() {
    if (role == SessionRole.host) {
      _sendSnapshot();
    } else {
      _send(ResyncBody(turn: _turn, hash: _hash));
    }
  }

  /// Stops the session: the two sides cannot play together. The peer is told
  /// (unless it told us), so neither side waits forever.
  void _fail(String reason, {bool tellPeer = true}) {
    if (_phase != SessionPhase.waiting && _phase != SessionPhase.playing) return;
    if (tellPeer) _send(const ByeBody(reason: ByeReason.incompatible));
    _phase = SessionPhase.failed;
    _failure = reason;
    _activeParticipant.value = null;
    _emit(SessionFailed(reason));
    _notify();
  }

  // ----------------------------------------------------------------- state

  String _hashOf(S state) => GameData(adapter.encodeState(state), policy: adapter.policy).hash;

  void _afterStateChange() {
    final s = _state;
    if (s != null && _phase == SessionPhase.playing) {
      final o = adapter.outcome(s);
      if (o != null) {
        _finish(o, announce: role == SessionRole.host);
        return;
      }
      final seat = adapter.seatToMove(s);
      if (seat != null && seat < _seats.length && _seats[seat] != TogetherSeats.ai) {
        _activeParticipant.value = _seats[seat];
      }
    }
    _notify();
  }

  void _finish(SeatOutcome o, {required bool announce}) {
    _phase = SessionPhase.finished;
    _outcome = o;
    _activeParticipant.value = null;
    final record = recordFor(o);
    _record = record;
    if (announce) _sendResult(o);
    _emit(SessionFinished(outcome: o, record: record));
    _notify();
    final r = recorder;
    if (r == null) {
      if (!_recorded.isCompleted) _recorded.complete(null);
      return;
    }
    unawaited(
      r(record).then(
        (value) {
          if (!_recorded.isCompleted) _recorded.complete(value);
        },
        onError: (Object e, StackTrace st) {
          if (!_recorded.isCompleted) _recorded.completeError(e, st);
        },
      ),
    );
  }

  /// The history record of [o]: winning seats mapped to the two players (AI
  /// seats to nobody), scores taken from each player's first seat.
  @visibleForTesting
  MatchRecord recordFor(SeatOutcome o) {
    final humans = <int>{
      for (final w in o.winners)
        if (w >= 0 && w < _seats.length && _seats[w] != TogetherSeats.ai) _seats[w],
    };
    final MatchOutcome outcome;
    if (o.isLoss) {
      outcome = MatchOutcome.teamLost;
    } else if (o.isDraw) {
      outcome = MatchOutcome.draw;
    } else if (humans.length == 2) {
      outcome = MatchOutcome.teamWon;
    } else if (humans.length == 1) {
      outcome = MatchOutcome.win(seating[humans.first]);
    } else {
      outcome = MatchOutcome.teamLost;
    }
    int? scoreOf(int participant) {
      final seat = _seats.indexOf(participant);
      return seat >= 0 && seat < o.scores.length ? o.scores[seat] : null;
    }

    final p1 = participantOf(PlayerSlot.one);
    final p2 = participantOf(PlayerSlot.two);
    final now = _clock();
    final started = _startedAt;
    return MatchRecord(
      id: matchId,
      gameId: adapter.gameId,
      endedAt: now,
      outcome: outcome,
      scoreOne: scoreOf(p1),
      scoreTwo: scoreOf(p2),
      mode: transport.mode,
      durationSeconds: started == null ? null : math.max(0, now.difference(started).inSeconds),
    );
  }

  String _randomId() {
    const hex = '0123456789abcdef';
    return String.fromCharCodes([for (var i = 0; i < 16; i++) hex.codeUnitAt(_random.nextInt(16))]);
  }

  void _emit(SessionEvent e) {
    if (!_events.isClosed) _events.add(e);
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }
}

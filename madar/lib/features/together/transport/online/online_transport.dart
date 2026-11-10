/// Two phones in different places over the user's own Firebase project
/// (optional, off by default): anonymous sign-in and a short-lived room in
/// the Realtime Database that holds nothing but game frames.
///
/// * **Host** ([OnlineTransport.host]) – creates `rooms/<code>` with a random
///   6-digit code valid for [OnlineRooms.joinWindow], shows it (and a QR),
///   then accepts – or declines – the partner who typed it.
/// * **Guest** ([OnlineTransport.join]) – checks the code (exists, not
///   expired, same game), claims the room's one guest seat, and waits for
///   the host to accept.
/// * **Frames** – each frame is pushed under `f/`; the recipient hands it to
///   the session and deletes it. Unread own frames are capped
///   ([OnlineRooms.maxOwnPending]). Order, duplicates and gaps are the
///   session's business (sequence numbers, sync, resend).
/// * **Lifetime** – a playing room is kept alive for [OnlineRooms.ttl] and
///   refreshed hourly; leaving deletes it (after the session's `bye` has had
///   a moment to be read). Rooms left behind by a crash are deleted at the
///   next online pairing ([OnlineRoomLedger]); expired rooms can be deleted
///   or reused by anyone signed in.
library;

import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;

import '../../domain/play_modes.dart';
import '../../protocol/envelope.dart';
import '../../protocol/session.dart';
import '../../protocol/transport.dart';
import '../pairing_state.dart';
import 'online_rooms.dart';
import 'rtdb.dart';

/// Thrown by an online transport's connect function when online play is off
/// or no Firebase project has been entered.
final class OnlineNotConfigured implements Exception {
  const OnlineNotConfigured();
}

class OnlineTransport extends PairingTransportBase {
  OnlineTransport({
    required this.request,
    required this.connect,
    this.ledger,
    math.Random? random,
    this.joinWindow = OnlineRooms.joinWindow,
    this.refreshEvery = OnlineRooms.refreshEvery,
    this.drain = const Duration(milliseconds: 1500),
    this.maxOwnPending = OnlineRooms.maxOwnPending,
  }) : _random = random ?? math.Random.secure(),
       super(mode: PlayMode.online);

  final TransportRequest request;

  /// Opens the database client (throws [OnlineNotConfigured] when online
  /// play is off or not set up).
  final Future<RtdbClient> Function() connect;
  final OnlineRoomLedger? ledger;
  final Duration joinWindow;
  final Duration refreshEvery;

  /// How long leaving waits for the last frames to be read.
  final Duration drain;
  final int maxOwnPending;

  final math.Random _random;
  RtdbClient? _client;
  PairingIdentity? _identity;
  String? _code;
  String? _hostUid;
  bool _paired = false;
  final List<StreamSubscription<Object?>> _subs = [];
  Timer? _joinTimer;
  Timer? _refreshTimer;
  final ListQueue<String> _own = ListQueue();
  final Set<String> _ownSet = {};
  final LinkedHashSet<String> _seen = LinkedHashSet();
  final Set<Future<void>> _inFlight = {};

  /// The room code (host: once created; guest: once joined).
  String? get code => _code;

  /// This phone's player.
  PairingIdentity? get identity => _identity;

  int get _self => roleValue == SessionRole.host ? 0 : 1;

  // ----------------------------------------------------------------- host

  /// Creates a room and shows its code.
  Future<void> host(PairingIdentity me) async {
    if (closed || _paired || state.busy || state.phase == PairingPhase.hosting) return;
    await _resetRoom();
    _identity = me;
    roleValue = SessionRole.host;
    final client = await _open();
    if (client == null || closed) return;
    final uid = client.uid;
    if (uid == null) {
      _fail(PairingFailure.signIn);
      return;
    }
    for (var attempt = 0; attempt < 8; attempt++) {
      final code = OnlineRooms.newCode(_random);
      final now = client.serverNow();
      try {
        await client.set(
          OnlineRooms.room(code),
          OnlineRooms.newRoom(hostUid: uid, gameId: request.gameId, host: me, now: now),
        );
      } on RtdbException catch (e) {
        if (e.kind == RtdbErrorKind.permissionDenied) continue; // a live room has that code
        _fail(_failureOf(e));
        return;
      }
      if (closed) {
        await _quietly(() => client.remove(OnlineRooms.room(code)));
        return;
      }
      _code = code;
      _hostUid = uid;
      await _quietly(() async => ledger?.add(code));
      setPairing(PairingState(PairingPhase.hosting, code: code, expiresAt: now.add(joinWindow)));
      _joinTimer = Timer(joinWindow, _onJoinWindowOver);
      final room = OnlineRooms.room(code);
      // The guest claims the seat (`g`) first and writes the profile (`pg`)
      // after it: the profile's arrival means both are there.
      _subs.add(client.watch('$room/pg').listen(_onGuest, onError: _onListenError));
      _subs.add(client.watch('$room/h').listen(_onHostField, onError: _onListenError));
      return;
    }
    // Every code refused: the database's rules are not the online-play rules.
    _fail(PairingFailure.rules);
  }

  Future<void> _onGuest(Object? profile) async {
    if (closed || _paired || roleValue != SessionRole.host || state.phase != PairingPhase.hosting) return;
    if (profile is! Map) return;
    final client = _client;
    final code = _code;
    if (client == null || code == null) return;
    Object? uid;
    try {
      uid = await client.read('${OnlineRooms.room(code)}/g');
    } on RtdbException {
      uid = null;
    }
    if (closed || state.phase != PairingPhase.hosting) return;
    if (uid is! String || uid.isEmpty) return;
    setPairing(PairingState(PairingPhase.confirm, peer: OnlineRooms.peerOf(uid, profile), code: code));
  }

  /// Host: plays with the partner who joined.
  Future<void> acceptGuest() async {
    final client = _client;
    final code = _code;
    if (closed || roleValue != SessionRole.host || state.phase != PairingPhase.confirm) return;
    if (client == null || code == null) return;
    final peer = state.peer;
    try {
      await client.update(OnlineRooms.room(code), {
        'ok': true,
        'x': OnlineRooms.ms(client.serverNow().add(OnlineRooms.ttl)),
      });
    } on RtdbException catch (e) {
      _fail(_failureOf(e));
      return;
    }
    if (closed) return;
    peerValue = peer;
    _joinTimer?.cancel();
    _startPlaying();
  }

  /// Host: not the partner – the room is deleted and a new code shown.
  Future<void> declineGuest() async {
    final me = _identity;
    if (closed || roleValue != SessionRole.host || state.phase != PairingPhase.confirm || me == null) return;
    await _resetRoom();
    setPairing(PairingState.initial);
    await host(me);
  }

  void _onJoinWindowOver() {
    if (closed || _paired || state.phase != PairingPhase.hosting) return;
    unawaited(_resetRoom().then((_) => _fail(PairingFailure.expired)));
  }

  // ---------------------------------------------------------------- guest

  /// Joins the room of [rawCode] (typed; Arabic-Indic digits welcome).
  Future<void> join(String rawCode, PairingIdentity me) async {
    if (closed || _paired || state.busy) return;
    await _resetRoom();
    final code = OnlineRooms.normalizeCode(rawCode);
    if (!OnlineRooms.isValidCode(code)) {
      _fail(PairingFailure.notFound);
      return;
    }
    _identity = me;
    roleValue = SessionRole.guest;
    final client = await _open();
    if (client == null || closed) return;
    final uid = client.uid;
    if (uid == null) {
      _fail(PairingFailure.signIn);
      return;
    }
    setPairing(PairingState(PairingPhase.joining, code: code));
    final room = OnlineRooms.room(code);
    try {
      final game = await client.read('$room/gm');
      final expires = await client.read('$room/x');
      if (game == null) {
        _fail(PairingFailure.notFound);
        return;
      }
      if (expires is! num || expires <= OnlineRooms.ms(client.serverNow())) {
        _fail(PairingFailure.expired);
        return;
      }
      if (game != request.gameId) {
        _fail(PairingFailure.differentGame);
        return;
      }
    } on RtdbException catch (e) {
      _fail(_failureOf(e));
      return;
    }
    // Each location of a multi-path update is authorised on its own, so the
    // seat goes first: the profile's and the expiry's rules look for this uid
    // in the room's existing data.
    try {
      await client.set('$room/g', uid);
    } on RtdbException catch (e) {
      // Someone else was quicker (or the code just expired).
      _fail(e.kind == RtdbErrorKind.permissionDenied ? PairingFailure.taken : _failureOf(e));
      return;
    }
    if (closed) {
      await _quietly(() => client.remove(room));
      return;
    }
    _code = code;
    await _quietly(() async => ledger?.add(code));
    try {
      await client.update(room, {
        'pg': OnlineRooms.profileOf(me),
        'x': OnlineRooms.ms(client.serverNow().add(OnlineRooms.ttl)),
      });
    } on RtdbException catch (e) {
      // The seat is taken but the host will never see us: give the room back.
      await _resetRoom();
      _fail(_failureOf(e));
      return;
    }
    if (closed) return;
    try {
      final hostUid = await client.read('$room/h');
      _hostUid = hostUid is String ? hostUid : null;
      peerValue = OnlineRooms.peerOf(_hostUid ?? '', await client.read('$room/ph'));
    } on RtdbException {
      peerValue = null;
    }
    if (closed) return;
    setPairing(PairingState(PairingPhase.waitingForPeer, peer: peerValue, code: code));
    _subs.add(
      client.watch('$room/ok').listen((v) {
        if (v == true) _startPlaying();
      }, onError: _onListenError),
    );
    _subs.add(client.watch('$room/h').listen(_onHostField, onError: _onListenError));
  }

  // -------------------------------------------------------------- playing

  void _startPlaying() {
    final client = _client;
    final code = _code;
    if (_paired || closed || client == null || code == null) return;
    _paired = true;
    _subs.add(client.childAdded(OnlineRooms.frames(code)).listen(_onFrame, onError: _onListenError));
    client.connected.addListener(_onConnectivity);
    _onConnectivity();
    setPairing(PairingState(PairingPhase.connected, peer: peerValue, role: roleValue, code: code));
    _refreshTimer = Timer.periodic(refreshEvery, (_) => unawaited(_refresh()));
  }

  void _onConnectivity() {
    final client = _client;
    if (!_paired || closed || client == null) return;
    if (state.phase == PairingPhase.failed) return;
    setStatus(client.connected.value ? TransportStatus.connected : TransportStatus.disconnected);
  }

  Future<void> _refresh() async {
    final client = _client;
    final code = _code;
    if (client == null || code == null || closed) return;
    await _quietly(
      () => client.update(OnlineRooms.room(code), {'x': OnlineRooms.ms(client.serverNow().add(OnlineRooms.ttl))}),
    );
  }

  /// The room's host field: null (or another host) once the room is gone.
  void _onHostField(Object? v) {
    if (closed || _code == null) return;
    if (v == null || (_hostUid != null && v != _hostUid)) {
      _roomGone();
      return;
    }
    if (v is String) _hostUid ??= v;
  }

  void _roomGone() {
    final wasPaired = _paired;
    final guestWaiting = roleValue == SessionRole.guest && !wasPaired;
    final guestLeft = roleValue == SessionRole.host && state.phase == PairingPhase.confirm;
    // Deleted by the partner (or taken over after expiry): nothing to clean.
    unawaited(_quietly(() async => ledger?.remove(_code ?? '')));
    _code = null;
    _cancelSubs();
    if (wasPaired) setStatus(TransportStatus.disconnected);
    _fail(
      wasPaired || guestLeft
          ? PairingFailure.peerLeft
          : guestWaiting
          ? PairingFailure.declinedByPeer
          : PairingFailure.expired,
    );
  }

  void _onFrame(RtdbChild child) {
    final client = _client;
    final code = _code;
    if (closed || client == null || code == null) return;
    final v = child.value;
    final path = '${OnlineRooms.frames(code)}/${child.key}';
    if (v is! Map) return;
    final from = v['s'];
    final text = v['t'];
    if (from == _self) {
      _trackOwn(child.key);
      return;
    }
    // Read once, then gone from the database.
    unawaited(_quietly(() => client.remove(path)));
    if (from != 1 - _self || text is! String || text.length > OnlineRooms.maxFrameChars) return;
    if (!_seen.add(child.key)) return;
    while (_seen.length > 512) {
      _seen.remove(_seen.first);
    }
    deliver(text);
  }

  void _trackOwn(String key) {
    if (!_ownSet.add(key)) return;
    _own.addLast(key);
    final client = _client;
    final code = _code;
    while (_own.length > maxOwnPending) {
      final old = _own.removeFirst();
      _ownSet.remove(old);
      if (client != null && code != null) {
        unawaited(_quietly(() => client.remove('${OnlineRooms.frames(code)}/$old')));
      }
    }
  }

  @override
  Future<void> send(TogetherFrame frame) {
    final client = _client;
    final code = _code;
    if (closed || !_paired || client == null || code == null) return Future<void>.value();
    if (frame.text.length > OnlineRooms.maxFrameChars) return Future<void>.value();
    late final Future<void> push;
    push = client
        .push(OnlineRooms.frames(code), OnlineRooms.frame(_self, frame.text))
        .then<void>(_trackOwn, onError: (Object _) {})
        .whenComplete(() => _inFlight.remove(push));
    _inFlight.add(push);
    return push;
  }

  // ------------------------------------------------------------ plumbing

  Future<RtdbClient?> _open() async {
    setPairing(const PairingState(PairingPhase.signingIn));
    try {
      final client = _client ??= await connect();
      await client.signIn();
      if (closed) return null;
      // Never put a room – a name, a frame – into a database anyone can read.
      await OnlineRooms.checkRules(client);
      if (closed) return null;
      await _cleanUpLeftovers(client);
      return client;
    } on OnlineNotConfigured {
      setPairing(const PairingState(PairingPhase.needsSetup));
    } on RtdbException catch (e) {
      _fail(_failureOf(e));
    } on Object {
      _fail(PairingFailure.unknown);
    }
    return null;
  }

  /// Rooms a crash left behind.
  Future<void> _cleanUpLeftovers(RtdbClient client) async {
    final l = ledger;
    if (l == null) return;
    try {
      for (final c in await l.codes()) {
        await _quietly(() => client.remove(OnlineRooms.room(c)));
      }
      await l.clear();
    } on Object {
      // Secure storage unavailable: nothing to clean.
    }
  }

  static PairingFailure _failureOf(RtdbException e) => switch (e.kind) {
    RtdbErrorKind.permissionDenied => PairingFailure.rules,
    RtdbErrorKind.network => PairingFailure.network,
    RtdbErrorKind.setup => PairingFailure.setup,
    RtdbErrorKind.signIn => PairingFailure.signIn,
    RtdbErrorKind.rulesOpen => PairingFailure.rulesOpen,
    RtdbErrorKind.unknown => PairingFailure.unknown,
  };

  void _fail(PairingFailure failure) {
    if (closed) return;
    setPairing(PairingState(PairingPhase.failed, failure: failure, peer: peerValue, code: _code));
  }

  void _onListenError(Object e) {
    if (closed) return;
    if (_paired) {
      setStatus(TransportStatus.disconnected);
      return;
    }
    _fail(e is RtdbException ? _failureOf(e) : PairingFailure.network);
  }

  void _cancelSubs() {
    for (final s in _subs) {
      unawaited(s.cancel());
    }
    _subs.clear();
    _joinTimer?.cancel();
    _refreshTimer?.cancel();
    _client?.connected.removeListener(_onConnectivity);
  }

  /// Back to no room (after a failure, before a new code).
  Future<void> _resetRoom() async {
    _cancelSubs();
    final client = _client;
    final code = _code;
    _code = null;
    _hostUid = null;
    _paired = false;
    peerValue = null;
    if (client != null && code != null) await _deleteRoom(client, code);
  }

  /// Deletes the room; it leaves the crash ledger only once really deleted
  /// (offline, the next online pairing deletes it).
  Future<void> _deleteRoom(RtdbClient client, String code) async {
    try {
      await client.remove(OnlineRooms.room(code)).timeout(const Duration(seconds: 3));
    } on Object {
      return;
    }
    await _quietly(() async => ledger?.remove(code));
  }

  /// Starts over from [PairingPhase.failed]: no room, no role.
  Future<void> reset() async {
    if (closed || _paired) return;
    await _resetRoom();
    roleValue = null;
    setPairing(PairingState.initial);
  }

  Future<void>? _closing;

  /// Leaves (idempotent: every call waits for the same clean-up).
  @override
  Future<void> close() => _closing ??= _close();

  Future<void> _close() async {
    if (!markClosed()) return;
    _joinTimer?.cancel();
    _refreshTimer?.cancel();
    final client = _client;
    if (client != null && _paired) {
      // Let the session's `bye` land and, briefly, be read.
      try {
        await Future.wait(List.of(_inFlight)).timeout(drain);
      } on Object {
        // Offline: the room goes anyway.
      }
      await _waitForPartnerToRead(client);
    }
    _cancelSubs();
    final code = _code;
    _code = null;
    if (client != null && code != null) await _deleteRoom(client, code);
    await _quietly(() async => client?.close());
    await finishClose();
  }

  Future<void> _waitForPartnerToRead(RtdbClient client) async {
    final code = _code;
    if (code == null || _own.isEmpty) return;
    final last = '${OnlineRooms.frames(code)}/${_own.last}';
    final end = DateTime.now().add(drain);
    while (DateTime.now().isBefore(end)) {
      try {
        if (await client.read(last) == null) return;
      } on Object {
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 150));
    }
  }

  /// Best effort, and never waits long: a database write made offline only
  /// completes once back online.
  static Future<void> _quietly(Future<void> Function() call) async {
    try {
      await call().timeout(const Duration(seconds: 3));
    } on Object {
      // Best effort.
    }
  }
}

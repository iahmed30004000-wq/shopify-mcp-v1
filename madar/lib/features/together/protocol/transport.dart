/// Transports carry encoded frames between the two players' sessions.
///
/// Implemented now: [LoopbackLink] (two in-memory endpoints – tests and
/// development, with fault injection) and [PassAndPlayTransport] (both
/// players on one device). Google Nearby Connections and the optional online
/// transport implement the same interface later and are registered through
/// `togetherTransportFactoriesProvider`.
library;

import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../domain/play_modes.dart';
import 'envelope.dart';

/// Connection state of a transport.
enum TransportStatus { connecting, connected, disconnected, closed }

/// A connection to the other player's session.
///
/// A transport only ever receives [TogetherFrame]s – already encoded by the
/// whitelist codec – and hands incoming text to the session, which decodes it
/// through the same whitelist before anything is used.
abstract class TogetherTransport {
  /// The play mode this transport serves.
  PlayMode get mode;

  /// The participants whose input this device takes: `{0, 1}` on a shared
  /// device, `{0}` on the host's phone, `{1}` on the guest's.
  Set<int> get localParticipants;

  ValueListenable<TransportStatus> get status;

  /// Untrusted frames from the peer.
  Stream<String> get incoming;

  /// Sends [frame] (dropped silently while disconnected: the session's
  /// sync/retransmission recovers).
  Future<void> send(TogetherFrame frame);

  Future<void> close();
}

/// What a session needs from a transport factory.
final class TransportRequest {
  const TransportRequest({required this.mode, required this.host, required this.gameId});

  final PlayMode mode;

  /// This device hosts (participant 0).
  final bool host;
  final String gameId;
}

/// Opens a transport (pairing, discovery, sign-in…) – registered per mode.
typedef TogetherTransportFactory = Future<TogetherTransport> Function(TransportRequest request);

/// Both players on one device (pass-and-play, split-screen): nothing leaves
/// the device. Encoded frames are counted (and the last few kept for audits)
/// but go nowhere.
class PassAndPlayTransport implements TogetherTransport {
  PassAndPlayTransport({this.mode = PlayMode.passAndPlay});

  @override
  final PlayMode mode;

  final ValueNotifier<TransportStatus> _status = ValueNotifier(TransportStatus.connected);
  final StreamController<String> _incoming = StreamController<String>.broadcast();

  /// The most recent frames (at most 32) – what would have travelled.
  final Queue<String> audit = Queue<String>();
  int framesSent = 0;

  @override
  Set<int> get localParticipants => const {0, 1};

  @override
  ValueListenable<TransportStatus> get status => _status;

  @override
  Stream<String> get incoming => _incoming.stream;

  @override
  Future<void> send(TogetherFrame frame) async {
    framesSent++;
    audit.addLast(frame.text);
    while (audit.length > 32) {
      audit.removeFirst();
    }
  }

  @override
  Future<void> close() async {
    _status.value = TransportStatus.closed;
    await _incoming.close();
  }
}

/// A frame that crossed a [LoopbackLink].
final class LoopbackWireRecord {
  const LoopbackWireRecord(this.from, this.text, {required this.delivered});

  final int from;
  final String text;

  /// False when it was lost (disconnected or dropped on purpose).
  final bool delivered;
}

/// Two in-memory endpoints joined by a simulated link: [host] (participant 0)
/// and [guest] (participant 1). Frames are delivered asynchronously, in
/// order, unless a test injects faults: [dropNext], [hold]/[release] (with
/// reordering), [disconnect]/[reconnect]. Every frame is logged in [wire].
class LoopbackLink {
  LoopbackLink({this.latency = Duration.zero, this.mode = PlayMode.nearby}) {
    host = LoopbackTransport._(this, 0);
    guest = LoopbackTransport._(this, 1);
  }

  final Duration latency;
  final PlayMode mode;
  late final LoopbackTransport host;
  late final LoopbackTransport guest;

  /// Everything sent over the link, in send order.
  final List<LoopbackWireRecord> wire = [];

  bool _connected = true;
  final List<int> _drop = [0, 0];
  final List<bool> _holding = [false, false];
  final List<List<String>> _held = [[], []];

  bool get connected => _connected;

  LoopbackTransport endpoint(int participant) => participant == 0 ? host : guest;

  /// Loses the next [count] frames sent by [from].
  void dropNext(int from, [int count = 1]) => _drop[from] += count;

  /// Holds frames sent by [from] until [release].
  void hold(int from) => _holding[from] = true;

  /// Delivers held frames of [from] (reversed when [reverse] – out of order).
  void release(int from, {bool reverse = false}) {
    _holding[from] = false;
    final frames = reverse ? _held[from].reversed.toList() : List.of(_held[from]);
    _held[from].clear();
    for (final f in frames) {
      _deliver(from, f);
    }
  }

  /// Breaks the link: frames sent meanwhile are lost.
  void disconnect() {
    if (!_connected) return;
    _connected = false;
    for (final e in [host, guest]) {
      if (e._status.value != TransportStatus.closed) e._status.value = TransportStatus.disconnected;
    }
  }

  /// Restores the link (sessions then exchange `sync`).
  void reconnect() {
    if (_connected) return;
    _connected = true;
    for (final e in [host, guest]) {
      if (e._status.value != TransportStatus.closed) e._status.value = TransportStatus.connected;
    }
  }

  void _send(int from, String text) {
    if (!_connected || _drop[from] > 0) {
      if (_connected) _drop[from]--;
      wire.add(LoopbackWireRecord(from, text, delivered: false));
      return;
    }
    wire.add(LoopbackWireRecord(from, text, delivered: true));
    if (_holding[from]) {
      _held[from].add(text);
      return;
    }
    _deliver(from, text);
  }

  void _deliver(int from, String text) {
    final to = endpoint(1 - from);
    void go() {
      if (_connected && !to._incoming.isClosed) to._incoming.add(text);
    }

    if (latency == Duration.zero) {
      scheduleMicrotask(go);
    } else {
      Timer(latency, go);
    }
  }
}

/// One end of a [LoopbackLink].
class LoopbackTransport implements TogetherTransport {
  LoopbackTransport._(this.link, this.participant);

  final LoopbackLink link;
  final int participant;
  final ValueNotifier<TransportStatus> _status = ValueNotifier(TransportStatus.connected);
  final StreamController<String> _incoming = StreamController<String>.broadcast();

  @override
  PlayMode get mode => link.mode;

  @override
  Set<int> get localParticipants => {participant};

  @override
  ValueListenable<TransportStatus> get status => _status;

  @override
  Stream<String> get incoming => _incoming.stream;

  /// Injects raw text as if the peer had sent it (hostile-peer tests).
  void injectIncoming(String text) => scheduleMicrotask(() => _incoming.add(text));

  @override
  Future<void> send(TogetherFrame frame) async {
    if (_status.value == TransportStatus.closed) return;
    link._send(participant, frame.text);
  }

  @override
  Future<void> close() async {
    _status.value = TransportStatus.closed;
    await _incoming.close();
  }
}

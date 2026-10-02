/// The Together wire format: versioned envelopes with a closed set of message
/// kinds, each with a fixed set of fields. The codec is a whitelist: it
/// refuses – on the way out and on the way in – any field the protocol does
/// not define and any game payload that fails [GameDataPolicy].
///
/// ```json
/// {"p":"madar.together","v":1,"sid":"3f9a…","k":"move","seq":7,"ack":6,"from":0,
///  "b":{"t":12,"s":0,"m":{"col":3},"h":"a1b2c3d4e5f60718"}}
/// ```
library;

import 'dart:convert';

import 'game_data.dart';

/// Protocol constants.
abstract final class TogetherProtocol {
  static const String magic = 'madar.together';

  /// Bumped for incompatible wire changes; a peer on another version is
  /// refused with [TogetherRejection.unsupportedVersion].
  static const int version = 1;

  /// Largest encoded frame (UTF-8 bytes).
  static const int maxFrameBytes = 256 * 1024;

  /// Participants: 0 is the host's player, 1 the guest's.
  static const int participants = 2;

  /// Largest seat count a game may have (cards: 4).
  static const int maxSeats = 8;
}

/// Every message kind.
enum TogetherMessageKind {
  /// Guest → host: "I am here, running this game".
  hello(sequenced: false, onlyFrom: 1),

  /// Host → guest: the shared seed, config and seating; resets ordering.
  start(sequenced: true, resets: true, onlyFrom: 0),

  /// A move of a turn-based game.
  move(sequenced: true),

  /// A real-time input (latest wins; not retransmitted).
  input(sequenced: false),

  /// The host's authoritative state; resets ordering.
  snapshot(sequenced: true, resets: true, onlyFrom: 0),

  /// "Where I am" after a (re)connection or a gap: turn, state hash, ack.
  sync(sequenced: false),

  /// Guest → host: "send me a snapshot".
  resync(sequenced: false, onlyFrom: 1),

  /// Host → guest: the match result (the host is the referee).
  result(sequenced: true, onlyFrom: 0),

  /// Leaving the session.
  bye(sequenced: false);

  const TogetherMessageKind({required this.sequenced, this.resets = false, this.onlyFrom});

  /// Delivered in order, acknowledged and retransmitted.
  final bool sequenced;

  /// Processed as soon as it arrives; later messages continue from it.
  final bool resets;

  /// The only participant that may send this kind (0 host, 1 guest), or
  /// null for both. The codec refuses it from the other side: a guest can
  /// neither declare the result nor jump the host's ordering with a reset.
  final int? onlyFrom;
}

/// How a finished game ended, by seat (the session maps seats to players).
/// [loss]: every seat lost (a co-op defeat).
enum SeatOutcomeKind { win, draw, loss }

/// Why a participant leaves.
enum ByeReason {
  /// The player left (or the game was closed).
  left,

  /// This side cannot play with the peer (other game, rules or protocol
  /// version): the peer should stop waiting and say so.
  incompatible,
}

/// A message body. Sealed: nothing else can be put on the wire.
sealed class TogetherBody {
  const TogetherBody();

  TogetherMessageKind get kind;

  Map<String, Object?> toWire();
}

final class HelloBody extends TogetherBody {
  const HelloBody({required this.gameId, required this.gameVersion});

  final String gameId;
  final int gameVersion;

  @override
  TogetherMessageKind get kind => TogetherMessageKind.hello;

  @override
  Map<String, Object?> toWire() => {'g': gameId, 'gv': gameVersion};
}

final class StartBody extends TogetherBody {
  const StartBody({
    required this.gameId,
    required this.gameVersion,
    required this.seed,
    required this.config,
    required this.seats,
    required this.hash,
  });

  final String gameId;
  final int gameVersion;

  /// The shared deterministic seed (32 bits).
  final int seed;
  final GameData config;

  /// Seat → participant (0 host, 1 guest, -1 an AI driven by the host).
  final List<int> seats;

  /// Hash of the initial state both sides must reach.
  final String hash;

  @override
  TogetherMessageKind get kind => TogetherMessageKind.start;

  @override
  Map<String, Object?> toWire() => {
    'g': gameId,
    'gv': gameVersion,
    'seed': seed,
    'cfg': config.value,
    'seats': seats,
    'h': hash,
  };
}

final class MoveBody extends TogetherBody {
  const MoveBody({required this.turn, required this.seat, required this.move, required this.hash});

  /// The turn this move creates (1 for the first move).
  final int turn;
  final int seat;
  final GameData move;

  /// Hash of the state after the move.
  final String hash;

  @override
  TogetherMessageKind get kind => TogetherMessageKind.move;

  @override
  Map<String, Object?> toWire() => {'t': turn, 's': seat, 'm': move.value, 'h': hash};
}

final class InputBody extends TogetherBody {
  const InputBody({required this.tick, required this.seat, required this.input});

  final int tick;
  final int seat;
  final GameData input;

  @override
  TogetherMessageKind get kind => TogetherMessageKind.input;

  @override
  Map<String, Object?> toWire() => {'tick': tick, 's': seat, 'i': input.value};
}

final class SnapshotBody extends TogetherBody {
  const SnapshotBody({required this.turn, required this.state, required this.hash});

  final int turn;
  final GameData state;
  final String hash;

  @override
  TogetherMessageKind get kind => TogetherMessageKind.snapshot;

  @override
  Map<String, Object?> toWire() => {'t': turn, 'st': state.value, 'h': hash};
}

final class SyncBody extends TogetherBody {
  const SyncBody({required this.turn, this.hash});

  final int turn;

  /// Null before the game has started on the sender.
  final String? hash;

  @override
  TogetherMessageKind get kind => TogetherMessageKind.sync;

  @override
  Map<String, Object?> toWire() => {'t': turn, 'h': ?hash};
}

final class ResyncBody extends TogetherBody {
  const ResyncBody({required this.turn, this.hash});

  final int turn;
  final String? hash;

  @override
  TogetherMessageKind get kind => TogetherMessageKind.resync;

  @override
  Map<String, Object?> toWire() => {'t': turn, 'h': ?hash};
}

final class ResultBody extends TogetherBody {
  const ResultBody({required this.matchId, required this.outcome, this.winners = const [], this.scores = const []});

  final String matchId;
  final SeatOutcomeKind outcome;

  /// Winning seats.
  final List<int> winners;

  /// Per seat.
  final List<int> scores;

  @override
  TogetherMessageKind get kind => TogetherMessageKind.result;

  @override
  Map<String, Object?> toWire() => {'m': matchId, 'o': outcome.name, 'w': winners, 'sc': scores};
}

final class ByeBody extends TogetherBody {
  const ByeBody({this.reason = ByeReason.left});

  final ByeReason reason;

  @override
  TogetherMessageKind get kind => TogetherMessageKind.bye;

  @override
  Map<String, Object?> toWire() => reason == ByeReason.left ? const {} : {'r': reason.name};
}

/// One message.
final class TogetherEnvelope {
  const TogetherEnvelope({
    required this.sessionId,
    required this.from,
    required this.body,
    this.seq = 0,
    this.ack = 0,
    this.version = TogetherProtocol.version,
  });

  final int version;
  final String sessionId;

  /// Sending participant (0 host, 1 guest).
  final int from;

  /// Sender's sequence number (sequenced kinds; 0 otherwise).
  final int seq;

  /// Last in-order sequence number the sender has received.
  final int ack;
  final TogetherBody body;

  TogetherMessageKind get kind => body.kind;

  @override
  String toString() => 'TogetherEnvelope(${kind.name}, from: $from, seq: $seq, ack: $ack)';
}

/// An encoded envelope, ready for a transport. Only [TogetherCodec] can make
/// one, so a transport can only ever send whitelisted data.
final class TogetherFrame {
  const TogetherFrame._(this.text);

  final String text;

  int get bytes => utf8.encode(text).length;
}

/// Encodes and decodes envelopes through the same whitelist.
final class TogetherCodec {
  const TogetherCodec({this.policy = GameDataPolicy.standard});

  /// The policy for game payloads (the game's own whitelist).
  final GameDataPolicy policy;

  static final RegExp _sessionId = RegExp(r'^[A-Za-z0-9_\-]{8,64}$');
  static final RegExp _id = RegExp(r'^[A-Za-z0-9_\-]{1,64}$');
  static const Set<String> _top = {'p', 'v', 'sid', 'k', 'seq', 'ack', 'from', 'b'};

  /// Encodes [e]; throws [TogetherDataRejected] when it holds anything the
  /// protocol does not allow.
  TogetherFrame encode(TogetherEnvelope e) {
    final wire = <String, Object?>{
      'p': TogetherProtocol.magic,
      'v': e.version,
      'sid': e.sessionId,
      'k': e.kind.name,
      'seq': e.seq,
      'ack': e.ack,
      'from': e.from,
      'b': e.body.toWire(),
    };
    // The outgoing map goes through exactly the checks an incoming one does.
    _parse(wire);
    final text = jsonEncode(wire);
    if (utf8.encode(text).length > TogetherProtocol.maxFrameBytes) {
      throw const TogetherDataRejected(TogetherRejection.tooLarge);
    }
    return TogetherFrame._(text);
  }

  /// Decodes an untrusted frame; throws [TogetherDataRejected].
  TogetherEnvelope decode(String text) {
    if (text.length > TogetherProtocol.maxFrameBytes) throw const TogetherDataRejected(TogetherRejection.tooLarge);
    final Object? json;
    try {
      json = jsonDecode(text);
    } on FormatException {
      throw const TogetherDataRejected(TogetherRejection.notJson);
    }
    return _parse(json);
  }

  TogetherEnvelope _parse(Object? json) {
    if (json is! Map) throw const TogetherDataRejected(TogetherRejection.notAnEnvelope);
    if (json['p'] != TogetherProtocol.magic) throw const TogetherDataRejected(TogetherRejection.notAnEnvelope, 'p');
    // The version first: another version may add fields or kinds, and must
    // be recognised as such (the session then stops instead of waiting).
    final v = _int(json, 'v', '');
    if (v != TogetherProtocol.version) throw const TogetherDataRejected(TogetherRejection.unsupportedVersion, 'v');
    for (final k in json.keys) {
      if (!_top.contains(k)) throw TogetherDataRejected(TogetherRejection.unknownField, '$k');
    }
    final sid = json['sid'];
    if (sid is! String || !_sessionId.hasMatch(sid)) throw const TogetherDataRejected(TogetherRejection.wrongType, 'sid');
    final kind = TogetherMessageKind.values.where((k) => k.name == json['k']).firstOrNull;
    if (kind == null) throw const TogetherDataRejected(TogetherRejection.notAnEnvelope, 'k');
    final seq = _int(json, 'seq', '', min: 0);
    final ack = _int(json, 'ack', '', min: 0);
    final from = _int(json, 'from', '', min: 0, max: TogetherProtocol.participants - 1);
    if (kind.onlyFrom != null && from != kind.onlyFrom) throw const TogetherDataRejected(TogetherRejection.wrongType, 'from');
    if (kind.sequenced != (seq > 0)) throw const TogetherDataRejected(TogetherRejection.wrongType, 'seq');
    final b = json['b'];
    if (b is! Map) throw const TogetherDataRejected(TogetherRejection.missingField, 'b');
    final body = _Fields(b, 'b');
    final TogetherBody parsed = switch (kind) {
      TogetherMessageKind.hello => HelloBody(gameId: body.id('g'), gameVersion: body.integer('gv', min: 0)),
      TogetherMessageKind.start => StartBody(
        gameId: body.id('g'),
        gameVersion: body.integer('gv', min: 0),
        seed: body.integer('seed', min: 0, max: 0xFFFFFFFF),
        config: body.data('cfg', policy),
        seats: body.intList('seats', min: -1, max: TogetherProtocol.participants - 1, maxLength: TogetherProtocol.maxSeats),
        hash: body.hash('h')!,
      ),
      TogetherMessageKind.move => MoveBody(
        turn: body.integer('t', min: 1),
        seat: body.integer('s', min: 0, max: TogetherProtocol.maxSeats - 1),
        move: body.data('m', policy),
        hash: body.hash('h')!,
      ),
      TogetherMessageKind.input => InputBody(
        tick: body.integer('tick', min: 0),
        seat: body.integer('s', min: 0, max: TogetherProtocol.maxSeats - 1),
        input: body.data('i', policy),
      ),
      TogetherMessageKind.snapshot => SnapshotBody(
        turn: body.integer('t', min: 0),
        state: body.data('st', policy),
        hash: body.hash('h')!,
      ),
      TogetherMessageKind.sync => SyncBody(turn: body.integer('t', min: 0), hash: body.hash('h', optional: true)),
      TogetherMessageKind.resync => ResyncBody(turn: body.integer('t', min: 0), hash: body.hash('h', optional: true)),
      TogetherMessageKind.result => _result(body),
      TogetherMessageKind.bye => ByeBody(reason: body.enumValue('r', ByeReason.values, optional: true) ?? ByeReason.left),
    };
    body.done();
    return TogetherEnvelope(sessionId: sid, from: from, body: parsed, seq: seq, ack: ack, version: v);
  }

  static ResultBody _result(_Fields body) {
    final outcome = body.enumValue('o', SeatOutcomeKind.values)!;
    final winners = body.intList('w', min: 0, max: TogetherProtocol.maxSeats - 1, maxLength: TogetherProtocol.maxSeats);
    // A win names its winners; a draw or a loss names none.
    if ((outcome == SeatOutcomeKind.win) == winners.isEmpty) {
      throw const TogetherDataRejected(TogetherRejection.wrongType, 'b.w');
    }
    return ResultBody(
      matchId: body.id('m'),
      outcome: outcome,
      winners: winners,
      scores: body.intList('sc', min: -999999999, max: 999999999, maxLength: TogetherProtocol.maxSeats),
    );
  }

  static int _int(Map<Object?, Object?> m, String key, String at, {int min = -GameDataPolicy.maxSafeInt, int? max}) {
    final v = m[key];
    if (v is! int) throw TogetherDataRejected(TogetherRejection.wrongType, at.isEmpty ? key : '$at.$key');
    if (v < min || v > (max ?? GameDataPolicy.maxSafeInt)) {
      throw TogetherDataRejected(TogetherRejection.numberOutOfRange, at.isEmpty ? key : '$at.$key');
    }
    return v;
  }
}

/// Reads the fields of one body and fails on any field left unread.
final class _Fields {
  _Fields(this.map, this.at);

  final Map<Object?, Object?> map;
  final String at;
  final Set<Object?> _read = {};

  String _p(String k) => '$at.$k';

  Object? _take(String k, {bool optional = false}) {
    _read.add(k);
    if (!map.containsKey(k)) {
      if (optional) return null;
      throw TogetherDataRejected(TogetherRejection.missingField, _p(k));
    }
    return map[k];
  }

  int integer(String k, {int min = -GameDataPolicy.maxSafeInt, int max = GameDataPolicy.maxSafeInt}) {
    final v = _take(k);
    if (v is! int) throw TogetherDataRejected(TogetherRejection.wrongType, _p(k));
    if (v < min || v > max) throw TogetherDataRejected(TogetherRejection.numberOutOfRange, _p(k));
    return v;
  }

  String id(String k) {
    final v = _take(k);
    if (v is! String || !TogetherCodec._id.hasMatch(v)) throw TogetherDataRejected(TogetherRejection.wrongType, _p(k));
    return v;
  }

  String? hash(String k, {bool optional = false}) {
    final v = _take(k, optional: optional);
    if (v == null && optional) return null;
    if (v is! String || !StateHash.pattern.hasMatch(v)) throw TogetherDataRejected(TogetherRejection.wrongType, _p(k));
    return v;
  }

  T? enumValue<T extends Enum>(String k, List<T> values, {bool optional = false}) {
    final v = _take(k, optional: optional);
    if (v == null && optional) return null;
    final match = values.where((e) => e.name == v).firstOrNull;
    if (match == null) throw TogetherDataRejected(TogetherRejection.wrongType, _p(k));
    return match;
  }

  List<int> intList(String k, {required int min, required int max, required int maxLength}) {
    final v = _take(k);
    if (v is! List || v.length > maxLength) throw TogetherDataRejected(TogetherRejection.wrongType, _p(k));
    return List<int>.unmodifiable([
      for (final (i, e) in v.indexed)
        if (e is int && e >= min && e <= max)
          e
        else
          throw TogetherDataRejected(TogetherRejection.wrongType, '${_p(k)}[$i]'),
    ]);
  }

  GameData data(String k, GameDataPolicy policy) {
    final v = _take(k);
    return GameData(v, policy: policy);
  }

  void done() {
    for (final k in map.keys) {
      if (!_read.contains(k)) throw TogetherDataRejected(TogetherRejection.unknownField, '$at.$k');
    }
  }
}

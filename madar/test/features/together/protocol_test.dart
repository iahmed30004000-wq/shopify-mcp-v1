import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/cinema/rules/board/board_games.dart' show boardGameKits;
import 'package:madar/features/cinema/rules/board/core/game_types.dart' show BoardGameId, GameMove, GameState;
import 'package:madar/features/cinema/rules/cards/core/card_game.dart' show CardGameId;
import 'package:madar/features/together/together.dart';

import 'together_test_utils.dart';

void main() {
  const codec = TogetherCodec(policy: GameDataPolicy(allowedKeys: RaceGame.keys));

  Map<String, Object?> moveFrame({Map<String, Object?>? body, Map<String, Object?> extraTop = const {}}) => {
    'p': 'madar.together',
    'v': 1,
    'sid': 'abcdef0123456789',
    'k': 'move',
    'seq': 1,
    'ack': 0,
    'from': 1,
    'b': body ?? {'t': 1, 's': 1, 'm': {'add': 1}, 'h': '0123456789abcdef'},
    ...extraTop,
  };

  group('whitelist – nothing but game state can travel', () {
    test('a valid move round-trips', () {
      final frame = codec.encode(
        TogetherEnvelope(
          sessionId: 'abcdef0123456789',
          from: 0,
          seq: 3,
          ack: 2,
          body: MoveBody(turn: 4, seat: 0, move: GameData({'add': 2}), hash: StateHash.of({'n': 1})),
        ),
      );
      final back = codec.decode(frame.text);
      expect(back.kind, TogetherMessageKind.move);
      expect(back.seq, 3);
      expect(back.ack, 2);
      final body = back.body as MoveBody;
      expect(body.move.map, {'add': 2});
      expect(body.turn, 4);
    });

    test('smuggling personal data into game data is refused', () {
      final attempts = <Map<String, Object?>>[
        {'add': 1, 'name': 'Player A'},
        {'add': 1, 'playerName': 'x'},
        {'add': 1, 'phone_number': '12'},
        {'add': 1, 'bloodPressure': 120},
        {'add': 1, 'medications': ['a']},
        {'add': 1, 'iban': 'x'},
        {'add': 1, 'walletBalance': 10},
        {'add': 1, 'latitude': 31.9},
        {'add': 1, 'diary': 'x'},
        {'add': 1, 'prayerLog': [1]},
        {
          'add': 1,
          'nested': {
            'deeper': {'email': 'x'},
          },
        },
      ];
      for (final a in attempts) {
        expect(
          () => GameData(a),
          throwsA(isA<TogetherDataRejected>().having((e) => e.reason, 'reason', TogetherRejection.forbiddenKey)),
          reason: '$a',
        );
      }
    });

    test('personal-looking strings are refused even under innocent keys', () {
      for (final s in [
        'someone@example.com',
        '+962 79 123 4567',
        '0791234567',
        '٠٧٩١٢٣٤٥٦٧',
        'JO71 CBJO 0000 0000 0000 1234 5678 90',
        'https://example.org/x',
      ]) {
        expect(
          () => GameData({'clue': s}),
          throwsA(isA<TogetherDataRejected>().having((e) => e.reason, 'reason', TogetherRejection.personalText)),
          reason: s,
        );
      }
      // Game strings pass: card ids, a FEN, an Arabic word.
      expect(GameData({'cards': ['10H', 'AS'], 'fen': '8/8/8/8/8/8/k7/K7 w - - 0 1', 'word': 'قمر'}).map, isNotEmpty);
    });

    test('a game whitelist refuses any other key', () {
      const policy = GameDataPolicy(allowedKeys: RaceGame.keys);
      expect(GameData({'add': 1}, policy: policy).map, {'add': 1});
      expect(
        () => GameData({'add': 1, 'mood': 'happy'}, policy: policy),
        throwsA(isA<TogetherDataRejected>().having((e) => e.reason, 'reason', TogetherRejection.keyNotAllowed)),
      );
    });

    test('non-JSON values, huge or deep payloads are refused', () {
      expect(() => GameData({'add': DateTime(2026)}), throwsA(isA<TogetherDataRejected>()));
      expect(() => GameData({'add': double.nan}), throwsA(isA<TogetherDataRejected>()));
      expect(() => GameData({'add': 1 << 60}), throwsA(isA<TogetherDataRejected>()));
      expect(() => GameData({1: 2}), throwsA(isA<TogetherDataRejected>()));
      expect(() => GameData({'s': 'x' * 500}), throwsA(isA<TogetherDataRejected>()));
      Object deep = 1;
      for (var i = 0; i < 20; i++) {
        deep = [deep];
      }
      expect(() => GameData({'d': deep}), throwsA(isA<TogetherDataRejected>()));
      expect(() => GameData({'l': List.filled(30000, 1)}), throwsA(isA<TogetherDataRejected>()));
      // A profile passed off as a "move": refused by name, and – even in its
      // compact storage form – by the game's key whitelist.
      expect(() => GameData({'name': 'Player A', 'avatar': 3}), throwsA(isA<TogetherDataRejected>()));
      final profile = TogetherProfile.defaults(PlayerSlot.one).copyWith(name: 'Player A').toJson();
      expect(
        () => GameData(profile, policy: const GameDataPolicy(allowedKeys: RaceGame.keys)),
        throwsA(isA<TogetherDataRejected>().having((e) => e.reason, 'reason', TogetherRejection.keyNotAllowed)),
      );
    });

    test('decoding refuses extra envelope fields, extra body fields and bad types', () {
      String t(Map<String, Object?> m) => jsonEncode(m);
      expect(codec.decode(t(moveFrame())).kind, TogetherMessageKind.move);
      final bad = <String>[
        t(moveFrame(extraTop: {'health': {'bpm': 80}})),
        t(moveFrame(extraTop: {'profile': 'x'})),
        t(moveFrame(body: {'t': 1, 's': 1, 'm': {'add': 1}, 'h': '0123456789abcdef', 'money': 5})),
        t(moveFrame(body: {'t': 1, 's': 1, 'm': {'add': 1, 'note': 'x'}, 'h': '0123456789abcdef'})),
        t(moveFrame(body: {'t': 1, 's': 1, 'm': {'add': 1}, 'h': 'not-a-hash'})),
        t(moveFrame(body: {'t': '1', 's': 1, 'm': {'add': 1}, 'h': '0123456789abcdef'})),
        t({...moveFrame(), 'v': 99}),
        t({...moveFrame(), 'p': 'other'}),
        t({...moveFrame(), 'k': 'exfiltrate'}),
        t({...moveFrame(), 'seq': 0}),
        t({...moveFrame(), 'from': 7}),
        'not json',
        '[1,2,3]',
      ];
      for (final text in bad) {
        expect(() => codec.decode(text), throwsA(isA<TogetherDataRejected>()), reason: text);
      }
    });

    test('a session refuses to send a smuggling move – nothing applied, nothing sent', () async {
      final link = LoopbackLink();
      final host = TogetherSession<RaceState, int>(
        adapter: const LeakyRaceGame({'name': 'Player A'}, strict: false),
        transport: link.host,
        random: _FixedRandom(),
      );
      addTearDown(host.dispose);
      await host.start(seed: 3);
      final sentBefore = link.wire.length;
      await expectLater(host.play(1), throwsA(isA<TogetherDataRejected>()));
      expect(host.turn, 0);
      expect(link.wire.length, sentBefore);

      // With the game's own whitelist, an innocent-looking extra key fails too.
      final strict = TogetherSession<RaceState, int>.local(adapter: const LeakyRaceGame({'mood': 3}));
      addTearDown(strict.dispose);
      await strict.start(seed: 1);
      await expectLater(strict.play(1), throwsA(isA<TogetherDataRejected>()));
      expect(strict.turn, 0);
    });

    test('a hostile peer frame is dropped and counted, the game continues', () async {
      final pair = SessionPair();
      addTearDown(pair.dispose);
      await pair.host.start(seed: 4);
      await settle();
      final events = <SessionEvent>[];
      pair.host.events.listen(events.add);
      pair.link.host.injectIncoming(jsonEncode(moveFrame(extraTop: {'health': 1})));
      pair.link.host.injectIncoming('{"p":"madar.together"}');
      await settle();
      expect(pair.host.rejectedFrames, 2);
      expect(events.whereType<FrameRejected>(), hasLength(2));
      await pair.host.play(1);
      await settle();
      expect(pair.guest.turn, 1);
    });

    test('everything that crossed the wire during a whole game is whitelisted game data', () async {
      final pair = SessionPair();
      addTearDown(pair.dispose);
      await pair.host.start(seed: 2);
      await settle();
      while (pair.host.phase == SessionPhase.playing) {
        final s = pair.host.seatToMove!;
        await (s == 0 ? pair.host : pair.guest).play(s == 0 ? 2 : 1);
        await settle();
      }
      expect(pair.link.wire, isNotEmpty);
      const allowedTop = {'p', 'v', 'sid', 'k', 'seq', 'ack', 'from', 'b'};
      for (final record in pair.link.wire) {
        final env = codec.decode(record.text); // re-validates every frame
        expect(env.version, TogetherProtocol.version);
        final json = jsonDecode(record.text) as Map<String, Object?>;
        expect(json.keys.toSet().difference(allowedTop), isEmpty);
        expect(record.text, isNot(contains('Player')));
      }
    });
  });

  group('state hash', () {
    test('is canonical: key order and 3 vs 3.0 do not matter', () {
      expect(StateHash.of({'a': 1, 'b': [1, 2.0]}), StateHash.of({'b': [1.0, 2], 'a': 1.0}));
      expect(StateHash.of({'a': 1}), isNot(StateHash.of({'a': 2})));
      expect(StateHash.pattern.hasMatch(StateHash.of(null)), isTrue);
    });
  });

  group('session – seeds, turns, ordering, resync, results', () {
    test('the shared seed gives both sides the same initial state', () async {
      final pair = SessionPair();
      addTearDown(pair.dispose);
      await pair.host.start(seed: 123456);
      await settle();
      expect(pair.guest.started, isTrue);
      expect(pair.guest.seed, 123456);
      expect(pair.guest.stateHash, pair.host.stateHash);
      expect(pair.guest.state.n, 123456 % 5);
      expect(pair.guest.sessionId, pair.host.sessionId);
    });

    test('a random seed is drawn when none is given (32 bits)', () async {
      final a = TogetherSession<RaceState, int>.local(adapter: const RaceGame());
      addTearDown(a.dispose);
      await a.start();
      expect(a.seed, inInclusiveRange(0, 0xFFFFFFFF));
    });

    test('turn ownership: only the seat to move, only on its own device', () async {
      final pair = SessionPair();
      addTearDown(pair.dispose);
      await pair.host.start(seed: 0);
      await settle();
      expect(pair.host.canPlay(), isTrue);
      expect(pair.guest.canPlay(), isFalse);
      await expectLater(pair.guest.play(1), throwsA(isA<TogetherMoveRefused>()));
      await expectLater(pair.host.play(1, seat: 1), throwsA(isA<TogetherMoveRefused>()));
      await expectLater(pair.host.play(3), throwsA(isA<TogetherMoveRefused>().having((e) => e.code, 'code', 'illegalMove')));
      await pair.host.play(2);
      await settle();
      expect(pair.guest.turn, 1);
      expect(pair.guest.canPlay(), isTrue);
      await expectLater(pair.host.play(1), throwsA(isA<TogetherMoveRefused>()));
      await pair.guest.play(1);
      await settle();
      expect(pair.host.turn, 2);
      expect(pair.host.stateHash, pair.guest.stateHash);
    });

    test('a forged move for the other seat is ignored and the host re-asserts its state', () async {
      final pair = SessionPair();
      addTearDown(pair.dispose);
      await pair.host.start(seed: 0);
      await settle();
      // The guest claims to move seat 0 (the host's seat) – forged by hand.
      final forged = const TogetherCodec(policy: GameDataPolicy(allowedKeys: RaceGame.keys)).encode(
        TogetherEnvelope(
          sessionId: pair.host.sessionId,
          from: 1,
          seq: 1,
          body: MoveBody(turn: 1, seat: 0, move: GameData({'add': 2}), hash: StateHash.of(0)),
        ),
      );
      pair.link.host.injectIncoming(forged.text);
      await settle();
      expect(pair.host.turn, 0);
      expect(pair.host.state.n, 0);
    });

    test('retransmitted duplicates are ignored', () async {
      final pair = SessionPair();
      addTearDown(pair.dispose);
      await pair.host.start(seed: 1);
      await settle();
      await pair.host.play(1);
      await settle();
      await pair.guest.play(2);
      await settle();
      final last = pair.link.wire.lastWhere((w) => w.from == 0 && w.text.contains('"k":"move"'));
      pair.link.guest.injectIncoming(last.text);
      pair.link.guest.injectIncoming(last.text);
      await settle();
      expect(pair.guest.turn, 2);
      expect(pair.guest.stateHash, pair.host.stateHash);
    });

    test('moves held and released in reverse order still apply in order', () async {
      // Host plays AI + own seat several times in a row: a 2-seat game where
      // seat 1 is an AI driven by the host.
      final link = LoopbackLink();
      final host = TogetherSession<RaceState, int>(
        adapter: const RaceGame(),
        transport: link.host,
        seats: const [0, TogetherSeats.ai],
      );
      final guest = TogetherSession<RaceState, int>(
        adapter: const RaceGame(),
        transport: link.guest,
        role: SessionRole.guest,
      );
      addTearDown(host.dispose);
      addTearDown(guest.dispose);
      await host.start(seed: 0);
      await settle();
      link.hold(0);
      await host.play(1); // seat 0
      await host.play(1, seat: 1); // the AI seat, played by the host
      await host.play(1); // seat 0
      link.release(0, reverse: true);
      await settle();
      expect(guest.turn, 3);
      expect(guest.stateHash, host.stateHash);
    });

    test('a lost frame is recovered through sync and retransmission', () async {
      final pair = SessionPair();
      addTearDown(pair.dispose);
      await pair.host.start(seed: 1);
      await settle();
      pair.link.dropNext(0);
      await pair.host.play(1); // lost
      await settle();
      expect(pair.guest.turn, 0);
      // The next message reveals the gap; the guest asks, the host resends.
      pair.host.resync();
      await settle();
      expect(pair.guest.turn, 1);
      expect(pair.guest.stateHash, pair.host.stateHash);
    });

    test('reconnect: moves made while disconnected arrive after the link returns', () async {
      final pair = SessionPair();
      addTearDown(pair.dispose);
      await pair.host.start(seed: 2);
      await settle();
      pair.link.disconnect();
      await pair.host.play(2);
      await settle();
      expect(pair.guest.turn, 0);
      pair.link.reconnect();
      await settle();
      expect(pair.guest.turn, 1);
      expect(pair.guest.stateHash, pair.host.stateHash);
      await pair.guest.play(1);
      await settle();
      expect(pair.host.turn, 2);
    });

    test('diverged states are repaired by the host snapshot (resync by state hash)', () async {
      // The guest's rules drift after the start (a bug): its state after the
      // host's move hashes differently, so it asks for the host's snapshot.
      final pair = SessionPair(guest: const _DriftingRace());
      addTearDown(pair.dispose);
      final events = <SessionEvent>[];
      pair.guest.events.listen(events.add);
      await pair.host.start(seed: 2);
      await settle();
      await pair.host.play(2);
      await settle();
      expect(events.whereType<StateResynced>(), isNotEmpty);
      expect(pair.guest.stateHash, pair.host.stateHash);
      expect(pair.guest.state.n, pair.host.state.n);
      expect(pair.guest.turn, 1);
      // Play continues in sync.
      await pair.guest.play(1);
      await settle();
      expect(pair.host.turn, 2);
    });

    test('a guest with different rules fails instead of playing a diverging game', () async {
      final pair = SessionPair(guest: const RaceGame(startOffset: 1));
      addTearDown(pair.dispose);
      await pair.host.start(seed: 2);
      await settle();
      expect(pair.guest.phase, SessionPhase.failed);
      expect(pair.guest.failure, 'incompatibleGame');
    });

    test('a guest that joins late gets the start and the current state', () async {
      final link = LoopbackLink();
      final host = TogetherSession<RaceState, int>(adapter: const RaceGame(), transport: link.host);
      addTearDown(host.dispose);
      link.disconnect();
      await host.start(seed: 3);
      await host.play(1);
      final guest = TogetherSession<RaceState, int>(
        adapter: const RaceGame(),
        transport: link.guest,
        role: SessionRole.guest,
      );
      addTearDown(guest.dispose);
      link.reconnect();
      await settle();
      expect(guest.started, isTrue);
      expect(guest.turn, 1);
      expect(guest.stateHash, host.stateHash);
    });

    test('results are recorded on both devices with the same match id', () async {
      final pair = SessionPair();
      addTearDown(pair.dispose);
      await pair.host.start(seed: 0);
      await settle();
      while (pair.host.phase == SessionPhase.playing) {
        final s = pair.host.seatToMove!;
        await (s == 0 ? pair.host : pair.guest).play(2);
        await settle();
      }
      expect(pair.host.phase, SessionPhase.finished);
      expect(pair.guest.phase, SessionPhase.finished);
      expect(pair.hostRecords, hasLength(1));
      expect(pair.guestRecords, hasLength(1));
      final h = pair.hostRecords.single;
      expect(pair.guestRecords.single.id, h.id);
      expect(pair.guestRecords.single.outcome, h.outcome);
      expect(h.gameId, 'race');
      expect(h.mode, PlayMode.nearby);
      // n: 0 → +2 ×6 = 12: the sixth move (seat 1) wins.
      expect(h.outcome, MatchOutcome.twoWon);
      expect(h.scoreOne, 5);
      expect(h.scoreTwo, 6);
    });

    test('the peer leaving ends the session', () async {
      final pair = SessionPair();
      addTearDown(pair.dispose);
      await pair.host.start(seed: 0);
      await settle();
      await pair.guest.leave();
      await settle();
      expect(pair.host.phase, SessionPhase.abandoned);
      expect(pair.host.failure, 'peerLeft');
    });

    test('real-time: inputs are latest-wins per seat, the host publishes snapshots', () async {
      final pair = SessionPair();
      addTearDown(pair.dispose);
      await pair.host.start(seed: 0);
      await settle();
      final inputs = <InputReceived>[];
      pair.host.events.listen((e) {
        if (e is InputReceived) inputs.add(e);
      });
      pair.link.hold(1);
      pair.guest.sendInput(1, {'add': 1}, tick: 1);
      pair.guest.sendInput(1, {'add': 2}, tick: 2);
      pair.link.release(1, reverse: true);
      await settle();
      expect(inputs.map((e) => e.tick), [2]); // tick 1 arrived late: dropped
      expect(() => pair.guest.sendInput(0, {'add': 1}, tick: 3), throwsA(isA<TogetherMoveRefused>()));
      expect(() => pair.guest.sendInput(1, {'name': 'x'}, tick: 3), throwsA(isA<TogetherDataRejected>()));

      pair.host.publishState(const RaceState(n: 7, toMove: 1, goal: 12), turn: 50);
      await settle();
      expect(pair.guest.turn, 50);
      expect(pair.guest.state.n, 7);
    });

    test('pass-and-play: both seats local, the active participant follows the turn', () async {
      final records = <MatchRecord>[];
      final s = TogetherSession<RaceState, int>.local(
        adapter: const RaceGame(),
        seating: const [PlayerSlot.two, PlayerSlot.one],
        recorder: (r) async {
          records.add(r);
          return null;
        },
      );
      addTearDown(s.dispose);
      expect(s.activeParticipant.value, isNull);
      await s.start(seed: 0);
      expect(s.activeParticipant.value, 0);
      await s.play(2);
      expect(s.activeParticipant.value, 1);
      expect(s.canPlay(), isTrue);
      while (s.phase == SessionPhase.playing) {
        await s.play(2);
      }
      await s.recorded;
      expect(records, hasLength(1));
      // Seat 1 (participant 1) won; participant 1 is player one here.
      expect(records.single.outcome, MatchOutcome.oneWon);
      expect(records.single.mode, PlayMode.passAndPlay);
      expect((s.transport as PassAndPlayTransport).framesSent, greaterThan(0));
      expect(s.activeParticipant.value, isNull);
    });

    test('recordFor maps seats to players: partners, rivals, AI winners', () async {
      final s = TogetherSession<RaceState, int>.local(adapter: const _FourSeatRace(), seats: TogetherSeats.partners(4));
      addTearDown(s.dispose);
      await s.start(seed: 0);
      expect(s.recordFor(SeatOutcome(winners: const [0, 2])).outcome, MatchOutcome.teamWon);
      expect(s.recordFor(SeatOutcome(winners: const [1, 3])).outcome, MatchOutcome.teamLost);
      expect(s.recordFor(const SeatOutcome.draw()).outcome, MatchOutcome.draw);
      final rivals = TogetherSession<RaceState, int>.local(
        adapter: const _FourSeatRace(),
        seats: TogetherSeats.rivals(4),
        seating: const [PlayerSlot.two, PlayerSlot.one],
      );
      addTearDown(rivals.dispose);
      await rivals.start(seed: 0);
      final r = rivals.recordFor(SeatOutcome(winners: const [0, 2], scores: const [31, 20, 31, 20]));
      expect(r.outcome, MatchOutcome.twoWon); // participant 0 is player two
      expect(r.scoreTwo, 31);
      expect(r.scoreOne, 20);
    });
  });

  group('adapters over the rules engines', () {
    test('four in a row plays a whole game over the loopback link', () async {
      final kit = boardGameKits[BoardGameId.connectFour]!;
      final link = LoopbackLink();
      final records = <MatchRecord>[];
      final host = TogetherSession<GameState, GameMove>(
        adapter: BoardKitTogetherAdapter(kit),
        transport: link.host,
        recorder: (r) async {
          records.add(r);
          return null;
        },
      );
      final guest = TogetherSession<GameState, GameMove>(
        adapter: BoardKitTogetherAdapter(kit),
        transport: link.guest,
        role: SessionRole.guest,
      );
      addTearDown(host.dispose);
      addTearDown(guest.dispose);
      await host.start(seed: 11);
      await settle();
      expect(host.adapter.gameId, 'fourInARow');
      var guard = 0;
      while (host.phase == SessionPhase.playing && guard++ < 60) {
        final seat = host.seatToMove!;
        final session = seat == 0 ? host : guest;
        final legal = kit.rules.legalMoves(session.state);
        await session.play(legal[(guard * 3) % legal.length]);
        await settle();
        expect(guest.stateHash, host.stateHash);
      }
      expect(host.phase, SessionPhase.finished);
      expect(guest.phase, SessionPhase.finished);
      expect(records, hasLength(1));
    });

    test('a card game (Basra) deals identically from the shared seed and stays in sync', () async {
      final link = LoopbackLink();
      final host = TogetherSession(adapter: CardEngineTogetherAdapter(CardGameId.basra), transport: link.host);
      final guest = TogetherSession(
        adapter: CardEngineTogetherAdapter(CardGameId.basra),
        transport: link.guest,
        role: SessionRole.guest,
      );
      addTearDown(host.dispose);
      addTearDown(guest.dispose);
      await host.start(seed: 77);
      await settle();
      expect(guest.stateHash, host.stateHash);
      for (var i = 0; i < 6; i++) {
        final seat = host.seatToMove!;
        // Rivals seating: seat 1 is the guest's, seat 0 and the AI seats the host's.
        final session = seat == 1 ? guest : host;
        final move = session.state.legalMoves(seat).first;
        await session.play(move);
        await settle();
        expect(guest.stateHash, host.stateHash);
      }
      expect(guest.turn, 6);
    });
  });
}

class _FixedRandom implements math.Random {
  @override
  bool nextBool() => false;

  @override
  double nextDouble() => 0.5;

  @override
  int nextInt(int max) => max ~/ 3;
}

/// Same start as [RaceGame], but a 2 counts as 3 (a rules bug on one side).
class _DriftingRace extends RaceGame {
  const _DriftingRace();

  @override
  RaceState applyMove(RaceState state, int seat, int move) => super.applyMove(state, seat, move == 2 ? 3 : move);
}

/// Four seats (partnership seating tests only).
class _FourSeatRace extends RaceGame {
  const _FourSeatRace();

  @override
  int get seatCount => 4;
}

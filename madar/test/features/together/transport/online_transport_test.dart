import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/encryption.dart' show MemorySecretStore;
import 'package:madar/features/cinema/rules/board/board_games.dart' show boardGameKits;
import 'package:madar/features/cinema/rules/board/core/game_types.dart' show BoardGameId, GameMove, GameState;
import 'package:madar/features/together/pairing/pairing.dart';
import 'package:madar/features/together/together.dart';

import '../together_test_utils.dart';
import 'net_fakes.dart';

PairingIdentity _me(PlayerSlot slot, String name, {int color = 1}) =>
    PairingIdentity(slot: slot, rawName: name, avatar: const TogetherAvatar.emoji('🌙', seed: 9), colorIndex: color);

class _Online {
  _Online({String gameB = 'fourInARow', Duration joinWindow = OnlineRooms.joinWindow}) {
    hostClient = db.client(uid: 'uid-ali');
    guestClient = db.client(uid: 'uid-sara');
    host = OnlineTransport(
      request: const TransportRequest(mode: PlayMode.online, host: true, gameId: 'fourInARow'),
      connect: () async {
        connects++;
        return hostClient;
      },
      ledger: OnlineRoomLedger(hostSecrets),
      random: ScriptedRandom([23456, 45678, 67890]),
      joinWindow: joinWindow,
      drain: const Duration(milliseconds: 300),
    );
    guest = OnlineTransport(
      request: TransportRequest(mode: PlayMode.online, host: false, gameId: gameB),
      connect: () async {
        connects++;
        return guestClient;
      },
      ledger: OnlineRoomLedger(guestSecrets),
      drain: const Duration(milliseconds: 300),
    );
  }

  final FakeRtdb db = FakeRtdb();
  late final FakeRtdbClient hostClient;
  late final FakeRtdbClient guestClient;
  late final OnlineTransport host;
  late final OnlineTransport guest;
  final MemorySecretStore hostSecrets = MemorySecretStore();
  final MemorySecretStore guestSecrets = MemorySecretStore();
  int connects = 0;

  final PairingIdentity ali = _me(PlayerSlot.one, 'Ali');
  final PairingIdentity sara = _me(PlayerSlot.one, 'Sara', color: 3);

  Future<String> hostRoom() async {
    await host.host(ali);
    await settle();
    return host.pairing.value.code!;
  }

  Future<void> pair() async {
    final code = await hostRoom();
    await guest.join(code, sara);
    await settle();
    await host.acceptGuest();
    await settle();
  }

  Future<void> dispose() async {
    await host.close();
    await guest.close();
  }
}

Future<
  (TogetherSession<GameState, GameMove>, TogetherSession<GameState, GameMove>, List<MatchRecord>, List<MatchRecord>)
>
_startGame(_Online o) async {
  final kit = boardGameKits[BoardGameId.connectFour]!;
  final hostRecords = <MatchRecord>[];
  final guestRecords = <MatchRecord>[];
  final host = PairedLink(transport: o.host, identity: o.ali).session(
    adapter: BoardKitTogetherAdapter(kit),
    firstPlayer: PlayerSlot.one,
    recorder: (r) async {
      hostRecords.add(r);
      return null;
    },
  );
  final guest = PairedLink(transport: o.guest, identity: o.sara).session(
    adapter: BoardKitTogetherAdapter(kit),
    firstPlayer: PlayerSlot.one,
    recorder: (r) async {
      guestRecords.add(r);
      return null;
    },
  );
  await host.start(seed: 11);
  await settle();
  return (host, guest, hostRecords, guestRecords);
}

void main() {
  group('pairing by code', () {
    test('nothing starts before "Create a code"; the room holds only the host\'s code data', () async {
      final o = _Online();
      addTearDown(o.dispose);
      await settle();
      expect(o.connects, 0, reason: 'Firebase is not touched until a code is created or typed');
      expect(o.db.writes, isEmpty);
      final code = await o.hostRoom();
      expect(code, '123456');
      expect(o.host.pairing.value.phase, PairingPhase.hosting);
      final room = o.db.room(code)!;
      expect(room.keys.toSet(), {'h', 'v', 'gm', 'c', 'x', 'ph'});
      expect(room['h'], 'uid-ali');
      expect(room['gm'], 'fourInARow');
      expect(room['ph'], {'n': 'Ali', 'a': 'e9:🌙', 'k': 1});
      expect(room['x'], o.db.nowMs + OnlineRooms.joinWindow.inMilliseconds);
      expect(o.host.pairing.value.expiresAt!.millisecondsSinceEpoch, room['x']);
    });

    test('the guest types the code (Arabic digits welcome); the host sees who joined and accepts', () async {
      final o = _Online();
      addTearDown(o.dispose);
      await o.hostRoom();
      await o.guest.join('١٢٣ ٤٥٦', o.sara);
      await settle();
      expect(o.guest.pairing.value.phase, PairingPhase.waitingForPeer);
      expect(o.guest.pairing.value.peer!.name, 'Ali');
      expect(o.host.pairing.value.phase, PairingPhase.confirm);
      final joiner = o.host.pairing.value.peer!;
      expect(joiner.name, 'Sara');
      expect(joiner.colorIndex, 3);
      expect(joiner.avatar, const TogetherAvatar.emoji('🌙', seed: 9));
      expect(o.guest.status.value, TransportStatus.connecting);

      await o.host.acceptGuest();
      await settle();
      expect(o.host.pairing.value.phase, PairingPhase.connected);
      expect(o.guest.pairing.value.phase, PairingPhase.connected);
      expect(o.host.role, SessionRole.host);
      expect(o.guest.role, SessionRole.guest);
      expect(o.host.status.value, TransportStatus.connected);
      expect(o.guest.status.value, TransportStatus.connected);
      final room = o.db.room('123456')!;
      expect(room['ok'], isTrue);
      expect(room['x'], o.db.nowMs + OnlineRooms.ttl.inMilliseconds, reason: 'a playing room lives longer');
    });

    test('declining a stranger deletes the room and shows a new code', () async {
      final o = _Online();
      addTearDown(o.dispose);
      await o.hostRoom();
      await o.guest.join('123456', o.sara);
      await settle();
      await o.host.declineGuest();
      await settle();
      expect(o.db.room('123456'), isNull);
      expect(o.host.pairing.value.phase, PairingPhase.hosting);
      expect(o.host.pairing.value.code, '145678');
      expect(o.guest.pairing.value.phase, PairingPhase.failed);
      expect(o.guest.pairing.value.failure, PairingFailure.declinedByPeer);
    });

    test('wrong, expired, other-game and taken codes are told apart', () async {
      final o = _Online();
      addTearDown(o.dispose);
      await o.hostRoom();

      await o.guest.join('999999', o.sara);
      expect(o.guest.pairing.value.failure, PairingFailure.notFound);
      await o.guest.join('12345', o.sara);
      expect(o.guest.pairing.value.failure, PairingFailure.notFound);

      final chess = OnlineTransport(
        request: const TransportRequest(mode: PlayMode.online, host: false, gameId: 'chess'),
        connect: () async => o.db.client(uid: 'uid-chess'),
      );
      addTearDown(chess.close);
      await chess.join('123456', o.sara);
      expect(chess.pairing.value.failure, PairingFailure.differentGame);

      await o.guest.join('123456', o.sara);
      await settle();
      expect(o.guest.pairing.value.phase, PairingPhase.waitingForPeer);
      final late = OnlineTransport(
        request: const TransportRequest(mode: PlayMode.online, host: false, gameId: 'fourInARow'),
        connect: () async => o.db.client(uid: 'uid-eve'),
      );
      addTearDown(late.close);
      await late.join('123456', _me(PlayerSlot.one, 'Eve'));
      expect(late.pairing.value.failure, PairingFailure.taken);
      expect(o.db.room('123456')!['g'], 'uid-sara');

      final o2 = _Online();
      addTearDown(o2.dispose);
      await o2.hostRoom();
      o2.db.advance(OnlineRooms.joinWindow + const Duration(seconds: 1));
      await o2.guest.join('123456', o2.sara);
      expect(o2.guest.pairing.value.failure, PairingFailure.expired);
    });

    test('an unused code expires: the host is told and the room is deleted', () async {
      final o = _Online(joinWindow: const Duration(milliseconds: 40));
      addTearDown(o.dispose);
      final code = await o.hostRoom();
      await Future<void>.delayed(const Duration(milliseconds: 80));
      await settle();
      expect(o.host.pairing.value.phase, PairingPhase.failed);
      expect(o.host.pairing.value.failure, PairingFailure.expired);
      expect(o.db.room(code), isNull);
      // A new code after "Try again".
      await o.host.reset();
      await o.host.host(o.ali);
      await settle();
      expect(o.host.pairing.value.phase, PairingPhase.hosting);
    });

    test('setup problems: online play off, anonymous sign-in off, rules missing', () async {
      final off = OnlineTransport(
        request: const TransportRequest(mode: PlayMode.online, host: true, gameId: 'fourInARow'),
        connect: () async => throw const OnlineNotConfigured(),
      );
      addTearDown(off.close);
      await off.host(_me(PlayerSlot.one, 'Ali'));
      expect(off.pairing.value.phase, PairingPhase.needsSetup);

      final db = FakeRtdb()..anonymousAuthEnabled = false;
      final noAuth = OnlineTransport(
        request: const TransportRequest(mode: PlayMode.online, host: true, gameId: 'fourInARow'),
        connect: () async => db.client(),
      );
      addTearDown(noAuth.close);
      await noAuth.host(_me(PlayerSlot.one, 'Ali'));
      expect(noAuth.pairing.value.failure, PairingFailure.signIn);

      final locked = FakeRtdb()..rulesInstalled = false;
      final noRules = OnlineTransport(
        request: const TransportRequest(mode: PlayMode.online, host: true, gameId: 'fourInARow'),
        connect: () async => locked.client(),
      );
      addTearDown(noRules.close);
      await noRules.host(_me(PlayerSlot.one, 'Ali'));
      expect(noRules.pairing.value.failure, PairingFailure.rules);
    });
  });

  group('a whole game online', () {
    test('four in a row start to finish; every frame is read once and deleted', () async {
      final o = _Online();
      await o.pair();
      final (host, guest, hostRecords, guestRecords) = await _startGame(o);
      final kit = boardGameKits[BoardGameId.connectFour]!;
      var guard = 0;
      while (host.phase == SessionPhase.playing && guard++ < 60) {
        final session = host.canPlay() ? host : guest;
        final legal = kit.rules.legalMoves(session.state);
        await session.play(legal[(guard * 3) % legal.length]);
        await settle();
        expect(guest.stateHash, host.stateHash);
      }
      expect(host.phase, SessionPhase.finished);
      expect(guest.phase, SessionPhase.finished);
      expect(hostRecords.single.id, guestRecords.single.id);
      expect(hostRecords.single.mode, PlayMode.online);
      await settle();
      expect(o.db.room('123456')!['f'], isNull, reason: 'the recipient deletes each frame it read');

      // Privacy: every write is room bookkeeping, a profile of name / avatar
      // / colour, or a whitelisted frame – nothing else ever reached the
      // database.
      final codec = TogetherCodec(policy: BoardKitTogetherAdapter.boardPolicy);
      var frames = 0;
      for (final w in o.db.writes) {
        final parts = w.path.split('/');
        expect(parts.first, 'rooms');
        expect(parts[1], '123456');
        if (w.value == null) continue; // a deletion
        if (parts.length == 2) {
          final room = w.value! as Map;
          expect(room.keys.toSet(), {'h', 'v', 'gm', 'c', 'x', 'ph'});
          expect((room['ph'] as Map).keys.toSet(), {'n', 'a', 'k'});
          continue;
        }
        switch (parts[2]) {
          case 'g' || 'x' || 'ok':
            expect(w.value, anyOf(isA<String>(), isA<int>(), isTrue));
          case 'pg':
            expect((w.value! as Map).keys.toSet(), {'n', 'a', 'k'});
          case 'f':
            final f = w.value! as Map;
            expect(f.keys.toSet(), {'s', 't', 'at'});
            expect(() => codec.decode(f['t'] as String), returnsNormally);
            expect(f['t'], isNot(contains('Ali')));
            expect(f['t'], isNot(contains('Sara')));
            frames++;
          default:
            fail('unexpected write ${w.path}');
        }
      }
      expect(frames, greaterThan(10));
      expect(o.db.refused, isEmpty);
      host.dispose();
      guest.dispose();
      await settle();
      await o.dispose();
    });

    test('leaving deletes the room; the partner hears the bye and sees the room gone', () async {
      final o = _Online();
      await o.pair();
      final (host, guest, _, _) = await _startGame(o);
      final events = <SessionEvent>[];
      guest.events.listen(events.add);
      await host.leave();
      host.dispose();
      await o.host.close();
      await settle();
      expect(o.db.room('123456'), isNull);
      expect(events.whereType<PeerLeft>(), hasLength(1));
      expect(o.guest.pairing.value.failure, PairingFailure.peerLeft);
      expect(await OnlineRoomLedger(o.hostSecrets).codes(), isEmpty);
      guest.dispose();
      await settle();
      await o.guest.close();
      expect(o.hostClient.closedCalled, isTrue);
    });

    test('a connection drop: moves made meanwhile arrive once back online', () async {
      final o = _Online();
      await o.pair();
      final (host, guest, _, _) = await _startGame(o);
      final kit = boardGameKits[BoardGameId.connectFour]!;
      o.guestClient.goOffline();
      await settle();
      expect(o.guest.status.value, TransportStatus.disconnected);
      await host.play(kit.rules.legalMoves(host.state).first);
      await settle();
      expect(guest.turn, 0);
      o.guestClient.goOnline();
      await settle();
      expect(o.guest.status.value, TransportStatus.connected);
      expect(guest.turn, 1);
      await guest.play(kit.rules.legalMoves(guest.state).first);
      await settle();
      expect(host.turn, 2);
      expect(host.stateHash, guest.stateHash);
      host.dispose();
      guest.dispose();
      await settle();
      await o.dispose();
    });

    test('duplicated and out-of-order frames in the room change nothing', () async {
      final o = _Online();
      await o.pair();
      final (host, guest, _, _) = await _startGame(o);
      final kit = boardGameKits[BoardGameId.connectFour]!;
      // The guest stops reading; the host plays twice (with the guest's turn
      // in between played by… nobody: the host's frames pile up).
      o.guestClient.goOffline();
      await host.play(kit.rules.legalMoves(host.state).first);
      await settle();
      final pending = Map<String, Object?>.from(o.db.room('123456')!['f']! as Map);
      expect(pending, isNotEmpty);
      // Replay those frames again, in reverse order, as the host.
      for (final f in pending.values.whereType<Map<Object?, Object?>>().where((f) => f['s'] == 0).toList().reversed) {
        await o.hostClient.push(OnlineRooms.frames('123456'), {'s': 0, 't': f['t'], 'at': rtdbServerTimestamp});
      }
      o.guestClient.goOnline();
      await settle(60);
      expect(guest.turn, 1);
      expect(guest.stateHash, host.stateHash);
      host.dispose();
      guest.dispose();
      await settle();
      await o.dispose();
    });

    test('unread own frames are capped while the partner is away', () async {
      final db = FakeRtdb();
      final a = db.client(uid: 'a');
      final b = db.client(uid: 'b');
      final host = OnlineTransport(
        request: const TransportRequest(mode: PlayMode.online, host: true, gameId: 'fourInARow'),
        connect: () async => a,
        random: ScriptedRandom([23456]),
        maxOwnPending: 5,
      );
      final guest = OnlineTransport(
        request: const TransportRequest(mode: PlayMode.online, host: false, gameId: 'fourInARow'),
        connect: () async => b,
      );
      await host.host(_me(PlayerSlot.one, 'Ali'));
      await settle();
      await guest.join('123456', _me(PlayerSlot.one, 'Sara'));
      await settle();
      await host.acceptGuest();
      await settle();
      b.goOffline();
      const codec = TogetherCodec();
      for (var i = 0; i < 12; i++) {
        await host.send(
          codec.encode(
            TogetherEnvelope(
              sessionId: 'abcdef0123456789',
              from: 0,
              body: SyncBody(turn: i),
            ),
          ),
        );
      }
      await settle();
      expect((db.room('123456')!['f']! as Map).length, lessThanOrEqualTo(5));
      await host.close();
      await guest.close();
    });
  });

  group('room lifetime and the rules', () {
    test('a room left behind by a crash is deleted at the next online pairing', () async {
      final o = _Online();
      addTearDown(o.dispose);
      final code = await o.hostRoom();
      expect(await OnlineRoomLedger(o.hostSecrets).codes(), [code]);
      // The app dies: no close. Next time, a new transport with the same
      // secure storage.
      final again = OnlineTransport(
        request: const TransportRequest(mode: PlayMode.online, host: true, gameId: 'fourInARow'),
        connect: () async => o.hostClient,
        ledger: OnlineRoomLedger(o.hostSecrets),
        random: ScriptedRandom([45678]),
      );
      addTearDown(again.close);
      await again.host(o.ali);
      await settle();
      expect(o.db.room(code), isNull);
      expect(o.db.room('145678'), isNotNull);
      expect(await OnlineRoomLedger(o.hostSecrets).codes(), ['145678']);
    });

    test('an expired room can be reused or deleted by anyone; a live one cannot', () async {
      final o = _Online();
      addTearDown(o.dispose);
      final code = await o.hostRoom();
      final eve = o.db.client(uid: 'uid-eve');
      await eve.signIn();
      Map<String, Object?> hijack() => OnlineRooms.newRoom(
        hostUid: 'uid-eve',
        gameId: 'chess',
        host: _me(PlayerSlot.one, 'Eve'),
        now: eve.serverNow(),
      );
      await expectLater(eve.set(OnlineRooms.room(code), hijack()), throwsA(isA<RtdbException>()));
      await expectLater(eve.remove(OnlineRooms.room(code)), throwsA(isA<RtdbException>()));
      o.db.advance(OnlineRooms.joinWindow + const Duration(minutes: 1));
      await eve.set(OnlineRooms.room(code), hijack());
      expect(o.db.room(code)!['h'], 'uid-eve');
      o.db.advance(OnlineRooms.joinWindow + const Duration(minutes: 1));
      final other = o.db.client(uid: 'uid-other');
      await other.signIn();
      await other.remove(OnlineRooms.room(code));
      expect(o.db.room(code), isNull);
    });

    test('strangers can neither read a room nor write frames, profiles or extra fields', () async {
      final o = _Online();
      addTearDown(o.dispose);
      await o.pair();
      const codec = TogetherCodec();
      final hello = codec.encode(
        const TogetherEnvelope(
          sessionId: 'abcdef0123456789',
          from: 1,
          body: HelloBody(gameId: 'fourInARow', gameVersion: 1),
        ),
      );
      final eve = o.db.client(uid: 'uid-eve');
      await eve.signIn();
      final room = OnlineRooms.room('123456');
      await expectLater(eve.read(room), throwsA(isA<RtdbException>()));
      await expectLater(eve.read('$room/ph'), throwsA(isA<RtdbException>()));
      expect(await eve.read('$room/gm'), 'fourInARow', reason: 'the game id alone is public to signed-in users');
      await expectLater(eve.push('$room/f', OnlineRooms.frame(1, hello.text)), throwsA(isA<RtdbException>()));
      await expectLater(eve.set('$room/g', 'uid-eve'), throwsA(isA<RtdbException>()));

      // Members: only frames that look like Together frames, as themselves.
      await expectLater(o.guestClient.push('$room/f', OnlineRooms.frame(0, hello.text)), throwsA(isA<RtdbException>()));
      await expectLater(
        o.guestClient.push('$room/f', OnlineRooms.frame(1, 'hello there')),
        throwsA(isA<RtdbException>()),
      );
      await expectLater(
        o.guestClient.push('$room/f', {'s': 1, 't': hello.text, 'at': rtdbServerTimestamp, 'phone': '0795551234'}),
        throwsA(isA<RtdbException>()),
      );
      await expectLater(o.guestClient.set('$room/notes', 'hi'), throwsA(isA<RtdbException>()));
      await expectLater(
        o.guestClient.set('$room/pg', {'n': 'Sara', 'a': 'c1', 'k': 1, 'city': 'Amman'}),
        throwsA(isA<RtdbException>()),
      );
      await expectLater(o.hostClient.set('$room/ok', false), throwsA(isA<RtdbException>()));
      await expectLater(
        o.hostClient.set('$room/x', o.db.nowMs + const Duration(days: 2).inMilliseconds),
        throwsA(isA<RtdbException>()),
        reason: 'a room lives at most 6 hours ahead',
      );
      await o.guestClient.push('$room/f', OnlineRooms.frame(1, hello.text));
    });
  });

  group('rooms and profiles', () {
    test('codes: random 6 digits, Arabic-Indic and Persian digits normalised, shown in two halves', () {
      expect(OnlineRooms.normalizeCode('١٢٣-۴۵۶'), '123456');
      expect(OnlineRooms.normalizeCode(' 12 34 56 '), '123456');
      expect(OnlineRooms.isValidCode('12345'), isFalse);
      expect(OnlineRooms.displayCode('123456'), '123 456');
      expect(OnlineRooms.newCode(ScriptedRandom([0])), '100000');
      expect(OnlineRooms.newCode(ScriptedRandom([899999])), '999999');
    });

    test('a stored profile is untrusted: cleaned, bounded, unknown avatars dropped', () {
      final peer = OnlineRooms.peerOf('u', {'n': '\u202E${'x' * 80}', 'a': 'z9', 'k': 99});
      expect(peer.name.runes.length, TogetherBounds.maxNameLength);
      expect(peer.avatar, isNull);
      expect(peer.colorIndex, isNull);
      expect(OnlineRooms.peerOf('u', null).name, '?');
      for (final a in const [
        TogetherAvatar.constellation(1207),
        TogetherAvatar.initials(seed: 3),
        TogetherAvatar.emoji('🦁', seed: 5),
      ]) {
        expect(OnlineRooms.avatarOf(OnlineRooms.avatarId(a)), a);
      }
    });

    test('the security rules are valid JSON with every guarded field', () {
      final rules = jsonDecode(OnlineSecurityRules.json) as Map;
      final room = ((rules['rules'] as Map)['rooms'] as Map)[r'$code'] as Map;
      expect(room.keys, containsAll(['.read', '.write', '.validate', 'h', 'g', 'x', 'ok', 'ph', 'pg', 'f', r'$other']));
      expect((rules['rules'] as Map)['.read'], isFalse);
      expect((rules['rules'] as Map)['.write'], isFalse);
      expect(((room['f'] as Map)[r'$frame'] as Map)['t'], isNotNull);
    });
  });
}

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/cinema/rules/board/board_games.dart' show boardGameKits;
import 'package:madar/features/cinema/rules/board/core/game_types.dart' show BoardGameId, GameMove, GameState;
import 'package:madar/features/together/pairing/pairing.dart';
import 'package:madar/features/together/together.dart';
import 'package:permission_handler/permission_handler.dart' show Permission;

import '../together_test_utils.dart';
import 'net_fakes.dart';

const _request = TransportRequest(mode: PlayMode.nearby, host: true, gameId: 'fourInARow');

PairingIdentity _me(PlayerSlot slot, String name) =>
    PairingIdentity(slot: slot, rawName: name, avatar: const TogetherAvatar.constellation(7), colorIndex: 1);

/// Two phones in the same air, each with its own transport.
class _Pair {
  _Pair({
    Duration grace = const Duration(milliseconds: 200),
    FakeNearbyPermissions? permsA,
    FakeNearbyPermissions? permsB,
    String gameA = 'fourInARow',
    String gameB = 'fourInARow',
  }) : air = FakeNearbyAir() {
    phoneA = air.phone('ali');
    phoneB = air.phone('sara');
    a = NearbyTransport(
      api: phoneA,
      permissions: permsA ?? FakeNearbyPermissions(),
      request: TransportRequest(mode: PlayMode.nearby, host: true, gameId: gameA),
      foreground: foregroundA,
      reconnectGrace: grace,
      autoConnectDelay: Duration.zero,
    );
    b = NearbyTransport(
      api: phoneB,
      permissions: permsB ?? FakeNearbyPermissions(),
      request: TransportRequest(mode: PlayMode.nearby, host: true, gameId: gameB),
      foreground: foregroundB,
      reconnectGrace: grace,
      autoConnectDelay: Duration.zero,
    );
  }

  final FakeNearbyAir air;
  late final FakeNearbyApi phoneA;
  late final FakeNearbyApi phoneB;
  late final NearbyTransport a;
  late final NearbyTransport b;
  final ValueNotifier<bool> foregroundA = ValueNotifier(true);
  final ValueNotifier<bool> foregroundB = ValueNotifier(true);

  // Ali is player one on his phone; Sara keeps herself as player one too.
  final PairingIdentity ali = _me(PlayerSlot.one, 'Ali');
  final PairingIdentity sara = _me(PlayerSlot.one, 'Sara');

  Future<void> tapPlayTogether() async {
    await a.playTogether(ali);
    await b.playTogether(sara);
    await settle();
  }

  Future<void> confirmBoth() async {
    await a.confirmToken();
    await b.confirmToken();
    await settle();
  }

  Future<void> pair() async {
    await tapPlayTogether();
    await confirmBoth();
  }

  NearbyTransport get host => a.role == SessionRole.host ? a : b;

  NearbyTransport get guest => a.role == SessionRole.host ? b : a;

  Future<void> dispose() async {
    await a.close();
    await b.close();
  }
}

/// The frames that crossed the air, reassembled per sender.
List<String> _framesOnAir(FakeNearbyAir air) {
  final out = <String>[];
  final buffers = <String, FrameReassembler>{};
  for (final (from, _, bytes) in air.wire) {
    final text = (buffers[from] ??= FrameReassembler()).add(bytes);
    if (text != null) out.add(text);
  }
  return out;
}

void main() {
  group('pairing', () {
    test('nothing is advertised or discovered before "Play together"', () async {
      final p = _Pair();
      addTearDown(p.dispose);
      await settle();
      expect(p.phoneA.calls, isEmpty);
      expect(p.phoneB.calls, isEmpty);
      expect(p.a.pairing.value.phase, PairingPhase.idle);
      expect(p.a.status.value, TransportStatus.connecting);
    });

    test('both phones show the same four digits; confirming pairs them with distinct roles', () async {
      final p = _Pair();
      addTearDown(p.dispose);
      await p.tapPlayTogether();
      expect(p.phoneA.advertisingName, 'Ali', reason: 'the endpoint name is the display name only');
      expect(p.phoneB.advertisingName, 'Sara');
      expect(p.phoneA.advertisingService, 'app.madar.orbit.together.v1.fourInARow');
      final sa = p.a.pairing.value;
      final sb = p.b.pairing.value;
      expect(sa.phase, PairingPhase.confirm);
      expect(sb.phase, PairingPhase.confirm);
      expect(sa.token, matches(RegExp(r'^[0-9]{4}$')));
      expect(sa.token, sb.token);
      expect(sa.peer!.name, 'Sara');
      expect(sb.peer!.name, 'Ali');

      await p.a.confirmToken();
      await settle();
      expect(p.a.pairing.value.phase, PairingPhase.waitingForPeer);
      expect(p.a.status.value, TransportStatus.connecting);
      await p.b.confirmToken();
      await settle();

      expect(p.a.pairing.value.phase, PairingPhase.connected);
      expect(p.b.pairing.value.phase, PairingPhase.connected);
      expect(p.a.status.value, TransportStatus.connected);
      expect({p.a.role, p.b.role}, {SessionRole.host, SessionRole.guest});
      expect(p.host.localParticipants, {0});
      expect(p.guest.localParticipants, {1});
      // Radios off once paired.
      for (final (t, phone) in [(p.a, p.phoneA), (p.b, p.phoneB)]) {
        expect(t.advertising, isFalse);
        expect(t.discovering, isFalse);
        expect(phone.advertising, isFalse);
        expect(phone.discovering, isFalse);
        expect(phone.calls, containsAll(['stopAdvertising', 'stopDiscovery']));
      }
    });

    test('phones opening different games never find each other', () async {
      final p = _Pair(gameB: 'chess');
      addTearDown(p.dispose);
      await p.tapPlayTogether();
      expect(p.a.pairing.value.phase, PairingPhase.searching);
      expect(p.a.pairing.value.found, isEmpty);
      expect(p.phoneA.calls, isNot(contains('requestConnection')));
    });

    test('"they don\'t match" refuses that phone: the other side is told, and it is not retried', () async {
      final p = _Pair();
      addTearDown(p.dispose);
      await p.tapPlayTogether();
      await p.a.declineToken();
      await settle();
      expect(p.a.pairing.value.phase, PairingPhase.searching);
      expect(p.a.pairing.value.found, isEmpty, reason: 'the declined phone is no longer offered');
      expect(p.b.pairing.value.phase, PairingPhase.failed);
      expect(p.b.pairing.value.failure, PairingFailure.declinedByPeer);
      expect(p.b.advertising, isFalse);
      final requests = p.phoneA.calls.where((c) => c == 'requestConnection').length;
      await settle();
      expect(p.phoneA.calls.where((c) => c == 'requestConnection').length, requests);
    });

    test('several phones found: none is picked automatically; the player chooses', () async {
      final air = FakeNearbyAir();
      final me = air.phone('ali');
      final t = NearbyTransport(api: me, permissions: FakeNearbyPermissions(), request: _request, autoConnectDelay: Duration.zero);
      addTearDown(t.close);
      for (final name in ['Sara', 'Huda']) {
        final other = air.phone(name);
        await other.startAdvertising(name: name, serviceId: t.serviceId);
      }
      await t.playTogether(_me(PlayerSlot.one, 'Ali'));
      await settle();
      expect(t.pairing.value.found.map((f) => f.name), unorderedEquals(['Sara', 'Huda']));
      expect(me.calls, isNot(contains('requestConnection')));
      t.connectTo(t.pairing.value.found.firstWhere((f) => f.name == 'Huda').id);
      await settle();
      expect(t.pairing.value.phase, PairingPhase.confirm);
      expect(t.pairing.value.peer!.name, 'Huda');
    });

    test('a radio error when starting fails as "turn on Bluetooth"', () async {
      final p = _Pair();
      addTearDown(p.dispose);
      p.phoneA.failNextStart = NearbyApiException.from(Exception('8007: STATUS_RADIO_ERROR'));
      await p.a.playTogether(p.ali);
      await settle();
      expect(p.a.pairing.value.phase, PairingPhase.failed);
      expect(p.a.pairing.value.failure, PairingFailure.radioOff);
      expect(p.a.advertising, isFalse);
    });

    test('the endpoint name is cleaned and bounded', () async {
      final p = _Pair();
      addTearDown(p.dispose);
      await p.a.playTogether(_me(PlayerSlot.one, '  A\u202Ebc\u0000 ${'x' * 60}'));
      await settle();
      expect(p.phoneA.advertisingName, isNot(contains('\u202E')));
      expect(p.phoneA.advertisingName!.runes.length, lessThanOrEqualTo(TogetherBounds.maxNameLength));
    });
  });

  group('permissions', () {
    test('missing permission: the rationale first, nothing started until the player continues', () async {
      final perms = FakeNearbyPermissions(status: NearbyPermissionStatus.needed);
      final p = _Pair(permsA: perms);
      addTearDown(p.dispose);
      await p.a.playTogether(p.ali);
      await settle();
      expect(p.a.pairing.value.phase, PairingPhase.needsPermission);
      expect(p.a.pairing.value.need, NearbyPermissionNeed.nearbyDevices);
      expect(p.phoneA.calls, isEmpty);
      expect(perms.requests, 0, reason: 'the system dialog only after the rationale');
      await p.a.grantPermissions();
      await settle();
      expect(perms.requests, 1);
      expect(p.a.pairing.value.phase, PairingPhase.searching);
      expect(p.phoneA.advertising, isTrue);
    });

    test('refused in the dialog: "permission needed", and asking again is possible', () async {
      final perms = FakeNearbyPermissions(status: NearbyPermissionStatus.needed, afterRequest: NearbyPermissionStatus.needed);
      final p = _Pair(permsA: perms);
      addTearDown(p.dispose);
      await p.a.playTogether(p.ali);
      await p.a.grantPermissions();
      expect(p.a.pairing.value.phase, PairingPhase.permissionDenied);
      expect(p.a.pairing.value.permanentlyDenied, isFalse);
      expect(p.phoneA.calls, isEmpty);
      perms.afterRequest = NearbyPermissionStatus.granted;
      await p.a.grantPermissions();
      await settle();
      expect(p.a.pairing.value.phase, PairingPhase.searching);
    });

    test('permanently refused: only the settings page can help', () async {
      final perms = FakeNearbyPermissions(
        status: NearbyPermissionStatus.permanentlyDenied,
        needValue: NearbyPermissionNeed.location,
      );
      final p = _Pair(permsA: perms);
      addTearDown(p.dispose);
      await p.a.playTogether(p.ali);
      expect(p.a.pairing.value.phase, PairingPhase.permissionDenied);
      expect(p.a.pairing.value.permanentlyDenied, isTrue);
      expect(p.a.pairing.value.need, NearbyPermissionNeed.location);
      await p.a.openSettings();
      expect(perms.appSettings, 1);
      expect(p.phoneA.calls, isEmpty);
    });

    test('location services off (Android 12L and older): settings, or search anyway', () async {
      final perms = FakeNearbyPermissions(status: NearbyPermissionStatus.serviceOff);
      final p = _Pair(permsA: perms);
      addTearDown(p.dispose);
      await p.a.playTogether(p.ali);
      expect(p.a.pairing.value.phase, PairingPhase.serviceOff);
      await p.a.openSettings();
      expect(perms.locationSettings, 1);
      await p.a.searchAnyway();
      await settle();
      expect(p.a.pairing.value.phase, PairingPhase.searching);
    });

    test('a permission revoked meanwhile (Nearby says MISSING_PERMISSION) shows the permission state', () async {
      final p = _Pair();
      addTearDown(p.dispose);
      p.phoneA.failNextStart = NearbyApiException.from(Exception('MISSING_PERMISSION_BLUETOOTH_SCAN'));
      await p.a.playTogether(p.ali);
      await settle();
      expect(p.a.pairing.value.phase, PairingPhase.permissionDenied);
    });

    test('the plan asks exactly what each Android version needs', () {
      expect(const NearbyPermissionPlan(26).permissions, [Permission.location]);
      expect(const NearbyPermissionPlan(30).need, NearbyPermissionNeed.location);
      expect(const NearbyPermissionPlan(31).permissions, [
        Permission.bluetoothScan,
        Permission.bluetoothAdvertise,
        Permission.bluetoothConnect,
        Permission.location,
      ]);
      expect(const NearbyPermissionPlan(32).need, NearbyPermissionNeed.nearbyDevicesAndLocation);
      expect(const NearbyPermissionPlan(33).permissions, [
        Permission.bluetoothScan,
        Permission.bluetoothAdvertise,
        Permission.bluetoothConnect,
        Permission.nearbyWifiDevices,
      ]);
      expect(const NearbyPermissionPlan(36).need, NearbyPermissionNeed.nearbyDevices);
    });
  });

  group('radios and the app lifecycle', () {
    test('going to the background stops advertising and discovery; coming back resumes', () async {
      final p = _Pair();
      addTearDown(p.dispose);
      await p.a.playTogether(p.ali);
      await settle();
      expect(p.phoneA.advertising, isTrue);
      p.foregroundA.value = false;
      await settle();
      expect(p.phoneA.advertising, isFalse);
      expect(p.phoneA.discovering, isFalse);
      expect(p.a.pairing.value.paused, isTrue);
      p.foregroundA.value = true;
      await settle();
      expect(p.phoneA.advertising, isTrue);
      expect(p.phoneA.discovering, isTrue);
      expect(p.a.pairing.value.paused, isFalse);
    });

    test('leaving stops everything and disconnects', () async {
      final p = _Pair();
      await p.pair();
      await p.a.close();
      await settle();
      expect(p.phoneA.calls, containsAll(['disconnect', 'stopAllEndpoints']));
      expect(p.a.status.value, TransportStatus.closed);
      expect(p.a.pairing.value.phase, PairingPhase.closed);
      expect(p.b.pairing.value.phase, PairingPhase.reconnecting);
      await p.b.close();
      expect(p.phoneB.advertising, isFalse);
      expect(p.phoneB.discovering, isFalse);
    });

    test('cancelling while searching stops the radios', () async {
      final p = _Pair();
      await p.a.playTogether(p.ali);
      await settle();
      await p.a.close();
      expect(p.phoneA.advertising, isFalse);
      expect(p.phoneA.discovering, isFalse);
      await p.b.close();
    });
  });

  group('payloads', () {
    test('a frame larger than a Nearby payload is cut and rebuilt; nothing is added', () async {
      final p = _Pair();
      addTearDown(p.dispose);
      await p.pair();
      final big = GameData([for (var i = 0; i < 12000; i++) 100000 + i]);
      final frame = const TogetherCodec().encode(
        TogetherEnvelope(
          sessionId: 'abcdef0123456789',
          from: 0,
          seq: 1,
          body: SnapshotBody(turn: 1, state: big, hash: big.hash),
        ),
      );
      expect(frame.bytes, greaterThan(2 * FrameChunks.nearbyMaxPayload));
      final got = <String>[];
      p.guest.incoming.listen(got.add);
      await p.host.send(frame);
      await settle();
      expect(got, [frame.text]);
      final payloads = [for (final (_, _, b) in p.air.wire) b];
      expect(payloads.every((b) => b.length <= FrameChunks.nearbyMaxPayload), isTrue);
      expect(payloads.fold<int>(0, (n, b) => n + b.length), frame.bytes);
    });

    test('files and streams from the peer are cancelled unread; bytes from a stranger are ignored', () async {
      final p = _Pair();
      addTearDown(p.dispose);
      await p.pair();
      final got = <String>[];
      p.a.incoming.listen(got.add);
      p.phoneA.receiveFile(p.phoneB, 42);
      final stranger = p.air.phone('eve');
      p.phoneA.receiveBytes(stranger, Uint8List.fromList(utf8.encode('{"p":"madar.together"}')));
      await settle();
      expect(p.phoneA.cancelled, [42]);
      expect(got, isEmpty);
    });

    test('frames that arrive before the session listens are kept for it', () async {
      final p = _Pair();
      addTearDown(p.dispose);
      await p.pair();
      const codec = TogetherCodec();
      final frame = codec.encode(
        const TogetherEnvelope(sessionId: 'abcdef0123456789', from: 0, body: SyncBody(turn: 0)),
      );
      await p.host.send(frame);
      await settle();
      final got = <String>[];
      p.guest.incoming.listen(got.add);
      await settle();
      expect(got, [frame.text]);
    });
  });

  group('a whole game over Nearby', () {
    Future<(TogetherSession<GameState, GameMove>, TogetherSession<GameState, GameMove>, List<MatchRecord>, List<MatchRecord>)>
    start(_Pair p, {required PlayerSlot hostFirst}) async {
      final kit = boardGameKits[BoardGameId.connectFour]!;
      final hostRecords = <MatchRecord>[];
      final guestRecords = <MatchRecord>[];
      final hostLink = PairedLink(transport: p.host, identity: p.host == p.a ? p.ali : p.sara);
      final guestLink = PairedLink(transport: p.guest, identity: p.guest == p.a ? p.ali : p.sara);
      final host = hostLink.session(
        adapter: BoardKitTogetherAdapter(kit),
        firstPlayer: hostFirst,
        recorder: (r) async {
          hostRecords.add(r);
          return null;
        },
      );
      final guest = guestLink.session(
        adapter: BoardKitTogetherAdapter(kit),
        firstPlayer: PlayerSlot.one, // ignored: the host seats
        recorder: (r) async {
          guestRecords.add(r);
          return null;
        },
      );
      await host.start(seed: 11);
      await settle();
      return (host, guest, hostRecords, guestRecords);
    }

    Future<void> playOut(TogetherSession<GameState, GameMove> host, TogetherSession<GameState, GameMove> guest) async {
      final kit = boardGameKits[BoardGameId.connectFour]!;
      var guard = 0;
      while (host.phase == SessionPhase.playing && guard++ < 60) {
        final session = host.canPlay() ? host : guest;
        expect(session.canPlay(), isTrue);
        final legal = kit.rules.legalMoves(session.state);
        await session.play(legal[(guard * 3) % legal.length]);
        await settle();
        expect(guest.stateHash, host.stateHash);
      }
    }

    test('four in a row from the first move to the result, recorded on both phones', () async {
      final p = _Pair();
      await p.pair();
      final (host, guest, hostRecords, guestRecords) = await start(p, hostFirst: PlayerSlot.one);
      expect(guest.started, isTrue);
      expect(host.seats, [0, 1]);
      await playOut(host, guest);
      expect(host.phase, SessionPhase.finished);
      expect(guest.phase, SessionPhase.finished);
      expect(hostRecords.single.id, guestRecords.single.id);
      expect(hostRecords.single.mode, PlayMode.nearby);

      // Privacy: every byte that crossed the air belongs to a whitelisted
      // frame, and no player name ever travelled in one.
      final frames = _framesOnAir(p.air);
      final codec = TogetherCodec(policy: BoardKitTogetherAdapter.boardPolicy);
      expect(frames, isNotEmpty);
      for (final f in frames) {
        expect(() => codec.decode(f), returnsNormally);
        expect(f, isNot(contains('Ali')));
        expect(f, isNot(contains('Sara')));
      }
      final total = p.air.wire.fold<int>(0, (n, w) => n + w.$3.length);
      expect(total, frames.fold<int>(0, (n, f) => n + utf8.encode(f).length));
      host.dispose();
      guest.dispose();
      await settle();
      await p.dispose();
    });

    test('the guest\'s player can start: seats follow "who starts", not the host', () async {
      final p = _Pair();
      await p.pair();
      // Both phones keep their owner as player one; the host lets the other
      // player (its player two – the guest's owner) start.
      final (host, guest, hostRecords, guestRecords) = await start(p, hostFirst: PlayerSlot.two);
      expect(host.seats, [1, 0]);
      expect(guest.seats, [1, 0]);
      expect(guest.canPlay(), isTrue, reason: 'the guest moves first');
      expect(host.canPlay(), isFalse);
      await playOut(host, guest);
      expect(host.phase, SessionPhase.finished);
      final outcome = host.outcome!;
      if (outcome.isDraw) {
        expect(hostRecords.single.outcome, MatchOutcome.draw);
        expect(guestRecords.single.outcome, MatchOutcome.draw);
      } else {
        final guestWon = host.seats[outcome.winners.single] == 1;
        // Each phone records the result in its own profile slots.
        expect(hostRecords.single.outcome, guestWon ? MatchOutcome.twoWon : MatchOutcome.oneWon);
        expect(guestRecords.single.outcome, guestWon ? MatchOutcome.oneWon : MatchOutcome.twoWon);
      }
      host.dispose();
      guest.dispose();
      await settle();
      await p.dispose();
    });

    test('the link drops mid-game: the phones find each other again without a second confirmation', () async {
      final p = _Pair(grace: const Duration(seconds: 5));
      await p.pair();
      final roles = (p.a.role, p.b.role);
      final (host, guest, _, _) = await start(p, hostFirst: PlayerSlot.one);
      final kit = boardGameKits[BoardGameId.connectFour]!;
      await host.play(kit.rules.legalMoves(host.state).first);
      await settle();
      expect(guest.turn, 1);

      p.air.cut(p.phoneA, p.phoneB);
      await settle();
      // (The fake re-finds instantly; a real reconnection takes seconds.)
      expect(p.phoneA.calls.where((c) => c == 'startAdvertising').length, 2);
      expect(p.a.pairing.value.phase, PairingPhase.connected);
      expect(p.b.pairing.value.phase, PairingPhase.connected);
      expect((p.a.role, p.b.role), roles);
      expect(p.phoneA.advertising, isFalse, reason: 'radios off again once reconnected');

      await guest.play(kit.rules.legalMoves(guest.state).first);
      await settle();
      expect(host.turn, 2);
      expect(host.stateHash, guest.stateHash);
      host.dispose();
      guest.dispose();
      await settle();
      await p.dispose();
    });

    test('moves made while out of range arrive after the reconnection', () async {
      final p = _Pair(grace: const Duration(seconds: 5));
      await p.pair();
      final (host, guest, _, _) = await start(p, hostFirst: PlayerSlot.one);
      final kit = boardGameKits[BoardGameId.connectFour]!;
      p.air.goOutOfRange();
      await settle();
      expect(p.a.pairing.value.phase, PairingPhase.reconnecting);
      expect(p.b.pairing.value.phase, PairingPhase.reconnecting);
      expect(host.canPlay(), isTrue);
      await host.play(kit.rules.legalMoves(host.state).first);
      await settle();
      expect(guest.turn, 0);
      p.air.comeBackIntoRange();
      await settle(60);
      expect(p.a.status.value, TransportStatus.connected);
      expect(p.b.status.value, TransportStatus.connected);
      expect(guest.turn, 1);
      expect(guest.stateHash, host.stateHash);
      host.dispose();
      guest.dispose();
      await settle();
      await p.dispose();
    });

    test('no partner within the grace period: lost, radios off; "search again" looks once more', () async {
      final p = _Pair(grace: const Duration(milliseconds: 60));
      await p.pair();
      await p.b.close(); // the partner walked away with the app closed
      await settle();
      expect(p.a.pairing.value.phase, PairingPhase.reconnecting);
      expect(p.phoneA.advertising, isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 120));
      await settle();
      expect(p.a.pairing.value.phase, PairingPhase.lost);
      expect(p.phoneA.advertising, isFalse);
      expect(p.phoneA.discovering, isFalse);
      expect(p.a.status.value, TransportStatus.disconnected);
      await p.a.searchAgain();
      await settle();
      expect(p.a.pairing.value.phase, PairingPhase.reconnecting);
      expect(p.phoneA.advertising, isTrue);
      await p.a.close();
    });

    test('duplicated and out-of-order frames: the sessions stay in step', () async {
      final p = _Pair();
      await p.pair();
      final (host, guest, _, _) = await start(p, hostFirst: PlayerSlot.one);
      final kit = boardGameKits[BoardGameId.connectFour]!;
      p.air.duplicateNext = 6;
      await host.play(kit.rules.legalMoves(host.state).first);
      await settle();
      await guest.play(kit.rules.legalMoves(guest.state).first);
      await settle();
      expect(host.stateHash, guest.stateHash);
      // Hold the host's next frames and deliver them backwards.
      final hostPhone = p.host == p.a ? p.phoneA : p.phoneB;
      p.air.hold(hostPhone);
      await host.play(kit.rules.legalMoves(host.state).first);
      host.resync();
      await settle();
      p.air.release(hostPhone, reverse: true);
      await settle(60);
      expect(guest.turn, host.turn);
      expect(guest.stateHash, host.stateHash);
      host.dispose();
      guest.dispose();
      await settle();
      await p.dispose();
    });

    test('leaving: the partner\'s session hears the bye', () async {
      final p = _Pair();
      await p.pair();
      final (host, guest, _, _) = await start(p, hostFirst: PlayerSlot.one);
      final events = <SessionEvent>[];
      guest.events.listen(events.add);
      await host.leave();
      host.dispose();
      await settle();
      expect(events.whereType<PeerLeft>(), hasLength(1));
      expect(guest.phase, SessionPhase.abandoned);
      guest.dispose();
      await settle();
      await p.dispose();
    });
  });

  group('frame chunks', () {
    test('split / reassemble round trips, an exact multiple ends with a space', () {
      for (final size in [1, 99, 100, 101, 250, 300, 1000]) {
        final text = '{"p":"${'é' * (size ~/ 2)}${'a' * (size % 2)}"}';
        final chunks = FrameChunks.ofText(text, 100);
        expect(chunks.every((c) => c.isNotEmpty && c.length <= 100), isTrue);
        final r = FrameReassembler(chunkSize: 100);
        String? out;
        for (final c in chunks) {
          out = r.add(c);
        }
        expect(out, text);
        expect(r.pending, 0);
      }
      final exact = FrameChunks.split(List.filled(200, 0x61), 100);
      expect(exact.map((c) => c.length), [100, 100, 1]);
      expect(exact.last, [0x20]);
    });

    test('garbage is dropped: over-long frames, broken UTF-8, oversized payloads', () {
      final r = FrameReassembler(chunkSize: 10, maxFrameBytes: 25);
      expect(r.add(Uint8List(10)), isNull);
      expect(r.add(Uint8List(10)), isNull);
      expect(r.add(Uint8List(10)), isNull, reason: 'over the frame limit');
      expect(r.pending, 0);
      expect(r.add(Uint8List.fromList([0xC3])), isNull, reason: 'not UTF-8');
      expect(r.add(Uint8List(11)), isNull, reason: 'larger than a payload');
      expect(r.add(Uint8List.fromList(utf8.encode('{}'))), '{}');
    });

    test('four digits from any token, the same on both phones', () {
      expect(NearbyAuthDigits.of('4827'), '4827');
      final d = NearbyAuthDigits.of('A1B2C');
      expect(d, matches(RegExp(r'^[0-9]{4}$')));
      expect(NearbyAuthDigits.of('A1B2C'), d);
      expect(NearbyAuthDigits.of('A1B2D'), isNot(d));
    });
  });
}

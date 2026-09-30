// Adversarial review of Together Mode (protocol, whitelist, records): every
// test here reproduced a defect before its fix.
import 'dart:convert';
import 'dart:math' as math;

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/core/db/database.dart';
import 'package:madar/core/providers.dart';
import 'package:madar/features/cinema/rules/board/board_games.dart' show boardGameKits, boardVariantKits;
import 'package:madar/features/cinema/rules/board/core/game_types.dart' show BoardGameId, GameMove, GameState;
import 'package:madar/features/cinema/rules/cards/core/card_game.dart' show CardGameId;
import 'package:madar/features/home/home_providers.dart' show appForegroundProvider;
import 'package:madar/features/together/together.dart';

import 'together_test_utils.dart';

void main() {
  const raceCodec = TogetherCodec(policy: GameDataPolicy(allowedKeys: RaceGame.keys));

  /// [body] as a frame the guest (participant 1) sends – written by hand:
  /// the codec itself refuses to encode a host-only kind from the guest.
  String fromGuest(String sessionId, int seq, TogetherBody body) {
    final json = jsonDecode(raceCodec.encode(TogetherEnvelope(sessionId: sessionId, from: 0, seq: seq, body: body)).text);
    return jsonEncode({...json as Map<String, Object?>, 'from': 1});
  }

  group('protocol', () {
    test('every board game kit – chess and draughts included – can be played through a session', () async {
      // Chess and draughts keep their Zobrist repetition keys as hex strings;
      // negative 64-bit keys ("-1f…") were refused as personal text, so the
      // session threw after a few moves and the games could not be played.
      final failures = <String>[];
      for (final e in boardVariantKits.entries) {
        final kit = e.value;
        final s = TogetherSession<GameState, GameMove>.local(
          adapter: BoardKitTogetherAdapter(kit),
          random: math.Random(1),
        );
        try {
          await s.start(seed: 5);
          final rng = math.Random(3);
          var n = 0;
          while (s.phase == SessionPhase.playing && n++ < 160) {
            final legal = kit.rules.legalMoves(s.state);
            await s.play(legal[rng.nextInt(legal.length)]);
          }
        } on Object catch (err) {
          failures.add('${e.key.name} after ${s.turn} moves: $err');
        } finally {
          s.dispose();
        }
      }
      expect(failures, isEmpty);
    });

    test('chess over the loopback link stays in sync move after move', () async {
      final kit = boardGameKits[BoardGameId.chess]!;
      final link = LoopbackLink();
      final host = TogetherSession<GameState, GameMove>(adapter: BoardKitTogetherAdapter(kit), transport: link.host);
      final guest = TogetherSession<GameState, GameMove>(
        adapter: BoardKitTogetherAdapter(kit),
        transport: link.guest,
        role: SessionRole.guest,
      );
      addTearDown(host.dispose);
      addTearDown(guest.dispose);
      await host.start(seed: 21);
      await settle();
      final rng = math.Random(8);
      for (var i = 0; i < 40 && host.phase == SessionPhase.playing; i++) {
        final seat = host.seatToMove!;
        final session = seat == 0 ? host : guest;
        final legal = kit.rules.legalMoves(session.state);
        await session.play(legal[rng.nextInt(legal.length)]);
        await settle();
        expect(guest.stateHash, host.stateHash, reason: 'move $i');
      }
      expect(host.rejectedFrames + guest.rejectedFrames, 0);
    });

    test('determinism: every card game and board kit stays in sync over the loopback link', () async {
      Future<String?> playOver<S, M>(TogetherGameAdapter<S, M> adapter, List<M> Function(S state, int seat) legal, int cap) async {
        final link = LoopbackLink();
        final host = TogetherSession<S, M>(adapter: adapter, transport: link.host, random: math.Random(2));
        final guest = TogetherSession<S, M>(adapter: adapter, transport: link.guest, role: SessionRole.guest);
        try {
          await host.start(seed: 1234567);
          await settle();
          final rng = math.Random(5);
          for (var i = 0; i < cap && host.phase == SessionPhase.playing; i++) {
            final seat = host.seatToMove!;
            // Rivals seating: seat 1 is the guest's; seat 0 and AI seats the host's.
            final session = seat == 1 ? guest : host;
            final moves = legal(session.state, seat);
            await session.play(moves[rng.nextInt(moves.length)], seat: seat);
            await settle(8);
            if (guest.stateHash != host.stateHash) return 'diverged at move $i';
          }
          if (host.rejectedFrames + guest.rejectedFrames > 0) return 'frames rejected';
          return null;
        } on Object catch (e) {
          return 'threw after ${host.turn}: $e';
        } finally {
          host.dispose();
          guest.dispose();
        }
      }

      final failures = <String>[];
      for (final id in CardGameId.values) {
        final error = await playOver(CardEngineTogetherAdapter(id), (s, seat) => s.legalMoves(seat), 300);
        if (error != null) failures.add('${id.name}: $error');
      }
      for (final e in boardVariantKits.entries) {
        final error = await playOver(BoardKitTogetherAdapter(e.value), (s, _) => e.value.rules.legalMoves(s), 120);
        if (error != null) failures.add('${e.key.name}: $error');
      }
      expect(failures, isEmpty);
    });

    test('a guest cannot declare the result – only the host does', () async {
      final pair = SessionPair();
      addTearDown(pair.dispose);
      await pair.host.start(seed: 0);
      await settle();
      await pair.host.play(1);
      await settle();
      // The guest's app claims victory in the middle of the game.
      final result = ResultBody(matchId: pair.host.sessionId, outcome: SeatOutcomeKind.win, winners: const [1]);
      expect(
        () => raceCodec.encode(TogetherEnvelope(sessionId: pair.host.sessionId, from: 1, seq: 1, body: result)),
        throwsA(isA<TogetherDataRejected>()),
      );
      pair.link.host.injectIncoming(fromGuest(pair.host.sessionId, 1, result));
      await settle();
      expect(pair.host.phase, SessionPhase.playing);
      expect(pair.hostRecords, isEmpty);
      expect(pair.host.rejectedFrames, 1);
      // The guest's real move (its first sequenced frame, seq 1) still counts.
      await pair.guest.play(1);
      await settle();
      expect(pair.host.turn, 2);
      expect(pair.host.stateHash, pair.guest.stateHash);
    });

    test('host-only messages from the guest cannot jam the ordering', () async {
      final pair = SessionPair();
      addTearDown(pair.dispose);
      await pair.host.start(seed: 0);
      await settle();
      await pair.host.play(1);
      await settle();
      // A "snapshot" from the guest with a huge sequence number: a reset
      // kind, so it used to move the host's ordering past every real frame.
      final state = GameData(
        const RaceGame().encodeState(pair.host.state),
        policy: const GameDataPolicy(allowedKeys: RaceGame.keys),
      );
      pair.link.host.injectIncoming(
        fromGuest(pair.host.sessionId, 1 << 40, SnapshotBody(turn: 99, state: state, hash: state.hash)),
      );
      await settle();
      await pair.guest.play(2);
      await settle();
      expect(pair.host.turn, 2, reason: 'the guest move must still be applied');
      expect(pair.host.rejectedFrames, 1);
    });

    test('a peer on a newer protocol version is recognised even when its envelope has new fields', () async {
      final pair = SessionPair();
      addTearDown(pair.dispose);
      await pair.host.start(seed: 1);
      await settle();
      pair.link.host.injectIncoming(
        jsonEncode({
          'p': 'madar.together',
          'v': 2,
          'sid': pair.host.sessionId,
          'k': 'move2',
          'seq': 1,
          'ack': 0,
          'from': 1,
          'b': <String, Object?>{},
          'sig': 'abc',
        }),
      );
      await settle();
      expect(pair.host.phase, SessionPhase.failed);
      expect(pair.host.failure, 'incompatibleProtocol');
    });

    test('a phone or account number cannot hide in a key name', () {
      for (final key in ['_0795551234', 'tel0795551234', 'x962795551234']) {
        expect(
          () => GameData({key: 1}),
          throwsA(isA<TogetherDataRejected>().having((e) => e.reason, 'reason', TogetherRejection.personalText)),
          reason: key,
        );
      }
      // Ordinary game keys with a few digits still pass.
      expect(GameData({'p1': 1, 'row7': 2, 'x2024': 3}).map, hasLength(3));
    });
  });

  group('records', () {
    test('a profile built directly (not through copyWith) is still stored bounded', () async {
      final db = MadarDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = TogetherRepository(db);
      await repo.saveProfile(
        TogetherProfile(
          slot: PlayerSlot.one,
          name: 'N' * 20000,
          avatar: TogetherAvatar.emoji('🦁' * 5000),
          colorIndex: 1 << 40,
          customTitle: 'T' * 20000,
        ),
      );
      final row = await (db.select(db.keyValues)..where((t) => t.key.equals(TogetherRepository.profilesKey))).getSingle();
      expect(utf8.encode(row.value).length, lessThan(1024));
      final back = await repo.profiles();
      expect(back.one.name.runes.length, TogetherBounds.maxNameLength);
      expect(back.one.customTitle.runes.length, TogetherBounds.maxTitleLength);
    });

    test('a streak is still alive after the clock moves back past midnight (travelling west of Amman)', () {
      // Played at 00:30 on 1 October (Amman), then the phone's zone moves
      // three hours west: "now" reads 22:30 on 30 September.
      final ledger = TogetherLedger.empty
          .apply(MatchRecord(id: 'a', gameId: 'chess', endedAt: DateTime(2026, 9, 29, 21), outcome: MatchOutcome.oneWon))
          .apply(MatchRecord(id: 'b', gameId: 'chess', endedAt: DateTime(2026, 9, 30, 21), outcome: MatchOutcome.oneWon))
          .apply(MatchRecord(id: 'c', gameId: 'chess', endedAt: DateTime(2026, 10, 1, 0, 30), outcome: MatchOutcome.twoWon));
      expect(ledger.dayStreak, 3);
      final now = DateTime(2026, 9, 30, 22, 30);
      expect(ledger.currentDayStreak(now), 3);
      expect(ledger.playedToday(now), isTrue);
      // Two days later it has lapsed.
      expect(ledger.currentDayStreak(DateTime(2026, 10, 3, 9)), 0);
    });

    test('"now" of the Together overview is refreshed when the app comes back', () async {
      final db = MadarDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      var now = DateTime(2026, 9, 30, 21);
      final foreground = ValueNotifier(true);
      addTearDown(foreground.dispose);
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          togetherClockProvider.overrideWithValue(() => now),
          appForegroundProvider.overrideWithValue(foreground),
        ],
      );
      addTearDown(container.dispose);
      await TogetherRepository(db).recordMatch(
        MatchRecord(id: 'm1', gameId: 'chess', endedAt: DateTime(2026, 9, 30, 20), outcome: MatchOutcome.oneWon),
      );
      final sub = container.listen(togetherOverviewProvider, (_, _) {});
      addTearDown(sub.close);
      Future<TogetherOverview> read() async {
        for (var i = 0; i < 50; i++) {
          final v = container.read(togetherOverviewProvider);
          if (v.hasValue && v.requireValue.hasMatches) return v.requireValue;
          await pumpEventQueue();
        }
        fail('the overview never loaded');
      }

      expect((await read()).dayStreak, 1);
      // The phone sleeps through two nights; nothing is recorded meanwhile.
      foreground.value = false;
      now = DateTime(2026, 10, 2, 22);
      foreground.value = true;
      await pumpEventQueue();
      final later = await read();
      expect(later.now, now);
      expect(later.dayStreak, 0, reason: 'the streak lapsed – the home must not show a stale one');
    });
  });
}

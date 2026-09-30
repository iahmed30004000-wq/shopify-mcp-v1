import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/cinema/rules/board/board_games.dart' show boardVariantKits;
import 'package:madar/features/cinema/rules/cards/core/card_game.dart' show CardGameId;
import 'package:madar/features/together/together.dart';

import 'together_test_utils.dart';

void main() {
  test('probe: every board kit through a local session', () async {
    final failures = <String>[];
    for (final e in boardVariantKits.entries) {
      final kit = e.value;
      final s = TogetherSession.local(adapter: BoardKitTogetherAdapter(kit), random: math.Random(1));
      try {
        await s.start(seed: 5);
        final rng = math.Random(3);
        var n = 0;
        while (s.phase == SessionPhase.playing && n++ < 600) {
          final legal = kit.rules.legalMoves(s.state);
          await s.play(legal[rng.nextInt(legal.length)]);
        }
        failures.add('${e.key.name}: ok after $n moves, phase ${s.phase.name}, bytes ${utf8.encode(jsonEncode(s.adapter.encodeState(s.state))).length}');
      } on Object catch (err) {
        failures.add('${e.key.name}: FAIL $err after ${s.turn}');
      } finally {
        s.dispose();
      }
    }
    // ignore: avoid_print
    print(failures.join('\n'));
  });

  test('probe: every card game through a local session', () async {
    final out = <String>[];
    for (final id in CardGameId.values) {
      final adapter = CardEngineTogetherAdapter(id);
      final s = TogetherSession.local(adapter: adapter, seats: TogetherSeats.rivals(adapter.seatCount));
      try {
        await s.start(seed: 9);
        final rng = math.Random(4);
        var n = 0;
        while (s.phase == SessionPhase.playing && n++ < 4000) {
          final seat = s.seatToMove!;
          final legal = s.state.legalMoves(seat);
          await s.play(legal[rng.nextInt(legal.length)]);
        }
        out.add('${id.name}: ok after $n, phase ${s.phase.name}, bytes ${utf8.encode(jsonEncode(adapter.encodeState(s.state))).length}');
      } on Object catch (err) {
        out.add('${id.name}: FAIL $err after ${s.turn}');
      } finally {
        s.dispose();
      }
    }
    // ignore: avoid_print
    print(out.join('\n'));
  });

  test('probe: corrupt timestamps', () {
    for (final f in [
      () => MatchRecord.fromJson({'i': 'a', 'g': 'chess', 't': 9000000000000000, 'o': 'draw'}),
      () => TogetherLedger.fromJson({'f': 9000000000000000}),
      () => GameTally.fromJson({'t': -9000000000000000}),
      () => EarnedTrophy.fromJson({'id': 'firstMatch', 't': 9000000000000000}),
      () => TogetherBounds.count(1e300),
      () => TogetherBounds.score(1e300),
    ]) {
      try {
        // ignore: avoid_print
        print('ok ${f()}');
      } on Object catch (e) {
        // ignore: avoid_print
        print('THROWS $e');
      }
    }
  });

  test('probe: duplicate start / version', () async {
    final pair = SessionPair();
    addTearDown(pair.dispose);
    final events = <SessionEvent>[];
    pair.guest.events.listen(events.add);
    await pair.host.start(seed: 1);
    await settle();
    await pair.host.play(1);
    await settle();
    await pair.guest.play(1);
    await settle();
    final hello = const TogetherCodec().encode(
      const TogetherEnvelope(sessionId: 'guestguest', from: 1, body: HelloBody(gameId: 'race', gameVersion: 1)),
    );
    final turns = <int>[];
    pair.guest.addListener(() => turns.add(pair.guest.turn));
    pair.link.host.injectIncoming(hello.text);
    await settle();
    // ignore: avoid_print
    print('starts ${events.whereType<SessionStarted>().length} turns $turns final ${pair.guest.turn}');
    final v2 = jsonEncode({
      'p': 'madar.together',
      'v': 2,
      'sid': pair.host.sessionId,
      'k': 'bye',
      'seq': 0,
      'ack': 0,
      'from': 1,
      'b': <String, Object?>{},
    });
    pair.link.host.injectIncoming(v2);
    await settle();
    // ignore: avoid_print
    print('host phase after v2 ${pair.host.phase} rejected ${pair.host.rejectedFrames}');
  });
}

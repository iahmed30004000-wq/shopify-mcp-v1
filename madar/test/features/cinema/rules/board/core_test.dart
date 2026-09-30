import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/cinema/rules/board/board_games.dart';

import 'board_test_utils.dart';

void main() {
  group('BoardRng', () {
    test('is deterministic and resumable from its state', () {
      final a = BoardRng(42), b = BoardRng(42);
      final seqA = [for (var i = 0; i < 50; i++) a.nextUint32()];
      expect([for (var i = 0; i < 50; i++) b.nextUint32()], seqA);
      final c = BoardRng(42);
      for (var i = 0; i < 20; i++) {
        c.nextUint32();
      }
      final resumed = BoardRng.fromState(c.state);
      expect([for (var i = 0; i < 30; i++) resumed.nextUint32()], seqA.sublist(20));
      expect(BoardRng.fromJson(roundTrip(c.toJson())).nextUint32(), c.copy().nextUint32());
      expect(BoardRng(1).nextUint32(), isNot(BoardRng(2).nextUint32()));
      expect(BoardRng(-5).nextUint32(), BoardRng(-5).nextUint32());
    });

    test('dice are fair enough and in range', () {
      final rng = BoardRng(7);
      final counts = List.filled(7, 0);
      for (var i = 0; i < 60000; i++) {
        counts[rng.rollDie()]++;
      }
      expect(counts[0], 0);
      for (var f = 1; f <= 6; f++) {
        expect(counts[f], inInclusiveRange(9500, 10500));
      }
      for (var i = 0; i < 1000; i++) {
        final d = rng.nextDouble();
        expect(d, inInclusiveRange(0.0, 1.0));
        expect(d, lessThan(1.0));
        expect(rng.nextInt(3), inInclusiveRange(0, 2));
      }
      expect(() => rng.nextInt(0), throwsRangeError);
    });

    test('shuffle is a permutation and depends on the seed', () {
      final a = List.generate(28, (i) => i), b = List.generate(28, (i) => i);
      BoardRng(1).shuffle(a);
      BoardRng(2).shuffle(b);
      expect(a.toSet().length, 28);
      expect(a, isNot(b));
    });
  });

  group('engine', () {
    test('rejects illegal moves, knows whose turn it is, undoes', () {
      final e = boardGameKits[BoardGameId.ticTacToe]!.engine();
      expect(e.legalMoves(0), hasLength(9));
      expect(e.legalMoves(1), isEmpty);
      e.apply(const TicTacToeMove(4));
      expect(() => e.apply(const TicTacToeMove(4)), throwsA(isA<IllegalMoveException>()));
      expect(e.currentPlayer, 1);
      expect(e.undo(), const TicTacToeMove(4));
      expect(e.canUndo, isFalse);
      expect(() => e.undo(), throwsStateError);
    });

    test('refuses to restore another game', () {
      final chess = boardGameKits[BoardGameId.chess]!.engine();
      expect(() => boardGameKits[BoardGameId.checkers]!.engineFromJson(chess.toJson()), throwsFormatException);
    });

    test('no moves after the end', () {
      final e = boardGameKits[BoardGameId.ticTacToe]!.engine();
      for (final c in [0, 3, 1, 4, 2]) {
        e.apply(TicTacToeMove(c));
      }
      expect(e.isOver, isTrue);
      expect(e.legalMoves(), isEmpty);
      expect(() => e.apply(const TicTacToeMove(8)), throwsA(isA<IllegalMoveException>()));
    });
  });

  test('AI runs on a background isolate with the same answer', () async {
    final kit = boardGameKits[BoardGameId.connectFour]!;
    final state = kit.engine().state;
    final rng = BoardRng(3);
    final direct = kit.ai.chooseMove(state, AiLevel.hard, rng.copy(), const AiBudget.nodes(5000));
    final background = await chooseMoveInBackground(kit.ai, state, AiLevel.hard, rng, const AiBudget.nodes(5000));
    expect(background, direct);
  });

  test('value types round-trip', () {
    const r = GameResult(winners: [1], reason: GameEndReason.checkmate, scores: [0, 1], ranking: [1, 0]);
    expect(GameResult.fromJson(roundTrip(r.toJson())), r);
    const b = AiBudget(maxTime: Duration(milliseconds: 150), maxNodes: 99);
    final back = AiBudget.fromJson(roundTrip(b.toJson()));
    expect(back.maxTime, b.maxTime);
    expect(back.maxNodes, 99);
  });

  test('every kit is registered with sane player ranges', () {
    expect(boardGameKits.keys.toSet(), BoardGameId.values.toSet());
    for (final kit in boardGameKits.values) {
      expect(kit.minPlayers, greaterThanOrEqualTo(2));
      expect(kit.maxPlayers, greaterThanOrEqualTo(kit.minPlayers));
      final e = kit.engine(players: kit.maxPlayers, seed: 1);
      expect(e.state.playerCount, kit.maxPlayers);
      expect(e.isOver, isFalse);
    }
  });
}

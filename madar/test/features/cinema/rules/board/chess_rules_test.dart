import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/cinema/rules/board/chess/chess_ai.dart';
import 'package:madar/features/cinema/rules/board/chess/chess_rules.dart';
import 'package:madar/features/cinema/rules/board/core/engine.dart';
import 'package:madar/features/cinema/rules/board/core/game_types.dart';
import 'package:madar/features/cinema/rules/board/core/rng.dart';

void main() {
  const rules = chessRules;

  ChessState play(ChessState s, List<String> sans) {
    for (final san in sans) {
      s = rules.apply(s, rules.fromSan(s, san));
    }
    return s;
  }

  group('basics', () {
    test('initial position has 20 moves and round-trips FEN', () {
      final s = ChessState.initial();
      expect(rules.legalMoves(s), hasLength(20));
      expect(s.fen, kStartFen);
      expect(s.currentPlayer, 0);
      expect(s.pieceAt(parseSquare('e1')), const ChessPiece(0, ChessPieceType.king));
      expect(s.pieceAt(parseSquare('d8')), const ChessPiece(1, ChessPieceType.queen));
      expect(s.pieceAt(parseSquare('e4')), isNull);
    });

    test('FEN import/export round trip', () {
      for (final fen in [
        'r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1',
        '8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0 1',
        'rnbqkbnr/ppp1pppp/8/3pP3/8/8/PPPP1PPP/RNBQKBNR w KQkq d6 0 3',
        'r4rk1/1pp1qppp/p1np1n2/2b1p1B1/2B1P1b1/P1NP1N2/1PP1QPPP/R4RK1 w - - 0 10',
      ]) {
        expect(ChessState.fromFen(fen).fen, fen);
      }
    });

    test('malformed FEN is rejected', () {
      expect(() => ChessState.fromFen('8/8/8/8/8/8/8/8 w - - 0 1'), throwsFormatException);
      expect(() => ChessState.fromFen('rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP w KQkq - 0 1'), throwsFormatException);
      expect(() => ChessState.fromFen('4k3/8/8/8/8/8/8/4K2R x - - 0 1'), throwsFormatException);
      // side not to move in check
      expect(() => ChessState.fromFen('4k3/8/8/8/8/8/8/4K2Q w - - 0 1'), returnsNormally);
      expect(() => ChessState.fromFen('4k3/8/8/8/8/8/8/4R1K1 w - - 0 1'), throwsFormatException);
    });

    test('en-passant square is normalised when no capture is possible', () {
      final s = ChessState.fromFen('rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1');
      expect(s.fen, 'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1');
      final after = play(ChessState.initial(), ['e4']);
      expect(after.epSquare, -1);
    });
  });

  group('special moves', () {
    test('en passant capture removes the passed pawn', () {
      var s = play(ChessState.initial(), ['e4', 'a6', 'e5', 'd5']);
      expect(s.epSquare, parseSquare('d6'));
      final ep = rules.fromSan(s, 'exd6');
      expect(ep, ChessMove(parseSquare('e5'), parseSquare('d6')));
      s = rules.apply(s, ep);
      expect(s.pieceAt(parseSquare('d5')), isNull);
      expect(s.pieceAt(parseSquare('d6')), const ChessPiece(0, ChessPieceType.pawn));
      expect(s.halfmoveClock, 0);
    });

    test('en passant expires after one move', () {
      final s = play(ChessState.initial(), ['e4', 'a6', 'e5', 'd5', 'h3', 'h6']);
      expect(rules.legalMoves(s).where((m) => m.uci == 'e5d6'), isEmpty);
    });

    test('castling both sides and loss of rights', () {
      final s = ChessState.fromFen('r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1');
      final moves = rules.legalMoves(s).map((m) => m.uci).toSet();
      expect(moves, containsAll(['e1g1', 'e1c1']));
      expect(rules.toSan(s, ChessMove.fromUci('e1g1')), 'O-O');
      expect(rules.toSan(s, ChessMove.fromUci('e1c1')), 'O-O-O');
      final castled = rules.apply(s, ChessMove.fromUci('e1g1'));
      expect(castled.pieceAt(parseSquare('f1')), const ChessPiece(0, ChessPieceType.rook));
      expect(castled.pieceAt(parseSquare('h1')), isNull);
      expect(castled.fen.split(' ')[2], 'kq');
      // Rook move drops only that side.
      final rookMoved = rules.apply(s, ChessMove.fromUci('a1a2'));
      expect(rookMoved.fen.split(' ')[2], 'Kkq');
      // Capturing a rook on its home square removes the victim's right.
      final capture = rules.apply(
        ChessState.fromFen('r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1'),
        ChessMove.fromUci('a1a8'),
      );
      expect(capture.fen.split(' ')[2], 'Kk');
    });

    test('cannot castle out of, through or into check', () {
      // Bishop on c4 attacks f1 (through), rook on e8 gives check.
      expect(
        rules.legalMoves(ChessState.fromFen('4k3/8/8/8/2b5/8/8/4K2R w K - 0 1')).map((m) => m.uci),
        isNot(contains('e1g1')),
      );
      expect(
        rules.legalMoves(ChessState.fromFen('4r1k1/8/8/8/8/8/8/4K2R w K - 0 1')).map((m) => m.uci),
        isNot(contains('e1g1')),
      );
      expect(
        rules.legalMoves(ChessState.fromFen('6rk/7p/8/8/8/8/8/4K2R w K - 0 1')).map((m) => m.uci),
        isNot(contains('e1g1')),
      );
      // Queen-side: b1 may be attacked, c1/d1 may not.
      expect(
        rules.legalMoves(ChessState.fromFen('1r2k3/8/8/8/8/8/8/R3K3 w Q - 0 1')).map((m) => m.uci),
        contains('e1c1'),
      );
      expect(
        rules.legalMoves(ChessState.fromFen('2r1k3/8/8/8/8/8/8/R3K3 w Q - 0 1')).map((m) => m.uci),
        isNot(contains('e1c1')),
      );
    });

    test('promotion offers four pieces and SAN shows =Q+', () {
      final s = ChessState.fromFen('8/P7/8/8/8/8/8/k6K w - - 0 1');
      final promos = rules.legalMoves(s).where((m) => m.from == parseSquare('a7')).toList();
      expect(promos.map((m) => m.promotion).toSet(), {
        ChessPieceType.queen,
        ChessPieceType.rook,
        ChessPieceType.bishop,
        ChessPieceType.knight,
      });
      expect(rules.toSan(s, ChessMove.fromUci('a7a8q')), 'a8=Q+');
      expect(rules.toSan(s, ChessMove.fromUci('a7a8n')), 'a8=N');
      expect(rules.fromSan(s, 'a8Q'), ChessMove.fromUci('a7a8q'));
      final after = rules.apply(s, ChessMove.fromUci('a7a8r'));
      expect(after.pieceAt(parseSquare('a8')), const ChessPiece(0, ChessPieceType.rook));
    });

    test('pinned piece cannot move', () {
      final s = ChessState.fromFen('4r1k1/8/8/8/8/8/4N3/4K3 w - - 0 1');
      expect(rules.legalMoves(s).where((m) => m.from == parseSquare('e2')), isEmpty);
    });
  });

  group('notation', () {
    test('SAN disambiguation by file, rank and square', () {
      final byFile = ChessState.fromFen('4k3/8/8/8/8/8/8/1N2KN2 w - - 0 1');
      expect(rules.toSan(byFile, ChessMove.fromUci('b1d2')), 'Nbd2');
      expect(rules.toSan(byFile, ChessMove.fromUci('f1d2')), 'Nfd2');
      final byRank = ChessState.fromFen('4k3/8/8/6N1/8/8/8/4K1N1 w - - 0 1');
      expect(rules.toSan(byRank, ChessMove.fromUci('g1f3')), 'N1f3');
      expect(rules.toSan(byRank, ChessMove.fromUci('g5f3')), 'N5f3');
      final bySquare = ChessState.fromFen('1k6/8/8/8/4Q2Q/8/8/K6Q w - - 0 1');
      expect(rules.toSan(bySquare, ChessMove.fromUci('h4e1')), 'Qh4e1');
    });

    test('SAN parser accepts common spellings', () {
      final s = ChessState.fromFen('r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1');
      expect(rules.fromSan(s, '0-0'), ChessMove.fromUci('e1g1'));
      expect(rules.fromSan(s, 'O-O-O'), ChessMove.fromUci('e1c1'));
      expect(rules.fromSan(s, 'Rxa8+'), ChessMove.fromUci('a1a8'));
      expect(rules.fromSan(s, 'e1f1'), ChessMove.fromUci('e1f1'));
      expect(() => rules.fromSan(s, 'Qd4'), throwsFormatException);
    });

    test('SAN line of a short game', () {
      final moves = ['e2e4', 'e7e5', 'g1f3', 'b8c6', 'f1b5', 'a7a6', 'b5c6', 'd7c6', 'e1g1'];
      expect(rules.toSanLine(ChessState.initial(), moves.map(ChessMove.fromUci)), [
        'e4',
        'e5',
        'Nf3',
        'Nc6',
        'Bb5',
        'a6',
        'Bxc6',
        'dxc6',
        'O-O',
      ]);
    });
  });

  group('game end', () {
    test("fool's mate is checkmate for black", () {
      final s = play(ChessState.initial(), ['f3', 'e5', 'g4']);
      expect(rules.toSan(s, rules.fromSan(s, 'Qh4')), 'Qh4#');
      final end = play(s, ['Qh4#']);
      expect(end.result, const GameResult(winners: [1], reason: GameEndReason.checkmate));
      expect(end.inCheck, isTrue);
      expect(rules.legalMoves(end), isEmpty);
    });

    test('stalemate', () {
      final s = ChessState.fromFen('7k/5Q2/6K1/8/8/8/8/8 b - - 0 1');
      expect(s.result?.reason, GameEndReason.stalemate);
      expect(s.result?.isDraw, isTrue);
    });

    test('insufficient material', () {
      for (final fen in [
        '8/8/8/4k3/8/8/8/4K3 w - - 0 1',
        '8/8/8/4k3/8/8/8/2B1K3 w - - 0 1',
        '8/8/8/4k3/8/8/8/1N2K3 w - - 0 1',
        '8/8/8/2b1k3/8/8/8/2B1K3 w - - 0 1', // c5 and c1 are both dark
      ]) {
        expect(ChessState.fromFen(fen).result?.reason, GameEndReason.insufficientMaterial, reason: fen);
      }
      for (final fen in [
        '8/8/8/4k3/8/8/8/1NN1K3 w - - 0 1',
        '8/8/8/3bk3/8/8/8/2B1K3 w - - 0 1', // opposite colours
        '8/8/8/4k3/8/8/4P3/4K3 w - - 0 1',
      ]) {
        expect(ChessState.fromFen(fen).result, isNull, reason: fen);
      }
    });

    test('threefold repetition', () {
      final s = play(ChessState.initial(), ['Nf3', 'Nf6', 'Ng1', 'Ng8', 'Nf3', 'Nf6', 'Ng1']);
      expect(s.result, isNull);
      final end = play(s, ['Ng8']);
      expect(end.result?.reason, GameEndReason.threefoldRepetition);
    });

    test('fifty-move rule', () {
      final s = ChessState.fromFen('8/8/8/4k3/8/8/3R4/4K3 w - - 99 80');
      expect(s.result, isNull);
      final end = rules.apply(s, ChessMove.fromUci('d2c2'));
      expect(end.result?.reason, GameEndReason.fiftyMoveRule);
      // A capture on the 100th half-move resets the clock instead.
      final s2 = ChessState.fromFen('8/8/8/4k3/8/8/r2R4/4K3 w - - 99 80');
      expect(rules.apply(s2, ChessMove.fromUci('d2a2')).result, isNull);
    });

    test('checkmate on the 100th half-move beats the fifty-move rule', () {
      final s = ChessState.fromFen('7k/8/6K1/8/8/8/8/R7 w - - 99 80');
      final end = rules.apply(s, ChessMove.fromUci('a1a8'));
      expect(end.result?.reason, GameEndReason.checkmate);
    });
  });

  group('engine', () {
    test('engine validates, undoes and round-trips JSON', () {
      final e = BoardGameEngine(rules, ChessState.initial());
      expect(e.legalMoves(1), isEmpty);
      expect(() => e.apply(ChessMove.fromUci('e2e5')), throwsA(isA<IllegalMoveException>()));
      for (final uci in ['e2e4', 'c7c5', 'g1f3', 'd7d6', 'd2d4', 'c5d4']) {
        e.apply(ChessMove.fromUci(uci));
      }
      final json = jsonDecode(jsonEncode(e.toJson())) as Map<String, Object?>;
      final restored = BoardGameEngine.fromJson(rules, json);
      expect(restored.state.fen, e.state.fen);
      expect(restored.history, e.history);
      e.undo();
      expect(e.state.fen, 'rnbqkbnr/pp2pppp/3p4/2p5/3PP3/5N2/PPP2PPP/RNBQKB1R b KQkq - 0 3');
      final stateJson = jsonDecode(jsonEncode(restored.state.toJson())) as Map<String, Object?>;
      expect(ChessState.fromJson(stateJson).keys, restored.state.keys);
    });
  });

  group('ai', () {
    test('finds mate in one at every level above easy', () {
      final s = ChessState.fromFen('6k1/5ppp/8/8/8/8/5PPP/R5K1 w - - 0 1');
      for (final level in [AiLevel.medium, AiLevel.hard]) {
        final m = ChessAi().chooseMove(s, level, BoardRng(1), const AiBudget.nodes(20000));
        expect(m.uci, 'a1a8', reason: level.name);
      }
    });

    test('hard wins a hanging queen and avoids losing its own', () {
      final s = ChessState.fromFen('4k3/8/8/3q4/8/8/3R4/4K3 w - - 0 1');
      expect(ChessAi().chooseMove(s, AiLevel.hard, BoardRng(2), const AiBudget.nodes(20000)).uci, 'd2d5');
    });

    test('hard finds a mate in two', () {
      // Rook ladder: 1.Rb7 Kg8 2.Ra8# (no mate in one exists).
      final s = ChessState.fromFen('7k/8/8/8/8/8/R7/1R4K1 w - - 0 1');
      final m = ChessAi().chooseMove(s, AiLevel.hard, BoardRng(3), const AiBudget.nodes(200000));
      var next = rules.apply(s, m);
      final reply = ChessAi().chooseMove(next, AiLevel.hard, BoardRng(4), const AiBudget.nodes(50000));
      next = rules.apply(next, reply);
      final mate = ChessAi().chooseMove(next, AiLevel.hard, BoardRng(5), const AiBudget.nodes(50000));
      expect(rules.apply(next, mate).result?.reason, GameEndReason.checkmate);
    });

    test('respects a time budget', () {
      final sw = Stopwatch()..start();
      ChessAi().chooseMove(
        ChessState.fromFen('r4rk1/1pp1qppp/p1np1n2/2b1p1B1/2B1P1b1/P1NP1N2/1PP1QPPP/R4RK1 w - - 0 10'),
        AiLevel.hard,
        BoardRng(9),
        const AiBudget(maxTime: Duration(milliseconds: 150)),
      );
      expect(sw.elapsedMilliseconds, lessThan(1500)); // generous for JIT/CI
    });
  });
}

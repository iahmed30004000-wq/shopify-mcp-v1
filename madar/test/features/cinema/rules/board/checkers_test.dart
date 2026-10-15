import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/cinema/rules/board/board_games.dart';
import 'package:madar/features/cinema/rules/board/checkers/checkers_rules.dart'
    show CheckersGameEnd, CheckersMoveGen, CheckersVariant;

int sq(int row, int col) => row * 8 + col;

CheckersState board(Map<int, int> pieces, {int player = 0, CheckersConfig config = CheckersConfig.american}) {
  final b = List<int>.filled(64, 0);
  pieces.forEach((k, v) => b[k] = v);
  return CheckersState(config: config, board: b, currentPlayer: player);
}

const m0 = CheckersPiece.man0, k0 = CheckersPiece.king0, m1 = CheckersPiece.man1, k1 = CheckersPiece.king1;

void main() {
  const rules = checkersRules;

  group('defaults and presets', () {
    test('the Jordanian rules are the default', () {
      expect(CheckersState.initial().config, CheckersConfig.jordan);
      final kitState = boardGameKits[BoardGameId.checkers]!.newGame() as CheckersState;
      expect(kitState.config, CheckersConfig.jordan);
      expect(kitState.config.variant, CheckersVariant.jordan);
    });

    test('every variant maps to its own preset and back', () {
      final configs = {for (final v in CheckersVariant.values) v.config};
      expect(configs, hasLength(CheckersVariant.values.length));
      for (final v in CheckersVariant.values) {
        expect(v.config.variant, v);
      }
      expect(CheckersConfig.jordan.copyWith(noProgressLimit: 32).variant, isNull);
      expect(CheckersConfig.turkish, CheckersConfig.jordan.copyWith(kingsBeatLoneKing: false));
      expect(CheckersConfig.americanFlyingKings, CheckersConfig.american.copyWith(flyingKings: true));
    });

    test('the American presets keep their previous behaviour', () {
      for (final c in [CheckersConfig.american, CheckersConfig.americanFlyingKings]) {
        expect(c.onePieceEachDraw || c.kingsBeatLoneKing || c.kingBeatsLoneMan, isFalse);
        expect(c.noProgressLimit, 80);
      }
    });

    test('JSON without the adjudication keys loads them as false', () {
      final json = CheckersConfig.jordan.toJson()
        ..remove('onePieceEachDraw')
        ..remove('kingsBeatLoneKing')
        ..remove('kingBeatsLoneMan');
      final c = CheckersConfig.fromJson(json);
      expect(c.onePieceEachDraw || c.kingsBeatLoneKing || c.kingBeatsLoneMan, isFalse);
      expect(c.geometry, CheckersGeometry.orthogonal);
      final state = CheckersState.initial(CheckersConfig.american).toJson();
      (state['config']! as Map<String, Object?>).remove('kingBeatsLoneMan');
      expect(CheckersState.fromJson(state).config, CheckersConfig.american);
    });
  });

  group('American', () {
    test('initial position', () {
      final s = CheckersState.initial(CheckersConfig.american);
      expect(s.pieceCount(0), 12);
      expect(s.pieceCount(1), 12);
      expect(rules.legalMoves(s), hasLength(7));
      expect(CheckersRules.squareNumber(sq(0, 0)), 1);
      expect(CheckersRules.squareNumber(sq(7, 7)), 32);
      expect(CheckersRules.squareNumber(sq(0, 1)), -1);
    });

    test('capturing is compulsory', () {
      final s = board({sq(2, 2): m0, sq(2, 6): m0, sq(3, 3): m1, sq(6, 6): m1});
      expect(rules.legalMoves(s), [
        CheckersMove([sq(2, 2), sq(4, 4)], [sq(3, 3)]),
      ]);
    });

    test('a multi-jump must be completed', () {
      final s = board({sq(2, 2): m0, sq(3, 3): m1, sq(5, 5): m1, sq(7, 1): m1});
      expect(rules.legalMoves(s), [
        CheckersMove([sq(2, 2), sq(4, 4), sq(6, 6)], [sq(3, 3), sq(5, 5)]),
      ]);
      final after = rules.apply(s, rules.legalMoves(s).single);
      expect(after.pieceCount(1), 1);
      expect(after.board[sq(6, 6)], m0);
    });

    test('men capture forwards only, kings both ways', () {
      final man = board({sq(4, 4): m0, sq(3, 3): m1, sq(7, 7): m1});
      expect(rules.legalMoves(man).every((m) => !m.isCapture), isTrue);
      final king = board({sq(4, 4): k0, sq(3, 3): m1, sq(7, 7): m1});
      expect(rules.legalMoves(king), [
        CheckersMove([sq(4, 4), sq(2, 2)], [sq(3, 3)]),
      ]);
    });

    test('kings move one square; men forwards only', () {
      final s = board({sq(3, 3): k0, sq(2, 6): m0, sq(7, 1): m1});
      final moves = rules.legalMoves(s).map((m) => m.path).toList();
      expect(moves.where((p) => p.first == sq(3, 3)), hasLength(4));
      expect(moves.where((p) => p.first == sq(2, 6)).map((p) => p.last).toSet(), {sq(3, 5), sq(3, 7)});
    });

    test('crowning ends the move', () {
      // After landing on the back row a king could jump again – not allowed.
      final s = board({sq(5, 1): m0, sq(6, 2): m1, sq(6, 4): m1, sq(0, 0): m1});
      final moves = rules.legalMoves(s);
      expect(moves, [
        CheckersMove([sq(5, 1), sq(7, 3)], [sq(6, 2)]),
      ]);
      expect(rules.apply(s, moves.single).board[sq(7, 3)], k0);
    });

    test('a player without moves loses', () {
      // p1's last man is boxed in (the jumps would leave the board).
      final s = board({sq(0, 0): m0, sq(0, 2): m0, sq(2, 0): m0, sq(2, 2): m0, sq(3, 7): m0, sq(1, 1): m1});
      final block = CheckersMove([sq(3, 7), sq(4, 6)]);
      expect(rules.legalMoves(s), contains(block));
      expect(rules.legalMoves(s).any((m) => m.isCapture), isFalse);
      final after = rules.apply(s, block);
      expect(after.result, const GameResult(winners: [0], reason: GameEndReason.noLegalMoves));
      final wipe = board({sq(2, 2): m0, sq(3, 3): m1});
      expect(rules.apply(wipe, rules.legalMoves(wipe).single).result?.winners, [0]);
    });

    test('threefold repetition and the no-progress rule draw', () {
      var s = board({sq(0, 0): k0, sq(7, 7): k1});
      final cycle = [
        CheckersMove([sq(0, 0), sq(1, 1)]),
        CheckersMove([sq(7, 7), sq(6, 6)]),
        CheckersMove([sq(1, 1), sq(0, 0)]),
        CheckersMove([sq(6, 6), sq(7, 7)]),
      ];
      for (var i = 0; i < 8; i++) {
        expect(s.result, isNull);
        s = rules.apply(s, cycle[i % 4]);
      }
      expect(s.result?.reason, GameEndReason.threefoldRepetition);
      expect(s.end, CheckersGameEnd.threefoldRepetition);

      final quiet = CheckersState(
        config: CheckersConfig.american,
        board: board({sq(0, 0): k0, sq(7, 7): k1}).board,
        currentPlayer: 0,
        pliesWithoutProgress: 79,
      );
      expect(rules.apply(quiet, cycle[0]).result?.reason, GameEndReason.noProgress);
    });

    test('every man move is irreversible on the diagonal board', () {
      final s = board({sq(2, 2): m0, sq(0, 0): k0, sq(7, 7): k1, sq(6, 6): k1});
      final quiet = CheckersState(
        config: CheckersConfig.american,
        board: s.board,
        currentPlayer: 0,
        pliesWithoutProgress: 10,
      );
      final step = CheckersMove([sq(2, 2), sq(3, 3)]);
      expect(CheckersMoveGen.isIrreversible(step, m0), isTrue);
      final after = rules.apply(quiet, step);
      expect(after.pliesWithoutProgress, 0);
      expect(after.keys, hasLength(1));
    });

    test('one piece each and kings v a lone king are not adjudicated', () {
      final one = board({sq(2, 2): m0, sq(3, 3): m1, sq(7, 7): k1});
      final after = rules.apply(one, rules.legalMoves(one).single);
      expect(after.pieceCount(0) + after.pieceCount(1), 2);
      expect(after.result, isNull);
      final kings = board({sq(0, 0): k0, sq(0, 2): k0, sq(7, 1): k1});
      expect(rules.apply(kings, CheckersMove([sq(0, 2), sq(1, 3)])).result, isNull);
    });
  });

  group('flying kings option', () {
    test('kings slide and choose any landing square', () {
      final s = board({sq(0, 0): k0, sq(6, 0): m1}, config: CheckersConfig.americanFlyingKings);
      expect(rules.legalMoves(s).map((m) => m.to).toSet(), {for (var i = 1; i < 8; i++) sq(i, i)});
      final cap = board({sq(0, 0): k0, sq(3, 3): m1, sq(6, 0): m1}, config: CheckersConfig.americanFlyingKings);
      expect(rules.legalMoves(cap).map((m) => m.to).toSet(), {sq(4, 4), sq(5, 5), sq(6, 6), sq(7, 7)});
      expect(rules.legalMoves(cap).every((m) => m.captures.length == 1 && m.captures.first == sq(3, 3)), isTrue);
    });
  });

  group('Turkish federation Dama (orthogonal)', () {
    const t = CheckersConfig.turkish;

    test('initial position and first moves', () {
      final s = CheckersState.initial(t);
      expect(s.pieceCount(0), 16);
      expect(s.pieceCount(1), 16);
      expect(rules.legalMoves(s), hasLength(8));
    });

    test('men move forwards and sideways, never backwards', () {
      final s = board({sq(3, 3): m0, sq(7, 7): m1}, config: t);
      expect(rules.legalMoves(s).map((m) => m.to).toSet(), {sq(4, 3), sq(3, 2), sq(3, 4)});
    });

    test('the maximum capture is compulsory', () {
      final s = board({sq(2, 0): m0, sq(3, 0): m1, sq(5, 0): m1, sq(2, 5): m0, sq(2, 6): m1}, config: t);
      expect(rules.legalMoves(s), [
        CheckersMove([sq(2, 0), sq(4, 0), sq(6, 0)], [sq(3, 0), sq(5, 0)]),
      ]);
    });

    test('captured pieces vanish at once, but a king may not turn back', () {
      final pieces = {sq(0, 3): k0, sq(0, 5): m1, sq(0, 1): m1, sq(7, 7): m1};
      final strict = rules.legalMoves(board(pieces, config: t));
      expect(strict.every((m) => m.captures.length == 1), isTrue);
      const noReverse = CheckersConfig(
        geometry: CheckersGeometry.orthogonal,
        flyingKings: true,
        maximumCapture: true,
        removeCapturedImmediately: true,
      );
      final loose = rules.legalMoves(board(pieces, config: noReverse));
      expect(loose.every((m) => m.captures.length == 2), isTrue);
      expect(loose.map((m) => m.to), contains(sq(0, 0)));
      // With captured pieces kept until the end of the move (blocking), the
      // way back is closed again.
      const blocking = CheckersConfig(geometry: CheckersGeometry.orthogonal, flyingKings: true, maximumCapture: true);
      expect(rules.legalMoves(board(pieces, config: blocking)).every((m) => m.captures.length == 1), isTrue);
    });

    test('a man reaching the far row keeps capturing sideways, then is crowned', () {
      final s2 = board({sq(5, 0): m0, sq(6, 0): m1, sq(7, 1): m1, sq(0, 7): m1}, config: t);
      expect(rules.legalMoves(s2), [
        CheckersMove([sq(5, 0), sq(7, 0), sq(7, 2)], [sq(6, 0), sq(7, 1)]),
      ]);
      expect(rules.apply(s2, rules.legalMoves(s2).single).board[sq(7, 2)], k0);
    });

    test('config survives JSON', () {
      final s = CheckersState.initial(t);
      expect(CheckersState.fromJson(s.toJson()).config, t);
    });
  });
}

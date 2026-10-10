// Jordanian Dama (الضامة) – the default checkers rules. Each `rule N` test
// follows the numbered rule of the spec (RULES.md §2, "as commonly played in
// Jordan"); `E-n` names are the spec's edge cases. Squares use a–h = columns
// 0–7 and 1–8 = rows 0–7 (player 0 / white starts on rows 2–3).
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/cinema/rules/board/board_games.dart';
import 'package:madar/features/cinema/rules/board/checkers/checkers_rules.dart'
    show CheckersGameEnd, CheckersMoveGen, CheckersVariant, checkersEndReason, checkersHash;

import 'board_test_utils.dart';

const m0 = CheckersPiece.man0, k0 = CheckersPiece.king0, m1 = CheckersPiece.man1, k1 = CheckersPiece.king1;
const jordan = CheckersConfig.jordan;
const rules = checkersRules;

int at(String name) => (int.parse(name.substring(1)) - 1) * 8 + (name.codeUnitAt(0) - 97);

String sqName(int sq) => '${String.fromCharCode(97 + (sq & 7))}${(sq >> 3) + 1}';

String fmt(CheckersMove m) => m.path.map(sqName).join(m.isCapture ? 'x' : '-');

CheckersState pos(Map<String, int> pieces, {int player = 0, CheckersConfig config = jordan, int quiet = 0}) {
  final b = List<int>.filled(64, 0);
  pieces.forEach((k, v) => b[at(k)] = v);
  return CheckersState(config: config, board: b, currentPlayer: player, pliesWithoutProgress: quiet);
}

Set<String> moves(CheckersState s) => {for (final m in rules.legalMoves(s)) fmt(m)};

CheckersMove mv(CheckersState s, String text) {
  final found = rules.legalMoves(s).where((m) => fmt(m) == text).toList();
  expect(found, hasLength(1), reason: '$text is not legal; legal: ${moves(s)}');
  return found.single;
}

CheckersState play(CheckersState s, String text) => rules.apply(s, mv(s, text));

void expectEnd(CheckersState s, CheckersGameEnd end, {int? winner}) {
  expect(s.end, end);
  expect(s.result, isNotNull);
  expect(s.result!.reason, checkersEndReason(end));
  expect(s.result!.winners, winner == null ? isEmpty : [winner]);
}

/// What a move does to the board: the piece, where it ends and which pieces
/// it takes (the route between is cosmetic once victims leave at once).
String outcome(CheckersMove m) => '${sqName(m.from)}>${sqName(m.to)} ${(List.of(m.captures)..sort()).map(sqName)}';

/// An independent reference for the Jordanian rules (spec rules 4–12, 14),
/// written on a row/column grid with a fresh copy per jump. Maps every legal
/// route (all of them, before equivalent routes are merged) to its
/// [outcome].
Map<String, String> referenceRoutes(List<int> board, int p) {
  final fwd = p == 0 ? 1 : -1;
  bool mine(int v) => v != 0 && (v > 0) == (p == 0);
  bool enemy(int v) => v != 0 && (v > 0) != (p == 0);
  bool on(int r, int c) => r >= 0 && r < 8 && c >= 0 && c < 8;
  List<(int, int)> dirs(bool king) => king ? const [(1, 0), (-1, 0), (0, 1), (0, -1)] : [(fwd, 0), (0, 1), (0, -1)];
  String route(List<int> path, bool capture) => path.map(sqName).join(capture ? 'x' : '-');
  final captures = <(List<int>, List<int>)>[];
  void jump(List<List<int>> g, int r, int c, bool king, (int, int)? last, List<int> path, List<int> victims) {
    var more = false;
    for (final (dr, dc) in dirs(king)) {
      if (last != null && last.$1 == -dr && last.$2 == -dc) continue; // no 180° turn
      var vr = r + dr, vc = c + dc;
      while (king && on(vr, vc) && g[vr][vc] == 0) {
        vr += dr;
        vc += dc;
      }
      if (!on(vr, vc) || !enemy(g[vr][vc])) continue;
      for (var lr = vr + dr, lc = vc + dc; on(lr, lc) && g[lr][lc] == 0; lr += dr, lc += dc) {
        more = true;
        final next = [
          for (final row in g) [...row],
        ]..[vr][vc] = 0; // removed at once
        jump(next, lr, lc, king, (dr, dc), [...path, lr * 8 + lc], [...victims, vr * 8 + vc]);
        if (!king) break;
      }
    }
    if (!more && victims.isNotEmpty) captures.add((path, victims));
  }

  for (var sq = 0; sq < 64; sq++) {
    if (!mine(board[sq])) continue;
    final g = [
      for (var r = 0; r < 8; r++) [for (var c = 0; c < 8; c++) board[r * 8 + c]],
    ];
    g[sq >> 3][sq & 7] = 0; // the mover is lifted from its origin
    jump(g, sq >> 3, sq & 7, board[sq].abs() == 2, null, [sq], []);
  }
  if (captures.isNotEmpty) {
    final most = captures.map((e) => e.$2.length).reduce((a, b) => a > b ? a : b);
    return {
      for (final (path, victims) in captures)
        if (victims.length == most) route(path, true): outcome(CheckersMove(path, victims)),
    };
  }
  final steps = <String, String>{};
  for (var sq = 0; sq < 64; sq++) {
    if (!mine(board[sq])) continue;
    final king = board[sq].abs() == 2;
    for (final (dr, dc) in dirs(king)) {
      for (var r = (sq >> 3) + dr, c = (sq & 7) + dc; on(r, c) && board[r * 8 + c] == 0; r += dr, c += dc) {
        steps[route([sq, r * 8 + c], false)] = outcome(CheckersMove([sq, r * 8 + c]));
        if (!king) break;
      }
    }
  }
  return steps;
}

/// A random position: [pieces] placements, a third of them kings (a man
/// on its own far row is made a king).
List<int> randomBoard(BoardRng rng, int pieces) {
  final b = List<int>.filled(64, 0);
  for (var k = 0; k < pieces; k++) {
    final sq = rng.nextInt(64), side = rng.nextInt(2), row = sq >> 3;
    final king = rng.nextInt(3) == 0 || row == (side == 0 ? 7 : 0);
    b[sq] = side == 0 ? (king ? k0 : m0) : (king ? k1 : m1);
  }
  return b;
}

void main() {
  group('Jordanian Dama – setup and turns', () {
    test('rule 1: 16 men each fill rows 2–3 and 6–7; rows 1, 4, 5 and 8 start empty', () {
      final s = CheckersState.initial();
      expect(s.config, jordan);
      for (var sq = 0; sq < 64; sq++) {
        final r = sq >> 3;
        expect(s.board[sq], r == 1 || r == 2 ? m0 : (r == 5 || r == 6 ? m1 : 0), reason: sqName(sq));
      }
      expect(s.pieceCount(0), 16);
      expect(s.pieceCount(1), 16);
    });

    test('rule 2: white (player 0) moves first, one move per turn, no passing', () {
      final e = BoardGameEngine<CheckersState, CheckersMove>(rules, CheckersState.initial());
      expect(e.currentPlayer, 0);
      expect(e.legalMoves(1), isEmpty);
      expect(e.legalMoves().every((m) => m.path.length >= 2 && m.from != m.to), isTrue);
      e.apply(e.legalMoves().first);
      expect(e.currentPlayer, 1);
      expect(e.legalMoves(0), isEmpty);
    });

    test('rule 3 (E-1): the opening has exactly 8 moves, each front man stepping forward', () {
      final s = CheckersState.initial();
      expect(moves(s), {for (final c in 'abcdefgh'.split('')) '${c}3-${c}4'});
      expect(moves(play(s, 'd3-d4')), {for (final c in 'abcdefgh'.split('')) '${c}6-${c}5'});
    });
  });

  group('Jordanian Dama – men', () {
    test('rule 4: a man steps forward, left or right – never backward or diagonally', () {
      expect(moves(pos({'d4': m0, 'h7': m1})), {'d4-d5', 'd4-c4', 'd4-e4'});
      expect(moves(pos({'a4': m0, 'h7': m1})), {'a4-a5', 'a4-b4'});
      expect(moves(pos({'e5': m1, 'a2': m0}, player: 1)), {'e5-e4', 'e5-d5', 'e5-f5'});
      // Blocked in front and on both sides: no move at all for that man.
      expect(moves(pos({'d4': m0, 'd5': m0, 'c4': m0, 'e4': m0, 'h8': k1})).where((m) => m.startsWith('d4')), isEmpty);
    });

    test('rule 5: a man captures forward or sideways, never backward or diagonally', () {
      expect(moves(pos({'d4': m0, 'd3': m1, 'c4': m1, 'e5': m1})), {'d4xb4'});
      expect(moves(pos({'d4': m0, 'd3': m1, 'e5': m1, 'h8': m1})).every((m) => !m.contains('x')), isTrue);
      expect(moves(pos({'e5': m1, 'e4': m0, 'a2': m0}, player: 1)), {'e5xe3'});
    });
  });

  group('Jordanian Dama – kings', () {
    test('rule 6: a king moves any distance along its row or column, forward or back', () {
      expect(moves(pos({'d4': k0, 'h8': m1})), {
        for (final c in 'abcefgh'.split('')) 'd4-${c}4',
        for (final r in [1, 2, 3, 5, 6, 7, 8]) 'd4-d$r',
      });
      final blocked = moves(pos({'d4': k0, 'd6': m0, 'h8': m1}));
      expect(blocked.where((m) => m.startsWith('d4-d') && int.parse(m.substring(4)) > 4), {'d4-d5'});
    });

    test('rule 7: a king captures from a distance and lands on any empty square beyond', () {
      expect(moves(pos({'a1': k0, 'a4': m1, 'h8': k1})), {'a1xa5', 'a1xa6', 'a1xa7', 'a1xa8'});
      // The run of landing squares stops at the next piece.
      expect(moves(pos({'a1': k0, 'a4': m1, 'a7': m0, 'h8': k1})), {'a1xa5', 'a1xa6'});
    });

    test('rule 8 (E-5, E-16): no jumping two pieces in a row, and never an own piece', () {
      expect(rules.legalMoves(pos({'a1': k0, 'a4': m1, 'a5': m1, 'h8': k1})).any((m) => m.isCapture), isFalse);
      expect(rules.legalMoves(pos({'a1': k0, 'a4': m1, 'a5': m0, 'h8': k1})).any((m) => m.isCapture), isFalse);
      final own = moves(pos({'a1': k0, 'a3': m0, 'h8': k1}));
      expect(own.where((m) => m.startsWith('a1-a')), {'a1-a2'});
      expect(own.any((m) => m.contains('x')), isFalse);
    });
  });

  group('Jordanian Dama – capture obligations', () {
    test('rule 9: capturing is compulsory', () {
      expect(moves(pos({'d4': m0, 'd5': m1, 'a2': m0, 'h8': k1})), {'d4xd6'});
    });

    test('rule 10 (E-6): the most pieces must be taken; a king counts as one; ties are free', () {
      // Two men beat one king.
      expect(moves(pos({'d4': m0, 'd5': k1, 'e4': m1, 'g4': m1})), {'d4xf4xh4'});
      // E-2: tied maxima – any landing after the last capture.
      expect(moves(pos({'a1': k0, 'a4': m1, 'c6': m1, 'h8': m1})), {for (final c in 'defgh'.split('')) 'a1xa6x${c}6'});
      // A tie between two different pieces.
      expect(moves(pos({'b4': m0, 'f4': m0, 'b5': m1, 'f5': m1, 'h8': k1})), {'b4xb6', 'f4xf6'});
      // The majority rule counts over all pieces: the man's double beats the king's single.
      expect(moves(pos({'b4': m0, 'b5': m1, 'b7': m1, 'a1': k0, 'c1': k1})), {'b4xb6xb8'});
    });

    test('rule 11 (E-14): a sequence goes on; victims vanish at once and their squares can be crossed', () {
      final s = pos({'a1': k0, 'a3': m1, 'c5': m1, 'd3': m1, 'b2': m1, 'a7': m1});
      expect(moves(s), {'a1xa5xd5xd2xa2xa8'});
      final after = play(s, 'a1xa5xd5xd2xa2xa8');
      expect(after.pieceCount(1), 0);
      expect(after.board[at('a8')], k0);
      expectEnd(after, CheckersGameEnd.noLegalMoves, winner: 0);
    });

    test('rule 12 (E-3, E-7): 90° turns are allowed, a 180° turn between jumps is not', () {
      expect(moves(pos({'a1': k0, 'a3': m1, 'c5': m1, 'f3': m1, 'h8': m1})), {'a1xa5xf5xf2', 'a1xa5xf5xf1'});
      expect(moves(pos({'d1': k0, 'b1': m1, 'f1': m1, 'h8': m1})), {'d1xa1', 'd1xg1', 'd1xh1'});
      // With the 180° ban switched off the king could take both. Going right
      // first it may stop on g1 or h1 before turning back – same position,
      // so one move.
      final loose = jordan.copyWith(forbidReverseInCapture: false);
      expect(moves(pos({'d1': k0, 'b1': m1, 'f1': m1, 'h8': m1}, config: loose)), {'d1xa1xg1', 'd1xa1xh1', 'd1xg1xa1'});
    });
  });

  group('Jordanian Dama – promotion', () {
    test('rule 13: a man whose move ends on the far row is crowned and flies from its next turn', () {
      var s = pos({'c7': m0, 'h3': m1, 'h4': m1});
      s = play(s, 'c7-c8');
      expect(s.board[at('c8')], k0);
      expect(s.currentPlayer, 1);
      s = play(s, 'h3-g3');
      expect(moves(s), containsAll(['c8-c1', 'c8-a8', 'c8-h8']));
    });

    test('rule 14 (E-4, E-12): mid-capture on the far row it keeps capturing as a man, crowned at the end', () {
      final e4 = pos({'d6': m0, 'd7': m1, 'e8': k1, 'a2': m1, 'b2': m1});
      expect(moves(e4), {'d6xd8xf8'});
      expect(play(e4, 'd6xd8xf8').board[at('f8')], k0);
      // As a man it cannot then jump backward over f7 (a king could).
      final e12 = pos({'d6': m0, 'd7': m1, 'e8': m1, 'f7': m1, 'a2': m1});
      expect(moves(e12), {'d6xd8xf8'});
      expect(play(e12, 'd6xd8xf8').board[at('f8')], k0);
    });

    test('rule 15 (E-15): a quiet step onto the far row ends the move even beside an enemy', () {
      final s = pos({'d7': m0, 'e8': m1, 'a2': m1});
      expect(moves(s), {'d7-d8', 'd7-c7', 'd7-e7'});
      final after = play(s, 'd7-d8');
      expect(after.board[at('d8')], k0);
      expect(after.currentPlayer, 1);
      expect(after.lastMove!.path, hasLength(2));
    });
  });

  group('Jordanian Dama – winning', () {
    test('rule 16 (E-11): a player with no piece or no legal move loses', () {
      // Player 1's last man on a2 is boxed in by a1, b2 and c2.
      final boxed = pos({'a1': k0, 'a3': m0, 'b2': m0, 'c2': m0, 'h4': m0, 'a2': m1});
      expect(rules.legalMoves(boxed).any((m) => m.isCapture), isFalse);
      expectEnd(play(boxed, 'h4-h5'), CheckersGameEnd.noLegalMoves, winner: 0);
      // Taking the last piece wins.
      expectEnd(play(pos({'d4': m0, 'd5': m1}), 'd4xd6'), CheckersGameEnd.noLegalMoves, winner: 0);
    });

    test('rule 17 (E-10a): two or more kings against a lone king win', () {
      final after = play(pos({'a1': k0, 'g1': k0, 'd5': k1}), 'g1-h1');
      expectEnd(after, CheckersGameEnd.kingsVsLoneKing, winner: 0);
      // The lone king could still move: this is an adjudication, not a block.
      final same = CheckersState(config: jordan, board: after.board, currentPlayer: 1);
      expect(rules.legalMoves(same), isNotEmpty);
    });

    test('rule 17 exception (E-10b): not while the lone king must capture', () {
      var s = play(pos({'c2': k0, 'h8': k0, 'd5': k1}), 'c2-d2');
      expect(s.result, isNull);
      expect(moves(s), {'d5xd1'});
      s = play(s, 'd5xd1');
      expectEnd(s, CheckersGameEnd.onePieceEach);
    });

    test('rule 17 (E-10c): men may remain beside the kings; either side to move', () {
      final after = play(pos({'a1': k0, 'h1': k0, 'b2': m0, 'c2': m0, 'e6': k1}, player: 1), 'e6-e5');
      expectEnd(after, CheckersGameEnd.kingsVsLoneKing, winner: 0);
      // Colours reversed: player 1's kings beat player 0's lone king.
      final rev = play(pos({'a8': k1, 'h8': k1, 'd4': k0}, player: 1), 'h8-h7');
      expectEnd(rev, CheckersGameEnd.kingsVsLoneKing, winner: 1);
      // One king and men against a lone king is played out.
      expect(play(pos({'a1': k0, 'b2': m0, 'c2': m0, 'e6': k1}, player: 1), 'e6-e5').result, isNull);
    });

    test('rules 18 and 22: resigning and draw offers are UI actions – the engine has only board moves', () {
      final s = CheckersState.initial();
      expect(rules.legalMoves(s).every((m) => m.path.length >= 2), isTrue);
      expect(GameResult(winners: const [1], reason: checkersEndReason(CheckersGameEnd.noLegalMoves)).isDraw, isFalse);
    });
  });

  group('Jordanian Dama – draws', () {
    test('rule 19 (E-8a): one piece each is a draw when the side to move cannot capture', () {
      final s = pos({'a1': k0, 'a4': m1, 'h8': k1});
      expect(moves(s), {'a1xa5', 'a1xa6', 'a1xa7', 'a1xa8'});
      for (final m in moves(s)) {
        expectEnd(play(s, m), CheckersGameEnd.onePieceEach);
      }
      // Two men count as one piece each too.
      expectEnd(play(pos({'a2': m0, 'h7': m1}, player: 1), 'h7-g7'), CheckersGameEnd.onePieceEach);
    });

    test('rule 19 exception (E-8b): the side to move that can take the last piece must, and wins', () {
      final s = pos({'b1': k0, 'b3': m1, 'h5': k1});
      expect(moves(s), {'b1xb4', 'b1xb5', 'b1xb6', 'b1xb7', 'b1xb8'});
      final hanging = play(s, 'b1xb5');
      expect(hanging.result, isNull);
      expect(moves(hanging), {'h5xa5'});
      expectEnd(play(hanging, 'h5xa5'), CheckersGameEnd.noLegalMoves, winner: 1);
      for (final safe in ['b1xb4', 'b1xb6', 'b1xb7', 'b1xb8']) {
        expectEnd(play(s, safe), CheckersGameEnd.onePieceEach);
      }
    });

    test('rule 20 (E-13): the third repetition is a draw; sideways man steps keep the history', () {
      var s = pos({'a2': m0, 'a3': m0, 'h6': m1, 'h7': m1});
      const cycle = ['a3-b3', 'h6-g6', 'b3-a3', 'g6-h6'];
      for (var i = 0; i < 8; i++) {
        expect(s.result, isNull, reason: 'ply $i');
        s = play(s, cycle[i % 4]);
      }
      expectEnd(s, CheckersGameEnd.threefoldRepetition);
      expect(s.pliesWithoutProgress, 8);
      expect(s.keys, hasLength(9));
    });

    test('rule 21 (E-9a): 50 plies without a capture or a forward man step draw', () {
      final pieces = {'a1': k0, 'c3': k0, 'h8': k1, 'f6': k1};
      final before = play(pos(pieces, quiet: 48), 'a1-a2');
      expect(before.result, isNull);
      expect(before.pliesWithoutProgress, 49);
      expectEnd(play(pos(pieces, quiet: 49), 'a1-a2'), CheckersGameEnd.noProgress);
    });

    test('rule 21 (E-9b, E-9c): a sideways man step counts toward the 50, a forward step resets it', () {
      final pieces = {'d3': m0, 'a1': k0, 'h8': k1, 'f6': k1};
      final sideways = play(pos(pieces, quiet: 49), 'd3-e3');
      expectEnd(sideways, CheckersGameEnd.noProgress);
      final forward = play(pos(pieces, quiet: 49), 'd3-d4');
      expect(forward.result, isNull);
      expect(forward.pliesWithoutProgress, 0);
      expect(forward.keys, hasLength(1));
      expect(CheckersMoveGen.isIrreversible(CheckersMove([at('d3'), at('e3')]), m0), isFalse);
      expect(CheckersMoveGen.isIrreversible(CheckersMove([at('d3'), at('d4')]), m0), isTrue);
      expect(CheckersMoveGen.isIrreversible(CheckersMove([at('a1'), at('a8')]), k0), isFalse);
      expect(CheckersMoveGen.isIrreversible(CheckersMove([at('a1'), at('a8')], [at('a4')]), k0), isTrue);
    });

    test('rule 21: a capture resets the count', () {
      final after = play(pos({'a1': k0, 'c3': k0, 'a4': m1, 'h8': k1, 'g8': k1}, quiet: 49), 'a1xa5');
      expect(after.result, isNull);
      expect(after.pliesWithoutProgress, 0);
    });
  });

  group('Options and other presets', () {
    test('Samara option (E-17): a king against a lone man wins; off by default it is a draw', () {
      final samara = jordan.copyWith(kingBeatsLoneMan: true);
      expectEnd(play(pos({'a1': k0, 'h7': m1}, config: samara), 'a1-b1'), CheckersGameEnd.kingVsLoneMan, winner: 0);
      expectEnd(play(pos({'a1': k0, 'h7': m1}), 'a1-b1'), CheckersGameEnd.onePieceEach);
      // Not while the man's side must capture the king: it takes it and wins.
      final trap = play(pos({'a3': k0, 'h3': m1}, config: samara), 'a3-g3');
      expect(trap.result, isNull);
      expectEnd(play(trap, 'h3xf3'), CheckersGameEnd.noLegalMoves, winner: 1);
      // Player 1's king against player 0's lone man.
      expectEnd(
        play(pos({'h8': k1, 'b2': m0}, player: 1, config: samara), 'h8-h7'),
        CheckersGameEnd.kingVsLoneMan,
        winner: 1,
      );
    });

    test('Turkish federation preset: no kings-v-lone-king adjudication, otherwise the same', () {
      const t = CheckersConfig.turkish;
      expect(play(pos({'a1': k0, 'g1': k0, 'd5': k1}, config: t), 'g1-h1').result, isNull);
      expectEnd(play(pos({'a1': k0, 'a4': m1, 'h8': k1}, config: t), 'a1xa6'), CheckersGameEnd.onePieceEach);
      expectEnd(play(pos({'a1': k0, 'g1': k0, 'd5': k1}, config: t, quiet: 49), 'g1-h1'), CheckersGameEnd.noProgress);
    });

    test('option: promotion ends the move', () {
      final ends = jordan.copyWith(promotionInCapture: CheckersPromotionInCapture.endsMove);
      final s = pos({'d6': m0, 'd7': m1, 'e8': k1, 'a2': m1, 'b2': m1}, config: ends);
      expect(moves(s), {'d6xd8'});
      expect(play(s, 'd6xd8').board[at('d8')], k0);
    });

    test('option: free choice of capture (no majority rule)', () {
      final free = jordan.copyWith(maximumCapture: false);
      expect(moves(pos({'d4': m0, 'd5': k1, 'e4': m1, 'g4': m1}, config: free)), {'d4xd6', 'd4xf4xh4'});
    });

    test('option: the no-progress limit is one number', () {
      final c32 = jordan.copyWith(noProgressLimit: 32);
      final pieces = {'a1': k0, 'c3': k0, 'h8': k1, 'f6': k1};
      expectEnd(play(pos(pieces, config: c32, quiet: 31), 'a1-a2'), CheckersGameEnd.noProgress);
      expect(play(pos(pieces, quiet: 31), 'a1-a2').result, isNull);
    });

    test('option: kingsBeatLoneKing and onePieceEachDraw can be switched off', () {
      final off = jordan.copyWith(kingsBeatLoneKing: false, onePieceEachDraw: false);
      expect(play(pos({'a1': k0, 'g1': k0, 'd5': k1}, config: off), 'g1-h1').result, isNull);
      expect(play(pos({'a1': k0, 'a4': m1, 'h8': k1}, config: off), 'a1xa6').result, isNull);
    });
  });

  group('Move generation cross-check', () {
    test('matches an independent reference on random positions (rules 4–12, 14)', () {
      final rng = BoardRng(2024);
      var captures = 0;
      for (var i = 0; i < 1500; i++) {
        final b = randomBoard(rng, 2 + rng.nextInt(15));
        final p = rng.nextInt(2);
        final legal = rules.legalMoves(CheckersState(config: jordan, board: b, currentPlayer: p));
        final ref = referenceRoutes(b, p);
        final why = 'position $i: $b, player $p';
        // Every route the engine lists is a legal route ...
        expect(ref.keys, containsAll(legal.map(fmt)), reason: why);
        // ... every legal outcome is offered ...
        expect({for (final m in legal) outcome(m)}, ref.values.toSet(), reason: why);
        // ... and each outcome exactly once.
        expect({for (final m in legal) outcome(m)}, hasLength(legal.length), reason: why);
        if (legal.any((m) => m.isCapture)) captures++;
      }
      expect(captures, greaterThan(500));
    });

    test('the end judgement after each move follows the spec order (§3.9) in random play', () {
      // Written from the spec: no legal move, Samara option, one piece each,
      // kings v lone king (each adjudication paused by a forced capture of
      // the side it rules against), no progress, threefold repetition.
      (CheckersGameEnd, int?)? expected(CheckersState before, CheckersMove m, CheckersState after) {
        final cfg = before.config, next = after.currentPlayer, mover = before.currentPlayer;
        final replies = CheckersMoveGen(cfg).generate(after.board, next);
        if (replies.isEmpty) return (CheckersGameEnd.noLegalMoves, mover);
        final mustCapture = replies.first.isCapture;
        int count(int p) => after.pieceCount(p);
        int kings(int p) => after.pieceCount(p, kings: true);
        if (count(0) == 1 && count(1) == 1) {
          if (cfg.kingBeatsLoneMan && kings(0) + kings(1) == 1) {
            final kingSide = kings(0) == 1 ? 0 : 1;
            if (!(next != kingSide && mustCapture)) return (CheckersGameEnd.kingVsLoneMan, kingSide);
          }
          if (cfg.onePieceEachDraw && !mustCapture) return (CheckersGameEnd.onePieceEach, null);
        }
        for (final x in [0, 1]) {
          final y = 1 - x;
          if (cfg.kingsBeatLoneKing && kings(x) >= 2 && count(y) == 1 && kings(y) == 1 && !(next == y && mustCapture)) {
            return (CheckersGameEnd.kingsVsLoneKing, x);
          }
        }
        final wasMan = !CheckersPiece.isKing(before.board[m.from]);
        final irreversible = m.isCapture || (wasMan && (m.from >> 3) != (m.to >> 3));
        final quiet = irreversible ? 0 : before.pliesWithoutProgress + 1;
        expect(after.pliesWithoutProgress, quiet);
        if (quiet >= cfg.noProgressLimit) return (CheckersGameEnd.noProgress, null);
        final key = checkersHash(after.board, next);
        final keys = irreversible ? [key] : [...before.keys, key];
        expect(after.keys, keys);
        if (keys.where((k) => k == key).length >= 3) return (CheckersGameEnd.threefoldRepetition, null);
        return null;
      }

      final configs = [jordan, CheckersConfig.turkish, jordan.copyWith(kingBeatsLoneMan: true)];
      final rng = BoardRng(99);
      final seen = <CheckersGameEnd?>{};
      for (var i = 0; i < 1200; i++) {
        final cfg = configs[i % configs.length];
        final b = randomBoard(rng, 2 + rng.nextInt(5));
        if (!b.any((v) => v > 0) || !b.any((v) => v < 0)) continue;
        var s = CheckersState(
          config: cfg,
          board: b,
          currentPlayer: rng.nextInt(2),
          pliesWithoutProgress: rng.nextInt(cfg.noProgressLimit),
        );
        final played = <CheckersMove>[];
        for (var ply = 0; ply < 30 && !s.isOver && rules.legalMoves(s).isNotEmpty; ply++) {
          final legal = rules.legalMoves(s);
          // Half the time, step back where this side came from, so that
          // positions repeat.
          final back = played.length < 2
              ? null
              : CheckersMove([played[played.length - 2].to, played[played.length - 2].from]);
          final m = back != null && legal.contains(back) && rng.nextBool() ? back : rng.pick(legal);
          played.add(m);
          final after = rules.apply(s, m);
          final want = expected(s, m, after);
          final why = '${cfg.variant ?? 'samara'} ${s.board} player ${s.currentPlayer} ${fmt(m)}';
          expect(after.end, want?.$1, reason: why);
          expect(after.result?.winners, want == null ? isNull : (want.$2 == null ? isEmpty : [want.$2]), reason: why);
          seen.add(after.end);
          s = after;
        }
      }
      expect(seen, containsAll([null, ...CheckersGameEnd.values]));
    });

    test('routes that take the same pieces to the same square are one move (no blow-up)', () {
      // A king among 16 scattered pieces can take all of them along
      // hundreds of thousands of routes, which reach only 62 different
      // positions. Listing every route froze move generation and the AI.
      final s = pos({
        'e2': k0,
        for (final q in ['d1', 'f1', 'g2', 'c3', 'b4', 'h4', 'f5', 'e7', 'd8', 'f8']) q: k1,
        for (final q in ['d2', 'e3', 'f3', 'a5', 'd6', 'g7']) q: m1,
      });
      final legal = rules.legalMoves(s);
      expect(legal.every((m) => m.captures.length == 16), isTrue);
      expect({for (final m in legal) outcome(m)}, hasLength(legal.length));
      expect(legal, hasLength(62));
      for (final m in legal.take(5)) {
        expectEnd(rules.apply(s, m), CheckersGameEnd.noLegalMoves, winner: 0);
      }
    });

    test('equal outcomes are merged for every preset, and the first route found is kept', () {
      // A flying king taking two pieces on one file may stop on d3, d4 or
      // d5 between them: three routes, two positions (d7 or d8 at the end).
      final line = pos({'d1': k1, 'd2': m0, 'd6': m0, 'g2': m0, 'h8': k0}, player: 1);
      expect(referenceRoutes(line.board, 1), hasLength(6));
      expect(moves(line), {'d1xd3xd7', 'd1xd3xd8'});
      // American draughts, whose captured pieces stay until the move ends,
      // merges the same way.
      final fly = pos({'a1': k0, 'c3': m1, 'f6': m1, 'h8': k1}, config: CheckersConfig.americanFlyingKings);
      expect(moves(fly), {'a1xd4xg7'});
      // A king circling four pieces gets back to a1 either way round: one
      // move, listed with the route found first.
      final ring = pos({'a1': k0, 'a3': m1, 'c5': m1, 'd3': m1, 'b1': m1, 'h8': m1});
      expect(referenceRoutes(ring.board, 0).keys, containsAll(['a1xa5xd5xd1xa1', 'a1xd1xd5xa5xa1']));
      expect(moves(ring), {'a1xa5xd5xd1xa1', 'a1xd1xd5xa5xa2'});
      expect(play(ring, 'a1xa5xd5xd1xa1').board[at('a1')], k0);
    });
  });

  group('Serialisation and match end', () {
    test('state, config and the exact end survive JSON', () {
      for (final v in CheckersVariant.values) {
        final s = CheckersState.initial(v.config);
        final copy = CheckersState.fromJson(roundTrip(s.toJson()));
        expect(copy.config, v.config);
        expect(canonical(copy), canonical(s));
      }
      final ended = play(pos({'a1': k0, 'g1': k0, 'd5': k1}), 'g1-h1');
      final copy = CheckersState.fromJson(roundTrip(ended.toJson()));
      expect(copy.end, CheckersGameEnd.kingsVsLoneKing);
      expect(copy.result, ended.result);
      expect(copy.lastMove, ended.lastMove);
      expect(canonical(copy), canonical(ended));
      final custom = jordan.copyWith(kingBeatsLoneMan: true, noProgressLimit: 100);
      expect(CheckersConfig.fromJson(roundTrip(custom.toJson())), custom);
    });

    test('a saved engine replays to the same state', () {
      final kit = boardGameKits[BoardGameId.checkers]!;
      final e = playGame(kit, players: 2, seed: 21, levels: const [AiLevel.medium, AiLevel.easy], cap: 40);
      final restored = kit.engineFromJson(roundTrip(e.toJson()));
      expect(canonical(restored.state), canonical(e.state));
      expect((restored.state as CheckersState).config, jordan);
    });

    test('a game saved mid-shuffle keeps its repetition history and quiet count', () {
      var s = pos({'a2': m0, 'a3': m0, 'h6': m1, 'h7': m1}, quiet: 40);
      const cycle = ['a3-b3', 'h6-g6', 'b3-a3', 'g6-h6'];
      for (var i = 0; i < 5; i++) {
        s = play(s, cycle[i % 4]);
      }
      s = CheckersState.fromJson(roundTrip(s.toJson()));
      expect(s.pliesWithoutProgress, 45);
      expect(s.keys, hasLength(6));
      expect(s.currentPlayer, 1);
      for (var i = 5; i < 8; i++) {
        expect(s.result, isNull, reason: 'ply $i');
        s = play(s, cycle[i % 4]);
      }
      expectEnd(s, CheckersGameEnd.threefoldRepetition);
      // The same save one ply before a 50-ply draw still draws on time.
      final late = CheckersState.fromJson(roundTrip(pos({'a1': k0, 'c3': k0, 'h8': k1, 'f6': k1}, quiet: 49).toJson()));
      expectEnd(play(late, 'a1-a2'), CheckersGameEnd.noProgress);
    });

    test('a finished game accepts no more moves', () {
      final e = BoardGameEngine<CheckersState, CheckersMove>(rules, pos({'a1': k0, 'g1': k0, 'd5': k1}));
      e.apply(mv(e.state, 'g1-h1'));
      expect(e.isOver, isTrue);
      expect(e.result!.winners, [0]);
      expect(e.legalMoves(), isEmpty);
      expect(() => e.apply(CheckersMove([at('d5'), at('d6')])), throwsA(isA<IllegalMoveException>()));
      e.undo();
      expect(e.isOver, isFalse);
    });

    test('seeded random games end on their own (termination)', () {
      for (final v in [CheckersVariant.jordan, CheckersVariant.turkish]) {
        for (var seed = 0; seed < 4; seed++) {
          final e = playGame(
            boardGameKits[BoardGameId.checkers]!,
            players: 2,
            seed: seed,
            levels: const [null],
            cap: 20000,
            initial: CheckersState.initial(v.config),
          );
          expect(e.isOver, isTrue, reason: '${v.name} seed $seed');
          expect((e.state as CheckersState).end, isNotNull);
        }
      }
    });
  });

  group('Self-play and AI per variant', () {
    final kit = boardGameKits[BoardGameId.checkers]!;

    for (final v in CheckersVariant.values) {
      test('${v.name}: random self-play keeps invariants and round-trips JSON', () {
        for (var seed = 0; seed < 3; seed++) {
          final e = playGame(
            kit,
            players: 2,
            seed: seed,
            levels: const [null],
            initial: CheckersState.initial(v.config),
          );
          final restored = kit.engineFromJson(roundTrip(e.toJson()));
          expect(canonical(restored.state), canonical(e.state));
        }
      });

      test('${v.name}: every AI level plays legal moves; same seed, same game', () {
        for (final level in AiLevel.values) {
          playGame(kit, players: 2, seed: 40, levels: [level], cap: 80, initial: CheckersState.initial(v.config));
        }
        List<String> line() => [
          for (final m in playGame(
            kit,
            players: 2,
            seed: 3,
            levels: const [AiLevel.hard, AiLevel.easy],
            cap: 40,
            initial: CheckersState.initial(v.config),
          ).history)
            m.toJson().toString(),
        ];
        expect(line(), line());
      });
    }

    test('AI never hands the lone king a capture of the last piece (E-8b)', () {
      final s = pos({'b1': k0, 'b3': m1, 'h5': k1});
      for (final level in [AiLevel.medium, AiLevel.hard]) {
        for (var seed = 0; seed < 4; seed++) {
          final m = const CheckersAi().chooseMove(s, level, BoardRng(seed), const AiBudget.nodes(3000));
          expect(fmt(m), isNot('b1xb5'), reason: '${level.name} seed $seed');
        }
      }
    });

    test('AI picks the landing that wins by kings v a lone king', () {
      final s = pos({'a2': k0, 'a8': k0, 'e6': m0, 'e7': m0, 'd2': m1, 'e5': k1});
      expect(moves(s), {'a2xe2', 'a2xf2', 'a2xg2', 'a2xh2'});
      for (final level in [AiLevel.medium, AiLevel.hard]) {
        final m = const CheckersAi().chooseMove(s, level, BoardRng(5), const AiBudget.nodes(3000));
        expectEnd(rules.apply(s, m), CheckersGameEnd.kingsVsLoneKing, winner: 0);
      }
    });

    test('AI always returns a legal move with the phone budget', () {
      var s = CheckersState.initial();
      final rng = BoardRng(77);
      for (var i = 0; i < 6 && !s.isOver; i++) {
        final m = const CheckersAi().chooseMove(s, AiLevel.values[i % 3], rng);
        expect(rules.legalMoves(s), contains(m));
        s = rules.apply(s, m);
      }
    });

    test('jordan: medium beats easy (difficulty ordering)', () {
      var score = 0.0;
      for (var g = 0; g < 4; g++) {
        final mediumSeat = g % 2;
        final e = playGame(
          kit,
          players: 2,
          seed: 900 + g,
          levels: mediumSeat == 0 ? const [AiLevel.medium, AiLevel.easy] : const [AiLevel.easy, AiLevel.medium],
          budget: const AiBudget.nodes(4000),
          invariants: false,
          cap: 3000,
        );
        final r = e.result;
        score += r == null || r.isDraw ? 0.5 : (r.winners.contains(mediumSeat) ? 1 : 0);
      }
      expect(score, greaterThanOrEqualTo(3.0));
    }, timeout: const Timeout(Duration(minutes: 5)));

    // Mirrors strength_test.dart's checkers plan for the default rules.
    for (final (v, games, minimum) in [
      (CheckersVariant.jordan, 6, 4.5),
      (CheckersVariant.turkish, 4, 3.0),
      (CheckersVariant.american, 4, 3.0),
    ]) {
      test('${v.name}: hard beats easy', () {
        var score = 0.0;
        for (var g = 0; g < games; g++) {
          final hardSeat = g % 2;
          final e = playGame(
            kit,
            players: 2,
            seed: 900 + g,
            levels: hardSeat == 0 ? const [AiLevel.hard, AiLevel.easy] : const [AiLevel.easy, AiLevel.hard],
            budget: const AiBudget.nodes(4000),
            invariants: false,
            cap: 3000,
            initial: CheckersState.initial(v.config),
          );
          final r = e.result;
          if (r == null || r.isDraw) {
            score += 0.5;
          } else if (r.winners.contains(hardSeat)) {
            score += 1;
          }
        }
        expect(score, greaterThanOrEqualTo(minimum));
      }, timeout: const Timeout(Duration(minutes: 5)));
    }
  });
}

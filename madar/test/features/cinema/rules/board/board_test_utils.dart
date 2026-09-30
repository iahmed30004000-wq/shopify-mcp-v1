import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/cinema/rules/board/board_games.dart';
import 'package:madar/features/cinema/rules/board/chess/chess_position.dart' show ChessPosition;

/// Small deterministic budgets so the suite is fast and reproducible.
const Map<BoardGameId, AiBudget> testBudgets = {
  BoardGameId.chess: AiBudget.nodes(1500),
  BoardGameId.checkers: AiBudget.nodes(1500),
  BoardGameId.backgammon: AiBudget.nodes(600),
  BoardGameId.dominoes: AiBudget.nodes(1500),
  BoardGameId.ludo: AiBudget.nodes(500),
  BoardGameId.mancala: AiBudget.nodes(1500),
  BoardGameId.connectFour: AiBudget.nodes(1500),
  BoardGameId.ticTacToe: AiBudget.nodes(500),
};

/// Maximum plies per self-play game before the test stops it.
const Map<BoardGameId, int> plyCaps = {
  BoardGameId.chess: 240,
  BoardGameId.checkers: 300,
  BoardGameId.backgammon: 800,
  BoardGameId.dominoes: 800,
  BoardGameId.ludo: 2000,
  BoardGameId.mancala: 400,
  BoardGameId.connectFour: 42,
  BoardGameId.ticTacToe: 9,
};

/// JSON through a real encode/decode cycle.
Map<String, Object?> roundTrip(Map<String, Object?> json) => jsonDecode(jsonEncode(json)) as Map<String, Object?>;

String canonical(GameState s) => jsonEncode(s.toJson());

/// Structural invariants every state must satisfy.
void checkInvariants(GameState s) {
  switch (s) {
    case ChessState():
      final pos = ChessPosition.fromFen(s.fen);
      expect(pos.toFen(), s.fen);
      expect(s.board.where((p) => p == 6).length, 1);
      expect(s.board.where((p) => p == 14).length, 1);
    case CheckersState():
      final perSide = s.config.geometry == CheckersGeometry.diagonal ? 12 : 16;
      expect(s.pieceCount(0), lessThanOrEqualTo(perSide));
      expect(s.pieceCount(1), lessThanOrEqualTo(perSide));
      for (var sq = 0; sq < 64; sq++) {
        if (s.board[sq] == CheckersPiece.man0) expect(sq >> 3, lessThan(7));
        if (s.board[sq] == CheckersPiece.man1) expect(sq >> 3, greaterThan(0));
      }
    case BackgammonState():
      var p0 = s.bar[0] + s.off[0], p1 = s.bar[1] + s.off[1];
      for (final v in s.points) {
        if (v > 0) p0 += v;
        if (v < 0) p1 -= v;
      }
      expect(p0, 15);
      expect(p1, 15);
      expect(s.cubeValue, greaterThanOrEqualTo(1));
    case DominoState():
      final all = <int>[
        for (final h in s.hands)
          for (final t in h) t.id,
        for (final t in s.boneyard) t.id,
        for (final p in s.line) p.tile.id,
      ];
      expect(all.length, 28);
      expect(all.toSet().length, 28);
      for (var i = 0; i + 1 < s.line.length; i++) {
        expect(s.line[i].right, s.line[i + 1].left);
      }
      for (final p in s.line) {
        expect({p.left, p.right}, {p.tile.low, p.tile.high});
      }
    case LudoState():
      for (final t in s.tokens) {
        expect(t.length, s.config.tokensPerPlayer);
        for (final x in t) {
          expect(x, inInclusiveRange(kLudoYard, kLudoHome));
        }
      }
    case MancalaState():
      final total = s.pits.fold(0, (a, b) => a + b) + s.stores[0] + s.stores[1];
      expect(total, s.config.totalSeeds);
      expect(s.pits.every((p) => p >= 0), isTrue);
    case ConnectFourState():
      final a = s.cells.where((c) => c == 1).length, b = s.cells.where((c) => c == 2).length;
      expect(a - b, inInclusiveRange(0, 1));
      for (var col = 0; col < kC4Cols; col++) {
        var seenEmpty = false;
        for (var row = 0; row < kC4Rows; row++) {
          final c = s.cell(row, col);
          if (c == 0) seenEmpty = true;
          if (seenEmpty) expect(c, 0, reason: 'floating stone');
        }
      }
    case TicTacToeState():
      final a = s.cells.where((c) => c == 1).length, b = s.cells.where((c) => c == 2).length;
      expect(a - b, inInclusiveRange(0, 1));
  }
}

/// Plays one game with every seat driven by [levels] (null = uniformly
/// random legal move). Returns the engine.
BoardGameEngine<GameState, GameMove> playGame(
  BoardGameKit<GameState, GameMove> kit, {
  required int players,
  required int seed,
  required List<AiLevel?> levels,
  AiBudget? budget,
  int? cap,
  bool invariants = true,
  GameState? initial,
}) {
  final engine = initial == null
      ? kit.engine(players: players, seed: seed)
      : BoardGameEngine<GameState, GameMove>(kit.rules, initial);
  final rng = BoardRng(seed * 7919 + 17);
  final limit = cap ?? plyCaps[kit.id]!;
  var plies = 0;
  while (!engine.isOver && plies < limit) {
    final state = engine.state;
    if (invariants) checkInvariants(state);
    final legal = engine.legalMoves();
    expect(legal, isNotEmpty, reason: '${kit.id} has no legal moves but is not over');
    expect(engine.legalMoves((state.currentPlayer + 1) % state.playerCount), isEmpty);
    final level = levels[state.currentPlayer % levels.length];
    final move = level == null ? rng.pick(legal) : kit.ai.chooseMove(state, level, rng, budget ?? testBudgets[kit.id]!);
    engine.apply(move);
    plies++;
  }
  if (invariants) checkInvariants(engine.state);
  return engine;
}

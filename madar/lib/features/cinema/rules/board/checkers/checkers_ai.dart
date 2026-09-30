/// Checkers AI: negamax alpha-beta with iterative deepening, capture
/// extension (forced captures are searched past the horizon), repetition
/// awareness and a material / advancement / back-rank evaluation.
library;

import '../core/engine.dart';
import '../core/game_types.dart';
import '../core/rng.dart';
import '../core/search.dart';
import 'checkers_rules.dart';

const int _win = 100000;

final class CheckersAi implements BoardAi<CheckersState, CheckersMove> {
  const CheckersAi();

  @override
  CheckersMove chooseMove(CheckersState state, AiLevel level, BoardRng rng, [AiBudget budget = AiBudget.phone]) {
    final moves = checkersRules.legalMoves(state);
    if (moves.isEmpty) throw StateError('no legal moves');
    if (moves.length == 1) return moves.first;
    final s = _Search(state, SearchClock(budget));
    switch (level) {
      case AiLevel.easy:
        if (rng.nextInt(100) < 15) return rng.pick(moves);
        return s.noisy(moves, 2, 40, rng);
      case AiLevel.medium:
        return s.noisy(moves, 4, 10, rng);
      case AiLevel.hard:
        final unlimited = budget.maxNodes == null && budget.maxTime == null;
        return s.iterate(moves, unlimited ? 8 : 40, rng);
    }
  }
}

final class _Search {
  _Search(CheckersState state, this.clock)
    : gen = CheckersMoveGen(state.config),
      board = List<int>.of(state.board),
      root = state.currentPlayer,
      quiet = state.pliesWithoutProgress,
      keys = List<int>.of(state.keys),
      kingValue = state.config.flyingKings ? 280 : 165,
      advance = state.config.geometry == CheckersGeometry.orthogonal ? 6 : 4;

  final CheckersMoveGen gen;
  final List<int> board;
  final int root;
  final SearchClock clock;
  final int kingValue;
  final int advance;
  int quiet;
  final List<int> keys;
  bool abortable = false;

  int evaluate(int player) {
    int score;
    final diagonal = gen.config.geometry == CheckersGeometry.diagonal;
    var material0 = 0, material1 = 0;
    for (var sq = 0; sq < 64; sq++) {
      final v = board[sq];
      if (v == 0) continue;
      final owner = CheckersPiece.owner(v);
      final r = sq >> 3, c = sq & 7;
      int value;
      if (CheckersPiece.isKing(v)) {
        value = kingValue;
        if (r >= 2 && r <= 5 && c >= 2 && c <= 5) value += 6;
      } else {
        final rowsAdvanced = owner == 0 ? r : 7 - r;
        value = 100 + rowsAdvanced * advance;
        if (diagonal && rowsAdvanced == 0) value += 8; // back-rank guard
        if (c >= 2 && c <= 5) value += 3;
      }
      if (owner == 0) {
        material0 += value;
      } else {
        material1 += value;
      }
    }
    // Trading down when ahead makes the lead count for more.
    score = (material0 - material1) * 3000 ~/ (material0 + material1 + 600);
    return player == 0 ? score : -score;
  }

  int _negamax(int player, int depth, int alpha, int beta, int ply, int extensions) {
    if (clock.tick() && abortable) throw const SearchAborted();
    final moves = gen.generate(board, player);
    if (moves.isEmpty) return -_win + ply;
    if (ply > 0) {
      if (quiet >= gen.config.noProgressLimit) return 0;
      final key = keys.last;
      if (key != -1) {
        for (var i = keys.length - 3; i >= 0; i -= 2) {
          if (keys[i] == -1 || keys[i + 1] == -1) break;
          if (keys[i] == key) return 0;
        }
      }
    }
    final forced = moves.first.isCapture;
    if (depth <= 0) {
      if (!forced || extensions >= 10) return evaluate(player);
      depth = 1;
      extensions++;
    }
    if (ply > 60) return evaluate(player);
    moves.sort((a, b) => b.captures.length - a.captures.length);
    var best = -_win * 2;
    for (final m in moves) {
      final wasMan = !CheckersPiece.isKing(board[m.from]);
      final undo = gen.make(board, m, player);
      final savedQuiet = quiet;
      final progress = m.isCapture || wasMan;
      quiet = progress ? 0 : quiet + 1;
      keys.add(progress ? -1 : checkersHash(board, 1 - player));
      int score;
      try {
        score = -_negamax(1 - player, depth - 1, -beta, -alpha, ply + 1, extensions);
      } finally {
        keys.removeLast();
        quiet = savedQuiet;
        gen.unmake(board, m, undo);
      }
      if (score > best) best = score;
      if (score > alpha) alpha = score;
      if (alpha >= beta) break;
    }
    return best;
  }

  int _scoreRoot(CheckersMove m, int depth, int alpha, int beta) {
    final wasMan = !CheckersPiece.isKing(board[m.from]);
    final undo = gen.make(board, m, root);
    final savedQuiet = quiet;
    final progress = m.isCapture || wasMan;
    quiet = progress ? 0 : quiet + 1;
    keys.add(progress ? -1 : checkersHash(board, 1 - root));
    try {
      return -_negamax(1 - root, depth - 1, -beta, -alpha, 1, 0);
    } finally {
      keys.removeLast();
      quiet = savedQuiet;
      gen.unmake(board, m, undo);
    }
  }

  CheckersMove noisy(List<CheckersMove> moves, int depth, int noise, BoardRng rng) {
    List<int> scoresAt(int d) => [for (final m in moves) _scoreRoot(m, d, -_win * 2, _win * 2)];
    abortable = false;
    var scores = scoresAt(1);
    abortable = true;
    for (var d = 2; d <= depth; d++) {
      try {
        scores = scoresAt(d);
      } on SearchAborted {
        break;
      }
    }
    var best = 0, bestScore = -_win * 4;
    for (var i = 0; i < moves.length; i++) {
      final s = scores[i] + rng.nextInt(2 * noise + 1) - noise;
      if (s > bestScore) {
        bestScore = s;
        best = i;
      }
    }
    return moves[best];
  }

  CheckersMove iterate(List<CheckersMove> moves, int maxDepth, BoardRng rng) {
    final order = [...moves];
    // Deterministic shuffle so equal moves vary between games.
    rng.shuffle(order);
    var best = order.first;
    for (var depth = 1; depth <= maxDepth; depth++) {
      abortable = depth > 1;
      var alpha = -_win * 2;
      var iterBest = order.first;
      try {
        for (final m in order) {
          final score = _scoreRoot(m, depth, alpha, _win * 2);
          if (score > alpha) {
            alpha = score;
            iterBest = m;
          }
        }
      } on SearchAborted {
        break;
      }
      best = iterBest;
      order
        ..remove(best)
        ..insert(0, best);
      if (alpha.abs() >= _win - 200) break;
      if (clock.checkTime() || clock.timeFraction > 0.4) break;
    }
    return best;
  }
}

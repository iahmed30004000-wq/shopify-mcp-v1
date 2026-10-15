/// Four-in-a-row AI: bitboard negamax with alpha-beta, iterative deepening,
/// a transposition table, "non-losing move" pruning (never play under an
/// opponent threat, answer forced blocks) and threat-count ordering and
/// evaluation.
library;

import 'dart:typed_data';

import '../core/engine.dart';
import '../core/game_types.dart';
import '../core/rng.dart';
import '../core/search.dart';
import 'connect_four_rules.dart';

const int _win = 10000;
const List<int> _order = [3, 2, 4, 1, 5, 0, 6];

final class _Pos {
  _Pos(this.current, this.mask, this.moves);
  int current; // stones of the player to move
  int mask; // all stones
  int moves;

  bool canPlay(int col) => mask & C4Bits.top(col) == 0;

  void play(int col) {
    current ^= mask;
    mask |= mask + C4Bits.bottom(col);
    moves++;
  }

  bool isWinningMove(int col) => C4Bits.aligned(current | ((mask + C4Bits.bottom(col)) & C4Bits.column(col)));

  int get possible => (mask + C4Bits.bottomMask) & C4Bits.boardMask;
  int get opponent => current ^ mask;
  int get key => current + mask;
}

final class _Tt {
  _Tt(int bits) : m = (1 << bits) - 1, keys = List<int>.filled(1 << bits, 0), vals = Int32List(1 << bits);
  final int m;
  final List<int> keys;
  final Int32List vals; // (score + 32768) | depth << 16 | flag << 24 | move << 26
}

final class ConnectFourAi implements BoardAi<ConnectFourState, ConnectFourMove> {
  const ConnectFourAi();

  @override
  ConnectFourMove chooseMove(ConnectFourState state, AiLevel level, BoardRng rng, [AiBudget budget = AiBudget.phone]) {
    final legal = connectFourRules.legalMoves(state);
    if (legal.isEmpty) throw StateError('no legal moves');
    if (legal.length == 1) return legal.first;
    final me = state.currentPlayer;
    final pos = _Pos(state.bitsOf(me), state.bitsOf(0) | state.bitsOf(1), state.moveCount);
    final s = _Searcher(SearchClock(budget), _Tt(16));
    switch (level) {
      case AiLevel.easy:
        if (rng.nextInt(100) < 30) return rng.pick(legal);
        return ConnectFourMove(s.noisy(pos, 2, 60, rng));
      case AiLevel.medium:
        return ConnectFourMove(s.noisy(pos, 5, 8, rng));
      case AiLevel.hard:
        final unlimited = budget.maxNodes == null && budget.maxTime == null;
        return ConnectFourMove(s.iterate(pos, unlimited ? 12 : 42));
    }
  }
}

final class _Searcher {
  _Searcher(this.clock, this.tt);
  final SearchClock clock;
  final _Tt tt;
  bool abortable = false;

  int evaluate(_Pos p) {
    final mine = C4Bits.winningCells(p.current, p.mask);
    final theirs = C4Bits.winningCells(p.opponent, p.mask);
    var score = (C4Bits.popcount(mine) - C4Bits.popcount(theirs)) * 12;
    final centre = C4Bits.column(3);
    score += (C4Bits.popcount(p.current & centre) - C4Bits.popcount(p.opponent & centre)) * 4;
    final nearCentre = C4Bits.column(2) | C4Bits.column(4);
    score += C4Bits.popcount(p.current & nearCentre) - C4Bits.popcount(p.opponent & nearCentre);
    return score;
  }

  /// Negamax for the side to move.
  int negamax(_Pos p, int depth, int alpha, int beta) {
    if (clock.tick() && abortable) throw const SearchAborted();
    if (p.moves >= 42) return 0;
    final possible = p.possible;
    if (C4Bits.winningCells(p.current, p.mask) & possible != 0) return _win - p.moves;
    final oppWin = C4Bits.winningCells(p.opponent, p.mask);
    final forced = possible & oppWin;
    var candidates = possible & ~(oppWin >> 1);
    if (forced != 0) {
      if (forced & (forced - 1) != 0) return -(_win - p.moves - 1); // two threats
      candidates &= forced;
    }
    if (candidates == 0) return -(_win - p.moves - 1); // every move loses
    if (depth <= 0) return evaluate(p);

    final idx = p.key & tt.m;
    var ttMove = -1;
    if (tt.keys[idx] == p.key) {
      final v = tt.vals[idx];
      ttMove = (v >> 26) & 7;
      if (ttMove == 7) ttMove = -1;
      if (((v >> 16) & 0xFF) >= depth) {
        final score = (v & 0xFFFF) - 32768;
        final flag = (v >> 24) & 3;
        if (flag == 1) return score;
        if (flag == 2 && score >= beta) return score;
        if (flag == 3 && score <= alpha) return score;
      }
    }

    // Order: TT move, then by threats created, centre first on ties.
    final cols = <int>[];
    final keys = <int>[];
    for (final c in _order) {
      final bit = candidates & C4Bits.column(c);
      if (bit == 0) continue;
      var k = C4Bits.popcount(C4Bits.winningCells(p.current | bit, p.mask));
      if (c == ttMove) k += 1000;
      var i = cols.length;
      cols.add(c);
      keys.add(k);
      while (i > 0 && keys[i - 1] < k) {
        cols[i] = cols[i - 1];
        keys[i] = keys[i - 1];
        cols[i - 1] = c;
        keys[i - 1] = k;
        i--;
      }
    }
    final origAlpha = alpha;
    var best = -_win * 2, bestCol = cols.first;
    for (final c in cols) {
      final child = _Pos(p.current, p.mask, p.moves)..play(c);
      final v = -negamax(child, depth - 1, -beta, -alpha);
      if (v > best) {
        best = v;
        bestCol = c;
      }
      if (v > alpha) alpha = v;
      if (alpha >= beta) break;
    }
    final flag = best <= origAlpha ? 3 : (best >= beta ? 2 : 1);
    tt.keys[idx] = p.key;
    tt.vals[idx] = (best + 32768) | (depth.clamp(0, 255) << 16) | (flag << 24) | (bestCol << 26);
    return best;
  }

  /// Exact-ish score of each legal root column at [depth].
  int _scoreRoot(_Pos p, int col, int depth, int alpha, int beta) {
    if (p.isWinningMove(col)) return _win - p.moves;
    final child = _Pos(p.current, p.mask, p.moves)..play(col);
    return -negamax(child, depth - 1, -beta, -alpha);
  }

  List<int> _roots(_Pos p) => [
    for (final c in _order)
      if (p.canPlay(c)) c,
  ];

  int noisy(_Pos p, int depth, int noise, BoardRng rng) {
    final roots = _roots(p);
    abortable = false;
    var scores = [for (final c in roots) _scoreRoot(p, c, 1, -_win * 2, _win * 2)];
    abortable = true;
    for (var d = 2; d <= depth; d++) {
      try {
        scores = [for (final c in roots) _scoreRoot(p, c, d, -_win * 2, _win * 2)];
      } on SearchAborted {
        break;
      }
    }
    var best = 0, bestScore = -_win * 4;
    for (var i = 0; i < roots.length; i++) {
      final s = scores[i] + rng.nextInt(2 * noise + 1) - noise;
      if (s > bestScore) {
        bestScore = s;
        best = i;
      }
    }
    return roots[best];
  }

  int iterate(_Pos p, int maxDepth) {
    final order = _roots(p);
    for (final c in order) {
      if (p.isWinningMove(c)) return c;
    }
    var best = order.first;
    for (var depth = 1; depth <= maxDepth && depth <= 42 - p.moves; depth++) {
      abortable = depth > 1;
      var alpha = -_win * 2;
      var iterBest = order.first;
      try {
        for (final c in order) {
          final v = _scoreRoot(p, c, depth, alpha, _win * 2);
          if (v > alpha) {
            alpha = v;
            iterBest = c;
          }
        }
      } on SearchAborted {
        break;
      }
      best = iterBest;
      order
        ..remove(best)
        ..insert(0, best);
      if (alpha.abs() >= _win - 42) break; // solved
      if (clock.checkTime() || clock.timeFraction > 0.4) break;
    }
    return best;
  }
}

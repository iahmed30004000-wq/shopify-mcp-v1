/// Chess AI: negamax alpha-beta (PVS) with iterative deepening, a
/// transposition table, null-move pruning, check extension, quiescence
/// search, MVV-LVA / killer / history move ordering and a compact tapered
/// piece-square evaluation.
library;

import 'dart:typed_data';

import '../core/engine.dart';
import '../core/game_types.dart';
import '../core/rng.dart';
import '../core/search.dart';
import 'chess_position.dart';
import 'chess_rules.dart';

const int _inf = 32000;
const int _mate = 31000;
const int _mateBound = 30000;
const int _maxPly = 96;

/// Piece values (index = type).
const List<int> _value = [0, 100, 320, 330, 500, 900, 0];

// Piece-square tables (Michniewski's simplified evaluation), written from
// white's point of view with rank 8 first.
const List<List<int>> _pstVisual = [
  [], // empty
  [
    0, 0, 0, 0, 0, 0, 0, 0, //
    50, 50, 50, 50, 50, 50, 50, 50,
    10, 10, 20, 30, 30, 20, 10, 10,
    5, 5, 10, 25, 25, 10, 5, 5,
    0, 0, 0, 20, 20, 0, 0, 0,
    5, -5, -10, 0, 0, -10, -5, 5,
    5, 10, 10, -20, -20, 10, 10, 5,
    0, 0, 0, 0, 0, 0, 0, 0,
  ],
  [
    -50, -40, -30, -30, -30, -30, -40, -50, //
    -40, -20, 0, 0, 0, 0, -20, -40,
    -30, 0, 10, 15, 15, 10, 0, -30,
    -30, 5, 15, 20, 20, 15, 5, -30,
    -30, 0, 15, 20, 20, 15, 0, -30,
    -30, 5, 10, 15, 15, 10, 5, -30,
    -40, -20, 0, 5, 5, 0, -20, -40,
    -50, -40, -30, -30, -30, -30, -40, -50,
  ],
  [
    -20, -10, -10, -10, -10, -10, -10, -20, //
    -10, 0, 0, 0, 0, 0, 0, -10,
    -10, 0, 5, 10, 10, 5, 0, -10,
    -10, 5, 5, 10, 10, 5, 5, -10,
    -10, 0, 10, 10, 10, 10, 0, -10,
    -10, 10, 10, 10, 10, 10, 10, -10,
    -10, 5, 0, 0, 0, 0, 5, -10,
    -20, -10, -10, -10, -10, -10, -10, -20,
  ],
  [
    0, 0, 0, 0, 0, 0, 0, 0, //
    5, 10, 10, 10, 10, 10, 10, 5,
    -5, 0, 0, 0, 0, 0, 0, -5,
    -5, 0, 0, 0, 0, 0, 0, -5,
    -5, 0, 0, 0, 0, 0, 0, -5,
    -5, 0, 0, 0, 0, 0, 0, -5,
    -5, 0, 0, 0, 0, 0, 0, -5,
    0, 0, 0, 5, 5, 0, 0, 0,
  ],
  [
    -20, -10, -10, -5, -5, -10, -10, -20, //
    -10, 0, 0, 0, 0, 0, 0, -10,
    -10, 0, 5, 5, 5, 5, 0, -10,
    -5, 0, 5, 5, 5, 5, 0, -5,
    0, 0, 5, 5, 5, 5, 0, -5,
    -10, 5, 5, 5, 5, 5, 0, -10,
    -10, 0, 5, 0, 0, 0, 0, -10,
    -20, -10, -10, -5, -5, -10, -10, -20,
  ],
  [
    -30, -40, -40, -50, -50, -40, -40, -30, // king, middle game
    -30, -40, -40, -50, -50, -40, -40, -30,
    -30, -40, -40, -50, -50, -40, -40, -30,
    -30, -40, -40, -50, -50, -40, -40, -30,
    -20, -30, -30, -40, -40, -30, -30, -20,
    -10, -20, -20, -20, -20, -20, -20, -10,
    20, 20, 0, 0, 0, 0, 20, 20,
    20, 30, 10, 0, 0, 10, 30, 20,
  ],
];

const List<int> _kingEndVisual = [
  -50, -40, -30, -20, -20, -30, -40, -50, //
  -30, -20, -10, 0, 0, -10, -20, -30,
  -30, -10, 20, 30, 30, 20, -10, -30,
  -30, -10, 30, 40, 40, 30, -10, -30,
  -30, -10, 30, 40, 40, 30, -10, -30,
  -30, -10, 20, 30, 30, 20, -10, -30,
  -30, -30, 0, 0, 0, 0, -30, -30,
  -50, -30, -30, -30, -30, -30, -30, -50,
];

/// `_pst[color][type * 64 + sq]` = material + square bonus (middle game).
final List<Int16List> _pst = List.generate(2, (color) {
  final t = Int16List(7 * 64);
  for (var type = 1; type <= 6; type++) {
    for (var sq = 0; sq < 64; sq++) {
      final visual = color == kWhite ? (7 - (sq >> 3)) * 8 + (sq & 7) : sq;
      t[type * 64 + sq] = _value[type] + _pstVisual[type][visual];
    }
  }
  return t;
});

final List<Int16List> _kingEnd = List.generate(2, (color) {
  final t = Int16List(64);
  for (var sq = 0; sq < 64; sq++) {
    t[sq] = _kingEndVisual[color == kWhite ? (7 - (sq >> 3)) * 8 + (sq & 7) : sq];
  }
  return t;
});

/// Static evaluation from the side to move's point of view (centipawns).
int evaluateChess(ChessPosition pos) {
  final b = pos.board;
  var mg0 = 0, mg1 = 0, phase = 0, bishops0 = 0, bishops1 = 0;
  var heavyOrPawn = 0, knights = 0, light = 0, dark = 0;
  var material0 = 0, material1 = 0;
  final pst0 = _pst[0], pst1 = _pst[1];
  for (var sq = 0; sq < 64; sq++) {
    final pc = b[sq];
    if (pc == 0) continue;
    final type = pc & 7;
    if (type == kKing) continue;
    if ((pc >> 3) == kWhite) {
      mg0 += pst0[type * 64 + sq];
      material0 += _value[type];
      if (type == kBishop) bishops0++;
    } else {
      mg1 += pst1[type * 64 + sq];
      material1 += _value[type];
      if (type == kBishop) bishops1++;
    }
    switch (type) {
      case kKnight:
        phase += 1;
        knights++;
      case kBishop:
        phase += 1;
        if (((sq >> 3) + (sq & 7)) & 1 == 0) {
          dark++;
        } else {
          light++;
        }
      case kRook:
        phase += 2;
        heavyOrPawn++;
      case kQueen:
        phase += 4;
        heavyOrPawn++;
      default:
        heavyOrPawn++;
    }
  }
  if (heavyOrPawn == 0 && ((knights == 0 && (light == 0 || dark == 0)) || (knights == 1 && light + dark == 0))) {
    return 0; // dead draw
  }
  if (phase > 24) phase = 24;
  final k0 = pos.kingSq[0], k1 = pos.kingSq[1];
  final king0 = (pst0[kKing * 64 + k0] * phase + _kingEnd[0][k0] * (24 - phase)) ~/ 24;
  final king1 = (pst1[kKing * 64 + k1] * phase + _kingEnd[1][k1] * (24 - phase)) ~/ 24;
  var score = mg0 + king0 - mg1 - king1;
  if (bishops0 >= 2) score += 30;
  if (bishops1 >= 2) score -= 30;
  // Mop-up: drive the lone/weaker king to the edge when far ahead late.
  final diff = material0 - material1;
  if (phase <= 8 && diff.abs() >= 400) {
    final loser = diff > 0 ? k1 : k0;
    final lf = loser & 7, lr = loser >> 3;
    final centre = (lf < 4 ? 3 - lf : lf - 4) + (lr < 4 ? 3 - lr : lr - 4);
    final kd = ((k0 & 7) - (k1 & 7)).abs() + ((k0 >> 3) - (k1 >> 3)).abs();
    final bonus = 10 * centre + 4 * (14 - kd);
    score += diff > 0 ? bonus : -bonus;
  }
  return pos.side == kWhite ? score : -score;
}

final class _Tt {
  _Tt(int bits)
    : mask = (1 << bits) - 1,
      keys = List<int>.filled(1 << bits, 0),
      moves = Int32List(1 << bits),
      info = Int32List(1 << bits);

  final int mask;
  final List<int> keys;
  final Int32List moves;
  final Int32List info; // score + 32768 | depth << 16 | flag << 24

  static const int exact = 1, lower = 2, upper = 3;

  void clear() {
    keys.fillRange(0, keys.length, 0);
    info.fillRange(0, info.length, 0);
    moves.fillRange(0, moves.length, 0);
  }
}

final class _Searcher {
  _Searcher(this.pos, this.clock, this.tt);

  final ChessPosition pos;
  final SearchClock clock;
  final _Tt tt;
  final List<Int32List> _moves = List.generate(_maxPly + 1, (_) => Int32List(256));
  final List<Int32List> _scores = List.generate(_maxPly + 1, (_) => Int32List(256));
  final Int32List _killers = Int32List((_maxPly + 1) * 2);
  final Int32List _history = Int32List(2 * 64 * 64);
  bool abortable = false;

  void _tick() {
    if (clock.tick() && abortable) throw const SearchAborted();
  }

  int _scoreMove(int m, int ttMove, int ply) {
    if (m == ttMove) return 2000000;
    final flags = moveFlags(m);
    final promo = movePromo(m);
    if (flags & kFlagCapture != 0) {
      final victim = flags & kFlagEnPassant != 0 ? kPawn : pos.board[moveTo(m)] & 7;
      final attacker = pos.board[moveFrom(m)] & 7;
      return 1000000 + _value[victim] * 10 - attacker + promo * 1000;
    }
    if (promo != 0) return 900000 + promo;
    if (m == _killers[ply * 2]) return 800000;
    if (m == _killers[ply * 2 + 1]) return 790000;
    return _history[(pos.side << 12) | (moveFrom(m) << 6) | moveTo(m)];
  }

  static int _pickNext(Int32List moves, Int32List scores, int start, int n) {
    var best = start;
    for (var i = start + 1; i < n; i++) {
      if (scores[i] > scores[best]) best = i;
    }
    if (best != start) {
      final m = moves[start];
      moves[start] = moves[best];
      moves[best] = m;
      final s = scores[start];
      scores[start] = scores[best];
      scores[best] = s;
    }
    return moves[start];
  }

  bool _hasNonPawnMaterial(int side) {
    final b = pos.board;
    for (var sq = 0; sq < 64; sq++) {
      final pc = b[sq];
      if (pc != 0 && (pc >> 3) == side) {
        final t = pc & 7;
        if (t != kPawn && t != kKing) return true;
      }
    }
    return false;
  }

  int quiesce(int alpha, int beta, int ply) {
    _tick();
    final stand = evaluateChess(pos);
    if (ply >= _maxPly) return stand;
    if (stand >= beta) return stand;
    if (stand > alpha) alpha = stand;
    final moves = _moves[ply], scores = _scores[ply];
    final n = pos.generate(moves, capturesOnly: true);
    for (var i = 0; i < n; i++) {
      scores[i] = _scoreMove(moves[i], 0, ply);
    }
    var best = stand;
    for (var i = 0; i < n; i++) {
      final m = _pickNext(moves, scores, i, n);
      if (!pos.makeMove(m)) continue;
      final score = -quiesce(-beta, -alpha, ply + 1);
      pos.unmakeMove();
      if (score > best) {
        best = score;
        if (score > alpha) {
          alpha = score;
          if (alpha >= beta) break;
        }
      }
    }
    return best;
  }

  int search(int depth, int alpha, int beta, int ply) {
    if (ply > 0) {
      if (pos.halfmove >= 100 || pos.isRepetition()) return 0;
    }
    final inCheck = pos.inCheck();
    if (inCheck) depth++;
    if (depth <= 0) return quiesce(alpha, beta, ply);
    _tick();
    if (ply >= _maxPly) return evaluateChess(pos);

    // Transposition table.
    final idx = pos.hash & tt.mask;
    var ttMove = 0;
    if (tt.keys[idx] == pos.hash) {
      ttMove = tt.moves[idx];
      final info = tt.info[idx];
      final ttDepth = (info >> 16) & 0xFF;
      if (ply > 0 && ttDepth >= depth) {
        var score = (info & 0xFFFF) - 32768;
        if (score >= _mateBound) score -= ply;
        if (score <= -_mateBound) score += ply;
        final flag = info >> 24;
        if (flag == _Tt.exact) return score;
        if (flag == _Tt.lower && score >= beta) return score;
        if (flag == _Tt.upper && score <= alpha) return score;
      }
    }

    // Null-move pruning.
    if (!inCheck && ply > 0 && depth >= 3 && beta < _mateBound && _hasNonPawnMaterial(pos.side)) {
      if (evaluateChess(pos) >= beta) {
        pos.makeNullMove();
        final score = -search(depth - 3, -beta, -beta + 1, ply + 1);
        pos.unmakeNullMove();
        if (score >= beta) return beta;
      }
    }

    final moves = _moves[ply], scores = _scores[ply];
    final n = pos.generate(moves);
    for (var i = 0; i < n; i++) {
      scores[i] = _scoreMove(moves[i], ttMove, ply);
    }
    final origAlpha = alpha;
    var best = -_inf, bestMove = 0, legal = 0;
    for (var i = 0; i < n; i++) {
      final m = _pickNext(moves, scores, i, n);
      if (!pos.makeMove(m)) continue;
      legal++;
      int score;
      if (legal == 1) {
        score = -search(depth - 1, -beta, -alpha, ply + 1);
      } else {
        score = -search(depth - 1, -alpha - 1, -alpha, ply + 1);
        if (score > alpha && score < beta) score = -search(depth - 1, -beta, -alpha, ply + 1);
      }
      pos.unmakeMove();
      if (score > best) {
        best = score;
        bestMove = m;
        if (score > alpha) {
          alpha = score;
          if (alpha >= beta) {
            if (moveFlags(m) & kFlagCapture == 0 && movePromo(m) == 0) {
              if (_killers[ply * 2] != m) {
                _killers[ply * 2 + 1] = _killers[ply * 2];
                _killers[ply * 2] = m;
              }
              final h = (pos.side << 12) | (moveFrom(m) << 6) | moveTo(m);
              _history[h] = (_history[h] + depth * depth).clamp(0, 700000);
            }
            break;
          }
        }
      }
    }
    if (legal == 0) return inCheck ? -_mate + ply : 0;

    final flag = best >= beta ? _Tt.lower : (best > origAlpha ? _Tt.exact : _Tt.upper);
    var stored = best;
    if (stored >= _mateBound) stored += ply;
    if (stored <= -_mateBound) stored -= ply;
    tt.keys[idx] = pos.hash;
    tt.moves[idx] = bestMove;
    tt.info[idx] = (stored + 32768) | (depth.clamp(0, 255) << 16) | (flag << 24);
    return best;
  }

  /// Full-window score of every root move at [depth] (for noisy levels).
  List<int> rootScores(List<int> rootMoves, int depth) {
    final out = <int>[];
    for (final m in rootMoves) {
      pos.makeMove(m);
      out.add(-search(depth - 1, -_inf, _inf, 1));
      pos.unmakeMove();
    }
    return out;
  }

  /// Iterative deepening; returns the best root move.
  int iterate(List<int> rootMoves, int maxDepth) {
    final order = [...rootMoves];
    var bestMove = order.first;
    for (var depth = 1; depth <= maxDepth; depth++) {
      abortable = depth > 1;
      var alpha = -_inf;
      var iterBest = order.first;
      try {
        for (var i = 0; i < order.length; i++) {
          final m = order[i];
          pos.makeMove(m);
          int score;
          if (i == 0) {
            score = -search(depth - 1, -_inf, -alpha, 1);
          } else {
            score = -search(depth - 1, -alpha - 1, -alpha, 1);
            if (score > alpha) score = -search(depth - 1, -_inf, -alpha, 1);
          }
          pos.unmakeMove();
          if (score > alpha) {
            alpha = score;
            iterBest = m;
          }
        }
      } on SearchAborted {
        break;
      }
      bestMove = iterBest;
      order
        ..remove(iterBest)
        ..insert(0, iterBest);
      if (alpha >= _mateBound || alpha <= -_mateBound) break; // forced mate found
      if (clock.checkTime() || clock.timeFraction > 0.45) break;
    }
    return bestMove;
  }
}

/// Chess opponent.
final class ChessAi implements BoardAi<ChessState, ChessMove> {
  ChessAi({this.ttBits = 16});

  /// log2 of the transposition-table size (16 → 65 536 entries, ~1 MB).
  final int ttBits;
  _Tt? _tt;

  @override
  ChessMove chooseMove(ChessState state, AiLevel level, BoardRng rng, [AiBudget budget = AiBudget.phone]) {
    final pos = state.toPosition();
    final root = pos.legalMoves();
    if (root.isEmpty) throw StateError('no legal moves');
    if (root.length == 1) return ChessRules.toPublicMove(root.first);
    final tt = _tt ??= _Tt(ttBits);
    tt.clear();
    final clock = SearchClock(budget);
    final s = _Searcher(pos, clock, tt);

    switch (level) {
      case AiLevel.easy:
        if (rng.nextInt(100) < 12) return ChessRules.toPublicMove(rng.pick(root));
        return ChessRules.toPublicMove(_noisy(s, root, 1, 150, rng));
      case AiLevel.medium:
        return ChessRules.toPublicMove(_noisy(s, root, 2, 30, rng));
      case AiLevel.hard:
        return ChessRules.toPublicMove(s.iterate(root, 64));
    }
  }

  int _noisy(_Searcher s, List<int> root, int depth, int noise, BoardRng rng) {
    s.abortable = false;
    var scores = s.rootScores(root, 1);
    if (depth > 1) {
      s.abortable = true;
      try {
        scores = s.rootScores(root, depth);
      } on SearchAborted {
        // keep the depth-1 scores
      }
      // rootScores may have been interrupted with moves still made.
    }
    var best = 0, bestScore = -1 << 30;
    for (var i = 0; i < root.length; i++) {
      final sc = scores[i] + rng.nextInt(2 * noise + 1) - noise;
      if (sc > bestScore) {
        bestScore = sc;
        best = i;
      }
    }
    return root[best];
  }
}

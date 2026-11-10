/// Mancala AI: alpha-beta over [MancalaPosition] with iterative deepening,
/// extra-turn aware (the side to move may repeat), evaluation = store
/// difference plus a small weight for seeds kept on one's own side.
library;

import '../core/engine.dart';
import '../core/game_types.dart';
import '../core/rng.dart';
import '../core/search.dart';
import 'mancala_rules.dart';

const int _win = 1000000;

final class MancalaAi implements BoardAi<MancalaState, MancalaMove> {
  const MancalaAi();

  @override
  MancalaMove chooseMove(MancalaState state, AiLevel level, BoardRng rng, [AiBudget budget = AiBudget.phone]) {
    final pos = state.toPosition();
    final pits = pos.legalPits();
    if (pits.isEmpty) throw StateError('no legal moves');
    if (pits.length == 1) return MancalaMove(pits.first);
    final clock = SearchClock(budget);
    switch (level) {
      case AiLevel.easy:
        if (rng.nextInt(100) < 40) return MancalaMove(rng.pick(pits));
        return MancalaMove(_search(pos, pits, 1, clock, rng, 3));
      case AiLevel.medium:
        return MancalaMove(_search(pos, pits, 4, clock, rng, 1));
      case AiLevel.hard:
        final unlimited = budget.maxNodes == null && budget.maxTime == null;
        return MancalaMove(_search(pos, pits, unlimited ? 10 : 40, clock, rng, 0));
    }
  }

  int _evaluate(MancalaPosition p, int me) {
    if (p.over) {
      final d = p.stores[me] - p.stores[1 - me];
      return d == 0 ? 0 : (d > 0 ? _win + d : -_win + d);
    }
    // Seeds on one's own side are worth a little in Kalah (they end up in
    // the store when the other side runs dry).
    final sideWeight = p.config.variant == MancalaVariant.kalah ? 1 : 0;
    return (p.stores[me] - p.stores[1 - me]) * 4 + (p.sideSeeds(me) - p.sideSeeds(1 - me)) * sideWeight;
  }

  /// Minimax from [me]'s point of view (extra turns keep the same player).
  int _minimax(MancalaPosition p, int me, int depth, int alpha, int beta, SearchClock clock, bool abortable) {
    if (clock.tick() && abortable) throw const SearchAborted();
    if (p.over || depth <= 0) return _evaluate(p, me);
    final moves = p.legalPits();
    if (moves.isEmpty) return _evaluate(p, me);
    final maximizing = p.player == me;
    var best = maximizing ? -_win * 4 : _win * 4;
    for (final m in moves) {
      final child = p.copy()..play(m);
      // An extra turn is not a full ply for the searcher.
      final nextDepth = child.player == p.player && !child.over ? depth : depth - 1;
      final v = _minimax(child, me, nextDepth, alpha, beta, clock, abortable);
      if (maximizing) {
        if (v > best) best = v;
        if (best > alpha) alpha = best;
      } else {
        if (v < best) best = v;
        if (best < beta) beta = best;
      }
      if (alpha >= beta) break;
    }
    return best;
  }

  int _search(MancalaPosition root, List<int> pits, int maxDepth, SearchClock clock, BoardRng rng, int noise) {
    final me = root.player;
    final order = [...pits];
    rng.shuffle(order); // vary between equal moves
    var best = order.first;
    for (var depth = 1; depth <= maxDepth; depth++) {
      final abortable = depth > 1;
      var alpha = -_win * 4;
      var iterBest = order.first;
      try {
        for (final m in order) {
          final child = root.copy()..play(m);
          final nextDepth = child.player == me && !child.over ? depth : depth - 1;
          // Noisy levels need exact scores; the hard level uses the window.
          final v = _minimax(child, me, nextDepth, noise > 0 ? -_win * 4 : alpha, _win * 4, clock, abortable);
          final noisy = noise > 0 ? v + rng.nextInt(2 * noise * 4 + 1) - noise * 4 : v;
          if (noisy > alpha) {
            alpha = noisy;
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
      if (alpha.abs() >= _win) break;
      if (clock.checkTime() || clock.timeFraction > 0.4) break;
    }
    return best;
  }
}

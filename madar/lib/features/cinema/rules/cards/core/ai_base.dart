/// Shared skeleton of the three AI levels.
///
/// * easy – the game's simple heuristic, with a random legal move now and
///   then ([easyMistakeRate]);
/// * medium – the full heuristic: card counting, voids, partner play;
/// * hard – [monteCarloChoose] over determinised worlds with the medium
///   heuristic (or a cheaper [rolloutMove]) as the rollout policy.
///
/// Heuristics only read the acting seat's own hand and public information;
/// the hard AI only sees the other hands through [determinize].
library;

import 'dart:math' as math;

import 'card_game.dart';
import 'search.dart';

abstract class HeuristicAi<S extends CardGameState, M extends CardMove> implements CardAi<S, M> {
  const HeuristicAi(this.rules);

  final CardRules<S, M> rules;

  double get easyMistakeRate => 0.2;

  /// Bonus (in game points) for a rollout that wins / loses the match.
  double get matchWinBonus => 100;

  int get maxRolloutMoves => 400;

  M easyMove(S s, int seat, List<M> legal, math.Random rng);

  M mediumMove(S s, int seat, List<M> legal, math.Random rng);

  /// Rollout policy; medium by default.
  M rolloutMove(S s, int seat, math.Random rng) {
    final legal = rules.legalMoves(s, seat);
    return legal.length == 1 ? legal.first : mediumMove(s, seat, legal, rng);
  }

  /// A copy of [s] in which everything [observer] cannot see is
  /// re-sampled consistently with public information.
  S determinize(S s, int observer, math.Random rng);

  /// Moves the hard AI compares (all legal moves by default).
  List<M> hardCandidates(S s, int seat, List<M> legal, M prior) => legal;

  bool rolloutDone(S root, S s) => s.isOver || s.dealNumber != root.dealNumber;

  /// Points gained by [observer]'s side minus the opponents' average since
  /// [root] (negated for penalty games), plus the match bonus.
  double evaluate(S root, S s, int observer) {
    final sign = s.lowerScoreWins ? -1.0 : 1.0;
    final team = s.teamOf(observer);
    final mine = (s.scores[observer] - root.scores[observer]).toDouble();
    var opp = 0.0;
    var n = 0;
    for (var seat = 0; seat < s.playerCount; seat++) {
      if (s.teamOf(seat) == team) continue;
      opp += s.scores[seat] - root.scores[seat];
      n++;
    }
    var v = sign * (mine - (n == 0 ? 0 : opp / n));
    if (s.isOver && !root.isOver) v += s.winners.contains(observer) ? matchWinBonus : -matchWinBonus;
    return v;
  }

  @override
  M chooseMove(S state, int player, AiLevel level, math.Random rng, AiBudget budget) {
    final legal = rules.legalMoves(state, player);
    if (legal.isEmpty) throw StateError('No legal move for seat $player');
    if (legal.length == 1) return legal.first;
    switch (level) {
      case AiLevel.easy:
        if (rng.nextDouble() < easyMistakeRate) return legal[rng.nextInt(legal.length)];
        return easyMove(state, player, legal, rng);
      case AiLevel.medium:
        return mediumMove(state, player, legal, rng);
      case AiLevel.hard:
        final prior = mediumMove(state, player, legal, rng);
        final candidates = hardCandidates(state, player, legal, prior);
        return monteCarloChoose<S, M>(
          candidates: candidates,
          hooks: SearchHooks<S, M>(
            sampleWorld: (r) => determinize(state, player, r),
            apply: (s, m) => rules.apply(s, m),
            policy: rolloutMove,
            done: (s) => rolloutDone(state, s),
            score: (s) => evaluate(state, s, player),
            maxRolloutMoves: maxRolloutMoves,
          ),
          rng: rng,
          budget: budget,
          fallback: prior,
        );
    }
  }
}

/// Picks the element with the highest [score] (first one on ties).
T bestBy<T>(Iterable<T> items, num Function(T) score) {
  T? best;
  num bestScore = double.negativeInfinity;
  for (final item in items) {
    final s = score(item);
    if (best == null || s > bestScore) {
      best = item;
      bestScore = s;
    }
  }
  return best as T;
}

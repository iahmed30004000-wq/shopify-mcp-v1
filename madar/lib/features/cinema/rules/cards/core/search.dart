/// Hard AI: information-set Monte Carlo over determinised worlds ("perfect
/// information Monte Carlo"), with a heuristic rollout policy.
///
/// Each iteration samples one world consistent with the observer's
/// knowledge, then plays every candidate move in that same world and rolls
/// the deal out with the fast policy. The candidate with the best mean score
/// wins. Too few samples (a tiny budget) fall back to the heuristic choice so
/// the hard AI is never weaker than its policy.
library;

import 'dart:math' as math;

import 'card_game.dart';

/// Game-specific hooks for [monteCarloChoose].
class SearchHooks<S extends CardGameState, M extends CardMove> {
  const SearchHooks({
    required this.sampleWorld,
    required this.apply,
    required this.policy,
    required this.done,
    required this.score,
    this.maxRolloutMoves = 400,
  });

  /// A copy of the root with hidden cards re-dealt from the observer's view.
  final S Function(math.Random rng) sampleWorld;
  final void Function(S state, M move) apply;

  /// Fast policy for every seat during rollouts.
  final M Function(S state, int seat, math.Random rng) policy;

  /// Stop the rollout (end of the deal, match over, …).
  final bool Function(S state) done;

  /// Value of a rolled-out state for the observer (higher is better).
  final double Function(S state) score;
  final int maxRolloutMoves;
}

/// Chooses among [candidates] by determinised rollouts. [fallback] (the
/// heuristic move) wins ties and is returned when the budget is too small.
M monteCarloChoose<S extends CardGameState, M extends CardMove>({
  required List<M> candidates,
  required SearchHooks<S, M> hooks,
  required math.Random rng,
  required AiBudget budget,
  required M fallback,
  int minWorlds = 2,
}) {
  if (candidates.length <= 1) return candidates.isEmpty ? fallback : candidates.first;
  final watch = Stopwatch()..start();
  final totals = List<double>.filled(candidates.length, 0);
  var worlds = 0;
  var simulations = 0;
  final values = List<double>.filled(candidates.length, 0);
  outer:
  while (true) {
    final world = hooks.sampleWorld(rng);
    for (var i = 0; i < candidates.length; i++) {
      if (simulations >= budget.maxSimulations || watch.elapsed >= budget.time) break outer;
      final s = world.copy() as S;
      hooks.apply(s, candidates[i]);
      var steps = 0;
      while (!hooks.done(s) && steps < hooks.maxRolloutMoves) {
        final seat = s.currentPlayer;
        if (seat == null) break;
        hooks.apply(s, hooks.policy(s, seat, rng));
        steps++;
      }
      values[i] = hooks.score(s);
      simulations++;
    }
    for (var i = 0; i < candidates.length; i++) {
      totals[i] += values[i];
    }
    worlds++;
  }
  // Only complete worlds are compared (every candidate saw the same worlds).
  if (worlds < minWorlds) return fallback;
  final fallbackIndex = candidates.indexOf(fallback);
  var best = fallbackIndex >= 0 ? fallbackIndex : 0;
  for (var i = 0; i < candidates.length; i++) {
    if (totals[i] > totals[best] + 1e-9) best = i;
  }
  return candidates[best];
}

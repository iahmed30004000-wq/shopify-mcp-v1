/// Backgammon AI: a hand-tuned positional evaluation (pip count, blot
/// exposure from exact shot counting, made points, primes, anchors, bar and
/// race handling) searched at 1 ply (medium) or 2-ply expectiminimax over
/// all 21 opponent rolls (hard), plus doubling-cube decisions.
///
/// The AI never looks at the game's RNG: chance is enumerated.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import '../core/engine.dart';
import '../core/game_types.dart';
import '../core/rng.dart';
import '../core/search.dart';
import 'backgammon_rules.dart';

/// The 21 distinct rolls and their weights out of 36.
final List<List<int>> _rolls = [
  for (var a = 1; a <= 6; a++)
    for (var b = a; b <= 6; b++) [a, b, a == b ? 1 : 2],
];

// Value of owning a made point (2+ checkers) at own pip n.
const List<double> _pointValue = [
  0, 3, 4, 6, 9, 11, 10, 8, 4, 2, 1, 1, 1, 1, 1, 1, 1, 1, 2, 3, 5, 6, 4, 3, 2, 0, //
];

/// Expected pips [me] loses to the opponent's next roll hitting its most
/// valuable exposed blot (exact over the 21 rolls; intermediate blocking
/// points and the opponent's need to enter from the bar are ignored).
double _blotRisk(Int8List me, Int8List opp) {
  // Distances from each blot to opponent checkers behind it.
  final blots = <int>[];
  for (var n = 1; n <= 24; n++) {
    if (me[n] == 1) blots.add(n);
  }
  if (blots.isEmpty) return 0;
  var expectedLoss = 0.0;
  for (final roll in _rolls) {
    final a = roll[0], b = roll[1];
    final reach = a == b ? [a, 2 * a, 3 * a, 4 * a] : [a, b, a + b];
    var worst = 0;
    for (final n in blots) {
      // Opponent checker at their pip m hits my pip n when m - (25 - n) is
      // a reachable distance; their bar is m = 25.
      final target = 25 - n;
      for (final dist in reach) {
        final m = target + dist;
        if (m > 25) continue;
        if (opp[m] > 0) {
          final loss = 25 - n + 6;
          if (loss > worst) worst = loss;
          break;
        }
      }
    }
    expectedLoss += worst * roll[2];
  }
  return expectedLoss / 36.0;
}

int _longestPrime(Int8List me) {
  var best = 0, run = 0;
  for (var n = 1; n <= 24; n++) {
    if (me[n] >= 2) {
      run++;
      if (run > best) best = run;
    } else {
      run = 0;
    }
  }
  return best;
}

int _homePointsClosed(Int8List me) {
  var c = 0;
  for (var n = 1; n <= 6; n++) {
    if (me[n] >= 2) c++;
  }
  return c;
}

int _pips(Int8List side) {
  var p = 0;
  for (var n = 1; n <= 25; n++) {
    p += side[n] * n;
  }
  return p;
}

int _highest(Int8List side) {
  for (var n = 25; n >= 1; n--) {
    if (side[n] > 0) return n;
  }
  return 0;
}

/// Evaluation in "pips" for side [me] versus [opp]; [meOnRoll] tells whose
/// roll is next (the other side's blots are the ones at risk).
double evaluateBackgammon(Int8List me, Int8List opp, {required bool meOnRoll}) {
  if (me[0] == 15) return 1000;
  if (opp[0] == 15) return -1000;
  final myPips = _pips(me), oppPips = _pips(opp);
  var score = (oppPips - myPips).toDouble();
  final contact = _highest(me) + _highest(opp) > 25;
  if (!contact) {
    // Pure race: pips plus bear-off efficiency.
    score += (meOnRoll ? 4 : -4);
    for (var n = 1; n <= 6; n++) {
      if (me[n] > 3) score -= (me[n] - 3) * 0.6;
      if (opp[n] > 3) score += (opp[n] - 3) * 0.6;
    }
    return score;
  }
  double side(Int8List x, Int8List y) {
    var s = 0.0;
    for (var n = 1; n <= 24; n++) {
      if (x[n] >= 2) s += _pointValue[n];
    }
    final prime = _longestPrime(x);
    if (prime >= 3) s += const [0, 0, 0, 3, 8, 15, 26][prime.clamp(0, 6)];
    if (y[25] > 0) s += y[25] * (2 + _homePointsClosed(x) * 3);
    s -= x[25] * 4;
    // Stacking penalty.
    for (var n = 1; n <= 24; n++) {
      if (x[n] > 4) s -= (x[n] - 4) * 1.5;
    }
    return s;
  }

  score += side(me, opp) - side(opp, me);
  if (meOnRoll) {
    score += _blotRisk(opp, me) * 1.1 - _blotRisk(me, opp) * 0.25;
  } else {
    score -= _blotRisk(me, opp) * 1.1 - _blotRisk(opp, me) * 0.25;
  }
  return score;
}

/// Rough probability that [me] wins from an evaluation.
double winProbability(double eval) => 1 / (1 + math.exp(-eval / 14));

final class BackgammonAi implements BoardAi<BackgammonState, BackgammonMove> {
  const BackgammonAi();

  @override
  BackgammonMove chooseMove(BackgammonState state, AiLevel level, BoardRng rng, [AiBudget budget = AiBudget.phone]) {
    final legal = backgammonRules.legalMoves(state);
    if (legal.isEmpty) throw StateError('no legal moves');
    final p = state.currentPlayer;
    switch (state.phase) {
      case BackgammonPhase.awaitingRoll:
        if (legal.length == 1 || level == AiLevel.easy) return BackgammonMove.roll;
        final board = BgBoard.fromState(state, p);
        final pWin = winProbability(evaluateBackgammon(board.a, board.b, meOnRoll: true));
        return pWin >= 0.70 ? BackgammonMove.offerDouble : BackgammonMove.roll;
      case BackgammonPhase.doubleOffered:
        if (level == AiLevel.easy) return BackgammonMove.take;
        final board = BgBoard.fromState(state, p);
        // The doubler is about to roll.
        final pWin = winProbability(evaluateBackgammon(board.a, board.b, meOnRoll: false));
        return pWin >= 0.24 ? BackgammonMove.take : BackgammonMove.drop;
      case BackgammonPhase.moving:
        break;
    }
    if (legal.length == 1) return legal.first;
    final plays = generatePlays(BgBoard.fromState(state, p), state.dice);
    // Map plays back to the public moves (same order as legalMoves).
    double oneply(BgPlay play) => evaluateBackgammon(play.result.a, play.result.b, meOnRoll: false);
    final scores = [for (final play in plays) oneply(play)];

    switch (level) {
      case AiLevel.easy:
        if (rng.nextInt(100) < 35) return rng.pick(legal);
        return legal[_argmax([for (final s in scores) s + (rng.nextDouble() - 0.5) * 30])];
      case AiLevel.medium:
        return legal[_argmax([for (final s in scores) s + (rng.nextDouble() - 0.5) * 2])];
      case AiLevel.hard:
        return legal[_twoPly(plays, scores, SearchClock(budget))];
    }
  }

  static int _argmax(List<double> xs) {
    var best = 0;
    for (var i = 1; i < xs.length; i++) {
      if (xs[i] > xs[best]) best = i;
    }
    return best;
  }

  /// Expectiminimax: my play → every opponent roll → opponent's best reply
  /// (by the 1-ply evaluation). Candidates are the best 1-ply plays; a
  /// candidate is only compared once it has been fully averaged.
  int _twoPly(List<BgPlay> plays, List<double> oneply, SearchClock clock) {
    final order = List<int>.generate(plays.length, (i) => i)..sort((x, y) => oneply[y].compareTo(oneply[x]));
    final candidates = order.take(6).toList();
    var best = candidates.first;
    var bestValue = double.negativeInfinity;
    for (final ci in candidates) {
      final after = plays[ci].result.swapped(); // opponent to move
      var expected = 0.0;
      var aborted = false;
      for (final roll in _rolls) {
        final replies = generatePlays(after, [roll[0], roll[1]]);
        var bestReply = double.negativeInfinity;
        if (replies.isEmpty) {
          bestReply = evaluateBackgammon(after.a, after.b, meOnRoll: false);
        }
        for (final r in replies) {
          clock.tick();
          final v = evaluateBackgammon(r.result.a, r.result.b, meOnRoll: false);
          if (v > bestReply) bestReply = v;
        }
        expected -= bestReply * roll[2] / 36.0;
        if (clock.stopped) {
          aborted = true;
          break;
        }
      }
      if (aborted) break;
      if (expected > bestValue) {
        bestValue = expected;
        best = ci;
      }
    }
    return best;
  }
}

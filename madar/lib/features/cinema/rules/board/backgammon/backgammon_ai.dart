/// طاولة الزهر AI for all three games: a hand-tuned positional evaluation
/// per variant searched at 1 ply (medium) or 2-ply expectiminimax over all
/// 21 opponent rolls (hard), plus doubling-cube decisions (شيش بيش only).
///
/// * شيش بيش: pip count, blot exposure from exact shot counting, made
///   points, primes, anchors, bar and race handling.
/// * محبوسة: pip count, pinned checkers (own −, opponent +, weighted by how
///   far from home they are stuck), the mothers, points held in front of
///   opposing checkers, and the exact risk of a lone checker being pinned.
/// * ٣١: pip race, points held in the opponent's path and blocks, the runner
///   rule for both sides, stacking.
///
/// The AI never looks at the game's RNG: chance is enumerated.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import '../core/engine.dart';
import '../core/game_types.dart';
import '../core/rng.dart';
import '../core/search.dart';
import 'backgammon_board.dart';
import 'backgammon_rules.dart';

/// The 21 distinct rolls and their weights out of 36.
final List<List<int>> _rolls = [
  for (var a = 1; a <= 6; a++)
    for (var b = a; b <= 6; b++) [a, b, a == b ? 1 : 2],
];

List<int> _reach(int a, int b) => a == b ? [a, 2 * a, 3 * a, 4 * a] : [a, b, a + b];

final List<List<int>> _reaches = [for (final r in _rolls) _reach(r[0], r[1])];

// ---------------------------------------------------------------------------
// شيش بيش

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
  for (var r = 0; r < _rolls.length; r++) {
    final reach = _reaches[r];
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
    expectedLoss += worst * _rolls[r][2];
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

/// شيش بيش evaluation in "pips" for side [me] versus [opp]; [meOnRoll]
/// tells whose roll is next (the other side's blots are the ones at risk).
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

// ---------------------------------------------------------------------------
// محبوسة

/// What a pinned mother (the last checker on the own start point) costs:
/// its owner can no longer bear off, which almost always means «مارس».
const double _motherValue = 40;

/// Cost of one checker pinned on its owner's pip [n]: the farther from
/// home, the longer it is stuck and the longer it blocks bearing off.
double _pinCost(int n) => 6 + n * 0.9;

/// Points [x] holds against [y] (2+ checkers, or a pin [x] controls), valued
/// by how many of [y]'s checkers still have to pass them, plus blocks.
double _pinPoints(Int8List x, Int8List y, Int8List yPinned, BgMode mode) {
  var s = 0.0;
  var run = 0, best = 0;
  // Walk [y]'s route from its start (y pip 24) to its home (y pip 1).
  var behind = 0; // y's free checkers already behind the current point
  for (var m = 24; m >= 1; m--) {
    final n = mode.mirror(m);
    final held = x[n] >= 2 || (x[n] >= 1 && yPinned[m] == 1);
    if (held && behind > 0) {
      s += 0.8 + 0.12 * behind;
      run++;
      if (run > best) best = run;
    } else {
      run = 0;
    }
    behind += y[m];
  }
  if (best >= 2) s += const [0, 0, 1, 3, 6, 10, 16][best.clamp(0, 6)];
  // Stacking penalty (the start stack is exempt: it is the reserve).
  for (var n = 1; n <= 23; n++) {
    if (x[n] > 4) s -= (x[n] - 4) * 0.8;
  }
  return s;
}

/// Expected loss of [x] to [y]'s next roll pinning its most valuable lone
/// checker (exact over the 21 rolls; intermediate points ignored).
double _pinRisk(Int8List x, Int8List y, Int8List yPinned, BgMode mode) {
  final lone = <int>[];
  for (var n = 1; n <= 24; n++) {
    // A lone checker on top of a pinned opposing checker is safe.
    if (x[n] == 1 && yPinned[mode.mirror(n)] == 0) lone.add(n);
  }
  if (lone.isEmpty) return 0;
  var expected = 0.0;
  for (var r = 0; r < _rolls.length; r++) {
    final reach = _reaches[r];
    var worst = 0.0;
    for (final n in lone) {
      final target = mode.mirror(n); // the point in y's numbering
      for (final dist in reach) {
        final m = target + dist;
        if (m > 24) break;
        if (y[m] > 0) {
          final loss = _pinCost(n) + (n == 24 ? _motherValue : 0);
          if (loss > worst) worst = loss;
          break;
        }
      }
    }
    expected += worst * _rolls[r][2];
  }
  return expected / 36.0;
}

double _evaluatePinning(BgBoard bd, bool meOnRoll) {
  final me = bd.a, opp = bd.b, myPins = bd.pa, oppPins = bd.pb, mode = bd.mode;
  if (me[0] == 15) return 1000;
  if (opp[0] == 15) return -1000;
  final myMother = myPins[24] == 1, theirMother = oppPins[24] == 1;
  if (myMother && theirMother) return 0; // a void game
  var score = (bd.opponentPips - bd.moverPips).toDouble() + (meOnRoll ? 4 : -4);
  if (theirMother) score += _motherValue;
  if (myMother) score -= _motherValue;
  for (var n = 1; n <= 24; n++) {
    if (oppPins[n] == 1) score += _pinCost(n);
    if (myPins[n] == 1) score -= _pinCost(n);
  }
  score += _pinPoints(me, opp, oppPins, mode) - _pinPoints(opp, me, myPins, mode);
  final myRisk = _pinRisk(me, opp, oppPins, mode), theirRisk = _pinRisk(opp, me, myPins, mode);
  score += meOnRoll ? theirRisk - myRisk * 0.25 : theirRisk * 0.25 - myRisk;
  return score;
}

// ---------------------------------------------------------------------------
// ٣١

/// Points [x] occupies (any count closes a point) in front of [y]'s
/// checkers, plus blocks of consecutive points.
double _blockPoints(Int8List x, Int8List y, BgMode mode) {
  var s = 0.0;
  var run = 0, best = 0;
  var behind = 0;
  for (var m = 24; m >= 1; m--) {
    final n = mode.mirror(m);
    if (x[n] > 0 && behind > 0) {
      s += 0.6 + 0.1 * behind;
      run++;
      if (run > best) best = run;
    } else {
      run = 0;
    }
    behind += y[m];
  }
  if (best >= 2) s += const [0, 0, 0.5, 2, 5, 10, 18][best.clamp(0, 6)];
  for (var n = 1; n <= 23; n++) {
    if (x[n] > 4) s -= (x[n] - 4) * 0.5;
  }
  return s;
}

bool _runnerActive(Int8List x, int target) {
  if (target == 0 || x[0] > 0) return false;
  for (var n = 1; n <= target; n++) {
    if (x[n] > 0) return false;
  }
  return true;
}

double _evaluateBlocking(BgBoard bd, bool meOnRoll) {
  final me = bd.a, opp = bd.b, mode = bd.mode;
  if (me[0] == 15) return 1000;
  if (opp[0] == 15) return -1000;
  var score = (_pips(opp) - _pips(me)).toDouble() + (meOnRoll ? 4 : -4);
  score += _blockPoints(me, opp, mode) - _blockPoints(opp, me, mode);
  // While the runner rule holds, the other fourteen checkers are frozen.
  if (_runnerActive(me, mode.runnerTarget)) score -= 6;
  if (_runnerActive(opp, mode.runnerTarget)) score += 6;
  return score;
}

/// Evaluation in pips of [board] for its mover (`a`); [meOnRoll] tells
/// whether the mover rolls next.
double evaluateTawla(BgBoard board, {required bool meOnRoll}) => switch (board.mode.landing) {
  BgLanding.hit => evaluateBackgammon(board.a, board.b, meOnRoll: meOnRoll),
  BgLanding.pin => _evaluatePinning(board, meOnRoll),
  BgLanding.block => _evaluateBlocking(board, meOnRoll),
};

/// Rough probability that [me] wins from an evaluation.
double winProbability(double eval) => 1 / (1 + math.exp(-eval / 14));

/// How [play] ends the game by any rule (15 off, the mother rule, a void
/// game), or null when the game goes on.
({bool? moverWon, int points, TawlaGameEnd end})? _playEnd(
  BgPlay play,
  BackgammonConfig cfg, {
  required int cubeValue,
  required int turns,
}) => BackgammonRules.playEnd(cfg, play.result, cubeValue: cubeValue, turns: turns, passed: play.from.isEmpty);

/// A win is worth more than any position, and more with every point it
/// scores, so the biggest finish is chosen (e.g. hitting on the way off
/// under `triple: barOnly`).
const double _winValue = 1000, _winPointValue = 100;

/// The value of a play for its mover: the evaluation of the position it
/// leaves or, when the play ends the game, the outcome itself. A void game
/// is replayed from scratch and counts as even.
double _playValue(BgPlay play, BackgammonConfig cfg, {required int cubeValue, required int turns}) {
  final end = _playEnd(play, cfg, cubeValue: cubeValue, turns: turns);
  if (end == null) return evaluateTawla(play.result, meOnRoll: false);
  final won = end.moverWon;
  if (won == null) return 0;
  final value = _winValue + _winPointValue * end.points;
  return won ? value : -value;
}

final class BackgammonAi implements BoardAi<BackgammonState, BackgammonMove> {
  const BackgammonAi();

  @override
  BackgammonMove chooseMove(BackgammonState state, AiLevel level, BoardRng rng, [AiBudget budget = AiBudget.phone]) {
    final legal = backgammonRules.legalMoves(state);
    if (legal.isEmpty) throw StateError('no legal moves');
    if (legal.length == 1) return legal.first;
    final p = state.currentPlayer;
    switch (state.phase) {
      case BackgammonPhase.awaitingRoll:
        if (level == AiLevel.easy) return BackgammonMove.roll;
        final pWin = winProbability(evaluateTawla(boardFor(state, p), meOnRoll: true));
        return pWin >= 0.70 ? BackgammonMove.offerDouble : BackgammonMove.roll;
      case BackgammonPhase.doubleOffered:
        if (level == AiLevel.easy) return BackgammonMove.take;
        // The doubler is about to roll.
        final pWin = winProbability(evaluateTawla(boardFor(state, p), meOnRoll: false));
        return pWin >= 0.24 ? BackgammonMove.take : BackgammonMove.drop;
      case BackgammonPhase.gameOver:
        return BackgammonMove.nextGame;
      case BackgammonPhase.moving:
        break;
    }
    final cfg = state.config;
    final plays = generatePlays(boardFor(state, p), state.dice);
    // Plays come in the same order as legalMoves.
    final turns = state.turns + 1;
    final scores = [for (final play in plays) _playValue(play, cfg, cubeValue: state.cubeValue, turns: turns)];

    switch (level) {
      case AiLevel.easy:
        if (rng.nextInt(100) < 35) return rng.pick(legal);
        return legal[_argmax([for (final s in scores) s + (rng.nextDouble() - 0.5) * 30])];
      case AiLevel.medium:
        return legal[_argmax([for (final s in scores) s + (rng.nextDouble() - 0.5) * 2])];
      case AiLevel.hard:
        return legal[_twoPly(plays, scores, cfg, state.cubeValue, turns, SearchClock(budget))];
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
  /// (by the 1-ply value). Candidates are the best 1-ply plays; a candidate
  /// is only compared once it has been fully averaged. A winning play is
  /// taken at once (the one scoring most, as [oneply] ranks it); a play that
  /// ends the game otherwise (a void) keeps its outcome value unsearched.
  int _twoPly(
    List<BgPlay> plays,
    List<double> oneply,
    BackgammonConfig cfg,
    int cubeValue,
    int turns,
    SearchClock clock,
  ) {
    final order = List<int>.generate(plays.length, (i) => i)..sort((x, y) => oneply[y].compareTo(oneply[x]));
    final ends = [for (final play in plays) _playEnd(play, cfg, cubeValue: cubeValue, turns: turns)];
    for (final i in order) {
      if (ends[i]?.moverWon ?? false) return i; // the highest-scoring win
    }
    final candidates = order.take(6).toList();
    var best = candidates.first;
    var bestValue = double.negativeInfinity;
    for (final ci in candidates) {
      if (ends[ci] != null) {
        // A void (or lost) game: its outcome value, nothing to search.
        if (oneply[ci] > bestValue) {
          bestValue = oneply[ci];
          best = ci;
        }
        continue;
      }
      final after = plays[ci].result.swapped(); // opponent to move
      var expected = 0.0;
      var aborted = false;
      for (final roll in _rolls) {
        final replies = generatePlays(after, [roll[0], roll[1]]);
        var bestReply = double.negativeInfinity;
        for (final r in replies) {
          clock.tick();
          final v = _playValue(r, cfg, cubeValue: cubeValue, turns: turns + 1);
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

/// Ludo AI, for every [LudoConfig] (safe pairs, blockades, capture before
/// home, partnerships…).
///
/// * easy – random legal move;
/// * medium – priorities: capture, reach home, leave the yard, escape
///   danger, advance the leading token;
/// * hard – a one-roll lookahead (expectimax): for each candidate it averages
///   over the six faces of the next roll (the next player's or its own after
///   a bonus roll), lets that player pick their best move, and scores the
///   result with a position evaluation: progress of all tokens, exact
///   capture risk from every opponent token (and yard exits) within six
///   squares behind, safe squares and safe pairs, captures (worth more while
///   a capture is still needed to enter home), and the opponents'
///   threatened material; partners count as one side. In a free-for-all
///   with 3–4 players it deepens through the other opponents' rolls while
///   the budget lasts (iterative deepening). When the budget runs out
///   before the first roll is searched it keeps the one-ply evaluation.
///
/// Decisions only concern [LudoState.movingPlayer]'s tokens; rolls and
/// forced passes are single legal moves.
library;

import '../core/engine.dart';
import '../core/game_types.dart';
import '../core/rng.dart';
import '../core/search.dart';
import 'ludo_rules.dart';

final class LudoAi implements BoardAi<LudoState, LudoMove> {
  const LudoAi();

  @override
  LudoMove chooseMove(LudoState state, AiLevel level, BoardRng rng, [AiBudget budget = AiBudget.phone]) {
    final legal = ludoRules.legalMoves(state);
    if (legal.isEmpty) throw StateError('no legal moves');
    if (legal.length == 1) return legal.first;
    switch (level) {
      case AiLevel.easy:
        return rng.pick(legal);
      case AiLevel.medium:
        return _best(state, legal, _priority);
      case AiLevel.hard:
        return _lookahead(state, legal, SearchClock(budget));
    }
  }

  static const double _win = 100000;

  /// One-ply evaluation first (always completes), then one roll deeper. In
  /// a free-for-all with 3–4 players the search then deepens through the
  /// following opponents' rolls, up to `players − 1` rolls, while the budget
  /// lasts; the deepest fully searched choice wins (iterative deepening).
  /// With two players or partnerships the depth stays at one roll.
  LudoMove _lookahead(LudoState s, List<LudoMove> legal, SearchClock clock) {
    var best = _best(s, legal, _evaluateMove);
    final me = s.currentPlayer;
    final maxDepth = s.config.teams ? 1 : s.config.players - 1;
    for (var depth = 1; depth <= maxDepth; depth++) {
      LudoMove? choice;
      var bestValue = double.negativeInfinity;
      for (final m in legal) {
        if (clock.checkTime()) break;
        final v = _chance(ludoRules.apply(s, m), me, clock, depth);
        if (v > bestValue) {
          bestValue = v;
          choice = m;
        }
      }
      // A depth cut short by the budget is discarded.
      if (clock.stopped || choice == null) break;
      best = choice;
    }
    return best;
  }

  /// Expected value for [me] over the next roll from [after] (awaiting a
  /// roll): the player on roll picks their best move for each face. With
  /// [depth] > 1 the rolls that follow are averaged too, until it is [me]'s
  /// turn again.
  double _chance(LudoState after, int me, SearchClock clock, int depth) {
    if (after.isOver) return after.result!.winners.contains(me) ? _win : -_win;
    var sum = 0.0;
    for (var d = 1; d <= 6; d++) {
      clock.tick();
      final st = after.copyWith(
        phase: LudoPhase.awaitingMove,
        dice: d,
        consecutiveSixes: d == 6 ? after.consecutiveSixes + 1 : 0,
      );
      final moves = ludoRules.legalMoves(st);
      final LudoState res;
      if (moves.first.kind == LudoMoveKind.pass) {
        if (depth <= 1) {
          sum += _positionValue(after, after.tokens, me);
          continue;
        }
        res = ludoRules.apply(st, moves.first);
      } else {
        // The player on roll plays their own best move (by the one-ply
        // evaluation); for [me] or a partner that is also best for [me].
        var choice = moves.first;
        if (moves.length > 1) choice = _best(st, moves, _evaluateMove);
        res = ludoRules.apply(st, choice);
      }
      if (res.isOver) {
        sum += res.result!.winners.contains(me) ? _win : -_win;
      } else if (depth > 1 && res.currentPlayer != me) {
        sum += _chance(res, me, clock, depth - 1);
      } else {
        sum += _positionValue(res, res.tokens, me);
      }
    }
    return sum / 6;
  }

  LudoMove _best(LudoState s, List<LudoMove> legal, double Function(LudoState, int) score) {
    var best = legal.first;
    var bestScore = double.negativeInfinity;
    for (final m in legal) {
      final v = score(s, m.token);
      if (v > bestScore) {
        bestScore = v;
        best = m;
      }
    }
    return best;
  }

  double _priority(LudoState s, int token) {
    final q = s.movingPlayer;
    final step = LudoRules.stepFor(s, q, token, s.dice)!;
    final from = s.tokens[q][token];
    if (step.captures.isNotEmpty) return 1000.0 + _distance(step.target);
    if (step.target == kLudoHome) return 900;
    if (from == kLudoYard) return 800;
    final dangerNow = _threats(s, q, s.tokens, s.absoluteSquare(q, from)) > 0;
    final dangerAfter =
        LudoState.onTrack(step.target) && _threats(s, q, s.tokens, s.absoluteSquare(q, step.target)) > 0;
    final d = _distance(from);
    if (dangerNow && !dangerAfter) return 700.0 + d;
    return d + (dangerAfter ? -60.0 : 0.0) + (step.target > kLudoLastTrack && step.target <= kLudoHome ? 30.0 : 0.0);
  }

  /// Squares travelled from the start, counting a lap in progress.
  static double _distance(int progress) {
    if (progress == kLudoBeforeStart) return 51;
    if (progress < 0) return 0;
    return progress.toDouble();
  }

  /// Number of opponent tokens that could land on absolute square [sq]
  /// with one die (0 when the square is safe, off the track, or holds a
  /// protected pair of [player]'s colour).
  static int _threats(LudoState s, int player, List<List<int>> tokens, int sq) {
    final cfg = s.config;
    if (sq < 0 || cfg.isSafe(sq)) return 0;
    if (cfg.pairsAreSafe) {
      var mine = 0;
      for (final t in tokens[player]) {
        if (s.absoluteSquare(player, t) == sq) mine++;
      }
      if (mine >= 2) return 0;
    }
    var n = 0;
    for (var o = 0; o < cfg.players; o++) {
      if (cfg.allies(o, player)) continue;
      final laps = s.mustLap(o);
      for (final t in tokens[o]) {
        if (t == kLudoYard) {
          // A yard token threatens its own start square via an exit roll.
          if (s.absoluteSquare(o, 0) == sq) n++;
          continue;
        }
        if (!LudoState.onTrack(t)) continue;
        final from = s.absoluteSquare(o, t);
        final dist = (sq - from + 52) % 52;
        if (dist < 1 || dist > 6) continue;
        // It must still be on its lap (not turning into its home column).
        if (t == kLudoBeforeStart || laps || t + dist <= kLudoLastTrack) n++;
      }
    }
    return n;
  }

  double _tokenValue(LudoState s, int player, int progress) {
    if (progress == kLudoYard) return 0;
    if (progress == kLudoHome) return 80;
    if (progress == kLudoBeforeStart) return 40; // a lap still to go
    if (progress > kLudoLastTrack) return 55.0 + (progress - kLudoLastTrack) * 3; // home column: safe
    // Without the capture that opens the column, the end of the lap is
    // worth little more than the middle.
    if (s.mustLap(player)) return 10.0 + (progress > 40 ? 40 : progress);
    return 10.0 + progress;
  }

  double _sideValue(LudoState s, List<List<int>> tokens, int q) {
    var v = 0.0;
    for (final t in tokens[q]) {
      v += _tokenValue(s, q, t);
      if (LudoState.onTrack(t)) {
        final threats = _threats(s, q, tokens, s.absoluteSquare(q, t));
        if (threats > 0) {
          final risk = (threats / 6).clamp(0.0, 0.9);
          v -= risk * (_tokenValue(s, q, t) + 6);
        }
      }
    }
    return v;
  }

  double _positionValue(LudoState s, List<List<int>> tokens, int p) {
    final cfg = s.config;
    final values = [for (var q = 0; q < cfg.players; q++) _sideValue(s, tokens, q)];
    if (cfg.teams) {
      final mine = values[p] + values[(p + 2) % 4];
      final theirs = values[(p + 1) % 4] + values[(p + 3) % 4];
      return mine - 0.5 * theirs;
    }
    var theirs = 0.0;
    for (var q = 0; q < cfg.players; q++) {
      if (q != p && values[q] > theirs) theirs = values[q]; // the strongest opponent matters most
    }
    return values[p] - 0.5 * theirs;
  }

  double _evaluateMove(LudoState s, int token) {
    final q = s.movingPlayer;
    final step = LudoRules.stepFor(s, q, token, s.dice)!;
    final tokens = [for (final t in s.tokens) List<int>.of(t)];
    tokens[q][token] = step.target;
    var bonus = 0.0;
    for (var i = 0; i < step.captures.length; i += 2) {
      final o = step.captures[i];
      bonus += 12 + _tokenValue(s, o, tokens[o][step.captures[i + 1]]) * 0.8;
      tokens[o][step.captures[i + 1]] = kLudoYard;
    }
    // The first capture opens the home column.
    if (step.captures.isNotEmpty && s.mustLap(q)) bonus += 30;
    final cfg = s.config;
    final again =
        (s.dice == 6 && cfg.extraTurnOnSix) ||
        (step.captures.isNotEmpty && cfg.extraTurnOnCapture) ||
        (step.target == kLudoHome && cfg.extraTurnOnHome);
    if (again) bonus += 6;
    // Evaluate as the side of the player to act (partners share it).
    final probe = step.captures.isNotEmpty && s.mustLap(q) ? _withCaptured(s, q) : s;
    return _positionValue(probe, tokens, s.currentPlayer) + bonus;
  }

  static LudoState _withCaptured(LudoState s, int q) => s.copyWith(captured: [...s.captured]..[q] = true);
}

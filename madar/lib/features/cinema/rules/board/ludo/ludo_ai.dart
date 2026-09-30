/// Ludo AI.
///
/// * easy – random legal move;
/// * medium – priorities: capture, reach home, leave the yard, escape
///   danger, advance the leading token;
/// * hard – evaluates every resulting position: progress of all tokens,
///   exact capture risk from every opponent token (and yard exits) within
///   six squares behind, safe squares, captures, extra turns, and the
///   opponents' threatened material.
library;

import '../core/engine.dart';
import '../core/game_types.dart';
import '../core/rng.dart';
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
        return _best(state, legal, _evaluateMove);
    }
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
    final p = s.currentPlayer;
    final step = LudoRules.stepFor(s, p, token, s.dice)!;
    final from = s.tokens[p][token];
    if (step.captures.isNotEmpty) return 1000.0 + step.target;
    if (step.target == kLudoHome) return 900;
    if (from == kLudoYard) return 800;
    final dangerNow = _threats(s, p, s.absoluteSquare(p, from)) > 0;
    final dangerAfter = step.target <= kLudoLastTrack && _threats(s, p, s.absoluteSquare(p, step.target)) > 0;
    if (dangerNow && !dangerAfter) return 700.0 + from;
    return from + (dangerAfter ? -60.0 : 0.0) + (step.target > kLudoLastTrack ? 30.0 : 0.0);
  }

  /// Number of opponent tokens that could land on absolute square [sq] with
  /// one die (0 when the square is safe or off the track).
  static int _threats(LudoState s, int player, int sq) {
    if (sq < 0 || s.config.isSafe(sq)) return 0;
    var n = 0;
    for (var o = 0; o < s.config.players; o++) {
      if (o == player) continue;
      for (final t in s.tokens[o]) {
        if (t < 0 || t > kLudoLastTrack) {
          // A yard token threatens its own start square via an exit roll.
          if (t == kLudoYard && s.absoluteSquare(o, 0) == sq) n++;
          continue;
        }
        final from = s.absoluteSquare(o, t);
        final dist = (sq - from + 52) % 52;
        // It must still be on its lap (not turning into its home column).
        if (dist >= 1 && dist <= 6 && t + dist <= kLudoLastTrack) n++;
      }
    }
    return n;
  }

  double _tokenValue(int progress) {
    if (progress == kLudoYard) return 0;
    if (progress == kLudoHome) return 80;
    if (progress > kLudoLastTrack) return 55.0 + (progress - kLudoLastTrack) * 3; // home column: safe
    return 10.0 + progress;
  }

  double _positionValue(LudoState s, List<List<int>> tokens, int p) {
    final probe = s.copyWith(tokens: tokens);
    var mine = 0.0, theirs = 0.0;
    for (var q = 0; q < s.config.players; q++) {
      var v = 0.0;
      for (final t in tokens[q]) {
        v += _tokenValue(t);
        if (t >= 0 && t <= kLudoLastTrack) {
          final threats = _threats(probe, q, probe.absoluteSquare(q, t));
          if (threats > 0) {
            final risk = (threats / 6).clamp(0.0, 0.9);
            v -= risk * (_tokenValue(t) + 6);
          }
        }
      }
      if (q == p) {
        mine = v;
      } else if (v > theirs) {
        theirs = v; // the strongest opponent matters most
      }
    }
    return mine - 0.5 * theirs;
  }

  double _evaluateMove(LudoState s, int token) {
    final p = s.currentPlayer;
    final step = LudoRules.stepFor(s, p, token, s.dice)!;
    final tokens = [for (final t in s.tokens) List<int>.of(t)];
    tokens[p][token] = step.target;
    var bonus = 0.0;
    for (var i = 0; i < step.captures.length; i += 2) {
      bonus += 12 + _tokenValue(tokens[step.captures[i]][step.captures[i + 1]]) * 0.8;
      tokens[step.captures[i]][step.captures[i + 1]] = kLudoYard;
    }
    final cfg = s.config;
    final again =
        (s.dice == 6 && cfg.extraTurnOnSix) ||
        (step.captures.isNotEmpty && cfg.extraTurnOnCapture) ||
        (step.target == kLudoHome && cfg.extraTurnOnHome);
    if (again) bonus += 6;
    return _positionValue(s, tokens, p) + bonus;
  }
}

/// Dominoes AI.
///
/// * easy – a random legal play;
/// * medium – a heuristic: shed heavy tiles and doubles, keep variety and
///   control of the ends, exploit known voids of the next opponent;
/// * hard – determinised Monte-Carlo: unseen tiles are dealt at random to
///   the other hands / boneyard (respecting public voids), each candidate is
///   played out with the medium policy for everyone, and the play with the
///   best average round score for the AI's side wins.
///
/// Only the AI's own hand and public information are read.
library;

import '../core/engine.dart';
import '../core/game_types.dart';
import '../core/rng.dart';
import '../core/search.dart';
import 'dominoes_rules.dart';

final List<int> _low = [for (final t in Domino.doubleSix) t.low];
final List<int> _high = [for (final t in Domino.doubleSix) t.high];

bool _matches(int id, int n) => _low[id] == n || _high[id] == n;
int _other(int id, int n) => _low[id] == n ? _high[id] : _low[id];

/// Heuristic value of playing tile [id] making ends ([l], [r]) from the
/// mover's point of view.
double _playValue(int id, int newLeft, int newRight, List<int> handAfter, int nextVoids, int partnerVoids) {
  var v = (_low[id] + _high[id]).toDouble();
  if (_low[id] == _high[id]) v += 4;
  // Variety and control: numbers still held, tiles matching the new ends.
  var seen = 0, control = 0;
  for (final t in handAfter) {
    seen |= (1 << _low[t]) | (1 << _high[t]);
    if (_matches(t, newLeft) || _matches(t, newRight)) control++;
  }
  var variety = 0;
  for (var n = 0; n <= 6; n++) {
    if (seen & (1 << n) != 0) variety++;
  }
  v += variety * 1.5 + control * 2.0;
  // Block the next opponent on numbers they are known to lack.
  if (nextVoids & (1 << newLeft) != 0) v += 3;
  if (nextVoids & (1 << newRight) != 0) v += 3;
  if (partnerVoids & (1 << newLeft) != 0) v -= 2;
  if (partnerVoids & (1 << newRight) != 0) v -= 2;
  return v;
}

final class DominoAi implements BoardAi<DominoState, DominoMove> {
  const DominoAi();

  @override
  DominoMove chooseMove(DominoState state, AiLevel level, BoardRng rng, [AiBudget budget = AiBudget.phone]) {
    final legal = dominoRules.legalMoves(state);
    if (legal.isEmpty) throw StateError('no legal moves');
    if (legal.length == 1) return legal.first;
    switch (level) {
      case AiLevel.easy:
        return rng.pick(legal);
      case AiLevel.medium:
        return _heuristic(state, legal);
      case AiLevel.hard:
        return _monteCarlo(state, legal, rng, SearchClock(budget));
    }
  }

  DominoMove _heuristic(DominoState s, List<DominoMove> legal) {
    final p = s.currentPlayer;
    final n = s.config.players;
    final hand = [for (final t in s.hands[p]) t.id];
    final nextVoids = s.voids[(p + 1) % n];
    final partnerVoids = s.config.teams ? s.voids[(p + 2) % n] : 0;
    var best = legal.first;
    var bestValue = double.negativeInfinity;
    for (final m in legal) {
      final id = m.tile!.id;
      final (l, r) = _endsAfter(s.leftEnd, s.rightEnd, id, m.end!, s.line.isEmpty);
      final after = [...hand]..remove(id);
      final v = _playValue(id, l, r, after, nextVoids, partnerVoids);
      if (v > bestValue) {
        bestValue = v;
        best = m;
      }
    }
    return best;
  }

  static (int, int) _endsAfter(int l, int r, int id, DominoEnd end, bool empty) {
    if (empty) return (_low[id], _high[id]);
    return end == DominoEnd.left ? (_other(id, l), r) : (l, _other(id, r));
  }

  DominoMove _monteCarlo(DominoState s, List<DominoMove> legal, BoardRng rng, SearchClock clock) {
    final me = s.currentPlayer;
    final cfg = s.config;
    final known = <int>{for (final t in s.hands[me]) t.id, for (final p in s.line) p.tile.id};
    final unseen = [
      for (var id = 0; id < 28; id++)
        if (!known.contains(id)) id,
    ];
    final totals = List<double>.filled(legal.length, 0);
    var worlds = 0;
    while (worlds < 2 || (!clock.stopped && worlds < 400)) {
      final world = _sampleWorld(s, unseen, rng);
      for (var i = 0; i < legal.length; i++) {
        final sim = _Sim(s, world, cfg);
        sim.play(me, legal[i]);
        totals[i] += sim.run(me, clock);
      }
      worlds++;
    }
    var best = 0;
    for (var i = 1; i < legal.length; i++) {
      if (totals[i] > totals[best]) best = i;
    }
    // Tie-break with the heuristic ordering for stability.
    if (totals.every((t) => t == totals[0])) return _heuristic(s, legal);
    return legal[best];
  }

  /// Deals the unseen tiles into the other hands (sizes known) and the
  /// boneyard, honouring voids where possible.
  List<List<int>> _sampleWorld(DominoState s, List<int> unseen, BoardRng rng) {
    final me = s.currentPlayer;
    final n = s.config.players;
    for (var attempt = 0; attempt < 20; attempt++) {
      final pool = [...unseen];
      rng.shuffle(pool);
      final hands = List<List<int>>.generate(n, (p) => p == me ? [for (final t in s.hands[me]) t.id] : <int>[]);
      var ok = true;
      // Most constrained players first.
      final order = [
        for (var p = 0; p < n; p++)
          if (p != me) p,
      ]..sort((a, b) => _bits(s.voids[b]) - _bits(s.voids[a]));
      for (final p in order) {
        final need = s.hands[p].length;
        final strict = attempt < 19;
        for (var i = 0; i < pool.length && hands[p].length < need;) {
          final t = pool[i];
          final v = s.voids[p];
          if (!strict || (v & (1 << _low[t]) == 0 && v & (1 << _high[t]) == 0)) {
            hands[p].add(t);
            pool.removeAt(i);
          } else {
            i++;
          }
        }
        if (hands[p].length < need) ok = false;
      }
      if (!ok) continue;
      hands.add(pool); // boneyard (last entry)
      return hands;
    }
    // Unreachable: the last attempt ignores voids.
    throw StateError('could not sample');
  }

  static int _bits(int v) {
    var c = 0;
    for (; v != 0; v &= v - 1) {
      c++;
    }
    return c;
  }
}

/// A fast mutable round simulation on tile ids.
final class _Sim {
  _Sim(DominoState s, List<List<int>> world, this.cfg)
    : hands = [for (var p = 0; p < cfg.players; p++) List<int>.of(world[p])],
      boneyard = List<int>.of(world[cfg.players]),
      left = s.leftEnd,
      right = s.rightEnd,
      empty = s.line.isEmpty,
      mustLead = s.mustLead?.id ?? -1,
      voids = List<int>.of(s.voids);

  final DominoConfig cfg;
  final List<List<int>> hands;
  final List<int> boneyard;
  final List<int> voids;
  int left, right;
  bool empty;
  int mustLead;
  int passes = 0;

  void play(int p, DominoMove m) {
    final id = m.tile!.id;
    _place(p, id, m.end == DominoEnd.left);
  }

  void _place(int p, int id, bool atLeft) {
    hands[p].remove(id);
    if (empty) {
      left = _low[id];
      right = _high[id];
      empty = false;
    } else if (atLeft) {
      left = _other(id, left);
    } else {
      right = _other(id, right);
    }
    mustLead = -1;
    passes = 0;
  }

  /// Plays the round out from the player after the last mover; returns the
  /// round score for [me]'s side (positive = won points).
  double run(int me, SearchClock clock) {
    final n = cfg.players;
    // Who moved last: find the player after `me` (we just played for me).
    var p = (me + 1) % n;
    if (hands[me].isEmpty) return _score(me, me);
    for (var guard = 0; guard < 200; guard++) {
      clock.tick();
      // Best playable tile by the heuristic, else draw / pass.
      var bestId = -1, bestLeft = true;
      var bestValue = double.negativeInfinity;
      final hand = hands[p];
      for (final id in hand) {
        for (final atLeft in const [true, false]) {
          if (!empty && !_matches(id, atLeft ? left : right)) continue;
          if (empty && !atLeft) continue;
          final nl = empty ? _low[id] : (atLeft ? _other(id, left) : left);
          final nr = empty ? _high[id] : (atLeft ? right : _other(id, right));
          var v = (_low[id] + _high[id]).toDouble();
          if (_low[id] == _high[id]) v += 4;
          final nextVoid = voids[(p + 1) % n];
          if (nextVoid & (1 << nl) != 0) v += 3;
          if (nextVoid & (1 << nr) != 0) v += 3;
          if (v > bestValue) {
            bestValue = v;
            bestId = id;
            bestLeft = atLeft;
          }
        }
      }
      if (bestId >= 0) {
        _place(p, bestId, bestLeft);
        if (hand.isEmpty) return _score(me, p);
        p = (p + 1) % n;
        continue;
      }
      if (cfg.drawFromBoneyard && boneyard.isNotEmpty) {
        voids[p] = (1 << left) | (1 << right);
        hand.add(boneyard.removeLast());
        continue;
      }
      voids[p] |= (1 << left) | (1 << right);
      passes++;
      if (passes >= n) return _score(me, null);
      p = (p + 1) % n;
    }
    return 0;
  }

  double _score(int me, int? out) {
    final n = cfg.players;
    final pips = [for (var p = 0; p < n; p++) hands[p].fold<int>(0, (s, t) => s + _low[t] + _high[t])];
    final sidePips = List.filled(cfg.sides, 0);
    for (var p = 0; p < n; p++) {
      sidePips[cfg.sideOf(p)] += pips[p];
    }
    int winnerSide;
    if (out != null) {
      winnerSide = cfg.sideOf(out);
    } else {
      var best = 0;
      var tie = false;
      for (var side = 1; side < cfg.sides; side++) {
        if (sidePips[side] < sidePips[best]) {
          best = side;
          tie = false;
        } else if (sidePips[side] == sidePips[best]) {
          tie = true;
        }
      }
      if (tie) return 0;
      winnerSide = best;
    }
    var points = 0;
    for (var side = 0; side < cfg.sides; side++) {
      if (side != winnerSide) points += sidePips[side];
    }
    // Scale down the opponents' gains when there are several of them.
    return winnerSide == cfg.sideOf(me) ? points.toDouble() : -points.toDouble() / (cfg.sides - 1);
  }
}

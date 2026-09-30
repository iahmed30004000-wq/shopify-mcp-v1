/// Dominoes AI, for every [DominoConfig] (count scoring and «الخمسات», draw
/// and block games, locked-line options, partnerships).
///
/// * easy – a random legal play;
/// * medium – a heuristic: shed heavy tiles and doubles, keep variety and
///   control of the ends, exploit known voids of the next opponent, take
///   All Fives end counts, and lock the line only when its own side is
///   likely to be the lighter one (estimated from the unseen tiles);
/// * hard – determinised Monte-Carlo: unseen tiles are dealt at random to
///   the other hands / stock (respecting public voids), each candidate is
///   played out with a fast medium-like policy for everyone under the
///   config's exact rules (locks, reserve, scoring), and the play with the
///   best average points for the AI's side wins.
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
int _pips(int id) => _low[id] + _high[id];

/// Tiles carrying each number that are already in the line.
List<int> _placedCounts(List<PlacedDomino> line) {
  final placed = List<int>.filled(7, 0);
  for (final p in line) {
    placed[p.tile.low]++;
    if (!p.tile.isDouble) placed[p.tile.high]++;
  }
  return placed;
}

/// Heuristic value of playing tile [id] making ends ([newLeft], [newRight])
/// from the mover's point of view.
double _playValue(int id, int newLeft, int newRight, List<int> handAfter, int nextVoids, int partnerVoids) {
  var v = _pips(id).toDouble();
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
    final cfg = s.config;
    final n = cfg.players;
    final hand = [for (final t in s.hands[p]) t.id];
    final nextVoids = s.voids[(p + 1) % n];
    final partnerVoids = cfg.teams ? s.voids[(p + 2) % n] : 0;
    final placed = _placedCounts(s.line);
    var best = legal.first;
    var bestValue = double.negativeInfinity;
    for (final m in legal) {
      final id = m.tile!.id;
      final (l, r) = _endsAfter(s.leftEnd, s.rightEnd, id, m.end!, s.line.isEmpty);
      final after = [...hand]..remove(id);
      var v = _playValue(id, l, r, after, nextVoids, partnerVoids);
      if (cfg.scoring == DominoScoring.allFives) {
        final count = _countAfter(s, id, m.end!, l, r);
        if (count > 0 && count % 5 == 0) v += 1.5 * count;
      }
      if (after.isNotEmpty && s.line.isNotEmpty && l == r && placed[l] + 1 == 7) {
        v += _lockValue(s, after);
      }
      if (v > bestValue) {
        bestValue = v;
        best = m;
      }
    }
    return best;
  }

  /// The value of locking the line, estimated from public information: the
  /// other hands are assumed to hold average unseen tiles.
  static double _lockValue(DominoState s, List<int> handAfter) {
    final cfg = s.config;
    final me = s.currentPlayer;
    final n = cfg.players;
    var unseenPips = 168, unseen = 28;
    for (final t in s.hands[me]) {
      unseenPips -= t.pips;
      unseen--;
    }
    for (final p in s.line) {
      unseenPips -= p.tile.pips;
      unseen--;
    }
    final avg = unseen == 0 ? 0.0 : unseenPips / unseen;
    final side = List<double>.filled(cfg.sides, 0);
    for (var q = 0; q < n; q++) {
      var est = q == me ? handAfter.fold<int>(0, (a, t) => a + _pips(t)).toDouble() : s.hands[q].length * avg;
      // Played out literally, the next player picks up the drawable stock.
      if (!cfg.endWhenLocked && cfg.drawFromBoneyard && q == (me + 1) % n) est += s.drawableStock * avg;
      side[cfg.sideOf(q)] += est;
    }
    final mine = side[cfg.sideOf(me)];
    var others = 0.0, lightest = double.infinity;
    for (var i = 0; i < cfg.sides; i++) {
      if (i == cfg.sideOf(me)) continue;
      others += side[i];
      if (side[i] < lightest) lightest = side[i];
    }
    if (mine < lightest - 1) return 12 + 0.5 * others;
    if (mine > lightest + 1) return -12 - 0.5 * mine;
    return -4;
  }

  /// The All Fives end count after playing [id] at [end] (new ends l, r).
  static int _countAfter(DominoState s, int id, DominoEnd end, int l, int r) {
    if (s.line.isEmpty) return _pips(id);
    final dbl = _low[id] == _high[id];
    if (end == DominoEnd.left) {
      return (dbl ? 2 * l : l) + (s.line.last.tile.isDouble ? 2 * r : r);
    }
    return (s.line.first.tile.isDouble ? 2 * l : l) + (dbl ? 2 * r : r);
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

/// A fast mutable round simulation on tile ids, following the config's rules.
final class _Sim {
  _Sim(DominoState s, List<List<int>> world, this.cfg)
    : hands = [for (var p = 0; p < cfg.players; p++) List<int>.of(world[p])],
      boneyard = List<int>.of(world[cfg.players]),
      left = s.leftEnd,
      right = s.rightEnd,
      empty = s.line.isEmpty,
      voids = List<int>.of(s.voids),
      placed = _placedCounts(s.line),
      leftDouble = s.line.isNotEmpty && s.line.first.tile.isDouble,
      rightDouble = s.line.isNotEmpty && s.line.last.tile.isDouble,
      tiles = s.line.length,
      singlePips = s.line.length == 1 ? s.line.first.tile.pips : 0,
      lastMover = s.lastMover,
      gain = List<int>.filled(cfg.sides, 0),
      fives = cfg.scoring == DominoScoring.allFives;

  final DominoConfig cfg;
  final List<List<int>> hands;
  final List<int> boneyard;
  final List<int> voids;
  final List<int> placed;
  final List<int> gain;
  final bool fives;
  int left, right;
  bool empty;
  bool leftDouble, rightDouble;
  int tiles;
  int singlePips;
  int? lastMover;
  int passes = 0;

  void play(int p, DominoMove m) => _place(p, m.tile!.id, m.end == DominoEnd.left);

  int get _count {
    if (tiles == 0) return 0;
    if (tiles == 1) return singlePips;
    return (leftDouble ? 2 * left : left) + (rightDouble ? 2 * right : right);
  }

  bool get _locked => cfg.endWhenLocked && !empty && left == right && placed[left] == 7;

  void _place(int p, int id, bool atLeft) {
    hands[p].remove(id);
    final dbl = _low[id] == _high[id];
    if (empty) {
      left = _low[id];
      right = _high[id];
      leftDouble = rightDouble = dbl;
      singlePips = _pips(id);
      empty = false;
    } else if (atLeft) {
      left = _other(id, left);
      leftDouble = dbl;
    } else {
      right = _other(id, right);
      rightDouble = dbl;
    }
    tiles++;
    placed[_low[id]]++;
    if (!dbl) placed[_high[id]]++;
    lastMover = p;
    passes = 0;
    if (fives) {
      final c = _count;
      if (c > 0 && c % 5 == 0) gain[cfg.sideOf(p)] += c;
    }
  }

  /// Plays the round out from the player after [me] (who just moved);
  /// returns the points for [me]'s side minus the average of the others'.
  double run(int me, SearchClock clock) {
    final n = cfg.players;
    var p = (me + 1) % n;
    if (hands[me].isEmpty) return _finish(me, me);
    if (_locked) return _finish(me, null);
    for (var guard = 0; guard < 200; guard++) {
      clock.tick();
      // Best playable tile by the heuristic, else draw / pass.
      var bestId = -1, bestLeft = true;
      var bestValue = double.negativeInfinity;
      final hand = hands[p];
      final nextVoid = voids[(p + 1) % n];
      for (final id in hand) {
        for (final atLeft in const [true, false]) {
          if (!empty && !_matches(id, atLeft ? left : right)) continue;
          if (empty && !atLeft) continue;
          final nl = empty ? _low[id] : (atLeft ? _other(id, left) : left);
          final nr = empty ? _high[id] : (atLeft ? right : _other(id, right));
          final dbl = _low[id] == _high[id];
          var v = _pips(id).toDouble();
          if (dbl) v += 4;
          if (nextVoid & (1 << nl) != 0) v += 3;
          if (nextVoid & (1 << nr) != 0) v += 3;
          if (fives) {
            final c = empty
                ? _pips(id)
                : (atLeft
                      ? (dbl ? 2 * nl : nl) + (rightDouble ? 2 * nr : nr)
                      : (leftDouble ? 2 * nl : nl) + (dbl ? 2 * nr : nr));
            if (c > 0 && c % 5 == 0) v += 1.5 * c;
          }
          if (v > bestValue) {
            bestValue = v;
            bestId = id;
            bestLeft = atLeft;
          }
        }
      }
      if (bestId >= 0) {
        _place(p, bestId, bestLeft);
        if (hand.isEmpty) return _finish(me, p);
        if (_locked) return _finish(me, null);
        p = (p + 1) % n;
        continue;
      }
      if (cfg.drawFromBoneyard && boneyard.length > cfg.stockReserve) {
        voids[p] = (1 << left) | (1 << right);
        hand.add(boneyard.removeLast());
        continue;
      }
      voids[p] |= (1 << left) | (1 << right);
      passes++;
      if (passes >= n) return _finish(me, null);
      p = (p + 1) % n;
    }
    return _value(me);
  }

  double _finish(int me, int? out) {
    final pips = [for (final h in hands) h.fold<int>(0, (s, t) => s + _pips(t))];
    final (:winner, :points) = DominoRules.settle(cfg, pips, out, lastMover);
    if (winner != null) gain[cfg.sideOf(winner)] += points;
    return _value(me);
  }

  double _value(int me) {
    final mine = cfg.sideOf(me);
    var others = 0;
    for (var side = 0; side < cfg.sides; side++) {
      if (side != mine) others += gain[side];
    }
    // Scale down the opponents' gains when there are several of them.
    return gain[mine] - others / (cfg.sides - 1);
  }
}

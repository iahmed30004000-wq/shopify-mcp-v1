// طاولة الزهر – differential test: the engine's pruned move generator
// (`generatePlays`, `isLegal`, `nextSteps`) against an independent,
// unpruned brute-force reference written from RULES.md §3 in absolute board
// coordinates. Positions come from random games (reachable) and from random
// end-game setups (bar, pins, bear-off, the ٣١ runner, noFullPrime).
import 'package:flutter_test/flutter_test.dart';
import 'package:madar/features/cinema/rules/board/board_games.dart';

import 'backgammon_test_helpers.dart';

/// Absolute position: free checkers (signed), pins, bar, off.
final class _Pos {
  _Pos(this.points, this.pinned, this.bar, this.off);
  factory _Pos.of(BackgammonState s) => _Pos([...s.points], [...s.pinned], [...s.bar], [...s.off]);
  final List<int> points, pinned, bar, off;
  _Pos copy() => _Pos([...points], [...pinned], [...bar], [...off]);
  String get key => '${points.join(',')}|${pinned.join(',')}|${bar.join(',')}|${off.join(',')}';
}

/// The rules of one step and one play, straight from the spec (no pruning).
final class _Ref {
  _Ref(this.cfg);
  final BackgammonConfig cfg;

  bool get parallel => cfg.variant == TawlaVariant.tawla31 && cfg.layout31 == Tawla31Layout.parallel;
  int get runnerTarget => cfg.variant != TawlaVariant.tawla31
      ? 0
      : (parallel || cfg.runnerTarget == Tawla31RunnerTarget.opponentHalf ? 12 : 6);

  /// Board index of [p]'s pip (player 1: 24 − pip, or (pip + 11) mod 24 in
  /// the parallel ٣١ layout).
  int idx(int p, int pip) => p == 0 ? pip - 1 : (parallel ? (pip + 11) % 24 : 24 - pip);

  int own(_Pos s, int p, int pip) {
    final v = s.points[idx(p, pip)];
    return p == 0 ? (v > 0 ? v : 0) : (v < 0 ? -v : 0);
  }

  int opposing(_Pos s, int p, int i) {
    final v = s.points[i];
    return p == 0 ? (v < 0 ? -v : 0) : (v > 0 ? v : 0);
  }

  bool runnerActive(_Pos s, int p) {
    if (runnerTarget == 0 || s.off[p] > 0) return false;
    for (var n = 1; n <= runnerTarget; n++) {
      if (own(s, p, n) > 0) return false;
    }
    return true;
  }

  bool mayBearOff(_Pos s, int p) {
    if (s.bar[p] > 0) return false;
    for (var n = 7; n <= 24; n++) {
      if (own(s, p, n) > 0) return false;
    }
    return cfg.variant != TawlaVariant.mahbusa || !s.pinned.contains(p);
  }

  /// Whether [p] may move a checker from pip [f] (25 = bar) by [d].
  bool legal(_Pos s, int p, int f, int d) {
    if (f == 25 ? s.bar[p] == 0 : (s.bar[p] > 0 || own(s, p, f) == 0)) return false;
    if (f == 24 && own(s, p, 24) < 15 && runnerActive(s, p)) return false;
    final t = f - d;
    if (t >= 1) {
      final i = idx(p, t);
      final n = opposing(s, p, i);
      return switch (cfg.variant) {
        TawlaVariant.sheshBesh => n <= 1,
        TawlaVariant.mahbusa => n == 0 || (n == 1 && s.pinned[i] != p),
        TawlaVariant.tawla31 => n == 0,
      };
    }
    if (!mayBearOff(s, p)) return false;
    if (t == 0) return true;
    for (var q = f + 1; q <= 6; q++) {
      if (own(s, p, q) > 0) return false;
    }
    return true;
  }

  void step(_Pos s, int p, int f, int d) {
    final sign = p == 0 ? 1 : -1, o = 1 - p;
    if (f == 25) {
      s.bar[p]--;
    } else {
      final i = idx(p, f);
      s.points[i] -= sign;
      if (s.points[i] == 0 && s.pinned[i] == o) {
        s.pinned[i] = -1; // the last pinner left: the checker is free again
        s.points[i] = -sign;
      }
    }
    final t = f - d;
    if (t < 1) {
      s.off[p]++;
      return;
    }
    final i = idx(p, t);
    if (opposing(s, p, i) == 1) {
      if (cfg.variant == TawlaVariant.sheshBesh) {
        s.points[i] = 0;
        s.bar[o]++;
      } else if (cfg.variant == TawlaVariant.mahbusa) {
        s.points[i] = 0;
        s.pinned[i] = o;
      }
    }
    s.points[i] += sign;
  }

  List<(int, int)> steps(_Pos s, int p, List<int> left) => [
    for (final d in left.toSet())
      for (var f = 25; f >= 1; f--)
        if (legal(s, p, f, d)) (f, d),
  ];

  /// Six consecutive points (in the opponent's route) held by [p] with no
  /// opposing checker past them.
  bool illegalPrime(_Pos s, int p) {
    final o = 1 - p;
    if (s.off[o] > 0) return false;
    var lowest = 99;
    for (var m = 24; m >= 1; m--) {
      if (own(s, o, m) > 0) lowest = m;
    }
    for (var m = 6; m <= 24; m++) {
      var held = true;
      for (var k = m - 5; k <= m; k++) {
        final v = s.points[idx(o, k)];
        if (p == 0 ? v <= 0 : v >= 0) held = false;
      }
      if (held && lowest > m) return true;
    }
    return false;
  }

  _Pos after(_Pos s, int p, int f, int d) {
    final t = s.copy();
    step(t, p, f, d);
    return t;
  }

  List<int> allDice(List<int> dice) => dice[0] == dice[1] ? [dice[0], dice[0], dice[0], dice[0]] : [...dice];

  /// Every end of a play: final key → (effective length, first die when it
  /// is a single step). Memoised on (position, dice left).
  ({Set<String> keys, int maxEff}) legalPlays(_Pos root, int p, List<int> dice) {
    final full = dice[0] == dice[1] ? 4 : 2;
    final ends = <(String, int, int, _Pos)>[]; // key, eff, first die, position
    final seen = <String>{};
    void dfs(_Pos s, List<int> left, int firstDie) {
      if (!seen.add('${s.key}#${left..sort()}#$firstDie')) return;
      if (s.off[p] == 15) {
        ends.add((s.key, full, firstDie, s));
        return;
      }
      final next = steps(s, p, left);
      if (next.isEmpty) ends.add((s.key, full - left.length, firstDie, s));
      for (final (f, d) in next) {
        final t = s.copy();
        step(t, p, f, d);
        dfs(t, [...left]..remove(d), left.length == full ? d : firstDie);
      }
    }

    dfs(root.copy(), allDice(dice), 0);
    final maxEff = ends.map((e) => e.$2).reduce((a, b) => a > b ? a : b);
    var kept = [for (final e in ends) if (e.$2 == maxEff) e];
    final high = dice[0] > dice[1] ? dice[0] : dice[1];
    if (maxEff == 1 && dice[0] != dice[1] && kept.any((e) => e.$3 == high)) {
      kept = [for (final e in kept) if (e.$3 == high) e];
    }
    if (cfg.variant == TawlaVariant.tawla31 && cfg.noFullPrime && maxEff > 0) {
      final ok = [for (final e in kept) if (!illegalPrime(e.$4, p)) e];
      if (ok.isNotEmpty) kept = ok;
    }
    return (keys: {for (final e in kept) e.$1}, maxEff: maxEff);
  }

  /// Whether some continuation from [s] ends in a legal play.
  bool completes(_Pos s, int p, List<int> left, int done, int maxEff, Set<String> keys, Map<String, bool> memo) {
    final full = left.length + done;
    if (s.off[p] == 15) return full == maxEff && keys.contains(s.key); // E4: counts as every die
    final memoKey = '${s.key}#${[...left]..sort()}';
    final cached = memo[memoKey];
    if (cached != null) return cached;
    final next = steps(s, p, left);
    var ok = false;
    if (next.isEmpty) {
      ok = done == maxEff && keys.contains(s.key);
    } else {
      for (final (f, d) in next) {
        final t = s.copy();
        step(t, p, f, d);
        if (completes(t, p, [...left]..remove(d), done + 1, maxEff, keys, memo)) {
          ok = true;
          break;
        }
      }
    }
    return memo[memoKey] = ok;
  }

  BackgammonStep toStep(int p, (int, int) s) => BackgammonStep(
    s.$1 == 25 ? BackgammonStep.bar : idx(p, s.$1),
    s.$1 - s.$2 < 1 ? BackgammonStep.off : idx(p, s.$1 - s.$2),
    s.$2,
  );
}

/// Compares the engine with the reference on [st] (phase moving).
void _compare(BackgammonState st, BoardRng rng, {bool deep = true}) {
  const rules = backgammonRules;
  final ref = _Ref(st.config);
  final p = st.currentPlayer;
  final root = _Pos.of(st);
  final (:keys, :maxEff) = ref.legalPlays(root, p, st.dice);
  final reason = 'dice ${st.dice} player $p ${st.toJson()}';

  final engineKeys = [for (final m in rules.legalMoves(st)) _Pos.of(rules.apply(st, m)).key];
  expect(engineKeys.toSet().length, engineKeys.length, reason: 'duplicate plays: $reason');
  expect(engineKeys.toSet(), keys, reason: 'legal final positions: $reason');
  if (!deep) return;

  final full = st.dice[0] == st.dice[1] ? 4 : 2;
  final memo = <String, bool>{};
  for (var walk = 0; walk < 12; walk++) {
    // A random complete step sequence: isLegal must agree with the reference.
    final s = root.copy();
    final left = ref.allDice(st.dice);
    final seq = <(int, int)>[];
    while (s.off[p] < 15) {
      final next = ref.steps(s, p, left);
      if (next.isEmpty) break;
      // Along the way, nextSteps must offer exactly the completable steps.
      if (walk < 4) {
        final partial = [for (final x in seq) ref.toStep(p, x)];
        final expected = <BackgammonStep>{
          for (final (f, d) in next)
            if (ref.completes(ref.after(s, p, f, d), p, [...left]..remove(d), seq.length + 1, maxEff, keys, memo))
              ref.toStep(p, (f, d)),
        };
        expect(rules.nextSteps(st, partial).toSet(), expected, reason: 'nextSteps($partial): $reason');
      }
      final pick = next[rng.nextInt(next.length)];
      ref.step(s, p, pick.$1, pick.$2);
      left.remove(pick.$2);
      seq.add(pick);
    }
    final eff = s.off[p] == 15 ? full : seq.length;
    final move = BackgammonMove.play([for (final x in seq) ref.toStep(p, x)]);
    final legal = eff == maxEff && keys.contains(s.key);
    expect(rules.isLegal(st, move), legal, reason: 'isLegal($move): $reason');
    if (legal) expect(_Pos.of(rules.apply(st, move)).key, s.key, reason: 'apply($move): $reason');
    // Any strict prefix of a play that could go on is never a legal play.
    if (seq.isNotEmpty && eff > 0 && s.off[p] < 15 && seq.length > 1) {
      final short = BackgammonMove.play([for (final x in seq.sublist(0, seq.length - 1)) ref.toStep(p, x)]);
      expect(rules.isLegal(st, short), isFalse, reason: 'prefix $short: $reason');
    }
  }
}

/// A random end-game-ish position of [c] (null when the draw fails).
BackgammonState? _synthetic(BackgammonConfig c, BoardRng r) {
  final ref = _Ref(c);
  final points = List<int>.filled(24, 0), pinned = List<int>.filled(24, -1);
  final bar = [0, 0], off = [0, 0];
  for (var p = 0; p < 2; p++) {
    final sign = p == 0 ? 1 : -1;
    off[p] = r.nextInt(100) < 40 ? 0 : r.nextInt(15);
    var left = 15 - off[p];
    if (c.variant == TawlaVariant.sheshBesh && left > 0 && r.nextInt(100) < 25) {
      bar[p] = 1 + r.nextInt(left < 2 ? 1 : 2);
      left -= bar[p];
    }
    final spread = const [6, 6, 12, 24][r.nextInt(4)];
    for (var guard = 0; left > 0 && guard < 500; guard++) {
      final i = ref.idx(p, 1 + r.nextInt(spread));
      if (points[i] * sign < 0) continue;
      points[i] += sign;
      left--;
    }
    if (left > 0) return null;
  }
  if (c.variant == TawlaVariant.mahbusa) {
    // Up to two pins: one checker of q moved under a point the other holds.
    for (var k = r.nextInt(3); k > 0; k--) {
      final q = r.nextInt(2), qs = q == 0 ? 1 : -1;
      final holders = [
        for (var i = 0; i < 24; i++)
          if (points[i] * qs < 0 && pinned[i] == -1) i,
      ];
      final donors = [
        for (var i = 0; i < 24; i++)
          if (points[i] * qs > 0) i,
      ];
      if (holders.isEmpty || donors.isEmpty) continue;
      points[donors[r.nextInt(donors.length)]] -= qs;
      pinned[holders[r.nextInt(holders.length)]] = q;
    }
  }
  if (c.variant == TawlaVariant.tawla31) {
    // While a side's runner rule is active, keep it reachable: 15 on the
    // start, or 14 there and one runner short of the target.
    for (var p = 0; p < 2; p++) {
      if (!ref.runnerActive(_Pos(points, pinned, bar, off), p)) continue;
      final sign = p == 0 ? 1 : -1, start = ref.idx(p, 24);
      if (points[start] * sign < 0) return null;
      for (var i = 0; i < 24; i++) {
        if (points[i] * sign > 0) points[i] = 0;
      }
      final i = ref.idx(p, ref.runnerTarget + 1 + r.nextInt(23 - ref.runnerTarget));
      if (i == start || points[i] * sign < 0) {
        points[start] = 15 * sign;
      } else {
        points[start] = 14 * sign;
        points[i] = sign;
      }
    }
  }
  final d1 = 1 + r.nextInt(6), d2 = r.nextInt(100) < 30 ? d1 : 1 + r.nextInt(6);
  return BackgammonState(
    config: c,
    points: points,
    pinned: pinned,
    bar: bar,
    off: off,
    currentPlayer: r.nextInt(2),
    phase: BackgammonPhase.moving,
    dice: [d1, d2],
    rng: const [1, 2, 3, 4],
  );
}

void main() {
  const configs = <String, BackgammonConfig>{
    'شيش بيش': single,
    'محبوسة': mahbusaSingle,
    '٣١': tawla31Single,
    '٣١ parallel': BackgammonConfig(variant: TawlaVariant.tawla31, matchTarget: 0, layout31: Tawla31Layout.parallel),
    '٣١ opponentHalf': BackgammonConfig(
      variant: TawlaVariant.tawla31,
      matchTarget: 0,
      runnerTarget: Tawla31RunnerTarget.opponentHalf,
    ),
    '٣١ noFullPrime': BackgammonConfig(variant: TawlaVariant.tawla31, matchTarget: 0, noFullPrime: true),
  };

  for (final MapEntry(key: name, value: config) in configs.entries) {
    test('$name: random game positions, every roll, match the reference', () {
      final rng = BoardRng(name.length);
      final e = BoardGameEngine<BackgammonState, BackgammonMove>(
        backgammonRules,
        BackgammonState.initial(seed: 4, config: config),
      );
      var ply = 0;
      while (!e.isOver) {
        final s = e.state;
        if (s.phase == BackgammonPhase.moving) {
          _compare(s, rng, deep: ply.isEven);
          if (ply % 16 == 0) {
            for (var a = 1; a <= 6; a++) {
              for (var b = a; b <= 6; b++) {
                _compare(s.copyWith(dice: [a, b]), rng, deep: false);
              }
            }
          }
        }
        e.apply(rng.pick(e.legalMoves()));
        ply++;
      }
    });

    test('$name: synthetic end-game positions match the reference', () {
      final rng = BoardRng(99 + name.length);
      var made = 0;
      while (made < 60) {
        final s = _synthetic(config, rng);
        if (s == null || s.off.contains(15)) continue;
        made++;
        _compare(s, rng);
      }
    });
  }
}

/// Move generation for طاولة الزهر, shared by the rules and the AI.
///
/// A [BgBoard] is a position seen from the player to move: `a` = the mover,
/// `b` = the opponent. Each array has `[0]` = checkers borne off,
/// `[1..24]` = free checkers on that side's own pip numbers, `[25]` = bar.
/// Pinned checkers (محبوسة only) are not counted in `a`/`b`; they are the
/// flags `pa`/`pb` (1 at the own pip where that side has a pinned checker).
///
/// The same point is the mover's pip `n` and the opponent's pip
/// `mode.mirror(n)`: `25 - n` when the two sides start facing each other
/// (every game's default), `n ± 12` in the parallel (Fevga-style) ٣١ layout.
library;

import 'dart:typed_data';

/// What happens when a checker lands on a point holding opposing checkers.
enum BgLanding {
  /// شيش بيش: a lone opposing checker is hit to the bar; 2+ close the point.
  hit,

  /// محبوسة: a lone unpinned opposing checker is pinned under the mover's
  /// checker; 2+ opposing checkers, or a point the opponent controls (the
  /// opponent's checkers on top of one of the mover's), close the point.
  pin,

  /// ٣١: any opposing checker closes the point; nothing is hit or pinned.
  block,
}

/// The movement rules of one variant.
final class BgMode {
  const BgMode({this.landing = BgLanding.hit, this.parallel = false, this.runnerTarget = 0, this.noFullPrime = false});

  static const BgMode sheshBesh = BgMode();
  static const BgMode mahbusa = BgMode(landing: BgLanding.pin);

  final BgLanding landing;

  /// Parallel start (٣١ option): the opponent's pip `m` is the mover's pip
  /// `m ± 12` instead of `25 - m`.
  final bool parallel;

  /// ٣١ runner rule: while the mover has borne nothing off and has no
  /// checker on own pip ≤ [runnerTarget], only the runner may move. 0 = off.
  final int runnerTarget;

  /// ٣١ option: a play may not leave six consecutive points held in front of
  /// every opposing checker (waived when every maximal play would).
  final bool noFullPrime;

  /// The other side's pip number of the point that is pip [m] for one side.
  int mirror(int m) => parallel ? (m <= 12 ? m + 12 : m - 12) : 25 - m;

  @override
  bool operator ==(Object other) =>
      other is BgMode &&
      other.landing == landing &&
      other.parallel == parallel &&
      other.runnerTarget == runnerTarget &&
      other.noFullPrime == noFullPrime;

  @override
  int get hashCode => Object.hash(landing, parallel, runnerTarget, noFullPrime);
}

/// Shared all-zero pin flags for the variants without pinning (never
/// written: only [BgLanding.pin] boards change pins).
final Int8List _noPins = Int8List(26);

/// A position from the mover's side (see the library comment).
final class BgBoard {
  BgBoard(this.a, this.b, {this.mode = BgMode.sheshBesh, Int8List? pa, Int8List? pb})
    : pa = pa ?? (mode.landing == BgLanding.pin ? Int8List(26) : _noPins),
      pb = pb ?? (mode.landing == BgLanding.pin ? Int8List(26) : _noPins);

  final Int8List a;
  final Int8List b;

  /// 1 at the mover's own pip where one of his checkers is pinned.
  final Int8List pa;

  /// 1 at the opponent's own pip where one of his checkers is pinned (by the
  /// mover's checkers on that point).
  final Int8List pb;
  final BgMode mode;

  bool get _pins => mode.landing == BgLanding.pin;

  BgBoard copy() => BgBoard(
    Int8List.fromList(a),
    Int8List.fromList(b),
    mode: mode,
    pa: _pins ? Int8List.fromList(pa) : null,
    pb: _pins ? Int8List.fromList(pb) : null,
  );

  /// The same position with the other side to move.
  BgBoard swapped() => BgBoard(b, a, mode: mode, pa: pb, pb: pa);

  /// Whether bearing off is allowed: every checker in the home board and –
  /// in محبوسة – none of the mover's checkers pinned anywhere.
  bool allHome() {
    for (var n = 7; n <= 25; n++) {
      if (a[n] > 0) return false;
    }
    if (_pins) {
      for (var n = 1; n <= 24; n++) {
        if (pa[n] > 0) return false;
      }
    }
    return true;
  }

  /// ٣١: whether the runner rule still restricts the mover.
  bool get runnerActive {
    final target = mode.runnerTarget;
    if (target == 0 || a[0] > 0) return false;
    for (var n = 1; n <= target; n++) {
      if (a[n] > 0) return false;
    }
    return true;
  }

  /// Whether a free checker on the mover's pip [f] (25 = bar) may move [d].
  bool canMove(int f, int d) {
    if (a[f] == 0) return false;
    if (a[25] > 0 && f != 25) return false;
    // Runner rule: once one checker has left the start, the rest wait there.
    if (f == 24 && a[24] < 15 && mode.runnerTarget > 0 && runnerActive) return false;
    final t = f - d;
    if (t >= 1) {
      final m = mode.mirror(t);
      switch (mode.landing) {
        case BgLanding.hit:
          return b[m] <= 1;
        case BgLanding.pin:
          return b[m] == 0 || (b[m] == 1 && pa[t] == 0);
        case BgLanding.block:
          return b[m] == 0;
      }
    }
    if (!allHome()) return false;
    if (t == 0) return true;
    for (var q = f + 1; q <= 6; q++) {
      if (a[q] > 0) return false;
    }
    return true;
  }

  /// Moves one checker (assumed legal). Returns an undo token: bit 1 = the
  /// landing hit or pinned a checker, bit 2 = leaving [f] released a pin.
  int move(int f, int d) {
    final t = f - d;
    var token = 0;
    a[f]--;
    if (_pins && f <= 24 && a[f] == 0) {
      final mf = mode.mirror(f);
      if (pb[mf] == 1) {
        pb[mf] = 0;
        b[mf] = 1;
        token |= 2;
      }
    }
    if (t < 1) {
      a[0]++;
      return token;
    }
    a[t]++;
    final m = mode.mirror(t);
    if (b[m] == 1) {
      switch (mode.landing) {
        case BgLanding.hit:
          b[m] = 0;
          b[25]++;
          token |= 1;
        case BgLanding.pin:
          b[m] = 0;
          pb[m] = 1;
          token |= 1;
        case BgLanding.block:
          break;
      }
    }
    return token;
  }

  /// Reverses [move] given its token.
  void undo(int f, int d, int token) {
    final t = f - d;
    if (t < 1) {
      a[0]--;
    } else {
      a[t]--;
      if (token & 1 != 0) {
        final m = mode.mirror(t);
        b[m] = 1;
        if (mode.landing == BgLanding.hit) {
          b[25]--;
        } else {
          pb[m] = 0;
        }
      }
    }
    if (token & 2 != 0) {
      final mf = mode.mirror(f);
      b[mf] = 0;
      pb[mf] = 1;
    }
    a[f]++;
  }

  /// A compact identity of the position (pins included where they exist).
  String get key => _pins
      ? String.fromCharCodes(a) + String.fromCharCodes(b) + String.fromCharCodes(pa) + String.fromCharCodes(pb)
      : String.fromCharCodes(a) + String.fromCharCodes(b);

  /// Pip count of one side's free checkers (bar = 25).
  int pips(Int8List side) {
    var p = 0;
    for (var n = 1; n <= 25; n++) {
      p += side[n] * n;
    }
    return p;
  }

  /// Pip counts including pinned checkers.
  int get moverPips => pips(a) + (_pins ? _pinPips(pa) : 0);
  int get opponentPips => pips(b) + (_pins ? _pinPips(pb) : 0);

  static int _pinPips(Int8List flags) {
    var p = 0;
    for (var n = 1; n <= 24; n++) {
      p += flags[n] * n;
    }
    return p;
  }

  /// ٣١ `noFullPrime`: the mover holds six consecutive points (in the
  /// opponent's direction of travel) and no opposing checker is past them.
  bool get hasIllegalPrime {
    if (b[0] > 0) return false; // a checker borne off is past any block
    var lowest = 25; // the opponent's most advanced checker (own pip)
    for (var m = 1; m <= 24; m++) {
      if (b[m] > 0) {
        lowest = m;
        break;
      }
    }
    var run = 0;
    for (var m = 1; m <= 24; m++) {
      run = a[mode.mirror(m)] > 0 ? run + 1 : 0;
      if (run >= 6 && lowest > m - 5) return true;
    }
    return false;
  }
}

/// A generated play: steps in the mover's pip coordinates plus the result.
final class BgPlay {
  BgPlay(this.from, this.dice, this.result);
  final List<int> from; // mover pips (25 = bar)
  final List<int> dice;
  final BgBoard result;

  /// The play bore off the mover's 15th checker (E4: complete even when
  /// dice are left).
  bool get terminal => result.a[0] == 15;
}

/// The number of dice a roll gives (4 for a double).
int diceCount(List<int> dice) => dice[0] == dice[1] ? 4 : 2;

/// The length every legal play of [plays] counts as: the number of steps,
/// or the full dice count for a play that ends the game (E4).
int effectiveLength(BgPlay play, int fullDice) => play.terminal ? fullDice : play.from.length;

/// Generates all distinct legal plays for [dice], one per final position
/// (never empty: a forced pass is the single empty play).
///
/// * As many dice as possible must be used; with a single die of a
///   non-double, the higher one when possible (G7).
/// * A play that bears off the 15th checker counts as using every die (E4).
/// * For doubles, checkers move in non-increasing pip order – every final
///   position is still reached. While the ٣١ runner rule is active only one
///   checker can move, and the order restarts once it lifts mid-roll.
/// * Non-doubles try the higher die first, so the representative of two
///   equal positions uses the higher die.
List<BgPlay> generatePlays(BgBoard board, List<int> dice) {
  final work = board.copy();
  final plays = <String, BgPlay>{};
  var maxLen = 0;
  final isDouble = dice[0] == dice[1];
  final full = isDouble ? 4 : 2;
  final high = dice[0] > dice[1] ? dice[0] : dice[1];
  final low = dice[0] > dice[1] ? dice[1] : dice[0];
  final remaining = isDouble ? [high, high, high, high] : [high, low];
  final from = <int>[], used = <int>[];
  final runnerRule = board.mode.runnerTarget > 0;

  void record() {
    final terminal = work.a[0] == 15;
    final len = terminal ? full : from.length;
    if (len < maxLen) return;
    if (len > maxLen) {
      maxLen = len;
      plays.clear();
    }
    // Single-step plays keep the die in the key so that the higher-die
    // rule below can still choose between equal positions.
    final key = !terminal && from.length == 1 ? '${work.key}#${used.first}' : work.key;
    plays.putIfAbsent(key, () => BgPlay(List.of(from), List.of(used), work.copy()));
  }

  void dfs(int cap) {
    if (work.a[0] == 15) {
      record();
      return;
    }
    var any = false;
    final restricted = runnerRule && work.runnerActive;
    final tried = <int>{};
    for (var i = 0; i < remaining.length; i++) {
      final d = remaining[i];
      if (d == 0 || !tried.add(d)) continue;
      final top = work.a[25] > 0 ? 25 : (isDouble ? cap : 24);
      for (var f = top; f >= 1; f--) {
        if (f < 25 && work.a[25] > 0) break;
        if (!work.canMove(f, d)) continue;
        any = true;
        final token = work.move(f, d);
        remaining[i] = 0;
        from.add(f);
        used.add(d);
        dfs(isDouble && !restricted ? f : 25);
        from.removeLast();
        used.removeLast();
        remaining[i] = d;
        work.undo(f, d, token);
      }
    }
    if (!any) record();
  }

  dfs(25);
  var out = plays.values.toList();
  if (maxLen == 1 && !isDouble) {
    final withHigh = [
      for (final p in out)
        if (p.dice.first == high) p,
    ];
    if (withHigh.isNotEmpty) out = withHigh;
    final seen = <String>{};
    out = [
      for (final p in out)
        if (seen.add(p.result.key)) p,
    ];
  }
  if (board.mode.noFullPrime && maxLen > 0) {
    final allowed = [
      for (final p in out)
        if (!p.result.hasIllegalPrime) p,
    ];
    if (allowed.isNotEmpty) out = allowed; // otherwise the rule is waived
  }
  return out;
}

/// Whether the mover has a non-empty play for at least one of the 21 rolls
/// (used by the frozen-position guard). A roll allows a non-empty play
/// exactly when one of its dice allows a single step.
bool hasAnyPlay(BgBoard board) {
  for (var d = 1; d <= 6; d++) {
    for (var f = 25; f >= 1; f--) {
      if (board.canMove(f, d)) return true;
    }
  }
  return false;
}

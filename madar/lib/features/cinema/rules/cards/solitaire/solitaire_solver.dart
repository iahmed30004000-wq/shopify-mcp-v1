/// Solitaire searches: the exact "stuck" test (S-31), the depth-first
/// solver that proves a deal winnable (S-61…S-63), and winnable-deal
/// generation with its bundled fallback (S-62).
///
/// Everything runs synchronously on a [SolitaireBoard]; the app runs the
/// solver in an isolate (`Isolate.run`).
library;

import 'dart:collection';

import '../core/card_rng.dart';
import 'solitaire_board.dart';
import 'solitaire_options.dart';
import 'solitaire_seeds.dart';

abstract final class SolitaireSearch {
  /// States the stuck search may visit before it answers "not stuck".
  static const int stuckLimit = 20000;

  /// S-31: true when no reachable position has more cards home or a card
  /// turned up. Breadth-first over every legal action (draws, recycles
  /// within the pass limit, all moves), keyed on the whole position. It
  /// stops at the first progress, so it never looks past a face-down card.
  /// Unknown (limit reached) is "not stuck". With a pass limit it is false
  /// while some stock card is still unseen (S-36a).
  static bool isStuck(SolitaireBoard board, SolitaireOptions o, {int limit = stuckLimit}) {
    if (board.won) return false;
    if (o.passLimit != null && board.stockUnseen) return false;
    final home = board.cardsHome;
    final withRecycles = o.passLimit != null;
    final seen = <String>{board.key(withRecycles: withRecycles)};
    final queue = Queue<SolitaireBoard>()..add(board);
    while (queue.isNotEmpty) {
      final s = queue.removeFirst();
      for (final a in s.legalActions(o)) {
        if (a.kind == SolitaireActionKind.autoComplete || a.kind == SolitaireActionKind.flip) return false;
        final t = s.copy()..apply(a, o);
        if (t.cardsHome > home || t.faceDownTotal < s.faceDownTotal) return false;
        if (seen.add(t.key(withRecycles: withRecycles))) {
          if (seen.length > limit) return false;
          queue.add(t);
        }
      }
    }
    return true;
  }
}

enum SolitaireSolveResult {
  /// A winning plan was found.
  won,

  /// The search (with its pruning) ran out of moves: no plan found. This is
  /// not a proof that the deal cannot be won.
  lost,

  /// The node budget ran out.
  unknown,
}

class SolitaireSolution {
  const SolitaireSolution(this.result, this.plan, this.nodes);

  final SolitaireSolveResult result;

  /// The engine actions that win the deal from the solved position (empty
  /// unless [won]). With `autoFlip` off it contains the flips.
  final List<SolitaireAction> plan;
  final int nodes;

  bool get won => result == SolitaireSolveResult.won;
}

class _Successor {
  _Successor(this.actions, this.board, this.priority);

  final List<SolitaireAction> actions;
  final SolitaireBoard board;
  final int priority;
}

/// S-63: depth-first search with full knowledge of the cards, the engine's
/// own move rules and automatic moves, the stock handled as the waste
/// positions it can reach, and a table of positions already explored.
/// It never moves a card back from a foundation, so a proof holds whether
/// or not S-16 is allowed.
class SolitaireSolver {
  const SolitaireSolver({this.nodeBudget = 200000});

  final int nodeBudget;

  SolitaireSolution solve(SolitaireBoard start, SolitaireOptions options) {
    final run = _Run(options, nodeBudget);
    final won = run.dfs(start.copy());
    final result = won
        ? SolitaireSolveResult.won
        : (run.aborted ? SolitaireSolveResult.unknown : SolitaireSolveResult.lost);
    return SolitaireSolution(result, won ? List.unmodifiable(run.plan) : const [], run.nodes);
  }
}

class _Run {
  _Run(this.o, this.budget) : withRecycles = o.passLimit != null;

  final SolitaireOptions o;
  final int budget;
  final bool withRecycles;
  final Set<String> seen = {};
  final List<SolitaireAction> plan = [];
  int nodes = 0;
  bool aborted = false;

  bool dfs(SolitaireBoard b) {
    if (b.won) return true;
    if (nodes >= budget) {
      aborted = true;
      return false;
    }
    nodes++;
    if (!seen.add(b.key(withRecycles: withRecycles))) return false;
    for (final s in _successors(b)) {
      final mark = plan.length;
      plan.addAll(s.actions);
      if (dfs(s.board)) return true;
      if (aborted) return false;
      plan.length = mark;
    }
    return false;
  }

  _Successor _after(SolitaireBoard b, List<SolitaireAction> actions, int priority) {
    final t = b.copy();
    for (final a in actions) {
      t.apply(a, o);
    }
    return _Successor(actions, t, priority);
  }

  List<_Successor> _successors(SolitaireBoard b) {
    // Forced steps first: turning up a card (when the player must do it),
    // a certain win, and (without automatic moves) a safe card home.
    if (!o.autoFlip) {
      for (var c = 0; c < 7; c++) {
        if (b.colLen(c) > 0 && b.down(c) == b.colLen(c)) return [_after(b, [SolitaireAction.flip(c)], 0)];
      }
    }
    if (b.canAutoComplete(o)) return [_after(b, [SolitaireAction.autoComplete], 0)];
    if (o.autoMoveToFoundation == SolitaireAutoMove.off) {
      final top = b.wasteTop;
      if (o.drawCount == 1 && top >= 0 && b.homePlace(top) >= 0 && b.isSafeHome(top)) {
        return [
          _after(b, [SolitaireAction.move(SolitairePile.waste, SolitairePile.foundation(b.homePlace(top)))], 0),
        ];
      }
      for (var c = 0; c < 7; c++) {
        final len = b.colLen(c);
        if (len == b.down(c)) continue;
        final card = b.at(c, len - 1);
        if (b.homePlace(card) >= 0 && b.isSafeHome(card)) {
          return [
            _after(b, [SolitaireAction.move(SolitairePile.column(c), SolitairePile.foundation(b.homePlace(card)))], 0),
          ];
        }
      }
    }

    final out = <_Successor>[];
    var firstEmpty = -1;
    for (var c = 0; c < 7; c++) {
      if (b.colLen(c) == 0) {
        firstEmpty = c;
        break;
      }
    }

    // Column cards home, and column moves that turn a card up, empty a
    // column for a waiting king, or free a card that can then go home.
    for (var c = 0; c < 7; c++) {
      final len = b.colLen(c);
      final d = b.down(c);
      if (len == d) continue;
      final last = b.at(c, len - 1);
      final p = b.homePlace(last);
      if (p >= 0) {
        out.add(_after(b, [SolitaireAction.move(SolitairePile.column(c), SolitairePile.foundation(p))], 0));
      }
      for (var k = d; k < len; k++) {
        final head = b.at(c, k);
        final reveals = k == d && d > 0;
        final empties = k == 0;
        final freesHome = k > d && b.homePlace(b.at(c, k - 1)) >= 0;
        if (!reveals && !empties && !freesHome) continue;
        if (empties && (SolitaireBoard.rankOfCode(head) == 13 || !_kingAvailable(b, c))) continue;
        for (var t = 0; t < 7; t++) {
          if (t == c || !b.fitsColumn(head, t)) continue;
          if (b.colLen(t) == 0 && t != firstEmpty) continue;
          final priority = reveals ? 16 - d : 60;
          out.add(
            _after(b, [SolitaireAction.move(SolitairePile.column(c), SolitairePile.column(t), count: len - k)], priority),
          );
        }
      }
    }

    // The talon: every waste card the stock can reach, played where it fits.
    final sim = b.copy();
    final steps = <SolitaireAction>[];
    final home = b.cardsHome;
    final start = b.wasteCount;
    var recycled = false;
    for (var guard = 0; guard < 80; guard++) {
      final top = sim.wasteTop;
      if (top >= 0) {
        final p = sim.homePlace(top);
        if (p >= 0) {
          out.add(
            _after(sim, [SolitaireAction.move(SolitairePile.waste, SolitairePile.foundation(p))], 20 + steps.length)
              ..actions.insertAll(0, steps),
          );
        }
        for (var t = 0; t < 7; t++) {
          if (!sim.fitsColumn(top, t)) continue;
          if (sim.colLen(t) == 0 && t != firstEmpty) continue;
          out.add(
            _after(sim, [SolitaireAction.move(SolitairePile.waste, SolitairePile.column(t))], 30 + steps.length)
              ..actions.insertAll(0, steps),
          );
        }
      }
      final SolitaireAction next;
      if (sim.stockCount > 0) {
        next = SolitaireAction.draw;
      } else if (sim.wasteCount > 0 && !recycled && sim.recycleAllowed(o)) {
        next = SolitaireAction.recycle;
        recycled = true;
      } else {
        break;
      }
      sim.apply(next, o);
      steps.add(next);
      if (sim.cardsHome != home) {
        // Drawing sent cards home by itself (draw one): a position of its own.
        out.add(_Successor(List.of(steps), sim.copy(), 15));
        break;
      }
      if (recycled && sim.wasteCount >= start) break;
    }
    out.sort((a, b) => a.priority - b.priority);
    return out;
  }

  static bool _kingAvailable(SolitaireBoard b, int exceptColumn) {
    for (var i = 0; i < b.talonLength; i++) {
      if (SolitaireBoard.rankOfCode(b.talonAt(i)) == 13) return true;
    }
    for (var c = 0; c < 7; c++) {
      if (c == exceptColumn) continue;
      for (var k = b.down(c) == 0 ? 1 : b.down(c); k < b.colLen(c); k++) {
        if (SolitaireBoard.rankOfCode(b.at(c, k)) == 13) return true;
      }
    }
    return false;
  }
}

/// A solver for [SolitaireDeals.winnable] (tests pass a stub).
typedef SolitaireSolveFn = SolitaireSolution Function(SolitaireBoard board, SolitaireOptions options);

/// A deal chosen for winnable-deal mode.
class SolitaireDealChoice {
  const SolitaireDealChoice(this.seed, {required this.proven, required this.fromBundle, this.plan = const []});

  /// The deal number to pass to `SolitaireGame.newDeal`.
  final int seed;

  /// Proved winnable under the options (a bundled seed is proved for its
  /// rule set; `always` auto-move is not covered by any proof).
  final bool proven;

  /// Taken from the bundled list after [SolitaireDeals.maxTries] failures.
  final bool fromBundle;

  /// The winning plan when the solver found one here.
  final List<SolitaireAction> plan;
}

abstract final class SolitaireDeals {
  /// Candidate seeds tried before the bundled list is used (S-62).
  static const int maxTries = 25;

  /// S-62: the first deal of a [CardRng] stream seeded with [streamSeed]
  /// that [solve] proves won under [options]; after [maxTries] failures the
  /// first seed of the bundled list for the rule set not in [used].
  static SolitaireDealChoice winnable({
    required int streamSeed,
    required SolitaireOptions options,
    SolitaireSolveFn? solve,
    Set<int> used = const {},
    SolitaireBoard Function(int seed)? deal,
  }) {
    final solver = solve ?? const SolitaireSolver().solve;
    final rng = CardRng(streamSeed);
    for (var i = 0; i < maxTries; i++) {
      final seed = rng.nextUint32() & 0x7fffffff;
      if (used.contains(seed)) continue;
      final solution = solver((deal ?? _deal)(seed), options);
      if (solution.won) return SolitaireDealChoice(seed, proven: true, fromBundle: false, plan: solution.plan);
    }
    final list = SolitaireSeeds.forOptions(options);
    final seed = list.firstWhere((s) => !used.contains(s), orElse: () => list[streamSeed.abs() % list.length]);
    return SolitaireDealChoice(
      seed,
      proven: options.autoMoveToFoundation != SolitaireAutoMove.always,
      fromBundle: true,
    );
  }

  static SolitaireBoard _deal(int seed) => SolitaireBoard.forSeed(seed);

  /// Deal of the day (S-64): yyyymmdd.
  static int dayNumber(DateTime day) => day.year * 10000 + day.month * 100 + day.day;
}

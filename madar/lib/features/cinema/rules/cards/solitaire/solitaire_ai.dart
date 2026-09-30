/// Solitaire auto-player at three levels (S-75): the hint (S-36), a
/// "watch" demo, and the self-play and strength tests.
///
/// Every decision is made on a masked copy of the board in which the
/// face-down cards, and the stock until its first recycle, are unknown
/// (S-36a). So no level can use a card the player has not seen.
library;

import 'dart:math' as math;

import '../core/card_game.dart' show AiLevel;
import 'solitaire_board.dart';
import 'solitaire_options.dart';

/// What kind of help a hint is (a stable id the UI explains).
enum SolitaireTechnique { toFoundation, revealCard, emptyColumn, fromWaste, drawStock, recycle, noMoves }

class SolitaireHint {
  const SolitaireHint(this.action, this.technique, {this.fromSolver = false});

  /// Null with [SolitaireTechnique.noMoves].
  final SolitaireAction? action;
  final SolitaireTechnique technique;

  /// The hint follows the solver's plan (S-37); the UI labels it.
  final bool fromSolver;

  @override
  String toString() => 'SolitaireHint($action, ${technique.name}${fromSolver ? ', solver' : ''})';
}

/// The medium priority list (S-75), best first.
enum _Kind {
  autoComplete,
  safeHome,
  reveal,
  emptyForKing,
  otherHome,
  wasteToColumn,
  stock,
}

class _Candidate {
  _Candidate(this.action, this.kind, this.order);

  final SolitaireAction action;
  final _Kind kind;

  /// Tie-break inside [kind]: smaller first.
  final int order;
}

abstract final class SolitaireAutoPlayer {
  /// The next action at [level] for the position [board], or null when the
  /// player would stop (nothing productive, and cycling the stock cannot
  /// help). [rng] is used by the easy level only.
  static SolitaireAction? choose(SolitaireBoard board, SolitaireOptions o, AiLevel level, math.Random rng) {
    final m = board.masked();
    final all = _candidates(m, o);
    if (all.isEmpty) return null;
    switch (level) {
      case AiLevel.easy:
        final productive = [
          for (final c in all)
            if (c.kind != _Kind.stock) c,
        ];
        if (productive.isNotEmpty) return productive[rng.nextInt(productive.length)].action;
        return all.first.action;
      case AiLevel.medium:
        return all.first.action;
      case AiLevel.hard:
        if (all.length == 1) return all.first.action;
        var best = all.first;
        var bestValue = double.negativeInfinity;
        for (final c in all) {
          final v = _value(m, o, c, 3);
          if (v > bestValue + 1e-9) {
            best = c;
            bestValue = v;
          }
        }
        return best.action;
    }
  }

  /// The hint (S-36): the best action at [level] and what it achieves.
  static SolitaireHint hint(SolitaireBoard board, SolitaireOptions o, {AiLevel level = AiLevel.hard, math.Random? rng}) {
    final a = choose(board, o, level, rng ?? math.Random(0));
    return SolitaireHint(a, techniqueOf(board, a));
  }

  /// The technique id of [a] played on [board].
  static SolitaireTechnique techniqueOf(SolitaireBoard board, SolitaireAction? a) {
    if (a == null) return SolitaireTechnique.noMoves;
    switch (a.kind) {
      case SolitaireActionKind.draw:
        return SolitaireTechnique.drawStock;
      case SolitaireActionKind.recycle:
        return SolitaireTechnique.recycle;
      case SolitaireActionKind.flip:
        return SolitaireTechnique.revealCard;
      case SolitaireActionKind.autoComplete:
        return SolitaireTechnique.toFoundation;
      case SolitaireActionKind.move:
        final from = a.from!;
        if (a.to!.isFoundation) return SolitaireTechnique.toFoundation;
        if (from.isColumn) {
          final c = from.index;
          final k = board.colLen(c) - a.count;
          if (k == board.down(c) && k > 0) return SolitaireTechnique.revealCard;
          if (k == 0) return SolitaireTechnique.emptyColumn;
        }
        if (from.isWaste) return SolitaireTechnique.fromWaste;
        return SolitaireTechnique.revealCard;
    }
  }

  // ---------------------------------------------------------------------------

  /// A king that could fill an empty column usefully: the waste card, or a
  /// face-up king that is not already first in its column.
  static bool _kingWaiting(SolitaireBoard m, int exceptColumn) {
    final top = m.wasteTop;
    if (top >= 0 && SolitaireBoard.rankOfCode(top) == 13) return true;
    for (var c = 0; c < 7; c++) {
      if (c == exceptColumn) continue;
      for (var k = math.max(1, m.down(c)); k < m.colLen(c); k++) {
        if (SolitaireBoard.rankOfCode(m.at(c, k)) == 13) return true;
      }
    }
    return false;
  }

  /// Whether drawing or recycling can help: some stock card is unseen, or a
  /// card the stock will show can be played somewhere now.
  static bool stockUseful(SolitaireBoard m, SolitaireOptions o) {
    if (m.stockCount == 0 && (m.wasteCount == 0 || !m.recycleAllowed(o))) return false;
    if (m.stockUnseen) return true;
    final len = m.talonLength;
    final start = m.wasteCount;
    final maxRecycles = o.maxRecycles;
    var recyclesLeft = maxRecycles == null ? 1 : math.min(1, maxRecycles - m.recycles);
    var p = start;
    var recycled = false;
    for (var guard = 0; guard < 2 * len + 4; guard++) {
      if (p < len) {
        p = math.min(p + o.drawCount, len);
      } else if (recyclesLeft > 0) {
        recyclesLeft--;
        recycled = true;
        p = 0;
        continue;
      } else {
        break;
      }
      if (recycled && p >= start) break;
      final card = m.talonAt(p - 1);
      if (m.homePlace(card) >= 0) return true;
      for (var t = 0; t < 7; t++) {
        if (m.fitsColumn(card, t)) return true;
      }
    }
    return false;
  }

  static List<_Candidate> _candidates(SolitaireBoard m, SolitaireOptions o) {
    final out = <_Candidate>[];
    if (m.won) return out;
    for (final a in m.legalActions(o)) {
      final c = _classify(m, o, a);
      if (c != null) out.add(c);
    }
    out.sort((a, b) => a.kind != b.kind ? a.kind.index - b.kind.index : a.order - b.order);
    return out;
  }

  static _Candidate? _classify(SolitaireBoard m, SolitaireOptions o, SolitaireAction a) {
    switch (a.kind) {
      case SolitaireActionKind.autoComplete:
        return _Candidate(a, _Kind.autoComplete, 0);
      case SolitaireActionKind.flip:
        return _Candidate(a, _Kind.reveal, a.column);
      case SolitaireActionKind.draw:
      case SolitaireActionKind.recycle:
        return stockUseful(m, o) ? _Candidate(a, _Kind.stock, 0) : null;
      case SolitaireActionKind.move:
        final from = a.from!;
        final to = a.to!;
        if (from.isFoundation) return null;
        final card = from.isWaste ? m.wasteTop : m.at(from.index, m.colLen(from.index) - a.count);
        final rank = SolitaireBoard.rankOfCode(card);
        if (to.isFoundation) {
          if (m.isSafeHome(card)) return _Candidate(a, _Kind.safeHome, rank * 8 + (from.isWaste ? 0 : 1 + from.index));
          if (from.isColumn && m.colLen(from.index) - 1 == m.down(from.index) && m.down(from.index) > 0) {
            return _Candidate(a, _Kind.reveal, (10 - m.down(from.index)) * 64 + from.index * 8);
          }
          return _Candidate(a, _Kind.otherHome, rank * 8 + (from.isWaste ? 0 : 1 + from.index));
        }
        final emptyTarget = m.colLen(to.index) == 0;
        if (from.isWaste) return _Candidate(a, _Kind.wasteToColumn, (emptyTarget ? 8 : 0) + to.index);
        final c = from.index;
        final k = m.colLen(c) - a.count;
        final d = m.down(c);
        if (k == d && d > 0) {
          return _Candidate(a, _Kind.reveal, (10 - d) * 64 + c * 8 + (emptyTarget ? 7 : to.index));
        }
        if (k == 0 && !emptyTarget && rank != 13 && _kingWaiting(m, c)) {
          return _Candidate(a, _Kind.emptyForKing, c * 8 + to.index);
        }
        return null;
    }
  }

  /// Hard's lookahead (S-75): cards turned up and cards home over at most
  /// [depth] actions, on the masked board only.
  static double _value(SolitaireBoard m, SolitaireOptions o, _Candidate c, int depth) {
    final t = m.copy();
    final downBefore = t.faceDownTotal;
    final homeBefore = t.cardsHome;
    final talonBefore = t.talonLength;
    final unseenDraw = c.action.kind == SolitaireActionKind.draw && t.stockUnseen;
    t.apply(c.action, o);
    if (t.won) return 1000;
    final revealed = downBefore - t.faceDownTotal;
    var v = 10.0 * revealed + 5.0 * (t.cardsHome - homeBefore) + 1.0 * (talonBefore - t.talonLength);
    if (c.kind == _Kind.otherHome) v -= 3;
    if (c.kind == _Kind.emptyForKing) v += 2;
    // A turned-up or newly drawn unseen card ends what can be foreseen.
    if (depth <= 1 || revealed > 0 || unseenDraw) return v;
    final next = _candidates(t, o);
    var best = 0.0;
    for (var i = 0; i < next.length && i < 5; i++) {
      best = math.max(best, _value(t, o, next[i], depth - 1));
    }
    return v + 0.9 * best;
  }
}

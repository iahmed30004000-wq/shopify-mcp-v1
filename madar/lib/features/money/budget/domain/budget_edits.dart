/// Pure edits of a nested budget that keep what the user sees stable
/// (pure Dart, on top of [BudgetMath]).
///
/// * Switching an item between amount and percent keeps its effective
///   amount ([switchMode]).
/// * Moving an item to another parent, or changing what its percent is
///   measured against, keeps its effective amount too: a percent item gets
///   the percent of its new base that yields the same plan ([moveTo],
///   [setPercentBase]).
library;

import '../../../../core/domain/budget_math.dart';
import '../../../../core/domain/enums.dart';

abstract final class BudgetEdits {
  /// [id] and all its descendants (depth-first, [id] first).
  static List<String> subtree(BudgetMath math, String id) {
    final out = <String>[];
    void walk(String n) {
      out.add(n);
      for (final c in math[n]?.childIds ?? const <String>[]) {
        walk(c);
      }
    }

    if (math[id] != null) walk(id);
    return out;
  }

  /// Items [id] may be moved under (everything outside its own subtree),
  /// depth-first.
  static List<BudgetNodeResult> parentCandidates(BudgetMath math, String id) {
    final own = subtree(math, id).toSet();
    return [
      for (final r in math.flattened)
        if (!own.contains(r.node.id)) r,
    ];
  }

  /// [id] switched to [mode] with the same effective amount (and, for
  /// [BudgetMode.percent], the percent of its base that gives it). A
  /// derived item (the sum of its sub-items) switched to amount keeps the
  /// current sum as its own amount.
  static BudgetNode switchMode(BudgetMath math, String id, BudgetMode mode) {
    final r = math[id];
    if (r == null) throw ArgumentError.value(id, 'id', 'Unknown budget item');
    return switch (mode) {
      BudgetMode.amount => math.setAmount(id, r.plannedMilli),
      BudgetMode.percent => math.setPercent(id, math.percentOfBase(id) ?? 0),
    };
  }

  /// [node] (an edited copy of an item of [math] – a new parent or percent
  /// base) re-expressed so its effective amount stays [plannedMilli]: a
  /// percent item gets the matching percent; an amount item gets its cached
  /// percent refreshed.
  static BudgetNode keepAmount(BudgetMath math, BudgetNode node, int plannedMilli) {
    if (node.mode == BudgetMode.percent) {
      final probe = math.replace(node.copyWith(mode: BudgetMode.amount, amountMilli: plannedMilli));
      final pct = probe.percentOfBase(node.id);
      return pct == null ? node : node.copyWith(percent: pct, amountMilli: plannedMilli);
    }
    final pct = math.replace(node).percentOfBase(node.id);
    return pct == null ? node.copyWith(clearPercent: true) : node.copyWith(percent: pct);
  }

  /// [id] moved under [parentId] (null = top level) with its effective
  /// amount kept. A percent-of-parent item moved to the top level becomes a
  /// percent of the total.
  static BudgetNode moveTo(BudgetMath math, String id, String? parentId) {
    final r = math[id];
    if (r == null) throw ArgumentError.value(id, 'id', 'Unknown budget item');
    if (parentId != null && subtree(math, id).contains(parentId)) {
      throw ArgumentError.value(parentId, 'parentId', 'An item cannot move inside itself');
    }
    var moved = r.node.copyWith(parentId: parentId, clearParent: parentId == null);
    if (parentId == null && moved.percentOf == PercentBase.parent) moved = moved.copyWith(percentOf: PercentBase.total);
    return keepAmount(math, moved, r.plannedMilli);
  }

  /// [id] measured against [base] with its effective amount kept.
  static BudgetNode setPercentBase(BudgetMath math, String id, PercentBase base) {
    final r = math[id];
    if (r == null) throw ArgumentError.value(id, 'id', 'Unknown budget item');
    return keepAmount(math, r.node.copyWith(percentOf: base), r.plannedMilli);
  }

  /// Sibling ids of [id] (including it) in display order.
  static List<String> siblings(BudgetMath math, String id) {
    final parent = math[id]?.parentId;
    return [for (final c in math.childrenOf(parent)) c.node.id];
  }

  /// The id order after placing [id] right after [afterId] among their
  /// common siblings (for "add sibling"). Unchanged when they are not
  /// siblings.
  static List<String> placeAfter(List<String> siblingIds, String id, String afterId) {
    final out = [
      for (final s in siblingIds)
        if (s != id) s,
    ];
    final at = out.indexOf(afterId);
    if (at < 0) return siblingIds;
    out.insert(at + 1, id);
    return out;
  }
}

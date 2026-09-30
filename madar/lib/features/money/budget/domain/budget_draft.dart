/// The live model behind the budget item editor (pure Dart).
///
/// A [BudgetDraft] holds the item being edited and a [BudgetMath] preview of
/// the whole budget with that edit applied, so every keystroke can show the
/// other value recalculated exactly: typing an amount shows the percent it
/// is of the parent / total, typing a percent shows the amount it yields.
/// Switching between amount and percent, changing the parent or what the
/// percent is measured against keeps the effective amount.
library;

import 'package:meta/meta.dart';

import '../../../../core/domain/budget_math.dart';
import '../../../../core/domain/enums.dart';
import 'budget_edits.dart';

/// How an item's plan is set.
enum BudgetDraftMode {
  /// A fixed amount (in the item's period and currency).
  amount,

  /// A percent of the parent or of the total.
  percent,

  /// The sum of its sub-items (only for items that have some).
  sum,
}

@immutable
class BudgetDraft {
  const BudgetDraft._({
    required this.base,
    required this.node,
    required this.preview,
    required this.original,
    required this.isNew,
  });

  BudgetDraft._build({required this.base, required this.node, required this.original, required this.isNew})
    : preview = base.replace(node);

  /// Edits the existing item [id] of [math].
  factory BudgetDraft.edit(BudgetMath math, String id) {
    final r = math[id];
    if (r == null) throw ArgumentError.value(id, 'id', 'Unknown budget item');
    return BudgetDraft._(base: math, node: r.node, preview: math, original: r.node, isNew: false);
  }

  /// A new item [id] under [parentId] (null = top level). It starts in
  /// amount mode with no amount; percents are measured against the parent,
  /// or the total at the top level.
  factory BudgetDraft.create(
    BudgetMath math, {
    required String id,
    String? parentId,
    String name = '',
    BudgetPeriod period = BudgetPeriod.monthly,
    String? currency,
    int sortOrder = 1 << 30,
  }) {
    final node = BudgetNode(
      id: id,
      name: name,
      parentId: parentId,
      percentOf: parentId == null ? PercentBase.total : PercentBase.parent,
      period: period,
      currency: currency,
      amountMilli: 0,
      sortOrder: sortOrder,
    );
    return BudgetDraft._build(base: math, node: node, original: node, isNew: true);
  }

  /// The budget before this edit.
  final BudgetMath base;

  /// The item as edited so far.
  final BudgetNode node;

  /// [base] with [node] applied.
  final BudgetMath preview;

  /// The item before this edit.
  final BudgetNode original;
  final bool isNew;

  String get id => node.id;
  BudgetNodeResult get result => preview[node.id]!;
  bool get hasChildren => result.hasChildren;

  BudgetDraftMode get mode {
    if (node.mode == BudgetMode.percent) return BudgetDraftMode.percent;
    if (node.amountMilli == null && hasChildren) return BudgetDraftMode.sum;
    return BudgetDraftMode.amount;
  }

  String get baseCurrency => base.settings.baseCurrency.toUpperCase();
  String get currency => node.currency?.toUpperCase() ?? baseCurrency;

  /// The effective plan in the item's own period and currency.
  int get amountMilli => result.plannedMilli;

  /// Monthly / weekly plan in the base currency.
  int get monthlyMilli => result.monthlyMilli;
  int get weeklyMilli => result.weeklyMilli;

  /// What the percent is measured against (roots always use the total).
  PercentBase get percentBase =>
      node.percentOf == PercentBase.total || node.parentId == null ? PercentBase.total : PercentBase.parent;

  /// The percent of [percentBase]: the typed one in percent mode, else the
  /// effective share (null when the base is zero).
  double? get percent => node.mode == BudgetMode.percent ? node.percent : preview.percentOfBase(node.id);

  double? get percentOfTotal => result.percentOfTotal;
  double? get percentOfParent => result.percentOfParent;

  /// The parent as it would be after this edit.
  BudgetNodeResult? get parent => node.parentId == null ? null : preview[node.parentId!];

  /// The total per month after this edit.
  int get totalMonthlyMilli => preview.totalMonthlyMilli;

  bool get nameValid => node.name.trim().isNotEmpty;
  bool get amountValid => (node.amountMilli ?? 0) >= 0;
  bool get percentValid =>
      node.mode != BudgetMode.percent || ((node.percent ?? 0) >= 0 && (node.percent ?? 0).isFinite);
  bool get isValid => nameValid && amountValid && percentValid;

  bool get dirty => isNew || node != original;

  /// Warnings the preview raises about this item or its parent (allocation
  /// of the parent, percents over 100 %).
  List<BudgetWarning> get warnings => [
    for (final w in preview.warnings)
      if (w.nodeId != null && (w.nodeId == node.id || w.nodeId == node.parentId)) w,
  ];

  BudgetDraft _with(BudgetNode next) => BudgetDraft._build(base: base, node: next, original: original, isNew: isNew);

  BudgetDraft withName(String name) => _with(node.copyWith(name: name));

  /// Sets the amount (own period and currency) and switches to amount mode;
  /// the percent follows.
  BudgetDraft withAmount(int amountMilli) => _with(preview.setAmount(node.id, amountMilli));

  /// Sets the percent of [percentBase] and switches to percent mode; the
  /// amount follows.
  BudgetDraft withPercent(double percent) => _with(preview.setPercent(node.id, percent));

  /// Switches how the plan is set, keeping the effective amount ([BudgetDraftMode.sum]
  /// adopts the sub-items' total instead).
  BudgetDraft withMode(BudgetDraftMode mode) {
    if (mode == this.mode) return this;
    return switch (mode) {
      BudgetDraftMode.amount => _with(BudgetEdits.switchMode(preview, node.id, BudgetMode.amount)),
      BudgetDraftMode.percent => _with(BudgetEdits.switchMode(preview, node.id, BudgetMode.percent)),
      BudgetDraftMode.sum =>
        hasChildren ? _with(node.copyWith(mode: BudgetMode.amount, clearAmount: true, clearPercent: true)) : this,
    };
  }

  /// Measures the percent against the parent or the total, keeping the
  /// effective amount.
  BudgetDraft withPercentBase(PercentBase percentBase) {
    if (node.percentOf == percentBase) return this;
    return _with(BudgetEdits.setPercentBase(preview, node.id, percentBase));
  }

  /// Monthly or weekly. The typed number stays (5 per month becomes 5 per
  /// week); the monthly equivalent follows.
  BudgetDraft withPeriod(BudgetPeriod period) => _refresh(node.copyWith(period: period));

  /// The currency of the amount (null = base). The typed number stays.
  BudgetDraft withCurrency(String? currency) {
    final c = currency?.toUpperCase();
    final next = BudgetNode(
      id: node.id,
      name: node.name,
      parentId: node.parentId,
      mode: node.mode,
      amountMilli: node.amountMilli,
      percent: node.percent,
      percentOf: node.percentOf,
      period: node.period,
      currency: c == null || c == baseCurrency ? null : c,
      sortOrder: node.sortOrder,
    );
    return _refresh(next);
  }

  /// Moves the item under [parentId] (null = top level), keeping the
  /// effective amount.
  BudgetDraft withParent(String? parentId) {
    if (parentId == node.parentId) return this;
    return _with(BudgetEdits.moveTo(preview, node.id, parentId));
  }

  /// Re-derives the cached counterpart value (amount of a percent item,
  /// percent of an amount item) after a change of period or currency.
  BudgetDraft _refresh(BudgetNode next) {
    final m = base.replace(next);
    if (next.mode == BudgetMode.percent) {
      return _with(next.copyWith(amountMilli: m[next.id]!.plannedMilli));
    }
    if (next.amountMilli == null) return _with(next);
    final pct = m.percentOfBase(next.id);
    return _with(pct == null ? next.copyWith(clearPercent: true) : next.copyWith(percent: pct));
  }

  /// The item to persist: trimmed name, and the counterpart value cached
  /// consistently with the preview.
  BudgetNode get toSave {
    final n = node.copyWith(name: node.name.trim());
    if (n.mode == BudgetMode.percent) return n.copyWith(amountMilli: result.plannedMilli);
    if (n.amountMilli == null) return n;
    final pct = preview.percentOfBase(n.id);
    return pct == null ? n.copyWith(clearPercent: true) : n.copyWith(percent: pct);
  }
}

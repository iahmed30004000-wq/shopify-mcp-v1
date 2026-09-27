/// Nested-budget arithmetic (pure Dart, exact).
///
/// A budget is a forest of [BudgetNode]s. Each node is set either by an
/// **amount** (in its own period and currency) or by a **percent** of its
/// parent or of the whole budget; the other value is derived. [BudgetMath]
/// computes, for every node:
///
/// * the monthly plan in the base currency (weekly amounts × weeks-per-month),
///   the weekly plan and the plan in the node's own period/currency;
/// * its effective percent of the parent and of the total;
/// * the sum of its children and how far it is from the node's plan;
/// * warnings (children under / over the parent, overspent items, percent
///   chains that exceed 100 % or are circular, broken parent links, missing
///   exchange rates);
/// * spend vs plan in a monthly or weekly window ([BudgetMath.spend]).
///
/// ### Exactness
/// Every value is kept as an exact [Rational] of milli-units until the very
/// end and rounded **once** per node, half-up (ties away from zero) to the
/// milli. So 5.000/week × 4 weeks = 20.000 and × 4.345 = 21.725 exactly.
///
/// ### Totals and percent-of-total
/// The total is the sum of the root items. Root items set as a percent of
/// the total make that definition circular (`T = A + p·T`); it is solved in
/// closed form (`T = A / (1 − Σp)`), so "savings = 10 % of total" with
/// 300 of fixed items gives T = 333.333 and savings = 33.333. The same closed
/// form resolves a parent without its own amount (its plan is the sum of its
/// children) whose children are percents of it.
library;

import 'package:meta/meta.dart';

import 'enums.dart';
import 'money.dart';

// -------------------------------------------------------------- Inputs ----

/// One budget item (mirrors the `budget_items` table).
@immutable
class BudgetNode {
  const BudgetNode({
    required this.id,
    required this.name,
    this.parentId,
    this.mode = BudgetMode.amount,
    this.amountMilli,
    this.percent,
    this.percentOf = PercentBase.parent,
    this.period = BudgetPeriod.monthly,
    this.currency,
    this.sortOrder = 0,
  });

  final String id;
  final String? parentId;
  final String name;
  final BudgetMode mode;

  /// Amount in [period] and [currency] (milli-units). For an amount-mode
  /// node without an amount the plan is the sum of its children.
  final int? amountMilli;

  /// Percent (0..100) of the parent or of the total ([percentOf]).
  final double? percent;
  final PercentBase percentOf;
  final BudgetPeriod period;

  /// Null = base currency.
  final String? currency;
  final int sortOrder;

  BudgetNode copyWith({
    String? name,
    String? parentId,
    bool clearParent = false,
    BudgetMode? mode,
    int? amountMilli,
    bool clearAmount = false,
    double? percent,
    bool clearPercent = false,
    PercentBase? percentOf,
    BudgetPeriod? period,
    String? currency,
    int? sortOrder,
  }) => BudgetNode(
    id: id,
    name: name ?? this.name,
    parentId: clearParent ? null : (parentId ?? this.parentId),
    mode: mode ?? this.mode,
    amountMilli: clearAmount ? null : (amountMilli ?? this.amountMilli),
    percent: clearPercent ? null : (percent ?? this.percent),
    percentOf: percentOf ?? this.percentOf,
    period: period ?? this.period,
    currency: currency ?? this.currency,
    sortOrder: sortOrder ?? this.sortOrder,
  );

  @override
  bool operator ==(Object other) =>
      other is BudgetNode &&
      other.id == id &&
      other.parentId == parentId &&
      other.name == name &&
      other.mode == mode &&
      other.amountMilli == amountMilli &&
      other.percent == percent &&
      other.percentOf == percentOf &&
      other.period == period &&
      other.currency == currency &&
      other.sortOrder == sortOrder;

  @override
  int get hashCode =>
      Object.hash(id, parentId, name, mode, amountMilli, percent, percentOf, period, currency, sortOrder);

  @override
  String toString() => 'BudgetNode($id "$name" ${mode.name} ${amountMilli ?? '-'} ${percent ?? '-'}%)';
}

/// Budget configuration.
@immutable
class BudgetSettings {
  const BudgetSettings({
    this.weeksPerMonth = defaultWeeksPerMonth,
    this.baseCurrency = 'JOD',
    this.ratesToBase = const {},
    this.weekStart = DateTime.saturday,
  });

  /// Four whole weeks per month – round numbers most people budget with.
  /// Set 4.345 (52.14 / 12) for calendar-accurate monthly totals.
  static const num defaultWeeksPerMonth = 4;

  /// `key_values` key holding the user's weeks-per-month (JSON number).
  static const weeksPerMonthKey = 'money.budget.weeksPerMonth';

  /// Weeks in a month for weekly ↔ monthly conversion (e.g. 4 or 4.345).
  final num weeksPerMonth;

  /// Currency every total is expressed in.
  final String baseCurrency;

  /// Manual rates: 1 unit of the key currency = value base units.
  final Map<String, num> ratesToBase;

  /// First day of a budgeting week ([DateTime.monday] … [DateTime.sunday]).
  final int weekStart;

  Rational get weeksPerMonthRatio => Rational.fromNum(weeksPerMonth);

  BudgetSettings copyWith({num? weeksPerMonth, String? baseCurrency, Map<String, num>? ratesToBase, int? weekStart}) =>
      BudgetSettings(
        weeksPerMonth: weeksPerMonth ?? this.weeksPerMonth,
        baseCurrency: baseCurrency ?? this.baseCurrency,
        ratesToBase: ratesToBase ?? this.ratesToBase,
        weekStart: weekStart ?? this.weekStart,
      );
}

// ------------------------------------------------------------- Outputs ----

enum BudgetWarningKind {
  /// Children add up to less than the parent's plan ([BudgetWarning.amountMilli] short).
  childrenUnder,

  /// Children add up to more than the parent's plan ([BudgetWarning.amountMilli] over).
  childrenOver,

  /// Spent more than planned in the window ([BudgetWarning.amountMilli] over).
  overspent,

  /// A percent, or the percents sharing one base, exceed 100 %
  /// ([BudgetWarning.percent] = the sum). Node id null = the whole budget.
  percentOver100,

  /// The percents cannot be resolved (a parent that is only the sum of
  /// children that are all percents of it).
  circularPercent,

  /// Parent links form a loop; the loop was cut at [BudgetWarning.nodeId].
  circularParent,

  /// The parent id does not exist; the node is treated as a root.
  orphanParent,

  /// No rate for [BudgetWarning.currency]; 1:1 was assumed.
  missingRate,
}

@immutable
class BudgetWarning {
  const BudgetWarning(this.kind, {this.nodeId, this.amountMilli, this.percent, this.currency, this.related = const []});

  final BudgetWarningKind kind;
  final String? nodeId;

  /// Positive magnitude in base-currency milli-units.
  final int? amountMilli;
  final double? percent;
  final String? currency;
  final List<String> related;

  @override
  bool operator ==(Object other) =>
      other is BudgetWarning &&
      other.kind == kind &&
      other.nodeId == nodeId &&
      other.amountMilli == amountMilli &&
      other.percent == percent &&
      other.currency == currency;

  @override
  int get hashCode => Object.hash(kind, nodeId, amountMilli, percent, currency);

  @override
  String toString() =>
      'BudgetWarning(${kind.name}${nodeId == null ? '' : ' $nodeId'}${amountMilli == null ? '' : ' $amountMilli'}'
      '${percent == null ? '' : ' $percent%'}${currency == null ? '' : ' $currency'})';
}

/// Computed values of one node. All `*Milli` values are base-currency
/// milli-units unless noted.
@immutable
class BudgetNodeResult {
  const BudgetNodeResult({
    required this.node,
    required this.depth,
    required this.parentId,
    required this.childIds,
    required this.monthlyMilli,
    required this.weeklyMilli,
    required this.plannedMilli,
    required this.percentOfParent,
    required this.percentOfTotal,
    required this.childrenSumMilli,
    required this.childrenDeltaMilli,
    required this.derivedFromChildren,
  });

  final BudgetNode node;

  /// 0 for roots.
  final int depth;

  /// Effective parent (null for roots, orphans and cut loops).
  final String? parentId;
  final List<String> childIds;

  /// Monthly plan in the base currency.
  final int monthlyMilli;

  /// Weekly plan in the base currency (monthly ÷ weeks-per-month).
  final int weeklyMilli;

  /// The plan in the node's own [BudgetNode.period] and currency – the value
  /// shown next to the item (e.g. 5.000/week).
  final int plannedMilli;

  /// Share of the parent's monthly plan (null for roots / zero parent).
  final double? percentOfParent;

  /// Share of the budget total (null when the total is zero).
  final double? percentOfTotal;

  /// Sum of the children's monthly plans (null without children).
  final int? childrenSumMilli;

  /// Children sum − own plan (0 without children or when derived from them).
  final int childrenDeltaMilli;

  /// The node has no own amount; its plan is the sum of its children.
  final bool derivedFromChildren;

  bool get hasChildren => childIds.isNotEmpty;
}

// ------------------------------------------------------------- Spending ----

/// A transaction as seen by the budget (expenses count, income/transfers
/// are ignored).
@immutable
class BudgetTx {
  const BudgetTx({
    required this.budgetItemId,
    required this.amountMilli,
    required this.date,
    this.currency,
    this.kind = TxKind.expense,
  });

  final String? budgetItemId;

  /// Positive amount in [currency] (null = base).
  final int amountMilli;
  final DateTime date;
  final String? currency;
  final TxKind kind;
}

/// A half-open time window `[start, end)` of one budget period.
@immutable
class BudgetWindow {
  const BudgetWindow(this.start, this.end, this.period);

  /// The calendar month containing [day].
  factory BudgetWindow.month(DateTime day) =>
      BudgetWindow(DateTime(day.year, day.month), DateTime(day.year, day.month + 1), BudgetPeriod.monthly);

  /// The week containing [day], starting on [weekStart] (default Saturday).
  factory BudgetWindow.week(DateTime day, {int weekStart = DateTime.saturday}) {
    final back = (day.weekday - weekStart + 7) % 7;
    final start = DateTime(day.year, day.month, day.day - back);
    return BudgetWindow(start, DateTime(start.year, start.month, start.day + 7), BudgetPeriod.weekly);
  }

  final DateTime start;
  final DateTime end;
  final BudgetPeriod period;

  bool contains(DateTime t) => !t.isBefore(start) && t.isBefore(end);
}

@immutable
class BudgetSpend {
  const BudgetSpend({required this.nodeId, required this.plannedMilli, required this.spentMilli});

  final String nodeId;

  /// Plan for the window's period (monthly or weekly), base currency.
  final int plannedMilli;

  /// Own + descendants' expenses in the window, base currency.
  final int spentMilli;

  int get remainingMilli => plannedMilli - spentMilli;
  bool get overspent => spentMilli > plannedMilli;

  /// Spent ÷ planned (null when nothing is planned).
  double? get ratio => plannedMilli == 0 ? null : spentMilli / plannedMilli;
}

@immutable
class BudgetSpendReport {
  const BudgetSpendReport({
    required this.window,
    required this.byId,
    required this.totalPlannedMilli,
    required this.totalSpentMilli,
    required this.unassignedMilli,
    required this.warnings,
  });

  final BudgetWindow window;
  final Map<String, BudgetSpend> byId;
  final int totalPlannedMilli;
  final int totalSpentMilli;

  /// Expenses in the window that point at no known budget item.
  final int unassignedMilli;

  /// [BudgetWarningKind.overspent] (+ [BudgetWarningKind.missingRate]).
  final List<BudgetWarning> warnings;
}

// ---------------------------------------------------------------- Math ----

/// `a + b·T` where `T` is the budget total (monthly, base milli).
@immutable
class _Aff {
  const _Aff(this.a, this.b);
  final Rational a;
  final Rational b;

  static final zero = _Aff(Rational.zero, Rational.zero);

  _Aff operator +(_Aff o) => _Aff(a + o.a, b + o.b);
  _Aff scale(Rational k) => _Aff(a * k, b * k);
  Rational at(Rational t) => a + b * t;
}

/// Computes a whole budget (see the library documentation). Immutable:
/// editing helpers return updated nodes; [replace] returns a new instance.
class BudgetMath {
  BudgetMath(Iterable<BudgetNode> nodes, {this.settings = const BudgetSettings()})
    : nodes = List.unmodifiable(nodes) {
    _compute();
  }

  final List<BudgetNode> nodes;
  final BudgetSettings settings;

  final Map<String, BudgetNode> _byId = {};
  final Map<String, String?> _parent = {};
  final Map<String, List<String>> _children = {};
  final List<String> _roots = [];
  final Map<String, _Aff> _aff = {};
  final Set<String> _inProgress = {};
  final Map<String, Rational> _value = {};
  final List<BudgetWarning> _warnings = [];
  final Set<String> _missingRates = {};
  late final Map<String, BudgetNodeResult> _results;
  late final Rational _total;

  /// Results by node id.
  Map<String, BudgetNodeResult> get results => _results;

  /// The result of [id], or null.
  BudgetNodeResult? operator [](String id) => _results[id];

  /// Root ids in display order.
  List<String> get rootIds => List.unmodifiable(_roots);

  /// Children of [id] (roots for null) in display order.
  List<BudgetNodeResult> childrenOf(String? id) =>
      [for (final c in id == null ? _roots : (_children[id] ?? const <String>[])) _results[c]!];

  /// Depth-first order (parents before children) – handy for tree lists.
  List<BudgetNodeResult> get flattened {
    final out = <BudgetNodeResult>[];
    void walk(String id) {
      out.add(_results[id]!);
      for (final c in _children[id] ?? const <String>[]) {
        walk(c);
      }
    }

    _roots.forEach(walk);
    return out;
  }

  /// Sum of the root items per month, base currency.
  int get totalMonthlyMilli => _total.roundHalfUp();

  /// Total per week, base currency.
  int get totalWeeklyMilli => (_total / settings.weeksPerMonthRatio).roundHalfUp();

  Money get totalMonthly => Money(totalMonthlyMilli, settings.baseCurrency);

  /// Structural and allocation warnings (spending warnings come from [spend]).
  List<BudgetWarning> get warnings => List.unmodifiable(_warnings);

  // ------------------------------------------------------ conversions ----

  /// Weekly → monthly with [weeksPerMonth], half-up to the milli.
  static int weeklyToMonthly(int weeklyMilli, num weeksPerMonth) =>
      (Rational.fromInt(weeklyMilli) * Rational.fromNum(weeksPerMonth)).roundHalfUp();

  /// Monthly → weekly with [weeksPerMonth], half-up to the milli.
  static int monthlyToWeekly(int monthlyMilli, num weeksPerMonth) =>
      (Rational.fromInt(monthlyMilli) / Rational.fromNum(weeksPerMonth)).roundHalfUp();

  /// Base units per unit of [currency]; null when no usable rate is set.
  Rational? _rateOrNull(String? currency) {
    if (currency == null || currency.toUpperCase() == settings.baseCurrency.toUpperCase()) return Rational.one;
    final r = settings.ratesToBase[currency.toUpperCase()] ?? settings.ratesToBase[currency];
    if (r == null || r <= 0 || r is double && !r.isFinite) return null;
    return Rational.fromNum(r);
  }

  /// Like [_rateOrNull] but assumes 1:1 (and warns once) for a missing rate.
  Rational _rate(String? currency) {
    final r = _rateOrNull(currency);
    if (r != null) return r;
    if (_missingRates.add(currency!.toUpperCase())) {
      _warnings.add(BudgetWarning(BudgetWarningKind.missingRate, currency: currency.toUpperCase()));
    }
    return Rational.one;
  }

  /// Own amount → monthly base (exact).
  Rational _monthlyBase(BudgetNode n, int amountMilli) {
    var v = Rational.fromInt(amountMilli);
    if (n.period == BudgetPeriod.weekly) v = v * settings.weeksPerMonthRatio;
    return v * _rate(n.currency);
  }

  /// Monthly base → own period and currency (exact).
  Rational _ownFromMonthlyBase(BudgetNode n, Rational monthlyBase) {
    var v = monthlyBase / _rate(n.currency);
    if (n.period == BudgetPeriod.weekly) v = v / settings.weeksPerMonthRatio;
    return v;
  }

  static Rational _pct(BudgetNode n) => Rational.fromNum(n.percent ?? 0) / Rational.hundred;

  bool _dependsOnParent(BudgetNode n) =>
      n.mode == BudgetMode.percent && n.percentOf == PercentBase.parent && _parent[n.id] != null;

  // ---------------------------------------------------------- compute ----

  void _compute() {
    for (final n in nodes) {
      _byId[n.id] = n;
    }
    final order = {for (var i = 0; i < nodes.length; i++) nodes[i].id: i};
    int compare(String a, String b) {
      final s = _byId[a]!.sortOrder.compareTo(_byId[b]!.sortOrder);
      return s != 0 ? s : order[a]!.compareTo(order[b]!);
    }

    // Parent links: orphans become roots; loops are cut.
    for (final n in _byId.values) {
      final p = n.parentId;
      if (p == null || p == n.id) {
        _parent[n.id] = null;
        if (p == n.id) _warnings.add(BudgetWarning(BudgetWarningKind.circularParent, nodeId: n.id, related: [n.id]));
      } else if (!_byId.containsKey(p)) {
        _parent[n.id] = null;
        _warnings.add(BudgetWarning(BudgetWarningKind.orphanParent, nodeId: n.id, related: [p]));
      } else {
        _parent[n.id] = p;
      }
    }
    final sortedIds = _byId.keys.toList()..sort(compare);
    for (final id in sortedIds) {
      final path = <String>[];
      final seen = <String>{};
      String? cur = id;
      while (cur != null && seen.add(cur)) {
        path.add(cur);
        cur = _parent[cur];
      }
      if (cur != null) {
        // `cur` closes a loop; cut it at the loop member that sorts first.
        final loop = path.sublist(path.indexOf(cur));
        final cutAt = (List.of(loop)..sort(compare)).first;
        _parent[cutAt] = null;
        _warnings.add(BudgetWarning(BudgetWarningKind.circularParent, nodeId: cutAt, related: loop));
      }
    }
    for (final id in sortedIds) {
      final p = _parent[id];
      if (p == null) {
        _roots.add(id);
      } else {
        (_children[p] ??= []).add(id);
      }
    }

    // Affine plans, then the total.
    var sum = _Aff.zero;
    for (final r in _roots) {
      sum += _affine(r);
    }
    final bSum = sum.b;
    if (bSum >= Rational.one) {
      // Σ percent-of-total ≥ 100 %: T = A + p·T has no (finite, unique)
      // solution. Exactly 100 % is circular; more is over-allocated.
      _warnings.add(
        BudgetWarning(
          bSum > Rational.one ? BudgetWarningKind.percentOver100 : BudgetWarningKind.circularPercent,
          percent: (bSum * Rational.hundred).toDouble(),
        ),
      );
      _total = sum.a;
    } else {
      _total = sum.a / (Rational.one - bSum);
    }
    for (final id in _byId.keys) {
      _value[id] = _affine(id).at(_total);
    }
    final rootSum = _roots.fold(Rational.zero, (a, r) => a + _value[r]!);
    if (bSum >= Rational.one) _total = rootSum;

    // Percent-of-parent siblings that together claim more than their parent
    // (a derived parent reports this from `_rollup` instead).
    for (final entry in _children.entries) {
      final parent = _byId[entry.key]!;
      if (parent.mode == BudgetMode.amount && parent.amountMilli == null) continue;
      var p = Rational.zero;
      for (final c in entry.value) {
        if (_dependsOnParent(_byId[c]!)) p += _pct(_byId[c]!);
      }
      if (p > Rational.one) {
        _warnings.add(
          BudgetWarning(
            BudgetWarningKind.percentOver100,
            nodeId: entry.key,
            percent: (p * Rational.hundred).toDouble(),
            related: [for (final c in entry.value) if (_dependsOnParent(_byId[c]!)) c],
          ),
        );
      }
    }

    // Results.
    final results = <String, BudgetNodeResult>{};
    int depthOf(String id) {
      var d = 0;
      for (var p = _parent[id]; p != null; p = _parent[p]) {
        d++;
      }
      return d;
    }

    for (final id in sortedIds) {
      final n = _byId[id]!;
      final v = _value[id]!;
      final kids = _children[id] ?? const <String>[];
      final parent = _parent[id];
      final derived = n.mode == BudgetMode.amount && n.amountMilli == null && kids.isNotEmpty;
      Rational? childSum;
      var delta = 0;
      if (kids.isNotEmpty) {
        childSum = kids.fold<Rational>(Rational.zero, (a, c) => a + _value[c]!);
        if (!derived) {
          delta = (childSum - v).roundHalfUp();
          if (delta != 0) {
            _warnings.add(
              BudgetWarning(
                delta < 0 ? BudgetWarningKind.childrenUnder : BudgetWarningKind.childrenOver,
                nodeId: id,
                amountMilli: delta.abs(),
              ),
            );
          }
        }
      }
      final pv = parent == null ? null : _value[parent]!;
      results[id] = BudgetNodeResult(
        node: n,
        depth: depthOf(id),
        parentId: parent,
        childIds: List.unmodifiable(kids),
        monthlyMilli: v.roundHalfUp(),
        weeklyMilli: (v / settings.weeksPerMonthRatio).roundHalfUp(),
        plannedMilli: n.mode == BudgetMode.amount && n.amountMilli != null
            ? n.amountMilli!
            : _ownFromMonthlyBase(n, v).roundHalfUp(),
        percentOfParent: pv == null || pv.isZero ? null : (v / pv * Rational.hundred).toDouble(),
        percentOfTotal: _total.isZero ? null : (v / _total * Rational.hundred).toDouble(),
        childrenSumMilli: childSum?.roundHalfUp(),
        childrenDeltaMilli: delta,
        derivedFromChildren: derived,
      );
    }
    _results = Map.unmodifiable(results);
  }

  _Aff _affine(String id) {
    final memo = _aff[id];
    if (memo != null) return memo;
    if (!_inProgress.add(id)) {
      _warnings.add(BudgetWarning(BudgetWarningKind.circularPercent, nodeId: id));
      return _Aff.zero;
    }
    final n = _byId[id]!;
    final _Aff result;
    if (n.mode == BudgetMode.percent) {
      final pct = _pct(n);
      if (pct > Rational.one) {
        _warnings.add(BudgetWarning(BudgetWarningKind.percentOver100, nodeId: id, percent: n.percent));
      }
      final parent = _parent[id];
      if (n.percentOf == PercentBase.total || parent == null) {
        result = _Aff(Rational.zero, pct);
      } else {
        result = _affine(parent).scale(pct);
      }
    } else if (n.amountMilli != null) {
      result = _Aff(_monthlyBase(n, n.amountMilli!), Rational.zero);
    } else if ((_children[id] ?? const []).isNotEmpty) {
      result = _rollup(n);
    } else {
      result = _Aff.zero;
    }
    _inProgress.remove(id);
    return _aff[id] = result;
  }

  /// A parent without an own amount = Σ children, where children that are a
  /// percent of it are solved in closed form: `x = I / (1 − Σp)`.
  _Aff _rollup(BudgetNode n) {
    var independent = _Aff.zero;
    var p = Rational.zero;
    for (final c in _children[n.id]!) {
      final child = _byId[c]!;
      if (_dependsOnParent(child)) {
        p += _pct(child);
      } else {
        independent += _affine(c);
      }
    }
    if (p.isZero) return independent;
    if (p >= Rational.one) {
      _warnings.add(
        BudgetWarning(
          p > Rational.one ? BudgetWarningKind.percentOver100 : BudgetWarningKind.circularPercent,
          nodeId: n.id,
          percent: (p * Rational.hundred).toDouble(),
        ),
      );
      return independent;
    }
    return independent.scale(Rational.one / (Rational.one - p));
  }

  // ---------------------------------------------------------- editing ----

  /// A new budget with [node] replacing the node of the same id (or added).
  BudgetMath replace(BudgetNode node) {
    final next = [for (final n in nodes) n.id == node.id ? node : n];
    if (!_byId.containsKey(node.id)) next.add(node);
    return BudgetMath(next, settings: settings);
  }

  /// Percent of the node's own base (its parent, or the total for
  /// `percentOf: total` and roots).
  double? percentOfBase(String id) {
    final r = _results[id];
    if (r == null) return null;
    final n = r.node;
    if (n.percentOf == PercentBase.total || r.parentId == null) return r.percentOfTotal;
    return r.percentOfParent;
  }

  /// Sets [id] to [amountMilli] (in its own period and currency), switches it
  /// to amount mode and recomputes its percent of its base so both stay
  /// consistent. Returns the updated node (persist it, or pass to [replace]).
  BudgetNode setAmount(String id, int amountMilli) {
    final n = _byId[id];
    if (n == null) throw ArgumentError.value(id, 'id', 'Unknown budget item');
    final updated = n.copyWith(mode: BudgetMode.amount, amountMilli: amountMilli);
    final pct = replace(updated).percentOfBase(id);
    return pct == null ? updated.copyWith(clearPercent: true) : updated.copyWith(percent: pct);
  }

  /// Sets [id] to [percent] of its base, switches it to percent mode and
  /// recomputes its amount (own period and currency, half-up). Returns the
  /// updated node.
  BudgetNode setPercent(String id, double percent) {
    final n = _byId[id];
    if (n == null) throw ArgumentError.value(id, 'id', 'Unknown budget item');
    final updated = n.copyWith(mode: BudgetMode.percent, percent: percent);
    return updated.copyWith(amountMilli: replace(updated)[id]!.plannedMilli);
  }

  // --------------------------------------------------------- spending ----

  /// Spend vs plan in [window] from [transactions]: expenses booked to an
  /// item count for it and all its ancestors; the plan is the monthly or
  /// weekly plan matching the window's period.
  BudgetSpendReport spend(Iterable<BudgetTx> transactions, BudgetWindow window) {
    final own = <String, Rational>{};
    var unassigned = Rational.zero;
    final missing = <String>{};
    final rateWarnings = <BudgetWarning>[];
    for (final tx in transactions) {
      if (tx.kind != TxKind.expense || !window.contains(tx.date)) continue;
      var rate = _rateOrNull(tx.currency);
      if (rate == null) {
        rate = Rational.one;
        final code = tx.currency!.toUpperCase();
        if (missing.add(code)) rateWarnings.add(BudgetWarning(BudgetWarningKind.missingRate, currency: code));
      }
      final base = Rational.fromInt(tx.amountMilli.abs()) * rate;
      final id = tx.budgetItemId;
      if (id == null || !_byId.containsKey(id)) {
        unassigned += base;
      } else {
        own[id] = (own[id] ?? Rational.zero) + base;
      }
    }
    final spent = <String, Rational>{};
    Rational total(String id) {
      final cached = spent[id];
      if (cached != null) return cached;
      var s = own[id] ?? Rational.zero;
      for (final c in _children[id] ?? const <String>[]) {
        s += total(c);
      }
      return spent[id] = s;
    }

    final byId = <String, BudgetSpend>{};
    final warnings = <BudgetWarning>[...rateWarnings];
    for (final id in _byId.keys) {
      final r = _results[id]!;
      final planned = window.period == BudgetPeriod.weekly ? r.weeklyMilli : r.monthlyMilli;
      final s = BudgetSpend(nodeId: id, plannedMilli: planned, spentMilli: total(id).roundHalfUp());
      byId[id] = s;
      if (s.overspent) {
        warnings.add(BudgetWarning(BudgetWarningKind.overspent, nodeId: id, amountMilli: -s.remainingMilli));
      }
    }
    final rootsSpent = _roots.fold(Rational.zero, (a, r) => a + total(r));
    return BudgetSpendReport(
      window: window,
      byId: Map.unmodifiable(byId),
      totalPlannedMilli: window.period == BudgetPeriod.weekly ? totalWeeklyMilli : totalMonthlyMilli,
      totalSpentMilli: rootsSpent.roundHalfUp(),
      unassignedMilli: unassigned.roundHalfUp(),
      warnings: List.unmodifiable(warnings),
    );
  }
}

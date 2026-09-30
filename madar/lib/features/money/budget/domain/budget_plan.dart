/// Display model of a nested budget, built on [BudgetMath] (pure Dart).
///
/// [BudgetPlan] flattens the tree (parents before children, in the user's
/// order), attaches every structural warning – and, when a spend report is
/// given, every overspent item – to the line it concerns, and ranks them for
/// the warnings summary. No arithmetic is repeated here: every number comes
/// from [BudgetMath].
library;

import 'package:meta/meta.dart';

import '../../../../core/domain/budget_math.dart';
import '../../../../core/domain/enums.dart';

/// How loudly a warning is shown.
enum BudgetIssueSeverity { notice, warning, danger }

/// One warning of the budget, placed on a line (or on the whole budget).
@immutable
class BudgetIssue {
  const BudgetIssue(this.warning, {required this.severity, this.selfPercent = false});

  /// Classifies [warning] against [math].
  factory BudgetIssue.of(BudgetWarning warning, BudgetMath math) {
    final node = warning.nodeId == null ? null : math[warning.nodeId!]?.node;
    final self =
        warning.kind == BudgetWarningKind.percentOver100 &&
        node != null &&
        node.mode == BudgetMode.percent &&
        warning.related.isEmpty &&
        node.percent == warning.percent;
    return BudgetIssue(warning, severity: severityOf(warning.kind), selfPercent: self);
  }

  final BudgetWarning warning;
  final BudgetIssueSeverity severity;

  /// For [BudgetWarningKind.percentOver100]: the item's own percent is over
  /// 100 % (otherwise the percents of its sub-items, or of the root items
  /// when [nodeId] is null, add up to more than 100 %).
  final bool selfPercent;

  BudgetWarningKind get kind => warning.kind;
  String? get nodeId => warning.nodeId;

  /// Base-currency milli-units (under / over allocation, overspend).
  int? get amountMilli => warning.amountMilli;
  double? get percent => warning.percent;

  static BudgetIssueSeverity severityOf(BudgetWarningKind kind) => switch (kind) {
    BudgetWarningKind.childrenOver ||
    BudgetWarningKind.overspent ||
    BudgetWarningKind.percentOver100 ||
    BudgetWarningKind.circularPercent => BudgetIssueSeverity.danger,
    BudgetWarningKind.childrenUnder || BudgetWarningKind.missingRate => BudgetIssueSeverity.warning,
    BudgetWarningKind.circularParent || BudgetWarningKind.orphanParent => BudgetIssueSeverity.notice,
  };

  @override
  bool operator ==(Object other) =>
      other is BudgetIssue &&
      other.warning == warning &&
      other.severity == severity &&
      other.selfPercent == selfPercent;

  @override
  int get hashCode => Object.hash(warning, severity, selfPercent);

  @override
  String toString() => 'BudgetIssue(${severity.name} $warning)';
}

/// One item of the budget as the tree shows it.
@immutable
class BudgetLine {
  const BudgetLine({required this.result, required this.baseCurrency, required this.issues, this.spend});

  final BudgetNodeResult result;
  final String baseCurrency;

  /// Warnings about this item (allocation, percent, overspending).
  final List<BudgetIssue> issues;

  /// Spend in the plan's report window (the current month), if known.
  final BudgetSpend? spend;

  BudgetNode get node => result.node;
  String get id => node.id;
  String get name => node.name;
  String? get parentId => result.parentId;
  int get depth => result.depth;
  bool get hasChildren => result.hasChildren;
  List<String> get childIds => result.childIds;
  BudgetPeriod get period => node.period;

  /// The item's own currency (the base currency when none is set).
  String get currency => node.currency?.toUpperCase() ?? baseCurrency;
  bool get isForeign => currency != baseCurrency.toUpperCase();

  /// The value shown next to the item: its plan in its own period and
  /// currency (e.g. 5.000 per week).
  int get plannedMilli => result.plannedMilli;

  /// Plan per month / per week in the base currency.
  int get monthlyMilli => result.monthlyMilli;
  int get weeklyMilli => result.weeklyMilli;

  bool get setByPercent => node.mode == BudgetMode.percent;

  /// The plan is the sum of the sub-items (no own amount).
  bool get derived => result.derivedFromChildren;

  /// What the item's percent is measured against: its parent, or the total
  /// (roots and `percentOf: total`).
  PercentBase get percentBase =>
      node.percentOf == PercentBase.total || result.parentId == null ? PercentBase.total : PercentBase.parent;

  /// Effective percent of [percentBase] (null when that base is zero). For
  /// an item set by percent this is the percent the user typed.
  double? get percentOfBase => percentBase == PercentBase.total ? result.percentOfTotal : result.percentOfParent;
  double? get percentOfParent => result.percentOfParent;
  double? get percentOfTotal => result.percentOfTotal;

  int? get childrenSumMilli => result.childrenSumMilli;

  /// Children sum − own plan (monthly, base currency).
  int get childrenDeltaMilli => result.childrenDeltaMilli;

  bool get hasIssues => issues.isNotEmpty;

  BudgetIssueSeverity? get worstSeverity {
    BudgetIssueSeverity? worst;
    for (final i in issues) {
      if (worst == null || i.severity.index > worst.index) worst = i.severity;
    }
    return worst;
  }
}

/// The whole budget ready for display.
@immutable
class BudgetPlan {
  const BudgetPlan._({
    required this.math,
    required this.lines,
    required this.byId,
    required this.issues,
    required this.globalIssues,
    required this.report,
  });

  /// Builds the display model of [math]. With [report] (normally the
  /// current month) overspent items carry an [BudgetWarningKind.overspent]
  /// issue as well.
  factory BudgetPlan(BudgetMath math, {BudgetSpendReport? report}) {
    final base = math.settings.baseCurrency.toUpperCase();
    final all = <BudgetIssue>[
      for (final w in math.warnings) BudgetIssue.of(w, math),
      if (report != null)
        for (final w in report.warnings)
          if (w.kind == BudgetWarningKind.overspent || !math.warnings.contains(w)) BudgetIssue.of(w, math),
    ];
    final byNode = <String, List<BudgetIssue>>{};
    final global = <BudgetIssue>[];
    for (final i in all) {
      final id = i.nodeId;
      if (id == null || math[id] == null) {
        global.add(i);
      } else {
        (byNode[id] ??= []).add(i);
      }
    }
    final lines = <BudgetLine>[];
    final byId = <String, BudgetLine>{};
    final order = <String, int>{};
    for (final r in math.flattened) {
      final issues = [...?byNode[r.node.id]]..sort((a, b) => b.severity.index.compareTo(a.severity.index));
      final line = BudgetLine(
        result: r,
        baseCurrency: base,
        issues: List.unmodifiable(issues),
        spend: report?.byId[r.node.id],
      );
      order[r.node.id] = lines.length;
      lines.add(line);
      byId[r.node.id] = line;
    }
    // Summary order: most severe first, then tree order; whole-budget issues
    // lead within their severity.
    final ranked = [...all]
      ..sort((a, b) {
        final s = b.severity.index.compareTo(a.severity.index);
        if (s != 0) return s;
        final oa = a.nodeId == null ? -1 : order[a.nodeId] ?? -1;
        final ob = b.nodeId == null ? -1 : order[b.nodeId] ?? -1;
        return oa.compareTo(ob);
      });
    return BudgetPlan._(
      math: math,
      lines: List.unmodifiable(lines),
      byId: Map.unmodifiable(byId),
      issues: List.unmodifiable(ranked),
      globalIssues: List.unmodifiable(global),
      report: report,
    );
  }

  final BudgetMath math;

  /// Depth-first (parents before children, siblings in the user's order).
  final List<BudgetLine> lines;
  final Map<String, BudgetLine> byId;

  /// Every issue, most severe first (the warnings summary).
  final List<BudgetIssue> issues;

  /// Issues about the whole budget (root percents over 100 %, missing rates).
  final List<BudgetIssue> globalIssues;
  final BudgetSpendReport? report;

  bool get isEmpty => lines.isEmpty;
  String get baseCurrency => math.settings.baseCurrency.toUpperCase();
  int get totalMonthlyMilli => math.totalMonthlyMilli;
  int get totalWeeklyMilli => math.totalWeeklyMilli;
  num get weeksPerMonth => math.settings.weeksPerMonth;

  BudgetLine? operator [](String id) => byId[id];

  List<BudgetLine> get roots => [
    for (final l in lines)
      if (l.depth == 0) l,
  ];

  List<BudgetLine> childrenOf(String? id) =>
      id == null ? roots : [for (final c in byId[id]?.childIds ?? const <String>[]) byId[c]!];

  int get dangerCount => issues.where((i) => i.severity == BudgetIssueSeverity.danger).length;

  /// Names from the root down to [id] (`["Home food", "Proteins"]`).
  List<String> pathOf(String id) {
    final out = <String>[];
    String? cur = id;
    final seen = <String>{};
    while (cur != null && seen.add(cur)) {
      final l = byId[cur];
      if (l == null) break;
      out.insert(0, l.name);
      cur = l.parentId;
    }
    return out;
  }
}

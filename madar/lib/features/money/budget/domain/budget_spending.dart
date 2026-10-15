/// Spend vs plan for one budget period, its projection and the previous
/// periods (pure Dart, on top of [BudgetMath.spend]).
library;

import 'package:meta/meta.dart';

import '../../../../core/domain/budget_math.dart';
import '../../../../core/domain/enums.dart';
import '../../../../core/domain/money.dart';

/// Calendar arithmetic of budget periods.
abstract final class BudgetPeriods {
  /// The month / week (starting on [weekStart]) that contains [day].
  static BudgetWindow containing(BudgetPeriod period, DateTime day, {int weekStart = DateTime.saturday}) =>
      period == BudgetPeriod.weekly ? BudgetWindow.week(day, weekStart: weekStart) : BudgetWindow.month(day);

  /// The period [by] steps after (negative: before) [window].
  static BudgetWindow shift(BudgetWindow window, int by, {int weekStart = DateTime.saturday}) {
    final s = window.start;
    return window.period == BudgetPeriod.weekly
        ? BudgetWindow.week(DateTime(s.year, s.month, s.day + 7 * by), weekStart: weekStart)
        : BudgetWindow.month(DateTime(s.year, s.month + by));
  }

  /// Calendar days in [window] (7 for a week, 28–31 for a month).
  static int days(BudgetWindow window) => _dayNumber(window.end) - _dayNumber(window.start);

  /// Days of [window] up to and including [today] (0 before it, [days]
  /// after it).
  static int elapsedDays(BudgetWindow window, DateTime today) {
    final n = _dayNumber(today) - _dayNumber(window.start) + 1;
    return n.clamp(0, days(window));
  }

  /// Whether [today] falls in [window].
  static bool isCurrent(BudgetWindow window, DateTime today) =>
      window.contains(DateTime(today.year, today.month, today.day));

  /// End-of-period spend at the current pace: [spentMilli] × days ÷
  /// elapsed days, exact and half-up. The spend itself for a finished
  /// period, null for one that has not started.
  static int? project(int spentMilli, BudgetWindow window, DateTime today) {
    final elapsed = elapsedDays(window, today);
    if (elapsed == 0) return null;
    final total = days(window);
    if (elapsed >= total) return spentMilli;
    return (Rational.fromInt(spentMilli) * Rational.fromInt(total, elapsed)).roundHalfUp();
  }

  /// Whether enough of the period has passed for a projection to mean
  /// something (a fifth of it, and at least two days).
  static bool projectionReliable(BudgetWindow window, DateTime today) {
    final elapsed = elapsedDays(window, today);
    final total = days(window);
    return elapsed >= total || elapsed >= (total / 5).ceil().clamp(2, total);
  }

  /// A zone-free day number (days since the epoch of the calendar day).
  static int _dayNumber(DateTime d) => DateTime.utc(d.year, d.month, d.day).millisecondsSinceEpoch ~/ 86400000;
}

/// Where an item stands in its period.
enum SpendStatus {
  /// Nothing planned and nothing spent.
  idle,

  /// Within the plan.
  calm,

  /// On pace to exceed the plan by the end of the period.
  atRisk,

  /// At least [BudgetSpending.nearRatio] of the plan is spent.
  near,

  /// More than planned is spent.
  over,

  /// Spent with nothing planned.
  unplanned,
}

@immutable
class SpendLine {
  const SpendLine({
    required this.id,
    required this.name,
    required this.depth,
    required this.parentId,
    required this.hasChildren,
    required this.plannedMilli,
    required this.spentMilli,
    required this.projectedMilli,
    required this.status,
  });

  final String id;
  final String name;
  final int depth;
  final String? parentId;
  final bool hasChildren;

  /// Plan for the window's period (monthly or weekly), base currency.
  final int plannedMilli;

  /// Own + sub-items' expenses in the window, base currency.
  final int spentMilli;

  /// End-of-period spend at the current pace (null when unknown).
  final int? projectedMilli;
  final SpendStatus status;

  int get remainingMilli => plannedMilli - spentMilli;
  bool get overspent => spentMilli > plannedMilli;

  /// Spent ÷ planned (null when nothing is planned).
  double? get ratio => plannedMilli == 0 ? null : spentMilli / plannedMilli;
}

/// Plan vs spent of one past (or the current) period.
@immutable
class BudgetPeriodSummary {
  const BudgetPeriodSummary({
    required this.window,
    required this.plannedMilli,
    required this.spentMilli,
    required this.overspentItems,
  });

  final BudgetWindow window;
  final int plannedMilli;
  final int spentMilli;

  /// Leaf items spent over their plan in this period.
  final int overspentItems;

  int get remainingMilli => plannedMilli - spentMilli;
  bool get overspent => spentMilli > plannedMilli;
}

/// Spend vs plan in one window, with the history of previous windows.
@immutable
class BudgetSpending {
  const BudgetSpending._({
    required this.window,
    required this.today,
    required this.report,
    required this.lines,
    required this.projectedMilli,
    required this.history,
  });

  /// Spend of [math]'s items in [window] from [transactions] (expenses in
  /// any currency, converted at the manual rates), with the previous
  /// [historyCount] − 1 periods (the plan is today's plan for every period).
  factory BudgetSpending.build({
    required BudgetMath math,
    required Iterable<BudgetTx> transactions,
    required BudgetWindow window,
    required DateTime today,
    int historyCount = 6,
    int weekStart = DateTime.saturday,
  }) {
    final txs = transactions.toList(growable: false);
    final report = math.spend(txs, window);
    final current = BudgetPeriods.isCurrent(window, today);
    final reliable = BudgetPeriods.projectionReliable(window, today);
    int? projectionOf(int spent) => BudgetPeriods.project(spent, window, today);
    final lines = <SpendLine>[];
    for (final r in math.flattened) {
      final s = report.byId[r.node.id];
      if (s == null) continue;
      final projected = projectionOf(s.spentMilli);
      lines.add(
        SpendLine(
          id: r.node.id,
          name: r.node.name,
          depth: r.depth,
          parentId: r.parentId,
          hasChildren: r.hasChildren,
          plannedMilli: s.plannedMilli,
          spentMilli: s.spentMilli,
          projectedMilli: projected,
          status: statusOf(
            plannedMilli: s.plannedMilli,
            spentMilli: s.spentMilli,
            projectedMilli: current && reliable ? projected : null,
          ),
        ),
      );
    }
    final history = <BudgetPeriodSummary>[
      for (var i = historyCount - 1; i >= 1; i--)
        summaryOf(math, txs, BudgetPeriods.shift(window, -i, weekStart: weekStart)),
      _summary(math, report),
    ];
    return BudgetSpending._(
      window: window,
      today: today,
      report: report,
      lines: List.unmodifiable(lines),
      projectedMilli: projectionOf(report.totalSpentMilli),
      history: List.unmodifiable(history),
    );
  }

  /// Share of the plan from which an item counts as nearly spent.
  static const double nearRatio = 0.85;

  static SpendStatus statusOf({required int plannedMilli, required int spentMilli, int? projectedMilli}) {
    if (plannedMilli <= 0) return spentMilli > 0 ? SpendStatus.unplanned : SpendStatus.idle;
    if (spentMilli > plannedMilli) return SpendStatus.over;
    if (spentMilli >= plannedMilli * nearRatio) return SpendStatus.near;
    if (projectedMilli != null && projectedMilli > plannedMilli) return SpendStatus.atRisk;
    return SpendStatus.calm;
  }

  /// Plan vs spent of [math] in [window].
  static BudgetPeriodSummary summaryOf(BudgetMath math, Iterable<BudgetTx> transactions, BudgetWindow window) =>
      _summary(math, math.spend(transactions, window));

  static BudgetPeriodSummary _summary(BudgetMath math, BudgetSpendReport report) => BudgetPeriodSummary(
    window: report.window,
    plannedMilli: report.totalPlannedMilli,
    spentMilli: report.totalSpentMilli,
    overspentItems: [
      for (final w in report.warnings)
        if (w.kind == BudgetWarningKind.overspent && !(math[w.nodeId!]?.hasChildren ?? true)) w,
    ].length,
  );

  final BudgetWindow window;
  final DateTime today;
  final BudgetSpendReport report;

  /// Depth-first, like the plan.
  final List<SpendLine> lines;

  /// End-of-period total spend at the current pace (null for a future window).
  final int? projectedMilli;

  /// Oldest first; the last entry is [window] itself.
  final List<BudgetPeriodSummary> history;

  int get plannedMilli => report.totalPlannedMilli;
  int get spentMilli => report.totalSpentMilli;
  int get remainingMilli => plannedMilli - spentMilli;

  /// Expenses in the window booked to no budget item.
  int get unassignedMilli => report.unassignedMilli;

  bool get isCurrent => BudgetPeriods.isCurrent(window, today);
  bool get isPast => !window.end.isAfter(DateTime(today.year, today.month, today.day));
  int get days => BudgetPeriods.days(window);
  int get elapsedDays => BudgetPeriods.elapsedDays(window, today);

  /// Whether [projectedMilli] is worth showing (the current period, far
  /// enough in).
  bool get projectionReliable => isCurrent && BudgetPeriods.projectionReliable(window, today);

  SpendStatus get status => statusOf(
    plannedMilli: plannedMilli,
    spentMilli: spentMilli,
    projectedMilli: projectionReliable ? projectedMilli : null,
  );

  /// Items spent over their plan (leaves and parents).
  List<SpendLine> get overspent => [
    for (final l in lines)
      if (l.status == SpendStatus.over || l.status == SpendStatus.unplanned) l,
  ];

  SpendLine? line(String id) {
    for (final l in lines) {
      if (l.id == id) return l;
    }
    return null;
  }
}

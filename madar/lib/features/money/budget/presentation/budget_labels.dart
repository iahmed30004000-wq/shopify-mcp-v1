import 'package:flutter/material.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/domain/budget_math.dart';
import '../../../../core/domain/enums.dart';
import '../../../../core/i18n/formatters.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../domain/budget_plan.dart';
import '../domain/budget_spending.dart';
import 'budget_format.dart';

/// Localised text, icons and colours of budget warnings and states.
abstract final class BudgetLabels {
  /// A user's item name, isolated so it never reorders the sentence around it.
  static String name(String name) => BidiIsolate.isolate(name.trim().isEmpty ? '…' : name.trim());

  /// The full sentence of [issue] for the warnings summary.
  static String issue(L10n l, BudgetFormat f, BudgetPlan plan, BudgetIssue issue) {
    final id = issue.nodeId;
    final n = id == null ? '' : name(plan[id]?.name ?? '');
    final amount = f.money(issue.amountMilli ?? 0);
    final pct = f.percent(issue.percent);
    return switch (issue.kind) {
      BudgetWarningKind.childrenUnder => l.budgetIssueChildrenUnder(n, amount),
      BudgetWarningKind.childrenOver => l.budgetIssueChildrenOver(n, amount),
      BudgetWarningKind.overspent => l.budgetIssueOverspent(n, amount),
      BudgetWarningKind.percentOver100 when id == null => l.budgetIssuePercentTotal(pct),
      BudgetWarningKind.percentOver100 when issue.selfPercent => l.budgetIssuePercentSelf(n, pct),
      BudgetWarningKind.percentOver100 => l.budgetIssuePercentChildren(n, pct),
      BudgetWarningKind.circularPercent when id == null => l.budgetIssueCircularTotal,
      BudgetWarningKind.circularPercent => l.budgetIssueCircular(n),
      BudgetWarningKind.circularParent => l.budgetIssueCircularParent(n),
      BudgetWarningKind.orphanParent => l.budgetIssueOrphan(n),
      BudgetWarningKind.missingRate => l.budgetIssueMissingRate(BidiIsolate.isolate(issue.warning.currency ?? '')),
    };
  }

  /// The short inline badge of [issue] on its row.
  static String badge(L10n l, BudgetFormat f, BudgetIssue issue) {
    final amount = f.money(issue.amountMilli ?? 0);
    return switch (issue.kind) {
      BudgetWarningKind.childrenUnder => l.budgetBadgeUnder(amount),
      BudgetWarningKind.childrenOver => l.budgetBadgeOver(amount),
      BudgetWarningKind.overspent => l.budgetBadgeOverspent(amount),
      BudgetWarningKind.percentOver100 => l.budgetBadgePercent(f.percent(issue.percent)),
      BudgetWarningKind.circularPercent => l.budgetBadgeCircular,
      BudgetWarningKind.circularParent || BudgetWarningKind.orphanParent => l.budgetBadgeMoved,
      BudgetWarningKind.missingRate => l.budgetBadgeNoRate,
    };
  }

  static IconData issueIcon(BudgetWarningKind kind) => switch (kind) {
    BudgetWarningKind.childrenUnder => Icons.pie_chart_outline_rounded,
    BudgetWarningKind.childrenOver => Icons.call_split_rounded,
    BudgetWarningKind.overspent => Icons.local_fire_department_rounded,
    BudgetWarningKind.percentOver100 => Icons.percent_rounded,
    BudgetWarningKind.circularPercent => Icons.sync_problem_rounded,
    BudgetWarningKind.circularParent || BudgetWarningKind.orphanParent => Icons.vertical_align_top_rounded,
    BudgetWarningKind.missingRate => Icons.currency_exchange_rounded,
  };

  static Color severityColor(MadarTokens t, BudgetIssueSeverity s) => switch (s) {
    BudgetIssueSeverity.notice => t.info,
    BudgetIssueSeverity.warning => t.warning,
    BudgetIssueSeverity.danger => t.danger,
  };

  static String status(L10n l, SpendStatus s) => switch (s) {
    SpendStatus.idle || SpendStatus.calm => l.budgetStatusCalm,
    SpendStatus.near => l.budgetStatusNear,
    SpendStatus.atRisk => l.budgetStatusAtRisk,
    SpendStatus.over => l.budgetStatusOver,
    SpendStatus.unplanned => l.budgetStatusUnplanned,
  };

  static Color statusColor(MadarTokens t, SpendStatus s) => switch (s) {
    SpendStatus.idle => t.textTertiary,
    SpendStatus.calm => t.success,
    SpendStatus.near || SpendStatus.atRisk => t.warning,
    SpendStatus.over || SpendStatus.unplanned => t.danger,
  };

  static String period(L10n l, BudgetPeriod p) => p == BudgetPeriod.weekly ? l.budgetWeekly : l.budgetMonthly;

  /// `12.500 a month` / `5.000 a week`.
  static String perPeriod(L10n l, BudgetPeriod p, String amount) =>
      p == BudgetPeriod.weekly ? l.budgetPerWeek(amount) : l.budgetPerMonth(amount);

  /// `50% of Home food` / `8.57% of the total`.
  static String share(L10n l, BudgetFormat f, BudgetPlan plan, BudgetLine line) {
    final pct = f.percent(line.percentOfBase);
    if (line.percentBase == PercentBase.total) return l.budgetPercentOfTotal(pct);
    return l.budgetPercentOf(pct, name(plan[line.parentId!]?.name ?? ''));
  }
}

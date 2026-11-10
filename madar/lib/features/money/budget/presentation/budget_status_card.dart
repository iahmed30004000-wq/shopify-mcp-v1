import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/widgets.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../data/budget_providers.dart';
import '../data/budget_repository.dart';
import '../domain/budget_plan.dart';
import '../domain/budget_spending.dart';
import 'budget_format.dart';
import 'budget_labels.dart';
import 'widgets/budget_widgets.dart';

/// This month's budget at a glance, for the Money hub: spent of plan with a
/// ring, what is left or over, the projection, a warnings count and the
/// three most used items. [onTap] opens the budget (the hub wires it).
class BudgetStatusCard extends ConsumerWidget {
  const BudgetStatusCard({super.key, this.onTap, this.maxItems = 3});

  final VoidCallback? onTap;

  /// How many items get a mini bar.
  final int maxItems;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final status = ref.watch(budgetStatusProvider).value;
    final currencies = ref.watch(budgetCurrenciesProvider).value ?? BudgetCurrencies.fallback;
    final stored = ref.watch(budgetStoredColorsProvider);
    final f = BudgetFormat.of(context, currencies);

    Widget title(String? trailing, {BudgetIssueSeverity? severity, int warnings = 0}) => Row(
      children: [
        Icon(Icons.account_tree_rounded, size: 18, color: t.gold),
        const SizedBox(width: Space.s),
        Expanded(
          child: Text.rich(
            TextSpan(
              text: l.budgetTitle,
              style: text.titleMedium,
              children: [
                if (trailing != null)
                  TextSpan(
                    text: '${l.commonFactSeparator}$trailing',
                    style: text.bodySmall?.copyWith(color: t.textTertiary),
                  ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (warnings > 0 && severity != null)
          BudgetBadge(
            label: f.fmt.localizeDigits(l.budgetCardWarnings(warnings)),
            color: BudgetLabels.severityColor(t, severity),
            icon: Icons.priority_high_rounded,
          ),
      ],
    );

    if (status == null) {
      return GlassCard(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            title(null),
            const SizedBox(height: Space.l),
            const Center(child: OrbitLoader(size: 24)),
          ],
        ),
      );
    }
    final plan = status.plan;
    final month = status.month;
    if (plan.isEmpty) {
      return GlassCard(
        onTap: onTap,
        semanticLabel: '${l.budgetTitle}. ${l.budgetCardEmpty}',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            title(null),
            const SizedBox(height: Space.m),
            Row(
              children: [
                Icon(Icons.add_chart_rounded, size: 28, color: t.accent),
                const SizedBox(width: Space.m),
                Expanded(
                  child: Text(l.budgetCardEmpty, style: text.bodyMedium?.copyWith(color: t.textSecondary)),
                ),
                Icon(Icons.chevron_right_rounded, color: t.textTertiary),
              ],
            ),
          ],
        ),
      );
    }

    final colors = budgetLineColors(plan, t, stored: stored);
    final ratio = month.plannedMilli == 0 ? 0.0 : month.spentMilli / month.plannedMilli;
    final over = month.remainingMilli < 0;
    final top = [
      for (final line in month.lines)
        if (line.depth == 0 && line.plannedMilli > 0) line,
    ]..sort((a, b) => (b.ratio ?? 0).compareTo(a.ratio ?? 0));
    final spentOf = l.budgetCardSpentOf(f.money(month.spentMilli), f.money(month.plannedMilli));
    final tail = over ? l.budgetOverBy(f.money(-month.remainingMilli)) : l.budgetLeft(f.money(month.remainingMilli));

    return GlassCard(
      onTap: onTap,
      semanticLabel: [
        l.budgetTitle,
        f.window(month.window),
        spentOf,
        tail,
        if (plan.issues.isNotEmpty) f.fmt.localizeDigits(l.budgetCardWarnings(plan.issues.length)),
      ].join('. '),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          title(
            f.window(month.window),
            severity: plan.issues.isEmpty ? null : plan.issues.first.severity,
            warnings: plan.issues.length,
          ),
          const SizedBox(height: Space.m),
          Row(
            children: [
              ProgressRing(
                value: ratio.clamp(0, 1).toDouble(),
                size: 70,
                strokeWidth: 7,
                color: over ? t.danger : t.accent,
                gradientEnd: over ? t.warning : t.highlight,
                child: BudgetAmountText(f.percent(ratio * 100, maxDecimals: 0), size: 15, weight: FontWeight.w700),
              ),
              const SizedBox(width: Space.l),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.centerStart,
                      child: BudgetAmountText(
                        f.money(month.spentMilli),
                        size: 22,
                        color: t.gold,
                        weight: FontWeight.w700,
                      ),
                    ),
                    Text(l.budgetOfPlan(f.money(month.plannedMilli)), style: text.bodySmall),
                    const SizedBox(height: Space.xs),
                    Text(tail, style: text.labelMedium?.copyWith(color: over ? t.danger : t.success)),
                  ],
                ),
              ),
            ],
          ),
          if (top.isNotEmpty) ...[
            const SizedBox(height: Space.m),
            for (final line in top.take(maxItems)) _MiniBar(line: line, color: colors[line.id] ?? t.accent, format: f),
          ],
        ],
      ),
    );
  }
}

class _MiniBar extends StatelessWidget {
  const _MiniBar({required this.line, required this.color, required this.format});

  final SpendLine line;
  final Color color;
  final BudgetFormat format;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final bar = switch (line.status) {
      SpendStatus.over || SpendStatus.unplanned => t.danger,
      SpendStatus.near || SpendStatus.atRisk => t.warning,
      _ => color,
    };
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: Space.s),
      child: Row(
        children: [
          SizedBox(
            width: 104,
            child: Text(
              line.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.labelMedium?.copyWith(color: t.textSecondary),
            ),
          ),
          const SizedBox(width: Space.s),
          Expanded(
            child: SpendBar(plannedMilli: line.plannedMilli, spentMilli: line.spentMilli, color: bar, height: 6),
          ),
          const SizedBox(width: Space.s),
          SizedBox(
            width: 44,
            child: Text(
              format.percent((line.ratio ?? 0) * 100, maxDecimals: 0),
              textAlign: TextAlign.end,
              style: text.labelSmall?.copyWith(color: line.overspent ? t.danger : t.textTertiary),
            ),
          ),
        ],
      ),
    );
  }
}

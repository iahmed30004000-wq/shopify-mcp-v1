import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/widgets.dart';
import '../../../../core/domain/budget_math.dart';
import '../../../../core/domain/enums.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../../../../core/motion/motion_kit.dart';
import '../../../../core/sound/sound_api.dart';
import '../data/budget_providers.dart';
import '../data/budget_repository.dart';
import '../domain/budget_spending.dart';
import 'budget_format.dart';
import 'budget_labels.dart';
import 'widgets/budget_widgets.dart';

/// The Spending tab: month / week, a navigator through past periods, spend
/// vs plan with the end-of-period projection, per-item bars and the
/// history of previous periods.
class BudgetSpendingView extends ConsumerWidget {
  const BudgetSpendingView({super.key, this.bottomInset = Space.xxl, this.onEmptyAction});

  final double bottomInset;

  /// Shown on the empty state (e.g. switch to the Plan tab and add).
  final VoidCallback? onEmptyAction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final t = context.tokens;
    final async = ref.watch(budgetSpendingProvider);
    final window = ref.watch(budgetSpendWindowProvider);
    final nav = ref.read(budgetSpendWindowProvider.notifier);
    final currencies = ref.watch(budgetCurrenciesProvider).value ?? BudgetCurrencies.fallback;
    final stored = ref.watch(budgetStoredColorsProvider);
    final plan = ref.watch(budgetPlanProvider).value;
    final f = BudgetFormat.of(context, currencies);
    final s = async.value;

    final header = <Widget>[
      Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 260),
          child: BudgetSegmented<BudgetPeriod>(
            values: const [BudgetPeriod.monthly, BudgetPeriod.weekly],
            value: window.period,
            height: 40,
            labels: {BudgetPeriod.monthly: l.budgetMonthly, BudgetPeriod.weekly: l.budgetWeekly},
            icons: const {
              BudgetPeriod.monthly: Icons.calendar_month_rounded,
              BudgetPeriod.weekly: Icons.view_week_rounded,
            },
            onChanged: nav.setPeriod,
          ),
        ),
      ),
      const SizedBox(height: Space.xs),
      Row(
        children: [
          BudgetNavButton(
            icon: Icons.chevron_left_rounded,
            semanticLabel: l.budgetPreviousPeriod,
            onTap: nav.canGoBack ? nav.previous : null,
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: context.motion(MadarMotion.short),
              child: Semantics(
                key: ValueKey(window.start),
                header: true,
                child: Text(
                  f.window(window),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(color: t.gold),
                ),
              ),
            ),
          ),
          BudgetNavButton(
            icon: Icons.chevron_right_rounded,
            semanticLabel: l.budgetNextPeriod,
            onTap: nav.canGoForward ? nav.next : null,
          ),
        ],
      ),
    ];

    if (s == null || plan == null) {
      return ListView(
        padding: EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.s, Space.gutter, bottomInset),
        children: [
          ...header,
          const SizedBox(height: Space.xxl),
          if (async.hasError)
            Text('${async.error}', style: Theme.of(context).textTheme.bodySmall)
          else
            const Center(child: OrbitLoader()),
        ],
      );
    }
    if (plan.isEmpty) {
      return ListView(
        padding: EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.s, Space.gutter, bottomInset),
        children: [
          ...header,
          const SizedBox(height: Space.xl),
          AnimatedEmptyState(
            kind: EmptyStateKind.noData,
            title: l.budgetEmptyTitle,
            body: l.budgetEmptyBody,
            actionLabel: onEmptyAction == null ? null : l.budgetEmptyAction,
            actionIcon: Icons.add_rounded,
            onAction: onEmptyAction,
          ),
        ],
      );
    }
    final colors = budgetLineColors(plan, t, stored: stored);
    return ListView(
      key: const PageStorageKey('budget.spending'),
      padding: EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.s, Space.gutter, bottomInset),
      children: [
        ...header,
        const SizedBox(height: Space.s),
        StaggerIn(
          id: ('budget.spend', window.start, window.period),
          children: [
            _HeroCard(spending: s, format: f),
            if (s.unassignedMilli > 0)
              Padding(
                padding: const EdgeInsetsDirectional.only(top: Space.s),
                child: _UnassignedRow(amount: f.money(s.unassignedMilli)),
              ),
            if (s.spentMilli == 0 && s.unassignedMilli == 0)
              Padding(
                padding: const EdgeInsetsDirectional.only(top: Space.m),
                child: Text(
                  l.budgetNoSpending,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: t.textTertiary),
                ),
              ),
            SectionHeader(
              title: l.budgetByItem,
              padding: const EdgeInsetsDirectional.fromSTEB(Space.xs, Space.xl, Space.xs, Space.m),
            ),
            GlassCard(
              seed: 1.7,
              padding: const EdgeInsetsDirectional.fromSTEB(Space.l, Space.s, Space.l, Space.s),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (i, line) in s.lines.indexed) ...[
                    if (i > 0 && line.depth == 0)
                      Divider(height: Space.s, thickness: 0.6, color: t.glassBorder.withValues(alpha: 0.6)),
                    _SpendRow(
                      line: line,
                      format: f,
                      color: colors[line.id] ?? t.accent,
                      showProjection: s.projectionReliable,
                    ),
                  ],
                ],
              ),
            ),
            SectionHeader(
              title: window.period == BudgetPeriod.weekly ? l.budgetHistoryWeeks : l.budgetHistoryMonths,
              padding: const EdgeInsetsDirectional.fromSTEB(Space.xs, Space.xl, Space.xs, Space.m),
            ),
            _HistoryCard(spending: s, format: f, onPick: nav.show),
          ],
        ),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.spending, required this.format});

  final BudgetSpending spending;
  final BudgetFormat format;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final s = spending;
    final f = format;
    final status = s.status;
    final color = BudgetLabels.statusColor(t, status);
    final ratio = s.plannedMilli == 0 ? (s.spentMilli > 0 ? 1.0 : 0.0) : s.spentMilli / s.plannedMilli;
    final over = s.remainingMilli < 0;
    final weekly = s.window.period == BudgetPeriod.weekly;

    Widget fact(String label, String value, {Color? valueColor}) => Padding(
      padding: const EdgeInsetsDirectional.only(top: Space.s),
      child: Row(
        children: [
          Expanded(child: Text(label, style: text.bodySmall)),
          const SizedBox(width: Space.s),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerEnd,
              child: BudgetAmountText(value, size: 14, color: valueColor ?? t.textPrimary),
            ),
          ),
        ],
      ),
    );

    return GlassCard(
      seed: 3.3,
      padding: const EdgeInsetsDirectional.fromSTEB(Space.l, Space.l, Space.l, Space.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ProgressRing(
                value: ratio.clamp(0, 1).toDouble(),
                size: 112,
                strokeWidth: 9,
                color: over ? t.danger : t.accent,
                gradientEnd: over ? t.warning : t.highlight,
                semanticLabel: l.budgetSpent,
                semanticValue: f.percent(ratio * 100, maxDecimals: 0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    BudgetAmountText(
                      f.percent(ratio * 100, maxDecimals: 0),
                      size: 22,
                      color: t.textPrimary,
                      weight: FontWeight.w700,
                    ),
                    Text(l.budgetSpent, style: text.labelSmall?.copyWith(color: t.textTertiary)),
                  ],
                ),
              ),
              const SizedBox(width: Space.l),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.budgetSpent, style: text.labelLarge?.copyWith(color: t.textSecondary)),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.centerStart,
                      child: BudgetAmountText(f.money(s.spentMilli), size: 26, color: t.gold, weight: FontWeight.w700),
                    ),
                    Text(l.budgetOfPlan(f.money(s.plannedMilli)), style: text.bodySmall),
                    const SizedBox(height: Space.s),
                    BudgetStatusPill(label: BudgetLabels.status(l, status), color: color),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.m),
          Container(height: 0.8, color: t.glassBorder.withValues(alpha: 0.6)),
          fact(
            over ? l.budgetOverPlan : l.budgetRemaining,
            f.money(s.remainingMilli.abs()),
            valueColor: over ? t.danger : t.success,
          ),
          if (s.projectionReliable && s.projectedMilli != null)
            fact(
              l.budgetProjection,
              weekly
                  ? l.budgetProjectionWeek(f.money(s.projectedMilli!))
                  : l.budgetProjectionMonth(f.money(s.projectedMilli!)),
              valueColor: s.projectedMilli! > s.plannedMilli ? t.warning : t.textPrimary,
            ),
          Padding(
            padding: const EdgeInsetsDirectional.only(top: Space.s),
            child: Text(
              s.isCurrent
                  ? l.budgetDayOf(f.count(s.elapsedDays), f.count(s.days))
                  : (s.isPast ? l.budgetPeriodClosed : ''),
              style: text.labelSmall?.copyWith(color: t.textTertiary),
            ),
          ),
        ],
      ),
    );
  }
}

class _UnassignedRow extends StatelessWidget {
  const _UnassignedRow({required this.amount});

  final String amount;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(Space.l, Space.s + 2, Space.l, Space.s + 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(t.radiusM),
        color: t.glassFill.withValues(alpha: 0.5),
        border: Border.all(color: t.glassBorder.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          Icon(Icons.label_off_outlined, size: 18, color: t.textTertiary),
          const SizedBox(width: Space.s),
          Expanded(
            child: Text(l.budgetUnassigned, style: text.bodyMedium?.copyWith(color: t.textSecondary)),
          ),
          BudgetAmountText(amount, size: 14, color: t.textSecondary),
        ],
      ),
    );
  }
}

class _SpendRow extends StatelessWidget {
  const _SpendRow({required this.line, required this.format, required this.color, required this.showProjection});

  final SpendLine line;
  final BudgetFormat format;
  final Color color;
  final bool showProjection;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final f = format;
    final statusColor = BudgetLabels.statusColor(t, line.status);
    final barColor = switch (line.status) {
      SpendStatus.over || SpendStatus.unplanned => t.danger,
      SpendStatus.near || SpendStatus.atRisk => t.warning,
      _ => color,
    };
    final root = line.depth == 0;
    final remaining = line.remainingMilli;
    final tail = remaining < 0 ? l.budgetOverBy(f.money(-remaining)) : l.budgetLeft(f.money(remaining));
    final spentOf = l.budgetSpentOf(f.money(line.spentMilli), f.money(line.plannedMilli));
    return Semantics(
      container: true,
      label: [line.name, spentOf, tail, BudgetLabels.status(l, line.status)].join(', '),
      excludeSemantics: true,
      child: Padding(
        padding: EdgeInsetsDirectional.fromSTEB(line.depth * 18.0, Space.m, 0, Space.s),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                if (root)
                  BudgetOrb(color: color, size: 10)
                else
                  BudgetOrb(color: color.withValues(alpha: 0.8), size: 6, glow: false),
                const SizedBox(width: Space.s + 2),
                Expanded(
                  child: Text(
                    line.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: (root ? text.titleSmall : text.bodyMedium)?.copyWith(color: t.textPrimary),
                  ),
                ),
                const SizedBox(width: Space.s),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerEnd,
                    child: Text(spentOf, style: text.labelMedium?.copyWith(color: t.textSecondary)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Space.s),
            SpendBar(
              plannedMilli: line.plannedMilli,
              spentMilli: line.spentMilli,
              projectedMilli: showProjection ? line.projectedMilli : null,
              color: barColor,
              height: root ? 8 : 6,
            ),
            const SizedBox(height: Space.xs + 1),
            Row(
              children: [
                if (line.status != SpendStatus.calm && line.status != SpendStatus.idle)
                  BudgetStatusPill(label: BudgetLabels.status(l, line.status), color: statusColor),
                const Spacer(),
                Text(tail, style: text.labelSmall?.copyWith(color: remaining < 0 ? t.danger : t.textTertiary)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Plan vs spent of the previous periods as a bar chart (latest at the
/// reading-direction end); tapping a bar shows that period.
class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.spending, required this.format, required this.onPick});

  final BudgetSpending spending;
  final BudgetFormat format;
  final ValueChanged<BudgetWindow> onPick;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final f = format;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final history = rtl ? spending.history.reversed.toList() : spending.history;
    final maxV = history.fold<int>(1, (a, h) => math.max(a, math.max(h.plannedMilli, h.spentMilli))) * 1.15;
    final labelStyle = (text.labelSmall ?? const TextStyle(fontSize: 11)).copyWith(color: t.textTertiary);
    final selected = spending.window.start;

    BarChartGroupData group(int x, BudgetPeriodSummary h) {
      final isSel = h.window.start == selected;
      final spentColor = h.overspent ? t.danger : t.accent;
      return BarChartGroupData(
        x: x,
        barsSpace: 3,
        barRods: [
          BarChartRodData(
            toY: h.plannedMilli.toDouble(),
            width: 9,
            color: t.textTertiary.withValues(alpha: 0.35),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
          ),
          BarChartRodData(
            toY: h.spentMilli.toDouble(),
            width: 9,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color.lerp(spentColor, budgetShine(t), 0.2)!,
                spentColor.withValues(alpha: isSel ? 1 : 0.7),
              ],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
            borderSide: isSel ? BorderSide(color: t.gold, width: 1.2) : BorderSide.none,
          ),
        ],
      );
    }

    return GlassCard(
      seed: 6.2,
      padding: const EdgeInsetsDirectional.fromSTEB(Space.m, Space.l, Space.m, Space.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 170,
            child: BarChart(
              BarChartData(
                maxY: maxV,
                minY: 0,
                alignment: BarChartAlignment.spaceAround,
                barGroups: [for (final (i, h) in history.indexed) group(i, h)],
                gridData: FlGridData(
                  drawVerticalLine: false,
                  horizontalInterval: maxV / 3,
                  getDrawingHorizontalLine: (_) =>
                      FlLine(color: t.glassBorder.withValues(alpha: 0.35), strokeWidth: 0.7),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(),
                  leftTitles: const AxisTitles(),
                  rightTitles: const AxisTitles(),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      getTitlesWidget: (value, meta) {
                        final i = value.round();
                        if (i < 0 || i >= history.length) return const SizedBox.shrink();
                        final isSel = history[i].window.start == selected;
                        return SideTitleWidget(
                          meta: meta,
                          space: 6,
                          child: Text(
                            f.windowShort(history[i].window),
                            style: labelStyle.copyWith(color: isSel ? t.gold : t.textTertiary),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => t.space2.withValues(alpha: 0.95),
                    tooltipBorder: BorderSide(color: t.glassBorder),
                    fitInsideHorizontally: true,
                    fitInsideVertically: true,
                    getTooltipItem: (g, gi, rod, ri) => ri == 1
                        ? BarTooltipItem(
                            '${f.window(history[g.x].window)}\n',
                            labelStyle,
                            children: [
                              TextSpan(
                                text: l.budgetSpentOf(
                                  f.money(history[g.x].spentMilli),
                                  f.money(history[g.x].plannedMilli),
                                ),
                                style: (text.labelMedium ?? const TextStyle()).copyWith(color: t.textPrimary),
                              ),
                            ],
                          )
                        : null,
                  ),
                  touchCallback: (event, response) {
                    if (event is FlTapUpEvent && response?.spot != null) {
                      final i = response!.spot!.touchedBarGroupIndex;
                      if (i >= 0 && i < history.length) {
                        Fx.fire(Sfx.navigate);
                        onPick(history[i].window);
                      }
                    }
                  },
                ),
              ),
              duration: context.motion(MadarMotion.medium),
              curve: MadarMotion.standard,
            ),
          ),
          const SizedBox(height: Space.s),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _Legend(color: t.textTertiary.withValues(alpha: 0.5), label: l.budgetLegendPlan),
              const SizedBox(width: Space.l),
              _Legend(color: t.accent, label: l.budgetLegendSpent),
              const SizedBox(width: Space.l),
              _Legend(color: t.danger, label: l.budgetStatusOver),
            ],
          ),
          const SizedBox(height: Space.s),
          Text(l.budgetHistoryNote, textAlign: TextAlign.center, style: labelStyle),
          // Screen readers get the numbers as a list.
          ExcludeSemantics(
            excluding: false,
            child: _HistorySemantics(spending: spending, format: f),
          ),
        ],
      ),
    );
  }
}

class _HistorySemantics extends StatelessWidget {
  const _HistorySemantics({required this.spending, required this.format});

  final BudgetSpending spending;
  final BudgetFormat format;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    return Semantics(
      container: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final h in spending.history)
            Semantics(
              label: l.budgetHistoryBar(
                format.window(h.window),
                format.money(h.spentMilli),
                format.money(h.plannedMilli),
              ),
              child: const SizedBox(width: 1, height: 0),
            ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: Space.xs + 2),
        Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: t.textSecondary)),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/widgets.dart';
import '../../../../core/domain/enums.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../../../../core/interaction/interaction.dart';
import '../../../../core/motion/motion_kit.dart';
import '../../../../core/sound/sound_api.dart';
import '../data/budget_providers.dart';
import '../data/budget_repository.dart';
import '../domain/budget_plan.dart';
import 'budget_actions.dart';
import 'budget_format.dart';
import 'budget_labels.dart';
import 'widgets/budget_widgets.dart';

/// The Plan tab: the total with its split, the warnings summary and the
/// nested tree (tap to edit, long-press for more, swipe for quick actions,
/// drag a handle to reorder within a group).
class BudgetPlanView extends ConsumerWidget {
  const BudgetPlanView({super.key, this.bottomInset = 96});

  /// Space kept free under the list (the add button).
  final double bottomInset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final async = ref.watch(budgetPlanProvider);
    final currencies = ref.watch(budgetCurrenciesProvider).value ?? BudgetCurrencies.fallback;
    final stored = ref.watch(budgetStoredColorsProvider);
    final plan = async.value;
    if (plan == null) {
      if (async.hasError) {
        return Center(child: Text('${async.error}', style: Theme.of(context).textTheme.bodySmall));
      }
      return const Center(child: OrbitLoader());
    }
    final f = BudgetFormat.of(context, currencies);
    final colors = budgetLineColors(plan, context.tokens, stored: stored);
    final actions = BudgetActions(ref, context);

    if (plan.isEmpty) {
      return ListView(
        padding: EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.s, Space.gutter, bottomInset),
        children: [
          _SummaryCard(plan: plan, format: f, colors: colors, onWeeks: actions.editWeeksPerMonth),
          const SizedBox(height: Space.xl),
          AnimatedEmptyState(
            kind: EmptyStateKind.emptyList,
            title: l.budgetEmptyTitle,
            body: l.budgetEmptyBody,
            actionLabel: l.budgetEmptyAction,
            actionIcon: Icons.add_rounded,
            onAction: () => actions.add(),
          ),
        ],
      );
    }

    final data = _PlanData(plan: plan, format: f, colors: colors, actions: actions);
    return ReorderableGlassList<BudgetLine>(
      key: const PageStorageKey('budget.plan'),
      items: plan.roots,
      itemKey: (line) => line.id,
      padding: EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.s, Space.gutter, 0),
      spacing: Space.m,
      header: Padding(
        padding: const EdgeInsetsDirectional.only(bottom: Space.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SummaryCard(plan: plan, format: f, colors: colors, onWeeks: actions.editWeeksPerMonth),
            const SizedBox(height: Space.m),
            _WarningsCard(plan: plan, format: f, onOpen: actions.edit),
          ],
        ),
      ),
      footer: Padding(
        padding: EdgeInsetsDirectional.fromSTEB(Space.l, Space.xs, Space.l, bottomInset),
        child: Text(
          l.budgetDragHint,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.tokens.textTertiary),
        ),
      ),
      onReorder: (lines) => actions.reorder([for (final x in lines) x.id]),
      itemBuilder: (context, line, index, grip) => _RootCard(data: data, line: line, grip: grip),
    );
  }
}

/// The plan, formatter, colours and actions the tree rows need. Passed
/// explicitly (not inherited): a dragged row is rebuilt in the overlay,
/// outside this view.
class _PlanData {
  const _PlanData({required this.plan, required this.format, required this.colors, required this.actions});

  final BudgetPlan plan;
  final BudgetFormat format;
  final Map<String, Color> colors;
  final BudgetActions actions;
}

// ---------------------------------------------------------------- header --

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.plan, required this.format, required this.colors, required this.onWeeks});

  final BudgetPlan plan;
  final BudgetFormat format;
  final Map<String, Color> colors;
  final VoidCallback onWeeks;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final f = format;
    final roots = plan.roots;
    final total = plan.totalMonthlyMilli;
    // Rounded so the legend adds up to exactly 100 %.
    final shares = plan.rootShares();
    return GlassCard(
      seed: 2.4,
      padding: const EdgeInsetsDirectional.fromSTEB(Space.l, Space.l, Space.l, Space.m + 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(l.budgetMonthlyPlan, style: text.labelLarge?.copyWith(color: t.textSecondary)),
              ),
              const SizedBox(width: Space.s),
              _WeeksChip(label: l.budgetWeeksPerMonthChip(f.weeks(plan.weeksPerMonth)), onTap: onWeeks),
            ],
          ),
          const SizedBox(height: Space.xs),
          Semantics(
            label: '${l.budgetMonthlyPlan}: ${f.money(total)}',
            excludeSemantics: true,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: BudgetAmountText(f.money(total), size: 32, color: t.gold, weight: FontWeight.w700),
            ),
          ),
          if (total != 0) ...[
            const SizedBox(height: Space.xxs),
            Text(l.budgetWeeklyEquivalent(f.money(plan.totalWeeklyMilli)), style: text.bodySmall),
          ],
          if (roots.isNotEmpty && total > 0) ...[
            const SizedBox(height: Space.l),
            AllocationStrip(
              semanticLabel: l.budgetAllocation,
              segments: [
                for (final r in roots) (id: r.id, share: r.monthlyMilli / total, color: colors[r.id] ?? t.accent),
              ],
            ),
            const SizedBox(height: Space.m),
            Wrap(
              spacing: Space.m,
              runSpacing: Space.xs + 2,
              children: [
                for (final r in roots)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      BudgetOrb(color: colors[r.id] ?? t.accent, size: 8),
                      const SizedBox(width: Space.xs + 1),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 130),
                        child: Text(
                          r.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.labelMedium?.copyWith(color: t.textSecondary),
                        ),
                      ),
                      const SizedBox(width: Space.xs),
                      Text(
                        f.percent(shares[r.id] ?? r.percentOfTotal, maxDecimals: 1),
                        style: text.labelMedium?.copyWith(color: t.textTertiary),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _WeeksChip extends StatelessWidget {
  const _WeeksChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return MadarPressable(
      onTap: onTap,
      sfx: Sfx.sheetOpen,
      semanticLabel: label,
      excludeChildSemantics: true,
      focusRadius: BorderRadius.circular(99),
      child: Container(
        constraints: const BoxConstraints(minHeight: 36),
        padding: const EdgeInsetsDirectional.fromSTEB(Space.m, Space.xs + 2, Space.s + 2, Space.xs + 2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(99),
          color: t.glassFill,
          border: Border.all(color: t.brass.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.date_range_rounded, size: 15, color: t.gold),
            const SizedBox(width: Space.xs + 2),
            Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: t.textSecondary)),
            Icon(Icons.expand_more_rounded, size: 16, color: t.textTertiary),
          ],
        ),
      ),
    );
  }
}

class _WarningsCard extends StatefulWidget {
  const _WarningsCard({required this.plan, required this.format, required this.onOpen});

  final BudgetPlan plan;
  final BudgetFormat format;
  final ValueChanged<String> onOpen;

  @override
  State<_WarningsCard> createState() => _WarningsCardState();
}

class _WarningsCardState extends State<_WarningsCard> {
  static const _collapsed = 3;
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final issues = widget.plan.issues;
    if (issues.isEmpty) {
      return Align(
        alignment: AlignmentDirectional.centerStart,
        child: BudgetBadge(label: l.budgetBalanced, color: t.success, icon: Icons.check_circle_outline_rounded),
      );
    }
    final worst = issues.first.severity;
    final color = BudgetLabels.severityColor(t, worst);
    final shown = _expanded ? issues : issues.take(_collapsed).toList();
    return GlassCard(
      seed: 4.1,
      borderColor: color.withValues(alpha: 0.45),
      glowColor: t.isDark ? color.withValues(alpha: 0.25) : null,
      padding: const EdgeInsetsDirectional.fromSTEB(Space.l, Space.m, Space.m, Space.s),
      child: AnimatedSize(
        duration: context.motion(MadarMotion.medium),
        curve: MadarMotion.emphasized,
        alignment: AlignmentDirectional.topStart,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: 0.16)),
                  child: Icon(Icons.priority_high_rounded, size: 18, color: color),
                ),
                const SizedBox(width: Space.m),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      widget.format.fmt.localizeDigits(l.budgetWarningsTitle(issues.length)),
                      style: text.titleSmall,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Space.xs),
            for (final i in shown)
              _IssueRow(
                text: BudgetLabels.issue(l, widget.format, widget.plan, i),
                icon: BudgetLabels.issueIcon(i.kind),
                color: BudgetLabels.severityColor(t, i.severity),
                onTap: i.nodeId == null ? null : () => widget.onOpen(i.nodeId!),
              ),
            if (issues.length > _collapsed)
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: MadarButton(
                  label: _expanded
                      ? l.budgetShowLess
                      : widget.format.fmt.localizeDigits(l.budgetWarningsMore(issues.length - _collapsed)),
                  variant: MadarButtonVariant.ghost,
                  size: MadarButtonSize.small,
                  trailingIcon: _expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                  onPressed: () => setState(() => _expanded = !_expanded),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _IssueRow extends StatelessWidget {
  const _IssueRow({required this.text, required this.icon, required this.color, this.onTap});

  final String text;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return MadarPressable(
      onTap: onTap,
      enabled: onTap != null,
      semanticLabel: text,
      excludeChildSemantics: true,
      focusRadius: BorderRadius.circular(t.radiusS),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Space.s),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.only(top: 1, start: 6),
              child: Icon(icon, size: 17, color: color),
            ),
            const SizedBox(width: Space.m + 1),
            Expanded(
              child: Text(text, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: t.textPrimary)),
            ),
            if (onTap != null)
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: t.textTertiary,
                textDirection: Directionality.of(context),
              ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ tree --

class _RootCard extends StatelessWidget {
  const _RootCard({required this.data, required this.line, required this.grip});

  final _PlanData data;
  final BudgetLine line;
  final Widget grip;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final color = data.colors[line.id] ?? t.accent;
    final worst = line.worstSeverity;
    return GlassCard(
      seed: line.id.hashCode % 97 / 10,
      padding: EdgeInsetsDirectional.zero,
      borderColor: worst == BudgetIssueSeverity.danger ? t.danger.withValues(alpha: 0.4) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ItemRow(data: data, line: line, grip: grip),
          if (line.hasChildren)
            Padding(
              padding: const EdgeInsetsDirectional.only(bottom: Space.s),
              child: _ChildList(data: data, parent: line, color: color),
            ),
        ],
      ),
    );
  }
}

/// The sub-items of [parent] as a reorderable group, each with its own
/// sub-items below it.
class _ChildList extends StatelessWidget {
  const _ChildList({required this.data, required this.parent, required this.color});

  final _PlanData data;
  final BudgetLine parent;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final kids = data.plan.childrenOf(parent.id);
    return Stack(
      children: [
        // The branch guide in the parent's colour.
        PositionedDirectional(
          start: 24.0 + parent.depth * 18,
          top: 0,
          bottom: Space.m,
          child: Container(
            width: 1.2,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [color.withValues(alpha: 0.55), color.withValues(alpha: 0.05)],
              ),
            ),
          ),
        ),
        ReorderableGlassList<BudgetLine>(
          items: kids,
          itemKey: (line) => line.id,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          spacing: 0,
          animateEntrance: false,
          onReorder: (lines) => data.actions.reorder([for (final x in lines) x.id]),
          itemBuilder: (context, line, index, grip) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              _ItemRow(data: data, line: line, grip: grip),
              if (line.hasChildren) _ChildList(data: data, parent: line, color: color),
            ],
          ),
        ),
      ],
    );
  }
}

/// One item: name, what it is worth in the other terms, warnings, the
/// value that sets it and a drag grip.
class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.data, required this.line, required this.grip});

  final _PlanData data;
  final BudgetLine line;
  final Widget grip;

  @override
  Widget build(BuildContext context) {
    final l = L10n.of(context);
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final f = data.format;
    final plan = data.plan;
    final actions = data.actions;
    final color = data.colors[line.id] ?? t.accent;
    final root = line.depth == 0;
    final byPercent = line.setByPercent;
    final money = f.money(line.plannedMilli, line.currency);

    // The value the user set, and what it is worth in the other terms.
    final primary = byPercent ? f.percent(line.percentOfBase) : money;
    final String? secondary = byPercent
        ? (line.percentBase == PercentBase.total
              ? l.budgetOfTotal
              : l.budgetOfParent(BudgetLabels.name(plan[line.parentId!]?.name ?? '')))
        : (line.period == BudgetPeriod.weekly ? BudgetLabels.period(l, line.period) : null);
    final meta = <String>[
      if (line.derived) l.budgetSumOfChildren,
      if (byPercent) BudgetLabels.perPeriod(l, line.period, money) else BudgetLabels.share(l, f, plan, line),
      if (line.isForeign || line.period == BudgetPeriod.weekly) l.budgetApproxMonthly(f.money(line.monthlyMilli)),
    ].join(l.commonFactSeparator);

    final label = [
      line.name,
      byPercent ? l.budgetSetByPercent : l.budgetSetByAmount,
      primary,
      ?secondary,
      meta,
      for (final i in line.issues) BudgetLabels.badge(l, f, i),
    ].join(', ');

    final content = Padding(
      padding: EdgeInsetsDirectional.fromSTEB(
        root ? Space.l : Space.l + 12 + line.depth * 18,
        root ? Space.m + 2 : Space.s + 2,
        Space.xxs,
        root ? Space.m + 2 : Space.s + 2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (root)
                BudgetOrb(color: color, size: 14)
              else
                BudgetOrb(color: color.withValues(alpha: 0.8), size: 7, glow: false),
              SizedBox(width: root ? Space.m : Space.m - 2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      line.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: (root ? text.titleMedium : text.bodyLarge)?.copyWith(
                        color: t.textPrimary,
                        fontWeight: root ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(meta, maxLines: 2, overflow: TextOverflow.ellipsis, style: text.bodySmall),
                  ],
                ),
              ),
              const SizedBox(width: Space.s),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 150),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.centerEnd,
                      child: BudgetAmountText(
                        primary,
                        size: root ? 17 : 15,
                        color: byPercent ? t.gold : t.textPrimary,
                        weight: root ? FontWeight.w700 : FontWeight.w600,
                      ),
                    ),
                  ),
                  if (secondary != null) ...[
                    const SizedBox(height: 2),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 120),
                      child: Text(
                        secondary,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.labelSmall?.copyWith(color: t.textTertiary),
                      ),
                    ),
                  ],
                ],
              ),
              SizedBox(width: 40, height: 44, child: Center(child: grip)),
            ],
          ),
          if (line.issues.isNotEmpty)
            Padding(
              padding: EdgeInsetsDirectional.only(
                top: Space.xs,
                start: root ? 14 + Space.m : 7 + Space.m - 2,
                end: Space.m,
              ),
              child: Wrap(
                spacing: Space.xs + 2,
                runSpacing: Space.xs,
                children: [
                  for (final i in line.issues)
                    BudgetBadge(
                      label: BudgetLabels.badge(l, f, i),
                      color: BudgetLabels.severityColor(t, i.severity),
                      icon: BudgetLabels.issueIcon(i.kind),
                    ),
                ],
              ),
            ),
        ],
      ),
    );

    return ActionableItem(
      semanticLabel: label,
      borderRadius: BorderRadius.circular(t.radiusM),
      onTap: () => actions.edit(line.id),
      actions: ItemActions(
        onEdit: () => actions.edit(line.id),
        onMove: () => actions.move(line.id),
        onDelete: () => actions.delete(line.id),
        extra: [
          ItemAction(
            icon: Icons.subdirectory_arrow_left_rounded,
            label: l.budgetAddChild,
            tone: ActionTone.accent,
            onSelected: () async {
              await actions.add(parentId: line.id);
              return null;
            },
          ),
          ItemAction(
            icon: Icons.playlist_add_rounded,
            label: l.budgetAddSibling,
            onSelected: () async {
              await actions.add(parentId: line.parentId, afterId: line.id);
              return null;
            },
          ),
        ],
      ),
      quickActions: [
        QuickAction(
          icon: Icons.subdirectory_arrow_left_rounded,
          label: l.budgetAddChild,
          onPressed: () async {
            await actions.add(parentId: line.id);
            return null;
          },
        ),
        QuickAction(
          icon: Icons.edit_rounded,
          label: l.actionEdit,
          tone: ActionTone.info,
          onPressed: () async {
            await actions.edit(line.id);
            return null;
          },
        ),
      ],
      child: content,
    );
  }
}

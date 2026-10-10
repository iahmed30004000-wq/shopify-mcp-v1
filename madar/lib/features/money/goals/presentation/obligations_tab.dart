import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/design/widgets/widgets.dart';
import '../../../../core/i18n/gen/app_localizations.dart';
import '../../../../core/motion/motion_kit.dart';
import '../data/goals_providers.dart';
import '../domain/due_dates.dart';
import '../domain/goals_snapshot.dart';
import '../domain/obligation_plan.dart';
import 'goals_actions.dart';
import 'goals_tiles.dart';
import 'goals_ui.dart';

/// Recurring obligations: what they cost per month, then overdue, due this
/// week, later and paused ones.
class ObligationsTab extends ConsumerWidget {
  const ObligationsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final t = context.tokens;
    final snap = ref.watch(goalsSnapshotProvider);
    if (snap == null) return const Center(child: OrbitLoader());
    final texts = goalsTexts(context, ref);
    final all = snap.obligations;
    final overdue = [
      for (final o in all)
        if (o.state.dueState == DueState.overdue) o,
    ];
    final soon = [
      for (final o in all)
        if (o.state.dueState == DueState.today || o.state.dueState == DueState.soon) o,
    ];
    final later = [
      for (final o in all)
        if (o.state.dueState == DueState.later) o,
    ];
    final paused = snap.pausedObligations;
    var index = 0;

    List<Widget> section(String title, List<ObligationView> items, {Color? color}) => [
      if (items.isNotEmpty) ...[
        GoalsSectionTitle(title, count: texts.fmt.formatInt(items.length), color: color),
        for (final o in items)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.s),
            child: StaggerItem(
              index: index++,
              child: ObligationTile(key: ValueKey(o.id), obligation: o),
            ),
          ),
      ],
    ];

    return ListView(
      padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.s, Space.gutter, goalsTabBottomPadding),
      children: [
        if (all.isEmpty && paused.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: Space.l),
            child: AnimatedEmptyState(
              kind: EmptyStateKind.emptyList,
              title: l.goalsObligationsEmptyTitle,
              body: l.goalsObligationsEmptyBody,
              actionLabel: l.goalsObligationNew,
              actionIcon: Icons.add_rounded,
              onAction: () => GoalsActions(context, ref).addObligation(),
            ),
          )
        else ...[
          StaggerItem(
            index: index++,
            child: ObligationTotalsCard(totals: snap.obligationTotals),
          ),
          const SizedBox(height: Space.xs),
          ...section(l.goalsSectionOverdue, overdue, color: t.danger),
          ...section(l.goalsSectionThisWeek, soon, color: t.warning),
          ...section(l.goalsSectionLater, later),
          ...section(l.goalsSectionPaused, paused, color: t.textSecondary),
          Padding(
            padding: const EdgeInsets.only(top: Space.m),
            child: Text(
              l.goalsObligationsHint,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: t.textTertiary),
            ),
          ),
        ],
      ],
    );
  }
}

/// The monthly cost of every active obligation (base currency) and how
/// many are overdue or due this week.
class ObligationTotalsCard extends ConsumerWidget {
  const ObligationTotalsCard({super.key, required this.totals});

  final ObligationTotals totals;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final t = context.tokens;
    final texts = goalsTexts(context, ref);
    final fmt = texts.fmt;
    return GoalsHeaderCard(
      seed: 3.7,
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: t.brass.withValues(alpha: 0.7)),
              gradient: RadialGradient(colors: [t.gold.withValues(alpha: 0.22), t.gold.withValues(alpha: 0.04)]),
            ),
            child: Icon(GoalsIcons.obligations, color: t.gold),
          ),
          const SizedBox(width: Space.m),
          Expanded(
            child: GoalsFigure(
              label: l.goalsMonthlyCommitments,
              value: texts.base(totals.monthlyBaseMilli),
              large: true,
              caption: fmt.localizeDigits(l.goalsActiveCount(totals.activeCount, fmt.formatInt(totals.activeCount))),
            ),
          ),
          // The amount shrinks to fit; it never runs into the pills.
          const SizedBox(width: Space.s),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (totals.overdueCount > 0)
                GoalsPill(
                  label: fmt.localizeDigits(
                    l.goalsOverdueCount(totals.overdueCount, fmt.formatInt(totals.overdueCount)),
                  ),
                  color: t.danger,
                  filled: true,
                ),
              if (totals.overdueCount > 0 && totals.dueSoonCount > 0) const SizedBox(height: Space.xs),
              if (totals.dueSoonCount > 0)
                GoalsPill(
                  label: fmt.localizeDigits(
                    l.goalsDueSoonCount(totals.dueSoonCount, fmt.formatInt(totals.dueSoonCount)),
                  ),
                  color: t.warning,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

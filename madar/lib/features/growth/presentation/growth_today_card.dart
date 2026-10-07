import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tokens.dart';
import '../../../core/design/widgets/widgets.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../../../core/sound/sound_api.dart';
import '../data/growth_providers.dart';
import '../domain/growth_goal.dart';
import 'growth_actions.dart';
import 'growth_navigation.dart';
import 'growth_texts.dart';
import 'widgets/growth_widgets.dart';

/// Compact card for the Growth planet hub: the (up to [limit]) goals that
/// need attention most, each with its ring, pace line and a one-tap "+usual
/// amount"; the streak and what was logged today. Empty: a call to add a
/// first goal. "All goals" opens [onOpen] (else pushes the Growth screen);
/// a row opens its goal.
class GrowthTodayCard extends ConsumerWidget {
  const GrowthTodayCard({super.key, this.onOpen, this.limit = 3});

  final void Function(BuildContext context)? onOpen;
  final int limit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final l = L10n.of(context);
    final texts = GrowthTexts.of(context);
    final text = Theme.of(context).textTheme;
    final overview = ref.watch(growthOverviewProvider).value;
    final green = GrowthColors.planet(t);

    void openAll() {
      if (onOpen != null) {
        Fx.fire(Sfx.navigate);
        onOpen!(context);
      } else {
        unawaited(GrowthNavigation.openGrowth(context));
      }
    }

    final Widget body;
    if (overview == null) {
      body = const SizedBox(height: 64, child: Center(child: OrbitLoader(size: 28)));
    } else if (overview.isEmpty) {
      body = Row(
        children: [
          Expanded(child: Text(l.growthCardEmpty, style: text.bodySmall)),
          const SizedBox(width: Space.m),
          MadarButton(
            label: l.growthNewGoal,
            icon: Icons.add_rounded,
            size: MadarButtonSize.small,
            onPressed: () => GrowthActions.create(context, ref),
          ),
        ],
      );
    } else {
      final focus = overview.focus(limit: limit);
      body = focus.isEmpty
          ? Row(
              children: [
                Icon(Icons.verified_rounded, color: t.success, size: 20),
                const SizedBox(width: Space.s),
                Expanded(child: Text(l.growthCardAllDone, style: text.bodySmall)),
              ],
            )
          : Column(
              children: [
                for (final (i, g) in focus.indexed) ...[
                  if (i > 0) Divider(height: Space.l, color: t.glassBorder.withValues(alpha: 0.6)),
                  _CardRow(goal: g),
                ],
              ],
            );
    }

    final streak = overview?.streak;
    return GlassCard(
      borderRadius: BorderRadius.circular(t.radiusL),
      padding: const EdgeInsetsDirectional.fromSTEB(Space.l, Space.m, Space.l, Space.m),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GrowthCardHeader(
            icon: Icons.spa_rounded,
            title: l.growthCardTitle,
            color: green,
            trailing: overview == null || overview.isEmpty
                ? null
                : GrowthLink(label: l.growthCardOpenAll, onTap: openAll),
          ),
          const SizedBox(height: Space.m),
          body,
          if (streak != null && overview != null && !overview.isEmpty) ...[
            const SizedBox(height: Space.m),
            Row(
              children: [
                GrowthPill(
                  label: texts.fmt.localizeDigits(l.growthStreakDays(streak.current)),
                  icon: Icons.local_fire_department_rounded,
                  color: streak.current > 0 ? t.warning : t.textTertiary,
                ),
                const SizedBox(width: Space.s),
                Expanded(
                  child: Text(
                    streak.atRisk
                        ? l.growthStreakAtRisk
                        : overview.loggedTodayCount == 0
                        ? l.growthNothingToday
                        : l.growthLoggedToday(
                            texts.fmt.formatInt(overview.loggedTodayCount),
                            texts.fmt.formatInt(overview.goals.length),
                          ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: text.labelSmall!.copyWith(color: streak.atRisk ? t.warning : t.textTertiary),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _CardRow extends ConsumerWidget {
  const _CardRow({required this.goal});

  final GrowthGoal goal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final l = L10n.of(context);
    final texts = GrowthTexts.of(context);
    final text = Theme.of(context).textTheme;
    final paceColor = GrowthColors.pace(t, goal.stats.pace);
    final usual = goal.usualAmount;
    return Row(
      children: [
        Expanded(
          child: MadarPressable(
            onTap: () => unawaited(GrowthNavigation.openGoal(context, ref, goal.id)),
            sfx: null,
            semanticLabel: texts.semantics(goal),
            excludeChildSemantics: true,
            // 48 dp high (Android) even when the pace line is one line.
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Row(
                children: [
                  GoalRing(goal: goal, size: 46, strokeWidth: 4),
                  const SizedBox(width: Space.m),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          goal.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.titleSmall!.copyWith(color: t.textPrimary),
                        ),
                        Text(
                          texts.paceLine(goal),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: text.labelMedium!.copyWith(color: paceColor),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: Space.s),
        AmountChip(
          label: texts.signed(usual),
          semanticLabel: l.growthLogQuick(texts.amount(goal.unit, usual)),
          color: GrowthColors.goal(t, goal.color),
          dense: true,
          sfx: null,
          onTap: () => GrowthActions.quickLog(context, ref, goal, usual),
        ),
      ],
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tokens.dart';
import '../../../core/design/widgets/widgets.dart';
import '../../../core/i18n/gen/app_localizations.dart';
import '../../../core/interaction/interaction.dart';
import '../../../core/motion/motion_kit.dart';
import '../../../core/settings/app_settings.dart';
import '../../../core/sound/sound_api.dart';
import '../data/growth_providers.dart';
import '../domain/growth_goal.dart';
import 'growth_actions.dart';
import 'widgets/goal_chart.dart';
import 'widgets/goal_history.dart';
import 'widgets/goal_panels.dart';

/// One learning goal: the ring with one-tap amounts and "log progress",
/// streak / active days / deadline, needed vs actual pace with the
/// projected finish, the trajectory chart and the progress log (edit or
/// delete any entry, with undo). Edit and delete the goal from the bar.
class GoalScreen extends ConsumerWidget {
  const GoalScreen({super.key, required this.goalId, this.animateBackdrop = true});

  final String goalId;

  /// Pass false in battery-saver mode (also follows the power setting).
  final bool animateBackdrop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final async = ref.watch(growthGoalProvider(goalId));
    final goal = async.value;
    return MadarScaffold(
      title: goal?.name ?? l.growthTitle,
      backdropSeed: 6.4,
      animateBackdrop:
          animateBackdrop && ref.watch(appSettingsProvider.select((s) => s.powerMode != PowerMode.batterySaver)),
      actions: [
        if (goal != null) ...[
          MadarButton.icon(
            icon: Icons.edit_rounded,
            onPressed: () => GrowthActions.edit(context, ref, goal),
            semanticLabel: l.growthEdit,
            variant: MadarButtonVariant.ghost,
          ),
          MadarButton.icon(
            icon: Icons.delete_outline_rounded,
            onPressed: () => _delete(context, ref, goal),
            semanticLabel: l.growthDelete,
            variant: MadarButtonVariant.ghost,
            sfx: Sfx.delete,
          ),
        ],
      ],
      body: switch (async) {
        AsyncData(value: final GrowthGoal g) => _GoalBody(goal: g),
        AsyncData() || AsyncError() => Center(
          child: AnimatedEmptyState(kind: EmptyStateKind.noData, title: l.growthGoalMissing, body: ''),
        ),
        _ => const Center(child: OrbitLoader(size: 40)),
      },
    );
  }

  static Future<void> _delete(BuildContext context, WidgetRef ref, GrowthGoal goal) async {
    final action = await GrowthActions.delete(context, ref, goal);
    if (!context.mounted) return;
    // The toast lives in the root overlay: it outlives this page.
    unawaited(showUndoToast(context, action));
    final navigator = Navigator.of(context);
    if (navigator.canPop()) navigator.pop();
  }
}

class _GoalBody extends ConsumerWidget {
  const _GoalBody({required this.goal});

  final GrowthGoal goal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L10n.of(context);
    final now = ref.watch(growthClockProvider)();
    final today = ref.watch(growthTodayProvider);
    var i = 0;
    return EntranceChoreo(
      id: 'growth-goal-${goal.id}',
      child: ListView(
        padding: const EdgeInsetsDirectional.fromSTEB(Space.gutter, Space.s, Space.gutter, Space.xxxl + Space.xl),
        children: [
          StaggerItem(
            index: i++,
            child: GoalHero(
              goal: goal,
              onQuickLog: (a) => GrowthActions.quickLog(context, ref, goal, a),
              onLog: () => GrowthActions.log(context, ref, goal),
              onResume: () async {
                final action = await GrowthActions.togglePause(context, ref, goal);
                if (context.mounted) unawaited(showUndoToast(context, action));
              },
            ),
          ),
          const SizedBox(height: Space.m),
          StaggerItem(
            index: i++,
            child: GoalStatsStrip(goal: goal),
          ),
          const SizedBox(height: Space.m),
          StaggerItem(
            index: i++,
            child: GoalPaceCard(goal: goal),
          ),
          StaggerItem(
            index: i++,
            child: SectionHeader(
              title: l.growthChartTitle,
              padding: const EdgeInsetsDirectional.fromSTEB(0, Space.xl, 0, Space.m),
            ),
          ),
          StaggerItem(
            index: i++,
            child: GlassCard(
              padding: const EdgeInsetsDirectional.fromSTEB(Space.s, Space.m, Space.m, Space.m),
              child: GoalChart(goal: goal, now: now),
            ),
          ),
          StaggerItem(
            index: i++,
            child: SectionHeader(
              title: l.growthHistoryTitle,
              actionLabel: goal.stats.active || goal.stats.completed ? l.growthLogProgress : null,
              onAction: () => GrowthActions.log(context, ref, goal),
              padding: const EdgeInsetsDirectional.fromSTEB(0, Space.xl, 0, Space.m),
            ),
          ),
          GoalHistory(
            goal: goal,
            today: today,
            onEdit: (log) => GrowthActions.editLog(context, ref, goal, log),
            onDelete: (log) => GrowthActions.deleteLog(context, ref, log),
          ),
        ],
      ),
    );
  }
}
